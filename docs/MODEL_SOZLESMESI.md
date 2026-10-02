# Model sözleşmesi (Studio'da elle/ajanla yapılan görseller)

Bu belge, kod kurucusu yerine Studio'da yapılıp `ServerStorage.Assets` altına konan bir modelin **kodun beklediği her
şeyi** karşılaması için kuralları verir. Kaynak kod okunarak çıkarıldı; satır numaraları 2026-10-01 `main` (ffb8d0e)
içindir. İş akışı, dışa aktarma, pilot ve ajan şablonu: `docs/MODEL_IS_PLANI.md`.

Kural dili: **ZORUNLU** (ihlal = hata/bozuk görünüm), **YASAK**, **ÖNERİ** (kodda sınır yok, stil/performans kararı).

## 1. Köprüler: hangi model nereden okunur?

| Tür | Arama yeri (ad = kimlik) | Temizleme | Kod | Köprü var mı? |
|---|---|---|---|---|
| Yükseltme binası (fabrika, ürün merkezi, silo...) | `ServerStorage.Assets.Buildings.<upgradeId>` (yoksa `ReplicatedStorage.Assets`) | `AssetSanitizer.clone(t, true)` | `UpgradeVisualService.luau:61-69` | Var |
| Hayvan (24 tür) | `ServerStorage.Assets.Animals.<animalId>` | `AssetSanitizer.clone(t, false)` | `AnimalModels.luau:406-419` | Var |
| Ahır | `Assets.Barns.Barn_Lv<1-4>` | `World/ModelAssets.clone` (çarpışma modeldeki gibi) | `World/BarnVisualService.luau` | Var (fener/pencere ışığı, sandık istemi, seviye yazısı kodla eklenir) |
| Toplayıcı para yığını | `Assets.Collectors.CollectorPile_Lv<1-5>` | aynı | `CollectorVisualService.luau` | Var |
| Bölge dekoru, bayrak, seviye süsü | `Assets.ZoneDecor.Decor_<bölge>[_T<tema>]`, `ZoneFlags.ZoneFlag_<tür>`, `ZoneLevels.ZoneLevel_<X>x<Z>_Lv<1-5>` | aynı | `ZoneVisualService.luau` | Var (çim tutamları ve gece pencereleri kodla) |
| Yem/büyüme/depo yığını, soy anıtı, yardımcı | `Assets.LevelProps`, `Lineage`, `Pets.Pet_<tür>_<cash\|goods>` | aynı | `UpgradeLevelProps.luau` | Var (yardımcı öznitelik/etiketi kodla) |
| Yapım alanı, tesis süsü/halkası | `Assets.FacilityProps.BuildSite_Unbuilt`, `FacilityProps_Lv<1-5>`, `FacilityRings_Lv<1-5>` | aynı | `UpgradeSites.luau` | Var (fiyat tabelası, direk ve satın alma istemi kodla) |
| Eklenti yapısı, kapasite süsü, üretim zemini, süt yükleme dekoru | `Assets.Extensions.<id>`, `ExtensionCapacity.CapacityProps_<id>_Cap3\|4`, `ProductionSites.ProductionSite_<id>`, `Extensions.MilkLoadingDecor` | aynı | `World/IslandSpecialization.luau`, `ExtensionVisualService.luau` | Var (tabela/istem kodla) |
| Bina tabelası | binada `SignBoard` (tahta) + 2 `SignPost` (direk) parçası | tahta çarpışmaz (kodda kapatılır) | `UpgradeVisualService.luau` `signSpecFor`, `UpgradeParts.faceSign` | Var: tahta/direk modelde (46 üretim binası), yazı (`WorldUi.sign`) tarif adından kodla eklenir. Üretim yapmayan binalar (`silo`, `milk_machine`, `auto_collector`, `egg_factory`, `golden_horseshoe`) tabelasızdır; `check-assets.py` diğerlerinde tahta + 2 direği zorunlu tutar |
| Bölge zemini + çit, ana ada/meydan dekoru (`HomeModels`, `HubProps`, `CommonDecor`, `ShoreModels`) | `assets/` dosyaları var | — | `World/MapParts.luau`, `Home*`, `Hub*`, `Decor*` | **Bağlanmadı**: harita yalnızca "Haritayı Kur" ile kurulur, Studio'daki kayıtlı harita zaten modeldir |


- **Kod kurucuları kaldırıldı:** model yoksa o görünüm çizilmez (hayvan için pembe yer tutucu kutu; diğerlerinde konsola bir kez uyarı).
  `scripts/check-assets.py` her görünüm için modelin varlığını `verify.ps1`'de denetler. Yapım alanı (`BuildSite`) yalnızca `assets/Buildings/<id>` varsa kurulur (`UpgradeVisualService.hasAsset`).
- Asset araması tam kimlikle yapılır (takma ad yok): `duck_packer` ve `down_home_center` kendi dosyalarıdır.
- Rojo: `ServerStorage.Assets` → `assets/` (`default.project.json:12-16`; içinde yalnızca `Animals/.gitkeep`, `Buildings/.gitkeep`).

## 2. Ortak teknik kurallar (temizleyici ve servisler ne yapıyor?)

| Kural | Kaynak | Modele etkisi |
|---|---|---|
| Tüm `LuaSourceContainer` silinir | `AssetSanitizer.luau:8-9` | Script koyma (YASAK; boşa gider) |
| Her BasePart `Anchored=true`, `CanTouch=false` | `AssetSanitizer.luau:11-13` | Kaynak/weld gerekmez |
| Bina: **her parça `CanCollide=true`** | `AssetSanitizer.luau:12` (`collide=true`) | Tabela tahtası, ince süs de çarpışır → `world-map.mdc:26,33-34` ile çelişir (bkz. plan K1) |
| Hayvan: her parça `CanCollide=false`, `CanQuery=false` | `AssetSanitizer.luau:12-16` | — |
| `WorldDecor.optimize`: çarpışmayan → `CanQuery=false`; en büyük boyu < 1.6 → `CastShadow=false` | `DecorProps.luau:42-54`, çağrı `UpgradeVisualService.luau:98` | Elle ayarlama gerekmez |
| Adı `Window` içeren **ve** `Material=Glass` parça → `NightColor` + `NightWindow` etiketi + kapalı `PointLight` | `UpgradeVisualService.luau:89-97`, `DecorLights.luau:46-56` | Gece penceresi için tek şart: ad + cam. Etiketi/ışığı elle ekleme |
| Gece ışığını yalnızca `DayNight.client` yakar; etiketsiz ışık sürülmez | `DayNight.client.luau:229-235`, `world-map.mdc:49-53` | Modele açık `PointLight`/`SpotLight` koyma (YASAK); lamba gerekiyorsa `NightLight` + `NightColor` + `Enabled=false` |
| Bina sonrası öznitelikler: `UpgradeVisualVersion`, `PartCount`, `VisualCreatedAt`; ad = `upgradeId` | `UpgradeVisualService.luau:87-88,143-153` | Modelde bu adlarla öznitelik bırakma |
| Hayvan sonrası: ad `{id}_{uid}`, `ModelStreamingMode=Atomic`, `Animal` etiketi, `AreaCFrame/AreaSize/HeightOffset/Uid/Stage/ZoneId/PartCount...` | `AnimalVisualService.luau:49-90` | Hiçbirini modele koyma; servis yazar |
| StreamingEnabled açık (Min 160 / Target 1024: uzaklaştırınca deniz Terrain'i de yüklü olsun) | `default.project.json:62-69` | Bina şablonunda `ModelStreamingMode` ayarlanmaz (koddaki binalar da Default; yalnızca tekne Atomic `:116`) |

## 3. Tür bazında sözleşme

### 3a. Yükseltme binası (`Assets/Buildings/<upgradeId>`)

| Başlık | Kural | Kaynak |
|---|---|---|
| Ad | Tam yükseltme kimliği (`duck_packer`, `silo`, `wool_mill`...). Tür fabrikaları `Config/Species.luau`'dan türer | `UpgradeVisualService.luau:64` |
| Pivot | ZORUNLU: zemin ortası, y=0 = ada yüzeyi. `PivotTo(spot.CFrame)` yapılır; spot ada yüzeyinde | `:76`, `MapLayout.luau:10`, `MapParts.luau:224-230` |
| Yön | ZORUNLU: kapı/ön yüz **-Z** | `UpgradeSites.luau` |
| Gövde kutusu | ZORUNLU: gövde 10 x 8 (X x Z), çatı taşması dahil ≤ 11.4 x 9.4. Seviye süsleri bu kutunun dışına (x ±7.2, z 5-8.2, z -5.6) kurulur, taşan model süsle iç içe girer | `UpgradeSites.luau:111-211`, `UpgradeBuildersGoods.luau:26` |
| Yükseklik | ÖNERİ: ≤ 12 stud (ör. ördek evinin çatı heykeli ~y12). İş çubuğu kutunun 6 üstüne kurulur | `UpgradeVisualService.luau` |
| Kapı | ZORUNLU: ≥ 4.6 x 6.6 açıklık; kapı önü (-Z) boş | `world-map.mdc:22` |
| Üretim prompt'u | YASAK: modele `ProductionPromptAnchor`/`ProductionPrompt` koyma; servis her zaman `base * (0, 2.5, -6)`'ya ekler (çift olur). ZORUNLU: o nokta duvar içinde kalmasın (gövde z ≥ -4) | `UpgradeVisualService.luau:122-139` |
| `JobAnchor` | İSTEĞE BAĞLI: modelde bu adda parça varsa iş çubuğu ona bağlanır; yoksa kutu üstü +6 | `JobMarks.luau:17-36` |
| Tabela | ÖNERİ (üretim binaları): ön sağ dışta, zeminde iki direkli `SignBoard` (6 x 1.7 x 0.16, ön yüz -Z; merkez x 9.4, z = en öndeki parça - 1, alt kenar y 2.45) + 2 `SignPost` (0.25 x 2.45 x 0.25). Kapı önü (|x| < 5.6) boş kalır; seviye süsleri sol-ön köşe (x -6.4) ve fener direkleri (x ±4.4) ile çakışmaz. Yazıyı kod ekler (`UpgradeParts.faceSign`); tahta adı koddan sonra `ProductionSign` olur, `CanCollide` kapatılır | `UpgradeVisualService.luau`, `UpgradeParts.luau` |
| Pencere | `Window*` + Glass (bkz. §2). Cam olmayan "Window" ışık almaz | `:89-97` |
| Parça bütçesi | ZORUNLU: ≤ 35 BasePart (kod binalarının sınırı) | `scripts/check-assets.py` |
| Seviye (Sv.1-5) | Modelde varyant YOK; seviye süsleri (`addFacilityProps`) ve altın halkalar ayrı modellerde (`LevelMarks/<id>`) koddan gelir | `UpgradeSites.luau:113-270` |
| Özel: `fishing_boat` | Pilot dışı: servis `Hull/Deck/JoinedBow/BowDeck/Wheelhouse/CabinRoof` adlarını katı sayar, `BoatRoot` ekler, istemci oynatır | `UpgradeVisualService.luau:99-121` |
| Özel: büyük alanlar | `milk_factory` 20x14, `hatchery` 14x16, `horse_training` 14x18 ayak izi | `IslandLayout.luau:84-107` |

Yerler (bina ve komşu çakışması için): ana ada `MapLayout.luau:79-98` (ör. `duck_packer` (43,0,-21); yakın anıt (59,-7), `1556ceb`),
uydu fabrika (18,0,37) / merkez (-18,0,37) `MapLayout.luau:158-159`.

### 3b. Hayvan (`Assets/Animals/<animalId>`)

| Başlık | Kural | Kaynak |
|---|---|---|
| Ad | Tür kimliği (`cow`, `duck`, `rabbit`...; 7 eski + 17 tablo türü) | `AnimalModels.luau:409`, `Config/Species.luau` |
| Boyut | ZORUNLU: **yetişkin** boyutunda yap; yavru 0.55 / genç 0.8 `ScaleTo` ile | `AnimalModels.luau:10-14,415-417` |
| Pivot / yön | ZORUNLU: pivotun LookVector'ü baş yönü (**-Z**). Yükseklik önemsiz (sınır kutusu tabanı zemine oturtulur) | `AnimalAnimator.client.luau:122-125`, `AnimalPlacement.luau:33-38` |
| PrimaryPart | ÖNERİ: gövde parçası `Body` ve `PrimaryPart`; etiket ve altın vurgu `PrimaryPart` ya da ilk BasePart'a bağlanır | `AnimalLabels.luau:28-30`, `GoldenAnimal.client.luau:56` |
| Animasyon | Uzuv animasyonu YOK; animatör bütün parçaları pivottan sabit ofsetle taşır (sallanma + dönüş). Adlı uzuv gerekmez | `AnimalAnimator.client.luau:216-228,328-348` |
| Ölçü | ÖNERİ: kod modelinin ±%20'si (inek gövdesi 3.2x2.4x5, at 2.4x2.4x5.2, tavuk 1.4x1.3x1.8). Büyük model alan kenarından taşar; alan kenardan 2 stud içeride | `AnimalModels.luau:55,88,135`, `AnimalPlacement.luau:8-17` |
| Parça bütçesi | ÖNERİ: ≤ 20 BasePart. Her parça her karede `BulkMoveTo` ile taşınır; kodda sayı sınırı yok | `AnimalAnimator.client.luau:348` |
| Yasak | Script, ışık, `Highlight`, BillboardGui (etiketleri servis kurar), `Animal` etiketi | `AnimalLabels.luau:35-41,71-79` |
| Çakışma | Hayvanlar yalnızca `AnimalObstacle` etiketli parçalardan kaçar (1.3 stud pay); bölge dekoru etiketsiz, kaçınma `BackReserve` düzeniyle sağlanır | `AnimalAnimator.client.luau:44-109`, `IslandSiteParts.luau:59-84` |

### 3c. Bölge/ağıl dekoru, eklenti, seviye süsleri (köprü yok)

| Tür | Bugün | Model yapılacaksa önce gereken kod (plan K4) |
|---|---|---|
| Ağıl dekoru (`Decor`) | assets/ZoneDecor/Decor_<bölge>; pivot = zemin üst ortası, -Z ön | `ZoneVisualService.luau:117-130`'a `Assets/Zones/<zoneId>` araması + `IslandSiteParts.markObstacles` |
| Bölge seviye süsleri (Sv.1-5) | assets/ZoneLevels/ZoneLevel_<X>x<Z>_Lv<1-5> (yalak, saman, gölgelik, çiçek, altın) | Model |
| Eklenti yapıları | assets/Extensions/<eklenti>, prompt ilk `ForSaleSign`/`SpecialtySign`'a bağlanır | `ExtensionVisualService.luau:73-75`, `:334` |
| Bina seviye süsleri | `UpgradeSites.addFacilityProps` | Kod kalsın |

## 4. Renk ve malzeme paleti

- Stil: blok/voxel (düz renkli kutu, top, kama); kullanılan malzemeler WoodPlanks, Brick, Slate, Metal, Glass, Fabric, Neon (yalnızca süs/altın).
- Ortak sabitler: `METAL (190,195,200)`, `GOLD (255,200,60)` (`UpgradeParts.luau:15-16`). Bina renkleri bina başına yazılmış;
  örnek ördek evi duvar (88,150,175) / çatı (130,85,55) (assets/Buildings/duck_packer). Ekran renkleri `UiTheme.luau:10-25` dünyaya değil UI'a aittir.
- ÖNERİ: yeni model aynı binanın mevcut asset'indeki renkleri kullansın (oyuncu tanıdığı rengi görür); `generate_mesh` dokulu mesh bu stile uymaz (plan R1).
- Neon yalnızca gece/altın vurgusu; büyük Neon yüzey YASAK (DayNight NightLight için Neon kullanır, `DayNight.client.luau:199-201`).
