--!strict
-- Ahır deposu: ürün (süt, yumurta, yün...) miktarları. Ürün merkezleri depoya ekler; sipariş sistemi depodan tüketir.
-- FarmMath cephesi (init.luau) bunları birleştirir; her zaman `FarmMath.<ad>` ile kullan.

local Config = require(script.Parent.Parent.Parent:WaitForChild("Config"))
local GameTypes = require(script.Parent.Parent.Parent:WaitForChild("GameTypes"))
local Core = require(script.Parent:WaitForChild("Core"))

type PlayerSave = GameTypes.PlayerSave

local Goods = {}

-- Her ürün türünden depoda tutulabilecek en fazla miktar (ahır seviyesine göre)
function Goods.getGoodsCap(save: PlayerSave): number
	return Core.getBarnConfig(save).goodsCap
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

-- Depodaki bütün ürünlerin para değeri (gösterim ve sipariş ödülü tabanı)
function Goods.getGoodsWorth(save: PlayerSave): number
	local total = 0
	for goodId, good in Config.GOODS do
		total += Goods.getGoodsAmount(save, goodId) * good.value
	end
	return total
end

return Goods
