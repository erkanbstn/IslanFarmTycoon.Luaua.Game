# GPT model iş listesi — tamamlama raporu

P1 harita grubunun 5 modeli için [ayrı rapor](gpt-model-p1-map.md). Bu dosya kalan 62 modeli listeler; 356 BasePart. Önceki grupla toplam 67 model / 374 BasePart.

Üreticiler: `tools/models/generate_p1_map.py`, `tools/models/generate_remaining.py`, `tools/models/model_xml.py`. Her model yazıldıktan hemen sonra XML, ad, pivot, Shape, parça sayısı ve PrimaryPart kontrol edildi.

| Ad | Dosya | Parça | Kutu X×Y×Z | Pivot | Not |
|---|---|---:|---|---|---|
| Gull | `client-assets/Birds/Gull.rbxmx` | 6 | 4.40×0.46×1.75 | Body merkezi | Body/LeftWing/RightWing ayrı |
| Songbird | `client-assets/Birds/Songbird.rbxmx` | 6 | 4.40×0.46×1.75 | Body merkezi | Body/LeftWing/RightWing ayrı |
| ReefFish | `client-assets/Fish/ReefFish.rbxmx` | 6 | 0.55×0.74×1.88 | Body merkezi | Tail WedgePart; Tint yüzgeç |
| Jellyfish | `client-assets/Sea/Jellyfish.rbxmx` | 6 | 2.40×4.10×2.40 | JellyBell merkezi | 5 ayrı JellyTentacle |
| BranchCoral | `client-assets/Sea/BranchCoral.rbxmx` | 11 | 2.48×4.22×2.43 | zemin | 5 dallı, uçlar tepede |
| BrainCoral | `client-assets/Sea/BrainCoral.rbxmx` | 6 | 5.30×1.87×3.10 | zemin | 3 yassı elips küme |
| FanCoral | `client-assets/Sea/FanCoral.rbxmx` | 6 | 4.41×4.10×1.06 | zemin | dik duran 3 yelpaze |
| SeaRock_A | `client-assets/Sea/SeaRock_A.rbxmx` | 3 | 3.06×2.00×2.95 | zemin | düz tabanlı kaya yığını |
| SeaRock_B | `client-assets/Sea/SeaRock_B.rbxmx` | 3 | 3.94×2.50×3.07 | zemin | düz tabanlı kaya yığını |
| SeaRock_C | `client-assets/Sea/SeaRock_C.rbxmx` | 3 | 2.49×1.80×2.51 | zemin | düz tabanlı kaya yığını |
| Starfish | `client-assets/Sea/Starfish.rbxmx` | 6 | 2.91×0.30×2.77 | zemin | 5 kol, merkezde birleşir |
| BareBranch | `client-assets/Season/BareBranch.rbxmx` | 1 | 0.25×3.00×0.25 | zemin | pivot dalın alt ucu |
| FallingLeaf | `client-assets/Season/FallingLeaf.rbxmx` | 1 | 0.22×0.05×0.42 | merkez | düşen yaprak; merkez pivot |
| OakTree_A | `assets/CommonDecor/OakTree_A.rbxmx` | 6 | 8.20×14.20×7.70 | zemin | Trunk silindir; 4 mevsimlik Leaves |
| OakTree_B | `assets/CommonDecor/OakTree_B.rbxmx` | 6 | 8.10×14.50×7.40 | zemin | Trunk silindir; 4 mevsimlik Leaves |
| OakTree_C | `assets/CommonDecor/OakTree_C.rbxmx` | 6 | 8.25×14.40×7.90 | zemin | Trunk silindir; 4 mevsimlik Leaves |
| OakTree_D | `assets/CommonDecor/OakTree_D.rbxmx` | 6 | 8.15×14.50×7.70 | zemin | Trunk silindir; 4 mevsimlik Leaves |
| PineTree_A | `assets/CommonDecor/PineTree_A.rbxmx` | 6 | 8.50×14.30×8.50 | zemin | 5 elips iğne katmanı |
| PineTree_B | `assets/CommonDecor/PineTree_B.rbxmx` | 6 | 8.50×14.30×8.50 | zemin | 5 elips iğne katmanı |
| PineTree_C | `assets/CommonDecor/PineTree_C.rbxmx` | 6 | 8.50×14.30×8.50 | zemin | 5 elips iğne katmanı |
| Bush_A | `assets/CommonDecor/Bush_A.rbxmx` | 3 | 4.20×2.90×3.85 | zemin | Leaves/Berry mevsim adları |
| Bush_B | `assets/CommonDecor/Bush_B.rbxmx` | 3 | 4.30×3.10×3.75 | zemin | Leaves/Berry mevsim adları |
| Bush_Berry | `assets/CommonDecor/Bush_Berry.rbxmx` | 7 | 4.20×2.90×4.00 | zemin | Leaves/Berry mevsim adları |
| FlowerPatch_Yellow | `assets/CommonDecor/FlowerPatch_Yellow.rbxmx` | 14 | 4.00×1.23×3.95 | zemin | 7 Stem + 7 Bloom |
| FlowerPatch_Pink | `assets/CommonDecor/FlowerPatch_Pink.rbxmx` | 14 | 4.00×1.23×3.95 | zemin | 7 Stem + 7 Bloom |
| FlowerPatch_White | `assets/CommonDecor/FlowerPatch_White.rbxmx` | 14 | 4.00×1.23×3.95 | zemin | 7 Stem + 7 Bloom |
| FlowerPatch_Purple | `assets/CommonDecor/FlowerPatch_Purple.rbxmx` | 14 | 4.00×1.23×3.95 | zemin | 7 Stem + 7 Bloom |
| FlowerPatch_Orange | `assets/CommonDecor/FlowerPatch_Orange.rbxmx` | 14 | 4.00×1.23×3.95 | zemin | 7 Stem + 7 Bloom |
| Crate_16 | `assets/CommonDecor/Crate_16.rbxmx` | 3 | 1.60×1.60×1.75 | zemin | kenar 1.6 stud |
| Crate_20 | `assets/CommonDecor/Crate_20.rbxmx` | 3 | 2.00×2.00×2.15 | zemin | kenar 2 stud |
| Crate_24 | `assets/CommonDecor/Crate_24.rbxmx` | 3 | 2.40×2.40×2.55 | zemin | kenar 2.4 stud |
| GrassTuft | `assets/CommonDecor/GrassTuft.rbxmx` | 2 | 1.20×1.00×1.20 | zemin | iki çapraz Tuft |
| GrassTuft_Flower | `assets/CommonDecor/GrassTuft_Flower.rbxmx` | 4 | 1.27×1.00×1.20 | zemin | iki çapraz Tuft + çiçek |
| HubTitleBoard | `assets/HubModels/HubTitleBoard.rbxmx` | 2 | 20.00×19.00×1.50 | zemin | Title düz; kod yazı ekler |
| HubTravelBoard | `assets/HubModels/HubTravelBoard.rbxmx` | 3 | 6.00×5.70×0.45 | zemin | TravelBoard yazı yüzeyi |
| HubPlayerBoard | `assets/HubModels/HubPlayerBoard.rbxmx` | 5 | 16.40×11.55×0.55 | zemin | PlayerBoard çarpışmaz |
| Rock_A | `assets/CommonDecor/Rock_A.rbxmx` | 3 | 2.85×1.70×2.31 | zemin | kara kayası |
| Rock_B | `assets/CommonDecor/Rock_B.rbxmx` | 3 | 3.82×2.12×3.33 | zemin | kara kayası |
| Rock_C | `assets/CommonDecor/Rock_C.rbxmx` | 3 | 2.38×1.44×2.26 | zemin | kara kayası |
| Stump_A | `assets/CommonDecor/Stump_A.rbxmx` | 3 | 1.79×1.60×1.55 | zemin | kesilmiş ağaç kütüğü |
| Stump_B | `assets/CommonDecor/Stump_B.rbxmx` | 3 | 1.97×2.05×1.90 | zemin | kesilmiş ağaç kütüğü |
| LogPile | `assets/CommonDecor/LogPile.rbxmx` | 3 | 4.05×1.70×1.00 | zemin | 3 yatay silindir |
| Reed_A | `assets/CommonDecor/Reed_A.rbxmx` | 10 | 2.20×2.40×0.84 | zemin | kıyı sazlığı |
| Reed_B | `assets/CommonDecor/Reed_B.rbxmx` | 10 | 2.30×2.40×0.84 | zemin | kıyı sazlığı |
| Cattail | `assets/CommonDecor/Cattail.rbxmx` | 8 | 1.52×2.81×1.02 | zemin | 4 saz başağı |
| PalmTree_A | `assets/CommonDecor/PalmTree_A.rbxmx` | 10 | 8.39×9.70×9.15 | zemin | 4 gövde + 6 palmiye yaprağı |
| PalmTree_B | `assets/CommonDecor/PalmTree_B.rbxmx` | 10 | 8.99×9.71×9.13 | zemin | 4 gövde + 6 palmiye yaprağı |
| BirchTree_A | `assets/CommonDecor/BirchTree_A.rbxmx` | 8 | 6.60×12.35×6.20 | zemin | beyaz gövde, 4 taç |
| BirchTree_B | `assets/CommonDecor/BirchTree_B.rbxmx` | 8 | 6.52×12.35×6.12 | zemin | beyaz gövde, 4 taç |
| Mushroom_A | `assets/CommonDecor/Mushroom_A.rbxmx` | 5 | 1.45×1.66×1.45 | zemin | elips mantar şapkası |
| Mushroom_B | `assets/CommonDecor/Mushroom_B.rbxmx` | 5 | 1.70×1.86×1.70 | zemin | elips mantar şapkası |
| Mushroom_C | `assets/CommonDecor/Mushroom_C.rbxmx` | 5 | 1.95×2.06×1.95 | zemin | elips mantar şapkası |
| Pumpkin | `assets/CommonDecor/Pumpkin.rbxmx` | 3 | 2.00×2.06×2.00 | zemin | turuncu elips kabak |
| Sunflower_Single | `assets/CommonDecor/Sunflower_Single.rbxmx` | 10 | 2.47×3.75×2.47 | zemin | 8 altın taç yaprağı |
| Pile | `assets/ShoreModels/Pile.rbxmx` | 1 | 0.70×12.00×0.70 | zemin | tek 12 stud kazık; yükseklik yerleşim koduna bağlı |
| SnowCap_Oak | `assets/SeasonModels/SnowCap_Oak.rbxmx` | 3 | 6.50×1.45×6.40 | zemin | ağaç/çalı üstüne oturan kar |
| SnowCap_Pine | `assets/SeasonModels/SnowCap_Pine.rbxmx` | 4 | 7.20×6.47×7.20 | zemin | ağaç/çalı üstüne oturan kar |
| SnowCap_Bush | `assets/SeasonModels/SnowCap_Bush.rbxmx` | 3 | 3.90×0.77×3.05 | zemin | ağaç/çalı üstüne oturan kar |
| Snowman | `assets/SeasonModels/Snowman.rbxmx` | 8 | 1.80×4.83×1.96 | zemin | 8 parçalı kardan adam |
| Hub_Statue | `assets/HubModels/Hub_Statue.rbxmx` | 6 | 3.80×4.55×3.80 | zemin | meydan heykeli |
| Hub_Banner | `assets/HubModels/Hub_Banner.rbxmx` | 4 | 6.80×8.00×0.40 | zemin | meydan kumaş flaması |
| Hub_Flag | `assets/HubModels/Hub_Flag.rbxmx` | 3 | 3.79×9.44×0.48 | zemin | meydan bayrağı |

Doğrulama: `python scripts/check-assets.py` ve Rojo 7.4.4 `build` geçti. Studio Edit'te altı temsilî model `Workspace.ModelBench.GPT_Review` altında görsel kontrol edildi; kalan modellerin tek tek görsel incelemesi bekliyor. Studio Save/Publish yapılmadı.

Oyun kodu, yerleşim, köprü/Terrain ve MAP_VERSION değiştirilmedi. Model dosyaları tek başına oyundaki yordamsal çizimi değiştirmez; yükleyici bağlantısı ve Play doğrulaması entegrasyon aşamasındadır.

At adasındaki yuva konumu ve değirmenin kayıtlı sahnedeki kapısı bu model listesi dışında bekleyen sorunlardır.
