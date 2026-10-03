# Rebirth, altın ve Robux geliştirme raporu

Başlangıç: 3 Ekim 2026, `main` / `dace9fd`. Çalışma dalı: `codex/rebirth-altin-robux`. Önceden bulunan `OYUNCU_AKISI_INCELEMESI.md` korundu. Commit, push, yayınlama veya veri sıfırlama yapılmaz; son yayın ve yönetici sıfırlaması kullanıcıdadır.

## Uygulama sözleşmesi

- Rebirth: altı çiftlik ve temaya uygun temel yükseltmeler; seviye/ırk zincirleri hariç. Etki seçmeden sıfırlama yok; tur kimliğiyle eski istek reddedilir.
- Nakit, çiftlik ilerlemesi, stok/siparişler ve nakit ekipman tur içidir. Altın, kalıcı sahiplik, rebirth etkileri, tercihler ve finansal günlükler hesap düzeyindedir.
- Günlük seri ve bugünkü alınmış ödül işareti korunur. Para kazanma başarımı yeni turun kazancını ölçer; ömür boyu toplam ayrıca korunur.
- Mevcut nakit eşya yolları, Taç dahil, korunur. Aynı ekipman altınla kalıcı edinilebilir. Bu seçim geri alınabilir; henüz kapatılmamış nakit Taç kararını kullanıcı adına kaldırmaz.
- Altın: ana ada dahil dört ada/çiftlik; 20 ada, 50 çiftlik başlangıç ayarı. Tamamlanma temel yükseltmelerle aynı koşulu kullanır. Günlük nakde çevirme kotası UTC gününde 200, tur kotası 600; günlük kota rebirth ile yenilenmez.
- Kalıcı ekipman × rebirth gelirinin sınırı 3; tur 2x bu sınırın dışında. Mevcut kalıcı 2x geçidi ile yeni tur 2x aynı gelir avantajını iki kez çarpmaz.
- Geri Dönüş: 24 saat gerçek zaman, yalnız ilk çiftliğin ineği. İkinci çiftliğin satın alınmasıyla kesin sona erer; eski çiftliğe dönmek yenilemez.
- Kalıcı nakit dönüşüm referansı: sahip olunan çiftliklerin en yüksek nötr, yetişkin potansiyel geliri; geçici bonuslar/görev/hava hariç. Nakit önizleme değiştiyse işlem yeni tutarı onaylamadan tahsil edilmez.
- Ek tılsım yuvası/aura/kaplama gibi yeni model veya slot sözleşmesi isteyen taslaklar ilk sürüm kapsamına sessizce alınmaz. Rebirth rozeti ve etkiler mevcut UI ile gösterilir; kalan kapsam burada izlenir.
- Robux kimlikleri kullanıcı tarafından sağlanana kadar 0 ve satış kapalı. Fiyatlar uydurulmaz. Makbuzla ödül aynı kalıcı işlemde; kayıt doğrulanmadan platform onayı yok.
- Opsiyonel uyumlu kayıt alanları güvenli varsayılanla eklenir; sırf bu alanlar için göçsüz sürüm sıfırlaması yapılmaz. Yönetici genel sıfırlaması rebirth'ten ayrı, mevcut arşivli veri çağı işlemidir.

Başlangıç ayarları ürünün kesin optimumu değildir. Ücretsiz ve ekipmanlı/Robux hızlandırıcılı simülasyonlarla değerlendirilecek; canlı oyuncu ölçümü ayrıca gereklidir.

## Aşamalar

| Aşama | Durum | Sorumluluk / çıktı |
|---|---|---|
| Başlangıç ve sözleşme | Tamamlandı | Rehberler, plan/kod farkları; başlangıç Luau regresyonu başarılı |
| Ekonomi çekirdeği | Tamamlandı | Alt ajan: Config, tamamlanma/altın/perk ve FarmMath etkileri |
| Kayıt ve sunucu | Tamamlandı | Alt ajan: codec, kalıcı hesap işlemi, altın/rebirth Remote ve reset |
| Oyuncu arayüzü | Tamamlandı | Alt ajan: altın, kalıcı market, süre atlama, etki seçimi ve açık sıfırlama özeti |
| Robux ve simülasyon | Tamamlandı; satış kapalı | Ana ajan: makbuz etkileri, ürün tanımları, gerçek ekonomi simi |
| Entegrasyon ve regresyon | Tamamlandı | Tip/lint/derleme, mali tekrar/kesinti ve aynı koşulda 15 süre karşılaştırması |
| Studio ve yayın kontrolü | Kısmen doğrulandı | Yerel açılış/altın penceresi doğrulandı; cihaz/çoklu oyuncu/gerçek ödeme kalan |

## Bulunan sorunlar ve uygulanan çözümler

| Kanıt / sorun | Değişiklik ve gerekçe |
|---|---|
| Taslakta rebirth/altın vardı; oyun, kalıcı sahiplik ve tamamlanma sözleşmesini uygulamıyordu | Tek Config, ortak Progression, sunucu servisi ve iki HUD penceresiyle uçtan uca bağlandı |
| Yalnız etkin çiftliğe bağlı gelir paketi, gelişmiş çiftliği olan oyuncuya düşük değer verebilirdi | Altın ve gelir paketi en yüksek kalıcı referansı kullanır; canlı görev/hava/geçici bonusla dönüşüm değeri oynanmaz |
| Aynı ada ödülü tekrar kontrol/reload ile yeniden verilebilirdi | Tur başına 30 sabit claim kimliği, tam ödül sığmıyorsa claim tüketmeme ve rebirth öncesi son tahsilat |
| Rebirth, günlük kota/ödül/asa kullanımını yenileyerek sınırsız aynı gün fayda verebilirdi | UTC günlük çevirme kotası, giriş ödülü ve asa kullanım kayıtları korunur; tur kotası ayrı sıfırlanır |
| Başarımlar yeni turda eski ömür boyu kazançla anında tekrar alınabilirdi | Tur başlangıç kazancı baz alınır; ömür boyu toplam silinmez |
| Altın tahsilatı ile hak ve makbuz işaretinin ayrı kaydı para/hak kaybı yaratabilirdi | Hesap mutex'i ve kalıcı checkpoint; belirsiz yazımda rollback yerine retry; kayıt olmadan platform onayı yok |
| Yüksek gelirde parti miktarı üst sınıra takılıp minimum nominal getiri sağlanamıyordu | Parti miktarı korunur; miktar tavanındaki açık ayrı nakit karşılıkla tamamlanır. Depo taşmasının indirimli hızlı satışı korunur; depo tercihi telafi edilmez |
| Return bitişini yalnız son anın katsayısıyla hesaplamak offline kazanç/büyümeyi bozabilirdi | Başlangıç, bitiş ve görev sınırlarıyla aralık hesabı; büyüme ilerlemesi gerçek bitişte korunur |
| Kalıcı 2x geçidi ile tur 2x ve eşya/rebirth çarpanları katlanabilirdi | Geçit/tur aynı 2x'i bir kez uygular; kalıcı eşya × rebirth tavanı 3; UI gerçek ek gelir etkisini gösterir |
| Eski tur, değişmiş fiyat veya yeni işe eski bitirme isteği uygulanabilirdi | expectedRun, beklenen nakit/bedel, üretim UID ve eklenti bitişi sunucuda doğrulanır |
| Ayrı ödenmiş ikinci kalıcı ürün veya geç teslim edilen 2x boşa gidebilirdi | Kalıcı ürün için altın eşdeğeri; aktif/tamamlanmış turdaki 2x için sonraki tur kredisi; kapasite yoksa erteleme |
| Yeni tamamlanma kontrolünü her defasında bütün Config yükseltmelerini tarayarak kurmak ek maliyet yaratıyordu | Referans tarama ile ölçülüp gereken kimlikler başlangıçta hazırlandı; sonraki kontrolde yalnız gerekli listeler taranır |
| Bir oyuncunun kalıcı kayıt bekleyişi bütün oyuncuların ilerleme döngüsünü bekletebilirdi | Oyuncu başına ayrı worker ve in-flight guard; işler birikmez, hata sonrası guard temizlenir. Yavaş ilk oyuncu/ilerleyen ikinci oyuncu senaryosu test edildi |

Üretim başlangıç maliyeti job kaydında saklanır; eski job'lar uyumlu varsayılanla yüklenir. Kalıcı eşya, çevrimdışı gelir hesaplanmadan önce envantere eklenir. İlk hayvan ve yeni ada mevcut kutlama panosuyla gösterilir; ilk snapshot/çiftlik geçişi/rebirth tekrar kutlama üretmez.

## Oyuncuya sunulan yapı

- Altın göstergesi: cüzdan ve R sayısı; pencerede kazanım açıklaması, günlük/tur kotası, nakit önizlemesi, kalıcı teklifler ve süre bitirme.
- Rebirth: yalnız altı çiftlik hazırsa menü; sekiz etki, beşer seviye, sıfırlanacak/kalacak özet ve ayrı onay. Kırk seçim sonrası prestij devam eder.
- Kalıcı teklif: mevcut on eşya ve üç kolaylık. Altın Taç, Elmas Çekiç, son asalar ve tılsımlar mevcut model/etkileriyle kullanılır. Yeni mesh yoktur.
- Kalıcı sahiplik ve bu tura ait eşya Envanter/Pazar'da ayrılır. Nakit yolları korunur; kalıcı alımın tekrar tahsilatı engellenir.
- Robux: 100/500/1500 altın, tur 2x, mevcut gelir/üretim ürünleri ve kalıcı teklifler. Kimliği 0 olan ürün görünür satışa çıkarılmaz.
- Beş dilde 137 yeni çeviri; toplam 1343 sözlük anahtarı ve 623 Config metni kapsamı.

## Denge ve süre ölçümü

`simulate-rebirth.py` gerçek Config/FarmMath/ProductionLogic kodunu kullanır. Aynı persona, satın alma politikası, altı çiftlik ve temel tamamlanma koşuluyla karşılaştırılır. Varsayılan ekipman politikası ilk yararlı kalıcı alım olarak 600 altınlık Elmas Çekiç'i seçer. Ölçüm takvim günüdür:

| Senaryo | İdeal, sürekli açık | Günlük 3×20 dk | Günlük 2×10 dk |
|---|---:|---:|---:|
| R0, altın biriktir | 5,15 | 19,00 | 33,50 |
| R0, kazanılan altınla ekipman al | 4,89 | 18,00 | 32,00 |
| R1, yalnız gelir seviyesi 1 | 4,72 | 17,67 | 31,00 |
| R1, gelir seviyesi 1 + önceki turdan 780 altınla ekipman | 4,18 | 15,00 | 26,50 |
| R10, gelir/büyüme 5; önceden ekipman/yardımcı + tur 2x | 0,75 | 3,33 | 6,50 |

İdeal oyuncunun ilk turu yaklaşık 123,62 aktif saattir. Günlük bir saat senaryosunda ilk tur 19 aktif saat, birikimli R1 turu 15 aktif saattir. Son hızlandırılmış senaryo ekipmanı/perkleri önceden varsayar; bunları edinmek için gereken geçmiş turları ve Robux harcamasını ölçmez. Ücretsiz oyuncu da aynı kalıcı ekipmanı altınla edinebilir.

Yalnız ilk gelir seçimi yüzde 7–8 hızlanma sağlar; eski taslaktaki yüzde 15–25 hedefini tek başına karşılamaz. Önceki turun birikimi + indirim ekipmanı birlikte yaklaşık yüzde 19–21 hızlanma sağlar. Bu nedenle sırf hedef yüzdesine ulaşmak için görünmez başlangıç çarpanı eklenmedi. İlk tur uzunluğu ve hangi etkinin seçildiği canlı kullanıcıyla ölçülmelidir; değerler kesin optimum değildir.

Eski tüm-yükseltme simülasyonuyla bu tablo karşılaştırılamaz: temel filtre çiftlikten daha erken ayrıldığı için park edilmiş çiftliğe daha az yatırım bırakır, sonraki çiftliklerin gelirini de değiştirir. “Daha az tamamlanma şartı her koşulda daha hızlı tur” iddiası yapılmaz.

Tekrar çalıştırma: `python scripts/simulate-rebirth.py --output .test-build/rebirth-comparison.json`. Altın çevirme politikası ayrıca `--scenarios free_convert` ile ölçülebilir; bu tabloda yoktur. Rastgele keşif, hareket süresi, oyuncunun tercih hataları ve canlı sunucu yükü tam modellenmez.

## Performans ölçümü

24 tamamlanmış ada, aynı Config, 1000 tekrar, beş örnek. Tüm yükseltmeleri tarayan eşdeğer referans uygulamanın medyanı 349,26 ms; yeni hazır gerekli kimlik listesi 3,45 ms: bu mikroölçümde yaklaşık yüzde 99,01 azalma. Referans, önceki main sürümünün üretim profili değil, yeni tamamlanma işleminin doğrudan tarama alternatifidir. Çıktı ve kaynak `.test-build/audit-progression-benchmark/` içindedir. Maliyet: başlangıçta sabit farm/ada listeleri ve kimlik referansları. Bu **oyunun FPS veya gerçek sunucu kare süresi ölçümü değildir**; bütün oyun için yüzde 99 hızlanma iddiası yapılmaz.

## Doğrulama kaydı

- Başlangıç: `python scripts/run-tests.py` başarılı; mevcut 44 saf Luau regresyon grubu geçti. Bu kontrol yeni kod uygulanmadan çalıştırıldı.
- Önceki oyuncu raporundaki tüm-yükseltme süreleri rebirth koşuluyla farklıdır; karşılaştırma için aynı filtre/politika kullanılacak.
- Saf Luau: gerçek finansal codec/reset, actual sunucu Remote, gerçek PDS kesinti/retry, makbuz ve gerçek UI fabrikası senaryoları geçti. Test beklentileri gevşetilmedi; goods taşma hesabı yeni ayrı karşılığı açıkça doğrular.
- Studio yerel Play: `WorldReady=true`, `DataStatus=Active`; altın ve kalıcı teklif sekmeleri açıldı, boş cüzdanda çevirme devre dışı, tamamlanmamış oyunda rebirth karosu gizli. Açılış/sekme kontrolü boyunca konsolda hata görülmedi. Studio kayıtsız test modundaydı; hesap/reset verisi değiştirilmedi. Test sonunda Edit moduna dönüldü.
- Son toplu `powershell -ExecutionPolicy Bypass -File scripts/verify.ps1 -RequireTypes`: **başarılı**, 4 Ekim 2026. 48 Luau spec çağrısı; 8 tip denetleyici + 11 model denetleyici Python testi; StyLua/Selene; Luau derleme; görsel servis kimlik testi; ekonomi ve rebirth smoke; ekonomi denetimi; ideal/casual/idle kademe monotonluğu; locale/Config; AI rehber; mimari; tip analizi (0 bulgu); oyun/eklenti/test Rojo derlemeleri geçti.
- Model kapsamı: 745 beklenen görünüm, 0 eksik, 0 bozuk dosya. Bu dosya/sözleşme doğrulamasıdır; gerçek cihazda render ve sanat kalitesinin onayı değildir. Studio görüntüsünde dünya ve eşya ViewportFrame render kalitesi bu otomasyonla kesin doğrulanamadı; UI sekmeleri/metinleri kontrol edildi.
- Selene yeni Roblox API dump'ını ağ nedeniyle alamadı; mevcut önbellekle lint yaptı ve 0 hata/uyarı verdi. Tip araçları mevcuttu; tip adımı atlanmadı. `git diff --check` ve değişen Python araçlarının bytecode derlemesi geçti.
- Son 15 karşılaştırma final ekonomi kaynaklarıyla tekrar üretildi; yukarıdaki tablo aynı sonuçları verdi. Ayrıntılı yerel çıktılar: `.test-build/rebirth-final-verify.log`, `.test-build/rebirth-comparison.json`. Bunlar geçici/ignore edilen doğrulama çıktılarıdır; kalıcı sonuç kaydı bu belgedir.

## Yayın öncesi açık işler

1. Creator Hub'da ürün ve fiyatları oluştur; `Config/Shop.products` içindeki ürün `id` alanlarını, kalıcı teklifler için `Config/Progression.permanentOffers` satırındaki opsiyonel `robuxProductId` alanını doldur. Eksik/0 kimlik altın/rebirth'i engellemez, Robux satışını kapalı tutar. Oluşturulan anahtar `permanent_<offerId>` olur; init içinde elle kimlik yazılmaz.
2. Özel test place'inde iki oyuncuyla altı çiftlikten rebirth ve dünya yeniden kurulumu; ayrılma/yeniden giriş, aynı gün asa/kota, kalıcı ekipman doğrulaması.
3. Telefon ve gamepad'de sekme/scroll/onay/iş seçimi; gerçek satın alma makbuzu, gecikmiş teslim ve kayıttan sonra reconnect.
4. Canlı DataStore'un budget/response-loss davranışı ve sunucu kapanışı: gerçek platform arızası burada enjekte edilmedi; sahte servislerde bu senaryolar test edildi.
5. Fiyat değişikliğine karar vermeden önce ilk hayvan, ilk ada, ilk çiftlik, altın harcama ve rebirth sürelerini gerçek kullanıcı telemetrisiyle ölç.
6. Bunlar onaylandıktan sonra kullanıcı temiz yayını ve yönetici sıfırlamasını yapar. Yayından önce eski üründen alınmış hakkın hangi ortamda kalacağı/sıfırlanacağı kontrol edilir; genel reset, rebirth'in kalıcı hak korumasıyla aynı işlem değildir.

R5 ek tılsım, R10 aura, R25 sipariş yuvası, yeni gezgin tüccar ürünleri ve ayrı kozmetik kataloğu uygulanmadı. Mevcut ekipman ve tüccar korundu; bunlar tamamlandı diye raporlanmaz. Commit, push, main merge, canlı yayın ve genel sıfırlama yapılmadı.
