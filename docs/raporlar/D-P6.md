# D-P6 raporu: `feat/mobil-ses` düzeltmeleri (worktree `roblox-oyun-mobil`)

- P6 raporundaki orta önemli bulgu (StatsPanel sekmesi) ve iki düşük bulgu düzeltildi; üç ayrı commit.
- Stylua, selene (0 uyarı) ve pure Luau testleri geçti.
- verify.ps1 tek yerde kırmızı: tip tabanı (`AnimalAnimator.client.luau:79`, bu dalın dokunmadığı dosya; aşağıda).

## Bulgular

| # | Durum | Commit | Not |
|---|---|---|---|
| 1 StatsPanel sekme konumu + 44 px | Düzeltildi | `fix: StatsPanel açma sekmesi ölçekli kökte doğru konumlanır, 44 px genişlik` | `followTab` kök konumunu çıkarıp `UiKit.screenScale()`'e bölüyor; sekme genişliği `UiKit.TouchTarget` (44), ok/kasa yerleşimi buna bağlı |
| 2 Kayıt gelmeden yapılan sürgü değişikliği | Atlandı | | Canlı özniteliği `Sfx` varsayılan değerle başlangıçta kendisi yazıyor; "oyuncu değiştirdi" ile "varsayılan yazıldı" ayırt edilemiyor, denersem kayıtlı değer hiç uygulanmaz. Kayıt gelmeden Ayarlar zaten açılmıyor. Davranış `Preferences.client` yorumunda belgelendi |
| 3 Kayıtlı değerin sunucuya geri yollanması | Düzeltildi | `fix: Preferences kayıtlı değeri geri göndermez (synced karşılaştırması)` | Sunucunun bildiği son değer (`synced`) tutuluyor; aynı değer gönderilmiyor. `applying` bayrağı kalktı (Deferred sinyalde işe yaramıyordu) |
| 5 Gamepad HUD kapalıyken | Düzeltildi | `fix: gamepad DPad kısayolları HUD kapalıyken pencere açmaz` | `screenGui.Enabled` kapısı eklendi. Roadmap'in DPad'e atanması istenmediği için dokunulmadı |
| 4 Slider / çentik sapması, 6 koşu düğmesi konumu | Atlandı | | Yalnızca emülatörde doğrulanabilir; kodda neden görmedim |

## verify.ps1
Son satır: `Verification failed: Type analysis (baseline...)`. `check-types.py`: 1 yeni bulgu, `src/client/Effects/AnimalAnimator.client.luau:79`. Bu dal o dosyayı değiştirmiyor (`git diff 54331d2..HEAD` boş); `main` o dosyayı sonradan değiştirmiş, yani dalın tip tabanı eski. Tabanı güncellemedim (başkasının bulgusunu gizlemek olur). Entegrasyonda `main` ile birleşince bu bulgu kendiliğinden kapanmalı; kapanmazsa E ajanı bakmalı.

## Studio'da denenecekler
- Stats panelini her ölçekte aç/kapat: telefon (0,85), 1080p, 1440p/4K; sekme panele yapışık, sekmeyi parmakla kolay basabiliyor musun (44 px).
- Kasa metni kapalı sekmede taşmıyor mu (sekme 114 px genişliğinde).
- Ayarlar: sürgüyü oynat, çık-gir, kayıtlı değer geri geliyor; Output'ta gereksiz tekrar remote görünmüyor.
- Gamepad: veri yüklenmeden DPad bir şey açmıyor, yüklenince açıyor.

## Karar
**Birleştirilebilir** (verify'daki tek kırmızı dalın dışındaki tip tabanı kaymasıdır; E aşamasında yeniden doğrulanacak).

`git log --oneline cd17bbb..HEAD`: üç commit (yukarıdaki tablo).
