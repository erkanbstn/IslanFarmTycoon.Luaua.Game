---
name: roblox-add-content
description: Adds or rebalances game content through Config.luau in this Roblox farm tycoon (animals, zones, roadmap upgrades, specialist islands, extensions, production recipes, seasons, weather) and wires the matching visuals, translations and tests. Use when the user asks for a new animal, building, upgrade, island, recipe, price/income change or balance tweak.
---

# İçerik ekleme / denge

Tek kaynak `src/shared/Config.luau`. Önce benzer mevcut kaydı bul ve aynı alanları doldur
(tipler dosyanın başındaki `export type ...Config`).

## Nereye ne eklenir
| İçerik | Config | Ek dokunuş |
|---|---|---|
| Hayvan | `ANIMALS` + `ANIMAL_ORDER` | model `assets/Animals`, `AnimalVisualService`; bir `ZONES[x].allowedAnimals` (ana ada hayvanıysa `THEMES[n].homeAnimal`) |
| Bölge | `ZONES` (`island` alanı zorunlu) + açan `UPGRADES` (kind zone) | `MapBuilder` bölge yerleşimi → `MAP_VERSION` +1 |
| Yükseltme | `UPGRADES` (`stage`, `requires`, `cost`) | görseli `UpgradeVisualService`; yapı noktası gerekiyorsa MapBuilder `BuildSpots` |
| Uzman ada | `FARM_ISLANDS` + `FARM_ISLAND_ORDER` + island upgrade + `THEMES[n].satellites` + `ROADMAP_STAGES` (**sona ekle**: `upgrade.stage` indeksidir) | MapBuilder `SATELLITE_TYPES`, `IslandSpecialization.SITES`; ana hayvanın kendi adası temada olmaz, inek yoksa `dairy` bulunur |
| Eklenti | `EXTENSIONS` + kind extension upgrade | `ExtensionVisualService` |
| Üretim | `PRODUCTION_RECIPES` | `ProductionRules`, `IslandSpecialization` |
| Mevsim/hava | `SEASONS`, `WEATHER` (incomeModifiers) | `WeatherEffects` WEATHER_LOOK, `SEASON_TINT` |

## Adımlar
```
- [ ] 1. Config kaydı (id küçük harf_alt_çizgi, displayName Türkçe)
- [ ] 2. FarmMath gerekiyorsa (yeni kural türü) — saf fonksiyon, sunucu+client ortak
- [ ] 3. Görsel servis / harita (harita değiştiyse MAP_VERSION +1, "Haritayı Kur" hatırlat)
- [ ] 4. displayName, description, trait, product metinlerinin çevirisi (en/de/ru)
- [ ] 5. Kayıt etkisi: yeni kalıcı alan varsa roblox-save-schema skill'i
- [ ] 6. Test: tests/economy.spec.luau (fiyat/gelir), orders/production gerekiyorsa
- [ ] 7. roblox-verify
```

## Denge ipuçları
- Gelir = `baseIncomePerSecond` × ahır çarpanı × (1 + güçlendirmeler) × mevsim/hava × evre çarpanı.
- Ana ada hayvanı temaya göre değişir: bölge iznini `Config.zoneAllows`, `incomeBoost.home` ile ana hayvan güçlendirmesi.
- Yol haritası sırası `ROADMAP_STAGES` ve `requires` ile; kilitli kart "Önce: ..." gösterir.
- Sayısal değişikliği README'deki tablolarla (mevsim, fiyat) tutarlı tut.
