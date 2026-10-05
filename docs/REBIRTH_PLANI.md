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

İlk hedef yüzde 75–85, otomatik garanti değildir. Yalnız +%8 gelir seçimi, simülasyonda turu yaklaşık yüzde 7–8 kısaltır. Altın artık tur içinde kazanılmaz; tek ödül rebirth ile gelir (aşağıda). Birinci tur hızı altından etkilenmediği için aynıdır; ikinci turdan itibaren R1 ödülüyle alınan kalıcı eşya turu kısaltır. Canlı oyuncu verisi henüz yoktur.

## Altın yalnız rebirth'te (5 Ekim 2026)

Ada başına 20 / çiftlik başına 50 altın (tur başı 780) kaldırıldı. Altın, bütün tur bitince (altı çiftlik tamam, rebirth hazır) rebirth işlemiyle bir kez ve atomik verilir: `gold.rebirthBase` 750 + `gold.rebirthPerLevel` 10 × o ana kadarki rebirth sayısı, `goldBonus` kilometre taşları (R3/R10, +%10'ar) çarpanıyla yuvarlanır (R1 750, R4 858, R11 1020, 30. rebirth 1248). Amaç: bir rebirth ~bir kalıcı prim eşya (350-900; Elmas Çekiç 740, altın taç 1500 hariç); daha hızlısı Robux altın paketleridir. R30'da son tur tamamlanınca aynı ödül (1260) `progression.claims.terminal` ile bir kez verilir (`ProgressionService.collect` → `Progression.collectTerminalGold`; cüzdan tavanında ertelenir). Tekrar oynatma `expectedRun` ile reddedilir. Eski kayıtlarda `island:*`/`farm:*` hak anahtarları okunurken atılır; tur ortasında tahsil edilmiş altın bakiyede kalır, tahsil edilmemiş ada/çiftlik altını artık yoktur (çifte ödeme yok). Ortak saf yardımcı `Progression.rebirthGoldReward(save)`.

Altınla bitirme (büyüme/genişletme) ve altın→nakit çevirme mantığı değişmedi; yeni oyuncuda ilk rebirth'e kadar altın yoktur, bu özellikler ilk rebirth'ten sonra ya da satın alınan altınla çalışır. Kilitlenme yoktur: rebirth altına bağlı değildir.

Erken kilometre taşları da kalıcı eşya verir (etkileri korunur): R1 Rüzgar Muskası, R2 Tüccar Şapkası, R3 Büyük Depo Muskası, R4 Büyük Büyüme Muskası, R5 Usta Tüccar Defteri (hepsi nakit+altın mağaza eşyası; çift sahiplikte Robux teslimi altın eşdeğerini öder).

Ölçüm (`scripts/simulate-rebirth.py`, aynı koşullar, takvim günü; kaynak `.test-build/rebirth-before.json` / `rebirth-after.json`):

| Oyuncu | Senaryo | Önce | Sonra |
|---|---|---|---|
| ideal / casual / idle | 1. tur (altın politikası fark etmez) | 5,26 / 19,33 / 34,00 | 5,26 / 19,33 / 34,00 |
| ideal / casual / idle | R1 sonrası tur, +%8 gelir (`r1_income`) | 4,83 / 17,67 / 29,00 | 4,83 / 17,33 / 28,00 |
| ideal / casual / idle | R1 sonrası tur, saklanan altınla ekipman | 4,23 / 15,00 / 27,00 (780 altın) | 4,23 / 14,67 / 26,50 (750 altın, `r1_reward_equipment`) |

Eski modelde ilk tur 780 altın biriktirip ilk turda zaten harcayamıyordu; yeni modelde aynı miktar rebirth anında tek seferde gelir, yani ikinci tura aynı gücü taşır (Elmas Çekiç 740 alınır, 10 altın kalır). Kampanya (casual, 3 tur, gerçek `Rebirth.apply` taşıma): ücretsiz 19,33 / 14,67 / 14,67 gün; hızlandırılmış 3,67 / 3,66 / 3,67 gün; R1 ödülü Elmas Çekiç'e gider. `r1_income` farkı R1 kilometre taşı eşyalarının modele girmesindendir. Simülasyon eşya gücünü sınırlı modeller; Studio'da gerçek oyun hissi denenmedi.

`python scripts/simulate-rebirth.py` gerçek Config/FarmMath ile yeni tur başlangıçlarını karşılaştırır. Tarihsel `simulate-tiers.py` tüm yükseltme ölçüsü ayrı kalır; rebirth koşuluyla aynı sayılmaz.

30 turu gerçek sıfırlamayla ve hesap haklarını taşıyarak ölçmek için `python scripts/simulate-rebirth-campaign.py` kullanılır. Son doğrulama ve sınırlar: [DEVIR_DURUMU.md](DEVIR_DURUMU.md).
