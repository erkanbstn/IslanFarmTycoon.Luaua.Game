# Kodsuz görsel geçiş — 2026-10-02

- Envanter: [KODSUZ_GECIS_ENVANTERI.md](../KODSUZ_GECIS_ENVANTERI.md). `Presentation/**`, `World/**`, `Effects/**` görsel üretimleri dosya:satır, S/V/D, sözleşme, tahmini parça ve model durumuyla listelendi.
- Önceki 54 `Buildings` + 24 `Animals` dosyasına dokunulmadı. Bu tur **166 yeni XML model**, **2.994 BasePart**; toplam `assets/` **244 model / 4.248 BasePart**.
- Studio Edit içinde yalnızca `Workspace.ModelBench` altına 17 yeni klasör kuruldu; geçici `__BuildBarn` temizlendi. `Plots`, `World`, Terrain, köprüler ve harita yerleşimi değiştirilmedi; Studio Save/Publish, kod değişikliği, commit/push yapılmadı.

| Asset klasörü | Dosya | İçerik |
|---|---:|---|
| `Barns` | 4 | `Barn_Lv1..4` |
| `Collectors` | 5 | `CollectorPile_Lv1..5` |
| `ZoneLevels` / `ZoneFlags` / `ZoneBases` | 10 / 4 / 3 | iki zemin ölçüsü × 5 seviye; dört bayrak; iki çit ve balık yürüme yolu |
| `ZoneDecor` | 32 | 13 tür + 4 ağıl + 3 su bölgesi + 6×2 ana tema |
| `LevelProps` / `Lineage` | 12 / 10 | yem 5, büyüme 3, depo 4; soy seviyesi 1..10 |
| `Pets` | 16 | kullanılan tür × yaka rengi gövdeleri |
| `FacilityProps` | 11 | yapım alanı, tesis süsü 1..5, altın halka 1..5 |
| `Extensions` / `ExtensionCapacity` | 7 / 12 | altı uzman yapı + yükleme dekoru; altı alanın kapasite 3/4 süsü |
| `HomeModels` / `HubProps` | 14 / 7 | ana ada yapıları/tarım/tema anıtları; dört satıcı ve meydan dekoru |
| `CommonDecor` / `ShoreModels` / `ProductionSites` | 14 / 2 / 3 | prop/tohum örnekleri; iskele/kulübe; üretim zemini |

- Yükleyici her modeli `ServerStorage.Assets.<klasör>.<ad>` yolundan alıp kaynak kurucunun zemin pivotuna `PivotTo` etmeli. Ahır `BarnSpot` ve -Z kapı; toplayıcı yığını `Collector` yanında yerel +X 6.4; bölge süsü Ground üst yüzeyinde; tesis süsü BuildSpot alt yüzeyinde yer alır.
- XML'de parça adları, ölçü, CFrame, renk, malzeme, şekil, çarpışma, şeffaflık ve pivot vardır; `Pets` içinde `Root` PrimaryPart korunur. XML **öznitelik, etiket, PointLight, GUI/Prompt ve iç Model hiyerarşisini içermez**.
- Kodun eklemesi gerekir: `NightLight/NightWindow + NightColor + kapalı PointLight`, `Windmill`, `RevealGate/RevealBarnLevel/RevealZoneId/RevealZoneLevel`, `AnimalObstacle`, `HubNpc/Action`, `PetFigure/PetKind/PetIsland/PetHome`, `CollectorPile.Level`, `ProductionSiteId`, `ExtensionId`, `ZoneId`, `LevelFlags.Signature` ve ilgili `PartCount`/görsel sürüm öznitelikleri.
- `WorldUi.sign/tag`, `ProductionSign`, `ChestTag`, `BarnChestPrompt`, satıcı/market/satın alma promptları ve seviye metinleri modelde yoktur; durum ve oyuncu verisine göre kod ekler. Mevcut kodda yeni grupların asset kancaları yok; dosyalar tek başına kod görsellerini değiştirmez.
- Kalan: ada/zemin/dağ/su/Terrain/köprü/Hub tabanı ve konuma bağlı yollar; tohumla geniş alana saçılan çim/ağaç örneklerinin diğer tohumları; istemci hareketi, gece, hava, su altı, parçacık, ses ve UI. Bu tur kapsamı gereği kodda kaldılar.
- Bilinçli fark: kaynak `SpecialMesh` çam küreleri Part/Ball yapıldı. Kaynaktaki >35 parçalı ahır Sv.4 (36), toplayıcı Sv.4/5 (36/43), bölge süsü Sv.4/5 (50/54), bazı ağıl/ev yapıları sadeleştirilmedi; sözleşme bütçesiyle çelişiyor.
- Doğrulama: 244 XML ayrıştırıldı, adlar dosya adlarıyla eşleşti, Rojo 7.4.4 `build` geçti (geçici çıktı silindi). Studio `GetPartsInPart`: 2.994 yeni parça, **ayrı modeller arası 0 temas**. Screen capture görüntüsü karanlık döndüğü için görsel QA sınırlı; satın alma/animasyon Play testi yapılmadı.
