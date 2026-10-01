# Birden fazla ana çiftlik

Bir **ana çiftlik**, büyük ana ada ve ona bağlı üç küçük uzman adanın tamamıdır. Çiftlik numarası
aynı zamanda **temadır** (Çiftlik 1 = Papatya ... Çiftlik 6; ana ada düzeni, küçük adalar, hayvan).
Adalar menüsünün (I) üst bölümü ana çiftlikleri satın alma/etkinleştirme içindir; alt bölümü etkin
çiftliğin küçük adalarını açar. Bu iki ilerleme seviyesi ayrıdır.

## Çok oyunculu model (6 oyunculu sunucu)

- Haritada `Config.MAP_PLOT_COUNT` kadar (şu an altı; sunucu Max Players ile eşit) **fiziksel ada** vardır ve hepsi aynı (1. tema) kurulur: aynı Terrain, aynı ana bölgeler,
  ahır, doğma noktası, toplama platformu. Her oyuncu girince bir fiziksel ada alır ve **Çiftlik 1** ile başlar.
- Oyuncunun etkin çiftliği yalnızca kendi fiziksel adasında çizilir. Başka bir çiftliği satın alıp/seçince
  ada, o çiftliğin temasıyla **çalışma anında yeniden giydirilir** (`MapBuilder.applyTheme`: yapı yerleri,
  ana ada süsleri/yerleşimi, küçük adalar ve bölgeleri; Terrain'e dokunulmaz). Diğer oyuncular değişimi canlı görür.
  Tema içeriği her tema için sunucu açılışında bir kez `ServerStorage.ThemeTemplates/Theme<n>` şablonuna kurulur
  (`MapBuilder.prepareTemplates`); `applyTheme` şablonu Clone edip adaya basar (yordamsal yol `applyThemeProcedural` yalnızca test referansıdır).
- Önceki çiftlik **park edilir**: çizilmez ama kayıtta durur ve çalışmayı sürdürür (gelir, üretim, yardımcılar).
  Otomatik Toplayıcısı olmayan park edilmiş çiftlik gelirinin `Config.PARKED_FARM_PAY_RATE` oranını doğrudan kasaya yatırır.
- Oyuncular birbirinin adasına yürüyebilir (Ziyaret) ama müdahale edemez.
- Fiziksel ada rezervasyonu yoktur; satın alma yalnızca temaya (çiftlik numarasına) bakar.

## Ortak ve ayrı olanlar

İlk çiftlik mevcut kayıttır. Ek çiftliklerin satın alma fiyatları `Config.MAIN_FARM_PRICES` (taban değerler; yükseltmelerle aynı
maliyet eğrisinden geçer, ilki ücretsiz), sınır `Config.MAIN_FARM_LIMIT`'tir. Çiftlik numarası (alım sırası) arttıkça o çiftlikteki
yükseltme, hayvan ve yapı fiyatları `Config.DIFFICULTY.tiers[sıra].costMultiplier` katına çıkar (`FarmMath.getPrice`; ayrıntı `docs/ZORLUK_VE_FIYAT.md`).
Dengeyi `scripts/simulate-economy.py` ile ölç.

Para, envanter ve ahır deposundaki ürünler oyuncuya aittir ve **tüm çiftliklerde ortaktır**
(tür başına depo sınırı = sahip olunan bütün ahırların toplamı). Her çiftliğin hayvanları, küçük ada kilitleri,
yükseltmeleri, ahır seviyesi, üretim partileri ve otomatik tekrar seçimi ayrıdır.
Yeni çiftlik başlangıç durumuyla açılır; mevcut çiftlikteki geliştirmeler kopyalanmaz.

Kayıt tek oturum kilidiyle, ortak cüzdan ve bütün çiftlikler birlikte yazılarak saklanır (şema sürümü `SessionLock.VERSION`;
kod `src/server/Modules/SaveCodec/`, DataStore `src/server/Services/SaveStore.luau`). Gecikmiş satın alma/üretim istekleri başka
çiftliğe uygulanmaması için hedef çiftlik kimliğiyle doğrulanır.

Studio kontrolü: harita sürümü değiştiyse Haritayı Kur → Doğrula → Ctrl+S. İkinci çiftliği satın al; adanın
yeni temayla yeniden kurulduğunu, ilkine dönünce eskisinin geri geldiğini ve iki ilerlemenin ayrı
kaldığını kontrol et. İki oyuncuyla (Test → Clients) birinin tema değişimini diğerinin ekranında izle.
