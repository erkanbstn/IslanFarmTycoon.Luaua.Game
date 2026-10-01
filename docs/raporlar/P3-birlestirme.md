# P3 birleştirme raporu

- O3 Opus incelemesindeki 3 zorunlu düzeltme (eski kayıtta tier, ürün kapasitesi kilidi, 3. tema hayalet ada) ve önerilen denge değerleri `balance/tur2` üzerinde yapıldı.
- `verify.ps1` hem dalda hem `main`'de geçti; dal `--no-ff` ile `main`'e birleştirildi, worktree ve dal silindi.
- Simülasyon: casual çevrimdışı payı %82,5 (hedef 70-80'in biraz üstünde, bilinçli bırakıldı), 6. çiftlik 8160. dakikada (6,7. gün değil, 5,7. gün).

## Maddeler

| Madde | Durum | Commit | Testler |
|---|---|---|---|
| 1 Eski kayıtta eksik tier = 1; bozuk tier = 1; 1. çiftlik her zaman 1; tier çiftlik sayısını aşamaz; al-sat kâr açığı | Tamam | `287a124` | `data.spec` (eski 3 çiftlik, hepsi tier 1; sınırlama), `economy.spec` (her tier, inek/tavuk, 4 alım: satış < ödenen) |
| 2 Üretim kilidi: `space < min(needed, goodsCap)`; sığmayan kısım teslimde 1,0x değerle paraya | Tamam | `a1752f1` | `goods.spec` (kapasiteyi aşan parti boş depoda başlar, 1 birim doluyken engellenir, fazlası x1,0 nakit) |
| 3 3. tema göçü (`SaveCodec.decodeFarm`) | Tamam | `dca8a79` | `data.spec` (iade tutarı birebir, hayvanlar, tekrar yükleme iade etmez, 2. çiftlik etkilenmez) |
| 4 Denge: `FARM_COST_STEP` 6; çevrimdışı Pasif Gelir 0,3 / 6 sa; toplam oran tavanı 0,5 (`OFFLINE_MAX_TOTAL_RATE`); sipariş `incomeSeconds` 60 | Tamam | `b587974` | `economy.spec` (tavan), mevcut spec'ler |
| 5 Simülasyon | Tamam, oran değişmedi | - | aşağıda |
| 6 verify.ps1 | Geçti (dal ve main) | `d717608` (selene gölgeleme düzeltmesi); merge `36dc2a2` | son satır aşağıda |

Ayrıntılar:
- Madde 1: yeni çiftlik tier'ı `#çiftlik + 1` (`MainFarmService` zaten böyleydi), alım sırasıyla uyumlu; "maks tier + 1" seçilmedi çünkü eski 3 çiftlikli oyuncunun 4. çiftliği tier 2 (x13) olup yeni oyuncudan ucuz kalırdı. Satış çarpanı değiştirilmedi: tier artık çiftlik başına sabit, alım ve satım aynı çarpanı kullandığından çiftlikler arası kâr kalmadı (açık yalnızca eski sıra atamasından geliyordu).
- Madde 2: üretim kuralı, istemci `ProductionPanel` ve `GoalCard` aynı formülü kullanıyor; yardımcı otomatik teslim (`canClaimAutomatically`) da aynı kuralla. Yeni metin: "Fazlası paraya çevrildi" (en/de/ru eklendi).
- Madde 3: temada olmayan ada yükseltmeleri (ada, bölge, tesis, bonus) yalnızca `farmId == "3"` için kaldırılır; bedel `upgrade.cost x tier çarpanı` olarak iade edilir. Bu adalardaki hayvanlar (hayvanın taban fiyatı x çarpan) iade edilir, taşınmaz. Bu adalardaki üretim işleri ve otomatik tekrar kayıtları düşer. Şema sürümü artmadı.

## Simülasyon (önce = P3 raporundaki dal sonu, sonra = bu rapor)

Casual (`--days 7`):

| Ölçü | Önce | Sonra |
|---|---|---|
| Çevrimdışı payı | %89,3 | %82,5 |
| Çiftlik 2 / 3 / 4 / 5 / 6 alındı (dk) | 1440 / 1920 / 2400 / 3378 / 5280 | 1440 / 2400 / 3376 / 5290 / 8160 |
| 7 gün sonu kasa | $2,6B | $222M |
| Sipariş payı | %2,3 | %1,5 |
| Park edilmiş çiftlik payı | %4,4 | %9,3 |

Not: Ç3-Ç6 alım süreleri çevrimdışı kesintinin (0,5 -> 0,3, 8 -> 6 sa) etkisiyle uzadı, adım düşüşünün (8 -> 6) etkisini bastırdı; 6. çiftlik yine 7 gün içinde (8160 dk = 5,7 gün). Kasa düşüşü, tüm yükseltmelerin alınmasından ($222M) kaynaklı; 39/69 yükseltme.
Oran ayarı: `OFFLINE_UPGRADED_EARNING_RATE` 0,25'te pay %80,0 ve 6. çiftlik 9120 dk'ya (6,3 gün) kayıyordu, ama 0,25 temel orana eşit olur ve Pasif Gelir'in oranı artırmasını siler (test "hem oran hem süre artar" der). Bu yüzden 0,3 bırakıldı; %82,5 "açıkça hedef dışı" sayılmadı.

Varsayılan (ideal, 6 sa): ilk ada (tavuk) 18,7 dk, at 54,2 dk, keçi 158,0 dk, 6. saat geliri 6838,4/sn, kasa $16M. P3'teki değerlerle birebir aynı (bu tur ilk çiftlik hızını değiştirmiyor).

## verify.ps1 son satırı
`All automated checks passed. Studio multiplayer, DataStore fault and device tests remain separate.`
(`main`'de tip analizi atlandı: `.tools/luau-lsp` ana checkout'ta yok; dalda çalıştırılmıştı. Eklenti yeniden derlenmeli uyarısı da duruyor.)

## Birleştirme ve temizlik
- `git merge --no-ff balance/tur2` tamam; `main`'de verify geçti.
- `git worktree remove` ve `git branch -d balance/tur2` tamam.
- `feat/onboarding`: `-D` ile silindi. Özel commit'leri vardı (son: `9ec7eb0` perf: FarmHud kapalı pencereleri çizmez); kullanıcı onayladığı için silindi, geri almak istenirse `git branch feat/onboarding 9ec7eb0`.
- `fix/analiz-hafta1`: `-d` kabul etti (zaten main'de), tamam.
- `stash@{0}` `yarim-mobil-artiklari` düşürüldü (geri alma: `git fsck --unreachable`, kimlik `2c5b187`).
- Hiçbir şey push edilmedi.

## Studio'da eklenecek denetimler
1. MAP_VERSION 51 (dal P3'ten): eklentiyi yeniden derle, "Haritayı Kur", `map-structure.spec`.
2. Eski kayıt göçleri: (a) çok çiftlikli eski hesap yüklenince tüm çiftliklerin fiyatı eskisi gibi (x1) olmalı, yeni alınan çiftlik `#çiftlik + 1` tier almalı; (b) eski 3. çiftlik (tavuk/domuz adalı) kaydı yüklenince `BarnVisualService` hatasız çalışmalı, kasaya iade yansımalı, haritada hayalet ada kalmamalı, At adası satın alınabilmeli.
3. Ürün merkezi: kapasiteyi aşan parti boş depoda başlamalı; teslimde "Ahıra eklendi ... Fazlası paraya çevrildi" bildirimi ve nakit gelmeli; Üretim penceresi düğmesi "Depo dolu" sadece sığabilecek kısım sığmıyorsa görünmeli.
4. Pasif Gelir açıklaması: "%25'ten %30'a, süre 2 saatten 6 saate" (Config'ten üretilir) ve eşyalı toplam oran 0,5'i geçmemeli.
5. Sipariş panosu ödülleri yarıya yakın düşer (taban 60 sn): panoda gösterilen ile alınan tutar aynı mı.

## Açık sorular
1. Yayında çok çiftlikli oyuncu yoksa 3. tema göçü ve eski kayıt testleri teorik kalır; varsa göç sonrası iade bildirimi (şu an sessiz) oyuncuya gösterilsin mi?
2. Casual çevrimdışı payı %82,5; hedef 70-80 için `OFFLINE_UPGRADED_MAX_HOURS` 6 -> 5 ya da oturum sayısı varsayımı mı denenmeli? (Oran 0,3'ün altına düşürmek Pasif Gelir'i anlamsızlaştırır.)
3. Genişletmeler (alan genişletme seviyeleri) göçte iade edilmiyor: 3. tema kaldırılan adaların bölge genişletmeleri kayıtta artık işe yaramaz halde duruyor (zararsız, para iadesi yok).
4. O3 bulgu 7 (park edilmiş toplayıcısız çiftlikte `autoCollect` telemetri nedeni) ve bulgu 8 (P3 belgesinde "tesis kurma x9" yanlışı, simülasyon yardım metni) bu turda yapılmadı.
