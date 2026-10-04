--!strict
-- Aynı hayvanları kullanan ürün/para tesisleri dünya etkileşiminde birlikte görünür.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local ProductionContext = {}

function ProductionContext.isRelated(
	recipe: Config.ProductionRecipeConfig,
	focused: Config.ProductionRecipeConfig
): boolean
	if recipe.island ~= focused.island then
		return false
	end
	if recipe.upgradeId == focused.upgradeId then
		return true
	end
	for _, animalId in recipe.animalIds do
		if table.find(focused.animalIds, animalId) then
			return true
		end
	end
	return false
end

return ProductionContext
