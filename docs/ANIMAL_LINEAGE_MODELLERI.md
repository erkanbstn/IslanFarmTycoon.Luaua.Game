# Hayvan ırk kozmetikleri — İstek 6

36 hayvan × T2/T3/T4 = 108 XML model; toplam 338 parça.
- T2: Sv.4–6 gümüş/mavi; T3: Sv.7–9 altın; T4: Sv.10 turkuaz/elmas.
- Dosyalar yalnız o kademenin yeni parçalarıdır. T3=T2+T3; T4=T2+T3+T4 klonlanır.
- Kara hayvanları: 36 model/99 parça; küçük hayvanlar ve kuşlar:36/105; balıklar:36/134.
- Kara: çan, çiçek, boynuz kapağı, omuz zırhı, hörgüç/karavan örtüsü, orman rozeti, yele klipsi, kulak bağı, meşe kesesi gibi farklı motifler.
- Küçük/kuş: türüne uygun tüy, dalga, gözbenek, kurye mührü, benek, fan; arıda bal tacı, salyangozda iki spiral uç halkası, kaplumbağada kabuk karoları, ipekböceğinde segment süsleri.
- Balık: gümüş solungaç/üçgen pul/benek; altın yan desen/koide inci; T4 turkuaz üst incileri/şerit. Kalkan süsleri yassı gövdenin üst yüzündedir.
- Her model identity WorldPivotData=(0,0,0), PrimaryPart veya Body yok. Parçalar Lineage_ adında, Part/WedgePart/eşit Ball; mesh/script/ışık/GUI yok; anchored ve fizik/sorgu/temas kapalı.
- Koordinatlar yetişkin kaynak hayvanın Body.CFrame'ine göredir. Claude aksesuar modelini aynı yaş+ırk ölçeğiyle büyütüp Body CF'ye yerleştirmeli; parça offsetleri hayvanın BulkMoveTo listesine alınmalı.
- Kademe başına kara/küçük türlerde <=14, balıklarda <=8 parça. Birleşik XYZ en fazla %23,2143 büyüyor; %25 sınırı korunuyor.
- Kademeler arası ve kaynak modelle SAT/uygun sphere testleri hacim kesişmesi göstermedi; yüzeylere teğet temas korunur. Bu kaynak geometrisi doğrulamasıdır, canlı oyun testi değildir.
- Her dosyanın parça sayısı/XYZ ölçüsü: [ANIMAL_LINEAGE_MODELLERI.csv](ANIMAL_LINEAGE_MODELLERI.csv).
- Üreticiler: docs/model-ureticileri/generate_lineage_land.py, generate_lineage_small.py, generate_lineage_fish.py; bundled Python+NumPy ile tekrar çalıştırılabilir.
- Oyun kodu, kaynak hayvanlar, sahne/Terrain/MAP_VERSION değiştirilmedi; save/publish yapılmadı.
- Claude check-assets beklentisine 36×3 AnimalLineage eklemeli (592→700). Yerel 108 dosya ayrıca inspect(AnimalLineage), bütçe/koordinat/flag/cumulativebounds testinden geçti. Play yaş/ırk ölçeği, etiket ve yüzme/yürüme kabulü entegrasyonda.
