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
local Counts = require(script.Parent:WaitForChild("Counts"))

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

-- Hayvanın görevinin gelir çarpanı: tesise verilmişse 0 (iş boyunca gelir getirmez), satın alınmış eklentide
-- duruyorsa 1 + bonus, görevi yoksa 1. Görevin süresi (task.startedAt..endsAt) dışında uygulanmaz.
local function taskMultiplier(save: PlayerSave, task: GameTypes.AnimalTask): number
	if task.kind == "production" then
		return 0
	end
	local extension = Config.getExtension(task.id)
	local upgrade = if extension then Config.getExtensionUpgrade(extension.id) else nil
	if extension and upgrade and save.purchased[upgrade.id] then
		return 1 + extension.incomeBonus
	end
	return 1
end

-- Şu anki çarpan (süresi dolmuş görev sayılmaz)
local function currentTaskFactor(save: PlayerSave, animal: GameTypes.AnimalRecord?, now: number?): number
	if animal then
		local task = Counts.getActiveTask(animal, now)
		if task then
			return taskMultiplier(save, task)
		end
	end
	return 1
end

-- Yetişkin bir hayvanın şu anki saniyelik geliri
function Income.getAnimalIncome(
	save: PlayerSave,
	animalId: string,
	animal: GameTypes.AnimalRecord?,
	now: number?
): number
	local animalConfig = Config.ANIMALS[animalId]
	if not animalConfig then
		return 0
	end
	return animalConfig.baseIncomePerSecond
		* Income.getAnimalMultiplier(save, animalId, nil, if animal then animal.zoneId else nil)
		* currentTaskFactor(save, animal, now)
end

-- Tür başına çarpan tek çağrı içinde önbelleğe alınır (her hayvan için yükseltme/hava taraması yapılmaz).
function Income.computeIncomePerSecond(save: PlayerSave, now: number?): number
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
		total += (rate :: number) * currentTaskFactor(save, animal, now) * stageMul
	end
	return total
end

-- Bir hayvanın [from, to] aralığındaki evre ağırlıklı saniyesi (yavru/genç/yetişkin gelir çarpanlarıyla).
local function stageSeconds(animal: GameTypes.AnimalRecord, speed: number, from: number, to: number): number
	local start = math.max(from, animal.bornAt)
	local youngAt = animal.bornAt + Config.GROWTH_SECONDS.calf / speed
	local adultAt = youngAt + Config.GROWTH_SECONDS.young / speed
	local calfSeconds = math.max(0, math.min(to, youngAt) - start)
	local youngSeconds = math.max(0, math.min(to, adultAt) - math.max(start, youngAt))
	local adultSeconds = math.max(0, to - math.max(start, adultAt))
	return calfSeconds * Config.STAGE_INCOME_MULTIPLIER.calf
		+ youngSeconds * Config.STAGE_INCOME_MULTIPLIER.young
		+ adultSeconds * Config.STAGE_INCOME_MULTIPLIER.adult
end

-- Evre sınırlarını kesen aralığı ayrı ayrı hesapla; dönüşteki yetişkin gelirini
-- yavruluk süresine uygulama. Önbellek yalnızca bu çağrıya ait, hava/yükseltme bayatlamaz.
-- Görev (tesis/eklenti) çarpanı yalnızca görevin süresiyle kesişen kısma uygulanır: tesiste geçen süre gelirsiz,
-- eklentide geçen süre bonuslu, görevden önce ve sonra normal.
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
		local weighted = stageSeconds(animal, speed :: number, startedAt, endedAt)
		local task = animal.task
		if task then
			local from = math.max(startedAt, task.startedAt)
			local to = math.min(endedAt, task.endsAt)
			if to > from then
				weighted += (taskMultiplier(save, task) - 1) * stageSeconds(animal, speed :: number, from, to)
			end
		end
		total += (baseRate :: number) * weighted
	end
	return total
end

-- Verilen hayvanların `duration` saniye boyunca yerinde (yetişkin olarak) kazanacağı gelir. Tesise verilen hayvanlar
-- iş boyunca gelir getirmediği için üretim ödülünün tabanı bu değerden hesaplanır.
function Income.estimateForgoneIncome(save: PlayerSave, animals: { GameTypes.AnimalRecord }, duration: number): number
	local total = 0
	for _, animal in animals do
		local animalConfig = Config.ANIMALS[animal.animalId]
		if animalConfig then
			total += animalConfig.baseIncomePerSecond * Income.getAnimalMultiplier(
				save,
				animal.animalId,
				nil,
				animal.zoneId
			) * duration
		end
	end
	return total
end

-- Çevrimdışı kazanç oranı (eşya/ada bonusu dahil) ve en çok sayılan süre (saat). Pasif Gelir ikisini de artırır.
function Income.getOfflineTerms(save: PlayerSave): (number, number)
	local upgraded = Core.hasOfflineIncome(save)
	local baseRate = if upgraded then Config.OFFLINE_UPGRADED_EARNING_RATE else Config.OFFLINE_EARNING_RATE
	local hours = if upgraded then Config.OFFLINE_UPGRADED_MAX_HOURS else Config.OFFLINE_MAX_HOURS
	return baseRate * (1 + Core.getBonus(save, "offlineBonus")), hours
end

-- Sınır depoya değil süreye bağlıdır: en çok `hours` saatlik gelirin `rate` oranı kasaya yatar.
function Income.computeOfflineEarnings(save: PlayerSave, lastSeen: number, now: number): number
	if not isFinite(lastSeen) or not isFinite(now) then
		return 0
	end
	local rate, hours = Income.getOfflineTerms(save)
	local endedAt = math.min(now, lastSeen + hours * 3600)
	return math.floor(math.max(0, Income.computeIncomeOverInterval(save, lastSeen, endedAt, true) * rate))
end

return Income
