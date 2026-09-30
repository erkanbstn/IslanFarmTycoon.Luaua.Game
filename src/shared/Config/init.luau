--!strict
-- Hem sunucu hem client'ın okuyabildiği sabit ayarlar.
-- Gizli bilgi koyma: ReplicatedStorage client'a da gider.
-- Veri tabloları bu klasördeki modüllerde durur (Core, Weather, Economy, Shop, Achievements, Audio, Islands,
-- Upgrades, Production, Animals, Items); burada birleştirilir, seviye zincirleri/maliyet eğrisi uygulanır ve getter'lar durur.

local Types = require(script:WaitForChild("Types"))
local Core = require(script:WaitForChild("Core"))
local Weather = require(script:WaitForChild("Weather"))
local Economy = require(script:WaitForChild("Economy"))
local Shop = require(script:WaitForChild("Shop"))
local Achievements = require(script:WaitForChild("Achievements"))
local Audio = require(script:WaitForChild("Audio"))
local Goods = require(script:WaitForChild("Goods"))
local Islands = require(script:WaitForChild("Islands"))
local Upgrades = require(script:WaitForChild("Upgrades"))
local Production = require(script:WaitForChild("Production"))
local Animals = require(script:WaitForChild("Animals"))
local Items = require(script:WaitForChild("Items"))

export type ZoneConfig = Types.ZoneConfig
export type BuildLevelEffects = Types.BuildLevelEffects
export type ProductionRecipeConfig = Types.ProductionRecipeConfig
export type ProductionOptionConfig = Types.ProductionOptionConfig
export type AnimalConfig = Types.AnimalConfig
export type BarnLevelConfig = Types.BarnLevelConfig
export type ThemeConfig = Types.ThemeConfig
export type ItemSlotConfig = Types.ItemSlotConfig
export type ItemPart = Types.ItemPart
export type ItemLook = Types.ItemLook
export type ItemEffects = Types.ItemEffects
export type ItemPower = Types.ItemPower
export type ItemConfig = Types.ItemConfig
export type FarmIslandConfig = Types.FarmIslandConfig
export type SeasonConfig = Types.SeasonConfig
export type WeatherConfig = Types.WeatherConfig
export type RoadmapStage = Types.RoadmapStage
export type UpgradeConfig = Types.UpgradeConfig
export type AchievementConfig = Types.AchievementConfig
export type ProductConfig = Types.ProductConfig
export type SoundConfig = Types.SoundConfig
export type ExtensionConfig = Types.ExtensionConfig

local Config = {
	-- Core
	GAME_NAME = Core.GAME_NAME,
	VERSION = Core.VERSION,
	MAIN_FARM_LIMIT = Core.MAIN_FARM_LIMIT,
	LANGUAGE_ORDER = Core.LANGUAGE_ORDER,
	GRAPHICS_MODES = Core.GRAPHICS_MODES,
	LANGUAGES = Core.LANGUAGES,
	DEFAULT_LANGUAGE = Core.DEFAULT_LANGUAGE,
	MAIN_FARM_PRICES = Core.MAIN_FARM_PRICES,
	DEBUG = Core.DEBUG,
	MAP_AUTO_BUILD = Core.MAP_AUTO_BUILD,
	MAP_PLOT_COUNT = Core.MAP_PLOT_COUNT,
	ISLAND_RING_RADIUS = Core.ISLAND_RING_RADIUS,
	PLOT_NAMES = Core.PLOT_NAMES,
	DATASTORE_NAME = Core.DATASTORE_NAME,
	AUTOSAVE_SECONDS = Core.AUTOSAVE_SECONDS,
	WALK_SPEED = Core.WALK_SPEED,
	SPRINT_SPEED = Core.SPRINT_SPEED,
	STARTING_COW_COUNT = Core.STARTING_COW_COUNT,
	STARTING_CASH = Core.STARTING_CASH,
	INCOME_TICK_SECONDS = Core.INCOME_TICK_SECONDS,
	MAX_INCOME_CATCHUP_SECONDS = Core.MAX_INCOME_CATCHUP_SECONDS,
	FISH_REPLACEMENT_REFUND_RATE = Core.FISH_REPLACEMENT_REFUND_RATE,
	ORDER_UNITS = Core.ORDER_UNITS,
	ORDER_PRODUCTION_SECONDS = Core.ORDER_PRODUCTION_SECONDS,
	ORDER_REWARD_MULTIPLIER = Core.ORDER_REWARD_MULTIPLIER,
	ORDER_TIERS = Core.ORDER_TIERS,
	ORDER_BOARD_SECONDS = Core.ORDER_BOARD_SECONDS,
	-- Weather
	SEASON_SECONDS = Weather.SEASON_SECONDS,
	DAY_SECONDS = Weather.DAY_SECONDS,
	DAY_START_HOUR = Weather.DAY_START_HOUR,
	WEATHER_SECONDS_MIN = Weather.WEATHER_SECONDS_MIN,
	WEATHER_SECONDS_MAX = Weather.WEATHER_SECONDS_MAX,
	SEASONS = Weather.SEASONS,
	WEATHER = Weather.WEATHER,
	-- Economy
	OFFLINE_EARNING_RATE = Economy.OFFLINE_EARNING_RATE,
	OFFLINE_MAX_HOURS = Economy.OFFLINE_MAX_HOURS,
	OFFLINE_STORAGE_MULTIPLIER = Economy.OFFLINE_STORAGE_MULTIPLIER,
	PRODUCTION_BONUS_PER_ADULT = Economy.PRODUCTION_BONUS_PER_ADULT,
	PRODUCTION_MAX_BONUS_ADULTS = Economy.PRODUCTION_MAX_BONUS_ADULTS,
	ANIMAL_PRICE_GROWTH = Economy.ANIMAL_PRICE_GROWTH,
	ANIMAL_SELL_FRACTION = Economy.ANIMAL_SELL_FRACTION,
	UPGRADE_COST_BASE = Economy.UPGRADE_COST_BASE,
	UPGRADE_COST_EXPONENT = Economy.UPGRADE_COST_EXPONENT,
	BULK_MULTIPLIERS = Economy.BULK_MULTIPLIERS,
	BUILD_UPGRADES = Economy.BUILD_UPGRADES,
	PRODUCTION_MIN_RETURN = Economy.PRODUCTION_MIN_RETURN,
	EXTENSION_STAY_SECONDS = Economy.EXTENSION_STAY_SECONDS,
	EXTENSION_CAPACITY_LEVELS = Economy.EXTENSION_CAPACITY_LEVELS,
	-- Shop
	ITEM_SLOT_ORDER = Shop.ITEM_SLOT_ORDER,
	ITEM_SLOTS = Shop.ITEM_SLOTS,
	ITEM_USE_COOLDOWN_SECONDS = Shop.ITEM_USE_COOLDOWN_SECONDS,
	ITEMS = Shop.ITEMS,
	ITEM_ORDER = Shop.ITEM_ORDER,
	LINEAGE = Shop.LINEAGE,
	PRODUCTS = Shop.PRODUCTS,
	PRODUCT_MIN_INCOME_PACK = Shop.PRODUCT_MIN_INCOME_PACK,
	DAILY_REWARD_MULTIPLIERS = Shop.DAILY_REWARD_MULTIPLIERS,
	DAILY_MINUTES = Shop.DAILY_MINUTES,
	DAILY_MIN_REWARD = Shop.DAILY_MIN_REWARD,
	MERCHANT = Shop.MERCHANT,
	GOLDEN = Shop.GOLDEN,
	SEASONAL_GOALS = Shop.SEASONAL_GOALS,
	SEASONAL_REWARD_SECONDS = Shop.SEASONAL_REWARD_SECONDS,
	SEASONAL_MIN_REWARD = Shop.SEASONAL_MIN_REWARD,
	-- Achievements
	ACHIEVEMENTS = Achievements.ACHIEVEMENTS,
	-- Goods (ahır deposu ürünleri)
	GOODS = Goods.GOODS,
	GOODS_ORDER = Goods.GOODS_ORDER,
	-- Audio
	SOUNDS = Audio.SOUNDS,
	AMBIENCE = Audio.AMBIENCE,
	ANIMAL_SOUNDS = Audio.ANIMAL_SOUNDS,
	-- Islands
	GROWTH_SECONDS = Islands.GROWTH_SECONDS,
	BARN_LEVELS = Islands.BARN_LEVELS,
	FARM_ISLAND_ORDER = Islands.FARM_ISLAND_ORDER,
	FARM_ISLANDS = Islands.FARM_ISLANDS,
	THEMES = Islands.THEMES,
	ROADMAP_STAGES = Islands.ROADMAP_STAGES,
	-- Upgrades
	UPGRADES = Upgrades.UPGRADES,
	-- Production
	EXTENSIONS = Production.EXTENSIONS,
	PRODUCTION_ORDER = Production.PRODUCTION_ORDER,
	PRODUCTION_RECIPES = Production.PRODUCTION_RECIPES,
	-- Animals
	ZONE_ORDER = Animals.ZONE_ORDER,
	ZONES = Animals.ZONES,
	ANIMAL_ORDER = Animals.ANIMAL_ORDER,
	ANIMALS = Animals.ANIMALS,
	STAGE_INCOME_MULTIPLIER = Animals.STAGE_INCOME_MULTIPLIER,
	STAGE_DISPLAY = Animals.STAGE_DISPLAY,
	LEGACY_UPGRADES = Animals.LEGACY_UPGRADES,
}

-- Ana çiftlik numarasına (= fiziksel ada numarasına) bağlı tema; bilinmeyen numara ilk temayı kullanır.
function Config.getTheme(farmId: string?): ThemeConfig
	local index = if farmId then tonumber(farmId) else nil
	return Config.THEMES[if index and index % 1 == 0 then index else 1] or Config.THEMES[1]
end

-- Bu çiftlikte bulunan adalar: ana ada + temanın 3 küçük adası
function Config.getThemeIslands(farmId: string?): { string }
	local islands = { "home" }
	for _, islandId in Config.getTheme(farmId).satellites do
		table.insert(islands, islandId)
	end
	return islands
end

function Config.themeHasIsland(farmId: string?, islandId: string): boolean
	return islandId == "home" or table.find(Config.getTheme(farmId).satellites, islandId) ~= nil
end

-- Ana adanın ağıl ve otlağında yaşayan hayvan (temaya göre)
function Config.getHomeAnimal(farmId: string?): string
	return Config.getTheme(farmId).homeAnimal
end

-- Bir bölgeye konabilen hayvanlar: temalı bölgelerde yalnızca çiftliğin ana ada hayvanı
function Config.getZoneAnimals(zone: ZoneConfig, farmId: string?): { string }
	if zone.themed then
		return { Config.getHomeAnimal(farmId) }
	end
	return zone.allowedAnimals
end

function Config.zoneAllows(zone: ZoneConfig, animalId: string, farmId: string?): boolean
	return table.find(Config.getZoneAnimals(zone, farmId), animalId) ~= nil
end

-- Bölgenin oyuncuya gösterilen adı: ağıl, çiftliğin hayvanının adını taşır
function Config.getZoneName(zone: ZoneConfig, farmId: string?): string
	if zone.id == "starter" then
		local animal = Config.ANIMALS[Config.getHomeAnimal(farmId)]
		return if animal then `{animal.displayName} Ağılı` else zone.displayName
	end
	return zone.displayName
end

function Config.getBarnLevelConfig(level: number): BarnLevelConfig?
	for _, entry in Config.BARN_LEVELS do
		if entry.level == level then
			return entry
		end
	end
	return nil
end

-- Seviyeli geliştirmeler: her zaman alınacak bir şey olsun. Her seviye ayrı bir yükseltmedir
-- ("<id>_lv<N>"); önceki seviye olmadan alınamaz. Kayıt şeması değişmez: purchased[id] yeterlidir.
-- kind = "level" (harita yapı noktası istemez); OrderRules ve "tüm yol haritası" sayımı bunları saymaz.
local LEVEL_CHAINS = {
	{
		id = "feed_quality",
		displayName = "Yem Kalitesi",
		description = "Tüm hayvanların geliri +%6",
		icon = "🌾",
		requires = "silo",
		costs = { 1200, 3000, 7500, 18000, 42000 },
		effect = "income",
		amount = 0.06,
	},
	{
		id = "storage_expansion",
		displayName = "Depo Genişletme",
		description = "Depo kapasitesi +%12",
		icon = "📦",
		requires = "silo",
		costs = { 900, 2600, 7000, 16000 },
		effect = "storage",
		amount = 0.12,
	},
	{
		id = "fast_growth",
		displayName = "Hızlı Büyüme",
		description = "Hayvanlar %8 daha hızlı büyür",
		icon = "⏩",
		requires = "silo",
		costs = { 2000, 6000, 15000 },
		effect = "growth",
		amount = 1.08,
	},
}
for _, chain in LEVEL_CHAINS do
	for level, cost in chain.costs do
		local upgrade: UpgradeConfig = {
			id = `{chain.id}_lv{level}`,
			displayName = `{chain.displayName} Sv.{level}`,
			description = chain.description,
			icon = chain.icon,
			stage = 1,
			cost = cost,
			requires = { if level == 1 then chain.requires else `{chain.id}_lv{level - 1}` },
			kind = "level",
			leveled = true,
		}
		if chain.effect == "income" then
			local boost: { [string]: number } = {}
			for animalId in Config.ANIMALS do
				boost[animalId] = chain.amount
			end
			upgrade.incomeBoost = boost
		elseif chain.effect == "storage" then
			upgrade.storageBonus = chain.amount
		else
			upgrade.growthSpeed = chain.amount
		end
		table.insert(Config.UPGRADES, upgrade)
	end
end

-- Eklenti kapasite yükseltmeleri: her eklenti 2 hayvanla başlar; iki yükseltmeyle 3 ve 4 olur.
-- kind = "level" (yol haritası "tamamlandı" sayımına girmez); her seviye bir öncekini ister.
Config.EXTENSION_CAPACITY_UPGRADES = {} :: { [string]: { string } }
do
	local extensionUpgrades: { UpgradeConfig } = {}
	for _, upgrade in Config.UPGRADES do
		if upgrade.kind == "extension" and upgrade.extensionId then
			table.insert(extensionUpgrades, upgrade)
		end
	end
	for _, base in extensionUpgrades do
		local extension = Config.EXTENSIONS[base.extensionId :: string]
		local ids: { string } = {}
		for level = 1, Config.EXTENSION_CAPACITY_LEVELS do
			local id = `{base.id}_cap{level}`
			table.insert(ids, id)
			table.insert(Config.UPGRADES, {
				id = id,
				displayName = `{base.displayName} · Kapasite {extension.capacity + level}`,
				description = `Aynı anda {extension.capacity + level} hayvan`,
				icon = base.icon,
				stage = base.stage,
				cost = math.floor(base.cost * (0.5 + level)),
				requires = { if level == 1 then base.id else `{base.id}_cap{level - 1}` },
				kind = "level",
				leveled = true,
				extensionId = base.extensionId,
				extensionCapacity = 1,
			})
		end
		Config.EXTENSION_CAPACITY_UPGRADES[base.extensionId :: string] = ids
	end
end

-- Yapı geliştirme profilleri: bölgenin/tesisin işlevine göre (varsayılan: bölge "barn", tesis "factory")
local upgradeProfiles: { [string]: string } = {
	poultry = "coop",
	pond = "coop",
	stable = "stable",
	goatpen = "fold",
	sheepfold = "fold",
	pigpen = "fold",
	fishpen = "sea",
}
for zoneId, profile in upgradeProfiles do
	Config.ZONES[zoneId].upgradeProfile = profile
end
Config.PRODUCTION_RECIPES.hatchery.upgradeProfile = "hatchery"

-- Geliştirilebilir yapılar: bölgeler ve üretim tesisleri (ada + ad + simge tek yerden)
Config.BUILD_TARGETS = {} :: { [string]: { island: string, icon: string, isZone: boolean } }
Config.BUILD_ORDER = {} :: { string }
for _, zoneId in Config.ZONE_ORDER do
	local zone = Config.ZONES[zoneId]
	Config.BUILD_TARGETS[zoneId] = { island = zone.island, icon = zone.icon, isZone = true }
	table.insert(Config.BUILD_ORDER, zoneId)
end
for _, recipeId in Config.PRODUCTION_ORDER do
	local recipe = Config.PRODUCTION_RECIPES[recipeId]
	-- Bölge ve tesis kimlikleri aynı yapı geliştirme tablosunu paylaşır; çakışırsa iki yapı tek kayda düşer.
	assert(not Config.BUILD_TARGETS[recipeId], `Üretim tarifi kimliği başka bir yapıyla çakışıyor: {recipeId}`)
	Config.BUILD_TARGETS[recipeId] = { island = recipe.island, icon = recipe.icon, isZone = false }
	table.insert(Config.BUILD_ORDER, recipeId)
end

-- Çiftliğin ana ada hayvanının simgesi (inek, tavuk ya da ördek)
function Config.getHomeAnimalIcon(farmId: string?): string
	local animal = Config.ANIMALS[Config.getHomeAnimal(farmId)]
	return if animal then animal.icon else "🐾"
end

-- Bölgenin oyuncuya gösterilen simgesi: ana ada ağılı çiftliğin hayvanının simgesini taşır (İnek/Tavuk/Ördek Ağılı),
-- diğer bölgeler kendi simgesini korur.
function Config.getZoneIcon(zone: ZoneConfig, farmId: string?): string
	if zone.id == "starter" then
		return Config.getHomeAnimalIcon(farmId)
	end
	return zone.icon
end

function Config.getBuildTargetIcon(targetId: string, farmId: string?): string
	local zone = Config.ZONES[targetId]
	if zone then
		return Config.getZoneIcon(zone, farmId)
	end
	local target = Config.BUILD_TARGETS[targetId]
	return if target then target.icon else "🐾"
end

function Config.getBuildTargetName(targetId: string, farmId: string?): string
	local zone = Config.ZONES[targetId]
	if zone then
		return Config.getZoneName(zone, farmId)
	end
	local recipe = Config.PRODUCTION_RECIPES[targetId]
	return if recipe then recipe.displayName else targetId
end

-- Maliyet eğrisi: taban fiyattan ölçeklenmiş fiyat (2 anlamlı basamak). Yükseltmeler ve ek ana çiftlik fiyatları aynı eğriyi kullanır.
local function curvedCost(base: number): number
	if base <= Config.UPGRADE_COST_BASE then
		return base
	end
	local scaled = base * (base / Config.UPGRADE_COST_BASE) ^ Config.UPGRADE_COST_EXPONENT
	local step = 10 ^ (math.floor(math.log10(scaled)) - 1)
	return math.floor(scaled / step + 0.5) * step
end

-- Tüm yükseltme maliyetlerine eğriyi bir kez uygula (seviye zincirleri dahil)
for _, upgrade in Config.UPGRADES do
	upgrade.cost = curvedCost(upgrade.cost)
end
-- Ek ana çiftlikler de aynı eğriyle (yazılı değerler taban fiyattır); ilki ücretsizdir
for index, price in Config.MAIN_FARM_PRICES do
	Config.MAIN_FARM_PRICES[index] = curvedCost(price)
end

-- Eşya tanımları (Config/Items.luau): fiyat ve dengeyi ordan düzenle.
Items.install(Config.ITEMS, Config.ITEM_ORDER)

function Config.getUpgrade(id: string): UpgradeConfig?
	for _, upgrade in Config.UPGRADES do
		if upgrade.id == id then
			return upgrade
		end
	end
	return nil
end

-- Bir bölgeyi açan yol haritası öğesi (adası açılınca kendiliğinden açılan bölgeler için nil)
function Config.getZoneUpgrade(zoneId: string): UpgradeConfig?
	for _, upgrade in Config.UPGRADES do
		if upgrade.kind == "zone" and upgrade.zoneId == zoneId then
			return upgrade
		end
	end
	return nil
end

-- Yükseltmenin hangi adaya ait olduğu (ahır ve ana ada bonusları her zaman "home").
-- Arayüz sekmeleri ve yönetici test araçları aynı eşlemeyi kullanır.
function Config.getUpgradeIsland(upgrade: UpgradeConfig): string
	if upgrade.kind == "barn" then
		return "home"
	end
	if upgrade.kind == "island" and upgrade.islandId then
		return upgrade.islandId
	end
	if upgrade.kind == "zone" and upgrade.zoneId then
		local zone = Config.ZONES[upgrade.zoneId]
		if zone then
			return zone.island
		end
	end
	if upgrade.extensionId then -- eklentiler ve kapasite yükseltmeleri (kind "extension" / "level")
		local extension = Config.EXTENSIONS[upgrade.extensionId]
		if extension then
			return extension.island
		end
	end
	local boostIsland: { [string]: string } = {
		silo = "home",
		milk_machine = "home",
		milk_factory = "home",
		fish_farm = "home",
		fishing_boat = "home",
		auto_collector = "home",
		egg_factory = "poultry",
		hatchery = "poultry",
		golden_horseshoe = "horse",
		horse_training = "horse",
		cheese_dairy = "goat",
		duck_house = "duck",
		wool_mill = "sheep",
		truffle_kitchen = "pig",
	}
	local mapped = boostIsland[upgrade.id]
	if mapped then
		return mapped
	end
	local stage = Config.ROADMAP_STAGES[upgrade.stage]
	return if stage and stage.island then stage.island else "home"
end

function Config.getExtension(extensionId: string): ExtensionConfig?
	return Config.EXTENSIONS[extensionId]
end

function Config.getExtensionUpgrade(extensionId: string): UpgradeConfig?
	for _, upgrade in Config.UPGRADES do
		if upgrade.kind == "extension" and upgrade.extensionId == extensionId then
			return upgrade
		end
	end
	return nil
end

return table.freeze(Config)
