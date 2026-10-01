# Island Farm Tycoon — Durum Raporu (2026-10-01)

Kaynak belge `docs/ANALIZ_RAPORU.md` (1 Ekim 2026) bu raporun tamamlanmasından sonra silindi; bulgu numaraları ona göre, metni git geçmişinde. Bu rapor kodla hedefli karşılaştırma (grep + kısa okuma) ve
`verify.ps1` / `simulate-economy.py` çıktılarıyla hazırlandı; Studio çalıştırılmadı. Ara raporlar (`docs/raporlar/`) bu raporun
2, 3, 6 ve 7. bölümlerine taşındı ve silindi (tarihçe git geçmişinde).

## 1. Yönetici özeti
- Analizdeki 5 kritik riskin 5'i de koda işlendi (tema yeniden kurulumu Studio'da ölçülmedi); ekonomi tasması (depo ×5, toplayıcı 5000), çevrimdışı gelir, park edilmiş çiftlik, çiftlik maliyet çarpanı çözüldü.
- **Kazanım 1:** Sunucu döngü hata koruması, makbuz/kilit dayanıklılığı, prompt hız sınırları ve telemetri (huni, ekonomi, ilerleme) eklendi.
- **Kazanım 2:** Tema şablonları (ServerStorage + Clone), `pushState` birleştirme, streaming 160/448, istemci performans paketi; tip borcu 774 → 284.
- **Kazanım 3:** Mobil güvenli alan/UIScale, 44 px hedefler, ses grupları ve kayıtlı ayarlar, gamepad, 6 adımlı onboarding, servis testleri (38 spec).
- **Risk 1:** Bu işlerin hiçbiri Studio'da denenmedi (harita yeniden kurulumu, tema açılış süresi, eski kayıt göçleri, mobil). Bekleyen tur büyük ve birbirine bağlı.
- **Risk 2:** Casual oyuncuda gelirin %91,8'i çevrimdışı + park edilmiş çiftlikten (hayvan geliri %2,3): aktif oyun hâlâ zayıf ödüllendiriliyor; ada tempo hedefleri (at 54 dk, keçi 158 dk; hedef 45/110) tutmuyor.
- **Risk 3:** Yayına hazırlık eksikleri: CI yok (P9), ses kimlikleri boş (32 yuva), Robux kimlikleri 0, admin komutları canlıda açık (K1), es/pt dilleri yok (P12), tip analizi yerelde atlanabiliyor.

## 2. Bulgu takibi

Durum: Çözüldü / Kısmen / Açık / Bilerek ertelendi. Kanıt: commit ya da `dosya:satır`.

| Bulgu | Durum | Kanıt | Not |
|---|---|---|---|
| 1.1 Remote kopyala-yapıştır | Kısmen | `6479fbd` (`RequestGuard.reply/activeFarm`, 6 serviste), `3da3d9f` | Production/MainFarm'da elle yanıt kopyaları kaldı; `withFarmContext` sarmalayıcısı yazılmadı |
| 1.2 Presentation ↔ Services döngüsü | Kısmen | `28ce9ad` (CollectorVisual tembel); `scripts/check-architecture.py:39-43` ALLOW 2 girdi | `PlotService.luau:28-39` hâlâ Presentation'ı doğrudan çağırıyor; `bef4c12` dosya başı yukarı require'ı yakalıyor |
| 1.3 Tip borcu | Çözüldü (ucuz kısım) | `9415f0f` (SharedRef, 774 → 284), `b97810a`, `69a833d` (verify uyarı basıyor) | Kalan 284 bilinen taban; `.tools/luau-lsp` yoksa yalnızca uyarı (bkz. risk 3.8) |
| 1.4 Büyük dosyalar | Açık | `SaveCodec.luau` 832, `PlayerDataService.luau` 807 satır | Bilinçli sona bırakıldı (ilk 3 ay) |
| 1.5a Eklenti/BuyPad prompt hız sınırı | Çözüldü | `4f47a23`; `ExtensionService.luau:32,80`, `BuyPadService.luau:202,283` | |
| 1.5b Admin komutları canlıda | Açık (K1) | `AdminPolicy.luau:5` yalnızca sahip UserId; `AdminService.luau:249` | Karar bekliyor |
| 1.5c `requestId` isteğe bağlı | Açık | `RateLimiter.luau:30-33` (nil kabul) | Eski istemci gerekçesi artık yok, zorunlu yapılabilir |
| 1.5d Altın hayvan mesafe kontrolü | Açık | `EngagementService.luau` mesafe denetimi yok | |
| 1.5e Tüccar al-sat marjı testi | Açık | `maxSellMult < 1 - MERCHANT.discount` testi yok | |
| 1.5f Hız/konum istemcide | Bilerek ertelendi | Analiz "dokunma" dedi | |
| 2.1 Döngü hata koruması | Çözüldü | `c6aa0d8`; `EconomyService.luau:150,160`, `AnimalService.luau:305-313` (`LoopError`), `SeasonService.luau:196` | |
| 2.2 Keçi adası eklenti klasörü | Çözüldü | `2baee2a`; `ExtensionVisualService.luau:294-316` (eklenti başına klasör+imza) | |
| 2.3 Giriş/çıkışta çift tema kurulumu | Kısmen | `a321fd8`, `dd7eeb2`; `PlotService.luau:461-470` (`keepTheme`) | `findFreePlot` hâlâ rastgele (`PlotService.luau:489-497`), kayıtlı temayla eşleşen boş adayı tercih etmiyor |
| 2.4 Çiftlik değiştirme maliyeti | Çözüldü (Studio'da ölçülmedi) | `4c32cac` (ThemeTemplates + Clone), `dd7eeb2` (6 sn, `Core.luau:10`), `fe8d156` MAP_VERSION 50 | Açılışta 6 şablon eşzamanlı kuruluyor (`MapBuilder.luau:475-486`); süre ölçümü bekliyor |
| 2.5 Alternatifler | Bilerek ertelendi | Şablon yaklaşımı seçildi; lobi → K3 | |
| 2.6a Hızlı sunucu değiştirenin girişi | Çözüldü | `c277930`; `PlayerDataService.luau:60,405-412` (60 sn geri çekilmeli bekleme) | |
| 2.6b Max Players uyarısı | Çözüldü | `7f6a6d2` README; `PlotService.luau:578` uyarı | Game Settings'te 6 yapmak kullanıcıda |
| 2.6c Hayvan yuva çakışması | Kısmen | `1a42f06` | Satış sonrası yine çakışabilir (O4-3, görsel); `Slot` özniteliği yazılmadı |
| 2.6d Misafir modu | Bilerek ertelendi | K3 | |
| 3.1 `pushState` birleştirme | Çözüldü | `40f5dd9` (0,25 sn, park edilmişler özet), `3860fb7` (%1 imza), `753f5f8`, `1471ed0` (`PlayerDataService.luau:756-760`) | Paket boyutu Studio'da ölçülmedi |
| 3.2 Streaming | Çözüldü | `ba51810`; `default.project.json:66-67` (160/448) | |
| 3.3-1 AnimalAnimator | Çözüldü | `54331d2` | |
| 3.3-2 Localizer çift yazım | Çözüldü | `8e7738a` | |
| 3.3-3 Gece ışıkları kalite | Çözüldü | `b00185c` | |
| 3.3-4 Pet uykusu | Çözüldü | `7ffb20a` | |
| 3.3-5 SeabedLife | Çözüldü | `762001a` | |
| 3.3-6 HUD ödül/pano | Çözüldü | `70c589b` | |
| 4.1 Depo tasması | Çözüldü | `92615fb`; `Config/Islands.luau:18-42` (50k/120k/300k/1M), Otomatik Toplayıcı tabanı 5000; sim depo dolu %0 | |
| 4.2 Çevrimdışı gelir | Çözüldü | `92615fb`, `b587974`; `Config/Economy.luau:9-14` (%25/2 sa, Pasif Gelir %30/6 sa, tavan 0,5) | Casual çevrimdışı payı %82,5 (hedef 70-80) |
| 4.3 Park edilmiş çiftlik | Çözüldü | `881762b` (`PARKED_FARM_PAY_RATE`); sim park payı %9,3 | Telemetri nedeni yanlış (risk 3.3) |
| 4.4 Çiftlik başına maliyet çarpanı | Çözüldü | `85c7a57`, `287a124`; `Config/Economy.luau:38` (`FARM_COST_STEP = 6`) | |
| 4.5 Geç oyun düzleşmesi | Çözüldü | `c423219` (ayrı çarpan), `99376e2` (büyüme 1,15), `bc51e68` (maxLevel 30 geri alındı) | 6-12. saat ≥%50 hedefi bilinçli gevşetildi; ırk geri dönüşü geç oyunda çöker (O10-2) |
| 4.6 Ada temposu / 3. tema | Kısmen | `0b9ac3e` (3. tema süt+at+keçi, At adası 2800, Ahır 4 5000) | İdeal: ilk ada 18,7 / at 54,2 / keçi 158,0 dk (hedef 15/45/110) |
| 4.7 Açılış | Açık | `Config/Core.luau:65-70` (75 $, hayvansız başlangıç) değişmedi | Casual sim: Mera 2,8 dk, Silo 10,8 dk |
| 4.8a Büyük parti çarpanı | Açık | `FarmMath/Production.luau` | Fabrikalar hâlâ en iyi yatırım olabilir; sim ölçmüyor |
| 4.8b Eklenti süresi | Çözüldü | `4e6a335` (360 sn, +%33) | |
| 4.8c Ürün taşması | Çözüldü | `c409862`, `a1752f1` | |
| 4.8d Siparişler | Çözüldü | `f04298c`, `b587974` (taban 60 sn); sim sipariş payı %1,5 | Hedef %10-20'nin çok altında |
| 4.8e Altın hayvan | Çözüldü | `87e0f79` | |
| 4.8f Elmas çekiç | Çözüldü | `460d08d` | |
| 4.8g Mevsim "6 yatırım" hedefi | Açık | Kodda değişiklik izi yok | Doğrulanmadı |
| 4.9 Simülasyon | Çözüldü | `a23ecd4`, `eaccfbb`, `eb1b080` (verify'da duman koşusu) | Bilinen sınırlar `simulate-economy.py` docstring'inde |
| 4.10 KPI telemetri | Çözüldü | `cebc649`, `e9daf91` (`docs/TELEMETRI.md`) | Canlıda Creator Hub'da görünmesi doğrulanmadı |
| 5a Ses | Kısmen | `1d8504a` (3 grup, kayıtlı düzey); `Config/Audio.luau`: 32 boş yuva, 5 `rbxasset://` yer tutucu | Kimlik seçimi kullanıcıda |
| 5b Mobil | Çözüldü (Studio'da denenmedi) | `acd9d97` (`Kit/Screen.luau:36`), `8e0db5a` | |
| 5c Onboarding | Çözüldü | `6fa725d`, `d08002b` | |
| 5d Robux penceresi güncellemesi | Çözüldü | `FarmHud.client.luau:127,169,176` (`storeForSale`) | |
| 5e Ses/ReducedMotion kaydı | Çözüldü | `1d8504a`, `81c24fd`, `preferences.spec` | |
| 5f Gamepad | Çözüldü | `8078cfa`, `bc860e6` | |
| 5g es/pt | Açık (P12) | `src/shared/Locales/` yalnızca en/de/ru | |
| 5h Çeviri kalitesi (ru hitap, de "es") | Açık (P12 ile) | — | |
| 5i Bildirim birleştirme | Çözüldü | `54fc4b0`, `36dfcc5` | Pencere birleştirme önerisi yapılmadı (analiz "düşük") |
| 6.1 Makbuz/eski anlık görüntü | Çözüldü | `95fde9c`; `monetization-service.spec` | |
| 6.2 Ödülsüz makbuz günlüğü | Çözüldü | `95fde9c`, `114a6e9` | |
| 6.3 Süresi dolmuş kirada yazma | Çözüldü | `c277930` | |
| 6.4a Gamepass sorgu hatası | Açık | `MonetizationService.luau:58-64` hata olunca yalnızca `warn` | Ürün kimlikleri 0 olduğu için bugün zararsız |
| 6.4b DataStore bütçesi | Açık | `PlayerDataService.luau` bütçe denetimi yok | |
| 6.4c Bozuk `_session` yedek yolu | Açık | — | |
| 6.4d Şema sürümü sabiti | Açık | `SessionLock.luau:6`, `SaveCodec.luau:532,810` (`4` üç yerde) | |
| 6.5 Telemetri | Çözüldü | `cebc649`, `a5d38e4`, `c866d0f` | |
| 6.6 Sürüm etiketi/geri alma | Açık | `docs/YAYIN_VE_ARKADAS_TESTI.md`'de `place-vN` süreci yok | Süreç işi; şema sürümü hâlâ 4 |
| 7.1 README | Çözüldü | `7f6a6d2`, `01a149a` ("Çiftliğim" 0 geçiş) | |
| 7.2 CI | Açık (P9) | `.github/workflows/` yok | |
| 7.3 Servis testleri | Çözüldü | `3da3d9f`; 38 spec | |
| 7.4 Studio testleri | Açık | `tests/run.server.luau:16-17` yalnızca data + economy | Open Cloud Luau Execution planı yok |
| 7.5 Belge sürdürülebilirliği | Kısmen | `a1045de` (MIMARI listeleri, `check-ai-docs` klasör karşılaştırır) | `economy-data.mdc` 178 satır; `URETIM_VE_UZMAN_ADALAR.md` çürük (bkz. §9) |
| 7.6 Commit hijyeni | Çözüldü | Son 80 commit `feat/fix/balance/perf/test/docs` önekli | |
| 7.7 Eklenti kırılganlığı | Çözüldü | `bef4c12`, `69a833d` (bayat eklenti uyarısı) | |
| 8.1 Keşif/tutunma | Kısmen | Telemetri + günlük ödül + çevrimdışı kanca var | İlk dakika "vay" anı (4.7) ve ses yok; sosyal/küresel sıralama yok |
| 8.2 Para kazanma | Kısmen | Tasma kalktı (4.1-4.3) | Kimlikler 0; anında üretimin kalan süreyle fiyatlanması doğrulanmadı; K2 |
| 8.3 Etik/çocuk güvenliği | Açık | — | Anket kullanıcı işi |

## 3. Yeni riskler

| # | Önem | Dosya:satır | Neden | Öneri |
|---|---|---|---|---|
| 3.1 | Orta | `MapBuilder.luau:475-486` | Açılışta 6 tema şablonu eşzamanlı kuruluyor ve `optimize` ediliyor; süre ve ServerStorage belleği (~9-18 bin parça tahmini) hiç ölçülmedi. `xpcall` yarıda kalırsa tema ilk geçişte tembel kurulur ve aynı hata o oyuncuda tekrar eder | Studio'da Play → ilk giriş süresini ölç; uzunsa 1. tema eşzamanlı, kalanlar `task.defer` |
| 3.2 | Orta | `PlotService.luau:489-497`, `:461-470` | `findFreePlot` rastgele; başka temadaki adaya girince kayıt yüklenince ilk girişte tema yeniden giydirilir (şablon sayesinde ucuz, ama ayağın altında değişir) ve tema değişimi temizliği (`9665816`) yalnızca testle korunuyor | Kayıtlı temayla eşleşen boş adayı tercih et; Studio'da iki istemciyle doğrula |
| 3.3 | Orta | `EconomyService.luau:141-142` | Toplayıcısız park edilmiş çiftliğin %50 ödemesi telemetriye `autoCollect` yazıyor ve `first_collect` hunisini tetikliyor (O3-7); huni ve ekonomi verisi kirlenir | `reason = "parkedPay"`; hunide yalnızca gerçek toplama |
| 3.4 | Orta | `SaveCodec.luau:170-176` | 3. tema göçü `save.farmId == "3"`'e sabit; iade sessiz, genişletme seviyeleri iade edilmiyor (zararsız ama değeri kayıp). Tema tablosu değişirse göç yeniden yazılmalı. Test yalnızca birim düzeyinde, Studio'da `BarnVisualService` ile denenmedi | Studio testi (§6); iade için tek seferlik bildirim; tema haritasından genel göç |
| 3.5 | Orta | `Config/Economy.luau:11-14`, sim | Casual'da çevrimdışı payı %82,5 + park %9,3; aktif oyun (hayvan geliri %2,3, sipariş %1,5) neredeyse anlamsız. Üstelik P3 kararı: oran 0,3'te kaldı (0,25 Pasif Gelir'i anlamsız kılar) | `OFFLINE_UPGRADED_MAX_HOURS` 6 → 5 denemesi ve sipariş/üretim ödülünü artırma; telemetri ile gerçek oyuncu verisi gelince karar |
| 3.6 | Orta | `Config/Shop.luau:28-33`, `FarmMath/Lineage.luau` | Irk geri dönüşü maliyeti hayvan fiyatına bağlı, kazanç ilerlemeyle büyüyor: geç oyunda geri dönüş dakikalara iner (O10-2); eski Sv.10 kayıtta ayrı çarpanla ~×2,7 gelir sıçraması olabilir (O10-3) | `economy.spec`'e "en yüksek ahırda son seviye geri dönüş ≥ X dk" değişmezi; sim'de eski kayıt profili |
| 3.7 | Düşük | `shared/GameTypes.luau:76`, `FarmProfiles.clientState` | İstemci yükünde `mainFarms` hafif görünüm; tip hâlâ `{ [string]: any }` ve "tam kayıt" der. İleride istemcide `mainFarms[id].animals` yazan biri sessizce nil okur (D-P4: opsiyonel yapmak 24 tip bulgusu açtı, geri alındı) | Ayrı `ClientPlayerState` tipi |
| 3.8 | Orta | `scripts/verify.ps1` | `.tools/luau-lsp` yoksa tip analizi yalnızca uyarıyla atlanıyor ve son satır yine "All automated checks passed" diyor (bu raporun koşusunda da atlandı); CI yokken yanlış güven | CI'da (P9) zorunlu yap; yerelde `setup-types.ps1` çalıştır |
| 3.9 | Düşük | `TelemetryService` / `docs/TELEMETRI.md` | AnalyticsService hız sınırı tahmini 120/dk; aşılırsa olaylar sessizce düşer (`TelemetryDropped`) | Canlıda `TelemetryDropped` izle, aralığı ayarla |
| 3.10 | Düşük | `MapBuilder.luau` `remapPositions`, `ServerStorage` şablon etiketleri | CFrame öznitelikleri koşulsuz dünya konumu sayılıyor (Vector3'te beyaz liste var); sunucuda `GetTagged` kullanan yeni servis 6 şablon kopyasını da görür (O11-3/4) | `world-map.mdc`'ye not ya da beyaz liste |

## 4. Ekonomi özeti

Komut: `python scripts/simulate-economy.py --days 7 --persona casual` (20 dk × 3 oturum/gün) ve varsayılan 6 saatlik ideal oyuncu.

| Ölçü | Casual (7 gün) | İdeal (6 saat) | Hedef |
|---|---|---|---|
| İlk ada (kümes) | 15,1 dk | 18,7 dk | ~15 dk |
| At adası | 486,4 dk | 54,2 dk | ~45 dk (ideal) |
| Keçi adası | 1440,1 dk | 158,0 dk | ~110 dk (ideal) |
| Çiftlik 2 / 3 / 4 / 5 / 6 alındı | 1440 / 2400 / 3376 / 5290 / 8160 dk (6. = 5,7 gün) | — | Ç6 7 gün içinde |
| 6. saat geliri | — | 6838/sn (analizde 4352) | — |
| Depo dolu geçen süre | %0,0 | %0,0 | düşük |
| Eylem | 6,14 dk başına | — | — |
| Son durum | 39/69 yükseltme, kasa $222M | 50/69, kasa $16M | — |

Casual gelir kaynakları: çevrimdışı %82,5 · park edilmiş çiftlik %9,3 · üretim %4,0 · hayvan %2,3 · sipariş %1,5 · günlük ödül %0,2 · mevsim %0,2 · altın hayvan %0,1.
Irk geri dönüşü en kötü 1,67 sa; ırk Sv.60 toplam $5,3M; alan genişletme toplam $881M.

**Yorum.** Analizin asıl ekonomi yarası (depo tasması, ~0 çevrimdışı gelir, kazanmayan park çiftlikleri, 1. çiftlik fiyatlı ek çiftlikler) kapandı: depo dolu süre %0, çiftlik 2-6 zamanları anlamlı aralıklarda (6. çiftlik 5,7 günde) ve ideal oyuncunun 6. saat geliri %57 arttı. Kalan sorun dağılım: casual oyuncuda aktif oyun (hayvan+sipariş) gelirin %3,8'i, yani oyuncu para kazanmak için oynamaktan çok harcamak için giriyor; bu tasarım tercihi mi kusur mu kararı telemetrinin gerçek oturum verisine bağlı. İdeal oyuncuda ada tempoları hedeften hâlâ 20-45% yavaş (özellikle keçi: 158 dk, hedef 110), açılış (75 $, hayvansız, 4.7) değişmedi, siparişler gelirin yalnızca %1,5'i (hedef %10-20). Bunlar bir sonraki denge turunun (§8) konusu; telemetri gelmeden büyük değişiklik yapılmamalı.

## 5. Ölçümler
- `verify.ps1` son satırı: `All automated checks passed. Studio multiplayer, DataStore fault and device tests remain separate.` Öncesinde uyarı: `Automated checks passed, but NOT everything ran: Type analysis` (`.tools/luau-lsp` bu checkout'ta yok).
- Tip bulgusu: `scripts/types-baseline.json` toplamı **284** (analizde 774). Bu koşuda tip analizi atlandı; rakam E raporundaki dal koşusundan ve tabandan.
- Test spec dosyası: **38** (`tests/*.spec.luau`; analizde 25).
- Çeviri anahtarı: **950** (en/de/ru eşit; analizde 932).
- `MAP_VERSION`: **51** (`src/server/World/MapBuilder.luau:28`; analizde 49).

## 6. Birleşik Studio test listesi (öncelik sırasıyla)

Birleştirilen kaynaklar: E, P1, P3, P4, P5, P6, P7, P8, P10, P11 ve D raporları. `FARM_COST_STEP` 6 ve ırk `maxLevel` 10'a göre güncellendi.

**A. Harita ve eklenti (önce bunlar; gerisi haritaya bağlı)**
1. Eklentiyi yeniden derle: `rojo build plugin.project.json --plugin IslandFarmTycoonHarita.rbxm`, Studio'da yeniden aç.
2. Edit modunda "Haritayı Kur" (MAP_VERSION 51), place'i kaydet. Eklenti yolunda `World` dosyaları `Shared`'ı (SharedRef) buluyor mu.
3. Edit modunda `tests/map-structure.spec`: yeşil, sonunda `ServerStorage.ThemeTemplates` temizlenmiş. 3. temanın (Güneşli Tarla) uydu adaları Süt/At/Keçi: yapı noktaları ve köprüler doğru.
4. Play: 6 `Theme<n>` şablonu, `[Map] Tema şablonları hazırlanamadı` uyarısı yok; **açılış süresini ölç** (Play → ilk giriş; risk 3.1).
5. Tema döngüsü 1→6→1, Plot1 ve döndürülmüş ada (3/5): yapı noktaları, uzman ada `AreaCFrame`/`PathStart/End`, ada adı/ikonu, takılma azaldı mı.
6. İki istemci: A farklı temayla çıkar, B girer; B'nin giriş sonrası tema değişiminde BuyPads yeni yuvalarda, `RevealGate` süsleri doğru, boşalan ada temiz (HiddenDecor artığı yok); düşme/ışınlanma yok.
7. Gece lambaları/pencereleri, çarpışma ve ışın sorguları şablon kopyasında korunmuş. Çiftlik toplayıcı görseli açılışta hatasız (tembel require).

**B. Kayıt göçleri ve çok çiftlikli oyuncu**
8. Eski çok çiftlikli hesap: tüm çiftliklerin fiyatı eskisi gibi (×1), yeni alınan çiftlik `#çiftlik + 1` tier alır; çökme/sürüm uyuşmazlığı yok.
9. Eski 3. çiftlik (tavuk/domuz adalı) kaydı: `BarnVisualService` hatasız, iade kasaya yansır, haritada hayalet ada yok, At adası satın alınabilir.
10. 2+ çiftlikli hesapta Envanter/Üretim depo kapasitesi sunucuyla aynı; Sipariş Panosu teklifleri ve GoalCard önerileri doğru.
11. Çiftlik 2 alınca yükseltme/hayvan/alan genişletme/BuyPad fiyatları ×7 (`1 + 6 × (tier − 1)`); istemci ve sunucu aynı (para yetmezse ret). Üretim tesisi kurma fiyatı **çarpılmaz** (P3 notundaki "×9" yanlıştı).
12. Park edilmiş çiftlik: büyüme ada görselinde güncelleniyor, etkin çiftlikte takılma yok; toplayıcısız çiftlik bakiyesi 5 sn'de kasaya akıyor (toplayıcılı %100), dönünce deposu eski haliyle. Çıkıp 1 saat sonra girince tüm çiftliklerin çevrimdışı kazancı toplanıyor.
13. Hızlı satın alma/üretim sırasında istemci fazladan `RequestPlayerState` atıyor mu; `pushState` paket boyutu önce/sonra (MicroProfiler); satın alma yanıtında 0,25 sn gecikme hissi.
14. Uzak adalar 448 stud'da görünüyor, adalar arası pop-in yok; yeni hayvanın yuvası çakışmıyor.

**C. Ekonomi ve ürün**
15. Üretim merkezi: kapasiteyi aşan parti boş depoda başlar; teslimde "Ahıra eklendi … Fazlası paraya çevrildi" ve nakit; sığmayan parti "yeterli yer yok (N gerekli, M boş)", düğme "Depo dolu", hedef kartı "Üretimi başlat" önermiyor.
16. Pasif Gelir açıklaması "%25'ten %30'a, süre 2 saatten 6 saate"; eşyalı toplam oran 0,5'i geçmiyor.
17. Sipariş panosu ödülleri (taban 60 sn): gösterilen = alınan; çiftlik değişince ödüller değişir.
18. Altın hayvan ödülü "toplam gelir × 90 sn" (çok çiftlikte yalnızca etkin çiftlik). Eklenti: 6 dk kalış, +%33; eski kayıtta süren hayvan 2 dk'da döner.
19. Pazar ırk düğmesi Sv.0→10, maliyet metni 3 anlamlı basamak; eski Sv.10 kayıtta düğme "en yüksek", gelir sıçraması makul; HUD gelir/sn sunucuyla aynı; rozet kademeleri; Elmas çekiç 2,5M.
20. Hayvan al/sat, gezgin tüccar, hamsi→levrek; hızlı spam ("Çok hızlı…" ≤0,5 sn'de bir); çiftlik değiştirirken tıklama ("Etkin çiftlik değişti"); yükseltme/ırk/bölge, sipariş, günlük/başarım/mevsim/altın ödülü, envanter yanıtları.

**D. Kayıt ve operasyon (DataStore hata testi)**
21. DataStore kapalıyken: kırmızı `[Data] …` satırı, oyun çökmüyor. Kilit başka sunucudayken girişte ~60 sn geri çekilmeli bekleme, sonunda açık mesajla atma. Ürün kimliği ≠ 0 yapıp test makbuzu: ödül kayıttan önce kaybolmuyor.

**E. Mobil, ses ve gamepad**
22. Device Emulator: telefon (dikey/yatay, çentikli), tablet, 1440p+; HUD çentiğe taşmıyor, pencereler sığıyor; Stats paneli aç/kapat her ölçekte (sekme panele yapışık, 44 px, kasa metni taşmıyor); koşu ile zıplama düğmesi çakışmıyor.
23. Ayarlar: üç ses sürgüsü + "Hareketi azalt"; çık-gir kayıtlı değer; yeni hesapta varsayılan 0,5/0,7/0,5; gereksiz tekrar remote yok; en/de/ru.
24. Ses kimlikleri boş: `Config/Audio.luau`'ya bir kimlik gir (`MUSIC.main`), ortam/efekt sürgülerini dene.
25. Gamepad: veri gelmeden DPad bir şey açmıyor; yön tuşları menü gezintisi (Destek karosu dahil), B ile kapatma, seçimin geri gelmesi.

**F. Onboarding ve HUD**
26. Yeni oyuncu: yalnızca Pazar/Ödüller/Ayarlar, "Destek" karosu yok, "İLK ADIMLAR 1/6". Adım 1-6 akışı (Pazar nabzı + altın ışın 12 stud'da kaybolur, 2/6 platform ışını, 3/6 "Yeni menü açıldı", 4/6 Yol Haritası, 5/6 genişletme, 6/6 Üretim; sonunda Adalar karosu). en/de/ru'da "x/6".
27. Kıdemli kayıt (1.500–20.000 kazanç): 4. adım her girişte çıkmaz; 20.000+ hiç çıkmaz. Aynı bildirim hızlı tekrar: tek kart "×N" (dar ekran, ru'da rozet taşması). `Config/Shop`'ta bir kimliği ≠ 0 yap: Destek karosu ve pencere. Kapalı Ödüller/Pano/Destek çizilmiyor ama rozet güncel.

**G. Telemetri ve istemci performansı**
28. `Workspace.TelemetryPrint = true`: ilk toplama/hayvan/yükseltme/ada/Ahır 2 satırları bir kez; para harcayınca `Source/Sink`; toplama 60 sn'de tek satır; çevrimdışı dönüşte `Offline`/`OfflineSeconds`; çıkışta `SessionSeconds`. Studio'da gerçek analitik gitmiyor (`TelemetryStudioSkipped`). Canlıda Creator Hub panelleri (ve `TelemetryDropped`).
29. Hayvan hareketi (BulkMoveTo), düşük kalitede 20 hayvan / 50 stud sınırı, parça sonradan eklenince hareket (P5-1); gece ışıkları kaliteye göre (düşükte ışıksız Neon), kalite değişince tazelenir; SeabedLife yüksek kamerada 15 Hz; Localizer: tabelalar çevrilir, Workspace'e sonradan gelen tabela çift izlenmez; pet uzakta bekler, köprü geç gelince yol grafiği güncellenir.

## 7. Açık sorular ve kullanıcı kararları

| # | Soru | Kısa öneri |
|---|---|---|
| K1 | Canlıda admin komutları kullanılacak mı? (`AdminPolicy.luau:5`, para sahibin gerçek kaydına yazılıyor) | Yalnızca `RunService:IsStudio()` ya da özel sunucuda; ya da `adminTainted` işaretle ve panodan çıkar |
| K2 | Robux açılışı ve ürün kimlikleri (`Config/Shop.luau` kimlikler 0) | Tasma düzeldi; kimlikleri girmeden önce 6.4a (gamepass hata) ve anında üretim fiyatlamasını kapat, 30 dk 2× güçlendirme ve kozmetikle başla |
| K3 | Lobi / rezerve sunucu / ziyaret | 2-4 hafta telemetri biriktikten sonra karar; o zamana kadar mevcut model |
| Q1 | 3. tema göçü sonrası iade bildirimi (şu an sessiz) gösterilsin mi? | Yayında 3. çiftlikli oyuncu yoksa gereksiz; varsa tek seferlik bildirim |
| Q2 | Casual çevrimdışı payı %82,5 (hedef 70-80): `OFFLINE_UPGRADED_MAX_HOURS` 6 → 5? | Telemetri sonrası; oran 0,3'ün altına inmesin |
| Q3 | Alan genişletme seviyeleri 3. tema göçünde iade edilmiyor | Kabul et (zararsız) |
| Q4 | Irk `maxLevel` 10 mu kalsın, 30'a kademeli yükselsin mi? 6-12. saat artış hedefi bilinçli gevşetildi mi? | 10 kalsın; eski kayıt profilini sim'de ölç (risk 3.6) |
| Q5 | `findFreePlot` tema tercihi (2.3) ve çiftlik değiştirmede `flushState` (O4-4) ayrı iş mi? | Tema tercihi evet (S); `flushState` gereksiz |
| Q6 | `QUALITY` eşikleri (50 stud/20 hayvan, 24 ışık, 120 stud, `HIGH_CAMERA_Y=40`) Config'e mi? | Dosyada kalsın (efekt kuralı) |
| Q7 | Ayarlar'daki "Görsel Ayarlar" başlığı hesaba kayıtlı grafik için doğru mu; rozet `Active = false` bilinçli (dokunuş karoya geçer) | Evet |
| Q8 | Destek karosu için sağ sütunda yer var mı (mobil düzenle) | Studio'da E-25'te bak |
| Q9 | AnalyticsService hız sınırı 120/dk tahmini doğru mu | Canlıda `TelemetryDropped` izle |
| Q10 | Ses kimliklerini sen mi seçeceksin (Creator Store)? 32 yuva boş | Önce para, satın alma, yükseltme, ödül, ortam, hayvan sesleri; müzik ayrı grup |
| Q11 | Creator Hub Maturity & Compliance anketi (8.3), Game Settings → Max Players 6, `place-vN` sürüm etiketi (6.6) | Yayın öncesi kullanıcı işi |
| Q12 | Büyük parti çarpanı (4.8a) ve mevsim "6 yatırım" hedefi (4.8g) bu turda ele alınmadı; yapılsın mı? | Bir sonraki denge turuna al |

## 8. Sıradaki adımlar

| # | Adım | Model | Efor |
|---|---|---|---|
| 1 | Birleşik Studio testi (§6, A-D önce) ve bulguları düzeltme | Kullanıcı + Sonnet (düzeltme) | M |
| 2 | **P9 CI**: `.github/workflows/verify.yml` (rokit, luau-lsp, `verify.ps1`; tip analizi atlanırsa kırmızı) | Sonnet | S |
| 3 | Ses: kimlik seç, 32 yuvayı bağla, müzik ayrı grup | Kullanıcı seçer, Sonnet bağlar | S |
| 4 | Küçük güvenlik/dayanıklılık paketi: `requestId` zorunlu, altın hayvan mesafe, tüccar marj testi, `parkedPay` telemetri, `findFreePlot` tema tercihi, gamepass hata, şema sabiti, K1 kararı | Sonnet | S |
| 5 | **P12** es/pt-br + Rusça hitap, Almanca "es" düzeltmesi | Sonnet | M |
| 6 | Denge 3. tur: açılış (4.7), ada tempoları, büyük parti çarpanı, sipariş payı, çevrimdışı payı; kısa Opus incelemesi | Sonnet + Opus | M |
| 7 | K2 Robux açılışı (kimlikler sonrası) ve yayın süreci (`place-vN`, Maturity anketi) | Sonnet + Opus (para/kayıt incelemesi) | M |
| 8 | `SaveCodec`/`PlayerDataService` bölme + kalan tip borcu (284) + Presentation↔Services döngüsü; telemetri verisiyle K3 | Sonnet (Opus kısa inceleme) | L |

## 9. Koddan çürütülmüş belge bilgileri (dokunulmadı)
- `docs/URETIM_VE_UZMAN_ADALAR.md`: "Harita sürümü 13" (gerçek 51) ve tesis tablosu (örn. Süt fabrikası 60 sn, 2 yetişkin inek, masraf 160/teslim 650); `src/shared/Config/Production.luau:120-130` süt fabrikası 35 sn, 1 yetişkin, masraf 0. Tablo güncellenmeli.
- `docs/ANA_CIFTLIKLER.md`: "Haritada 6 fiziksel ada hepsi aynı (1. tema) kurulur" ve "çalışma anında yeniden giydirilir" ifadesi artık yalnızca kısmen doğru (şablon Clone, `MapBuilder.luau:48-51,170`); çiftlik fiyat cümlesi (~590 bin ... 100 milyon) `FARM_COST_STEP = 6` sonrası doğrulanmadı.

## 10. Temizlik

Silinen:
- `docs/raporlar/*.md` (23 dosya: D-P1, D-P2, D-P4, D-P6, D-P7, D-P10, D-P11, E, O3, O4, O10, O11, P1, P2, P3, P3-birlestirme, P4, P5, P6, P7, P8, P10, P11): açık sorular, Studio adımları, ertelenen bulgular ve kararlar bu rapora (§2, §3, §6, §7) taşındı; tarihçe git geçmişinde.
- `docs/DEVAM_PLANI.md`: Aşama 1-5 tamamlandı (P9 hariç, o §8'de); dal haritası ve ajan kuralları geçersiz, kalan iş §8'de.
- `docs/AI_ANALIZ_PROMPTU.md`: tek seferlik analiz prompt'u; analiz yapıldı, proje tarifi (kayıt, ekonomi, tema) o günkü duruma ait ve artık güncel değil.

Değiştirilen:
- `docs/SONNET_IS_PAKETLERI.md`: yapılan paketler (P0-P8, P10, P11, P3, inceleme prompt'ları) çıkarıldı; yalnızca ortak kurallar ile yapılmamış P9, P12, K1-K3 kaldı.
- `docs/ANALIZ_RAPORU.md` (sonradan silindi): bu raporun bulgu tablosu onu kapsıyor; metni `git show b15e796:docs/ANALIZ_RAPORU.md`.
- `docs/SES_LISTESI.md` (sonradan silindi): içeriği `docs/SESLER.md` §6'ya birleştirildi.
- README.md, AGENTS.md, `.cursor/rules` silinen belgelere bağlantı vermiyordu; değişiklik gerekmedi.
