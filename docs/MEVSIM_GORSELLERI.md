# Mevsim görselleri

Mevsim süresi `Config.SEASON_SECONDS = 900` (15 dakika); hava değişimi 150–270 saniye.
Tüm sunucular aynı mevsim saatini kullanır. Yeni katılan oyuncu kalan süreyi görür;
katılınca kişisel bir 15 dakika başlamaz.

HUD aynı sunucu saatinden ilerleme, kalan dakika/saniye ve sonraki mevsimi hesaplar.
Sol `Stats` panelinde (depo ile hedef kartı arasında, `Ui/Hud/SeasonBar.luau`) küçük bir kart kullanılır. Hava ve mevsim
ikonları UiKit kutularında; dolum rengi mevsime göre temadan alınır.

Görsel geri bildirim sonrası: çalılar saydamlaşmaz, opak kalıp yatayda daralır. Yaprak
kümeleri cam gibi solmak yerine sırayla tamamen dökülür; çiçekler ve meyveler de yalnızca
görünür/gizli olur.

Yağmur, Roblox ile gelen yumuşak kenarlı dokuyla hızlı düşen küçük yuvarlak damlalar oluşturur;
hıza göre yönlendirme ve esnetme kaldırılmıştır.
Kar aynı yuvarlak dokuyu küçük, yavaş ve hafif sürüklenen taneler olarak kullanır; yıldız
dokusu kaldırıldı. Yağış kaliteye göre sınırlanır ve kamera çatı altındayken durur.

`Shared.Modules.SeasonVisuals` salt görsel 0–1 eğriler üretir. Ekonomi çarpanları değişmedi.

| Dönem | Davranış |
|---|---|
| İlkbahar başı | Kıştan kalan %20 kar/buz ilk %20 sürede erir; yapraklar ilk %35 sürede geri gelir. |
| İlkbahar ortası | Çiçeklenme yoğunlaşır, mevsimin sonuna doğru uçuşan çiçek yaprakları azalır. |
| Yaz | Dolu yeşil yaprak örtüsü; kar ve buz yoktur. |
| Sonbahar | İlk %40 sürede sıcak yaprak renkleri; %35'ten sonra yapraklar kademeli dökülür. |
| Kış başı/ortası | Yaprak döken ağaçlar çıplak, çamlar yeşil kalır. Kar ilk %25, buz ilk %40 sürede yoğunlaşır. |
| Kış sonu | Son %30 sürede kar ve buz azalmaya başlar; ilkbahara %20 kalıntı taşınır. |

Kıyı buzu dekoratiftir, çarpışma oluşturmaz. Mevsim efektleri harita yapısına dokunmaz, bu yüzden
`MAP_VERSION` gerektirmez. Kalite ayarı efekt bütçesini sınırlar; hareket azaltma uçuşan
yaprak/çiçek parçacıklarını kapatır. Görseller client'ta üretilir ve ekonomi durumuna yazmaz.

Otomatik mevsim testleri gerçek kaynakları kullanarak dört mevsim sınırındaki devamlılığı,
0–1 sınırlarını, geç katılma zamanını, ilerleme değerini, dökülme/birikme/erime sırasını doğrular.
`scripts/verify.ps1` bunları diğer regresyonlarla birlikte çalıştırır.

Studio'da ayrıca kontrol edilecekler: telefon portre/yatay panel çakışmaları, sonbahar/kış
ağaçları, kilitli ada açılması, streaming ile çıkıp geri gelen dekor, düşük kalite/hareketi
azaltma değişimleri, kıyı buzunun köprü/iskeleyle kesişmemesi ve 6 çiftlikte efekt maliyeti.
Gerçek Studio görüntü ve FPS doğrulaması bu çalışma ortamında yapılmadı.
