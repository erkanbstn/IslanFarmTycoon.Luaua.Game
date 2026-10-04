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
- **Ürün değeri hesapla bulunur** (`Config/Goods.luau` "DEĞER KURALI"): tam yükseltilmiş çiftlikte merkezin asgari parti getirisi x ~9 (`audit-economy.py` bölüm D; testte 6-14 bandı).
  Böylece taban miktar (2 birim) bile asgari getiriyi aşar; asgari getiri miktarı şişirerek değil değerle sağlanır.
- **Parti küçüktür**: `FarmMath.getGoodsYield` yetişkin bonusu + tesis verimi + muskayı TOPLAR (çarpmaz), toplam `PRODUCTION_YIELD_MAX_MULT`i, miktar `PRODUCTION_MAX_BATCH_UNITS`i aşamaz.
  Kaçırılan gelir tabanı kalır ama artık yalnızca bu sınıra kadar yükseltir.
- **Sipariş ödülü = ürün değeri x kademe çarpanı (1,05-2) x sipariş bonusu**; gelir tabanı kaldırıldı. Satır birimi kademe değeridir (pahalı üründe `unitRefValue / değer` ile küçülür),
  depo büyüklüğüne ya da gelire bağlı değildir. Sonuç: ödül/değer 1-2,2; ödül ortanca ~0,5-4 dk gelir (en çok ~14 dk, yalnızca orta evre fixture'ında).
- **Hızlı satış/takas oranı** (`GOODS_SELL/BARTER.rate`) ürün değerinin ölçeğini yansıtır (değer ~2,3x asgari getiri): bir partiyi satmak `PRODUCTION_MAX_RETURN`ı aşmaz, takas satışı aşmaz.
- **Ürün merkezi tarifinin `reward` alanı tesis ölçeğidir** (geliştirme fiyatı tabanı); değerden bağımsız olduğundan değer ayarı fiyat temposunu (Çiftlik 1 referansı) bozmaz.
- **Bilinen denge bedeli**: sipariş payı (casual, 7 gün) ~%9,3'ten ~%5'e indi (değer çarpanı ~2,3: en pahalı ürün ~130K; 1 et 1M gibi uçuk fiyat çıkmasın diye bilinçli); hardcore payı ~%9. Gelir tabanı kalktığı için pay artık yalnızca değer çarpanıyla ayarlanır; çarpan büyüdükçe
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
