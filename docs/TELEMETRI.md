# Telemetri (canlı ölçüm)

Tüm olaylar **sunucudan** `Services/TelemetryService.luau` ile gönderilir; saf kurallar (olay adları, yuvarlama, toplama, bütçe)
`Modules/TelemetryLogic.luau`'dadır ve `tests/telemetry.spec.luau` ile sınanır. Oyuncunun gönderdiği hiçbir değer olaya girmez.

## Çalışma kuralları
- **Studio'da hiçbir olay gönderilmez** (canlı veri kirlenmesin). Yalnızca `ServerStorage.Diagnostics` sayaçları artar
  (`TelemetryEconomy`, `TelemetryFunnel`, `TelemetryCustom`, `TelemetryProgression`, `TelemetryStudioSkipped`).
  Ne gidecekti görmek için Studio'da `Workspace` özniteliği `TelemetryPrint = true` yap: olaylar Output'a yazılır.
- Tüm AnalyticsService çağrıları `pcall` içindedir; hata `TelemetryError` sayacına yazılır, oyunu bozmaz.
- Sunucu başına iç bütçe: dakikada `TelemetryLogic.EVENTS_PER_MINUTE` (120) olay. Aşılırsa olay düşer ve `TelemetryDropped` artar
  (Roblox'un belgelenmiş bir dakikalık sınırı yok; bu değer muhafazakâr bir tahmindir, canlıda `TelemetryDropped` 0 değilse artır/azalt).
- Yüksek frekanslı kaynaklar (Toplama, Otomatik toplama) oyuncu başına birikir ve 60 sn'de bir (ve oyuncu çıkarken) tek olay olarak gider.
- Roblox sınırları: 5 para birimi (yalnızca `Cash`), 20 işlem türü, 100 SKU, 100 özel olay adı. Test bunları denetler;
  yeni kategori/olay eklerken `TelemetryLogic`'e ekle (listede olmayan olay gönderilmez, `TelemetryUnknown*` sayılır).

## Olaylar

### Onboarding hunisi (`LogOnboardingFunnelStepEvent`, oyuncu başına bir kez)
| Adım | Ad | Tetik |
|---|---|---|
| 1 | First collect | İlk toplama (platform ya da Otomatik Toplayıcı) |
| 2 | First animal | İlk hayvan alımı (pazar ya da gezgin tüccar) |
| 3 | First upgrade | İlk yol haritası yükseltmesi |
| 4 | First island | İlk uzman ada |
| 5 | Barn level 2 | Ahır Sv.2 |

"Bir kez" için kayıt şeması değişmedi: oyuncu girince kayıttan geçilmiş adımlar çıkarılır (`TelemetryLogic.factsFromViews`:
ömür boyu kazanç > 0, hayvan > 0, alınmış yükseltme > 0, açık ada > 1, ahır ≥ 2) ve yeniden gönderilmez. Telemetriden önce oynayan
oyuncular bu yüzden hunide görünmez; yalnızca sonradan geçtikleri adımlar sayılır.

### Ekonomi (`LogEconomyEvent`, para birimi `Cash`)
| Yön | İşlem türü (`transactionType`) | Kaynak kodu |
|---|---|---|
| Kaynak | Collect, AutoCollect (toplu, 60 sn) | `EconomyService` |
| Kaynak | Offline | `PlayerDataService.load` (çevrimdışı dönüş) |
| Kaynak | Daily, Season, Achievement, GoldenAnimal | `EngagementService` |
| Kaynak | Order | `ContractService` |
| Kaynak | Production | `ProductionService`, `PetService` (para fabrikası ödülü) |
| Kaynak | IncomePack | `MonetizationService` (gelir paketi) |
| Kaynak | Refund | `AnimalService` (hayvan satışı iadesi) |
| Gider | Animal (hayvan, gezgin tüccar, balık değişimi) | `AnimalService` |
| Gider | Upgrade, Lineage, Expansion | `UpgradeService` |
| Gider | Item | `InventoryService` |
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

## Yeni olay eklerken
1. Para kategorisi: `TelemetryLogic.ECONOMY`'ye ekle (işlem türü benzersiz; toplam ≤ 20), çağrıda `reason` ver.
2. Özel olay: `TelemetryLogic.CUSTOM_EVENTS`'e adı ekle, `TelemetryService.custom(player, ad, değer)`.
3. Testi (`tests/telemetry.spec.luau`) ve bu belgeyi güncelle.
