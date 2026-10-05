--!strict
-- Ahır siparişleri (depo sözleşmeleri): ahır deposundaki ürünleri para karşılığı teslim eden, zamanla yenilenen panodaki teklifler.
-- Teklifler kayıttan ve sunucu saatinden türetilir (sunucu anahtarı yeniden hesaplayıp doğrular, client yalnızca çizer).
-- FarmMath cephesi (init.luau) bunları birleştirir; her zaman `FarmMath.<ad>` ile kullan.

local Config = require(script.Parent.Parent.Parent:WaitForChild("Config"))
local GameTypes = require(script.Parent.Parent.Parent:WaitForChild("GameTypes"))
local Core = require(script.Parent:WaitForChild("Core"))
local Goods = require(script.Parent:WaitForChild("Goods"))
local Income = require(script.Parent:WaitForChild("Income"))
local Production = require(script.Parent:WaitForChild("Production"))

type PlayerSave = GameTypes.PlayerSave

local Contracts = {}

export type Line = { goodsId: string, amount: number }
export type Offer = {
	key: string, -- "<pencere>:<sıra>:<teklif özeti>"
	tier: string,
	displayName: string,
	lines: { Line },
	worth: number, -- satırların ürün değerleri toplamı
	rewardFactor: number,
	reward: number,
	uncappedReward: number,
}

function Contracts.window(now: number): number
	return math.floor(now / Config.GOODS_CONTRACTS.seconds)
end

-- Kaç saniye sonra yenilenir
function Contracts.secondsLeft(now: number): number
	return Config.GOODS_CONTRACTS.seconds - now % Config.GOODS_CONTRACTS.seconds
end

-- Tavan ölçüsü park edilmiş en iyi çiftliği ve görev nedeniyle geçici kesilmeyen yetişkin potansiyelini kapsar.
function Contracts.referenceIncome(save: PlayerSave, now: number): number
	return math.max(Income.getReferenceIncome(save, now), Income.getPermanentIncomePerSecond(save))
end

-- Panoya yalnızca oyuncunun ŞU AN üretebildiği ürünler gelir (GOODS_ORDER sırasıyla): etkin çiftlikte o ürünün merkezi kurulu, adası açık,
-- tarif çiftliğin temasında ve merkezin gerektirdiği kadar o türden hayvan açık bölgede var. Açılmamış ada, kurulmamış merkez, başka temanın
-- ürünü ya da elle üretilemeyen (park edilmiş çiftlik) ürün sipariş edilmez.
function Contracts.availableGoods(save: PlayerSave, now: number?): { string }
	local farmId = (save :: any).farmId or save.activeMainFarmId
	local built: { [string]: boolean } = {}
	for _, recipe in Config.PRODUCTION_RECIPES do
		if
			recipe.output ~= "goods"
			or not recipe.goodsId
			or not save.purchased[recipe.upgradeId]
			or not save.unlockedIslands[recipe.island]
		then
			continue
		end
		local upgrade = Config.getUpgrade(recipe.upgradeId)
		if upgrade and not Config.upgradeInTheme(upgrade, farmId) then
			continue
		end
		local keepers = 0
		for _, animal in save.animals do
			if
				table.find(recipe.animalIds, animal.animalId)
				and save.unlockedZones[animal.zoneId]
				and Core.getStage(
						animal.bornAt,
						now or os.time(),
						Production.getGrowthSpeed(save, animal.animalId, animal.zoneId, now)
					)
					== "adult"
			then
				keepers += 1
			end
		end
		if keepers >= recipe.requiredAdults then
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

-- Bir satırın birim sayısı (rastgelelik dışı taban): kademe değeri; pahalı üründe `unitRefValue / değer` ile küçülür (satır değeri ürünler arasında
-- benzer kalır), en az 1. Depo büyüklüğüne ve gelire bağlı değildir (sayılar küçük kalır).
function Contracts.baseUnits(tier: any, goodsId: string): number
	local settings = Config.GOODS_CONTRACTS
	local scale = math.min(1, settings.unitRefValue / Config.GOODS[goodsId].value)
	return math.clamp(math.floor(tier.units * scale + 0.5), 1, settings.maxLineUnits)
end

-- Teklifin ödülü: ürünlerin para değeri x kademe çarpanı (rewardFactor, 1-2) x (1 + sipariş bonusu). Ödül ürünün değerine bağlıdır, oyuncunun
-- anlık gelirine DEĞİL: ürün değeri (Config/Goods.luau) zaten ürün merkezinin asgari getirisine göre ölçülüdür, ödül/değer oranı kademe
-- çarpanı kadardır (tests/economy.spec ve scripts/audit-economy.py bunu korur).
function Contracts.reward(worth: number, rewardFactor: number, bonus: number?): number
	return math.floor(worth * rewardFactor * (1 + (bonus or 0)))
end

-- Toplam sipariş bonusu (eşya + ada + yükseltme + kalıcı etki + kilometre taşı + mevsim) tavanla sınırlanır: en yüksek kademe de
-- ECONOMY_LIMITS.maxRewardRatio'yu bonuslar dahil aşamaz.
function Contracts.totalBonus(save: PlayerSave, bonus: number?): number
	return math.clamp((bonus or 0) + Core.getBonus(save, "contractBonus"), 0, Config.GOODS_CONTRACTS.maxBonus)
end

-- Pano ödeme bütçesi (referans gelirin dakikası; başlangıç payında sınırsız): referans gelir arttıkça (evre ilerledikçe) büyür, bkz. Config/Goods.luau `windowBudget`.
function Contracts.budgetMinutes(referencePerSecond: number): number
	local budget = Config.GOODS_CONTRACTS.windowBudget
	-- Başlangıç payı: referans gelir graceIncome'un altındayken bütçe yoktur (ilk saatin ilk yarısı; erken ilerleme siparişlerle hızlanır).
	if referencePerSecond < budget.graceIncome then
		return math.huge
	end
	if referencePerSecond <= budget.lowIncome then
		return budget.lowMinutes
	end
	local phase = math.clamp(
		math.log(referencePerSecond / budget.lowIncome) / math.log(budget.highIncome / budget.lowIncome),
		0,
		1
	)
	return budget.lowMinutes + (budget.highMinutes - budget.lowMinutes) * phase ^ budget.curve
end

-- Panodaki teklif sayısı: üretilebilir ürün sayısıyla orantılı (en az minSlots, en çok slots). Az üründe talep tek ürüne yığılmaz.
function Contracts.slotCount(goodsCount: number): number
	local settings = Config.GOODS_CONTRACTS
	if goodsCount <= 0 then
		return 0
	end
	return math.clamp(
		math.ceil(goodsCount * settings.slotsPerGoods),
		math.min(settings.minSlots, settings.slots),
		settings.slots
	)
end

-- Park-Miller üreteci: pencere ve sıraya bağlı, sunucu ile client'ta aynı sonucu verir (Roblox Random gerekmez).
local function newGenerator(seed: number): () -> number
	local state = seed % 2147483646 + 1
	return function(): number
		state = state * 16807 % 2147483647
		return state / 2147483647
	end
end

-- En çok adet istenen satırdan bir birim düşer; düşecek (adedi 1'den büyük) satır yoksa false.
local function shrinkLargest(lines: { Line }): boolean
	local target: Line? = nil
	for _, line in lines do
		if
			line.amount > 1
			and (
				target == nil
				or line.amount * Config.GOODS[line.goodsId].value
					> target.amount * Config.GOODS[target.goodsId].value
			)
		then
			target = line
		end
	end
	if not target then
		return false
	end
	target.amount -= 1
	return true
end

-- O anki pencerenin teklifleri: `slots` kadar (ızgara). Her sıra ağırlıklı rastgele bir kademe seçer, kademenin satır sayısı kadar
-- farklı ürünü rastgele sıralar ve birim sayısını ± variation oranında oynatır. Hiç ürün merkezi yoksa boş.
function Contracts.offers(save: PlayerSave, now: number, bonus: number?): { Offer }
	local available = Contracts.availableGoods(save, now)
	local offers: { Offer } = {}
	if #available == 0 then
		return offers
	end
	local settings = Config.GOODS_CONTRACTS
	local window = Contracts.window(now)
	local cap = Goods.getGoodsCap(save)
	-- Göreve verilen hayvan gelirinin geçici kesilmesi panoyu sıfırlamasın: nötr yetişkin potansiyeli alt referanstır.
	-- Tek sipariş ödülü bu referansın birkaç dakikasını aşamaz; tek pahalı birim de sınıra dahildir.
	local rewardCap = Contracts.referenceIncome(save, now) * 60 * Config.GOODS_CONTRACTS.rewardCapMinutes
	-- Gelir her saniye oynar; tavan %25'lik basamaklara yuvarlanır ki panodaki adetler (ve sunucunun teslimde yeniden hesapladığı adetler) titremesin.
	if rewardCap >= 1 then
		rewardCap = 1.25 ^ math.floor(math.log(rewardCap, 1.25))
	end
	-- Pano bütçesi aynı %25'lik basamaklı referanstan türer (teslimde sunucunun yeniden hesapladığı pano titremesin).
	local budget = rewardCap
		/ settings.rewardCapMinutes
		* Contracts.budgetMinutes(rewardCap / settings.rewardCapMinutes / 60)
	local rewardBonus = Contracts.totalBonus(save, bonus)
	local totalWeight = 0
	for _, tier in settings.tiers do
		totalWeight += tier.weight
	end
	local slotCount = Contracts.slotCount(#available)
	for slot = 1, slotCount do
		local random = newGenerator(window * 7919 + slot * 104729 + 12345)
		random()
		local roll = random() * totalWeight
		local tier = settings.tiers[#settings.tiers]
		for _, candidate in settings.tiers do
			roll -= candidate.weight
			if roll <= 0 then
				tier = candidate
				break
			end
		end
		-- Her açık ürünün panoda yeri vardır; yüksek karma primi ancak o çeşitlilik gerçekten istenirse verilir.
		if slot <= #available then
			for _, candidate in settings.tiers do
				if candidate.id == settings.guaranteedTier then
					tier = candidate
					break
				end
			end
		else
			while tier.lines > #available do
				local index = table.find(settings.tiers, tier) or 1
				tier = settings.tiers[math.max(1, index - 1)]
			end
		end
		-- Ürünleri karıştır (Fisher-Yates), ilk `lines` tanesini al
		local pool = table.clone(available)
		for index = #pool, 2, -1 do
			local pick = math.floor(random() * index) + 1
			pool[index], pool[pick] = pool[pick], pool[index]
		end
		if slot <= #available then
			pool[1] = available[slot]
		end
		local lines: { Line } = {}
		for step = 1, math.min(tier.lines, #pool) do
			-- Miktar [alt, üst] aralığında rastgele bir tam sayıdır (1'den kademe tabanının üst sınırına; üst sınır eskisiyle aynı, ödül/gelir değişmezleri korunur. Pahalı üründe taban zaten 1'dir: değer, gelire göre ölçülü).
			-- Ödül ürün değeriyle orantılı kaldığından birim başına getiri değişmez; yalnızca istenen adet çeşitlenir.
			local base = Contracts.baseUnits(tier, pool[step])
			local low = math.max(1, math.floor(base * (1 - settings.variation)))
			local high = math.max(low, math.floor(base * (1 + settings.variation) + 0.5), settings.minHighUnits)
			local amount = low + math.floor(random() * (high - low + 1))
			table.insert(lines, {
				goodsId = pool[step],
				amount = math.clamp(amount, 1, math.min(math.max(cap, 1), settings.maxLineUnits)),
			})
		end
		-- Önce ödül tavanına sığmak için en büyük satır küçültülür; tek birim bile pahalıysa son ödeme ayrıca sınırlanır.
		-- Pahalı ürün bu yüzden erken oyunda 1 adet, gelir büyüdükçe 2-3 adet istenir.
		local shrinking = true
		while shrinking and Contracts.reward(totalWorth(lines), tier.rewardFactor, rewardBonus) > rewardCap do
			shrinking = shrinkLargest(lines)
		end
		local worth = totalWorth(lines)
		local uncappedReward = Contracts.reward(worth, tier.rewardFactor, rewardBonus)
		local reward = math.min(uncappedReward, math.max(0, math.floor(rewardCap)))
		-- Aynı slot yeni ürün/ödülle değişirse eski seçim farklı ürünleri tüketemez.
		local fingerprint = reward % 1000003
		for _, line in lines do
			for index = 1, #line.goodsId do
				fingerprint = (fingerprint * 31 + string.byte(line.goodsId, index)) % 1000003
			end
			fingerprint = (fingerprint * 31 + line.amount) % 1000003
		end
		table.insert(offers, {
			key = `{window}:{slot}:{fingerprint}`,
			tier = tier.id,
			displayName = tier.displayName,
			lines = lines,
			worth = worth,
			rewardFactor = tier.rewardFactor,
			reward = reward,
			uncappedReward = uncappedReward,
		})
	end
	-- Pano bütçesi: slot sırasıyla, ödül toplamı bütçeyi aşmayan teklifler kalır (ilk teklif her zaman); sığmayan sonraki daha ucuz bir teklife yer bırakır.
	local kept: { Offer } = {}
	local spent = 0
	for _, offer in offers do
		if #kept == 0 or spent + offer.reward <= budget then
			table.insert(kept, offer)
			spent += offer.reward
		end
	end
	return kept
end

-- Bu pencerede teslim edilmiş mi
function Contracts.isDone(save: PlayerSave, offer: Offer): boolean
	local contracts = save.contracts
	if not contracts then
		return false
	end
	local window = tonumber(string.match(offer.key, "^(%d+):"))
	if contracts.window ~= window then
		return false
	end
	local slotKey = string.match(offer.key, "^(%d+:%d+)")
	for key, done in contracts.done do
		if done and string.match(key, "^(%d+:%d+)") == slotKey then
			return true
		end
	end
	return false
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

-- Varsayılan sipariş stoğu; isteğe bağlı depo modu ortak kapasiteyi hedefler.
function Contracts.productionTarget(
	save: PlayerSave,
	goodsId: string,
	batchUnits: number,
	now: number,
	goodsHolder: PlayerSave?,
	fillToCapacity: boolean?
): number
	if fillToCapacity then
		return Goods.getGoodsCap(goodsHolder or save)
	end
	local demand = 0
	for _, offer in Contracts.offers(save, now) do
		if not Contracts.isDone(save, offer) then
			for _, line in offer.lines do
				if line.goodsId == goodsId then
					demand += line.amount
				end
			end
		end
	end
	return math.min(Goods.getGoodsCap(goodsHolder or save), demand + batchUnits * Config.GOODS_CONTRACTS.reserveBatches)
end

return Contracts
