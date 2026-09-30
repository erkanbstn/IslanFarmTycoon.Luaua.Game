--!strict
-- Ahır siparişleri (depo sözleşmeleri): ahır deposundaki ürünleri para karşılığı teslim eden, zamanla yenilenen panodaki teklifler.
-- Teklifler kayıttan ve sunucu saatinden türetilir (sunucu anahtarı yeniden hesaplayıp doğrular, client yalnızca çizer).
-- FarmMath cephesi (init.luau) bunları birleştirir; her zaman `FarmMath.<ad>` ile kullan.

local Config = require(script.Parent.Parent.Parent:WaitForChild("Config"))
local GameTypes = require(script.Parent.Parent.Parent:WaitForChild("GameTypes"))
local Core = require(script.Parent:WaitForChild("Core"))
local Goods = require(script.Parent:WaitForChild("Goods"))

type PlayerSave = GameTypes.PlayerSave

local Contracts = {}

export type Line = { goodsId: string, amount: number }
export type Offer = {
	key: string, -- "<pencere>:<sıra>"
	tier: string,
	displayName: string,
	lines: { Line },
	worth: number, -- satırların ürün değerleri toplamı
	rewardFactor: number,
	reward: number,
}

function Contracts.window(now: number): number
	return math.floor(now / Config.GOODS_CONTRACTS.seconds)
end

-- Kaç saniye sonra yenilenir
function Contracts.secondsLeft(now: number): number
	return Config.GOODS_CONTRACTS.seconds - now % Config.GOODS_CONTRACTS.seconds
end

-- Çiftliğin üretebildiği ürünler: ürün merkezi kurulu ve adası açık olanlar (GOODS_ORDER sırasıyla)
function Contracts.availableGoods(save: PlayerSave): { string }
	local built: { [string]: boolean } = {}
	for _, recipe in Config.PRODUCTION_RECIPES do
		if
			recipe.output == "goods"
			and recipe.goodsId
			and save.purchased[recipe.upgradeId]
			and save.unlockedIslands[recipe.island]
		then
			built[recipe.goodsId] = true
		end
	end
	local result: { string } = {}
	for _, goodsId in Config.GOODS_ORDER do
		if built[goodsId] then
			table.insert(result, goodsId)
		end
	end
	return result
end

local function totalWorth(lines: { Line }): number
	local worth = 0
	for _, line in lines do
		worth += line.amount * Config.GOODS[line.goodsId].value
	end
	return worth
end

-- Teklifin ödülü: ürünlerin para değeri x kademe çarpanı x (1 + mevsim bonusu)
function Contracts.reward(worth: number, rewardFactor: number, bonus: number?): number
	return math.floor(worth * rewardFactor * (1 + (bonus or 0)))
end

-- O anki pencerenin teklifleri: kademe başına bir teklif; satır sayısı kadar farklı ürün ister. Hiç ürün merkezi yoksa boş.
function Contracts.offers(save: PlayerSave, now: number, bonus: number?): { Offer }
	local available = Contracts.availableGoods(save)
	local offers: { Offer } = {}
	if #available == 0 then
		return offers
	end
	local window = Contracts.window(now)
	local cap = Goods.getGoodsCap(save)
	for index, tier in Config.GOODS_CONTRACTS.tiers do
		local lines: { Line } = {}
		local start = (window * 3 + index * 2) % #available
		for step = 0, math.min(tier.lines, #available) - 1 do
			local goodsId = available[(start + step) % #available + 1]
			table.insert(lines, { goodsId = goodsId, amount = math.min(tier.units, cap) })
		end
		local worth = totalWorth(lines)
		table.insert(offers, {
			key = `{window}:{index}`,
			tier = tier.id,
			displayName = tier.displayName,
			lines = lines,
			worth = worth,
			rewardFactor = tier.rewardFactor,
			reward = Contracts.reward(worth, tier.rewardFactor, (bonus or 0) + Core.getBonus(save, "contractBonus")),
		})
	end
	return offers
end

-- Bu pencerede teslim edilmiş mi
function Contracts.isDone(save: PlayerSave, offer: Offer): boolean
	local contracts = save.contracts
	if not contracts then
		return false
	end
	local window = tonumber(string.match(offer.key, "^(%d+):"))
	return contracts.window == window and contracts.done[offer.key] == true
end

-- Depoda bütün satırlar için yeterli ürün var mı
function Contracts.canFulfill(save: PlayerSave, offer: Offer): boolean
	for _, line in offer.lines do
		if Goods.getGoodsAmount(save, line.goodsId) < line.amount then
			return false
		end
	end
	return true
end

-- Anahtarı doğrular; geçerliyse ilgili teklifi döner
function Contracts.resolve(save: PlayerSave, key: unknown, now: number, bonus: number?): (Offer?, string?)
	if typeof(key) ~= "string" or #key > 24 then
		return nil, "Geçersiz sipariş"
	end
	for _, offer in Contracts.offers(save, now, bonus) do
		if offer.key == key then
			return offer, nil
		end
	end
	return nil, "Teklifler yenilendi; panodan yeniden seç"
end

-- Teslim: ürünleri depodan düşer, teklifi bu pencere için teslim edilmiş işaretler. Ödülü döner (para eklemek çağıranın işidir).
-- Yetersiz ürün ya da zaten teslim edilmiş teklifte hiçbir şey değişmez; (nil, sebep) döner.
function Contracts.fulfill(save: PlayerSave, key: unknown, now: number, bonus: number?): (number?, string?)
	local offer, problem = Contracts.resolve(save, key, now, bonus)
	if not offer then
		return nil, problem
	end
	if Contracts.isDone(save, offer) then
		return nil, "Bu sipariş bu turda zaten teslim edildi"
	end
	if not Contracts.canFulfill(save, offer) then
		return nil, "Ahır deposunda yeterli ürün yok"
	end
	for _, line in offer.lines do
		assert(Goods.removeGoods(save, line.goodsId, line.amount), "goods vanished during a contract")
	end
	local window = Contracts.window(now)
	local contracts: GameTypes.ContractsRecord = save.contracts or { window = window, done = {}, completed = 0 }
	save.contracts = contracts
	if contracts.window ~= window then
		contracts.window = window
		contracts.done = {}
	end
	contracts.done[offer.key] = true
	contracts.completed = math.min(contracts.completed + 1, 1e9)
	return offer.reward, nil
end

-- Teslime hazır (henüz teslim edilmemiş ve depoda yeterli) teklif sayısı: menü rozeti ve hedef kartı için
function Contracts.readyCount(save: PlayerSave, now: number, bonus: number?): number
	local count = 0
	for _, offer in Contracts.offers(save, now, bonus) do
		if not Contracts.isDone(save, offer) and Contracts.canFulfill(save, offer) then
			count += 1
		end
	end
	return count
end

return Contracts
