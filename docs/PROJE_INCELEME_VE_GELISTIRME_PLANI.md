# Ahır Tycoon — Proje incelemesi ve geliştirme planı

İnceleme tarihi: 28 Eylül 2026. Kod sürümü: Config.VERSION = 0.5.0, MAP_VERSION = 11.

> Bu belge ilk incelemenin tarihsel kaydıdır. 0.6.0 düzeltmelerinin güncel durumu ve doğrulama sınırları [Düzeltme durumu](DUZELTME_DURUMU.md) belgesindedir. Aşağıdaki “değiştirilmedi” ve kontrol sonuçları ilk inceleme anına aittir.

Bu belge mevcut kodun statik incelemesini, derleme/biçim kontrollerini ve geliştirme önerilerini içerir. Oyun kodu değiştirilmedi. Roblox Studio'da oyun, gerçek DataStore arızası, telefon performansı veya çok sunuculu oturum testi çalıştırılmadı. Dolayısıyla bu belge bütün olası hataların bulunduğu garantisi değildir; doğrulanabilen kod davranışları ile çalıştırılarak sınanması gereken riskler ayrılmıştır.

**Genel değerlendirme**

Oynanabilir prototip için temel yapı uygun: sunucu/client ayrımı, merkezi Config, ortak FarmMath, UiKit/WorldUi, sunucuda satın alma kontrolü, küçük ekonomi paketleri ve mesafeye göre görsel güncelleme var. Başlangıçtan tekrar yazmak gerekmiyor. Öncelik sırası: kayıt güvenliği → etkileşim güvenliği ve açılış → ilerleme/ekonomi → mobil arayüz → ölçülmüş performans → yeni içerik.

**İnceleme ve kontroller**

| Kontrol | Sonuç |
|---|---|
| Kaynak envanteri | src ve plugin altında 36 Luau dosyası, 8.441 satır |
| Strict başlıkları | 36 dosyanın tamamında --!strict var |
| Eski wait/spawn/delay kullanımı | Yapılan taramada bulunmadı |
| StyLua --check src plugin | Geçti; kaynaklar değiştirilmedi |
| Rojo oyun derlemesi | Geçti; çıktı geçici klasöre yazıldı |
| Rojo eklenti derlemesi | Geçti; çıktı geçici klasöre yazıldı |
| Selene src plugin | Tamamlanamadı: Roblox standard library için API dump alınamadı |
| Luau tür analizi | Ayrı bir tür analiz aracı çalıştırılmadı; strict başlığı tek başına başarı kanıtı değil |
| Git | Bu klasörde git status, “not a git repository” döndü |
| Otomatik test/CI | İncelenen dosyalarda bulunmadı |
| Harici model kaynakları | assets/Animals ve assets/Buildings içinde yalnızca .gitkeep var |

Rokit yönlendirme dosyaları bu çalıştırma ortamında “home directory not found” verdi. Kontroller kurulu araçların tool-storage içindeki gerçek çalıştırılabilir dosyalarıyla tekrarlandı. Bu, normal geliştirme terminalinin de bozuk olduğu anlamına gelmez. Rojo derlemesi paketlemeyi doğrular; Roblox çalışma zamanı ve tür doğrulaması yerine geçmez.

**Öncelik ve kanıt dili**

- P1: Yayın öncesinde çözülmeli; veri, güvenlik veya temel ilerleme riski.
- P2: İlk iyileştirme sürümlerinde ele alınmalı; davranış, kullanılabilirlik veya verimlilik sorunu.
- P3: İhtiyaca göre büyütülecek bakım ve ürün geliştirmesi.
- Kod bulgusu: Davranış veya eksik koruma kaynakta görülüyor; gerçekleşme sıklığı ölçülmüş değil.
- Koşullu risk: Belirtilen ortam, girdi veya içerik oluştuğunda önem kazanıyor.
- Tasarım kararı: Mevcut davranış geçerli bir tercih olabilir; oyuncuya verilen vaatle netleştirilmeli.
- Ölçüm gerekli: Darboğaz olduğu iddia edilmiyor; profil/test sonucuna göre işlem yapılmalı.

**Korunması gereken iyi kararlar**

- Fiyat, kapasite, ön koşul ve ödeme sunucuda hesaplanıyor; client fiyat veya gelir miktarı gönderemiyor.
- Başarısız veri yüklemesinden sonra canSave kapanıyor; boş kaydın gerçek kaydı ezmesine karşı mevcut koruma korunmalı.
- Türetilen ada/bölge/ahır durumu purchased üzerinden oluşturuluyor.
- Her saniye bütün profil yerine EconomyTick gönderiliyor.
- AnimalVisualService UID üzerinden yalnızca değişen hayvanı yeniliyor; BarnVisualService ve diğer görseller de yeniden oluşturmayı sınırlandırıyor. “Her alımda bütün ada silinip kuruluyor” iddiası doğru olmaz.
- Hayvan, kuş ve süs balığı hareketleri client tarafında; mesafe kontrolleri mevcut.
- Debug hava değiştirme sunucuda IsStudio kontrolünden geçiyor; yayınlanmış oyunda açık bir yönetici remote'u değil.
- Config'in Shared içinde bulunması açık değil; zaten oyuncuya gösterilebilecek oyun dengeleri burada olmalı.
- Başka adaya gitmek ve pazardan uzaktan satın almak mevcut tasarımın parçası; tek başına hile sayılmaz.

**Kayıt ve veri bütünlüğü — 6 bulgu**

**D01 · P1 · Oturum sahipliği ve sıralı kayıt yok — kod bulgusu.**
Kanıt: src/server/Services/PlayerDataService.luau:210, :269, :363, :369. GetAsync ile yükleniyor; UpdateAsync callback'i mevcut değeri/sahipliği kontrol etmeden önceden hazırlanmış payload döndürüyor. Hızlı kayıt, otomatik kayıt, ayrılma ve kapanış aynı oyuncu için çakışabilir. Eski sunucunun geciken kaydı yeni oturumun ilerlemesini geri alabilir. UpdateAsync kullanmak tek başına bunu çözmüyor.
Çözüm: Oyuncu anahtarı başına tek kayıt kuyruğu, oturum kilidi ve süreli yenileme, değişiklik revizyonu, kapanış durumu. Kilit kaybında ekonomik değişiklikleri durdur. Kabul: Geciktirilmiş eski kayıt yeni revizyonu ezememeli; ikinci sunucu geçerli kilit varken aynı profili yönetememeli. Bu yaklaşım Roblox'un [oyuncu verisi rehberiyle](https://create.roblox.com/docs/cloud-services/data-stores/player-data-purchasing) uyumludur.

**D02 · P1 · Başarısız son kayıt sonrası veri bellekten siliniyor — kod bulgusu.**
Kanıt: PlayerDataService.luau:269 ve :300. save yalnızca warn yapıyor, başarı sonucu vermiyor; release sonucundan bağımsız temizliyor. Çıkışta geçici hata son ilerlemeyi kaybettirebilir.
Çözüm: Başarı/başarısızlık sonucu, süre bütçeli tekrar deneme, sıralamayı koruyan bekleme, son başarılı kayıt zamanı ve dirty durumu. Kabul: İlk iki yazması başarısız olan senaryo üçüncü başarıya kadar kontrollü sürmeli; kapanış süresi tükenirse hata ölçülmeli. Mutlak sıfır veri kaybı vaadi verilmemeli.

**D03 · P1 · Studio ve canlı veri ayrımı tanımlı değil — koşullu risk.**
Kanıt: src/shared/Config.luau:109 ve README kayıt kurulumu. Tek DATASTORE_NAME kullanılıyor. Aynı deneyimde API erişimi açık Studio testi canlı oyuncu anahtarlarına yazabilir. Mevcut place ayarı okunmadı; riskin şu anda gerçekleştiği iddia edilmiyor.
Çözüm: Ayrı test deneyimi; ek koruma olarak açık ortam/store seçimi. Kabul: Test kullanıcısının yazdığı anahtarın canlı ortamda değişmediğini doğrula. Roblox da [Studio erişimi için ayrı test sürümü](https://create.roblox.com/docs/cloud-services/data-stores) öneriyor.

**D04 · P1 · Kayıtsız oturum normal oyun gibi devam ediyor — kod bulgusu.**
Kanıt: PlayerDataService.luau:244 ve devamı; src/client/UiKit.luau:581 civarındaki kısa bildirim süresi. Yükleme hatasında varsayılan profille devam ediliyor ve bilgi kısa toast ile veriliyor. Oyuncu sonradan kaydedilmeyecek ilerlemeye zaman harcayabilir. Ayrıca store hiç alınamazsa loadOk doğru kabul ediliyor; bu yol belirgin oyuncu uyarısını atlayabiliyor.
Çözüm: Canlı oyunda kalıcı yükleme/yeniden deneme ekranı; yüklenmeyen profilde satın alma ve gelir akışını başlatmama. Studio denemesi açıkça “kayıtsız test” olarak kalabilir. Kabul: Veri hatası kullanıcıdan gizlenmemeli, gerçek profil hiçbir fallback veriyle yazılmamalı.

**D05 · P2 · Kayıt sürümü yazılıyor fakat okunmuyor — kod bulgusu.**
Kanıt: PlayerDataService.luau:21, :90, :101. LEGACY_UPGRADES birkaç ID dönüştürüyor; sıralı şema migrasyonu veya gelecekteki sürümü reddetme yok.
Çözüm: RawSaveV1/RawSaveV2 tipleri, adım adım migration ve desteklenmeyen sürümde korumalı duruş. Kabul: Eski kayıt iki defa işlenince ikinci kez ödül/iade verilmemeli; yeni sürüm eski kodla sessizce bozulmamalı.

**D06 · P2 · Yüklenen verinin bütünlük denetimi eksik — koşullu risk.**
Kanıt: PlayerDataService.luau:108–170. Sayılarda sonluluk ve üst sınır, UID tekilliği, hayvan toplamı/bölge kapasitesi, tarih sınırları ve açık bölgeye yerleşim tam doğrulanmıyor. Uyumlu tür, kilitli veya kapasitesi dolu bölgede kalabiliyor; kaldırılmış bölge ID'sindeki kayıt ise doğrudan atlanıyor. Bu, client'ın doğrudan DataStore değiştirebildiği anlamına gelmez; eski sürüm, migrasyon veya bozuk kayıt senaryosudur.
Çözüm: Normalleştirme + sürüme özgü taşıma politikası; UID üretme/tekilleştirme; sorunlu kaydı gözlenebilir şekilde koruma/karantinaya alma. Kabul: Bozuk örnekler NaN/sonsuz gelir, görünmez hayvan, sınırsız kapasite veya sessiz varlık kaybı üretmemeli.

**Etkileşim güvenliği — 3 bulgu**

**S01 · P1 · Yükseltme isteğinde sunucu hız sınırı yok — kod bulgusu.**
Kanıt: src/server/Services/UpgradeService.luau:16 ve :64. Hayvan alımında 0,2 saniye sınırı var; yükseltme alımında karşılığı yok. Geçersiz veya zaten alınmış ID bile hesap ve Notify cevabı üretiyor.
Çözüm: Oyuncu/eylem bazında ortak hız sınırlayıcı, kısa ID sınırı, yüklenmiş/aktif oturum kontrolü. Prompt ve remote aynı denetimden geçmeli. Kabul: Kontrollü yoğun istek testinde ekonomik değişiklik ve cevap üretimi sınırlandırılmalı. Referans: [Client–server sınırını koruma](https://create.roblox.com/docs/scripting/security/client-server-boundary).

**S02 · P2 · Toplama yalnızca Touched ve sahipliğe güveniyor — kod bulgusu.**
Kanıt: src/server/Services/EconomyService.luau:98. Sahiplik kontrolü doğru, fakat sunucuda karakter-platform yakınlığı kontrol edilmiyor. Mevcut etki başkasının parasını çalmak değil, kendi deposunu uzaktan toplama kuralını aşmak olabilir.
Çözüm: Ekonomik işlemi yapan collect içinde sunucu karakteri, geçerli plot ve makul mesafe doğrulaması. Hız/konum atlaması için yalnızca gerçekten gereken kontroller; istemcinin yönettiği karakter konumunu da mutlak güvenlik saymama. Kabul: Uzakta tetiklenen olay aktarım yapmamalı. Roblox, [Touched olayının istemci tarafından etkilenebileceğini](https://create.roblox.com/docs/physics/network-ownership) belgeliyor.

**S03 · P1 · Bina modellerinde script temizliği yok — koşullu risk.**
Kanıt: src/server/Services/UpgradeVisualService.luau:326–351. Model Clone edilip Workspace'e ekleniyor. AnimalVisualService.luau:280'de hayvan modellerinin Script/LocalScript çocukları temizlenirken binalarda bu işlem yok. README'nin tüm Toolbox modelleri temizleniyor açıklaması bu nedenle fazla geniş. Şu anda assets klasöründe harici model yok; mevcut zararlı script bulunduğu söylenmiyor.
Çözüm: Ortak model kabul/temizleme yordamı; çalışabilir scriptleri dünyaya eklemeden kaldır; fizik/anchor ayarlarını doğrula. Şablonları ihtiyaç yoksa ServerStorage'da tut. Kabul: Test binasının içine konan zararsız test Script'i klonlama sonrasında çalışmamalı; istemci RunContext gibi durumlar için içe alma aşaması da denetlenmeli.

**Açılış ve dünya yaşam döngüsü — 3 bulgu**

**R01 · P2 · İlk durum için hazır olma/yeniden eşitleme protokolü yok — dayanıklılık riski.**
Kanıt: src/server/init.server.luau:100, src/client/ClientState.luau:41–52. Tam durum sunucudan gönderiliyor; client'ın snapshot istemesi veya revizyon açığını onarması yok. current nil iken ekonomi paketi kullanılmıyor. Normal RemoteEvent tamponlaması kısa gecikmeleri karşılayabilir; her girişte ilk paket kaybolur iddiası doğru değil.
Çözüm: Client hazır bildirimi, hız sınırlı güncel snapshot cevabı ve revizyon; ClientState dinleyicilerinin abonelikten çıkabilmesi. Kabul: HUD geç başlatıldığında veya tekrar kurulduğunda güncel durum güvenilir biçimde gelsin.

**R02 · P2 · Yükleme ekranı profilin hazır olmasını beklemiyor — kod bulgusu.**
Kanıt: LoadingScreen.client.luau:128–135 ve init.server.luau:86–100. Karakter veri yüklemesinden önce doğuyor; yükleme ekranı karakter gelince kapanıyor, HUD ise profili bekliyor. 25 saniye sınırı game.Loaded:Wait aşamasını kapsamıyor.
Çözüm: Dünya/karakter/profil için ayrı hazır durumları, bütün açılışı kapsayan zaman aşımı ve kullanıcıya anlamlı hata. LoadCharacter hatasını da yakala. Kabul: Yavaş/hatalı veri yüklemesinde boş arayüz veya belirsiz bekleme görülmemeli.

**R03 · P1 · Ada yokken ekonomik oturum devam ediyor — koşullu risk.**
Kanıt: init.server.luau:90–95; MapBuilder.luau:858 ve :1046. Ada atanamasa da veri ve gelir başlıyor. hasValidPlots tek uygun plot görünce yeterli sayıyor; eksik plot/bölge/collector ve eski harita sadece kısmen denetleniyor. Oyuncu satın alabilir fakat hayvanlarını veya toplayıcısını göremeyebilir.
Çözüm: Açılışta harita sözleşmesi doğrulaması; sayı, eşsiz ID, spawn, collector, bölgeler ve satın alma noktaları; plot verilemeyince kontrollü hata/yeniden katılım akışı. Kabul: Eksik harita ile normal ekonomi başlatılmamalı; MaxPlayers ve 6 plot tutarlı olmalı. Uzman ada kilidi fiziksel erişim değil ekonomik açılma olarak korunabilir.

**Ekonomi ve ilerleme — 7 bulgu**

**E01 · P1 · Balık kapasitesi kalıcı seçim kilidi oluşturuyor — kod bulgusu.**
Kanıt: Config.luau:444–445, FarmMath.findZoneForAnimal ve AnimalService.tryBuy. Hamsi ile levrek aynı 10 yeri kullanıyor. 10 hamsi alan oyuncu levrek alamıyor; satma, taşıma veya değiştirme işlemi yok. Bütün oyun değil, bu üretim dalının geliştirilmesi kilitleniyor.
Çözüm: En küçük çözüm olarak sunucuda doğrulanan hamsi → levrek değiştirme; alternatif satış + yeniden alım veya ayrı kapasite. İade fiyatını büyüyen güncel alış fiyatından türeterek al-sat kazanç döngüsü oluşturma. Kabul: Dolu kafes levreğe yükseltilebilmeli, para/kapasite korunmalı.

**E02 · P2 · Çevrimdışı kazanç geçmişi bugünün koşullarıyla hesaplanıyor — kod bulgusu/tasarım kararı.**
Kanıt: PlayerDataService.luau:151 ve :178–182; FarmMath.computeIncomePerSecond → Environment. Önce hayvan dönüş anındaki evreye büyütülüyor, sonra bu gelir bütün ayrılık süresiyle çarpılıyor. O anki sunucunun hava/mevsimi de geçmiş süreye uygulanıyor.
Çözüm: Basit ve açık bir politika: çevrimdışında nötr hava, zaman aralıklarına göre büyüme evresi hesabı, üst süre/kapasite sınırı; ya da bilinçli sabit snapshot geliri. Kabul: Tek yavru ineğin 135 saniyelik ayrılığında, bonuslar hariç ve depo sınırına takılmadan, evre hesabı 65,25 brüt çevrimdışı gelir verirken mevcut yaklaşım 135 veriyor; seçilen politika bu farkı açıkça çözmeli. Hava sunucusunu değiştirerek geçmiş ödül değişmemeli.

**E03 · P2 · Gelir gerçek geçen süre yerine sabit tick ile artıyor — kod bulgusu.**
Kanıt: EconomyService.luau:79 ve :114. Döngü gecikse de yalnızca INCOME_TICK_SECONDS kadar kazanç ödeniyor. Yük altında gelir duvar saatinin gerisine düşebilir.
Çözüm: Monotonik zamanla geçen süreyi hesapla; oyuncu bazında yüklenme anını dikkate al, uzun duraksama telafisine bilinçli sınır koy. Kabul: Aynı 60 saniyelik senaryoda gecikmeli scheduler ile normal scheduler anlamlı biçimde farklı para üretmemeli.

**E04 · P2 · Hedef süreleri depoyu ve toplama gereksinimini hesaba katmıyor — kod bulgusu.**
Kanıt: FarmHud.client.luau:515 ve :561. Hesap yalnızca (fiyat - cash) / gelir. Depo doluyken gelir durmasına rağmen süre gösteriliyor; depoda satın almaya yetecek para varsa hâlâ beklemeyi önerebiliyor.
Çözüm: Cash, stored, cap ve otomatik toplama durumunu birlikte kullan. “Önce depoyu topla” veya “düzenli toplarsan yaklaşık...” açıklaması. Kabul: Dolu depoda kalan süre değişmeyen fakat yanıltıcı bir vaat olarak kalmamalı.

**E05 · P2 · Hızlandırıcı geçmiş büyüme süresini de çarpıyor — tasarım kararı.**
Kanıt: FarmMath.luau getStage/getGrowthSpeed. Silo alımı (now - bornAt) değerinin tamamına yeni hızı uyguluyor; eski hayvan bir anda evre atlayabilir. Değişiklik büyüme döngüsünde yansıtıldığı için alım anındaki durum kısa süre eski kalabilir.
Çözüm: Retroaktif büyüme bilinçli tercihse açıklayıp tutarlı uygula; değilse birikmiş büyüme ve son güncelleme zamanı tut. Kabul: Silo öncesi/sonrası sınır testlerinde aynı kural uygulanmalı.

**E06 · P2 · Sekiz saatlik çevrimdışı sınır mevcut depolarla çoğunlukla etkisiz — denge/tasarım kararı.**
Kanıt: Config.luau:186–187 ve BARN_LEVELS; PlayerDataService çevrimdışı hesabı. Nötr mevsim/hava, boş depo ve başlangıçtaki iki yetişkin inek varsayımıyla 250 kapasite, %50 çevrimdışı gelirde 125 saniyede dolar. Bütün yükseltmeler + 14 inek/10 levrek/12 tavuk/6 at/8 keçi için nötr gelir 1.485,8/sn; 12.500 kapasite çevrimdışında yaklaşık 16,8 saniyede dolar. Otomatik toplayıcı çevrimdışı hesapta kapasite sınırını kaldırmıyor. Bunlar oynanış ölçümü değil Config'ten hesaplanan örneklerdir.
Çözüm: Çevrimdışı kazanç için ayrı bütçe/depo veya farklı eğri; otomatik toplayıcının çevrimdışı davranışını açık yaz. Kabul: 5 dakika, 30 dakika, 2 saat ve 8 saat dönüş senaryolarındaki ödüller bilinçli ürün kararına uymalı.

**E07 · P3 · Mevcut yol haritası bitince yeni hedef kalmıyor — ürün fırsatı.**
Kanıt: FarmHud.updateGoal tamamlanınca yalnızca tüm yükseltmelerin alındığını söylüyor. Ürün adları var fakat ayrı ürün envanteri/teslimat döngüsü yok; temel oyun pasif gelir + satın alma.
Çözüm: İlk genişleme olarak tek bir kısa çiftlik siparişi/ustalık döngüsü seç. Sonra isteğe bağlı dekorasyon veya koleksiyon. Rebirth, ticaret, nadirlik, görev, yeni adalar ve monetizasyonu aynı anda ekleme. Kabul: Oyuncunun otomatik toplayıcı sonrasında ve son yükseltme sonrasında anlaşılır bir sonraki hedefi olsun; eğlence/oturum ölçümüyle değerlendir.

**Arayüz ve oyuncu deneyimi — 6 bulgu**

**U01 · P1 · Mobil yerleşim sabit masaüstü genişliklerine dayanıyor — kod bulgusu, cihaz testi gerekli.**
Kanıt: FarmHud.client.luau:39–48, :206–238; TravelMenu.client.luau ölçek kurulumu. 380 genişlikli pencere sağ kenardan 194 uzaklığa konuyor; yalnızca 0,75 ölçek varsayımı bile dar ekranlarda yeterli güvenli alan sağlamıyor. Sol istatistik paneli ve sağ menü birlikte alan kaplıyor. Seyahat menüsü ölçeği yalnızca ilk kurulumda hesaplanıyor.
Çözüm: Telefonda kompakt üst HUD + tek tam/geniş pencere; ekran genişliği ve yüksekliğine göre sınırlama; çentik, dokunmatik joystick ve yön değişimi kontrolü. Kabul: 360/390 genişlik, küçük yatay ekran ve tablette temel butonlar erişilebilir olmalı. Gerçek taşma ekran görüntüsü bu incelemede alınmadı.

**U02 · P2 · Kart ve bildirimlerin metin ölçüleri esnek değil — kod bulgusu.**
Kanıt: UiKit.luau:430 sabit 66 yükseklik; :561 TextWrapped=false. Uzun açıklamalar dar sütunda büyüyebilir; toast sınırsız yatay genişleyebilir. Mevsim barında da sarılmayan metinler var.
Çözüm: Kart yüksekliğini içeriğe bağla; bildirim genişliğini viewport'a göre sınırla ve satır kırdır; uzun sayı/metin senaryoları. Kabul: Uzun ada açıklaması, büyük para miktarı ve dört bildirim üst üste geldiğinde okunabilirlik korunmalı.

**U03 · P2 · Satın alım bekleme/sonuç durumu yok — kod bulgusu.**
Kanıt: FarmHud satın alma Activated bağlantıları. İstek gönderilince buton güncel cevaba kadar yeniden basılabiliyor. Hayvan alımında gecikme boyunca fiyat değişerek birden çok alım oluşabilir; server cooldown bunu yalnızca kısmen azaltır.
Çözüm: İstek kimliği ve sonuç cevabı; ilgili kartta kısa pending durumu, zaman aşımı ve tekrar eşitleme. Kabul: Tek satın alma niyeti yüksek gecikmede istemeden ek alıma dönüşmemeli. Bu UI koruması sunucu doğrulamasının yerini alamaz.

**U04 · P3 · UI standardının birkaç istisnası dağınık — kod bulgusu.**
Kanıt: FarmHud içindeki sabit RichText renkleri; LoadingScreen renk/font kopyaları; CollectorGuide.floatMoney'nin doğrudan BillboardGui üretmesi. LoadingScreen'in ReplicatedFirst'ta erken başlaması için bağımsız olması anlaşılır, ama güncelleme politikası yok.
Çözüm: Tema tabanlı RichText yardımcıları; WorldUi para etiketi bileşeni; erken yükleme teması için küçük ortak/üretilmiş sabitler veya açık belgelenmiş istisna. Kabul: Renk değişikliği birden fazla elle düzenleme gerektirmemeli.

**U05 · P2 · İlk hedef her zaman en ucuz yükseltme; öğretim sınırlı — tasarım fırsatı.**
Kanıt: FarmHud.updateGoal en ucuz available yükseltmeyi seçiyor. Başlangıçta 6 inek yeri varken 2 dolu; buna rağmen ilk yükseltme hedefi +8 yer sağlayan Otlak. Sonraki inek fiyatı 90; başlangıç cash 50. Toplayıcı çizgisi faydalı ama tam bir ilk kullanım akışı değil.
Çözüm: “İlk parayı topla → yeni inek al → büyümeyi gör → kapasite/ahır tercih et” gibi kısa, sunucu durumuna dayanan öğretim. Tamamlanan aşamalar kaydedilebilir. Kabul: Yeni oyuncu yardım almadan ilk toplama ve alımı yapabilmeli; zamanını ölç.

**U06 · P3 · Ses, erişilebilirlik ve gamepad akışı planlanmamış — ürün fırsatı.**
Kanıt: Mevcut scriptlerde ses/ayar sistemi yok; sprintte gamepad tuşu var, menüler için açık odak ve geri dönüş akışı yok. Durumlar metinle de verildiği için yalnızca renk kullanılıyor demek doğru olmaz.
Çözüm: Toplama/alım/ret için hafif sesler, ses seviyesi; düşük efekt/hareket ve şimşek azaltma seçeneği; gamepad odak testi. Kabul: Efektler kapalıyken temel geri bildirim anlaşılır olmalı, menüler klavye/gamepad ile kapanabilmeli.

**Performans ve görsel tutarlılık — 6 bulgu**

**P01 · P2 · Hafif ekonomi paketinden sonra ağır UI güncellemesi yapılıyor — kod bulgusu.**
Kanıt: ClientState structural bayrağı üretiyor; FarmHud.onState :567 bu bayrağı kullanmıyor ve :595–596 bütün pazar/yol haritası kartlarını tekrar hesaplıyor. Pencereler kapalıyken de çalışıyor; değişmeyen cash için tween oluşturulabiliyor.
Çözüm: Para tick'inde para/depo ve değişen alınabilirlik; yapısal veya çevresel değişimde kart içerikleri; kapalı pencereleri dirty olarak işaretle. Kabul: Kapalı pazar kartlarının bütün metinleri her saniye yenilenmemeli; açıldığında güncel olmalı.

**P02 · P2 · Gelir hesabında aynı türe ait çarpanlar tekrar hesaplanıyor — ölçüm gerekli.**
Kanıt: FarmMath.computeIncomePerSecond → getAnimalIncome → getAnimalMultiplier her hayvan için upgrade listesini geziyor. Bu miktarda kendi başına ağır darboğaz kanıtı değil. Mevcut üst sınır 50 hayvan/oyuncu, altı oyuncuda 300 ekonomik hayvan.
Çözüm: Önce profil ölçümü; gerekirse tek hesap döngüsünde tür başına çarpan önbelleği, revizyona bağlı türetilmiş değerler. Kabul: Sonuçlar aynı kalmalı; önbellek mevsim/yükseltme değişince geçersizleşmeli.

**P03 · P2 · Efekt kalitesi cihaz kapasitesine göre ayarlanmıyor — ölçüm gerekli.**
Kanıt: WeatherEffects.client.luau:213–214; yağmur 1.200, fırtına 2.200, kar 550 Rate; kar ömrü 6–8 saniye. Bunlar tanımlı oranlar; motorun cihazdaki gerçek parçacık sayısı/FPS'i ölçülmedi. Birds/FishLife mesafe kontrolüne rağmen bütün modelleri başlangıçta oluşturuyor.
Çözüm: Düşük/orta/yüksek kalite, yakındaki süsler için oluşturma/yeniden kullanım sınırı; gerektiğinde uzak animasyon güncelleme sıklığını düşür. Kabul: Altı dolu çiftlik + kar/fırtına + açık pazar senaryosunda seçilen düşük cihazda hedef FPS ve bellek bütçesi sağlansın.

**P04 · P2 · Dekorların fizik ve gölge maliyeti sistematik sınırlandırılmıyor — ölçüm gerekli.**
Kanıt: WorldDecor.part, MapBuilder.makePart, AnimalVisualService.block. Bazı süslerde CanCollide kapalı, ancak CanTouch/CanQuery/CastShadow politikası tutarlı değil; özel modellerin fizik ayarları da farklı kalabilir.
Çözüm: Yürünen zemin, etkileşimli nesne ve dekor için ayrı parça ayarları; görsel asset bütçesi. Collector gibi gerçek dokunma nesnelerini koru. Kabul: Görünüm/yürünebilirlik korunurken fizik, gölge ve instance maliyetindeki farkı ölç.

**P05 · P2 · Bir defalık dünya taramaları geç yüklenmeye ve streaming'e hazır değil — koşullu risk.**
Kanıt: IslandPrompts.client.luau başlangıç GetChildren/GetDescendants; WeatherEffects :352–355; FishLife spawnSchools öncesi sabit 2 saniye; BuildEffects başlangıç plot taraması. Plots klasörünün gelmesi bütün çocuklarının geldiğinin garantisi olarak kullanılıyor. Klasörde StreamingEnabled ayarı belirtilmiyor; gerçek place ayarı bilinmiyor.
Çözüm: İdempotent ekleme/çıkarma, CollectionService veya descendant olayları; streaming ile model bütünlüğü ve uzak teleport hedefi hazırlığı. Bir düğmeyle streaming açıp bitmiş sayma. Kabul: Gecikmeli çoğalan ve stream-out/in olan nesneler tekrar düzgün izlenmeli. Referans: [Instance streaming](https://create.roblox.com/docs/workspace/streaming).

**P06 · P2 · Sunucu ada yenilemesi mevsim görünümünü ezebilir — kod bulgusu.**
Kanıt: PlotService.luau:208–210 her refresh'te açık ada Color/Material değerini geri yazar. WeatherEffects.applyGround ise mevsim/hava veya Locked değişiminde tekrar çalışıyor. Aynı Locked değeri tekrar yazıldığında bu dinleyiciye güvenilemez; satın alma/büyüme kış görünümünü bozabilir.
Çözüm: Sunucu yalnızca oyun kilit durumunu, client mevsim görünümünü yönetsin; ya da görünüm revizyonunu açıkça ilet. Kabul: Kışın hayvan alıp büyütünce uzman adanın kar görünümü korunmalı.

**Bakım, yayın ve ölçüm — 5 bulgu**

**M01 · P1 · Bu çalışma kopyasında sürüm kontrolü yok; model dosyaları genel olarak ignore ediliyor — kod/ortam bulgusu.**
Kanıt: git status sonucu ve .gitignore içindeki *.rbxm/*.rbxmx. İleride assets altına konacak kaynak modeller de bu kurala takılabilir. Başka yerde yedek/depo olmadığı sonucuna varılmıyor.
Çözüm: Bu klasör için Git ve doğrulanmış uzak yedek; kaynak asset'leri build çıktılarından ayıran ignore kuralları. Mevcut Studio place'i ve harita tekrar üretme prosedürü de kaydedilmeli. Kabul: Temiz bir checkout'tan kaynak modeller ve Rojo projeleriyle tekrar kurulum yapılabilmeli.

**M02 · P1 · Ekonomi/veri değişikliklerini koruyan otomatik test kapısı yok — kod bulgusu.**
Çözüm: Önce saf FarmMath, bozuk kayıt/migration ve kayıt çakışma testleri; ardından Studio çok oyunculu senaryolar. CI'da StyLua, Selene, Luau tür analizi ve iki Rojo build. Kabul: Geçersiz satın alma para değiştirmemeli; ekonomi evre sınırları, migration ve D01/D02 hata enjeksiyonları otomatik doğrulanmalı. Sırf uygulamayı tekrar eden testler eklenmemeli.

**M03 · P3 · Strict sınırları bazı yerlerde any ile genişletilmiş; büyük dosyalar sorumluluk biriktiriyor — bakım bulgusu.**
Kanıt: Remotes.get :49 any döndürüyor; PlayerDataService raw tabloları any; FarmHud 604 ve MapBuilder 1.064 satır. Satır sayısı tek başına hata değil.
Çözüm: Tipli remote isim/payload sözleşmeleri, raw veri doğrulayıcıları; FarmHud'da panel/controller ayrımı, MapBuilder'da layout/veri ile yapım yordamlarının ayrılması. Sadece ilgili işi yaparken küçük adımlarla böl. Eklenti Shared fallback'ini ve MAP_VERSION sözleşmesini koru.

**M04 · P2 · Harita kurmanın silme kapsamı belgelenenden geniş — kod bulgusu.**
Kanıt: MapBuilder.luau:980–1000. Plots/World dışında Baseplate, Workspace kökündeki SpawnLocation'lar ve tüm Terrain siliniyor. README elle eklenen süsleri Plots/World dışına taşımanın yeterli olabileceğini söylüyor; Terrain için yeterli değil. Eklenti geri alma kaydı açılamasa da build'e devam ediyor.
Çözüm: Üretilen içerik sınırlarını açıkla; mümkünse haritayı doğruladıktan sonra değiştir; undo kaydı olmadan destructive build yapma; hata halinde eski haritayı koru. Kabul: Harici dekor/terrain için politika ve geri alma testi açık olmalı; eklenti tekrar tıklama/hata durumunda yarım harita bırakmamalı.

**M05 · P2 · Hata ve oyuncu ilerlemesi ölçümleri yok — bakım/ürün fırsatı.**
Kanıt: Loglar print/warn ağırlıklı; kaydetme başarı oranı, yükleme süresi, ilk satın alma, depo dolu geçirilen süre veya yol haritası tamamlanma ölçümü yok. DEBUG canlı/test ayrımı olmadan true.
Çözüm: Az sayıda yararlı sayaç/olay: veri yükleme-kayıt hatası, kilit çakışması, ilk toplama/alım, ada açma, depo doluluk süresi, roadmap tamamlama; sürüm/ortam bilgisi. Kişisel veriyi gereksiz loglama. Kabul: “Oyuncu niye ayrıldı / kayıt niye kayboldu?” sorularına tahmin yerine kayıtla yaklaşılabilmeli.

**Uygulama paketleri**

Her paket ayrı, küçük değişiklikler halinde uygulanmalı. Yeni sistem eklemek yerine mevcut servisleri güçlendirmek tercih edilmeli. M01 sürüm/yedek kurulumu uygulama başlamadan; M02 test altyapısı ilk paketle birlikte ele alınmalı.

| Sıra | Paket | Kapsam | Tamamlanma ölçütü |
|---|---|---|---|
| 1 | Güvenilir oyuncu profili | D01–D06, M01, M02'nin veri testleri | Çakışan kayıt eski veriyi yazamıyor; hata/çıkış testleri geçiyor; test ve canlı ayrılmış |
| 2 | Güvenli etkileşim ve açılış | S01–S03, R01–R03, M04 | Spam sınırlandırılmış; modeller temizleniyor; plot/profil hazır olmadan normal ekonomi başlamıyor |
| 3 | Tutarlı ekonomi ve ilk oyun | E01–E06, U05 | Dolu kafes geliştirilebiliyor; offline/tick/ETA kuralları tutarlı; ilk kullanım anlaşılır |
| 4 | Mobil ve erişilebilir arayüz | U01–U04, U06 | Telefon/tablet/masaüstü ve gamepad senaryoları geçiyor; satın alma sonucu belirgin |
| 5 | Ölçülmüş performans ve dünya görünümü | P01–P06 | Altı tam çiftlikte profil kaydı var; önce/sonra farkı ölçülmüş; mevsim ve streaming testleri geçiyor |
| 6 | Tek bir tekrar oynama döngüsü | E07, M05'in ürün olayları | Yol haritası sonrası hedef var; deneme oyuncularının davranışı ölçülüyor |
| 7 | Sürdürülebilir yayın | M02'nin tam CI kapısı, M03, M05 | Temiz kurulum, sürümleme, smoke test, veri geri yükleme ve hata takip prosedürü hazır |

Paket 5 için temel performans ölçümü geliştirme öncesinde alınmalı; optimizasyonun uygulaması sonra yapılabilir. M05'in veri hata ölçümleri paket 1'de başlamalı; kullanıcı davranışı ölçümleri paket 3 ve 6'da genişletilmeli. Paket 7'deki test kapıları daha önce yazılmış kontrolleri birleştirir; testler sona bırakılmaz.

**Paket 1 için somut iş sırası**

- [ ] Studio/canlı ortamını ayır; eski kayıt örneklerini test fikstürü yap.
- [ ] Profil durumlarını tanımla: Loading, Active, Failed, Closing, Closed.
- [ ] Tek oyuncu anahtarında sıralı kayıt ve değişiklik revizyonu kur.
- [ ] Atomik oturum kilidi, yenileme, kilit kaybı ve son kayıtla bırakma akışını ekle.
- [ ] Save sonucunu çağırana ilet; başarısızlıkta kontrollü tekrar deneme ve görünür hata kaydı ekle.
- [ ] Migrasyon ve normalleştirmeyi ayrı saf yordamlar yap.
- [ ] Load/save/leave/shutdown yarışlarını ve yeni sürüm reddini test et.
- [ ] Bu kapılar geçince satın alma/ekonomi servislerini yalnızca Active profille çalıştır.

**Yayın öncesi test matrisi**

| Senaryo | Beklenen |
|---|---|
| İki sunucu aynı kullanıcı için çakışan oturum açıyor | Yalnızca biri profil üzerinde yetkili |
| Autosave sürerken alım + çıkış + shutdown | Eski snapshot yeni ilerlemeyi geri almıyor |
| DataStore geçici hata/kalıcı hata | Kontrollü retry; yanlış başarı bildirimi veya sessiz kayıt silme yok |
| Geçersiz ID/tip, yoğun satın alma isteği | Para/envanter korunuyor, işlem/cevap üretimi sınırlandırılıyor |
| Başkasının collector/prompt etkileşimi | Başkasının ekonomisi değişmiyor |
| Yükleme sırasında çıkış ve hızlı tekrar giriş | Hayalet profil/plot veya eski kayıt yazması yok |
| Altı plot dolu, yedinci oyuncu/eksik harita | Açık hata akışı; plotsuz normal ekonomi yok |
| 10 hamsi bulunan kafeste levreğe geçiş | Güvenli değiştirme/satış mümkün |
| 44/45/134/135 saniyelik büyüme sınırları | Beklenen evre/gelir; hızlandırıcı kuralı tutarlı |
| Offline dönüş + hava/mevsim/silo/auto collect | Belgelenen aynı politika uygulanıyor |
| Dolu depo ve satın almaya yetecek stored | Doğru toplama yönlendirmesi; yanıltıcı süre yok |
| Yavaş çoğalma + dünya stream-out/in + teleport | Prompt, rehber ve efektler tekrar doğru bağlanıyor |
| Kışın hayvan alımı/büyümesi | Uzman ada kar görünümü korunuyor |
| 360/390 ekran genişliği + yatay dönüş + uzun metin | Butonlar ve bütün temel bilgiler erişilebilir |
| Altı oyuncu × 50 hayvan + kar/fırtına + menü | Hedef cihazda kabul edilen FPS/bellek/ağ bütçesi |
| Temiz checkout + Rojo oyun/eklenti build | Gerekli kaynak asset'ler ve harita kurulumu eksiksiz |

Performans için başlangıç hedefi olarak düşük cihazda kararlı 30 FPS, masaüstünde 60 FPS değerlendirilebilir; bunlar mevcut ölçüm sonuçları değil, gerçek test cihazı seçilince netleştirilecek ürün hedefleridir. Ortalama yanında kare sürelerinin kötü yüzde dilimi, client bellek kullanımı, server script süresi ve ağ trafiği kaydedilmeli.

**Kapsamı koruma**

İlk üç paket tamamlanmadan yeni ada/hayvan türleri, ticaret veya ücretli ürün eklemek mevcut sorunların etkisini büyütür. Özellikle oyuncular arası ticaret, güvenilir veri sahipliği ve atomik işlem tasarımı gerektirir. Temeli sağlamlaştırdıktan sonra Ahır Tycoon'un sade kimliğine uygun tek bir aktif çiftlik etkileşimini deneyerek ilerlemek daha ölçülebilir olacaktır.
