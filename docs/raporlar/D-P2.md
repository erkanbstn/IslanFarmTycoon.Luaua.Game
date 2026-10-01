# D-P2 raporu: `feat/sim-genislet` düzeltmeleri

`docs/raporlar/P2.md` bulgularından 1, 2, 3-5 ve 6 uygulandı; hiçbiri atlanmadı. Çalışma worktree'si: `C:\Users\erkan\Desktop\roblox-oyun-sim` (dal `feat/sim-genislet`). O2 raporu yok (Aşama 2'de P2 yoktu). Push yapılmadı.
Çevrimdışı gelir: ilk turda "yalnızca etkin çiftlik" yapılmıştı, kullanıcı kararıyla ikinci turda geri alındı (park edilmişler de kazanır); güncel durum "## İkinci tur" başlığında.
Karar: **Birleştirilebilir.**

## Bulgular
| # | Durum | Commit |
|---|---|---|
| 1 Çevrimdışı gelir tüm çiftliklere yatıyor | Düzeltildi: `goOffline` yalnızca kök (etkin) kayıt için `computeOfflineEarnings` çağırıyor (`SaveCodec.luau:383` gibi); görev temizliği tüm çiftliklerde duruyor | `7c25f36` |
| 2 Aynı `.test-build/simulate.luau` | Düzeltildi: `simulate-<pid>.luau`, iş bitince siliniyor. Üç persona paralel koşuldu, çıktılar doğru başlıkta | `40cb952` |
| 3, 4, 5 Sınırlar (tek oturumlu 6 sa, depo dolu metriği, park edilmişte elle üretim yok) | Kod değişmedi; betik docstring'ine "Bilinen sınırlar" eklendi | `eb1b080` |
| 6 Duman testi | `verify.ps1`'e "Economy simulation smoke (--json parses)" adımı eklendi (casual, 2 saat, JSON ayrışır, hayvan > 0) | `eb1b080` |

## 7 günlük persona tablosu (düzeltme sonrası, sırasız paralel koşu)
| Persona | Yükseltme | Çiftlik | Kasa | Gelir/sn | Dk. eylem | Çevrimiçi | 2. çiftlik | Gelir payları |
|---|---|---|---|---|---|---|---|---|
| idle | 40/69 | 6 | 142 M$ | 5851 | 11,95 | 140 dk | 3600 dk | çevrimdışı %85, park %9, hayvan %3, üretim %2 |
| casual | 40/69 | 6 | 1,24 Mr$ | 5851 | 6,42 | 420 dk | 1920 dk | çevrimdışı %68, park %16, üretim %9, hayvan %5 |
| hardcore | 40/69 | 6 | 3,68 Mr$ | 5851 | 5,71 | 1680 dk | 720 dk | park %35, çevrimdışı %31, üretim %21, hayvan %12 |

Önceki (hatalı) kasa: 2,69 / 6,1 / 8,4 Mr$; çevrimdışı payı %96 / %91 / %69.
Hâlâ dikkat: 7 günde üç persona da aynı son durumda (40/69, 5851/sn, 6 çiftlik); simülasyon kasayı harcayacak yatırım bulamıyor, yani ayrım son durumda değil zamanlamada ve kasada. P3'te (çiftlik başı maliyet çarpanı) ölçüt olarak kilometre taşı zamanlarına (özellikle "ÇİFTLİK n alındı") bak, son duruma değil. `idle` dakikada eylem sayısı yüksek görünüyor çünkü çevrimiçi süre kısa ve oturum başında birikmiş kasa topluca harcanıyor; bu bir hata değil.

## verify.ps1 son satırı
`All automated checks passed. Studio multiplayer, DataStore fault and device tests remain separate.`
(Yeni worktree'de `.tools/luau-lsp` olmadığı için "Tip analizi ATLANDI" çıktı; ana klasörün `-LuauDirectory`'si kullanıldı. Değişen yalnızca Python/PowerShell olduğundan Luau tip tabanına etkisi yok.)

## Studio'da denenecekler
Yok. İsteğe bağlı: 2 çiftlikli hesapla çıkıp 1 saat sonra girince çevrimdışı kazancın yalnızca etkin çiftlik için yatması (P2.md Açık soru 1: bu davranış tasarım gereği mi, hâlâ kullanıcı kararı bekliyor).

## Açık sorular
1. Park edilmiş çiftliklerin çevrimdışı kazanç getirmemesi tasarım gereği mi? Oyun değişirse (P3 madde 2) `goOffline` de değişmeli.
2. Altın hayvan deterministik eşik olarak kalsın mı?

## `git log --oneline main..HEAD`
```
eb1b080 test: sim duman koşusu verify.ps1'de, bilinen sınırlar docstring'de
40cb952 fix: sim geçici Luau dosyası süreç kimliğiyle, paralel koşular çakışmaz
7c25f36 fix: sim çevrimdışı kazancı yalnızca etkin çiftliğe yatar (SaveCodec ile aynı)
a23ecd4 feat: ekonomi simülasyonunu genişlet (oturum, üretim, sipariş, ödül, çoklu çiftlik, persona)
```

## İkinci tur
Kullanıcı kararı: **park edilmiş çiftlikler çevrimdışıyken de kazanır; oyun böyle kalacak.** Kanıt (`main`): `SaveCodec.decode` her çiftliği `decodeFarm`'dan geçirir, çevrimdışı kazanç o çiftliğin `farm.cash`'ine yazılır, `refundedTotal` ile ortak kasaya eklenir (`SaveCodec.luau` ~519-542). Birinci turdaki "yalnızca etkin çiftlik" düzeltmesi (`7c25f36`) bu yüzden oyunun gerçek davranışından sapıyordu; Açık soru 1 kapandı, yukarıdaki Bulgu 1 ve özet satırı bu turla geçersiz.

Düzeltme (`scripts/simulate-economy.py`, `goOffline`, commit `eaccfbb`): her çiftlik `FarmProfiles.view(save, farmId)` görünümüyle kendi `computeOfflineEarnings`'ini hesaplar (kendi Pasif Gelir oranı/süresi ve bonusları; SaveCodec'te her çiftlik bağımsız çözüldüğü için denk), hepsi ortak kasaya yatar ve ömür boyu kazanca sayılmaz. Görev temizliği aynı döngüde. Başka kod değişmedi.

Altın hayvan (Açık soru 2): deterministik kaldı. `Golden.current(save, USER_ID, now)` sabit kullanıcı kimliğinden türer, yakalama `Merchant.rand(USER_ID, cycle, 99) < goldenChance` eşiğiyle karar verir; rastgelelik eklenmedi. Gelir payı ~%0,0 (1,2 K$ - 481 K$), kasayı etkilemiyor.

### 7 günlük persona özeti (önce / sonra)
"Önce" = birinci tur sonu (`eb1b080`, yalnızca etkin çiftlik), "sonra" = bu tur. Kasa birimi: M = milyon, Mr = milyar.

| Persona | Kasa | Çevrimdışı payı | Park payı | 2. çiftlik (dk) | 3 / 4 / 5 / 6. çiftlik (dk) | Dk. eylem |
|---|---|---|---|---|---|---|
| idle | 142 M$ → 2,7 Mr$ | %85 → %96 | %9 → %2,7 | 3600 → 3600 | 4320 / 5040 / 5760 / 7920 → 4320 / 4320 / 5040 / 5040 | 11,95 → 11,15 |
| casual | 1,2 Mr$ → 6,1 Mr$ | %68 → %91 | %16 → %5 | 1920 → 1920 | 1929 / 2880 / 3360 / 4800 → 1929 / 2400 / 2400 / 2880 | 6,42 → 6,00 |
| hardcore | 3,7 Mr$ → 8,4 Mr$ | %31 → %69 | %35 → %17 | 720 → 720 | 755 / 1080 / 1440 / 2160 → 755 / 1080 / 1080 / 1440 | 5,71 → 5,51 |

Üç persona da 7. günde yine 40/69 yükseltme, 106 hayvan, 5851/sn ve 6 çiftlikte; son durum değişmedi. Kasa değerleri birinci turdan önceki değerlerle aynı (2,7 / 6,1 / 8,4 Mr$; çevrimdışı payı %96 / %91 / %69), yani birinci tur öncesi sayılar aslında doğru davranışı gösteriyormuş.

Yorum: 2. çiftlik zamanı değişmedi (o ana kadar park edilmiş çiftlik yok). 4.-6. çiftlikler park edilmişlerin getirisiyle daha erken alınıyor (en çok idle'da 6. çiftlik 7920 → 5040 dk). Persona ayrımı çiftlik zamanlamasında ve kasada sürüyor (2. çiftlik 3600 / 1920 / 720 dk). P3'te (çiftlik başı maliyet çarpanı) ölçütü son duruma değil kilometre taşı zamanlarına bağla ve çevrimdışı gelirin kasanın %69-96'sı olduğunu hesaba kat.

`verify.ps1` son satırı: `All automated checks passed. Studio multiplayer, DataStore fault and device tests remain separate.` (`-LuauDirectory` ana klasörün `.tools/luau`'su.)

Studio'da denenecek: 2 çiftlikli hesapla çıkıp 1 saat sonra girince kasaya iki çiftliğin çevrimdışı kazancının toplamı yatmalı (kod değişmedi, yalnızca sim SaveCodec'e eşlendi).

**Karar: Birleştirilebilir.** (Karar güncellendi: park edilmiş çiftlik çevrimdışı kazancı tasarım gereği; sim buna uyuyor.)
