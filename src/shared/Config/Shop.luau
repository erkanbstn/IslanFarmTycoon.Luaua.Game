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
			gold_50 = {
				id = 0,
				displayName = "50 Altın",
				description = "Altın rebirth sonrasında kalır",
				icon = "🪙",
				effect = "goldPack",
				goldAmount = 50,
				lifetime = "permanent",
			},
			gold_3000 = {
				id = 0,
				displayName = "3000 Altın",
				description = "Altın rebirth sonrasında kalır",
				icon = "🪙",
				effect = "goldPack",
				goldAmount = 3000,
				lifetime = "permanent",
			},
			instant_growth = {
				id = 0,
				displayName = "Yavruları Büyüt",
				description = "Etkin çiftlikte genç hayvanları büyütür; teslimde genç yoksa 50 altın verir",
				icon = "🌱",
				effect = "instantGrowth",
				goldAmount = 50,
				lifetime = "run",
			},
			gold_100 = {
				id = 0,
				displayName = "100 Altın",
				description = "Altın rebirth sonrasında kalır",
				icon = "🪙",
				effect = "goldPack",
				goldAmount = 100,
				lifetime = "permanent",
			},
			gold_500 = {
				id = 0,
				displayName = "500 Altın",
				description = "Altın rebirth sonrasında kalır",
				icon = "🪙",
				effect = "goldPack",
				goldAmount = 500,
				lifetime = "permanent",
			},
			gold_1500 = {
				id = 0,
				displayName = "1500 Altın",
				description = "Altın rebirth sonrasında kalır",
				icon = "🪙",
				effect = "goldPack",
				goldAmount = 1500,
				lifetime = "permanent",
			},
			run_double_income = {
				id = 0,
				displayName = "Bu Tur 2 Kat Gelir",
				description = "Teslim edildiği turda geçerli; rebirth ile sona erer",
				icon = "⚡",
				effect = "runDouble",
				lifetime = "run",
			},
			income_pack_small = {
				id = 0,
				displayName = "15 Dakikalık Gelir",
				description = "Kalıcı referans gelirinin 15 dakikalık karşılığı",
				icon = "💰",
				effect = "incomePack",
				incomeHours = 0.25,
				lifetime = "run",
			},
			income_pack_large = {
				id = 0,
				displayName = "3 Saatlik Gelir",
				description = "Kalıcı referans gelirinin 3 saatlik karşılığı",
				icon = "💰",
				effect = "incomePack",
				incomeHours = 3,
				lifetime = "run",
			},
			income_pack = {
				id = 0,
				displayName = "1 Saatlik Gelir",
				description = "Anında 1 saatlik gelir kazan",
				icon = "💰",
				effect = "incomePack",
				incomeHours = 1,
				lifetime = "run",
			},
		} :: { [string]: Types.ProductConfig },
	},

	PRODUCT_MIN_INCOME_PACK = 500, -- Gelir paketi en az bu kadar verir

	-- Günlük giriş ödülü: 7 günlük seri; bozulursa baştan başlar. Ödül, oyuncunun o anki gelirinin
	-- DAILY_MINUTES dakikalık karşılığı x seri çarpanıdır (en az DAILY_MIN_REWARD): geç oyunda da anlamlı kalır.
	DAILY_REWARD_MULTIPLIERS = { 1, 1.2, 1.5, 2, 2.5, 3, 4 },

	DAILY_MINUTES = 2,

	DAILY_MIN_REWARD = 250,

	-- Gezgin tüccar (rastgele olay): her oyuncuya ayrı ve sunucu saatinden türeyen ziyaret pencereleri.
	-- Her cycleSeconds içinde chance olasılıkla, rastgele bir başlangıçla visitSeconds süren bir ziyaret olur;
	-- ziyarette stock farklı tur eşyası discount indirimle sunulur; ziyaret başına tek eşya alınabilir.
	-- Ziyaret oturum uzunluğuna göre ayarlıdır: ~20 dk'lık oturumda en az bir, çoğunlukla iki ziyaret yakalanır.
	MERCHANT = {
		cycleSeconds = 600,
		visitSeconds = 300,
		chance = 0.75,
		discount = 0.3,
		stock = 3,
		buyRadius = 16,
	},

	-- Altın hayvan (rastgele olay): her oyuncuya ayrı, sunucu saatinden türeyen kısa pencereler. Pencere açıkken
	-- etkin çiftlikteki yetişkin hayvanlardan biri parlar; dokunan, çiftliğin TOPLAM gelirinin rewardSeconds saniyelik karşılığını alır
	-- (tek hayvanın değil; böylece ödül gelirle birlikte büyür).
	GOLDEN = {
		cycleSeconds = 600,
		windowSeconds = 75,
		chance = 0.6,
		rewardSeconds = 90,
		minReward = 100,
		claimRadius = 320, -- stud: oyuncu kendi adasının (uydu adalar dahil) bu kadar yakınında olmalı; hayvanın konumu istemcidedir
	},

	-- Mevsim hedefi: her mevsimde (SEASON_SECONDS) tek bir hedef; mevsim dönünce yenisi gelir, alınmamışsa kaybolur.
	-- metric "earned": mevsim başından beri kazanılan para (hedef = gelir x mevsim süresi x factor, en az minTarget).
	-- metric "invest": başarılı yatırım sayısı (hayvan, yükseltme, ırk, alan genişletme veya ahır siparişi teslimi; hedef = target).
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
