---
description: UiKit bileşenleri, tema, pencere davranışı, mobil, güvenli alan ve gamepad
paths:
  - "src/client/Ui/UiKit.luau"
  - "src/client/Ui/Kit/**"
  - "src/shared/UiTheme.luau"
  - "src/shared/WorldUi.luau"
  - "src/first/**/*.luau"
---

# Arayüz standardı: Kit

Giriş dosyası: `.claude/rules/client-ui.md` (konu haritası).

Katman: `src/client/Ui/` (UiKit, FarmHud, `Hud/*`, paneller, `IslandManager`, `IncomeBubbles`) yalnızca `Core/` ve `Effects/`'e bağlanır (bkz. `docs/MIMARI.md`).

- Bileşenler `src/client/Ui/UiKit.luau` (cephe; gövde `Ui/Kit/`: Tokens, Base, Controls, Grid, Flags, Windows, Toasts, Screen — yeni bileşeni uygun dosyaya yaz, `UiKit`'e ekle): panel, window, card, button, menuButton (karo), closeButton,
  badge, progressBar, sectionHeader, toastHost, iconChip, flag, textInput, slider, pulse, screenRoot.
  Sık güncellenen metni `UiKit.setText` ile yaz (aynı kaynak metni tekrar yazmaz; Localizer'la çift yazım olmaz).
- **Kalabalık pencereler** dikey kart listesi yerine kategori sekmesi + ızgara kullanır: `UiKit.tabs` (sekme), `UiKit.grid` (kap) ve `UiKit.tile` (ölçüler `Kit/Grid.luau`'da; `UiKit.card` ile aynı alanlar
  — frame/icon/title/detail/action — olduğu için kart güncelleme kodu karoyla aynen çalışır; kart metni doğal yükseklikle büyür; fiyat/aksiyon kırpılmaz). Genişliğe göre sütun sayan hali: `UiKit.autoGrid` / `autoTile`. Örnekler: Eşya Dükkânı (slot sekmeleri), Envanter (Ahır Deposu | Takılı | Eşyalarım),
  Yükseltmeler (Yapılar | Geliştirmeler). Uzun açıklamalı ya da çok düğmeli kartlar (Pazar, Üretim) liste kalır.
- **Pencere davranışı tek kaynak** (`Ui/Kit/Windows`): fareli geniş ekranda birden çok pencere açık kalır; yalnız başlıktan sürüklenir ve güvenli ekran sınırına sıkıştırılır. `UiKit.toggleWindow` menü/kısayolda açık pencereyi kapatır, kapalı pencereyi varsayılan konumunda açar. Dar veya fare olmayan ekranda tek pencere korunur. `showWindow` dünya etkileşiminde açık pencerenin konumunu koruyarak öne getirir. X yalnız kendi penceresini; ESC/gamepad B yalnız en öndeki açık pencereyi kapatır. Kamera yakınlaştırma çalışır (`Interaction/MenuZoom.client`).
- Pencereler ortak Windows ScreenGui katmanındadır (DisplayOrder 10), bildirimlerin (20) altında kalır. ZIndex kayıt sırasıyla sınırlı tutulur; ayrı ekranlardaki pencereler de doğru sıralanır. Orijinal host `window.ownerParent` ile izlenir; host yok edilince pencere ve bağlantıları temizlenir. Kendi toggle/tek pencere listesi yazma. Konum oturum içidir; kayıt şeması eklenmez.
- Renk/yazı/boyut `UiKit.Color / UiKit.Font / UiKit.TextSize / UiKit.Radius`. Renk ve yazı tipinin kaynağı `UiTheme`; **ekran arayüzünün yazı boyutları** `Kit/Tokens.luau`'da (`UiTheme.TextSize`'dan Body/Caption +2, diğerleri +1 px büyük, `Button` = Body-1; dünyadaki tabelalar `UiTheme.TextSize`'ı olduğu gibi kullanır).
  Elle sayı yazma (`TextSize = 13` yok): `UiKit.TextSize.Button/Caption/Body` kullan; sekme başlıkları `UiKit.TextSize.Tab` (içerik yazısından büyük; `UiKit.tabs` ve ada sekmeleri kullanır). Yazı büyüyünce düğme/karo yüksekliği ve satır kırpması gözle denenir.
  Elle `Color3.fromRGB` veya font yazma.
- Emoji yalnızca `iconChip` (ve WorldUi `icon` alanı) içinde. Buton ve metinde emoji yok.
- Buton varyantı: primary=alınabilir, warning=para yetmiyor, disabled=kilitli/dolu, owned=alındı.
- Dünyadaki tabela: `WorldUi.tag` / `WorldUi.sign`, güncelleme `setTag` / `setSignText`.

## Mobil, güvenli alan ve gamepad
- Tam ekran her `ScreenGui` `UiKit.screenRoot(gui)` ile kurulur (`ScreenInsets = DeviceSafeInsets` + ekran boyutuna bağlı kök `UIScale`; kademeler `shared/Modules/UiScale`); pencere/paneller dönen kökün altına konur, doğrudan ScreenGui'ye değil. Ekrana sığdırma için `camera.ViewportSize` değil `UiKit.viewport()` (ölçek uygulanmış) kullan.
- Dokunma hedefi >= `UiKit.TouchTarget` (görünen şekil küçük olsa da tıklama alanı büyük olur), yazı alt sınırı `UiKit.MinTextSize` (değerler `Kit/Tokens.luau`).
- Gamepad: DPad menü kısayolları `FarmHud.client` içinde (`HudGamepadMenu`; tuş eşlemesi o dosyada) ve yalnızca arayüz seçimi boşken çalışır; menü karolarında `NextSelection*` zinciri `MenuBar` içindeki `linkSelection` ile görünür karolara göre kurulur — yeni karo eklersen `topOrder`/`sideOrder` listesine koy.
