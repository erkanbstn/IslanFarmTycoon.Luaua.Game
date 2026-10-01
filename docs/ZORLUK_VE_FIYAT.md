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
(casual) biter. Süre, çok çiftlikli ideal oyuncunun çiftliği **satın almadan tüm yükseltmelerine kadar** geçen süredir (önceki çiftliklerin park edilmiş
geliri dahil); ölçüm `python scripts/simulate-tiers.py` (= `simulate-economy.py --farms 6 --finish-first`).

Gerekçe: `timeGrowth = 1,5` aralığın (1,5-2) alt ucudur. Daha dik (2x) 6. çiftliği ~270 saate çıkarır; 1,5x ile tüm oyun ~4 gün ideal (casual ~3 hafta) sürer. Çarpan ile
süre doğrusal değildir (gelir birikerek büyür, park edilmiş çiftlikler akar): bu yüzden çarpanlar sim ile ayarlanır ve ~2 kat/kademe büyür.

| Çiftlik | Çarpan | Hedef (dk) | Ölçülen ideal (dk) | Önceki çiftliğe oran | Eski çarpanla (1/7/13/19/25/31) |
|---|---|---|---|---|---|
| 1 | 1 | 276 | 283 | — | 276 |
| 2 | 6,6 | 414 | 414 | 1,46 | 297 |
| 3 | 17,6 | 621 | 630 | 1,52 | 293 |
| 4 | 34,8 | 932 | 942 | 1,49 | 294 |
| 5 | 62,7 | 1397 | 1416 | 1,50 | 304 |
| 6 | 107,5 | 2096 | 2106 | 1,49 | 319 |
| Toplam | | | 4,1 gün (eskiden 32 sa) | | |

Çiftlik 1 referans tempoyu korur (ideal): ilk ada 12,4 dk, at 46,1, keçi 117,8, tüm yükseltmeler 283 dk (eskiden 12,4 / 45,0 / 114,2 / 276). Tema başına tek başına (kademe 1) ölçüm
`--farm N` ile: ilk/orta/geç ada ve tamamlama (dk), önce → sonra:

| Tema | Önce | Sonra |
|---|---|---|
| 1 Klasik Çayır | 12,4 / 45,0 / 114,2 / 276 | 12,4 / 46,1 / 117,8 / 283 |
| 2 Yün ve Süt | 13,9 / 47,0 / 80,1 / 252 | 13,9 / 55,6 / 115,5 / 271 |
| 3 Güneşli Tarla | 14,6 / 34,6 / 95,8 / 252 | 14,6 / 35,9 / 104,2 / 264 |
| 4 Göl ve Hara | 15,0 / 44,9 / 133,6 / 297 | 15,0 / 45,5 / 132,2 / 293 |
| 5 Dağ ve Orman | 13,9 / 34,4 / 109,4 / 262 | 13,9 / 37,2 / 124,0 / 278 |
| 6 Meyve ve Süt | 14,6 / 41,8 / 94,1 / 257 | 14,6 / 48,8 / 113,8 / 271 |

Casual (3 oturum x 20 dk/gün) ve idle (2 x 10 dk) çiftlik tamamlama süreleri (`--personas casual,idle`): casual 1: 24 sa, 2: 24 sa, 3: 40 sa, 4: 3,0 gün, 5: 4,3 gün, 6: 6,3 gün;
idle 1: 3,0 gün, 2: 2,0 gün, 3: 3,5 gün, 4: 5,5 gün, 5: 8,5 gün, 6: 11,5 gün. Oturum sınırlı oyuncuda Çiftlik 1 üretim/geri dönüş zincirine bağlı uzun sürer (casual: eskiden 16 sa, şimdi
24 sa: bir ek oturum), Çiftlik 2 ise o sırada biriken kasayla hızlı biter; bu yüzden Çiftlik 2 süresi 1'den uzun olmayabilir (sim hata saymaz), Çiftlik 3'ten sonra süre artar.
Casual oyuncu (ucuzsa yeni çiftlik al) çiftlikleri 16 / 40 / 72 / 144 / 264 saatte alır (eskiden 16 / 32 / 56 / 80 / 112 sa): 6. çiftlik 4,7 günden ~11 güne çıktı.
Depo/ürün: casual'da açılışlar üretilen ürünün ~%12'sini harcar, doluluk ~%15, taşan yok.

## Açılışlar ürün de ister (goodsCost)

Ada, bölge, fabrika ve büyük yükseltmeler para yanında ahır deposundan **ürün** de ister (`Config/Upgrades.luau` `goodsCost`, hesap `FarmMath.getGoodsCost`).
Amaç: oyuncu önceki adalara/hayvanlara dönüp üretsin, ama uğraşmasın.

- `goodsCost = { step, shares }`: `step` 1 erken / 2 orta / 3 geç aşama; `shares[kaynak]` = temel para fiyatının bu payı kadar **değerde** ürün.
  Miktar = `pay x temel fiyat x stepBase[step] x (1 + tierGrowth x (tier - 1)) / ürün birim değeri` (yukarı yuvarlanır, en az 1; `DIFFICULTY.goods`).
  Çiftlik 1'in erken adımı ürün istemez (`tutorialFree`, öğretici).
- Kaynak ürün temaya göre çözülür (`Config.resolveGoodsSource`): `home` (çiftliğin ana hayvanının ürünü), `previous` (bu adadan önceki ada; ilk adada ana hayvan),
  `slot1..3` (temanın o küçük adasının ürünü), `sea` (balık). Böylece 24 yeni hayvanlı temalar da kendi ürünlerini ister; `goodsCost` yeniden yazılmaz.
- Ürün merkezleri ürün istemez (üretim hiç başlayamaz hâle gelmesin). Miktar, açılışın gerektirdiği ahır seviyesinin ürün kapasitesinin `capShare` payını aşmaz.
- Değişmezler (`tests/config.spec.luau`, `tests/economy.spec.luau`): her temada ve kademede kaynak çözülür, ürünü üreten merkez temada vardır ve açılışın kendisine bağlı değildir
  (deadlock yok); en ağır kademede tüm yükseltmeler ön koşul + ürün sırasıyla alınabilir; gereken ürünün satış değeri para fiyatının altında kalır; `GOODS_BARTER.rate <= GOODS_SELL.rate`.
- Sunucu: `UpgradeService.tryBuy` para ve ürünü `PlayerDataService.trySpend(..., goodsCost)` ile **tek adımda** düşer (biri yetmezse hiçbiri); `RequestBuyUpgrade` (requestId, etkin çiftlik
  doğrulaması, hız sınırı) değişmedi. Arayüz `HudCommon.upgradeVariant/goodsNeedText`: yetmeyen kalem kırmızı, buton `warning`.
- Hayvan türü açılışı ada/bölge açılışıyla birlikte gelir (her ada kendi türünü açar); hayvan alımı ayrıca ürün istemez (takas `GOODS_BARTER` ile çakışmasın).

## Yeni içerik eklerken

1. Taban fiyatı "gelir hızı x hedef süre" ile hesapla ve ilgili Config dosyasına yaz (Çiftlik 1 ölçeğinde).
2. Kademe çarpanları sonradan değişirse `Difficulty.luau`'yu ayarla, `scripts/simulate-tiers.py` ile ölç; `tests/economy.spec.luau` kademe monotonluğunu denetler.
3. Fiyatı elle çarpma; `FarmMath.getPrice` (ya da sarmalayıcıları `getUpgradeCost/getAnimalPrice/getBulkPrice/getExpansionCost`) kullan.
