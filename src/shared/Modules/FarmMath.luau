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
	for key, pass in Config.PRODUCTS.passes do
		if pass.autoCollect and save.passes and save.passes[key] then
			return true
		end
	end
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
	-- Oyun geçidi: ekstra depo
	for key, pass in Config.PRODUCTS.passes do
		if pass.storageBonus and save.passes and save.passes[key] then
			bonus += pass.storageBonus
		end
	end
	return math.floor(FarmMath.getBarnConfig(save).storageCap * (1 + bonus))
end

-- Irk geliştirme seviyesi (0..maxLevel); kayıt alanı yoksa 0
function FarmMath.getLineageLevel(save: PlayerSave, animalId: string): number
	local lineage = save.lineage
	local level = if lineage then lineage[animalId] else nil
	if typeof(level) ~= "number" or not isFinite(level) then
		return 0
	end
	return math.clamp(math.floor(level), 0, Config.LINEAGE.maxLevel)
end

-- `level` -> `level + 1` maliyeti; en üst seviyede math.huge
function FarmMath.getLineageCost(animalId: string, level: number): number
	local animalConfig = Config.ANIMALS[animalId]
	local lineage = Config.LINEAGE
	if not animalConfig or level < 0 or level >= lineage.maxLevel then
		return math.huge
	end
	local raw = animalConfig.price * lineage.costMultiplier * lineage.costGrowth ^ level
	local step = 10 ^ (math.floor(math.log10(raw)) - 1)
	return math.floor(raw / step + 0.5) * step
end

export type LineageStatus = "available" | "locked" | "max"

-- Irk geliştirme durumu: en az bir yetişkin hayvan gerekir. Üçüncü değer: sonraki seviye maliyeti.
function FarmMath.getLineageStatus(save: PlayerSave, animalId: string): (LineageStatus, string?, number)
	local level = FarmMath.getLineageLevel(save, animalId)
	if not Config.ANIMALS[animalId] then
		return "locked", "Bilinmeyen hayvan", math.huge
	end
	if level >= Config.LINEAGE.maxLevel then
		return "max", nil, math.huge
	end
	for _, animal in save.animals do
		if animal.animalId == animalId and animal.stage == "adult" then
			return "available", nil, FarmMath.getLineageCost(animalId, level)
		end
	end
	return "locked", "Önce yetişkin bir hayvan gerekir", FarmMath.getLineageCost(animalId, level)
end

-- Bir hayvan türünün toplam çarpanı (ahır seviyesi x güçlendirmeler)
function FarmMath.getAnimalMultiplier(save: PlayerSave, animalId: string, neutralWeather: boolean?): number
	local bonus = 0
	for _, upgrade in Config.UPGRADES do
		local boost = upgrade.incomeBoost
		if boost and save.purchased[upgrade.id] then
			bonus += boost[animalId] or 0
			-- "home": çiftliğin ana ada hayvanı (temaya göre inek, tavuk veya ördek)
			if boost.home and animalId == Config.getHomeAnimal(save.farmId or save.activeMainFarmId) then
				bonus += boost.home
			end
		end
	end
	-- Irk geliştirme: her seviye bu türün gelirini incomePerLevel kadar artırır
	bonus += FarmMath.getLineageLevel(save, animalId) * Config.LINEAGE.incomePerLevel
	-- Oyun geçidi çarpanı (sunucu doğrular; client yalnızca gösterir)
	local passFactor = 1
	for key, pass in Config.PRODUCTS.passes do
		if pass.incomeMultiplier and save.passes and save.passes[key] then
			passFactor *= pass.incomeMultiplier
		end
	end
	-- Ahır seviyesi x güçlendirmeler x mevsim/hava x geçit
	local environment = if neutralWeather then 1 else Environment.getIncomeMultiplier(animalId)
	return FarmMath.getBarnConfig(save).incomeMultiplier * (1 + bonus) * environment * passFactor
end

-- Satın alınmış eklentideki hayvanın gelir çarpanı (eklenti yoksa 1)
local function extensionFactor(save: PlayerSave, animal: GameTypes.AnimalRecord?): number
	if animal and animal.extensionId then
		local extension = Config.getExtension(animal.extensionId)
		local upgrade = if extension then Config.getExtensionUpgrade(extension.id) else nil
		if extension and upgrade and save.purchased[upgrade.id] then
			return 1 + extension.incomeBonus
		end
	end
	return 1
end

-- Yetişkin bir hayvanın şu anki saniyelik geliri
function FarmMath.getAnimalIncome(save: PlayerSave, animalId: string, animal: GameTypes.AnimalRecord?): number
	local animalConfig = Config.ANIMALS[animalId]
	if not animalConfig then
		return 0
	end
	return animalConfig.baseIncomePerSecond
		* FarmMath.getAnimalMultiplier(save, animalId)
		* extensionFactor(save, animal)
end

-- Tür başına çarpan tek çağrı içinde önbelleğe alınır (her hayvan için yükseltme/hava taraması yapılmaz).
function FarmMath.computeIncomePerSecond(save: PlayerSave): number
	local total = 0
	local rates: { [string]: number } = {}
	for _, animal in save.animals do
		local animalConfig = Config.ANIMALS[animal.animalId]
		if not animalConfig or not save.unlockedZones[animal.zoneId] then
			continue
		end
		local rate = rates[animal.animalId]
		if rate == nil then
			rate = animalConfig.baseIncomePerSecond * FarmMath.getAnimalMultiplier(save, animal.animalId)
			rates[animal.animalId] = rate
		end
		local stageMul = Config.STAGE_INCOME_MULTIPLIER[animal.stage] or 1
		total += (rate :: number) * extensionFactor(save, animal) * stageMul
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
		local baseRate = rates[animal.animalId]
		if baseRate == nil then
			baseRate = animalConfig.baseIncomePerSecond
				* FarmMath.getAnimalMultiplier(save, animal.animalId, neutralWeather)
			rates[animal.animalId] = baseRate
		end
		local rate = (baseRate :: number) * extensionFactor(save, animal)
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
	return math.floor(math.max(0, math.min(potential, FarmMath.getOfflineCap(save))))
end

-- Çevrimdışı kazancın üst sınırı (kasaya eklenir, depoyu doldurmaz)
function FarmMath.getOfflineCap(save: PlayerSave): number
	return FarmMath.getStorageCap(save) * Config.OFFLINE_STORAGE_MULTIPLIER
end

-- Üretimde sayılan yetişkin hayvanlar (açık bölgede, tarifin türlerinden)
function FarmMath.countProductionAdults(save: PlayerSave, recipe: Config.ProductionRecipeConfig, now: number): number
	local count = 0
	local speeds: { [string]: number } = {}
	for _, animal in save.animals do
		if not save.unlockedZones[animal.zoneId] or not table.find(recipe.animalIds, animal.animalId) then
			continue
		end
		local speed = speeds[animal.animalId]
		if speed == nil then
			speed = FarmMath.getGrowthSpeed(save, animal.animalId)
			speeds[animal.animalId] = speed
		end
		if FarmMath.getStage(animal.bornAt, now, speed :: number) == "adult" then
			count += 1
		end
	end
	return count
end

-- Gerekenden fazla yetişkin başına ödül artar; bonus oranı (0.5 = +%50) ve ödül döner.
function FarmMath.getProductionReward(
	save: PlayerSave,
	recipe: Config.ProductionRecipeConfig,
	now: number
): (number, number)
	local extra = math.clamp(
		FarmMath.countProductionAdults(save, recipe, now) - recipe.requiredAdults,
		0,
		Config.PRODUCTION_MAX_BONUS_ADULTS
	)
	local bonus = extra * Config.PRODUCTION_BONUS_PER_ADULT
	return math.floor(recipe.reward * (1 + bonus)), bonus
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

-- Bölge bu çiftlikte bu hayvanı kabul ediyor mu? (ana ada bölgeleri temaya göre değişir)
function FarmMath.zoneAllows(save: PlayerSave, zone: Config.ZoneConfig, animalId: string): boolean
	return Config.zoneAllows(zone, animalId, save.farmId or save.activeMainFarmId)
end

-- Bu türün konabileceği açık bölgelerdeki toplam boş yer
function FarmMath.getFreeSlots(save: PlayerSave, animalId: string): number
	local free = 0
	for _, zoneId in Config.ZONE_ORDER do
		local zone = Config.ZONES[zoneId]
		if zone and FarmMath.zoneAllows(save, zone, animalId) and save.unlockedZones[zoneId] then
			free += math.max(0, zone.capacity - FarmMath.countInZone(save, zoneId))
		end
	end
	return free
end

-- Ardışık `count` hayvanın toplam fiyatı: her yeni hayvan bir öncekinden ANIMAL_PRICE_GROWTH kadar pahalıdır.
function FarmMath.getBulkPrice(save: PlayerSave, animalId: string, count: number): number
	local animalConfig = Config.ANIMALS[animalId]
	if not animalConfig or count < 1 then
		return math.huge
	end
	local owned = FarmMath.countAnimals(save, animalId)
	local total = 0
	for index = 0, count - 1 do
		total += math.floor(animalConfig.price * Config.ANIMAL_PRICE_GROWTH ^ (owned + index))
	end
	return total
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
		if zone and FarmMath.zoneAllows(save, zone, animalId) and save.unlockedZones[zoneId] then
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
		if not zone or not FarmMath.zoneAllows(save, zone, animalId) then
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
-- Bu çiftliğin (temasının) adaları: ana ada + 3 küçük ada. Etkin olmayan çiftlik görünümleri farmId taşır.
function FarmMath.themeIslands(save: PlayerSave): { string }
	return Config.getThemeIslands(save.farmId or save.activeMainFarmId)
end

-- Henüz açılmamış, en ucuz sıradaki ada (yalnızca bu çiftliğin temasındakiler)
function FarmMath.getNextIsland(save: PlayerSave): (Config.FarmIslandConfig?, Config.UpgradeConfig?)
	local best: Config.FarmIslandConfig? = nil
	local bestUpgrade: Config.UpgradeConfig? = nil
	for _, islandId in FarmMath.themeIslands(save) do
		local island = Config.FARM_ISLANDS[islandId]
		if island and island.upgradeId and not save.unlockedIslands[islandId] then
			local upgrade = Config.getUpgrade(island.upgradeId)
			if upgrade and (not bestUpgrade or upgrade.cost < bestUpgrade.cost) then
				best, bestUpgrade = island, upgrade
			end
		end
	end
	return best, bestUpgrade
end

function FarmMath.countIslands(save: PlayerSave): (number, number)
	local owned = 0
	local islands = FarmMath.themeIslands(save)
	for _, islandId in islands do
		if save.unlockedIslands[islandId] then
			owned += 1
		end
	end
	return owned, #islands
end

local MONEY_SUFFIXES = { "K", "M", "B", "T", "Qa" }
local MONEY_ABBREVIATE_FROM = 10000

-- 9999 -> "$9,999" · 12400 -> "$12.4K" · 3100000 -> "$3.1M" · 250000 -> "$250K"
-- 10.000'e kadar tam sayı okunur; üstü kısaltılır. Bir basamak ondalık yalnızca 100'ün altında gösterilir.
function FarmMath.formatMoney(amount: number): string
	if amount ~= amount then
		return "$0"
	end
	local value = math.floor(amount)
	local sign = if value < 0 then "-" else ""
	local absolute = math.abs(value)
	if absolute < MONEY_ABBREVIATE_FROM then
		local formatted = tostring(absolute)
		while true do
			local replaced, count = string.gsub(formatted, "^(%d+)(%d%d%d)", "%1,%2")
			formatted = replaced
			if count == 0 then
				break
			end
		end
		return `{sign}${formatted}`
	end
	local scaled = absolute
	local index = 0
	while scaled >= 1000 and index < #MONEY_SUFFIXES do
		scaled /= 1000
		index += 1
	end
	-- Yuvarlama 999.95K -> 1000K gibi taşmalara yol açmasın: bir üst birime geç.
	local text = if scaled < 100 then string.format("%.1f", scaled) else string.format("%.0f", scaled)
	if tonumber(text) :: number >= 1000 and index < #MONEY_SUFFIXES then
		scaled /= 1000
		index += 1
		text = string.format("%.1f", scaled)
	end
	text = (string.gsub(text, "%.0$", ""))
	return `{sign}${text}{MONEY_SUFFIXES[index]}`
end

-- Depo doluluğu: 0 = boş, 1..5 = para yığını büyüklüğü (dünyadaki yığın görseli bunu kullanır).
function FarmMath.getStorageLevel(stored: number, cap: number): number
	if cap <= 0 or stored < 1 then
		return 0
	end
	local ratio = math.clamp(stored / cap, 0, 1)
	if ratio >= 0.999 then
		return 5
	end
	return math.clamp(math.floor(ratio * 4) + 1, 1, 4)
end

-- 2 -> "2", 2.345 -> "2.3"
function FarmMath.formatRate(rate: number): string
	if rate == math.floor(rate) then
		return tostring(rate)
	end
	return string.format("%.1f", rate)
end

return FarmMath
