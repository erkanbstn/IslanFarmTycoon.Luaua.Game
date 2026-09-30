# AI Asistanları İçin Proje Rehberi

Bu dosya Claude, Cursor, Copilot, Codex gibi AI araçlarının projeyi doğru anlaması için yazıldı.
(`CLAUDE.md`, `.cursorrules` ve `.github/copilot-instructions.md` bu dosyaya yönlendirir; Codex/Gemini gibi araçlar `AGENTS.md`'yi doğrudan okur.)

## AI rehber seti (tek kaynak)
- Bu dosya: her zaman geçerli temel kurallar ve **hangi dosyaya dokunurken hangi kural dosyasının okunacağı** (aşağıdaki tablo).
- `.cursor/rules/*.mdc`: dosya türüne göre kapsamlı kurallar (Cursor otomatik yükler; Claude için
  eşleme tablosu `CLAUDE.md`'de). Stil, sunucu güvenliği, UI/HUD, yerelleştirme, harita/ışık,
  ekonomi/kayıt, client performansı, testler.
- `.cursor/skills/<ad>/SKILL.md`: adım adım iş akışları — remote ekleme, UI ekleme, içerik/denge,
  harita değişikliği, çeviri, kayıt şeması, doğrulama. `.claude/skills/` bunlara yönlendirir.
- Kural değişirse önce ilgili `.mdc`/`SKILL.md`'yi güncelle; aynı bilgiyi iki yere kopyalama.
- Kural/skill/yönlendirme dosyalarının tutarlılığı `python scripts/check-ai-docs.py` ile denetlenir (`verify.ps1` çalıştırır).

### Dokunduğun yere göre okunacak kural dosyası
Cursor bunları dosya türüne göre otomatik yükler; diğer araçlar (Claude, Copilot, Codex...) ilgili dosyaya
dokunmadan önce satırdaki kural dosyasını **bir kez** okumalı (hepsini baştan okuma).

| Dokunduğun yer | Oku |
|---|---|
| Herhangi bir `.luau` | `.cursor/rules/luau-style.mdc` |
| `src/server/**` | `.cursor/rules/server-security.mdc` |
| `src/client/**`, `UiTheme`, `WorldUi`, `src/first/**` | `.cursor/rules/client-ui.mdc` |
| Oyuncuya görünen metin | `.cursor/rules/localization.mdc` |
| `MapBuilder`, `WorldDecor`, `HomeBuildings`, `HubNpcs`, `*VisualService`, `plugin/**`, `DayNight`, `WeatherEffects` | `.cursor/rules/world-map.mdc` |
| `Config`, `FarmMath`, `GameTypes`, `SaveCodec`, `PlayerDataService`, `EconomyService` | `.cursor/rules/economy-data.mdc` |
| `src/client/*.client.luau` efekt/görsel scriptleri | `.cursor/rules/client-performance.mdc` |
| `tests/**`, `scripts/**`, proje/araç ayarları | `.cursor/rules/tests-tooling.mdc` |

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
| `src/server` | `ServerScriptService.Server` | Sadece sunucu |
| `src/client` | `StarterPlayer.StarterPlayerScripts.Client` | Sadece oyuncunun cihazı |
| `src/shared` | `ReplicatedStorage.Shared` | İkisi de erişebilir |
| `src/first` | `ReplicatedFirst` | Client'ta ilk çalışan (yükleme ekranı) |

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
- Harita `src/server/Services/MapBuilder.luau` ile üretilir; Studio'da `plugin/` eklentisinin
  "Haritayı Kur" butonuyla düzenleme modunda kurulup place'e kaydedilir.
- Meydandaki satıcı NPC'ler `HubNpcs.luau`, genel ada yapıları `HomeBuildings.luau`. Tabelalar uzun direklere asılır, tahtası çarpışmaz
  (yol kapanmasın); dekor kurulumunun sonunda `WorldDecor.optimize` çağrılır.
- Düzen değişince `MAP_VERSION`'ı artır. MapBuilder ve BarnVisualService `Shared`'ı
  `script.Parent.Parent` üzerinden de arar (eklenti modülleri kopyalayıp çalıştırıyor) — bunu bozma.
- Gece ışığı: parça `NightLight`/`NightWindow` etiketi + `NightColor` + kapalı `PointLight` alır
 (`WorldDecor.lamp` / `smallLamp` / `markNightWindow`). Gece/gündüz Lighting değerlerini yalnızca
 `DayNight.client` yazar; `WeatherEffects` pozlamayı `Lighting.WeatherExposure` özniteliğiyle bildirir.
- Oyun dengesi (fiyat, gelir, yol haritası) sadece `src/shared/Config.luau` içinde.
- Her ana çiftlik kendi hayvanıyla başlar (`theme.homeAnimal`: inek/tavuk/ördek); inek olmayanlarda inek `dairy` (Süt Adası) küçük adasındadır.
  Bölge izni `Config.zoneAllows`/`FarmMath.zoneAllows` ile sorulur, `allowedAnimals`'a doğrudan bakılmaz.
- Her oyuncunun takımadası: ana ada + uzman adalar (`Config.FARM_ISLANDS`). Bölgeler bir adaya bağlıdır
  (`ZONES[x].island`); açık adalar/bölgeler `FarmMath.applyDerived` ile `purchased`'dan türetilir.

## Arayüz (UI) standardı
- Ekran arayüzü `src/client/UiKit.luau` bileşenleriyle yazılır (panel, window, card, button, menuButton,
  closeButton, badge, progressBar, toastHost). Renk/yazı tipi/boyutu UiKit tablolarından al, elle değer yazma.
- Dünyadaki tabelalar (BillboardGui/SurfaceGui) `src/shared/WorldUi.luau` ile yazılır: `tag` (havada etiket),
  `sign` (tahta tabela yüzü); güncellemek için `setTag` / `setSignText`.
- Renk, yazı tipi ve boyutların tek kaynağı `src/shared/UiTheme.luau` (UiKit ve WorldUi ikisi de kullanır).
- Emoji sadece ikon kutusunda (`UiKit.iconChip`, WorldUi'nin `icon` alanı); metinlerde emoji yok.
  Kapat/bildirim işaretleri çizilir.
- Buton tipleri: primary = alınabilir, warning = para yetmiyor, disabled = kilitli/dolu, owned = alındı.
- HUD bölgeleri: sol orta `Stats` paneli, alt orta menü karoları (dar ekranda sağ orta 3 karo),
 sağda pencereler, üst ortada bildirimler. Sağ üst (oyuncu listesi) ve sol üst (sohbet) boş kalır.
 Ayrıntılı bilgi ana HUD'a değil "Çiftliğim" penceresine gider. Sipariş Panosu, Eşya Dükkânı, Envanter, Pazar, Yol Haritası ve Yükseltmeler
  ayrı pencerelerdir; pencere ve bölüm kodu `src/client/Hud/` altında, `FarmHud.client.luau` yalnızca orkestrasyondur.
- Sunucu bildirim (Notify) metinlerine emoji koyma; bildirimin türü (success/error/money/info) işareti belirler.

## Yerelleştirme (diller)
- Desteklenen diller `Config.LANGUAGES` içinde: Türkçe (kaynak), İngilizce, Almanca, Rusça.
- Kod Türkçe metin yazmaya devam eder; `src/client/Localizer.client.luau` ekrandaki ve tabelalardaki
  (TextLabel/TextButton/ProximityPrompt) yazıları çevirir. Sunucu bildirimleri de böyle çevrilir, sunucuda dil bilinmez.
- **Yeni metin eklediysen** `src/shared/Locales/en.luau`, `de.luau`, `ru.luau` içine aynı Türkçe anahtarla çeviri ekle.
  Değişken içeren metinlerde boşluğu `{}` yaz, hedefte `{1}`, `{2}` kullan (örn. `["Önce: {}"] = "Requires: {1}"`).
  Parçalar " · ", satır sonu ve ", " ile ayrı ayrı da çevrilir; hazır ifadeyi tek başına sözlüğe eklemek yeterli.
- Metni sunucuda parçalayıp birleştirme; olduğu gibi tam cümle kur ki sözlük eşleşebilsin. Bulunamayan metin Türkçe kalır.
- Dil seçimi: ilk girişte Roblox dilinden (`LocaleId`), desteklenmiyorsa ülkeden algılanır. Ayarlar → Dil ile değişir ve
  sunucuda `save.language` olarak saklanır (`RequestSetLanguage`, `SavedLanguage` özniteliği).
- Bayraklar emoji değil, `UiKit.flag` ile şekillerle çizilir (Roblox yazı tipleri bayrak emojisini göstermez).

## Araçlar
- Rokit (`rokit.toml`) ile: rojo, stylua, selene.
- Lint: `selene src` · Format: `stylua src` · Senkronizasyon: `rojo serve`
- Testler: `python scripts/run-tests.py` · Çeviri kapsamı: `python scripts/check-locales.py --strict-literals`
- Tam doğrulama: `powershell -ExecutionPolicy Bypass -File scripts/verify.ps1`
