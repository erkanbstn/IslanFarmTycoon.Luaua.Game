Güncel durum için docs/DURUM_RAPORU.md

# Island Farm Tycoon — Proje Analiz Raporu (2026-10-01)

`docs/AI_ANALIZ_PROMPTU.md` istemine göre hazırlandı. Kod okunarak yazıldı; iddiaların hepsi dosya/satıra dayanır.
Kritik bulgular ayrıca elle doğrulandı. Studio çalıştırılmadı; instance sayıları ve ağ yükü kodla **tahmin** edildi.
Ekonomi rakamları `scripts/simulate-economy.py` farklı parametrelerle çalıştırılarak elde edildi.

Otomatik kontrollerin bugünkü durumu: testler (25 spec), mimari, AI belgeleri, çeviri (932 anahtar), tip (774 bilinen, yeni yok),
Selene ve StyLua — **hepsi temiz.**

---

## Yönetici özeti (10 satır)

1. Kod tabanı tek kişilik bir proje için olağanüstü düzenli: katmanlar denetleniyor, para/ödül sunucuda, kayıt sistemi profesyonel düzeyde.
2. Para basmaya yarayan bir istismar bulunmadı; her Remote tip kontrolü ve hız sınırı taşıyor.
3. En büyük teknik risk: ekonomi, büyüme ve mevsim döngüleri tek bir hatada **herkes için kalıcı olarak duruyor** (`pcall` yok).
4. En büyük tasarım riski: ahır deposu yalnızca **1–3 dakikalık geliri** tutuyor. 5 dakikada bir toplayan oyuncu ilerlemenin yarısını kaybediyor; en iyi strateji platformda AFK durmak.
5. Çevrimdışı gelir, "Pasif Gelir" alınana kadar (ideal oyuncuda 135. dakika) neredeyse sıfır. 1. gün geri dönüş kancası yok.
6. Çalışma anında tema giydirme fikri doğru, uygulaması pahalı. Her girişte, çıkışta ve çiftlik değişiminde ada tamamen yeniden kuruluyor (tahminen 1,5–3 bin parça).
7. Telemetri yok denecek kadar az: `AnalyticsService` hiç kullanılmıyor. Arkadaş testinden sonra karar verecek veri olmayacak.
8. Robux akışında iki kayıt tutarlılığı hatası var. Ürün kimlikleri 0 olduğu için bugün zararsız, açılmadan önce düzeltilmeli.
9. İstemci tarafında ses büyük ölçüde boş (36 yuvadan 31'i). Mobilde güvenli alan ve UI ölçeği yok. Hayvan animasyonu düşük cihazda en pahalı iş.
10. Geç oyun 5. saatten sonra düzleşiyor ve sonraki çiftlikler 1. çiftlik fiyatlarını kullandığı için "yeni bölüm" hissi vermiyor.

## En kritik 5 risk

| # | Risk | Önem | Efor |
|---|---|---|---|
| 1 | Sunucu döngüleri tek hatayla kalıcı duruyor (gelir/büyüme/mevsim) | Kritik | S |
| 2 | Depo 1–3 dk'da doluyor; AFK platformda durmak en iyi strateji | Kritik | S |
| 3 | Yeni oyuncu için çevrimdışı gelir ≈ 0; geri dönüş nedeni yok | Kritik | S |
| 4 | Telemetri yok; tutunma, huni ve veri kaybı ölçülemiyor | Yüksek | M |
| 5 | Tema yeniden kurulumu: her giriş/çıkışta 2 tam kurulum, 0,6 sn'de bir çiftlik değiştirme, keçi adası her yenilemede yeniden kuruluyor | Yüksek | S–M |

---

## 1. Mimari ve kod kalitesi

**Şu an:** Katman yapısı (`Modules → World → Presentation → Services`, istemci `Core → Effects → Ui → Interaction`) gerçekten uygulanıyor ve `check-architecture.py` ile denetleniyor. `run-tests.py` gerçek kaynak kodu çalıştırıyor, servisler `game`/`DateTime` enjeksiyonlu fabrikalar. Büyük dosyalar makul boyutta (en büyüğü `SaveCodec` 782 satır).

### 1.1 Remote işleyicilerinde kopyala-yapıştır kalıplar — Orta · S–M · bakım
- "Etkin çiftlik değişti" kontrolü 9 kez tekrarlanıyor (`AnimalService` ×4, `UpgradeService.luau:224-262` ×3, Contract, Production).
- `purchaseThrottleReply` → `PurchaseResult`/`Notify` bloğu 6 kez yazılmış (`UpgradeService.luau:115-128`, `AnimalService.luau:196`, `EngagementService.luau:152`, `InventoryService.luau:292`).
- `pushState` 13 servisten ayrı ayrı çağrılıyor.
- **Öneri:** `Services/RequestGuard.luau` içinde `withFarmContext(handler)` + `reply(player, requestId, ok, msg)`. Yaklaşık 150 satır azalır ve MIMARI'deki "doğrula → sınırla → hesapla → kaydet → pushState" sırası tek yerde zorunlu olur.

### 1.2 Presentation ↔ Services döngüsü ve gizli tembel olmayan require — Orta · M
- `CollectorVisualService.luau:12-13`, `PlayerDataService` ve `PlotService`'i **dosya başında** require ediyor. Bu MIMARI'nin "yalnızca tembel require" kuralına aykırı; ALLOW listesi bunu gizliyor.
- `PlotService.luau:31-38` üç Presentation servisini çağırıyor, döngü buradan.
- **Öneri:** Bağımlılıkları `init.server.luau`'dan `init(deps)` ile ver ya da `Services/WorldEvents` sinyali kur; ALLOW girdilerini sil. `check-architecture.py`, izinli dosyada bile dosya başındaki yukarı yönlü require'ı yakalasın.

### 1.3 Tip borcunun %75'i iki kalıptan geliyor — Orta · S (ucuz kısım)
- 774 bulgudan 429'u (%55) `World/*` içindeki "Unknown require" hatası. Kaynağı eklenti uyumlu `script.Parent.Parent:FindFirstChild("Shared") or ...` araması (`MapBuilder.luau:13`).
- **Öneri:** Tek bir `World/SharedRef.luau` + `:: typeof(ReplicatedStorage.Shared)` dönüşümü yaklaşık 450 girdiyi silebilir (Studio'da denenmeli).
- 144 bulgu döngüsel bağımlılık (1.2 ile çözülür).
- 53 bulgu `pcall` yanlış pozitifi. Kalan yaklaşık 100 gerçek bulgu ucuz: `PlayerDataService` `unknown?` → `string?` gibi.
- **Not:** `.tools/luau-lsp` yoksa `verify.ps1:69` tip denetimini **sessizce atlıyor**. Temiz klonda ya da CI'da yanlış güven verir; atlama uyarı basmalı.

### 1.4 Büyük, karışık sorumluluklu dosyalar — Orta · M–L
- `SaveCodec` (tüm alt sistemlerin decode/göçü): alana göre böl (goods, contracts, inventory, pets), tek `decode` arkasında.
- `PlayerDataService` (DataStore, kilit, yedek, metrik, pushState): kalıcılığı `SaveStore` modülüne ayır.
- Tip borcu ile aynı dosyalar; refactor ve tip düzeltmesini birlikte yap.

### 1.5 Güvenlik
Genel durum iyi:
- Her Remote `unknown` tipinden doğrulanıyor ve hız sınırlı; fiyat ve ödül sunucuda hesaplanıyor (`UpgradeService.luau:41-52`).
- Tek seferlik ödüllerde bayrak paradan önce yazılıyor (`EngagementService.luau:50,120,142`).
- Gelir telafisi 60 sn ile sınırlı (`EconomyService.luau:121`).
- Sahiplik dünya etkileşimlerinin hepsinde sunucuda kontrol ediliyor.

Açık noktalar:

| Bulgu | Önem · Efor | Kanıt | Öneri |
|---|---|---|---|
| Eklenti prompt'ları hız sınırını atlıyor; her tetik settle + pushState + save + yeniden çizim yapıyor | Orta · S | `ExtensionVisualService.luau:152-169` → `ExtensionService.luau:30,75`; benzeri `BuyPadService.luau:185,200-204` | `RateLimiter.allow`'u `tryAssign`/`tryUnassign` içine taşı |
| Admin komutları canlı sunucuda da çalışıyor; para sahibin gerçek kaydına ve sıralama panosuna yazılıyor, hava/mevsim herkesi etkiliyor | Orta · S | `AdminService.luau:36-53`, `AdminPolicy.luau:4` | `RunService:IsStudio()` veya özel sunucu şartı; ya da kaydı `adminTainted` işaretle ve panodan çıkar; her eylemi logla |
| `requestId` isteğe bağlı | Düşük · S | `RateLimiter.luau:30-32` | Eski istemciler bitince zorunlu yap |
| Altın hayvan mesafe kontrolsüz alınıyor; zamanlama paylaşılan modülde, öngörülebilir | Düşük · S | `EngagementService.luau:129-147`, `Golden.luau:15-28` | Karakter ~30 stud içinde olsun |
| Tüccardan al-sat marjı ince: tüm eşyalar birikirse iade 0,67, tüccar indirimi 0,70 | Düşük · S | `Shop.luau:95`, `Animals.luau:27-36`, `Items.luau` | `maxSellMult < 1 - MERCHANT.discount` testi ekle |
| Hız ve konum istemcide | Kabul edilebilir | `Sprint.client.luau:33` | Kazanç yolu yok; dokunma |

---

## 2. Çok oyunculu tasarım

**Değerlendirme:** "6 aynı ada + çalışma anında tema" yaklaşımı 6 kişilik sunucu için **doğru**. Arazi, bölgeler, ahır, doğma noktası ve toplayıcı ortak; tema değiştirilebilir bir katman. Sorun tasarımda değil, temanın nasıl uygulandığında. Dünya etkileşimlerinde yalıtım iyi: her prompt sahiplik kontrolü yapıyor (`UpgradeService.luau:275-291`, `BuyPadService.luau:191-194`). Yeniden kurulumlar yield etmediği için yarış koşulu pratikte yok.

### 2.1 Üç çekirdek döngüde hata koruması yok — **Kritik** · S · tüm sunucu
- `EconomyService.luau:166-179`, `AnimalService.luau:319-328`, `SeasonService.luau:192-197` *(doğrulandı)*.
- Tek oyuncunun bozuk verisi ya da `updateGrowth` → `refreshPlayerWorld` içindeki bir görsel hatası, döngüyü **sunucu yeniden başlayana kadar** herkes için durdurur: gelir yok, büyüme yok, mevsim yok.
- Pet, AnimalTask, BuyPad, Collector, Engagement ve HubBoard zaten oyuncu başına `pcall` kullanıyor.
- **Öneri:** Döngüdeki her oyuncuyu `PetService.luau:111-120`'deki gibi `pcall` + `warn` + `Metrics.increment("LoopError")` ile sar. 15 dakikalık iş.

### 2.2 Keçi adasındaki eklenti görselleri her yenilemede yeniden kuruluyor — Yüksek · S · hata
- `ExtensionVisualService.luau:265-331` *(doğrulandı)*. `rocky_terraces` ve `goat_cliffs` ikisi de `island = "goat"` (`IslandLayout.luau:43,54`).
- İki eklenti aynı `ExtensionVisuals` klasörünü ve **tek** `Signature` özniteliğini paylaşıyor; fiyatlar farklı olduğu için imza her seferinde uyuşmuyor.
- Sonuç: her `apply`'da iki eklenti de silinip yeniden kuruluyor (`ClearAllChildren`); ilk eklentinin tabelası ve prompt'ları kalıcı görünmüyor.
- **Öneri:** Klasörü `ExtensionVisuals/<extensionId>` yap ya da imzayı eklenti modeline taşı.

### 2.3 Her giriş ve çıkış 2 tam ada kurulumu demek — Yüksek · S
- `assign` önce "1" temasını bağlıyor (`PlotService.luau:533`). Kayıt yüklenince `restoreMainFarms` kayıtlı temaya yeniden giydiriyor (`:489-497`).
- Çıkışta `resetPlot` yine `retheme(plot, "1")` çağırıyor (`:429-433`) ve temizlikleri tekrarlıyor (`:438-440`).
- **Öneri:** Çıkışta yeniden giydirme yapma; boş ada herhangi bir temada kalabilir, yalnızca sahibin görsellerini temizle. `findFreePlot` (`:478-486`) rastgele seçmek yerine, oyuncunun kayıtlı temasıyla eşleşen boş adayı tercih etsin. `init.server.luau:229`'daki ikinci `refreshPlayerWorld`'ü kaldır.

### 2.4 Çiftlik değiştirme pahalı ve kolay tetikleniyor — Yüksek · M
- `MapBuilder.applyTheme` (`MapBuilder.luau:48-81`) adanın bütün tema içeriğini tek karede siliyor ve yeniden kuruyor. Ardından `WorldDecor.optimize(plot)` adanın **tamamını** geziyor.
- Tahmini maliyet geçiş başına 1,5–3 bin BasePart. Herkes takılma hisseder; her istemciye büyük bir çoğaltma paketi gider.
- Bekleme süresi yalnızca 0,6 sn (`MainFarmService.luau:107`).
- **Öneri (sırayla):**
  1. "select" için 5–10 sn ayrı bekleme süresi.
  2. `optimize`'ı yalnızca yeni alt ağaçta çalıştır.
  3. **Asıl çözüm:** 6 temanın içeriğini bir kez (sunucu açılışında ya da eklentide) `ServerStorage`'a kur; geçişte `Clone()` + `PivotTo` + parent yap. Yordamsal iş ve `optimize` biter, sonuç deterministik olur.
  4. Kurulumu asenkron yaparsan ada başına nesil (generation) jetonu şart.

### 2.5 Alternatifler
- **Önerilen:** hazır tema şablonları + temaya göre ada seçimi (2.3 ve 2.4).
- **Oyuncuya özel rezerve sunucu** (`LOBI_VE_ADA_MIMARISI.md`'deki lobi planı): çapraz oyuncu maliyeti tamamen kalkar, oyuncu bütün çiftliklerini yan yana bile görebilir. Bedeli ortak sosyal alanın kaybı, TeleportService ve misafir mantığı. Sosyal alan oyunun merkezinde değilse ciddi aday; karar telemetri sonrasına kalsın.
- **Önerilmeyen:** 6 temayı her adaya önceden yerleştirip görünürlükle aç/kapat. Yaklaşık 6 kat instance demek.

### 2.6 Diğer çok oyunculu bulgular

| Bulgu | Önem · Efor | Kanıt | Öneri |
|---|---|---|---|
| Hızlı sunucu değiştirenin girişi anında reddediliyor, oyuncu adasız bir plot'u tutuyor | Orta · S | `PlayerDataService.luau:393-395`, `init.server.luau:217-221` | Kilit başkasındaysa kira süresi boyunca (~60 sn) geri çekilerek tekrar dene; sonunda başarısızsa açık mesajla at |
| Max Players yalnızca uyarı | Düşük · S | `PlotService.luau:567-569` | Game Settings'te 6; `README.md:52`'deki "1 yap" bilgisini düzelt (aşağıda 7.1) |
| Yan yana eklenen hayvanlar aynı yuvaya düşebilir | Düşük · S | `AnimalVisualService.luau:128-188` | Bölgedeki tüm görünür hayvanları say |
| Misafir modu yok; giren herkes plot alıyor | Bilgi | `LOBI_VE_ADA_MIMARISI.md` | Lobi/ziyaret işinde ele alınacak |

---

## 3. Performans

### 3.1 `pushState` bütün kaydı gönderiyor ve sık tetikleniyor — Orta-Yüksek · M
- `PlayerDataService.luau:624-638` tüm `data` tablosunu gönderiyor. `FarmProfiles.view` (`:54-67`) yüzünden park edilmiş her çiftlik `inventory`/`passes` kopyası taşıyor; etkin çiftlik paylaşılan tablolar nedeniyle iki kez serileşiyor.
- `EngagementService.luau:183-188`: imzaya `floor(seasonalProgress)` giriyor; "earned" metriğinde her saniye değişiyor. Sonuç: oyuncu başına **5 sn'de bir tam kayıt**.
- `AnimalService.updateGrowth` (`:212-237`) park edilmiş bir çiftlik değişse bile etkin adayı yeniden çiziyor.
- **Öneri:**
  1. Mevsim ilerlemesini hafif `EconomyTick` yolundan gönder ya da %1 adımlara yuvarla.
  2. `pushState`'i oyuncu başına en çok 0,25 sn'de bire birleştir (kirli bayrak + `task.defer`).
  3. Park edilmiş çiftlikleri istemciye yalnızca özet olarak gönder.
  4. `refreshPlayerWorld`'ü yalnızca etkin çiftlik değiştiğinde çağır.
- Boyut `DataBytes` özniteliğinde zaten ölçülüyor; Studio'da bak.

### 3.2 Streaming açık ama yarıçap bütün haritayı kapsıyor — Orta · S
- `default.project.json:62-68`: Min 512 / Target 1024. Adalar 175 stud halkada, uydu adalar en fazla 200 stud dışarıda.
- Her istemci 6 adanın tamamını (tahminen 10–20 bin parça) ve her yeniden kurulum paketini alıyor.
- **Öneri:** Min yarıçap 128–192, hedef 384–512. İstemci zaten `FindFirstChild` ile dayanıklı. Hareket ettirilen hayvan modelleri için `ModelStreamingMode.Atomic`.

### 3.3 İstemci efektleri (düşük cihaz sırasıyla)

| # | Sorun | Kanıt | Öneri |
|---|---|---|---|
| 1 | Yakındaki tüm hayvanlar her karede `PivotTo` (RenderStepped, 140 / düşükte 80 stud, bütün oyuncuların hayvanları) | `AnimalAnimator.client.luau:138-214` | Tek `Workspace:BulkMoveTo` (SeabedLife zaten yapıyor); düşükte 50 stud ve en çok ~20 hareketli hayvan; `PreRender` |
| 2 | Localizer çift yazım: HUD her saniye Türkçe yazıyor, Localizer çeviriyi geri yazıyor; 3000 girişlik önbellek dolunca tamamen siliniyor | `Localizer.client.luau:71-92`, `Localization.luau:209-215`, `StatsPanel.luau:146-186` | Kaynak değişmediyse yazmayan `setText` yardımcısı; LRU önbellek; Workspace'te yalnızca Billboard/SurfaceGui izle |
| 3 | Gece ışıkları kalite ayarını yok sayıyor, 3 sn'de bir bütün ışıklara yazıyor | `DayNight.client.luau:93-112,247-252` | Düşükte PointLight kapalı, yalnızca Neon/renk değişsin |
| 4 | Pet boşta döngüsü uzaktayken de her kare çalışıyor; her yürüyüşte yol grafiği yeniden kuruluyor | `PetAnimator.client.luau:169-185,245-246` | ~120 stud ötesinde 0,5 sn uyku; grafiği ada başına önbelleğe al |
| 5 | SeabedLife su altında olmasa da çalışıyor; denizanası `Size` her kare değişiyor | `SeabedLife.client.luau:~637,691` | Kamera yüksekteyken 15 Hz; düşükte yosun ve baloncuk kapalı |
| 6 | HUD ödül ve pano güncellemeleri saniyede 2 kez, pencere kapalıyken bile | `FarmHud.client.luau:292-347` | `onState`'teki tekrarı kaldır; kapalıyken yalnızca rozet sayısı |

İyi yapılanlar: FPS ölçen otomatik grafik kademeleri (`Graphics.client.luau:82-227`), havuzlama ve mesafe kesimi (WeatherPrecip, IncomeBubbles, BuyPads), `ReducedMotion` uyumu.

---

## 4. Oyun tasarımı ve ekonomi

**Simülasyondan ilk 30 dakika (1. çiftlik, anında toplama):**
- Başlangıç 75 $, bu da tam 1 inek eder. Gelir 0,8/sn'den başlıyor (yavru 0,4×).
- Mera (440 $) 6,9. dk, Silo 14,4. dk, Ahır 2 15,8. dk, ilk ada (Kümes, 3,8 bin $) 18,7. dk.
- Gelir: 10. dakikada 8/sn, 30. dakikada 135/sn.
- İlk 10 dakikada 11 karar (10'u aynı "inek al"); 2–3. dakikalarda para ~0.
- **İlk 10 dakikada hiç yetişkin hayvan yok** (yavru 600 sn + genç 1200 sn).

### 4.1 Depo bir tasma gibi çalışıyor ve simülasyon bunu gizliyor — **Kritik** · S
- Ahır kapasiteleri 10k / 24k / 60k / 200k (`Config/Islands.luau:13-46`); her saatte yalnızca **58–208 sn** gelir tutuyor.
- Toplayıcı, platformda duran oyuncudan **her saniye** otomatik topluyor (`EconomyService.luau:166-171` → `collect`, `:85-93` mesafe kontrolü) *(doğrulandı)*.
- Simülasyon karşılaştırması:

| Senaryo | 6. saat geliri | Keçi adası |
|---|---|---|
| İdeal (anında toplama) | 4.352/sn | 163. dk |
| `--collect 300` | 1.967/sn | 319. dk |
| `--collect 600` | 737/sn (−%83) | — |
| `--collect 300 --cap-mult 5` | ideal ile aynı | ideal ile aynı |

- **Sorun:** Ada, fabrika ve sipariş yönetmek yerine platformda AFK durmak en kazançlı davranış. Oyun yanlış şeyi ödüllendiriyor. Otomatik Toplayıcı 910 bin $, ancak 243. dakikada alınabiliyor.
- **Öneri:** Kapasiteleri ~5 katına çıkar (50k / 120k / 300k / 1M) ya da `cap = max(barnCap, gelir × 600 sn)`. Otomatik Toplayıcı tabanını 15000'den ~5000'e indir (eğriden sonra ~180 bin $, yaklaşık 2. saat).

### 4.2 Çevrimdışı gelir yeni oyuncu için ≈ 0, "8 saat" gerçekte ~1 saat — **Kritik** · S
- Pasif Gelir (150 bin $, ideal oyuncu 135. dk) alınmadan uzakta geçen süre yalnızca depoyu doldurur, yani 1–3 dk gelir (`SaveCodec.luau:384-391`). İlk oturumların çoğu 135. dakikadan çok önce biter.
- Alındıktan sonra sınır `storageCap × 24` (`Config/Economy.luau:9-13`). Geç oyunda **~59 dakikada** doluyor; `OFFLINE_MAX_HOURS = 8`'e hiç ulaşılmıyor.
- **Öneri:** Yükseltme yokken gelirin %25'i, en çok 2 saat. Yükseltmeyle %50, en çok 8 saat. Sınırı depoya değil "saat × gelir"e bağla ve arayüzde gerçek sınırı göster. WelcomeBack ekranı bu kazancı kutlasın.

### 4.3 Park edilmiş çiftlikler fiilen kazanmıyor — Yüksek · M
- Park edilmiş çiftliğin geliri kendi deposuna gidiyor (`EconomyService.luau:124-136`). `collect` yalnızca etkin çiftliği boşaltıyor. Otomatik Toplayıcı'sı olmayan çiftlik dakikalar içinde doluyor.
- Hesap düzeyindeki Otomatik Toplayıcı **oyun geçişi** (gamepass) bütün park edilmiş çiftlikleri anında verimli kılıyor. Bu doğrudan pay-to-win.
- **Öneri:** Park edilmiş çiftlikler otomatik olarak cüzdana %50 ödesin, ya da 2. çiftlik düğmesi Otomatik Toplayıcı şartını açıkça istesin.

### 4.4 Sonraki çiftlikler 1. çiftlik fiyatlarını kullanıyor — Yüksek · M
- Yükseltme maliyeti çiftlikten bağımsız (`FarmMath/Core.luau:112-121`). 1. çiftlik ~5.000/sn kazanırken 2. çiftliğin ilk 2 saatlik yükseltmeleri saniyeler tutuyor; kalan tek kapı büyüme süreleri.
- **Öneri:** Çiftlik numarası başına yükseltme ve hayvan fiyatlarına ~×8 çarpan (ya da eşleşen gelir çarpanı).

### 4.5 Geç oyun 5. saatten sonra düzleşiyor — Yüksek · M
- 12 saatlik simülasyon: 6. saatten 12. saate gelir 4.352 → 5.066/sn (+%16), bu arada **113 milyon $ ırk geliştirmeye** gidiyor.
- Neden: ırk (+%8) ve eşya bonusları zaten +3–4 olan toplama **ekleniyor**. Her seviye fiilen ~%2 değerinde, maliyet 1,85× büyüyor. `income_charm_3` (5M $, +%10) fiilen %2,5 ediyor, geri dönüşü ~11 saat.
- **Öneri:** Irk ve eşya gelirini ayrı çarpan `(1 + lineage)` olarak uygula. Simülasyon çiftlik de satın alsın ki gerçek son oyun ölçülsün.

### 4.6 Ada temposu hedefleri kaçırıyor; 3. temada orta oyun adası yok — Orta · S
- Hedefler 15 / 45 / 110 dk, ölçülenler 18,7 / **63,3** / **162,8** dk. Maliyet sıçramaları: 3,8k → 53k (14×) → 230k.
- Ayçiçeği teması (`Config/Islands.luau:127-132`): dairy ve poultry (ikisi de Ahır 2) + pig (Ahır 4). Sonuç: **86 dakika yeni ada yok.**
- **Öneri:** 3. temada poultry yerine Ahır 3 adası (koyun veya at). At adası tabanı 3500 → ~2800, Ahır 4 6000 → ~5000.

### 4.7 Açılış yavaş ve tekdüze — Orta · S
- **Öneri:** Bir yetişkin hayvanla başlat, ya da ilk 10 hayvan için yavru 180 sn / genç 360 sn. Silo'yu Mera'nın önüne al (taban ~250). İlk sipariş ya da başarım ~5. dakikada gelsin.

### 4.8 Üretim, siparişler ve yardımcılar

| Bulgu | Önem · Efor | Kanıt / hesap | Öneri |
|---|---|---|---|
| Büyük parti çarpanı sabit; fabrikalar en iyi yatırım. At eğitimi binası ~11 dk'da, peynir ~16 dk'da geri ödüyor | Orta · M | `FarmMath/Production.luau:118-124` | Büyük parti çarpanını ~2,0'a sınırla ya da bina seviyesine bağla |
| Eklentiler 120 sn sürüyor; orta oyunda dakikada 4–6 tıklama (topla / yeniden gönder / yeniden başlat) | Orta · S | `Config/Upgrades.luau:400-419` | Toplam bonus aynı kalsın, süre 300–600 sn |
| Ürün taşması sessizce siliniyor; "≥1,4× vazgeçilen gelir" vaadi depo dolunca bozuluyor | Orta · S | `FarmMath/Goods.luau:57-68` | Sığmayacaksa parti başlatma, ya da taşanı 1,0× değerden sat |
| Siparişler geç oyunda önemsiz (1. saatte gelirin %9'u, 4. saatte %3,5) | Orta · S | 9 teklif / 10 dk, sabit ürün değerleri | Ödül = `max(değer, gelir × 60–180 sn)` |
| Altın hayvan *tek* hayvanın 150 sn geliri; 1. saatten sonra değersiz | Orta · S | `Golden.luau:318-321` | Toplam gelir × 90 sn |
| Elmas çekiç (5M $) geri ödeyemiyor | Düşük · S | `Items.luau` | ~2,5M $ |

**Yardımcılar (pet):** Yalnızca yeniden başlatmayı otomatikleştiriyor ve ~20 dk'da geri ödüyor. Döngüyü silmeden yatırımı ödüllendiriyor; **olduğu gibi kalsın.**
**Günlük ödül** (3 dk × 1–4) ve **mevsim ödülü** (90 sn) dengeli. Mevsimin "6 yatırım yap" hedefi geç oyunda zorlaşıyor; genişletme ve siparişleri de saysın.

### 4.9 Simülasyonu iyileştirme
- **Bugün modellenen:** açgözlü ideal oyuncu, anında toplama, tek çiftlik, nötr hava.
- **Eksik:** üretim, pet, eklenti ataması, sipariş/ürün, tüccar, altın hayvan, ödüller, eşyalar, çoklu çiftlik, hava/mevsim, çevrimdışı süre, yürüme süresi, geçişler.
- **Öneri (sırayla):**
  1. Varsayılan `--collect 120`; `--session 20m --offline 8h --sessions-per-day 3` (`computeOfflineEarnings` kullanarak).
  2. Üretim döngüsü: N sn'de bir en iyi partiyi yeniden başlat (pet varsa anında).
  3. Eklenti yeniden gönderme aralığı.
  4. Siparişler: 10 dk'da 9 teklif, simüle edilmiş ürünlerden.
  5. Altın hayvan, günlük ve mevsim ödül akışları.
  6. 2–6. çiftlikleri satın alma ve park mantığı.
  7. Oyuncu tipleri (idle / casual / hardcore): tepki gecikmesi ve karar kalitesiyle.
  8. Çıktı: X'e ulaşma süresi yüzdelikleri, dakikada eylem, depo dolu geçen sürenin yüzdesi.

### 4.10 Ölçülmesi gerekenler (canlı KPI)
- **Huni:** ilk hayvan, ilk yükseltme, ilk ada, Ahır 2/3/4, her ada, 2…6. çiftlik.
- **Depo:** oturumda depo dolu geçen süre, toplama anında depo/kapasite oranı, toplamaların yüzde kaçı platformda AFK.
- **Oturum:** süre, D1/D7/D30, çevrimdışı süreye karşı ödeme (kaçı sınıra takıldı).
- **Üretim:** parti boyutu dağılımı, bitiş ile yeniden başlatma arası boşta süre, pet alım zamanı.
- **Siparişler:** pencere başına teslim, taşmadan kaybolan ürün.
- **Ekonomi kaynak/gider:** hayvan, fabrika, sipariş, ödül, çevrimdışı, paket; yükseltme, hayvan, eşya, çiftlik, ırk.
- **Olaylar:** altın hayvan tıklama oranı, tüccar alımı, günlük seri dağılımı, mevsim hedefi tamamlama.
- **Kopma noktası:** son sahip olunan yükseltmeye göre oyunu bırakma.

---

## 5. Arayüz ve deneyim

| Bulgu | Önem · Efor | Kanıt | Öneri |
|---|---|---|---|
| **Ses büyük ölçüde boş:** 36 yuvadan 31'i boş, müzik yok; çalan 5 ses `rbxasset://` yer tutucusu | Yüksek · S (bağlama) / M (seçim) | `Config/Audio.luau:11-58` | Önce para, satın alma, yükseltme, ödül alma, ortam ve hayvan sesleri; müzik ayrı SoundGroup'ta |
| **Mobil:** güvenli alan yok (`IgnoreGuiInset = true`), global UIScale yok; kapat düğmesi 30 px, rozetler 20 px, `MinTextSize = 8`; koşu düğmesi zıplama düğmesiyle çakışabilir | Yüksek · M | `FarmHud.client.luau:57`, `Kit/Controls.luau:138,258,293-297`, `Sprint.client.luau:67` | `ScreenInsets = DeviceSafeInsets`; ekran boyutuna bağlı kök `UIScale` (telefonda ~0,85); dokunma hedefleri ≥ 44 px; `MinTextSize` ≥ 11 |
| Onboarding 3 adımda bitiyor; 1. ve 3. adım dünyada değil yalnızca HUD'da işaret ediyor; Adalar karosu yalnızca "kıdemli"ye açılıyor; 1,5 bin kazanç atlama kuralı tek eşya alanı kıdemli sayıyor | Orta · M | `Hud/Onboarding.luau:20,29-42`, `MenuBar.luau:217` | 4–6. adımlar (Yol Haritası, ilk genişletme, Üretim) dünyada ışın/ok ile; yeni karo açılınca "ilk kez açıldı" bildirimi |
| Robux mağaza penceresi hiç açılamıyor ama saniyede bir güncelleniyor | Orta · S | `FarmHud.client.luau:97-108,144,150,199-201` | Kimlik ≠ 0 ise karo; o zamana kadar `updateStore`'u atla |
| Ses düzeyi ve ReducedMotion kaydedilmiyor; tek ses sürgüsü | Orta · S | `SettingsMenu.luau:15,77,113`, `Sfx.luau:20-28` | `save.graphics` gibi kaydet; SFX / Ortam / Müzik grupları |
| Gamepad ile menüler açılamıyor | Orta · S | `FarmHud.client.luau:237-256` | `ContextActionService` ile DPad eşlemesi |
| İspanyolca ve Portekizce yok; Roblox otomatik çevirisi kapalı (`AutoLocalize = false`) | Orta · M | `Localizer.client.luau:60-62` | `es` ve `pt-br` sözlükleri (Roblox'un en büyük kitlelerinden; altyapı hazır) |
| Çeviri kalitesi iyi; Rusçada "ты/вы" karışık (24/22), Almancada belirsiz bir "es", kaynakta İngilizce "shop'u" | Düşük · S | `Locales/ru.luau`, `ShopWindow.luau:165` | Rusçada tek hitap biçimi |
| 14 pencere, 10 menü giriş noktası; aynı bildirimler birleşmiyor | Düşük · M | `Kit/Toasts.luau:126` | Aynı bildirimi "×3" olarak birleştir; Sipariş Panosu, Eşya Dükkânı ve Envanter sekmeli tek pencere olabilir |

İyi yapılanlar: tutarlı UiKit (token, varyant, autoGrid), pencereler ekrana sığacak şekilde kırpılıyor, kademeli karo açılışı, gamepad seçimi pencere kapanınca geri geliyor.

---

## 6. Kayıt ve operasyon

**Şu an (güçlü):**
- Atomik `UpdateAsync` kilit, sahip jetonu ve revizyon kontrolüyle (`SessionLock.luau:75-105`).
- Anahtar başına yazma sıralaması (`busyKeys`).
- `BindToClose`'da 25 sn bütçeyle paralel bırakma.
- Açık alan listesiyle encode (çalışma anı verisi kaydedilmiyor).
- Gelecek sürümü reddetme, dönüşümlü yedek, karantina, boyut uyarısı.
- Studio için ayrı `_Studio` store.

### 6.1 Robux satın alımı eski anlık görüntüyle "kaydedildi" sayılabiliyor — Yüksek (Robux açılmadan önce) · S
- `PlayerDataService.luau:154`: yeni yük yalnızca `not session.pending` ise üretiliyor. Önceki yazım başarısızsa eski yük yeniden kullanılıyor ve `save()` (`:497-506`) **true** dönüyor *(doğrulandı)*.
- `MonetizationService.luau:120-121` bunu "makbuz kalıcı" sayıp `PurchaseGranted` dönüyor. Sunucu sonraki kayıttan önce çökerse ödül kaybolur, Roblox makbuzu yeniden göndermez.
- **Öneri:** `save()` bırakma yolundaki gibi (`:265-267`) döngü kursun: işlenen anlık görüntünün `packetRevision`'ı güncel değilse tekrar yazsın.

### 6.2 Ödül verilemese bile makbuz günlüğe yazılıyor — Orta · S
- `MonetizationService.luau:112`: `ReceiptLog.add`, `applyProduct`'tan önce çalışıyor *(doğrulandı)*. `applyProduct` başarısızsa (yapılandırma hatası) Roblox'un tekrar denemesinde `has` true döner ve ödül hiç verilmeden `PurchaseGranted` döner.
- **Öneri:** Önce `product.effect`'i doğrula, ya da başarısızlıkta id'yi günlükten sil.

### 6.3 DataStore kesintisinde kira dolunca güvenle kaydedilebilecek ilerleme atılıyor — Orta · S
- `SessionLock.luau:96`: commit `expiresAt > now` istiyor. `PlayerDataService.luau:284-286`: kira (180 sn) dolunca oturum başarısız sayılıyor. 3 dakikadan uzun kesinti, son iyi kayıttan sonraki her şeyi kaybettirir.
- **Öneri:** `owner` ve `revision` hâlâ bizimse süresi dolmuş kiraya da yazmaya izin ver; başka sunucu ancak bunları değiştirerek devralabilir.

### 6.4 Diğer kayıt bulguları

| Bulgu | Önem | Kanıt | Öneri |
|---|---|---|---|
| Gamepass sorgusu hata verirse geçiş düşüyor | Düşük | `MonetizationService.luau:58-70` | Hata alanlar için önceki değeri koru, sonra tekrar dene |
| DataStore istek bütçesi hiç kontrol edilmiyor | Düşük | — | Bütçe düşükse yedek ve hızlı kaydı atla; bırakma ve makbuz kaydını asla atlama |
| `_session`/`version` bozuk kayıt yedeğe ulaşmadan reddediliyor | Düşük | `SessionLock.luau` acquire, `PlayerDataService.luau:422-438` | Yedekten kurtarmayı bu yola da bağla |
| Şema sürümü `4` iki yerde sabit yazılı | Düşük | `SessionLock.luau:6`, `SaveCodec.luau:762` | Tek sabit kullan |

### 6.5 Telemetri — Yüksek · M
- `Metrics.luau` yalnızca sunucu başına `ServerStorage.Diagnostics` özniteliklerine yazıyor; sunucu kapanınca kayboluyor, toplanmıyor. `AnalyticsService` hiç yok.
- **Öneri:**
  - `LogOnboardingFunnelStepEvent`: ilk toplama, ilk hayvan, ilk yükseltme, ilk ada.
  - `LogEconomyEvent`: 4.10'daki kaynak ve giderler.
  - `LogProgressionEvent`: ada ve çiftlik açılışları.
  - Kayıt hataları, kurtarma ve `FinalSaveFailed` için özel olaylar. Bunlar `warn` yerine `error` seviyesinde olsun ki Creator Hub hata raporunda görünsün.

### 6.6 Canlı güncelleme ve geri alma
- Sürüm etiketi ve değişiklik günlüğü yok. `SaveCodec` gelecek sürümü reddettiği için **geri alma, şema yükselten bir sürümden sonra yapılamaz.**
- **Öneri:** Her yayını `place-vN` olarak etiketle (mesajda `MAP_VERSION`). Şema yükseltmesini ayrı bir sürümde yap; önce "okuyabilen ama hâlâ eski şemayı yazan" sürümü yayınla, sonra yeni şemayı yazan sürümü. Böylece bir sürüm geri dönülebilir.

---

## 7. Test ve geliştirme süreci

### 7.1 README'de bayat ve yanlış bilgiler — Yüksek · S
- `README.md:52` "Max Players 1 yap" diyor; kod ve belgeler 6 diyor (`Core.luau:36`, `LOBI_VE_ADA_MIMARISI.md:9`). **Yayında oyunu bozar.**
- `:57` gerçek olmayan bir günlük metni alıntılıyor.
- `:127` çiftlik fiyatları yanlış (gerçeği `{0, 12000, 25000, 50000, 100000, 167000}`).
- "Çiftliğim" menüsünden 7 kez söz ediliyor; bu menü artık kodda yok.
- **Öneri:** Bölümleri yeniden yaz, sabit rakamları `Config`'e işaretle değiştir.

### 7.2 CI yok — Yüksek · S
- `.github/workflows/` yok. 116 commit'in 110'u son iki günde atılmış. Her şey `verify.ps1`'i hatırlamaya bağlı.
- **Öneri:** `windows-latest` üzerinde GitHub Actions: `rokit install`, Luau ve luau-lsp kur, `verify.ps1` çalıştır.

### 7.3 En çok para alan servislerin servis testi yok — Yüksek · M
- `AnimalService`, `UpgradeService`, `InventoryService`, `EngagementService`, `MonetizationService` (yalnızca `ReceiptLog` var), `PetService`, `BuyPadService` `run-tests.py`'de yüklenmiyor.
- **Öneri:** Mevcut fabrika kalıbıyla sahip / parası yok / tekrar / yanlış çiftlik / hız sınırı testleri. 2.1 (döngü koruması) ve 6.1–6.2 (makbuz) için de regresyon testi.

### 7.4 Studio testleri elle — Orta · M
- `tests/run.server.luau` 27 spec'ten yalnızca 2'sini çalıştırıyor. `map-structure` ve `world` spec'leri yalnızca eklenti düğmesiyle çalışıyor (hâlâ bekliyor).
- **Öneri:** Open Cloud **Luau Execution** ile `test.project.json`'dan kurulan test place'inde sunucu tarafı spec'ler + `MapBuilder.build` + `world.spec` (CI'a bağlanabilir). Kısa vadede `run.server.luau` bütün saf spec'leri çalıştırsın.

### 7.5 Belge sürdürülebilirliği — Düşük · S
- Tek kaynak + yönlendirme yapısı iyi ve `check-ai-docs.py` ile denetleniyor.
- `docs/MIMARI.md` dosya listeleri kaymış: 12 dosya eksik (PetService, AnimalTaskService, HubBoardService, DecorReveal, StartupGate, BridgeBoost…). `check-ai-docs.py` listede olmayan dosyayı yakalasın.
- `economy-data.mdc` (176 satır) değişiklik günlüğüne dönüşüyor ve sabit süreler içeriyor (satır 41, 70, 139-154); README gibi bayatlayacak. Rakamlar yerine `Config` anahtar adları kullan.
- `docs/URETIM_VE_UZMAN_ADALAR.md`'deki tablo `Config/Production.luau` ile uyuşmuyor.

### 7.6 Commit hijyeni — Düşük · S
- Commit başlıkları uzun; tek commit 4 farklı iş içeriyor (örn. `98ab3d6`).
- **Öneri:** Commit başına tek konu, `feat:` / `fix:` / `balance:` / `map:` öneki. `MAP_VERSION` artışı ayrı commit.

### 7.7 Eklentinin kopyala-require yaklaşımı kırılgan — Düşük-Orta · S
- `plugin/MapTool.server.luau:174-199` önbellekten kaçmak için akıllıca. Ama `World`'den `Modules`/`Presentation`'a giden bir require sessizce canlı kopyaya düşer ya da `WaitForChild`'da asılı kalır.
- **Öneri:** "World yalnızca World/Shared'ı require eder" kuralını `check-architecture.py`'ye ekle. `plugin/` değişip eklenti derlenmediyse `verify.ps1` uyarsın.

---

## 8. Yayın ve büyüme

### 8.1 Keşif ve tutunma eksikleri — Yüksek · M–L
- **İlk dakika:** 75 $ ile tek inek, yarım saat yetişkin hayvan yok, ses yok. İlk 60 saniyede bir "vay" anı yok. 4.7 ve 5'teki ses işi en ucuz kazanç.
- **Geri dönüş kancası:** çevrimdışı gelir (4.2) + günlük ödül. Günlük ödül var; çevrimdışı kanca yok.
- **Sosyal:** sunucu sıralama panosu var (`HubBuilder.luau:174`). Kalıcı küresel sıralama (OrderedDataStore), ada ziyareti, arkadaşa beğeni/hediye yok. 6 kişilik sunucu sosyal bir alan; bundan yararlan, ya da lobi kararını telemetriye göre ver.
- **Etkinlikler:** mevsimler var. Haftalık etkinlik veya sınırlı süreli hayvan yok; canlı operasyon başladığında `Config` yapısı bunu kolaylaştırır.
- **Roblox önerileri:** oturum süresi ve D1 tutunma keşfi belirler. 4.1 ve 4.2 burada doğrudan etkili.

### 8.2 Para kazanma planı — Orta · S
- **Planlanan:** 2× gelir, otomatik toplayıcı, +%50 depo geçişleri; anında üretim ve 1 saatlik gelir ürünleri. Kimlikler 0.
- **Risk:** 4.1–4.3 düzelmeden otomatik toplayıcı geçişi sıradan oyuncuya 2–6× gelir değerinde. Bu kolaylık değil, **pay-to-win**. Anında üretim, kalan süreye bakmadan tam ödeme veriyor.
- **Öneri:**
  1. Önce tasmayı düzelt (4.1–4.3), sonra geçişleri aç.
  2. Anında üretimi kalan süreyle fiyatla.
  3. Robux kozmetikleri ekle (şapka sistemi hazır).
  4. 30 dk'lık zamanlı 2× güçlendirme ve başlangıç paketi.
  5. Sıralama panosunu ücretli çarpanlardan ayır.
  6. Önce 6.1–6.2'yi düzelt.

### 8.3 Etik ve çocuk güvenliği — Düşük · S
- Sohbet ve metin girişi yok, kullanıcı içeriği yok; risk düşük.
- Deneyim anketini (Maturity & Compliance Questionnaire) doldur. Muhtemelen "Minimal" etiketi alır.
- Ücretli rastgele ödül (loot box) yok; öyle kalsın. Ülke kısıtlamaları için ücretli rastgele öğe ekleme.
- Bildirimlerde ve geri sayımlarda "acele et, kaçırırsın" baskısını (FOMO) çocuklara yönelik abartma.

---

## Önerilen sıralı yol haritası

### İlk 1 hafta (çoğu S efor; hataları kapat, dengeyi düzelt)
1. Ekonomi, büyüme ve mevsim döngülerine oyuncu başına `pcall` (2.1) + test.
2. Keçi adası eklenti klasörü / imza hatası (2.2).
3. Çiftlik seçimine 5–10 sn bekleme süresi (2.4); çıkışta yeniden giydirmeyi kaldır, çift `refreshPlayerWorld`'ü sil (2.3).
4. Eklenti/BuyPad prompt'larına hız sınırı (1.5).
5. Depo kapasitesi ~×5 (ya da gelir × 600 sn) ve Otomatik Toplayıcı fiyatı (4.1); temel çevrimdışı gelir (4.2). Simülasyon varsayılanı `--collect 120`.
6. `EngagementService` tam push sıklığını düşür (3.1, ilk madde).
7. Makbuz akışı: 6.1 ve 6.2; süresi dolmuş kirada yazma (6.3); kilit tutuluyken giriş için geri çekilerek tekrar deneme.
8. README düzeltmesi (7.1); Game Settings → Max Players = 6.
9. Bekleyen Studio doğrulaması: haritayı yeniden kur, `map-structure` ve `world` spec'lerini çalıştır, yeni özellikleri dene.

### İlk 1 ay
1. `AnalyticsService` hunisi ve ekonomi/ilerleme olayları; kayıt hataları `error` seviyesinde (6.5).
2. Simülasyonu genişlet: oturum/çevrimdışı, üretim, sipariş, çoklu çiftlik, oyuncu tipleri (4.9).
3. Park edilmiş çiftlik geliri (4.3), çiftlik başına maliyet çarpanı (4.4), altın hayvan ölçeklemesi.
4. `pushState` birleştirme ve park edilmiş çiftlikleri özetle gönderme (3.1); streaming yarıçapı (3.2).
5. İstemci: AnimalAnimator `BulkMoveTo`, Localizer `setText` + LRU, gece ışığı kalitesi, pet uykusu (3.3).
6. Mobil güvenli alan + UIScale + dokunma hedefleri; ses yuvalarını doldur, ses ayarlarını kaydet (5).
7. Onboarding 4–6. adımlar (5).
8. CI (7.2); Animal/Upgrade/Monetization servis testleri (7.3); `RequestGuard` (1.1); `SharedRef` tip dönüşümü (1.3).

### İlk 3 ay
1. Hazır tema şablonları + temaya göre ada seçimi (2.4, 2.5).
2. Geç oyun yapısı: ırk ve eşyayı ayrı çarpan yap; 3. tema ada sırası; ada temposu (4.5, 4.6).
3. Robux açılışı: kozmetikler, zamanlı güçlendirme, başlangıç paketi; geçişler ancak tasma düzeldikten sonra (8.2).
4. `es` ve `pt-br` dilleri (5).
5. Open Cloud Luau Execution ile Studio testlerini CI'a bağla (7.4).
6. `SaveCodec`/`PlayerDataService` bölme (1.4); Presentation ↔ Services döngüsünü kır (1.2).
7. Telemetri verisine göre lobi / rezerve sunucu / ziyaret kararı (2.5, 8.1).

## Bilerek yapmamamız gerekenler
- **Tasma (4.1–4.3) düzelmeden Otomatik Toplayıcı ya da 2× gelir geçişini açmak.** Pay-to-win olur ve ilk izlenimi zehirler.
- **Telemetri gelmeden yeni ada, hayvan veya çiftlik eklemek.** Oyuncular sorunu içerik azlığında değil tempoda yaşıyor olabilir.
- **6 temayı her adaya önceden yerleştirip görünürlükle değiştirmek.** Yaklaşık 6 kat instance.
- **Hareket ve konumu sunucu otoriteli yapmaya çalışmak.** Kazanılacak bir istismar yok; gecikme ve karmaşıklık getirir.
- **Tip borcunu sıfırlamaya çalışmak.** Yalnızca ucuz %75'i (SharedRef + döngü) ve gerçek ~100 bulguyu düzelt; `pcall` yanlış pozitiflerini temel listede bırak.
- **Lobiyi tutunma verisi olmadan kurmak.** Pahalı ve geri dönüşü zor bir mimari karar.
- **Daha fazla pencere eklemek.** Yeni özellikler mevcut pencerelere sekme olarak girsin.
- **Kayıt şemasını yükseltip aynı sürümde yeni şemayı yazmak.** Geri alma imkânı kalmaz (6.6).
