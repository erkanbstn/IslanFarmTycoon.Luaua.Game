# Rebirth planı

Durum: **çekirdek uygulandı**, 4 Ekim 2026. Güncel teslim ve doğrulama kaydı: [DEVIR_DURUMU.md](DEVIR_DURUMU.md).

## Uygulanan sözleşme

- En çok **30 rebirth** yapılır. İlk beş tur altı çiftliğin temel yükseltmelerini ister; sonraki turlar ana ağıl, soy, para tesisi ve uzman ada ağıllarını kademeli geliştirir. Gereksinimler `Config/Progression.completionRequirements`, ortak karar `Progression.isRebirthFarmComplete` / `canRebirth` içindedir. Temel tamamlanma altını bu ek hedeflerden bağımsızdır.
- Sekiz etkiden biri seçilir; her biri beş seviyelidir. Ayrıca her R seviyesi otomatik, sınırlı kalıcı kazanım verir. R6/12/18/24/30 beş ücretsiz kalıcı ekipman kazandırır; satın alma yolu yoktur. R30 sonrası sıfırlama kapanır, mevcut çiftliklerde oyun sürer. Eski R40 kayıtları ve hakları silinmez. Tek kaynak `Config/Progression.luau` içindedir.
- Hazır Başlangıç sırasıyla otomatik toplayıcı, yetişkin ana hayvan, ilk küçük adanın açılışı, ikinci ve üçüncü yetişkin ana hayvan verir. Açılış, adanın bütün yükseltmelerini ücretsiz tamamlamaz.
- Nakit, çiftlikler, hayvanlar, yükseltmeler, stok, sipariş, tur ekipmanı ve başarımlar sıfırlanır. Altın, kalıcı sahiplik, makbuz/aktarım günlükleri, tercihler ve ömür boyu kazanç korunur. Günlük giriş serisi, bugünkü ödül ve asaların günlük kullanım sınırları korunur.
- Geri Dönüş 24 saat gerçek zaman boyunca yalnız ilk çiftliğin ineğini etkiler. Herhangi başka bir çiftlik satın alınınca kesin biter; ilk çiftliğe dönmek süreyi yenilemez. Çevrimdışı gelir ve büyüme, bonusun başlangıç/bitiş sınırlarında ayrı hesaplanır.
- `Modules/Rebirth` saf sıfırlama mantığıdır; `Services/ProgressionService` altın ve rebirth Remote'larını yönetir. `SaveCodec/Financial` hesap alanlarını doğrular. Uyumlu opsiyonel alanlar nedeniyle kayıt sürümü artırılmadı; eski kayıt silinmez.
- `PlayerDataService.transactAccount` önce bekleyen kaydı doğrular, hesabı işlemlere kilitler ve tek kalıcı snapshot yazar. Başarısı belirsiz yazımda eski veriye dönülmez; tekrar kayıt yapılana kadar kilit korunur. Arayüz/dünya güncellemesi kayıt doğrulanınca yapılır.
- HUD altın/R sayacı, ilk hayvan sonrası incelenebilir Rebirth menüsü, mevcut/sonraki ödül, 30 seviyelik yolculuk, hedefler ve ayrı sıfırlama onayı vardır. Gelir önizlemesi takılı eşyanın tavanından sonra gerçek ek kazancı gösterir.
- Otomatik ödüller gelir enflasyonu yaratmaz: R30 toplamı depo +%15, tesis hızı +%7, sipariş +%8, çevrimdışı oran +2 puan ve süre +30 dakika, başlangıç +2 hayvan bedeli, tamamlama altını +%20, altınla bitirme indirimi %15'tir. Ekipman etkileri yuva seçimine tabidir.

## Süre kararı

İlk hedef yüzde 75–85, otomatik garanti değildir. Yalnız +%8 gelir seçimi, simülasyonda turu yaklaşık yüzde 7–8 kısaltır. Önceki turdan saklanan 780 altınla Elmas Çekiç edinmek ve aynı gelir etkisi, günlük bir saat oynayan senaryoyu 19 günden 15 güne indirir. Böylece ücretsiz birikim sonraki turu da hızlandırır. Tam koşullar ve hızlandırılmış senaryolar geliştirme raporundadır; canlı oyuncu verisi henüz yoktur.

`python scripts/simulate-rebirth.py` gerçek Config/FarmMath ile yeni tur başlangıçlarını karşılaştırır. Tarihsel `simulate-tiers.py` tüm yükseltme ölçüsü ayrı kalır; rebirth koşuluyla aynı sayılmaz.

30 turu gerçek sıfırlamayla ve hesap haklarını taşıyarak ölçmek için `python scripts/simulate-rebirth-campaign.py` kullanılır. Son doğrulama ve sınırlar: [DEVIR_DURUMU.md](DEVIR_DURUMU.md).
