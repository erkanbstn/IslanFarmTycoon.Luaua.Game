---
name: roblox-save-schema
description: Changes persisted player save data safely in this Roblox project (GameTypes, SaveCodec decode/encode normalization, schema version migration, PlayerDataService session lock) with regression tests. Use when adding a saved field, renaming or removing save data, changing DataStore behaviour, or debugging lost/corrupted progress.
---

# Kayıt verisi değişikliği

Kayıt kaybı geri alınamaz; her adımı test et.

Önce karar: alan **çiftlik başına** mı (`FarmProfiles.FIELDS`'e eklenir; her ana çiftlikte ayrı) yoksa **hesap düzeyi** mi (kökte; cüzdan, envanter, dil, grafik gibi)? Çalışma anı alan mı (`passes`, `envOverride`, `adminForce`: kaydedilmez, `FarmProfiles.view` gerekiyorsa taşır)?

```
- [ ] 1. GameTypes: PlayerSave / farm tipine alan ekle
- [ ] 2. SaveCodec.decode: eksik/bozuk değere varsayılan, sayılarda sonlu + clamp, id doğrulama
- [ ] 3. SaveCodec.encode: alanı yaz
- [ ] 4. Yeni hesap için varsayılan: SaveCodec.newFarm(config, farmMath, now, newUid, farmId) / FarmProfiles
      (SaveCodec/Farm.decode çiftlik numarasını `farmId` ile alır: başlangıç hayvanı temaya göre)
- [ ] 5. Şema biçimi değiştiyse version +1 ve eski sürümden göç
- [ ] 6. tests/data.spec.luau: eski kayıt → yeni, bozuk değer, gelecekteki sürüm reddi
- [ ] 7. python scripts/run-tests.py
```

## Kurallar
- Bilinmeyen gelecekteki sürüm reddedilir; bilinmeyen hayvan/alan varsa orijinal korunur,
  varsayılanla **ezilmez**.
- Türetilmiş alanlar (açık adalar/bölgeler) kaydedilmez; `FarmMath.applyDerived` üretir.
- DataStore yalnızca `PlayerDataService`; oturum sahipliği `SessionLock` (UpdateAsync, süreli kilit).
- Studio'da store adı `_Studio` eki alır; canlı veriyle test etme.
- Hesap düzeyi tercih alanlarında (dil, grafik) doğrulama listesi `Config`'tedir; tanınmayan değer yok sayılır, yanlış tür reddedilmez ama atılır.
- Para/sayı sınırı: `SaveCodec` MAX_MONEY ve `SessionLock.isFinite`.

## Yedek ve ölçüm (`Modules/SaveBackup`, `PlayerDataService`)
- Her başarılı kayıtta (en fazla 10 dakikada bir) asıl anahtarın yanına dönüşümlü iki yedek yazılır: `player_<id>_backup1/2` (oturum kilidi ve revizyon içermez, `_backupAt` taşır).
- Asıl kayıt çözülemezse (bozuk) yükleme en yeni çözülebilir yedekle açılır; bozuk kayıt önce `player_<id>_quarantine` anahtarına kopyalanır (yazılamazsa kurtarma yapılmaz). Gelecek sürüm kayıt yedekle ezilmez (kilit kaydı reddeder).
- Ölçüm: `ServerStorage.Diagnostics` özniteliklerinde `SaveBytesLast/Max`, `SaveSizeWarning`, `SaveWriteMaxSeconds`, `SaveFailed`, `BackupWritten/Failed`, `ProfileRecovered`; oyuncu özniteliği `DataBytes`, `DataBackupAt`, `DataRecovered`. Boyut uyarı eşikleri 3,0 MB / 3,8 MB (sınır 4 MB).
- Yeni bir kayıt alanı eklerken boyutu düşün; yedek yalnızca ham yükü kopyaladığından şema değişikliği ek iş gerektirmez.
