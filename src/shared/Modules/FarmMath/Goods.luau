--!strict
-- Ahır deposu: ürün (süt, yumurta, yün...) miktarları. Ürün merkezleri depoya ekler; sipariş sistemi depodan tüketir.
-- FarmMath cephesi (init.luau) bunları birleştirir; her zaman `FarmMath.<ad>` ile kullan.

local Config = require(script.Parent.Parent.Parent:WaitForChild("Config"))
local GameTypes = require(script.Parent.Parent.Parent:WaitForChild("GameTypes"))
local Core = require(script.Parent:WaitForChild("Core"))

type PlayerSave = GameTypes.PlayerSave

local Goods = {}

-- Ahır deposu HESAP düzeyindedir (tüm çiftliklerde ortak). Her ürün türünden tutulabilecek en fazla miktar,
-- sahip olunan bütün çiftliklerin ahır limitlerinin TOPLAMIDIR (bir ahırı yükseltmek toplamı büyütür).
-- save: kök kayıt (mainFarms içerir); etkin çiftliğin seviyesi save.barnLevel'dan, diğerleri kayıtlarından okunur.
-- mainFarms yoksa (tek çiftlikli yalın kayıt) yalnızca kendi ahırı sayılır.
function Goods.getGoodsCap(save: PlayerSave): number
	local farms = (save :: any).mainFarms
	if not farms then
		return Core.getBarnConfig(save).goodsCap
	end
	local liveId = (save :: any).farmId or save.activeMainFarmId
	local total = 0
	for id, farm in farms do
		local level = if id == liveId then save.barnLevel else farm.barnLevel
		local barn = Config.getBarnLevelConfig(level) or Config.BARN_LEVELS[1]
		total += barn.goodsCap
	end
	return math.max(total, Core.getBarnConfig(save).goodsCap)
end

-- Sahip olunan her çiftlik için visit(çiftlik) çağırır: etkin çiftlik için kök kayıt, diğerleri için kayıtları.
-- mainFarms yoksa yalnızca kendisi.
function Goods.forEachFarm(save: PlayerSave, visit: (farm: any) -> ())
	local farms = (save :: any).mainFarms
	if not farms then
		visit(save)
		return
	end
	local liveId = (save :: any).farmId or save.activeMainFarmId
	for id, farm in farms do
		visit(if id == liveId then save else farm)
	end
end

function Goods.getGoodsAmount(save: PlayerSave, goodId: string): number
	local goods = save.goods
	local amount = if goods then goods[goodId] else nil
	return if typeof(amount) == "number" then amount else 0
end

function Goods.getGoodsSpace(save: PlayerSave, goodId: string): number
	return math.max(0, Goods.getGoodsCap(save) - Goods.getGoodsAmount(save, goodId))
end

-- Depoya ekler; sığmayan kısım eklenmez. Gerçekten eklenen miktarı döner.
function Goods.addGoods(save: PlayerSave, goodId: string, amount: number): number
	if not Config.GOODS[goodId] or amount ~= amount or amount <= 0 then
		return 0
	end
	local added = math.min(math.floor(amount), Goods.getGoodsSpace(save, goodId))
	if added > 0 then
		local goods = save.goods or {}
		save.goods = goods
		goods[goodId] = Goods.getGoodsAmount(save, goodId) + added
	end
	return added
end

-- Depodan düşer; yeterli yoksa hiçbir şey değişmez ve false döner.
function Goods.removeGoods(save: PlayerSave, goodId: string, amount: number): boolean
	if not Config.GOODS[goodId] or amount ~= amount or amount <= 0 or amount % 1 ~= 0 then
		return false
	end
	local current = Goods.getGoodsAmount(save, goodId)
	if current < amount then
		return false
	end
	local goods = save.goods or {}
	save.goods = goods
	goods[goodId] = if current - amount > 0 then current - amount else nil
	return true
end

-- Birden çok ürünü tek adımda düşer ({ [ürün] = adet }); herhangi biri yetmiyorsa hiçbir şey değişmez ve false döner.
function Goods.removeGoodsBundle(save: PlayerSave, bundle: { [string]: number }): boolean
	for goodId, amount in bundle do
		if not Config.GOODS[goodId] or amount ~= amount or amount < 0 or amount % 1 ~= 0 then
			return false
		end
		if Goods.getGoodsAmount(save, goodId) < amount then
			return false
		end
	end
	for goodId, amount in bundle do
		if amount > 0 then
			Goods.removeGoods(save, goodId, amount)
		end
	end
	return true
end

-- Depodaki bütün ürünlerin para değeri (gösterim ve sipariş ödülü tabanı)
function Goods.getGoodsWorth(save: PlayerSave): number
	local total = 0
	for goodId, good in Config.GOODS do
		total += Goods.getGoodsAmount(save, goodId) * good.value
	end
	return total
end

-- Kapasitenin GOODS_FULL_WARNING oranına ulaşmış ürünler (GOODS_ORDER sırasıyla): menü rozeti ve hedef kartı uyarısı için
function Goods.getFullGoods(save: PlayerSave): { string }
	local full: { string } = {}
	local limit = math.max(1, math.ceil(Goods.getGoodsCap(save) * Config.GOODS_FULL_WARNING))
	for _, goodId in Config.GOODS_ORDER do
		if Goods.getGoodsAmount(save, goodId) >= limit then
			table.insert(full, goodId)
		end
	end
	return full
end

-- Hızlı boşaltma ("Hepsini sat" / "Yarısını sat"): bir ürünün satılacak adedi ("all" = hepsi, "half" = yarısı, yukarı yuvarlanır;
-- tek birim kaldıysa o satılır). Geçersiz kip ya da ürün yoksa 0.
function Goods.getSellAmount(save: PlayerSave, goodId: string, mode: unknown): number
	if not Config.GOODS[goodId] then
		return 0
	end
	local current = Goods.getGoodsAmount(save, goodId)
	if mode == "all" then
		return current
	elseif mode == "half" then
		return math.ceil(current / 2)
	end
	return 0
end

-- Satış geliri: değer x GOODS_SELL.rate (sipariş ödülünün ve takasın üstüne çıkamaz; ürün başına tam sayı)
function Goods.getSellValue(goodId: string, amount: number): number
	local good = Config.GOODS[goodId]
	if not good or amount ~= amount or amount <= 0 then
		return 0
	end
	return math.floor(amount * good.value * Config.GOODS_SELL.rate)
end

-- Ürünü depodan düşer ve para karşılığını (çağıran ekler) döner: (nakit, satılan adet). Satacak ürün yoksa hiçbir şey değişmez; (nil, nil).
function Goods.sellGoods(save: PlayerSave, goodId: string, mode: unknown): (number?, number?)
	local amount = Goods.getSellAmount(save, goodId, mode)
	if amount <= 0 or not Goods.removeGoods(save, goodId, amount) then
		return nil, nil
	end
	return Goods.getSellValue(goodId, amount), amount
end

-- Depodaki ürünlerin takasta sayılan değeri (değer x GOODS_BARTER.rate)
function Goods.getBarterWorth(save: PlayerSave): number
	local total = 0
	for goodId, good in Config.GOODS do
		total += math.floor(Goods.getGoodsAmount(save, goodId) * good.value * Config.GOODS_BARTER.rate)
	end
	return total
end

-- Takas planı: `price` tutarını ürünlerle karşılar. En çok yığılmış (doluluğu en yüksek) ürünlerden başlar; her üründen en az birim alınır.
-- Döner: ({ [ürün] = adet }, sayılan değer) ya da değerler yetmiyorsa (nil, eldeki toplam). Plan uygulanmaz (uygula: Goods.applyBarter).
function Goods.planBarter(save: PlayerSave, price: number): ({ [string]: number }?, number)
	local rate = Config.GOODS_BARTER.rate
	local cap = math.max(Goods.getGoodsCap(save), 1)
	local order: { string } = {}
	for _, goodId in Config.GOODS_ORDER do
		if Goods.getGoodsAmount(save, goodId) > 0 then
			table.insert(order, goodId)
		end
	end
	table.sort(order, function(a: string, b: string): boolean
		local fillA, fillB = Goods.getGoodsAmount(save, a) / cap, Goods.getGoodsAmount(save, b) / cap
		if fillA ~= fillB then
			return fillA > fillB
		end
		return a < b
	end)
	local plan: { [string]: number } = {}
	local credited = 0
	for _, goodId in order do
		if credited >= price then
			break
		end
		local unit = math.floor(Config.GOODS[goodId].value * rate)
		if unit <= 0 then
			continue
		end
		local need = math.ceil((price - credited) / unit)
		local take = math.min(need, Goods.getGoodsAmount(save, goodId))
		plan[goodId] = take
		credited += take * unit
	end
	if credited < price then
		return nil, Goods.getBarterWorth(save)
	end
	return plan, credited
end

-- Planı uygular (hepsi ya da hiçbiri): ürünleri düşer; yetmezse hiçbir şey değişmez ve false döner.
function Goods.applyBarter(save: PlayerSave, plan: { [string]: number }): boolean
	for goodId, amount in plan do
		if Goods.getGoodsAmount(save, goodId) < amount then
			return false
		end
	end
	for goodId, amount in plan do
		assert(Goods.removeGoods(save, goodId, amount), "goods vanished during a barter")
	end
	return true
end

return Goods
