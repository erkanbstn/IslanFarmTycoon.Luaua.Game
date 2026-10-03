# Üretim, sipariş ve gezgin tüccar çalışması

## Durum — 4 Ekim 2026

Önceki UI çalışması `f90b3ec` ile main'e birleştirildi ve uzak depoya gönderildi.
Bu çalışma `codex/uretim-tuccar-dengesi` dalında doğrulandı. 4 Ekim'de kullanıcı main'e birleştirme ve uzak depoya gönderme onayı verdi. Canlı yayın veya kayıt sıfırlaması yapılmadı.

## Giderilen sorunlar

- Erken oyunda pahalı tek ürün siparişi gelir tavanını aşabiliyordu. İki yetişkin inekli ölçümde brüt ödül 7.455 nakit / 31,06 dakika gelirden 1.262 / 5,26 dakikaya indi. Miktar küçültmek yetmediğinde ödeme de sınırlandırılıyor.
- Az ürün çeşidiyle yüksek karma sipariş primi alınabiliyordu. Kademe artık gerçekten istenebilen çeşitliliğe göre seçiliyor.
- Her üretilebilir ürünün ilk pano slotlarında tek ürün siparişi var. Yetişkin hayvan gerekiyor; üretimde meşgul olması ürünü geçici olarak panodan silmiyor. Aynı pencerenin teslim edilmiş slotu yeni ürün açılınca tekrar ödül vermiyor; yeni hak sonraki 420 saniyelik pencerede gelir.
- Açılış veya gelir değişince aynı anahtarlı teklif farklı ürün tüketebiliyordu. Teklif anahtarı artık ürün/miktar/ödül parmak izi içeriyor; eski kayıtların teslim hakları korunuyor.
- Otomatik tekrar talebi aşan stok üretiyordu. Ürün yardımcısı, bekleyen siparişler + iki parti yedek hedefi ve kapasite sınırına göre bekler. Ayar açık kalır; satış/teslim/tüketim sonrası yeniden başlar. Elle üretim korunur. Tampon, sipariş hesabı yaptığı için otomatik başlatma kontrolünde küçük ek hesap maliyeti getirir.
- Geçersiz ürün takası kısmi stok düşüremiyor; işlem bütünüyle reddediliyor.
- Altınla üretim bitirme stok fazlasını hızlandırıyor ve üretimin bekleme maliyetini atlıyordu. Üretimde kapalı; hayvan büyümesi ve eklenti görevi bitirme korunuyor. Eski istemci isteği altın düşürmeden reddedilir. Kimliği henüz tanımlanmamış Robux üretim bitirme ürünü de katalog ve sunucu etkilerinden kaldırıldı; makbuz güvenliği testleri hızlı büyütme ürünüyle korunuyor.
- Gezgin tüccar artık meydanda mevcut `Vendor_store` modeliyle görünür. Kişisel ziyaret düzeni korunur; üç tur eşyası %30 indirimli seçki olarak sunulur, ziyaret başına tek alım vardır. Hayvan satışı kaldırıldı. Bildirim kataloğu açabilir; alım için sunucu meydandaki tüccara yakınlığı, ziyaret/pencereyi, teklif fiyatını ve sahipliği doğrular.
- Studio, tüccar yerleşiminde ek bir hata ortaya çıkardı: özyinelemeli `Hub` araması bazen yel değirmeninin aynı adlı parçasını buluyordu. Yerleşim doğrudan `Workspace.World.Hub` yoluna bağlandı.
- Yönetici büyütme/doldurma/tamamlama işlemleri eski geliri önce hesaplar. Envanter temizliği genç hayvanların büyüme ilerlemesini korur. Tamamlama soy seviyelerini de kapsar. Uygun hayvan yokken altın hayvan çağırma başarı bildirmez. Sunucu hatası anında eşleşen sonuç döndürür; isteği otomatik tekrar uygulamaz.

## Ölçümler ve sınırlar

Önceki kaynaklar `f90b3ec` arşivinden ayrı dizinde çalıştırıldı; sonuçlar `.test-build` altında geçici kanıttır.

- Aynı 40 sipariş penceresi ve tam gelişmiş altı çiftlik: talep 7,35–9,53 → 6,65–8,72 birim/pencere; teorik üretim/talep oranı 2,59–5,71 → 2,63–6,43. Son ayarda talep artmadı: garantili tek ürün slotları karma sipariş miktarını azaltıyor. Ham üretim hızı hâlâ talebi aşabilir; yığılmayı çözen temel değişiklik stok tamponunun otomatik fazlayı durdurmasıdır. Önceki 6 adet denemesi, seyrek oyuncuda ikinci çiftliği ilkinden kısa tamamlatıyordu; test gevşetilmeden üst miktar tabanı 4 olarak ayarlandı. Genel zorluk katsayıları değiştirilmedi.
- Dört saat otomatik tekrar: tek merkez stok 50/96'da durdu. Tüm stok satıldıktan sonraki kontrol üretimi yeniden başlattı.
- 30 ürün merkezi için mevcut hızlı satış hâlâ net kârlı. Ürün nominal değerleri ve hızlı satış oranı (%6) değiştirilmedi.
- Aynı altı saatlik hardcore simülasyon (`--persona hardcore --session 0 --hours 6 --farm 1`): her iki koşuda üç çiftlik; süt ortalama stok doluluğu %32,50 → %27,21, balık %41,17 → %34,29. Siparişte tüketilen ürünler arttı; toplam sipariş kazancı 44,16M → 50,45M. Bu bir oyuncu davranışı ölçümü değil, deterministik aktif simülasyondur; üretim yardımcısı tamponunun ayrı testi yukarıdadır.
- Ödül sınırı etkin çiftliğin anlık gelirine değil, en yüksek referans gelir/nötr yetişkin potansiyeline bağlıdır. Meşgul hayvanlar veya yeni çiftliğe geçiş nedeniyle anlık gelir üzerinden oran daha yüksek görünebilir. Aktif gelir ve tavan referansı ayrı değerlendirilmelidir.
- Altı saatlik son koşuda 515 teslimin her biri referans sınırına karşı doğrulandı: en yüksek ödül 5,03 dakika referans gelir (sınır 6). Aynı ödül, etkin çiftliğin anlık geliriyle 9,28 dakikaya çıkabiliyor; bu iki ölçü birbirinin yerine kullanılmaz.
- Tüccar satın alımları ekonomi simülasyonunda modellenmez; ayrı gerçek servis testleri fiyat/yakınlık/tekrar alım kontrolünü sınar.
- Performans: toplu doğrulama bittikten sonra aynı Python/Luau ve altı saatlik CLI ile sıralı önce/sonra/önce/sonra ölçüldü. Önce 2,896/2,878 saniye (ortalama 2,887), sonra 3,830/3,686 saniye (ortalama 3,758); +0,871 saniye / +%30,2. Bu bütün simülasyon süresidir; yeni sürüm 476 yerine 515 teslim ve 3.010 yerine 3.065 eylem yaptığı için ek hesap maliyetini tek başına ayırmaz. Oyuncu cihazı veya canlı sunucu profili yapılmadı. Üretim tamponu ve teklif doğrulaması ek hesap getirir; canlı yük profili bir sonraki doğrulama adımıdır.
- Doğrulama aracı gereksiz olarak çiftlikler bittikten sonra 150/365 günlük ufkun kalanını simüle ediyordu. Normal süreli simülasyon korunarak, yalnız tamamlama kontrolü için `--stop-after-farms` eklendi. Aracın doğrulamasında tüm altı tamamlanma zamanı ve bitişe kadarki kilometre taşları durmasız koşuyla birebir eşleşti; gereksiz kalan süre çalıştırılmadı. Üç yeni araç regresyon testi tamamlama eşitliğini, eksik çiftliklerde durmamayı ve varsayılan altı saatlik ufkun korunmasını sınar.

## Doğrulama ve kalan işler

- Üretim, sipariş, stok, tüccar, yönetici ve altın bitirme senaryolarını kapsayan toplu Luau testleri geçti.
- Beş dilde 1.555 anahtar ve 700 Config metni doğrulandı.
- Studio uçtan uca: kayıtsız test profili (`DataPersistent=false`) üzerinde gerçek yönetici isteğiyle tüccar çağırma, üç teklifin görünmesi, uzak alımda ret/bakiye korunması, 8,54 stud yakın alımda 10.000 → 7.000 fiyat/aynı tutarda tahsilat/eşya ve kuşanma, ikinci alımın reddi doğrulandı. Yetişkinsiz profilde altın hayvan çağırma doğru şekilde reddedildi. Yeni konsol hatası yok; oturum durdurulup Edit moduna dönüldü. Canlı DataStore'a yazılmadı.
- Son kaynaklarla `powershell -ExecutionPolicy Bypass -File scripts/verify.ps1 -RequireTypes` geçti: format, lint, Luau derleme/regresyon, üç simülasyon durma testi, ekonomi ve rebirth smoke, ekonomi denetimi, ideal/casual/idle altı çiftlikte kesin artan tamamlama süreleri, çeviri/AI rehber/mimari/model kontrolleri, sıfır tip bulgusu ve üç Rojo derlemesi. Log: `.test-build/production-release-verify.log`.
- İlk uzun koşu eski araçtaki gereksiz ufuk çalışmasını düzeltmek için durduruldu. Sonraki koşu yeni NPC modülünün mimari belgede eksik olması ve idle ikinci çiftlik süresinin ilkinden kısa çıkması nedeniyle başarısız oldu. Belge ve miktar ayarı düzeltildi; beklentiler gevşetilmeden son toplu kontrol geçti.
- Çok oyunculu Studio oturumu, gerçek mobil cihaz, canlı sunucu yük profili ve canlı DataStore arıza deneyi bu çalışmada yapılmadı. Seyrek oyuncuda ilk iki çiftlik yaklaşık üç gün sürüyor; kesin artış olsa da aradaki fark yaklaşık sekiz dakika. Oyuncunun hissedeceği zorluk farkı için canlı oturum verisi gerekir.
- Yayın öncesi gerçek oyuncularla uzun oturum ölçümü: depo doluluğu, sipariş teslim oranı, üretimin beklemede geçirdiği süre ve çiftlik açma süreleri izlenmeli. Mevcut ölçümler canlı kullanıcı telemetrisi yerine geçmez.
- Main birleştirmesi kullanıcı tarafından onaylandı; son toplu doğrulama başarılı. Canlı veri sıfırlama ve yayın kullanıcı tarafından yapılacak.
