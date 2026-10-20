---
description: Ana ada düzeni/temaları, geliştirmeyle beliren yapılar, streaming, harita çevresi
paths:
  - "src/server/World/**"
  - "src/server/Presentation/**"
---

# Harita ve dünya: Ana Ada Duzen

Giriş dosyası: `.claude/rules/world-map.md` (konu haritası).

- Ana ada düzeni temaya göre değişir: `MapLayout.homePlacements(plotIndex)` batı kümesinde bahçe↔ambar ve değirmen↔kovan, doğuda çiftlik evi↔meyve bahçesi yer
  değiştirir, kuyu iki yandan birinde durur (6 düzen, yuvalar sabit; yol/bölge/yapı noktaları değişmez). Çim kaçınma dikdörtgenleri aynı yerleşimden türer
  (`homeBuildingAvoidRects`): yeni yapı eklersen `homePlacements`'a koy. Her temanın doğu kıyıda kendi işaret yapısı vardır (`Config.THEMES[n].landmark` →
  `HomeBuildings.landmark` (`HomeModels/Landmark_<tür>`): daisy/tulip/sunflower/rose/pine/cherry). `tests/map-structure.spec.luau` işaret yapısını ve >= 5 farklı yerleşimi denetler.
- Kayıtlı harita bütün fiziksel adaları 1. temayla kurar (`ThemeIndex` özniteliği); tema içeriği (BuildSpots, Decor, Islands + uzman bölgeler) `IslandBuilder.buildThemeContent` ile,
  her tema için sunucu açılışında bir kez `ServerStorage.ThemeTemplates/Theme<n>` şablonuna kurulur (`MapBuilder.prepareTemplates`, `ensure` çağırır; eklentide/place'te değil) ve çalışma anında `MapBuilder.applyTheme(plot, tema)` şablon farkını ThemePatch ile mevcut adaya uygular (PlotService çağırır; önce `DecorReveal.reset`). Mutlak konum taşıyan öznitelikler basılırken aynı farkla taşınır: yeni mutlak CFrame/Vector3 öznitelik eklersen `MapBuilder.POSITION_CFRAME_ATTRIBUTES` / `POSITION_VECTOR_ATTRIBUTES` beyaz listesine koy. Şablonlardaki etiketler sunucu `CollectionService`'inde de görünür: sunucuda `GetTagged` kullanan kod `Workspace.Plots` altını süzmeli (`IsDescendantOf`). `applyThemeProcedural` eski yordamsal yoldur, yalnızca `tests/map-structure.spec` karşılaştırması için referanstır. Boş ada temasını korur. Temaya bağlı kod `PlotId` değil `ThemeIndex` okur; yeni temaya bağlı parçayı `buildThemeContent` içine koy.
- Çimen yüzeyi ana/küçük ada ve çimenli bölgelerde `LeafyGrass` kullanır. Kilit/tema güncellemesi dokuyu eski `Grass` değerine çevirmemeli; mevsim kodu kar eriyince kaynağın özgün malzemesini geri yükler. Düz ton yamaları da aynı mevsim renklendirmesine katılır.
- Ada temaları çiftlik numarasına bağlanır (Çiftlik 1 = Papatya ...); genel ada çekirdeği hepsinde ortaktır; ağıl/otlak görünümü temaya göre değişir (`assets/ZoneDecor/Decor_pasture_T<1-6>`, `Decor_starter_T<1-6>`).

- **Geliştirmeyle beliren yapılar**: haritaya kaydedilen süs yapıları `RevealGate` etiketli Model olarak kurulur (`RevealBarnLevel = n` ya da `RevealZoneId` + `RevealZoneLevel = n`;
  ana ada: kuyu/tarla ahır Sv.2, değirmen/kovan/ambar Sv.3, meyve bahçesi/anıt Sv.4, çiftlik evi otlak Sv.1; iskele kulübesi balık kafesi Sv.1). `Presentation/DecorReveal.apply` (UpgradeVisualService'ten çağrılır)
  hak edilmeyeni `ServerStorage.HiddenDecor`a alır, hak edilince eski yerine koyar; yeni bir kapılı yapıda yalnızca öznitelik + etiket yeter.
- **Seviyeli yükseltmelerin görünen karşılığı**: bölge/tesis seviyeleri `assets/ZoneLevels` / `assets/FacilityProps`, Yem Kalitesi / Depo Genişletme / Hızlı Büyüme zincirleri
  `Presentation/UpgradeLevelProps` (yem istasyonu, depo yığını, büyüme feneri) ile çizilir; her seviye yeni bir şey ekler (çarpışan parçalar katıdır, ince süsler geçilir).
- Streaming: `default.project.json` Workspace `StreamingMinRadius`/`StreamingTargetRadius`: adalar arası görünürlük ve uzaklaştırınca denizin (Terrain) dolu görünmesi bu değerlere bağlıdır (Target 448 iken kameradan uzak su parçaları yüklenmeyip karanlık "delik" gibi görünüyordu; şimdi 1024), harita yarıçapını büyütürsen ikisini de gözden geçir.
- Eklenti kapasitesi 3/4 olunca alanın arka kenarına su teknesi + saman, gölgelik + fener eklenir (`ExtensionVisualService.addCapacityProps`); ırk geliştirme (Irk Sv.1+) ana adada "ırk anıtı"
  olarak görünür (`UpgradeLevelProps.lineageMonument`: tür başına kaide, Sv.1-3 bronz top, 4-6 gümüş kupa, 7-9 altın kupa, 10 taç ve ışık). Meydan/pazar tezgâhlarının yanları panelle kapalıdır.
- **Harita çevresi**: `World/MapMountains` iki sıra Terrain dağı (iç sıra ~505, dış sıra ~575 yarıçap, karlı doruklar) ve `MapRim` (aynı dosyada) görünmez dairesel duvar (yarıçap 452, yükseklik 320) kurar;
  denizin sonuna yüzülemez. Oyun alanı ~435 yarıçaptadır (ada halkası 175 + küçük ada yuvası 200 + yarıçap 52 + kum): bu sınırları değiştirirsen dağ/duvar yarıçaplarını da kaydır.
