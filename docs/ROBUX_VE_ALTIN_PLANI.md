# Altın, Robux marketi ve rebirth seviyeleri planı

Durum: **altın, kalıcı sahiplik ve ürün ödülleri uygulandı**; Creator Hub kimlikleri/fiyatları olmadığı için Robux satışları kapalıdır. Güncel teslim: [REBIRTH_GELISTIRME_RAPORU.md](REBIRTH_GELISTIRME_RAPORU.md), 4 Ekim 2026.

Market genişletmesi: [MARKET_GELISTIRME_RAPORU.md](MARKET_GELISTIRME_RAPORU.md) ilk sekiz yeni ekipmanı ve birleşik kataloğu anlatır. Sonraki 30 rebirth geliştirmesi üç uzman ürün, beş ücretsiz rebirth ekipmanı, 50/3000 altın paketleri ve tek kullanımlık büyütme ürünü ekler. Güncel kalıcı satış teklifi sayısı 24'tür; fiyat/etki kaynağı Config'tir. [30 tur doğrulaması](REBIRTH_30_DOGRULAMA.md).

## Güncel satış ve ekonomi sözleşmesi

- Her turun ana ada dahil 24 adası ve altı çiftliği için başlangıç altını 780'dir. Tamamlanma ödülü bir kere verilir; son ödüller rebirth sıfırlamasından önce tahsil edilir. R3/R10 bonuslarıyla 858/936 olabilir.
- Altın kalıcıdır. Nakit çevirme günlük UTC 200, tur başına 600 ile sınırlıdır; rebirth bugünkü kotayı yenilemez. Bir altın 30 saniyelik kalıcı referans gelir eder. Referans, sahip olunan çiftliklerin en yüksek nötr yetişkin potansiyelidir; geçici Return/tur 2x, görev kaybı ve hava dahil değildir. Önizleme değişirse işlem reddedilir.
- Üretim, büyüme ve eklenti bekleme süreleri altınla bitirilebilir. Sunucu güncel kalan süreyi, hayvan/iş kimliğini ve önizleme bedelini doğrular; eski işe ait istek yeni işi bitiremez.
- Kalıcı satış teklifleri 21 ekipman ve üç kolaylıktır. Tek kaynak `Config/Progression.permanentOffers` tablosudur. Nakit edinim tur içidir, altın/Robux kalıcıdır. Beş rebirth ekipmanı ücretsiz kazanılır, satın alınamaz. Her yuvada tek ekipman takılır; tüm avantajlar üst üste toplanmaz. Yeni mesh üretilmedi.
- Robux kataloğu: 50/100/500/1500/3000 altın, üç nakit paketi, tur 2x, kalıcı teklifler, mevcut üretimi bitir ve tek kullanımlık genç hayvanları büyüt. Nakit paketi kalıcı referans gelirle hesaplanır. Kimlikler 0 olduğundan satış kapalıdır; platform fiyatı uydurulmaz. Altın satın almak çevirme kotalarını artırmaz.
- Mevcut 2x geçidi ile tur 2x üst üste 4x olmaz. Takılı eşya × rebirth gelirinin sert tavanı 3'tür; tur/geçit 2x bunun dışındadır. UI gelir etkisinin tavan sonrası ek kazancını gösterir.
- Makbuz etkisi ve satın alma kimliği aynı kalıcı snapshot içindedir. Kayıt doğrulanmadan `PurchaseGranted` verilmez. Aynı makbuz tekrar ödül vermez. Ayrı ödeme nedeniyle ikinci kalıcı eşya teslimi altın eşdeğerini verir; cüzdan tavanında teslim ertelenir. R30 öncesi aktif 2x üzerine gelen 2x sonraki tur kredisidir; terminal krediler ve geç gelen ayrı 2x ödemeleri adet başına 200 altın olur. Hızlı büyütme tesliminde genç hayvan kalmamışsa 50 altın karşılık verilir. Dolu cüzdan hakları yok etmez.
- Rebirth, kalıcı asanın bugünkü kullanımını ve finansal günlükleri korur. Geçmiş kayıtlar opsiyonel alanların güvenli varsayılanıyla yüklenir; sürüm artırıp kullanıcı verisi silme uygulanmadı.
- R5 ek tılsım yuvası, R10 aura, R25 sipariş yuvası, görünüm sekmesi ve gezgin tüccara yeni ürün eklemek ayrı geliştirme kapsamıdır. Mevcut tüccar ve model sözleşmesi korunur. İlk sürüm mevcut ekipmana işlevsel kalıcı satın alma yolları verir.

## Creator Hub açılış adımları

Ürünleri oluştur, kimlikleri doğru teklif anahtarlarına bağla, Robux fiyatlarını platformda belirle; ardından özel test ortamında gerçek makbuz/reconnect ve aynı ürün tekrar teslimini doğrula. Kimlik 0 olan ürün satışa sunulmaz. Canlı yayın ve yönetici sıfırlaması bu geliştirme sırasında yapılmaz.

## Tarihsel taslak

Aşağıdaki özgün öneriler karar geçmişidir. **Yukarıdaki sözleşme günceldir**; aşağıdaki kaldırılacak nakit yolları, sürüm artırma, görünüm ve ek slot önerileri uygulanmış özellik sayılmaz.

**Eşyaların güncel hali** (`feat/esya-etkileri` dalı, `Config/Items.luau`): artık etkisiz eşya yoktur; 8 şapka (ticari) ve 7 sırt (lojistik) mevcut etki anahtarlarıyla fayda verir, `weather_staff_1/3/5` güçsüz "Çoban Asası" olmuştur (hava gücü yalnızca `weather_staff_inf` Ebedi Hava Asası'ndadır; mevsim asaları 1/3/5/sınırsız kademeli kalmıştır), `golden_crown` (Altın Taç) en pahalı şapkadır ve `incomeBonus` ile geliri doğrudan çarpar. Bu belgedeki eşya satışı ve rebirth kuralları buna göre yazılmıştır; sayılar `Config/Items.luau`'dadır, burada kopyalanmaz.
**Terim:** **altın** = yeni para birimi; **Altın Hayvan** = mevcut rastgele olay (`Config.GOLDEN`); birbirinden bağımsızdır (bölüm 2b).

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

## 2b. Aynı sorun başka yerlerde (**yapıldı**, `fix/referans-gelir`)
`FarmMath.getReferenceIncome` yazıldı ve altın/Robux işinden bağımsız olarak şu yerlere bağlandı (altın ve para paketi hâlâ plandadır). Eskiden **etkin çiftliğin** gelirini kullanıyorlardı; 6. çiftliği olan oyuncu başka çiftlikteyken mahrum kalıyordu:
| Yer | Bugün | Öneri |
|---|---|---|
| Günlük ödül (`Rewards.dailyAmount`) | etkin çiftlik geliri x 3 dk | **referans gelir (yapıldı)** |
| Mevsim hedefi ve ödülü (`Rewards.newSeasonalGoal`/`seasonalReward`) | etkin çiftlik | **referans gelir (yapıldı)** |
| Sipariş ödül tavanı (`Contracts.offers` `rewardCapMinutes`) | etkin çiftlik; yeni çiftlikte adetler 1'e iner | **referans gelir (yapıldı)**; istemci eşitliği için sunucu `parkedIncomeBest` gönderir |
| Gelir paketi (`MonetizationService.incomePack`) | etkin çiftlik | referans gelir (Robux işi, **sonraya bırakıldı**) |
| Altın Hayvan (`Golden`, olay) | etkin çiftliğin toplam geliri | **kalır**: süreli bir olaydır (her oyuncuya özel döngülerde pencere açılır, alınmazsa o döngü kaybolur; değerler `Config.GOLDEN`), kalan süre geri sayımı istemcide görünür. Referans gelire bağlanmaz ve **altın (para birimi) kazandırmaz** |
| Çevrimdışı kazanç | **her çiftlik ayrı hesaplanıp toplanır** (`SaveCodec/Farm.decode`, çiftlik başına `lastSeen`; sim yalnızca etkin çiftliği modeller) | **bağlanmadı, gerek yok**: zaten tüm çiftlikleri topluyor (iki çiftlikli denemede ~4x), referansa bağlamak (en yüksek tek çiftlik) kazancı azaltırdı |
`FarmMath.getReferenceIncome` (etkin çiftlik canlı geliri ile park edilmiş çiftliklerin en yükseğinin büyüğü) tek yerden yazılır; sunucu park edilmiş çiftlikleri tam kayıttan hesaplar, istemciye `parkedIncomeBest` olarak gider (`FarmProfiles.clientState`, `PlayerDataService.sendState`). Sipariş tavanı %25'lik basamaklara yuvarlandığı için titremez. Test: `tests/rewards.spec.luau`.

## 3. Robux Marketi
Dükkândaki "Destek paketleri" **Robux Marketi** penceresine dönüşür (`StoreSection` genişler); sekmeler:
- **Altın:** 100 / 500 / 1500 altın paketleri (fiyatlar kullanıcıya ait).
- **Para:** "N dakikalık gelir" paketleri (mevcut `incomePack` mantığı, ama **referans gelirle**, bölüm 1b); tutar ürün kartında önceden yazar. **Sabit para miktarı satılmaz** (erken oyunda çiftlik açılışlarını atlatır, geç oyunda değersiz kalır). Rebirth sonrası referans gelir küçük olduğundan paket tur başında küçük çıkar, oyuncu doğal olarak daha geç alır.
- **Tur boyunca:** 2x gelir ve üretimi tamamla (rebirth'te sıfırlanır; her turda tekrar alınır, ucuz).
- **Kalıcı:** son seviye eşyalar ve kolaylık ürünleri (bölüm 4) ile **Görünüm** sekmesi (bölüm 5); ilgili pencerelerde de "Robux ile al" düğmesi.
Para ve altın ürün satışı yalnızca sunucuda `ProcessReceipt` ile (kimlik 0 = kapalı kuralı sürer; makbuz çift işlenmez).

## 4. Kalıcı eşya ve kolaylık ürünleri
- **Son seviye eşyalar** (Robux **ya da** altın, **kalıcı**, rebirth'te kalır). Her eşya hattının son kademesi (`Config/Items.luau`):
  - **Elmas Çekiç** (`diamond_hammer`),
  - **Ebedi Mevsim Asası** (`season_staff_inf`) ve **Ebedi Hava Asası** (`weather_staff_inf`); hava gücü yalnızca bu asadadır, alt asalar (Çırak/Usta/Üstat **Çoban Asası**) güçsüz nakit eşyadır,
  - **Altın Bereket Muskası** (`income_charm_3`), Büyük Büyüme Muskası, Büyük Depo Muskası, Altın Ambar Anahtarı, Usta Tüccar Defteri (her hattın son tılsımı),
  - **Altın Taç** (`golden_crown`) ve **Altın Kanatlar** (`golden_wings`).
- **Alt kademeler ve tüm şapka/sırt eşyaları nakit ekonomisinde kalır**, etkilidir ve **rebirth'te sıfırlanır** (karar: "her şey sıfırlanır" kuralı; Robux/altınla alınmadıkça kalıcı değildir). Nakit yol: Çoban Asaları ve alt kademeler.
- **Altın Taç** (en pahalı eşya, gelir çarpanı zincirinde ayrı bir yeri vardır, bölüm 4b): Robux ya da altınla alınır, kalıcıdır. `Config/Items.luau`'daki nakit fiyatı Robux/altın yolu açılınca kaldırılır (nakitle alınamaz); aksi halde her turda birkaç saat içinde geliri x2'ye çıkaran kısa yol olurdu.
- **Fiyat:** son seviye eşyaların altın/Robux fiyatları ileride artırılabilir (özellikle gelir çarpanı verenler); fiyatlar Config'e bağlı kalır, belgede sayı yazılmaz ("Açık kararlar").
- **Kolaylık ürünleri** (otomatik toplayıcı, yardımcılar `pet_cash`/`pet_goods`, isteğe bağlı depo): üç yol: nakit (sıfırlanır), altın veya Robux (kalıcı). Robux/altınla alınan sahiplik hesap düzeyinde `owned` işaretiyle tutulur; nakit sahiplik çiftlik kaydındadır; ikisi varsa etki bir kez uygulanır.

## 4b. Gelir çarpanı zinciri ve toplam sınır
`Income.getAnimalMultiplier` bugün: ahır x (1 + diğer bonuslar) x (1 + ırk) x (1 + **eşya**) x mevsim/hava x geçit. Eşya `incomeBonus`'u ayrı çarpandır; tüm slotlar takılıysa en çok Altın Taç + Altın Bereket Muskası + Altın Kanatlar = +%116, yani **çarpan 2,16** (`Config/Items.luau`; ancak Robux/altın yoluyla kalıcı olur).
Rebirth ve Robux bu zincire şöyle eklenir:
| Çarpan | Kaynak | En çok (taslak) |
|---|---|---|
| Eşya | takılı eşyaların `incomeBonus` toplamı | x2,16 |
| Rebirth | seçilen gelir etkisi (ayrı çarpan, eşya toplamına katılmaz; seviye başına ~%8, tavan 5) | x1,40 |
| Tur 2x (Robux, geçici) | geçit çarpanı gibi, rebirth'te sıfırlanır | x2,00 |
| Geri Dönüş bonusu | yalnızca Çiftlik 1'in ana hayvanı, 24 saat | geçici (bu hesaba girmez) |

Altın paketleri **çarpan değil para** verir (referans gelire göre, bölüm 1b); gelir çarpanını artırmazlar.
Hepsi birleşirse eşya x rebirth = x3,02, tur 2x ile **~x6,0** (mevcut ırk x1,8 vb. çarpanların üstüne). Öneri (karar bekler):
- **Kalıcı hesap çarpanı (eşya x rebirth) sınırı x3,0** (knee/tavan; sınıra yaklaştıkça artış azalır). Robux tur 2x'i bu sınırın dışındadır; en kötü durumda toplam ~x6.
- **Tur süresi tabanı** (`REBIRTH_PLANI` bölüm 8) **eşyasız** oyuncu için ölçülür; Robux/altınla alınan hızlandırıcılar (Taç, tur 2x) bu tabanın altına inebilir (bilinçli "bekleme atlatma"). En hızlı kurulumun alt sınırı sim ile raporlanır (ideal ~4 gün / 6 = ~16 saat).
- `ECONOMY_LIMITS`'e "kalıcı gelir çarpanı üst sınırı" eklenir; "hepsi takılı" üst sınır testi `tests/inventory.spec.luau`'da zaten vardır (`feat/esya-etkileri`).

## 5. Görünüm (gerçekten etkisiz kozmetik) — Robux sekmesi
Nakit dükkândaki şapka ve sırt eşyaları **etkilidir** ve eşya olarak kalır (bölüm 4); onlar Görünüm sekmesine girmez. **Robux Marketi › Görünüm** yalnızca **eşya olmayan, etkisiz** öğeleri satar, hepsi kalıcıdır:
- **Görünüm yuvaları:** aura, ayak izi/iz, unvan/isim çerçevesi (eşya slotu değildir, etki vermez).
- **Yardımcı hayvan görünümleri** (kaplama), **ada tabelası çerçevesi / ada süsleri**, **hayvan kaplamaları** (aynı hayvanın alternatif modeli; fiyat/gelir değişmez, balık görünümü gibi `Config.getAnimalLook` mantığıyla).
- **Eşya kaplamaları:** bir eşyanın görünüşünü değiştirir, etkisi aynı kalır.
Altınla da alınabilecek ucuz bir alt küme isteğe bağlıdır (altın sink'i). Rebirth rozet/aura kozmetikleri (bölüm 6) ücretsiz kazanılır ve aynı gösterim sistemini kullanır.

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
| para, çiftlikler, hayvanlar, yükseltmeler, ırk, **nakitle alınan tüm eşyalar** (çekiç, Çoban Asaları, alt asa/tılsım kademeleri, şapka, sırt) ve yükseltme/yardımcı/toplayıcı, başarımlar, ahır stoğu, sözleşmeler, tur içi Robux ürünleri | **altın**, Robux/altınla alınan kalıcı eşya (son seviye eşyalar, Altın Taç dahil) ve kolaylıklar, Görünüm satın alımları, rebirth sayısı/etkileri/rozetleri, ayarlar, makbuz kayıtları |

## 8. Uygulama sırası
0. **`FarmMath.getReferenceIncome`** (bölüm 1b/2b): **yapıldı** (`parkedIncomeBest` ile; `mainFarmSummaries` alanı gerekmedi). Altın/para paketi bu işlevi kullanacak.
1. **Altın:** `GameTypes` + `SaveCodec/Account` (`gold`), `SessionLock.VERSION`, `FarmMath.isIslandComplete`, kazanım olayı, `Services/GoldService` (çevir, hızlı bitir, satın alma), HUD altın göstergesi, testler (kazanım yalnızca sunucuda, çevirme sınırı, atomik tahsilat).
2. **Robux Marketi:** `Config/Shop.luau` yeni ürünler (altın/para paketleri, tur ürünleri), `MonetizationService` etkileri, `StoreSection` sekmeleri, makbuz testleri.
3. **Kalıcı sahiplik:** `owned` işareti (Robux/altın), son seviye eşya ve kolaylık çift fiyat, Görünüm sekmesi.
4. **Rebirth** (`REBIRTH_PLANI` bölüm 10): `RebirthService`, menü, seviye dönüm noktaları.
5. **Sim/denge:** `--rebirth`, altın kazanım/çevirme oranı, toplam etki tavanı, `audit-economy.py` ve `ECONOMY_LIMITS`'e altın/eşya sınırları.

## 9. Açık kararlar (kullanıcıya sorulacak)
1. **Altın Taç yolu:** önerim Robux/altın + kalıcı, nakit fiyatı kaldırılır (bölüm 4). Nakit yol kalsın mı? (Kalırsa Taç her turda birkaç saatte x2 gelir verir ve rebirth'te sıfırlanır.)
2. **Kalıcı gelir çarpanı sınırı:** eşya x rebirth için x3,0 önerisi (bölüm 4b). Taç tek başına x2 olduğundan rebirth gelir etkisi sınırın hemen altında kalıyor; alternatif: rebirth gelir etkisini küçültüp büyüme/indirim gibi diğer etkilere kaydırmak.
3. **Tur süresi tabanı** eşyasız oyuncu için ölçülsün, Robux hızlandırıcıları taban altına inebilsin mi? (Önerim: evet.)
4. **Son seviye eşya fiyatları** (altın ve Robux) ileride artırılabilir; özellikle Altın Taç, Altın Bereket Muskası, Altın Kanatlar. Fiyat kullanıcıya aittir, Config'e bağlanır.
5. **Çevrimdışı kazanç:** karar verildi, referansa bağlanmadı; mevcut davranış (tüm çiftlikler toplanır) kalır. (Çözüldü.)
6. **Görünüm sekmesinin altınla alınabilen alt kümesi** olsun mu?
7. **Seviye dönüm noktası kazanımları** (ek tılsım yuvası, panoya slot) uygulamada ayrıntılandırılır; kullanıcı onaylar.
8. Altın miktarları, çevirme oranı ve limitleri sim ile ayarlanır; Robux fiyatları ve paket büyüklükleri kullanıcıya aittir.
