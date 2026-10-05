# Telemetri (canlı ölçüm)

Tüm olaylar **sunucudan** `Services/TelemetryService.luau` ile gönderilir; saf kurallar (olay adları, yuvarlama, toplama, bütçe)
`Modules/TelemetryLogic.luau`'dadır ve `tests/telemetry.spec.luau` ile sınanır. Oyuncunun gönderdiği hiçbir değer olaya girmez.

## Çalışma kuralları
- **Studio'da hiçbir olay gönderilmez** (canlı veri kirlenmesin). Yalnızca `ServerStorage.Diagnostics` sayaçları artar
  (`TelemetryEconomy`, `TelemetryFunnel`, `TelemetryCustom`, `TelemetryProgression`, `TelemetryStudioSkipped`).
  Ne gidecekti görmek için Studio'da `Workspace` özniteliği `TelemetryPrint = true` yap: olaylar Output'a yazılır.
- Tüm AnalyticsService çağrıları `pcall` içindedir; hata `TelemetryError` sayacına yazılır, oyunu bozmaz.
- Sunucu başına iç bütçe: dakikada `TelemetryLogic.EVENTS_PER_MINUTE` olay. Aşılırsa olay düşer ve `TelemetryDropped` artar
  (Roblox'un belgelenmiş bir dakikalık sınırı yok; bu değer muhafazakâr bir tahmindir, canlıda `TelemetryDropped` 0 değilse artır/azalt).
- Yüksek frekanslı kaynaklar (Toplama, Otomatik toplama, Üretim) oyuncu başına birikir ve 60 sn'de bir (ve oyuncu çıkarken) tek olay olarak gider.
- Roblox sınırları: 5 para birimi (yalnızca `Cash`), 20 işlem türü, 100 SKU, 100 özel olay adı. Test bunları denetler;
  yeni kategori/olay eklerken `TelemetryLogic`'e ekle (listede olmayan olay gönderilmez, `TelemetryUnknown*` sayılır).

## Olaylar

### Onboarding hunisi (`LogOnboardingFunnelStepEvent`, oyuncu başına bir kez)
İlk dört adım öğreticiyle (`OnboardingSteps`: hayvan, toplama, yükseltme, üretim) aynı sıradadır; sonrası uzun vadeli kilometre taşlarıdır.
| Adım | Ad | Tetik |
|---|---|---|
| 1 | First animal | İlk hayvan alımı (pazar) |
| 2 | First collect | İlk toplama (platform ya da Otomatik Toplayıcı) |
| 3 | First upgrade | İlk yol haritası yükseltmesi |
| 4 | First production | İlk üretim partisi (`ProductionService`, elle başlatma) |
| 5 | First island | İlk uzman ada |
| 6 | Barn level 2 | Ahır Sv.2 |

Eski sıra (1 First collect, 2 First animal, 3 First upgrade, 4 First island, 5 Barn level 2) hayvan almadan toplama olamayacağı için
Creator Hub hunisinde 2. adımı 1.'den önce gösteriyordu; 5 Ekim 2026'da yukarıdaki sıraya çevrildi. Canlıda eski adlarla veri toplandıysa
huni geçiş gününde bölünür (adımlar yeni numaralarla yeniden başlar); eski veri bu belgedeki sıraya göre okunmaz.

"Bir kez" için kayıt şeması değişmedi: oyuncu girince kayıttan geçilmiş adımlar çıkarılır (`TelemetryLogic.factsFromViews`:
hayvan > 0, ömür boyu kazanç > 0, alınmış yükseltme > 0, çalışan üretim partisi var, açık ada > 1, ahır ≥ 2) ve yeniden gönderilmez. Telemetriden önce oynayan
oyuncular bu yüzden hunide görünmez; yalnızca sonradan geçtikleri adımlar sayılır. Üretim adımı için tamamlanıp teslim alınmış
ilk parti kayıtta iz bırakmaz: yalnızca o sırada çalışan parti olan oyuncu "geçilmiş" sayılır, diğerleri ilk yeni partide bir kez gönderir (küçük bir fazla sayım).

### Ekonomi (`LogEconomyEvent`, para birimi `Cash`)
| Yön | İşlem türü (`transactionType`) | Kaynak kodu |
|---|---|---|
| Kaynak | Collect, AutoCollect, ParkedPay (toplayıcısız park edilmiş çiftlik; toplu, 60 sn) | `EconomyService` |
| Kaynak | Offline | `PlayerDataService.load` (çevrimdışı dönüş) |
| Kaynak | Daily, Season, Achievement, GoldenAnimal | `EngagementService` |
| Kaynak | GoodsSale | `ContractService` (ahır deposundan ürün satışı) |
| Kaynak | Order | `ContractService` |
| Kaynak | Production (toplu, 60 sn) | `ProductionService`, `PetService` (para fabrikası ödülü) |
| Kaynak | IncomePack | `MonetizationService` (gelir paketi) |
| Kaynak | Refund | `AnimalService` (hayvan satışı iadesi) |
| Gider | Animal (hayvan, balık değişimi) | `AnimalService` |
| Gider | Upgrade, Lineage, Expansion | `UpgradeService` |
| Gider | Item (dükkan ve gezgin tüccar) | `InventoryService` |
| Gider | Farm | `MainFarmService` |
| Gider | Facility (üretim başlatma) | `ProductionService`, `PetService` |

`itemSku`: hayvan kimliği (Animal, Refund, Lineage) ve yükseltme kimliği (Upgrade); diğerlerinde boş. `endingBalance` işlem sonrası bakiyedir.
Para hareketi `PlayerDataService.addCash/addRefund/trySpend`'e verilen kategori ile işaretlenir; kategorisiz hareket gönderilmez.
Yönetici (`AdminService`) para eklemeleri gönderilmez.

### İlerleme
`LogProgressionCompleteEvent` + aynı anda aynı adlı özel olay (Roblox ilerleme olayını henüz grafikte göstermiyor):
| Yol | Özel olay | Seviye |
|---|---|---|
| Islands | IslandUnlocked | açık ada sayısı |
| Farms | FarmUnlocked | sahip olunan ana çiftlik sayısı |
| Barn | BarnLevel | ahır seviyesi |

### Özel olaylar (`LogCustomEvent`, değer = sayı)
| Olay | Değer | Ne zaman |
|---|---|---|
| SessionSeconds | saniye | Oyuncu çıkarken |
| StorageFullSeconds | saniye | Çıkarken: etkin çiftlikte depo dolu (Otomatik Toplayıcı yokken) geçen toplam süre |
| OfflineSeconds | saniye | Girişte, çevrimdışı kazanç varsa: ne kadar uzakta kalındı |
| OfflineCapped | 1 | Uzaklık Pasif Gelir sınırını aştıysa (kazanç sınıra takıldı) |
| SaveFailed | 1 | Bir kayıt yazımı bütün denemelerde başarısız oldu |
| FinalSaveFailed | 1 | Çıkıştaki son kayıt başarısız (anlık görüntü bellekte tutulur, döngü tekrar dener) |
| FinalSaveAbandoned | 1 | Kilit süresi doldu, son kayıttan vazgeçildi (**veri kaybı**) |
| ProfileRecovered | 1 | Asıl kayıt bozuktu, yedekten açıldı |
| ProfileLoadFailed | 1 | Kayıt yüklenemedi (oyuncu atıldı) |
| LoadLockWait | 1 | Girişte kilit başka sunucudaydı, beklendi |
| LoopError | 1 | Gelir ya da hayvan büyüme döngüsünde oyuncu başına hata yakalandı |
| RebirthAvailable | sıradaki rebirth numarası | Altı çiftlik tamamlanıp rebirth açıldığı an (oyuncu oyundayken; zaten hazır girenler için gönderilmez) |
| RebirthDone | tamamlanan rebirth sayısı | Rebirth yapıldı |
| RebirthPerk | 1-8 (`Config.PROGRESSION.perkOrder` sırası: income, growth, starting_cash, upgrade_discount, facility_speed, offline, contract, ready_start) | Rebirth'te seçilen etki; RebirthDone ile birlikte |
| GoldGained | altın | Altın bakiyesi arttı: rebirth ödülü, ilk başarım hediyesi, Robux altın paketi (kaynak ayrımı yok) |
| GoldSpent | altın | Altın bakiyesi azaldı. Alan `CustomField01` = `source`: `item` (kalıcı teklif), `convert` (altın→nakit), `finish` (hızlı bitirme), `other` (bildirilmeyen kalan) |
| ItemAcquired | 1 | Bir eşya/kalıcı hak edinildi. Alanlar: `CustomField01` = `channel` (`cash` tur içi dükkan, `merchant` gezgin tüccar, `gold` kalıcı teklif altınla, `robux` kalıcı teklif makbuzla, `reward` rebirth kilometre taşı eşyası), `CustomField02` = `slot` (eşyanın slotu: charm, tool, head, back...; kalıcı kolaylıklar `convenience`; eşya kimliği yok) |

**Özel olay bütçesi:** 20 farklı olay adı / Roblox sınırı 100 (`TelemetryLogic.CUSTOM_EVENT_CAP`; test sayıyı ve sınırı denetler). Kaynak/kanal ayrımı yeni olay adı değil, özel alanla yapılır
(her olay en çok 3 alan; burada en çok 2). Alanlı gönderim Roblox'ta reddedilirse (`TelemetryFieldsRejected` sayacı) aynı olay alansız bir kez daha gönderilir.

`ItemAcquired` kancaları (hepsi işlem kalıcı olarak tamamlandıktan sonra, edinim başına bir kez):
`InventoryService.tryBuy` (cash), `tryBuyMerchantOffer` (merchant), `ProgressionService.tryGoldAction` "buy" (gold), `ProgressionService.tryRebirth` (reward; yalnız kilometre taşı eşyası ilk kez veriliyorsa),
`MonetizationService.processReceipt` kalıcı teklif makbuzu (robux; yalnız ilk işlenen makbuz ve hak yeni veriliyorsa: tekrar gelen makbuz ve zaten sahip olunan hak/iade yolu olay üretmez).
Bilinen eksikler: kayıt yazımı başarısız olursa (ödül bellekte, işlem "kaydediliyor" döner) olay gitmez (hafif eksik sayım, fazla sayım yok);
`ProgressionService.collect` içindeki geç rebirth eşya uzlaştırması (eski rebirth'lere sonradan eklenen ödül eşyaları) edinim sayılmaz.

`GoldSpent` kaynak ayrımı: `ProgressionService` (item, convert, finish) işlem başarılı olunca `TelemetryService.goldSpent` ile tutarı bildirir; 5 sn'lik gözlemde net düşüş, bildirilen tutarlarla (sırayla item, convert, finish; toplamı aşmadan) bölünür,
kalan `other` olur. Gözlemde tüketilmeyen bildirim sonraki pencereye taşınmaz (hesap işlemi gözlemden hemen önce bitmişse küçük bir kısım `other` görünebilir).

Son beş olay `EngagementService` döngüsünden (5 sn) `TelemetryService.observe` ile üretilir: iki anlık görüntünün farkıdır
(`TelemetryLogic.progressEvents`, ilk görüntü yalnızca başlangıç çizgisi). Aynı 5 sn'lik pencerede hem kazanç hem harcama olursa yalnızca net fark görünür.
Altın ayrı para birimi olarak gönderilmez (5 para birimi sınırı; yalnızca `Cash`); GoldGained/GoldSpent Custom Events'te toplanır.

### Hata günlüğü (Creator Hub'da görünür)
`warn` Creator Hub hata raporuna girmez. Veri kaybı riski taşıyan üç durum `TelemetryService.critical` ile `task.spawn(error, mesaj)`
olarak ayrı iş parçacığında atılır (kayıt akışı bozulmaz; dakikada en çok 20, fazlası `warn`):
`ProfileFailed` (`fail()`), `ProfileRecovered`, `FinalSaveAbandoned`. Mesajlar `[Data] ... user=<UserId>` biçimindedir.

## Creator Hub'da nerede görülür
Creator Hub → deneyim → **Analytics** (menü adları Roblox tarafından değişebilir; her olay türünün belgesi: create.roblox.com/docs/production/analytics):
- **Funnels → Onboarding**: huni adımları (veri akması ve grafik oluşması birkaç saat/gün sürebilir).
- **Economy**: Cash kaynak/gider, işlem türü ve SKU kırılımı (Sources / Sinks / Wallet).
- **Custom Events**: yukarıdaki özel olaylar (yeni olay adı listede görünmesi gecikebilir). `Progression` olayları şu an Roblox grafiklerinde yok; aynı adlı özel olaylara bak.
- **Hata/performans raporları** (sunucu betik hataları burada toplanır; canlı sunucu günlüğü için oyun içi Developer Console → Server Log): `[Data] ProfileFailed/ProfileRecovered/FinalSaveAbandoned` kayıtları. İlk canlı yayında bu kaydın gerçekten göründüğünü bir kez doğrula.

## Ürün soruları nereden cevaplanır
| Soru | Nerede |
|---|---|
| İlk 10 dakikada nerede takılıyor? | Funnels → Onboarding adım 1-4 dönüşümü; adım 2'den 3'e düşüş = para/yükseltme bekleme |
| Rebirth hunisi | RebirthAvailable → RebirthDone sayısı/oranı; RebirthPerk dağılımı (hangi etki seçiliyor) |
| Altın dolaşımı | GoldGained toplamı / GoldSpent toplamı; ilk başarım hediyesi sonrası GoldSpent'in başlaması (öğretinin işe yaradığı) |
| Sipariş teslimi | Economy → Source `Order` (olay sayısı = teslim sayısı) |
| Ürün satışı | Economy → Source `GoodsSale` |
| Dükkan (nakit) | Economy → Sink `Item` (SKU boş) |
| Dükkan (Robux) | Roblox'un kendi Revenue/Marketplace raporu; oyun içi olay yok |
| Dükkan (altın) | `GoldSpent` `source = item`; edinim sayısı `ItemAcquired` `channel = gold` |
| Hangi kanal eşya satıyor? | `ItemAcquired` kanal kırılımı (cash / merchant / gold / robux / reward); slot kırılımıyla hangi slotun satıldığı |
| Altın nereye gidiyor? | `GoldSpent` `source` kırılımı (item / convert / finish / other); `convert` baskınsa altın nakde dönüşüyor (eşya değeri düşük), `finish` baskınsa bekleme atlatılıyor |
| Gezgin tüccar işe yarıyor mu? | `ItemAcquired` `channel = merchant` sayısı / oturum |
| Rebirth ödül eşyası ulaşıyor mu? | `ItemAcquired` `channel = reward` (R1-R5 ve ödül eşyaları) |
| Geri dönüş | OfflineSeconds, OfflineCapped, SessionSeconds; günlük ödül oranı için `Daily` işlem sayısı |

Ölçülmeyenler (öneri): ürün atma (`ItemsDiscarded` yalnızca `Metrics` sayacı), eşya kimliği (kardinalite için bilerek yok; slot var), dönüş özetinin görüntülenme/etkileşim oranı.

## Dönüş özeti (OfflineSummary) ek alanları
Telemetri değil, istemci özeti; burada tutulur çünkü geri dönüş sorularını destekler. Sunucu (`Modules/OfflineBrief`, `init.server` girişte) çevrimdışı kazanç/büyüme varsa `OfflineSummary(earned, grown, brief)` gönderir;
`brief` kayıttan hesaplanan isteğe bağlı küçük tablodur (yeni kalıcı alan yok, istemciden değer alınmaz): `daily` (günlük ödül alınabilir), `orders` (1-99 teslime hazır sipariş), `merchant` (gezgin tüccar şu an teklif sunuyor),
`golden` (altın hayvan parlıyor). Boş/ilgisiz alan yazılmaz; hesap hatası yalnız o alanı düşürür; eski istemci üçüncü bağımsız değişkeni yok sayar, yeni istemci eksik alanı "yok" sayar. Pencere satırları `Ui/Hud/WelcomeBackLines` (saf, testli).

## Yeni olay eklerken
1. Para kategorisi: `TelemetryLogic.ECONOMY`'ye ekle (işlem türü benzersiz; toplam ≤ 20), çağrıda `reason` ver.
2. Özel olay: `TelemetryLogic.CUSTOM_EVENTS`'e adı ekle, `TelemetryService.custom(player, ad, değer)`.
3. Testi (`tests/telemetry.spec.luau`) ve bu belgeyi güncelle.
