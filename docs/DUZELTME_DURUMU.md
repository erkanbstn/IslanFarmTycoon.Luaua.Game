# Ahır Tycoon 0.6.0 — Düzeltme durumu

28 Eylül 2026. İlk incelemedeki 36 madde aşağıda izlenir. Üç subagent veri güvenliği,
ekonomi ve dünya sistemlerini ayrı ayrı ele aldı; ana agent açılış, istemci durumu,
arayüz ve birleştirmeyi yaptı. Karşılıklı inceleme bulguları da düzeltildi.

Sonraki mevsim/tasarım geliştirmeleri: [Mevsim görselleri](MEVSIM_GORSELLERI.md).
Bu ek pakette 15 dakikalık mevsimler, süre/ilerleme paneli ve kademeli bitki/kar/buz geçişleri bulunur.

Görsel geri bildirim düzeltmesi: hava kartı sağ menüye taşındı; çalıların saydamlaşması kaldırıldı.
Yakındaki hayvanlar tüm kalite seviyelerinde her çizim karesinde güncellenir; kalite yalnızca
görünür hareket mesafesini sınırlar. Orta kalitede de satın alma büyüme animasyonu tekrar vardır.
Animasyon ve boyut efekti aynı hayvan pivotuna eşzamanlı yazmaz.

“Uygulandı” kod değişikliğini ifade eder. Studio'da çok oyunculu, gerçek DataStore,
mobil/gamepad ve FPS doğrulaması yapılmadı; bu belge bunları tamamlandı saymaz.

## Paket 1 — Kayıt güvenliği

| ID | Durum | Sonuç |
|---|---|---|
| D01 | Uygulandı; regresyonlar geçti | UpdateAsync ile süreli oturum sahipliği, anahtar başına yazma sırası, revizyon ve tekrar yazma token'ı. Kaybolan yanıt aynı işlemle uzlaştırılır. |
| D02 | Uygulandı; regresyonlar geçti | Başarı sonucu, süre bütçeli tekrar deneme; başarısız son snapshot kilit süresi boyunca korunur. Kapanış bütçesi 25 saniye. |
| D03 | Uygulandı | Studio store adı `_Studio` eki alır. Ayrı test deneyimi önerisi README'de; canlı ortamda gerçek karşılaştırma henüz yapılmadı. |
| D04 | Uygulandı | Başarısız yükleme ekonomi/karakter açılışını engeller. Kayıtsız test yalnızca açık Studio attribute'u ile, kalıcı HUD uyarısıyla çalışır. |
| D05 | Uygulandı; regresyonlar geçti | V1/V2/V3 → V4 normalleştirme, bağımsız ana çiftlikler ve kayıtlı üretim partileri; desteklenmeyen gelecekteki şemayı reddetme, bilinmeyen veriyi varsayılan profille ezmeme. |
| D06 | Uygulandı; regresyonlar geçti | Sonlu sayı, üst sınır, UID, tarih, bölge ve kapasite kontrolü; taşıma/iade. Bilinmeyen hayvan türünde orijinal kayıt korunup yükleme durur. |

Yeni modüller: SessionLock, SaveCodec. DataStatus, DataPersistent, DataDirty,
DataLastSavedAt ve DataError, oturum durumunu görünür yapar. Süreli kilit 180 saniyedir;
çöken sunucudan sonra tekrar giriş kilidin bitmesini bekleyebilir. Hiçbir yöntem mutlak
sıfır veri kaybı garantisi vermez; sunucu öldürülmesi/kalıcı servis kesintisi ayrıca sınanmalıdır.

## Paket 2 — Sunucu sınırları ve açılış

| ID | Durum | Sonuç |
|---|---|---|
| S01 | Uygulandı | Ortak eylem hız sınırı, kısa ID doğrulama, aktif profil/dünya kontrolü, son istek kimliklerini tekrar işlememe. |
| S02 | Uygulandı | Toplama sahibin yaşayan karakterini ve döndürülmüş platformun yerel sınırlarına yakınlığını doğrular. |
| S03 | Uygulandı; Studio testi hazır | Hayvan/bina klonlarında çalışabilir kod dünyaya eklenmeden kaldırılır; kaynak modeller ServerStorage'a taşındı. |
| R01 | Uygulandı | Snapshot isteği/ilk yükleme tekrarı, paket revizyonları, eski paket koruması ve revizyon boşluğunda yeniden eşitleme. |
| R02 | Uygulandı | Yükleme ekranı profil + dünya + karakter + ilk client durumunu bekler, gecikme/hata metni gösterir. |
| R03 | Uygulandı | Harita sözleşmesi ve sürümü doğrulanır; ada yoksa giriş durur. Gelir dünya hazırlandıktan sonra başlar. |

Ayrılma sırası son gelir hesabı → ada temizliği → profil kapanış kaydıdır. Dünya temizliği
hata verse de kayıt denenir. Karakter ilk kez veri ve dünya hazırlanırken yüklenir.

## Paket 3 — Ekonomi ve yeni içerik

| ID | Durum | Sonuç |
|---|---|---|
| E01 | Uygulandı; hesap regresyonu geçti | Dolu kafeste hamsi → yavru levrek değiştirme. Fiyat sunucuda; iade yükselen satış fiyatından değil sabit taban fiyattan hesaplanır. |
| E02 | Uygulandı; regresyonlar geçti | Çevrimdışı süre büyüme aşamalarına bölünür; kaydı tutulmayan hava/mevsim nötr kabul edilir. |
| E03 | Uygulandı; regresyonlar geçti | Gerçek geçen süreyle gelir, 60 saniye telafi üst sınırı. Satın alma öncesinde eski durumun geliri kapatılır. |
| E04 | Uygulandı | Hedef metinleri depodaki parayı, depo sınırını ve toplama gereksinimini belirtir; negatif süre göstermez. |
| E05 | Uygulandı; regresyon geçti | Yeni büyüme hızı geçmiş yaşı çarpmaz; mevcut büyüme ilerlemesi korunur. |
| E06 | Politika netleştirildi | 8 saat üst sınırı ve depo kapasitesi korunur; otomatik toplama çevrimiçine aittir. HUD/README vaatleri buna uyarlandı. Sayısal yeniden dengeleme yapılmadı. |
| E07 | Uygulandı | Ustalık hedefleri: tüm kapasiteyi yetişkin hayvanlarla doldurma ve balık kafesini levreklerle doldurma. Tüm yükseltmelerden sonra tekrar eden üretim siparişleri açılır. |

Siparişler yalnızca sahip olunan yetişkin türlerinden seçilir. Çevrimiçi yetişkin üretim süresi
ilerleme sağlar; hayvan harcanmaz. Teslimde sipariş UID'si tüketilir, ödül sunucuda hesaplanır,
tamamlanma sayısı kaydedilir ve yeni sipariş atanır. Ustalık sayaçları hedef gösterimidir;
ekstra rozet, kalıcı unvan veya prestij sıfırlaması eklenmedi. Denge sabitleri Config'tedir.

## Paket 4 — Arayüz ve erişilebilirlik

| ID | Durum | Sonuç |
|---|---|---|
| U01 | Uygulandı; cihaz testi bekliyor | Dar/kısa ekranda sade HUD ve Çiftliğim penceresi; ekran boyutuyla sınırlandırılmış pencereler. |
| U02 | Uygulandı; görsel test bekliyor | Esnek kart yüksekliği, alta alınan aksiyonlar ve satır kaydıran bildirimler. |
| U03 | Uygulandı | Ortak bekleyen istek, eşleşen sonuç, çift tıklama aralığı ve otomatik tekrar satın almayan zaman aşımı. |
| U04 | Uygulandı | LoadingScreen aynı UiTheme kaynağını kullanır; CollectorGuide para etiketi WorldUi'ye taşındı. |
| U05 | Uygulandı | Başlangıçta boş kapasiteye yeni inek hedefi; otlak önerisi mevcut başlangıç alanı dolana kadar ertelenir. |
| U06 | Kısmen uygulandı | Hareketi azaltma, kalite seçenekleri, pencere odağı, gamepad kapatma/seçim temeli. Ses içeriği ve uçtan uca gamepad kabul testi açık. |

Kalite/hareket tercihleri oturumla sınırlıdır. Ses asset'i olmadığı için boş/sahte ses
ayarları eklenmedi. Lisansı uygun gerçek seslerle geri bildirim ve ses düzeyi ayarı ayrı
içerik işidir. Düşük/orta/yüksek kalite otomatik cihaz tahmini yerine açık kullanıcı seçimidir.

## Paket 5 — Performans ve dünya

| ID | Durum | Sonuç |
|---|---|---|
| P01 | Uygulandı | Yapısal değişiklik ile para güncellemesi ayrıldı; kapalı pencerelerin kartları ertelenir, değişmeyen para animasyonu tekrarlanmaz. |
| P02 | Uygulandı; süre hesabı test edildi | Gelir döngüsünde tür başına çarpan/büyüme hızı önbelleği; gerçek CPU kazancı ölçülmedi. |
| P03 | Uygulandı; FPS testi bekliyor | Kaliteye göre hareket sıklığı/parçacık sayısı, hareket azaltmada kuş/balık/gezinme/şimşek sınırlandırması. |
| P04 | Kısmen uygulandı | Dekor/klonlarda gereksiz dokunma ve seçili fizik/gölge maliyetleri azaltıldı. Tüm sahneye körlemesine ayar uygulanmadı; GPU/CPU profili açık. |
| P05 | Uygulandı; Studio streaming testi bekliyor | Efekt/prompt/hayvan/collector keşfi eklenme-kaldırılmaya uyumlu; bağlantı/nesne temizliği ve tekrar bağlama. StreamingEnabled varsayılanı değiştirilmedi. |
| P06 | Uygulandı | Ada/bölge kilidi değişmediyse temel renk tekrar yazılmaz; sunucu yenilemesi mevsim rengini ezmez. |

İyileştirmelerin ölçülmüş FPS yüzdesi yoktur. 6 dolu çiftlik, düşük cihaz ve yoğun hava
koşullarında MicroProfiler/istatistik karşılaştırması yapılmadan performans hedefi geçti denemez.

## Paket 6 — Bakım, araçlar ve ölçüm

| ID | Durum | Sonuç |
|---|---|---|
| M01 | Yerel kısım uygulandı | Git başlangıç kaydı, LF kuralları, model dosyalarını assets altında izleme. Uzak depo/yedek kurulmadı; hedef repo belirtilmedi. |
| M02 | Uygulandı; yerel kontroller geçti | Gerçek kaynakları çalıştıran Luau testleri, servis hata taklitleri, verify.ps1, ayrı Studio test projesi ve CI iş akışı. Uzak CI henüz çalıştırılmadı. |
| M03 | Kısmen uygulandı | Oturum, codec, hız sınırı, sipariş, satın alma istemcisi ayrı modüller; remote adları tipli. Test enjeksiyon sınırlarında any hâlâ var; tam Roblox tür analizi ve büyük görsel dosyaların daha ileri bölünmesi açık. |
| M04 | Uygulandı; Studio geri alma testi bekliyor | Harita temizliği üretilen klasörler/Terrain hacmiyle sınırlandı; bağımsız Baseplate/Spawn korunur. Plugin geri alma kaydı olmadan çalışmaz. |
| M05 | Temel ölçüm uygulandı | ServerStorage.Diagnostics: profil süresi/başarı/hata, kayıt denemeleri, alım/ret, toplama ve sipariş sayaçları. Kalıcı analitik ve oyuncu ilerleme hunisi henüz yok. |

## Çalıştırılan kontroller

- StyLua: src, plugin, tests biçim kontrolü.
- Selene: aynı kaynaklarda hata/uyarı kontrolü.
- Luau 0.740: tüm kaynakların sözdizimi derlemesi.
- Gerçek Config/FarmMath/SaveCodec/SessionLock/OrderRules üzerinden veri, ekonomi ve sipariş regresyonları.
- Gerçek RateLimiter üzerinden hız sınırı, bağımsız yanıt bütçesi, geçersiz kimlik,
  tekrar istek, 128 öğelik geçmiş sınırı ve oyuncu ayrılma temizliği regresyonları.
- Gerçek PlayerDataService kaynak kodu, taklit Roblox servisleri/saat/scheduler ile: ilk iki yazma hatası,
  kayda rağmen yanıt kaybı, save/release çakışması, yükleme sırasında ayrılma, son kayıt hatası sonrası
  tekrar, yabancı oturum sahipliği, kilit süresi dolması ve gelecekteki şemayı koruma.
- SessionLock ve OrderRules için Luau tür analizi. **Tüm projenin tür analizi değildir.**
- Rojo: oyun, harita eklentisi ve izole test place'i derlemesi.

Tek komut ve Studio test yönergeleri README'dedir. Testler client arayüzünü render etmez,
gerçek DataStore kotasını taklit etmez; bu sınırları geçilen kontrol olarak yorumlama.

## Sonraki kabul sırası

1. Ayrı Studio test place'inde dünya/sanitizer testi; plugin oluştur → geri al → tekrar oluştur.
2. Normal oyunda MaxPlayers 6, iki client: ada sahipliği, izinsiz toplama, alım, ayrılma/yeniden giriş.
3. Ayrı yayınlanmış test deneyiminde iki sunucu/aynı profil sahipliği ve DataStore kesinti senaryoları.
4. Telefon portre/yatay, tablet, PC ve gamepad: Pazar/Yol Haritası/Çiftliğim, uzun metin,
   hızlı tıklama, bekleyen yanıt, pencere odağı, döndürme ve streaming tekrar giriş.
5. Tüm yükseltmeler + dolu balık kafesi: değiştirme, yetişkinlik geçişi, sipariş teslimini tekrarlama,
   yeniden girişte sipariş devamı ve çevrimdışı depo sınırı.
6. 6 dolu çiftlikle düşük/orta/yüksek kalite ve fırtına altında CPU/GPU/bellek ölçümü;
   gözlenen darboğaza göre sonraki optimizasyon. Ses içeriği ve kalıcı analitik ayrı ürün işleri.
