# Hayvan–eklenti yüzey denetimi

## Doğrulanan neden
Bütün mevcut 26 hayvan aynı AnimalAnimator kullanıyor. İlk yerleşim (AnimalAnimator.client.luau:190) ve hareket (:363) alanın üstünde sabit HeightOffset ile yazılıyor; yüzey yüksekliği sorgusu yok. BulkMoveTo doğrudan konum yazdığı için CanCollide açmak tek başına çözüm değildir. CliffStep/TerraceStep engel listesinde, CliffRock/CliffTop/RetainingRock platformları listede değil; platformun içinde hareket görülüyor.

## Model düzeltmesi
Yürünebilir yüzeylerde CanCollide=true, CanQuery=true doğrulandı. İnce zemin/yuva samanı/training kum pisti/ot kaplaması ve alçak GroveLog modellerindeki eksik katılık düzeltildi. Pivot, ölçü, parça sayısı, ada yerleşimi aynı. Bu değişiklik tek başına hayvanı platformun üstüne çıkarmaz; hareket bağlantısı Claude'da.

## Claude için davranış kabulü
- İlk yerleşim, hayvan büyümesi ve hareket aynı yüzey sorgusunu kullanmalı. Modelin ölçeklenmiş alt noktasından ayak/pivot payı korunmalı; gerçek yürünebilir yüzey yüksekliği buna eklenmeli.
- Raycast yalnız yürünebilir yüzeyleri içermeli. Çatı/saçak/yaprak/hayvan/tabela/görünmez alan anchor'ı/su yüzeyi filtre dışında. Üst kaplama varsa gövde yerine onun üstü seçilmeli.
- Ön/arka ayak desteklerini örnekle; aşırı dik/ulaşılamayan basamakta dur veya rota değiştir, yukarı ışınlama. Keçi kayalıklarda basamak üzerinden yürüyebilmeli; duvar/direk/yemliğe girmemeli.
- Hedef ve yol ile dönüş sırasında ölçeklenmiş hayvan gövdesinin ayak izi denetlenmeli; sabit 1.3 engel payı büyük türlerde yetersiz. Hayvan-hayvan kaçınması sadece hedefte değil yol boyunca uygulanmalı.
- Atın track oval hareketi de denetimi atlamamalı. Balıklar SwimDepthOffset yüzme davranışını korumalı; kara yüzeyi yüksekliğine çıkarılmamalı.
- 26 tür × baby/young/adult, 6 eklenti × Cap2/3/4, 32 yuva; ilk atama/yükleme/büyüme, düşük/orta/yüksek kalite, streaming ve ReducedMotion sınanmalı. Kalite yüzünden zemine batma geri gelmemeli.

## 50 kaynak modelin yüzey/engel adayları
Engel sütunu katı ve çatı olmayan parçaları gösterir. Tek büyük engel kutusu kullanma; açık barınağın içine girmek yasak değil, duvar/direk içine girmek yasaktır.

| Model | Yürünebilir yüzeyler | Katı engel adayları |
|---|---|---|
| Extensions/folluk_garden | NestFloor×3, NestStraw×3, Path×2, StrawYard×1 | Box×1, NestBack×3, NestSide×6, Slat×2 |
| Extensions/goat_cliffs | CliffRock×3, CliffStep×9, CliffTop×3 | FlagPole×1 |
| Extensions/hillside_pasture | HillMeadow×1, HutFloor×1, HutStep×1 | HillWall×5, HutBack×1, HutFront×2, HutHeader×1, HutSide×2 |
| Extensions/rocky_terraces | DairyApron×1, Path×3, RetainingRock×3, TerraceGrass×3, TerraceStep×9 | Body×2, Hoop×4 |
| Extensions/training_course | Path×2, TrackSand×24 | Body×1, Hoop×2, JumpStandard×4 |
| Extensions/truffle_grove | GroveLog×2, GroveSoil×1 | Trunk×6 |
| ExtensionCapacity/CapacityProps_folluk_garden_Cap3 | — | HayBale×2, WaterTrough×5 |
| ExtensionCapacity/CapacityProps_folluk_garden_Cap4 | — | HayBale×2, ShelterPost×4, WaterTrough×5 |
| ExtensionCapacity/CapacityProps_goat_cliffs_Cap3 | — | HayBale×2, WaterTrough×5 |
| ExtensionCapacity/CapacityProps_goat_cliffs_Cap4 | — | HayBale×2, ShelterPost×4, WaterTrough×5 |
| ExtensionCapacity/CapacityProps_hillside_pasture_Cap3 | — | HayBale×2, WaterTrough×5 |
| ExtensionCapacity/CapacityProps_hillside_pasture_Cap4 | — | HayBale×2, ShelterPost×4, WaterTrough×5 |
| ExtensionCapacity/CapacityProps_rocky_terraces_Cap3 | — | HayBale×2, WaterTrough×5 |
| ExtensionCapacity/CapacityProps_rocky_terraces_Cap4 | — | HayBale×2, ShelterPost×4, WaterTrough×5 |
| ExtensionCapacity/CapacityProps_training_course_Cap3 | — | HayBale×2, WaterTrough×5 |
| ExtensionCapacity/CapacityProps_training_course_Cap4 | — | HayBale×2, ShelterPost×4, WaterTrough×5 |
| ExtensionCapacity/CapacityProps_truffle_grove_Cap3 | — | HayBale×2, WaterTrough×5 |
| ExtensionCapacity/CapacityProps_truffle_grove_Cap4 | — | HayBale×2, ShelterPost×4, WaterTrough×5 |
| ZoneDecor/Decor_bee_pen | — | HiveBox×12, HiveStand×6 |
| ZoneDecor/Decor_camel_pen | — | Cloth×2, Post×6, Rock×2, Trough×1, WellBeam×1, WellWall×4 |
| ZoneDecor/Decor_deer_pen | — | BackWall×1, Crown×1, Log×2, Post×3, SaltBase×1, SaltBlock×1, Stump×3, Trunk×1 |
| ZoneDecor/Decor_falcon_pen | RockBlock×3 | Post×5 |
| ZoneDecor/Decor_fishpen | ServiceDeck×1 | — |
| ZoneDecor/Decor_goatpen | — | BackWall×1, FeedTrough×1, Post×2, Trough×1 |
| ZoneDecor/Decor_llama_pen | — | HayBale×1, Post×2, RackShelf×1, Rock×4, ShelterPost×4, StoneWall×3, Trough×1, WallCap×3 |
| ZoneDecor/Decor_parrot_pen | — | FeedTable×1, FrameBeam×1, Post×6 |
| ZoneDecor/Decor_pasture_T1 | — | HayBale×3, Trough×1 |
| ZoneDecor/Decor_pasture_T2 | — | HayBale×3, Trough×1 |
| ZoneDecor/Decor_pasture_T3 | — | HayBale×3, Trough×1 |
| ZoneDecor/Decor_pasture_T4 | — | HayBale×3, RoseBush×5, Trough×1 |
| ZoneDecor/Decor_pasture_T5 | — | HayBale×3, Rock×4, Trough×1, Trunk×2 |
| ZoneDecor/Decor_pasture_T6 | — | Crown×3, HayBale×3, Trough×1, Trunk×3 |
| ZoneDecor/Decor_peacock_pen | — | ArchMid×1, ArchSide×2, ArchTop×2, Post×4, Rock×2 |
| ZoneDecor/Decor_pigeon_pen | — | Post×2, Tower×1, TowerBase×1, TowerCap×2 |
| ZoneDecor/Decor_pigpen | StyFloor×1, StyStep×1 | FeedTrough×1, HayBale×1, StyBack×1, StyFront×2, StyHeader×1, StySide×2 |
| ZoneDecor/Decor_pond | DuckHouseFloor×1, DuckHouseStep×1 | DuckHouseBack×1, DuckHouseFront×2, DuckHouseHeader×1, DuckHouseSide×2, FeedTrough×1, Pier×1, PierPost×4 |
| ZoneDecor/Decor_poultry | CoopFloor×1, CoopStep×3 | CoopBack×4, CoopFront×2, CoopHeader×1, CoopSide×2, FeedTrough×1, NestBox×3, Stilt×6, Trough×1, Window×1 |
| ZoneDecor/Decor_quail_pen | CoopFloor×3 | Coop×3, CoopSide×6, FeedTrough×3, HayBale×1, NestBox×3 |
| ZoneDecor/Decor_rabbit_pen | HutchFloor×4 | FeedTrough×1, HayBale×1, Hutch×4, HutchLeg×8, HutchSide×8 |
| ZoneDecor/Decor_sheepfold | — | HayBale×1, ShedBack×1, ShedPost×3, ShedSide×2, Trough×1 |
| ZoneDecor/Decor_silkworm_pen | — | Post×4, Trunk×1 |
| ZoneDecor/Decor_snail_pen | — | BedFrame×12, Bucket×1, MossStone×1, Rock×2, ShelterPost×4 |
| ZoneDecor/Decor_stable | — | BackWall×1, Divider×5, FeedTrough×1, HayBale×1, Post×5 |
| ZoneDecor/Decor_starter_T1 | — | BackWall×1, FeedTrough×1, HayBale×3, Post×2, SideWall×2, Trough×1 |
| ZoneDecor/Decor_starter_T2 | — | BackWall×1, FeedTrough×1, HayBale×3, Post×2, SideWall×2, Trough×1 |
| ZoneDecor/Decor_starter_T3 | — | BackWall×1, FeedTrough×1, HayBale×3, Post×2, SideWall×2, Trough×1 |
| ZoneDecor/Decor_starter_T4 | — | BackWall×1, FeedTrough×1, HayBale×3, Post×2, SideWall×2, Trough×1 |
| ZoneDecor/Decor_starter_T5 | — | BackWall×1, FeedTrough×1, HayBale×3, Post×2, SideWall×2, Trough×1 |
| ZoneDecor/Decor_starter_T6 | — | BackWall×1, FeedTrough×1, HayBale×3, Post×2, SideWall×2, Trough×1 |
| ZoneDecor/Decor_tortoise_pen | BaskingRock×3 | HayBale×1, LowWall×1, PoolRim×4, ShelterPost×4, WallPillar×3 |

50 model, 97 yürünebilir parça; collision/query denetim hatası: 0. Canlı hareket testi henüz yapılmadı.
