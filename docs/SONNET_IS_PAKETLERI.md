# Sonnet 5.5 iş paketleri (maliyet odaklı yol haritası)

Kaynak: `docs/ANALIZ_RAPORU.md` (bölüm numaraları ona göre). Her paket **yeni bir Sonnet 5.5 oturumunda** çalıştırılır.
Yapıştırılacak metin her paketin altındaki kod bloğudur. Uzun konuşmayı sürdürmek yerine her pakette yeni oturum aç (bağlam küçük kalır, ucuzdur).

## Nasıl kullanılır
1. Claude masaüstü → aynı klasör → yeni Code oturumu → model **Sonnet 5.5**, izin modu otomatik kabul.
2. Paketin prompt'unu yapıştır. Bitince Sonnet rapor verir.
3. **İnceleme:**
   - "Opus incelemesi: evet" yazan paketlerde yeni bir **Opus** oturumu aç ve en alttaki "Opus inceleme prompt'u"nu yapıştır.
   - Diğerlerinde yeni bir **Sonnet** oturumunda "Sonnet inceleme prompt'u"nu yapıştır.
4. İnceleme temizse dalı main'e al (prompt'larda var). "Studio" yazan noktalarda önce sen Studio'da dene.
5. Push etmek senin kararın; Sonnet push etmez.

## Sıra ve kontrol noktaları

| # | Paket | Opus incelemesi | Senden gereken |
|---|---|---|---|
| P0 | Küçük düzeltmeler + `fix/analiz-hafta1`'i main'e al | hayır | — |
| ★ | **Studio turu 1** (P0 sonrası) | — | Studio'da dene (liste P0 raporunda) |
| P1 | Telemetri (AnalyticsService) | hayır | — |
| P2 | Ekonomi simülasyonunu genişlet | hayır | — |
| P3 | Ekonomi 2. tur (çiftlik çarpanı, altın hayvan, siparişler, eklenti süresi, 3. tema) | **evet** | P2 bitmiş olmalı |
| P4 | Ağ ve sunucu performansı (pushState, streaming) | **evet** | Sonra Studio'da dene |
| P5 | İstemci performansı | hayır | Sonra Studio'da dene |
| P6 | Mobil arayüz + ses ayarlarının kaydı + gamepad | hayır | Ses kimliklerini sen seç (Creator Store) |
| P7 | Onboarding 4-6 + bildirim birleştirme | hayır | — |
| ★ | **Studio turu 2** (P4-P7 sonrası) | — | Telefon emülatörü dahil dene |
| P8 | Kod kalitesi + servis testleri | hayır | — |
| P9 | CI (GitHub Actions) | hayır | Push sonrası Actions sekmesine bak |
| P10 | Geç oyun yapısı (ırk/eşya ayrı çarpan) | **evet** | P2 ve P3 bitmiş olmalı |
| P11 | Hazır tema şablonları | **evet** | Büyük iş; Studio'da kapsamlı dene |
| P12 | İspanyolca ve Portekizce | hayır | — |
| K1 | Admin komut kısıtlaması | — | **Karar:** canlıda admin kullanacak mısın? |
| K2 | Robux açılışı | — | **Karar + ürün kimlikleri** (P3 sonrası) |
| K3 | Lobi / rezerve sunucu | — | **Karar:** P1 verisi 2-4 hafta birikince |

K paketleri için karar verdiğinde Sonnet'e "docs/ANALIZ_RAPORU.md bölüm X'i şu kararla uygula" demen yeterli. Ortak kurallar yine geçerli.

---

## Ortak kurallar (her prompt bunu okutur)
- `CLAUDE.md`, `AGENTS.md`, `docs/MIMARI.md` ve `docs/ANALIZ_RAPORU.md`'nin ilgili bölümlerini oku. AGENTS.md'deki tabloya göre dokunduğun dosyanın kural dosyasını bir kez oku. İlgili `.cursor/skills/<ad>/SKILL.md` varsa (remote, ui, content, map, localize, save-schema) onu izle.
- Main'den `git checkout -b <paket-dalı>` ile çalış. Her madde ayrı commit (`fix:` / `feat:` / `balance:` / `perf:` / `test:` / `docs:` öneki, kısa Türkçe başlık). Push etme.
- Her maddeden sonra: `stylua src tests plugin` → `selene src` → `python scripts/run-tests.py`. Bitirirken `powershell -ExecutionPolicy Bypass -File scripts/verify.ps1` temiz olmalı.
- Yeni oyuncu metni → en/de/ru çevirisi. Kayıt alanı değişirse `roblox-save-schema` skill'i. `src/server/World` veya `plugin/` değişirse raporda "eklentiyi yeniden derle" de. Harita düzeni değişirse `MAP_VERSION` artır.
- Soru sormak için durma. Riskli ya da belirsiz maddeyi atla, gerekçeyi yaz, devam et. Kapsam dışına çıkma; gördüğün sorunları yalnızca not et.
- **Rapor biçimi (kısa tut):**
  1. Özet (3 satır).
  2. Madde tablosu: # | Durum | Commit | Dosyalar | Testler.
  3. Sapmalar.
  4. verify.ps1 son satırı.
  5. Studio'da denenecekler.
  6. Açık sorular.
  7. `git log --oneline main..HEAD`.

---

## P0 — Küçük düzeltmeler ve birleştirme
```text
docs/SONNET_IS_PAKETLERI.md içindeki "Ortak kurallar"ı oku ve uy. İstisna: bu pakette yeni dal açma, mevcut fix/analiz-hafta1 dalında çalış.
0. Henüz commit'lenmemiş docs/SONNET_IS_PAKETLERI.md dosyasını "docs: Sonnet iş paketleri" ile commit'le.
1. src/server/init.server.luau: kayıt yüklenemeyince yapılan Kick'te, RunService:IsStudio() ise mesajın sonuna oyuncunun DataError özniteliğini ekle (Studio'da API erişimi kapalıyken neden görünsün). Canlıda mesaj aynı kalsın.
2. README.md: "2 yetişkin hayvan, $100" gibi başlangıç bilgisini gerçek değerlere göre düzelt (Config.STARTING_COW_COUNT, Config.getStartingCash). Rakam yazmak yerine Config adına işaret etmek tercih.
3. src/shared/Config/init.luau: Pasif Gelir (offline_income) açıklaması %25/%50 ve 2/8 saat rakamlarını elle yazıyor. Metni Config.OFFLINE_* değerlerinden üret. Çeviri sözlüğü kalıbına uy ({} boşlukları); en/de/ru anahtarlarını güncelle; `python scripts/check-locales.py --strict-literals` temiz olsun.
4. src/server/Services/MonetizationService.luau: processReceipt'teki izinli efekt listesi ("instantProduction"/"incomePack") applyProduct'tan ayrı yazılmış. Tek kaynak yap (ör. applyProduct'ın desteklediği efektler tablosu ve bir isSupported fonksiyonu). Mevcut testler geçsin.
5. verify.ps1 temizse: `git checkout main` ve `git merge --ff-only fix/analiz-hafta1`. ff-only olmazsa birleştirme, rapora yaz.
Raporun "Studio'da denenecekler" bölümüne fix/analiz-hafta1 değişikliklerinin listesini de koy: keçi adası eklenti tabelaları, çiftlik değiştirme 6 sn bildirimi, oyuncu çıkınca ada boşalması, prompt spam, çevrimdışı dönüş tutarları (Pasif Gelir varken/yokken), yeni depo kapasiteleri.
```

## P1 — Telemetri
```text
docs/SONNET_IS_PAKETLERI.md "Ortak kurallar"a uy. Dal: feat/telemetri. Kapsam: docs/ANALIZ_RAPORU.md 6.5 ve 4.10.
Amaç: Roblox AnalyticsService ile canlı oyunun ölçülebilmesi. Her şey sunucu tarafında.
1. Roblox'un AnalyticsService'iyle karışmasın diye `src/server/Services/TelemetryService.luau` adıyla kur (Services katmanı). AnalyticsService çağrıları pcall içinde olsun, Studio'da yalnızca print/Metrics'e yazsın (canlı veriyi kirletmesin). Saf yardımcı mantık (olay adları, değer yuvarlama) varsa Modules/ altında ve test edilebilir olsun.
2. Onboarding hunisi (LogOnboardingFunnelStepEvent, oyuncu başına bir kez): ilk toplama, ilk hayvan, ilk yükseltme, ilk ada, Ahır 2. Adım bilgisi kayıtta tutulacaksa roblox-save-schema skill'ine uy.
3. Ekonomi (LogEconomyEvent): kaynaklar (toplama/otomatik toplama, çevrimdışı, günlük, mevsim, altın hayvan, sipariş, üretim, iade) ve giderler (hayvan, yükseltme, eşya, çiftlik, ırk). Yüksek frekanslı kaynaklar (toplama, otomatik toplama) her olayda değil, oyuncu başına toplanıp 60 sn'de bir gönderilsin; AnalyticsService limitlerini aşma.
4. İlerleme (LogProgressionEvent veya Custom): ada ve çiftlik açılışları.
5. Custom olaylar: oturum süresi (çıkışta), çevrimdışı süre ve ödeme, depo dolu geçen süre (oturum başına toplam saniye), kayıt hataları (SaveFailed, FinalSaveFailed, ProfileRecovered, LoadLockWait, LoopError).
6. Kayıt veri kaybı riski taşıyan hatalar (FinalSaveAbandoned, ProfileRecovered, fail()) warn yerine Creator Hub'da görünecek şekilde loglansın (ör. task.spawn(error, ...) ile, akışı bozmadan).
7. Testler: olay toplama/yuvarlama mantığı ve "Studio'da gönderme" davranışı.
8. docs/ altına kısa bir TELEMETRI.md: olay listesi, Creator Hub'da nerede görüleceği.
```

## P2 — Ekonomi simülasyonu
```text
docs/SONNET_IS_PAKETLERI.md "Ortak kurallar"a uy. Dal: feat/sim-genislet. Kapsam: docs/ANALIZ_RAPORU.md 4.9. Yalnızca scripts/simulate-economy.py ve onun Luau şablonu; oyun koduna dokunma.
Simülasyon gerçek FarmMath'i kullanmaya devam etsin (Python'a formül kopyalama).
Ekle:
1. Oturumlar: --session (dk), --offline (saat), --sessions-per-day; çevrimdışı kazanç FarmMath.computeOfflineEarnings ile.
2. Üretim: her N sn'de (--prod-interval) en iyi parti yeniden başlar; ilgili yardımcı (pet) alınmışsa anında.
3. Eklenti ataması ve --ext-interval ile yeniden gönderme.
4. Siparişler: Config'teki pencere ve teklif sayısıyla simüle ürünlerden teslim.
5. Altın hayvan, günlük ve mevsim ödülü akışları (Config/Rewards/Golden mantığıyla).
6. 2-6. çiftlikleri satın alma ve park edilmiş çiftlik geliri (EconomyService.settlePlayer mantığıyla aynı).
7. Oyuncu tipleri: --persona idle|casual|hardcore (tepki gecikmesi, toplama aralığı, oturum düzeni ön ayarları).
8. Çıktı: mevcut kilometre taşları + dakikada eylem, depo dolu geçen süre yüzdesi, gelir kaynağı payları; --json ile makine okunur çıktı.
Rapora üç persona için 6 saatlik ve 7 günlük (oturumlu) özet tabloyu koy. Varsayılan çıktı formatını bozma (eski kullanım çalışsın).
```

## P3 — Ekonomi 2. tur (Opus incelemesi: evet)
```text
docs/SONNET_IS_PAKETLERI.md "Ortak kurallar"a uy. Dal: balance/tur2. Kapsam: docs/ANALIZ_RAPORU.md 4.3, 4.4, 4.6, 4.8 tablosu. Önce .cursor/skills/roblox-add-content/SKILL.md ve economy-data.mdc'yi oku.
Her maddeden önce ve sonra P2'deki simülasyonu (casual persona, 7 gün oturumlu + ideal 6 saat) çalıştır, rakamları rapora koy.
1. Çiftlik başına maliyet çarpanı (4.4): yükseltme ve hayvan fiyatlarına çiftlik numarasına göre çarpan (Config'te tek sabit, başlangıç ×8/çiftlik; sim ile 2. çiftliğin ilk 2 saatinin "saniyeler" değil anlamlı sürmesini hedefle). FarmMath/Core getUpgradeCost ve hayvan fiyatı.
2. Park edilmiş çiftlik (4.3): Otomatik Toplayıcı yoksa park edilmiş çiftliğin geliri %50 oranla doğrudan kasaya (EconomyService.settlePlayer). Oran Config'te.
3. Altın hayvan ödülü: tek hayvan × 150 sn yerine toplam gelir × 90 sn (Golden.luau / Config).
4. Ürün taşması: başlatılan partinin ürünü ahır deposuna sığmayacaksa başlatmayı reddet ve açık mesaj ver (FarmMath/Goods + ProductionService).
5. Siparişler: ödül = max(ürün değeri, gelir × 120 sn) (sabit Config'te).
6. Eklenti kalış süresi 120 → 360 sn, toplam bonus aynı kalacak şekilde çarpanı ayarla.
7. 3. tema (Ayçiçeği, Config/Islands.luau ~127-132): poultry yerine Ahır 3 gerektiren bir ada (koyun ya da at), "erken/orta/geç" yorumuna uy. Ada temposu: At adası tabanı 3500→2800, Ahır 4 6000→5000.
Tüm sabitler Config'te; economy-data.mdc'yi rakam değil Config adıyla güncelle. Kayıt şeması değişirse roblox-save-schema.
Raporda her madde için "önce/sonra" sim tablosu ve beklenmeyen etkiler.
```

## P4 — Ağ ve sunucu performansı (Opus incelemesi: evet)
```text
docs/SONNET_IS_PAKETLERI.md "Ortak kurallar"a uy. Dal: perf/sunucu-ag. Kapsam: docs/ANALIZ_RAPORU.md 3.1, 3.2, 2.6 (hayvan yuvası).
1. pushState birleştirme: PlayerDataService.pushState çağrıları oyuncu başına kirli bayrak + task.defer ile en çok 0,25 sn'de bir gönderilsin. İstemci davranışı (ClientState) bozulmasın; satın alma yanıtları gecikmeyle sorun çıkarmasın.
2. Park edilmiş çiftlikler istemciye yalnızca özet olarak (istemcinin gerçekten okuduğu alanlar; önce src/client'ta mainFarms kullanımını grep'le). Paylaşılan tabloların iki kez serileşmesini önle.
3. AnimalService.updateGrowth: refreshPlayerWorld yalnızca etkin çiftlik değiştiğinde.
4. default.project.json streaming: StreamingMinRadius 160, StreamingTargetRadius 448. İstemcide uzak ada parçalarına WaitForChild ile kilitlenen kod varsa FindFirstChild'a çevir ve listele.
5. AnimalVisualService (~128-188): yeni hayvanın yuva hesabı bölgedeki tüm görünür hayvanları saysın.
6. Test: birleştirme mantığı (sahte zamanlayıcı ile) ve özet içeriği.
Raporda: pushState'in yaklaşık boyutu önce/sonra (encode ederek ölç), Studio'da denenecekler (uzak adalar görünüyor mu, satın alma tepkisi gecikiyor mu).
```

## P5 — İstemci performansı
```text
docs/SONNET_IS_PAKETLERI.md "Ortak kurallar"a uy (client-performance.mdc ve client-ui.mdc'yi oku). Dal: perf/istemci. Kapsam: docs/ANALIZ_RAPORU.md 3.3 tablosu (6 madde).
1. AnimalAnimator: tek Workspace:BulkMoveTo toplu taşıma (SeabedLife örnek), RenderStepped → PreRender, düşük kalitede 50 stud ve en çok 20 hareketli hayvan (Config ya da EffectSettings).
2. Localizer: kaynak metin değişmediyse yazmayan bir setText yardımcısı (Ui katmanında) ve HUD sıcak yollarında (StatsPanel, RewardsSection, collector etiketi) kullanımı; Localization önbelleğini tam silme yerine LRU/iki kuşaklı yap; Workspace'te yalnızca BillboardGui/SurfaceGui altını izle.
3. DayNight: düşük kalitede PointLight/SpotLight kapalı (yalnızca Neon/renk), orta kalitede kameraya en yakın N ışık; 3 sn'lik toplu yazım yalnızca değer değişince.
4. PetAnimator: kameraya 120 stud'dan uzaksa 0,5 sn uyku; yol grafiği ada başına önbellek.
5. SeabedLife: kamera su seviyesinin çok üstündeyse 15 Hz; düşükte yosun/baloncuk kapalı; denizanası Size yerine ölçek ya da düşük/ortada kapalı.
6. FarmHud: onState'teki tekrarlanan updateRewards/updateBoard çağrılarını kaldır; pencere kapalıyken yalnızca rozet sayısı.
EffectsQuality ve ReducedMotion kurallarını koru. Raporda Studio'da denenecekler (MicroProfiler ile önce/sonra bakılacak yerler).
```

## P6 — Mobil, ses ayarları, gamepad
```text
docs/SONNET_IS_PAKETLERI.md "Ortak kurallar"a uy (client-ui.mdc, roblox-add-ui ve roblox-save-schema skill'leri). Dal: feat/mobil-ses. Kapsam: docs/ANALIZ_RAPORU.md bölüm 5 tablosunun mobil, ses ayarı ve gamepad satırları.
1. HUD ScreenGui'leri ScreenInsets = DeviceSafeInsets (yalnızca üst çubuk kenardan kenara kalabilir); ekran boyutuna bağlı kök UIScale (telefonda ~0,85, 1440p+ için >1) UiKit/Tokens'ta tek yerden.
2. Dokunma hedefleri ≥ 44 px (kapat düğmesi, rozet tıklama alanı), MinTextSize ≥ 11. Sprint dokunma düğmesi zıplama düğmesiyle çakışmasın.
3. Ses: SoundGroup'ları SFX / Ortam / Müzik olarak ayır; Ayarlar'da üç sürgü. Ses düzeyleri ve ReducedMotion kayda yazılsın (save.graphics/save.language kalıbı, yeni remote gerekiyorsa roblox-add-remote). Müzik için Config/Audio'ya boş bir müzik yuvası (kimliği kullanıcı girecek).
4. Gamepad: ContextActionService ile DPad Yukarı=Pazar, Sağ=Yükseltmeler, Sol=Adalar, Aşağı=Envanter; menü karolarında NextSelection*.
Ses kimliği SEÇME (kullanıcı seçecek); yalnızca altyapı. Raporda telefon emülatöründe (Studio Device Emulator) denenecekler.
```

## P7 — Onboarding ve geri bildirim
```text
docs/SONNET_IS_PAKETLERI.md "Ortak kurallar"a uy (client-ui.mdc, roblox-add-ui). Dal: feat/onboarding. Kapsam: docs/ANALIZ_RAPORU.md bölüm 5 tablosunun onboarding, mağaza penceresi ve bildirim satırları.
1. Hud/Onboarding.luau: 1. ve 3. adımda HUD vurgusuna ek olarak dünyada işaret (pazar tezgâhına / yapım alanına ışın veya billboard ok; CollectorGuide kalıbı).
2. 4-6. adımlar: Yol Haritası'nı aç, ilk genişletme, Üretim'de ilk parti; her adımda tek satır "neden" açıklaması. "Kıdemli" atlama kuralını (1,5 bin kazanç) adım ilerlemesine göre düzelt.
3. Yeni menü karosu açılınca bir kez "yeni açıldı" bildirimi + karo nabzı.
4. Aynı metinli bildirimler birleşsin ("×3"), Kit/Toasts.
5. Robux mağaza penceresi: Config/Shop'ta en az bir kimlik ≠ 0 ise menü karosu görünsün; değilse updateStore hiç çalışmasın.
Yeni metinlerin çevirileri. Raporda yeni oyuncu akışını Studio'da (yeni kayıtla) adım adım deneme listesi.
```

## P8 — Kod kalitesi ve testler
```text
docs/SONNET_IS_PAKETLERI.md "Ortak kurallar"a uy (tests-tooling.mdc). Dal: refactor/kalite. Kapsam: docs/ANALIZ_RAPORU.md 1.1, 1.2, 1.3, 7.3, 7.5 (MIMARI listeleri), 7.7 ve 1.3 sonundaki verify notu. Davranış değiştirme.
1. Servis testleri: AnimalService, UpgradeService, InventoryService, EngagementService, MonetizationService, BuyPadService için run-tests.py fabrika girdileri ve spec'ler (sahip / parası yok / tekrar istek / yanlış çiftlik / hız sınırı; Engagement için mevsim imzası %1 yuvarlaması). Önce testleri yaz, sonra refactor yap.
2. Services/RequestGuard.luau: "etkin çiftlik değişti" kontrolü ve throttle→PurchaseResult/Notify yanıt bloğu tek yerde; kopyaları buna geçir.
3. CollectorVisualService'in dosya başı require'larını tembel yap; check-architecture.py izinli dosyada bile dosya başındaki yukarı yönlü require'ı yakalasın; World'ün yalnızca World/Shared'ı require etmesini denetlesin.
4. World/SharedRef.luau ile Shared araması tek yerde ve `:: typeof(ReplicatedStorage.Shared)` dönüşümlü; plugin kopyalama davranışı bozulmasın (plugin/MapTool.server.luau'yu oku). check-types.py ile düşen bulguları scripts/types-baseline.json'dan çıkar (yeni bulgu ekleme). Eklentiyi yeniden derleme notu.
5. verify.ps1: luau-lsp yoksa tip denetimini atlarken görünür uyarı bassın.
6. check-ai-docs.py: docs/MIMARI.md'deki dosya listeleri ile klasörleri karşılaştırsın; eksik dosyaları MIMARI.md'ye ekle.
Raporda tip bulgu sayısı önce/sonra.
```

## P9 — CI
```text
docs/SONNET_IS_PAKETLERI.md "Ortak kurallar"a uy. Dal: ci/github-actions. Kapsam: docs/ANALIZ_RAPORU.md 7.2.
.github/workflows/verify.yml: push ve pull_request'te windows-latest; rokit ile rokit.toml araçları (resmî kurulum yöntemini kullan), Python, scripts/setup-types.ps1 ile Luau + luau-lsp, sonra scripts/verify.ps1. Araç önbelleği (actions/cache). Gizli anahtar gerekmez.
Yerelde çalıştırılabilecek kadarını dene (verify.ps1); workflow sözdizimini dikkatle kontrol et. Push etme; raporda kullanıcının push sonrası Actions sekmesinde neye bakacağını yaz.
README'ye kısa CI bölümü.
```

## P10 — Geç oyun yapısı (Opus incelemesi: evet)
```text
docs/SONNET_IS_PAKETLERI.md "Ortak kurallar"a uy (economy-data.mdc). Dal: balance/gec-oyun. Kapsam: docs/ANALIZ_RAPORU.md 4.5 ve 4.8 (elmas çekiç).
1. Irk geliştirme (lineage) ve eşya gelir bonuslarını mevcut toplanan bonus toplamından çıkarıp ayrı çarpan olarak uygula: gelir = taban × (1 + diğer bonuslar) × (1 + ırk) × (1 + eşya). FarmMath/Income ve Core.getBonus; istemcide gösterilen gelir de aynı formülü kullansın.
2. Bu değişiklik geliri artırır: sim ile (ideal 12 saat + casual 7 gün) ırk maliyet büyümesini (1,85×) yeniden ayarla; hedef: her ırk seviyesi geri dönüşü ≤ 2 saat, 6-12. saat arası gelir artışı ≥ %50.
3. Elmas çekiç 5M → 2,5M.
Raporda önce/sonra sim tabloları ve değişen sabitler.
```

## P11 — Hazır tema şablonları (Opus incelemesi: evet)
```text
docs/SONNET_IS_PAKETLERI.md "Ortak kurallar"a uy (world-map.mdc, roblox-map-change skill). Dal: feat/tema-sablonlari. Kapsam: docs/ANALIZ_RAPORU.md 2.4 ve 2.5 (önerilen yol).
Hedef: çiftlik değiştirme ve girişte yordamsal yeniden kurulum yerine hazır şablon kopyalama.
1. MapBuilder.applyTheme'in kurduğu tema içeriğini (BuildSpots, Decor, Islands, ev dışı bölgeler) tema başına bir kez ServerStorage altında bir şablona kur (sunucu açılışında; eklenti haritayı kurarken de üretilebilir; hangisi olduğunu gerekçelendir). Geçişte: eskiyi sil, şablonu Clone + PivotTo (plot çerçevesi) + parent.
2. WorldDecor.optimize yalnızca yeni alt ağaçta çalışsın (ya da şablonda bir kez).
3. Sonuç eski yordamsal kurulumla aynı olmalı: map-structure.spec ve world.spec mantığını kullanan bir karşılaştırma (instance adları/sayıları, öznitelikler) ekle.
4. findFreePlot: kayıt yüklenmeden tema bilinmediği için şimdilik dokunma; ama PlotService akışında gereksiz yeniden kurulum kalmasın.
5. MAP_VERSION artır, eklentiyi yeniden derleme notu.
Bu büyük ve riskli bir iş: emin olmadığın adımda dur, yaptığın kısmı commit'le ve raporla. Raporda ayrıntılı Studio test listesi (tema döngüsü, 2 istemci, giriş/çıkış).
```

## P12 — İspanyolca ve Portekizce
```text
docs/SONNET_IS_PAKETLERI.md "Ortak kurallar"a uy (localization.mdc, roblox-localize skill). Dal: feat/es-pt. Kapsam: docs/ANALIZ_RAPORU.md bölüm 5 dil satırı.
Config.LANGUAGES'e es ve pt-br ekle; src/shared/Locales/es.luau ve pt.luau (en.luau'daki bütün anahtarlar, {1}/{2} yer tutucuları korunarak; oyuncuya "tú"/"você" ile hitap). UiKit.flag ile İspanya ve Brezilya bayrakları (şekillerle). LocaleId eşlemesi (es-*, pt-*). check-locales.py yeni dilleri de denetlesin; --strict-literals temiz.
Ayrıca rapor 5'teki Rusça hitap tutarlılığı (ты) ve Almanca "es" düzeltmesi.
```

---

## Sonnet inceleme prompt'u (Opus gerekmeyen paketler için, yeni Sonnet oturumu)
```text
Kod incelemesi yap; dosya değiştirme. Dal: <DAL-ADI>, karşılaştırma: main. docs/SONNET_IS_PAKETLERI.md'deki ilgili paket prompt'unu ve docs/ANALIZ_RAPORU.md'nin ilgili bölümünü oku, sonra `git diff main..<DAL-ADI>`'yi incele.
Kontrol et: paket maddeleri gerçekten yapılmış mı; davranış hatası, yarış koşulu, nil erişimi; sunucu güvenliği (istemciye güven, hız sınırı); kayıt uyumluluğu; çeviri eksikleri; testler anlamlı mı.
Çıktı: en fazla 10 bulgu (Önem · dosya:satır · neden · öneri) ve sonda tek satır karar: "Birleştirilebilir" / "Düzeltme gerekir".
```

## Opus inceleme prompt'u (P3, P4, P10, P11 için, yeni Opus oturumu)
```text
Kısa ve odaklı bir kod incelemesi yap; dosya değiştirme, verify çalıştırma (Sonnet çalıştırdı). Dal: <DAL-ADI>, karşılaştırma: main.
Önce docs/SONNET_IS_PAKETLERI.md'deki ilgili paket prompt'unu oku. Sonra yalnızca `git diff main..<DAL-ADI>`'yi oku; tüm repoyu tarama, gerektiğinde değişen fonksiyonun çevresine bak.
Sonnet'in raporu (özet + sapmalar + açık sorular):
<SONNET RAPORUNUN 1, 3 VE 6. BÖLÜMLERİNİ BURAYA YAPIŞTIR>
Çıktı: en fazla 8 bulgu (Önem · dosya:satır · neden · öneri), açık sorulara kısa cevap, tek satır karar ("Birleştirilebilir" / "Şu düzeltmelerle birleştirilebilir" / "Geri al").
```
