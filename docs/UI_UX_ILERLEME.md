# İlerleme ekranı ve arayüz sadeleştirmesi

Önceki 30 rebirth ve market çalışması `8ba58be` ile main'e birleştirildi ve uzak depoya gönderildi. Bu aşama `codex/ui-ux-ilerleme` dalındadır; ekonomi, kayıt şeması ve ürün kimlikleri değiştirilmedi.

## Tamamlananlar

- İlerleme penceresinde Etkiler ve Rebirth sekmeleri. Etkiler gerçek FarmMath hesaplarını kullanır; takılı olmayan eşya aktif güç sayılmaz. Gelir kaynakları çıkarıldığında oluşan farklar yalnız ayrıntı açıkken hesaplanır ve birbirine eklenmediği belirtilir.
- Rebirth yolculuğunda 30 seviyenin kazanımları, alınmış/sıradaki/kilitli durumu ve son seviyedeki terminal durum.
- Pazar, market, eşya dükkânı, envanter, yükseltmeler, yol haritası, üretim, siparişler, ödüller, ayarlar, adalar ve yönetici ekranlarında isteğe bağlı ayrıntılar. Ana eylem, fiyat, gerekli kaynaklar ve geri alınamayan işlem uyarıları korunur.
- İnceleme gerektiren eşya düğmeleri önce “İncele · fiyat”, inceleme açıkken “Satın al · fiyat” gösterir. İlk tıklama ödeme göndermez; olumsuz etkiler satın alma öncesinde görünür.
- Ortak UiKit disclosure bileşeni; bağlam/pencere değişiminde eski ayrıntıların sıfırlanması. Beş dilde çeviri güncellendi.

## Doğrulama

- Gerçek modüllerle regresyon: gelir sınırı, birlikte 2x hakları, Dönüş bitişi, salt okunur etki karşılaştırması, tembel ayrıntı hesapları, ödeme öncesi inceleme ve yönetici sıfırlama onayı.
- Ortak ayrıntı bileşeni 300 aç/kapat döngüsünde yeni UI nesnesi üretmez; bu kontrol kare hızı ölçümü değildir.
- Studio kayıtsız Play: ilk hayvan alımı, İlerleme açılışı, etki ayrıntısı, Rebirth sekmesi ve yolculuğu, yönetici görünümü. İlerleme penceresi 296×440 gerçek piksel alanına daraltıldığında görünür metinlerde TextFits hatası yoktu; gerçek telefon emülasyonu değildir.
- `verify.ps1 -RequireTypes` tamamlandı: tüm otomatik kontroller geçti; yeni veya bilinen tip bulgusu yok. Beş dilde 1522 anahtar doğrulandı; oyun, eklenti ve test place'i Rojo ile derlendi. Selene API verisini indiremediği için mevcut önbelleği kullandı ve 0 hata/uyarı verdi.
- Toplu kontrol çıktısı: `.test-build/ui-ux-verify.log` (yerel, Git'e eklenmez). Studio oturumu sonunda Edit moduna döndürüldü.
- Studio incelemesinden sonra marketin üstündeki ürün kimlikleriyle ilgili genel paragraf kaldırıldı; bu son metin temizliğinin ardından regresyon testleri yeniden geçti ve oyun Rojo derlemesi yenilendi.

## Yayın öncesi kalanlar

- Gerçek telefon ve gamepad ile gezinme, kaydırma ve ödeme ekranlarının kullanılabilirlik kontrolü.
- Creator Hub ürün/geçit kimliklerini tanımlama ve gerçek makbuz akışını test ortamında doğrulama. Kimliği olmayan Robux ürünleri satışa açılmaz.
- Canlı yayın ve yönetici veri sıfırlaması yapılmadı. Bu işlemler geliştiricinin son yayın adımıdır.

## İkinci görsel düzenleme aşaması

Kullanıcının dört ekran görüntüsü üzerinden genel menü taraması yapıldı. İlk aşamadaki değişiklikler korunarak aynı dalda devam edildi.

- Saf beyaz yüzeyler mint/turkuaz tonlarına taşındı; lavanta ve gökyüzü önizlemeleri canlılaştırıldı. Kart, panel ve giriş kenarlıkları görünür hale getirildi. Dünyadaki koyu tabela renkleri korundu.
- Altın için platform emojisine bağlı olmayan, UiKit içinde çizilen yuvarlak madeni para simgesi kullanıldı; geniş önizlemede de dairesel kalır. Sol cüzdan simge, miktar ve rebirth seviyesini tek tam genişlikli düğmede gösterir; market başlığı da aynı simgeyi kullanır.
- Sıradaki ada ayrıntıları tüm kart genişliğine yayıldı. Ahır, mevsim/hava, başlık ve düğmeler uzun metinle doğal büyür; grafik seçenekleri dar ekran için iki sütuna alındı. Üretim alanında çakışan sıralar ve düşük düğme yükseklikleri düzeltildi.
- Izgara kartları aynı satırın yüksekliğine uzar; modelsiz katalog ikonları da model önizlemesiyle aynı yüksekliktedir. Altın alternatifi olan ürünlerde dışarıda tek ana satın alma düğmesi, ayrıntıda Robux alternatifi vardır; yapay boş düğme eklenmedi.
- “Kalıcı geçit” kaldırıldı: kartta doğrudan ürün faydası, ayrıntıda ek etkiler/eksiler ve sonraki turlarda korunma bilgisi vardır. Aynı ana fayda iki kez gösterilmez.

### İkinci aşama kanıtları

- Gerçek kaynak testleri: altın simgesi/cüzdan değerleri, tam genişlikli ada ayrıntısı, doğal kart büyümesi, yuvarlak coin önizlemesi, dışarıda tek ana ödeme aksiyonu, ayrıntıdaki alternatif ödeme ve yinelenmeyen ürün faydaları.
- Studio ölçümü: ayrıntı açıkken aynı satırdaki iki kalıcı ürün kartı 214/214 piksel yüksekliğindeydi. 296×440 piksele daraltılan markette Türkçe ve Almanca görünür metinlerin TextFits kontrolünde taşma yoktu. Bu kontroller gerçek telefon veya tüm dil/durum kombinasyonlarının doğrulaması değildir.
- Tema RGB değerlerinden hesaplanan kontrast oranları: ana metin/yüzey 10,05; ikincil metin/yükseltilmiş yüzey 5,28; açık metin/turuncu düğme 4,77; açık metin/turkuaz düğme 4,99. Bunlar düz renk karşılaştırmasıdır; görüntüdeki tüm ton geçişleri için ölçüm değildir. Ayarlar ekranının görünür metinlerinde Studio TextFits kontrolü temizdi.
- [Roblox düzen sözleşmesi](https://create.roblox.com/docs/reference/engine/classes/UIListLayout) doğrultusunda satır hizalaması `ItemLineAlignment.Stretch` kullanır. Studio'da `VerticalFlex.Fill` uzun kaydırmalı içerikleri sıkıştırdığı için uygulanmadı; regresyon testi bu seçeneği engeller.
- Güncel toplu çıktı `.test-build/ui-polish-verify.log`: `verify.ps1 -RequireTypes` tüm otomatik kontrolleri geçti. Erken kontrol yeni testlerin dört eksik assert mesajını yakaladı; mesajlar düzeltildi ve temiz son koşu tamamlandı. Yeni/bilinen tip bulgusu 0; Selene hata/uyarı 0; beş dilde 1529 anahtar doğrulandı; üç Rojo derlemesi başarılı.
