---
description: Model tabanlı görseller: geometri assets modellerinden gelir, kod çizmez
paths:
  - "src/server/World/**"
  - "src/server/Presentation/**"
  - "src/client/Effects/**"
---

# Harita ve dünya: Model Gorseller

Giriş dosyası: `.claude/rules/world-map.md` (konu haritası).

## Model tabanlı görseller (kod geometri çizmez)
- Oyunda görünen her şeyin geometrisi `assets/<klasör>/<ad>.rbxmx` (sunucu: `ServerStorage.Assets`, `World/ModelAssets`; istemci efektleri: `client-assets/` → `ReplicatedStorage.ClientAssets`, `Core/ClientModelAssets`)
  modelinden gelir. Kod yalnızca model dosyasında olamayanı ekler: yazı/ikon (`WorldUi`), prompt/etkileşim, gece ışığı etiketi (`ModelAssets.markLantern/markGlowWindow`), parçacık, öznitelik/etiket,
  boyuta/yerleşime bağlı ölçekleme. **Yeni görsel için `makePart`/`Instance.new("Part")` ile geometri yazma**: modeli `docs/MODEL_SOZLESMESI.md` iş akışıyla `assets/`a koy, `scripts/check-assets.py` beklenen listesine ekle, kodda `ModelAssets.clone/place` ile yerleştir.
  İsteğe bağlı model yoksa kod bir kez `warn` verir ve o görseli çizmez (yedek kod kurucusu yoktur); `check-assets.py` eksikte `verify.ps1`'i kırmızı yapar.
- İstemci efektleri `client-assets/` şablonlarından kurulur (`Core/ClientModelAssets`, model yoksa bir kez `warn`, çizilmez): `Birds` (kuş), `Fish` (`ReefFish` deniz dibi, `ShoreFish_A/B` yüzey sürüleri), `Sea` (mercan, kaya, yıldız, denizanası, `KelpBlade_A–C`
  (Lower/Upper alt modelleri; alt pivot 0, üst pivot y=4; hareket her karede `pivot * ofset`), `Seagrass_A–C`, `SeaAnemone`, `ShellCluster`, `Bubble`, `SurfaceWake`, `BoatFoam`, parçacık şablonları `AmbientBubbles/VentBubbles/EntryBubbles/SwimBubbles/Splash`
  (görünmez parça + kapalı `Rate=0` emitter; kod Enabled/Rate/ömür ve Emit'i yönetir) ve `UnderwaterAtmosphere` (tam güç `UnderwaterGrade`/`UnderwaterBlur` değerleri; kod 0..1 güçle ölçekler)). Seyrek dip yapıları `DiverChest`/`ReefArch` ayrı tohumlu RNG ile (orta/yüksek kalite) yerleşir. Yardımcının taşıdığı hayvan `assets/Animals` tek kaynağından `ClientAssets.Animals` olarak da çoğaltılır. `PetCargo` gerçek üretim görevindeki tür/ağılı seçer; `PetService` model/bölge özniteliklerini yayınlar. `PetAnimator` modeli ölçüsüne göre küçültüp yardımcı gövdesinin üstüne yerleştirir; taşıma nesnesi hareket gövde ölçüsüne katılmaz. Sandık/para `client-assets/PetProps/CarryCrate|CarryCoins` kullanır; tüm yük modelleri en büyük kenarı 1.8 stud olacak şekilde sınırlanır, yardımcı gövdesinin üstüne kutu ölçüsünden yerleştirilir. Yeni istemci efekt şablonu `check-assets.py` `CLIENT_EXPECTED` listesine, sunucu modeli `expected()` listesine girer.
- Model sözleşmesi `docs/MODEL_SOZLESMESI.md` / `docs/GPT_MODEL_IS_LISTESI.md`: yalnızca Part/WedgePart (+ elips için Block + `SpecialMesh` MeshType=Sphere), `WorldPivotData` zorunlu, Script/ışık/GUI/prompt/MeshPart yok.
  `PrimaryPart` verilmiş modelde pivot **PrimaryPart merkezidir** (Roblox WorldPivotData'yı yok sayar): yalnızca hayvan/yardımcı/kuş/balık/denizanasında kullan, tabela/dekor/zemin modülünde verme.
- Modeller doğrudan değil sarmalayıcıyla yerleşirse (ör. tabela, toplayıcı, meydan tahtaları) parçaları plot/hub modeline düz taşı; servisler ve testler `PlotSign`, `Collector`, `PlayerBoard`, `TravelBoard`, `IslandSign`, `SignPost` gibi adları doğrudan çocuk olarak arar.
- Ölçeklenen/dizilen modüller: köprü (`BridgeModels/BridgeModule_8/_2`, `MapParts.buildBridgeBetween`), iskele güvertesi (`ShoreModels/DockDeck_5` + kazık `Pile` boyu koddan, kazık katıdır), bölge çiti (`ZoneBases/ZoneFence_Segment_4/Corner`, ray boyu bölüme göre),
  balık yolu (`FishWalkway_Module` Deck'i boyutlandırılır), sandık (`Crate_16/20/24`).
- Çeşitlilik: ağaç/çalı/çiçek varyantları (`OakTree_A–D`, `PineTree_A–C`, `Bush_A/B/Berry`, `FlowerPatch_*`) tohumla seçilir (`DecorNature.placeVaried`); yerleşen modelin adı türün adıdır (`OakTree`, `PineTree`, `Bush`, `Flowers`) çünkü
  `SeasonalScenery` (client) mevsim rengini bu ad + parça adlarıyla (`Trunk`, `Leaves`, `Needles`, `Berry`, `Bloom`, `Stem`) bulur: yeni varyant bu adları korumalı. Ağaç/çalıya gizli `SnowCap` (assets/SeasonModels) oturur, kardan adam `Nature.scatterProps` ile serpiştirilir;
  ikisi de Transparency=1 gelir, client karlı mevsimde açar. Adalara serpiştirilen süsler (`Nature.scatterProps`: kaya, saz, kütük, mantar, kabak, ayçiçeği, huş, palmiye) `addIslandGrass` kaçınma listesine uyar.
- Tohum konuma bağlıdır (`MapParts.seedFrom`): şablon başka konumda kurulduğu için ağaç/çim/serpiştirme sayıları plot ile şablon arasında oynar; `tests/map-structure.spec` bunları (ScatterProps, GrassTufts, SnowCap, ağaç yolları) sayım dışı bırakır. Yeni tohumlu süs ekleyince aynı muafiyeti düşün.
