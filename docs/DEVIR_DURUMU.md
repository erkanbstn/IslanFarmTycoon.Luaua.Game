# Güncel devir durumu

4 Ekim 2026. Başlangıç rehberi `AGENTS.md` ve `AI_DEVIR_REHBERI.md`; güncel davranış kaynağı Config, FarmMath, servisler ve testlerdir.

## Teslim edilen yapı

- Main `3349e54`: 30 rebirth, altın/kalıcı sahiplik, geniş market, ilerleme/etki ekranı, arayüz düzenlemeleri, üretim-talep dengesi ve meydandaki indirimli ekipman tüccarı.
- Çalışma dalı `codex/ai-calisma-araclari`: doctor, Fast/Full doğrulama, harness bağımlılık kontrolü, ekonomi karşılaştırması ve izole Studio senaryoları. Admin maxAll hayvan kimliğiyle soy seviyesi yazıyor; GoalCard test bağımlılıkları tamamlandı. Bu aşama 4 Ekim 2026'da main'e yerel olarak fast-forward birleştirildi; push edilmedi. Roblox yerelleştirme/CSV geçişi dalı (`feat/roblox-ceviri`) vazgeçildi ve silindi; çeviri kaynağı `src/shared/Locales` olarak kalır.
- Son Full `-RequireTypes` başarılı; tip bulgusu sıfır, model kapsamı 761 görünümde eksik/bozuk yok. Fast yaklaşık 7,5 saniye. 19 tooling (hijyen dahil), 8 karşılaştırma, 5 QA Python testi ve saf Luau regresyonları geçti.
- Kayıtsız Studio'da fresh/merchant/production ve altı çiftlikli R29/R30 profilleri çalıştı. R29 rebirth açılıyor, R30 kapanıyor. QA kapalı ve eski requestId reddediliyor. Bunlar gerçek 30 tur oynama veya gerçek ödeme testi değildir.
- Altı saatlik aynı hardcore senaryosu, ikişer tekrar: AI araçları öncesi/sonrası oyun ölçümleri aynı. 3,729/3,724 saniyelik proses farkı performans kazancı sayılmaz.

## Temizlik

Geçici Studio QA scriptleri ve StudioQaEnabled özniteliği kalmadı. Başlangıçta mevcut StudioNonPersistentData=true koruma bayrağı korunuyor. Otomatik onay denetimi bu bayrağın kaldırılmasını sonraki Studio Play kalıcı kayıt kullanabileceği için reddetti; kaldırma için kullanıcı onayı isteniyor. Edit'teki `_ModelSwapBackup` klasörü (17.458 alt nesne: eski Plots/World, Terrain kopyaları ve EmptyIslandTest) kaldırıldı; mevcut Workspace.Plots/World korundu. Undo waypoint oluşturuldu. Studio değişikliği kaydedilmedi/yayınlanmadı; kalıcı tutmak için geliştirici Edit'te kontrol edip kaydetmelidir.

Yinelenen 12 tarihsel inceleme/ilerleme raporu aktif docs alanından .cleanup-archive/2026-10-04 altına taşındı; iki render günlüğü de arşivlendi. Arşiv git dışında, yerel olarak geri alınabilir. Eski plan taslakları kaldırıldı. Gerekli açık riskler aşağıya taşındı; takipli eski dosyalar ayrıca Git geçmişinden bulunabilir. Yaklaşık 126 MB üretilmiş test çıktısı, geçici derlemeler, sourcemap ve Python önbellekleri temizlendi. Son temizlikte Fast -RequireTypes, rehber/model denetimleri ve git diff --check geçti; oyun kaynakları bu temizlikte değiştirilmedi. Önceki Full başarılıydı; çıktı dosyaları artık yeniden üretilmelidir. Kullanılan modeller, üretici kaynakları, sözleşmeler ve çalıştırılabilir test/QA araçları korundu.

İkinci temizlik (4 Ekim 2026, aynı gün): ~900 satırlık `GPT_ILETISIM.md` iş günlüğü, `GPT_MODEL_IS_LISTESI.md` teslim listeleri ve pilot dönemi `MODEL_IS_PLANI.md` tamamlandıkları için kısa güncel sürümlere indirildi; özgün metinler yerel `.cleanup-archive/2026-10-04/docs/` ve Git geçmişindedir. Uygulanmış tek seferlik model yama betikleri (`fix_animal_torso_slopes`, `fix_bridge_well_safety`, `fix_spawn_plaza_clearance`, `refresh_tile_roofs`, `fix_tree_trunk_collision`) silindi; yeniden çalıştırılabilir üreticiler kaldı. Tüketicisi olmayan `Ui/Hud/ProgressionWindow.luau` uyumluluk modülü silindi. Eski/yetim kalan belgeler `AI_DEVIR_REHBERI.md` dizinine bağlandı. Yeniden bayatlamayı yakalamak için `scripts/check-repo-hygiene.py` (ölü yol/bağlantı, yetim belge/betik/modül, izlenen çöp, 400 satır sınırı, olmayan commit kimliği) eklendi; Fast ve Full içinde çalışır, testi `tests/tooling.spec.py`.

Üçüncü tur (4 Ekim 2026, alt ajanlarla): Kullanılmayan `IslandContext.isPreview/hasAnimal`, `StoreSection.isForSale`, `PlayerDataService.takeOfflineEarnings`, `MapBuilder.warnIfNoPlots` ve beş dilde aynı 50 çeviri anahtarı (1555 → 1505) silindi. Ölü Remote, yorumlu kod ve tüketicisiz Config bulunmadı. `check-assets.py` fazla/bilinmeyen model dosyasını hata sayar (761 görünüm, 0 fazla). Hızlı başlangıç araçları: `python scripts/triage.py` (değişen dosyalara göre kural, skill ve en küçük kontrol komutları; `--run`, `--json`), `python scripts/smoke-quick.py --only ad` / `run-tests.py --only ad --list` (saf Luau alt kümesi, saniyeler) ve `docs/HIZLI_AKSIYON.md` görev→komut tarifleri. Şüpheli bırakılanlar: yalnız testlerde kullanılan `PlotService.getFarmId`, `Config.getAnimalTheme`, `Config.getIslandAnimal`, `Inventory.ownedCount`, boş `Remotes.FUNCTIONS` şablonu ve ~187 dinamik olabilecek çeviri anahtarı. Sonra işi bitmiş `GPT_ILETISIM.md`, `HAYVAN_YUZEY_DENETIMI.md`, `REBIRTH_30_DOGRULAMA.md` ve `URETIM_TUCCAR_DENGE.md` de silindi (yerel arşivde ve Git geçmişinde). Hijyen denetimi sonradan ölü fonksiyon, yorumlu kod, yarım Remote ve ölü çeviri anahtarını da yakalar hâle geldi; ilk koşuda yakaladığı `ExtensionVisualService.findExtensionArea` (ve ona bağlı `ExtensionAreas` require/test bağımlılığı) silindi. Full `-RequireTypes` bu turdan sonra geçti.

## Yayın öncesi somut kalan işler

1. Creator Hub ürün kimliklerini ve fiyatlarını belirle; kimliği 0 olan Robux ürünleri kapalı. Ayrı test ortamında gerçek makbuz/tekrar giriş ve çift ödeme korumasını doğrula.
2. Studio iki oyuncu: aktarım, çiftlik geçişi, streaming, ayrılma/yeniden giriş. Mobil/gamepad, uzun oturum belleği ve MicroProfiler/FPS ölçümü ayrı yapılmalı.
3. Ayrı test DataStore'unda gecikme, yanıt kaybı, kapanış ve kota senaryoları; SaveFailed, ReceiptCapacityBlocked, mali günlük ve inbox boyutlarını izle. QA fixture'ları kayıt yazmadığından bunları kanıtlamaz.
4. Mali günlük 20.000 kayda ulaşınca yeni işlem güvenli biçimde durur. Eski kimlikleri silmeden kalıcı arşiv protokolü gerekir. Geçmiş eski kodun sildiği makbuzlar veya geri alınmış bakiyeler otomatik uzlaştırılamaz; karantina kanıtlarıyla manuel inceleme gerekir.
5. Bekleyen aktarım hemen teslim garantisi vermez. Sunucu inbox yayımından önce kapanırsa kayıtlı outbox gönderenin sonraki girişinde sürdürülür; kapasite veya nakit tavanı geciktirebilir. Borcu otomatik silme. Yeni mali alanları tanımayan eski codec'e dönmek hak kaybı yaratabilir.
6. Model/Studio kabulü: R15 `season_staff_inf` + `golden_crown` birlikte takılınca `Equip_head`/`Equip_staff` kesişiyor (R6'da yok); alt parçalar ölçülüp model düzeltilmeli, 8 asa × 8 başlık R6/R15'te taranmalı. Hayvan yüzey takibi (`AnimalAnimator.supportAt`) kodlandı ama 26 tür × 3 yaş, eklenti kapasiteleri ve streaming Play kabulü yapılmadı.
7. Ses kimlikleri, gerçek cihazdaki çeviri/arayüz görünümü ve ayrı lobi kararı ilgili tasarım belgeleriyle değerlendirilir. Eski raporlardaki model/locale sayıları güncel doğrulama yerine kullanılmaz.

Skill-creator quick_validate PyYAML bulunmadığından çalışmadı; proje rehber/frontmatter/yönlendirme kontrolü geçti. Selene API indirme yerine mevcut önbelleği kullandı, lint sıfır hata.

## Devralma promptu

“Bu Roblox/Luau projesini devral. Önce AGENTS.md, docs/AI_DEVIR_REHBERI.md ve docs/DEVIR_DURUMU.md dosyalarını oku; mevcut dalı ve kullanıcı değişikliklerini koruyarak doctor ve hızlı doğrulamayı çalıştır. Verdiğim görevi ilgili skill/rule'lara göre uygula, davranış testleriyle doğrula ve sonunda gerekli Full/Studio kontrollerini yap. Commit, push, merge, publish veya canlı veri sıfırlamasını yalnızca açık talebimle yap; kısa Türkçe sonuç ver. Görevim: [buraya yapılacak işi yaz].”

## Son arayüz çalışması

Dal `codex/menu-onboarding`, başlangıç `main/789e8c6` temizdi. Pazar/Yükseltmeler/Yol Haritası ortalandı, 600 × 560 mantıksal alan ve UiKit ekran sığdırması kullanıyor. Yol Haritası seçili adada bir aşama gösterir; kalabalık aşamalar altışar yükseltmeli sayfalara ayrılır. Aşama/ada değişiminde sayfa ve ayrıntı sıfırlanır, para güncellemesi seçimi bozmaz.

Öğreticide Atla bütün vurguları ve dünya işaretlerini kapatır. Üretim adımı yeterli yetişkin/para/depo alanı olan parti ister; ilk üretim sonrası aynı oturumda geri gelmez. Genişletme adımı Yükseltmeler'in doğru sekmesini açar. Atla/toplu alım/eklenti aksiyonlarının dokunma hedefleri büyütüldü. Yeni sayfa metni beş dile çevrildi.

Gerçek kaynak regresyonları aşama geçişi, sayfa sınırı, eski kartların gizlenmesi, para/ada bağlamı ve gerçek öğretici iptalini doğrular. Son `verify.ps1 -Mode Full -RequireTypes` başarılı; log `.test-build/menu-final-verify.log`. Studio'da üç pencere merkez ve aynı ölçüyle açıldı, gerçek aşama/sayfa düğmeleri ve Atla tıklandı. Aynı 1914 × 634 viewport, 0,8 kök ölçeği ve taze profilde ilk aşama sayfalama öncesi 1547 px, ilk sayfa sonrası 683 px içerik yüksekliğinde; ikinci sayfa 522 px. Görünen metinlerde taşma yoktu. Geçici 320 × 500 mantıksal pencere (256 × 400 render) kontrolü de taşmasız; gerçek telefon emülasyonu değildir. Play durduruldu, geçici arayüz boyut/isimleri oturumla temizlendi. Commit/push/merge/publish yapılmadı. Gerçek mobil/gamepad kontrolleri ayrı kalır.

## Ada dönüşü, meydan ve bildirim düzeni

Aynı çalışma dalında etkin çiftliğe dönüş artık sunucuda gerçek ana ada ışınlanmasını doğrular; karakter hazır değilse başarı cevabı verilmez. Tema yeniden kurulmaz, dönüş ücreti yoktur. Sol cüzdan şekille çizilmiş altın simgesi yanında Altın miktarını ve ayrı satırda açık Rebirth sayısını gösterir; yeni şablon beş dile çevrildi.

Meydanın Hub_Banner modelindeki saydam yüzeyler açıkça görünür yapıldı, iki yüzüne karşılama yazısı kondu. Sıralama üst tabelası Island Farm Tycoon gösterir; nakit sıralaması korunarak her oyuncunun rebirth sayısı eklendi. Harita sürümü 58; Edit'te buildverify çalıştı, harita/dünya sözleşme testleri geçti. Kalıcı place kaydı için geliştirici Ctrl+S yapmalıdır; yayın yapılmadı.

Bildirimler tüm pencerelerden tek Notifications katmanında (DisplayOrder 20) gelir. İki görünür ve altı bekleyen sınırı, tekrar birleştirme, zamanlayıcı/animasyon iptali ve kök kapanış temizliği var; taşmada en eski bekleyen çıkarılır. Öğretici ve tüccar rozeti görünür gerçek boyutlarıyla bildirimleri aşağı taşır; öğretici kapanınca boşluk kalkar. Tüccar rozeti de öğreticinin altında kalır. Kurallar ve UI skill ortak API için güncellendi.

Gerçek kaynak testleri dönüş/başarısız karakter/ücretsiz dönüş, canlı rebirth sıralaması/legacy sıfır/eski satır temizliği ve 1.000 bildirimlik kuyruğun sınırları/tekrar/animasyon yarışı/ReducedMotion/kapanış senaryolarını doğrular. Studio nonpersistent Play'de gerçek dönüş düğmesi karakteri meydandan kendi ana adasına taşıdı. 12 bildirim gönderildiğinde aynı anda iki kart görünür ve öğretici/tüccarın altında çakışmasızdı; Atla sonrası alan yukarı taşındı ve kuyruk tamamen boşaldı. Cüzdanın iki metni TextFits kontrolünü geçti. Edit ekranında dolu karşılama tabelası görsel olarak incelendi. Play durduruldu; geçici QA isimleri/bildirimleri oturumla temizlendi. Gerçek telefon/gamepad ve çok oyunculu testler bu aşamada yapılmadı.

Son toplu `verify.ps1 -Mode Full -RequireTypes` başarılı; log `.test-build/hud-world-final-verify.log`. Tip analizi sıfır bulgu, beş dilde 1507 anahtar, 761 modelde eksik/bozuk yok; tüm Luau regresyonları, araç testleri, ekonomi/çiftlik simülasyonları ve üç Rojo derlemesi geçti. Selene API indirmesi başarısız olduğunda mevcut önbelleği kullandı, lint sıfır hata/uyarı. Commit, push, merge ve publish yapılmadı.
