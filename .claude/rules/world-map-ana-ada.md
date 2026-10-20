---
description: Ana ada yapıları, meydan, tabelalar, yapım alanları, sandık ve küçük ada yerleşimi
paths:
  - "src/server/World/**"
  - "src/server/Presentation/**"
---

# Harita ve dünya: Ana Ada

Giriş dosyası: `.claude/rules/world-map.md` (konu haritası).

## Ana ada yapıları
- `HomeBuildings.luau` (geometri `assets/HomeModels` modellerinden gelir; kod yalnızca gece ışığı, duman, değirmen kanatları ve pazar etkileşimini ekler): pazar tezgâhı (`MarketPrompt` → Hayvan Pazarı penceresi), çiftlik evi, yel değirmeni
  (kanatlar `Windmill` etiketi, döndürme `Windmill.client`), kuyu, sebze bahçesi, meyve bahçesi, arı kovanları, ambar.
  `IslandBuilder` (`decorateHome`) çağırır; yerleri `addIslandGrass` kaçınma listesinde de tutulur. Kapılar >= 4.6 x 6.6 stud.
- Meydan (`HubBuilder.buildHub`; modeller `assets/HubProps` + `assets/HubModels`: satıcı tezgâhları, çeşme, bank, çiçeklik, karşılama/sıralama/adalar tahtaları, heykel): doğma noktası, Adalar tabelası ve `HubNpcs.vendor` ile 4 satıcı (`VendorPrompt`, `Action`:
  `orders`/`store`/`roadmap`/`travel`; client `FarmHud.client` ilgili pencereyi açar). Satıcı doğma noktasından >= 15 stud uzakta durur. Düzen kenar halkasıdır (`HubBuilder` buildHub başındaki açıklama): tahtalar ve satıcılar köprü aralarında merkeze bakar, köprü eksenleri boş kalır; merkezde yalnız çeşme.
- Ana ada avlusu (`IslandBuilder.decorateHome`): ana yolu çerçeveleyen çitler, saman balyaları, korkuluk, el arabası, kavşak yön tabelası (`buildSignpost`, ok yönleri `yaw` ile).
  Yeni avlu parçası bir `assets/CommonDecor` modeli olarak eklenir ve `WorldDecor` yardımcısıyla (`fenceRun/hayBale/scarecrow/wheelbarrow/barrel/crate/mailbox`, hepsi `DecorProps.placeDecor`) yerleştirilir; çarpışma modeldeki `CanCollide` değerinden gelir (çit/dekor çarpışmaz).
- Çalışma anı seviye işaretleri: `UpgradeSites.applyLevelMarks` (UpgradeVisualService çağırır) (tesis dibinde altın halkalar + "Sv.N" etiketi), `ZoneVisualService.applyLevelFlags` (bölge bayrakları).
- NPC tabelasında `title` + işlev satırı (`blurb`) vardır; NPC adı etkileşim ipucunda (`ObjectText`). Yeni satıcıya `blurb` zorunlu.
- Yapım alanları (`UpgradeSites.buildSite`): `UpgradeVisualService.apply` satın alınabilen ama alınmamış, karada yapı noktası olan binaların yerine `plot.Sites` altında toprak zemin +
  kazık + sarı şerit + fiyatlı tabela koyar (çalışma anında, harita sürümü gerekmez); alınınca kaldırılır ve bina kurulur. Denizdeki nokta (`BoatPatrolX`) atlanır.
- Meydan dekoru (`HubNpcs.fountain/bench/planter`): köprü ışınlarından (0°, 60°, ...) ve doğma noktasından uzak tut; satıcılar `HubNpc` etiketi taşır,
  `src/client/Interaction/HubNpcs.client.luau` onları canlandırır (göz teması, el sallama, selam balonu; yalnızca client'ta CFrame yazılır).
- Tabelalar (giriş `PlotSign`, ada `IslandSign`, yön `Signpost_Direction`, uzman/satılık `SpecialtySign`, ahır `LevelSign`; hepsi `assets/SignModels` ya da ahır modelinde, yazı kodla): uzun direk, tahta alt kenarı yerden >= 10 stud, tahta `CanCollide=false` (yolu kapatmaz).
  Yeni tabela eklerken `tests/map-structure.spec.luau` bu yüksekliği denetler.
- Ahır sandığı: `BarnVisualService.addStorageChest` (kapının sağı; `BarnChestPrompt` → Envanter/Ahır Deposu). Ürün merkezleri (Species satırlarından türeyen binalar): ilk temada süt merkezi ahırın arkasında, balık merkezi iskelenin yanında (`HOME_BUILD_SPOTS.milk_center/fish_cannery`, kapısı iskeleye bakar; iskele başında küçük balıkçı kulübesi `Shore.dock` → `ShoreModels/FisherHut_Lv1`),
  küçük adalarda `SATELLITE_TYPES[...].buildSpot/itemSpot` (±18, 0, 37; `SATELLITE_TYPES` `Config.FARM_ISLANDS` + `World/IslandLooks` satırından türer: yeni ada = `Config/Species.luau` satırı + bir `IslandLooks` satırı, `MAP_VERSION` +1; ana ada hayvanlarının yuvaları `Config.SPECIES` home satırlarından `HOME_BUILD_SPOTS`'a eklenir). Küçük adalar yarıçap 52'dir; yuvalar (`SATELLITE_SLOTS`) komşu çiftliklerle arada en az ~24 stud su kalacak biçimde hesaplıdır
  (yarıçap/yuva değişirse 6'lı halka için yeniden hesapla). Adadaki ağaç/çalı süsleri bina yerlerinden (`addIslandGrass` kaçınma dikdörtgenleri) uzak tutulur; yeni bina yeri eklerken kaçınma listesini de güncelle.
  Yeni bir "boost" yükseltmesi için yapı noktası zorunludur.
- Dekor bitince `WorldDecor.optimize(root)`: küçük parçalar gölge düşürmez, çarpışmayanlar `CanQuery=false` olur.
