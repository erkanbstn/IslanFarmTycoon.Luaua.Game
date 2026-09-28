--!strict
-- Sunucu ve client'ın aynı sonucu hesaplaması için ortak oyun hesapları.
-- Sunucu bunları KARAR için, client sadece GÖSTERİM için kullanır.

local Config = require(script.Parent.Parent:WaitForChild("Config"))
local GameTypes = require(script.Parent.Parent:WaitForChild("GameTypes"))
local Environment = require(script.Parent:WaitForChild("Environment"))

type PlayerSave = GameTypes.PlayerSave
type AnimalStage = GameTypes.AnimalStage

local FarmMath = {}

local function isFinite(value: number): boolean
	return value == value and value > -math.huge and value < math.huge
end

-- purchased'dan barnLevel, açık adaları ve açık bölgeleri yeniden hesaplar (tek doğruluk kaynağı: purchased).
-- Bir bölge açıktır: adası açıksa VE (bölgeyi açan bir yol haritası öğesi yoksa ya da alınmışsa).
function FarmMath.applyDerived(save: PlayerSave)
	local level = 1
	local islands: { [string]: boolean } = { home = true }
	for _, upgrade in Config.UPGRADES do
		if not save.purchased[upgrade.id] then
			continue
		end
		if upgrade.kind == "barn" and upgrade.barnLevel then
			level = math.max(level, upgrade.barnLevel)
		elseif upgrade.kind == "island" and upgrade.islandId then
			islands[upgrade.islandId] = true
		end
	end

	local zones: { [string]: boolean } = {}
	for zoneId, zone in Config.ZONES do
		if not islands[zone.island] then
			continue
		end
		local zoneUpgrade = Config.getZoneUpgrade(zoneId)
		if zoneUpgrade == nil or save.purchased[zoneUpgrade.id] then
			zones[zoneId] = true
		end
	end

	save.barnLevel = level
	save.unlockedIslands = islands
	save.unlockedZones = zones
end

-- Bir hayvan türünün büyüme hızı: genel güçlendirmeler (silo) x o türe özel (ör. Tavuk Adası)
function FarmMath.getGrowthSpeed(save: PlayerSave, animalId: string): number
	local speed = 1
	for _, upgrade in Config.UPGRADES do
		if not save.purchased[upgrade.id] then
			continue
		end
		if upgrade.growthSpeed then
			speed *= upgrade.growthSpeed
		end
		local perAnimal = upgrade.growthBoost
		if perAnimal and perAnimal[animalId] then
			speed *= perAnimal[animalId]
		end
	end
	return speed
end

function FarmMath.hasAutoCollect(save: PlayerSave): boolean
	for _, upgrade in Config.UPGRADES do
		if upgrade.autoCollect and save.purchased[upgrade.id] then
			return true
		end
	end
	return false
end

function FarmMath.getStage(bornAt: number, now: number, growthSpeed: number): AnimalStage
	if bornAt == 0 then
		return "adult"
	end
	local age = (now - bornAt) * growthSpeed
	if age < Config.GROWTH_SECONDS.calf then
		return "calf"
	elseif age < Config.GROWTH_SECONDS.calf + Config.GROWTH_SECONDS.young then
		return "young"
	end
	return "adult"
end

function FarmMath.getBarnConfig(save: PlayerSave): Config.BarnLevelConfig
	return Config.getBarnLevelConfig(save.barnLevel) or Config.BARN_LEVELS[1]
end

function FarmMath.getStorageCap(save: PlayerSave): number
	local bonus = 0
	for _, upgrade in Config.UPGRADES do
		if upgrade.storageBonus and save.purchased[upgrade.id] then
			bonus += upgrade.storageBonus
		end
	end
	return math.floor(FarmMath.getBarnConfig(save).storageCap * (1 + bonus))
end

-- Bir hayvan türünün toplam çarpanı (ahır seviyesi x güçlendirmeler)
function FarmMath.getAnimalMultiplier(save: PlayerSave, animalId: string, neutralWeather: boolean?): number
	local bonus = 0
	for _, upgrade in Config.UPGRADES do
		local boost = upgrade.incomeBoost
		if boost and boost[animalId] and save.purchased[upgrade.id] then
			bonus += boost[animalId]
		end
	end
	-- Ahır seviyesi x güçlendirmeler x mevsim/hava
	local environment = if neutralWeather then 1 else Environment.getIncomeMultiplier(animalId)
	return FarmMath.getBarnConfig(save).incomeMultiplier * (1 + bonus) * environment
end

-- Yetişkin bir hayvanın şu anki saniyelik geliri
function FarmMath.getAnimalIncome(save: PlayerSave, animalId: string, animal: GameTypes.AnimalRecord?): number
	local animalConfig = Config.ANIMALS[animalId]
	if not animalConfig then
		return 0
	end
	local income = animalConfig.baseIncomePerSecond * FarmMath.getAnimalMultiplier(save, animalId)
	if animal and animal.extensionId then
		local extension = Config.getExtension(animal.extensionId)
		local upgrade = if extension then Config.getExtensionUpgrade(extension.id) else nil
		if extension and upgrade and save.purchased[upgrade.id] then
			income *= 1 + extension.incomeBonus
		end
	end
	return income
end

function FarmMath.computeIncomePerSecond(save: PlayerSave): number
	local total = 0
	local incomeByAnimal: { [string]: number } = {}
	for _, animal in save.animals do
		if not save.unlockedZones[animal.zoneId] then
			continue
		end
		local stageMul = Config.STAGE_INCOME_MULTIPLIER[animal.stage] or 1
		total += FarmMath.getAnimalIncome(save, animal.animalId, animal) * stageMul
	end
	return total
end

-- Evre sınırlarını kesen aralığı ayrı ayrı hesapla; dönüşteki yetişkin gelirini
-- yavruluk süresine uygulama. Önbellek yalnızca bu çağrıya ait, hava/yükseltme bayatlamaz.
function FarmMath.computeIncomeOverInterval(
	save: PlayerSave,
	startedAt: number,
	endedAt: number,
	neutralWeather: boolean?
): number
	if not isFinite(startedAt) or not isFinite(endedAt) or endedAt <= startedAt then
		return 0
	end
	local total = 0
	local rates: { [string]: number } = {}
	local speeds: { [string]: number } = {}
	for _, animal in save.animals do
		local animalConfig = Config.ANIMALS[animal.animalId]
		if not animalConfig or not save.unlockedZones[animal.zoneId] then
			continue
		end
		local speed = speeds[animal.animalId]
		if speed == nil then
			speed = FarmMath.getGrowthSpeed(save, animal.animalId)
			speeds[animal.animalId] = speed
		end
		local rate = if neutralWeather
			then animalConfig.baseIncomePerSecond * FarmMath.getAnimalMultiplier(save, animal.animalId, true)
			else FarmMath.getAnimalIncome(save, animal.animalId, animal)
		if neutralWeather and animal.extensionId then
			local extension = Config.getExtension(animal.extensionId)
			local upgrade = if extension then Config.getExtensionUpgrade(extension.id) else nil
			if extension and upgrade and save.purchased[upgrade.id] then
				rate *= 1 + extension.incomeBonus
			end
		end
		local start = math.max(startedAt, animal.bornAt)
		local youngAt = animal.bornAt + Config.GROWTH_SECONDS.calf / speed
		local adultAt = youngAt + Config.GROWTH_SECONDS.young / speed
		local calfSeconds = math.max(0, math.min(endedAt, youngAt) - start)
		local youngSeconds = math.max(0, math.min(endedAt, adultAt) - math.max(start, youngAt))
		local adultSeconds = math.max(0, endedAt - math.max(start, adultAt))
		total += rate * (calfSeconds * Config.STAGE_INCOME_MULTIPLIER.calf + youngSeconds * Config.STAGE_INCOME_MULTIPLIER.young + adultSeconds * Config.STAGE_INCOME_MULTIPLIER.adult)
	end
	return total
end

function FarmMath.computeOfflineEarnings(save: PlayerSave, lastSeen: number, now: number): number
	if not isFinite(lastSeen) or not isFinite(now) then
		return 0
	end
	local endedAt = math.min(now, lastSeen + Config.OFFLINE_MAX_HOURS * 3600)
	local potential = FarmMath.computeIncomeOverInterval(save, lastSeen, endedAt, true) * Config.OFFLINE_EARNING_RATE
	return math.floor(math.max(0, math.min(potential, FarmMath.getStorageCap(save) - save.stored)))
end

-- Yeni büyüme hızı yalnızca satın alımdan sonraki süreye uygulanır.
function FarmMath.preserveGrowthProgress(save: PlayerSave, previousSpeeds: { [string]: number }, now: number)
	for _, animal in save.animals do
		local previous = previousSpeeds[animal.animalId]
		if previous and animal.bornAt ~= 0 then
			local speed = FarmMath.getGrowthSpeed(save, animal.animalId)
			local age = math.max(0, now - animal.bornAt) * previous
			animal.bornAt = now - age / speed
			animal.stage = FarmMath.getStage(animal.bornAt, now, speed)
		end
	end
end

function FarmMath.countInZone(save: PlayerSave, zoneId: string): number
	local count = 0
	for _, animal in save.animals do
		if animal.zoneId == zoneId and (animal.extensionId == nil or animal.extensionId == "") then
			count += 1
		end
	end
	return count
end

function FarmMath.countInExtension(save: PlayerSave, extensionId: string): number
	local count = 0
	for _, animal in save.animals do
		if animal.extensionId == extensionId then
			count += 1
		end
	end
	return count
end

function FarmMath.getExtensionStatus(save: PlayerSave, extensionId: string): (UpgradeStatus, { string })
	local upgrade = Config.getExtensionUpgrade(extensionId)
	if not upgrade then
		return "locked", {}
	end
	return FarmMath.getUpgradeStatus(save, upgrade.id)
end

function FarmMath.countAnimals(save: PlayerSave, animalId: string): number
	local count = 0
	for _, animal in save.animals do
		if animal.animalId == animalId then
			count += 1
		end
	end
	return count
end

function FarmMath.getAnimalPrice(save: PlayerSave, animalId: string): number
	local animalConfig = Config.ANIMALS[animalId]
	if not animalConfig then
		return math.huge
	end
	local owned = FarmMath.countAnimals(save, animalId)
	return math.floor(animalConfig.price * Config.ANIMAL_PRICE_GROWTH ^ owned)
end

function FarmMath.findReplaceableFish(save: PlayerSave): GameTypes.AnimalRecord?
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

function FarmMath.getFishReplacementPrice(save: PlayerSave): number
	local price = FarmMath.getAnimalPrice(save, "seabass")
	-- Yükselen mevcut hamsi fiyatını iade etme: al-sat döngüsü kâr üretememeli.
	local refund = math.floor(Config.ANIMALS.anchovy.price * Config.FISH_REPLACEMENT_REFUND_RATE)
	return math.max(0, price - math.min(price, refund))
end

export type ZoneBlock = "full" | "locked"

-- Bu hayvan türü için en az bir bölge açık mı? (ada seçimi shop'u gizlemesin)
function FarmMath.hasUnlockedAnimalZone(save: PlayerSave, animalId: string): boolean
	for _, zoneId in Config.ZONE_ORDER do
		local zone = Config.ZONES[zoneId]
		if zone and table.find(zone.allowedAnimals, animalId) and save.unlockedZones[zoneId] then
			return true
		end
	end
	return false
end

-- Hayvanın konabileceği ilk açık ve boş alanı döner; yoksa (nil, sebep metni, engel türü)
function FarmMath.findZoneForAnimal(save: PlayerSave, animalId: string): (string?, string?, ZoneBlock?)
	local anyUnlocked = false
	local lockedBy: string? = nil

	for _, zoneId in Config.ZONE_ORDER do
		local zone = Config.ZONES[zoneId]
		if not zone or not table.find(zone.allowedAnimals, animalId) then
			continue
		end
		if save.unlockedZones[zoneId] then
			anyUnlocked = true
			if FarmMath.countInZone(save, zoneId) < zone.capacity then
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

export type UpgradeStatus = "owned" | "available" | "locked"

-- Yol haritası öğesinin durumu; kilitliyse eksik ön koşulların adları
function FarmMath.getUpgradeStatus(save: PlayerSave, upgradeId: string): (UpgradeStatus, { string })
	if save.purchased[upgradeId] then
		return "owned", {}
	end
	local upgrade = Config.getUpgrade(upgradeId)
	if not upgrade then
		return "locked", {}
	end
	local missing: { string } = {}
	for _, requiredId in upgrade.requires do
		if not save.purchased[requiredId] then
			local required = Config.getUpgrade(requiredId)
			table.insert(missing, if required then required.displayName else requiredId)
		end
	end
	if #missing > 0 then
		return "locked", missing
	end
	return "available", {}
end

-- Henüz açılmamış, ön koşulları tamam olan en ucuz ada (sıradaki ada hedefi)
function FarmMath.getNextIsland(save: PlayerSave): (Config.FarmIslandConfig?, Config.UpgradeConfig?)
	for _, islandId in Config.FARM_ISLAND_ORDER do
		local island = Config.FARM_ISLANDS[islandId]
		if island and island.upgradeId and not save.unlockedIslands[islandId] then
			return island, Config.getUpgrade(island.upgradeId)
		end
	end
	return nil, nil
end

function FarmMath.countIslands(save: PlayerSave): (number, number)
	local owned = 0
	for _, islandId in Config.FARM_ISLAND_ORDER do
		if save.unlockedIslands[islandId] then
			owned += 1
		end
	end
	return owned, #Config.FARM_ISLAND_ORDER
end

-- 1234567 -> "$1,234,567"
function FarmMath.formatMoney(amount: number): string
	local formatted = tostring(math.floor(amount))
	while true do
		local replaced, count = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1,%2")
		formatted = replaced
		if count == 0 then
			break
		end
	end
	return `${formatted}`
end

-- 2 -> "2", 2.345 -> "2.3"
function FarmMath.formatRate(rate: number): string
	if rate == math.floor(rate) then
		return tostring(rate)
	end
	return string.format("%.1f", rate)
end

return FarmMath
