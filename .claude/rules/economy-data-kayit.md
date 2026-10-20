---
description: Kayıt şeması, SaveCodec, oturum kilidi, DataStore ve makbuz/aktarım
paths:
  - "src/server/Modules/SaveCodec/**"
  - "src/server/Modules/SessionLock.luau"
  - "src/server/Modules/FarmProfiles.luau"
  - "src/server/Services/PlayerDataService.luau"
  - "src/server/Services/SaveStore.luau"
  - "src/shared/GameTypes.luau"
---

# Ekonomi ve veri: Kayit

Giriş dosyası: `.claude/rules/economy-data.md` (konu haritası).

## Kayıt şeması
- Kalıcı alan: `GameTypes` tipi → `SaveCodec` (`src/server/Modules/SaveCodec/`: `init` giriş, `Farm`, `Animals`, `Production`, `Tasks`, `Goods`, `Inventory`, `Account`, `Common`)
  decode normalleştirme (eksik alana varsayılan, sonlu sayı/üst sınır) → encode → `tests/data.spec.luau`.
- Şema sürümünün tek kaynağı `SessionLock.VERSION`. Biçim değişirse artır ve eski sürümden göç yaz; gelecekteki bilinmeyen sürüm reddedilir, bilinmeyen veri varsayılanla ezilmez.
- DataStore çağrıları yalnızca `Services/SaveStore` (oturum kilidi `SessionLock`, yedek `Modules/SaveBackup`); `PlayerDataService` oturum/facade'dır ve SaveStore'u çağırır.
  Başka servis DataStore kullanmaz (`check-architecture.py` denetler). Ayrıntılı iş akışı: `roblox-save-schema` skill'i.
- Çiftlik düzeyi mi hesap düzeyi mi: çiftlik başına alanlar `FarmProfiles`'taki `FIELDS` listesindedir (`stored`, `purchased`, `lineage`, `expansions`, `animals`,
  `production`, `autoRepeat`, `barnLevel`, `unlockedIslands`, `unlockedZones`). Hesap düzeyi alanlar kökte durur ve `SaveCodec/Account` (+ `Goods`, `Inventory`) normalleştirir:
  `cash`, `lifetimeEarned`, `daily`, `achievements`, `seasonal`, `merchant`, `golden`, `inventory`, `goods`, `contracts`, `receipts`, `transfers`, `language`, `graphics`, `audio`, `reducedMotion` ve finansal ilerleme `gold`, `progression`, `owned`.
  Çalışma anı alanlar (`passes`, `envOverride`, `adminForce`) kaydedilmez; `FarmProfiles.view` gerekenleri etkin olmayan çiftliğe taşır. Eski kayıtta eksik opsiyonel alanlar varsayılanla yüklenir;
  normalleştirilen içerik ile bozuk finansal/kritik verinin reddini ayır. Para, hak ve claim bozulmasını sessizce sıfırlama; gerçek davranış SaveCodec testlerinde doğrulanır.
- `lifetimeEarned` yalnızca `addCash` ve otomatik toplama ile artar. İade (`PlayerDataService.addRefund`) kazanç/başarım sayacına girmez.
- Ürün kimlikleri `Config.PRODUCTS` (`id = 0` satışta değil). `MonetizationService.processReceipt` makbuzu `ReceiptLog` ile bir kez işler; `PurchaseGranted` yalnızca kayıt başarılıysa döner.
- Makbuz geçmişi ve aktarım tekrar kimlikleri silinmez; kapasite dolunca yeni işlem durur. Sınırlar `ReceiptLog` ve `TransferLedger` içindedir. `FarmProfiles.clientState` bu özel günlükleri ağ paketine koymaz.
- Para aktarımı: borç + `transfers.outbox` aynı hesap kaydında kalıcılaştırılır; `SaveStore` alıcı inbox'ına aynı kimlikle idempotent yayımlar. Alıcı nakit + `transfers.received` işaretini kaydetmeden inbox silinmez. Ayrı anahtarlar atomik değildir; yeniden deneme ve işaretler uzlaştırır. Testler `transfer-ledger`, `transfer-service`, `save-store-transfer` spec dosyalarındadır.
- Yedekten kurtarmada `transfers.quarantined` kalıcıdır; aktarım ve makbuz işleme elle mali uzlaştırmaya kadar durur. Yedek, asıl kayıttaki son mali işaretleri içermeyebilir; karantinayı incelemeden kaldırma.
- Eski kayıt biçimini değiştirmeyen opsiyonel hesap alanı eklemede sürüm aynı kalabilir: alan yoksa güvenli varsayılan, bozuksa orijinali koruyan ret ve eski kayıt testi şarttır. Sırf alan eklemek için VERSION artırmak mevcut decoder'da eski ilerlemeyi sıfırlar.

Değişiklikten sonra: `python scripts/run-tests.py`.
