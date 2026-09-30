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
| 1 | `Modules/` | Saf sunucu mantığı | Kayıt kodlama (`SaveCodec`), kilit, hız sınırı, kurallar. Roblox servisine ya da başka katmana bağlanmaz. |
| 2 | `World/` | **Statik harita** (Studio'da bir kez kurulup place'e kaydedilir) | `MapBuilder`, `WorldDecor`, `HomeBuildings`, `HubNpcs`, `IslandSpecialization`, `BarnVisualService`. Oyun servislerini bilmez; eklenti (`plugin/`) bu klasörü kopyalayıp çalıştırır. |
| 3 | `Presentation/` | **Durumdan dünyaya çizim** (oyuncu verisi değişince yeniden çizilir) | `AnimalVisualService`, `UpgradeVisualService`, `ZoneVisualService`, `ExtensionVisualService`, `CollectorVisualService`. Kayıt nesnesini okur, dünyayı günceller; para/kayıt yazmaz. |
| 4 | `Services/` | **Oyun mantığı ve çalışma anı durumu** | `PlayerDataService`, `PlotService`, `EconomyService`, `AnimalService`, `UpgradeService`, `ProductionService`, `OrderService`, `SeasonService`, `InventoryService`, `MainFarmService`, `ExtensionService`, `BuyPadService`, `EngagementService`, `MonetizationService`, `AdminService`. Remote dinler, doğrular, ödeme/kayıt yapar, `Presentation`'ı çağırır. |
| — | `init.server.luau` | Bileşim noktası | Servisleri başlatır ve Remote'ları bağlar; iş mantığı içermez. |

Kurallar:
- `World` hiçbir zaman `Services`/`Presentation`'a bağlanmaz (eklenti bağımsız çalışabilsin).
- `Presentation` para/kayıt değiştirmez; `Services`'e yalnızca tembel `require` ile (döngü) ve `scripts/check-architecture.py` `ALLOW` listesindeki dosyalarda.
- Her Remote işleyicisi: oyuncu/argüman doğrula → hız sınırı → sunucuda hesapla → kaydet → `pushState`.

## İstemci (`src/client`)

Bağımlılık yönü alttan üste: `Core` ← `Effects` ← `Ui` ← `Interaction`.

| Katman | Klasör | İş | Örnekler |
|---|---|---|---|
| 1 | `Core/` | Durum, satın alma, yerelleştirme, ses yardımcısı | `ClientState`, `PurchaseController`, `IslandContext`, `Localizer`, `Sfx`, `EffectSettings` (ReducedMotion/EffectsQuality önbelleği), `ClientBootstrap` |
| 2 | `Effects/` | Görsel/işitsel atmosfer (oyun durumuna dokunmaz) | `DayNight`, `WeatherEffects`, `WeatherPrecip`, `SeasonalScenery`, `Underwater`, `Graphics`, `Birds`, `FishLife`, `SeabedLife`, `ShoreIce`, `BuildEffects`, `AnimalAnimator`, `BoatAnimator`, `Windmill`, `Soundscape` |
| 3 | `Ui/` | Ekran arayüzü ve dünyada duran arayüz | `UiKit`, `FarmHud` (yalnızca orkestrasyon), `Hud/*` (pencere ve bölümler; `StatsPanel`, `GoalCard`, `MenuBar`, `Celebration` ana HUD parçaları), `IslandManager` (Adalar menüsü), `IncomeBubbles`, `SettingsMenu`, `AdminPanel`, `ProductionPanel`, `TravelMenu` |
| 4 | `Interaction/` | Oyuncunun dünyayla etkileşimi | `BuyPads`, `CollectorGuide`, `GoldenAnimal`, `HubNpcs`, `IslandAutoSelect`, `IslandPrompts`, `Sprint`, `CharacterSafety`, `WelcomeBack` |
| — | `init.client.luau` | Giriş noktası | Yalnızca karşılama günlüğü |

Kurallar:
- İstemci sunucu klasörlerine ve `ServerStorage`'a erişmez; konuşma `Remotes` ile olur.
- Yeni ekran → `Ui/Hud/<Ad>.luau` (`create` + `update`) ve menü karosu; `FarmHud`'a mantık yığma.
- Yeni atmosfer/efekt → `Effects/`; `EffectsQuality` ve `ReducedMotion`'a uy.
- Kalite profilini yalnızca `Effects/Graphics.client.luau` yazar.

## Ortak (`src/shared`)

| Dosya/klasör | İş |
|---|---|
| `Config/` | **Tüm oyun dengesi ve veri** (fiyat, gelir, yol haritası, profiller). `init.luau` parçaları birleştirir ve getter'ları tutar; veri `Core` (sabitler), `Weather`, `Economy`, `Shop`, `Items`, `Achievements`, `Audio`, `Islands` (adalar/temalar/yol haritası), `Upgrades`, `Production`, `Animals` (bölgeler/hayvanlar), tipler `Types`. Denge başka yerde yazılmaz. |
| `GameTypes.luau` | Kayıt ve ortak tipler |
| `Remotes.luau` | Tüm RemoteEvent adları tek listede |
| `Modules/` | Saf mantık: `FarmMath` (tüm hesaplar), `Environment`, `Inventory`, `Rewards`, `OrderBoard`, `Merchant`, `Golden`, `SeasonVisuals` |
| `Locales/` | Çeviriler (tr kaynak; en, de, ru) |
| `UiTheme.luau`, `WorldUi.luau`, `Localization.luau` | Tema, dünya tabelaları, dil seçimi |

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
| Hesap/formül | `shared/Modules/FarmMath.luau` (testle) |
| Oyun kuralı + Remote | `server/Services/<Ad>Service.luau` + `shared/Remotes.luau` |
| Kayıt alanı | `GameTypes` + `server/Modules/SaveCodec.luau` + test |
| Dünyada görünen durum | `server/Presentation/` |
| Statik harita parçası | `server/World/` (+ `MAP_VERSION`) |
| Pencere/panel | `client/Ui/Hud/` |
| Ses/görsel atmosfer | `client/Effects/` |
| Oyuncu etkileşimi (prompt, tıklama) | `client/Interaction/` |
| Ortak saf mantık | `shared/Modules/` |

## Bilinen mimari borç

- `MapBuilder` (~1500) ve `UpgradeVisualService` (~1200) büyük dosyalar; bölümlere ayrılabilir.
- `Presentation` ↔ `Services` döngüsü (`PlotService` görselleri çağırır, bazı görseller servisleri okur) tembel `require` ile kırılıyor; bir arayüz (olay) katmanıyla kaldırılabilir.
