---
description: Oyun dengesi (Config), paylaşılan hesaplar (FarmMath) ve kayıt şeması
paths:
  - "src/shared/Config/**"
  - "src/shared/GameTypes.luau"
  - "src/shared/Modules/FarmMath/**"
  - "src/server/Services/AnimalService.luau"
  - "src/server/Services/UpgradeService.luau"
  - "src/server/Modules/SaveCodec/**"
  - "src/server/Modules/SessionLock.luau"
  - "src/server/Modules/FarmProfiles.luau"
  - "src/server/Services/PlayerDataService.luau"
  - "src/server/Services/SaveStore.luau"
  - "src/server/Services/EconomyService.luau"
---

# Ekonomi ve veri

Rakamlar (süre, fiyat, oran, sayı) bu dosyaya kopyalanmaz: ilgili `Config` anahtarına ve ölçüm komutuna işaret edilir. Ayrıntı konu dosyalarına bölündü (her biri kendi dar `paths` eşleşmesiyle yüklenir); ilgili konuyu aşağıdan seç, hepsini okuma.

| Konu dosyası | Ne zaman |
|---|---|
| `.claude/rules/economy-data-denge.md` | Denge değerleri, FarmMath hesapları ve ekonomi ölçümü (simülasyon) |
| `.claude/rules/economy-data-kayit.md` | Kayıt şeması, SaveCodec, oturum kilidi, DataStore ve makbuz/aktarım |
| `.claude/rules/economy-data-ada-yapi.md` | Ada temaları, ana hayvan, seviyeli/ırk/yapı geliştirme |
| `.claude/rules/economy-data-fiyat-gorev.md` | Hayvan satışı, fiyat ve zorluk, referans gelir, ürünle açılış, hayvan görevleri, üretim tesisleri |
| `.claude/rules/economy-data-urun-siparis.md` | Ahır deposu, ürün merkezleri ve ahır siparişleri |
| `.claude/rules/economy-data-olaylar-hedef.md` | Ürün silme, mevsim hedefi, rastgele olaylar, altın hayvan, çevrimdışı/park gelir, başarımlar |
| `.claude/rules/economy-data-envanter-yardimci.md` | Envanter, eşyalar, asa yetenekleri ve yardımcılar (pet) |
| `.claude/rules/economy-data-rebirth.md` | Rebirth, kalıcı haklar ve ücretli yollar |

Eşleşen dosyaya dokununca ilgili konu dosyası otomatik yüklenir; yüklenmediyse tablodan elle oku. Yeni kural eklerken en uygun konu dosyasına yaz, yeni parça gerekirse bu tabloyu güncelle.
