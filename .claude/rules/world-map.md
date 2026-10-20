---
description: Harita üretimi, dünya görselleri, gece ışıkları ve Lighting sahipliği
paths:
  - "src/server/World/**"
  - "src/server/Presentation/**"
  - "plugin/**"
  - "src/client/Effects/**"
---

# Harita ve dünya

Harita sözleşmesi, model tabanlı görseller, ana ada, gece ışıkları ve Lighting sahipliği. Ayrıntı konu dosyalarına bölündü (her biri kendi dar `paths` eşleşmesiyle yüklenir); ilgili konuyu aşağıdan seç, hepsini okuma.

| Konu dosyası | Ne zaman |
|---|---|
| `.claude/rules/world-map-harita.md` | Harita üretimi/sözleşmesi, çalışma anı çiftlik geçişi, taş yollar ve zemin modelleri |
| `.claude/rules/world-map-model-gorseller.md` | Model tabanlı görseller: geometri assets modellerinden gelir, kod çizmez |
| `.claude/rules/world-map-ana-ada.md` | Ana ada yapıları, meydan, tabelalar, yapım alanları, sandık ve küçük ada yerleşimi |
| `.claude/rules/world-map-ana-ada-duzen.md` | Ana ada düzeni/temaları, geliştirmeyle beliren yapılar, streaming, harita çevresi |
| `.claude/rules/world-map-isik.md` | Gece ışıkları ve Lighting özellik sahipliği |

Eşleşen dosyaya dokununca ilgili konu dosyası otomatik yüklenir; yüklenmediyse tablodan elle oku. Yeni kural eklerken en uygun konu dosyasına yaz, yeni parça gerekirse bu tabloyu güncelle.
