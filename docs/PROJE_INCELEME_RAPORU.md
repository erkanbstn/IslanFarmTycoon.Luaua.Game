# Proje inceleme ve iyileştirme raporu

3 Ekim 2026 tarihinde başlayan inceleme, doğruluk, kararlılık, performans ve bakım kolaylığına odaklanır. Güvenli düzeltmeler kaynak kodda ve regresyon testlerinde uygulanır. Çalışma başlangıcında `git status --short` temizdi; kullanıcı değişikliği bulunmadı. İnceleme sırasında commit ve merge yapılmadı; kullanıcı sonradan yerel main ile birleştirmeyi istedi. Push, yayınlama ve canlı veri değişikliği yapılmadı.

## Mimari ve çalışma süreci

Oyun Luau ile yazılır; Rojo 7.4.4 dosyaları Roblox yürütme alanlarına eşler. Sunucu giriş noktası `src/server/init.server.luau`, ilk yükleme `src/first`, istemci başlangıcı `src/client/init.client.luau` ve `Core/ClientBootstrap.client.luau` dosyalarıdır. Diğer `.client.luau` dosyaları kendi dinleyicilerini başlatır. StyLua 2.0.2 biçimlendirme, Selene 0.28.0 lint, Luau 0.740 derleme ve saf modül testlerinde kullanılır.

Sunucu Modules → World → Presentation → Services katmanlarından oluşur. İstemci Core → Effects → Ui → Interaction yönünde bağlanır. Ortak Config dengeyi, FarmMath hesapları, GameTypes kayıt tiplerini, Remotes ağ sözleşmesini taşır. İstemci isteğini sunucu doğrular, hesaplar ve kaydı değiştirir; durum paketi ClientState ve UI'yi, PlotService dünya görsellerini günceller. DataStore erişimi SaveStore ile sınırlıdır; PlayerDataService oturum ve kayıt arayüzüdür. Modeller `assets` ve `client-assets`, ışık değerleri `Lighting.Presets` üzerinden gelir.

`scripts/verify.ps1` biçim, lint, derleme, saf Luau testleri, ekonomi simülasyonları, çeviri, rehber, model, mimari, tip analizi ve üç Rojo derlemesini topluca çalıştırır. Gerçek Studio dünyası, çok oyunculu davranış, DataStore kesintisi ve cihaz FPS ölçümleri ayrı doğrulama gerektirir.

## İncelenen alanlar

Başlangıç, Remote doğrulama ve yanıtları, SaveStore/PlayerDataService oturum ve kayıt yolları, MonetizationService geçit ve makbuz işlemleri, TransferService, ekonomi/üretim/sipariş/hayvan görev mantığı incelendi. İstemcide yerelleştirme, durum paketleri, streaming ile gelen görev işaretleri ve efekt yaşam döngüsü tarandı. Dünya tarafında ThemePatch, VisualWorkBudget, ModelAssets, DecorReveal, ShoreIceService ve çiftlik geçiş/sahiplik korumaları gözden geçirildi. Asset, çeviri, mimari, derleme ve ekonomi bütünlüğü otomatik denetimle kapsandı.

Bu kapsam tüm dosyaların her satırının veya gerçek Roblox çalışma zamanının eksiksiz denetlendiği anlamına gelmez. Bağımlılık yükseltmesi veya harita yerleşim değişikliği yapılmadı. İkinci aşamada aktarım protokolü değiştirildi ve uyumlu opsiyonel hesap günlüğü eklendi; kayıt sürümü artırılmadı, eski ilerleme korunur.

## Başlangıç durumu

Başlangıç toplu kontrolünde StyLua, mevcut `tests/visual-identity.spec.luau` biçimi nedeniyle başarısız oldu; bu dosya yalnızca biçimlendirildi. Tip analizi PATH üzerindeki Rokit Rojo başlatıcısının sourcemap üretim hatası nedeniyle çalışamadı. Başlangıç denetimi sürerken ajanlar değişikliklere başladığı için geç çalışan adımlar değişmiş ağacı görmüş olabilir; erken biçim hatası ve değişmemiş Rojo çözümleme hatası başlangıca aittir. Log `.test-build/audit-baseline.log` içindedir.

Tip aracının sonradan bildirdiği yeni iterator tip hatası yeni Monetization düzeltmesine aitti; açık tablo tipiyle giderildi. Tip tabanı genişletilmedi. Başlangıç ve değişiklik kaynakları ayrıştırılmadan sonuçlar başlangıç başarısı olarak sunulmadı.

## Giderilen sorunlar

| Öncelik | Kanıtlanan sorun | Uygulanan değişiklik ve doğrulama |
|---|---|---|
| Yüksek | Tam durum paketi beklerken ekonomik değişiklik kayıt revizyonunu artırmıyordu; devam eden eski snapshot yazımı yeni değişikliği temiz sayabiliyordu. | PlayerDataService revizyonu paket birleştirme kontrolünden önce artırır. Yield eden kayıt testi, eski snapshot sonrası DataDirty'nin açık kalmasını ve sonraki kaydın yeni parayı yazmasını doğrular. Ağ paketi sayısı artmaz. |
| Yüksek | Marketplace sorgusu sürerken satın alınan geçit, sorgunun eski false yanıtıyla silinebiliyordu. Eski sorgu başka profil nesnesine de yazabiliyordu. | MonetizationService başlangıç sahipliğini klonlar, aynı oturumu yeniden kontrol eder ve sorgu sırasında yeni kazanılmış sahipliği korur. Satın alma yarışı ve profil değişimi testleri eklendi. Maliyet küçük sahiplik tablosunun kopyasıdır. |
| Yüksek | Üretim veya eklenti görevindeki balık değiştirilebiliyor, işteki hayvan kayıttan çıkarılabiliyordu. | AnimalService ve istemcinin kullandığı FarmMath yardımcısı aktif görevi reddeder; biten göreve izin verir. Nakit, hayvan ve görev korunumu ile bitiş sonrası değişim testi eklendi. Bölge izni ortak zoneAllows üzerinden sorulur. |
| Orta | Sipariş teslim Remote'u hız sınırını aşan her yeni kimliğe yanıt gönderiyordu. | ContractService ortak RequestGuard.reply kullanır. Aynı anda 100 yeni isteğin yalnızca bir throttle yanıtı üretmesi ve kaydı değiştirmemesi doğrulandı. Normal sonuç sözleşmesi korunur. |
| Orta | Dünyadaki ProximityPrompt ActionText/ObjectText alanları yerelleştirme izleyicisine alınmıyordu. GUI yeniden parent edildiğinde dinleyiciler çoğalıyordu. | Localizer başlangıçta ve streaming ile gelen promptları izler; dünya GUI kökü bir kez izlenir. Metin/dil değişimi ve 100 yeniden parent olayında tek bağlantı test edildi. Yeni oyuncu metni eklenmedi. |
| Orta | JobAnchor bekleyen bağlantı tag kaldırılınca açık kalıyor; geç gelen anchor sahipsiz GUI oluşturabiliyordu. | JobProgress bekleyen bağlantıları kayıt altında tutar, tag kaldırmada ve script temizliğinde koparır. Model Destroying bağlantısı da entry temizliğinde koparılır. 100 takip döngüsü ve geç anchor testi açık bağlantı bırakmadı. |
| Orta | Yetişkin sayacı yalnız sayı için hayvan listesi oluşturup sıralıyordu. | FarmMath/Production ortak filtreyle doğrudan sayar. Hayvan seçimi yolundaki en yaşlıdan başlayan sıralama korunur. Aktif/kendi/başka/bitmiş görevler, eski stage alanı, kapalı bölge ve tür filtreleri test edildi. |
| Orta | Tip analizörü tanı üretmeden başarısız olduğunda boş bulgu listesi başarılı sayılabiliyordu. --update yeni hataları tabana ekleyebiliyordu. | Araç hatası başarısız sonuç verir; --update yalnızca tabanı küçültür. Sekiz Python testi araç hatasını, geçerli hata çıktısını, temiz sonucu, taban artışını ve Rojo seçimini kapsar. |
| Orta | Tip analizinin Rojo seçimi, verify.ps1'in sabit sürüm seçimiyle aynı değildi. | check-types.py önce rokit.toml içindeki kurulu sabit Rojo'yu kullanır. Kısıtlı ortamda başarısız olan shim atlanır. PATH yalnız sabit kurulum yoksa yedektir. |
| Düşük | README ve AnimalVisualService açıklamaları olmayan kod tabanlı model yedeğini anlatıyordu. | Açıklamalar gerçek model sözleşmesiyle hizalandı. Daha önce ayrı duran görsel kimlik testi ve yeni tip aracı testleri toplu verify sürecine eklendi. |

## Performans ve kaynak ölçümleri

Üretim sayacı gerçek eski/yeni kaynakları aynı Luau CLI ile çalıştırılarak ölçüldü. Sentetik yük: başlangıç bölgesinde 1000 yetişkin inek, ters UID sırası, yükseltme yok, sabit now=100000, packed_milk tarifi; örnek başına 1000 sayaç çağrısı, beş örnek, RNG yok. Her örnekte checksum 1.000.000 kaldı.

| Kaynak | Beş örnek saniye | Medyan saniye |
|---|---|---|
| Önce | 0.432808, 0.433329, 0.428875, 0.433211, 0.429219 | 0.432808 |
| Sonra | 0.137397, 0.122734, 0.123921, 0.127647, 0.139709 | 0.127647 |

Medyan süre yaklaşık %70,5 azaldı. Sayaç yolu sonuç listesi ayırmaz ve sıralamaz; O(n log n) sıralama maliyeti kaldırıldı. Maliyet ortak bir filtre fonksiyonu ve aynı çağrı içi büyüme hızı önbelleğidir. Bu stres mikro ölçümüdür; normal çiftlik kapasitesini veya Studio FPS kazancını temsil etmez.

Kaynak snapshotları ve komutlar `.test-build/audit-production-benchmark/results.txt`, `before.luau`, `after.luau` içindedir. `.test-build` git tarafından izlenmez; sonuç sayıları bu kalıcı rapora aktarılmıştır. Bağlantı ölçümlerinde JobProgress 100 döngüden sonra sıfır bekleyen bağlantı, Localizer 100 yeniden parent olayında tek GUI dinleyicisi tuttu. Gerçek bellek profili alınmadı.

## Birinci aşamanın doğrulaması

Hedefli saf Luau paketi 35 spec grubuyla geçti. Yeni Localizer/JobProgress testleri HEAD kaynaklarda başarısız, değiştirilmiş gerçek kaynakta başarılı oldu. Sipariş spamı ve görevdeki balık testi de HEAD üzerinde gerçek hatayı yakaladı; kanıt dosyaları benchmark klasöründe tutuldu. Test beklentileri gevşetilmedi.

Sekiz tip aracı Python testi, ayrı görsel kimlik testi, StyLua ve tip analizi hedefli olarak geçti. Tip analizinde yeni bulgu yok; 230 mevcut bulgu raporlanıyor, taban genişletilmedi. Bu sonuç bütün mevcut tip bulgularının giderildiği anlamına gelmez. `git diff --check` temiz.

Son toplu regresyon `powershell -ExecutionPolicy Bypass -File scripts/verify.ps1 -RequireTypes` ile exit 0 döndürdü; atlanan adım yok. StyLua, Selene (0 hata/uyarı), Luau derleme, 35 saf Luau spec grubu, görsel kimlik testi, sekiz Python testi, ekonomi duman/değer denetimi, ideal/casual/idle altı çiftlik tamamlama simülasyonu, çeviri kapsamı, rehber/model/mimari kontrolleri, saf yardımcı ve Roblox tip analizi, oyun/eklenti/test Rojo derlemeleri geçti. Model denetimi 745 beklenen görünümde eksik/bozuk dosya bulmadı. Sonuç logu `.test-build/audit-final.log` içindedir.

## İkinci aşama: optimizasyon dalı ve alt ajanlar

Kullanıcı isteğiyle `main` (`a8c15a17ece6c90aef8baf850c29d0c8b84f38d9`) üzerinden `codex/optimizasyon` açıldı; ilk aşamanın çalışma ağacı korundu. Kalıcı kayıt, istemci efekt/tip ve model doğrulama işleri bağımsız alt ajanlara ayrıldı; kaynak değişiklikleri ve testler aynı dalda bütünleştirildi. Commit, push, merge ve yayın yapılmadı.

| Sorun | Uygulanan çözüm ve kanıt | Maliyet / sınır |
|---|---|---|
| İki oyuncunun ayrı kayıt yazımları arasında çökme para bütünlüğünü bozuyordu. | `TransferLedger` + kalıcı gönderen outbox/alıcı inbox/received kimliği eklendi. Borç ve niyet kaydedilmeden yayımlanmaz; alıcı nakit ve tekrar işareti kalıcı olmadan inbox onaylanmaz. Gerçek TransferService ve SaveStore testlerinde yazım öncesi/sonrası hata, commit olup yanıtın kaybolması, yeniden başlatma, aynı kimliğin tekrarı, eşzamanlı yeni niyet ve selective ack denenir; nakit + benzersiz bekleyen borç toplamı korunur. | Ayrı anahtarları atomik yapmaz; tekrarlarla tamamlanır. Normal aktarımda inbox publish/read/ack nedeniyle ek DataStore işlemi vardır. Outbox 64, inbox 128 ile sınırlıdır; dolulukta para silinmez, işlem bekler. 10 saniyelik yoklama 6 çevrimiçi oyuncuda yaklaşık 36 inbox okuması/dakika üretir; canlı kota/gecikme ölçülmedi. |
| Kayıt sırasında eklenen mali işaret, devam eden eski snapshot sonrasında kaydedilmiş sayılabiliyordu. | `PlayerDataService.save` çağrı anı revizyonunu checkpoint alır, eski yazım bittiğinde o checkpoint kalıcı olana kadar yeniden yazar. `markDirty` ağ ve yield olmadan işaretler. Yield sırasında ikinci transfer testi yeni borcun eski checkpoint ile yayımlanmadığını doğrular. | Eşzamanlı değişiklikte ek yazım gerekebilir. |
| 200 makbuzdan sonra eski kimlik siliniyor ve tekrar ödül riski doğuyordu. | `ReceiptLog` ve codec eski kimliği hiç silmez; 20.000 sınırında yeni ödül `NotProcessedYet` ile bekler. 201 makbuz + reload + eski replay, kayıtsız çökme, tam kapasite ve sunum hataları test edilir. Kalıcı ödül mutasyonu bildirim/telemetri hatasından ayrıldı. | Daha önce eski kodun sildiği kimlikler geri üretilemez. 20.000 x 40 ASCII kimlik için yalnız receipt JSON yaklaşık 860.001 bayt; gerçek toplam kayıt ayrıca izlenmeli. 1.000 başarısız lookup medyanı 200 kimlikte 0,000356 sn, 20.000 kimlikte 0,031841 sn (7 örnek, sentetik). Kapasite sonrasında ayrı kalıcı günlük tasarımı gerekir. |
| Yedek, son mali tekrar işaretlerini içermeyebilir. | Kurtarmada kalıcı `transfers.quarantined` işareti yazılır; transfer/makbuz otomatik işleme durur. Gerçek PlayerDataService kurtarma ve tekrar kayıt testi, TransferService ve Monetization testleri karantinayı doğrular. | Yedekteki nakit daha eski olabilir; bu çözüm eski bakiyeyi otomatik mali uzlaştırmaz. Karantina ancak kanıtlarla elle incelemeden sonra kaldırılmalı. |
| Bekleyen kayıt snapshot’ı makbuz dizisini canlı profille paylaşıyordu; sonraki makbuzun işareti eski nakit görüntüsüne sızabilirdi. | Codec makbuz dizisini kopyalar. Gerçek codec testinde snapshot sonrası ödül ve makbuz silme eski snapshot’ı değiştirmez. | Snapshot başına makbuz dizisinin kopyası; kalıcı etki/işaret bütünlüğü için gereklidir. |
| Mali geçmiş büyüdükçe her PlayerState paketine kopyalanıyordu. | `FarmProfiles.clientState` receipts/transfers alanlarını dışarıda tutar. Test kamuya açık nakit/envanterin kaldığını ve sunucu günlüğünün değişmediğini doğrular. | Mali geçmiş istemcide kullanılmıyordu; özellik sözleşmesi korunur. Gerçek ağ bayt ölçümü yapılmadı. |
| SeasonSignal her 15 Hz tick'te model altını tarıyordu; düşük kalite modunda da gereksiz yazıyordu. | `SeasonGlow` parçaları/başlangıç saydamlığını bir kez yakalar; düşük kalite/hareket azaltmada yalnız mod geçişi yazar. Model tabanlı zemin parıltısı korunur; güncel kural gerçek görünümle hizalandı. Tag kaldırma glow ve dinleyiciyi temizler; duplicate tag ve mod geçişleri test edilir. | Model başına küçük parça önbelleği tutulur; kurulum taraması bir kez yapılır. Model yapısı efektin ömrü boyunca sabittir. |
| Tip analizi borcu ve Presentation → Services geri bağımlılığı vardı. | Callback dönüşleri/record tipleri açıklandı, nullable değerler daraltıldı. ExtensionVisualService tipli Actions alır; giriş noktası sahiplik/satın alma/görev fonksiyonlarını configure eder. Üç geri require ve mimari istisna kaldırıldı. Gerçek prompt testleri sahiplik değişimi, red/hata/sessiz throttle yollarını kapsar. | Başlangıçta configure bağı vardır; test eksik yapılandırmanın kapalı davranmasını doğrular. Tip analizi 0 bulgu, baseline 0; yeni hatalar gizlenmez. |
| MarketStall aynı referent kimliklerini iki parçada kullanıyordu; doğrulayıcı kaçırıyordu. | Son iki parça referenti benzersiz 38/39 oldu; geometri, pivot ve renk değişmedi. Model denetimi duplicate referent, dangling/null PrimaryPart, top-level ek nesne, animation pivot, sonlu/pozitif ölçü ve zorunlu animasyon parçalarını kontrol eder. Kaynak beklenti parsing hatası sessizce kapsam daraltmaz. 11 Python regresyonu eklendi. | 745 model statik doğrulandı. Studio görsel/animasyon testi ayrıca gerekir; harita yerleşimi değişmediği için MAP_VERSION artırılmadı. |

### Efekt önce/sonra ölçümü

`python scripts/benchmark-season-glow.py`: main kaynak snapshotı ve yeni gerçek kod, aynı Luau CLI, 120 glow × 8 parça × 1.500 tick; yedi dönüşümlü önce/sonra tekrar. Son koşu medyanları:

| Mod | Önce | Sonra | Süre azalması |
|---|---:|---:|---:|
| Yüksek | 0,215294 sn | 0,060389 sn | %72,0 |
| Düşük | 0,104824 sn | 0,004048 sn | %96,1 |

Animasyon sırasında GetDescendants çağrısı 180.000'den sıfıra iner; ilk kurulumda glow başına bir çağrı vardır. Sentetik mikro ölçümüdür; FPS veya gerçek cihaz kazancı olarak sunulmaz. Log `.test-build/optimization-season-benchmark.log`; script ölçümü tekrar üretir.

### İkinci aşama doğrulama durumu

Son toplu regresyon `powershell -ExecutionPolicy Bypass -File scripts/verify.ps1 -RequireTypes` exit 0 ile geçti; atlanan adım yok. Son makbuz snapshot düzeltmesi bu koşuya dahildir. 44 saf Luau spec grubu, ayrı görsel kimlik testi ve 19 Python regresyon testi (8 tip aracı + 11 model doğrulayıcı) geçti. StyLua, Selene (0 hata/uyarı), bütün Luau derleme, ekonomi duman/değer ve ideal/casual/idle altı çiftlik sıralı tamamlama simülasyonları, 1.206 çeviri anahtarı ve UI literal kapsamı, rehber/mimari kontrolleri, saf yardımcı/Roblox tip analizi ve oyun/eklenti/test Rojo derlemeleri geçti. 745 modelde 0 eksik/bozuk dosya var. Tip analizi 0 bulgu; baseline sıfıra daraltıldı. Log `.test-build/optimization-final.log` içindedir.

İlk ikinci-aşama toplu koşusu yeni kurtarma assert'inin açıklama metni eksik olduğundan Selene'de başarısızdı; metin eklendi ve bütün toplu kontrol yeniden geçirildi. Test beklentileri veya lint kuralları gevşetilmedi. `git diff --check` temiz. Studio çalışma zamanı, gerçek servis kesintileri ve cihaz kontrolleri bu sonuçların dışında kalır.

## Kalan riskler ve somut devam adımları

1. Bekleyen aktarım hemen tamamlanma garantisi vermez: sunucu inbox yayımından önce kapanırsa gönderenin kayıtlı outbox’ı sonraki girişinde yeniden yürütülür; yayımlanmış inbox alıcının hazır oturumunda işlenir. Nakit tavanı/kuyruk doluluğu teslimi geciktirebilir; bekleyen borç otomatik silinmez.
2. Studio Test → Server + 2 Players ile transfer, tekrar giriş, satın alma, görevdeki balık, çiftlik geçişinde ayrılma, streaming/tag ve model animasyonlarını dene. Yerel otomatik testler gerçek Roblox servislerinin yerine geçmez.
3. Ayrı test DataStore'unda yanıt kaybı/kapanış ve uzun oturum dene; mali günlük boyutu, inbox kuyruğu, DataStore kota/gecikme, SaveFailed ve ReceiptCapacityBlocked ölçümlerini izle. Canlı kayıt kullanılmadı.
4. Eski 200-makbuz kodunun geçmişte sildiği kimlikler ve yedekten geri alınmış bakiye otomatik düzeltilemez. Kurtarılan hesap karantinasında asıl kayıt/yedek/inbox kanıtlarıyla manuel mali uzlaştırma gerekir; kanıtsız karantina kaldırma yapılmadı.
5. 20.000 makbuz/alınan transfer sonrasında eski kimlikleri silmeden ayrı kalıcı günlük veya arşiv protokolü tasarla. Yeni işlem o sınıra ulaşınca durur; kapasite için güvenlik beklentisi gevşetilmedi.
6. Yeni mali alanları tanımayan eski uygulama/codec sürümüne doğrudan geri dönmek geçmiş işaretlerini kaybettirebilir. Yayın/geri alma planında günlüğü koruyan sürüm kullanılmalı; mevcut çalışma henüz yayınlanmadı.
7. Düşük cihazda MicroProfiler, FPS, gerçek ağ paketi boyutu ve uzun süreli bellek kontrolü yap; ölçülen CLI kazancını cihaz kazancı sayma. Telefon/gamepad/HUD ekran boyutları da bekliyor.

Kullanıcı son toplu otomatik doğrulamadan sonra yerel `main` ile birleştirmeyi istedi. `codex/optimizasyon` değişiklikleri commit edilerek main'e birleştirilir; push veya dağıtım bu talebin kapsamında değildir. Studio ve gerçek servis/cihaz kontrolleri yukarıdaki devam adımları olarak kalır. Canlı veri silme, geri alınamaz şema işlemi veya dağıtım yapılmadı.
