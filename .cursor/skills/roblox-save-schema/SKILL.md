---
name: roblox-save-schema
description: Changes persisted player save data safely in this Roblox project (GameTypes, SaveCodec decode/encode normalization, schema version migration, PlayerDataService session lock) with regression tests. Use when adding a saved field, renaming or removing save data, changing DataStore behaviour, or debugging lost/corrupted progress.
---

# Kayıt verisi değişikliği

Kayıt kaybı geri alınamaz; her adımı test et.

```
- [ ] 1. GameTypes: PlayerSave / farm tipine alan ekle
- [ ] 2. SaveCodec.decode: eksik/bozuk değere varsayılan, sayılarda sonlu + clamp, id doğrulama
- [ ] 3. SaveCodec.encode: alanı yaz
- [ ] 4. Yeni hesap için varsayılan: SaveCodec.newFarm(config, farmMath, now, newUid, farmId) / FarmProfiles
      (decodeFarm çiftlik numarasını `farmId` ile alır: başlangıç hayvanı temaya göre)
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
- Para/sayı sınırı: `SaveCodec` MAX_MONEY ve `SessionLock.isFinite`.
