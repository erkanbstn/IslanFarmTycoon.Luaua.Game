# AI Asistanları İçin Proje Rehberi

Bu dosya Claude, Cursor, Copilot, Codex gibi AI araçlarının projeyi doğru anlaması için yazıldı.
(`CLAUDE.md`, `.cursorrules` ve `.github/copilot-instructions.md` bu dosyaya yönlendirir.)

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
- Düzen değişince `MAP_VERSION`'ı artır. MapBuilder ve BarnVisualService `Shared`'ı
  `script.Parent.Parent` üzerinden de arar (eklenti modülleri kopyalayıp çalıştırıyor) — bunu bozma.
- Oyun dengesi (fiyat, gelir, yol haritası) sadece `src/shared/Config.luau` içinde.
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
- Sunucu bildirim (Notify) metinlerine emoji koyma; bildirimin türü (success/error/money/info) işareti belirler.

## Araçlar
- Rokit (`rokit.toml`) ile: rojo, stylua, selene.
- Lint: `selene src` · Format: `stylua src` · Senkronizasyon: `rojo serve`
