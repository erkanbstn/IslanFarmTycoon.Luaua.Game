--!strict
-- Üretim kuralları Roblox nesnelerinden bağımsız; sunucu ve regresyon testleri kullanır.
local ProductionRules = {}

function ProductionRules.validRequestId(value: unknown): boolean
	return typeof(value) == "number" and value == value and value >= 1 and value <= 2147483647 and value % 1 == 0
end

-- Üretime verilebilecek boşta yetişkin sayısı (eklentide duranlar ve başka tesise verilmiş olanlar sayılmaz)
function ProductionRules.countAdults(save: any, recipe: any, farmMath: any, now: number): number
	return farmMath.countProductionAdults(save, recipe, now)
end

function ProductionRules.canStart(save: any, recipe: any, farmMath: any, now: number): (boolean, string?)
	if not save.purchased[recipe.upgradeId] or not save.unlockedIslands[recipe.island] then
		return false, "Önce bu üretim binasını açmalısın."
	end
	if save.production[recipe.id] then
		return false, "Önce mevcut üretimi teslim almalısın."
	end
	if recipe.output == "goods" and farmMath.getGoodsSpace(save, recipe.goodsId) < (recipe.goodsAmount or 0) then
		return false, "Ahır deposunda bu ürün için yeterli yer yok."
	end
	if ProductionRules.countAdults(save, recipe, farmMath, now) < recipe.requiredAdults then
		return false, `Bu üretim için boşta {recipe.requiredAdults} yetişkin hayvan gerekli.`
	end
	return true, nil
end

return ProductionRules
