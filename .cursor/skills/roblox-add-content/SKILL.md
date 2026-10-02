---
name: roblox-add-content
description: Adds or rebalances game content through the Config/ folder in this Roblox farm tycoon (animals, zones, roadmap upgrades, specialist islands, extensions, production recipes, seasons, weather) and wires the matching visuals, translations and tests. Use when the user asks for a new animal, building, upgrade, island, recipe, price/income change or balance tweak.
---

# İçerik ekleme / denge

Tek kaynak `src/shared/Config/` (`init.luau` birleştirir; veri: `Upgrades`, `Animals` = hayvan/bölge, `Islands` = ada/tema/yol haritası/ahır, `Production`, `Goods`, `Shop`, `Items`, `Weather`, `Economy`, `Core`).
Önce benzer mevcut kaydı bul ve aynı alanları doldur (tipler `Config/Types.luau`; `Config.ZoneConfig` gibi yeniden dışa aktarılır).

## Nereye ne eklenir
| İçerik | Config | Ek dokunuş |
|---|---|---|
| Hayvan (yeni tür) | **`Config/Species.luau` satırı** (hayvan, ürün, ada, bölge, fabrika, ürün merkezi, tarif, mevsim/hava türer) + `THEMES[n]` (ana hayvan / `satellites`) | görsel satırları: `Presentation/AnimalModelsSpecies`, `UpgradeBuildersSpecies`, `ZoneBuildersSpecies`, `World/IslandLooks`; çeviri; `MAP_VERSION` +1; `check-config-locales.py` |
| Hayvan (elle) | `ANIMALS` + `ANIMAL_ORDER` | model `assets/Animals` (`Presentation/AnimalModels`), `Presentation/AnimalVisualService`; bir `ZONES[x].allowedAnimals` (ana ada hayvanıysa `THEMES[n].homeAnimal`) |
| Bölge | `ZONES` (`island` alanı zorunlu) + açan `UPGRADES` (kind zone) | `World/MapLayout` bölge yerleşimi (+ görsel `Presentation/ZoneBuilders*`) → `MAP_VERSION` +1; geliştirme profili: `ZONES[x].upgradeProfile` |
| Yükseltme | `UPGRADES` (`stage`, `requires`, `cost`) | görseli `server/Presentation/UpgradeBuilders*` (bina id → kurucu; ortak parçalar `UpgradeParts`, birleştirme `UpgradeVisualService`); yapı noktası gerekiyorsa `World/MapLayout` (`HOME_BUILD_SPOTS`, uydu adalarda `SATELLITE_TYPES`) |
| Uzman ada | `FARM_ISLANDS` + `FARM_ISLAND_ORDER` + island upgrade + `THEMES[n].satellites` + `ROADMAP_STAGES` (**sona ekle**: `upgrade.stage` indeksidir) | `MapLayout.SATELLITE_TYPES` `FARM_ISLANDS` + `World/IslandLooks`'tan türer, `IslandSpecialization.SITES`; her adada tek hayvan, hayvan iki çiftlikte olmaz |
| Üretim | `PRODUCTION_RECIPES` (+ `upgradeProfile`; para tesisi: `cost = 0` + `options` partileri, çok hayvan = hayvan başına daha çok ödül; kimlik bölge kimliğiyle çakışmamalı) | `ProductionRules`, `World/IslandSpecialization`; tesis geliştirmesi `BUILD_UPGRADES.profiles` |
| Ürün / ürün merkezi | `GOODS` + `GOODS_ORDER` + `PRODUCTION_RECIPES` (`output = "goods"`) + açan `UPGRADES` | bina `Presentation/UpgradeBuildersGoods` + yapı noktası; ayrıntı `economy-data.mdc` "Ahır deposu"; `tests/goods.spec.luau` |
| Yapı geliştirme | `BUILD_UPGRADES` (`profiles`, `costMultiplier/costGrowth`) | etki `FarmMath`'te; `tests/economy.spec.luau`; `simulate-economy.py` kalibrasyonu |
| Mevsim/hava | `SEASONS`, `WEATHER` (incomeModifiers) | `Lighting.Presets/Weather/<id>` ve `Presets/Season/<id>` değerleri (`src/lighting/Presets.rbxmx`; `client/Effects/WeatherEffects` okur) |
| Eklenti (süreli kalış) | `Config.EXTENSIONS` (`stayDuration`, `incomeBonus`) + `UPGRADES` kind "extension" (kapasite yükseltmeleri `EXTENSION_CAPACITY_UPGRADES` ile otomatik üretilir) | `IslandLayout.EXTENSIONS` (yer) + `IslandSiteBuilders` (görsel) + `IslandSpecialization.buildExtensionVisual` (+ `Presentation/ExtensionVisualService`); `MAP_VERSION` +1; çeviri; `tests/tasks.spec.luau` |
| Eşya (çekiç, asa, muska, kozmetik) | `Config.ITEMS` (+ `ITEM_SLOTS`) — `effects`/`power`/`look` | etki `FarmMath`'te okunur; çeviri (ad + şablon); `tests/inventory.spec.luau` |

## Adımlar
```
- [ ] 1. Config kaydı (id küçük harf_alt_çizgi, displayName Türkçe)
- [ ] 2. FarmMath gerekiyorsa (yeni kural türü) — saf fonksiyon, sunucu+client ortak
- [ ] 3. Görsel servis / harita (harita değiştiyse MAP_VERSION +1, "Haritayı Kur" hatırlat)
- [ ] 4. displayName, description, trait, product metinlerinin çevirisi (en/de/ru/es/pt)
- [ ] 5. Kayıt etkisi: yeni kalıcı alan varsa roblox-save-schema skill'i
- [ ] 6. Test: tests/economy.spec.luau (fiyat/gelir), goods/production/contracts gerekiyorsa
- [ ] 7. Fiyat/gelir değiştiyse `python scripts/simulate-economy.py` (çıktıdaki ada süreleri ve `TÜM YÜKSELTMELER` hedefleri korunmalı; ölçüm kuralları `economy-data.mdc` "Ölçüm")
- [ ] 8. roblox-verify
```

## Denge ipuçları
- Gelir (`FarmMath/Income.luau`) = `baseIncomePerSecond` × ahır çarpanı × (1 + güçlendirmeler) × (1 + ırk) × (1 + eşya) × mevsim/hava × oyun geçidi × evre çarpanı (`STAGE_INCOME_MULTIPLIER`); ırk ve eşya ayrı çarpandır, toplanmaz.
- Ana ada hayvanı temaya göre değişir: bölge iznini `Config.zoneAllows`, `incomeBoost.home` ile ana hayvan güçlendirmesi.
- Yol haritası sırası `ROADMAP_STAGES` ve `requires` ile; kilitli kart "Önce: ..." gösterir.
- Tema ve mevsim değiştiyse README'deki tema/mevsim tablolarını da güncelle.
