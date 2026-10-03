# Altın, Robux marketi ve rebirth seviyeleri planı

Durum: **plan** (kod yok). `docs/REBIRTH_PLANI.md` ile birlikte okunur. Sayılar taslaktır; `scripts/simulate-*.py` ile ayarlanır.
**Kapsam dışı:** mevcut görünüm eşyalarına (8 şapka, 7 sırt) etki verilmesi ayrı, bağımsız bir iştir (ayrı yönerge ile yapılır); bu belge ona bağlı değildir.

## 1. Omurga: üç katman
| Katman | Ne | Rebirth'te |
|---|---|---|
| **Para** | tur içi oyun parası | sıfırlanır |
| **Altın** | hesap düzeyi, **zaman para birimi** (1 altın ≈ 1 dk bekleme / 0,5 dk gelir) | **kalır, birikir** |
| **Robux** | altın, anlık para paketi ve tur ürünlerini satar; kalıcı eşya/görünüm de alır | satın alınanlar kalır |

İlke: **her şey Robux'la hızlanabilir, ama hiçbir şey yalnızca Robux'la kilitli değildir**: Robux'la alınabilen kalıcı eşyaların hepsi altınla da alınabilir (altın ilerleme/zamanla kazanılır). Robux = bekleme süresini atlatmak.

## 1b. Referans gelir (altın ve para paketlerinin ölçüsü)
Altının paraya çevrilmesi ve "N dakikalık gelir" paketleri **etkin çiftliğin değil, hesabın referans gelirine** göre hesaplanır:
- **Referans gelir = sahip olunan çiftlikler arasında en yüksek (kalıcı) gelir** (`FarmMath.getReferenceIncome`). Çoğu zaman en yüksek numaralı çiftliktir; ama yeni açılmış, henüz hayvansız bir 6. çiftlik küçük gelir verirse onun yerine gerçekten en çok kazanan çiftlik sayılır (kullanıcının "en yüksek çiftlik" önerisinin sağlamlaştırılmış hali).
- Amaç: 6. çiftliği açmış oyuncu Çiftlik 1 etkinken (ya da yeni çiftlikteyken) çevirme yapınca gereksiz yere az para almasın, şikâyet çıkmasın. Cüzdan zaten tektir (para çiftlikler arasında ortak), bu yüzden dönüşümün de hesap düzeyinde olması tutarlıdır.
- **Geçici bonuslar referansa girmez:** Geri Dönüş bonusu ve "tur boyunca 2x" bonusu referans gelire katılmaz (altın çevirme/paket ile bonusun üst üste binip katlanmasın). Kalıcı etkiler, eşyalar ve geçitler girer.
- **Hesaplama:** sunucuda `FarmProfiles.view(data, farmId)` ile her sahip olunan çiftliğin geliri `computeIncomePerSecond` ile hesaplanır, en yükseği alınır (en çok 6 çiftlik; olay başına bir kez). **İstemci park edilmiş çiftliğin hayvanlarını görmez** (`FarmProfiles.clientState` hafif görünüm): sunucu her çiftliğin gelirini `mainFarmSummaries[i].incomePerSecond` ile gönderir, istemci en yüksek olanı alır. Önizlemeler ("X altın -> $Y", "paket ≈ $Z") bu değerden hesaplanır; gösterilen = tahsil edilen.
- **Önizleme zorunlu:** çevirme düğmesi onaydan önce tutarı gösterir ("20 altın → $4,2M, referans: Çiftlik 6"); tahmini tutar sunucu yanıtıyla aynıdır.

## 2. Altın
- **Kaynak (yalnızca ilerleme):** ada tamamlanınca (adanın tüm yükseltmeleri) **20**, çiftlik tamamlanınca **+50** (~780 altın/tur; taslak). Kazanım yalnızca sunucuda "ada/çiftlik tamamlandı" olayından hesaplanır; istemci miktar gönderemez.
- **Robux ile satın alma:** Market'te altın paketleri.
- **Kullanım (sink'ler):**
  1. **Paraya çevir:** 1 altın = **referans gelirin** (bölüm 1b) 0,5 dakikalık karşılığı nakit. Oran gelire bağlı, erken ve geç oyunda aynı "zaman değerini" verir; hangi çiftliğin etkin olduğundan bağımsızdır.
  2. **Hızlı bitir:** devam eden üretim partisi, hayvan büyümesi, eklenti bekleyişi (kalan dakika kadar altın, en az 1).
  3. **Kalıcı eşya/görünüm:** Robux'luk son seviye eşyalar ve kolaylık ürünleri altınla da alınır (örn. 300-1500 altın; taslak).
- **Birikim koruması:** altın kalıcı ve birikir; sınırsız birikip tek seferde paraya çevrilerek geç turları anlamsızlaştırmasın diye çevirme **günlük ve tur başına sınırlıdır** (taslak: günde en çok 200, turda en çok 600 altın). Sink'ler (3) birikimi doğal olarak tüketir.
- **Kayıt:** `gold` hesap alanı (`SaveCodec/Account`, `SessionLock.VERSION` artar). Çevirme/hızlı bitir/satın alma sunucuda, `RequestGuard` + hız sınırı + `requestId`; `PlayerDataService.trySpend` benzeri tek adımlık tahsilat.

## 2b. Aynı sorun başka yerlerde (ayrı düzeltme önerisi)
Bugün şu hesaplar **etkin çiftliğin** gelirini kullanıyor; 6. çiftliği olan oyuncu başka çiftlikteyken aynı mahrumiyeti yaşar:
| Yer | Bugün | Öneri |
|---|---|---|
| Günlük ödül (`Rewards.dailyAmount`) | etkin çiftlik geliri x 3 dk | referans gelir |
| Mevsim hedefi ödülü (`Rewards.seasonalReward`/hedef) | etkin çiftlik | referans gelir |
| Sipariş ödül tavanı (`Contracts.offers` `rewardCapMinutes`) | etkin çiftlik; yeni çiftlikte adetler 1'e iner | referans gelir (istemci eşitliği için `save.referenceIncome` sunucudan gelir) |
| Gelir paketi (`MonetizationService.incomePack`) | etkin çiftlik | referans gelir |
| Altın hayvan (`Golden`) | etkin çiftliğin toplam geliri | **kalır** (etkin çiftlikte oynanan, yakalanan olay) |
| Çevrimdışı kazanç | yalnızca etkin çiftlik (bilinen sınır, `SaveCodec`) | ayrı karar |
`FarmMath.getReferenceIncome` tek yerden yazılır; yukarıdakiler ona bağlanır. Sipariş tavanında istemci/sunucu eşitliği için hesap sunucuda yapılıp client state'e yazılır (tavan %25'lik basamaklara yuvarlandığı için titremez). Bu düzeltme altın işinden bağımsız yapılabilir (ayrı yönerge).

## 3. Robux Marketi
Dükkândaki "Destek paketleri" **Robux Marketi** penceresine dönüşür (`StoreSection` genişler); sekmeler:
- **Altın:** 100 / 500 / 1500 altın paketleri (fiyatlar kullanıcıya ait).
- **Para:** "N dakikalık gelir" paketleri (mevcut `incomePack` mantığı, ama **referans gelirle**, bölüm 1b); tutar ürün kartında önceden yazar. **Sabit para miktarı satılmaz** (erken oyunda çiftlik açılışlarını atlatır, geç oyunda değersiz kalır). Rebirth sonrası referans gelir küçük olduğundan paket tur başında küçük çıkar, oyuncu doğal olarak daha geç alır.
- **Tur boyunca:** 2x gelir ve üretimi tamamla (rebirth'te sıfırlanır; her turda tekrar alınır, ucuz).
- **Kalıcı:** son seviye eşyalar ve kolaylık ürünleri (bölüm 4) ile **Görünüm** sekmesi (bölüm 5); ilgili pencerelerde de "Robux ile al" düğmesi.
Para ve altın ürün satışı yalnızca sunucuda `ProcessReceipt` ile (kimlik 0 = kapalı kuralı sürer; makbuz çift işlenmez).

## 4. Kalıcı eşya ve kolaylık ürünleri
- **Son seviye eşyalar** (Robux **ya da** altın, kalıcı; rebirth'te kalır): Elmas Çekiç, Mevsim/Hava Asası (sonsuz), Gelir Tılsımı 3, Büyüme/Depo/Ambar/Sipariş Tılsımı son kademeleri. Alt kademeler nakitle alınır ve rebirth'te sıfırlanır.
- **Kolaylık ürünleri** (otomatik toplayıcı, yardımcılar `pet_cash`/`pet_goods`, isteğe bağlı depo): üç yol — nakit (sıfırlanır), altın veya Robux (kalıcı). Robux/altınla alınan sahiplik hesap düzeyinde `owned` işaretiyle tutulur; nakit sahiplik çiftlik kaydındadır; ikisi varsa etki bir kez uygulanır.
- **Tavan:** eşya + rebirth etkisi + Robux ürünü toplamı gelir artısı için knee/tavanla sınırlanır; hepsi alınsa bile tur süresi tabanın altına inmez (`REBIRTH_PLANI` bölüm 6/8; sim denetler).

## 5. Görünüm (saf kozmetik) — Robux sekmesi
- Nakit dükkândaki eşyalar etki verir (ayrı iş); **etkisiz saf kozmetik** (şapka, kanat, aura, iz, yardımcı/ada görünümü, ada tabelası çerçevesi) yalnızca **Robux Marketi › Görünüm** sekmesinde satılır, kalıcıdır.
- Altınla da alınabilecek bir alt küme (ucuz kozmetikler) isteğe bağlı; altın sink'i olarak kullanılabilir.
- Rebirth rozet/aura kozmetikleri (bölüm 6) ücretsiz kazanılır ve aynı gösterim sistemini kullanır.

## 6. Rebirth sayısı ve seviyeleri
Rebirth sayısı = kalıcı etki puanı sayısı (`REBIRTH_PLANI` bölüm 4). Her rebirth bir etki seçimi verir (havuz `REBIRTH_PLANI` bölüm 6). Ek olarak **seviye dönüm noktaları** (taslak):

| Seviye | Kazanım |
|---|---|
| Her rebirth | +1 etki seçimi (havuzdan; seviyeli, tavanlı) |
| R1 | bronz rozet, Geri Dönüş bonusu (24 saat, `REBIRTH_PLANI` bölüm 7) |
| R3 | gümüş rozet, altın kazanımı +%10 |
| R5 | ek tılsım yuvası, hızlı bitir altın maliyeti -%10 |
| R10 | altın rozet + aura, altın kazanımı +%10 daha |
| R25 | efsane rozet, sipariş panosuna +1 slot |

Rozet gösterimi: `StatsPanel`'de para satırı altında (`UiKit.iconChip` + `UiKit.badge`), oyuncu adı üstünde küçük rozet. Etki toplamı yine tek tavana tabidir.

## 7. Rebirth'te neler kalır (özet)
| Sıfırlanır | Kalır |
|---|---|
| para, çiftlikler, hayvanlar, yükseltmeler, ırk, nakitle alınan eşya/yükseltme/yardımcı/toplayıcı, başarımlar, ahır stoğu, sözleşmeler, tur içi Robux ürünleri | **altın**, Robux/altınla alınan kalıcı eşya ve kolaylıklar, Görünüm satın alımları, rebirth sayısı/etkileri/rozetleri, ayarlar, makbuz kayıtları |

## 8. Uygulama sırası
0. **`FarmMath.getReferenceIncome`** (bölüm 1b/2b), `mainFarmSummaries[].incomePerSecond`, istemci eşitliği testi.
1. **Altın:** `GameTypes` + `SaveCodec/Account` (`gold`), `SessionLock.VERSION`, `FarmMath.isIslandComplete`, kazanım olayı, `Services/GoldService` (çevir, hızlı bitir, satın alma), HUD altın göstergesi, testler (kazanım yalnızca sunucuda, çevirme sınırı, atomik tahsilat).
2. **Robux Marketi:** `Config/Shop.luau` yeni ürünler (altın/para paketleri, tur ürünleri), `MonetizationService` etkileri, `StoreSection` sekmeleri, makbuz testleri.
3. **Kalıcı sahiplik:** `owned` işareti (Robux/altın), son seviye eşya ve kolaylık çift fiyat, Görünüm sekmesi.
4. **Rebirth** (`REBIRTH_PLANI` bölüm 10): `RebirthService`, menü, seviye dönüm noktaları.
5. **Sim/denge:** `--rebirth`, altın kazanım/çevirme oranı, toplam etki tavanı, `audit-economy.py` ve `ECONOMY_LIMITS`'e altın/eşya sınırları.

## 9. Açık noktalar (karar/ölçüm)
- Altın miktarları, çevirme oranı ve limitleri sim ile ayarlanır.
- Robux fiyatları ve paket büyüklükleri kullanıcıya aittir.
- Görünüm sekmesinin altınla alınabilen alt kümesi olsun mu?
- Seviye dönüm noktası kazanımları (ek yuva, panoya slot) uygulamada ayrıntılandırılır.
