# AI Asistanları İçin Proje Rehberi

Bu dosya Claude, Cursor, Copilot, Codex gibi AI araçlarının projeyi doğru anlaması için yazıldı.
(`CLAUDE.md`, `.cursorrules` ve `.github/copilot-instructions.md` bu dosyaya yönlendirir; Codex/Gemini gibi araçlar `AGENTS.md`'yi doğrudan okur.)

## AI rehber seti (tek kaynak)
- Bu dosya: her zaman geçerli temel kurallar ve **hangi dosyaya dokunurken hangi kural dosyasının okunacağı** (aşağıdaki tablo).
- `docs/MIMARI.md`: kodun **nereye konacağı** ve katmanların kime bağlanabileceği (yeni dosya açmadan önce oku).
- `.cursor/rules/*.mdc`: dosya türüne göre kapsamlı kurallar (Cursor otomatik yükler; Claude için
  eşleme tablosu `CLAUDE.md`'de). Stil, sunucu güvenliği, UI/HUD, yerelleştirme, harita/ışık,
  ekonomi/kayıt, client performansı, testler.
- `.cursor/skills/<ad>/SKILL.md`: adım adım iş akışları — remote ekleme, UI ekleme, içerik/denge,
  harita değişikliği, çeviri, kayıt şeması, doğrulama. `.claude/skills/` bunlara yönlendirir.
- `docs/GPT_MODEL_IS_LISTESI.md`: model üreten yapay zekâya verilen iş listesi (kodla çizilen görselleri modele çevirme: ölçü/renk/parça adı şartnameleri, teslim yolu, doğrulama).
- Kural değişirse önce ilgili `.mdc`/`SKILL.md`'yi güncelle; aynı bilgiyi iki yere kopyalama.
- Kural/skill/yönlendirme dosyalarının tutarlılığı `python scripts/check-ai-docs.py`, katman bağımlılıkları `python scripts/check-architecture.py` ile denetlenir (`verify.ps1` ikisini de çalıştırır).

### Dokunduğun yere göre okunacak kural dosyası
Cursor bunları dosya türüne göre otomatik yükler; diğer araçlar (Claude, Copilot, Codex...) ilgili dosyaya
dokunmadan önce satırdaki kural dosyasını **bir kez** okumalı (hepsini baştan okuma).

| Dokunduğun yer | Oku |
|---|---|
| Herhangi bir `.luau` | `.cursor/rules/luau-style.mdc` |
| `src/server/**` | `.cursor/rules/server-security.mdc` |
| `src/client/**`, `UiTheme`, `WorldUi`, `src/first/**` | `.cursor/rules/client-ui.mdc` |
| Oyuncuya görünen metin | `.cursor/rules/localization.mdc` |
| `src/server/World/**` (MapBuilder, WorldDecor, HomeBuildings, HubNpcs...), `src/server/Presentation/**` (`*VisualService`), `plugin/**`, `src/client/Effects/**` (DayNight, WeatherEffects, Underwater, Graphics...) | `.cursor/rules/world-map.mdc` |
| `Config`, `FarmMath`, `GameTypes`, `SaveCodec`, `PlayerDataService`, `EconomyService` | `.cursor/rules/economy-data.mdc` |
| `src/client/**/*.client.luau` (özellikle `Effects/` ve `Interaction/`) efekt/görsel scriptleri | `.cursor/rules/client-performance.mdc` |
| `tests/**`, `scripts/**`, `docs/MIMARI.md`, proje/araç ayarları | `.cursor/rules/tests-tooling.mdc` |

### İş akışı skill'leri
Tam metin `.cursor/skills/<ad>/SKILL.md` içindedir (`.claude/skills/<ad>/SKILL.md` yalnızca oraya yönlendirir):
`roblox-add-remote`, `roblox-add-ui`, `roblox-add-content`, `roblox-map-change`, `roblox-localize`,
`roblox-save-schema`, `roblox-verify`.

## Proje
- Roblox oyunu, **Luau** dili ile yazılıyor (C# değil, Lua değil — Luau).
- Kod dosya sisteminde tutulur ve **Rojo** ile Roblox Studio'ya senkronize edilir.
- Geliştirici C# geçmişine sahip; açıklamalarda C# karşılaştırmaları faydalı.

## Klasör → Roblox eşlemesi (`default.project.json`)
| Klasör | Roblox konumu | Nerede çalışır |
|---|---|---|
| `src/server` | `ServerScriptService.Server` (`Modules`, `World`, `Presentation`, `Services`) | Sadece sunucu |
| `src/client` | `StarterPlayer.StarterPlayerScripts.Client` (`Core`, `Effects`, `Ui`, `Interaction`) | Sadece oyuncunun cihazı |
| `src/shared` | `ReplicatedStorage.Shared` | İkisi de erişebilir |
| `src/first` | `ReplicatedFirst` | Client'ta ilk çalışan (yükleme ekranı) |

## Mimari (kod nereye konur?) — önce `docs/MIMARI.md`
Sunucu katmanları (alttan üste, yukarıya bağımlılık yok): `Modules/` (saf mantık) → `World/` (statik harita, eklenti de çalıştırır) →
`Presentation/` (durumdan dünyaya çizim) → `Services/` (oyun mantığı, Remote). İstemci: `Core/` → `Effects/` → `Ui/` → `Interaction/`.
`shared` sunucu/istemciye bağlanmaz; tüm denge `Config`'te, tüm hesap `FarmMath`'te. Kurallar `python scripts/check-architecture.py` ile denetlenir.
Yeni dosya eklerken `docs/MIMARI.md`'deki "Yeni şey nereye?" tablosuna bak.

## Dosya adlandırma (Rojo kuralları)
- `*.server.luau` → Script (sunucu)
- `*.client.luau` → LocalScript (client)
- `*.luau` → ModuleScript
- `init.server.luau` / `init.client.luau` → klasörün kendisi o script olur

## Kod kuralları
- Her dosyanın başında `--!strict` olsun, tip anotasyonları kullan.
- Servisleri `game:GetService("...")` ile al, `game.Workspace` gibi doğrudan erişme.
- `wait()`, `spawn()`, `delay()` KULLANMA → `task.wait()`, `task.spawn()`, `task.delay()` kullan.
- Diziler 1'den başlar.
- String interpolasyon için backtick kullan: `` `Merhaba {name}` ``.
- Sekme (tab) ile girinti, StyLua formatına uy (`stylua.toml`).

## Güvenlik (çok önemli)
- **Client'a asla güvenme.** Para, can, hasar, envanter gibi her şey sunucuda hesaplanır ve doğrulanır.
- RemoteEvent argümanlarını sunucuda her zaman tip ve mantık olarak kontrol et.
- Gizli değerleri `src/shared` içine koyma; client da görebilir.

## Remote'lar
- Tüm RemoteEvent/RemoteFunction'lar `src/shared/Remotes.luau` içindeki listeye eklenir.
- Sunucu `Remotes.init()` çağırır, iki taraf `Remotes.get("Ad")` ile erişir.
- Çiftliğe bağlı Remote işleyicileri etkin çiftlik ve hız sınırı için `Services/RequestGuard`, `Modules/RateLimiter` kullanır.
- Kayıt: şema `GameTypes` + `Modules/SaveCodec/` (decode/encode; sürüm `SessionLock.VERSION`); DataStore'a yalnızca `Services/SaveStore.luau` dokunur (`check-architecture.py` denetler), `PlayerDataService` oturum/facade'dır.

## Harita
- Harita `src/server/World/MapBuilder.luau` (+ `MapLayout`, `MapParts`, `MapMountains`, `IslandBuilder`, `SatelliteBuilder`, `HubBuilder`) ile üretilir; Studio'da `plugin/` eklentisinin
  "Haritayı Kur" butonuyla düzenleme modunda kurulup place'e kaydedilir.
- Bina/hayvan modellerini Studio'da (MCP ajanıyla) yapma: `docs/MODEL_SOZLESMESI.md` (kurallar) ve `docs/MODEL_IS_PLANI.md` (iş akışı, pilot). Modeller `ServerStorage.Assets` altına doğrudan değil, repodaki `assets/` dosyasından gelir.
- Meydandaki satıcı NPC'ler `HubNpcs.luau`, genel ada yapıları `HomeBuildings.luau`. Tabelalar uzun direklere asılır, tahtası çarpışmaz
  (yol kapanmasın); dekor kurulumunun sonunda `WorldDecor.optimize` çağrılır.
- Place'e kaydedilen düzen değişince `MapBuilder.luau`'daki `MAP_VERSION`'ı artır (çalışma anı `Presentation/` için gerekmez). Temaya bağlı ada içeriği sunucu açılışında `ServerStorage.ThemeTemplates` şablonlarına kurulur,
  çiftlik değişince `MapBuilder.applyTheme` şablonu Clone eder. `World` dosyaları `Shared`'ı yalnızca
  `World/SharedRef.luau` üzerinden alır (eklenti modülleri kopyalayıp çalıştırır; kopyadaki `Shared`'ı o bulur) — bunu bozma;
  `World` yalnızca `World`/`Shared` require eder (`check-architecture.py` denetler).
- Gece ışığı: parça `NightLight`/`NightWindow` etiketi + `NightColor` + kapalı `PointLight` alır
 (`WorldDecor.lamp` / `smallLamp` / `markNightWindow`). Gece/gündüz Lighting değerlerini yalnızca
 `DayNight.client` yazar; `WeatherEffects` pozlamayı `Lighting.WeatherExposure` özniteliğiyle bildirir.
  Gündüz/gece/hava/mevsim değerleri kodda değil Studio'daki `Lighting.Presets` klasöründedir (`src/lighting/Presets.rbxmx`, okuyucu `Core/LightingPresets`).
- Oyun dengesi (fiyat, gelir, yol haritası) sadece `src/shared/Config/` içinde (`init.luau` birleştirir; veri ilgili dosyada: fiyat/yükseltme `Upgrades`, hayvan/bölge `Animals`, ada/tema `Islands`, üretim `Production`, depo ürünleri `Goods`, eşya/olay/ürün `Shop`/`Items`, mevsim/hava `Weather`, ses `Audio`, sabitler `Core`/`Economy`).
- Her çiftlik = ana ada + 3 küçük ada, **her adada tek hayvan**, hiçbir hayvan iki çiftlikte yok (24 tür; `docs/ADA_TASARIMI.md`). Her ana çiftlik kendi hayvanıyla başlar (`theme.homeAnimal`); hayvan→ada→çiftlik eşlemesi
  `THEMES` + `FARM_ISLANDS[ada].animalId`. Yeni hayvan = `Config/Species.luau` satırı (yükseltme/tarif/ürün/ada türer) + görsel şablon satırları. Süt Adası yoktur.
  Bölge izni `Config.zoneAllows`/`FarmMath.zoneAllows` ile sorulur, `allowedAnimals`'a doğrudan bakılmaz.
- Her oyuncunun takımadası: ana ada + uzman adalar (`Config.FARM_ISLANDS`). Bölgeler bir adaya bağlıdır
  (`ZONES[x].island`); açık adalar/bölgeler `FarmMath.applyDerived` ile `purchased`'dan türetilir.

## Arayüz (UI) standardı
- Ekran arayüzü `src/client/Ui/UiKit.luau` (gövde `Ui/Kit/`) bileşenleriyle yazılır (panel, window, card, button, menuButton,
  closeButton, badge, progressBar, toastHost). Renk/yazı tipi/boyutu UiKit tablolarından al, elle değer yazma.
- Dünyadaki tabelalar (BillboardGui/SurfaceGui) `src/shared/WorldUi.luau` ile yazılır: `tag` (havada etiket),
  `sign` (tahta tabela yüzü); güncellemek için `setTag` / `setSignText`.
- Renk, yazı tipi ve boyutların tek kaynağı `src/shared/UiTheme.luau` (UiKit ve WorldUi ikisi de kullanır). Ekran ölçeği `UiKit.screenScale` / `Shared/Modules/UiScale` ile hesaplanır; elle ölçek yazma.
- Emoji sadece ikon kutusunda (`UiKit.iconChip`, WorldUi'nin `icon` alanı); metinlerde emoji yok.
  Kapat/bildirim işaretleri çizilir.
- Buton tipleri: primary = alınabilir, warning = para yetmiyor, disabled = kilitli/dolu, owned = alındı.
- HUD bölgeleri: sol orta `Stats` paneli (sola kayarak kapanır), üst orta menü çubuğu (Pazar, Yükseltmeler, Yol Haritası, Üretim, Adalar), sağ orta menü sütunu (Envanter, Ödüller, Adama Dön, Ayarlar),
 sağda pencereler, üst ortada bildirimler. Sağ üst (oyuncu listesi) ve sol üst (sohbet) boş kalır.
 Menü karoları kademeli açılır (yeni oyuncu Pazar/Ödüller/Ayarlar görür); ipucu satırı yalnızca sorun varken çıkar. Ayrıntılı bilgi ana HUD'a değil ilgili pencereye (ödüller "Ödüller" penceresine) gider. Sipariş Panosu, Eşya Dükkânı, Envanter, Pazar, Yol Haritası ve Yükseltmeler
  ayrı pencerelerdir; pencere ve bölüm kodu `src/client/Ui/Hud/` altında, `FarmHud.client.luau` yalnızca orkestrasyondur.
- Sunucu bildirim (Notify) metinlerine emoji koyma; bildirimin türü (success/error/money/info) işareti belirler.

## Yerelleştirme (diller)
- Desteklenen diller `Config.LANGUAGES` içinde: Türkçe (kaynak), İngilizce, Almanca, Rusça, İspanyolca, Portekizce (pt-BR); hitap: ru "ты", es "tú", pt "você".
- Kod Türkçe metin yazmaya devam eder; `src/client/Core/Localizer.client.luau` ekrandaki ve tabelalardaki
  (TextLabel/TextButton/ProximityPrompt) yazıları çevirir. Sunucu bildirimleri de böyle çevrilir, sunucuda dil bilinmez.
- **Yeni metin eklediysen** `src/shared/Locales/` altındaki tüm sözlüklere (`en`, `de`, `ru`, `es`, `pt`) aynı Türkçe anahtarla çeviri ekle.
  Değişken içeren metinlerde boşluğu `{}` yaz, hedefte `{1}`, `{2}` kullan (örn. `["Önce: {}"] = "Requires: {1}"`).
  Parçalar " · ", satır sonu ve ", " ile ayrı ayrı da çevrilir; hazır ifadeyi tek başına sözlüğe eklemek yeterli.
- Metni sunucuda parçalayıp birleştirme; olduğu gibi tam cümle kur ki sözlük eşleşebilsin. Bulunamayan metin Türkçe kalır.
- Dil seçimi: ilk girişte Roblox sistem dilinden (`LocaleId`); desteklenmiyorsa İngilizce (ülkeye bakılmaz). Ayarlar → Dil ile değişir ve
  sunucuda `save.language` olarak saklanır (`RequestSetLanguage`, `SavedLanguage` özniteliği).
- Bayraklar emoji değil, `UiKit.flag` ile şekillerle çizilir (Roblox yazı tipleri bayrak emojisini göstermez).

## Grafik ve atmosfer
- Grafik kademesi (Otomatik/Düşük/Orta/Yüksek, hesaba kayıtlı `save.graphics`) yalnızca `src/client/Effects/Graphics.client.luau`'da uygulanır; `EffectsQuality` ve `ReducedMotion` (`Core/EffectSettings`) yeni efektlerde zorunlu.
  Ses düzeyleri ve hareketi azaltma da hesaba kayıtlıdır (`save.audio`, `save.reducedMotion`; `Modules/Preferences` doğrular, `Core/Preferences.client` uygular).
- Su altı (`Underwater.client`) kamera su seviyesinin altındayken renk/bulanıklık/baloncuk/ses ekler ve yağışı keser (`Submerged`).

## Araçlar
- Rokit (`rokit.toml`) ile: rojo, stylua, selene. Luau yorumlayıcı/derleyici/analizör `.tools/luau` altındadır (`verify.ps1 -LuauDirectory`); tip analizi için `.tools/luau-lsp`.
- Lint: `selene src plugin tests` · Format: `stylua src tests plugin` · Senkronizasyon: `rojo serve`
- Testler: `python scripts/run-tests.py` · Çeviri kapsamı: `python scripts/check-locales.py --strict-literals`
- Çiftlik kademeleri/zorluk: `python scripts/simulate-tiers.py` (`docs/ZORLUK_VE_FIYAT.md`)
- Model kapsamı (her kod görünümünün `assets/` karşılığı var mı): `python scripts/check-assets.py` (eksik = kod kurucusu silinemez; `verify.ps1` çalıştırır) · Mimari kuralları: `python scripts/check-architecture.py` · Tip analizi (yeni bulgu = hata): `python scripts/check-types.py` (araçları `powershell scripts/setup-types.ps1` `.tools/luau-lsp` altına kurar; yoksa `verify.ps1` adımı atlar, `-RequireTypes` ile hata sayar)
- Tam doğrulama: `powershell -ExecutionPolicy Bypass -File scripts/verify.ps1`
