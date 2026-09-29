# Üretim ve uzman adalar

Harita sürümü 13. Mevcut takımadalardaki kayıtlı hayvan/bölge kimlikleri korunur.
Haritadaki altı takımada ana çiftlik alanlarıdır. Bir oyuncu boş olanlardan birden fazlasını
satın alabilir; her birinin ana, tavuk, at ve keçi adaları ayrı ilerler. Ayrıntılar
[Ana çiftlikler](ANA_CIFTLIKLER.md) belgesindedir.

## Oyun döngüsü

Tesis satın al → yeterli yetişkin hayvanı yetiştir → parti masrafını öde → üretim
süresini bekle → ürünü sat veya kuluçkadaki civcivi kümese ekle → yeni parti başlat.
Pasif hayvan geliri devam eder. Yetişkin hayvanlar üretim girdisi olarak tüketilmez.

| Tesis | Gereken | Süre | Masraf | Teslim |
|---|---|---|---|---|
| Süt fabrikası | 2 yetişkin inek | 60 sn | 160 | 650 |
| Kuluçkahane | 2 yetişkin tavuk | 90 sn | 120 | 240 veya 1 yavru tavuk |
| At eğitim merkezi | 1 yetişkin at | 75 sn | 300 | 850 |
| Peynirhane | 2 yetişkin keçi | 100 sn | 500 | 1.400 |
| Balık sevkiyatı | Toplam 3 yetişkin hamsi/levrek | 90 sn | 350 | 1.050 |

Tablodaki teslim tutarları brüttür; net kazanç için masraf düşülür. Dengelerin kodda
tek kaynağı `Config.PRODUCTION_RECIPES` ve `Config.UPGRADES` tablolarıdır.
Süt makinesi korunur; süt fabrikası ayrıca inek gelirine +%150 ekler ve parti üretimini açar.

Her tesiste aynı anda bir parti bulunabilir. Parti, tek UID ve bitiş zamanı ile oyuncu
kaydına yazılır. Oyundan çıkınca süre devam eder; dönüşte en fazla mevcut tek parti
hazırdır, çevrimdışında otomatik yeni partiler başlamaz. Hazır ürün teslim edilene kadar
korunur. Kümes doluyken civciv kaybolmaz; yer açılınca eklenebilir veya satılabilir.

## Kullanım

Masaüstünde sağdaki **Üretim** düğmesi veya **R**; dar ekranda **Çiftliğim → Üretim**.
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
ardından kaydet ve Play. Bu sürümde harita düzeni değiştiği için yeniden kurulum gerekir.

Studio'da ayrıca teknenin iskele/denizle hizası, tesislerin yürüme yolları, mobil panel,
iki oyuncu arasında üretim ayrımı, parti sürerken çıkıp geri girme ve dolu kümeste
civciv teslimi kontrol edilmeli. Kod testleri gerçek Studio görüntü/FPS ölçümünün yerini tutmaz.
