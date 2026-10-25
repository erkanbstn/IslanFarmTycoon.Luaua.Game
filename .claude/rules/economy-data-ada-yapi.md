---
description: Ada temaları, ana hayvan, seviyeli/ırk/yapı geliştirme
paths:
  - "src/shared/Config/**"
  - "src/shared/Modules/FarmMath/**"
  - "src/server/Services/AnimalService.luau"
  - "src/server/Services/UpgradeService.luau"
---

# Ekonomi ve veri: Ada Yapi

Giriş dosyası: `.claude/rules/economy-data.md` (konu haritası).

## Sistemler (kural, dosya, test)
- **Ada temaları**: `Config.THEMES[n]` ana çiftlik n'nin küçük adalarını tanımlar; ada türleri `FARM_ISLANDS` + `ZONES` + `ANIMALS` + `UPGRADES` (island + boost) içindedir; ada
  yükseltmesi yalnızca `barn_N`'e bağlanır; temalar birbirinin kopyası olmaz (`tests/config.spec.luau` doğrular). Mantık `Config.getTheme/themeHasIsland`, `FarmMath.themeIslands`;
  `UpgradeService.tryBuy` tema dışı adayı reddeder. Harita yuvaları `MapLayout.SATELLITE_TYPES`/`SATELLITE_SLOTS`; etkin çiftlik kendi adasına `MapBuilder.applyTheme` ile giydirilir
  (`PlotService.bindFarm`). `ROADMAP_STAGES` sırası `upgrade.stage` indeksidir: yeni aşamayı **sona** ekle.
- **Tema tutarlılığı**: çiftlik yalnızca kendi temasındaki adaların yükseltmesini alır (`FarmMath.isUpgradeInTheme`, `getUpgradeStatus` temada olmayanı `"locked"` döner);
  "tüm yol haritası" sayan her kural, başarım ve hedef temaya göre süzülür. Yeni başarım/hedef her temada ulaşılabilir olmalı (`tests/rewards.spec.luau`, `tests/economy.spec.luau`).
- **Ana ada hayvanı**: `theme.homeAnimal` `themed = true` bölgelerin hayvanını belirler. Bölge izni `Config.zoneAllows` ile sorulur (`allowedAnimals`'a doğrudan bakma). `incomeBoost.home`
  ana hayvana uygulanır. Her adada tek hayvan yaşar ve hiçbir hayvan iki çiftlikte olmaz (`FARM_ISLANDS[ada].animalId` + `THEMES`; `tests/config.spec.luau` doğrular); ana hayvanın kendi küçük adası olmaz.
  Yeni hayvan türü `Config/Species.luau` satırıdır: hayvan, ürün, ada, bölge, fabrika, ürün merkezi, tarif, mevsim/hava etkisi sıra profilinden (`PROFILES`) türer; elle yazma.
- **Seviyeli geliştirme**: `LEVEL_CHAINS` (`Config/init.luau`) her seviyeyi `<id>_lv<N>` yükseltmesi (`kind = "level"`, `leveled = true`) olarak üretir; şema değişmez.
  `kind = "boost"` verme: `MapBuilder.validate` her boost için yapı noktası ister. "Tüm yol haritası" sayımı `leveled` olanları saymaz.
- **Irk geliştirme**: `Config.LINEAGE`; kayıt `lineage { [animalId] = seviye }` (çiftlik alanı; `SaveCodec` tanınmayan türü atar, seviyeyi sıkıştırır). Mantık
  `FarmMath.getLineageLevel/getLineageCost/getLineageStatus`; gelir etkisi `getAnimalMultiplier` içinde **ayrı çarpan** (diğer bonuslar toplamına eklenmez; takılı eşyanın `incomeBonus`'u da
  ayrı çarpandır). Sunucu `UpgradeService.tryUpgradeLineage` (`RequestUpgradeLineage`, en az bir yetişkin şart, `settlePlayer` sonra `trySpend`). Görünürlük:
  `Presentation/AnimalLabels.applyLineage` rozeti yerinde yeniler (hayvan yeniden kurulmaz).
- **Yapı geliştirme** (bölge ve üretim tesisi): `Config.BUILD_UPGRADES` (`profiles` = seviye başına fayda), `BUILD_ORDER/BUILD_TARGETS`. Bölge profili `ZONES[x].upgradeProfile`
  (`capacity`, `growthSpeed`, `incomeBonus`, `seasonAffinity`), tesis profili `PRODUCTION_RECIPES[x].upgradeProfile` (`speed`, `yield`, `thrift`; para tesisi `cashFactory`).
  Yardımcıları kullan: `getZoneCapacity`, `getGrowthSpeed(save, animalId, zoneId)`, `getAnimalMultiplier(.., zoneId)`, `getFacilityDuration/getFacilityCost`, `getProductionReward`;
  büyüme anlık görüntüsü `snapshotGrowthSpeeds` + `preserveGrowthProgress`. Kayıt `expansions { [bölgeVeyaTarifId] = seviye }`; bölge açık, tesis kurulu olmalı; bölgenin dolu olması gerekmez, hayvan sayısı tamamlanmayı etkilemez
  (`getExpansionStatus`). Sunucu `UpgradeService.tryExpandZone` (`RequestExpandZone`); bölge ve tarif kimlikleri aynı tabloyu paylaşır, çakışma Config yüklenirken `assert` ile reddedilir.
  Yeni profil/seviye: `tests/economy.spec.luau` + sim kalibrasyonu ("ALAN toplam Sv.N"). Bölge bayrakları: `ZoneVisualService.applyLevelFlags`.
