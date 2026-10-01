# Başka bir AI'a verilecek proje analiz prompt'u

Aşağıdaki metni olduğu gibi kopyala. AI'ın kodu görebilmesi için depoyu (ya da `src/`, `docs/`, `scripts/`, `tests/`, `.cursor/rules/`, `AGENTS.md`, `CLAUDE.md`) da paylaş.

---

Sen kıdemli bir Roblox/Luau oyun geliştiricisi, oyun tasarımcısı ve yazılım mimarısın. Aşağıdaki projeyi **eleştirel ama yapıcı** bir gözle analiz edip "ne nasıl yapılmış, nasıl olmalıydı, neyi değiştirmeliyiz" sorusuna **önceliklendirilmiş, uygulanabilir** bir rapor yazmanı istiyorum. Dolgu ve genel tavsiye istemiyorum; her bulgu için somut dosya/sistem, gerekçe, risk ve önerilen çözüm ver.

## Proje
- **Ne:** "Island Farm Tycoon" — Roblox'ta çok oyunculu (sunucu başına en fazla 6 oyuncu) takımada çiftlik/tycoon oyunu. Oyuncu hayvan alır, hayvanlar gelir üretir (depoda birikir, platformdan toplanır), yükseltmeler/adalar/üretim tesisleri alır.
- **Dil/araçlar:** Luau (`--!strict`), Rojo ile Studio'ya senkron, StyLua/Selene, saf Luau test koşucusu (`python scripts/run-tests.py`), `scripts/verify.ps1` (stil, lint, test, çeviri kapsamı, mimari kuralları, tip analizi, Rojo build'leri). Geliştirici C# geçmişli, tek kişi; testler arkadaşlarla.
- **Katmanlar:** Sunucu `Modules (saf mantık) → World (statik harita, eklenti de çalıştırır) → Presentation (durumdan dünyaya çizim) → Services (oyun mantığı, Remote)`. İstemci `Core → Effects → Ui → Interaction`. `src/shared`: `Config/` (tüm denge), `Modules/FarmMath` (tüm hesap), `Remotes`, `Locales` (TR kaynak; en/de/ru). Kurallar `docs/MIMARI.md` ve `scripts/check-architecture.py` ile denetlenir.

## Ana sistemler (kısa)
1. **Ekonomi:** hayvanlar (büyüme evreleri, evre başına gelir çarpanı), yükseltmeler (yol haritası, ada açma, seviye zincirleri), ahır seviyeleri (depo kapasitesi), alan genişletme, ırk geliştirme, mevsim/hava gelir etkileri, çevrimdışı gelir ("Pasif Gelir" satın alınmadıkça yalnızca depo birikir).
2. **Üretim:** para fabrikaları (parti seçenekleri) ve ürün merkezleri (ahır deposuna ürün); hayvanlar işe verilir; yardımcılar (pet) otomatik teslim/tekrar eder ve adada yürüyerek canlandırılır (istemci tarafı).
3. **Siparişler:** ahır deposundaki ürünler zamanla yenilenen 9 karolu panoda para karşılığı teslim edilir.
4. **Çoklu çiftlik/çok oyunculu:** her oyuncuya haritadaki 6 aynı düzenli fiziksel adadan biri rastgele verilir; oyuncunun etkin çiftliği (tema) o adaya **çalışma anında** giydirilir (`MapBuilder.applyTheme`), diğer çiftlikler "park" edilir ama çalışmaya devam eder. Cüzdan, envanter, ahır deposu ve siparişler hesap düzeyinde ortaktır; hayvan/yükseltme/üretim çiftlik başınadır.
5. **Kayıt:** DataStore, oturum kilidi (`SessionLock`), `SaveCodec` (şema 4, gelecek sürüm reddi, bozuk veri onarımı), 3 denemeli yazma, 10 dakikada bir dönüşümlü yedek, bozuk kayıtta karantina + yedekten açma, boyut/süre/hata ölçümü.
6. **Arayüz:** `UiKit` bileşenleri, 2 sütunlu esnek ızgaralar, ada sekmeleri, çok dilli, kademeli açılan HUD.
7. **Atmosfer:** gece/gündüz, mevsim, hava (3 halkalı yağış), su altı, ses (çoğu ses yuvası boş), köprüde hız artışı.

## Durum ve bilinen belirsizlikler (dürüst liste)
- Yakın zamanda yapılan **çoğu görsel/dünya değişikliği Studio'da hiç doğrulanmadı**: çalışma anı tema değiştirme, yardımcı yürüyüşü ve rotaları, ızgara arayüzler, eşya (şapka/çekiç/asa) oturumu, hayvan gözleri, panolar.
- Otomatik testler yalnızca saf mantığı kapsıyor; Roblox çalışma zamanı (dünya, UI, çok oyunculu) otomatik test edilmiyor.
- Ekonomi `scripts/simulate-economy.py` ile "ideal oyuncu" olarak modelleniyor; üretim tesisleri, yardımcılar, eşyalar, siparişler, altın hayvan ve çok çiftlikli ilerleme simülasyonda **yok**.
- Yayınlandı; arkadaşlarla test başladı. Para (Robux) ürünlerinin kimlikleri 0 (kapalı).

## İstediğim analiz
Her başlık için "Şu an nasıl", "Sorun/risk", "Olması gereken", "Önerim (somut adımlar, tahmini efor)" ver:

1. **Mimari ve kod kalitesi:** katman ihlalleri, devasa dosyalar, tekrar eden kod, strict tip borcu (`scripts/types-baseline.json`), test edilebilirlik, istemci/sunucu sorumluluk dağılımı. Güvenlik: istemciye güvenme, Remote doğrulama, hız sınırı, kayıt bütünlüğü, hile/istismar yüzeyi (ör. hız istemcide, yardımcı görseli istemcide).
2. **Çok oyunculu tasarım:** tek fiziksel ada + çalışma anı tema giydirme yaklaşımı doğru mu? Yeniden kurulumun maliyeti, streaming, ağ yükü, ada atama/ayrılma, 6 kişi sınırı, ziyaret/etkileşim yalıtımı, yarış koşulları. Alternatifler.
3. **Performans:** sunucu döngüleri (ekonomi 1 sn, yardımcılar 2 sn, görünüm yenilemeleri), ağ trafiği (pushState sıklığı ve boyutu), istemci efektleri (yağış, yürüyen yardımcılar, balonlar), instance sayısı, mobil/düşük cihaz.
4. **Oyun tasarımı ve ekonomi:** ilk 10 dakika, ilerleme temposu, depo/toplama mekaniği, çevrimdışı gelir, büyüme süresi, çiftlik fiyatları, ürün/sipariş sistemi, yardımcılar, ödüller (günlük/başarım/mevsim), eşya fiyatları. Sıkmayan ama kolay olmayan bir denge için neyi ölçmeliyiz? Simülasyonu nasıl iyileştiririz (üretim, yardımcılar, çok çiftlik)?
5. **Arayüz/deneyim:** bilgi mimarisi, pencere sayısı, ızgara geçişi, mobil/dokunmatik uyumu, onboarding, geri bildirim (ses, bildirim, ipucu), erişilebilirlik ve yerelleştirme kalitesi.
6. **Kayıt ve operasyon:** şema/göç stratejisi, yedek ve kurtarma yeterli mi, canlı güncelleme/rollback süreci, sunucu kapatma, telemetri (hangi sayaçlar/olaylar eksik), hata ayıklama.
7. **Test ve geliştirme süreci:** hangi Studio testleri otomatikleştirilebilir (Roblox test servisleri, istemci simülasyonu), CI, sürüm yönetimi, belge/kural dosyalarının sürdürülebilirliği (AI kural dosyaları: `AGENTS.md`, `.cursor/rules`).
8. **Yayın ve büyüme:** Roblox keşif/retention için eksikler (ilk dakika, sosyal özellikler, sıralama panosu, etkinlikler), monetizasyon planı (gamepass/geliştirici ürünü) ve etik/güvenlik (çocuk güvenliği, içerik etiketi).

## Çıktı biçimi
- Önce **10 satırlık yönetici özeti** ve "en kritik 5 risk".
- Sonra başlık başlık bulgular; her bulgu: **Önem (Kritik/Yüksek/Orta/Düşük) · Efor (S/M/L) · Etki** etiketiyle.
- Sonda **önerilen sıralı yol haritası** (ilk 1 hafta, 1 ay, 3 ay) ve "bilerek yapmamamız gerekenler".
- Emin olmadığın yerde varsayımını açıkça yaz, kod okumadan karar verme; bir iddia dosya/satıra dayanmalı.
- Türkçe yaz; kod adları ve dosya yolları olduğu gibi kalsın.

---
