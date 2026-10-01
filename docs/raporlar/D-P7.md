# D-P7 raporu — `feat/onboarding-paketi` düzeltmeleri

**Özet:** P7 raporundaki 1-4. bulgular düzeltildi (3 commit, worktree `roblox-oyun-onboarding`); 5-8 bilinçli atlandı.
`scripts/verify.ps1` temiz, testler yeşil (O7 raporu yok; yalnızca P7 esas alındı).

## Düzeltilen
| Bulgu | Commit | Ne yapıldı |
|---|---|---|
| 1 Çeviri "x/3" | `83057b2` | en/de/ru `İLK ADIMLAR 1/6..3/6` değerleri x/6 yapıldı |
| 4 Toasts bayat girdi | `36dfcc5` | `scheduleFade` önce `active[key]`'yi (yalnızca aynı girdiyse) temizler, sonra silinmişse döner |
| 2 4. adım her girişte | `d08002b` | 4. adım yalnızca `lifetimeEarned < 1500` ve genişletmesizken; kıdemli doğrudan 5/6'ya geçer (kayıt alanı gerekmedi) |
| 3 5. adım 6'yı bloklar | `d08002b` | Genişletmeye para yetmiyor ve hazır tesis (parti yok) varsa 6. adım öne geçer; para yetince 5 |
Testler `tests/onboarding.spec.luau`'da güncellendi (kıdemlide 4 çıkmaz) ve yeni durum eklendi (para yetmezken 6, yetince 5).

## Atlanan
- 5 (rozetli toast'ta uzun metin): Studio'da dar ekran/ru ile görülmeli; kod değişikliği için kanıt yok.
- 6, 7, 8: P7 raporunda yalnızca not, davranış hatası değil.
- Açık soru "kıdemli her girişte 4. adım": düzeltmeyle çözüldü (yeni hesaba özel).

## Notlar
- Davranış değişikliği: 1.500–20.000 bandındaki oyuncu artık Yol Haritası adımını görmez; Yol Haritası karosu `step >= 4 or earned >= 300` ile zaten açık kalır.
- Hâlâ geçerli: `feat/mobil-ses` ile 5 dosyada çakışma (`FarmHud`, `MenuBar`, 3 dil dosyası, `run-tests.py`); çeviri anahtarlarını birleştirirken x/6 değerlerini koru.
- Dikkat: ana klasörde yanlışlıkla `stylua src tests plugin` çalıştı; yalnızca biçimlendirir (izlenen değişiklik listesi aynı kaldı, yeni dosya değişmedi), ama ana klasördeki yarım mobil dosyalar da biçimlenmiş olabilir.

## verify.ps1 son satırı
`All automated checks passed. Studio multiplayer, DataStore fault and device tests remain separate.`

## Commit'ler
`git log --oneline main..HEAD`: `d08002b`, `36dfcc5`, `83057b2` (düzeltmeler) + `6fa725d`, `54fc4b0` (P7).

**Karar: Birleştirilebilir** (mobil-ses çakışması Aşama 4'te çözülecek).
