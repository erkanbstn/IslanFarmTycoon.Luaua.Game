---
description: Denge değerleri, FarmMath hesapları ve ekonomi ölçümü (simülasyon)
paths:
  - "src/shared/Config/**"
  - "src/shared/GameTypes.luau"
  - "src/shared/Modules/FarmMath/**"
---

# Ekonomi ve veri: Denge

Giriş dosyası: `.claude/rules/economy-data.md` (konu haritası).

Rakamlar (süre, fiyat, oran, sayı) bu dosyaya kopyalanmaz: ilgili `Config` anahtarına ve ölçüm komutuna işaret edilir.

## Denge ve hesap
- Denge değerleri (fiyat, gelir, kapasite, süre, yol haritası) **yalnızca** `src/shared/Config/` altındadır (`init.luau` birleştirir; veri dosyaları:
  `Upgrades`, `Animals` = hayvan/bölge, `Islands` = ada/tema/ahır/büyüme, `Production`, `Goods`, `Shop` = ürün/ırk/olaylar/mevsim hedefi, `Items`, `Weather`, `Economy`, `Core`).
- `FarmMath` (`src/shared/Modules/FarmMath/`, cephe `init.luau`) saf ve paylaşılan: sunucu da client da aynı sonucu hesaplar, Roblox örneğine dokunmaz
  (`Environment` dışında). Her zaman `FarmMath.<ad>` ile çağır. Açık ada/bölge `FarmMath.applyDerived` ile `purchased`'dan türer; türetilmiş alanı kayda yazma.
- Para/süre/kapasite/ödül gösteren her ekran `FarmMath` yardımcısını kullanır (`getUpgradeCost`, `getExpansionCost`, `getFacilityCost/Duration`,
  `getZoneCapacity`, `getSellPrice`); elle çarpma yazma.
- Döngüde tür başına sabitleri önbelleğe al (`computeIncomePerSecond` kalıbı). Gelir değişmeden önce `EconomyService.settlePlayer` ile geçen süre eski çarpanla kapatılır.
- Test: `tests/economy.spec.luau`, `tests/config.spec.luau`.

## Ölçüm
- `python scripts/simulate-economy.py` (ideal oyuncu, gerçek Config/FarmMath; `--farm 1..6` her temayı dene; `--days/--persona` ile gündelik oyuncu; `--farms` çoklu çiftlik;
  `--collect` platforma uğrama sıklığı; `--cost-exp/--cost-base/--price-growth/--cap-mult` deneme). Tempo hedefleri çıktının "ADIM ZAMANLARI" satırlarında (`goals` tablosu
  scriptte) ve `TÜM YÜKSELTMELER` kilometre taşındadır; tempoyu etkileyen her değişiklikten sonra çalıştır, hedefler sapmasın.
- `python scripts/simulate-tiers.py [--personas ideal,casual,idle]`: çok çiftlikli oyuncu her çiftliği bitirip sıradakini alır (`simulate-economy.py --finish-first`); çiftlik başına ada açılışları, tamamlama süresi ve
  süre oranını yazar, çiftlik bitmezse (deadlock) ya da süre kademe arttıkça artmazsa hata verir. Çarpan ayarı: `--mults 1,6.6,...` (Config'e dokunmadan). Önce/sonra karşılaştırmasını aynı persona, saat sınırı, çiftlik, toplama aralığı ve rebirth/perk koşullarıyla yap; komut `roblox-verify` skill'indeki ölçüm akışında tanımlıdır. Tarihsel rapordaki süreyi güncel hedef sayma.
- `UPGRADES[].cost` taban fiyattır: `UPGRADE_COST_BASE/EXPONENT` eğrisi Config yüklenirken uygulanır (`MAIN_FARM_PRICES` da aynı eğriden geçer).
- Depo (`BARN_LEVELS[].storageCap`) platformdan uzak duran oyuncunun gelirini silmeyecek büyüklükte olmalı: değişince `--collect 120` ve `--collect 300` ile geç oyun gelirinin
  `--collect 0`a yakın kaldığını doğrula.
- Irk geri dönüşü: sim "Irk geri dönüş" satırı en kötü seviyede bile ~2 saati geçmemeli (her `--farm`'da); `LINEAGE.costGrowth/maxLevel` değişince yeniden ölç.
  Tesis geri ödemesi: "Tesis geri ödeme" satırı; `PRODUCTION_MAX_RETURN` parti çarpanını sınırlar.
- Başlangıç: yeni çiftlik hayvansız başlar (`STARTING_COW_COUNT`); `Config.getStartingCash(farmId)` ana hayvanı tam bir tane almaya yeter (`STARTING_CASH` yedek). Çiftliğin
  ilk `STARTER_ADULT_ANIMALS` hayvanı yetişkin doğar (`FarmMath.getNewAnimalBornAt`; şema değişmez). Hayvansız profil geçerlidir.
- Büyüme süresi `Config.GROWTH_SECONDS`'tan okunur (testler de); rakamı elle yazma. Değişince simülasyonla kilit zamanlarını kontrol et.
- Büyüme hızı (`FarmMath.getGrowthSpeed`): kaynakların artısı (çarpan - 1) TOPLANIR; toplam artı `Config.GROWTH_SPEED_KNEE`'ye kadar aynen geçer, üstü azalan getiriyle sıkışır ve hız
  `Config.GROWTH_SPEED_CAP`'e yaklaşır ama ulaşmaz. Çarpanları elle çarpma; yeni hız kaynağı `getGrowthSpeed` toplamına girer. Bir hayvanın toplam büyüme süresi
  `FarmMath.getGrowthSeconds(save, animalId, zoneId)` (arayüzde henüz gösterilmiyor); taban süre uzayınca eski kayıtta yakın alınmış hayvan gençleşebilir.
