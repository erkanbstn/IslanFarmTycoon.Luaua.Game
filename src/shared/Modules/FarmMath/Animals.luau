--!strict
-- Hayvan pazarı: fiyat, satış, boş yuva, toplu alım, balık değiştirme ve bölge seçimi.
-- FarmMath cephesi (init.luau) bunları birleştirir; her zaman `FarmMath.<ad>` ile kullan.

local Config = require(script.Parent.Parent.Parent:WaitForChild("Config"))
local GameTypes = require(script.Parent.Parent.Parent:WaitForChild("GameTypes"))
local Core = require(script.Parent:WaitForChild("Core"))
local Counts = require(script.Parent:WaitForChild("Counts"))
local Expansion = require(script.Parent:WaitForChild("Expansion"))
local Pricing = require(script.Parent:WaitForChild("Pricing"))

type PlayerSave = GameTypes.PlayerSave

local Animals = {}

export type ZoneBlock = "full" | "locked"

function Animals.getAnimalPrice(save: PlayerSave, animalId: string): number
	return Pricing.getPrice(save, "animal", animalId)
end

-- Yeni alınan hayvanın doğum zamanı: çiftlikteki ilk STARTER_ADULT_ANIMALS hayvan yetişkin (bornAt = 0), sonrakiler yavru.
function Animals.getNewAnimalBornAt(save: PlayerSave, now: number): number
	if #save.animals < Config.STARTER_ADULT_ANIMALS then
		return 0
	end
	return now
end

-- Satış: son alınan hayvanın (sahip olunan - 1) fiyatının ANIMAL_SELL_FRACTION'ı geri gelir
function Animals.getSellPrice(save: PlayerSave, animalId: string): number
	local owned = Counts.countAnimals(save, animalId)
	if not Config.ANIMALS[animalId] or owned <= 0 then
		return 0
	end
	local bonus = 1 + Core.getBonus(save, "sellBonus")
	return math.floor(Pricing.getPrice(save, "animal", animalId, owned - 1) * Config.ANIMAL_SELL_FRACTION * bonus)
end

-- Satılacak hayvan: aynı türün en genci. Görevdeki (tesise verilmiş ya da eklentide duran) hayvan satılmaz.
-- Çiftlikte tek hayvan kalıyorsa satılmaz (gelirsiz kilitlenmeyi önler). Dönen değer kayıttaki kayıttır.
function Animals.findSellableAnimal(save: PlayerSave, animalId: string, now: number?): GameTypes.AnimalRecord?
	if #save.animals <= 1 then
		return nil
	end
	local best: GameTypes.AnimalRecord? = nil
	local bestKey = math.huge
	for _, animal in save.animals do
		if animal.animalId == animalId and Counts.getActiveTask(animal, now) == nil then
			-- En genç (en büyük bornAt) önce; bornAt 0 = başlangıç hayvanı en sona
			local key = -animal.bornAt
			if key < bestKey or best == nil then
				best, bestKey = animal, key
			end
		end
	end
	return best
end

-- Bu türün konabileceği açık bölgelerdeki toplam boş yer
function Animals.getFreeSlots(save: PlayerSave, animalId: string): number
	local free = 0
	for _, zoneId in Config.ZONE_ORDER do
		local zone = Config.ZONES[zoneId]
		if zone and Counts.zoneAllows(save, zone, animalId) and save.unlockedZones[zoneId] then
			free += math.max(0, Expansion.getZoneCapacity(save, zoneId) - Counts.countInZone(save, zoneId))
		end
	end
	return free
end

-- Ardışık `count` hayvanın toplam fiyatı: her yeni hayvan bir öncekinden n. alım eğrisi kadar pahalıdır (Pricing.getAnimalGrowth).
function Animals.getBulkPrice(save: PlayerSave, animalId: string, count: number): number
	if not Config.ANIMALS[animalId] or count < 1 then
		return math.huge
	end
	local owned = Counts.countAnimals(save, animalId)
	local total = 0
	for index = 0, count - 1 do
		total += Pricing.getPrice(save, "animal", animalId, owned + index)
	end
	return total
end

function Animals.findReplaceableFish(save: PlayerSave): GameTypes.AnimalRecord?
	for _, animal in save.animals do
		local zone = Config.ZONES[animal.zoneId]
		if
			animal.animalId == "anchovy"
			and save.unlockedZones[animal.zoneId]
			and zone
			and table.find(zone.allowedAnimals, "seabass")
		then
			return animal
		end
	end
	return nil
end

function Animals.getFishReplacementPrice(save: PlayerSave): number
	local price = Animals.getAnimalPrice(save, "seabass")
	-- Yükselen mevcut hamsi fiyatını iade etme: al-sat döngüsü kâr üretememeli.
	local refund = math.floor(Pricing.getPrice(save, "animal", "anchovy", 0) * Config.FISH_REPLACEMENT_REFUND_RATE)
	return math.max(0, price - math.min(price, refund))
end

-- Bu hayvan türü için en az bir bölge açık mı? (ada seçimi shop'u gizlemesin)
function Animals.hasUnlockedAnimalZone(save: PlayerSave, animalId: string): boolean
	for _, zoneId in Config.ZONE_ORDER do
		local zone = Config.ZONES[zoneId]
		if zone and Counts.zoneAllows(save, zone, animalId) and save.unlockedZones[zoneId] then
			return true
		end
	end
	return false
end

-- Hayvanın konabileceği ilk açık ve boş alanı döner; yoksa (nil, sebep metni, engel türü)
function Animals.findZoneForAnimal(save: PlayerSave, animalId: string): (string?, string?, ZoneBlock?)
	local anyUnlocked = false
	local lockedBy: string? = nil

	for _, zoneId in Config.ZONE_ORDER do
		local zone = Config.ZONES[zoneId]
		if not zone or not Counts.zoneAllows(save, zone, animalId) then
			continue
		end
		if save.unlockedZones[zoneId] then
			anyUnlocked = true
			if Counts.countInZone(save, zoneId) < Expansion.getZoneCapacity(save, zoneId) then
				return zoneId, nil
			end
		elseif lockedBy == nil then
			local island = Config.FARM_ISLANDS[zone.island]
			local upgrade = Config.getZoneUpgrade(zoneId)
			if not save.unlockedIslands[zone.island] and island then
				lockedBy = island.displayName
			else
				lockedBy = if upgrade then upgrade.displayName else zone.displayName
			end
		end
	end

	if anyUnlocked and lockedBy then
		return nil, `Yer dolu · Daha fazlası için: {lockedBy}`, "full"
	elseif anyUnlocked then
		return nil, "Tüm yerler dolu", "full"
	elseif lockedBy then
		return nil, `Önce açılmalı: {lockedBy}`, "locked"
	end
	return nil, "Uygun alan yok", "locked"
end

return Animals
