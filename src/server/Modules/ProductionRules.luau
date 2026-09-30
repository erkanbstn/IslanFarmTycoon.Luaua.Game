--!strict
-- Üretim kuralları Roblox nesnelerinden bağımsız; sunucu ve regresyon testleri kullanır.
local ProductionRules = {}

function ProductionRules.validRequestId(value: unknown): boolean
	return typeof(value) == "number" and value == value and value >= 1 and value <= 2147483647 and value % 1 == 0
end

function ProductionRules.countAdults(save: any, recipe: any, farmMath: any, now: number): number
	local count = 0
	for _, animal in save.animals do
		if
			save.unlockedZones[animal.zoneId]
			and table.find(recipe.animalIds, animal.animalId)
			and farmMath.getStage(animal.bornAt, now, farmMath.getGrowthSpeed(save, animal.animalId, animal.zoneId))
				== "adult"
		then
			count += 1
		end
	end
	return count
end

function ProductionRules.canStart(save: any, recipe: any, farmMath: any, now: number): (boolean, string?)
	if not save.purchased[recipe.upgradeId] or not save.unlockedIslands[recipe.island] then
		return false, "Önce bu üretim binasını açmalısın."
	end
	if save.production[recipe.id] then
		return false, "Önce mevcut üretimi teslim almalısın."
	end
	if ProductionRules.countAdults(save, recipe, farmMath, now) < recipe.requiredAdults then
		return false, `Bu üretim için {recipe.requiredAdults} yetişkin hayvan gerekli.`
	end
	return true, nil
end

return ProductionRules
