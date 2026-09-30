--!strict
-- Sayım ve bölge izni yardımcıları (bölge, eklenti, hayvan sayıları).
-- FarmMath cephesi (init.luau) bunları birleştirir; her zaman `FarmMath.<ad>` ile kullan.

local Config = require(script.Parent.Parent.Parent:WaitForChild("Config"))
local GameTypes = require(script.Parent.Parent.Parent:WaitForChild("GameTypes"))

type PlayerSave = GameTypes.PlayerSave

local Counts = {}

function Counts.countInZone(save: PlayerSave, zoneId: string): number
	local count = 0
	for _, animal in save.animals do
		if animal.zoneId == zoneId and (animal.extensionId == nil or animal.extensionId == "") then
			count += 1
		end
	end
	return count
end

function Counts.countInExtension(save: PlayerSave, extensionId: string): number
	local count = 0
	for _, animal in save.animals do
		if animal.extensionId == extensionId then
			count += 1
		end
	end
	return count
end

function Counts.countAnimals(save: PlayerSave, animalId: string): number
	local count = 0
	for _, animal in save.animals do
		if animal.animalId == animalId then
			count += 1
		end
	end
	return count
end

-- Bölge bu çiftlikte bu hayvanı kabul ediyor mu? (ana ada bölgeleri temaya göre değişir)
function Counts.zoneAllows(save: PlayerSave, zone: Config.ZoneConfig, animalId: string): boolean
	return Config.zoneAllows(zone, animalId, save.farmId or save.activeMainFarmId)
end

return Counts
