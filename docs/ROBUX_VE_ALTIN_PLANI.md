# Altın, Robux marketi ve rebirth seviyeleri planı

Durum: **altın, kalıcı sahiplik ve ürün ödülleri uygulandı**; Creator Hub kimlikleri/fiyatları olmadığı için Robux satışları kapalıdır. Güncel teslim: [DEVIR_DURUMU.md](DEVIR_DURUMU.md), 4 Ekim 2026.


## Güncel satış ve ekonomi sözleşmesi

- Her turun ana ada dahil 24 adası ve altı çiftliği için başlangıç altını 780'dir. Tamamlanma ödülü bir kere verilir; son ödüller rebirth sıfırlamasından önce tahsil edilir. R3/R10 bonuslarıyla 858/936 olabilir.
- Altın kalıcıdır. Nakit çevirme günlük UTC 200, tur başına 600 ile sınırlıdır; rebirth bugünkü kotayı yenilemez. Bir altın 30 saniyelik kalıcı referans gelir eder. Referans, sahip olunan çiftliklerin en yüksek nötr yetişkin potansiyelidir; geçici Return/tur 2x, görev kaybı ve hava dahil değildir. Önizleme değişirse işlem reddedilir.
- Yalnızca hayvan büyümesi ve eklenti bekleme süreleri altınla bitirilebilir; üretim partileri altın veya Robux ile bitirilemez. Sunucu güncel kalan süreyi, hayvan/iş kimliğini ve önizleme bedelini doğrular; eski işe ait istek yeni işi bitiremez.
- Kalıcı satış teklifleri 21 ekipman ve üç kolaylıktır. Tek kaynak `Config/Progression.permanentOffers` tablosudur. Nakit edinim tur içidir, altın/Robux kalıcıdır. Beş rebirth ekipmanı ücretsiz kazanılır, satın alınamaz. Her yuvada tek ekipman takılır; tüm avantajlar üst üste toplanmaz. Yeni mesh üretilmedi.
- Robux kataloğu: 50/100/500/1500/3000 altın, üç nakit paketi, tur 2x, kalıcı teklifler ve tek kullanımlık genç hayvanları büyüt. Nakit paketi kalıcı referans gelirle hesaplanır. Kimlikler 0 olduğundan satış kapalıdır; platform fiyatı uydurulmaz. Altın satın almak çevirme kotalarını artırmaz.
- Mevcut 2x geçidi ile tur 2x üst üste 4x olmaz. Takılı eşya × rebirth gelirinin sert tavanı 3'tür; tur/geçit 2x bunun dışındadır. UI gelir etkisinin tavan sonrası ek kazancını gösterir.
- Makbuz etkisi ve satın alma kimliği aynı kalıcı snapshot içindedir. Kayıt doğrulanmadan `PurchaseGranted` verilmez. Aynı makbuz tekrar ödül vermez. Ayrı ödeme nedeniyle ikinci kalıcı eşya teslimi altın eşdeğerini verir; cüzdan tavanında teslim ertelenir. R30 öncesi aktif 2x üzerine gelen 2x sonraki tur kredisidir; terminal krediler ve geç gelen ayrı 2x ödemeleri adet başına 200 altın olur. Hızlı büyütme tesliminde genç hayvan kalmamışsa 50 altın karşılık verilir. Dolu cüzdan hakları yok etmez.
- Rebirth, kalıcı asanın bugünkü kullanımını ve finansal günlükleri korur. Geçmiş kayıtlar opsiyonel alanların güvenli varsayılanıyla yüklenir; sürüm artırıp kullanıcı verisi silme uygulanmadı.
- Ek tılsım yuvası ve aura gibi gelecekteki fikirleri uygulanmış özellik sayma. Gezgin tüccar artık meydanda indirimli tur ekipmanları sunar; mevcut özelliklerin tek kaynağı Config ve ilgili servistir. Mevcut tüccar ve model sözleşmesi korunur. İlk sürüm mevcut ekipmana işlevsel kalıcı satın alma yolları verir.

## Creator Hub açılış adımları

Ürünleri oluştur, kimlikleri doğru teklif anahtarlarına bağla, Robux fiyatlarını platformda belirle; ardından özel test ortamında gerçek makbuz/reconnect ve aynı ürün tekrar teslimini doğrula. Kimlik 0 olan ürün satışa sunulmaz. Canlı yayın ve yönetici sıfırlaması bu geliştirme sırasında yapılmaz.
