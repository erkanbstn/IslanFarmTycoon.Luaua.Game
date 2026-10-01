--!strict
-- Çiftlik zorluğu ve dinamik fiyat katmanı. Gizli bilgi koyma: ReplicatedStorage client'a da gider.
--
-- Fiyat tek bir hesaptan çıkar (`FarmMath.getPrice`): fiyat = taban fiyat x çiftlik çarpanı x ada sırası çarpanı x n. alım eğrisi.
--   - Taban fiyat: Çiftlik 1'in (referans çiftliğin) yazılı fiyatı; `Config/Upgrades`, `Animals`, `Production`, `Core.MAIN_FARM_PRICES`.
--     Taban = temel gelir hızı x hedef süre ile bulunur; hedefler 1. çiftlikte ideal oyuncu: ilk ada ~15 dk, at ~45, keçi ~110, tüm yükseltmeler ~240-300 dk.
--   - Çiftlik çarpanı (`tiers[n].costMultiplier`): n. çiftlik (alım sırası = `save.tier`) o çiftlik için tek başına oynayan ideal oyuncunun tüm
--     yükseltmeleri `tiers[n].targetMinutes` dakikada bitirmesi için `scripts/simulate-economy.py --tier n` ile ayarlanır (aşağıdaki gerekçe).
--   - Ada sırası çarpanı (`slotSpread`): temanın erken/orta/geç adası (THEMES.satellites sırası, ana ada = 1) çiftlik ilerledikçe daha pahalı olur;
--     Çiftlik 1'de etkisi yoktur (korunan tempo).
--   - n. alım eğrisi: hayvan `ANIMAL_PRICE_GROWTH + animalGrowthPerTier x (tier - 1)` ^ sahip olunan; yapı geliştirme `BUILD_UPGRADES.costGrowth`;
--     yükseltme maliyeti eğrisi `UPGRADE_COST_EXPONENT` (hepsi `Config/Economy.luau`).
--   - Açılış gereksinimi (ürün): `goods` bloğu; `FarmMath.getGoodsCost`.
-- Gelir ölçeği yoktur (hayvan geliri çiftlikten çiftliğe aynı): zorluk yalnızca maliyetten gelir, böylece ödüller (sipariş, günlük, tesis)
-- kendi formüllerinde kalır.

local Types = require(script.Parent:WaitForChild("Types"))

local REFERENCE_MINUTES = 276
local TIME_GROWTH = 1.6

-- Hedef süre: Çiftlik n tek başına (park edilmiş gelir olmadan) ideal oyuncuyla REFERENCE_MINUTES x TIME_GROWTH^(n-1) dakikada biter.
-- 1,6 katı: her çiftlik bir öncekinden belirgin uzun (1,5-2 kat aralığı) ama 6. çiftlik (~48 sa ideal) birkaç hafta casual oyunda biter.
-- costMultipliers sim ile bu hedeflere ayarlanır (maliyet ile süre doğrusal değil: gelir birikerek büyüdüğü için).
local COST_MULTIPLIERS = { 1, 7, 13, 19, 25, 31 }

local tiers: { Types.DifficultyTier } = {}
for tier, multiplier in COST_MULTIPLIERS do
	table.insert(tiers, {
		tier = tier,
		targetMinutes = math.floor(REFERENCE_MINUTES * TIME_GROWTH ^ (tier - 1) + 0.5),
		costMultiplier = multiplier,
	})
end

return {
	DIFFICULTY = {
		referenceMinutes = REFERENCE_MINUTES,
		timeGrowth = TIME_GROWTH,
		tiers = tiers,
		-- Ada sırası çarpanı: 1 + slotSpread x (tier - 1) x (sıra - 1); sıra: ana ada ve erken ada = 1, orta = 2, geç = 3
		slotSpread = 0,
		-- n. alım eğrisi: hayvan fiyat artışına çiftlik başına eklenen pay
		animalGrowthPerTier = 0,
		-- Açılışlar para yanında ürün de ister (`Upgrades.luau` goodsCost; miktar: FarmMath.getGoodsCost): değer payı x adım x kademe / ürün değeri.
		-- Çiftlik 1'in erken adımı ürün istemez (öğretici); ürün her zaman önceki adaların/ana hayvanın ürünlerinden seçilir ve ahır kapasitesine sığar.
		goods = {
			stepBase = { 1, 1.5, 2 },
			tierGrowth = 0.5,
			tutorialFree = true,
			capShare = 0.5,
		},
	} :: Types.DifficultyConfig,
}
