---
name: roblox-add-ui
description: Builds or changes screen UI in this Roblox project with UiKit (HUD stats panel, menu tiles, windows, cards, badges, toasts) while respecting HUD layout zones, compact mode, emoji and localization rules. Use when adding a window, panel, HUD element, menu button, or fixing overlapping/cluttered UI.
---

# Arayüz ekleme / düzenleme

Önce `.cursor/rules/client-ui.mdc` içindeki yerleşim bölgelerini ve mobil/güvenli alan kurallarını oku. Ana HUD dosyası
`src/client/Ui/FarmHud.client.luau` yalnızca orkestrasyondur; pencere ve bölümler `src/client/Ui/Hud/` altındaki modüllerdedir
(`create(...)` + `update(state)` kalıbı, ortak `HudCommon.setPurchaseButton`). Ayrı büyük paneller `src/client/Ui/` içinde kendi modülünde (`ProductionPanel`,
`IslandManager`, `SettingsMenu`, `AdminPanel`) ve `open`/`toggle` fonksiyonu verir. Ui katmanı yalnızca `Core/` ve `Effects/`'e bağlanır (`docs/MIMARI.md`).

## Karar
- Sık bakılan tek değer mi? → `Stats` paneline satır (`statRow(stats, order, icon, tint)`).
- Ayrıntı / nadiren bakılan? → ilgili pencere (ödül/başarım: `rewardsWindow.list`); sipariş ve dükkân kendi pencerelerinde (`boardWindow`, `storeWindow`).
- Yeni ekran/akış? → `src/client/Ui/Hud/<Ad>.luau` modülü (`create` + `update`) + `UiKit.window` + menü karosu; ana betiğe yığma.
- Tam ekran yeni `ScreenGui` mu? → `UiKit.screenRoot(gui)` ile kur (güvenli alan + ölçek); pencereleri bu kökün altına koy.

## Menü karosu
```luau
-- Hud/MenuBar içinde: karoyu kur, topOrder (üst çubuk) ya da sideOrder (sağ sütun) listesine ekle
local questsButton = UiKit.menuButton(topBar, "📜", "Görevler", Color.Blue, if hasKeyboard then "G" else nil)
questsButton.Activated:Connect(QuestsPanel.open)
```
Menü kademeli açılır: yeni karonun ne zaman görüneceğini `updateVisibility` içinde (`setMenuTile`) yaz; yeni oyuncuya hepsini gösterme.
`topOrder`/`sideOrder` aynı zamanda gamepad gezinti zincirini kurar (`linkSelection`); karoyu oraya koymayı unutma.
Kısayol tuşu verdiysen `InputBegan` işleyicisine ekle ve mevcut tuşlarla çakıştırma (kullanılanlar `FarmHud.client` ve `Hud/MenuBar` içindeki `InputBegan` işleyicilerinde; F7 `WeatherEffects`'te).
Gamepad DPad kısayolları `FarmHud.client`'taki `HudGamepadMenu`'dedir. Rozet: `local setBadge = UiKit.badge(button)`; `setBadge(n)`.

## Pencere
```luau
local window = UiKit.window(screenGui, {
	title = "Görevler", icon = "📜", tint = Color.Blue,
	width = 330, maxHeight = 430,
	anchor = Vector2.new(1, 0.5), position = WINDOW_POSITION, -- ya da ortada (0.5, 0.5)
})
local card = UiKit.card(window.list, order, "🐄")
card.title.Text = "..."; card.detail.Text = "..."
setPurchaseButton(card.action, FarmMath.formatMoney(price), if canAfford then "primary" else "warning")
```
- Pencere kapalıyken içerik güncelleme; `frame:GetPropertyChangedSignal("Visible")` ile açılınca çiz.
- Dar ekranda UiKit pencereyi otomatik ortalar ve boyutlar. Sık güncellenen metni `UiKit.setText` ile yaz (Localizer çift yazımı olmaz).
- İlk görünüm kısa sonuç/fiyat/aksiyon; uzun yardım ve formül `UiKit.disclosure` içinde kapalı başlar. Kartta `UiKit.cardDetails` kullan; tutar, gerçek eksi ve geri alınamaz uyarı işlemden önce görünür kalır. Uzun çeviri ve fiyat doğal yüksekliğe sarılır; sabit yükseklik/boş düğme ile hizalama yapma.
- Bildirim: `toastHost` aynı metni ×N rozetiyle birleştirir; tekrar süzme kodu yazma.

## Kontrol listesi
```
- [ ] Renk/yazı/boyut UiKit tablolarından; elle Color3/font yok
- [ ] Emoji yalnızca iconChip/ikon parametresinde
- [ ] Buton varyantları: primary / warning / disabled / owned
- [ ] Tekrarlayan ipucu ekleme: aynı şeyi söyleyen satır/kart varsa birini kaldır (HUD kalabalık olmasın)
- [ ] Para/süre/kapasite gösteriyorsan `FarmMath` yardımcısı (elle hesap yok)
- [ ] Kompakt (dar/kısa ekran: `FarmHud` `compact`, `UiKit.window` ortalama) ve geniş yerleşimde çakışma yok;
      sağ üst (oyuncu listesi) ve sol üst (sohbet) boş
- [ ] Yeni metinler tüm `Locales/` sözlüklerinde; etiketler kısa (menü karosu `UiKit.MenuTileSize`)
- [ ] Dokunma hedefi >= `UiKit.TouchTarget`, yazı >= `UiKit.MinTextSize`; sığdırmada `UiKit.viewport()` (ham `camera.ViewportSize` değil)
- [ ] `python scripts/check-locales.py --strict-literals` ve `python scripts/check-config-locales.py` temiz; interpolasyon atomları kaynakta ayrıca incelendi
- [ ] Studio'da 1920x1080, 1366x768 ve telefon emülatöründe görsel kontrol (çalıştırılmadıysa raporda açıkça belirt)
```
