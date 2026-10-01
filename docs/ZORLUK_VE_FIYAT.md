# Zorluk ve dinamik fiyat

Oyundaki bütün fiyatlar **tek bir hesaptan** çıkar: `FarmMath.getPrice(save, kind, id, level)` (`src/shared/Modules/FarmMath/Pricing.luau`).
Gösterilen fiyat (arayüz, tabela, buton) ile sunucunun tahsil ettiği fiyat aynı işlevden gelir; hiçbir yerde elle çarpan yazılmaz.
Kurallar ve rakamlar `src/shared/Config/Difficulty.luau` içindedir; bu belge gerekçeyi açıklar, rakamları tutmaz (sürüm kaymasın).

## Formül

```
fiyat = taban fiyat x çiftlik çarpanı x ada sırası çarpanı x n. alım eğrisi
```

- **Taban fiyat**: Çiftlik 1'in (referans çiftliğin) yazılı fiyatı: `Config/Upgrades` (yükseltme, ada, bölge, bina), `Config/Animals` (hayvan),
  `Config/Production` (tesis ölçeği), `Config/Core.MAIN_FARM_PRICES` (ana çiftlik). Taban, "temel gelir hızı x hedef süre" ile bulunur: bir
  adımın fiyatı, o adımdaki ideal oyuncunun gelirinin hedef süre kadar birikimidir (ilk ada ~15 dk, at ~45, keçi ~110, tüm yükseltmeler ~240-300 dk).
  Yeni içerik eklerken bu çarpımı hesapla; rakamı gelişigüzel yazma (`scripts/simulate-economy.py` ile doğrula).
- **Çiftlik çarpanı** (`DIFFICULTY.tiers[tier].costMultiplier`): `tier` çiftliğin alım sırasıdır (`save.tier`, 1 = ilk çiftlik). Park edilmiş çiftlikler gelir
  akıttığı için sonraki çiftliğin maliyeti yalnızca "bir önceki x katsayı" olamaz; çarpanlar, **çok çiftlikli ideal oyuncunun** her çiftliği
  `targetMinutes` dakikada (satın almadan tamamlamaya) bitirmesi için `--finish-first` sim'iyle ayarlanır.
- **Ada sırası çarpanı** (`DIFFICULTY.slotSpread`): temanın erken/orta/geç adası (`THEMES.satellites` sırası; ana ada ve ilk ada = 1). Çarpan
  `1 + slotSpread x (tier - 1) x (sıra - 1)`: çiftlik ilerledikçe geç adalar göreli pahalanır. Çiftlik 1'de etkisi yoktur (korunan tempo).
- **n. alım eğrisi**: hayvan her sahip olunan aynı türle `ANIMAL_PRICE_GROWTH + animalGrowthPerTier x (tier - 1)` kat pahalanır; yapı geliştirme seviye
  başına `BUILD_UPGRADES.costGrowth` / `facilityCostGrowth`; yükseltme maliyeti `UPGRADE_COST_EXPONENT` eğrisinden geçer (`Config/Economy.luau`).
- **Gelir ölçeği yoktur**: hayvan geliri her çiftlikte aynıdır; zorluk yalnızca maliyetten gelir. Böylece ödüller (sipariş, günlük, tesis) kendi formüllerinde
  kalır ve park edilmiş çiftlik gelirinin değeri tutarlı olur.

`kind` değerleri: `"upgrade"` (id = yükseltme), `"animal"` (id = hayvan; level = sahip olunan sayı), `"expansion"` (id = bölge ya da tesis; level = ulaşılmış seviye),
`"farm"` (level = alınacak çiftliğin sırası; çiftlik çarpanı uygulanmaz). Bilinmeyen kimlik ve en üst seviye `math.huge` döner.

## Hedef süreler

Çiftlik n'nin hedef süresi `referenceMinutes x timeGrowth^(n-1)` dakikadır (`DIFFICULTY.tiers[n].targetMinutes`). Çarpan, her çiftliğin bir
öncekinden ~1,5-2 kat daha uzun sürmesi için seçilir: oyuncu ilerledikçe belirgin biçimde daha çok emek ister, ama 6. çiftlik hâlâ haftalar içinde
(casual) biter. Tablo `docs/DURUM_RAPORU.md` ve `python scripts/simulate-economy.py --tier-table` çıktısındadır.

## Yeni içerik eklerken

1. Taban fiyatı "gelir hızı x hedef süre" ile hesapla ve ilgili Config dosyasına yaz (Çiftlik 1 ölçeğinde).
2. Kademe çarpanları sonradan değişirse `Difficulty.luau`'yu ayarla, `--tier-table` ile ölç; `tests/economy.spec.luau` kademe monotonluğunu denetler.
3. Fiyatı elle çarpma; `FarmMath.getPrice` (ya da sarmalayıcıları `getUpgradeCost/getAnimalPrice/getBulkPrice/getExpansionCost`) kullan.
