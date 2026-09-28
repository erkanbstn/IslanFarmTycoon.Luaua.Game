--!strict
-- Hem sunucu hem client'ın okuyabildiği sabit ayarlar.
-- Gizli bilgi koyma: ReplicatedStorage client'a da gider.

export type ZoneConfig = {
	id: string,
	displayName: string,
	icon: string,
	island: string, -- Hangi çiftlik adasında (FARM_ISLANDS id)
	capacity: number,
	allowedAnimals: { string },
}

export type ProductionRecipeConfig = {
	id: string,
	displayName: string,
	description: string,
	icon: string,
	island: string,
	upgradeId: string,
	animalId: string,
	animalIds: { string },
	requiredAdults: number,
	duration: number,
	cost: number,
	reward: number,
	output: "cash" | "chicken",
}

export type AnimalConfig = {
	id: string,
	displayName: string,
	icon: string,
	product: string, -- Ürettiği şey (arayüzde gösterilir)
	price: number, -- İlk hayvanın fiyatı; her sahip olunan aynı türle ANIMAL_PRICE_GROWTH kadar artar
	baseIncomePerSecond: number,
}

export type BarnLevelConfig = {
	level: number,
	displayName: string,
	barnScale: number,
	storageCap: number, -- Depoda birikebilecek en fazla para
	incomeMultiplier: number, -- Tüm gelire uygulanır
}

-- Oyuncunun takımadasındaki adalar. "home" herkese ücretsiz; diğerleri yol haritasından açılır
-- ve her biri yeni bir hayvanı + kendine özel bir bonusu getirir.
export type FarmIslandConfig = {
	id: string,
	displayName: string,
	icon: string,
	trait: string, -- Adanın özelliği (tabelada ve arayüzde yazar)
	upgradeId: string?, -- Adayı açan yol haritası öğesi (home için nil)
}

-- Mevsim ve hava: hayvan türlerine göre gelir değişimi (0.2 = +%20, -0.1 = -%10)
export type SeasonConfig = {
	id: string,
	displayName: string,
	icon: string,
	incomeModifiers: { [string]: number },
	weather: { [string]: number }, -- Bu mevsimde görülebilecek havalar ve ağırlıkları
	grassColor: Color3,
}

export type WeatherConfig = {
	id: string,
	displayName: string,
	icon: string,
	incomeModifiers: { [string]: number },
}

-- Yol haritası aşaması: bir adaya (island) ya da bağımsız bir dala (ör. Deniz) ait olabilir
export type RoadmapStage = {
	name: string,
	island: string?, -- FARM_ISLANDS id; varsa arayüz adanın özelliğini gösterir
	description: string?, -- Adası olmayan aşamanın açıklaması
}

-- Yol haritasındaki satın alınabilir her şey. Oyuncu sırayı kendisi seçer;
-- sadece "requires" içindekilere önce sahip olmak gerekir.
export type UpgradeConfig = {
	id: string,
	displayName: string,
	description: string,
	icon: string,
	stage: number, -- Yol haritasında hangi aşamada (ROADMAP_STAGES) gösterilir
	cost: number,
	requires: { string },
	kind: string, -- "barn" | "zone" | "island" | "boost"
	barnLevel: number?, -- kind == "barn"
	zoneId: string?, -- kind == "zone"
	islandId: string?, -- kind == "island"
	incomeBoost: { [string]: number }?, -- animalId -> ek gelir (0.5 = +%50)
	growthSpeed: number?, -- Tüm hayvanların büyüme hızı çarpanı
	growthBoost: { [string]: number }?, -- animalId -> büyüme hızı çarpanı
	storageBonus: number?, -- Depo kapasitesine ek (0.25 = +%25)
	autoCollect: boolean?, -- Depo yerine para doğrudan kasaya
	extensionId: string?, -- kind == "extension" → Config.EXTENSIONS
}

export type ExtensionConfig = {
	id: string,
	displayName: string,
	description: string,
	icon: string,
	island: string,
	sourceZoneId: string,
	animalId: string,
	capacity: number,
	incomeBonus: number, -- 0.5 = +%50 gelir (eklentideki hayvanlar)
}

local Config = {
	GAME_NAME = "Ahır Tycoon",
	VERSION = "0.8.0",
	MAIN_FARM_LIMIT = 6,
	MAIN_FARM_PRICES = { 0, 5000, 12000, 25000, 50000, 100000 },
	DEBUG = false,

	-- Harita normalde Studio'da "Ahır Tycoon → Haritayı Kur" butonuyla kurulup place'e kaydedilir.
	-- true  → Place'te harita yoksa oyun başlarken kodla kurulur (güvenlik ağı).
	-- false → Harita yoksa açılış durdurulur; eksik dünyada oyuncu oturumu başlamaz.
	MAP_AUTO_BUILD = true,
	MAP_PLOT_COUNT = 6, -- Çiftlik sayısı = sunucudaki en fazla oyuncu (Game Settings'te Max Players'ı buna eşitle)
	ISLAND_RING_RADIUS = 175, -- Ana adaların merkezdeki meydana uzaklığı

	-- Oyuncuların ana adalarının isimleri (sırayla). MAP_PLOT_COUNT'tan azsa kalanlar "Ada N" olur.
	PLOT_NAMES = {
		{ name = "Papatya Adası", icon = "🌼" },
		{ name = "Lale Adası", icon = "🌷" },
		{ name = "Ayçiçeği Adası", icon = "🌻" },
		{ name = "Gül Adası", icon = "🌹" },
		{ name = "Yonca Adası", icon = "🍀" },
		{ name = "Kiraz Adası", icon = "🍒" },
	} :: { { name: string, icon: string } },

	-- Kayıt (DataStore). Studio'da çalışması için: Game Settings → Security → Enable Studio Access to API Services
	DATASTORE_NAME = "AhirTycoon_v1",
	AUTOSAVE_SECONDS = 60,

	-- Hareket: Shift basılıyken (telefonda "Koş" düğmesiyle) koşu hızı
	WALK_SPEED = 16,
	SPRINT_SPEED = 48, -- Yürümenin 3 katı

	-- Yeni oyuncuya ücretsiz: ana ada, Küçük Ahır (Sv.1), İnek Ağılı ve bu kadar inek
	STARTING_COW_COUNT = 2,
	STARTING_CASH = 50,

	INCOME_TICK_SECONDS = 1,
	MAX_INCOME_CATCHUP_SECONDS = 60,
	FISH_REPLACEMENT_REFUND_RATE = 0.5,
	ORDER_UNITS = 12,
	ORDER_PRODUCTION_SECONDS = 15,
	ORDER_REWARD_MULTIPLIER = 0.5,

	-- Mevsimler sırayla döner; tüm sunucularda aynı anda değişir (saat os.time'a bağlı).
	-- Hava her sunucuda rastgele, mevsime uygun olarak birkaç dakikada bir değişir.
	SEASON_SECONDS = 900, -- 15 dakika; dört mevsimlik döngü bir saat sürer.
	WEATHER_SECONDS_MIN = 150,
	WEATHER_SECONDS_MAX = 270,
	SEASONS = {
		{
			id = "spring",
			displayName = "İlkbahar",
			icon = "🌸",
			incomeModifiers = { cow = 0.2, chicken = 0.25 },
			weather = { sunny = 4, cloudy = 3, rain = 3 },
			grassColor = Color3.fromRGB(106, 168, 74),
		},
		{
			id = "summer",
			displayName = "Yaz",
			icon = "☀️",
			incomeModifiers = { anchovy = 0.3, seabass = 0.3, horse = 0.15, cow = -0.1 },
			weather = { sunny = 6, cloudy = 2, storm = 1 },
			grassColor = Color3.fromRGB(128, 170, 70),
		},
		{
			id = "autumn",
			displayName = "Sonbahar",
			icon = "🍂",
			incomeModifiers = { horse = 0.25, goat = 0.2, chicken = -0.1 },
			weather = { cloudy = 4, rain = 3, storm = 2, sunny = 2 },
			grassColor = Color3.fromRGB(150, 150, 75),
		},
		{
			id = "winter",
			displayName = "Kış",
			icon = "❄️",
			incomeModifiers = { goat = 0.3, cow = 0.15, chicken = -0.2, anchovy = -0.2, seabass = -0.2 },
			weather = { snow = 4, cloudy = 3, sunny = 2 },
			grassColor = Color3.fromRGB(175, 190, 180),
		},
	} :: { SeasonConfig },
	WEATHER = {
		sunny = { id = "sunny", displayName = "Güneşli", icon = "☀️", incomeModifiers = {} },
		cloudy = { id = "cloudy", displayName = "Bulutlu", icon = "☁️", incomeModifiers = {} },
		rain = {
			id = "rain",
			displayName = "Yağmurlu",
			icon = "🌧️",
			incomeModifiers = { cow = 0.1, horse = 0.1, goat = 0.1 },
		},
		storm = {
			id = "storm",
			displayName = "Fırtına",
			icon = "⛈️",
			incomeModifiers = { anchovy = -0.3, seabass = -0.3, chicken = -0.1 },
		},
		snow = {
			id = "snow",
			displayName = "Karlı",
			icon = "🌨️",
			incomeModifiers = { goat = 0.1, chicken = -0.1 },
		},
	} :: { [string]: WeatherConfig },

	-- Oyuncu yokken de depo dolar: normal gelirin bu oranı kadar, en fazla bu kadar saat için.
	-- Depo sınırı yine geçerli, yani büyük ahır = daha çok çevrimdışı kazanç.
	OFFLINE_EARNING_RATE = 0.5,
	OFFLINE_MAX_HOURS = 8,
	ANIMAL_PRICE_GROWTH = 1.1,

	-- Bir hayvanın her evrede kaldığı süre (saniye). Yetişkin olunca tam gelir verir.
	GROWTH_SECONDS = {
		calf = 45,
		young = 90,
	},

	BARN_LEVELS = {
		{ level = 1, displayName = "Küçük Ahır", barnScale = 1, storageCap = 250, incomeMultiplier = 1 },
		{ level = 2, displayName = "Genişletilmiş Ahır", barnScale = 1.2, storageCap = 900, incomeMultiplier = 1.2 },
		{ level = 3, displayName = "Çiftlik Ahırı", barnScale = 1.45, storageCap = 3000, incomeMultiplier = 1.4 },
		{ level = 4, displayName = "Büyük Çiftlik", barnScale = 1.7, storageCap = 10000, incomeMultiplier = 1.7 },
	} :: { BarnLevelConfig },

	FARM_ISLAND_ORDER = { "home", "poultry", "horse", "goat" },
	FARM_ISLANDS = {
		home = {
			id = "home",
			displayName = "Ana Ada",
			icon = "🐄",
			trait = "İnek çiftliğin ve ahırın burada",
		},
		poultry = {
			id = "poultry",
			displayName = "Tavuk Adası",
			icon = "🐔",
			trait = "Tavuklar burada 2 kat hızlı büyür",
			upgradeId = "island_poultry",
		},
		horse = {
			id = "horse",
			displayName = "At Adası",
			icon = "🐎",
			trait = "Hara: atlar +%25 gelir getirir",
			upgradeId = "island_horse",
		},
		goat = {
			id = "goat",
			displayName = "Keçi Adası",
			icon = "🐐",
			trait = "Serin iklim: depo kapasitesi +%25",
			upgradeId = "island_goat",
		},
	} :: { [string]: FarmIslandConfig },

	-- Yol haritası aşamaları: adalar + onlarla paralel ilerleyen Deniz dalı
	ROADMAP_STAGES = {
		{ name = "Ana Ada", island = "home" },
		{ name = "Deniz", description = "Balık kafesinde hamsi ve levrek yetiştir" },
		{ name = "Tavuk Adası", island = "poultry" },
		{ name = "At Adası", island = "horse" },
		{ name = "Keçi Adası", island = "goat" },
	} :: { RoadmapStage },

	UPGRADES = {
		-- Aşama 1: Ana ada — ilk tercih: daha çok yer mi, daha büyük ahır mı, hızlı büyüme mi?
		{
			id = "zone_pasture",
			displayName = "Otlak",
			description = "+8 inek yeri",
			icon = "🌾",
			stage = 1,
			cost = 300,
			requires = {},
			kind = "zone",
			zoneId = "pasture",
		},
		{
			id = "silo",
			displayName = "Yem Silosu",
			description = "Tüm hayvanlar 2 kat hızlı büyür",
			icon = "🌽",
			stage = 1,
			cost = 450,
			requires = {},
			kind = "boost",
			growthSpeed = 2,
		},
		{
			id = "barn_2",
			displayName = "Ahır Sv.2",
			description = "Tüm gelir x1.2 · Depo 900",
			icon = "🏚️",
			stage = 1,
			cost = 500,
			requires = {},
			kind = "barn",
			barnLevel = 2,
		},
		{
			id = "milk_machine",
			displayName = "Süt Makinesi",
			description = "İnek geliri +%50",
			icon = "🥛",
			stage = 1,
			cost = 1200,
			requires = { "zone_pasture" },
			kind = "boost",
			incomeBoost = { cow = 0.5 },
		},
		-- Aşama 2: Deniz (adalarla paralel dal)
		{
			id = "fish_farm",
			displayName = "Balık Kafesi",
			description = "Denizde 10 balık yeri: hamsi ve levrek",
			icon = "🐟",
			stage = 2,
			cost = 1000,
			requires = { "barn_2" },
			kind = "zone",
			zoneId = "fishpen",
		},
		{
			id = "fishing_boat",
			displayName = "Balıkçı Teknesi",
			description = "Balık geliri +%50",
			icon = "⛵",
			stage = 2,
			cost = 5000,
			requires = { "fish_farm" },
			kind = "boost",
			incomeBoost = { anchovy = 0.5, seabass = 0.5 },
		},
		-- Aşama 3: Tavuk Adası
		{
			id = "island_poultry",
			displayName = "Tavuk Adası",
			description = "Tavuk açılır · Tavuklar 2 kat hızlı büyür",
			icon = "🐔",
			stage = 3,
			cost = 900,
			requires = { "barn_2" },
			kind = "island",
			islandId = "poultry",
			growthBoost = { chicken = 2 },
		},
		{
			id = "barn_3",
			displayName = "Ahır Sv.3",
			description = "Tüm gelir x1.4 · Depo 3.000 · At Adası için gerekli",
			icon = "🏠",
			stage = 1,
			cost = 1800,
			requires = { "barn_2" },
			kind = "barn",
			barnLevel = 3,
		},
		{
			id = "egg_factory",
			displayName = "Yumurta Fabrikası",
			description = "Tavuk geliri +%60",
			icon = "🥚",
			stage = 3,
			cost = 2500,
			requires = { "island_poultry" },
			kind = "boost",
			incomeBoost = { chicken = 0.6 },
		},
		-- Aşama 4: At Adası
		{
			id = "island_horse",
			displayName = "At Adası",
			description = "At açılır · Hara: atlar +%25 gelir",
			icon = "🐎",
			stage = 4,
			cost = 3500,
			requires = { "barn_3" },
			kind = "island",
			islandId = "horse",
			incomeBoost = { horse = 0.25 },
		},
		{
			id = "auto_collector",
			displayName = "Otomatik Toplayıcı",
			description = "Para depoya değil doğrudan kasana gelir",
			icon = "🤖",
			stage = 4,
			cost = 4000,
			requires = { "barn_3" },
			kind = "boost",
			autoCollect = true,
		},
		{
			id = "golden_horseshoe",
			displayName = "Altın Nal",
			description = "At geliri +%75",
			icon = "🏆",
			stage = 4,
			cost = 8000,
			requires = { "island_horse" },
			kind = "boost",
			incomeBoost = { horse = 0.75 },
		},
		-- Aşama 5: Keçi Adası
		{
			id = "barn_4",
			displayName = "Ahır Sv.4",
			description = "Tüm gelir x1.7 · Depo 10.000",
			icon = "🏰",
			stage = 1,
			cost = 6000,
			requires = { "barn_3" },
			kind = "barn",
			barnLevel = 4,
		},
		{
			id = "island_goat",
			displayName = "Keçi Adası",
			description = "Keçi açılır · Depo kapasitesi +%25",
			icon = "🐐",
			stage = 5,
			cost = 7500,
			requires = { "island_horse" },
			kind = "island",
			islandId = "goat",
			storageBonus = 0.25,
		},
		{
			id = "cheese_dairy",
			displayName = "Peynirhane",
			description = "Keçi geliri 2 katı · Peynir partisi üretimi",
			icon = "🧀",
			stage = 5,
			cost = 12000,
			requires = { "island_goat" },
			kind = "boost",
			incomeBoost = { goat = 1 },
		},

		{
			id = "milk_factory",
			displayName = "Süt Fabrikası",
			description = "İnek geliri +%150 · Paketli süt üretimi",
			icon = "🥛",
			stage = 3,
			cost = 6000,
			requires = { "milk_machine", "barn_3" },
			kind = "boost",
			incomeBoost = { cow = 1.5 },
		},
		{
			id = "hatchery",
			displayName = "Kuluçkahane",
			description = "Yumurtadan civciv üret; büyüt veya sat",
			icon = "🐣",
			stage = 3,
			cost = 2800,
			requires = { "island_poultry" },
			kind = "boost",
		},
		{
			id = "horse_training",
			displayName = "At Eğitim Alanı",
			description = "Atları antrenmana gönder; yarış ödülü kazan",
			icon = "🏇",
			stage = 4,
			cost = 5500,
			requires = { "island_horse" },
			kind = "boost",
		},
		{
			id = "ext_folluk_garden",
			displayName = "Folluk Bahçesi",
			description = "6 tavuk · kümes yerini boşaltır · +%50 gelir",
			icon = "🐔",
			stage = 3,
			cost = 1400,
			requires = { "island_poultry" },
			kind = "extension",
			extensionId = "folluk_garden",
		},
		{
			id = "ext_training_course",
			displayName = "Koşu ve Engel Parkuru",
			description = "4 at · hara yerini boşaltır · +%50 gelir",
			icon = "🏇",
			stage = 4,
			cost = 2200,
			requires = { "island_horse" },
			kind = "extension",
			extensionId = "training_course",
		},
		{
			id = "ext_rocky_terraces",
			displayName = "Kayalık Otlak Terasları",
			description = "5 keçi · ağıl yerini boşaltır · +%50 gelir",
			icon = "🐐",
			stage = 5,
			cost = 3200,
			requires = { "island_goat" },
			kind = "extension",
			extensionId = "rocky_terraces",
		},
	} :: { UpgradeConfig },

	EXTENSIONS = {
		folluk_garden = {
			id = "folluk_garden",
			displayName = "Folluk Bahçesi",
			description = "Kümes dışı tavuklar",
			icon = "🐔",
			island = "poultry",
			sourceZoneId = "poultry",
			animalId = "chicken",
			capacity = 6,
			incomeBonus = 0.5,
		},
		training_course = {
			id = "training_course",
			displayName = "Koşu Parkuru",
			description = "Antrenman atları",
			icon = "🏇",
			island = "horse",
			sourceZoneId = "stable",
			animalId = "horse",
			capacity = 4,
			incomeBonus = 0.5,
		},
		rocky_terraces = {
			id = "rocky_terraces",
			displayName = "Kayalık Teraslar",
			description = "Teras otlak keçileri",
			icon = "🐐",
			island = "goat",
			sourceZoneId = "goatpen",
			animalId = "goat",
			capacity = 5,
			incomeBonus = 0.5,
		},
	} :: { [string]: ExtensionConfig },

	-- Tek bir ücretli parti çevrimdışında tamamlanabilir; otomatik tekrar üretmez.
	PRODUCTION_ORDER = { "dairy", "hatchery", "horse_training", "cheese", "fish_dispatch" },
	PRODUCTION_RECIPES = {
		dairy = {
			id = "dairy",
			displayName = "Paketli Süt",
			description = "Sütü işle, paketle ve kasaları sat.",
			icon = "🥛",
			island = "home",
			upgradeId = "milk_factory",
			animalId = "cow",
			animalIds = { "cow" },
			requiredAdults = 2,
			duration = 60,
			cost = 160,
			reward = 650,
			output = "cash",
		},
		hatchery = {
			id = "hatchery",
			displayName = "Civciv Kuluçkası",
			description = "Bir civciv çıkar; kümesine ekle veya sat.",
			icon = "🐣",
			island = "poultry",
			upgradeId = "hatchery",
			animalId = "chicken",
			animalIds = { "chicken" },
			requiredAdults = 2,
			duration = 90,
			cost = 120,
			reward = 240,
			output = "chicken",
		},
		horse_training = {
			id = "horse_training",
			displayName = "At Antrenmanı",
			description = "Parkur antrenmanını tamamla, yarış ödülünü al.",
			icon = "🏇",
			island = "horse",
			upgradeId = "horse_training",
			animalId = "horse",
			animalIds = { "horse" },
			requiredAdults = 1,
			duration = 75,
			cost = 300,
			reward = 850,
			output = "cash",
		},
		cheese = {
			id = "cheese",
			displayName = "Peynir Partisi",
			description = "Keçi sütünü olgunlaştır ve peynir kasalarını sat.",
			icon = "🧀",
			island = "goat",
			upgradeId = "cheese_dairy",
			animalId = "goat",
			animalIds = { "goat" },
			requiredAdults = 2,
			duration = 100,
			cost = 500,
			reward = 1400,
			output = "cash",
		},
		fish_dispatch = {
			id = "fish_dispatch",
			displayName = "Balık Sevkiyatı",
			description = "Taze balıkları hazırla ve tekneyle pazara gönder.",
			icon = "🐟",
			island = "home",
			upgradeId = "fishing_boat",
			animalId = "anchovy",
			animalIds = { "anchovy", "seabass" },
			requiredAdults = 3,
			duration = 90,
			cost = 350,
			reward = 1050,
			output = "cash",
		},
	} :: { [string]: ProductionRecipeConfig },

	-- Bölgeler. Sıra önemli: hayvan alınınca ilk açık & boş alana konur.
	-- Bir bölge, adası açıksa ve (varsa) kendi yol haritası öğesi alınmışsa açıktır.
	ZONE_ORDER = { "starter", "pasture", "fishpen", "poultry", "stable", "goatpen" },
	ZONES = {
		starter = {
			id = "starter",
			displayName = "İnek Ağılı",
			icon = "🐄",
			island = "home",
			capacity = 6,
			allowedAnimals = { "cow" },
		},
		pasture = {
			id = "pasture",
			displayName = "Otlak",
			icon = "🌾",
			island = "home",
			capacity = 8,
			allowedAnimals = { "cow" },
		},
		fishpen = {
			id = "fishpen",
			displayName = "Balık Kafesi",
			icon = "🐟",
			island = "home",
			capacity = 10,
			allowedAnimals = { "anchovy", "seabass" },
		},
		poultry = {
			id = "poultry",
			displayName = "Kümes",
			icon = "🐔",
			island = "poultry",
			capacity = 12,
			allowedAnimals = { "chicken" },
		},
		stable = {
			id = "stable",
			displayName = "Hara",
			icon = "🐎",
			island = "horse",
			capacity = 6,
			allowedAnimals = { "horse" },
		},
		goatpen = {
			id = "goatpen",
			displayName = "Keçi Ağılı",
			icon = "🐐",
			island = "goat",
			capacity = 8,
			allowedAnimals = { "goat" },
		},
	} :: { [string]: ZoneConfig },

	ANIMAL_ORDER = { "cow", "anchovy", "chicken", "seabass", "horse", "goat" },
	ANIMALS = {
		cow = {
			id = "cow",
			displayName = "İnek",
			icon = "🐄",
			product = "Süt",
			price = 75,
			baseIncomePerSecond = 2,
		},
		anchovy = {
			id = "anchovy",
			displayName = "Hamsi",
			icon = "🐟",
			product = "Taze hamsi",
			price = 200,
			baseIncomePerSecond = 4,
		},
		seabass = {
			id = "seabass",
			displayName = "Levrek",
			icon = "🐠",
			product = "Levrek",
			price = 1500,
			baseIncomePerSecond = 16,
		},
		chicken = {
			id = "chicken",
			displayName = "Tavuk",
			icon = "🐔",
			product = "Yumurta",
			price = 350,
			baseIncomePerSecond = 5,
		},
		horse = {
			id = "horse",
			displayName = "At",
			icon = "🐎",
			product = "Yarış ödülü",
			price = 1200,
			baseIncomePerSecond = 12,
		},
		goat = {
			id = "goat",
			displayName = "Keçi",
			icon = "🐐",
			product = "Keçi sütü",
			price = 2500,
			baseIncomePerSecond = 22,
		},
	} :: { [string]: AnimalConfig },

	STAGE_INCOME_MULTIPLIER = {
		calf = 0.25,
		young = 0.6,
		adult = 1,
	} :: { [string]: number },

	STAGE_DISPLAY = {
		calf = "Yavru",
		young = "Genç",
		adult = "Yetişkin",
	} :: { [string]: string },

	-- Eski kayıtlardaki kaldırılmış yol haritası id'leri → yeni karşılıkları
	LEGACY_UPGRADES = {
		zone_poultry = "island_poultry",
		zone_stable = "island_horse",
	} :: { [string]: string },
}

function Config.getBarnLevelConfig(level: number): BarnLevelConfig?
	for _, entry in Config.BARN_LEVELS do
		if entry.level == level then
			return entry
		end
	end
	return nil
end

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
