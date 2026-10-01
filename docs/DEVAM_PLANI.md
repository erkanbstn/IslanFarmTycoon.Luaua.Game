# Devam planı: görev kartları

## Kullanım (sen)
Her ajana yalnızca şunu yaz (kimliği değiştir):

> `C:\Users\erkan\Desktop\roblox-oyun\docs\DEVAM_PLANI.md` dosyasını incele, **P4** ile ilgileneceksin.

- Oturumları `roblox-oyun` klasöründe aç.
- Model her kartın başında yazıyor (Sonnet 5.5 ya da Opus).
- Aşamaları sırayla yürüt. Bir aşamanın kartları birbirinden bağımsız, **paralel** çalıştırılabilir. Sonraki aşamaya önceki bitince geç.

| Aşama | Kartlar | Model | Paralel mi |
|---|---|---|---|
| 1 — İnceleme | P1, P2, P4, P5, P6, P7, P8, P10, P11 | Sonnet | **Evet, 9'u birden** |
| 2 — Opus incelemesi | O4, O10, O11 | Opus | Evet, 3'ü birden |
| 3 — Düzeltme | D (raporu "Düzeltme gerekir" diyen her dal için bir ajan) | Sonnet | Evet, dal başına bir ajan |
| 4 — Entegrasyon | E | Sonnet | **Hayır, tek başına** |
| 5 — Kalanlar | P3, ardından P9 | Sonnet | Hayır, sırayla |

Sonuçlar `docs/raporlar/<KİMLİK>.md` dosyalarında birikir. Sohbetlerde rapor aramana gerek yok.

---

## Ajan için ortak kurallar (her kart için geçerli)
1. Sana bir **kimlik** verildi. Bu dosyada yalnızca o kimliğin kartını uygula. Başka kartlara ve başka dallara dokunma.
2. Okunacaklar:
   - `C:\Users\erkan\Desktop\roblox-oyun\AGENTS.md`
   - `docs/ANALIZ_RAPORU.md` (kartta yazan bölüm)
   - `docs/SONNET_IS_PAKETLERI.md` (kartta yazan paket)
   Dosya bulunamazsa `git show main:<yol>` ile oku.
3. **Rapor dosyası:** `C:\Users\erkan\Desktop\roblox-oyun\docs\raporlar\<KİMLİK>.md` (mutlak yol; klasör yoksa oluştur). Başına 3 satır özet, sonuna tek satır karar yaz. Sohbete yalnızca dosya yolunu ve kararı yaz.
4. **Aşama 1-2 kartları salt okunur:** kaynak koda dokunma, commit atma, `git checkout`/`switch` yapma. Yalnızca `git log`, `git diff`, `git show <dal>:<yol>` kullan. Bütün repoyu tarama; diff'e ve değişen fonksiyonun çevresine bak.
5. **Aşama 3-5 kartları kod değiştirir:** `docs/SONNET_IS_PAKETLERI.md` "Ortak kurallar" geçerli (format/lint/test, maddeye göre commit, push yok, verify.ps1 temiz).
6. Soru sormak için durma. Belirsizliği rapora "Açık sorular" olarak yaz ve devam et.

## Dal haritası (bilgi)

| Kimlik | Dal | Taban (diff için) | Paket | Rapor bölümü |
|---|---|---|---|---|
| P1 | `feat/telemetri` | `main` | P1 | 6.5, 4.10 |
| P2 | `feat/sim-genislet` | `main` | P2 | 4.9 |
| P4 | `perf/sunucu-ag` | `feat/sim-genislet` | P4 | 3.1, 3.2, 2.6 |
| P5 | `perf/istemci` | `perf/sunucu-ag` | P5 | 3.3 |
| P6 | `feat/mobil-ses` | `54331d2` | P6 | 5 |
| P7 | `feat/onboarding-paketi` | `main` | P7 | 5 |
| P8 | `refactor/kalite` | `main` | P8 | 1.1–1.3, 7.3, 7.5, 7.7 |
| P10 | `balance/gec-oyun` | `feat/sim-genislet` | P10 | 4.5, 4.8 |
| P11 | `feat/tema-sablonlari` | `main` | P11 | 2.4, 2.5 |

Bilinen durum:
- Bu paketler başka oturumlarda uygulandı, raporları kayboldu.
- Ana klasör `feat/onboarding` dalında ve üstünde commit'lenmemiş, yarım mobil arayüz değişiklikleri var. Bu dal çöp: istemci performansı commit'lerinin kopyaları.
- Worktree klasörleri: `Desktop/roblox-oyun-gec`, `-istemci`, `-kalite`, `-mobil`, `-onboarding`, `-tema`.
- P3 ve P9 hiç yapılmadı.

---

## AŞAMA 1 — Dal incelemesi (Sonnet; P1, P2, P4, P5, P6, P7, P8, P10, P11)
Kimliğinle dal haritasındaki satırı bul (dal, taban, paket, rapor bölümü). Sonra:
1. `git log --oneline <taban>..<dal>` ve `git diff <taban>..<dal>` ile değişiklikleri incele.
2. **Madde tablosu:** paket prompt'undaki her maddeyi Tamam / Kısmi / Yapılmamış olarak işaretle; prompt dışı ekleri de yaz. Kanıt: commit + dosya.
3. **Kod incelemesi:** davranış hatası, nil erişimi, yarış koşulu; sunucu güvenliği (istemciye güven, hız sınırı); kayıt uyumluluğu (eski kayıtlar açılır mı); çeviri eksikleri (yeni oyuncu metni en/de/ru'da var mı); testler anlamlı mı. En fazla 10 bulgu: Önem · dosya:satır · neden · öneri.
4. **Çakışma riski:** bu dalın değiştirdiği dosyalardan, haritadaki diğer dalların da değiştirdikleri (`git diff --name-only` kesişimi). Kısa liste.
5. **Studio'da elle denenecekler.**
6. **Açık sorular.**
7. **Karar:** "Birleştirilebilir" / "Düzeltme gerekir" / "Geri al".

Karta özel ek kontroller:
- **P4:** pushState birleştirmesi satın alma yanıtını geciktiriyor mu; istemci park edilmiş çiftlik özetinde eksik alan okuyor mu (`src/client`'ta `mainFarms` kullanımı).
- **P5:** `UiKit.setText` geçişi metin güncellemesini atlayan bir yer bırakmış mı; DayNight ışık sınırı gece görünümünü bozuyor mu.
- **P6:** ses/ReducedMotion kayıt alanları SaveCodec'te encode/decode ve testli mi; remote eklendiyse doğrulama ve hız sınırı var mı. Ana klasördeki commit'lenmemiş değişikliklerle bu dal arasında, dalda **olmayan** bir şey var mı (`git diff feat/mobil-ses` ile karşılaştır, yalnızca oku).
- **P7:** onboarding adım bilgisi kayda yazılıyorsa şema uyumu.
- **P8:** refactor davranış değiştirmiş mi (RequestGuard'a geçen her handler eski mesaj ve dönüşleri koruyor mu); tip tabanı düşüşü gerçek mi.
- **P10:** prompt dışı karar (ırk maxLevel 10→30, costMultiplier 60, costGrowth 1,038): eski kayıtlardaki ırk seviyeleri ve maliyetleri ne oluyor; istemcide gösterilen gelir formülü sunucuyla aynı mı.
- **P11:** paket maddelerinin hepsi var mı (şablon kopyalama, optimize alt ağacı, eski/yeni karşılaştırma testi, MAP_VERSION); yalnızca 3 commit olduğu için eksik olabilir.

---

## AŞAMA 2 — Opus incelemesi (Opus; O4, O10, O11)
O4 → P4 dalı · O10 → P10 dalı · O11 → P11 dalı (dal ve taban haritada).
1. Önce Aşama 1 raporunu oku: `docs/raporlar/P4.md` / `P10.md` / `P11.md`. Rapor yoksa dur ve bunu yaz.
2. `git diff <taban>..<dal>`'de yalnızca riskli kısımlara bak: kayıt, ekonomi, çok oyunculu, yarış koşulu, prompt dışı kararların mantıklılığı. Aşama 1 raporunun kaçırdıklarına odaklan.
3. Raporunu `docs/raporlar/O4.md` / `O10.md` / `O11.md` dosyasına yaz:
   - en fazla 8 bulgu (Önem · dosya:satır · neden · öneri)
   - Aşama 1 bulgularına katılıp katılmadığın
   - tek satır karar: "Birleştirilebilir" / "Şu düzeltmelerle birleştirilebilir" / "Geri al"

---

## AŞAMA 3 — Düzeltme (Sonnet; kimlik: D-P<n>, ör. D-P4)
Yalnızca raporu "Düzeltme gerekir" ya da "Şu düzeltmelerle…" diyen dallar için.
1. `docs/raporlar/P<n>.md` ve varsa `O<n>.md`'yi oku.
2. Dalın worktree klasörü varsa (`git worktree list`) **orada** çalış; yoksa ana klasörde `git checkout <dal>`. Ana klasörde başka bir ajan çalışıyorsa önce `git worktree add ..\roblox-oyun-<kısa ad> <dal>`.
3. Bulguları düzelt (raporla çelişen ya da riskli gördüğünü atla ve gerekçe yaz). Her düzeltme ayrı commit. verify.ps1 temiz.
4. Rapor: `docs/raporlar/D-P<n>.md`. İçerik: düzeltilen / atlanan bulgular, commit listesi, verify son satırı, karar.

---

## AŞAMA 4 — Entegrasyon (Sonnet; kimlik: E) — TEK BAŞINA ÇALIŞTIR
1. **Temizlik (ana klasör):**
   - `git stash push -m "yarim-mobil-artiklari"` (yalnızca izlenen dosyalar; `docs/raporlar` ve bu dosya izlenmiyorsa yerinde kalır), sonra `git checkout main`.
   - `feat/onboarding`'in 3 commit'i `perf/istemci`'dekilerle aynı içerikteyse (`git diff` ile doğrula) `git branch -D feat/onboarding`. Değilse dokunma, rapora yaz.
2. `git checkout -b entegrasyon main`. Bu dosyayı ve `docs/raporlar/*.md`'yi commit'le.
3. **Hangi dallar alınacak:** `docs/raporlar/`'daki son karara göre (O* > D-* > P* önceliğiyle). "Geri al" → alma. "Düzeltme gerekir" olup D-raporu olmayan → atla.
4. **Sıra:** `git merge --no-ff`: `feat/telemetri` → `refactor/kalite` → `feat/sim-genislet` → `perf/sunucu-ag` → `perf/istemci` → `feat/mobil-ses` → `feat/onboarding-paketi` → `balance/gec-oyun` → `feat/tema-sablonlari`.
   - Çakışmada iki tarafın amacını da koru (ör. RequestGuard'a geçen servise telemetri çağrısını taşı; arayüzde `UiKit.setText` ile güvenli alan/UIScale değişikliklerini birlikte uygula).
   - Her birleştirmeden sonra stylua → selene → run-tests. Kırmızıysa düzelt ve "fix: <dal> entegrasyonu" commit'i at.
   - Çözemediğin çakışmada `git merge --abort`, o dalı atla, rapora yaz.
5. **Doğrulama:** verify.ps1 temiz olsun. Tip tabanına yeni bulgu ekleme, düzelt.
6. `python scripts/simulate-economy.py` çalıştır (varsayılan ve casual persona, 7 gün); çıktıyı rapora koy.
7. **Kapanış:** Her şey temizse `git checkout main` → `git merge --ff-only entegrasyon`. Birleştirilen dalları `git branch -d` ile sil. Worktree'leri, içlerinde commit'lenmemiş değişiklik yoksa `git worktree remove` ile kaldır; varsa dokunma ve listele.
8. **Rapor (`docs/raporlar/E.md`):**
   - alınan / atlanan dallar ve nedenleri
   - çözülen çakışmalar (dosya ve nasıl)
   - entegrasyon düzeltmeleri
   - verify son satırı ve simülasyon çıktısı
   - eklenti/harita notu (MAP_VERSION 50 → Haritayı Kur, eklentiyi yeniden derle)
   - **tek birleşik Studio test listesi** (`docs/raporlar/*.md` listelerinin tekrarsız birleşimi, öncelik sırasıyla)
   - açık sorular
   Raporu commit'le.

---

## AŞAMA 5 — Kalanlar (Sonnet; sırayla P3, sonra P9)
- **P3:** `docs/SONNET_IS_PAKETLERI.md` → "P3 — Ekonomi 2. tur" prompt'unu uygula. Main güncel (E bitti). Simülasyonu birleşik hâliyle çalıştır. Rapor: `docs/raporlar/P3.md`.
  Bittikten sonra yeni bir **Opus** oturumuna "`docs/DEVAM_PLANI.md` dosyasını incele, **O3** ile ilgileneceksin" de. O3, Aşama 2 kuralıyla çalışır: dal `balance/tur2`, taban `main`, rapor `O3.md`. Ardından dalı main'e al.
- **P9:** `docs/SONNET_IS_PAKETLERI.md` → "P9 — CI" prompt'unu uygula. Rapor: `docs/raporlar/P9.md`.
- Sonra karar paketleri (K1-K3) için senin kararın gerekiyor.
