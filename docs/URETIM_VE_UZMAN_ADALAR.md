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

## Fabrika × ada × hayvan uyumu (değişmez)

Bir fabrika yalnızca kendi adasında ve o adada yaşayan hayvanla kurulur; kural `tests/config.spec.luau` ile her temada denetlenir
(yeni hayvan/tema eklenince de koşar; sabit liste yok). Tarif → ada eşlemesi `Config/Production.luau` `island`, tesisi açan yükseltme
`Config/Upgrades.luau`'dadır. Tema kuralı `Config.upgradeInTheme`: adası temada olmalı; **ana ada fabrikalarında** (`homeAnimal` alanı)
çiftliğin ana hayvanı da eşleşmeli (ana adada yalnızca ana hayvanın fabrikası çıkar).

| Ada | Hayvan | Para fabrikası (tarif / yükseltme) | Ürün merkezi (tarif / yükseltme) |
|---|---|---|---|
| Ana ada, ana hayvan inek | inek | `packed_milk` / `milk_factory` | `milk_goods` / `milk_center` |
| Ana ada, ana hayvan tavuk | tavuk | `egg_packing` / `egg_packer` | `egg_home_goods` / `egg_home_center` |
| Ana ada, ana hayvan ördek | ördek | `duck_packing` / `duck_packer` | `down_home_goods` / `down_home_center` |
| Ana ada (deniz, balık kafesi) | hamsi, levrek | `fish_dispatch` / `fishing_boat` | `fish_goods` / `fish_cannery` |
| Süt Adası | inek | `dairy_packing` / `dairy_factory` | `dairy_goods` / `dairy_center` |
| Tavuk Adası | tavuk | `hatchery` / `hatchery` | `egg_goods` / `egg_center` |
| At Adası | at | `horse_training` / `horse_training` | `horseshoe_goods` / `horseshoe_forge` |
| Keçi Adası | keçi | `cheese` / `cheese_dairy` | `cheese_goods` / `cheese_cellar` |
| Ördek Adası | ördek | `duck_eggs` / `duck_house` | `down_goods` / `down_workshop` |
| Koyun Adası | koyun | `wool` / `wool_mill` | `wool_goods` / `wool_loom` |
| Domuz Adası | domuz | `truffle` / `truffle_kitchen` | `meat_goods` / `meat_smokehouse` |

Ana ada yuvaları (süt/yumurta/ördek) harita üzerinde aynı koordinatı paylaşır (`MapLayout.HOME_BUILD_SPOTS`); bir çiftlikte yalnızca ana
hayvanın yükseltmesi alınabildiği için üst üste binmez. Görünüm: `UpgradeVisualService.BUILDER_ALIASES` (yeni yapı mevcut bir binanın görünümünü paylaşır).

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
