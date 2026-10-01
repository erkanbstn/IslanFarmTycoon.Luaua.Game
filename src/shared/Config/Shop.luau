--!strict
-- Eşya yuvaları, soy, ürünler ve günlük/tüccar/altın hayvan/mevsim hedefi ayarları (eşya tanımları Items.luau).
-- Gizli bilgi koyma: ReplicatedStorage client'a da gider.

local Types = require(script.Parent:WaitForChild("Types"))
return {
	-- Irk geliştirme (oyun sonu para harcama yolu): her hayvan türü için ayrı, çiftlik başına seviye.
	-- Seviye n -> n+1 maliyeti = türün taban fiyatı x costMultiplier x costGrowth^n (2 anlamlı basamak).
	-- Getiri doğrusal (her seviye incomePerLevel) ve diğer gelir bonuslarından ayrı çarpandır (bkz. FarmMath/Income); maliyet
	-- üstel ama yavaş (costGrowth): her seviyenin geri dönüşü ~2 saati geçmesin (python scripts/simulate-economy.py, "Irk geri dönüş").
	-- Eşyalar: hesap düzeyinde envanter. Slot başına bir eşya takılır; fiyatlar oyun parasıyladır (ITEMS aşağıda doldurulur).
	ITEM_SLOT_ORDER = { "tool", "staff", "charm", "head", "back" },

	ITEM_SLOTS = {
		tool = { id = "tool", displayName = "Alet", icon = "🔨" },
		staff = { id = "staff", displayName = "Asa", icon = "🪄" },
		charm = { id = "charm", displayName = "Muska", icon = "📿" },
		head = { id = "head", displayName = "Başlık", icon = "🎩" },
		back = { id = "back", displayName = "Sırt", icon = "🧥" },
	} :: { [string]: Types.ItemSlotConfig },

	ITEM_USE_COOLDOWN_SECONDS = 20, -- Asa gücü iki kullanım arası en az bu kadar bekler (sınırsız asalar dahil)

	ITEMS = {} :: { [string]: Types.ItemConfig },

	ITEM_ORDER = {} :: { string },

	LINEAGE = {
		maxLevel = 10,
		incomePerLevel = 0.08,
		costMultiplier = 50,
		costGrowth = 1.15,
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
		} :: { [string]: Types.ProductConfig },
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
		} :: { [string]: Types.ProductConfig },
	},

	PRODUCT_MIN_INCOME_PACK = 500, -- Gelir paketi en az bu kadar verir

	-- Günlük giriş ödülü: 7 günlük seri; bozulursa baştan başlar. Ödül, oyuncunun o anki gelirinin
	-- DAILY_MINUTES dakikalık karşılığı x seri çarpanıdır (en az DAILY_MIN_REWARD): geç oyunda da anlamlı kalır.
	DAILY_REWARD_MULTIPLIERS = { 1, 1.2, 1.5, 2, 2.5, 3, 4 },

	DAILY_MINUTES = 3,

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

	SEASONAL_REWARD_SECONDS = 90,

	SEASONAL_MIN_REWARD = 150,
}
