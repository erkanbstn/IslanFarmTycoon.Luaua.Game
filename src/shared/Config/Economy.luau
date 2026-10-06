--!strict
-- Gelir, çevrimdışı kazanç, fiyat eğrisi ve yapı yükseltmeleri.
-- Gizli bilgi koyma: ReplicatedStorage client'a da gider.

local Types = require(script.Parent:WaitForChild("Types"))
return {
	-- Oyuncu yokken kazanç doğrudan kasaya eklenir: normal gelirin bu oranı kadar, en fazla bu kadar saat için.
	-- Sınır depoya değil süreye bağlıdır (saat x gelir). Pasif Gelir yükseltmesi oranı ve süreyi artırır.
	OFFLINE_EARNING_RATE = 0.25,
	OFFLINE_MAX_HOURS = 2,
	OFFLINE_UPGRADED_EARNING_RATE = 0.3,
	OFFLINE_UPGRADED_MAX_HOURS = 5,
	-- Eşya/yükseltme çevrimdışı bonusları dahil toplam oran bunu aşamaz (aktif oyun çevrimdışından değerli kalsın).
	OFFLINE_MAX_TOTAL_RATE = 0.5,
	-- Tam bölgeden (OFFLINE_MAX_HOURS / Pasif Gelir süresi) sonra kesinti yerine azalan kuyruk: her dilim `hours` saat boyunca
	-- çevrimdışı oranın `factor` katını öder. Uzun ayrılık da bir şey kazandırır, ama ilk bölge her zaman en değerlisidir.
	OFFLINE_TAIL = { { hours = 4, factor = 0.3 }, { hours = 4, factor = 0.15 } },
	-- Dönüş sandığı: en az `minAwayHours` uzakta kalana, uzak her saat için `referenceMinutesPerHour` dakikalık güncel gelir
	-- (en çok `capMinutes`); `maxAwayHours` sonrası artmaz. Durumsuzdur: kayıt alanı gerekmez, dönüşte kasaya yatar.
	OFFLINE_RETURN_CHEST = { minAwayHours = 4, maxAwayHours = 8, referenceMinutesPerHour = 2, capMinutes = 16 },

	-- Üretimde gerekenden fazla her yetişkin hayvan satış ödülünü bu oranda artırır (en fazla MAX kadar hayvan).
	PRODUCTION_BONUS_PER_ADULT = 0.25,

	PRODUCTION_MAX_BONUS_ADULTS = 12,

	-- Ürün merkezi partisi küçük kalır: yetişkin bonusu, tesis verimi ve muska ayrı çarpan DEĞİL, artıları toplanır ve toplam çarpan bu değeri aşamaz
	-- (taban miktar 1-2 birim). Miktar ayrıca PRODUCTION_MAX_BATCH_UNITS ile sınırlanır: asgari getiri (PRODUCTION_MIN_RETURN) miktarı şişirerek
	-- değil, ürünün birim DEĞERİYLE sağlanır (`Config/Goods.luau`; `scripts/audit-economy.py` bölüm D).
	PRODUCTION_YIELD_MAX_MULT = 3,
	PRODUCTION_MAX_BATCH_UNITS = 6,

	-- "Uçuk sayı" sınırları (`tests/economy.spec.luau` ve `scripts/audit-economy.py --check` bunlara karşı ölçer; oyun mantığında kullanılmaz).
	-- Değer sınırı yoktur, çoğu oran/sayıdır; fiyat tavanı kademe tablosundadır (`DIFFICULTY.tiers[n].maxPrice`).
	ECONOMY_LIMITS = {
		maxBatchUnits = 6, -- ürün merkezi partisi (tam yükseltilmiş çiftlik)
		maxLineUnits = 12, -- sipariş satırı birimi
		maxRewardRatio = 3.2, -- sipariş ödülü / ürünlerin değeri (ada sipariş bonusu dahil)
		minRewardRatio = 1,
		maxRewardMinutes = 8, -- sipariş ödülü, o evredeki gelirin en çok bu kadar dakikası
		maxDisplayValue = 1e10, -- hiçbir ekran değeri bunu aşmaz
		-- Ürün birim değeri / tam yükseltilmiş çiftlikte merkezin asgari parti getirisi (tabanı): bu bantta kalır (Config/Goods.luau "DEĞER KURALI")
		valueToFloorMin = 1.8,
		valueToFloorMax = 3.2,
	},

	-- Üretim tesisine verilen yetişkin hayvanlar iş boyunca gelir getirmez. Teslim ödülü, (hayvanların kaçırdığı gelir +
	-- başlatma maliyeti) x bu orandan az olamaz: tesis her zaman hayvanları yerinde bırakmaktan daha kârlıdır.
	PRODUCTION_MIN_RETURN = 1.4,

	-- Parti çarpanı (seçeneğin returnMultiplier'ı) bunu aşamaz: büyük parti fabrikayı tek başına en iyi yatırım yapmasın
	-- (en iyi parti sürekli çalışırken geri ödeme ~25-40 dk bandında; `simulate-economy.py` "Tesis geri ödeme").
	PRODUCTION_MAX_RETURN = 2.0,

	-- Eklentide duran hayvanlar bu süre (sn) bonus kazanır, sonra ana bölgesine döner; kapasite yükseltmeyle 2 -> 4.
	EXTENSION_STAY_SECONDS = 360,
	EXTENSION_CAPACITY_LEVELS = 2,

	ANIMAL_PRICE_GROWTH = 1.18,

	-- Otomatik Toplayıcısı olmayan park edilmiş çiftliğin geliri depoya değil, bu oranda doğrudan kasaya yatar (kalanı yok olur).
	-- Böylece oyun geçidi (gamepass) olmadan da park edilmiş çiftlikler kazanır; toplayıcı hâlâ %100 verir.
	PARKED_FARM_PAY_RATE = 0.5,

	-- Çiftlik zorluğu (alım sırası save.tier) ve çiftlik çarpanı: Config/Difficulty.luau (FarmMath.getPrice).

	ANIMAL_SELL_FRACTION = 0.5, -- Hayvan satınca, son alınan hayvanın fiyatının bu kadarı geri gelir (kazanç sayılmaz)

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
			-- Başlatma ücretsiz olan para tesisleri: indirim yerine verim
			cashFactory = {
				{ speed = 0.9 },
				{ yield = 0.1 },
				{ yield = 0.08 },
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
		} :: { [string]: { Types.BuildLevelEffects } },
	},
}
