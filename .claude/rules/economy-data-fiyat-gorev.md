---
description: Hayvan satışı, fiyat ve zorluk, referans gelir, ürünle açılış, hayvan görevleri, üretim tesisleri
paths:
  - "src/shared/Config/**"
  - "src/shared/Modules/FarmMath/**"
  - "src/server/Services/AnimalService.luau"
  - "src/server/Services/UpgradeService.luau"
  - "src/server/Services/EconomyService.luau"
---

# Ekonomi ve veri: Fiyat Gorev

Giriş dosyası: `.claude/rules/economy-data.md` (konu haritası).

- **Hayvan satışı**: `Config.ANIMAL_SELL_FRACTION`, `FarmMath.getSellPrice/findSellableAnimal` (görevdekiler sona, çiftlikte son hayvan satılmaz), `AnimalService.trySell`.
- **Fiyat ve zorluk (tek hesap)**: yükseltme, hayvan, yapı geliştirme ve ana çiftlik fiyatı **yalnızca** `FarmMath.getPrice(save, kind, id, level)` ile (`FarmMath/Pricing.luau`; `getUpgradeCost/getAnimalPrice/getBulkPrice/getExpansionCost`
  ince sarmalayıcıdır); gösterim (arayüz, tabela) ve tahsilat aynı işlevi çağırır, elle çarpan yazma. Fiyat = yazılı taban (Çiftlik 1) x `Config.DIFFICULTY.tiers[tier].costMultiplier` x ada sırası çarpanı
  (`slotSpread`) x n. alım eğrisi. Kademe çiftliğin TEMA numarasıdır (`Pricing.getTier`, eksik/bozuk = 1; kayıtta tier yoktur); ada açılışı ayrıca `DIFFICULTY.islandPremium` ile çarpılır; ırk geliştirme çarpılmaz.
  Yeni çiftlik/kademe: `Config/Difficulty.luau` + `docs/ZORLUK_VE_FIYAT.md`; `scripts/simulate-tiers.py --personas ideal,casual,idle --assert-monotonic` ile ayarla (`--mults/--premium/--order` dener); çiftlik süresi tema 1 -> 6 her personada artmalı.
- **Kayıt sürümü**: mevcut `SaveCodec.decode` farklı geçmiş sürümü temiz hesaba çevirebilir. Bu davranış göç değildir; kalıcı veri korumasını test etmeden sürüm artırma. Dönüşüm/sıfırlama iş akışı `roblox-save-schema` içindedir.
- **Referans gelir** (`FarmMath.getReferenceIncome`): hesabın ödül/tavan ölçüsü; etkin çiftliğin canlı geliri ile park edilmiş çiftliklerin en yükseğinin büyüğü (sunucu tam kayıttan hesaplar, istemciye `parkedIncomeBest` gider). Günlük ödül, mevsim hedefi/ödülü ve sipariş ödül tavanı bunu kullanır; Altın Hayvan olayı etkin çiftlikte kalır. Gelir hesabı eklerken "etkin çiftlik mi hesap mı" sor. Çevrimdışı kazanç her çiftliği ayrı hesaplayıp toplar (`SaveCodec/Farm`). Test: `tests/rewards.spec.luau`.
- **Ürünle açılış**: `UpgradeConfig.goodsCost = { step, shares }` (`Config/Upgrades.luau`, seviye zincirinde yalnızca `_lv1`); miktar `FarmMath.getGoodsCost` (kademe, adım ve kapasite `Config.DIFFICULTY.goods`), kaynak ürün
  `Config.resolveGoodsSource` (home/previous/slotN/sea). Para + ürün tahsilatı yalnızca `PlayerDataService.trySpend(player, price, reason, sku, goodsCost)` ile tek adımda; arayüz fiyatı
  `FarmMath.formatUpgradePrice`, yetmeyen kalem `getGoodsShortfall`. Ürün merkezine `goodsCost` verme; değişmezler `tests/config.spec.luau` (çözülürlük, deadlock, kapasite, arbitraj). Yeni açılış eklerken `docs/ZORLUK_VE_FIYAT.md`.
- **Hayvan görevleri**: `AnimalRecord.task { kind = "production"|"extension", id, startedAt, endsAt }` (`SaveCodec/Tasks.decodeTask`: bozuk görev atılır, hayvan korunur; çevrimdışıyken
  biten görev yüklemede temizlenir). Üretimde hayvan gelirsiz, görünmez, satılamaz; eklentide `EXTENSIONS[id].incomeBonus` bonusu `stayDuration` boyunca sürer (toplam bonus = incomeBonus x
  stayDuration sabit kalsın). Gelir `FarmMath.computeIncomeOverInterval` içinde yalnızca görev penceresiyle kesişen kısma uygulanır (`taskMultiplier`); anlık gelir `computeIncomePerSecond(save, now)`.
  Ana bölgedeki yer ayrılı kalır (`countInZone`). **Görev başlatmadan/bitirmeden önce `EconomyService.settlePlayer`** çağır. Süre dolumunu `AnimalTaskService` yapar (önce gelir kesilir, sonra
  görev temizlenir). Eklenti: `ExtensionService`, kapasite `FarmMath.getExtensionCapacity` (`Config.EXTENSION_CAPACITY_UPGRADES`). Bina üstü ilerleme: `Presentation/JobMarks` +
  `Interaction/JobProgress.client`. Yeni görev türü: `taskMultiplier`, `SaveCodec/Tasks`, `AnimalTaskService`, `tests/tasks.spec.luau`.
- **Üretim tesisleri**: para tesisi (`output = "cash"`) ücretsiz başlar (`getFacilityCost` 0) ve `options` (parti) taşır; çok hayvan isteyen seçenek hayvan başına daha çok öder
  (`tests/config.spec.luau` denetler). Seçim `FarmMath.resolveRecipe(recipe, optionId)` ile (önbellekli, tarifi değiştirmez); `RequestProductionAction` dördüncü alanı (`detail`) parti kimliğidir
  (`ProductionRules.validOption`), iş kaydına `job.optionId` yazılır. Teslim ödülü `max(seçenek ödülü x tesis verimi, ceil(forgone x returnMultiplier))`; `PRODUCTION_MIN_RETURN` / `PRODUCTION_MAX_RETURN` tabanı
  ve tavanı belirler (tesis hayvanları yerinde bırakmaktan her zaman kârlı olmalı). `ProductionService` boşta yetişkinleri `FarmMath.pickProductionAnimals` ile verir, `job.forgone` kaçırılan gelirdir
  (`estimateForgoneIncome`). Çekirdek `Modules/ProductionLogic` (`start`, `claim`, `runPets`).
