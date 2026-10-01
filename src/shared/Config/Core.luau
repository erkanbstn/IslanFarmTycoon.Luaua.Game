--!strict
-- Sabit ayarlar: ad, sürüm, diller, kayıt, başlangıç ve sipariş sabitleri.
-- Gizli bilgi koyma: ReplicatedStorage client'a da gider.
return {
	GAME_NAME = "Island Farm Tycoon",

	VERSION = "0.8.0",

	MAIN_FARM_LIMIT = 6,
	MAIN_FARM_SWITCH_COOLDOWN_SECONDS = 6, -- tema yeniden kurulumu pahalı; çiftlik seçimi bu aralıkta bir

	-- Arayüz dilleri. Kaynak dil Türkçe; diğerleri src/shared/Locales/<kod>.luau içinde.
	-- countries: kullanılmıyor (başlangıç dili yalnızca Roblox sistem dilinden; desteklenmiyorsa İngilizce).
	LANGUAGE_ORDER = { "tr", "en", "de", "ru", "es", "pt" },

	-- Grafik tercihi (hesaba kaydedilir): auto = cihaza ve kare hızına göre otomatik
	GRAPHICS_MODES = { auto = true, low = true, medium = true, high = true } :: { [string]: boolean },

	LANGUAGES = {
		tr = { code = "tr", name = "Türkçe", countries = { "TR" } },
		en = { code = "en", name = "English", countries = {} },
		de = { code = "de", name = "Deutsch", countries = { "DE", "AT", "CH", "LI", "LU" } },
		ru = { code = "ru", name = "Русский", countries = { "RU", "BY", "KZ", "KG" } },
		es = { code = "es", name = "Español", countries = {} },
		pt = { code = "pt", name = "Português", countries = {} },
	} :: { [string]: { code: string, name: string, countries: { string } } },

	DEFAULT_LANGUAGE = "en",

	MAIN_FARM_PRICES = { 0, 12000, 25000, 50000, 100000, 167000 },

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
	DATASTORE_NAME = "IslandFarmTycoon_v2",

	AUTOSAVE_SECONDS = 60,

	-- Hareket: Shift basılıyken (telefonda "Koş" düğmesiyle) koşu hızı
	WALK_SPEED = 16,

	SPRINT_SPEED = 24, -- Yürümenin 1,5 katı

	-- Köprüde koşarken hız çarpanı (BridgeBoost): adalar arası yol kısalır; köprüden inince normale döner
	BRIDGE_SPEED_MULTIPLIER = 1.6,

	-- Yeni oyuncuya ücretsiz: ana ada, Küçük Ahır (Sv.1) ve ana ağıl. Hayvanla başlanmaz (STARTING_COW_COUNT = 0):
	-- ilk hayvan, çiftliğin ana hayvanını (inek/tavuk/ördek) tam alacak kadar parayla alınır (Config.getStartingCash).
	STARTING_COW_COUNT = 0,

	-- Çiftlikteki ilk bu kadar hayvan yetişkin doğar (bornAt = 0): ilk dakikada "vay" anı, gelir hemen tam hızda başlar.
	-- Yalnızca hayvan sayısı bunun altındayken alınanlara uygulanır; kayıt şeması değişmez (bornAt = 0 zaten yetişkin demektir).
	STARTER_ADULT_ANIMALS = 3,

	-- İnek (en ucuz ana hayvan) fiyatı: Config.getStartingCash temaya göre ana hayvanın fiyatını verir.
	STARTING_CASH = 75,

	INCOME_TICK_SECONDS = 1,

	-- Toplama platformunda iki toplama arası en az bu kadar saniye (platformda durmak da toplar)
	COLLECT_COOLDOWN_SECONDS = 3,

	MAX_INCOME_CATCHUP_SECONDS = 60,

	FISH_REPLACEMENT_REFUND_RATE = 0.5,
}
