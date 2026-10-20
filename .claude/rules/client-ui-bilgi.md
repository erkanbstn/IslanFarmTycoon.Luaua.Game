---
description: Bilgiyi gerektiğinde göster: ayrıntı aç/kapa, kart düzeni, sekme ve işlem rozetleri
paths:
  - "src/client/Ui/**/*.luau"
---

# Arayüz standardı: Bilgi

Giriş dosyası: `.claude/rules/client-ui.md` (konu haritası).

## Bilgiyi gerektiğinde göster

- İlk görünümde başlık, kısa sonuç, fiyat ve ana aksiyon kalır. Açıklama, ayrıntılı formül ve ikincil işlemler `UiKit.disclosure(parent, order, title)` içinde varsayılan kapalıdır; mevcut kart açıklaması için `UiKit.cardDetails` kullanılabilir.
- Detay düğmesi dokunma/gamepad hedefini korur. İncelenen çiftlik, tur veya ürün değişince eski inceleme kapatılır. Para/ürün gereksinimi, gerçek eşya eksileri ve geri alınamaz işlem uyarıları ilgili işlemden önce gösterilir.
- Ayrıntı gövdesi ortak `DisclosureBody` stilini kullanır: mint yüzey, ince kenar, iç boşluk ve rahat satır aralığı. `UiKit.text(details.body, ..., "Caption")` içeride Body boyutuna ve ana metin rengine yükselir; özel uyarı/fiyat renkleri korunur. `cardDetails` taşınan kart açıklamasını aynı okunabilir stile getirir. Ayrıntıya elle küçük yazı boyutu verme.
- Aktif etkiler ve 30 seviye kazanımları aynı **İlerleme** penceresinin Etkiler/Rebirth sekmelerindedir. Sahip olunan fakat takılı olmayan ekipman aktif bonus diye sunulmaz. Ayrıntılı kaynak hesapları yalnız ilgili bölüm açılınca yapılır.
- Yeni oyuncunun görev şeridi ile sol hedef kartında aynı talimatı iki kez gösterme; görev şeridi açıkken sol hedef kartı gizlenir.
- Kart ayrıntısı tüm kart genişliğine yayılır. Esnek ızgaralarda satır hizalaması `ItemLineAlignment.Stretch` kullanır; kaydırmalı otomatik içerik yüksekliğini sıkıştıran `VerticalFlex.Fill` kullanılmaz. Eşitlik için boş düğme veya sabit büyük yükseklik ekleme.
- Aynı karttaki alternatif/ikincil işlemler `UiKit.actionRow` + `actionButton` kullanır: genişliğe göre 2/4 sütun, dar kartta 1 sütun; gizli düğme yer ayırmaz, son eksik satır kalan alanı paylaşır. Metin küçültülmez, doğal yükseklik ve TouchTarget korunur. Ana satın alma/teslim ve geri alınamaz onay tek satır genişliğinde kalabilir. `ProductionContext` dünya üzerinden açılan üretimde aynı ada + aynı bina veya ortak hayvan grubunun ilgili tariflerini gösterir; kilit/tema/ücret sunucu ve mevcut görünüm kurallarından gelir.
- Bir ürünün karttaki ana faydasını ayrıntıda tekrar etme. Alternatif ödeme ayrıntıda gösterilebilir; ana fiyat ve inceleme/satın alma niyeti ilk bakışta anlaşılır kalır.

- Sekme seçimi seçili sekmede tekrar çalışmaz. Ayrıntı aç/kapa yalnız ilgili kartı günceller; gizli sayfanın teklif/ayrıntı hesabını yapma. Pencere açılışında yalnız o pencereyi tazele; çoklu açık katalogları yeniden çizme.
- İşlem rozetleri menüden ilgili sekmeye kadar aynı anlamı taşır: `Hud/ActionBadges` üretimde hazır parti, yükseltmelerde karşılanabilen yatırım, ödüllerde alınabilir ödül sayar. Ada sayaçları `IslandTabs.setBadges`, kategori sayaçları `UiKit.tabs` üçüncü dönüşüyle güncellenir; sıfır gizlenir, bakmak sayacı tüketmez. Ödüllerde mevsim hedefi Günlük sekmesine aittir; Başarımlar sayısına eklenmez. Envanterde dolu ürün türleri Ahır Deposu sekmesinde gösterilir. Sayı için başlık metnini değiştirip çeviriyi bozma; inline rozet metne alan ayırır.
	Rozet tüm girişlerde sağ üst köşededir; merkezdeki sekme metninin üzerine yerleştirme. Eşya kartlarında Config.ITEMS.level katalog kademesi gösterilir; kategori içinde seviye, fiyat ve kimlik sırası kullanılır. Katalog seviyesi oyuncu seviyesi veya satın alma kilidi değildir; farklı fayda ve eksiler kartta korunur. ITEM_ORDER sunucunun tüccar seçim sözleşmesi için değiştirilmez.
