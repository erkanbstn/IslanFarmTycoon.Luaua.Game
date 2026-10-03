# Ana çiftlik geçişi performansı — 2026-10-03

- Önceki yol: sahibi değişen çiftliğin görsellerini sil, tema ağacını bütünüyle Clone et, hayvanları topluca kur.
- Yeni yol: `World/ThemePatch` ortak Model/Folder/Part kimliğini korur; yalnız özellik ve ağaç farklarını uygular.
- Ada/bölge yuvaları ad veya hayvan türüyle değil fiziksel konumuyla eşleştirilir; tabanlar ve ortak çitler korunur.
- GUI gibi model dışı yapraklar gerektiğinde kopyalanır; bütün tema tek seferde kopyalanmaz.
- `World/VisualWorkBudget`: geçiş coroutine'leri ortak 128 nesne / 3 ms eşik kullanır, Heartbeat sonrası devam eder.
- Bu eşikler sert FPS garantisi değildir; tek model klonlama gibi atomik işler eşik aşabilir.
- ModelAssets klonları ve hayvan kurma/silme bu kapsamda bütçelenir; normal küçük güncellemeler bekletilmez.
- MainFarmService: tek işçi kuyruğu, oyuncu başına tek bekleyen işlem, yürütme anında tekrar doğrulama.
- Geçiş boyunca WorldReady=false, WorldTransition=true; normal dünya yenilemeleri ve BuyPads müdahalesi durur.
- Satın alma profili ve ücret, tema hazırlığı başarılı olduktan sonra birlikte kesinleşir; kopan oturum yeni adaya sahip olmuş sayılmaz.
- Aynı çiftliği tekrar seçmek geometriyi değiştirmez. İlk giriş kurulumu da bütçeli ve iptal korumalıdır.
- Son geçiş süresi plot.WorldTransitionSeconds ile gözlenebilir.
- BuildEffects: başka oyuncunun modelleri erken elenir; toplu geçişte pop/toz/ses yok; aday/parça taraması sınırlı.
- SeasonalScenery: kaynaklar 64 işlem/kare kuyruğunda; korunan yaprakların ThemeBaseColor/Size değerleri yenilenir.
- Mevsim tween'leri geçişte tema özellikleriyle yarışmaz.
- StreamingMinRadius 160→128, StreamingTargetRadius 1024→512, StreamOutBehavior=Opportunistic.
- Uzak ayrıntılar daha erken boşaltılabilir; uzak görünüm ve mobil bellek canlı oyunda değerlendirilmelidir.
- Ada konumları, köprüler, Terrain, model geometrileri ve MAP_VERSION değişmedi.

## Tek toplu kontrol ve bulunan hataların onarımı

- Saf Luau servis/ekonomi/kuyruk/kopma/başarısız satın alma regresyonları geçti.
- Görsel kimliği regresyonu, 745 asset, mimari, AI rehber, 1202 çeviri anahtarı ve Rojo derlemesi geçti.
- Selene 0 hata/uyarı; tip analizi 0 yeni bulgu (230 bilinen).
- Studio gerçek ThemePatch testi: özellik/etiket/öznitelik, yinelenen adlar, kimlik ve bekleme sonrası iptal geçti.
- Geçici kopyada temalar 2–6: her geçişte 5451–5725 Part aynı Instance olarak kaldı; toplam 6158–6304 Part.
- Düzenli çalıştırmada tema başına 1.81–1.88 s; ilk soğuk koşuda bir geçiş 6.16 s. Bunlar model kurulum süresidir, FPS ölçümü değildir.
- Decor/Islands/BuildSpots geometri imzaları kaynak şablonla eşleşti; gerçek oyuncu plot'una dokunulmadı.
- İstemci: toplu geçiş ve başka adada efekt yok; normal satın almada BuildPopActive başladı.
- Altı gerçek oyuncuyla ağ/FPS profili henüz ölçülmedi; sıfır kasma garantisi verilmez.
- Geçici runner ve test modelleri kaldırıldı, Studio Edit'e döndü; save/publish/commit/push yapılmadı.
- Streaming ayarlarının place'e geçmesi için Rojo ayarları güncelken kullanıcı Ctrl+S ve Publish yapmalıdır.
