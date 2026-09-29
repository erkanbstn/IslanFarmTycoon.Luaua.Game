---
name: roblox-add-ui
description: Builds or changes screen UI in this Roblox project with UiKit (HUD stats panel, menu tiles, windows, cards, badges, toasts) while respecting HUD layout zones, compact mode, emoji and localization rules. Use when adding a window, panel, HUD element, menu button, or fixing overlapping/cluttered UI.
---

# Arayüz ekleme / düzenleme

Önce `.cursor/rules/client-ui.mdc` içindeki yerleşim bölgelerini oku. Ana HUD dosyası
`src/client/FarmHud.client.luau` yalnızca orkestrasyondur; pencere ve bölümler `src/client/Hud/` altındaki modüllerdedir
(`create(...)` + `update(state)` kalıbı, ortak `HudCommon.setPurchaseButton`). Ayrı büyük paneller kendi modülünde (`ProductionPanel`,
`IslandManager`, `SettingsMenu`, `AdminPanel`) ve `open(screenGui)` fonksiyonu verir.

## Karar
- Sık bakılan tek değer mi? → `Stats` paneline satır (`statRow(stats, order, icon, tint)`).
- Ayrıntı / nadiren bakılan? → "Çiftliğim" penceresi (`goalsWindow.list`); sipariş ve dükkân kendi pencerelerinde (`boardWindow`, `storeWindow`).
- Yeni ekran/akış? → `src/client/Hud/<Ad>.luau` modülü (`create` + `update`) + `UiKit.window` + menü karosu; ana betiğe yığma.

## Menü karosu
```luau
local questsButton = UiKit.menuButton(dock, "📜", "Görevler", Color.Blue, if hasKeyboard then "G" else nil)
questsButton.Activated:Connect(QuestsPanel.open)
-- menuEntries listesine sırayla ekle; compactDock=true yalnızca en sık kullanılanlar (≤ 3-4)
{ button = questsButton, compactDock = false },
```
Kısayol tuşu verdiysen `InputBegan` işleyicisine ekle ve mevcut tuşlarla (P, Y, U, R, I, F7, F8)
çakıştırma. Rozet: `local setBadge = UiKit.badge(button)`; `setBadge(n)`.

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
- Dar ekranda UiKit pencereyi otomatik ortalar ve boyutlar.

## Kontrol listesi
```
- [ ] Renk/yazı/boyut UiKit tablolarından; elle Color3/font yok
- [ ] Emoji yalnızca iconChip/ikon parametresinde
- [ ] Buton varyantları: primary / warning / disabled / owned
- [ ] Kompakt (<900 genişlik veya <560 yükseklik) ve geniş yerleşimde çakışma yok;
      sağ üst (oyuncu listesi) ve sol üst (sohbet) boş
- [ ] Yeni metinler en/de/ru sözlüklerinde; etiketler kısa (karo 76 px)
- [ ] `python scripts/check-locales.py --strict-literals` temiz
- [ ] Studio'da 1920x1080, 1366x768 ve telefon emülatöründe görsel kontrol (kullanıcıya hatırlat)
```
