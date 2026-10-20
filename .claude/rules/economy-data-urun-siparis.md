---
description: Ahır deposu, ürün merkezleri ve ahır siparişleri
paths:
  - "src/shared/Config/**"
  - "src/shared/Modules/FarmMath/**"
  - "src/server/Services/EconomyService.luau"
---

# Ekonomi ve veri: Urun Siparis

Giriş dosyası: `.claude/rules/economy-data.md` (konu haritası).

- **Ahır deposu ve ürün merkezleri**: `Config.GOODS/GOODS_ORDER`; ürün miktarı **hesap** alanıdır (`save.goods`, kökte). Limit türe göre, sahip olunan bütün çiftliklerin ahır
  `BARN_LEVELS[].goodsCap` toplamıdır (`FarmMath.getGoodsCap(kökKayıt)`); depo/sipariş işlemleri park edilmiş görünümle değil KÖK kayıtla yapılır. Depo işlemleri **yalnızca**
  `FarmMath.getGoodsAmount/getGoodsSpace/addGoods/removeGoods/getGoodsWorth/getGoodsCap` ile (`removeGoods` yetmiyorsa hiçbir şey değiştirmez). Ürün merkezi `PRODUCTION_RECIPES` içinde
  `output = "goods"`, `goodsId`, `goodsAmount` taşır, seçeneksizdir ve başlatma ücreti alır; depoda yer yoksa başlamaz (`ProductionRules.canStart`, `FarmMath.previewGoodsYield`). Teslim:
  `FarmMath.getGoodsYield` ürün miktarını verir; depoya sığmayan ürün satış karşılığına çevrilir, asgari getiri farkı `getGoodsFloorCash` ile nakit tamamlanır (`ProductionLogic.claim`). Parti miktarı küçük kalır: `getGoodsYield` yetişkin bonusu + tesis verimi + muskayı TOPLAR, toplam `PRODUCTION_YIELD_MAX_MULT`i ve miktar `PRODUCTION_MAX_BATCH_UNITS`i aşmaz;
  asgari getiri (`PRODUCTION_MIN_RETURN`) miktarı şişirerek değil ürünün birim DEĞERİYLE sağlanır (`Config/Goods.luau` "DEĞER KURALI": değer = tam yükseltilmiş merkezin asgari parti getirisi x `ECONOMY_LIMITS.valueToFloor*` bandı). Yeni ürün/hayvan ya da gelir dengesi değişince
  `python scripts/audit-economy.py` bölüm D'den değeri yeniden hesapla; ürün merkezi tarifinin `reward` alanı tesis ölçeğidir (geliştirme fiyatı tabanı), değerden bağımsız. Değişmezler: `tests/goods.spec.luau` "ekonomi değişmezleri". Yeni ürün/merkez: `Config/Goods` + tarif + yükseltme + bina görseli (`Presentation/UpgradeBuildersGoods`) + yapı noktası (`MapLayout`
  `HOME_BUILD_SPOTS` / `SATELLITE_TYPES[...].itemSpot`) + `UpgradeParts.PRODUCTION_RECIPES` + çeviri. Arayüz: Envanter penceresinde "Ahır Deposu"; ahırdaki sandık (`BarnChestPrompt`) aynı pencereyi açar.
- **Ahır siparişleri**: `Config.GOODS_CONTRACTS` (`seconds`, `slots`, `tiers`, `unitRefValue`, `maxLineUnits`); saf mantık `FarmMath/Contracts.luau`. Teklifler kayıttan ve sunucu saatinden (pencere = `now / seconds`,
  anahtar `"<pencere>:<sıra>"`) türer; yalnızca ürün merkezi kurulu ürünler istenir. Satır birimi kademe değeridir (`units`, ± `variation`), pahalı üründe `unitRefValue / değer` ile küçülür (en az 1, `maxLineUnits` tavan); depo büyüklüğüne ya da gelire bağlı değildir. 8 kademe, `slots` slot.
  Pano boyutu üretilebilir ürün sayısına bağlıdır (`Contracts.slotCount`, `slots` yalnız üst sınır) ve penceredeki ödül toplamı evreye bağlı bütçeyi (`windowBudget`, referans gelirin dakikası) aşamaz. Toplam sipariş bonusu `GOODS_CONTRACTS.maxBonus` (0,6) ile sınırlıdır (en yüksek kademe 2 x 1,6 = `maxRewardRatio` 3,2): yeni bonus kaynağı eklerken tavanı ve `contracts.spec` en kötü yığın testini koru. Günlük ödül `Config.DAILY_MINUTES` x seri çarpanı x referans gelir (`Rewards.dailyAmount`; hafta toplamı bir günün gelirinin %3'ünü geçmez, `rewards.spec`). Brüt ödül `ürün değerleri x rewardFactor x (1 + sipariş bonusu)` (`Contracts.reward`); teklif oluşturulurken referans gelire bağlı ödül tavanı uygulanır. `offer.reward` gerçek ödemedir, `uncappedReward` yalnız brüt değer; ikisini UI/tahsilatta karıştırma. Teslim `fulfillContract`
  ile tek adımda; anahtar `save.contracts` (hesap alanı) içine yazılır. Para ekleme `Services/ContractService` (`RequestFulfillContract`). Yol haritasından bağımsız açılır (ilk ürün merkezi yeter).
  Hızlı boşaltma: `Config.GOODS_SELL.rate` (ürün değerinin payı; bir partiyi satmak `PRODUCTION_MAX_RETURN`ı aşmaz, testte denetlenir; "Hepsini/Yarısını sat", `FarmMath/Goods`); üretimin depoya sığmayan taşan kısmı da aynı oranla paraya çevrilir. Takas ("Ürünle satın al", hayvan alımı):
  `Config.GOODS_BARTER.rate`, satış oranını AŞAMAZ (`config.spec` denetler). Doluluk uyarısı `Config.GOODS_FULL_WARNING` (Envanter rozeti, hedef kartı). Sim ürün üretimini/tüketimini/doluluğu ölçer.
  Test: `tests/contracts.spec.luau`, `tests/contract-service.spec.luau`. Uçuk sayı denetimi: `python scripts/audit-economy.py [--check]` (parti miktarı, ürün değeri/taban, ödül/değer ve gelir dakikası, kademe fiyat tavanı
  `DIFFICULTY.tiers[n].maxPrice`; sınırlar `Config.ECONOMY_LIMITS`; `verify.ps1` çalıştırır).
