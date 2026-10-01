# Island Farm Tycoon

Rojo + Luau ile yazılan Roblox çiftlik tycoon oyunu. Her oyuncunun kendi adası var.

## Kurulum (bir kez)

1. [Roblox Studio](https://create.roblox.com) kur.
2. [Rokit](https://github.com/rojo-rbx/rokit) kur, sonra bu klasörde:
   ```
   rokit install
   ```
   Bu komut `rojo`, `stylua` ve `selene` araçlarını kurar.
3. VS Code / Cursor'da önerilen eklentileri kur (klasörü açınca sorar):
   Rojo, Luau Language Server, StyLua, Selene.
4. Roblox Studio'da **Rojo** eklentisini kur (Plugins → Manage Plugins veya `rojo plugin install`).

## Çalıştırma

```
rojo serve
```
Studio'da place'i aç → Rojo eklentisi → **Connect**.

### Harita (bir kez, ve harita kodu değişince)

Harita kodla üretilir ama **düzenleme modunda** kurulup place'e kaydedilir, böylece Play'e basmadan görünür.

1. Eklentiyi kur (bir kez; Studio'yu yeniden başlat):
   ```
   rojo build plugin.project.json --plugin IslandFarmTycoonHarita.rbxm
   ```
2. Studio → **Plugins** sekmesi → **Island Farm Tycoon → Panel** ile sabit işlemler panelini aç (tek düğme; panel bir kez daha basınca kapanır).
   Panelde: **Haritayı Kur**, **Haritayı Doğrula** (validate + harita yapı testi + dünya testi), **Harita Bilgisi**, **Rojo Kontrolü**, **Günlüğü Temizle**.
   Sonuçlar panelde ve Output'ta görünür. (Harita kurulumu Ctrl+Z ile geri alınır.)
   Testler eklentinin içinde gömülüdür; kodu değiştirince `rojo build plugin.project.json --plugin IslandFarmTycoonHarita.rbxm` ile eklentiyi yenile.
3. **Ctrl+S** ile kaydet / Publish et.

`MapBuilder.luau` içinde düzeni değiştirirsen `MAP_VERSION`'ı 1 artır ve butona tekrar bas;
oyun eski veya eksik haritayı kabul etmez. Place'te harita yoksa oyun başlarken kendisi kurar.
Buton `Workspace.Plots`/`World` içeriğini ve üretim alanındaki Terrain'i yeniden kurar.
Mevcut üretim alanı merkezden X/Z yönünde yaklaşık 552 stud, Y yönünde -32…32 stud'dur;
bu hacimde elle düzenlenmiş Terrain korunmaz. Dışarıdaki Terrain, bağımsız modeller,
Baseplate ve SpawnLocation korunur. Şablon Baseplate/SpawnLocation oyuna engelse elle kaldır.
İşlem Studio geri alma kaydı gerektirir; kayıt açılamazsa haritayı değiştirmez.

- **Kayıt için:** Oyunu yayınla (File → Publish) ve Game Settings → Security →
  *Enable Studio Access to API Services* aç. Studio, canlı kayıttan ayrı `_Studio` store kullanır;
  yine de test için ayrı deneyim kullan. API/yükleme hatası normal oyuna geçirilmez.
- **API olmadan açıkça kayıtsız test:** Play'den önce Workspace'e Boolean
  `StudioNonPersistentData = true` attribute'u ekle. HUD kayıtsız test uyarısını sürekli gösterir.
  Kalıcı kayıt testinden önce attribute'u kaldır veya false yap. Bu seçenek canlı oyunda etkisizdir.
- **Max Players:** Haritada oyuncu başına bir ada var; yayında Game Settings → Places'te Max Players'ı `Config.MAP_PLOT_COUNT` (6) yap. Kapasite ada sayısından büyükse
  sunucu açılışta uyarır, ada kalmayan oyuncunun girişini reddeder. Lobi planı: [mimari](docs/LOBI_VE_ADA_MIMARISI.md).
- **Çok oyunculu test:** Test sekmesi → Clients and Servers → 2 oyuncu → Start.

### Play'de boş gökyüzünde kalma

Studio günlüklerinde `[Map] MaxPlayers=N; haritada yalnızca 6 ada var.` uyarısı, Max Players'ın ada sayısından
büyük olduğunu gösterir. Kod boş adaları kullanır, yalnızca ada kalmayan oyuncunun girişini reddeder
(`Boş ada yok` günlüğü). Yayında kapasite `Config.MAP_PLOT_COUNT` olmalıdır.

Rojo bağlantısı koptuğunda `Haritayı Kur` eski/eksik senkronize kodları çalıştırabilir.
Play'i durdur, Rojo'da Disconnect → Connect ile bu projeye yeniden bağlan ve sonra Play yap.
API kapalıysa yukarıdaki açık kayıtsız Studio testi seçeneğini kullan; bu durum kapasite
hatasından ayrıdır.

## Oynanış

1. Oyuncu meydanda doğar, boş bir adaya ışınlanır.
   Meydanda çeşme, bankler ve çiçeklikler vardır; satıcı NPC'ler yaklaşan oyuncuya bakar, el sallar ve kısa bir selam söyler. Tabelada adı yazar.
2. **Ücretsiz başlangıç:** Küçük Ahır, Başlangıç Ağılı, hayvansız başlangıç (`Config.STARTING_COW_COUNT`); ilk hayvanı (temaya göre inek/tavuk/ördek) tam alacak başlangıç parası (`Config.getStartingCash`).
2b. **İlk adımlar:** sol paneldeki hedef kartı yeni oyuncuyu üç adımda yönlendirir: ilk hayvanı al (Pazar düğmesi yanıp söner), parayı topla (yeşil platforma ışın çizgisi), ilk yükseltmeyi al. Durumdan türetilir; eski oyuncular atlar.
2c. **Yapım alanları:** satın alabildiğin ama henüz almadığın binaların yeri adada kazıklı, sarı şeritli bir yapım alanı olarak görünür ve tabelasında adı ile fiyatı yazar.
   Satın alınca alan kalkar, yerine bina kurulur.
3. Hayvanlar her saniye **depoya** para üretir. Adadaki **yeşil platforma** basınca para kasaya geçer.
   Depo dolarsa üretim durur → oyuncu geri gelip toplamalı (ya da Otomatik Toplayıcı almalı).
4. **Hayvan Pazarı:** Açık bölgelerindeki hayvanlar (tema ve açılan adalara göre: inek, tavuk, ördek, at, koyun, keçi, domuz, hamsi, levrek). Yavru doğarlar (%25 gelir) → Genç (%60) → Yetişkin (%100).
   Aynı türden aldıkça fiyat %18 artar.
4b. **Irk geliştirme:** Pazar'da sahip olduğun her hayvan türünün kartında ikinci düğme vardır. Her seviye o türün gelirini %8 artırır (en fazla Sv.10);
   maliyet her seviyede üstel büyür. Seviyeler çiftlik başınadır ve kayıtlıdır. Bu, yol haritası bittikten sonra da para harcama yoludur. Geliştirilmiş hayvanın üstünde kademe renginde (bronz, gümüş, altın, elmas) bir yıldız ve seviye rozeti görünür.
4c. **Yapı geliştirme:** Yükseltmeler penceresinde, açık bölgelerin (ahır, kümes, ağıl, kafes...) ve kurulu üretim tesislerinin altında "Yapı geliştirme" kartı çıkar. Her yapı 5
   seviyelidir ve her seviye yapının işlevine uygun bir fayda verir: bölgelerde **kapasite** (dolu bölgede açılır), **büyüme hızı**, **verim** ve **mevsim uyumu** (olumlu mevsim/hava
   etkisi büyür, olumsuzlar küçülür); tesislerde **üretim süresi**, **satış ödülü** ve **başlatma maliyeti**. Bazı seviyeler iki fayda birden verir (ör. kapasite + büyüme).
   Maliyet bölgedeki hayvanın ya da tesisin ödülünün değerine ve seviyeye bağlıdır. Seviyeler çiftlik başınadır ve kayıtlıdır.
4d. **Mevsim hedefi:** Ödüller penceresinde her mevsim (15 dk) yeni bir hedef vardır: bahar ve sonbaharda para kazan, yaz ve kışta yatırım yap
   (hayvan, yükseltme, ırk veya alan genişletme). Tamamlayınca ödülü al; mevsim değişince alınmamış hedef kaybolur. Ödül gelire göre ölçeklenir.
4e. **Gezgin tüccar (rastgele olay):** Her oyuncuya ayrı zamanlarda, yaklaşık 15 dakikalık dönemlerde ve 4 dakikalığına gelir. Geldiğinde bildirim çıkar ve
   Pazar penceresinin en üstünde, satın alınabilen pahalı hayvanlardan biri en fazla 3 adet, %30 indirimle sunulur. Her ziyarette bir kez alınabilir.
4f. **Altın hayvan (rastgele olay):** Her oyuncuya ayrı zamanlarda, yaklaşık 10 dakikalık dönemlerde ve 75 saniyeliğine, etkin çiftliğindeki yetişkin bir hayvan
   altın gibi parlar. Üstündeki **Topla** düğmesine basınca o hayvanın yaklaşık 2,5 dakikalık gelirini alırsın; her pencerede bir kez.
4h. **Envanter ve eşyalar:** Meydandaki **Usta Ömer**'den (Eşya Dükkânı) oyun parasıyla eşya alırsın; bir kez alınır, faydası kalıcıdır. **Envanter** (B) beş slotluktur:
   **Alet** (çekiç: tüm yükseltme maliyetlerinden %5-20 indirim), **Asa** (mevsim ya da hava değiştirme gücü: günde 1 / 3 / 5 kez ya da sınırsız, her kullanım arası kısa bekleme),
   **Muska** (depo, büyüme hızı ya da gelir bonusu; yalnızca biri takılır), **Başlık** ve **Sırt** (görünüm eşyaları, karakterde görünür). Slot başına bir eşya takılır; boş slota
   satın alınan eşya otomatik takılır. Asa ile seçilen mevsim tam süre (15 dk) **yalnızca sana** uygulanır: gelirin, gökyüzü/hava efektlerin ve HUD'un o mevsimi gösterir, süre bitince dünyanın
   doğal mevsimine dönersin. Dünya mevsimi ve havası herkes için aynı kalır. Hava asası senin havanı değiştirir (yalnızca mevsimde görülebilen türler, yaklaşık 4 dk).
   Şimdilik hiçbir eşya Robux ile satılmaz.
5. **Yol Haritası:** Oyuncu sırayı kendi seçer; sadece ön koşulu olanlar kilitlidir.
6. **Adalar:** Herhangi bir ada tabelasına ya da meydandaki "🧭 Adalar" tabelasına yaklaşıp **E** →
   meydana veya başka bir adaya ışınlan.
7. **Balık değiştirme:** Pazar'da bir hamsiyi yavru levreğe yükseltebilirsin; yeni levrek fiyatından
   hamsinin sabit başlangıç fiyatının %50'si düşülür. Kafes doluyken de çalışır.
8. **Yol haritası sonrası:** Tüm alanları yetişkin hayvanlarla doldurma ve 10 levreğe ulaşma
   ustalık hedefleri görünür. Tekrar eden ürün siparişlerinde yetişkin hayvanlar çevrimiçiyken
   üretim yapar; tamamlanan siparişi teslim edince para ve yeni sipariş alınır. Hayvan tüketilmez.

Çevrimdışı kazanç büyüme aşamalarını kullanır ve doğrudan kasaya eklenir: gelirin `Config.OFFLINE_EARNING_RATE` oranı, en çok
`Config.OFFLINE_MAX_HOURS` saat için; Pasif Gelir yükseltmesi oranı ve süreyi `Config.OFFLINE_UPGRADED_*` değerlerine çıkarır. Sınır depoya değil süreye bağlıdır.
Geçmiş hava kaydı tutulmadığından nötr hava/mevsim üzerinden hesaplanır. Otomatik Toplayıcı
yalnızca çevrimiçiyken kasaya aktarır.

Kısayollar: **P** = Pazar, **Y** = Yol Haritası, **U** = Yükseltmeler, **R** = Üretim. Alınabilecek bir şey olunca düğmede rozet çıkar.
Yükseltmeler penceresi açılabilir geliştirmeleri önce gösterir; kilitli olanlarda gerekenleri yazar,
alınanları listeden kaldırır. Pazar ve Yol Haritası gibi 330×430 boyutuyla sınırlıdır ve küçük
ekranlarda kullanılabilir alana sığar.

**Üretim:** Süt fabrikası, kuluçkahane, at eğitimi, peynirhane ve balık sevkiyatı süreli
partiler üretir. Kuluçkadaki civciv satılabilir veya boş kümese eklenebilir. Her tesiste
tek parti kaydedilir; süre çevrimdışında da ilerler.
Harita kodu değişince (`MAP_VERSION` artar) eklenti panelinden **Haritayı Kur** gerekir.
**Adalar / I** ekranında kendi uzman adalarını açabilir, **Git ve yönet** ile ada seçebilirsin.
Pazar, Yükseltmeler, Yol Haritası ve Üretim seçili adayı gösterir; para ortaktır, genel çiftlik bonusları yalnızca ilgili ana çiftlikte geçerlidir.
Diğer oyuncuların çiftlikleri bu adalardan ayrı, yalnızca ziyaret olarak listelenir.

**Birden fazla ana çiftlik:** Ada Yönetimi'nin üst kısmından boş bir **ana ada** satın alabilirsin.
Her ana çiftlik kendi ana adası ve bağlı üç küçük adasıyla ayrı ilerler; hayvan, yükseltme,
depo ve üretim kayıtları birbirine karışmaz. Yalnızca para ortaktır. Seçili olmayan çiftlikler
de kendi depo sınırları ve otomatik toplama yükseltmeleriyle gelir üretir.
İlave ana çiftlik fiyatları `Config.MAIN_FARM_PRICES` taban değerleridir ve yükseltmelerle aynı maliyet eğrisinden geçer;
üst sınır `Config.MAIN_FARM_LIMIT` çiftliktir.
Harita doluyken satın alma yapılmaz. Yeni oyunculara yer açılırken etkin olmayan çiftliklerin
fiziksel görünümü geçici olarak kaldırılabilir; kayıtları ve gelirleri korunur, seçildiğinde
oyuncunun kendi harita alanına geri yüklenir. [Ana çiftlik sistemi](docs/ANA_CIFTLIKLER.md).
Ayrıntılar: [Üretim ve uzman adalar](docs/URETIM_VE_UZMAN_ADALAR.md).
Sağ menü sütunundaki Ayarlar'da
grafik kalitesi (Otomatik/Düşük/Orta/Yüksek; hesaba kaydedilir) ve hareketi azaltma (yalnızca bu oturum) bulunur.

## Takımada ve Yol Haritası

Her oyuncunun kendi takımadası var: **ana ada** (ücretsiz) + arkasında köprüyle bağlı **3 uzman ada**.
Uzman adalar kilitliyken toprak renginde durur, tabelasında fiyatı ve özelliği yazar; oyuncu tabelaya
gidip **E** ile ya da Yol Haritası'ndan satın alır. Her ada yeni bir hayvan + kendine özel bir bonus getirir.

Ana adanın yerleşimi de temaya göre değişir: bahçe, ambar, değirmen, kovanlar, çiftlik evi ve meyve bahçesi farklı yuvalara oturur, kuyu iki yandan birindedir ve doğu kıyıda
temaya özel bir işaret yapısı vardır (papatya halkası ve korkuluk, lale tarhı, ayçiçeği tarlası, gül çardağı, çam öbeği, kiraz korusu).

Hangi üç küçük adanın geldiği **çiftlik numarasına (tema)** bağlıdır; her ana çiftlik de kendi hayvanıyla başlar:

| Çiftlik | Tema | Ana ada hayvanı | Küçük adalar |
|---|---|---|---|
| 1 | Klasik Çayır | İnek | Tavuk, At, Keçi |
| 2 | Yün ve Süt | Tavuk | Süt, Koyun, Keçi |
| 3 | Güneşli Tarla | Ördek | Süt, Tavuk, Domuz |
| 4 | Göl ve Hara | İnek | Ördek, At, Domuz |
| 5 | Dağ ve Orman | Tavuk | Süt, At, Domuz |
| 6 | Meyve ve Süt | Ördek | Süt, Koyun, Domuz |

Her ada yeni bir hayvan, kendine özel bir bonus, bir üretim tesisi ve bir eklenti alanı getirir.
Ada ve yükseltme listesi, fiyatlar ve ön koşullar **yalnızca** `src/shared/Config/` içindedir; bu dosyada kopyalanmaz.

**Tempo hedefleri** (ideal oyuncu, `python scripts/simulate-economy.py --farm 1..6`): ilk hayvan saniyeler içinde,
ilk küçük ada ~10 dk, ikincisi ~30 dk, üçüncüsü ~1 saat, tüm yükseltmeler ~3 saat. Yazılı yükseltme fiyatları taban
fiyattır; `UPGRADE_COST_BASE`/`UPGRADE_COST_EXPONENT` eğrisiyle büyütülür, aynı türden her yeni hayvan `ANIMAL_PRICE_GROWTH` kadar pahalıdır.
Denge değiştirirsen önce simülasyonu çalıştır; `--cost-exp` ve `--price-growth` bayraklarıyla Config'e dokunmadan dene.

**Deniz** dalı adalarla paralel ilerler: ana adanın önündeki iskeleden gidilen yüzen balık kafesinde
hamsi ve levrek suyun altında yüzer. Denizdeki diğer balıklar sadece süs (`FishLife`).

Tüm dengeler `src/shared/Config/` içinde (`FARM_ISLANDS`, `UPGRADES`, `ANIMALS`, `ZONES`).
Eski kayıtlar otomatik taşınır (`LEGACY_UPGRADES`); artık yaşayamayacağı bölgedeki hayvanlar
uygun yere taşınır, yer yoksa ilk fiyatı iade edilir.

## Mevsimler ve hava

### Yönetici paneli

Yetki yalnızca **Geo_Geyo / UserId 11641916529** hesabındadır; sunucu
`src/server/Modules/AdminPolicy.luau` içindeki sabit kimliği kontrol eder.
Kullanıcı adı, istemcinin değiştirdiği `IsAdmin` attribute'u veya Studio'da bulunmak
yetki sağlamaz. Studio'nun sentetik çoklu test oyuncuları da otomatik yönetici olmaz.

- Masaüstü: **Yönetici** düğmesi veya **F8**.
- Sağ menü sütunundaki **Yönetici** düğmesi (yalnızca yetkili hesapta görünür).
- Para: kendi bakiyeni belirli bir tutara ayarla veya ekleme yap. Kalıcı oturumda bu değişiklik
  kaydedilir; `StudioNonPersistentData` test modunda saklanmaz.
- Hava/mevsim: yalnızca bulunduğun sunucuyu etkiler. Seçim otomatik değişimi durdurur;
  ilgili **Otomatik** düğmesi doğal döngüye döndürür. Sabit mevsim kendi süresini tekrarlar.
- Studio'daki F7 hava kısayolu da aynı yönetici kontrolüne tabidir; panelden otomatiğe dönülebilir.
- Test araçları (yalnızca kendi profilin): hayvanları büyüt, seçili adadaki her şeyi aç, slotları doldur ve **rastgele olaylar**: gezgin tüccarı çağır,
  altın hayvanı çağır, mevsim hedefini tamamla, olayları sıfırla. Olay işaretleri kaydedilmez (çalışma anı alanı `adminForce`).

Sunucu her istekte yetki, miktar, durum, hız ve istek kimliğini doğrular. Başka oyuncunun
parasını değiştiren veya istemciden keyfi kod çalıştıran bir komut bulunmaz.

### Mevsim döngüsü

Mevsimler 15 dakikada bir sırayla döner (tüm sunucularda aynı anda; tam döngü 1 saat).
Sonradan katılan oyuncu mevcut mevsimin kalan süresinden devam eder. Hava her sunucuda mevsime uygun
olarak 2,5–4,5 dakikada bir değişir. Etkiler gelire eklenir; mevsim panelinde ve Pazar kartlarında görünür.
Sol paneldeki küçük hava kartı ilerleme çubuğu, kalan dakika/saniye ve hava durumunu gösterir;
geniş ekranda sıradaki mevsim de görünür. Bildirimler ayrı alandadır.

HUD yerleşimi: sol ortada para/depo/mevsim/hedef paneli (sola kayarak kapanır); üst ortada menü çubuğu (Pazar, Yükseltmeler, Yol Haritası, Üretim, Adalar),
sağ ortada menü sütunu (Envanter, Ödüller, Adama Dön, Ayarlar, yetkili hesapta Yönetici). Karolar kademeli açılır. Ayrıntı: `AGENTS.md` "Arayüz (UI) standardı".

| Mevsim | Artış | Düşüş | Olası hava |
|---|---|---|---|
| 🌸 İlkbahar | İnek +%20, Tavuk +%25 | — | Güneşli, Bulutlu, Yağmurlu |
| ☀️ Yaz | Hamsi/Levrek +%30, At +%15 | İnek -%10 | Güneşli, Bulutlu, Fırtına |
| 🍂 Sonbahar | At +%25, Keçi +%20 | Tavuk -%10 | Bulutlu, Yağmurlu, Fırtına, Güneşli |
| ❄️ Kış | Keçi +%30, İnek +%15 | Tavuk -%20, Balıklar -%20 | Karlı, Bulutlu, Güneşli |

Hava: Yağmurlu (İnek/At/Keçi +%10), Fırtına (Balıklar -%30, Tavuk -%10), Karlı (Keçi +%10, Tavuk -%10).
Görsel olarak: yağmur/kar, fırtınada şimşek, bulut yoğunluğu, ışık tonu, mevsime göre çimen ve yaprak rengi,
gökyüzünde kuş ve martı sürüleri. Ayarlar: `Config.SEASONS`, `Config.WEATHER`.
Sonbaharda yapraklar renklenip dökülür, kışın yaprak döken ağaçlar çıplak kalır; çamlar yeşil
örtüsünü korur. Kar ve kıyı buzları kademeli oluşur, kışın son %30'unda erimeye başlar ve
ilkbaharın başında kaybolur. İlkbaharda yapraklar yeniden çıkar ve çiçeklenme görülür.
Bu değişimler yerel görseldir; buzlar yürünebilir zemin oluşturmaz ve yüzmeyi engellemez.
Yakındaki efektler kaliteye göre sınırlanır; hareketi azaltma uçuşan yaprakları kapatır.
**Test:** Studio'da oynarken **F7** havayı sırayla değiştirir (Güneşli → Bulutlu → Yağmurlu → Fırtına → Karlı).
Yayınlanmış oyunda çalışmaz.

Oyunda ölüm yok: suya düşülürse yüzülür, dipte kum taban ve altında görünmez güvenlik zemini var;
bir şekilde haritanın altına düşülürse karakter kendi adasına ışınlanır.

## Görseller / Asset'ler

Hepsi kodla basit parçalardan yapılır, ama kendi modellerini koyabilirsin
(Studio'da `ServerStorage.Assets` altına, ya da `assets/` klasörüne `.rbxm` olarak):

- `Assets/Animals/cow`, `horse`, `chicken` → hayvan modelleri (Model, önü -Z yönüne baksın)
- `Assets/Buildings/<upgrade id>` → ör. `silo`, `milk_machine`, `auto_collector`, `egg_factory`, `golden_horseshoe`

Model yoksa kodla yapılan yedek görünüm kullanılır. Hayvan ve bina klonlarındaki Script,
LocalScript ve ModuleScript'ler dünyaya eklenmeden temizlenir; kaynak şablon değiştirilmez.
Eski `ReplicatedStorage.Assets` konumu geçiş için desteklenir, yeni modelleri ServerStorage'a koy.

## Yapı

```
src/
  server/
    Modules/        → saf sunucu mantığı (kayıt kodlama, kilit, hız sınırı)
    World/          → statik harita: MapBuilder, WorldDecor, HomeBuildings, HubNpcs...
    Presentation/   → oyuncu durumundan dünyaya çizim (hayvan, bina, bölge görselleri)
    Services/       → oyun mantığı: PlayerData, Plot, Economy, Animal, Upgrade, Production, Order...
  client/
    Core/           → ClientState, PurchaseController, Localizer, Sfx
    Effects/        → gün-gece, hava, mevsim, su altı, grafik kalitesi, kuşlar/balıklar
    Ui/             → UiKit, FarmHud, Hud/* pencereleri, ayarlar, yönetici paneli
    Interaction/    → satın alma platformları, toplama, NPC, ada geçişi
  shared/Config            → TÜM oyun dengesi (fiyatlar, gelirler, yol haritası)
  shared/Modules/FarmMath  → sunucu ve client'ın ortak hesapları
```

Ayrıntı ve bağımlılık kuralları: [docs/MIMARI.md](docs/MIMARI.md).

AI araçları için kurallar: `AGENTS.md`

## Doğrulama ve geliştirme durumu

Kod mimarisi ve klasör kuralları: [docs/MIMARI.md](docs/MIMARI.md). Eski inceleme ve düzeltme kayıtları git geçmişindedir.

PowerShell'de tam yerel kontrol:

```powershell
./scripts/verify.ps1 -Python python -LuauDirectory .tools/luau
```

Rokit araçlarına ek olarak resmi [Luau 0.740](https://github.com/luau-lang/luau/releases/tag/0.740)
paketindeki `luau`, `luau-compile`, `luau-analyze` gereklidir. Paketini `.tools/luau` altına aç
veya `-LuauDirectory` ile başka konum ver. Araçlar repoya eklenmez.
Kontrol; biçim, lint, kaynak sözdizimi derlemesi, veri/ekonomi/sipariş ve taklit servis regresyonları,
üç saf modülün tür analizi ve oyun/eklenti/test place derlemelerini çalıştırır.
Bu, tüm Roblox kodunun tür analizinin veya gerçek Studio testinin yerine geçmez.
GitHub Actions yapılandırması da aynı kontrolleri içerir; uzak repo üzerinde henüz çalıştırılmadı.

Harita testleri ana place'te, eklenti panelindeki **Haritayı Doğrula** düğmesiyle çalışır (Studio düzenleme modunda; Command Bar gerekmez).
Saf testler ayrı test place'inde de çalıştırılabilir: `rojo build test.project.json -o .test-build/tests.rbxlx` dosyasını Studio'da aç, Play'e bas.
Eski yöntem (Command Bar, test place'inde düzenleme modunda) hâlâ geçerlidir:

```luau
require(game:GetService("ServerScriptService").Server.World.MapBuilder).ensure()
require(game:GetService("ServerScriptService").Tests["world.spec"])()
require(game:GetService("ServerScriptService").Tests["map-structure.spec"])()
```

Dünya testi geçici Collector/PlotId/MapVersion değişikliklerini geri alır.

Sunucu çalışma anında `ServerStorage.Diagnostics` attribute'ları profil yükleme, kayıt denemesi,
hata ve sipariş sayılarını tutar. Bunlar sunucu ömrüyle sınırlıdır; harici analitik sistemi değildir.
