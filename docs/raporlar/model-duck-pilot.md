# Ördek modeli pilotu (02.10.2026)

- Çalışma alanı: `Workspace.ModelBench`; `ServerStorage.Assets` ve repo kodu değiştirilmedi.
- `Buildings/duck_packer`: 24 BasePart; zemin pivotu `(1000,4,175)`, yerel ön `-Z`, kutu 10.98 × 12.00 × 9.20 stud. Mavi tahta gövde, eğimli kahverengi çatı, açık giriş, cam yan pencereler, çatı ördeği.
- Giriş 4.6 × 5.1 stud test kutusu ve üretim prompt noktası `(0,2.5,-6)` boş. Sözleşmedeki 6.6 stud kapı yüksekliği, 6 stud kod gövdesiyle çeliştiği için sağlanamıyor.
- `Plot1.BuildSpots.duck_packer` üzerinde `GetPartsInPart`: 16 temasın tamamı aynı noktayı paylaşan mevcut `milk_factory` prototipiyle; o alternatif hariç istenmeyen temas 0.
- `Animals/duck`: 15 BasePart; `Body` PrimaryPart, bakış `-Z`, yetişkin yüksekliği 2.95 stud. `ScaleTo`: yavru 1.63, genç 2.36, yetişkin 2.95 stud.
- Her iki modelde script, prompt, açık ışık, GUI, yasak pencere malzemesi 0. Hayvan parçaları `CanCollide=false`, `CanQuery=false`; bina parçaları çarpışır.
- Ön ve yakın kamera görüntüleri kontrol edildi; kopuk görünen kanatlar gövdeye yaklaştırıldı.
- Studio `SerializationService` ikili `.rbxm` üretti; Rojo 7.4.4 yeni `Tags` tipini okuyamadığı için bu iki ikili dosya silindi. Aynı parça verisi okunabilir `.rbxmx` olarak `assets/Buildings/duck_packer.rbxmx` ve `assets/Animals/duck.rbxmx` dosyalarına aktarıldı. Rojo build geçti.
- Rojo ile Studio'ya yüklenen iki model, tezgâhtaki modellerle parça imzası/pivot açısından 0 fark; `duck` PrimaryPart=`Body`. Kalan `wool_mill`, `truffle_kitchen`, `cheese_dairy`, `sheep`, `pig`, `goat` da `.rbxmx` olarak aktarıldı; sekiz modelde Studio senkron farkı 0.
- Kısa Play açılış hatası olmadan geçti. MCP komutunda `AssetSanitizer`/`AnimalModels` require işlemi Capabilities nedeniyle reddedildi; satın alınmış bina/hayvanın gerçek servis klonlama dalı henüz oynanışta sınanmadı. Kod kurucuları yedek olarak duruyor.
