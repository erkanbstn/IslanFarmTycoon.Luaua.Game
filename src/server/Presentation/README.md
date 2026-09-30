# Server/Presentation

Oyuncu durumunu (kayıt nesnesi) okuyup dünyayı günceller; para/kayıt yazmaz. Bina görselleri `UpgradeBuilders*` dosyalarındadır (id → kurucu), `UpgradeVisualService` bunları birleştirir; bölge görselleri `ZoneBuilders*` (+ `ZoneParts`), birleştirme `ZoneVisualService`. Kurallar: docs/MIMARI.md.
