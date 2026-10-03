# 30 rebirth geliştirmesi

4 Ekim 2026 · `codex/market-cesitlendirme`. Mevcut kullanıcı/market çalışmaları korunmuştur; bu aşamada commit, push, yayın veya veri sıfırlama yapılmadı.

Uygulama tamamlandı: 30 otomatik ödül, beş yalnız ilerlemeyle kazanılan kalıcı ekipman, 30 seçim puanı, kademeli ücretsiz yapı/soy hedefleri; üç gerçek dezavantajlı uzman eşya; genişleyen tek Market ve meydan dükkânı. Denge verileri `src/shared/Config/Progression.luau`, `Items.luau`, `Shop.luau` içindedir. Kaynakta belirtilen her seviye oyundaki “30 Rebirth Yolculuğu” sekmesinde incelenebilir.

## Ölçüm

`python scripts/simulate-rebirth-campaign.py` gerçek Config, FarmMath ve Rebirth.apply kullanır; altın, kalıcı sahiplik, ekipman, perkler, günlük kota ve zaman turdan tura taşınır. UTC oturum fazı korunur. Ücretsiz koşu kazandığı altını kalıcı ekipmana yatırır; boş yuvadaki kazanılmış ekipmanı takar. Hızlandırılmış koşu en baştan dört kalıcı ekipman, üç yardımcı ve her tur 2x hakkına sahiptir; satın alma/edinme süresi hariçtir. İki senaryo aynı karar ve perk seçim politikasını kullanır.

| Senaryo | 30 turun takvim süresi | Aktif oyun | Son tur aktif |
|---|---:|---:|---:|
| Gündelik, ücretsiz (3 × 20 dk/gün) | 189,67 gün | 189,67 saat | 4,67 saat |
| Gündelik, hızlandırılmış | 89,67 gün | 89,67 saat | 2,33 saat |
| Seyrek, ücretsiz (2 × 10 dk/gün) | 448 gün | 149,45 saat | 4,17 saat |
| Seyrek, hızlandırılmış | 184 gün | 61,35 saat | 1,83 saat |

120 tam tur tamamlandı; hiçbir ücretsiz koşuda ücretli şart veya ilerleme kilidi oluşmadı. Bu, canlı oyuncu tutundurma ölçümü değildir: yürüyüş, yanlış yatırımlar, terk etme ve karar kalitesi modellenmez. Özellikle seyrek oyuncunun takvim süresi uzundur; açılış sonrası telemetriyle ayrıca değerlendirilmelidir. Başlangıç seviyesine ait önceki ücretsiz/altın biriktirme ölçümü 19 gündür; aynı politika korunurken ilk tur ölçüsü değiştirilmemiştir. 30 tur ölçüsü önceki tek-tur ölçüsüyle doğrudan hızlanma yüzdesi olarak karşılaştırılmaz.

## Doğrulama durumu

- Gerçek sıfırlama + codec yeniden yükleme ile 30 tur; eski R40 hakları ve R30 sınırı.
- 30 oyunculu eşzamanlı ilerleme işçileri, 30 makbuz tekrarı, belirsiz kayıt ve cüzdan tavanı durumları.
- Üç eşyanın gerçek büyüme, çevrimdışı kazanç, tesis süresi ve ürün miktarı dezavantajları.
- Gerçek kaynak UI testleri: 30 ödül, mevcut/sonraki kazanım, hazır olmayan oyuncu ve terminal durum; eşya yuvası ve ücretli/ücretsiz yollar.
- 761 model; 1459 çeviri anahtarı ve beş dilde 702 Config metni. Yeni mesh yok.

Toplu doğrulama `scripts/verify.ps1 -RequireTypes` **geçti**: biçim/lint, derleme, Luau regresyonları, ekonomi denetimi, üç persona için artan çiftlik süreleri, çeviri/model/mimari kontrolleri, sıfır tip bulgusu ve üç Rojo derlemesi. Son UI metin güncellemesinden sonra regresyonlar ve tip/çeviri kontrolleri tekrar geçti. Yerel log `.test-build/rebirth30-verify.log`; Selene API dump indirmesi yerine mevcut önbelleği kullandı, lint sonucu 0 hata/uyarıdır.

Studio kayıtsız Play'de WorldReady ve DataStatus Active; ilk hayvanın gerçek sunucu satın alımından sonra Rebirth menüsü açıldı. R0/30, sonraki ödül, 30 satır ve hazır olmayan oyuncunun kapalı sıfırlama düğmesi kontrol edildi; konsolda çalışma hatası görülmedi. Dünya atmosferi/FPS ve gerçek mobil cihaz bu arayüz kontrolünün kapsamı değildir.

Rebirth penceresi geçici 370 × 550 boyutta da kontrol edildi (ölçek sonrası 296 × 440): görünen metinlerde TextFits hatası yoktu. Boyut geri alındı ve Play durduruldu; bu dar pencere kontrolü gerçek telefon emülasyonu sayılmaz.

## Yayın öncesi kalanlar

Creator Hub ürün kimlikleri ve gerçek Robux fiyatları henüz yok; kimliği 0 olan ürünler sergilenir fakat alınamaz. Gerçek ödeme/reconnect testi, iki oyunculu Studio testi, gerçek telefon/gamepad, MicroProfiler ve uzun canlı oturum testleri otomatik paketin yerine geçmez. Canlı publish ve yönetici veri sıfırlaması geliştiriciye aittir.
