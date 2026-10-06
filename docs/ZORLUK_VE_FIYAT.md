# Zorluk ve dinamik fiyat

Oyundaki bütün fiyatlar **tek bir hesaptan** çıkar: `FarmMath.getPrice(save, kind, id, level)` (`src/shared/Modules/FarmMath/Pricing.luau`).
Gösterilen fiyat (arayüz, tabela, buton) ile sunucunun tahsil ettiği fiyat aynı işlevden gelir; hiçbir yerde elle çarpan yazılmaz.
Kurallar ve rakamlar `src/shared/Config/Difficulty.luau` içindedir; bu belge gerekçeyi açıklar, rakamları tutmaz (sürüm kaymasın). Ölçülen değerler
aynı koşullarda yeniden çalıştırılan `scripts/simulate-tiers.py` çıktısındadır.

Rebirth ilk beş tur temel yükseltmeleri, sonraki turlar kademeli soy/tesis/genişletme hedeflerini ister; karar Config.PROGRESSION.completionRequirements ve Progression.canRebirth içindedir. `simulate-tiers.py` tarihsel tüm-yükseltme metriğini korur; yeni `scripts/simulate-rebirth.py` temel koşulu ve kalıcı altın/etki senaryolarını ölçer. Güncel koşullar, takvim/aktif süre ayrımı ve sonuçlar `docs/DEVIR_DURUMU.md` içindedir. İki metriğin süreleri aynı ilerleme politikası varsayılmadan karşılaştırılmaz.

## Kademe = tema numarası

Çiftliğin zorluk kademesi **temanın numarasıdır** (`Pricing.getTier`: etkin çiftlik numarası = `THEMES` sırası; tek yer). Alım sırası serbesttir: oyuncu istediği temayı
alır, ama fiyat, çarpan, ada primi ve ürün gereksinimi o **temaya** bağlıdır; çiftlik satın alma bedeli de temanın sırasına göredir
(`MAIN_FARM_PRICES[tema]`, `FarmMath.getPrice(save, "farm", nil, tema)`). 6. temayı ikinci alan oyuncu 6. temanın fiyatını öder; kayıtta `tier` alanı yoktur.
Farklı alım sırasını güncel kaynak ve aynı persona ile yeniden ölç; tarihsel ölçümü her strateji için garanti sayma.

## Formül

```
fiyat = taban fiyat x çiftlik çarpanı x ada sırası çarpanı x n. alım eğrisi        (ada açılışında ayrıca x ada açılış primi)
```

- **Taban fiyat**: Çiftlik 1'in (referans çiftliğin) yazılı fiyatı: `Config/Upgrades`, `Config/Animals`, `Config/Species` (yeni hayvanlar, sıra profili), `Config/Production`
  (tesis ölçeği), `Config/Core.MAIN_FARM_PRICES` (ana çiftlik). Taban, "temel gelir hızı x hedef süre" ile bulunur: bir adımın fiyatı, o adımdaki ideal oyuncunun
  gelirinin hedef süre kadar birikimidir (ilk ada ~15 dk, at ~45, keçi ~110, tüm yükseltmeler ~240-300 dk). Yeni içerik eklerken bu çarpımı hesapla; rakamı
  gelişigüzel yazma (`scripts/simulate-economy.py` ile doğrula). Yeni hayvan satırları (`Species.luau`) sıra profilinden gelir.
- **Çiftlik çarpanı** (`DIFFICULTY.tiers[tema].costMultiplier`): çok çiftlikli ideal oyuncunun her çiftliği `targetMinutes` dakikada (satın almadan tamamlamaya)
  bitirmesi için `--finish-first` sim'iyle ayarlanır (park edilmiş çiftlikler gelir akıttığı için çarpan "bir öncekinin katsayısı" olamaz).
- **Ada sırası çarpanı** (`DIFFICULTY.slotSpread`): temanın erken/orta/geç adası (`THEMES.satellites` sırası; ana ada = 1). Çarpan `1 + slotSpread x (tema - 1) x (sıra - 1)`.
- **Ada açılış primi** (`DIFFICULTY.islandPremium`, `Pricing.getIslandPremium`): yalnızca "island" yükseltmesinin parasını çarpar (ürün gereksinimi, fabrikalar ve genişletmeler
  değişmez). Prim `1 + perTier x (tema - 1) ^ power`; Çiftlik 1'de x1. Amaç **ada ritmi** (aşağıda): Çiftlik 2-6'da ilk ada alınır alınmaz açılmasın (park edilmiş çiftlik geliri
  yüzünden fiyat çarpanı tek başına yetmez: erken ada x32, orta ~x3-5, geç x2,8). Prim sim ile ayarlandı (gerekçe: ritim tablosu).
- **n. alım eğrisi**: hayvan her sahip olunan aynı türle `ANIMAL_PRICE_GROWTH + animalGrowthPerTier x (tema - 1)` kat pahalanır; yapı geliştirme seviye başına
  `BUILD_UPGRADES.costGrowth` / `facilityCostGrowth`; yükseltme maliyeti `UPGRADE_COST_EXPONENT` eğrisinden geçer (`Config/Economy.luau`).
- **Gelir ölçeği yoktur**: hayvan geliri her çiftlikte aynıdır (sıra profili); zorluk yalnızca maliyetten gelir. Böylece ödüller (sipariş, günlük, tesis) kendi
  formüllerinde kalır ve park edilmiş çiftlik gelirinin değeri tutarlıdır.

`kind` değerleri: `"upgrade"` (id = yükseltme), `"animal"` (id = hayvan; level = sahip olunan sayı), `"expansion"` (id = bölge ya da tesis; level = ulaşılmış seviye),
`"farm"` (level = alınacak çiftliğin **tema numarası**; çiftlik çarpanı uygulanmaz). Bilinmeyen kimlik ve en üst seviye `math.huge` döner.

## Hedef süreler

Çiftlik n'nin hedef süresi `referenceMinutes x timeGrowth^(n-1)` dakikadır (`DIFFICULTY.tiers[n].targetMinutes`, 1,5x/kademe). Süre, çok çiftlikli ideal oyuncunun
çiftliği **satın almadan tüm yükseltmelerine kadar** geçen süredir (önceki çiftliklerin park edilmiş geliri dahil); ölçüm `python scripts/simulate-tiers.py`
(= `simulate-economy.py --farms 6 --finish-first`). Gerekçe: `timeGrowth = 1,5` aralığın (1,5-2) alt ucudur; tüm oyun ~4 gün ideal, casual ~16 gün, idle ~29 gün sürer.

**Monotonluk (üç persona).** Çiftlik tamamlama süresi tema 1 -> 6 ideal, casual ve idle personanın HEPSİNDE kesin artar (`simulate-tiers.py --assert-monotonic`; `verify.ps1` çalıştırır).
Oturum sınırlı oyuncuda süre oturum sayısıyla ölçülür; Çiftlik 1'in 3. aşamasına kadar ürün istenmemesi (`DIFFICULTY.goods.tutorialSteps = 3`) Çiftlik 1'i bir
oturum kısaltır, böylece Çiftlik 2 (birikmiş kasa yüzünden aynı oturum sayısında bitebiliyordu) kesin uzun kalır.

**Ada ritmi.** Çiftlik 1'de ilk/orta/geç ada tamamlamanın ~%4 / %16 / %42'sinde açılır (12 / 46 / 118 dk). Çiftlik 2-6'da hedef orantıdır (ideal; satın almadan sonra dk):
ilk ada ~18 / 26 / 39 / 57 / 83, orta ~67 / 101 / 152 / 227 / 341, geç ~173 / 259 / 389 / 583 / 874. Kollar: `islandPremium` (üç sıra için `perTier`, `power`), `slotSpread`, ürün gereksinimi.
Sim ölçümü ve farklı sıra karşılaştırması güncel kaynakla yeniden üretilir.

## Açılışlar ürün de ister (goodsCost)

Ada, bölge, fabrika ve büyük yükseltmeler para yanında ahır deposundan **ürün** de ister (`Config/Upgrades.luau` ve `Species.luau` `goodsCost`, hesap `FarmMath.getGoodsCost`).
Amaç: oyuncu önceki adalara/hayvanlara dönüp üretsin, ama uğraşmasın.

- `goodsCost = { step, shares }`: `step` 1 erken / 2 orta / 3 geç aşama; `shares[kaynak]` = temel para fiyatının bu payı kadar **değerde** ürün.
  Miktar = `pay x temel fiyat x stepBase[step] x (1 + tierGrowth x (tema - 1)) / ürün birim değeri` (yukarı yuvarlanır, en az 1; `DIFFICULTY.goods`).
  Çiftlik 1 öğreticidir: `tutorialSteps` adıma kadar (şimdi hepsi) ürün istemez; ürün gereksinimi Çiftlik 2'de başlar (oyuncu ürün döngüsünü Çiftlik 1'de siparişlerle öğrenir).
- Kaynak ürün temaya göre çözülür (`Config.resolveGoodsSource`): `home` (çiftliğin ana hayvanının ürünü), `previous` (bu adadan önceki ada; ilk adada ana hayvan),
  `slot1..3` (temanın o küçük adasının ürünü), `sea` (balık). Yeni hayvanlı temalar kendi ürünlerini ister; `goodsCost` yeniden yazılmaz.
- Ürün merkezleri ürün istemez (üretim hiç başlayamaz hâle gelmesin). Miktar, açılışın gerektirdiği ahır seviyesinin ürün kapasitesinin `capShare` payını aşmaz.
- Değişmezler (`tests/config.spec.luau`, `tests/economy.spec.luau`): her temada (kendi kademesinde) kaynak çözülür, ürünü üreten merkez temada vardır ve açılışın kendisine
  bağlı değildir (deadlock yok); tüm yükseltmeler ön koşul + ürün sırasıyla alınabilir; gereken ürünün satış değeri para fiyatının altında kalır; `GOODS_BARTER.rate <= GOODS_SELL.rate`.
- Sunucu: `UpgradeService.tryBuy` para ve ürünü `PlayerDataService.trySpend(..., goodsCost)` ile **tek adımda** düşer (biri yetmezse hiçbiri); `RequestBuyUpgrade` (requestId, etkin
  çiftlik doğrulaması, hız sınırı) değişmedi. Arayüz `HudCommon.upgradeVariant/goodsNeedText`: yetmeyen kalem kırmızı, buton `warning`.
- Hayvan türü açılışı ada/bölge açılışıyla birlikte gelir (her ada kendi türünü açar); hayvan alımı ayrıca ürün istemez (takas `GOODS_BARTER` ile çakışmasın).

## Ürün değeri, parti ve sipariş (uçuk sayı koruması)

Para/ürün akışlarının büyüklüğü tek bir kuralla bağlıdır; "bu sayı makul mü" sorusunu `python scripts/audit-economy.py` (verify: `--check`) ve `tests/goods.spec.luau`
"ekonomi değişmezleri" yanıtlar (sınırlar `Config.ECONOMY_LIMITS`, kademe fiyat tavanı `DIFFICULTY.tiers[n].maxPrice`).

- **Kök neden (eski)**: ürünün para değeri sabitti, onu üreten ve ödeyen formüller oyuncunun ANLIK gelirine bağlıydı. Parti miktarı `(kaçırılan gelir + başlatma) x MIN_RETURN / değer`
  tabanıyla gelirle şişiyor (21 birime kadar), sipariş ödülü `max(değer, gelir x 300 sn x ...)` tabanıyla değerin yüzlerce katına çıkıyordu (ödül/değer 240-1000x, satır 30 birim).
- **Ürün değeri hesapla bulunur** (`Config/Goods.luau` "DEĞER KURALI"): tam yükseltilmiş çiftlikte merkezin asgari parti getirisi x ~2,3 (`audit-economy.py` bölüm D; testte `ECONOMY_LIMITS.valueToFloorMin/Max` = 1,8-3,2 bandı).
  Böylece taban miktar (2 birim) bile asgari getiriyi aşar; asgari getiri miktarı şişirerek değil değerle sağlanır.
- **Parti küçüktür**: `FarmMath.getGoodsYield` yetişkin bonusu + tesis verimi + muskayı TOPLAR (çarpmaz), toplam `PRODUCTION_YIELD_MAX_MULT`i, miktar `PRODUCTION_MAX_BATCH_UNITS`i aşamaz.
  Kaçırılan gelir tabanı kalır ama artık yalnızca bu sınıra kadar yükseltir.
- **Sipariş ödülü = ürün değeri x kademe çarpanı (1,05-2) x sipariş bonusu**; gelir tabanı kaldırıldı. Satır birimi kademe değeridir (pahalı üründe `unitRefValue / değer` ile küçülür),
  depo büyüklüğüne ya da gelire bağlı değildir. Sonuç (5 Ekim 2026, `audit-economy.py` bölüm B): ödül/değer 1,05-1,87; ödül ortanca ~0,2-1,5 dk gelir, en çok ~3-5,5 dk (tek sipariş).
- **Sipariş bonusu tavanı, pano boyutu ve bütçesi** (5 Ekim 2026): toplam bonus `GOODS_CONTRACTS.maxBonus` 0,6 ile sınırlıdır (2,0 x 1,6 = 3,2 = `maxRewardRatio`); pano `ceil(ürün x 6)` teklif (6-12); pano ödül toplamı, referans gelir 900/sn'yi aşınca, gelirin 2,5 (erken) - 12 (geç) dakikasını geçmez (`windowBudget`). Hardcore ilk saat sipariş payı %59,6 -> %43,6, 7 gün casual/hardcore %7,4/%12,2 -> %5,0/%9,0; keçi adası (hardcore, kesintisiz) 44,9 -> 55,0 dk, süt fabrikası 45,2 -> 59,4 dk (keçi adası <= ~55 hedefi korunur; pay <= %35 ile tempo hedefi birlikte sağlanamaz, tarama tablosu `docs/URETIM_VE_UZMAN_ADALAR.md` "Sipariş bütçesi"). Günlük ödül: 2,5 dk x en çok 5 (7. gün 12,5 dk gelir; hafta bir günün %2,8'i).
- **Hızlı satış/takas oranı** (`GOODS_SELL/BARTER.rate`) ürün değerinin ölçeğini yansıtır (değer ~2,3x asgari getiri): bir partiyi satmak `PRODUCTION_MAX_RETURN`ı aşmaz, takas satışı aşmaz.
- **Ürün merkezi tarifinin `reward` alanı tesis ölçeğidir** (geliştirme fiyatı tabanı); değerden bağımsız olduğundan değer ayarı fiyat temposunu (Çiftlik 1 referansı) bozmaz.
- **Bilinen denge bedeli** (ilk ölçüm; güncel pay aşağıda "Denetim" bölümünde ve `docs/URETIM_VE_UZMAN_ADALAR.md`): sipariş payı (casual, 7 gün) ~%9,3'ten ~%5'e indi (değer çarpanı ~2,3: en pahalı ürün ~130K; 1 et 1M gibi uçuk fiyat çıkmasın diye bilinçli); hardcore payı ~%9. Gelir tabanı kalktığı için pay artık yalnızca değer çarpanıyla ayarlanır; çarpan büyüdükçe
  tek tek sipariş gelirin dakikalarına yaklaşır (güncel tavan Config.GOODS_CONTRACTS içindedir) (git geçmişindeki eski üretim-tüccar denge notu).

## Hayvan büyümesi (4 Ekim 2026)

- Taban süre `Config.GROWTH_SECONDS`: yavru 400 sn + genç 800 sn = **20 dk**, bütün tür/ada/çiftliklerde aynı (eskiden 40 dk). Yem Silosu (x2) ve Hızlı Büyüme Sv.1-3, bölge geliştirmeleri, muska ve perklerle hız `GROWTH_SPEED_CAP` (4) altında artar; tam geliştirilmiş çiftlikte yeni hayvan ~7 dk'da yetişkin olur.
- **Her türün çiftlikteki ilk `STARTER_ADULT_ANIMALS` (3) hayvanı yetişkin doğar** (`FarmMath.getNewAnimalBornAt(save, now, animalId)`): her yeni adanın üretimi ilk dakikadan başlar; 4. ve sonrası yavrudur. Kayıt şeması değişmez (`bornAt = 0` zaten yetişkin).
- Hızlanan ilk çiftlik, simülasyonun "her çiftlik bir öncekinden uzun" değişmezini en pasif oyuncu tipinde (idle, 12 saatlik oturumlar) eşitliğe düşürdü; Çiftlik 2 maliyet çarpanı 5,9 → 6,4 yapıldı (ideal çiftlik 2 süresi 7,0 → 7,6 sa; hedef 6,9). `simulate-tiers.py --assert-monotonic` yeniden geçer.
- Neden: büyüme süresi gelir dengesinin değil bekleme hissinin kapısıdır. Üretim tarifleri 40-120 sn sürerken yeni tavuk adasında 20+ dk yetişkin beklemek gerekiyordu.
- Ölçüm (aynı koşullar, `compare-economy.py`, 2 tekrar, Çiftlik 1): hardcore `--session 0 --hours 6`: ilk büyüyen yetişkin 22,6 → 12,6 dk; at adası 28,5 → 23,4; keçi adası 52,6 → 44,8; Çiftlik 2 alımı 87,2 → 75,9 dk; ilk çiftliğin yükseltmeleri ~%14-18 daha erken; Çiftlik 1 geliri 6. saatte +%1,4 (Çiftlik 3 anlık geliri alım zamanına bağlı dalgalanır, kararlı bir fark değildir). Casual (3 x 20 dk oturum / gün): ilk büyüyen yetişkin ilk oturumda 12,8 dk'da (eskiden 480. dk, ikinci oturum); ada açılış zamanları oturum aralığına bağlı olduğundan aynı. Sim oyuncu davranışı ya da gerçek FPS/oynanış değildir.

## Yeni içerik eklerken

1. Yeni hayvan: `Config/Species.luau` satırı (sıra profilini seç; rakamlar profilden gelir) + `THEMES` + görsel satırları (`docs/ADA_TASARIMI.md`).
2. Taban fiyatı "gelir hızı x hedef süre" ile hesapla ve ilgili Config dosyasına yaz (Çiftlik 1 ölçeğinde); yeni profil gerekiyorsa sim ile doğrula.
3. Kademe çarpanları, ada primi ya da `slotSpread` değişirse `scripts/simulate-tiers.py --personas ideal,casual,idle --assert-monotonic` ile ölç (`--mults`, `--premium`,
   `--slot-spread`, `--goods-tier`, `--goods-step` Config'e dokunmadan dener; `--order 1,6,5,4,3,2` en kötü alım sırasını ölçer); `tests/economy.spec.luau` kademe monotonluğunu denetler.
4. Fiyatı elle çarpma; `FarmMath.getPrice` (ya da sarmalayıcıları `getUpgradeCost/getAnimalPrice/getBulkPrice/getExpansionCost`) kullan.

## Pano ürünleri (yalnızca üretilebilenler)
`Contracts.availableGoods`: pano yalnızca etkin çiftlikte ŞU AN üretilebilen ürünü ister: merkez kurulu, adası açık, tarif çiftliğin temasında ve merkezin gerektirdiği kadar o türden hayvan açık bölgede.
Açılmamış ada, kurulmamış merkez, başka temanın ya da park edilmiş çiftliğin ürünü sipariş edilmez (çiftlik değişince pano değişir). Stoktaki başka çiftlik ürünü "Hepsini/Yarısını sat" ile paraya çevrilir.

## Ekipman gücü ölçümü (5 Ekim 2026)

`python scripts/simulate-items.py` (gerçek Config/FarmMath; ~42 dk, 14 paralel koşu; `--probe` koşusuz akış/tavan denetimi, `--what-if` Config'e dokunmadan etki dener, `--reanalyze` kayıtlı ölçümden analizi yeniler). Tek eşya = yalın tabana (R5'te ücretsiz R1-5 eşyaları çıkarılmış) tek eşya takılı; ölçü = altı çiftlik temel turun takvim günü. Taban (gün): ideal R0 5,26 / R5 4,57; casual R5 17,0-17,3 (kaynak sürümüne göre; eşzamanlı Config değişimleri casual'ı ±0,3 gün oynatır). Çözünürlük: ideal ±%0,4; casual 8 sa kuantalı (tek eşya ±%2 gürültü); idle ölçülmedi (`--idle`). Hareket hızı, hayvan satış geliri (`sellBonus`) ve asa güçleri modellenmez: 70 eşyadan 43'ünün değeri alt sınırdır. Etki akışı: 164/164 etki gerçek tüketiciye beklenen oranda ulaşıyor; tavanlar (hareket %25, tesis %50, gelir x3, ödeme %90) tutuyor.

| Takım (yuva başına ölçülmüş en iyi) | altın eşd. | ideal R5 | casual R5 | ideal R0 | kaç rebirth altını |
|---|---|---|---|---|---|
| starter (yalnız nakit) | 1150 | %2,8 (0,13 g) | %17 (offline) | %1,9 | 2 |
| mid (nakit+nakit/altın) | 1810 | %12 (0,55 g) | %37 | %12 | 3 |
| premium (en iyi satılanlar) | 4350 | %60 (2,7 g) | %69 (12 g) | %60 | 6 |
| endgame (+ödüller) | 3800 | %60 | %69 | %60 | 5 |

Ücretsiz R1-R5 eşyaları: ideal %-0,1, casual %+3,8 (Rüzgar Muskası ve Tüccar Şapkası tempoya katkı vermez; değerleri hareket/sipariş).

Bulgular (ideal R5, tek eşya):
- **Altın formülü fayda ile uyumsuz**: Spearman 0,36; kademe 1-2 ortanca fayda %0 (25 eşya), kademe 3-5 ortanca %0,1-0,2; 70 eşyadan 29'u hiçbir kişide %0,5'i geçmiyor. Ölçülen kabaca değer: 1 puan tempo ≈ 36 altın (uyum doğrusu `fayda = -3 + 0,028 x altın`). Alet yuvası tutarlı (Bakır 2,8 < Demir 5,5 < Altın 10,8 < Elmas 12,1 < Ustabaşı 12,6); diğer yuvalar değil.
- **Fazla güçlü (>%10)**: Altın Taç %50 (gelir +%100, 1500 altın; adil bedeli ~1900 altın), Ustalık Tacı (R30) %20, Ustabaşı Tokmağı %12,6, Elmas Çekiç %12,1, Mühendis Anahtarı %11,7, Altın Çekiç %10,8. Gün/100 altın: Altın Taç 0,154; çekiçler 0,075-0,083; Demir Çekiç 0,064; en kötüler (≈0): Tüccar Mührü, Kaptan Şapkası, Kervan Çantası, Ulak Çantası, Tüccar Tacı, Pazarlık Muskası, Ambar Çantası.
- **Ölü yük (<%0,5 her kişide; 29 eşya)**: dört mevsim asası, Çırak/Ebedi hava asası, iki büyüme tılsımı, Bilge Tılsımı, Çiftçi/Kasket/Tavuk/Kovboy/Hasır şapka, çanta/sepet, Tüccar Şapkası, Pazarlık Muskası, Tüccar Tacı, Kervan/Ulak Çantası. Nedenleri: `contractBonus` sipariş payı ~%5 olduğundan sıfır; büyüme hızı R5'te doygun; `goodsYield` tüm tariflerde taban 2 birim olduğundan `floor(2 x çarpan)` yalnız toplam >=+%50'de artar (Altın Ambar Anahtarı +%25 bile ≈0); asa güçleri ve satış/hareket modellenmez.
- **Offline eşyaları casual'a ait**: `offlineBonus` ideal'de 0, casual'da en güçlü kol: Gece Nöbeti Muskası (+0,45) %24-25 (450 altın), Servet Tılsımı %25, Büyük Depo Muskası (ücretsiz R3 ödülü, 350 altın) %12-13, Keşif/Ambar Çantası %13. Tek 350 altınlık eşya 740 altınlık Elmas Çekiç'in (casual %16) yarısı kadar tempo verir.
- **Kademe/yuva ihlalleri**: asa yuvası (Kademe 4 Üretim Asası %0,3 < Kademe 2-3 hava asaları %7-9 (offline)), baş yuvası (Kademe 1 %3,8 > Kademe 2-4 %0), sırt/tılsım yuvası (dar fiyat bandında 5-6 eşya birbirinden ayrışmıyor); aynı yuvada 60 pahalı-ucuzdan-zayıf çifti.
- **Bütçe**: bir rebirth 750-880 altın (R30 1260). Yuva başına tek eşya kuralıyla en çok kazandıran sıra: R1 Ustabaşı (700), R2 Altın Kanatlar, R3 Altın Bereket Muskası, R4 Üstat Çoban Asası, R6 Altın Taç; yani ~üç rebirth'te %12'lik orta takım, altı rebirth'te ~%60'lık premium takım. Kazançlar toplanmaz, çarpılır (tek tek toplam %79, ölçülen %60).

Uygulanan değişiklikler (5 Ekim 2026, ikinci tur): `simulate-items.py --items ... --states ideal:5,casual:5` ile gerçek Config'te yeniden ölçüldü (taban ideal R5 4,57 g, casual R5 17,0 g; casual bu turda 17,33 yerine 17,0 ölçüldü, bu yüzden casual sütunları ±%2 gürültülüdür). Yüzde = tek eşya tur kısalması.
| Eşya | Etki (eski -> yeni) | ideal R5 önce -> sonra | casual R5 önce -> sonra | Altın önce -> sonra |
|---|---|---|---|---|
| Altın Taç | `incomeBonus` 1,0 -> 0,4 | %50,5 -> %29,0 | %48,1 -> %27,4 | 1500 -> 1180 |
| Elmas Çekiç | `upgradeDiscount` 0,20 -> 0,15 (referans fiyat 3,5M -> 2,3M) | %12,1 -> %10,9 | %17,3 -> %13,7 | 740 -> 750 |
| Altın Çekiç | `upgradeDiscount` 0,15 -> 0,14 (aile sırası) | %10,8 -> %8,7 | %13,5 -> %11,8 | 600 -> 680 |
| Atölye Çekici | + `upgradeDiscount` 0,10 | %3,7 -> %11,7 | %7,6 -> %13,7 | 550 -> 730 |
| Gece Nöbeti Muskası | `offlineBonus` 0,45 -> 0,25 | %0 -> %0 | %25,0 -> %13,7 | 450 -> 320 |
| Büyük Depo Muskası | `offlineBonus` 0,20 -> 0,10 | %0 -> %0 | %13,5 -> %5,9 | 350 -> 200 |
| Tüccar Şapkası | + `incomeBonus` 0,04 | %0 -> %4,3 | %1,9 -> %3,9 | 340 -> 250 |
| Pazarlık Muskası | + `incomeBonus` 0,06 | %-0,1 -> %6,0 | %1,9 -> %5,9 | 650 -> 560 |
| Bilge Tılsımı | + `incomeBonus` 0,05 | %0,2 -> %4,8 | %1,9 -> %5,8 | 620 -> 540 |
| Tüccar Tacı | + `incomeBonus` 0,08 | %0 -> %7,7 | %1,9 -> %7,8 | 890 -> 620 |
| Kaptan Şapkası | + `incomeBonus` 0,04 | %0 -> %4,3 | %1,9 -> %3,9 | 640 -> 400 |
| Ulak Çantası | + `offlineBonus` 0,05 | %0 -> %0 | %1,9 -> %3,9 | 600 -> 400 |
| Kervan Çantası | + `offlineBonus` 0,10 | %0,1 -> %0,1 | %1,9 -> %5,9 | 770 -> 470 |

Altın bedeli kuralı artık ölçülen faydadan türer: `min(1500, yuvarla10(taban + 28 x puan))`; taban cashGold 150, goldRobux/gold 400; puan = (ideal R5 % + max(casual R5 % - 2, 0)) / 2 + 15 x hareket + 8 x satış (hareket/satış simüle edilmediği için küçük sabit kredi). Ölçüm tablosu `tests/config.spec.luau` `TEMPO_POINTS`, kural Progression.luau yorumunda; aynı kanalda daha çok tempo veren eşya daha ucuz olamaz (test). Sonuç: ölü yük eşya taban fiyatta (150-160 cashGold, 400-420 premium), Altın Çekiç/Elmas/Mühendis/Ustabaşı 680-790, Servet Tılsımı 830, Altın Taç 1180 (~1,5 rebirth). Değişmeyen ölçümler eski koşudan alındı (casual ±%2). Henüz kalan: mevsim/hava asaları ve büyüme tılsımı ölü (taban fiyatta), `contractBonus` ve `goodsYield` mekaniği bilerek düzeltilmedi. `scripts/simulate-items.py` içindeki eski `formula_gold` artık "uyumsuz" bildirir (bilgi amaçlı).

Ek: tarif `goodsAmount`'ı 2 iken `goodsYield` anlamsız; ya miktarı artır ya etkiyi `PRODUCTION_BONUS_PER_ADULT` basamağına (0,25) bağla.

## Uzun süre sonra dönen oyuncu (6 Ekim 2026)

Şikayet: "5-10 saat sonra dönünce yalnız 2 yükseltme alabiliyorum, sıkıcı". Ölçüm: gerçek Config/FarmMath, `simulate-economy.py` düzeni + geçici ölçüm kancaları (repoya eklenmedi; Config'e dokunulmadı). Kesintisiz casual yolunda ara anlarda "X saat uzakta kalsaydı" hesabı (tüm çiftlikler ayrı ayrı çevrimdışı öder; yardımcı/üretim çevrimdışı çalışmaz). Gelir dakikası = tüm çiftliklerin toplam gelirinin dakikası; "sıradaki yükseltme" = etkin çiftlik gelirinin dakikası.

| Evre (kesintisiz yolun saati) | Sıradaki yükseltme | 1 sa | 5 sa | 8 sa | 24 sa | Dönüşte alınan (5 sa / 8 sa) |
|---|---|---|---|---|---|---|
| 1 sa, Çiftlik 1 (Pasif Gelir yok) | 2 dk | 19 dk | 38 | 38 | 38 | 20 yükseltme + 8 hayvan |
| 8 sa, Çiftlik 3 | 34 dk | 21 | 104 | 104 | 104 | 10 + 6 |
| 24 sa, Çiftlik 4 | 136 dk | 21 | 105 | 105 | 105 | 3 + 1 |
| 48 sa, Çiftlik 5 | 406 dk | 22 | 109 | 109 | 109 | 1 + 2 |
| 72-96 sa, Çiftlik 6 | 529-707 dk | 22 | 108-115 | aynı | aynı | 2 + 0-6 |

Sürekli çevrimiçi oyuna göre dönüş değeri (tüm çiftlikler, Pasif Gelir varken): 1 sa %35, 5 sa %35, 8 sa %22, 12 sa %15, 24 sa %7; Pasif Gelir yokken 5/8/24 sa %10/%7/%2. Kök nedenler, ağırlık sırasıyla:
1. **Yükseltme bedeli geç evrede saatlerce gelir** (etkin çiftlik geliri: 2 dk -> 116 -> 406 -> 707 dk; Çiftlik 6 sonunda 2267 dk); dönüş ise en çok ~105-115 toplam gelir dakikası. Alım sayısı = dönüş değeri / bedel; çevrimdışı ayarı bunu geç evrede düzeltemez (bedel-tempo takası, bilinçli tasarım: Çiftlik n+1 süresi 1,5x).
2. **Sert süre kesintisi**: 2 sa (Pasif Gelir 5 sa) sonrası kazanç sabit; 5 sa = 8 sa = 24 sa. 8 sa uzakta kalan temel katmanda ~30 dk (%6), Pasif Gelirle 90 dk gelir kazanır.
3. **Ürün darboğazı yeni çiftlikte**: Çiftlik 2 alındıktan 24 sa sonra 1 sa dönüşte 2 yükseltme (ürün yetmiyor) vs ürün istenmeseydi 13; 5 sa'te 6 vs 39. Üretim ve yardımcılar çevrimdışı çalışmaz; 3-47 hazır parti dönüşte elle toplanmayı bekler.
4. **Dönüş ekranı bilgi vermiyor**: yalnız "+X kazandın"; süre sınırı, Pasif Gelir farkı gösterilmiyor (`capped` yalnız telemetride). Sipariş panosu 7 dk'lık pencere olduğundan çevrimdışıyken birikmez.
5. Erken oyun şikayet kaynağı değil (dönüşte 11-20 yükseltme); günlük ödül küçük (2,5 dk x seri) ve bir gün atlanınca seri sıfırlanır.

Çözüm paketleri (`--persona X --farms 6 --finish-first --completion basic --stop-at-rebirth`, ilk tur takvim günü, 4 faz ortalaması; casual 8 sa, idle 12 sa, hardcore 6 sa oturum aralığı). Hardcore ilk saat aynı (ada 0,13/0,39/0,92 sa her pakette; çevrimdışı kalmaz).

| Paket | hardcore | casual | idle | çevrimdışı gelir payı c/i | dönüş değeri c/i (dk) |
|---|---|---|---|---|---|
| Mevcut | 10,10 | 19,46 | 34,19 | %77/%88 | 98/95 |
| A kuyruk: tam bölgeden sonra +4 sa %30, +4 sa %15 | 10,04 | 17,63 | 27,06 | %80/%90 | 112/128 |
| **A + C-hafif (önerilen)**: A + dönüş sandığı 2 dk/uzak saat (4-8 sa, tavan 16 dk referans gelir) | 9,85 | 16,79 | 26,19 | %78/%88 | 117/133 |
| A + C-güçlü (4 dk/sa, tavan 32) | 9,84 | 16,46 | 25,19 | %76/%86 | 122/141 |
| B-hafif: taban 3 sa, Pasif 6 sa/%35 | 9,34 | 15,13 | 26,19 | %83/%91 | 134/133 |
| B: taban 4 sa/%30, Pasif 8 sa/%40 | 8,78 | 11,38 | 19,19 | %88/%94 | 197/199 |
| C yalnız sandık (5 dk/sa, tavan 40) | 9,74 | 18,13 | 30,81 | %72/%80 | 108/108 |
| D çevrimdışı yardımcı 1 sa / 4 sa | 9,35 / 8,04 | 18,54 / 16,63 | 32,06 / 27,69 | %73/%81 · %63/%67 | 98 |

Önerilen paketin dönüş etkisi (5/8/12 sa, gelir dk -> alım): Çiftlik 1: 38 -> 65/82/88 dk, 20+8 -> 28+10/32+15/33+15; Çiftlik 3: 104 -> 108/129/145, 10 -> 10/11/12; Çiftlik 5-6: 108 -> 111-112/132-133/148-149, geç evrede alım sayısı değişmez (2). Açık sınır: geç evre için bedel/adım yapısı (daha çok, daha ucuz adım) ya da daha yüksek tempo gerekir; yalnız çevrimdışı ayarıyla çözülmez. Tuzak: `simulate-tiers.py --assert-monotonic` idle'da ince ayara duyarlı (A+C-güçlü Tema 3 < Tema 2; önerilen paket geçer); uygulamadan sonra yeniden çalıştır. D hardcore tempoyu da bozduğu için (yardımcı üretimi çevrimdışı çarpılır) önerilmez.

Uygulandı (6 Ekim 2026, A + hafif sandık): `Config/Economy.luau` `OFFLINE_TAIL` (4 sa x0,30 + 4 sa x0,15 çevrimdışı oran) ve `OFFLINE_RETURN_CHEST` (>=4 sa uzakta: uzak saat başına 2 dk güncel gelir, 8 saatte durur, tavan 16 dk). Sandık durumsuzdur, `FarmMath.computeOfflineEarnings` içinde hesaplanır (yeni kayıt alanı/Remote yok); dönüş ekranı, kazanç sınırı aşıldığında (`FarmMath.isOfflineEarningsCapped`) süre sınırını açıklar. Testler: `economy.spec` (kuyruk, sandık, tavan), `data.spec`, `welcome-back-lines.spec`.
