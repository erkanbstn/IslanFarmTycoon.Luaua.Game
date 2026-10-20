---
description: Ürün silme, mevsim hedefi, rastgele olaylar, altın hayvan, çevrimdışı/park gelir, başarımlar
paths:
  - "src/shared/Config/**"
  - "src/shared/Modules/FarmMath/**"
  - "src/server/Services/EconomyService.luau"
---

# Ekonomi ve veri: Olaylar Hedef

Giriş dosyası: `.claude/rules/economy-data.md` (konu haritası).

- **Ürün silme**: `RequestDiscardGoods` (`Services/GoodsDiscardService`, kurallar `Modules/GoodsDiscard`) depodaki ürün adedini KALICI siler, para vermez; yalnız ürün adedi, ekipman/kalıcı hak silinemez. Arayüz `Hud/GoodsDiscardPrompt` (onaylı); testler `tests/goods-discard*.spec.luau`.
- **Mevsim hedefi**: `Config.SEASONAL_GOALS`, `SEASONAL_REWARD_SECONDS/SEASONAL_MIN_REWARD`; hesap alanı `seasonal {key, progress, target, base, claimed}` (bozuk kayıt atılır). Saf `Rewards.seasonal*`
  (kazanç `lifetimeEarned - base`; yatırım sayacı `Rewards.recordInvest`). Ödül `RequestClaimSeasonal` (işaret önce yazılır), hazırlık `EngagementService`. Yeni yatırım türü `Rewards.recordInvest`
  çağırır; yeni metrik `Rewards.seasonalProgress` + istemci metnini günceller.
- **Rastgele olaylar (kalıp)**: saf zaman/teklif mantığı oyuncu kimliği + döngü numarasından türer (kayıt gerekmez); yalnızca alınan olayın işareti kaydedilir ve sunucu olayı yeniden
  hesaplar (fiyat/ödül client'tan gelmez; işaret önce yazılır). **Gezgin tüccar**: `Config.MERCHANT`, `Merchant.status`, `InventoryService.tryBuyMerchantItem`; indirimli nakit/tur ekipmanı kataloğu, ziyaret başına bir alım, meydanda sunucu mesafe kontrolü; hesap alanı `merchant`.
  **Altın hayvan**: `Config.GOLDEN`, `Golden.window/current`, `EngagementService.tryClaimGolden` (`PlotService.isNearPlot` + `GOLDEN.claimRadius`), alan `golden`; ödül çiftliğin TOPLAM gelirinin
  `rewardSeconds` karşılığıdır; görsel client'ta `Interaction/GoldenAnimal.client`. Teklif durumu tek kaynaktan: `Merchant.status(save, userId, now)` (ziyaret, alındı mı, teklif); `Merchant.offer` ve rozet/bildirim ondan okur, istemci geçişi `Merchant.newTracker/advance` ("arrived"/"missed"). Ziyaret sıklığı `Config.MERCHANT` (`cycleSeconds`, `visitSeconds`, `chance`); katalog yalnız sahip olunmayan, ödüle özel olmayan nakit eşyaları sunar. Rozet `MerchantWindow` açar; runtime NPC `MerchantVisualService` ile sunucuda aktif ziyaretlerde kurulur, son ziyaret bitince kaldırılır; mevcut model varsa mesafe referansı olarak sahiplenilir. Satın alma mesafesi NPC pivotundan değil `VendorPromptAnchor` noktasından ölçülür ve canlı karakter gerekir. `Merchant.currentVisit` katalog üretmeden aynı ziyaret sınırını verir; yerel `MerchantVisitActive` her oyuncunun kişisel görünürlüğünü korur. Yeni olay aynı kalıbı ve bir yönetici test aracını (`forceMerchant/forceGolden/completeSeason/resetEvents`:
  `AdminPolicy` + `AdminService` + AdminPanel; zorlama yalnızca çalışma anı `save.adminForce` ile) ekler. Testler: `tests/merchant.spec.luau`, `tests/golden.spec.luau`, `tests/engagement-service.spec.luau`.

- **Çevrimdışı kazanç**: kazanç doğrudan kasaya yatar (`SaveCodec/Farm.decode` → `FarmMath.computeOfflineEarnings`); depo çevrimdışıyken dolmaz. Oran/süre `Config.OFFLINE_EARNING_RATE/OFFLINE_MAX_HOURS`;
  Pasif Gelir (`offline_income_lv1`, `FarmMath.hasOfflineIncome`) `Config.OFFLINE_UPGRADED_*`'a geçirir (`FarmMath.getOfflineTerms`; toplam oran `Config.OFFLINE_MAX_TOTAL_RATE` ile sınırlı, eşya/yükseltme
  `offlineBonus` dahil). `decode` beşinci dönüş değeri sen yokken yetişkin olan hayvan sayısıdır.
- **Park edilmiş çiftlik geliri**: `FarmMath.settleFarmIncome(farm, kazanç, parked)` (sunucu `EconomyService.settlePlayer` ve sim ortak): Otomatik Toplayıcılı çiftlik her şeyi kasaya yatırır; toplayıcısız
  park edilmiş çiftlik `Config.PARKED_FARM_PAY_RATE` kadarını kasaya yatırır (kalanı yok olur, telemetri `parkedPay`); etkin çiftlik depoyu doldurur.
- **Başarımlar**: metrikler `Rewards.progress` içindedir; her başarım her temada ulaşılabilir olmalı (`tests/rewards.spec.luau` tema sınırlarını denetler; yeni metrik oraya sınır ekler).
