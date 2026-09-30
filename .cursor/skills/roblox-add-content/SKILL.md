---
name: roblox-add-content
description: Adds or rebalances game content through the Config/ folder in this Roblox farm tycoon (animals, zones, roadmap upgrades, specialist islands, extensions, production recipes, seasons, weather) and wires the matching visuals, translations and tests. Use when the user asks for a new animal, building, upgrade, island, recipe, price/income change or balance tweak.
---

# İçerik ekleme / denge

Tek kaynak `src/shared/Config/` (`Upgrades`, `Animals` = bölge/hayvan, `Islands` = ada/tema/yol haritası, `Production`, `Shop`/`Items`, `Weather`, `Core`). Önce benzer mevcut kaydı bul ve aynı alanları doldur
(tipler `Config/Types.luau`; `Config.ZoneConfig` gibi yeniden dışa aktarılır).

## Nereye ne eklenir
| İçerik | Config | Ek dokunuş |
|---|---|---|
| Hayvan | `ANIMALS` + `ANIMAL_ORDER` | model `assets/Animals`, `server/Presentation/AnimalVisualService`; bir `ZONES[x].allowedAnimals` (ana ada hayvanıysa `THEMES[n].homeAnimal`) |
| Bölge | `ZONES` (`island` alanı zorunlu) + açan `UPGRADES` (kind zone) | `server/World/MapBuilder` bölge yerleşimi → `MAP_VERSION` +1; geliştirme profili: `ZONES[x].upgradeProfile` |
| Yükseltme | `UPGRADES` (`stage`, `requires`, `cost`) | görseli `server/Presentation/UpgradeBuilders*` (bina id → kurucu; ortak parçalar `UpgradeParts`, birleştirme `UpgradeVisualService`); yapı noktası gerekiyorsa `World/MapBuilder` `BuildSpots` |
| Uzman ada | `FARM_ISLANDS` + `FARM_ISLAND_ORDER` + island upgrade + `THEMES[n].satellites` + `ROADMAP_STAGES` (**sona ekle**: `upgrade.stage` indeksidir) | MapBuilder `SATELLITE_TYPES`, `IslandSpecialization.SITES`; ana hayvanın kendi adası temada olmaz, inek yoksa `dairy` bulunur |
| Eklenti | `EXTENSIONS` + kind extension upgrade | `Presentation/ExtensionVisualService` |
| Üretim | `PRODUCTION_RECIPES` (+ `upgradeProfile`) | `ProductionRules`, `World/IslandSpecialization`; tesis geliştirmesi `BUILD_UPGRADES.profiles` |
| Yapı geliştirme | `BUILD_UPGRADES` (`profiles`, `costMultiplier/costGrowth`) | etki `FarmMath`'te; `tests/economy.spec.luau`; `simulate-economy.py` kalibrasyonu |
| Mevsim/hava | `SEASONS`, `WEATHER` (incomeModifiers) | `client/Effects/WeatherEffects` WEATHER_LOOK, `SEASON_TINT` |
| Eşya (çekiç, asa, muska, kozmetik) | `Config.ITEMS` (+ `ITEM_SLOTS`) — `effects`/`power`/`look` | etki `FarmMath`'te okunur; çeviri (ad + şablon); `tests/inventory.spec.luau` |

## Adımlar
```
- [ ] 1. Config kaydı (id küçük harf_alt_çizgi, displayName Türkçe)
- [ ] 2. FarmMath gerekiyorsa (yeni kural türü) — saf fonksiyon, sunucu+client ortak
- [ ] 3. Görsel servis / harita (harita değiştiyse MAP_VERSION +1, "Haritayı Kur" hatırlat)
- [ ] 4. displayName, description, trait, product metinlerinin çevirisi (en/de/ru)
- [ ] 5. Kayıt etkisi: yeni kalıcı alan varsa roblox-save-schema skill'i
- [ ] 6. Test: tests/economy.spec.luau (fiyat/gelir), orders/production gerekiyorsa
- [ ] 7. Fiyat/gelir değiştiyse `python scripts/simulate-economy.py` (ada süreleri ve TÜM YÜKSELTMELER hedefi, `economy-data.mdc` tempo satırı)
- [ ] 8. roblox-verify
```

## Denge ipuçları
- Gelir = `baseIncomePerSecond` × ahır çarpanı × (1 + güçlendirmeler) × mevsim/hava × evre çarpanı.
- Ana ada hayvanı temaya göre değişir: bölge iznini `Config.zoneAllows`, `incomeBoost.home` ile ana hayvan güçlendirmesi.
- Yol haritası sırası `ROADMAP_STAGES` ve `requires` ile; kilitli kart "Önce: ..." gösterir.
- Sayısal değişikliği README'deki tablolarla (mevsim, fiyat) tutarlı tut.
