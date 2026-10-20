---
description: Rebirth, kalıcı haklar ve ücretli yollar
paths:
  - "src/shared/Config/**"
  - "src/shared/GameTypes.luau"
  - "src/server/Modules/SaveCodec/**"
  - "src/server/Services/PlayerDataService.luau"
  - "src/server/Services/SaveStore.luau"
  - "src/server/Services/EconomyService.luau"
---

# Ekonomi ve veri: Rebirth

Giriş dosyası: `.claude/rules/economy-data.md` (konu haritası).

## Rebirth ve ücretli yollar
- **Gezgin tüccar kişisel stoku**: `Merchant.status` sahip olunmayan, nakitle satılabilir eşyaları kullanıcı/ziyaret sırasıyla seçip `Config.MERCHANT.stock` kadar doldurur. Başka oyuncunun alımı stoku tüketmez; ziyaret başına tek alım işareti oyuncuya aittir. Fiyat, ziyaret süresi, sahiplik ve NPC mesafesi sunucuda tekrar doğrulanır. Bütün uygun katalog sahiplenilmişse boş durum açıklanır; Robux/altın/reward-only ürünleri nakit teklifine çevirme.
- **Üretim iptali**: `ProductionLogic.cancel` / `RequestProductionAction("cancel")` yalnız bitmemiş, aynı UID'li partiyi iptal eder. İade kayıtlı `startCost` kadardır; güncel tarife fiyatı, kaçırılan gelir veya çıktı ödülü değildir. Eski kayıtta ücret yoksa iade sıfırdır. `addRefund` kazanç sayacını artırmaz; görevli hayvanlar serbest bırakılır, o tarifin otomatik tekrarı kapanır. Aynı UID/istek tekrar iade edemez.
- **Hava asası sırası**: `SeasonService` aktif asa etkisini kesmez; `WeatherQueueOffer` oyuncuya bağlı, 30 saniyelik onay sunar. FIFO kuyruğu en fazla `MAP_PLOT_COUNT`, oyuncu başına bir seçimdir. Hak onayda değil başlangıçta harcanır; sahiplik, takılı eşya, hak ve rebirth turu yeniden doğrulanır. İptal, uygunluk kaybı, ayrılma ve yönetici hava sabitlemesi bekleyen hakkı tüketmez. Sıra çalışma anındadır, kayda yazılmaz; süreler normal hava aralığıdır. İstemci `Hud/WeatherQueuePrompt` üzerinden sıra/iptal gösterir.
- Tek kaynak `Config/Progression`, hesap `Modules/Progression`, sunucu `ProgressionService`: 30 seviyelik terminal ilerleme, tamamlanma hedefi mevcut ve sıradaki seviyeye göre türetilir. Testler `tests/rebirth-journey.spec.luau` ve `tests/progression-service.spec.luau`.
- Kalıcı altın/ekipman hakları ile tur nakit/eşyaları farklıdır; sıfırlama `Progression` sözleşmesiyle yapılır, finansal günlükler korunur. Altın dönüşümü `goldCashQuote` ve günlük/tur kotasını kullanır; satın alınan altın kotayı artırmaz.
- Üretim partisi altın veya Robux ile bitirilemez. `finishTargets` yalnız büyüme/eklenti; bekleme önizlemesi tur, kimlik, görev başlangıç/bitiş zamanı ve maliyetle doğrulanır.
- Makbuz/gold/rebirth işlemi kalıcı snapshot ve hesap finansal kilidiyle uygulanır (`PlayerDataService.transactAccount`). Kimlik 0 ödeme açmaz; Creator Hub kimliği eklemek canlı makbuz testinin yerine geçmez.
