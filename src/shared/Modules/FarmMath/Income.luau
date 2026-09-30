--!strict
-- Gelir hesapları: hayvan çarpanı/geliri, saniyelik gelir, aralık geliri ve çevrimdışı kazanç.
-- FarmMath cephesi (init.luau) bunları birleştirir; her zaman `FarmMath.<ad>` ile kullan.

local Config = require(script.Parent.Parent.Parent:WaitForChild("Config"))
local GameTypes = require(script.Parent.Parent.Parent:WaitForChild("GameTypes"))
local Environment = require(script.Parent.Parent:WaitForChild("Environment"))
local Core = require(script.Parent:WaitForChild("Core"))
local Lineage = require(script.Parent:WaitForChild("Lineage"))
local Expansion = require(script.Parent:WaitForChild("Expansion"))
local Production = require(script.Parent:WaitForChild("Production"))

type PlayerSave = GameTypes.PlayerSave
local isFinite = Core.isFinite

local Income = {}

-- Bir hayvan türünün toplam çarpanı (ahır seviyesi x güçlendirmeler)
function Income.getAnimalMultiplier(
	save: PlayerSave,
	animalId: string,
	neutralWeather: boolean?,
	zoneId: string?
): number
	local bonus = 0
	local affinity = 0
	if zoneId then
		bonus += Expansion.getBuildBonus(save, zoneId, "incomeBonus") -- bölge geliştirmesi: verim
		affinity = Expansion.getBuildBonus(save, zoneId, "seasonAffinity")
	end
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
	bonus += Core.getEquippedBonus(save, "incomeBonus")
	-- Irk geliştirme: her seviye bu türün gelirini incomePerLevel kadar artırır
	bonus += Lineage.getLineageLevel(save, animalId) * Config.LINEAGE.incomePerLevel
	-- Oyun geçidi çarpanı (sunucu doğrular; client yalnızca gösterir)
	local passFactor = 1
	for key, pass in Config.PRODUCTS.passes do
		if pass.incomeMultiplier and save.passes and save.passes[key] then
			passFactor *= pass.incomeMultiplier
		end
	end
	-- Ahır seviyesi x güçlendirmeler x mevsim/hava x geçit
	local environment = if neutralWeather
		then 1
		else Environment.getIncomeMultiplier(animalId, save.envOverride, affinity)
	return Core.getBarnConfig(save).incomeMultiplier * (1 + bonus) * environment * passFactor
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
function Income.getAnimalIncome(save: PlayerSave, animalId: string, animal: GameTypes.AnimalRecord?): number
	local animalConfig = Config.ANIMALS[animalId]
	if not animalConfig then
		return 0
	end
	return animalConfig.baseIncomePerSecond
		* Income.getAnimalMultiplier(save, animalId, nil, if animal then animal.zoneId else nil)
		* extensionFactor(save, animal)
end

-- Tür başına çarpan tek çağrı içinde önbelleğe alınır (her hayvan için yükseltme/hava taraması yapılmaz).
function Income.computeIncomePerSecond(save: PlayerSave): number
	local total = 0
	local rates: { [string]: number } = {}
	for _, animal in save.animals do
		local animalConfig = Config.ANIMALS[animal.animalId]
		if not animalConfig or not save.unlockedZones[animal.zoneId] then
			continue
		end
		local cacheKey = `{animal.animalId}|{animal.zoneId}`
		local rate = rates[cacheKey]
		if rate == nil then
			rate = animalConfig.baseIncomePerSecond
				* Income.getAnimalMultiplier(save, animal.animalId, nil, animal.zoneId)
			rates[cacheKey] = rate
		end
		local stageMul = Config.STAGE_INCOME_MULTIPLIER[animal.stage] or 1
		total += (rate :: number) * extensionFactor(save, animal) * stageMul
	end
	return total
end

-- Evre sınırlarını kesen aralığı ayrı ayrı hesapla; dönüşteki yetişkin gelirini
-- yavruluk süresine uygulama. Önbellek yalnızca bu çağrıya ait, hava/yükseltme bayatlamaz.
function Income.computeIncomeOverInterval(
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
		local cacheKey = `{animal.animalId}|{animal.zoneId}`
		local speed = speeds[cacheKey]
		if speed == nil then
			speed = Production.getGrowthSpeed(save, animal.animalId, animal.zoneId)
			speeds[cacheKey] = speed
		end
		local baseRate = rates[cacheKey]
		if baseRate == nil then
			baseRate = animalConfig.baseIncomePerSecond
				* Income.getAnimalMultiplier(save, animal.animalId, neutralWeather, animal.zoneId)
			rates[cacheKey] = baseRate
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

function Income.computeOfflineEarnings(save: PlayerSave, lastSeen: number, now: number): number
	if not isFinite(lastSeen) or not isFinite(now) then
		return 0
	end
	local endedAt = math.min(now, lastSeen + Config.OFFLINE_MAX_HOURS * 3600)
	local potential = Income.computeIncomeOverInterval(save, lastSeen, endedAt, true) * Config.OFFLINE_EARNING_RATE
	return math.floor(math.max(0, math.min(potential, Income.getOfflineCap(save))))
end

-- Çevrimdışı kazancın üst sınırı (kasaya eklenir, depoyu doldurmaz)
function Income.getOfflineCap(save: PlayerSave): number
	return Core.getStorageCap(save) * Config.OFFLINE_STORAGE_MULTIPLIER
end

return Income
