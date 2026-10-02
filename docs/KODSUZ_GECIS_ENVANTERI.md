# Kodla üretilen görseller: modele geçiş envanteri

Tarih: 2026-10-02. Kapsam: `src/server/Presentation/**`, `src/server/World/**`, `src/client/Effects/**`. Satırlar mevcut çalışma ağacına göredir. Parça sayısı tek örnek/tek varyant için yaklaşık BasePart sayısıdır; rastgele dağıtım ve ada sayısı toplamı değiştirir. **S** sabit geometri, **V** oyun durumuna göre görünüm, **D** zaman/kamera/oyuncu hesabı. “Hazır” dosya asset'ini, “Kalan” model dosyası açılmadığını belirtir. Mevcut 54 bina ve 24 hayvan yeniden üretilmedi. `WorldUi.sign/tag`, metin, ProximityPrompt ve satın alma/üretim mantığı her zaman kod ekler.

## Presentation

| Kaynak (dosya:satır) / görsel | Tür ve durum sayısı | Kod sözleşmesi | Parça; modele geçiş |
|---|---|---|---|
| `AnimalModels.luau:50-405`, `AnimalModelsSpecies.luau:10-653` hayvan gövdeleri | V: 24 tür × yetişkin/genç/yavru ölçeği | `Animals/<animalId>`, gövde, -Z yönü; `AnimalModels.luau:406-431` önce asset dener | ~8-25; **evet, hazır** 24 yetişkin modeli; ölçekleme kodda |
| `AnimalVisualService.luau:40-94,118-210` hayvan örnekleri | D: kayıt, konum, evre, altın/soy | `Animal` etiketi, `Uid,Stage,ZoneId,ExtensionId,AreaCFrame,AreaSize,HeightOffset,PartCount`; `ModelStreamingMode=Atomic` | Model kabuğu hazır; yerleştirme ve durum kodda kalır |
| `AnimalLabels.luau:10-63` ad/soy etiketi | D: isim ve soy seviyesi | `AnimalNameTag`, `Lineage` görünümü; WorldUi metin | 0 parça + GUI; **hayır**, kod ekler |
| `AnimalPlacement.luau:7-55` alan/zemine oturtma | D: kapasite, bölge | `Zones/<ZoneId>/Ground`, `AreaCFrame` | Yeni parça yok; kod kalır |
| `UpgradeBuildersHome.luau:1-305`, `UpgradeBuildersBarnyard.luau:1-251` | S: bina kimliği | `Buildings/<upgradeId>`, pencere adı `Window*` + Glass | ~5-35; **evet, hazır** 54 bina setinde |
| `UpgradeBuildersGoods.luau:26-321`, `UpgradeBuildersWorkshops.luau:1-263`, `UpgradeBuildersSpecies.luau:31-1102` | S: bina/tür kimliği | `ProductionSign` gövdesi ve WorldUi yazısı kodda; `NightWindow` işaretleme kodda | ~5-35; **evet, hazır** bina setinde |
| `UpgradeParts.luau:22-129` ortak parça, sütun, küre, kiriş, tabela | S: çağıran binaya bağlı | `ProductionSign`/WorldUi.sign kod ekler | Tekil 1-3; bina içinde hazır, tabela/UI kod kalır |
| `UpgradeVisualService.luau:61-156,166-221` bina yerleştirme | V: satın alınmadı/kuruldu, 54 kimlik | `BuildSpots/<upgradeId>`, `UpgradeVisualVersion,PartCount,VisualCreatedAt`; pencereleri gece işaretler, prompt ve iş çubuğu ekler | Gövde hazır; konum/oyun durumu kod kalır |
| `UpgradeSites.luau:25-112` satın alma alanı | V: 54 yükseltme kimliği için aynı gövde, değişen fiyat/başlık | `UpgradeId`, `BuySitePrompt`, `SitePromptAnchor`, `WorldUi.sign` kod ekler | 9 parça (tabela/prompt hariç); **evet, hazır** `FacilityProps/BuildSite_Unbuilt` |
| `UpgradeSites.luau:113-214` tesis süsü | V: tesis seviyesi 1-5, kümülatif | `LevelMarks/<upgradeId>`, `Crate,FlagPole,LampPost,AwningPost,Counter` | 4/6/10/14/16; **evet, hazır** `FacilityProps/FacilityProps_Lv1..5` |
| `UpgradeSites.luau:215-271` halka ve seviye yazısı | V: kurulu tesis seviyesi 1-5; altın disk sayısı seviyeyle artar | `LevelMarks`, WorldUi seviye etiketi kod ekler | 1-5 disk + GUI; **evet, hazır** `FacilityProps/FacilityRings_Lv1..5`; sayaç/metin kodda |
| `CollectorVisualService.luau:31-125,134-160` para yığını | V: depo doluluk seviyesi 0-5; 0 görünmez | `Collector` konumu, `CollectorPile`, `Level` | 4/14/22/36/43; **evet, hazır** `Collectors/CollectorPile_Lv1..5`; 0 = model yok |
| `ZoneVisualService.luau:49-92` bölge bayrakları | V: 1-5 adet, `growth/income/season/capacity` renkleri ve sıraları | `LevelFlags.Signature`, `FlagPole`, `Flag` | 2 parça/bayrak; **hazır** `ZoneFlags/` 4 renk; sayı/sıra kodda |
| `ZoneLevelDecor.luau:13-111` bölge seviye süsleri | V: 1-5 kümülatif, 30×24 ve 30×26 zemin | `LevelFlags` altına, zemin üstü pivot | 4/13/22/50/54; **evet, hazır** `ZoneLevels/` 10 varyant |
| `ZoneVisualService.luau:94-158` açılmış bölge dekoru ve kilitli zemin rengi | V: 22 `ZoneId` görünümü, ana bölgede 6 tema, kilit durumu | `Zones/<ZoneId>/Ground`, `OpenColor,ThemeIndex`, `Decor`; ot şeridi tohumla | 9-55; **evet, hazır** `ZoneDecor/` 32 şablon; kilit rengi/konum/ot kodda |
| `ZoneBuildersHome.luau:22-145` başlangıç/otlak, `ZoneBuildersPens.luau:20-245` ahırlar | S/V: bölge kimliği ve tema rengi | `Decor`, `ZoneId`, `ZoneParts.Look`, -Z ön | 9-47; **evet, hazır** 12 tema + 4 ağıl şablonu |
| `ZoneBuildersWater.luau:20-268` kuş/su/balık bölgeleri | S/V: bölge ve su alanı | `Decor`, `NightWindow` cam, `SwimDepth` | 10-55; **evet, hazır** 3 şablon; su yüzeyi/Terrain kodda |
| `ZoneBuildersSpecies.luau:28-982` 13 tür ağılı/dekoru | S: bölge kimliği | `Decor`, `ZoneId`; ortak ZoneParts geometrisi | 15-49; **evet, hazır** 13 şablon |
| `ZoneParts.luau:14-132` yalak/saman/bitki/ağaç/kaya/çatı yardımcıları | S: parametreli ölçü/renk | Ana `Decor` ya da `LevelFlags` içine eklenir | 1-3/öğe; ayrı asset zorunlu değil, üst grup içinde |
| `UpgradeLevelProps.luau:68-256,525-610` yem, büyüme, depo | V: `feed_quality` 1-5; `fast_growth` 1-3; `storage_expansion` 1-4 | `LevelProps.Signature`; bölgeler `ZoneId`/Ground, depo `Collector` yanı | 2-11; **evet, hazır** `LevelProps/` 12 model; tekrar sayısı/konum kodda |
| `UpgradeLevelProps.luau:258-325` soy anıtı | V: 24 tür × seviye 1-10; 8'li sıra | `LevelProps`, `save.lineage`, tür sırası | 2-5/tür; **evet, hazır** `Lineage/LineageMonument_Lv1..10`; çoklama kodda |
| `UpgradeLevelProps.luau:327-523,613-666` yardımcı gövdesi | V+D: 9 görünüm türü, 2 yaka rengi; 16 kullanılan birleşim | `Pet_{kind}_{island}`, `PetKind,PetIsland,PetHome`, `PetFigure`, görünmez `Root` | 14-15; **evet, hazır** `Pets/` 16 kabuk; hareket/rota kodda |
| `ExtensionVisualService.luau:61-173,266-342` eklenti görünümü | V: kilitli/satılık/kurulu, ada ve eklenti türü | `ExtensionId`, `SpecialtySign/ForSaleSign`, promptlar kod ekler | 30-86; **evet, hazır** altı kurulu yapı; satılık tabela, satın alma ve işleme kodda |
| `ExtensionVisualService.luau:175-265` kapasite süsü | V: kapasite 3/4+ | `CapacityProps`, ilgili ada slotu | 4/10; **evet, hazır** altı eklenti × iki kapasite |
| `JobMarks.luau:16-95` iş ankrajı/ilerleme etiketi | D: üretim zamanı/doluluk | `JobAnchor`, GUI/WorldUi; `ProductionSign` başlığı | 1 görünmez parça + GUI; **hayır**, iş zamanlayıcısı kod kalır |
| `DecorReveal.luau:25-100` kilitli görseli gizleme | D: barn/bölge açılımı | `RevealGate`, `RevealBarnLevel`, `RevealZoneId`, `RevealZoneLevel` | Yeni geometri 0; kod kalır |

## World

| Kaynak (dosya:satır) / görsel | Tür ve durum sayısı | Kod sözleşmesi | Parça; modele geçiş |
|---|---|---|---|
| `BarnVisualService.luau:57-340` ahır ve sandık | V: ahır seviyesi 1-4 | `BarnSpot` zemin pivotu, -Z kapı, `Barn`; `NightLight/NightWindow` + `NightColor`/kapalı ışık; `BarnChestPrompt`/`ChestTag` ve `LevelSign` kod ekler | 28/31/34/36 (UI hariç); **evet, hazır** `Barns/Barn_Lv1..4` |
| `MapParts.luau:111-223` bölge zemin/çit/yüzer yol, `IslandBuilder.luau:328-340` | S: kara 30×24/30×26, balık 20×20 | `Zones/<ZoneId>/Ground,Fence,Walkway`, `OpenColor,BackReserve,SwimDepth,WalkSurfaceY` | çit 37/39, yüzer yol 12; **şablon hazır** `ZoneBases/` 3 model; zemin/yerleşim kodda |
| `MapParts.luau:85-141,255-331` ağaç/yüzer yürüyüş/çim/lamba | S: tohum, ada/bölge ölçüsü | `NightLight`, `NightColor`; `WorldDecor.optimize` | 2-çok; **evet, kalan** dekor şablonları; dağılım kodda |
| `MapParts.luau:224-254` BuildSpot/köprü | S: yükseltme kimliği/ada geometrisi | `BuildSpots/<upgradeId>`, köprü temasları | 1/çok; **hayır bu tur**, konum/köprüye dokunma kuralı |
| `IslandBuilder.luau:47-229` yön tabelası ve ev dekoru | S/V: 6 tema; ahır/bölge açılımı | `RevealGate` + `RevealBarnLevel/RevealZoneId/RevealZoneLevel`; WorldUi metin kod ekler | ~1-100/grup; **evet, kalan** yerel dekor; tabela metni kodda |
| `IslandBuilder.luau:230-438`, `SatelliteBuilder.luau:31-291` ana/uydu ada kurulumları | S/V: tema 1-6, ada kimliği | `PlotBase,Islands,BuildSpots,Zones,Collector,BarnSpot`; `IslandFrame,FarmIslandId` | yüzlerce; **hayır bu tur**, ada/köprü/Terrain düzeni donduruldu; iç dekor ayrı model olabilir |
| `HomeHouses.luau:30-320`, `HomeFarmland.luau:22-292`, `HomeMarket.luau:23-133`, `HomeLandmarks.luau:22-233` | S: ev/değirmen/kuyu/ambar, bahçe/kovan/pazar/6 anıt | `Windmill`, `NightLight/NightWindow`; pazar prompt/WorldUi kod ekler | 7-85/grup; **evet, hazır** `HomeModels/` 14 model |
| `HomeParts.luau:16-166`, `DecorParts.luau:5-61` | S: ortak şekil yardımcıları | Çağıran modelin adı/etiketi | 1-3/öğe; üst grup içinde modellenir |
| `DecorNature.luau:25-295` meşe/çam/çalı/çiçek/çim | S: tohumlu ölçü ve dağılım | `Random.new(seed)`, ada/zemin CFrame | 3-14; **örnek hazır** `CommonDecor/` 4 tohum-11 şablonu; diğer tohum/çim dağılımı kodda |
| `DecorProps.luau:17-267` yol/fıçı/kasa/posta/çit/saman/korkuluk/el arabası | S/V: ölçek ve saman istifi | `WorldDecor.optimize`; çarpışma uygunluğu | 3-7; **örnek hazır** `CommonDecor/` 8 şablon; yol/çit uzunluğu kodda |
| `DecorLights.luau:17-84` sokak/küçük lamba/pencere | S+D: gövde sabit, gece ışığı değişir | `NightLight/NightWindow`, `NightColor`, kapalı `PointLight` | 3-4; **evet, hazır** iki lamba gövdesi; ışık kodda |
| `DecorShore.luau:23-218` kıyı Terrain, kaya, iskele/kulübe | S/V: yarıçap/tohum; kulübe bölge seviyesinde açılır | `RevealGate`, `RevealZoneId=fishpen`, `RevealZoneLevel=1` | 17+19; **evet, hazır** `ShoreModels/Dock_Main,FisherHut_Lv1`; Terrain **hayır bu tur** |
| `IslandSiteBuilders.luau:14-379`, `IslandSiteParts.luau:15-85` 6 satın alınan ada eklentisi ve ev yükleme süsü | S/V: at, tavuk, keçi, yamaç, koyun, trüf, ev | `AnimalObstacle`, `ForSaleSign/SpecialtySign`; WorldUi kod ekler | 12-86; **hazır** 6 eklenti + `MilkLoadingDecor` |
| `IslandSpecialization.luau:32-226` üretim alanı/eklenti satış ve yükleme dekoru | V: ada/eklentinin satın alınması ve üretim tipi | `ProductionSiteId`, `ExtensionId`, `ProductionSites`, `MilkLoadingDecor` | 1-12; **hazır** 3 `ProductionSites/` pad + `MilkLoadingDecor`; durum/tabela/prompt kodda |
| `HubBuilder.luau:21-175`, `HubNpcs.luau:45-290` meydan, satıcı, çeşme, bank, saksı | S: 4 satıcı ve meydan dekoru | `HubNpc`, `Action`; WorldUi tabela/isim ve prompt kod ekler | 4-18; **hazır** `HubProps/` 7 model; meydan/köprü konumu bu tur sabit |
| `HubBuilder.luau:176-...` köprü, `MapMountains.luau:23-82` dağ/duvar | S: ada koordinatı ve tohum | `World.Bridges`, `MapRim`, Terrain | çok; **hayır bu tur**, köprü/Terrain'e dokunma kuralı |
| `MapBuilder.luau:75-204,324-491` tema kopyalama/deniz/sınır/ışık | V+D: 6 tema, Studio kurulum ve çalışma zamanı | `ThemeTemplates`, `TEMPLATE_CONTENT`, `MAP_VERSION`, `SeaSafety` | yüzlerce/0; **hayır bu tur**, harita kurma, Terrain, MAP_VERSION yasak |
| `WorldDecor.luau:1-49`, `HomeBuildings.luau:1-25`, `IslandLooks.luau:1-228`, `IslandLayout.luau:1-115`, `MapLayout.luau:1-...`, `SharedRef.luau:1-13` | S: kurucu yönlendirme, veri ve ölçü | Alt kurucuların sözleşmesi | Doğrudan geometri 0; ayrı model yok |

## Client Effects

| Kaynak (dosya:satır) / görsel | Tür | Kodda kalacak parça; model olasılığı |
|---|---|---|
| `AnimalAnimator.client.luau:48-348` | D: hayvan yürüme, salınım, kaçınma | `Animal`, `AreaCFrame/AreaSize`; 24 kabuk hazır, hareket kodda |
| `PetAnimator.client.luau:60-133,167-482` | D: yardımcı rota ve elde taşınan ürün/para | `PetFigure`, `PetKind/PetIsland/PetHome`, `Root`; gövde model olabilir, geçici yük kodda |
| `BoatAnimator.client.luau:34-...`, özellikle `:209` | D: `fishing_boat` rota ve geçici köpük izi | `BoatRoot`, tekne kabuğu `Buildings` içinde; iz kodda |
| `Windmill.client.luau:18-...` | D: kanat dönüşü | `Windmill` etiketi; gövde model olabilir, dönüş kodda |
| `Birds.client.luau:45-109` | D: 2 kuş biçimi ve sürü uçuşu | 3-5 parça/kuş; kabuk model olabilir, sürü yoğunluğu/uçuş kodda |
| `FishLife.client.luau:49-312` | D: 2 parçalı balık, sıçrama ve su parçacığı | Balık kabuğu model olabilir; sıçrama/uzaklık kodda |
| `SeabedLife.client.luau:143-345,366-530` | D: kamera hücrelerinde tohumlu yosun/mercan/kaya/denizyıldızı, balık/denizanası | Statik prop kabuğu model olabilir; hücre seçimi, kalite bütçesi, hareket ve baloncuk kodda |
| `ShoreIce.client.luau:105-...`, `SeasonalScenery.luau:43-453` | D: mevsim/buz/renk/ölçek | Buz kabuğu model olabilir; mevsim ve havuz hesabı kodda |
| `DayNight.client.luau:91-368` | D: gece/gündüz, hale, ışık ve pozlama | `NightLight/NightWindow/NightColor`; lamba kabuğu model olabilir, ışık kodda |
| `WeatherEffects.client.luau:144-...`, `WeatherPrecip.luau:49-403` | D: hava rengi, yağmur/kar parçacıkları | Parçacık ve Lighting hesabı kodda; sabit model yok |
| `Underwater.client.luau:54-300` | D: kamera altı hacim, kabarcık/menfez/sıçrama | Efekt ankrajları istemci kodunda kalır; sabit model yok |
| `BuildEffects.client.luau:71-251` | D: yapım tozu, parıltı, pop animasyonu | Geçici parçalar kodda kalır |
| `Graphics.client.luau:73-...` | D: cihaz/kullanıcı grafik seviyesi | `EffectsQuality`, `ReducedMotion`; yeni model yok |
| `SeasonSignal.client.luau:26-80` | D: mevsim durumu etiketi | UI/etiket kodda kalır |
| `Soundscape.client.luau:30-130` | D: ses nesneleri, ortam/hayvan seçimi | 0 BasePart; ses kodda kalır |

## Aktarım ve açık konular

- XML dosyaları Studio'daki gerçek kod kurucularından üretilen BasePart'ların **ad, sınıf, ölçü, CFrame, renk, malzeme, şekil, Anchored, CanCollide, CanTouch, CanQuery, Transparency ve Reflectance** değerlerini taşır. Pivot dünya koordinatında zemin yüzeyidir; yükleyici `PivotTo` ile gerçek noktaya almalıdır.
- Bu XML dışa aktarımı **Roblox özniteliklerini, CollectionService etiketlerini, iç içe Model hiyerarşisini ve PointLight/Prompt/GUI çocuklarını serialize etmez**. Yükleyici `Barn` için `NightLight/NightWindow + NightColor` ve kapalı PointLight; `CollectorPile.Level`; yardımcı için `PetFigure/PetKind/PetIsland/PetHome`; `Windmill` ve `HubNpc/Action`; eklenti için `AnimalObstacle`; `RevealGate` varyantları için ilgili Reveal özniteliklerini kurmalıdır. Studio tezgâhında oluşan etiketler geçicidir; kalıcı asset dosyasında yoktur.
- Kaynaktaki çam yaprak `SpecialMesh` küreleri sözleşmedeki Part/Ball kuralı için Ball parçaya çevrildi. Bu, çam temalı otlak, çam anıtı, trüf korusu ve örnek çam şablonunda bilinçli görsel farktır.
- Sözleşmenin bina için 35 BasePart bütçesi, kaynak kurucuyla birebir ahır Sv.4'te 36; toplayıcı Sv.4/5'te 36/43; bölge süsü Sv.4/5'te 50/54 ile çelişir. Burada kaynak imzası korundu; sadeleştirme sonraki görsel karardır.
- Yeni asset'ler için mevcut kodda yükleme kancası yoktur. Bu dosyalar tek başına oyundaki kod görsellerinin yerine geçmez; kodun koşullu klonlama, doğru ad/öznitelik/etiket ve konum bağlaması eklenmelidir. Kod ve yerleşim bu tur değiştirilmedi.
