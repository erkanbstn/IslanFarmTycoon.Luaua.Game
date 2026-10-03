# Market ve ürün çeşitlendirme raporu

4 Ekim 2026. Önceki rebirth/altın çalışması `2cc4a74` commit'iyle yerel ve uzak `main` dalına birleştirildi. Uzak depo kullanıcı tarafından açıkça onaylandı: `erkanbstn/ahir-tycoon`. Yeni çalışma dalı `codex/market-cesitlendirme`; bu market çalışmasının main'e birleştirilmesi ve yayınlanması henüz yapılmadı.

## Kapsam ve sözleşme

- Tek market ekranında altın, referans gelire bağlı oyun parası, kalıcı ekipman ve tur ürünleri sergilenir; altın → nakit dönüşümü de aynı akıştadır.
- Creator Hub kimliği olmayan ürün katalogda görünür, ödeme düğmesi kapalıdır. Robux fiyatı uydurulmaz; gerçek fiyat platformdan gelir. Altın satın alma, kalıcı sahiplik ve dönüşüm sunucuda doğrulanır.
- Yeni mesh, dış varlık veya kullanıcıdan ayrı model üretimi gerektirmeyen sekiz ekipman varyantı. Repo modellerinin primitive parçaları yeniden renklendirilir; kaynak modeller korunur.
- Eşyalar farklı oyun tercihleri sunar: üretim, çevrimdışı kazanç, büyüme, lojistik ve ticaret. Mevcut slot, gelir ve etki tavanları korunur. Nakit edinim tur içi, altın/Robux edinim kalıcıdır.
- Aydınlık krem/teal ekranlar, daha canlı model önizleme fonları ve kontrastlı düğmeler. Dünya tabelalarının mevcut koyu kontrastı ayrı tema token'larıyla korunur.
- Yeni ürünler mevcut finansal checkpoint/makbuz sistemini kullanır; yeni kayıt sürümü veya genel veri sıfırlama yoktur.

## İş dağılımı

| Aşama | Sorumlu | Durum |
|---|---|---|
| Önceki çalışmanın push/main birleştirmesi | Ana ajan | Tamamlandı |
| Sekiz ekipman, altın fiyatı ve nakit paketleri | Ürün alt ajanı | Tamamlandı |
| Birleşik market ekranı ve katalog | Market UI alt ajanı | Tamamlandı |
| Tema, model önizlemesi ve primitive varyantlar | Görsel alt ajanı | Tamamlandı |
| Sunucu, tekrar/sahiplik güvenliği, çeviriler | Ana ajan | Tamamlandı |
| Entegrasyon, ekonomi karşılaştırması ve Studio | Ana ajan | Tamamlandı; platform/cihaz kontrolleri aşağıda ayrı |

## Başlangıç doğrulaması

Rebirth sürümünün son tam doğrulaması başarılıydı; yeni geliştirme öncesi 48 Luau spec çağrısı tekrar geçti. Başlangıç çalışma ağacı önceki 62 dosyalık teslimden ibaretti; kullanıcıya ait ayrı değişiklik bulunmadı. Önceki inceleme ve raporlar commit'e dahil edildi. Yeni sonuçlar tamamlandıkça aşağıya eklenecek.

## Eklenen ürünler ve fiyat gerekçesi

| Ürün | Nakit | Kalıcı altın | Tercih / etki |
|---|---:|---:|---|
| Atölye Çekici | 1.600.000 | 550 | Geliştirme indirimi %18, tesis hızı %18; genel yükseltme indirimi yerine üretim odaklı |
| Üretim Asası | 1.200.000 | 500 | Tesis hızı %18, ürün verimi %12; mevsim/hava değiştirme gücü yok |
| Gece Nöbeti Muskası | 900.000 | 450 | Çevrimdışı kazanç katkısı %45, sipariş katkısı %5 |
| Lojistik Muskası | 1.800.000 | 600 | Nakit depo kapasitesi %60, ürün verimi %8; ahır ürün kapasitesiyle karıştırılmaz |
| Filiz Muskası | 1.500.000 | 650 | Büyüme hızı 1,5x, hayvan satış katkısı %6 |
| Tüccar Şapkası | 350.000 | 300 | Sipariş katkısı %10, hayvan satış katkısı %8 |
| Keşif Çantası | 1.800.000 | 350 | Çevrimdışı kazanç katkısı %20, nakit depo %25 |
| Atölye Pelerini | 1.300.000 | 400 | Tesis hızı %8, ürün verimi %8 |

Tek sayısal kaynak Config'tir; tablo 4 Ekim ölçüm kaydıdır. Yeni sekiz eşyanın toplamı 3.800 altın, yaklaşık 4,87 başlangıç turu ödülüdür. Amaç bütün eşyaları zorunlu toplatmak değil, oyuncunun tarzına uygun seçim sunmaktır. Her biri 300–650 ile ilk turun 780 altın ödülü içinde seçilebilir; takmak aynı yuvadaki eşyayı çıkarır. Hiçbir yeni eşya doğrudan incomeBonus eklemez. Mevcut başlık/sırt fiyat-güç testleri ve bütün etki tavanları değiştirilmedi.

Oyun parası paketleri 15 dakika, mevcut 1 saat ve yeni 3 saat kalıcı referans geliridir. En az 500 oyun parası kuralı korunur; gelir henüz yokken paket miktarları eşit olabilir. Robux fiyatlarını belirlerken bu ilk oyun durumu ayrıca kontrol edilmelidir. Kart oyuncunun güncel gerçek tutarını gösterir. Altın paketleri 100/500/1500 kalır; paket boyutları ve fiyatları bağımsız alanlardır, burada Robux fiyatı önerilmiş veya tanımlanmış değildir.

Kalıcı katalog 21 teklif; platform kataloğu 29 developer product + 3 mevcut gamepass'tir. Mevcut eşyalar ve üç kolaylık korunur. Otomatik Toplayıcı'nın altın/ürün/geçit yolları aynı sahiplik kabul edilir: aynı kalıcı özellik ikinci kez tahsil edilmez. Ayrı ödenmiş gecikmiş makbuzlar mevcut güvenli teslim/altın eşdeğeri kuralını sürdürür.

## Market ve görsel değişiklikler

Öne Çıkanlar, Altın, Para, Kalıcı, Bu Tur, Altın Çevir ve Hızlı Bitir sekmeleri. Market kimlikler 0 iken görünür; Robux butonu “Yakında” ve devre dışıdır. Kalıcı kartta altın alımı da vardır. HUD altın düğmesi doğrudan marketin çevirme sekmesini açar. Eski ayrı Robux/altın pencereleri tek MarketWindow ile birleştirilir; ProgressionWindow eski girişlere uyumluluk yönlendirmesidir.

Krem/beyaz zemin, mint yüzey, koyu okunaklı yazı; teal/yeşil/plum/amber vurgular. Dünya tabelaları ayrı koyu token'ları kullanır. Model önizlemesi yuvaya göre renkli fon, ayrı sabit ortam aydınlatması ve daha büyük görüntü kullanır. Aynı model yeniden klonlanmaz; boyut dinleyicisi viewport yok edilirken kopar. Yeni sekiz model mevcut primitive modellerin renk varyantıdır; siluet, pivot, parça tipleri ve takılma sözleşmesi korunur. Yeni mesh, çalışma anında model kurucu veya animasyon döngüsü eklenmedi.

Düz renk kontrast hesabı: normal yazı/krem 10,87:1; soluk yazı/beyaz 6,19:1; beyaz buton yazısının yeşil/turuncu/mavi/kırmızı/teal zeminlerde en düşüğü 4,52:1. Gradient, gerçek ekran ve her durumu bu tek ölçüm temsil etmez; Studio kontrolü ayrıca yapıldı.

## Ölçüm ve doğrulama

- İki günlük aynı gündelik simülasyon: her koşuda 120 aktif dakika ve üç sahip olunan çiftlik. Başlangıçtan gece/keşif ekipmanına sahip senaryoda kalan nakit 30,127M → 46,474M, çevrimdışı nakit 92,429M → 135,845M. Edinme maliyeti/süresi hariç; farklı yatırım/portföy bileşimi nedeniyle bu doğrudan gelir çarpanı olarak yorumlanmaz. Kaynak: `.test-build/market-products-comparison.json`.
- Aynı koşuda süt adedi 114 → 114; para üretimi 664.154 → 457.357. Kısa görev, kaçırılan gelir tabanını ve ziyaretler arasında tekrar başlatma fırsatını değiştirir. Tesis hızı her oyuncu ziyaret düzeninde daha çok üretim nakdi garanti etmez. Sabit formülde atölye çekici + asa + pelerin süreyi %44 azaltır; mevcut %50 hız tavanı korunur. Asa+pelerin ürün verimi katkısı %20'dir, miktar tavanı korunur.
- Yeni actual-source testleri: ekipman takma/değiştirme, offline/growth/production, kalıcı hak kayıt döngüsü; katalog ID0 ve ödeme engeli; altın alımı ve kalıcı sahiplik; exact dönüşüm önizlemesi. Sunucuda yeni nakit paketlerinin doğru süre/replay makbuzları ve otomatik toplayıcının eşdeğer hakla yeniden satışının engellenmesi test edildi.
- Studio yerel Play: WorldReady/Active; market, çevirme ve katalog sekmeleri açıldı. 1914×634 çalışma viewport'u ve geçici 370×550 UI pencere daraltma kontrolünde sekmeler iki satıra geçti; kontrol edilen etiketlerin TextFits sonucu true. Bu telefon emülatörü/gerçek dokunma testi değildir. Modeller camera/WorldModel ile yüklüydü; dar katalog ekranında pelerin önizlemesi görüldü. Konsolda hata görülmedi. Test sonunda UI ölçüsü geri alındı ve Edit moduna dönüldü.
- Son `powershell -ExecutionPolicy Bypass -File scripts/verify.ps1 -RequireTypes` başarılı. 50 Luau spec çağrısı; 8 tip denetleyici ve 11 model denetleyici Python testi; StyLua/Selene; Luau derleme; görsel kimlik regresyonu; ekonomi/rebirth smoke; ekonomi denetimi; ideal/casual/idle kademe monotonluğu; locale/Config; AI rehber; mimari; tip analizi (0 bulgu); oyun/eklenti/test Rojo derlemeleri geçti. 753 model, 0 eksik/bozuk; 1363 sözlük anahtarı ve 635 Config metni beş dilde tamam.
- Selene yeni Roblox API dump'ını ağ nedeniyle alamadı; önbellekle 0 hata/uyarı verdi. Tip denetimi atlanmadı. `git diff --check` ve değişen Python runner'ın bytecode derlemesi geçti. Ayrıntılı yerel doğrulama çıktısı `.test-build/market-final-verify.log` içindedir; kalıcı sonuç kaydı bu rapordur.
- Canlı ödeme/DataStore/gerçek cihaz kontrolü bununla tamamlanmış sayılmaz. FPS ve cihaz bellek kullanımı öncesi/sonrası profillenmedi; yalnız model klonlama/bağlantı yaşam döngüsü korunmuş ve görsel kontrast ölçülmüştür.

## Açık platform kontrolleri

Creator Hub kimlikleri/fiyatları en son kullanıcı tarafından tamamlanacak. Gerçek ödeme, iki oyuncu, mobil ve gamepad kontrolleri otomatik testlerle aynı sayılmaz. Canlı yayın ve yönetici sıfırlaması bu çalışma kapsamında tetiklenmez.

Somut sonraki adımlar:

1. Yeni market ve uzman ekipman tercihlerini özel place'te dene; fiyat/oyun tarzı değerlendirmesi için bu rapordaki tabloyu kullan.
2. Creator Hub'da seçilen ürünlerin kimliklerini oluştur: nakit/altın/tur paketleri `Config/Shop.products.*.id`, kalıcı teklif kimliği `Config/Progression.permanentOffers.*.robuxProductId`. Robux fiyatları platformda belirlenir; kimlik yoksa satış kapalı kalır.
3. 15 dakika/1 saat/3 saat paket fiyatlarını gerçek gösterilen tutarla karşılaştır; başlangıç 500 tabanı nedeniyle eşit tutar çıkabilen ilk oyun durumunda daha pahalı aynı miktar satılmasın.
4. Özel place'te gerçek makbuz + reconnect; kalıcı ürün + rebirth; iki oyuncu; telefon ve gamepad; genel reset öncesi hak/kayıt kontrolü.
5. Yeni dalı değerlendirdikten sonra main'e birleştir ve temiz yayını yap. Bu aşamada yalnız önceki rebirth çalışması push/main yapılmıştır; yeni market değişiklikleri `codex/market-cesitlendirme` çalışma ağacındadır.

Gezgin tüccar mevcut indirimli hayvan tekliflerini korur; ekipman RNG satıcısı, yeni fiziksel bina/ada, yeni kozmetik slotu veya süreli güçlendirme kayıt sistemi eklenmedi. Bu sürüm mevcut yapı içinde sekiz alternatif ekipman ve birleşik market getirir. Kimlikler/fiyatlar beklenirken kullanılabilir altın/nakit yolları çalışır.
