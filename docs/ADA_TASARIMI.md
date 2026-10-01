# Ada ve hayvan tasarımı (24 hayvan, 6 çiftlik)

Bu belge çiftlikler arası çeşitliliğin **tasarımıdır**; rakamlar `src/shared/Config/` içindedir (burada yalnızca gerekçe ve hedef). Zorluk/fiyat mantığı
[Zorluk ve dinamik fiyat](ZORLUK_VE_FIYAT.md), fabrika kuralları [Üretim ve uzman adalar](URETIM_VE_UZMAN_ADALAR.md) belgelerindedir.

## Temel yapı

- 6 ana çiftlik (`Config.THEMES`). Her çiftlik = 1 ana ada + 3 küçük (uydu) ada = 4 ada. **Her adada tek bir hayvan türü** yaşar (ana adada çiftliğin `homeAnimal`ı,
  küçük adalarda `FARM_ISLANDS[ada].animalId`). Çiftlik başına 4 hayvan; **hiçbir hayvan iki çiftlikte yoktur** (6 x 4 = 24 benzersiz tür; balık "Deniz" dalı her çiftlikte ortaktır, 24'e girmez).
- Hayvan → ada → çiftlik eşlemesi tek yerde tutulur: `THEMES` (ana hayvan + `satellites` sırası) ve `FARM_ISLANDS[ada].animalId`; `Config.getAnimalTheme(hayvan)` bunlardan türer.
- Süt Adası (`dairy`) yoktur: inek yalnızca Çiftlik 1'in ana adasında yaşar. Ördek yalnızca Çiftlik 2'nin ana adasında, tavuk yalnızca Çiftlik 1'in Tavuk Adası'nda.
- Küçük adalar `THEMES.satellites` sırasıyla **erken / orta / geç** açılır (ahır seviyesi 2 / 3 / 4). Çiftlik 1'de tempo korunur (tavuk, at, keçi: ~12 / 46 / 118 dk).
  Çiftlik 1 için istek listesindeki "At, Keçi, Tavuk" sırası küme tanımıdır; açılış sırası mevcut tempoyu korumak için tavuk (erken), at (orta), keçi (geç) kaldı.

## 24 hayvan: çiftlik x ada x hayvan x ürün x fabrika

Para fabrikası = yükseltme (gelir artışı + parti üretimi, `cash`); ürün merkezi = depoya ürün üretir (`goods`). Her hayvanda ikisi de vardır; fabrika yalnızca kendi adasında kurulur
(`tests/config.spec.luau`). Ana ada fabrikaları `homeAnimal` işaretiyle yalnızca o ana hayvanlı çiftlikte vardır.

| Çiftlik | Ada (sıra) | Hayvan | Ürün (`GOODS`) | Para fabrikası (tarif / yükseltme) | Ürün merkezi (tarif / yükseltme) | Ada özelliği | Dekor kimliği |
|---|---|---|---|---|---|---|---|
| 1 Klasik Çayır (`papatya`) | Ana ada | İnek | Süt (`milk`) | `packed_milk` / `milk_factory` | `milk_goods` / `milk_center` | — | papatya anıtı |
| | Tavuk Adası (erken) | Tavuk | Yumurta (`egg`) | `hatchery` / `hatchery` (+`egg_factory`) | `egg_goods` / `egg_center` | Üretim tesisleri %12 hızlı | kümes, folluk |
| | At Adası (orta) | At | Nal (`horseshoe`) | `horse_training` / `horse_training` (+`golden_horseshoe`) | `horseshoe_goods` / `horseshoe_forge` | Sipariş ödülü +%8 | parkur |
| | Keçi Adası (geç) | Keçi | Peynir (`cheese`) | `cheese` / `cheese_dairy` | `cheese_goods` / `cheese_cellar` | Çevrimdışı kazanç +%25 | kayalık |
| 2 Göl ve Yün (`lale`) | Ana ada | Ördek | Tüy (`down`) | `duck_packing` / `duck_packer` | `down_home_goods` / `down_home_center` | — | lale anıtı |
| | Tavşan Adası (erken) | Tavşan | Angora (`angora`) | `angora_spinning` / `angora_mill` | `angora_goods` / `angora_loom` | Depo kapasitesi +%15 | tavşan yuvaları |
| | Koyun Adası (orta) | Koyun | Yün (`wool`) | `wool` / `wool_mill` | `wool_goods` / `wool_loom` | Ürün merkezi verimi +%10 | yamaç |
| | Domuz Adası (geç) | Domuz | Et (`meat`) | `truffle` / `truffle_kitchen` | `meat_goods` / `meat_smokehouse` | Geliştirme maliyeti -%8 | çam ormanı |
| 3 Güneşli Tarla (`aycicegi`) | Ana ada | Hindi | Hindi Füme (`smoked_turkey`) | `turkey_packing` / `turkey_packer` | `turkey_goods` / `turkey_center` | — | ayçiçeği anıtı |
| | Arı Adası (erken) | Arı | Bal (`honey`) | `honey_bottling` / `honey_mill` | `honey_goods` / `honey_extractor` | Tesisler %10 hızlı | kovanlar |
| | Deve Adası (orta) | Deve | Deve Sütü (`camel_milk`) | `camel_caravan` / `caravan_post` | `camel_goods` / `camel_dairy` | Çevrimdışı kazanç +%20 | çöl kayalığı |
| | Tavus Adası (geç) | Tavus Kuşu | Tavus Tüyü (`peacock_feather`) | `peacock_show` / `peacock_pavilion` | `peacock_goods` / `peacock_atelier` | Satış geliri +%15 | gösteri köşkü |
| 4 Gül Vadisi (`gul`) | Ana ada | Manda | Kaymak (`buffalo_cream`) | `buffalo_packing` / `buffalo_packer` | `buffalo_goods` / `buffalo_center` | — | gül anıtı |
| | Bıldırcın Adası (erken) | Bıldırcın | Bıldırcın Yumurtası (`quail_egg`) | `quail_packing` / `quail_hatchery` | `quail_goods` / `quail_coop` | Depo kapasitesi +%15 | tahıl tarlası |
| | Güvercin Adası (orta) | Güvercin | Posta (`pigeon_post`) | `pigeon_courier` / `pigeon_loft` | `pigeon_goods` / `pigeon_office` | Sipariş ödülü +%10 | güvercinlik kulesi |
| | Salyangoz Adası (geç) | Salyangoz | Kaviyar (`snail_caviar`) | `snail_gourmet` / `snail_bistro` | `snail_goods` / `snail_cellar` | Ürün merkezi verimi +%12 | nemli bahçe |
| 5 Dağ ve Orman (`yonca`) | Ana ada | Yak | Yak Kürkü (`yak_fur`) | `yak_packing` / `yak_packer` | `yak_goods` / `yak_center` | — | çam anıtı |
| | Lama Adası (erken) | Lama | Lama Kumaşı (`llama_cloth`) | `llama_weaving` / `llama_loom` | `llama_goods` / `llama_workshop` | Ürün merkezi verimi +%10 | dağ yolu |
| | Geyik Adası (orta) | Geyik | Boynuz (`antler`) | `deer_carving` / `deer_lodge` | `deer_goods` / `deer_forge` | Geliştirme maliyeti -%7 | orman açıklığı |
| | Şahin Adası (geç) | Şahin | Av Ödülü (`falcon_trophy`) | `falcon_hunt` / `falcon_perch` | `falcon_goods` / `falcon_hall` | Sipariş ödülü +%10 | kaya zirvesi |
| 6 Meyve Bahçesi (`kiraz`) | Ana ada | Sincap | Fındık (`hazelnut`) | `squirrel_packing` / `squirrel_packer` | `squirrel_goods` / `squirrel_center` | — | kiraz anıtı |
| | İpek Böceği Adası (erken) | İpek Böceği | İpek (`silk`) | `silk_spinning` / `silk_mill` | `silk_goods` / `silk_loft` | Tesisler %12 hızlı | dut bahçesi |
| | Papağan Adası (orta) | Papağan | Gösteri Bileti (`parrot_ticket`) | `parrot_show` / `parrot_theatre` | `parrot_goods` / `parrot_box` | Satış geliri +%15 | tropik bahçe |
| | Kaplumbağa Adası (geç) | Kaplumbağa | Hediyelik Kabuk (`tortoise_shell`) | `tortoise_craft` / `tortoise_workshop` | `tortoise_goods` / `tortoise_vault` | Çevrimdışı kazanç +%30 | lagün |

Ürün kimlikleri benzersizdir (Config testi); ada özellikleri mevcut etki anahtarlarını kullanır (`facilitySpeed`, `contractBonus`, `offlineBonus`, `storageBonus`, `goodsYield`, `sellBonus`, `expansionDiscount`),
yeni etki kodu gerekmez. Dekor kimliği: ada başına `World/` süsü (ağaç türü, yapı) ve `Presentation/` hayvan/yapı görünümü (`AnimalLooks`, `SpeciesLooks`); renk ve şekil çiftlikten çiftliğe farklıdır.

## Hayvan başına gelir/fiyat

Fiyat ve gelir **Çiftlik 1 ölçeğinde** yazılır; çiftlik çarpanı `FarmMath.getPrice` ile gelir (elle çarpma yok). Yeni hayvan, ada sırasının profiline (`Config/Species.luau` `PROFILES`) göre
mevcut hayvanlarla aynı bantta durur; böylece Çiftlik 1 ve mevcut hayvanların sim ayarı bozulmaz:

| Sıra | Bant (fiyat / gelir sn) | Mevcut örnek | Yeni hayvanlar |
|---|---|---|---|
| Ana ada | 400-620 / 5,5-7,5 | ördek 400/5,5 | hindi, manda, yak, sincap |
| Erken ada | 350-420 / 5-5,6 | tavuk 350/5 | tavşan, arı, bıldırcın, lama, ipek böceği |
| Orta ada | 1200-1450 / 12-13,5 | at 1200/12, koyun 1400/13 | deve, güvercin, geyik, papağan |
| Geç ada | 2000-2300 / 24-27 | keçi 2000/24, domuz 2200/26 | tavus, salyangoz, şahin, kaplumbağa |

Fabrika (para) ve ürün merkezi sayıları da sıra profilinden gelir (parti seçenekleri, süre, ürün miktarı, açılış maliyeti); ürün birim değeri sıra bandındadır
(ana ada ~500-900, erken ~450-800, orta ~1300-2200, geç ~5000-9000).

## Ürün gereksinim zinciri (açılış)

Her açılış para yanında ürün ister (`goodsCost`; `Config.resolveGoodsSource`): kaynaklar çiftlikten bağımsız yazılır, temaya göre çözülür, bu yüzden yeni hayvanlar kalıbı bozmaz.

| Açılış | Kaynak (pay) | Anlam |
|---|---|---|
| Erken ada (adım 1) | `home` .05 | ana hayvanın ürünü (Çiftlik 1'de ücretsiz, öğretici) |
| Orta ada (adım 2) | `home` .04 + `previous` .04 | ana hayvan + erken adanın ürünü |
| Geç ada (adım 3) | `home` .03 + `previous` .03 + `slot1` .03 | ana + orta + erken adanın ürünü |
| Fabrika (para) | `previous` .04 (erken), .03-.02 (orta/geç) | bir önceki adanın ürünü |
| Ürün merkezi | yok | üretim hiç başlayamaz hâle gelmesin |

Deadlock yok: bir açılışın kaynağı olan ürünün merkezi, açılışın kendisine bağlı değildir ve yalnızca daha erken bir adaya/ahır seviyesine ihtiyaç duyar (`tests/config.spec.luau`: her temada ve kademede
çözülür, en ağır kademede tüm yükseltmeler alınabilir). Yeni ürünler depo, ahır siparişi ve takasa `GOODS`/`GOODS_ORDER` ile girer; sipariş panosu `Contracts.availableGoods` ile yalnızca
kurulu ürün merkezlerinin ürünlerini sunar (çiftlik çeşitliliği doğal olarak ürün çeşitliliği olur).

## Hedef süreler

- **Kademe = tema numarası.** Fiyat çarpanı çiftliğin temasından gelir (`Pricing.getTier`); alım sırası serbesttir (6. temayı ikinci alan oyuncu 6. temanın fiyatını öder ve çiftlik satın alma
  bedeli de temanın sırasına göredir: `MAIN_FARM_PRICES[tema]`). Kademe büyüdükçe çiftlik çarpanı artar (`DIFFICULTY.tiers`); gerekçe `ZORLUK_VE_FIYAT.md`.
- Çiftlik tamamlama süresi (ideal): 283 / 414 / 621 / 932 / 1397 / 2096 dk (`DIFFICULTY.targetMinutes`, 1,5x/kademe). Casual ve idle oyuncuda da süre tema 1 -> 6 **monoton artar** (`scripts/simulate-tiers.py --assert-monotonic`, `tests/economy.spec.luau`).
- Ada ritmi: Çiftlik 1'in 12 / 46 / 118 / 283 dk (ilk / orta / geç ada / tamam) oranı hedef alınır: ilk ada tamamlamanın ~%4'ü, orta ~%16'sı, geç ~%42'si.
  Çiftlik n için hedef (ideal; satın almadan sonra): ilk ada ~12 x 1,46^(n-1), orta ~46 x 1,46^(n-1), geç ~118 x 1,46^(n-1) dk (yani tamamlamayla aynı orantı). Gerekçe: oyuncu yeni çiftliği alınca hemen ilk adaya
  yetişmeli ama "alınır alınmaz" açılmamalı; orta ve geç ada kademeyle birlikte uzar. Kollar: `DIFFICULTY.slotSpread`, ada sırası ağırlıkları, açılış ürün gereksinimi.
- Ölçülen değerler ve en kötü alım sırası: `docs/DURUM_RAPORU.md` ve `ZORLUK_VE_FIYAT.md` (sim çıktısı).

## Kayıt

Oyun yayında değildir; eski kayıtlar sıfırlanabilir. Tema/ada/hayvan kimlikleri değişince `SessionLock.VERSION` artar; eski sürümdeki kayıt çökmeden temiz yeni oyuna döner. Hiçbir tema/ada göçü yazılmaz.

## İleriki iş (kapsam dışı)

- Hayvanların çiftlikler arası karışması/tekrarı (aynı hayvanın birden çok çiftlikte yaşaması), çiftlik içi hayvan değişimi gibi son oyun akışı bu işte yoktur.
- Veri modeli buna engel olmaz: hayvan -> ada eşlemesi `FARM_ISLANDS[ada].animalId` ve `THEMES` ile tek yerdedir; "benzersiz hayvan" kuralı yalnızca `tests/config.spec.luau`'daki bir değişmezdir, kodda gömülü değildir.
- Hayvan görünümleri, fabrika ve ada dekoru `AnimalLooks`/`SpeciesLooks` tablolarındaki satırlardır; ileride bir tür başka bir çiftlikte yeniden kullanılırsa görsel yeniden yazılmaz.
