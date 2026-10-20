---
description: Gece ışıkları ve Lighting özellik sahipliği
paths:
  - "src/client/Effects/**"
  - "src/server/World/**"
  - "src/server/Presentation/**"
---

# Harita ve dünya: Isik

Giriş dosyası: `.claude/rules/world-map.md` (konu haritası).

## Gece ışıkları
- Işık kaynağı parçası `NightLight` (fener, Neon) veya `NightWindow` (pencere, SmoothPlastic)
  etiketi + `NightColor` özniteliği + `Enabled = false` bir `PointLight` alır.
  Hazır yardımcılar: `WorldDecor.lamp`, `WorldDecor.smallLamp`, `WorldDecor.markNightWindow`.
- `DayNight.client` bu parçaları yakar/söndürür; parlaklık = taban × rampa × yönetici çarpanı,
  menzil de çarpanla ölçeklenir (≤ 60). Etiketsiz ışık gece/gündüz ve yönetici ayarından etkilenmez.
- Taban değer ışığın yerel `BaseBrightness`/`BaseRange` özniteliğinde tutulur. Instance anahtarlı
  zayıf (`__mode = "k"`) tabloya koyma: sarmalayıcı toplanır, gündüz 0'a çekilmiş değer taban sanılır.
- Genel yoğunluk ince ayarı `DayNight` içindeki `LIGHT_BRIGHTNESS_SCALE` / `LIGHT_RANGE_SCALE`
  (harita yeniden kurulmaz). Yanma zamanı `Environment.getLightFactor` = gecenin karanlığından
  türetilir; ayrı saat aralığı yazma (gündüz ışık yanar).
- Gece payı eğrisi tek kaynaktan `Environment.NIGHT_CURVE` (saat/pay anahtarları, smoothstep; saatler artan, 0 ve 24 uçları aynı). Işık rampası takvim saatine değil gökyüzünün kararmasına bağlıdır:
  yeni gece davranışı eğriden türer, ayrı saat yazma. Orta kalitede ışık bütçesi histerezislidir (seçili parça sıralamada düşse de hemen bırakılmaz, titreme yok); düşükte gerçek ışık yok, fenerde
  ucuz `NightHalo` parıltısı görünür (`DayNight` `HALO_*`).
- Teşhis: yönetici paneli "Gece ışıkları" satırı bu ekranda izlenen lamba/ışık sayısını gösterir.

## Lighting sahipliği (iki script aynı özelliğe yazmasın)
| Özellik | Sahibi |
|---|---|
| ClockTime, Brightness, Ambient, OutdoorAmbient, ExposureCompensation, Bloom, NightGrade | DayNight |
| Bulutlar, Atmosphere Haze/Density, SunRays (yoğunluk), WeatherGrade | WeatherEffects |
| Bloom/SunRays/Clouds `Enabled`, GlobalShadows, ShadowSoftness, EnvironmentSpecularScale, Terrain su/süs, DepthOfField | Graphics (kalite profili) |
| UnderwaterGrade, UnderwaterBlur, `SoundService.AmbientReverb`, `Submerged` özniteliği | Underwater |
- Değerlerin kaynağı Studio'daki `Lighting.Presets` klasörüdür (`src/lighting/Presets.rbxmx`: Day, Night, Twilight, Lights, Weather/<id>, Season/<id>; `Core/LightingPresets` okur). Rengi/parlaklığı değiştirmek kod değil preset değeri düzenlemektir; yeni hava/mevsim = klasöre ilgili değer klasörü eklemek.
- Hava pozlaması: WeatherEffects `Lighting:SetAttribute("WeatherExposure", n)` yazar, DayNight
  yumuşatıp gece payıyla birlikte uygular. Yeni efekt bu tabloya uymalı.
