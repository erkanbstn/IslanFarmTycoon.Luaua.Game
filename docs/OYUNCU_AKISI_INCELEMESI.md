# Oyuncu akışı ve oyun dengesi incelemesi

4 Ekim güncellemesi: Bu belge başlangıç incelemesidir. Altın, rebirth, kalıcı satın alma ve yeni simülasyonlar artık uygulanmıştır; güncel değişiklikler, ölçümler ve kalan yayın kontrolleri [REBIRTH_GELISTIRME_RAPORU.md](REBIRTH_GELISTIRME_RAPORU.md) içindedir. Aşağıdaki başlangıç bulguları kanıt geçmişi olarak korunmuştur.

Bu inceleme 3 Ekim 2026 tarihinde, `main` dalındaki `dace9fd` sürümünde yapıldı. Amaç, oyuncunun ilk hayvandan altı çiftliklik ilerlemeye kadar ne yaptığı, satın almaların ne kadar anlamlı olduğu ve planlanan rebirth için mevcut yapının uygunluğunu değerlendirmektir. Oyun fiyatları, modeller ve davranışları bu incelemede değiştirilmedi.

Ana değerlendirme: başlangıçta anlaşılır bir tycoon döngüsü ve güçlü içerik çeşitliliği var. İlerleyen çiftliklerde zorluk ağırlıkla maliyet ve süre artışıyla geliyor; aynı üretim eylemlerinin uzun süre tekrar edilmesi riski bulunuyor. Bu, oyuncuların sıkıldığına ilişkin ölçülmüş bir sonuç değildir. Altın ve rebirth planları kalıcı ilerleme için bir temel sunuyor; fakat mevcut simülasyon planlanan rebirth koşulunu ve ekipmanlı ekonomiyi birlikte ölçmüyor. Gerçek oyuncu oturumları da ölçülmeden doğru toplam süreyi belirleyemeyiz.

## İncelemenin dayanakları

- Ekonomi, arayüz ve model alanlarını üç alt ajan bağımsız inceledi; sonuçlar gerçek Config ve oyuncuya görünen eylemlerle karşılaştırıldı.
- Son toplu doğrulamadaki güncel ideal, casual ve idle simülasyon sonuçları kullanıldı. İlk 5, 15 ve 30 dakika ayrıca kısa simülasyonlarla ölçüldü.
- Eşya etkileri ve güncel fiyatlar gerçek Config ve FarmMath ile Luau CLI'da doğrulandı. Ölçüm dosyaları `.test-build/player-experience-items.luau` ve `.log` içindedir.
- Açık Studio Edit sahnesi kuşbakışı ve ana adaya yakın açıdan görüntülendi. Ada, köprü, meydan ve mevcut yerleşim görüldü. Oyun başlatılmadı; ilk oyuncu HUD'ı, hareket, tamamlanmış temalar ve seviye animasyonları oynanarak değerlendirilmedi.
- Canlı Analytics verisi alınmadı. Aşağıdaki oyuncu hissiyatı sonuçları, ayrıca belirtilmedikçe tasarım değerlendirmesi ve doğrulanacak hipotezdir.
- [Altın ve Robux planı](ROBUX_VE_ALTIN_PLANI.md) ile [rebirth planı](REBIRTH_PLANI.md) sonradan tamamen okundu; ekonomi, oyuncu arayüzü ve kayıt alanları üç alt ajanla tekrar karşılaştırıldı. İlk değerlendirmede bu belgeler atlanmıştı. Bu sürüm, tamamlanma tanımı ve süre yorumunu düzeltir; mevcut planlardaki kararları değiştirmez.

## İlk oturumdaki oyuncu yolculuğu

Oyuncu hayvansız başlar; ilk ana hayvanı alacak parası vardır. Görev şeridi Pazar'a, ardından para toplama platformuna ve ilk yükseltmeye yönlendirir. İlk üç hayvan yetişkin gelir; böylece başlangıçta büyüme beklemeden gelir başlar. Menüler kademeli açılır, bütün sistemler aynı anda gösterilmez. Bunlar korunması gereken güçlü tercihlerdir.

Kısa ideal simülasyon ölçümü; tek çiftlik, 120 saniyede bir toplama, kusursuz yatırım kararları, nötr hava, eşya yok. Para üretimi, sipariş ve ödül seçenekleri bu kısa koşularda kapalıdır. Eylem sayısı simülasyon işlemleridir, gerçek oyuncu tıklaması değildir.

| Geçen süre | Hayvan | Alınmış yol haritası yükseltmesi | Gelir saniye başına | Simülasyon eylemi |
|---|---:|---:|---:|---:|
| 5 dakika | 10 | 1 | 13 | 13 |
| 15 dakika | 22 | 4 | 53,64 | 34 |
| 30 dakika | 46 | 10 | 209,904 | 76 |

Bu politikada otlak yaklaşık 3,2, silo 8,2, Ahır Sv.2 9,3 ve ilk küçük ada 12,4 dakikada açılır. İlk tavuk 12,7, balık kafesi 18,8, süt merkezi 25,8 dakikada gelir. Gerçek oyuncunun yürümesi, seçenekleri okuması, yanlış yatırımları ve ödül toplaması bu süreleri değiştirir.

**Değerlendirme:** İlk yarım saatte içerik değişimi var; yalnız para sayacına bakılan bir başlangıç tasarlanmamış. Ancak 10 dakikalık oturum yapan idle sim oyuncusu ilk küçük adayı ikinci girişte, yaklaşık 12 saat sonra görüyor. İlk oturumun tatmin edici bitişi bu oyuncuda ada açılışı olamaz; ilk yapı, sürü büyümesi veya ilk tamamlanan iş ayrı bir başarı anı taşımalı.

Başlangıçtan sonra alınan hayvanın temel büyümesi 800 + 1.600 saniye, yani 40 dakikadır. Silo bunu hızlandırır; kısa simde ilk sonradan yetişen hayvan yaklaşık 24,9 dakikada oluşur. Oyuncunun bu bekleyişin nedenini ve kalan süreyi anlayıp anlamadığı kontrol edilmelidir. İlk üç yetişkinin ardından büyüme kuralının görünür biçimde öğretilmemesi, aynı satın alımın daha az gelir getirdiği hissini yaratabilir.

Kaynaklar: `Config/Core`, `Config/Islands`, `Modules/OnboardingSteps`, `Ui/Hud/GoalCard`, `scripts/simulate-economy.py`.

## Altı çiftliğin mevcut temposu

Aşağıdaki süreler son `optimization-final.log` çıktısından gelir. Her satırın süresi ilgili çiftliği satın aldıktan sonra hesaplanır. İdeal politika sürekli çevrimiçidir; önceki çiftliklerin geliri de hesaba katılır. Simülasyon temaya uygun tüm `Config.UPGRADES` kayıtlarını, seviye zincirleri dahil sayar. Bu bitiş ölçüsü, planın seviye zincirlerini hariç tutan rebirth koşuluyla aynı değildir.

| Çiftlik | İlk küçük ada | Orta ada | Geç ada | Simde tüm yükseltmeler (seviye zincirleri dahil) |
|---|---:|---:|---:|---:|
| 1 | 12 dakika | 45 dakika | 114 dakika | 4,6 saat |
| 2 | 19 dakika | 54 dakika | 145 dakika | 7,0 saat |
| 3 | 25 dakika | 101 dakika | 4,0 saat | 10,5 saat |
| 4 | 38 dakika | 165 dakika | 5,6 saat | 15,3 saat |
| 5 | 48 dakika | 4,0 saat | 9,5 saat | 22,6 saat |
| 6 | 79 dakika | 6,6 saat | 16,6 saat | 33,7 saat |

**Tasarım hipotezi:** Altıncı çiftlikte yeni küçük adayı görmek için 79 dakika beklemek, daha tecrübeli oyuncuda yeniden başlangıç hissini yavaşlatabilir. Orta ve geç ada arasındaki yaklaşık 10 saatlik aralık da ayrı hedefler gerektirir. Bu aralık tamamen içeriksiz değildir: hayvanlar, yapılar, soy seviyeleri, üretim ve siparişler vardır. Sorun, bu faaliyetlerin oyuncuya yeni bir deneyim mi yoksa aynı işin devamı mı sunduğudur.

| Simülasyon politikası | Altı çiftliğin sim bitişine kadar yaklaşık takvim süresi | Yaklaşık aktif süre | Varsayım |
|---|---:|---:|---|
| İdeal | 4 gün | 96 saat | Sürekli çevrimiçi |
| Casual | 18,3 gün | 18,3 saat | Günde üç kez 20 dakika |
| Idle | 36,5 gün | 12,2–12,3 saat | Günde iki kez 10 dakika |

Toplamlar yuvarlanmış tablodan çıkarımdır. Bunlar canlı oyuncu ortalamaları veya hedeflenen oturum düzeni değildir. Aktif süre ile takvim süresi farklıdır: daha uzun takvim süresi, her zaman daha çok oynanış anlamına gelmez.

Eski tasarım belgelerindeki yaklaşık 16/29 gün ifadeleri güncel simülasyonla aynı değildir. Mevcut değerlendirme güncel ölçümü esas alır; eski belge bu incelemede düzenlenmedi.

## Zorluk ve fiyatların oyuncuya etkisi

Fiyat çarpanları 1 / 5,9 / 16,8 / 34,8 / 62,7 / 125. Hayvan gelirleri çiftlik kademesiyle aynı oranda yükselmez. İlk küçük adanın açılışında ikinci çiftlikten itibaren ayrıca 32 kat prim vardır. Zorluğun temel kaynağı artan ekonomik maliyettir; yeni türü yönetmek için daha zor bir kontrol veya farklı bir beceri zorunlu değildir.

Gerçek fiyat hesabından alınan örnekler; eşya indirimi yok, ada tutarlarında ürün maliyeti ayrıca vardır:

| Çiftlik | Ana çiftlik satın alma bedeli | İlk küçük ada bedeli |
|---|---:|---:|
| 1 | Ücretsiz | 3.800 |
| 2 | 590.000 | 717.440 |
| 3 | 2.500.000 | 2.042.880 |
| 4 | 9.500.000 | 4.231.680 |
| 5 | 37.000.000 | 7.624.320 |
| 6 | 100.000.000 | 15.200.000 |

Taban dosyadaki fiyat, ekrana çıkan fiyat değildir; maliyet eğrisi ve kademe hesabı uygulanır. Örneğin ikinci çiftlikte ilk küçük ada ana çiftliğin kendisinden pahalıdır. Bu bilinçli ritim ayarıdır, tek başına hata değildir. Oyuncuya yeni çiftliğin ne açacağı ve sonraki hedefin ne kadar uzak olduğu anlaşılır gösterilmelidir.

**Öneri:** Fiyatları topluca indirmek yerine pahalı hedefleri işlevine göre incele. Yeni sistem veya ada açan alımlar, salt küçük yüzde bonuslarından ayrı değerlendirilmelidir. Oyuncu daha zor çiftlikte üretim planlama, hangi ürünü saklama/satma, hangi ekipmanı takma gibi kararlarla ilerleyebilmeli; yalnız aynı parayı daha uzun süre biriktirmemeli.

Ürün gereksinimleri ikinci çiftlikte başlar. Bu, önceki adalara ekonomik işlev verir ve ilk çiftliğin öğretici kalmasını sağlar. Fakat ilk çiftlikte ürün üretimi/sipariş öğretimi atlanırsa ikinci çiftliğin ürün şartı sürpriz olabilir. İlk ürünün üretilmesi ve stoktan harcanması ayrıca öğretilmelidir.

Kaynaklar: `Config/Difficulty`, `Config/init`, `FarmMath/Pricing`, `Config/Upgrades`, `Config/Species`.

## Eşyaların fiyatı ve anlamlı seçimler

38 eşya ve beş takma yuvası bulunur. Muska yuvasında depo, büyüme, gelir, ürün ve sipariş arasında tercih yapılması anlamlıdır. Eşya model önizlemeleri satın alınan şeyin görünümünü anlatır. Ancak bazı ucuz faydalar çok küçük, bazı pahalı faydalar ise bütün dengeyi değiştirecek kadar büyüktür.

Gerçek FarmMath hesabı; başka takılı gelir eşyası olmayan aynı hayvan için:

| Eşya | Fiyat | Gelir etkisi | Oyuncu açısından değerlendirme |
|---|---:|---:|---|
| Bereket Muskası | 150.000 | +%3 | Küçük artış; geri dönüş açıklaması gerekli |
| Büyük Bereket Muskası | 900.000 | +%6 | Önceki muskaya göre yalnız üç puan fazladır |
| Altın Bereket Muskası | 5.000.000 | +%10 | Gelir kadar diğer etkileri ve görünümü de değer taşımalı |
| Melek Kanatları | 250.000 | +%5 | Gelir için fiyat açısından güçlü seçenek |
| Altın Kanatlar | 1.000.000 | +%6 | Önceki kanada göre bir puan + çevrimdışı bonus; doğrudan gelir farkı küçük |
| Altın Taç | 30.000.000 | +%100 | Diğer bonus yokken hayvan gelirini iki katına çıkarır |

Taç hesap düzeyindeki envanterden tüm çiftliklere uygulanır. Mevcut süre simülasyonu eşya satın almaz veya takmaz; bu büyük etki simülasyonda bulunmaz. İndirim çekiçleri de yoktur. Dolayısıyla simülasyondaki geç oyun temposu, oyuncunun gerçek ekipmanlı temposunu temsil etmez.

Sırt Çantası 12.000 karşılığında başlangıç para deposunu 50.000'den 52.500'e çıkarır. Sık para toplayan erken oyuncuda faydası görünmeyebilir. Çiftçi Şapkası 10.000 karşılığında hayvan satışına +%1 verir; hayvan satmayan oyuncuda ekonomik faydası oluşmaz. Görünüş için alınabilir, fakat ekonomi eşyası olarak sunuluyorsa değerinin anlaşılması gerekir.

Bakır Çekiç 150.000 karşılığında yükseltmelere %5 indirim verir. Diğer etkileri ve değişen gelirleri dışarıda bırakan basit hesapta, yalnız bu indirimle bedelini karşılamak için sonraki indirime uygun harcamanın 3 milyon olması gerekir. Bu örnek tüm eşyanın kesin geri ödeme süresi değildir; indirim eşyasının gelecekteki planla değer kazandığını gösterir.

**Öneri:** Eşyalarda yükseltme sıralamasını sadece fiyat üzerinden kurma. Aynı yuvadaki önceki eşyaya göre ek faydayı, kullanım tarzını ve görsel değeri göster. Altın/Robux planı Altın Taç'ı kalıcı ekipmana taşımayı öneriyor; nakit yolunun kaldırılması aynı belgenin açık kararlarında da bulunduğundan kesinleşmiş uygulama sayılmamalı. Ekonomi simülasyonuna gerçek takma ve satın alma politikası girmeden taç nerf'i veya yeni fiyat önerilmemeli.

Satın alma sonrası mağaza kartı “Sahipsin” der; takmak için ayrı Envanter gerekir. İlk eşyada satın almakla etkinleştirmenin aynı olmadığı açık öğretilmeli veya doğrudan “Tak” geçişi sunulmalı.

Kaynaklar: `Config/Items`, `Modules/Inventory`, `FarmMath/Core`, `FarmMath/Income`, `Ui/Hud/ItemShopWindow`.

## Adaların işlevi ve tekrar riski

Her çiftlik bir ana hayvan ve üç uzman adadan oluşur; ana/uzman adalarda 24 farklı hayvan vardır. Deniz dalı ayrıca tüm çiftliklerde ortaktır. İçerik kimlikleri ve görünüm değişimi koleksiyon motivasyonu sağlar.

| Çiftlik | Ana hayvan | Erken ada | Orta ada | Geç ada |
|---|---|---|---|---|
| Klasik Çayır | İnek | Tavuk ve tesis hızı | At ve sipariş bonusu | Keçi ve çevrimdışı gelir |
| Göl ve Yün | Ördek | Tavşan ve depo | Koyun ve ürün verimi | Domuz ve geliştirme indirimi |
| Güneşli Tarla | Hindi | Arı ve tesis hızı | Deve ve çevrimdışı gelir | Tavus ve hayvan satış bonusu |
| Gül Vadisi | Manda | Bıldırcın ve depo | Güvercin ve sipariş bonusu | Salyangoz ve ürün verimi |
| Dağ ve Orman | Yak | Lama ve ürün verimi | Geyik ve geliştirme indirimi | Şahin ve sipariş bonusu |
| Meyve Bahçesi | Sincap | İpek böceği ve tesis hızı | Papağan ve hayvan satış bonusu | Kaplumbağa ve çevrimdışı gelir |

Ortak eylem: hayvanı al/yetiştir → para fabrikası veya ürün merkezi kur → yetişkinleri partiye gönder → bekle → teslim al → yeniden yatırım yap. Görevdeki hayvan normal gelir üretmez; kısa/uzun parti ve para/ürün seçimi gerçek kararlar sunar. Tavuk kuluçkasında civcivi tutma/satma ayrıca farklı bir eylemdir.

At parkuru, papağan gösterisi ve şahin avı isimleri ayrı oynanabilir minigame oldukları anlamına gelmez; kaynakta aynı genel üretim sistemi kullanılır. Atın parkur animasyonu oyuncunun kendisinin yarışması değildir. Çeşitlilik güçlü biçimde içerik ve görsel düzeydedir; etkileşim çeşitliliği daha sınırlıdır.

**Öneri:** Her çiftliğe büyük bir yeni minigame yapmak gerekmiyor. Bir sonraki çiftlikte küçük fakat belirgin bir yönetim farkı, kısa ilk ziyaret görevi veya farklı üretim tercihi olabilir. Önce iki çiftlikte denenmeli; 24 türe ayrı sistem eklemek bakım ve öğretim yükünü artırır. Mevcut menü kısayolları korunarak ilk kullanım dünyada tanıtılabilir.

## Tycoon hissiyatı ve modeller

Edit görüntüsünde merkezi meydan, adaları bağlayan köprüler, ahır ve tarım yapıları birlikte okunabilen bir dünya kuruyor. Yakın açıdan basit ve tutarlı geometrik bir stil görülüyor. Bu, tamamlanmış bütün modellerin sanat kalitesi onayı değildir.

Kaynakta bina seviyeleri 1–5 için ayrı modeller, bölge seviyeleri için bayrak/süs setleri ve geliştirmeyle beliren yapılar var. Satın alma dünyayı değiştirebiliyor; yalnız sayısal ilerleme yok. Ancak bu farkların normal oyuncu kamerasında yeterince büyük ve anlaşılır olup olmadığı görülmedi. Edit sahnesindeki boş alanlar, çalışma anında satın alınacak içeriğin boş olduğu kanıtı değildir.

Tycoon açısından güçlü zincir: parayı topla → yeni yapı kur → ada/sürü büyüsün → daha çok üret → daha büyük hedef gör. Riskli taraf: yatırım ve üretimin büyük kısmı menüden yönetilebildiği için dünya bir süre sonra yönetim panelinin arka planı olabilir. Bu mevcut kolaylığın kaldırılması gerektiği anlamına gelmez; ilk keşif ve önemli ödül anları dünyaya bağlanmalı.

Kaynakta genel yapı ve seviye alımı kutlanır; `Celebration` ada açılışını dışarıda bırakır ve ilk hayvanı izlemez. Başka dünya efektlerinin toplam karşılığı oynanmadı. En önemli büyüme anlarının küçük alımlardan daha güçlü hissetmesi test edilmeli: ilk hayvan, ilk üretim teslimi, ilk ada ve ilk yeni çiftlik.

Yol Haritası ve Yükseltmeler ekranları kısmen aynı satın almaları sunar. Yol Haritası bir yerde en kârlı yatırım seçimi olarak tanıtılır, fakat önerilen hedef çoğunlukla en ucuz alınabilir yükseltmedir. Bu, oyuncuya yatırım nedenini anlatmaz. Hedefte fiyatın yanında “şu hayvanı açar”, “şu üretim yolunu açar” veya “gelir şu kadar artar” sonucu gösterilmesi daha anlaşılır olacaktır.

Yeni çiftlik kartları fiyat ve zorluğu anlatır; yeni hayvanları ve oynanış farkını yeterince öne çıkarmaz. Tema değişimi “başka bir pahalı çiftlik” olarak okunabilir. Bu bir oyuncu testi hipotezidir. Modellerin koleksiyon ve prestij yönü kartlarda ve kilometre taşlarında daha görünür yapılabilir.

Yeni ana çiftlik, oyuncunun kişisel haritasına ikinci bir ana ada eklemez. Mevcut fiziksel alan seçilen temaya dönüşür; eski hesap çiftliği park edilir ve gelir üretir. Edit görüntüsündeki altı ana ada, bir oyuncunun satın aldığı altı çiftliğin birlikte gösterimi değildir; sunucunun oyuncu alanlarıdır. Ekonomik portföy büyürken ekranda önceki çiftliğin kaybolması “imparatorluğum genişliyor” hissini zayıflatabilir; bu tasarım hipotezidir. Park edilmiş çiftliklerin model önizlemesi, ilerleme özeti ve katkısı açık gösterilerek sahiplik hissi test edilebilir; sırf bunun için bütün haritayı yeniden kurmak önerilmiyor.

## Mevcut rebirth kararı ve simülasyon farkı

`REBIRTH_PLANI` bölüm 2'de kabul edilmiş koşul zaten var: altı çiftliğin satın alınması ve temel yükseltmelerinin tamamlanması; ırk/seviye zincirleri hariç. Tüm eşya koleksiyonu şart değil. Önceki rapordaki “full tanımı yok” yorumu ve seviye zincirlerini ekleme önerisi kaldırıldı. Rebirth henüz uygulanmamış olsa da ürün kararı mevcut.

Belge bu koşulu simdeki “TÜM YÜKSELTMELER” ile eşit sayıyor; kaynak kod bunu doğrulamıyor. `simulate-economy.py` tamamlanma kontrolünde temaya uygun yükseltmeleri sayıyor, `leveled` olanları dışlamıyor. Bu nedenle 4 / 18,3 / 36,5 günlük sonuçlar planlanan ilk rebirth süresi değildir. Tamamlanma koşulunu düzeltmek tek başına yeterli olmaz: ekipman, altın, kalıcı haklar ve sonraki tur etkileri de modellenmeli.

Planların birlikte okunduğunda tarif ettiği yapı: nakit ve tur ilerlemesi sıfırlanır; altın, altın/Robux ile alınan kalıcı ekipman ve kolaylıklar, görünümler, rebirth seçimleri ve ayarlar korunur. Tur boyunca 2x ayrı ve geçicidir. Sayısal etkiler, fiyatlar, tavan ve kilometre taşı ödülleri taslaktır. İlk tur için doğru süre bu yapıyı ölçmeden belirlenemez.

## Altın ve Robux planıyla birleşen ekonomi

**Planın çözdüğü tasarım ihtiyacı:** ada/çiftlik bitirmek yalnız sonraki nakit hedefini değil, hesapta kalan bir ödülü de verir. Kalıcı güçlü eşyaların altınla da alınabilmesi ücretsiz oyuncuya ilerleme yolu sunar. Rebirth seçimi, ekipman ve görünüm aynı hesap ilerlemesine bağlanabilir. Bunlar henüz kodda uygulanmış çözümler değildir; erken öğretim, ada kutlaması ve geç çiftliklerin benzer eylemleri ayrıca iyileştirilmelidir.

### Ücretsiz altın ve harcama seçimi

Taslakta ada başına 20, çiftlik başına 50 altın var. Ana ada dahil dört ada sayılırsa `6 × (4 × 20 + 50) = 780` altın/tur; yalnız üç uzman ada sayılırsa 660 olur. “Ada tamamlandı” koşulunda seviye zincirlerinin dahil olup olmadığı da açık yazılmalı; aksi halde rebirth hazırken altın ödülleri henüz hazır olmayabilir.

300–1.500 altınlık kalıcı eşya taslağında 1.500'lük eşya, hiç altın harcanmadan iki tur gerektirir. İlk tur kazançlarını nakde/bekleme atlamaya harcayan oyuncu kalıcı ekipmanı daha geç alır. Bu anlamlı bir seçim olabilir; fakat ücretsiz yolu bilinmeden ilk görülen mağaza yalnız ücretliymiş gibi algılanabilir. İlk altın ödülüne ulaşılmadan kazanım yolu gösterilmeli. Mevcut Altın Hayvan olayı yeni altın para birimi değil, nakit verir; isim ve simgeyle bu fark anlaşılmalı.

Tur başına 600 altın nakde çevirme sınırı, 780 ödülden en az 180'ini diğer kullanım için bırakır; başka altın harcamaları yokken birikim sürer. Taslak R3 +%10 ile ödül 858, R10 toplam +%20 ile 936 olur. Bu oranlar mevcut içerikte ölçülmüş veya onaylanmış denge değerleri değildir.

### Altın sabit hesap süresi değildir

1 altın = en yüksek gelirli tek çiftliğin 30 saniyelik nakdi öneriliyor. Bu, altı çiftliğin toplam gelirinin 30 saniyesi değildir. Aşağıdaki hesaplar eşit gelirli altı çiftlik ve değişmeyen gelir varsayımıyla matematiksel örnektir; tam oyun simülasyonu değildir:

| 600 altının nakit karşılığı | Gerçek toplam gelire göre zaman eşdeğeri |
|---|---:|
| Tek çiftliğin referans geliri | 300 dakika |
| Altı çiftlik tam gelirle otomatik topluyor | 50 dakika |
| Etkin çiftlik tam, beş park edilmiş çiftlik %50 gelirle | 85,7 dakika |
| Aynı iki hesapta referansa girmeyen tur 2x de etkin | 25 / 42,9 dakika |

Dolayısıyla “zaman para birimi” açıklaması tek bir sabit bekleme değeri vaat etmemeli. Nakde çevirme ile işi hemen bitirme iki ayrı faydadır. Çevirme önizlemesi açık tutar göstermeli. Mevcut `getReferenceIncome` yardımcı işlevi var; fakat canlı etkin gelir, hava ve hayvan durumundan etkileniyor. Plandaki geçici etkileri dışlayan kalıcı referans için hesap ve önizleme kuralları ayrıca uygulanmalı. Günlük/mevsim/sipariş ödüllerinin aynı yeni politikaya geçip geçmeyeceği de belirlenmeli.

### Üst üste gelen hızlandırıcılar

Taslak ekipman `2,16 × rebirth 1,40 × tur 2 = 6,048` gelir çarpanı oluşturur. Kalıcı tavan 3 seçilirse tur ürününden sonra en çok 6 olur. Geri Dönüş'ün inek için x3 etkisi de çarpılırsa ilk çiftliğin ana hayvanında geçici x18 mümkün olabilir; bu bütün hesabın x18 olduğu anlamına gelmez. R5'te ek tılsım yuvası önerisi mevcut 2,16 ekipman üst hesabını da değiştirebilir.

“4 gün / 6 = 16 saat” yalnız aritmetiktir, doğrulanmış en hızlı tur süresi değildir. Ürün şartları, büyüme, indirimler, kapasite ve satın alma sırası doğrusal hızlanmaz. Kalıcı ekipmanla yeni turda alt kademe eşya seçimlerinin ne kadar anlamlı kaldığı da denenmeli.

Üretim nakit ödülü halihazırda göreve gönderilen hayvanların vazgeçilen gelirinden türetiliyor; üzerine gelir çarpanını tekrar uygulamak aynı artışı iki kez sayabilir. Ürün partisinde ise miktar tavanı 6'dır. Varsayımsal x18 gelir stresinde ürün miktarı tavana takılarak ürün işi nakit gelirine göre cazibesini kaybedebilir. Basitleştirilmiş nötr örnekte ürün değeri 2,3 katsayıyla hesaplandığında gerekli miktar 8'e çıkarken tavan 6 kalır; toplam değer vazgeçilen gelirin yaklaşık 1,07 katında kalır, 1,4 hedefini karşılamaz. Bu gerçek oyuncuda kanıtlanmış kayıp değildir; yeni çarpanlarla gerçek tarifler üzerinden regresyon testi gerektiren koşullu risktir. Hesap çıktısı: `.test-build/audit-gold-rebirth-stress.json`.

## Plan tutarlılığı ve satın alınan haklar

Aşağıdaki noktalar uygulamadan önce tek kurala indirilmeli; mevcut belgeler bu incelemede değiştirilmedi:

| Nokta | Belgelerdeki fark / oyuncuya etkisi |
|---|---|
| Kalıcılık | Robux tablosu satın alınanların kaldığını söylüyor; tur 2x ve hızlı bitir kalıcı değil. Ürün kartları “Bu tur” / “Kalıcı” ayrımını satın almadan önce göstermeli. |
| Ücretsiz erişim | Genel ilke hiçbir şeyin yalnız Robux'a kilitli olmadığını söylüyor; görünüm bölümünde altınla alınan alt küme isteğe bağlı. İlkenin kapsamı güç eşyaları mı bütün ürünler mi açık olmalı. |
| Taç ve sırt/şapka | “Tüm şapka/sırt nakitle ve sıfırlanır” ifadesinin Taç/Kanat kalıcı istisnaları var. Taç nakit yolu hem kaldırılacak diye yazılmış hem açık karar olarak duruyor. |
| Gelir ve tavan | Rebirth açıklamasında ayrı çarpan, etki tablosunda `incomeBonus` toplamı yazıyor. Kalıcı tavan mı geçici bonusların da tavanı mı olduğu bölümler arasında değişiyor; sert sınır ve azalan getiri farklı davranışlar. |
| Sıfırlama özeti | Eski rebirth pencere metni altın ve kalıcı ekipmanı anmıyor; envanteri tamamen sıfırlayan tablo yeni kalıcılık kuralıyla çelişiyor. Onay özeti oyuncunun gerçek kayıplarını göstermeli. |
| Gerçek zaman | Günlük seri için kalır/sıfırlanır seçenekleri birlikte duruyor. Geri Dönüş çevrimdışıyken de tükeniyor; bitiş saati gösterilmeli. Çiftlik 2'ye geçişin etkisini kesin bitirmesi mi yalnız kapsam dışında bırakması mı olduğu netleşmeli. |
| Referans ve sim | Eski `mainFarmSummaries` anlatımı `parkedIncomeBest` uygulamasıyla güncellenmemiş; “sim yalnız etkin çiftliği modeller” ifadesi mevcut çevrimdışı tüm çiftlik hesabıyla uyuşmuyor. |

**Hak kaybı ve tekrar ödül riskleri:** Plan, kayıt sürümü artınca eski kaydı göç olmadan temizlemeyi de tarif ediyor. Kalıcı altın/Robux hakları satışa açıldıktan sonra bu yaklaşım satın alınan hakları ve makbuzları silebilir. Geliştirme ortamının temiz kaydıyla oyuncunun isteğe bağlı rebirth'i ve yayınlanmış hesabın sürüm geçişi ayrı işlemler olmalı.

Rebirth sıfırlaması yalnız para/çiftlik listesinden oluşmamalı: bekleyen para transferleri, makbuzlar, aynı gün ödül alma işaretleri ve altın kazanım kayıtları da korunmalı veya açıkça sonuçlandırılmalı. Eski turda alınan Robux ürünü için makbuz yeni turda geç gelirse hangi hakkın verileceği tanımlanmalı. Ücret tahsil edilip hak kaybolmamalı.

`lifetimeEarned` yalnız telemetri değildir; mevcut para kazanma başarımlarını da besler. Bu toplam korunup başarım alma işaretleri sıfırlanırsa oyuncu eski kazancıyla yeni turun ödüllerini hemen tekrar alabilir. Günlük seri ile bugün ödül alındı işareti de farklıdır; ikisini birlikte temizlemek aynı gün tekrar ödül doğurabilir. Bunlar henüz uygulanmamış rebirth'in mevcut kodla etkileşim riskleridir.

Ada/çiftlik altını her yükleme veya yeniden tema seçmede tekrar verilmemeli; tur ve hedef kimliğiyle kazanım kaydı kalıcı tutulmalı. Günlük altın kotası rebirth ile yenilenmemeli; tur kotası ayrı olmalı. Çift tıklamayı bellekte engellemek, yeniden bağlanmada aynı sıfırlamanın tekrar uygulanmasını tek başına engellemez. Kalıcı sahiplik ile satın alma işlemi birlikte kaydedilmeli; nakit ve kalıcı sahiplik aynı kolaylığın etkisini iki kez vermemeli.

## Öncelikli kararlar ve doğrulama planı

| Sıra | İş | Beklenen çıktı |
|---|---|---|
| 1 | Mevcut kararları koruyarak iki plandaki çelişkileri ve açık noktaları ayır | Tek tamamlanma/sıfırlama/sahiplik kuralı; taslak rakamlar ayrıca görünür |
| 2 | Simde planlanan rebirth koşulu, eşya alımı/takma, altın ve etki seçimi politikalarını ekle | İlk tur ve sonraki turlar; ücretsiz, altın biriktiren/harcayan ve Robux hızlandırıcılı süreler ayrı |
| 3 | Rehberi bilmeyen oyuncularla ilk 10–30 dakikayı gözlemle | Hedefi anlama, ilk satın alma/toplama/üretim/ada süreleri ve kopuş noktaları |
| 4 | İlk eşya değeri, alma sonrası takma ve ada/çiftlik ödül anını test et | Satın alımın görünür ve anlaşılır faydası |
| 5 | İkinci ve altıncı çiftlikte oynanış örneklerini karşılaştır | Beklemeyi dolduran gerçek kararlar ve yeni işlev ihtiyacı |
| 6 | Aynı kamerada yeni/orta/tamamlanmış çiftlik ve Sv.0/1/5 modelleri incele | Görsel ilerlemenin uzaklık ve mobil ekranda okunabilirliği |
| 7 | Pilot ve sim verisiyle fiyat, altın oranı, ada primi ve eşya faydalarını ayarla | Hedefli değişiklik, önce/sonra ölçümü; satıştan önce kalıcı hak ve kayıt testleri |

İlk denemede 5–8 rehberi bilmeyen oyuncunun küçük gözlem grubu nitel sorunları bulabilir; bu sayı istatistiksel retention kanıtı sağlamaz. Onlara çözümü anlatmadan sıradaki hedefi, yatırımın faydasını ve yeni adanın ne getirdiğini sordur. Aktif oynama süresi, menüde geçirilen süre, dünyada dolaşma, beklenen üretim ve neden çıkıldığı kaydedilsin.

Telemetri var, fakat mevcut huni sırası ilk toplama → ilk hayvan → ilk yükseltme → ilk ada → Ahır Sv.2 şeklinde. Oyuncu başlangıçta önce hayvan alır; ilk ada da Ahır Sv.2 gerektirir. Giriş/yükleme ve ilk satın alma öncesi çıkış ölçümü için huni başlangıcı ve sıra yeniden tasarlanmalıdır. Mevcut grafiğin gerçekten nasıl göründüğü incelenmedi; veri kaybı oranı iddia edilmiyor.

Ölçülecek sıra: giriş → oynanış hazır → ilk hayvan → ilk para toplama → ilk yükseltme → ilk tamamlanan üretim → ilk ada ziyareti. Üretim/ada dalları için gerekirse ayrı huni kullan; bütün oyuncuların tek zorunlu sırada ilerlediğini varsayma. İlerleyen çiftlikte ara hedefler, yeni eşyayı takma ve satın alma sonrası gelir farkı ayrıca izlenmeli.

Roblox'un resmi [onboarding rehberi](https://create.roblox.com/docs/production/game-design/onboarding) temel döngüyü ve eylemlerin nedenini öğretmeyi, görünür hedefler ve başarı anları kurmayı önerir. [Engagement rehberi](https://create.roblox.com/docs/production/analytics/engagement) ilk oturumun dakika bazındaki oyuncu kalışını incelemeyi anlatır. [Funnel rehberi](https://create.roblox.com/docs/production/analytics/funnel-events) ilk adımın huniyi başlattığını ve olayların Studio'dan gönderilemediğini belirtir. Bu kaynaklar belirli bir tycoon için tek bir doğru süre vermez; önerilen fiyat/süre kararları yerel ölçümle sınanmalıdır.

## İnceleme sonucu ve açık işler

Başlangıç yönlendirmesi, hayvan koleksiyonu, üretim seçenekleri ve fiziksel yapı ilerlemesi iyi bir temel oluşturuyor. Altın/Robux/rebirth planı bunlara kalıcı ilerleme ekleyebilir; fakat dengesiz fiyat veya zayıf oynanışı satışla çözmüş sayamayız. Önce mevcut kararlarla simülasyon aynı bitişi ölçmeli, ekipmanlı ve ücretsiz tempo karşılaştırılmalı. Ardından geç çiftliklerde tekrar hissi, ilk eşya faydası ve önemli büyüme anları hedefli biçimde iyileştirilmeli.

Bu rapor kod/fiyat uygulaması değildir. Plan/kod karşılaştırması ve matematiksel stres hesapları yapıldı; altın/Robux/rebirth içeren tam tur simülasyonu, gerçek oyuncu retention'ı, tüm çiftliklerin tamamlanmış görsel karşılaştırması, mobil HUD ve aktif/çevrimdışı uzun oturum denemesi bekliyor. Belge değişikliği için oyun regresyon paketi yeniden çalıştırılmadı. Önceki kod çalışmasının toplu doğrulaması başarılıydı; bu sonuç yeni planların uygulanmış veya test edilmiş olduğunu göstermez.

Somut sıra: plan tutarlılığı → rebirth/ekipman/altın simülasyonu → hedefli denge kararı → altın ve kalıcı sahiplik/kayıt güvenliği → satış ürünleri ve rebirth → oyuncu testi. Altın planında simülasyonun sona ve kalıcı sahipliğin marketten sonraya konması yerine, dengeyi fiyatlardan önce ve sahipliği kalıcı satışları açmadan önce doğrulamak öneriliyor. Uygulama sırası değişikliği henüz yapılmadı; Robux fiyatı veya yeni ekonomi sayısı bu incelemede belirlenmedi.
