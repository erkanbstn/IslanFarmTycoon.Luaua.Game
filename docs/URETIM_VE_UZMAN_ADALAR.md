# Üretim ve uzman adalar

Harita sürümü `MapBuilder.luau` içindeki `MAP_VERSION`'dır. Mevcut takımadalardaki kayıtlı hayvan/bölge kimlikleri korunur.
Haritada `Config.MAP_PLOT_COUNT` kadar takımada oyuncu başına birer fiziksel adadır; oyuncu birden fazla çiftlik (tema)
satın alabilir ve etkin olanı kendi adasında çizilir; her çiftliğin ana ve küçük adaları ayrı ilerler. Ayrıntılar
[Ana çiftlikler](ANA_CIFTLIKLER.md) belgesindedir.

## Oyun döngüsü

Tesis satın al → yeterli yetişkin hayvanı yetiştir → parti seçeneğini (küçük/standart/büyük) seç, varsa masrafı öde →
üretim süresini bekle → ürünü sat (para tesisleri), depoya al (ürün merkezleri) veya kuluçkadaki civcivi kümese ekle →
yeni parti başlat. Pasif hayvan geliri devam eder. Yetişkin hayvanlar üretim girdisi olarak tüketilmez.

Tesis listesi, gereken yetişkin sayısı, süre, masraf ve ödül **tek kaynaktan** okunur: `Config.PRODUCTION_ORDER` sırasıyla
`Config.PRODUCTION_RECIPES` (`src/shared/Config/Production.luau`; parti seçenekleri `options`). Tesisi açan yükseltmeler ve
gelir bonusları `Config.UPGRADES` içindedir. Rakamlar bu belgede tutulmaz; sürüm kaymasın diye koda bak.
Tesisler iki türdür: para tesisleri (`output = "cash"`) ve depoya ürün üreten ürün merkezleri (ahır deposu, bkz. `Config/Goods.luau`).

Her tesiste aynı anda bir parti bulunabilir. Parti, tek UID ve bitiş zamanı ile oyuncu
kaydına yazılır. Oyundan çıkınca süre devam eder; dönüşte en fazla mevcut tek parti
hazırdır, çevrimdışında otomatik yeni partiler başlamaz. Hazır ürün teslim edilene kadar
korunur. Kümes doluyken civciv kaybolmaz; yer açılınca eklenebilir veya satılabilir.

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
