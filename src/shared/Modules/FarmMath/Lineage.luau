--!strict
-- Irk geliştirme seviyesi, maliyeti ve durumu.
-- FarmMath cephesi (init.luau) bunları birleştirir; her zaman `FarmMath.<ad>` ile kullan.

local Config = require(script.Parent.Parent.Parent:WaitForChild("Config"))
local GameTypes = require(script.Parent.Parent.Parent:WaitForChild("GameTypes"))
local Core = require(script.Parent:WaitForChild("Core"))

type PlayerSave = GameTypes.PlayerSave
local isFinite = Core.isFinite

local Lineage = {}

export type LineageStatus = "available" | "locked" | "max"

-- Irk geliştirme seviyesi (0..maxLevel); kayıt alanı yoksa 0
function Lineage.getLineageLevel(save: PlayerSave, animalId: string): number
	local lineage = save.lineage
	local level = if lineage then lineage[animalId] else nil
	if typeof(level) ~= "number" or not isFinite(level) then
		return 0
	end
	return math.clamp(math.floor(level), 0, Config.LINEAGE.maxLevel)
end

-- `level` -> `level + 1` maliyeti; en üst seviyede math.huge
function Lineage.getLineageCost(animalId: string, level: number): number
	local animalConfig = Config.ANIMALS[animalId]
	local lineage = Config.LINEAGE
	if not animalConfig or level < 0 or level >= lineage.maxLevel then
		return math.huge
	end
	local raw = animalConfig.price * lineage.costMultiplier * lineage.costGrowth ^ level
	local step = 10 ^ (math.floor(math.log10(raw)) - 1)
	return math.floor(raw / step + 0.5) * step
end

-- Irk geliştirme durumu: en az bir yetişkin hayvan gerekir. Üçüncü değer: sonraki seviye maliyeti.
function Lineage.getLineageStatus(save: PlayerSave, animalId: string): (LineageStatus, string?, number)
	local level = Lineage.getLineageLevel(save, animalId)
	if not Config.ANIMALS[animalId] then
		return "locked", "Bilinmeyen hayvan", math.huge
	end
	if level >= Config.LINEAGE.maxLevel then
		return "max", nil, math.huge
	end
	for _, animal in save.animals do
		if animal.animalId == animalId and animal.stage == "adult" then
			return "available", nil, Lineage.getLineageCost(animalId, level)
		end
	end
	return "locked", "Önce yetişkin bir hayvan gerekir", Lineage.getLineageCost(animalId, level)
end

return Lineage
