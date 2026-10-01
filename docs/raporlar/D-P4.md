# D-P4 raporu — `perf/sunucu-ag` düzeltmeleri

Çalışma yeri: worktree `C:\Users\erkan\Desktop\roblox-oyun-sunucu-ag` (dal `perf/sunucu-ag`, `.tools` ana klasörden kopyalandı, git'e girmez).
O4'ün iki "Yüksek" bulgusu düzeltildi; isteğe bağlı olanlar atlandı. verify.ps1 temiz.

## Düzeltilen
- **O4-1 / EconomyTick revizyon boşluğu** — `PlayerDataService.pushEconomy`: `statePending` doğruysa ekonomi paketi gönderilmez (bekleyen PlayerState parayı/depoyu zaten taşır), revizyon yalnızca gerçek gönderimde artar. Test: `tests/player-data-service.spec.luau` (bekleyen durumda atlanır, bekleyen yoksa gönderir ve revizyon boşluksuz ilerler; fixture EconomyTick'i de kaydeder).
- **O4-2 = P4-1 / istemcide `mainFarms` yok** — `FarmProfiles.clientState` hafif `mainFarms` ekler: park edilmiş çiftlik `barnLevel`+`purchased`+`unlockedIslands`, etkin çiftlik yalnızca `barnLevel`. `Goods`/`Contracts` değişmedi, istemcide sunucuyla aynı sonucu verir. Testler: `main-farm.spec` (istemci yükü ile sunucu kaydı için `getGoodsCap` ve `getContractGoods` eşit), `player-data-service.spec` (yük hafif, tam kayıt gitmiyor).

## Atlanan / değiştirilen
- **O4-2 `GameTypes.mainFarms` isteğe bağlı (`?`)**: denendi, sunucuda 24 yeni tip bulgusu açtı (`MainFarmService`, `PlotService`); geri alındı, yalnızca yorum eklendi.
- **O4-3 yuva çakışması (satış sonrası)**: isteğe bağlıydı, görsel; atlandı (ayrı iş).
- **O4-4 / P4-2,3 anında gönderim (`flushState`)**: isteğe bağlı sigorta; atlandı, tek tıklamada gecikme zaten oluşmuyor (O4 de Düşük sayıyor).
- P4 Bulgu 4-7 bilgi düzeyi, işlem yok.

## Commit'ler (`git log f33dca4..HEAD`)
- 1471ed0 fix: bekleyen PlayerState varken pushEconomy atlanır
- fix: istemci yüküne hafif mainFarms görünümü
- fix: GameTypes.mainFarms zorunlu kalır (yalnızca yorum)

## verify.ps1 son satırı
`All automated checks passed. Studio multiplayer, DataStore fault and device tests remain separate.`

## Studio'da denenecekler
- 2+ çiftlikli hesapta Envanter/Üretim depo kapasitesi sunucuyla aynı mı; Sipariş Panosu teklifleri; GoalCard önerileri.
- Hızlı satın alma + üretim sırasında istemci ek `RequestPlayerState` atıyor mu (boşluk kalktı mı).
- pushState paket boyutu önce/sonra (P4'te ölçülmemişti).
- Çakışma notu: `refactor/kalite` ile `AnimalService.luau` çakışıyor (P4 raporu); `feat/mobil-ses` ve `feat/onboarding-paketi` `InventoryWindow`/`ProductionPanel`/`GoalCard`'a dokunuyor, bu düzeltme istemci dosyalarına dokunmadığı için ek çakışma yaratmaz.

## Karar
Birleştirilebilir (O4'ün istediği iki düzeltme yapıldı, verify temiz).
