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
2. Studio → **Plugins** sekmesi → **Island Farm Tycoon → Haritayı Kur**. (Ctrl+Z ile geri alınır.)
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
- **Max Players:** Bu place oyuncuya özel ada haritasıdır; yayında Game Settings → Places'te 1 yap. Lobi ayrı place olacak ([mimari](docs/LOBI_VE_ADA_MIMARISI.md)). Studio'da birden fazla oyuncu denemek istersen kapasite 1'den büyükken uyarı çıkar, bu normaldir.
- **Çok oyunculu test:** Test sekmesi → Clients and Servers → 2 oyuncu → Start.

### Play'de boş gökyüzünde kalma

Studio günlüklerinde `MaxPlayers ada sayısından büyük` hatası görünüyorsa eski açılış kodu
çalışıyordur. Güncel kod kapasite farkında uyarır; boş adaları kullanır, yalnızca ada kalmayan
oyuncunun girişini reddeder. Yayında bu place'in kapasitesi 1'dir (oyuncuya özel harita).

Rojo bağlantısı koptuğunda `Haritayı Kur` eski/eksik senkronize kodları çalıştırabilir.
Play'i durdur, Rojo'da Disconnect → Connect ile bu projeye yeniden bağlan ve sonra Play yap.
API kapalıysa yukarıdaki açık kayıtsız Studio testi seçeneğini kullan; bu durum kapasite
hatasından ayrıdır.

## Oynanış

1. Oyuncu meydanda doğar, boş bir adaya ışınlanır. Tabelada adı yazar.
2. **Ücretsiz başlangıç:** Küçük Ahır, Başlangıç Ağılı, 2 yetişkin ana ada hayvanı (temaya göre inek/tavuk/ördek), $100.
2b. **İlk adımlar:** sol paneldeki hedef kartı yeni oyuncuyu üç adımda yönlendirir: ilk hayvanı al (Pazar düğmesi yanıp söner), parayı topla (yeşil platforma ışın çizgisi), ilk yükseltmeyi al. Durumdan türetilir; eski oyuncular atlar.
3. Hayvanlar her saniye **depoya** para üretir. Adadaki **yeşil platforma** basınca para kasaya geçer.
   Depo dolarsa üretim durur → oyuncu geri gelip toplamalı (ya da Otomatik Toplayıcı almalı).
4. **Hayvan Pazarı:** İnek, tavuk, at, keçi, hamsi ve levrek. Yavru doğarlar (%25 gelir) → Genç (%60) → Yetişkin (%100).
   Aynı türden aldıkça fiyat %18 artar.
5. **Yol Haritası:** Oyuncu sırayı kendi seçer; sadece ön koşulu olanlar kilitlidir.
6. **Adalar:** Herhangi bir ada tabelasına ya da meydandaki "🧭 Adalar" tabelasına yaklaşıp **E** →
   meydana veya başka bir adaya ışınlan.
7. **Balık değiştirme:** Pazar'da bir hamsiyi yavru levreğe yükseltebilirsin; yeni levrek fiyatından
   hamsinin sabit başlangıç fiyatının %50'si düşülür. Kafes doluyken de çalışır.
8. **Yol haritası sonrası:** Tüm alanları yetişkin hayvanlarla doldurma ve 10 levreğe ulaşma
   ustalık hedefleri görünür. Tekrar eden ürün siparişlerinde yetişkin hayvanlar çevrimiçiyken
   üretim yapar; tamamlanan siparişi teslim edince para ve yeni sipariş alınır. Hayvan tüketilmez.

Çevrimdışı kazanç en fazla 8 saatlik süreyi ve büyüme aşamalarını kullanır; doğrudan kasaya eklenir ve üst sınırı
depo kapasitesinin `OFFLINE_STORAGE_MULTIPLIER` katıdır.
Geçmiş hava kaydı tutulmadığından nötr hava/mevsim üzerinden hesaplanır. Otomatik Toplayıcı
yalnızca çevrimiçiyken kasaya aktarır; 8 saat sınırsız veya depo üstü kazanç vaadi değildir.

Kısayollar: **P** = Pazar, **Y** = Yol Haritası, **U** = Yükseltmeler, **R** = Üretim. Alınabilecek bir şey olunca düğmede rozet çıkar.
Yükseltmeler penceresi açılabilir geliştirmeleri önce gösterir; kilitli olanlarda gerekenleri yazar,
alınanları listeden kaldırır. Pazar ve Yol Haritası gibi 330×430 boyutuyla sınırlıdır ve küçük
ekranlarda kullanılabilir alana sığar. Dar ekranlarda Yol Haritası, Çiftliğim menüsündedir.

**Üretim:** Süt fabrikası, kuluçkahane, at eğitimi, peynirhane ve balık sevkiyatı süreli
partiler üretir. Kuluçkadaki civciv satılabilir veya boş kümese eklenebilir. Her tesiste
tek parti kaydedilir; süre çevrimdışında da ilerler. Dar ekranda Üretim, Çiftliğim içindedir.
Yeni tesisler ve deniz tabanına bağlı iskeleler için harita sürümü 13'te **Haritayı Kur** gerekir.
**Adalar / I** ekranında kendi uzman adalarını açabilir, **Git ve yönet** ile ada seçebilirsin.
Pazar, Yükseltmeler, Yol Haritası ve Üretim seçili adayı gösterir; para ortaktır, genel çiftlik bonusları yalnızca ilgili ana çiftlikte geçerlidir.
Diğer oyuncuların çiftlikleri bu adalardan ayrı, yalnızca ziyaret olarak listelenir.

**Birden fazla ana çiftlik:** Ada Yönetimi'nin üst kısmından boş bir **ana ada** satın alabilirsin.
Her ana çiftlik kendi ana adası ve bağlı üç küçük adasıyla ayrı ilerler; hayvan, yükseltme,
depo ve üretim kayıtları birbirine karışmaz. Yalnızca para ortaktır. Seçili olmayan çiftlikler
de kendi depo sınırları ve otomatik toplama yükseltmeleriyle gelir üretir.
İlave ana çiftlik fiyatları: 5.000 / 12.000 / 25.000 / 50.000 / 100.000; üst sınır 6 çiftliktir.
Harita doluyken satın alma yapılmaz. Yeni oyunculara yer açılırken etkin olmayan çiftliklerin
fiziksel görünümü geçici olarak kaldırılabilir; kayıtları ve gelirleri korunur, seçildiğinde
oyuncunun kendi harita alanına geri yüklenir. [Ana çiftlik sistemi](docs/ANA_CIFTLIKLER.md).
Ayrıntılar: [Üretim ve uzman adalar](docs/URETIM_VE_UZMAN_ADALAR.md).
Dar ekranlarda hedefler, eve dönüş ve ayarlar **Çiftliğim** menüsündedir. Ayarlar'da düşük/orta/yüksek
efekt kalitesi ve hareketi azaltma bulunur; tercihler bu oturum için geçerlidir.

## Takımada ve Yol Haritası

Her oyuncunun kendi takımadası var: **ana ada** (ücretsiz) + arkasında köprüyle bağlı **3 uzman ada**.
Uzman adalar kilitliyken toprak renginde durur, tabelasında fiyatı ve özelliği yazar; oyuncu tabelaya
gidip **E** ile ya da Yol Haritası'ndan satın alır. Her ada yeni bir hayvan + kendine özel bir bonus getirir.

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
Ada ve yükseltme listesi, fiyatlar ve ön koşullar **yalnızca** `src/shared/Config.luau` içindedir; bu dosyada kopyalanmaz.

**Tempo hedefleri** (ideal oyuncu, `python scripts/simulate-economy.py --farm 1..6`): ilk hayvan saniyeler içinde,
ilk küçük ada ~10 dk, ikincisi ~30 dk, üçüncüsü ~1 saat, tüm yükseltmeler ~3 saat. Yazılı yükseltme fiyatları taban
fiyattır; `UPGRADE_COST_BASE`/`UPGRADE_COST_EXPONENT` eğrisiyle büyütülür, aynı türden her yeni hayvan `ANIMAL_PRICE_GROWTH` kadar pahalıdır.
Denge değiştirirsen önce simülasyonu çalıştır; `--cost-exp` ve `--price-growth` bayraklarıyla Config'e dokunmadan dene.

**Deniz** dalı adalarla paralel ilerler: ana adanın önündeki iskeleden gidilen yüzen balık kafesinde
hamsi ve levrek suyun altında yüzer. Denizdeki diğer balıklar sadece süs (`FishLife`).

Tüm dengeler `src/shared/Config.luau` içinde (`FARM_ISLANDS`, `UPGRADES`, `ANIMALS`, `ZONES`).
Eski kayıtlar otomatik taşınır (`LEGACY_UPGRADES`); artık yaşayamayacağı bölgedeki hayvanlar
uygun yere taşınır, yer yoksa ilk fiyatı iade edilir.

## Mevsimler ve hava

### Yönetici paneli

Yetki yalnızca **Geo_Geyo / UserId 11641916529** hesabındadır; sunucu
`src/server/Modules/AdminPolicy.luau` içindeki sabit kimliği kontrol eder.
Kullanıcı adı, istemcinin değiştirdiği `IsAdmin` attribute'u veya Studio'da bulunmak
yetki sağlamaz. Studio'nun sentetik çoklu test oyuncuları da otomatik yönetici olmaz.

- Masaüstü: **Yönetici** düğmesi veya **F8**.
- Mobil/dar ekran: **Çiftliğim → Yönetici**.
- Para: kendi bakiyeni belirli bir tutara ayarla veya ekleme yap. Kalıcı oturumda bu değişiklik
  kaydedilir; `StudioNonPersistentData` test modunda saklanmaz.
- Hava/mevsim: yalnızca bulunduğun sunucuyu etkiler. Seçim otomatik değişimi durdurur;
  ilgili **Otomatik** düğmesi doğal döngüye döndürür. Sabit mevsim kendi süresini tekrarlar.
- Studio'daki F7 hava kısayolu da aynı yönetici kontrolüne tabidir; panelden otomatiğe dönülebilir.

Sunucu her istekte yetki, miktar, durum, hız ve istek kimliğini doğrular. Başka oyuncunun
parasını değiştiren veya istemciden keyfi kod çalıştıran bir komut bulunmaz.

### Mevsim döngüsü

Mevsimler 15 dakikada bir sırayla döner (tüm sunucularda aynı anda; tam döngü 1 saat).
Sonradan katılan oyuncu mevcut mevsimin kalan süresinden devam eder. Hava her sunucuda mevsime uygun
olarak 2,5–4,5 dakikada bir değişir. Etkiler gelire eklenir; mevsim panelinde ve Pazar kartlarında görünür.
Sol paneldeki küçük hava kartı ilerleme çubuğu, kalan dakika/saniye ve hava durumunu gösterir;
geniş ekranda sıradaki mevsim de görünür. Bildirimler ayrı alandadır.

HUD yerleşimi: solda para/depo/mevsim/hedef paneli; menü geniş ekranda alt ortada yatay karo çubuğu,
dar ekranda (genişlik < 900 veya yükseklik < 560) sağ kenarda üç karoluk sütun. Ahır ve sıradaki ada
bilgisi ile dar ekranda taşınan menü karoları "Çiftliğim" penceresindedir.

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
  server/Services/
    PlayerDataService   → yükleme/kaydetme (DataStore), leaderstats
    MapBuilder          → deniz, meydan, köprüler, adalar
    PlotService         → ada atama/sıfırlama, ışınlama, bölge kilitleri
    UpgradeService      → yol haritası satın alma
    AnimalService       → hayvan satın alma + büyüme
    EconomyService      → gelir, depo, toplama platformu
    OrderService        → tekrar eden üretim siparişleri
    *VisualService      → ahır, hayvan ve bina görselleri
  client/FarmHud        → arayüz (panel, Pazar, Yol Haritası, bildirimler)
  shared/Config         → TÜM oyun dengesi (fiyatlar, gelirler, yol haritası)
  shared/Modules/FarmMath → sunucu ve client'ın ortak hesapları
```

AI araçları için kurallar: `AGENTS.md`

## Doğrulama ve geliştirme durumu

`docs/PROJE_INCELEME_VE_GELISTIRME_PLANI.md` ilk incelemeyi,
`docs/DUZELTME_DURUMU.md` uygulanan düzeltmeleri ve kalan kabul kontrollerini içerir.

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

Ayrı test place'i: `rojo build test.project.json -o .test-build/tests.rbxlx`.
Bu place'i Studio'da açıp Play ile saf testleri çalıştır. Dünya testi için aynı place'te
**düzenleme modunda**, Command Bar'da önce test haritasını kur, sonra testi çağır:

```luau
require(game:GetService("ServerScriptService").Server.Services.MapBuilder).ensure()
require(game:GetService("ServerScriptService").Tests["world.spec"])()
require(game:GetService("ServerScriptService").Tests["map-structure.spec"])()
```

Bu komutları ayrı test place'inde kullan. Dünya testi geçici Collector/PlotId/MapVersion
değişikliklerini geri alır. Studio dünya testi bu değişiklik paketi sırasında çalıştırılmadı.

Sunucu çalışma anında `ServerStorage.Diagnostics` attribute'ları profil yükleme, kayıt denemesi,
hata ve sipariş sayılarını tutar. Bunlar sunucu ömrüyle sınırlıdır; harici analitik sistemi değildir.
