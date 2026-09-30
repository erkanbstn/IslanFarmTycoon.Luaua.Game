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
	upgradeProfile: string?, -- BUILD_UPGRADES.profiles anahtarı (yoksa "barn")
	themed: boolean?, -- true: bölgenin hayvanı temanın ana ada hayvanıdır (homeAnimal)
}

-- Yapı geliştirme: her bölge (ahır, ağıl, kafes) ve her üretim tesisi 5 seviyelik bir yoldur; her seviye işlevine uygun bir fayda demeti verir.
-- Bölge: capacity (adım sayısı), growthSpeed (çarpan), incomeBonus (toplanır), seasonAffinity (olumlu mevsim/hava etkileri büyür, olumsuzlar küçülür).
-- Tesis: speed (süre çarpanı), yield (satış ödülü artışı), thrift (başlatma maliyeti indirimi).
export type BuildLevelEffects = {
	capacity: number?,
	growthSpeed: number?,
	incomeBonus: number?,
	seasonAffinity: number?,
	speed: number?,
	yield: number?,
	thrift: number?,
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
	upgradeProfile: string?, -- BUILD_UPGRADES.profiles anahtarı (yoksa "factory")
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
-- Ada teması: her ana çiftlik numarasının (= fiziksel ada numarası) kendi 3 küçük adası vardır.
-- satellites sırası = harita yuvası sırası (erken, orta, geç); hepsi FARM_ISLANDS'ta tanımlı olmalıdır.
export type ThemeConfig = {
	id: string,
	displayName: string,
	homeAnimal: string, -- Ana adanın ağıl ve otlağında yaşayan hayvan
	landmark: string, -- Ana adada doğu kıyıdaki tema işaret yapısı (HomeBuildings.landmark türü)
	satellites: { string },
}

-- Eşyalar (envanter): slotlara takılır, satın alma kalıcıdır. effects = takılıyken geçerli kalıcı faydalar (FarmMath),
-- power = asa gücü (Inventory), look = karakterde görünen parçalar (InventoryService). Vector3 yerine düz {x, y, z} tabloları.
export type ItemSlotConfig = { id: string, displayName: string, icon: string }
export type ItemPart = {
	shape: string?, -- "Block" | "Ball" | "Cylinder"
	size: { number },
	offset: { number },
	angle: { number }?, -- derece
	color: Color3,
	material: string?, -- Enum.Material adı
}
export type ItemLook = { attach: string, parts: { ItemPart } } -- attach: head | back | hip | chest | hand
export type ItemEffects = {
	upgradeDiscount: number?, -- Bütün yükseltme maliyetlerinden indirim (0.1 = %10)
	storageBonus: number?, -- Depo kapasitesi (0.15 = +%15)
	growthSpeed: number?, -- Büyüme hızı çarpanı (1.15 = %15 daha hızlı)
	incomeBonus: number?, -- Bütün gelir (0.03 = +%3)
}
export type ItemPower = { kind: string, usesPerDay: number? } -- kind: season | weather; usesPerDay nil = sınırsız
export type ItemConfig = {
	id: string,
	displayName: string,
	icon: string,
	slot: string,
	price: number,
	effects: ItemEffects?,
	power: ItemPower?,
	look: ItemLook?,
}

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
	eventName: string?, -- Mevsim etkinliği adı (sipariş ödülüne bonus verir)
	orderBonus: number?, -- Sipariş ödülü bonusu (0.3 = +%30)
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
	kind: string, -- "barn" | "zone" | "island" | "boost" | "extension" | "level"
	leveled: boolean?, -- kind == "level": seviyeli zincir; yol haritası "tamamlandı" sayımına girmez
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

export type AchievementConfig = {
	id: string,
	displayName: string,
	description: string,
	icon: string,
	metric: string, -- "cows" | "animals" | "islands" | "purchases" | "earned" | "orders"
	target: number,
	reward: number,
}

-- Oyun geçidi (gamepass) ve tek seferlik ürün (developer product). id = 0 → henüz Roblox'ta oluşturulmadı:
-- ürün mağazada gizlenir ve satın alınamaz. Fiyat Roblox tarafında belirlenir; burada yalnızca etki vardır.
export type ProductConfig = {
	id: number,
	displayName: string,
	description: string,
	icon: string,
	incomeMultiplier: number?, -- Geçit: tüm hayvan gelirine çarpan
	storageBonus: number?, -- Geçit: depo kapasitesine ek (0.5 = +%50)
	autoCollect: boolean?, -- Geçit: baştan otomatik toplayıcı
	effect: string?, -- Ürün: "instantProduction" | "incomePack"
	incomeHours: number?, -- Ürün: "incomePack" kaç saatlik gelir verir
}

export type SoundConfig = { id: string, volume: number, pitch: number? }

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
	GAME_NAME = "Island Farm Tycoon",
	VERSION = "0.8.0",
	MAIN_FARM_LIMIT = 6,

	-- Arayüz dilleri. Kaynak dil Türkçe; diğerleri src/shared/Locales/<kod>.luau içinde.
	-- countries: oyuncunun Roblox dili desteklenmiyorsa ülkesinden seçilen dil (ISO 3166-1 alpha-2).
	LANGUAGE_ORDER = { "tr", "en", "de", "ru" },
	-- Grafik tercihi (hesaba kaydedilir): auto = cihaza ve kare hızına göre otomatik
	GRAPHICS_MODES = { auto = true, low = true, medium = true, high = true } :: { [string]: boolean },
	LANGUAGES = {
		tr = { code = "tr", name = "Türkçe", countries = { "TR" } },
		en = { code = "en", name = "English", countries = {} },
		de = { code = "de", name = "Deutsch", countries = { "DE", "AT", "CH", "LI", "LU" } },
		ru = { code = "ru", name = "Русский", countries = { "RU", "BY", "KZ", "KG" } },
	} :: { [string]: { code: string, name: string, countries: { string } } },
	DEFAULT_LANGUAGE = "en",
	MAIN_FARM_PRICES = { 0, 5000, 12000, 25000, 50000, 100000 },
	DEBUG = false,

	-- Harita normalde Studio'da "Island Farm Tycoon → Haritayı Kur" butonuyla kurulup place'e kaydedilir.
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
	-- Yayından sonra bu ad DEĞİŞMEMELİ: değişirse mevcut oyuncu kayıtları bulunamaz.
	DATASTORE_NAME = "IslandFarmTycoon_v1",
	AUTOSAVE_SECONDS = 60,

	-- Hareket: Shift basılıyken (telefonda "Koş" düğmesiyle) koşu hızı
	WALK_SPEED = 16,
	SPRINT_SPEED = 48, -- Yürümenin 3 katı

	-- Yeni oyuncuya ücretsiz: ana ada, Küçük Ahır (Sv.1), İnek Ağılı ve bu kadar inek
	STARTING_COW_COUNT = 2,
	STARTING_CASH = 100,

	INCOME_TICK_SECONDS = 1,
	MAX_INCOME_CATCHUP_SECONDS = 60,
	FISH_REPLACEMENT_REFUND_RATE = 0.5,
	ORDER_UNITS = 12,
	ORDER_PRODUCTION_SECONDS = 15,
	ORDER_REWARD_MULTIPLIER = 0.5,
	-- Sipariş panosu: aynı anda 3 seçenek (kısa/orta/uzun). units = hedef birim, rewardFactor = ödül çarpanı.
	-- Seçenekler ORDER_BOARD_SECONDS'ta bir yenilenir (sunucu saatinden türetilir, herkeste aynı pencere).
	ORDER_TIERS = {
		{ id = "short", displayName = "Kısa", units = 6, rewardFactor = 1 },
		{ id = "medium", displayName = "Orta", units = 12, rewardFactor = 1.15 },
		{ id = "long", displayName = "Uzun", units = 24, rewardFactor = 1.4 },
	},
	ORDER_BOARD_SECONDS = 300,

	-- Mevsimler sırayla döner; tüm sunucularda aynı anda değişir (saat os.time'a bağlı).
	-- Hava her sunucuda rastgele, mevsime uygun olarak birkaç dakikada bir değişir.
	SEASON_SECONDS = 900, -- 15 dakika; dört mevsimlik döngü bir saat sürer.
	DAY_SECONDS = 480, -- Bir gün-gece döngüsü (24 oyun saati) gerçek 8 dakikadır; tüm sunucuda aynı anda ilerler.
	DAY_START_HOUR = 9, -- Sunucu saati 0 iken oyun saati
	WEATHER_SECONDS_MIN = 150,
	WEATHER_SECONDS_MAX = 270,
	SEASONS = {
		{
			id = "spring",
			displayName = "İlkbahar",
			icon = "🌸",
			incomeModifiers = { cow = 0.2, chicken = 0.25, duck = 0.2, sheep = 0.2 },
			weather = { sunny = 4, cloudy = 3, rain = 3 },
			eventName = "Bahar Şenliği",
			orderBonus = 0.15,
			grassColor = Color3.fromRGB(106, 168, 74),
		},
		{
			id = "summer",
			displayName = "Yaz",
			icon = "☀️",
			incomeModifiers = {
				anchovy = 0.3,
				seabass = 0.3,
				horse = 0.15,
				cow = -0.1,
				duck = 0.15,
				sheep = -0.1,
				pig = -0.1,
			},
			weather = { sunny = 6, cloudy = 2, storm = 1 },
			eventName = "Hasat Zamanı",
			orderBonus = 0.2,
			grassColor = Color3.fromRGB(128, 170, 70),
		},
		{
			id = "autumn",
			displayName = "Sonbahar",
			icon = "🍂",
			incomeModifiers = { horse = 0.25, goat = 0.2, chicken = -0.1, pig = 0.25, sheep = 0.1 },
			weather = { cloudy = 4, rain = 3, storm = 2, sunny = 2 },
			eventName = "Sonbahar Pazarı",
			orderBonus = 0.2,
			grassColor = Color3.fromRGB(150, 150, 75),
		},
		{
			id = "winter",
			displayName = "Kış",
			icon = "❄️",
			incomeModifiers = {
				goat = 0.3,
				cow = 0.15,
				chicken = -0.2,
				anchovy = -0.2,
				seabass = -0.2,
				sheep = 0.2,
				duck = -0.15,
				pig = 0.05,
			},
			weather = { snow = 4, cloudy = 3, sunny = 2 },
			eventName = "Kış Festivali",
			orderBonus = 0.3,
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

	-- Oyuncu yokken kazanç doğrudan kasaya eklenir: normal gelirin bu oranı kadar, en fazla bu kadar saat için.
	-- Üst sınır depo kapasitesinin OFFLINE_STORAGE_MULTIPLIER katıdır; büyük ahır = daha çok çevrimdışı kazanç.
	OFFLINE_EARNING_RATE = 0.5,
	OFFLINE_MAX_HOURS = 8,
	OFFLINE_STORAGE_MULTIPLIER = 4,
	-- Üretimde gerekenden fazla her yetişkin hayvan satış ödülünü bu oranda artırır (en fazla MAX kadar hayvan).
	PRODUCTION_BONUS_PER_ADULT = 0.25,
	PRODUCTION_MAX_BONUS_ADULTS = 12,
	ANIMAL_PRICE_GROWTH = 1.18,
	-- Yükseltme maliyet eğrisi: yazılı fiyatlar taban fiyattır; BASE üstündekiler (fiyat/BASE)^EXPONENT ile büyütülür
	-- (2 anlamlı basamağa yuvarlanır). Tempo hedefleri: scripts/simulate-economy.py ile ölçülür.
	UPGRADE_COST_BASE = 200,
	UPGRADE_COST_EXPONENT = 0.95,
	BULK_MULTIPLIERS = { 1, 2, 3, 5 }, -- Pazarda toplu alım çarpanları
	-- Yapı geliştirme (bölgeler ve tesisler): seviye n -> n+1 maliyeti, bölgede bölgedeki hayvanın taban fiyatı, tesiste tarifin satış ödülü
	-- x çarpan x büyüme^n (2 anlamlı basamak). Kapasite adımı = max(2, taban kapasite / 4). Bir seviye kapasite veriyorsa bölge dolu olmalıdır.
	-- Kayıt: save.expansions[hedefId] = seviye (hedef bölge ya da tarif kimliği).
	BUILD_UPGRADES = {
		maxLevel = 5,
		costMultiplier = 70,
		costGrowth = 2.2,
		facilityCostMultiplier = 25,
		facilityCostGrowth = 1.8,
		profiles = {
			barn = {
				{ capacity = 1 },
				{ capacity = 1, growthSpeed = 1.12 },
				{ incomeBonus = 0.05 },
				{ capacity = 1, incomeBonus = 0.03 },
				{ capacity = 1, growthSpeed = 1.15, seasonAffinity = 0.25 },
			},
			coop = {
				{ capacity = 1 },
				{ capacity = 1, growthSpeed = 1.12 },
				{ incomeBonus = 0.06 },
				{ capacity = 1, growthSpeed = 1.1 },
				{ capacity = 1, incomeBonus = 0.04, seasonAffinity = 0.2 },
			},
			stable = {
				{ capacity = 1 },
				{ incomeBonus = 0.05 },
				{ capacity = 1, growthSpeed = 1.12 },
				{ capacity = 1, incomeBonus = 0.06, seasonAffinity = 0.2 },
				{ capacity = 1, incomeBonus = 0.08 },
			},
			fold = {
				{ capacity = 1 },
				{ capacity = 1, growthSpeed = 1.1, incomeBonus = 0.03 },
				{ incomeBonus = 0.05, seasonAffinity = 0.25 },
				{ capacity = 1, incomeBonus = 0.05 },
				{ capacity = 1, growthSpeed = 1.12, incomeBonus = 0.04 },
			},
			sea = {
				{ capacity = 1 },
				{ capacity = 1, seasonAffinity = 0.3 },
				{ growthSpeed = 1.15 },
				{ capacity = 1, incomeBonus = 0.05 },
				{ capacity = 1, seasonAffinity = 0.35, incomeBonus = 0.06 },
			},
			factory = {
				{ speed = 0.9 },
				{ yield = 0.1 },
				{ thrift = 0.1 },
				{ speed = 0.88 },
				{ yield = 0.15, speed = 0.9 },
			},
			hatchery = {
				{ speed = 0.9 },
				{ thrift = 0.12 },
				{ speed = 0.88 },
				{ yield = 0.12 },
				{ speed = 0.9, yield = 0.1 },
			},
		} :: { [string]: { BuildLevelEffects } },
	},
	-- Irk geliştirme (oyun sonu para harcama yolu): her hayvan türü için ayrı, çiftlik başına seviye.
	-- Seviye n -> n+1 maliyeti = türün taban fiyatı x costMultiplier x costGrowth^n (2 anlamlı basamak).
	-- Getiri doğrusal (her seviye incomePerLevel), maliyet üstel: sonraki seviyeler giderek pahalı, sıra bir karardır.
	-- Eşyalar: hesap düzeyinde envanter. Slot başına bir eşya takılır; fiyatlar oyun parasıyladır (ITEMS aşağıda doldurulur).
	ITEM_SLOT_ORDER = { "tool", "staff", "charm", "head", "back" },
	ITEM_SLOTS = {
		tool = { id = "tool", displayName = "Alet", icon = "🔨" },
		staff = { id = "staff", displayName = "Asa", icon = "🪄" },
		charm = { id = "charm", displayName = "Muska", icon = "📿" },
		head = { id = "head", displayName = "Başlık", icon = "🎩" },
		back = { id = "back", displayName = "Sırt", icon = "🧥" },
	} :: { [string]: ItemSlotConfig },
	ITEM_USE_COOLDOWN_SECONDS = 20, -- Asa gücü iki kullanım arası en az bu kadar bekler (sınırsız asalar dahil)
	ITEMS = {} :: { [string]: ItemConfig },
	ITEM_ORDER = {} :: { string },
	LINEAGE = {
		maxLevel = 10,
		incomePerLevel = 0.08,
		costMultiplier = 50,
		costGrowth = 1.85,
	},

	-- Gelir modeli. Kimlikleri (id) Roblox Creator Hub'da ürünleri oluşturunca yaz; 0 = kapalı.
	PRODUCTS = {
		passes = {
			double_income = {
				id = 0,
				displayName = "2 Kat Gelir",
				description = "Bütün hayvanların geliri 2 kat",
				icon = "💎",
				incomeMultiplier = 2,
			},
			auto_collector = {
				id = 0,
				displayName = "Otomatik Toplayıcı",
				description = "Para kendiliğinden kasana gelir",
				icon = "🤖",
				autoCollect = true,
			},
			extra_storage = {
				id = 0,
				displayName = "Ekstra Depo",
				description = "Depo kapasitesi +%50",
				icon = "📦",
				storageBonus = 0.5,
			},
		} :: { [string]: ProductConfig },
		products = {
			instant_production = {
				id = 0,
				displayName = "Üretimi Bitir",
				description = "Devam eden bütün üretimleri hemen tamamlar",
				icon = "⚡",
				effect = "instantProduction",
			},
			income_pack = {
				id = 0,
				displayName = "1 Saatlik Gelir",
				description = "Anında 1 saatlik gelir kazan",
				icon = "💰",
				effect = "incomePack",
				incomeHours = 1,
			},
		} :: { [string]: ProductConfig },
	},
	PRODUCT_MIN_INCOME_PACK = 500, -- Gelir paketi en az bu kadar verir

	-- Günlük giriş ödülü: 7 günlük seri; bozulursa baştan başlar. Ödül, oyuncunun o anki gelirinin
	-- DAILY_MINUTES dakikalık karşılığı x seri çarpanıdır (en az DAILY_MIN_REWARD): geç oyunda da anlamlı kalır.
	DAILY_REWARD_MULTIPLIERS = { 1, 1.5, 2, 3, 4, 6, 10 },
	DAILY_MINUTES = 10,
	DAILY_MIN_REWARD = 250,

	-- Gezgin tüccar (rastgele olay): her oyuncuya ayrı ve sunucu saatinden türeyen ziyaret pencereleri.
	-- Her cycleSeconds içinde chance olasılıkla, rastgele bir başlangıçla visitSeconds süren bir ziyaret olur;
	-- ziyarette satın alınabilen hayvanlardan pahalı yarısından biri, en fazla stock adet, discount indirimle sunulur.
	MERCHANT = {
		cycleSeconds = 900,
		visitSeconds = 240,
		chance = 0.7,
		discount = 0.3,
		stock = 3,
	},

	-- Altın hayvan (rastgele olay): her oyuncuya ayrı, sunucu saatinden türeyen kısa pencereler. Pencere açıkken
	-- etkin çiftlikteki yetişkin hayvanlardan biri parlar; dokunan, o hayvanın rewardSeconds saniyelik gelirini alır.
	GOLDEN = {
		cycleSeconds = 600,
		windowSeconds = 75,
		chance = 0.6,
		rewardSeconds = 150,
		minReward = 100,
	},

	-- Mevsim hedefi: her mevsimde (SEASON_SECONDS) tek bir hedef; mevsim dönünce yenisi gelir, alınmamışsa kaybolur.
	-- metric "earned": mevsim başından beri kazanılan para (hedef = gelir x mevsim süresi x factor, en az minTarget).
	-- metric "invest": başarılı yatırım sayısı (hayvan, yükseltme, ırk veya alan genişletme; hedef = target).
	-- Ödül alınırken gelirin SEASONAL_REWARD_SECONDS saniyelik karşılığıdır (en az SEASONAL_MIN_REWARD).
	SEASONAL_GOALS = {
		spring = { metric = "earned", factor = 0.35, minTarget = 300 },
		summer = { metric = "invest", target = 4 },
		autumn = { metric = "earned", factor = 0.5, minTarget = 500 },
		winter = { metric = "invest", target = 6 },
	} :: { [string]: { metric: string, factor: number?, minTarget: number?, target: number? } },
	SEASONAL_REWARD_SECONDS = 120,
	SEASONAL_MIN_REWARD = 150,

	-- Başarımlar: her birinin tek seferlik para ödülü var. metric hesabı Rewards.progress içindedir.
	ACHIEVEMENTS = {
		{
			id = "cows_10",
			displayName = "İlk 10 inek",
			description = "10 inek sahibi ol",
			icon = "🐄",
			metric = "cows",
			target = 10,
			reward = 500,
		},
		{
			id = "animals_25",
			displayName = "Küçük sürü",
			description = "Toplam 25 hayvana ulaş",
			icon = "🐑",
			metric = "animals",
			target = 25,
			reward = 2500,
		},
		{
			id = "animals_50",
			displayName = "Büyük sürü",
			description = "Toplam 50 hayvana ulaş",
			icon = "🐎",
			metric = "animals",
			target = 50,
			reward = 12000,
		},
		{
			id = "first_island",
			displayName = "İlk ada",
			description = "Bir küçük ada aç",
			icon = "🏝️",
			metric = "islands",
			target = 2,
			reward = 1500,
		},
		{
			id = "all_islands",
			displayName = "Takımadanın efendisi",
			description = "Bütün adaları aç",
			icon = "👑",
			metric = "islands",
			target = 4,
			reward = 20000,
		},
		{
			id = "earned_10k",
			displayName = "İlk 10 bin",
			description = "Toplam 10.000 kazan",
			icon = "💰",
			metric = "earned",
			target = 10000,
			reward = 1000,
		},
		{
			id = "earned_100k",
			displayName = "Yüz bin kulübü",
			description = "Toplam 100.000 kazan",
			icon = "💰",
			metric = "earned",
			target = 100000,
			reward = 8000,
		},
		{
			id = "earned_1m",
			displayName = "Milyoner",
			description = "Toplam 1 milyon kazan",
			icon = "💎",
			metric = "earned",
			target = 1000000,
			reward = 60000,
		},
		{
			id = "purchases_10",
			displayName = "Yatırımcı",
			description = "10 yükseltme al",
			icon = "🛠️",
			metric = "purchases",
			target = 10,
			reward = 3000,
		},
		{
			id = "purchases_25",
			displayName = "Çiftlik imparatoru",
			description = "25 yükseltme al",
			icon = "🏆",
			metric = "purchases",
			target = 25,
			reward = 30000,
		},
		{
			id = "orders_5",
			displayName = "Sipariş ustası",
			description = "5 sipariş teslim et",
			icon = "📋",
			metric = "orders",
			target = 5,
			reward = 2000,
		},
	} :: { AchievementConfig },

	-- Ses. `id` boşsa o ses çalınmaz. Arayüz sesleri motorun kendi dosyalarını kullanır (yer tutucu);
	-- gerçek "cha-ching", ortam ve hayvan sesleri için Creator Store'dan (Roblox'un ücretsiz sesleri)
	-- aldığın `rbxassetid://NUMARA` kimliklerini aşağıya yaz. Kimlik doğrulaması Studio'da yapılır.
	SOUNDS = {
		click = { id = "rbxasset://sounds/clickfast.wav", volume = 0.35 },
		coin = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.55, pitch = 1.6 },
		success = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.45, pitch = 1.15 },
		error = { id = "rbxasset://sounds/switch.wav", volume = 0.4, pitch = 0.7 },
		build = { id = "rbxasset://sounds/victory.wav", volume = 0.3 },
	} :: { [string]: SoundConfig },
	-- Ortam döngüleri (mevsim, hava ve gece): boş kimlik = o katman yok.
	AMBIENCE = {
		birds = { id = "", volume = 0.35 }, -- ilkbahar/yaz gündüz
		wind = { id = "", volume = 0.3 }, -- sonbahar/kış
		rain = { id = "", volume = 0.45 }, -- yağmur
		storm = { id = "", volume = 0.5 }, -- fırtına
		night = { id = "", volume = 0.3 }, -- gece (cırcır böceği)
	} :: { [string]: SoundConfig },
	-- Hayvan sesleri: animalId -> ses. Yakındaki yetişkin hayvan arada bir ses çıkarır.
	ANIMAL_SOUNDS = {
		cow = { id = "", volume = 0.5 },
		chicken = { id = "", volume = 0.45 },
		horse = { id = "", volume = 0.5 },
		goat = { id = "", volume = 0.5 },
		duck = { id = "", volume = 0.45 },
		sheep = { id = "", volume = 0.5 },
		pig = { id = "", volume = 0.5 },
	} :: { [string]: SoundConfig },

	-- Bir hayvanın her evrede kaldığı süre (saniye). Yetişkin olunca tam gelir verir.
	GROWTH_SECONDS = {
		calf = 45,
		young = 90,
	},

	BARN_LEVELS = {
		{ level = 1, displayName = "Küçük Ahır", barnScale = 1, storageCap = 500, incomeMultiplier = 1 },
		{
			level = 2,
			displayName = "Genişletilmiş Ahır",
			barnScale = 1.2,
			storageCap = 1200,
			incomeMultiplier = 1.2,
		},
		{ level = 3, displayName = "Çiftlik Ahırı", barnScale = 1.45, storageCap = 3000, incomeMultiplier = 1.4 },
		{ level = 4, displayName = "Büyük Çiftlik", barnScale = 1.7, storageCap = 10000, incomeMultiplier = 1.7 },
	} :: { BarnLevelConfig },

	-- Bütün ada türleri; hangi çiftlikte hangilerinin olduğunu THEMES belirler.
	FARM_ISLAND_ORDER = { "home", "dairy", "poultry", "duck", "horse", "sheep", "goat", "pig" },
	FARM_ISLANDS = {
		home = {
			id = "home",
			displayName = "Ana Ada",
			icon = "🐄",
			trait = "İnek çiftliğin ve ahırın burada",
		},
		dairy = {
			id = "dairy",
			displayName = "Süt Adası",
			icon = "🐄",
			trait = "İnekler burada 2 kat hızlı büyür",
			upgradeId = "island_dairy",
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
		duck = {
			id = "duck",
			displayName = "Ördek Adası",
			icon = "🦆",
			trait = "Göl kenarında ördekler 2 kat hızlı büyür",
			upgradeId = "island_duck",
		},
		sheep = {
			id = "sheep",
			displayName = "Koyun Adası",
			icon = "🐑",
			trait = "Yün: koyunlar +%25 gelir getirir",
			upgradeId = "island_sheep",
		},
		pig = {
			id = "pig",
			displayName = "Domuz Adası",
			icon = "🐖",
			trait = "Trüf ormanı: domuzlar +%25 gelir getirir",
			upgradeId = "island_pig",
		},
	} :: { [string]: FarmIslandConfig },

	-- Temalar: dizi sırası = ana çiftlik numarası = fiziksel ada numarası (Çiftlik 1 her zaman Papatya).
	-- Her tema erken (Ahır Sv.2), orta (Sv.3) ve geç (Sv.4) birer ada türü içerir; hiçbir tema diğeriyle aynı değildir.
	THEMES = {
		{
			id = "papatya",
			landmark = "daisy",
			displayName = "Klasik Çayır",
			homeAnimal = "cow",
			satellites = { "poultry", "horse", "goat" },
		},
		{
			id = "lale",
			landmark = "tulip",
			displayName = "Yün ve Süt",
			homeAnimal = "chicken",
			satellites = { "dairy", "sheep", "goat" },
		},
		{
			id = "aycicegi",
			landmark = "sunflower",
			displayName = "Güneşli Tarla",
			homeAnimal = "duck",
			satellites = { "dairy", "poultry", "pig" },
		},
		{
			id = "gul",
			landmark = "rose",
			displayName = "Göl ve Hara",
			homeAnimal = "cow",
			satellites = { "duck", "horse", "pig" },
		},
		{
			id = "yonca",
			landmark = "pine",
			displayName = "Dağ ve Orman",
			homeAnimal = "chicken",
			satellites = { "dairy", "horse", "pig" },
		},
		{
			id = "kiraz",
			landmark = "cherry",
			displayName = "Meyve ve Süt",
			homeAnimal = "duck",
			satellites = { "dairy", "sheep", "pig" },
		},
	} :: { ThemeConfig },

	-- Yol haritası aşamaları: adalar + onlarla paralel ilerleyen Deniz dalı
	ROADMAP_STAGES = {
		{ name = "Ana Ada", island = "home" },
		{ name = "Deniz", description = "Balık kafesinde hamsi ve levrek yetiştir" },
		{ name = "Tavuk Adası", island = "poultry" },
		{ name = "At Adası", island = "horse" },
		{ name = "Keçi Adası", island = "goat" },
		{ name = "Ördek Adası", island = "duck" },
		{ name = "Koyun Adası", island = "sheep" },
		{ name = "Domuz Adası", island = "pig" },
		{ name = "Süt Adası", island = "dairy" },
	} :: { RoadmapStage },

	UPGRADES = {
		-- Aşama 1: Ana ada — ilk tercih: daha çok yer mi, daha büyük ahır mı, hızlı büyüme mi?
		{
			id = "zone_pasture",
			displayName = "Otlak",
			description = "+8 hayvan yeri",
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
			displayName = "Yem Makinesi",
			description = "Ana ada hayvanlarının geliri +%50",
			icon = "🥛",
			stage = 1,
			cost = 1200,
			requires = { "zone_pasture" },
			kind = "boost",
			incomeBoost = { home = 0.5 },
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
			id = "island_dairy",
			displayName = "Süt Adası",
			description = "İnek açılır · İnekler 2 kat hızlı büyür",
			icon = "🐄",
			stage = 9,
			cost = 900,
			requires = { "barn_2" },
			kind = "island",
			islandId = "dairy",
			growthBoost = { cow = 2 },
		},
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
			description = "Tüm gelir x1.4 · Depo 3.000 · Orta adalar için gerekli",
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
			description = "Tüm gelir x1.7 · Depo 10.000 · Son adalar için gerekli",
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
			requires = { "barn_4" },
			kind = "island",
			islandId = "goat",
			storageBonus = 0.25,
		},
		-- Aşama 6: Ördek Adası (erken ada: Ahır Sv.2)
		{
			id = "island_duck",
			displayName = "Ördek Adası",
			description = "Ördek açılır · Göl kenarında 2 kat hızlı büyür",
			icon = "🦆",
			stage = 6,
			cost = 950,
			requires = { "barn_2" },
			kind = "island",
			islandId = "duck",
			growthBoost = { duck = 2 },
		},
		{
			id = "duck_house",
			displayName = "Ördek Kulübesi",
			description = "Ördek geliri +%60",
			icon = "🏠",
			stage = 6,
			cost = 2600,
			requires = { "island_duck" },
			kind = "boost",
			incomeBoost = { duck = 0.6 },
		},
		-- Aşama 7: Koyun Adası (orta ada: Ahır Sv.3)
		{
			id = "island_sheep",
			displayName = "Koyun Adası",
			description = "Koyun açılır · Yün: koyunlar +%25 gelir",
			icon = "🐑",
			stage = 7,
			cost = 3600,
			requires = { "barn_3" },
			kind = "island",
			islandId = "sheep",
			incomeBoost = { sheep = 0.25 },
		},
		{
			id = "wool_mill",
			displayName = "Yün Değirmeni",
			description = "Koyun geliri +%75",
			icon = "🧶",
			stage = 7,
			cost = 8500,
			requires = { "island_sheep" },
			kind = "boost",
			incomeBoost = { sheep = 0.75 },
		},
		-- Aşama 8: Domuz Adası (geç ada: Ahır Sv.4)
		{
			id = "island_pig",
			displayName = "Domuz Adası",
			description = "Domuz açılır · Trüf ormanı: domuzlar +%25 gelir",
			icon = "🐖",
			stage = 8,
			cost = 7800,
			requires = { "barn_4" },
			kind = "island",
			islandId = "pig",
			incomeBoost = { pig = 0.25 },
		},
		{
			id = "truffle_kitchen",
			displayName = "Trüf Mutfağı",
			description = "Domuz geliri 2 katı",
			icon = "🍄",
			stage = 8,
			cost = 12500,
			requires = { "island_pig" },
			kind = "boost",
			incomeBoost = { pig = 1 },
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
			displayName = "Paketleme Fabrikası",
			description = "Ana ada hayvanlarının geliri +%150 · Paketli ürün",
			icon = "🥛",
			stage = 3,
			cost = 6000,
			requires = { "milk_machine", "barn_3" },
			kind = "boost",
			incomeBoost = { home = 1.5 },
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
		{
			id = "ext_duck_cove",
			displayName = "Ördek Koyu",
			description = "6 ördek · göl yerini boşaltır · +%50 gelir",
			icon = "🦆",
			stage = 6,
			cost = 1500,
			requires = { "island_duck" },
			kind = "extension",
			extensionId = "duck_cove",
		},
		{
			id = "ext_hillside_pasture",
			displayName = "Yün Yamacı",
			description = "5 koyun · ağıl yerini boşaltır · +%50 gelir",
			icon = "🐑",
			stage = 7,
			cost = 4200,
			requires = { "island_sheep" },
			kind = "extension",
			extensionId = "hillside_pasture",
		},
		{
			id = "ext_truffle_grove",
			displayName = "Trüf Korusu",
			description = "4 domuz · çiftlik yerini boşaltır · +%50 gelir",
			icon = "🐖",
			stage = 8,
			cost = 6500,
			requires = { "island_pig" },
			kind = "extension",
			extensionId = "truffle_grove",
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
		duck_cove = {
			id = "duck_cove",
			displayName = "Ördek Koyu",
			description = "Koyda yüzen ördekler",
			icon = "🦆",
			island = "duck",
			sourceZoneId = "pond",
			animalId = "duck",
			capacity = 6,
			incomeBonus = 0.5,
		},
		hillside_pasture = {
			id = "hillside_pasture",
			displayName = "Yün Yamacı",
			description = "Yamaçta otlayan koyunlar",
			icon = "🐑",
			island = "sheep",
			sourceZoneId = "sheepfold",
			animalId = "sheep",
			capacity = 5,
			incomeBonus = 0.5,
		},
		truffle_grove = {
			id = "truffle_grove",
			displayName = "Trüf Korusu",
			description = "Ormanda trüf arayan domuzlar",
			icon = "🐖",
			island = "pig",
			sourceZoneId = "pigpen",
			animalId = "pig",
			capacity = 4,
			incomeBonus = 0.5,
		},
	} :: { [string]: ExtensionConfig },

	-- Tek bir ücretli parti çevrimdışında tamamlanabilir; otomatik tekrar üretmez.
	PRODUCTION_ORDER = {
		"dairy",
		"hatchery",
		"duck_eggs",
		"horse_training",
		"wool",
		"cheese",
		"truffle",
		"fish_dispatch",
	},
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
		duck_eggs = {
			id = "duck_eggs",
			displayName = "Ördek Yumurtası Sevkiyatı",
			description = "Göl kenarında toplanan yumurtaları paketle ve pazara gönder.",
			icon = "🥚",
			island = "duck",
			upgradeId = "duck_house",
			animalId = "duck",
			animalIds = { "duck" },
			requiredAdults = 3,
			duration = 70,
			cost = 260,
			reward = 900,
			output = "cash",
		},
		wool = {
			id = "wool",
			displayName = "Yün İpliği",
			description = "Yünü eğir, iplik yap ve kangalları sat.",
			icon = "🧶",
			island = "sheep",
			upgradeId = "wool_mill",
			animalId = "sheep",
			animalIds = { "sheep" },
			requiredAdults = 2,
			duration = 90,
			cost = 700,
			reward = 2100,
			output = "cash",
		},
		truffle = {
			id = "truffle",
			displayName = "Trüf Sosu",
			description = "Ormandan toplanan trüfleri sosa çevir ve şişeleri sat.",
			icon = "🍄",
			island = "pig",
			upgradeId = "truffle_kitchen",
			animalId = "pig",
			animalIds = { "pig" },
			requiredAdults = 2,
			duration = 110,
			cost = 1300,
			reward = 3700,
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
	ZONE_ORDER = {
		"starter",
		"pasture",
		"fishpen",
		"dairy",
		"poultry",
		"pond",
		"stable",
		"sheepfold",
		"goatpen",
		"pigpen",
	},
	ZONES = {
		starter = {
			id = "starter",
			displayName = "İnek Ağılı",
			icon = "🐄",
			island = "home",
			capacity = 6,
			allowedAnimals = { "cow" },
			themed = true,
		},
		pasture = {
			id = "pasture",
			displayName = "Otlak",
			icon = "🌾",
			island = "home",
			capacity = 8,
			allowedAnimals = { "cow" },
			themed = true,
		},
		dairy = {
			id = "dairy",
			displayName = "İnek Çayırı",
			icon = "🐄",
			island = "dairy",
			capacity = 10,
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
		pond = {
			id = "pond",
			displayName = "Ördek Gölü",
			icon = "🦆",
			island = "duck",
			capacity = 12,
			allowedAnimals = { "duck" },
		},
		sheepfold = {
			id = "sheepfold",
			displayName = "Koyun Ağılı",
			icon = "🐑",
			island = "sheep",
			capacity = 8,
			allowedAnimals = { "sheep" },
		},
		pigpen = {
			id = "pigpen",
			displayName = "Domuz Çiftliği",
			icon = "🐖",
			island = "pig",
			capacity = 8,
			allowedAnimals = { "pig" },
		},
	} :: { [string]: ZoneConfig },

	ANIMAL_ORDER = { "cow", "anchovy", "chicken", "duck", "seabass", "horse", "sheep", "goat", "pig" },
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
			price = 1200,
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
			price = 2000,
			baseIncomePerSecond = 24,
		},
		duck = {
			id = "duck",
			displayName = "Ördek",
			icon = "🦆",
			product = "Ördek yumurtası",
			price = 400,
			baseIncomePerSecond = 5.5,
		},
		sheep = {
			id = "sheep",
			displayName = "Koyun",
			icon = "🐑",
			product = "Yün",
			price = 1400,
			baseIncomePerSecond = 13,
		},
		pig = {
			id = "pig",
			displayName = "Domuz",
			icon = "🐖",
			product = "Trüf",
			price = 2200,
			baseIncomePerSecond = 26,
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

-- Yapı geliştirme profilleri: bölgenin/tesisin işlevine göre (varsayılan: bölge "barn", tesis "factory")
for zoneId, profile in
	{
		poultry = "coop",
		pond = "coop",
		stable = "stable",
		goatpen = "fold",
		sheepfold = "fold",
		pigpen = "fold",
		fishpen = "sea",
	}
do
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
	Config.BUILD_TARGETS[recipeId] = { island = recipe.island, icon = recipe.icon, isZone = false }
	table.insert(Config.BUILD_ORDER, recipeId)
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

-- Eşya tanımları. Fiyatlar toplam yükseltme harcamasına (≈12 milyon) ve gelir tempo hedeflerine göre ayarlıdır:
-- çekiç indirimleri, ilk saatte alınırsa büyük tasarruf sağlar; pahalı kademeler geç oyun içindir.
do
	local function block(
		size: { number },
		offset: { number },
		color: Color3,
		material: string?,
		angle: { number }?
	): ItemPart
		return { shape = "Block", size = size, offset = offset, color = color, material = material, angle = angle }
	end
	local function ball(diameter: number, offset: { number }, color: Color3, material: string?): ItemPart
		return {
			shape = "Ball",
			size = { diameter, diameter, diameter },
			offset = offset,
			color = color,
			material = material,
		}
	end
	local WOOD = Color3.fromRGB(120, 85, 55)
	local GOLD = Color3.fromRGB(255, 200, 70)

	local function hammerLook(headColor: Color3, material: string): ItemLook
		return {
			attach = "hip",
			parts = {
				block({ 0.22, 1.8, 0.22 }, { -1.25, -0.6, 0.55 }, WOOD, "Wood", { 0, 0, 25 }),
				block({ 1, 0.6, 0.6 }, { -0.9, 0.35, 0.55 }, headColor, material, { 0, 0, 25 }),
			},
		}
	end
	local function staffLook(orbColor: Color3, rodColor: Color3): ItemLook
		return {
			attach = "hand",
			parts = {
				block({ 0.25, 5, 0.25 }, { 0, 1.8, 0 }, rodColor, "Wood"),
				ball(1, { 0, 4.6, 0 }, orbColor, "Neon"),
				block({ 0.7, 0.18, 0.7 }, { 0, 4, 0 }, GOLD, "Metal"),
			},
		}
	end
	local function charmLook(color: Color3, diameter: number): ItemLook
		return { attach = "chest", parts = { ball(diameter, { 0, 0.6, -0.95 }, color, "Neon") } }
	end

	local function add(item: ItemConfig)
		Config.ITEMS[item.id] = item
		table.insert(Config.ITEM_ORDER, item.id)
	end

	-- Aletler: tüm yükseltme maliyetlerinden kalıcı indirim
	add({
		id = "copper_hammer",
		displayName = "Bakır Çekiç",
		icon = "🔨",
		slot = "tool",
		price = 60000,
		effects = { upgradeDiscount = 0.05 },
		look = hammerLook(Color3.fromRGB(184, 115, 51), "Metal"),
	})
	add({
		id = "iron_hammer",
		displayName = "Demir Çekiç",
		icon = "🔨",
		slot = "tool",
		price = 250000,
		effects = { upgradeDiscount = 0.1 },
		look = hammerLook(Color3.fromRGB(150, 155, 165), "Metal"),
	})
	add({
		id = "gold_hammer",
		displayName = "Altın Çekiç",
		icon = "🔨",
		slot = "tool",
		price = 800000,
		effects = { upgradeDiscount = 0.15 },
		look = hammerLook(GOLD, "Neon"),
	})
	add({
		id = "diamond_hammer",
		displayName = "Elmas Çekiç",
		icon = "🔨",
		slot = "tool",
		price = 2000000,
		effects = { upgradeDiscount = 0.2 },
		look = hammerLook(Color3.fromRGB(110, 220, 255), "Neon"),
	})

	-- Asalar: mevsim ya da hava değiştirme gücü (günlük hak sayısına göre kademeli, en üst kademe sınırsız)
	local seasonOrb, weatherOrb = Color3.fromRGB(120, 230, 120), Color3.fromRGB(110, 180, 255)
	add({
		id = "season_staff_1",
		displayName = "Çırak Mevsim Asası",
		icon = "🪄",
		slot = "staff",
		price = 150000,
		power = { kind = "season", usesPerDay = 1 },
		look = staffLook(seasonOrb, WOOD),
	})
	add({
		id = "season_staff_3",
		displayName = "Usta Mevsim Asası",
		icon = "🪄",
		slot = "staff",
		price = 600000,
		power = { kind = "season", usesPerDay = 3 },
		look = staffLook(seasonOrb, Color3.fromRGB(90, 60, 110)),
	})
	add({
		id = "season_staff_5",
		displayName = "Büyücü Mevsim Asası",
		icon = "🪄",
		slot = "staff",
		price = 1500000,
		power = { kind = "season", usesPerDay = 5 },
		look = staffLook(seasonOrb, Color3.fromRGB(60, 40, 90)),
	})
	add({
		id = "season_staff_inf",
		displayName = "Ebedi Mevsim Asası",
		icon = "🪄",
		slot = "staff",
		price = 6000000,
		power = { kind = "season" },
		look = staffLook(Color3.fromRGB(255, 230, 120), GOLD),
	})
	add({
		id = "weather_staff_1",
		displayName = "Çırak Hava Asası",
		icon = "🪄",
		slot = "staff",
		price = 100000,
		power = { kind = "weather", usesPerDay = 1 },
		look = staffLook(weatherOrb, WOOD),
	})
	add({
		id = "weather_staff_3",
		displayName = "Usta Hava Asası",
		icon = "🪄",
		slot = "staff",
		price = 400000,
		power = { kind = "weather", usesPerDay = 3 },
		look = staffLook(weatherOrb, Color3.fromRGB(60, 90, 130)),
	})
	add({
		id = "weather_staff_5",
		displayName = "Büyücü Hava Asası",
		icon = "🪄",
		slot = "staff",
		price = 1000000,
		power = { kind = "weather", usesPerDay = 5 },
		look = staffLook(weatherOrb, Color3.fromRGB(40, 70, 120)),
	})
	add({
		id = "weather_staff_inf",
		displayName = "Ebedi Hava Asası",
		icon = "🪄",
		slot = "staff",
		price = 4000000,
		power = { kind = "weather" },
		look = staffLook(Color3.fromRGB(200, 240, 255), Color3.fromRGB(220, 235, 250)),
	})

	-- Muskalar: takılıyken kalıcı pasif fayda (yalnızca bir muska takılır: hangisinin seçileceği bir karardır)
	add({
		id = "storage_charm_1",
		displayName = "Depo Muskası",
		icon = "📿",
		slot = "charm",
		price = 40000,
		effects = { storageBonus = 0.15 },
		look = charmLook(Color3.fromRGB(190, 140, 80), 0.6),
	})
	add({
		id = "storage_charm_2",
		displayName = "Büyük Depo Muskası",
		icon = "📿",
		slot = "charm",
		price = 400000,
		effects = { storageBonus = 0.35 },
		look = charmLook(Color3.fromRGB(230, 170, 70), 0.8),
	})
	add({
		id = "growth_charm_1",
		displayName = "Büyüme Muskası",
		icon = "📿",
		slot = "charm",
		price = 50000,
		effects = { growthSpeed = 1.15 },
		look = charmLook(Color3.fromRGB(110, 210, 110), 0.6),
	})
	add({
		id = "growth_charm_2",
		displayName = "Büyük Büyüme Muskası",
		icon = "📿",
		slot = "charm",
		price = 600000,
		effects = { growthSpeed = 1.4 },
		look = charmLook(Color3.fromRGB(60, 240, 120), 0.8),
	})
	add({
		id = "income_charm_1",
		displayName = "Bereket Muskası",
		icon = "📿",
		slot = "charm",
		price = 150000,
		effects = { incomeBonus = 0.03 },
		look = charmLook(Color3.fromRGB(255, 220, 100), 0.6),
	})
	add({
		id = "income_charm_2",
		displayName = "Büyük Bereket Muskası",
		icon = "📿",
		slot = "charm",
		price = 900000,
		effects = { incomeBonus = 0.06 },
		look = charmLook(Color3.fromRGB(255, 200, 60), 0.8),
	})
	add({
		id = "income_charm_3",
		displayName = "Altın Bereket Muskası",
		icon = "📿",
		slot = "charm",
		price = 5000000,
		effects = { incomeBonus = 0.1 },
		look = charmLook(Color3.fromRGB(255, 240, 150), 1),
	})

	-- Başlıklar (görünüm)
	local band = Color3.fromRGB(170, 45, 38)
	add({
		id = "farmer_hat",
		displayName = "Çiftçi Şapkası",
		icon = "🎩",
		slot = "head",
		price = 10000,
		look = {
			attach = "head",
			parts = {
				block({ 3, 0.15, 3 }, { 0, 0.55, 0 }, Color3.fromRGB(225, 195, 110), "Fabric"),
				block({ 1.6, 0.8, 1.6 }, { 0, 0.95, 0 }, Color3.fromRGB(225, 195, 110), "Fabric"),
				block({ 1.65, 0.2, 1.65 }, { 0, 0.72, 0 }, band, "Fabric"),
			},
		},
	})
	add({
		id = "flat_cap",
		displayName = "Kasket",
		icon = "🎩",
		slot = "head",
		price = 15000,
		look = {
			attach = "head",
			parts = {
				block({ 1.8, 0.6, 1.8 }, { 0, 0.75, 0 }, Color3.fromRGB(70, 90, 140), "Fabric"),
				block({ 1.5, 0.12, 0.9 }, { 0, 0.5, -1.05 }, Color3.fromRGB(50, 65, 105), "Fabric"),
			},
		},
	})
	add({
		id = "chicken_hat",
		displayName = "Tavuk Şapkası",
		icon = "🎩",
		slot = "head",
		price = 30000,
		look = {
			attach = "head",
			parts = {
				ball(1.7, { 0, 0.85, 0 }, Color3.fromRGB(250, 250, 250), "SmoothPlastic"),
				block({ 0.3, 0.7, 1 }, { 0, 1.6, 0 }, Color3.fromRGB(220, 50, 50), "SmoothPlastic"),
				block({ 0.5, 0.25, 0.5 }, { 0, 0.55, -0.95 }, Color3.fromRGB(250, 190, 50), "SmoothPlastic"),
			},
		},
	})
	add({
		id = "cowboy_hat",
		displayName = "Kovboy Şapkası",
		icon = "🎩",
		slot = "head",
		price = 60000,
		look = {
			attach = "head",
			parts = {
				block({ 3.4, 0.15, 2.6 }, { 0, 0.55, 0 }, Color3.fromRGB(130, 85, 50), "Fabric"),
				block({ 1.7, 1, 1.7 }, { 0, 1.05, 0 }, Color3.fromRGB(130, 85, 50), "Fabric"),
				block({ 1.75, 0.2, 1.75 }, { 0, 0.72, 0 }, Color3.fromRGB(60, 40, 30), "Fabric"),
			},
		},
	})
	add({
		id = "golden_crown",
		displayName = "Altın Taç",
		icon = "🎩",
		slot = "head",
		price = 400000,
		look = {
			attach = "head",
			parts = {
				block({ 1.8, 0.5, 1.8 }, { 0, 0.75, 0 }, GOLD, "Neon"),
				block({ 0.3, 0.6, 0.3 }, { -0.7, 1.25, -0.7 }, GOLD, "Neon"),
				block({ 0.3, 0.6, 0.3 }, { 0.7, 1.25, -0.7 }, GOLD, "Neon"),
				block({ 0.3, 0.6, 0.3 }, { -0.7, 1.25, 0.7 }, GOLD, "Neon"),
				block({ 0.3, 0.6, 0.3 }, { 0.7, 1.25, 0.7 }, GOLD, "Neon"),
				ball(0.5, { 0, 1.05, -0.95 }, Color3.fromRGB(220, 40, 70), "Neon"),
			},
		},
	})

	-- Sırt eşyaları (görünüm)
	add({
		id = "backpack",
		displayName = "Sırt Çantası",
		icon = "🧥",
		slot = "back",
		price = 12000,
		look = {
			attach = "back",
			parts = {
				block({ 1.6, 2, 0.8 }, { 0, 0.2, 0.9 }, Color3.fromRGB(130, 90, 55), "Fabric"),
				block({ 1.2, 0.5, 0.9 }, { 0, 1.2, 0.95 }, Color3.fromRGB(100, 70, 45), "Fabric"),
			},
		},
	})
	add({
		id = "red_cape",
		displayName = "Kırmızı Pelerin",
		icon = "🧥",
		slot = "back",
		price = 50000,
		look = {
			attach = "back",
			parts = { block({ 2.2, 3, 0.15 }, { 0, -0.1, 0.85 }, Color3.fromRGB(190, 40, 50), "Fabric", { 8, 0, 0 }) },
		},
	})
	add({
		id = "angel_wings",
		displayName = "Melek Kanatları",
		icon = "🧥",
		slot = "back",
		price = 250000,
		look = {
			attach = "back",
			parts = {
				block({ 0.2, 2.6, 1.6 }, { -1.2, 0.6, 0.95 }, Color3.fromRGB(250, 250, 255), "Neon", { 0, 25, -15 }),
				block({ 0.2, 2.6, 1.6 }, { 1.2, 0.6, 0.95 }, Color3.fromRGB(250, 250, 255), "Neon", { 0, -25, 15 }),
			},
		},
	})
	add({
		id = "golden_wings",
		displayName = "Altın Kanatlar",
		icon = "🧥",
		slot = "back",
		price = 1000000,
		look = {
			attach = "back",
			parts = {
				block({ 0.25, 3.4, 2.2 }, { -1.4, 0.7, 1 }, GOLD, "Neon", { 0, 25, -15 }),
				block({ 0.25, 3.4, 2.2 }, { 1.4, 0.7, 1 }, GOLD, "Neon", { 0, -25, 15 }),
				block({ 0.2, 2.2, 1.4 }, { -1.1, 0.2, 0.9 }, Color3.fromRGB(255, 235, 150), "Neon", { 0, 25, -15 }),
				block({ 0.2, 2.2, 1.4 }, { 1.1, 0.2, 0.9 }, Color3.fromRGB(255, 235, 150), "Neon", { 0, -25, 15 }),
			},
		},
	})
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
	if upgrade.kind == "extension" and upgrade.extensionId then
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
