---
description: Ekran arayüzü (UiKit), HUD yerleşimi ve dünya tabelaları (WorldUi)
paths:
  - "src/client/**/*.luau"
  - "src/shared/UiTheme.luau"
  - "src/shared/WorldUi.luau"
  - "src/first/**/*.luau"
---

# Arayüz standardı

UiKit bileşenleri, bilgiyi gerektiğinde gösterme, HUD bölgeleri, mobil/gamepad, ses/para biçimi. Ayrıntı konu dosyalarına bölündü (her biri kendi dar `paths` eşleşmesiyle yüklenir); ilgili konuyu aşağıdan seç, hepsini okuma.

| Konu dosyası | Ne zaman |
|---|---|
| `.claude/rules/client-ui-kit.md` | UiKit bileşenleri, tema, pencere davranışı, mobil, güvenli alan ve gamepad |
| `.claude/rules/client-ui-bilgi.md` | Bilgiyi gerektiğinde göster: ayrıntı aç/kapa, kart düzeni, sekme ve işlem rozetleri |
| `.claude/rules/client-ui-hud.md` | HUD yerleşim bölgeleri, menü kademeleri, Hud modülleri, ada bağlamı, mevsim/hava |
| `.claude/rules/client-ui-ses-para.md` | Ses (Sfx), para biçimi, bildirimler ve UI performansı |

Eşleşen dosyaya dokununca ilgili konu dosyası otomatik yüklenir; yüklenmediyse tablodan elle oku. Yeni kural eklerken en uygun konu dosyasına yaz, yeni parça gerekirse bu tabloyu güncelle.
