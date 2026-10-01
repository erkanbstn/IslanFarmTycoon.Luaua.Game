--!strict
-- Alan genişletme ve yapı geliştirme: seviye, maliyet, kapasite, tesis süresi/maliyeti, durum.
-- FarmMath cephesi (init.luau) bunları birleştirir; her zaman `FarmMath.<ad>` ile kullan.

local Config = require(script.Parent.Parent.Parent:WaitForChild("Config"))
local GameTypes = require(script.Parent.Parent.Parent:WaitForChild("GameTypes"))
local Core = require(script.Parent:WaitForChild("Core"))
local Counts = require(script.Parent:WaitForChild("Counts"))
local Recipes = require(script.Parent:WaitForChild("Recipes"))
local Pricing = require(script.Parent:WaitForChild("Pricing"))

type PlayerSave = GameTypes.PlayerSave
local isFinite = Core.isFinite

local Expansion = {}

export type ExpansionStatus = "available" | "locked" | "max"

-- Yapı geliştirme: her bölge ve her üretim tesisi 5 seviyelik bir yoldur; seviyeler işlevine uygun faydalar verir.
-- Seviyeler `save.expansions[hedefId]` içinde tutulur (hedef = bölge ya da tarif kimliği).
local function buildProfile(targetId: string): { Config.BuildLevelEffects }?
	local zone = Config.ZONES[targetId]
	if zone then
		return Config.BUILD_UPGRADES.profiles[zone.upgradeProfile or "barn"]
	end
	local recipe = Config.PRODUCTION_RECIPES[targetId]
	if recipe then
		return Config.BUILD_UPGRADES.profiles[recipe.upgradeProfile or "factory"]
	end
	return nil
end

function Expansion.getExpansionLevel(save: PlayerSave, targetId: string): number
	local expansions = save.expansions
	local level = if expansions then expansions[targetId] else nil
	if typeof(level) ~= "number" or not isFinite(level) then
		return 0
	end
	return math.clamp(math.floor(level), 0, Config.BUILD_UPGRADES.maxLevel)
end

-- Ulaşılmış seviyelerdeki fayda anahtarının toplamı (kapasite adımı, verim, mevsim uyumu, ödül, tasarruf)
function Expansion.getBuildBonus(save: PlayerSave, targetId: string, key: string): number
	local profile = buildProfile(targetId)
	local total = 0
	if profile then
		for level = 1, Expansion.getExpansionLevel(save, targetId) do
			local value = if profile[level] then (profile[level] :: any)[key] else nil
			if typeof(value) == "number" then
				total += value
			end
		end
	end
	return total
end

-- Ulaşılmış seviyelerdeki fayda anahtarının çarpımı (büyüme hızı, tesis hızı)
function Expansion.getBuildMultiplier(save: PlayerSave, targetId: string, key: string): number
	local profile = buildProfile(targetId)
	local product = 1
	if profile then
		for level = 1, Expansion.getExpansionLevel(save, targetId) do
			local value = if profile[level] then (profile[level] :: any)[key] else nil
			if typeof(value) == "number" then
				product *= value
			end
		end
	end
	return product
end

-- Ulaşılmış seviyelerdeki çarpan etkisinin artısı: (çarpan - 1) toplamı (büyüme hızı: 1.12 -> +0.12)
function Expansion.getBuildExcess(save: PlayerSave, targetId: string, key: string): number
	local profile = buildProfile(targetId)
	local total = 0
	if profile then
		for level = 1, Expansion.getExpansionLevel(save, targetId) do
			local value = if profile[level] then (profile[level] :: any)[key] else nil
			if typeof(value) == "number" then
				total += value - 1
			end
		end
	end
	return total
end

-- Bir sonraki seviyenin fayda demeti (en üst seviyede nil)
function Expansion.getNextBuildLevel(save: PlayerSave, targetId: string): Config.BuildLevelEffects?
	local profile = buildProfile(targetId)
	local level = Expansion.getExpansionLevel(save, targetId)
	if not profile or level >= Config.BUILD_UPGRADES.maxLevel then
		return nil
	end
	return profile[level + 1]
end

-- Bir seviyenin görünür türü (bölge bayrağı rengi): büyüme > verim > mevsim > kapasite
function Expansion.getBuildLevelKind(targetId: string, level: number): string
	local profile = buildProfile(targetId)
	local bundle = if profile then profile[level] else nil
	if not bundle then
		return "capacity"
	end
	if bundle.growthSpeed then
		return "growth"
	elseif bundle.incomeBonus then
		return "income"
	elseif bundle.seasonAffinity then
		return "season"
	end
	return "capacity"
end

function Expansion.getExpansionStep(zone: Config.ZoneConfig): number
	return math.max(2, math.ceil(zone.capacity / 4))
end

-- Bölgenin bu çiftlikteki kapasitesi (taban + geliştirmeyle kazanılan adımlar)
function Expansion.getZoneCapacity(save: PlayerSave, zoneId: string): number
	local zone = Config.ZONES[zoneId]
	if not zone then
		return 0
	end
	return zone.capacity + Expansion.getBuildBonus(save, zoneId, "capacity") * Expansion.getExpansionStep(zone)
end

-- Bütün seviyeler tamamlanınca ulaşılabilecek en büyük kapasite (başarım ulaşılabilirliği ve testler)
function Expansion.getMaxZoneCapacity(zoneId: string): number
	local zone = Config.ZONES[zoneId]
	local profile = buildProfile(zoneId)
	if not zone or not profile then
		return 0
	end
	local steps = 0
	for _, bundle in profile do
		steps += bundle.capacity or 0
	end
	return zone.capacity + steps * Expansion.getExpansionStep(zone)
end

-- Sonraki seviyenin maliyeti; en üst seviyede veya bilinmeyen hedefte math.huge (hesap: Pricing.getPrice)
function Expansion.getExpansionCost(save: PlayerSave, targetId: string): number
	return Pricing.getPrice(save, "expansion", targetId)
end

-- Geliştirme durumu. Bölge açık olmalı; kapasite veren bir seviye için bölge dolu olmalı. Tesis kurulu olmalı.
-- Üçüncü değer: sonraki seviye maliyeti.
function Expansion.getExpansionStatus(save: PlayerSave, targetId: string): (ExpansionStatus, string?, number)
	local zone = Config.ZONES[targetId]
	local recipe = Config.PRODUCTION_RECIPES[targetId]
	if not zone and not recipe then
		return "locked", "Bilinmeyen yapı", math.huge
	end
	if Expansion.getExpansionLevel(save, targetId) >= Config.BUILD_UPGRADES.maxLevel then
		return "max", nil, math.huge
	end
	local cost = Expansion.getExpansionCost(save, targetId)
	if zone then
		if not save.unlockedZones[targetId] then
			return "locked", "Bölge henüz açık değil", cost
		end
		local nextLevel = Expansion.getNextBuildLevel(save, targetId)
		if
			nextLevel
			and (nextLevel.capacity or 0) > 0
			and Counts.countInZone(save, targetId) < Expansion.getZoneCapacity(save, targetId)
		then
			return "locked", "Önce bölgeyi hayvanla doldur", cost
		end
		return "available", nil, cost
	end
	local built = recipe and save.purchased[recipe.upgradeId] and save.unlockedIslands[recipe.island]
	if not built then
		return "locked", "Önce bu tesisi kur", cost
	end
	return "available", nil, cost
end

-- Tesis istatistikleri: geliştirmeden sonra süre, başlatma maliyeti ve ödül çarpanı
-- optionId: para tesisinde seçilen parti (verilmezse ilk seçenek)
function Expansion.getFacilityDuration(
	save: PlayerSave,
	recipe: Config.ProductionRecipeConfig,
	optionId: string?
): number
	local resolved = Recipes.resolve(recipe, optionId)
	local faster = 1 - math.clamp(Core.getBonus(save, "facilitySpeed"), 0, 0.5) -- eşya ve ada özellikleri
	return math.max(10, math.floor(resolved.duration * Expansion.getBuildMultiplier(save, recipe.id, "speed") * faster))
end

-- Başlatma ücreti; ücretsiz (cost = 0) para tesislerinde 0, diğerlerinde en az 1
function Expansion.getFacilityCost(save: PlayerSave, recipe: Config.ProductionRecipeConfig): number
	if recipe.cost <= 0 then
		return 0
	end
	local thrift = math.clamp(Expansion.getBuildBonus(save, recipe.id, "thrift"), 0, 0.8)
	return math.max(1, math.floor(recipe.cost * (1 - thrift)))
end

return Expansion
