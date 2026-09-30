--!strict
-- Sayım ve bölge izni yardımcıları (bölge, eklenti, hayvan sayıları).
-- FarmMath cephesi (init.luau) bunları birleştirir; her zaman `FarmMath.<ad>` ile kullan.

local Config = require(script.Parent.Parent.Parent:WaitForChild("Config"))
local GameTypes = require(script.Parent.Parent.Parent:WaitForChild("GameTypes"))

type PlayerSave = GameTypes.PlayerSave
type AnimalRecord = GameTypes.AnimalRecord
type AnimalTask = GameTypes.AnimalTask

local Counts = {}

-- Hayvanın süresi dolmamış görevi (üretim ya da eklenti); yoksa nil. now verilmezse saat kullanılır.
function Counts.getActiveTask(animal: AnimalRecord, now: number?): AnimalTask?
	local task = animal.task
	if task and (now or os.time()) < task.endsAt then
		return task
	end
	return nil
end

-- Hayvan şu an üretim tesisinde mi? (yerinde değildir, gelir getirmez)
function Counts.isInProduction(animal: AnimalRecord, now: number?): boolean
	local task = Counts.getActiveTask(animal, now)
	return task ~= nil and task.kind == "production"
end

-- Bölge sayımı: eklentide ya da tesiste olan hayvanın yeri ana bölgede ayrılı kalır (dönünce yer bulunur).
function Counts.countInZone(save: PlayerSave, zoneId: string): number
	local count = 0
	for _, animal in save.animals do
		if animal.zoneId == zoneId then
			count += 1
		end
	end
	return count
end

-- Eklentide şu an duran (süresi dolmamış) hayvan sayısı
function Counts.countInExtension(save: PlayerSave, extensionId: string, now: number?): number
	local count = 0
	for _, animal in save.animals do
		local task = Counts.getActiveTask(animal, now)
		if task and task.kind == "extension" and task.id == extensionId then
			count += 1
		end
	end
	return count
end

-- Eklentinin aynı anda alabileceği hayvan: taban + satın alınan kapasite yükseltmeleri
function Counts.getExtensionCapacity(save: PlayerSave, extensionId: string): number
	local extension = Config.getExtension(extensionId)
	if not extension then
		return 0
	end
	local capacity = extension.capacity
	local upgradeIds: { string } = Config.EXTENSION_CAPACITY_UPGRADES[extensionId] or {}
	for _, upgradeId in upgradeIds do
		if save.purchased[upgradeId] then
			local upgrade = Config.getUpgrade(upgradeId)
			capacity += if upgrade then upgrade.extensionCapacity or 0 else 0
		end
	end
	return capacity
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
