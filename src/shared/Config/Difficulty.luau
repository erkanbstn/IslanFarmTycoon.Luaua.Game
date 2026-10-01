--!strict
-- Çiftlik zorluğu ve dinamik fiyat katmanı. Gizli bilgi koyma: ReplicatedStorage client'a da gider.
--
-- Fiyat tek bir hesaptan çıkar (`FarmMath.getPrice`): fiyat = taban fiyat x çiftlik çarpanı x ada sırası çarpanı x n. alım eğrisi.
--   - Taban fiyat: Çiftlik 1'in (referans çiftliğin) yazılı fiyatı; `Config/Upgrades`, `Animals`, `Production`, `Core.MAIN_FARM_PRICES`.
--     Taban = temel gelir hızı x hedef süre ile bulunur; hedefler 1. çiftlikte ideal oyuncu: ilk ada ~15 dk, at ~45, keçi ~110, tüm yükseltmeler ~240-300 dk.
--   - Çiftlik çarpanı (`tiers[n].costMultiplier`): n. çiftlik (alım sırası = `save.tier`); çok çiftlikli ideal oyuncunun o çiftliğin tüm yükseltmelerini
--     satın almadan sonra `tiers[n].targetMinutes` dakikada bitirmesi için `scripts/simulate-tiers.py` ile ayarlanır (aşağıdaki gerekçe).
--   - Ada sırası çarpanı (`slotSpread`): temanın erken/orta/geç adası (THEMES.satellites sırası, ana ada = 1) çiftlik ilerledikçe daha pahalı olur;
--     Çiftlik 1'de etkisi yoktur (korunan tempo).
--   - n. alım eğrisi: hayvan `ANIMAL_PRICE_GROWTH + animalGrowthPerTier x (tier - 1)` ^ sahip olunan; yapı geliştirme `BUILD_UPGRADES.costGrowth`;
--     yükseltme maliyeti eğrisi `UPGRADE_COST_EXPONENT` (hepsi `Config/Economy.luau`).
--   - Açılış gereksinimi (ürün): `goods` bloğu; `FarmMath.getGoodsCost`.
-- Gelir ölçeği yoktur (hayvan geliri çiftlikten çiftliğe aynı): zorluk yalnızca maliyetten gelir, böylece ödüller (sipariş, günlük, tesis)
-- kendi formüllerinde kalır.

local Types = require(script.Parent:WaitForChild("Types"))

local REFERENCE_MINUTES = 276
local TIME_GROWTH = 1.5

-- Hedef süre (ideal oyuncu): Çiftlik n, satın alındıktan sonra tüm yükseltmelerini REFERENCE_MINUTES x TIME_GROWTH^(n-1) dakikada bitirir (çok çiftlikli oyuncu önceki
-- çiftliklerini bitirip sıradakini alır; park edilmiş çiftliklerin geliri dahildir). 1,5 katı (1,5-2 kat aralığının alt ucu): her çiftlik bir öncekinden belirgin uzun,
-- ama 6. çiftlik (~35 sa ideal, hepsi ~96 sa) casual oyunda haftalar içinde biter.
-- costMultipliers bu hedeflere `python scripts/simulate-tiers.py` / `simulate-economy.py --farms 6 --finish-first --mults ...` ile ayarlanır; maliyet ile süre doğrusal değildir
-- (park edilmiş çiftlik geliri ve birikim): çarpan kademe başına ~2x büyür (1, 6.6, 17.6, 34.8, 62.7, 107.5).
local COST_MULTIPLIERS = { 1, 5.9, 16.8, 34.8, 62.7, 125 }

-- Kademe başına en pahalı tek kalemin (yükseltme, hayvan, yapı geliştirme) tavanı: `scripts/audit-economy.py` (bölüm C) ve `tests/goods.spec` bunu denetler.
-- Tavan, fiyat tablosunun doğal sonucudur (çarpan x yazılı taban); aşılırsa fiyat/çarpan değişimi ya da yeni içerik "uçuk" büyüklüğe çıkmış demektir.
-- Gösterim her zaman kısaltılır (`FarmMath.formatMoney`: 3,3M, 900M ...).
local MAX_PRICES = { 4e6, 3e7, 1e8, 2e8, 5e8, 1e9 }

local tiers: { Types.DifficultyTier } = {}
for tier, multiplier in COST_MULTIPLIERS do
	table.insert(tiers, {
		tier = tier,
		targetMinutes = math.floor(REFERENCE_MINUTES * TIME_GROWTH ^ (tier - 1) + 0.5),
		costMultiplier = multiplier,
		maxPrice = MAX_PRICES[tier],
	})
end

return {
	DIFFICULTY = {
		referenceMinutes = REFERENCE_MINUTES,
		timeGrowth = TIME_GROWTH,
		tiers = tiers,
		-- Ada sırası çarpanı: 1 + slotSpread x (tier - 1) x (sıra - 1); sıra: ana ada ve erken ada = 1, orta = 2, geç = 3
		slotSpread = 0.1,
		-- Ada açılış bedeli primi (erken / orta / geç ada = THEMES.satellites sırası): 1 + perTier x (tier - 1) ^ power; Çiftlik 1'de x1.
		-- Yalnızca "island" yükseltmesinin parasını çarpar (ürün gereksinimi, fabrikalar ve genişletmeler değişmez); ritim hedefi docs/ADA_TASARIMI.md.
		islandPremium = {
			{ perTier = 31, power = 0 }, -- erken ada: x32 (Çiftlik 2-6'da ilk ada ~20-80 dk sonra açılır)
			{ perTier = 2.3, power = 0.35 }, -- orta ada: x3,3 (Çiftlik 2) ... x5 (Çiftlik 6)
			{ perTier = 1.8, power = 0 }, -- geç ada: x2,8
		},
		-- n. alım eğrisi: hayvan fiyat artışına çiftlik başına eklenen pay
		animalGrowthPerTier = 0.005,
		-- Açılışlar para yanında ürün de ister (`Upgrades.luau` goodsCost; miktar: FarmMath.getGoodsCost): değer payı x adım x kademe / ürün değeri.
		-- Çiftlik 1'in erken adımı ürün istemez (öğretici); ürün her zaman önceki adaların/ana hayvanın ürünlerinden seçilir ve ahır kapasitesine sığar.
		goods = {
			stepBase = { 1, 1, 1.25 },
			tierGrowth = 0.5,
			tutorialSteps = 3, -- Çiftlik 1'de bu adıma kadar (1 erken, 2 orta ada) ürün istenmez; oturum sınırlı oyuncuda çiftlik süresi tema 1 -> 6 artsın (Q29)
			capShare = 0.5,
		},
	} :: Types.DifficultyConfig,
}
