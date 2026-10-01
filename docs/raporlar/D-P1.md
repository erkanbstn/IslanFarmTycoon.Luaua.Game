# D-P1 — Telemetri düzeltmeleri (`feat/telemetri`, worktree `..\roblox-oyun-telemetri`)

Rapor P1'in bulgularından 1, 2, 4 ve 5 düzeltildi; her biri ayrı commit. 3, 6, 7, 8 bilinçli atlandı.
Test, selene, mimari denetim ve tip analizi temiz (tip tabanına yeni bulgu yok); push yok.
Not: `.tools/` worktree'ye ana klasörden kopyalandı (izlenmiyor, commit'e girmedi).

| P1 bulgusu | Durum | Commit |
|---|---|---|
| 1 Düşen huni adımı bir daha gönderilmiyor | Düzeltildi: `dispatch` bool döner, işaret yalnızca gittiyse konur. Bütçe doluyken düşüp yenilenince gitmesini sınayan test eklendi | c866d0f |
| 2 `production` toplamasız | Düzeltildi: `batched = true` (60 sn'de bir), test ve `TELEMETRI.md` güncellendi | sonraki commit |
| 4 `reportLoaded` pcall dışı | Düzeltildi: `pcall`, hatada `TelemetryError` sayacı. Birim test yok (player-data spec'te telemetri kuklası var), kod incelemesiyle bırakıldı | |
| 5 Çıkıştan sonra durum yeniden açılıyor | Düzeltildi: zayıf anahtarlı `leaving` tablosu. Test: Parent hâlâ Players iken durum açılmıyor (bir testin eski davranışa dayanan satırı yeni oyuncuyla düzeltildi) | |
| 3 Bütçeyi oyuncu sayısına göre ölçekle | Atlandı: canlı `TelemetryDropped` verisi olmadan tahmin. Üretim toplu olunca yük zaten azaldı | — |
| 6 Çıkış olaylarını bütçe dışı tut | Atlandı: bütçe mimarisini değiştirir, ayrı karar ister | — |
| 7 Robux IAP ölçümü | Atlandı: paket dışı (K kararı) | — |
| 8 Çağrı sitelerinde reason/sku testi | Atlandı: servis testleri kukla telemetriyle çalışıyor, ayrı iş | — |

## Commit listesi
```
179f104 fix: telemetri çıkışı başlayan oyuncu için durumu yeniden açmaz
df10954 fix: telemetri onLoaded hatası kayıt yüklemeyi bozmaz (pcall)
a5d38e4 perf: telemetri üretim geliri toplu gönderilir (bütçeyi tüketmesin)
c866d0f fix: telemetri huni adımı bütçe yüzünden düşerse işaretlenmez, sonra yeniden denenir
e9daf91 docs: TELEMETRI.md (olay listesi, Creator Hub'da nerede görülür) ve mimari notları
cebc649 feat: TelemetryService ile canlı ölçüm (huni, ekonomi, ilerleme, özel olaylar)
```

## verify.ps1 son satırı
`All automated checks passed. Studio multiplayer, DataStore fault and device tests remain separate.`
(`-LuauDirectory` ana klasörün `.tools/luau`'suna verildi; `check-types.py` ayrıca çalıştırıldı.)

## Entegrasyon notu
`refactor/kalite` ile en çok çakışan dal (`PlayerDataService`, `UpgradeService`, `AnimalService`...). `reportLoaded` çevresi `PlayerDataService.load` sonunda değişti. RequestGuard'a geçen handler'larda `addCash/trySpend` çağrılarına `reason`/`sku` taşınmalı.

**Karar: Birleştirilebilir** (3 ve 6 canlı `TelemetryDropped` verisine göre sonra ele alınabilir).
