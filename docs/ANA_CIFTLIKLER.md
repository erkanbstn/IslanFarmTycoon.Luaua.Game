# Birden fazla ana çiftlik

Bir **ana çiftlik**, büyük ana ada ve ona bağlı üç küçük uzman adanın tamamıdır. Çiftlik numarası
aynı zamanda **temadır** (Çiftlik 1 = Papatya ... Çiftlik 6; ana ada düzeni, küçük adalar, hayvan).
Ada Yönetimi'nin üst bölümü ana çiftlikleri satın alma/etkinleştirme içindir; alt bölümü etkin
çiftliğin küçük adalarını açar. Bu iki ilerleme seviyesi ayrıdır.

## Çok oyunculu model (6 oyunculu sunucu)

- Haritada 6 **fiziksel ada** vardır ve hepsi aynı (1. tema) kurulur: aynı Terrain, aynı ana bölgeler,
  ahır, doğma noktası, toplama platformu. Her oyuncu girince bir fiziksel ada alır ve **Çiftlik 1** ile başlar.
- Oyuncunun etkin çiftliği yalnızca kendi fiziksel adasında çizilir. Başka bir çiftliği satın alıp/seçince
  ada, o çiftliğin temasıyla **çalışma anında yeniden giydirilir** (`MapBuilder.applyTheme`: yapı yerleri,
  ana ada süsleri/yerleşimi, küçük adalar ve bölgeleri; Terrain'e dokunulmaz). Diğer 5 oyuncu değişimi canlı görür.
- Önceki çiftlik **park edilir**: çizilmez ama kayıtta durur ve çalışmayı sürdürür (gelir, üretim, yardımcılar).
- Oyuncular birbirinin adasına yürüyebilir (Ziyaret) ama müdahale edemez.
- Fiziksel ada rezervasyonu yoktur; satın alma yalnızca temaya (çiftlik numarasına) bakar.

## Ortak ve ayrı olanlar

İlk çiftlik mevcut kayıttır. Sonraki beş çiftliğin fiyatları sırasıyla yaklaşık 590 bin, 2,5 milyon, 9,5 milyon,
37 milyon ve 100 milyondur (`Config.MAIN_FARM_PRICES` taban değerleri 12.000 ... 167.000, yükseltme eğrisinden geçer);
ikinci çiftlik ilk çiftlik bitmeye yakınken (yaklaşık 3. saat) bir "yeni bölüm" olacak şekilde ayarlıdır.

Para, envanter ve ahır deposundaki ürünler oyuncuya aittir ve **tüm çiftliklerde ortaktır**
(tür başına depo sınırı = sahip olunan bütün ahırların toplamı). Her çiftliğin hayvanları, küçük ada kilitleri,
yükseltmeleri, ahır seviyesi, üretim partileri ve otomatik tekrar seçimi ayrıdır.
Yeni çiftlik başlangıç durumuyla açılır; mevcut çiftlikteki geliştirmeler kopyalanmaz.

Kayıt şeması 4'tür. Kayıt tek oturum kilidiyle, ortak cüzdan ve bütün çiftlikler birlikte yazılarak
saklanır. Gecikmiş satın alma/üretim istekleri başka çiftliğe uygulanmaması için hedef çiftlik
kimliğiyle doğrulanır.

Studio kontrolü: Haritayı Kur → Doğrula → Ctrl+S (MAP_VERSION değişti). İkinci çiftliği satın al; adanın
yeni temayla yeniden kurulduğunu, ilkine dönünce eskisinin geri geldiğini ve iki ilerlemenin ayrı
kaldığını kontrol et. İki oyuncuyla (Test → Clients) birinin tema değişimini diğerinin ekranında izle.
