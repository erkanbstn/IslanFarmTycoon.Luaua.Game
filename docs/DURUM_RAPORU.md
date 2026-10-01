# Island Farm Tycoon — Durum Raporu (güncel: 2026-10-01, geri bildirim turu sonrası)

Kaynak: 1 Ekim 2026 proje analizi (metni silindi: `git show b15e796:docs/ANALIZ_RAPORU.md`); bulgu numaraları ona göre. Bu rapor kodla hedefli
karşılaştırma ve `verify.ps1 -RequireTypes` / `simulate-economy.py` çıktılarıyla hazırlandı; Studio çalıştırılmadı. İkinci turda (güvenlik paketi,
es/pt, denge 3. tur, kayıt bölme) güncellendi. Ara raporlar silindi; bilgileri bu raporda (tarihçe git geçmişinde).

## 1. Yönetici özeti
- Analizdeki 5 kritik risk ve bulguların çoğu koda işlendi: ekonomi tasması, çevrimdışı gelir, park edilmiş çiftlik, çiftlik maliyet çarpanı, açılış, ada tempoları, sipariş payı, döngü hata koruması, makbuz/kilit dayanıklılığı, güvenlik küçük paketi.
- **Kazanım 1:** Ekonomi hedeflere oturdu: ideal ilk ada 13,1 / at 46,8 / keçi 115,8 dk; casual çevrimdışı payı %71,5, sipariş %12,3, 6. çiftlik 5,3 gün.
- **Kazanım 2:** Kod yapısı sadeleşti: `SaveCodec/` (8 modül) + `SaveStore`, tip borcu 774 → 214, 38 spec, tip analizi `luau-lsp` ile yerelde çalışıyor.
- **Kazanım 3:** 5 dil (tr/en/de/ru + es/pt-BR), mobil güvenli alan/UIScale, ses grupları, gamepad, 6 adımlı onboarding, telemetri.
- **Risk 1:** Bu işlerin hiçbiri Studio'da denenmedi (harita yeniden kurulumu, tema açılış süresi, eski kayıt göçleri, `SaveStore` ile kayıt akışı, mobil, es/pt metin taşması). Bekleyen tur büyük ve birbirine bağlı.
- **Risk 2:** Yayın hazırlığı eksik: CI yok (P9, şimdilik yapılmıyor), ses kimlikleri boş (32 yuva), Robux kimlikleri 0, admin komutları canlıda açık (K1), es/pt çevirileri anadil incelemesinden geçmedi.
- **Risk 3:** Casual oyuncuda gelirin %81'i çevrimdışı + park edilmiş çiftlikten, hayvan geliri %2,5: aktif oyunun değeri telemetri olmadan bilinmiyor; hardcore'da sipariş payı %35.

## 2. Bulgu takibi

Durum: Çözüldü / Kısmen / Açık / Bilerek ertelendi. Kanıt: commit ya da `dosya:satır`.

| Bulgu | Durum | Kanıt | Not |
|---|---|---|---|
| 1.1 Remote kopyala-yapıştır | Kısmen | `6479fbd` (`RequestGuard.reply/activeFarm`, 6 serviste), `3da3d9f` | Production/MainFarm'da elle yanıt kopyaları kaldı; `withFarmContext` sarmalayıcısı yazılmadı |
| 1.2 Presentation ↔ Services döngüsü | Kısmen | `28ce9ad` (CollectorVisual tembel); `scripts/check-architecture.py:39-43` ALLOW 2 girdi | `PlotService.luau:28-39` hâlâ Presentation'ı doğrudan çağırıyor; `bef4c12` dosya başı yukarı require'ı yakalıyor |
| 1.3 Tip borcu | Çözüldü (ucuz kısım) | `9415f0f` (774 → 284), `b43e0b5` (284 → 214), `69a833d` | Kalan 214: döngüsel `require` ve `pcall` yanlış pozitifleri; tip analizi artık yerelde çalışıyor |
| 1.4 Büyük dosyalar | Çözüldü | `114ad32` (`SaveCodec/` 8 modül), `3e2e6ca` (`SaveStore.luau`; `PlayerDataService` 807 → 638) | Davranış aynı (36 örnek kayıtta birebir); Studio testi bekliyor (§6-30) |
| 1.5a Eklenti/BuyPad prompt hız sınırı | Çözüldü | `4f47a23`; `ExtensionService.luau:32,80`, `BuyPadService.luau:202,283` | |
| 1.5b Admin komutları canlıda | Açık (K1) | `AdminPolicy.luau:5` yalnızca sahip UserId; `AdminService.luau:249` | Karar bekliyor |
| 1.5c `requestId` isteğe bağlı | Çözüldü | `12254e2`; `RateLimiter.luau:29` (`allowMissing` yalnızca sunucu içi prompt) | |
| 1.5d Altın hayvan mesafe kontrolü | Çözüldü | `b909acd`; `PlotService.isNearPlot`, `Config.GOLDEN.claimRadius` 320 | Kaba sınır: hayvanın konumu istemcide |
| 1.5e Tüccar al-sat marjı testi | Çözüldü | `2bb09ab` (`merchant.spec`) | |
| 1.5f Hız/konum istemcide | Bilerek ertelendi | Analiz "dokunma" dedi | |
| 2.1 Döngü hata koruması | Çözüldü | `c6aa0d8`; `EconomyService.luau:150,160`, `AnimalService.luau:305-313` (`LoopError`), `SeasonService.luau:196` | |
| 2.2 Keçi adası eklenti klasörü | Çözüldü | `2baee2a`; `ExtensionVisualService.luau:294-316` (eklenti başına klasör+imza) | |
| 2.3 Giriş/çıkışta çift tema kurulumu | Çözüldü | `a321fd8`, `dd7eeb2`, `b24db7c` (tema 1 / son tema tercihi, `bc7edc6` test) | Kayıtlı tema giriş anında bilinmediği için tercih yaklaşık |
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
| 4.2 Çevrimdışı gelir | Çözüldü | `92615fb`, `b587974`; `Config/Economy.luau:9-14` (%25/2 sa, Pasif Gelir %30/5 sa (`09fb6f5`), tavan 0,5) | Casual çevrimdışı payı %71,5 |
| 4.3 Park edilmiş çiftlik | Çözüldü | `881762b` (`PARKED_FARM_PAY_RATE`); sim park payı %9,3 | Telemetri nedeni yanlış (risk 3.3) |
| 4.4 Çiftlik başına maliyet çarpanı | Çözüldü | `85c7a57`, `287a124`; `Config/Economy.luau:38` (`FARM_COST_STEP = 6`) | |
| 4.5 Geç oyun düzleşmesi | Çözüldü | `c423219` (ayrı çarpan), `99376e2` (büyüme 1,15), `bc51e68` (maxLevel 30 geri alındı) | 6-12. saat ≥%50 hedefi bilinçli gevşetildi; ırk geri dönüşü geç oyunda çöker (O10-2) |
| 4.6 Ada temposu / 3. tema | Çözüldü | `0b9ac3e`, `04e02a1` (ideal ilk ada 13,1 / at 46,8 / keçi 115,8 dk) | |
| 4.7 Açılış | Çözüldü | `3b81761` (`Config.STARTER_ADULT_ANIMALS = 3`, ilk 3 hayvan yetişkin doğar) | Silo'ya dokunulmadı |
| 4.8a Büyük parti çarpanı | Çözüldü | `82566fc` (2,4 → 2,0, `PRODUCTION_MAX_RETURN`, sim "Tesis geri ödeme") | Süt fabrikası 57 dk (bant dışı) |
| 4.8b Eklenti süresi | Çözüldü | `4e6a335` (360 sn, +%33) | |
| 4.8c Ürün taşması | Çözüldü | `c409862`, `a1752f1` | |
| 4.8d Siparişler | Çözüldü | `f04298c`, `b587974`, `9fbeebf` (taban 300 sn, pano 7 dk); sim sipariş payı %12,3 | |
| 4.8e Altın hayvan | Çözüldü | `87e0f79` | |
| 4.8f Elmas çekiç | Çözüldü | `460d08d` | |
| 4.8g Mevsim "6 yatırım" hedefi | Çözüldü | `779d986` (sipariş teslimi de sayılır; genişletme zaten sayılıyordu) | |
| 4.9 Simülasyon | Çözüldü | `a23ecd4`, `eaccfbb`, `eb1b080` (verify'da duman koşusu) | Bilinen sınırlar `simulate-economy.py` docstring'inde |
| 4.10 KPI telemetri | Çözüldü | `cebc649`, `e9daf91` (`docs/TELEMETRI.md`) | Canlıda Creator Hub'da görünmesi doğrulanmadı |
| 5a Ses | Kısmen | `1d8504a` (3 grup, kayıtlı düzey); `Config/Audio.luau`: 32 boş yuva, 5 `rbxasset://` yer tutucu | Kimlik seçimi kullanıcıda |
| 5b Mobil | Çözüldü (Studio'da denenmedi) | `acd9d97` (`Kit/Screen.luau:36`), `8e0db5a` | |
| 5c Onboarding | Çözüldü | `6fa725d`, `d08002b` | |
| 5d Robux penceresi güncellemesi | Çözüldü | `FarmHud.client.luau:127,169,176` (`storeForSale`) | |
| 5e Ses/ReducedMotion kaydı | Çözüldü | `1d8504a`, `81c24fd`, `preferences.spec` | |
| 5f Gamepad | Çözüldü | `8078cfa`, `bc860e6` | |
| 5g es/pt | Çözüldü | `fcbf8cb` (es "tú", pt-BR "você", 950 anahtar, bayraklar) | Anadil incelemesi yok (Q13) |
| 5h Çeviri kalitesi (ru hitap, de "es") | Çözüldü | `f03849e` (~40 ru emir kipi "ты", 8 de "es", "dükkânı") | |
| 5i Bildirim birleştirme | Çözüldü | `54fc4b0`, `36dfcc5` | Pencere birleştirme önerisi yapılmadı (analiz "düşük") |
| 6.1 Makbuz/eski anlık görüntü | Çözüldü | `95fde9c`; `monetization-service.spec` | |
| 6.2 Ödülsüz makbuz günlüğü | Çözüldü | `95fde9c`, `114a6e9` | |
| 6.3 Süresi dolmuş kirada yazma | Çözüldü | `c277930` | |
| 6.4a Gamepass sorgu hatası | Çözüldü | `cca0b8c` (önceki değer korunur, 30 sn'de ≤3 yeniden deneme) | |
| 6.4b DataStore bütçesi | Açık | `Services/SaveStore.luau` bütçe denetimi yok | |
| 6.4c Bozuk `_session` yedek yolu | Açık | — | |
| 6.4d Şema sürümü sabiti | Çözüldü | `ffe489b` (`SessionLock.VERSION`) | Çiftlik anlık görüntüsü `version = 3` ayrı kavram |
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

### Oyun geri bildirimi (7 madde, dal `fix/oyun-geri-bildirimi`)

| # | Madde | Durum | Kanıt | Not |
|---|---|---|---|---|
| G1 | Gece çok karanlık, ışıklar tutarsız | Yapıldı (Studio'da görülmedi) | `9d7b3a7`, `afe46e1` | `Environment.NIGHT_CURVE` (şafak erken), ışık rampası gökyüzüne bağlı, orta kalitede histerezisli ışık bütçesi, düşükte `NightHalo` |
| G2 | Sipariş, toplu satış, takas, doluluk uyarısı | Yapıldı | `a62c240`, `d3ca1f8`, `06f1d2a`, `6809321`, `858354b`, `28a869d`, `5e75193`, `ca5df39`, `bc427e3` | Siparişler depo kapasitesiyle büyür (8 kademe, 12 slot); "Hepsini/Yarısını sat"; ürünle hayvan alma; Envanter rozeti + hedef kartı uyarısı; sim ürün üretim/tüketimini ölçer |
| G3 | Büyüme hızı toplam-artı + tavan | Yapıldı | `a09d641` | `GROWTH_SPEED_KNEE/CAP`, taban süre uzadı; `getGrowthSeconds` hazır, arayüzde yok |
| G4 | Yardımcı hareketi (PetMotion) | Yapıldı | `29d4fc3` | Düşükte ışınlanma kalktı (yalnızca çok uzakta); tek `PreRender`/`BulkMoveTo` döngüsü yapılmadı |
| G5 | Kuluçka otomasyonu | Yapıldı | `2deaf40` | `FarmMath.petKindFor`: kuluçka "cash" yardımcısıyla teslim + tekrar |
| G6 | Tüccar rozeti | Yapıldı | `5b44ce7` | `Merchant.status` + `MerchantBadge`; geri sayım, kaçırma bildirimi, `MERCHANT` sıklığı arttı |
| G7 | Mevsim/hava oku | Yapıldı | `57be755` | `SeasonSignal` + `Environment.getSeasonEffect` (eşik `SEASON_SIGNAL_THRESHOLD`) |

## 3. Yeni riskler

| # | Önem | Dosya:satır | Neden | Öneri |
|---|---|---|---|---|
| 3.1 | Orta | `MapBuilder.luau:475-486` | Açılışta 6 tema şablonu eşzamanlı kuruluyor ve `optimize` ediliyor; süre ve ServerStorage belleği (~9-18 bin parça tahmini) hiç ölçülmedi. `xpcall` yarıda kalırsa tema ilk geçişte tembel kurulur ve aynı hata o oyuncuda tekrar eder | Studio'da Play → ilk giriş süresini ölç; uzunsa 1. tema eşzamanlı, kalanlar `task.defer` |
| 3.2 | Düşük | `PlotService.luau` `findFreePlot` | Tercih artık tema 1 / son tema (`b24db7c`) ama kayıtlı tema giriş anında bilinmiyor: farklı temalı oyuncu ilk girişte yine tema değişimi görebilir (şablonla ucuz); temizlik yalnızca testle korunuyor | Studio'da iki istemciyle doğrula (§6-6, 34) |
| 3.4 | Orta | `Modules/SaveCodec/Farm.luau` (3. tema göçü) | 3. tema göçü `save.farmId == "3"`'e sabit; iade sessiz, genişletme seviyeleri iade edilmiyor (zararsız ama değeri kayıp). Tema tablosu değişirse göç yeniden yazılmalı. Test yalnızca birim düzeyinde, Studio'da `BarnVisualService` ile denenmedi | Studio testi (§6); iade için tek seferlik bildirim; tema haritasından genel göç |
| 3.5 | Düşük | `Config/Economy.luau`, sim | Casual çevrimdışı + park payı %81, aktif oyun (hayvan+üretim) %6; hardcore sipariş payı %35. Davranış gerçek oyuncuyla ölçülmedi | Telemetri sonrası bak (§8-5); Q17 |
| 3.6 | Orta | `Config/Shop.luau:28-33`, `FarmMath/Lineage.luau` | Irk geri dönüşü maliyeti hayvan fiyatına bağlı, kazanç ilerlemeyle büyüyor: geç oyunda geri dönüş dakikalara iner (O10-2); eski Sv.10 kayıtta ayrı çarpanla ~×2,7 gelir sıçraması olabilir (O10-3) | `economy.spec`'e "en yüksek ahırda son seviye geri dönüş ≥ X dk" değişmezi; sim'de eski kayıt profili |
| 3.7 | Düşük | `shared/GameTypes.luau:76`, `FarmProfiles.clientState` | İstemci yükünde `mainFarms` hafif görünüm; tip hâlâ `{ [string]: any }` ve "tam kayıt" der. İleride istemcide `mainFarms[id].animals` yazan biri sessizce nil okur (D-P4: opsiyonel yapmak 24 tip bulgusu açtı, geri alındı) | Ayrı `ClientPlayerState` tipi |
| 3.8 | Düşük | `scripts/verify.ps1` | Tip analizi `.tools/luau-lsp` yoksa yalnızca uyarıyla atlanır (CI yok): temiz klonda yanlış güven | Yerelde `-RequireTypes` ile koş; `.tools/luau-lsp` bu makinede kurulu |
| 3.9 | Düşük | `TelemetryService` / `docs/TELEMETRI.md` | AnalyticsService hız sınırı tahmini 120/dk; aşılırsa olaylar sessizce düşer (`TelemetryDropped`) | Canlıda `TelemetryDropped` izle, aralığı ayarla |
| 3.10 | Düşük | `MapBuilder.luau` `remapPositions`, `ServerStorage` şablon etiketleri | CFrame öznitelikleri koşulsuz dünya konumu sayılıyor (Vector3'te beyaz liste var); sunucuda `GetTagged` kullanan yeni servis 6 şablon kopyasını da görür (O11-3/4) | `world-map.mdc`'ye not ya da beyaz liste |
| 3.11 | Orta | `Services/SaveStore.luau`, `Modules/SaveCodec/` | Kayıt katmanı bölündü; pure-Luau testlerle ve 36 örnek kayıtta eski modülle birebir doğrulandı ama gerçek DataStore, kilit bekleme, yedek/karantina, `BindToClose` ve `run.server.luau` Studio'da denenmedi | §6-30 tamamlanmadan canlıya çıkma |
| 3.12 | Orta | `Config/Islands.luau` `GROWTH_SPEED_*`, `Config/Animals.luau` | Taban büyüme süresi uzadı: mevcut kayıtta yakın zamanda alınmış hayvan (`bornAt` sabit) yeniden yavru/genç görünebilir; büyüme süresi arayüzde gösterilmiyor (`FarmMath.getGrowthSeconds` hazır) | Studio'da eski kayıtla bak (§6-36); gerekirse arayüze süre ekle |
| 3.13 | Orta | `Config/Goods.luau` `GOODS_CONTRACTS`, sim | Casual ilk gün gelir yaklaşık -%17 (`incomeSeconds` ayarlanabilir); hardcore sipariş payı yaklaşık +%22; ürün talep ağırlığı yok (hangi ürün ne sıklıkla istenir eşit) | Sim'i yeniden çalıştır, `incomeSeconds`/kademe ağırlıklarına bak (Q18-19) |
| 3.14 | Düşük | `Config/Goods.luau` `GOODS_BARTER` | Takas oranı satış oranıyla aynı (`config.spec` üstüne çıkmayı engeller); ürünle hayvan alma satışla eşdeğer tek adım | Telemetri sonrası ayrı oran gerekirse bak |
| 3.15 | Düşük | `Services/ProductionService.luau`, `Modules/ProductionLogic.luau` | Kuluçka dolu kümeste teslim bekler (yardımcı de alamaz); alternatif: paraya çevirmek | Studio'da yaşa; sorun olursa paraya çevir (Q23) |

## 4. Ekonomi özeti

Komut: `python scripts/simulate-economy.py --days 7 --persona casual` (20 dk × 3 oturum/gün) ve varsayılan 6 saatlik ideal oyuncu (denge 3. tur sonrası).

| Ölçü | Casual (7 gün) | İdeal (6 saat) | Hedef |
|---|---|---|---|
| İlk ada (kümes) | 9,8 dk | 13,1 dk | ~15 dk |
| At adası | 480 dk | 46,8 dk | ~45 dk (ideal) |
| Keçi adası | 494 dk | 115,8 dk | ~110 dk (ideal) |
| Çiftlik 2 / 3 / 4 / 5 / 6 alındı | 960 / 1920 / 2880 / 4800 / 7680 dk (6. = 5,3 gün) | — | Ç6 7 gün içinde |
| Tüm yükseltmeler | — | 275,3 dk | 240-300 dk |
| 6. saat geliri | — | 6912/sn | — |
| Depo dolu geçen süre | %0,0 | %0,0 | düşük |
| Eylem | 6,8 / dk | — | — |
| Son durum | 40/69 yükseltme, kasa $222M | 50/69, kasa $24,9M | — |

Casual gelir kaynakları: çevrimdışı %71,5 · sipariş %12,3 · park edilmiş çiftlik %9,5 · üretim %3,5 · hayvan %2,5 · günlük ödül %0,3 · mevsim %0,3 · altın hayvan %0,1.
Irk geri dönüşü en kötü 1,67 sa; ilk 3 hayvan yetişkin doğuyor (ilk yetişkin 0 dk; önceden ~30 dk). Fabrika geri ödemesi 1. çiftlikte ~23 dk (süt 57 dk).

**Yorum.** Analizin ekonomi yarası kapandı ve 3. turla hedef bantlara oturdu: ideal tempolar hedefin %5'i içinde, casual çevrimdışı payı hedef 70-80 bandında, sipariş payı 10-20 bandında, depo tasması yok. Kalan belirsizlik gerçek oyuncu davranışı: çevrimdışı + park edilmiş çiftlik hâlâ casual gelirinin %81'i ve aktif oyun (hayvan+üretim) %6; sipariş ödülü artık gelire bağlı olduğu için hardcore persona gelirinin %35'i siparişten geliyor (aktif oyun ödüllensin diye bilinçli ama telemetriyle teyit edilmeli). Süt fabrikasının geri ödemesi (57 dk) bandın dışında; Ç3+ çiftliklerdeki 100'lerce dakikalık fabrika ölçümü büyük olasılıkla küçük sürü artefaktı. Telemetri gelmeden başka denge değişikliği yapılmamalı.

## 5. Ölçümler
- `verify.ps1 -RequireTypes` son satırı: `All automated checks passed. Studio multiplayer, DataStore fault and device tests remain separate.` (tip analizi dahil çalıştı; yerel Studio eklentisi `plugin/`'den eski olabilir uyarısı sürüyor).
- Tip bulgusu: `scripts/types-baseline.json` **214** (analizde 774; `check-types.py`: yeni bulgu yok). `luau-lsp` bu makinede kuruldu (`scripts/setup-types.ps1`).
- Test spec dosyası: **38** (`tests/*.spec.luau`; analizde 25).
- Çeviri anahtarı: **950** (en/de/ru/es/pt eşit; analizde 932).
- `MAP_VERSION`: **51** (`src/server/World/MapBuilder.luau:28`).
- Büyük dosyalar: `SaveCodec/` 8 modül (en büyüğü `Farm` 222 satır), `PlayerDataService` 638, `SaveStore` 284 satır.

## 6. Birleşik Studio test listesi (öncelik sırasıyla)

Birleştirilen kaynaklar: eski ara raporlar ve ikinci tur. `FARM_COST_STEP` 6, ırk `maxLevel` 10, Pasif Gelir %30 / 5 sa.

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
16. Pasif Gelir açıklaması "%25'ten %30'a, süre 2 saatten 5 saate"; eşyalı toplam oran 0,5'i geçmiyor.
17. Sipariş panosu ödülleri (taban 300 sn gelir, pano 7 dk'da yenilenir): gösterilen = alınan; çiftlik değişince ödüller değişir; kış mevsiminde teslim "Yatırım yap: n/6" sayacını artırır.
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

**H. İkinci tur eklemeleri**
30. Kayıt akışı (`SaveStore`): normal giriş/çıkış (çıkışta `DataStatus` `Closed`); aynı hesapla iki sunucu (kilit bekleme `LoadLockWait`); eski kayıt açma (tek çiftlikli, 3. tema, `goods`/`contracts` çiftlik içinde duran eski kayıt); bozuk kayıttan yedekle açılış ve karantina (`ProfileRecovered`, `player_<id>_quarantine`); oyuncular varken sunucu kapatma (`BindToClose`, son kayıt + kilit bırakma); `StudioNonPersistentData`; `tests/run.server.luau` ile `data.spec` (klasör modülü `SaveCodec`).
31. Açılış: yeni hesapta ilk 3 hayvan yetişkin görünümünde doğuyor, 4. hayvan yavru; ilk dakikada gelir hissi.
32. Altın hayvan: kendi adandan (uydu adalar dahil) alınıyor, çok uzaktayken "yeterince yakın değilsin" (`Config.GOLDEN.claimRadius` 320 stud; uzak uydu adadan alınabiliyor mu kontrol et).
33. Gamepass: geçici sorguda geçit düşmüyor (Studio'da `UserOwnsGamePassAsync` hatası taklit edilirse 30 sn'de yeniden dener, en çok 3).
34. Boş ada seçimi: tema 1'deki boş ada tercih ediliyor; oyuncu çıkıp aynı sunucuya dönerse son temasındaki ada. Telemetri: toplayıcısız park edilmiş çiftlik `ParkedPay`, huni `first_collect` yalnızca gerçek toplamada.
35. es/pt: Ayarlar → Dil'de 6 buton ve İspanya/Brezilya bayrakları (Brezilya eşkenar dörtgeni biraz basık olabilir); uzun İspanyolca/Portekizce metinler menü karoları, butonlar ve pencerelerde taşıyor mu; `es-419`/`pt-BR` Roblox dili ilk girişte doğru dili seçiyor mu; Rusça yönerge metinleri ("ты") doğal okunuyor mu.

**I. Geri bildirim turu (dal `fix/oyun-geri-bildirimi`)**
36. Gece: 17:00-20:30 kararma, 03:30-07:00 şafak (saatleri `Environment.NIGHT_CURVE` ile oynat, yönetici saat aracı); fenerler gökyüzü kararınca yanıyor, sabah aydınlanmadan sönüyor; orta kalitede kamera hareketinde ışıklar titremiyor; düşükte gerçek ışık yok, fenerlerde `NightHalo` parıltısı görünüyor (görünüm beğenilmezse `HALO_*`). Eski kayıtta yakın zamanda alınmış hayvan yeniden gençleşmiş mi (risk 3.12).
37. Siparişler: pano büyük depoda büyük birim ister, ödül gösterilen = alınan; ürün başına "Hepsini sat/Yarısını sat" paraya doğru çeviriyor; "Ürünle satın al" (takas) hayvan fiyatından değer düşüyor; depo %90 dolunca Envanter rozeti ve hedef kartı satırı; taşan üretim satış oranıyla paraya çevriliyor.
38. Büyüme: yem silosu tek başına 2 kat, birden çok geliştirme birikince hız tavana yaklaşıyor ama hiç ulaşmıyor; yavru -> yetişkin süreleri makul.
39. Yardımcı: düşük kalitede ışınlanmadan akıcı yürüyor (çok uzakta hariç); kuluçka: yardımcılı çiftlikte hazır parti kendi teslim ve yeniden başlıyor, dolu kümeste bekliyor.
40. Gezgin tüccar: rozet teklif belirince geri sayımla çıkıyor, alınca/bitince kalkıyor, kaçırılan teklifte bildirim; dolu bölgeli oyuncuya teklif yok; ziyaret ~20 dk oturumda en az bir kez.
41. Mevsim oku: yakın hayvanlarda yeşil/kırmızı ok (görevdeki hayvanda da görünür), nötrde yok; düşükte aura yok, hareketi azaltmada nabız yok; Mevsim çubuğu ile aynı yönü gösteriyor.

## 7. Açık sorular ve kullanıcı kararları

| # | Soru | Kısa öneri |
|---|---|---|
| K1 | Canlıda admin komutları kullanılacak mı? (`AdminPolicy.luau:5`, para sahibin gerçek kaydına yazılıyor) | Yalnızca `RunService:IsStudio()` ya da özel sunucuda; ya da `adminTainted` işaretle ve panodan çıkar |
| K2 | Robux açılışı ve ürün kimlikleri (`Config/Shop.luau` kimlikler 0) | Kimlikleri girmeden önce anında üretim fiyatlamasını kapat; 30 dk 2× güçlendirme ve kozmetikle başla |
| K3 | Lobi / rezerve sunucu / ziyaret | 2-4 hafta telemetri biriktikten sonra karar |
| Q1 | 3. tema göçü sonrası iade bildirimi (şu an sessiz) gösterilsin mi? | Yayında 3. çiftlikli oyuncu yoksa gereksiz; varsa tek seferlik bildirim |
| Q3 | Alan genişletme seviyeleri 3. tema göçünde iade edilmiyor | Kabul et (zararsız) |
| Q4 | Irk `maxLevel` 10 kalsın mı? Geç oyunda geri dönüş çöküşü (risk 3.6) | 10 kalsın; eski kayıt profilini sim'de ölç |
| Q6 | `QUALITY` eşikleri Config'e mi? | Dosyada kalsın |
| Q8 | Destek karosu için sağ sütunda yer var mı (mobil düzenle) | Studio'da E-25'te bak |
| Q9 | AnalyticsService hız sınırı 120/dk tahmini doğru mu | Canlıda `TelemetryDropped` izle |
| Q10 | Ses kimliklerini sen mi seçeceksin (Creator Store)? 32 yuva boş | Önce para, satın alma, yükseltme, ödül, ortam, hayvan sesleri; müzik ayrı grup |
| Q11 | Maturity & Compliance anketi (8.3), Game Settings → Max Players 6, `place-vN` sürüm etiketi (6.6) | Yayın öncesi kullanıcı işi |
| Q13 | es/pt çevirileri anadil incelemesinden geçsin mi; yalnızca pt-BR (pt-PT yok) yeterli mi? | Yayından önce bir kez gözden geçirt; pt-BR yeterli |
| Q14 | Süt fabrikası geri ödemesi 57 dk (bant 25-40) | Küçük nominal artış; telemetri sonrası |
| Q15 | `data.spec` Pasif Gelir beklentisi sabit ×3 yerine Config'ten türetildi (oran × saat = ×3,0) | Kabul; sıkılaştı |
| Q16 | `SaveStore` yedek zaman damgası artık arka plan görevi çalışınca basılıyor (aynı saniye) | Kabul |
| Q17 | Büyük parti çarpanı, sipariş tabanı (300 sn) ve pano süresi (7 dk) telemetri verisine göre yeniden bakılacak | Gelir verisi gelince |
| Q18 | Sabah eğrisi saatleri (`Environment.NIGHT_CURVE`: 03:30 şafak, 07:00 tam gündüz) ve halo görünümü (`DayNight` `HALO_*`) uygun mu | Studio'da gör, beğenilmezse eğri noktalarını/halo ölçeğini ayarla |
| Q19 | Casual ilk gün gelir -%17 kabul mü? Hardcore sipariş +%22 mi | `GOODS_CONTRACTS.incomeSeconds` ile oyna; sim'de kontrol |
| Q20 | Takas oranı satışla aynı (0.5) kalsın mı; ürün talep ağırlığı eklensin mi | Aynı kalsın; talep ağırlığı telemetri sonrası |
| Q21 | Mevcut kayıtlarda yeni uzun büyüme süresi yüzünden yakın alınmış hayvan gençleşebilir; süre arayüzde gösterilsin mi (`getGrowthSeconds` hazır) | Kabul et; göstermek istersen küçük bir iş |
| Q22 | Tek `PreRender`/`BulkMoveTo` pet döngüsü yapılmadı; düşükte ışınlanma tamamen kalktı | Studio'da kare süresine bak, gerekirse birleştir |
| Q23 | Kuluçka dolu kümeste teslim bekler; alternatif: dolu kümeste paraya çevir | Bekleme kalsın; şikâyet gelirse paraya çevir |
| Q24 | Tüccar: dolu bölgeli oyuncuya teklif yok; `MERCHANT.chance` 0.75 ile sıklık arttı | Telemetriden ziyaret/alım oranına bak |
| Q25 | Mevsim oku görevdeki (üretim/eklenti) hayvanda da görünür | Kabul et; istenmezse görevdekileri ele |

## 8. Sıradaki adımlar

| # | Adım | Model | Efor |
|---|---|---|---|
| 1 | Birleşik Studio testi (§6, A-D ve H önce) ve bulguları düzeltme | Kullanıcı + Sonnet (düzeltme) | M |
| 2 | Ses: kimlik seç, 32 yuvayı bağla, müzik ayrı grup | Kullanıcı seçer, Sonnet bağlar | S |
| 3 | K1 admin kararı + DataStore bütçe denetimi (6.4b) ve bozuk `_session` yedek yolu (6.4c) | Sonnet | S |
| 4 | **K2** Robux açılışı (kimlikler sonrası) ve yayın süreci (`place-vN`, Maturity anketi) | Sonnet + Opus (para/kayıt incelemesi) | M |
| 5 | Telemetri verisiyle denge ve K3 (lobi) kararı | Opus + Sonnet | M |
| 6 | es/pt anadil incelemesi | Kullanıcı / dış | S |
| 7 | Kalan tip borcu (214), Presentation↔Services döngüsü (1.2), `withFarmContext` sarmalayıcısı (1.1) | Sonnet | M |
| 8 | P9 CI (şimdilik yapılmıyor; `verify.ps1 -RequireTypes` yerelde yeterli) | Sonnet | S |

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
- Sonraki temizlik turu: `docs/ANALIZ_RAPORU.md` (metni git geçmişinde) ve `docs/SES_LISTESI.md` (`SESLER.md` §6'ya birleşti) silindi; `.test-build/` ve `sourcemap.json` artıkları temizlendi; `economy-data.mdc`'deki bayat tempo cümlesi kaldırıldı.
- `docs/SONNET_IS_PAKETLERI.md`: P12 ve diğer yapılan işler çıkarılabilir; yalnızca P9 (ertelendi) ve K1-K3 anlamlı.
