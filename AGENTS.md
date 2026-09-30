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

## Harita
- Harita `src/server/World/MapBuilder.luau` (+ `MapLayout`, `MapParts`, `IslandBuilder`, `SatelliteBuilder`, `HubBuilder`) ile üretilir; Studio'da `plugin/` eklentisinin
  "Haritayı Kur" butonuyla düzenleme modunda kurulup place'e kaydedilir.
- Meydandaki satıcı NPC'ler `HubNpcs.luau`, genel ada yapıları `HomeBuildings.luau`. Tabelalar uzun direklere asılır, tahtası çarpışmaz
  (yol kapanmasın); dekor kurulumunun sonunda `WorldDecor.optimize` çağrılır.
- Düzen değişince `MAP_VERSION`'ı artır. MapBuilder ve BarnVisualService `Shared`'ı
  `script.Parent.Parent` üzerinden de arar (eklenti modülleri kopyalayıp çalıştırıyor) — bunu bozma.
- Gece ışığı: parça `NightLight`/`NightWindow` etiketi + `NightColor` + kapalı `PointLight` alır
 (`WorldDecor.lamp` / `smallLamp` / `markNightWindow`). Gece/gündüz Lighting değerlerini yalnızca
 `DayNight.client` yazar; `WeatherEffects` pozlamayı `Lighting.WeatherExposure` özniteliğiyle bildirir.
- Oyun dengesi (fiyat, gelir, yol haritası) sadece `src/shared/Config/` içinde (`init.luau` birleştirir; veri ilgili dosyada: fiyat/yükseltme `Upgrades`, hayvan/bölge `Animals`, ada/tema `Islands`, sabitler `Core`).
- Her ana çiftlik kendi hayvanıyla başlar (`theme.homeAnimal`: inek/tavuk/ördek); inek olmayanlarda inek `dairy` (Süt Adası) küçük adasındadır.
  Bölge izni `Config.zoneAllows`/`FarmMath.zoneAllows` ile sorulur, `allowedAnimals`'a doğrudan bakılmaz.
- Her oyuncunun takımadası: ana ada + uzman adalar (`Config.FARM_ISLANDS`). Bölgeler bir adaya bağlıdır
  (`ZONES[x].island`); açık adalar/bölgeler `FarmMath.applyDerived` ile `purchased`'dan türetilir.

## Arayüz (UI) standardı
- Ekran arayüzü `src/client/Ui/UiKit.luau` (gövde `Ui/Kit/`) bileşenleriyle yazılır (panel, window, card, button, menuButton,
  closeButton, badge, progressBar, toastHost). Renk/yazı tipi/boyutu UiKit tablolarından al, elle değer yazma.
- Dünyadaki tabelalar (BillboardGui/SurfaceGui) `src/shared/WorldUi.luau` ile yazılır: `tag` (havada etiket),
  `sign` (tahta tabela yüzü); güncellemek için `setTag` / `setSignText`.
- Renk, yazı tipi ve boyutların tek kaynağı `src/shared/UiTheme.luau` (UiKit ve WorldUi ikisi de kullanır).
- Emoji sadece ikon kutusunda (`UiKit.iconChip`, WorldUi'nin `icon` alanı); metinlerde emoji yok.
  Kapat/bildirim işaretleri çizilir.
- Buton tipleri: primary = alınabilir, warning = para yetmiyor, disabled = kilitli/dolu, owned = alındı.
- HUD bölgeleri: sol orta `Stats` paneli (sola kayarak kapanır), üst orta menü çubuğu (Pazar, Yükseltmeler, Yol Haritası, Üretim, Adalar), sağ orta menü sütunu (Envanter, Ödüller, Adama Dön, Ayarlar),
 sağda pencereler, üst ortada bildirimler. Sağ üst (oyuncu listesi) ve sol üst (sohbet) boş kalır.
 Menü karoları kademeli açılır (yeni oyuncu Pazar/Ödüller/Ayarlar görür); ipucu satırı yalnızca sorun varken çıkar. Ayrıntılı bilgi ana HUD'a değil ilgili pencereye (ödüller "Ödüller" penceresine) gider. Sipariş Panosu, Eşya Dükkânı, Envanter, Pazar, Yol Haritası ve Yükseltmeler
  ayrı pencerelerdir; pencere ve bölüm kodu `src/client/Ui/Hud/` altında, `FarmHud.client.luau` yalnızca orkestrasyondur.
- Sunucu bildirim (Notify) metinlerine emoji koyma; bildirimin türü (success/error/money/info) işareti belirler.

## Yerelleştirme (diller)
- Desteklenen diller `Config.LANGUAGES` içinde: Türkçe (kaynak), İngilizce, Almanca, Rusça.
- Kod Türkçe metin yazmaya devam eder; `src/client/Core/Localizer.client.luau` ekrandaki ve tabelalardaki
  (TextLabel/TextButton/ProximityPrompt) yazıları çevirir. Sunucu bildirimleri de böyle çevrilir, sunucuda dil bilinmez.
- **Yeni metin eklediysen** `src/shared/Locales/en.luau`, `de.luau`, `ru.luau` içine aynı Türkçe anahtarla çeviri ekle.
  Değişken içeren metinlerde boşluğu `{}` yaz, hedefte `{1}`, `{2}` kullan (örn. `["Önce: {}"] = "Requires: {1}"`).
  Parçalar " · ", satır sonu ve ", " ile ayrı ayrı da çevrilir; hazır ifadeyi tek başına sözlüğe eklemek yeterli.
- Metni sunucuda parçalayıp birleştirme; olduğu gibi tam cümle kur ki sözlük eşleşebilsin. Bulunamayan metin Türkçe kalır.
- Dil seçimi: ilk girişte Roblox dilinden (`LocaleId`), desteklenmiyorsa ülkeden algılanır. Ayarlar → Dil ile değişir ve
  sunucuda `save.language` olarak saklanır (`RequestSetLanguage`, `SavedLanguage` özniteliği).
- Bayraklar emoji değil, `UiKit.flag` ile şekillerle çizilir (Roblox yazı tipleri bayrak emojisini göstermez).

## Grafik ve atmosfer
- Grafik kademesi (Otomatik/Düşük/Orta/Yüksek, hesaba kayıtlı `save.graphics`) yalnızca `src/client/Effects/Graphics.client.luau`'da uygulanır; `EffectsQuality` ve `ReducedMotion` yeni efektlerde zorunlu.
- Su altı (`Underwater.client`) kamera su seviyesinin altındayken renk/bulanıklık/baloncuk/ses ekler ve yağışı keser (`Submerged`).

## Araçlar
- Rokit (`rokit.toml`) ile: rojo, stylua, selene.
- Lint: `selene src` · Format: `stylua src` · Senkronizasyon: `rojo serve`
- Testler: `python scripts/run-tests.py` · Çeviri kapsamı: `python scripts/check-locales.py --strict-literals`
- Mimari kuralları: `python scripts/check-architecture.py` · Tip analizi (yeni bulgu = hata): `python scripts/check-types.py` (araçlar `.tools/luau-lsp`, `scripts/setup-types.ps1`)
- Tam doğrulama: `powershell -ExecutionPolicy Bypass -File scripts/verify.ps1`
