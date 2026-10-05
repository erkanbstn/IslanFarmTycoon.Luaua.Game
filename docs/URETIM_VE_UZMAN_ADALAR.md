# Üretim ve uzman adalar

Harita sürümü `MapBuilder.luau` içindeki `MAP_VERSION`'dır. Kayıt kimlikleri değişince sürümü otomatik artırıp veriyi sıfırlama. Uyumluluk, taşıma ve finansal hakların korunmasını kayıt şeması skill'iyle değerlendir; `SaveCodec.decode` sürüm uyumsuzluğunda yeni profil oluşturabilir.
Haritada `Config.MAP_PLOT_COUNT` kadar takımada oyuncu başına birer fiziksel adadır; oyuncu birden fazla çiftlik (tema)
satın alabilir ve etkin olanı kendi adasında çizilir; her çiftliğin ana ve küçük adaları ayrı ilerler. Ayrıntılar
[Ana çiftlikler](ANA_CIFTLIKLER.md) belgesindedir.

## Oyun döngüsü

Tesis satın al → yeterli yetişkin hayvanı yetiştir → parti seçeneğini (küçük/standart/büyük) seç, varsa masrafı öde →
üretim süresini bekle → ürünü sat (para tesisleri), depoya al (ürün merkezleri) veya kuluçkadaki civcivi kümese ekle →
yeni parti başlat. Göreve atanmış hayvanların gelir etkisi gerçek FarmMath hesabından gelir; tüm pasif gelirin değişmeden süreceği varsayılmaz. Yetişkin hayvanlar üretim girdisi olarak tüketilmez.

Tesis listesi, gereken yetişkin sayısı, süre, masraf ve ödül **tek kaynaktan** okunur: `Config.PRODUCTION_ORDER` sırasıyla
`Config.PRODUCTION_RECIPES` (`src/shared/Config/Production.luau`; parti seçenekleri `options`). Tesisi açan yükseltmeler ve
gelir bonusları `Config.UPGRADES` içindedir. Rakamlar bu belgede tutulmaz; sürüm kaymasın diye koda bak.
Tesisler iki türdür: para tesisleri (`output = "cash"`) ve depoya ürün üreten ürün merkezleri (ahır deposu, bkz. `Config/Goods.luau`).

Her tesiste aynı anda bir parti bulunabilir. Parti, tek UID ve bitiş zamanı ile oyuncu
kaydına yazılır. Oyundan çıkınca süre devam eder; dönüşte en fazla mevcut tek parti
hazırdır, çevrimdışında otomatik yeni partiler başlamaz. Hazır ürün teslim edilene kadar
korunur. Kümes doluyken civciv kaybolmaz; yer açılınca eklenebilir veya satılabilir.

## Fabrika × ada × hayvan uyumu (değişmez)

Bir fabrika yalnızca kendi adasında ve o adada yaşayan hayvanla kurulur; kural `tests/config.spec.luau` ile her temada denetlenir
(yeni hayvan/tema eklenince de koşar; sabit liste yok). Tarif → ada eşlemesi `Config/Production.luau` `island`, tesisi açan yükseltme
`Config/Upgrades.luau`'dadır. Tema kuralı `Config.upgradeInTheme`: adası temada olmalı; **ana ada fabrikalarında** (`homeAnimal` alanı)
çiftliğin ana hayvanı da eşleşmeli (ana adada yalnızca ana hayvanın fabrikası çıkar).

Her çiftlikte ana ada + 3 küçük ada vardır ve her adada TEK hayvan yaşar; tam liste (24 hayvan: çiftlik x ada x hayvan x ürün x fabrika x ürün merkezi x ada özelliği)
[Ada tasarımı](ADA_TASARIMI.md) belgesindedir. Özet kural: her hayvanın bir para fabrikası ve bir ürün merkezi vardır; ana ada fabrikaları `homeAnimal` işaretiyle yalnızca o ana hayvanlı çiftlikte kurulur
(ör. inek: `packed_milk` / `milk_factory`, ürün merkezi `milk_goods` / `milk_center`; ördek: `duck_packing` / `duck_packer`, `down_home_goods` / `down_home_center`). Süt Adası ve Ördek Adası yoktur.
Elle yazılan eski türler (inek, tavuk, at, keçi, ördek, koyun, domuz, balık) `Config/Production.luau` ve `Config/Upgrades.luau`'dadır; 17 yeni hayvanın tarif, yükseltme ve ada satırları
`Config/Species.luau` tablosundan türer (sıra profili: ana ada / erken / orta / geç). Balık (hamsi, levrek) "Deniz" dalıdır ve her çiftlikte ortaktır (`fish_dispatch` / `fishing_boat`, `fish_goods` / `fish_cannery`).

Ana ada yuvaları (her ana hayvanın fabrikası ve ürün merkezi) harita üzerinde aynı koordinatı paylaşır (`MapLayout.HOME_BUILD_SPOTS`, `Config.SPECIES` home satırlarından eklenir); bir çiftlikte yalnızca ana
hayvanın yükseltmesi alınabildiği için üst üste binmez. Görünüm: her bina `assets/Buildings/<upgradeId>.rbxmx` modelidir (`UpgradeVisualService` klonlar; kod kurucuları silindi).

## Kullanım

Üst menü çubuğundaki **Üretim** karosu veya **R**.
**Adalar / I** ekranından uzman ada satın alınır ve **Git ve yönet** ile seçilir.
Yatırım menüleri seçilen adaya göre süzülür; para ortaktır, güçlendirmeler ilgili ana çiftliğe aittir.
Ana adadaki tüm yükseltmeler bitince sonraki adayı bu yönetim ekranından açmak mümkündür;
orada gereken ön koşullar ve fiyat gösterilir. Başka oyuncuların çiftlikleri satın alınmaz.
Sabit üretim binalarının yanındaki etkileşim de ilgili tesisi öne getirir. Panelde
tesis kurulumu, gereken ön koşullar, üretim süresi, satış bedeli ve hazır ürünler görünür.
Üretim düğmesinin rozeti teslim edilebilen parti sayısını gösterir.

At adasında eğitim parkuru, tavuk adasında yuva alanları, keçi adasında teraslar vardır.
Balıkçı teknesinin gövdesi birleştirildi ve su çizgisine göre yerleştirildi. Tekne yakın
çevresinde görsel bir devriye yapar; binilebilir taşıt değildir. Hareketi yereldir ve
ekonomi hesabını etkilemez.

## Studio'ya aktarma ve doğrulama

Play'i durdur, Rojo senkronizasyonunu tamamla, **Eklentiler → Island Farm Tycoon → Haritayı Kur**,
ardından kaydet ve Play. Harita düzeni değiştiyse (`MAP_VERSION` arttıysa) yeniden kurulum gerekir.

Studio'da ayrıca teknenin iskele/denizle hizası, tesislerin yürüme yolları, mobil panel,
iki oyuncu arasında üretim ayrımı, parti sürerken çıkıp geri girme ve dolu kümeste
civciv teslimi kontrol edilmeli. Kod testleri gerçek Studio görüntü/FPS ölçümünün yerini tutmaz.

## Denetim: sipariş panosu, üretim zinciri, ürün değerleri (5 Ekim 2026)

Araçlar: `python scripts/audit-economy.py --check` (bölüm F merkez ekonomisi, G sipariş karşılanabilirliği, H para tesisi getirisi eklendi), `tests/goods.spec.luau` yeni değişmezler,
`scripts/simulate-economy.py --persona casual|hardcore` (6 çiftlik, 7 gün). Aşağıdaki sayılar tam yükseltilmiş fixture'dır (Çiftlik 1-6, evre 1,0); sim oyuncu davranışıdır, gerçek oynanış değildir.

**Tutarlı çıkanlar (değişiklik gerekmedi).** Her merkezde "2 birim x 1,2 / (kaçırılan gelir + başlatma)" 7,2-8,4 bandındadır (taban 2 birim = ürün değeri/taban ~2,3 kuralının sonucu).
Aynı ada sırasındaki ürünlerin saniyelik değeri (2 birim / taban süre) birbirine yakındır: erken ada ~330-370 (yumurta, bal, bıldırcın, lama, ipek, angora), orta ~875-980 (yün, deve, güvercin, boynuz, gösteri bileti),
geç ~1950-2220 (peynir, et, tavus, kaviyar, av ödülü, kabuk). Ana ada ürünleri hayvanın gelirini izler (süt 254, tüy/hindi/kaymak/yak/fındık 1030-1385). Satır ≤ depo: en büyük satır 7 birim, en küçük ahır 12.
Sipariş / satış oranı: en düşük kademe 1,05/0,06 = 17,5x; takas = satış (0,06). Hiçbir teklifte ödül/değer < 1,05 (düşük gelir stres fixture'ında da). Ödül tavanı (6 dk) nadiren bağlar (%1-6 teklif, yalnızca düşük gelir fixture'ında).

| Bulgu | Kanıt | Karar |
|---|---|---|
| `fish_dispatch` büyük/standart parti, asgari getirinin çok üstünde ödüyordu (yazılı `reward` tabanı aşıyordu); diğer tüm para tesisleri tam tabanda (1,5/1,8/2,0x) | getiri/(kaçırılan+başlatma): Ç1-6 tüm evrelerde en çok 3,46 (büyük), 2,70 (standart); `PRODUCTION_MAX_RETURN` 2,0. Büyük parti, hayvan başına dakikada net 2338 (Ç1 tam) vs paketli süt 1131, yün 4583 | **Düzeltildi**: seçenek ödülleri 1940/6000 -> 1100/2400. Sonra getiri 1,50/1,80/2,00; hayvan başı net 1183 (süt ile 1131 aynı bantta). Sim'de fark yok (sim bu seçenekleri seçmiyor: üretim geliri iki koşuda da tam aynı); korunma testi: `goods.spec` "maximum return", audit bölüm H |
| Küçük gelir/erken evrede panodan gelen para, çiftlik gelirinin katlarıdır: ürün değeri TAM yükseltilmiş çiftliğe göre ölçülü, merkez getirisi evreden bağımsız sabit (~11-23K/dk, ilk merkezler) | Ç1 merkez net/dk: evre 0,15 gelir 467/dk -> %2300; evre 0,25 4,4K/dk -> %310-516; evre 0,4 17K/dk -> %80-134; evre 0,6 107K/dk -> %12-20; evre 1,0 310K/dk -> %5-9. Hardcore, tek çiftlik, ilk saat: gelir 638 -> 1875/sn (2,9x), siparişler ilk saat gelirinin %59,6'sı; keçi adası 44,8 dk (ideal persona, siparişsiz: 107 dk; `--no-orders` ilk saatte açılmadı). Merkez fiyatı geri ödeme: süt/yumurta/tüy 0,6-1,0 dk, hindi 2,4, peynir 2,7, nal 3,2 (para tesisi hedefi 25-40 dk) | **Uygulandı** (aşağıda "Sipariş bütçesi"): (b) seçildi, evreye bağlı pano bütçesi. Eski öneri: pano gelirini erken evrede bastırmak için ya (a) ürün merkezi ücretlerini ilk merkezlerde yükselt, ya (b) pano başına toplam ödeme bütçesi (gelir dakikası) ekle, ya (c) ürün değerini "kurulum evresi" geliriyle ölçekle. `rewardCapMinutes` düşürmek işe yaramıyor: sim 6 -> 3 -> 1,5 dk: ilk saat sipariş geliri 4,8M -> 3,9M -> 3,7M |
| Sipariş payı belgedeki ~%5 / ~%9'un üstüne çıkmış (büyüme 20 dk, başlangıç yetişkinleri, çok çiftlik) | `--days 7 --persona casual` %7,4 (748 teslim), `hardcore` %12,2 (2934 teslim); yalnız Ç1, ilk gün casual %14, hardcore ilk 3 saat %35,4 | Belge güncellendi; ayar önerisi yukarıdaki satırla aynı |
| `GOODS_CONTRACTS.tiers[].units` çoğu kademede etkisiz: `minHighUnits = 4` tüm kademelerde ve pahalı üründe 1..4 birim üretiyor (hızlı ≡ küçük; pahalı üründe toptan/tüccar toptan hızlıyla aynı adet, ama +%30/40 ödüyor) | Ç1 son: satır başı ortalama 2,62 birim; et (130K) için tüm kademelerde 1..4 | **Öneri**: kademe ödülünü adetle ilişkilendir (örn. `minHighUnits` kademeye göre) ya da pahalı üründe toptan kademelerini ele; ödül sözleşmesi testlerine dokunur, ayrı iş. Yorum düzeltildi |
| En büyük satır bazı ucuz ürünlerde tabandaki merkezle (hız ve yetişkin bonusu yok) tek pencerede üretilemiyor | 7 birimlik satır: yumurta 540 sn, bal/bıldırcın/lama/ipek/angora 480 sn, nal 440 sn, pencere 420 sn | Sorun değil (stok kalıcı, depo 12): en çok 2 pencere olması test edildi (`goods.spec` "karşılanabilir") |
| Talep, ürün sayısı azken yoğunlaşıyor: 12 slot 2 ürüne bölününce ürün başına ortalama 17 (en çok 31) birim/pencere, 5 üründe 8 (en çok 20) | Ç3-6 evre 0,6: pano değeri 20-23 dk gelir/pencere; üretim 15-30 birim/pencere | **Uygulandı**: pano boyutu `ceil(ürün x 2,5)`, en az 3, en çok 12 (aşağıda) |
| Tam yükseltilmiş çiftlikte üretim kapasitesi talebin 3-5 katı (talep 7-9, üretim 24-42 birim/pencere); fazlası yalnızca %6 satış ile çıkar | audit bölüm G | Beklenen (taşan fazlanın çıkışı); satış oranını yükseltme, sipariş en iyi kanal kalmalı |
| Toplam sipariş bonusu (eşya + ada + mevsim + yükseltme + ilerleme) sınırsız; `ECONOMY_LIMITS.maxRewardRatio` (3,2) yalnızca bonussuz ölçülüyor | Eşya yuvaları en çok +0,61, ada +0,1, ilerleme etkisi +0,25 (5 sv), kilometre taşı +0,08, mevsim +0,30 = ~+1,34 -> dev karma 2,0 x 2,34 = 4,7x değer | **Uygulandı**: toplam bonus `GOODS_CONTRACTS.maxBonus` = 0,6 ile sınırlı (aşağıda) |
| Merkez fiyatı / net getiri, tema 1 -> 6 boyunca 1-3 dk -> 130-700 dk (fiyat ada/tema çarpanlarıyla büyür, ürün değeri sabit) | audit bölüm F "geri ödeme"; Ç6 tavus/kabuk merkezi 92,5M, net ~130K/dk | Zorluk tasarımıyla uyumlu ("gelir ölçeği yoktur"); not olarak kaydedildi |

Düzeltme öncesi/sonrası (aynı koşullar, `audit-economy.py` bölüm H ve ayrı betik, tam yükseltilmiş Ç1): `fish_dispatch` büyük parti ödülü 7980 -> 5361 (getiri 2,98 -> 2,00), standart 2580 -> 2413 (1,93 -> 1,80);
tüm evrelerde en yüksek getiri büyük 3,46 -> 2,00, standart 2,70 -> 1,80. Diğer para tesisleri değişmedi (en çok 2,01-2,19: yuvarlama, tek evre).

## Sipariş bütçesi, pano boyutu, bonus tavanı, günlük ödül (5 Ekim 2026)

Yukarıdaki denetimin önerileri uygulandı. Tüm sayılar aynı koşullarda ölçüldü (`scripts/simulate-economy.py` aynı bayraklar, önce = ayarlar etkisiz yapılmış Config, sonra = bu kod; `scripts/audit-economy.py` tam yükseltilmiş fixture).

**1) Bonus tavanı.** `Contracts.totalBonus`: eşya + ada + yükseltme + kalıcı etki + kilometre taşı + mevsim toplamı `Config.GOODS_CONTRACTS.maxBonus` (0,6) ile sınırlıdır. En yüksek kademe 2,0 x (1 + 0,6) = 3,2 = `ECONOMY_LIMITS.maxRewardRatio`, yani bonuslar dahil de ödül/değer 3,2'yi aşamaz.
En kötü yığın (her yuvada en iyi `contractBonus` eşyası, her etki tam seviye, R30 kilometre taşları, ada yükseltmeleri, en iyi mevsim `orderBonus`) Config'ten hesaplanır: +1,52 (tavandan 2,5 kat); önce dev karmada 2,0 x 2,52 = 5,04x değer, şimdi en çok 3,2x.
Test: `contracts.spec` "bonus tavanı" (en kötü yığın, 81 pencere), `goods.spec` ayar tutarlılığı; audit `--check`: dev bonusla (+10) tüm çiftlik/evrelerde ödül/değer en çok 2,72 (o fixture'da erişilebilen kademe 1,7; sınır 3,2).

**2) Pano boyutu.** `Contracts.slotCount(n) = clamp(ceil(n x slotsPerGoods), minSlots, slots)` (6 / 6 / 12): 1 ürün 6, 2+ ürün 12 teklif. İlk sürüm 2,5 / 3 idi (1 -> 3, 2 -> 5, 3 -> 8, 4 -> 10); erken ürün merkezlerinde panoyu fazla daralttığı için tek başına keçi adasını 44,9 -> 54,1 dk'ya itiyordu. İkinci sürüm 4 / 4 (1 -> 4, 2 -> 8) `simulate-tiers.py --assert-monotonic` idle oyuncusunda Tema 2 tamamlama süresini Tema 1'e eşitledi (2,5 gün = 2,5 gün; aralığı etkileyen yalnız slot sayısıydı: yalnız bütçe/günlük ödül değişince 3,0 gün); 5 / 5 aynı hatayı verir, 6 / 6 eski 3,0 gün/1,20x'i geri getirir.
Teklifler yine pencere ve oyuncu için kesindir (slot tohumu yalnız pencere ve sıradır; ürün kümesi kayıttan). Tam yükseltilmiş 5 üründe talep değişmedi (audit G: ort. 6,7-8,7, en çok 13-20 birim/pencere).

**3) Erken evre dalgası: pano bütçesi.** Neden `rewardCapMinutes` bağlamadı: tavan TEK sipariş içindir (6 dk x referans gelir) ve ortalama sipariş zaten ~1 dk'dır; sorun siparişin büyüklüğü değil adedi (ilk saat 80 teslim), tavanı 1,5 dk'ya indirmek sim'de ilk saat sipariş gelirini yalnız 4,8M -> 3,7M indirmişti.
Çözüm `GOODS_CONTRACTS.windowBudget`: penceredeki tekliflerin ödül toplamı, referans gelirin `budgetMinutes(ref)` dakikasını aşamaz (slot sırasıyla, sığmayan teklif panoya girmez, ilk teklif her zaman kalır). Referans gelir `graceIncome` (900/sn) altındayken bütçe yoktur; üstünde dakika `lowIncome` (500/sn) ve altında 2,5, `highIncome` (5000/sn) ve üstünde 12, arası log ölçekte karesel artar.
Neden evreye bağlı: ürün değeri tam yükseltilmiş çiftliğe göre ölçülü olduğundan pano toplamı erken evrede 20-23 dk (Ç3-6, evre 0,6), tam yükseltilmişte 5-6 dk gelirdir; sabit bütçe ya erken evreyi bastırmaz ya geç oyunu keser. Tam yükseltilmiş fixture'da kırpılan pencere 0 (audit B/--check korur).

**Tempo / pay ödünleşimi (hardcore, tek çiftlik, `--session 0 --hours 4`, aynı bayraklar).** İki hedef (keçi adası <= ~55 dk ve ilk saat sipariş payı <= ~%35) bu mekanizmayla aynı anda sağlanamıyor: keçi adası ilk ~50 dk'daki toplam sipariş gelirine bağlı, pay ise aynı gelirin ilk saatteki oranı. Taranan parametre kümeleri:

| Küme (slot / bütçe) | Keçi adası | Süt fabrikası | İlk saat pay | 3. saat gelir |
|---|---|---|---|---|
| Önce (sınırsız) | 44,9 dk | 45,2 dk | %59,6 | 5618/sn |
| İlk sürüm: 2,5 / 3, bütçe 2,5-10 dk (sonra 12), grace yok | 74,1 | 79,3 | %24,6 | 5544 |
| Yalnız slot 2,5 / 3, bütçe yok | 54,1 | 59,4 | %54,0 | 5701 |
| Slot 2,5, ramp 4-12 dk (eğri 2) | 67,7 | 73,7 | %33,8 | 5544 |
| Slot 2,5, ramp 5-12 / 6-12 dk (eğri 2) | 66,2 / 64,6 | 70,0 / 66,2 | %38,5 / %41,7 | 5618 |
| Slot 4, grace < 800/sn (bütçe yok), sonra 2,5-12 | 55,2 | 59,4 | %45,9 | 5692 |
| Slot 4, grace < 800/sn, grace bütçesi 5 / 8 dk | 66,2 / 62,9 | 71,3 / 66,2 | %36,0 / %38,4 | 5544 / 5692 |
| Slot 4, grace < 850/sn, ramp 1,5 dk | 57,9 | 62,8 | %43,4 | 5839 |
| Slot 4 / 4, grace < 900/sn, ramp 2,5-12 (idle'da Tema 2 = Tema 1: reddedildi) | 55,2 | 59,4 | %45,9 | 5692 |
| **Son: slot 6 / 6, grace < 900/sn, ramp 2,5-12** | **55,0** | **59,4** | **%43,6** | 5544 |
| Slot 4, grace < 950/sn (sonra 2,5-12) | 45,5 | 52,6 | %52,4 | 5544 |

Seçim: koordinatörün öncelikli ölçütü (keçi adası <= ~55 dk) sağlanır; süt fabrikası +14,2 dk (hedef ~+10, 59,4 yerine <= ~55), ilk saat payı %43,6 (hedef <= ~%35; ilk sürümün %24,6'sı değil, eski %59,6'ya göre -13,7 puan). Geçiş eşiği 900-920 arası aynı sonucu verir; 950'de keçi adası 45,5 dk/süt 52,6 dk ama pay %52,4 (kayma, yalnız kurulum evresinin sonunda). Payı <= %35'e indirmek keçi adasını ~63-66 dk'ya iter (tabloda 5. ve 7. satırlar).

| Ölçüm (aynı koşul) | Önce | İlk sürüm | Son |
|---|---|---|---|
| Hardcore ilk saat sipariş payı | %59,6 ($4,8M / $8,1M) | %24,6 ($559K / $2,3M) | %43,6 ($1,9M) |
| Hardcore, keçi adası / süt fabrikası (kesintisiz) | 44,9 / 45,2 dk | 74,1 / 79,3 | 55,0 / 59,4 |
| Hardcore, 1. / 2. / 3. saat sonu gelir (sn) | 1875 / 5802 / 5618 | 858 / 2469 / 5544 | 1245 / 2829 / 5692 |
| Hardcore, 4 saatlik sipariş payı | %31,1 | %30,9 | %30,4 |
| Casual 1. gün / 7 gün payı | %14,0 / %7,4 | %8,2 / %4,3 | %11,4 / %5,0 |
| Hardcore 1. gün / 7 gün payı | %15,7 / %12,2 | %10,8 / %8,0 | %15,1 / %9,0 |
| Hardcore 1. gün yükseltme sayısı; oturumlu keçi adası | 27; 44,9 dk | 21; 360 dk (2. oturum) | 23; 55,2 dk |
| Tam yükseltilmiş fixture pano toplamı (dk gelir/pencere) | 5,1-6,4 | 5,1-6,3 | 5,1-6,3 (kırpma yok, teklif ~12/12) |

Geç oyun (7 gün sim) payları belgedeki ~%5 (casual) / ~%9 (hardcore) bandına geri oturdu (eski %7,4 / %12,2 bandın üstündeydi); tam yükseltilmiş fixture'da bütçe bağlamaz.

**4) Günlük ödül.** `DAILY_MINUTES` 2 -> 2,5, 7. gün çarpanı 4 -> 5 (`{1, 1.2, 1.5, 2, 2.5, 3, 5}`); hâlâ `referenceIncome` ile ölçeklenir ve en az `DAILY_MIN_REWARD`. Geç oyunda son gün 8 -> 12,5 dk gelir; 7 günlük seri 28,4 -> 40,5 dk (+%43), yani bir günün gelirinin %1,97 -> %2,81'i (test tavanı %3).
Sim (7 gün, günlük ödül payı): casual %0,4 ($4,2M) -> %0,5 ($5,6M), hardcore %0,2 ($5,8M) -> %0,3 ($7,8M). Rebirth temposuna etkisi ihmal edilebilir: haftada +12,1 gelir dakikası = haftalık gelirin %0,12'si (sürekli gelir varsayımıyla); ilk gün ödülü taban 250 kalır (ilk üç hayvan kuralı bozulmaz). Test: `rewards.spec` "günlük ödül tavanı" (azalmayan çarpanlar, son gün 10-15 dk, hafta <= %3, referans gelirle ölçek); audit "günlük ödül" satırı `--check`.

**Kalan riskler.** Studio'da ve gerçek oyuncuyla denenmedi. (1) İlk saat payı %43,6: hedef %35'in üstünde; erken sipariş hızlandırıcısı bilinçli korundu (tempo hedefi için), payı düşürmek keçi adasını geciktirir (tablo). (2) Süt fabrikası kesintisiz oyunda +14 dk. (3) Pano bütçesi referans gelire bağlıdır, gelir 1,25 basamağını aşınca bir teklif anahtarı değişebilir ("Teklifler yenilendi"; ödül tavanıyla aynı kırılganlık); `graceIncome` sınırında (900/sn) pano aniden bütçeli hale gelir (teklif sayısı ve toplam sıçrar). (4) Orta evrede pahalı ana ürünler (hindi, kaymak, yak, fındık) bütçeye sığmadığı için az sipariş görür. (5) Eşya/rebirth bonusları 0,6 toplamında tavanlanır; arayüz metinleri ham toplamı gösterir. (6) 7 günlük sim oyuncuları 150 yükseltmenin ~44'üne varır; geç oyun iddiası audit fixture'ına dayanır.

**Çiftlik tamamlama monotonluğu (`simulate-tiers.py --personas ideal,casual,idle --assert-monotonic`).** Slot 4 / 4 ile idle Tema 1 = 2,5 gün, Tema 2 = 2,5 gün (önceki 3,0 gün, 1,20x); ayrıştırma: sipariş eski + günlük yeni 3,0 gün; yalnız günlük eski + yeni siparişler 2,5 gün; yalnız slot yeni 2,5 gün; yalnız bütçe yeni 3,0 gün: sebep günlük ödül ya da bütçe değil, erken panonun daralmasıydı. Slot 6 / 6 ile üç oyuncu tipi de geçer (ideal 4,4 sa -> 7,6 sa, casual 24,1 -> 39,8 sa, idle 2,5 -> 3,0 gün; Tema 2 hepsinde Tema 1'den uzun).
