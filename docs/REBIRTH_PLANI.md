# Rebirth planı

Durum: **çekirdek uygulandı**, 4 Ekim 2026. Güncel teslim ve doğrulama kaydı: [REBIRTH_GELISTIRME_RAPORU.md](REBIRTH_GELISTIRME_RAPORU.md).

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

30 turu gerçek sıfırlamayla ve hesap haklarını taşıyarak ölçmek için `python scripts/simulate-rebirth-campaign.py` kullanılır. Son doğrulama ve sınırlar: [REBIRTH_30_DOGRULAMA.md](REBIRTH_30_DOGRULAMA.md).

## Tarihsel taslak

Aşağıdaki özgün taslak karar geçmişi için korunmuştur. **Yukarıdaki uygulama sözleşmesi geçerlidir**; aşağıdaki eski dosya adları, sürüm artırma, kozmetik ve süre önerileri uygulanmış özellik veya sonraki iş talimatı değildir.

İlgili belgeler: `docs/ROBUX_VE_ALTIN_PLANI.md` (eşya etkileri, altın, Robux marketi; Robux ile alınanlar ve altın rebirth'te kalır), `docs/ZORLUK_VE_FIYAT.md` (çiftlik süreleri), `docs/DURUM_RAPORU.md` (K2 Robux), `.cursor/rules/economy-data.mdc` (kayıt şeması).

## 1. Amaç
Altı çiftliği bitiren oyuncu, oyunu baştan oynarken **her turda bir öncekinden hızlı ama farklı** ilerlesin; aynı ilk saatleri aynı biçimde tekrar yaşayıp sıkılmasın.
Rebirth sayısı sadece sayaç değil, **oyuncunun sahip olduğu kalıcı etki sayısıdır** (her rebirth = bir seçim).

## 2. Kararlar (kullanıcı)
- Rebirth **altı çiftlik bitince açılır**. "Bitti" = altı çiftliğin hepsi satın alınmış ve her birinin tüm yükseltmeleri (ırk/seviye zinciri hariç; sim'deki "TÜM YÜKSELTMELER" ölçüsü) alınmış (`FarmMath.isFarmComplete`, `FarmMath.canRebirth` yazılacak).
- Rebirth'te **her şey sıfırlanır**, başarımlar dahil. Oyuncunun rebirth hanesine 1 yazılır.
- Her rebirth **kalıcı bir etki** (ya da etki veren kozmetik) kazandırır.
- Her rebirth sonrası kısa süreli (1 gün) **Geri Dönüş bonusu** ilk adadan başlamayı hızlandırır.
- Rebirth'e özel bir **menü** vardır: yalnızca rebirth açıkken görünür; "Etki seç ve sıfırla" akışı. Seçim yapılmadan sıfırlama olmaz.

## 3. Akış (öneri eklerimle)
1. **Hazır olunca** sağ orta menü sütununda (`MenuBar`) **Rebirth** karosu belirir (altı çiftlik bitene kadar yok; ipucu satırı "Rebirth hazır" der). Karo hafifçe parlar ama kalıcı bildirim yapmaz.
2. Pencere **"Rebirth"** (`Ui/Hud/RebirthWindow`): üstte şu anki rebirth sayısı ve sahip olunan etkiler, ortada **etki havuzu** (kartlar: ad, seviye n/N, bir sonraki seviyenin etkisi), altta özet.
3. Oyuncu bir kart seçer. Altta **özet**: "Sıfırlanacak: para, çiftlikler, hayvanlar, yükseltmeler, eşyalar, ırk, başarımlar. Kalacak: rebirth, etkiler, kozmetikler, ayarlar." ve bu turun süresi/kazancı (hesaplanan, bilgi amaçlı).
4. **"Etki seç ve sıfırla"** düğmesi; basınca ikinci onay ("Emin misin? Geri alınamaz"). Seçilmeden düğme `disabled`.
5. Sunucu **tek adımda** seçimi uygular ve sıfırlar (atomik; yarım kalırsa hiçbiri). Ardından istemciye kutlama ve yeni oyun; Geri Dönüş bonusu başlar.
6. Eklediklerim: (a) sıfırlamadan önce **kayıt yedeği** (`SaveBackup`); (b) seçim ve sıfırlama **aynı remote** (`RequestRebirth(perkId, requestId, expectedFarmId)`), çift tıklama/tekrar gönderim `requestId` ile engellenir; (c) tüm etkiler tavandaysa kart yerine "Prestij" kozmetik seçimi çıkar (oyun tıkanmaz); (d) oturum sunucuda sıfırlama sırasında koparsa kayıt ya eski ya yeni haldedir (atomik kayıt).

## 4. Rebirth sayısının anlamı
- **Sayı = kalıcı etki sayısı** (her rebirth bir seçim; aynı etkiyi tekrar seçmek seviyesini artırır, tavan var).
- **Gösterim:** `StatsPanel`'de para satırının altında (para = `iconChip`+yeşil sayı) bir **Rebirth rozeti**: `UiKit.iconChip` (altın ton) + "R3" (`UiKit.badge`); üzerine gelince seçilmiş etkiler listelenir. Emoji yalnızca ikon kutusunda (kural). Oyuncu adının üstünde de küçük rozet (sunucuda `WorldUi.tag`).
- **Dönüm noktaları** (rebirth sayısına bağlı kozmetik, ücretsiz kazanılan): R1, R3, R5, R10, R25 (taç/aura/iz). Kozmetik rebirth'te kalır, Robux'la satılan kozmetiklerle aynı sistemden gösterilir.
- **Liderlik/tabela:** ada tabelasında "Rebirth N" (isteğe bağlı, ikinci aşama).

## 5. Neler sıfırlanır, neler kalır
Kaynak: `FarmProfiles` (çiftlik alanları) ve hesap düzeyi alanlar (`SaveCodec/Account`, `economy-data.mdc`).

| Sıfırlanır | Kalır |
|---|---|
| `cash`, çiftlik alanları (`stored`, `purchased`, `lineage`, `expansions`, `animals`, `production`, `autoRepeat`, `barnLevel`, `unlockedIslands`, `unlockedZones`), tüm `mainFarms` (yalnızca Çiftlik 1 kalır) | `language`, `graphics`, `audio`, `reducedMotion` |
| `inventory` (eşyalar), `goods` (ahır stoğu), `contracts` | `receipts` (Robux makbuzu çift işlenmesin), `passes` (çalışma anı, MarketplaceService'ten gelir) |
| `achievements` (kararı: sıfırlanır), `seasonal`, `daily` seri hedefi* | `rebirth` (sayı, etkiler, kozmetikler, Geri Dönüş bitişi) |
| `merchant`, `golden` zaman pencereleri sunucu saatinden türer, ayrıca sıfırlama gerekmez | `lifetimeEarned` (telemetri; rebirth `lifetimeEarned`'ı sıfırlamaz) |

\* Günlük giriş serisi gerçek zamanlı bir sadakat sayacıdır, ilerleme değil: **öneri olarak kalır** (rebirth'te seri bozulmasın). İstersen sıfırlanır.

Rebirth çekirdeği `Modules/Rebirth` (saf mantık: `canRebirth`, `applyReset`, etki seviyeleri) + `Services/RebirthService` (remote, hız sınırı, `RequestGuard`, yedek, telemetri) olur; `PlotService` Çiftlik 1'i yeniden kurar.

## 6. Kalıcı etki havuzu (taslak, sim'le ayarlanır)
Her etki seviyeli, **tavanlı** (örnek tavan 5). Gelir dışındaki etkiler mevcut `Core.getBonus`/`getGrowthSpeed` toplama sistemine girer (katlanmaz). **Gelir etkisi** eşyanın `incomeBonus`'una katılmaz, ayrı bir çarpandır (`ROBUX_VE_ALTIN_PLANI.md` bölüm 4b: eşya x rebirth için kalıcı üst sınır, Altın Taç gelir çarpanı dahil).

| Etki | Seviye başına (taslak) | Not |
|---|---|---|
| Gelir | +%8 | `incomeBonus` toplamına |
| Büyüme hızı | +%6 | `getGrowthSpeed` artı toplamına (KNEE/CAP korunur) |
| Başlangıç kasası | ilk hayvan fiyatının +2 hayvanı | `Config.getStartingCash`'a |
| Açılış indirimi | +%3 (tavan %15) | `upgradeDiscount` |
| Tesis hızı | +%5 | `facilitySpeed` |
| Çevrimdışı | +%5 oran, +0,5 saat | `OFFLINE_MAX_TOTAL_RATE` korunur |
| Sipariş ödülü | +%4 | `contractBonus` |
| Hazır başlangıç | S1 otomatik toplayıcı baştan, S2 ilk ada açık hayvanla, ... | tek seferlik "kolaylık"; en küçük etki |

Havuz tamamen dolunca (8 etki x 5 = 40 rebirth) prestij kozmetik seçimi çıkar. Toplam kalıcı gelir çarpanı (eşya x rebirth) `ROBUX_VE_ALTIN_PLANI.md` bölüm 4b'deki tavana/knee kuralına (`GROWTH_SPEED_KNEE` benzeri) tabidir; Robux tur 2x'i bu sınırın dışındadır.

## 7. Geri Dönüş bonusu (geçici)
- **Süre:** 24 saat gerçek zaman (çevrimdışıyken de akar), her rebirth'te yenilenir.
- **Kapsam:** yalnızca **Çiftlik 1'in ana hayvanı** (inek) geliri x3 ve büyüme hızı +%50; Çiftlik 2'ye geçince etki biter. Amaç: ilk adaya kadar olan ~12 dk ve ilk saatler kısalsın, geç oyun etkilenmesin.
- **Birleşim:** bu bonus yalnızca Çiftlik 1 ana hayvanını etkiler ve referans gelire girmez; gelir çarpan zinciri ve toplam sınır için `ROBUX_VE_ALTIN_PLANI.md` bölüm 4b.

## 8. Hedef tur süreleri (sim hedefi)
`simulate-tiers.py`'ye `--rebirth N` eklenir; ideal/casual/idle için tur süresi ölçülür.
- İlk rebirth turu bir öncekinin ~%75-85'i, sonraki turlar azalan oranla (her tur ~%5-8 daha kısa), taban: ilk turun ~%35'i (ideal ~1,4 gün altına inmesin).
- Çiftlik süreleri turlar arasında 1,5x/kademe oranını korur (`assert-monotonic`).
- Etki havuzu hangi sırayla seçilirse seçilsin (en hızlı sıra = hep gelir+büyüme) taban süre aşılmaz.

## 9. Robux ile ilişki
- **Tur boyunca 2x gelir** (dev ürünü, ucuz): `save.rebirth.run` altında tutulur, rebirth'te sıfırlanır; oyuncu her turda tekrar alır. Kalıcı geçit olarak satılmaz.
- **Üretimi tamamla** (dev ürünü, ucuz) ve kısa süreli güçlendirme: tur içi, rebirth'te sıfırlanır.
- **Eşyalar** (karar güncellendi, bkz. `ROBUX_VE_ALTIN_PLANI.md`): etkisiz eşya kalmadı (şapka/sırt dahil hepsi etki verir). Nakitle alınanlar (şapka, sırt, çekiç, Çoban Asaları, alt kademeler) rebirth'te sıfırlanır; son seviye eşyalar (Altın Taç dahil) Robux ya da altınla alınır ve **kalıcıdır**. Etkisiz kozmetik (aura, iz, kaplama) ayrı Görünüm sekmesindedir, kalıcıdır. Altın hesap düzeyinde kalır.
- **Satılmaz:** rebirth'in kendisi, rebirth etkisi, doğrudan çiftlik/yükseltme açılışı.

## 10. Uygulama adımları
1. `docs` (bu belge) + `ECONOMY_LIMITS` içine rebirth sınırları.
2. **Sim:** `simulate-economy.py`/`simulate-tiers.py` `--rebirth N` ve etki seçimi (en hızlı sıra). Bonus sayıları buradan.
3. **Kayıt:** `GameTypes` + `SaveCodec/Account` (`rebirth`), `SessionLock.VERSION` artar (eski kayıt temiz yeni oyuna döner; göç yok).
4. **Mantık:** `Modules/Rebirth` (+ `FarmMath.isFarmComplete/canRebirth`, etki toplama), `Services/RebirthService` (`RequestRebirth`, `Remotes.luau`).
5. **Arayüz:** `RebirthWindow`, `MenuBar` karosu (koşullu), `StatsPanel` rozeti, kutlama; metinler en/de/ru/es/pt (`roblox-localize`).
6. **Testler:** `tests/rebirth.spec.luau` (neyin sıfırlandığı/kaldığı, atomiklik, tavan, çift gönderim, etki toplama), `config.spec` (havuz tutarlılığı), sim "tur süresi" değişmezleri; `check-architecture` katman kuralları.
7. **Robux:** tur ürünleri (`save.rebirth.run`) ve kozmetik satış, `MonetizationService` yeni etkiler.

## 11. Riskler ve açık noktalar
- Rebirth sırasında `PlotService` Çiftlik 1'i yeniden kurmalı (çok çiftlikli kayıt tek çiftliğe iner): Studio'da denenmeli.
- Etki toplamı: Robux 2x ve geçici bonus birleşince knee ile sınırlanmalı; rakamlar sim'le doğrulanmadan sabitlenmez.
- Günlük seri kalsın mı (öneri: kalır).
- İlk rebirth hedef süresi (ideal 4 gün, casual 16 gün, idle 29 gün) rebirth'e çok geç ulaştırıyor: casual/idle için ara ödül gerekebilir (ör. Çiftlik 3 bitince küçük kozmetik); ayrı karar.
