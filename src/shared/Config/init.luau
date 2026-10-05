--!strict
-- Hem sunucu hem client'ın okuyabildiği sabit ayarlar.
-- Gizli bilgi koyma: ReplicatedStorage client'a da gider.
-- Veri tabloları bu klasördeki modüllerde durur (Core, Weather, Economy, Shop, Achievements, Audio, Islands,
-- Upgrades, Production, Animals, Items); burada birleştirilir, seviye zincirleri/maliyet eğrisi uygulanır ve getter'lar durur.

local Types = require(script:WaitForChild("Types"))
local Species = require(script:WaitForChild("Species"))
local Core = require(script:WaitForChild("Core"))
local Weather = require(script:WaitForChild("Weather"))
local Economy = require(script:WaitForChild("Economy"))
local Difficulty = require(script:WaitForChild("Difficulty"))
local Shop = require(script:WaitForChild("Shop"))
local Achievements = require(script:WaitForChild("Achievements"))
local Audio = require(script:WaitForChild("Audio"))
local Goods = require(script:WaitForChild("Goods"))
local Islands = require(script:WaitForChild("Islands"))
local Upgrades = require(script:WaitForChild("Upgrades"))
local Production = require(script:WaitForChild("Production"))
local Animals = require(script:WaitForChild("Animals"))
local Items = require(script:WaitForChild("Items"))
local Progression = require(script:WaitForChild("Progression"))

export type ZoneConfig = Types.ZoneConfig
export type BuildLevelEffects = Types.BuildLevelEffects
export type ProductionRecipeConfig = Types.ProductionRecipeConfig
export type ProductionOptionConfig = Types.ProductionOptionConfig
export type AnimalConfig = Types.AnimalConfig
export type BarnLevelConfig = Types.BarnLevelConfig
export type ThemeConfig = Types.ThemeConfig
export type ItemSlotConfig = Types.ItemSlotConfig
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
	PROGRESSION = Progression,
	-- Core
	GAME_NAME = Core.GAME_NAME,
	VERSION = Core.VERSION,
	MAIN_FARM_LIMIT = Core.MAIN_FARM_LIMIT,
	MAIN_FARM_SWITCH_COOLDOWN_SECONDS = Core.MAIN_FARM_SWITCH_COOLDOWN_SECONDS,
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
	MOVEMENT_SPEED_BONUS_CAP = Core.MOVEMENT_SPEED_BONUS_CAP,
	BRIDGE_SPEED_MULTIPLIER = Core.BRIDGE_SPEED_MULTIPLIER,
	STARTING_COW_COUNT = Core.STARTING_COW_COUNT,
	ONBOARDING = Core.ONBOARDING,
	STARTER_ADULT_ANIMALS = Core.STARTER_ADULT_ANIMALS,
	STARTING_CASH = Core.STARTING_CASH,
	INCOME_TICK_SECONDS = Core.INCOME_TICK_SECONDS,
	COLLECT_COOLDOWN_SECONDS = Core.COLLECT_COOLDOWN_SECONDS,
	MAX_INCOME_CATCHUP_SECONDS = Core.MAX_INCOME_CATCHUP_SECONDS,
	FISH_REPLACEMENT_REFUND_RATE = Core.FISH_REPLACEMENT_REFUND_RATE,
	-- Weather
	SEASON_SECONDS = Weather.SEASON_SECONDS,
	DAY_SECONDS = Weather.DAY_SECONDS,
	DAY_START_HOUR = Weather.DAY_START_HOUR,
	WEATHER_SECONDS_MIN = Weather.WEATHER_SECONDS_MIN,
	WEATHER_SECONDS_MAX = Weather.WEATHER_SECONDS_MAX,
	SEASON_SIGNAL_THRESHOLD = Weather.SEASON_SIGNAL_THRESHOLD,
	SEASONS = Weather.SEASONS,
	WEATHER = Weather.WEATHER,
	-- Economy
	OFFLINE_EARNING_RATE = Economy.OFFLINE_EARNING_RATE,
	OFFLINE_MAX_HOURS = Economy.OFFLINE_MAX_HOURS,
	OFFLINE_UPGRADED_EARNING_RATE = Economy.OFFLINE_UPGRADED_EARNING_RATE,
	OFFLINE_UPGRADED_MAX_HOURS = Economy.OFFLINE_UPGRADED_MAX_HOURS,
	OFFLINE_MAX_TOTAL_RATE = Economy.OFFLINE_MAX_TOTAL_RATE,
	PRODUCTION_BONUS_PER_ADULT = Economy.PRODUCTION_BONUS_PER_ADULT,
	PRODUCTION_MAX_BONUS_ADULTS = Economy.PRODUCTION_MAX_BONUS_ADULTS,
	PRODUCTION_YIELD_MAX_MULT = Economy.PRODUCTION_YIELD_MAX_MULT,
	PRODUCTION_MAX_BATCH_UNITS = Economy.PRODUCTION_MAX_BATCH_UNITS,
	ECONOMY_LIMITS = Economy.ECONOMY_LIMITS,
	ANIMAL_PRICE_GROWTH = Economy.ANIMAL_PRICE_GROWTH,
	-- Difficulty
	DIFFICULTY = Difficulty.DIFFICULTY,
	PARKED_FARM_PAY_RATE = Economy.PARKED_FARM_PAY_RATE,
	ANIMAL_SELL_FRACTION = Economy.ANIMAL_SELL_FRACTION,
	UPGRADE_COST_BASE = Economy.UPGRADE_COST_BASE,
	UPGRADE_COST_EXPONENT = Economy.UPGRADE_COST_EXPONENT,
	BULK_MULTIPLIERS = Economy.BULK_MULTIPLIERS,
	BUILD_UPGRADES = Economy.BUILD_UPGRADES,
	PRODUCTION_MIN_RETURN = Economy.PRODUCTION_MIN_RETURN,
	PRODUCTION_MAX_RETURN = Economy.PRODUCTION_MAX_RETURN,
	EXTENSION_STAY_SECONDS = Economy.EXTENSION_STAY_SECONDS,
	EXTENSION_CAPACITY_LEVELS = Economy.EXTENSION_CAPACITY_LEVELS,
	-- Shop
	ITEM_SLOT_ORDER = Shop.ITEM_SLOT_ORDER,
	ITEM_SLOTS = Shop.ITEM_SLOTS,
	ITEM_USE_COOLDOWN_SECONDS = Shop.ITEM_USE_COOLDOWN_SECONDS,
	ITEM_POWER_SETTINGS = Shop.ITEM_POWER_SETTINGS,
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
	GOODS_CONTRACTS = Goods.GOODS_CONTRACTS,
	GOODS_SELL = Goods.GOODS_SELL,
	GOODS_FULL_WARNING = Goods.GOODS_FULL_WARNING,
	GOODS_BARTER = Goods.GOODS_BARTER,
	-- Audio
	SOUNDS = Audio.SOUNDS,
	AMBIENCE = Audio.AMBIENCE,
	MUSIC = Audio.MUSIC,
	AUDIO_DEFAULTS = Audio.AUDIO_DEFAULTS,
	ANIMAL_SOUNDS = Audio.ANIMAL_SOUNDS,
	-- Islands
	GROWTH_SECONDS = Islands.GROWTH_SECONDS,
	GROWTH_SPEED_KNEE = Islands.GROWTH_SPEED_KNEE,
	GROWTH_SPEED_CAP = Islands.GROWTH_SPEED_CAP,
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
	-- Hayvan türü tablosu (Species.luau): yeni hayvanların kaynağı
	SPECIES = Species.SPECIES,
	-- Animals
	ZONE_ORDER = Animals.ZONE_ORDER,
	ZONES = Animals.ZONES,
	ANIMAL_ORDER = Animals.ANIMAL_ORDER,
	ANIMALS = Animals.ANIMALS,
	STAGE_INCOME_MULTIPLIER = Animals.STAGE_INCOME_MULTIPLIER,
	STAGE_DISPLAY = Animals.STAGE_DISPLAY,
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

-- Adada yaşayan hayvan: ana adada çiftliğin ana hayvanı, küçük adalarda FARM_ISLANDS[ada].animalId (balık kafesi ayrı bir bölgedir)
function Config.getIslandAnimal(farmId: string?, islandId: string): string?
	if islandId == "home" then
		return Config.getHomeAnimal(farmId)
	end
	local island = Config.FARM_ISLANDS[islandId]
	return if island then island.animalId else nil
end

-- Hayvanın yaşadığı çiftlik (tema numarası); hiçbir temada yaşamayan hayvan (hamsi, levrek) için nil. Hayvan -> ada -> çiftlik eşlemesi THEMES'ten türer.
function Config.getAnimalTheme(animalId: string): number?
	for index, theme in Config.THEMES do
		if theme.homeAnimal == animalId then
			return index
		end
		for _, islandId in theme.satellites do
			if Config.getIslandAnimal(tostring(index), islandId) == animalId then
				return index
			end
		end
	end
	return nil
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
-- kind = "level" (harita yapı noktası istemez); "tüm yol haritası" sayımı bunları saymaz.
type LevelChain = {
	id: string,
	displayName: string,
	description: string,
	icon: string,
	requires: string,
	costs: { number },
	effect: string,
	amount: number,
	goodsCost: Types.GoodsCostConfig?,
}
local LEVEL_CHAINS: { LevelChain } = {
	{
		id = "feed_quality",
		displayName = "Yem Kalitesi",
		description = "Tüm hayvanların geliri +%8",
		icon = "🌾",
		requires = "silo",
		costs = { 1200, 3000, 7500, 15000, 28000 },
		effect = "income",
		amount = 0.08,
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
	-- Pasif Gelir (çevrimdışı gelir): çevrimdışı kazanç oranını ve süresini artırır (Config.OFFLINE_UPGRADED_*).
	-- Yalnızca bir yetenek: etkisi FarmMath.hasOfflineIncome / getOfflineTerms.
	{
		id = "offline_income",
		displayName = "Pasif Gelir",
		description = `Çevrimdışı kazanç %{math.floor(Economy.OFFLINE_EARNING_RATE * 100 + 0.5)}'ten %{math.floor(
			Economy.OFFLINE_UPGRADED_EARNING_RATE * 100 + 0.5
		)}'ye, süre {Economy.OFFLINE_MAX_HOURS} saatten {Economy.OFFLINE_UPGRADED_MAX_HOURS} saate çıkar`,
		icon = "💤",
		requires = "barn_2",
		costs = { 6000 },
		effect = "offline",
		amount = 0,
		goodsCost = { step = 3, shares = { home = 0.02, slot1 = 0.02 } },
	},
	-- Yardımcılar (pet): çiftlik başına. Para yardımcısı para fabrikalarını, ürün yardımcısı ürün merkezlerini
	-- "otomatik tekrarla" işaretli olduğunda kendisi teslim alır ve yeniden başlatır (PetService).
	{
		id = "pet_cash",
		displayName = "Para Yardımcısı",
		description = "Biten para partisini senin yerine alır. Otomatik üretim açıksa yenisini de başlatır.",
		icon = "🐕",
		requires = "silo",
		costs = { 12000 },
		effect = "pet",
		amount = 0,
		goodsCost = { step = 3, shares = { home = 0.02, slot1 = 0.02 } },
	},
	{
		id = "pet_goods",
		displayName = "Ürün Yardımcısı",
		description = "Biten ürün partisini senin yerine depoya alır. Otomatik üretim açıksa yenisini de başlatır.",
		icon = "🐈",
		requires = "silo",
		costs = { 15000 },
		effect = "pet",
		amount = 0,
		goodsCost = { step = 3, shares = { home = 0.02, slot2 = 0.02 } },
	},
	{
		id = "fast_growth",
		displayName = "Hızlı Büyüme",
		description = "Hayvanlar %25 daha hızlı büyür",
		icon = "⏩",
		requires = "silo",
		costs = { 2000, 6000, 15000 },
		effect = "growth",
		amount = 1.25,
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
		if level == 1 and chain.goodsCost then
			upgrade.goodsCost = chain.goodsCost -- yalnızca zincirin ilk seviyesi (yetenek) ürün ister
		end
		if chain.effect == "income" then
			local boost: { [string]: number } = {}
			for animalId in Config.ANIMALS do
				boost[animalId] = chain.amount
			end
			upgrade.incomeBoost = boost
		elseif chain.effect == "storage" then
			upgrade.storageBonus = chain.amount
		elseif chain.effect == "pet" or chain.effect == "offline" then
			-- Yalnızca bir yetenek: etkisi PetService'te (FarmMath.hasPet)
			upgrade.description = chain.description
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
				costCurve = base.costCurve,
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
-- Yeni oyuncunun başlangıç parası: çiftliğin ana hayvanından (inek/tavuk/ördek) tam bir tane alacak kadar.
function Config.getStartingCash(farmId: string?): number
	local animal = Config.ANIMALS[Config.getHomeAnimal(farmId)]
	return if animal then animal.price else Config.STARTING_CASH
end

-- Hayvanın bu çiftlikteki görünümü: balıklarda (anchovy/seabass) çiftlik temasının balığı (THEMES[n].fish), diğerlerinde ANIMALS satırı.
-- modelId = assets/Animals/<modelId>.rbxmx. Fiyat/gelir/kayıt kimliği değişmez (animalId aynı kalır).
export type AnimalLook = { displayName: string, icon: string, product: string, modelId: string }
function Config.getAnimalLook(animalId: string, farmId: string?): AnimalLook
	local skins = Config.getTheme(farmId).fish
	local skin = if skins then skins[animalId] else nil
	if skin then
		return { displayName = skin.displayName, icon = skin.icon, product = skin.product, modelId = skin.id }
	end
	local animal = Config.ANIMALS[animalId]
	if animal then
		return { displayName = animal.displayName, icon = animal.icon, product = animal.product, modelId = animalId }
	end
	return { displayName = animalId, icon = "🐾", product = "", modelId = animalId }
end

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
	upgrade.cost = if upgrade.costCurve == false then upgrade.cost else curvedCost(upgrade.cost)
end
-- Ek ana çiftlikler de aynı eğriyle (yazılı değerler taban fiyattır); ilki ücretsizdir
for index, price in Config.MAIN_FARM_PRICES do
	Config.MAIN_FARM_PRICES[index] = curvedCost(price)
end

-- Eşya tanımları (Config/Items.luau): fiyat ve dengeyi ordan düzenle.
Items.install(Config.ITEMS, Config.ITEM_ORDER)

local convenienceNames =
	{ auto_collect = "Otomatik Toplayıcı", pet_cash = "Para Yardımcısı", pet_goods = "Ürün Yardımcısı" }
for id, offer in Config.PROGRESSION.permanentOffers do
	local item = if offer.kind == "item" then Config.ITEMS[(offer :: any).itemId] else nil
	Config.PRODUCTS.products[`permanent_{id}`] = {
		id = offer.robuxProductId or 0,
		displayName = if item then item.displayName else convenienceNames[id],
		description = "Kalıcı. Altınla da alabilirsin.",
		icon = if item then item.icon else "🎁",
		effect = "permanentOffer",
		offerId = id,
		lifetime = "permanent",
	}
end

-- Eşyanın satış kanalı (tek kaynak): `reward` (rebirth ödülü), `cash` (yalnız nakit, tur içi), `cashGold` (nakit tur içi ya da kalıcı teklif),
-- `goldRobux` (nakit yok; kalıcı teklif altın ya da Robux), `gold` (nakit yok; yalnız altın). Kalıcı teklif `Config/Progression.permanentOffers`.
local offerByItem: { [string]: any } = {}
for _, offer in Config.PROGRESSION.permanentOffers do
	if offer.kind == "item" then
		offerByItem[(offer :: any).itemId] = offer
	end
end

-- Nakitle satın alınabilir mi (tur içi satış; gezgin tüccar ve Pazar'ın nakit listesi de bunu kullanır)
function Config.isCashItem(item: ItemConfig): boolean
	return not item.rewardOnly and not item.noCash and item.price > 0
end

function Config.getItemChannel(itemId: string): string
	local item = Config.ITEMS[itemId]
	if not item then
		return "none"
	end
	if item.rewardOnly then
		return "reward"
	end
	local offer = offerByItem[itemId]
	local robux = offer ~= nil and (offer.robuxProductId or 0) ~= 0
	if item.noCash then
		return if robux then "goldRobux" elseif offer then "gold" else "none"
	end
	return if offer then "cashGold" else "cash"
end

function Config.getUpgrade(id: string): UpgradeConfig?
	for _, upgrade in Config.UPGRADES do
		if upgrade.id == id then
			return upgrade
		end
	end
	return nil
end

-- Telemetri SKU'su (Roblox: deneyim başına en çok 100): önemli açılışlar (ada, ahır, bölge) kimliğiyle, diğer yükseltmeler türüyle ("boost", "level",
-- "extension") raporlanır; içerik büyüse de SKU sayısı sınırlı kalır (tests/telemetry.spec.luau denetler).
local SKU_BY_ID_KINDS: { [string]: boolean } = { island = true, barn = true, zone = true }
function Config.getUpgradeSku(upgrade: UpgradeConfig): string
	return if SKU_BY_ID_KINDS[upgrade.kind] then upgrade.id else upgrade.kind
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
	if upgrade.island then
		return upgrade.island
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
		duck_packer = "home",
		fish_farm = "home",
		fishing_boat = "home",
		auto_collector = "home",
		egg_factory = "poultry",
		hatchery = "poultry",
		golden_horseshoe = "horse",
		horse_training = "horse",
		cheese_dairy = "goat",
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

-- Yükseltme bu çiftliğin temasında var mı? Adası temada olmalı; ana ada fabrikalarında (`homeAnimal`) çiftliğin ana hayvanı da eşleşmeli:
-- ana adada yalnızca ana hayvanın fabrikası kurulur (inek: süt, tavuk: yumurta, ördek: ördek yumurtası).
function Config.upgradeInTheme(upgrade: UpgradeConfig, farmId: string?): boolean
	if upgrade.homeAnimal ~= nil and upgrade.homeAnimal ~= Config.getHomeAnimal(farmId) then
		return false
	end
	return Config.themeHasIsland(farmId, Config.getUpgradeIsland(upgrade))
end

-- Hayvan türünün ürünü (GOODS.animalId); ürünü olmayan tür (hamsi) için nil
function Config.getAnimalGoods(animalId: string): string?
	for goodsId, good in Config.GOODS do
		if good.animalId == animalId then
			return goodsId
		end
	end
	return nil
end

-- Çiftlikte bir adanın ürünü: adadaki ilk uygun bölgenin hayvanının ürünü (ana adada çiftliğin ana hayvanı; balık kafesi ayrıdır: "sea")
function Config.getIslandGoods(farmId: string?, islandId: string): string?
	for _, zoneId in Config.ZONE_ORDER do
		local zone = Config.ZONES[zoneId]
		if zone.island == islandId and zoneId ~= "fishpen" then
			for _, animalId in Config.getZoneAnimals(zone, farmId) do
				local goodsId = Config.getAnimalGoods(animalId)
				if goodsId then
					return goodsId
				end
			end
		end
	end
	return nil
end

-- Açılış gereksinimi kaynağını (goodsCost.shares anahtarı) çiftlikteki ürüne çevirir; çözülemezse nil.
-- islandId: gereksinimin ait olduğu ada ("previous" için).
function Config.resolveGoodsSource(farmId: string?, source: string, islandId: string?): string?
	local satellites = Config.getTheme(farmId).satellites
	if source == "home" then
		return Config.getIslandGoods(farmId, "home")
	elseif source == "sea" then
		return Config.getAnimalGoods("seabass")
	elseif source == "previous" then
		local slot = if islandId then table.find(satellites, islandId) else nil
		if slot and slot > 1 then
			return Config.getIslandGoods(farmId, satellites[slot - 1])
		end
		return Config.getIslandGoods(farmId, "home")
	end
	local slotNumber = tonumber(string.match(source, "^slot(%d)$"))
	local island = if slotNumber then satellites[slotNumber] else nil
	return if island then Config.getIslandGoods(farmId, island) else nil
end

-- Bir yükseltmeye ulaşmak için gereken en düşük ahır seviyesi (ön koşul zincirindeki ahır yükseltmeleri; kendisi hariç). Ürün gereksinimi
-- bu seviyedeki ürün kapasitesine sığmak zorundadır (FarmMath.getGoodsCost).
local minBarnCache: { [string]: number } = {}
function Config.getMinBarnLevel(upgradeId: string): number
	local cached = minBarnCache[upgradeId]
	if cached then
		return cached
	end
	minBarnCache[upgradeId] = 1 -- döngüye karşı
	local level = 1
	local upgrade = Config.getUpgrade(upgradeId)
	if upgrade then
		for _, requiredId in upgrade.requires do
			local required = Config.getUpgrade(requiredId)
			if required then
				level = math.max(level, required.barnLevel or 1, Config.getMinBarnLevel(requiredId))
			end
		end
	end
	minBarnCache[upgradeId] = level
	return level
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
