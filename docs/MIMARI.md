# Kod mimarisi

Bu belge kodun **nereye** konacağını ve **kime bağlanabileceğini** belirler. İnsanlar ve AI araçları yeni kod yazmadan
önce buraya bakar. Kurallar `python scripts/check-architecture.py` ile denetlenir (`verify.ps1` çalıştırır).

## Büyük resim

Roblox'ta üç yürütme alanı vardır ve her biri bir Rojo klasörüdür:

| Alan | Klasör | Çalıştığı yer |
|---|---|---|
| Ortak | `src/shared` | Sunucu ve istemci (saf mantık, veri, tipler) |
| Sunucu | `src/server` | Yalnızca sunucu (otorite: para, kayıt, güvenlik) |
| İstemci | `src/client` | Oyuncunun cihazı (ekran, efekt, etkileşim) |

Temel ilke: **sunucu karar verir, istemci gösterir.** Hesap gerektiren her şey `shared` içinde tek yerde durur
(`FarmMath`), sunucu uygular, istemci aynı sonucu ekranda gösterir.

## Sunucu (`src/server`)

Bağımlılık yönü: aşağıdaki liste **alttan üste**; bir katman kendi ve altındaki katmanları kullanabilir.

| Katman | Klasör | İş | Ne koyulur |
|---|---|---|---|
| 1 | `Modules/` | Saf sunucu mantığı | Kayıt: `SaveCodec/` (şema sınırı; `init` tek giriş decode/encode/newFarm, parçalar `Farm`, `Animals`, `Production`, `Tasks`, `Goods` (depo+sipariş), `Inventory`, `Account` (hesap alanları), `Common`), `SessionLock` (oturum kilidi dönüşümleri), `SaveBackup` (yedek/boyut), `Preferences` (ses düzeyi ve hareket azaltma tercihleri: doğrulama ve öznitelikler), `FarmProfiles` (çiftlik profilleri), `TelemetryLogic` (telemetri: olay adları, yuvarlama, toplama, bütçe). Güvenlik ve sayaç: `RateLimiter` (eylem başına hız sınırı + istek kimliği), `AdminPolicy` (yetki yalnızca UserId), `TransferRules` (para gönderme tutar/bakiye/tavan kuralları), `ReceiptLog` (makbuz günlüğü), `Metrics` (sunucu sayaçları), `AssetSanitizer` (içe aktarılan görsel temizliği). Üretim: `ProductionRules` (kurallar), `ProductionLogic` (parti başlat/teslim, yardımcı çekirdeği). Yardımcı: `ExtensionAreas` (eklenti hayvan alanı), `InstanceUtil`. Roblox servisine ya da başka katmana bağlanmaz (`Metrics`, `RateLimiter` ve `AssetSanitizer` yalnızca kendi tek servisini kullanır). |
| 2 | `World/` | **Statik harita** (Studio'da bir kez kurulup place'e kaydedilir) | `MapBuilder` (sürüm, doğrulama, ışık/deniz, `build`/`ensure`), `MapLayout` (düzen sabitleri ve yerleşimler), `MapParts` (yapı taşları), `IslandBuilder`, `SatelliteBuilder`, `HubBuilder`, `WorldDecor` (cephe; `DecorParts`, `DecorProps`, `DecorShore`, `DecorNature`, `DecorLights`), `HomeBuildings` (ana ada yapıları: `assets/HomeModels` modellerini yerleştirir, gece ışığı/duman/kanat/pazar etkileşimini ekler), `HubNpcs`, `IslandSpecialization` (+ `IslandLayout`, `IslandSiteParts`), `IslandLooks` (küçük ada görünümü verisi: zemin/bölge rengi ve süsler; yeni ada = bir satır), `MapMountains` (çevre dağ halkası), `ModelAssets` (hazır modellerin ortak yükleyicisi: `ServerStorage.Assets.<klasör>.<ad>`; model yoksa çağıran bir kez uyarır ve o görünümü çizmez, yedek kod kurucusu yoktur), `BarnVisualService`, `SharedRef` (`Shared` klasörüne tek ulaşma yeri). Oyun servislerini bilmez; eklenti (`plugin/`) bu klasörü kopyalayıp çalıştırır, bu yüzden yalnızca `World` kardeşlerini ve `Shared`'ı `require` eder (`Shared`'a `SharedRef` ile ulaşılır). |
| 3 | `Presentation/` | **Durumdan dünyaya çizim** (oyuncu verisi değişince yeniden çizilir) | `AnimalVisualService` (+ `AnimalModels` (assets/Animals modelini klonlar; ırk kademesine göre boy/ton + assets/AnimalLineage aksesuarları), `AnimalPlacement`, `AnimalLabels`), `JobMarks` (bina üstü iş ilerlemesi işaretleri), `UpgradeVisualService` (+ `UpgradeParts`, `UpgradeSites`; bina görselleri assets/Buildings (Sv.0) ve assets/BuildingLevels/<id>_Lv1-5 modelleridir), `ZoneVisualService` (assets/ZoneDecor, ZoneFlags, ZoneLevels modelleri), `ExtensionVisualService`, `CollectorVisualService`, `DecorReveal` (geliştirmeyle beliren süsler), `UpgradeLevelProps` (seviyeli yükseltme süsleri). Kayıt nesnesini okur, dünyayı günceller; para/kayıt yazmaz. |
| 4 | `Services/` | **Oyun mantığı ve çalışma anı durumu** | `PlayerDataService` (oyuncu oturumu/facade: tryGet, addCash, trySpend, pushState), `SaveStore` (DataStore: oturum kilidi, sıralı yazım, yedek, kurtarma; DataStore'a dokunan tek dosya), `PlotService`, `EconomyService`, `AnimalService`, `UpgradeService`, `ProductionService`, `ContractService`, `SeasonService`, `InventoryService`, `MainFarmService`, `ExtensionService`, `BuyPadService`, `EngagementService`, `MonetizationService`, `AdminService` (kendi profili/sunucu), `AdminPlayerService` (yönetici → başka oyuncu: para ver/al, özet, at), `DataResetService` (yönetici "herkesi sıfırla": veri çağını artırır, oyuncuları atar; bkz. roblox-save-schema), `TransferService` (oyuncudan oyuncuya para; kurallar `Modules/TransferRules`), `AnimalTaskService` (süreli hayvan görevleri), `PetService` (yardımcılar), `HubBoardService` (meydan sıralama panosu), `RequestGuard` (Remote işleyicilerinin ortak etkin-çiftlik kontrolü ve hız sınırı cevabı), `TelemetryService` (AnalyticsService olayları; bkz. `docs/TELEMETRI.md`). Remote dinler, doğrular, ödeme/kayıt yapar, `Presentation`'ı çağırır. |
| — | `init.server.luau` | Bileşim noktası | Servisleri başlatır ve Remote'ları bağlar; iş mantığı içermez. |

Kurallar:
- `World` hiçbir zaman `Services`/`Presentation`'a bağlanmaz (eklenti bağımsız çalışabilsin).
- `Presentation` para/kayıt değiştirmez; `Services`'e yalnızca tembel `require` ile (döngü) ve `scripts/check-architecture.py` `ALLOW` listesindeki dosyalarda.
- Her Remote işleyicisi: oyuncu/argüman doğrula → hız sınırı → sunucuda hesapla → kaydet → `pushState`.

## İstemci (`src/client`)

Bağımlılık yönü alttan üste: `Core` ← `Effects` ← `Ui` ← `Interaction`.

| Katman | Klasör | İş | Örnekler |
|---|---|---|---|
| 1 | `Core/` | Durum, satın alma, yerelleştirme, ses yardımcısı | `ClientState`, `PurchaseController`, `IslandContext`, `Localizer`, `Preferences` (kayıtlı ses/hareket tercihlerini istemciye uygular ve sunucuya gönderir), `Sfx`, `EffectSettings` (ReducedMotion/EffectsQuality önbelleği), `ClientModelAssets` (istemci efekt modelleri: `ReplicatedStorage.ClientAssets`, kaynak `client-assets/`), `LightingPresets` (Studio'daki `Lighting.Presets` değerlerini okur; dosya `src/lighting/Presets.rbxmx`), `StartupGate` (açılış yükünü yayan sıralı başlatıcı), `ClientBootstrap` |
| 2 | `Effects/` | Görsel/işitsel atmosfer (oyun durumuna dokunmaz) | `DayNight`, `WeatherEffects`, `WeatherPrecip`, `SeasonalScenery`, `Underwater`, `Graphics`, `Birds`, `FishLife`, `SeabedLife`, `ShoreIce`, `BuildEffects`, `AnimalAnimator`, `BoatAnimator`, `Windmill`, `PetAnimator`, `SeasonSignal` (hayvan isim etiketi mevsim/hava kenarlığı), `Soundscape` |
| 3 | `Ui/` | Ekran arayüzü ve dünyada duran arayüz | `UiKit` (cephe; gövde `Kit/`: `Tokens`, `Base`, `Controls`, `Flags`, `Windows`, `Toasts`), `FarmHud` (yalnızca orkestrasyon), `Hud/*` (pencere ve bölümler; `StatsPanel`, `GoalCard`, `MenuBar`, `Celebration` ana HUD parçaları), `IslandManager` (Adalar menüsü), `IncomeBubbles`, `SettingsMenu`, `AdminPanel`, `SendMoney` (Para gönder penceresi), `ProductionPanel`, `TravelMenu` |
| 4 | `Interaction/` | Oyuncunun dünyayla etkileşimi | `BuyPads`, `CollectorGuide`, `GoldenAnimal`, `HubNpcs`, `TutorialMarker` (ilk adımların dünya işareti), `IslandAutoSelect`, `IslandPrompts`, `Sprint`, `BridgeBoost` (köprüde hız), `CharacterSafety`, `WelcomeBack`, `EventSounds` (olay sesleri), `JobProgress` (iş ilerleme çubuğu), `MenuZoom` (pencere açıkken kamera yakınlaştırma) |
| — | `init.client.luau` | Giriş noktası | Yalnızca karşılama günlüğü |

Kurallar:
- İstemci sunucu klasörlerine ve `ServerStorage`'a erişmez; konuşma `Remotes` ile olur.
- Yeni ekran → `Ui/Hud/<Ad>.luau` (`create` + `update`) ve menü karosu; `FarmHud`'a mantık yığma.
- Yeni atmosfer/efekt → `Effects/`; `EffectsQuality` ve `ReducedMotion`'a uy.
- Kalite profilini yalnızca `Effects/Graphics.client.luau` yazar.

## Ortak (`src/shared`)

| Dosya/klasör | İş |
|---|---|
| `Config/` | **Tüm oyun dengesi ve veri** (fiyat, gelir, yol haritası, profiller). `init.luau` parçaları birleştirir ve getter'ları tutar; veri `Core` (sabitler), `Weather`, `Economy`, `Difficulty` (çiftlik zorluğu ve dinamik fiyat katmanı), `Shop`, `Items`, `Goods` (depo/ürün), `Achievements`, `Audio`, `Islands` (adalar/temalar/yol haritası), `Upgrades`, `Production`, `Animals` (bölgeler/hayvanlar), `Species` (**hayvan türü tablosu**: yeni hayvan = bir satır; hayvan, ürün, ada, bölge, fabrika, ürün merkezi, yükseltmeler, tarifler, mevsim/hava etkisi bundan türer), tipler `Types`. Denge başka yerde yazılmaz. |
| `GameTypes.luau` | Kayıt ve ortak tipler |
| `Remotes.luau` | Tüm RemoteEvent adları tek listede |
| `Modules/` | Saf mantık: `FarmMath` (tüm hesaplar), `Environment`, `Inventory`, `Rewards`, `Merchant` (ziyaret/teklif durumu), `Golden`, `SeasonVisuals`, `PetMotion` (yardımcı hareketi), `OnboardingSteps` (ilk adımlar), `UiScale` (ekran ölçeği) |
| `Locales/` | Çeviriler (tr kaynak; en, de, ru, es, pt) |
| `UiTheme.luau`, `WorldUi.luau`, `Localization.luau` | Tema, dünya tabelaları, dil seçimi |
| `MapPaths.luau` | Taş yol listesi (harita çizimi ve yardımcı rotası aynı listeyi kullanır) |

Kural: `shared` sunucu ya da istemci klasörlerine bağlanmaz.

## Veri akışı (bir satın alma örneği)

1. İstemci: `PurchaseController.submit("RequestBuyUpgrade", id)` → `Remotes`
2. Sunucu `Services/UpgradeService`: doğrula → `FarmMath.getUpgradeCost` ile hesapla → `PlayerDataService.trySpend` → kaydı değiştir
3. `PlayerDataService.pushState` → istemcide `ClientState` güncellenir → `Ui` yeniden çizer
4. `PlotService.refreshPlayerWorld` → `Presentation/*` dünyayı günceller

## Yeni şey nereye?

| Yeni şey | Yer |
|---|---|
| Fiyat/gelir/profil | `shared/Config/` (ilgili veri dosyası) |
| Yeni hayvan türü (ada, ürün, fabrika dahil) | `shared/Config/Species.luau` satırı + `THEMES` + `World/IslandLooks` + `assets/Animals/<id>`, `assets/Buildings/<fabrika ve merkez id>`, `assets/ZoneDecor/Decor_<id>_pen` modelleri (bkz. `docs/ADA_TASARIMI.md`, `scripts/check-assets.py`) |
| Hesap/formül | `shared/Modules/FarmMath/` (ilgili alan dosyası: `Core`, `Recipes` (parti seçeneği çözümü), `Contracts` (ahır siparişleri), `Goods` (ahır deposu), `Expansion`, `Production`, `Income`, `Animals`, `Islands`, `Lineage`, `Counts`, `Format`; testle) |
| Oyun kuralı + Remote | `server/Services/<Ad>Service.luau` + `shared/Remotes.luau` |
| Kayıt alanı | `GameTypes` + `server/Modules/SaveCodec/` (ilgili parça) + test |
| Dünyada görünen durum | `server/Presentation/` |
| Statik harita parçası | `server/World/` (+ `MAP_VERSION`) |
| Pencere/panel | `client/Ui/Hud/` |
| Ses/görsel atmosfer | `client/Effects/` |
| Oyuncu etkileşimi (prompt, tıklama) | `client/Interaction/` |
| Ortak saf mantık | `shared/Modules/` |

## Bilinen mimari borç

- `Presentation` ↔ `Services` döngüsü (`PlotService` görselleri çağırır, bazı görseller servisleri okur) tembel `require` ile kırılıyor; bir arayüz (olay) katmanıyla kaldırılabilir.
