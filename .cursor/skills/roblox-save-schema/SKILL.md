---
name: roblox-save-schema
description: Changes persisted player save data safely in this Roblox project (GameTypes, SaveCodec decode/encode normalization, schema version migration, PlayerDataService session lock) with regression tests. Use when adding a saved field, renaming or removing save data, changing DataStore behaviour, or debugging lost/corrupted progress.
---

# Kayıt verisi değişikliği

Kayıt kaybı geri alınamaz; her adımı test et.

Önce karar: alan **çiftlik başına** mı (`FarmProfiles`'taki `FIELDS` listesine eklenir; her ana çiftlikte ayrı) yoksa **hesap düzeyi** mi (kökte; cüzdan, envanter, ahır deposu, dil, grafik gibi)?
Çalışma anı alan mı (`passes`, `envOverride`, `adminForce`: kaydedilmez, `FarmProfiles.view` gerekiyorsa etkin olmayan çiftliğe taşır)?

```
- [ ] 1. GameTypes: PlayerSave / farm tipine alan ekle
- [ ] 2. SaveCodec parçasında decode: eksik/bozuk değere varsayılan, sayılarda sonlu + clamp, id doğrulama
      (alan başına parça: src/server/Modules/SaveCodec/ içinde Farm, Animals, Production, Tasks, Goods, Inventory, Account, Common)
- [ ] 3. Aynı parçada encode (hesap alanları SaveCodec/init.luau encode'unda kökte listelenir)
- [ ] 4. Yeni hesap için varsayılan: SaveCodec.newFarm(config, farmMath, now, newUid, farmId, tier) / FarmProfiles
      (SaveCodec/Farm.decode çiftlik numarasını `farmId` ile alır: başlangıç hayvanı temaya göre)
- [ ] 5. Şema biçimi değiştiyse SessionLock.VERSION +1 (tek kaynak) ve eski sürümden göç
- [ ] 6. tests/data.spec.luau: eski kayıt → yeni, bozuk değer, gelecekteki sürüm reddi
- [ ] 7. python scripts/run-tests.py (SaveCodec klasörüne dosya eklediysen scripts/run-tests.py SAVE_CODEC_PARTS)
```

## Kurallar
- Bilinmeyen gelecekteki sürüm reddedilir (`SessionLock.validate`); bilinmeyen hayvan/alan varsa orijinal korunur, varsayılanla **ezilmez**.
- Türetilmiş alanlar (açık adalar/bölgeler) kaydedilmez; `FarmMath.applyDerived` üretir.
- DataStore çağrıları yalnızca `Services/SaveStore`'dadır (anahtar kilidi, UpdateAsync + yeniden deneme, yedek); `PlayerDataService` oturum/facade'dır ve SaveStore'u çağırır.
  Oturum sahipliği `SessionLock` (süreli kilit). Başka servis DataStore kullanmaz.
- Studio'da store adı `_Studio` eki alır; canlı veriyle test etme.
- Tercih alanları: dil ve grafik için doğrulama listesi `Config`'tedir (`LANGUAGES`, `GRAPHICS_MODES`); ses ve hareket azaltma için `Modules/Preferences`. Tanınmayan değer atılır.
- Para/sayı sınırı: `SaveCodec/Common` `MAX_MONEY` ve `SessionLock.isFinite`.

## Yedek ve ölçüm (`Modules/SaveBackup`, `Services/SaveStore`, `PlayerDataService`)
- Başarılı kayıtta, `SaveBackup.INTERVAL_SECONDS` aralığıyla asıl anahtarın yanına dönüşümlü `SaveBackup.SLOTS` yedek yazılır (`SaveBackup.slotKey`; oturum kilidi ve revizyon içermez, `_backupAt` taşır).
- Asıl kayıt çözülemezse (bozuk) yükleme en yeni çözülebilir yedekle açılır (`SaveStore.recoverFromBackup`); bozuk kayıt önce `SaveBackup.quarantineKey` anahtarına kopyalanır (yazılamazsa kurtarma yapılmaz).
  Gelecek sürüm kayıt kilit aşamasında reddedilir, yedekle ezilmez.
- Ölçüm: `ServerStorage.Diagnostics` öznitelikleri (`Metrics`; ör. `SaveBytesLast/Max`, `SaveSizeWarning`, `SaveFailed`, `BackupWritten/Failed`, `ProfileRecovered`, `SaveWrite*`); oyuncu öznitelikleri
  `DataBytes`, `DataBackupAt`, `DataRecovered`. Boyut eşikleri `SaveBackup.SIZE_WARN_BYTES/SIZE_CRITICAL_BYTES` (DataStore değer sınırına göre).
- Yeni bir kayıt alanı eklerken boyutu düşün; yedek ham yükü kopyaladığından şema değişikliği ek yedek işi gerektirmez.
