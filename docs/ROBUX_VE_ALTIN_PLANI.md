# Altın, Robux marketi ve rebirth seviyeleri planı

Durum: **altın, kalıcı sahiplik ve ürün ödülleri uygulandı**; 4 Ekim 2026'da 34 Developer Product ve üç geçit kimliği bağlandı (Kalıcı Altın Kanatlar ve Rüzgar Muskası dahil). Gerçek satın alma/reconnect kabul testi ve yayın ayrı adımdır. Güncel teslim: [DEVIR_DURUMU.md](DEVIR_DURUMU.md).


## Oyuncular arası para gönderimi ve PolicyService

Nakit paketleri Robux'la satıldığından oyuncudan oyuncuya para gönderimi temkinli bir ürün kararıyla Roblox'un `IsPaidItemTradingAllowed` politikasına bağlanmıştır. Resmî belge bayrağı "Robux veya oyun içi parayla alınan sanal eşyaların oyuncular arası takası" için tanımlar; nakdi kapsamda saymak bu belgenin zorunlu bir yorumu değil, bilinçli bir kısıttır (kapsam dışı sayılırsa kapı tek yerde kaldırılır).

- Sunucu `TradePolicyService`, oyuncu katılınca `PolicyService:GetPolicyInfoForPlayerAsync` çağırır (`pcall`). Değer yalnızca bellekte tutulur, kayda yazılmaz, oyuncu ayrılınca silinir.
- Yalnızca açıkça `true` izin verir. Yükleniyor, API hatası, eksik/boolean olmayan yanıt ve `false` yeni gönderimi reddeder. Geçici hata 3 denemeyle (2 sn, 5 sn) yeniden denenir; sonra `unavailable`, en erken 30 sn arayla tembel yeniden deneme.
- `TransferService.trySend` hem göndereni hem alıcıyı sunucuda denetler; istemcinin gönderdiği hiçbir izin değeri okunmaz. Alıcı kısıtlıysa gönderene sebep açıklanmaz ("Bu oyuncuya şu anda para gönderilemiyor.").
- Önceden kabul edilmiş outbox/inbox kayıtları politika değişse de uzlaştırılır (`reconcile` kapıdan geçmez); borç silinmez.
- İstemci kendi durumunu `RequestTradePolicy` ile ister, `TradePolicyState` ile alır; başkasının durumu gönderilmez. Para gönderme penceresi izin yoksa devre dışıdır ve sebebi gösterir.
- Rastgele ücretli ürün (loot kutusu vb.) yoktur; `ArePaidRandomItemsRestricted` için özellik eklenmedi. Böyle bir ürün eklenirse aynı kalıpla sunucuda denetlenmelidir.

## Güncel satış ve ekonomi sözleşmesi

- Altın tur içinde kazanılmaz (ada/çiftlik başına altın kaldırıldı). Tek ödül, bütün tur bitince (altı çiftlik tamam = rebirth hazır) rebirth işlemiyle atomik verilir: `Config.PROGRESSION.gold.rebirthBase` (750) + `rebirthPerLevel` (10) × o ana kadarki rebirth sayısı, tamamlama altını (`goldBonus`, R3/R10 +%10) çarpanıyla; R1 750, R4 858, R11 1020, R30 sonrası terminal 1260. Böylece bir rebirth ~bir kalıcı prim eşya (Elmas Çekiç 740) alır; hızlı yol Robux altın paketleridir. R30'da (başka sıfırlama yok) son tur tamamlanınca aynı ödül `progression.claims.terminal` ile bir kez verilir. Ortak saf yardımcı `Progression.rebirthGoldReward(save)`; eski `island:`/`farm:` hak anahtarları okunurken zararsızca atılır. Altın→nakit ve hızlı bitirme mantığı aynı; ilk rebirth'e kadar altın yoktur (yalnız Robux altını ya da R1 ödülünden sonra).
- Altın kalıcıdır. Nakit çevirme günlük UTC 200, tur başına 600 ile sınırlıdır; rebirth bugünkü kotayı yenilemez. Bir altın 30 saniyelik kalıcı referans gelir eder. Referans, sahip olunan çiftliklerin en yüksek nötr yetişkin potansiyelidir; geçici Return/tur 2x, görev kaybı ve hava dahil değildir. Önizleme değişirse işlem reddedilir.
- Yalnızca hayvan büyümesi ve eklenti bekleme süreleri altınla bitirilebilir; üretim partileri altın veya Robux ile bitirilemez. Sunucu güncel kalan süreyi, hayvan/iş kimliğini ve önizleme bedelini doğrular; eski işe ait istek yeni işi bitiremez.
- Kalıcı satış teklifleri 42 ekipman ve üç kolaylıktır (dört kanal ve altın formülü aşağıdaki "Ekipman satış kanalları" bölümündedir). Tek kaynak `Config/Progression.permanentOffers` tablosudur. Nakit edinim tur içidir, altın/Robux kalıcıdır. Dokuz rebirth ekipmanı ücretsiz kazanılır, satın alınamaz (R6, R9, R12, R15, R18, R21, R24, R27, R30). Her yuvada tek ekipman takılır; tüm avantajlar üst üste toplanmaz. Yeni mesh üretilmedi.
- Robux kataloğu: 50/100/500/1500/3000 altın, üç nakit paketi, tur 2x, kalıcı teklifler ve tek kullanımlık genç hayvanları büyüt. Nakit paketi kalıcı referans gelirle hesaplanır. Temel kimlikler Config/Shop, kalıcı ekipman kimlikleri Config/Progression.permanentOffers içindedir. Kimlik 0 satış kapalı demektir; kalıcı auto_collect ürünü aynı faydayı veren geçidi tekrar satmamak için kapalıdır (altın yolu açıktır). Robux fiyatı Roblox satın alma ekranından gelir; oyun kartları rakamı sabitlemez. Altın satın almak çevirme kotalarını artırmaz.
- Mevcut 2x geçidi ile tur 2x üst üste 4x olmaz. Takılı eşya × rebirth gelirinin sert tavanı 3'tür; tur/geçit 2x bunun dışındadır. UI gelir etkisinin tavan sonrası ek kazancını gösterir.
- Makbuz etkisi ve satın alma kimliği aynı kalıcı snapshot içindedir. Kayıt doğrulanmadan `PurchaseGranted` verilmez. Aynı makbuz tekrar ödül vermez. Ayrı ödeme nedeniyle ikinci kalıcı eşya teslimi altın eşdeğerini verir; cüzdan tavanında teslim ertelenir. R30 öncesi aktif 2x üzerine gelen 2x sonraki tur kredisidir; terminal krediler ve geç gelen ayrı 2x ödemeleri adet başına 200 altın olur. Hızlı büyütme tesliminde genç hayvan kalmamışsa 50 altın karşılık verilir. Dolu cüzdan hakları yok etmez.
- Rebirth, kalıcı asanın bugünkü kullanımını ve finansal günlükleri korur. Geçmiş kayıtlar opsiyonel alanların güvenli varsayılanıyla yüklenir; sürüm artırıp kullanıcı verisi silme uygulanmadı.
- Ek tılsım yuvası ve aura gibi gelecekteki fikirleri uygulanmış özellik sayma. Gezgin tüccar artık meydanda indirimli tur ekipmanları sunar; mevcut özelliklerin tek kaynağı Config ve ilgili servistir. Mevcut tüccar ve model sözleşmesi korunur. İlk sürüm mevcut ekipmana işlevsel kalıcı satın alma yolları verir.

## Ekipman satış kanalları

| Kanal | Koşul (referans nakit fiyat T) | Nasıl alınır |
|---|---|---|
| cash | T <= ~150k | yalnız tur içi nakit; teklif yok |
| cashGold | ~150k < T < 1,5M | tur içi nakit ya da kalıcı teklif (altın; Robux kimliği olanlar Robux) |
| goldRobux | T >= 1,5M veya yuvanın en iyisi, `noCash` | kalıcı teklif: altın ya da mevcut Robux ürünü |
| gold | `noCash`, Robux kimliği yok | yalnız altın |
| reward | `rewardOnly` | rebirth ilerlemesi; satılmaz |

Altın bedeli: `min(1500, yuvarla10(150 + 100 * sqrt(T / 100000)))`; T arttıkça düşmez, `tests/config.spec` formülü ve tek sıralamayı doğrular. Bir rebirth ~750-1040 altın verdiği için orta kademe bir kesir, en pahalı ekipmanlar yaklaşık bir rebirth (~900), Altın Taç tavan 1500. Yalnız-altın ekipmanlar: Ustabaşı Tokmağı, Servet Tılsımı, Tüccar Tacı, Kervan Çantası, Ebedi Çoban Asası, Altın Çekiç ve yeni altı ürün: Kristal Kanatlar (1,55M ref., 540 altın), Mühendis Anahtarı (2,7M, 670), Bilge Tılsımı (2,2M, 620), Kaptan Şapkası (2,4M, 640), Ulak Çantası (2,0M, 600), Tüccar Mührü (3,2M, 720). Yeni rebirth ödülleri (fiyat 1, satılmaz, kilometre taşı etkisi korunur): Şans Yoncası R9, Hasat Orağı R15, Zafer Çelengi R21, Anka Kanatları R27. Kanat merdiveni hız: Melek .06 < Kristal .09 < Altın .12 < Anka .15 (toplam hız tavanı %25). Robux ürün kimlikleri değişmedi ve yenisi eklenmedi; kimliği olmayan teklif Robux'ta kapalıdır (`id = 0`). Doğrudan `Items.price` sıralama/değer referansıdır, noCash eşyada satış fiyatı değildir.

## Creator Hub açılış adımları

4 Ekim 2026 ek içerik: Kalıcı Rüzgar Muskası (`permanent_wind_charm`) 450 altın; Robux kimliği 3716422184 ile bağlı, Creator Hub fiyatı 149 Robux. Tur içi eşya 550.000 nakit. Takılıyken +%15 yürüyüş/koşu ve +3 puan çevrimdışı gelir sağlar, ürün verimi %3 azalır. Aynı muska yuvasındaki diğer ekonomik eşyanın yerini alır; toplam ekipman hız bonusu %25'i aşmaz. Yeni mesh kullanılmadı; Roblox metadata adı/fiyatı ve satış durumu doğrulandı. Üç geçit ve önceki 33 bağlı ürünün kimlikleri korundu; bu ürünle 34 bağlı Developer Product vardır.

Ürünleri oluştur, kimlikleri doğru teklif anahtarlarına bağla, Robux fiyatlarını platformda belirle; ardından özel test ortamında gerçek makbuz/reconnect ve aynı ürün tekrar teslimini doğrula. Kimlik 0 olan ürün satışa sunulmaz. Canlı yayın ve yönetici sıfırlaması bu geliştirme sırasında yapılmaz.
