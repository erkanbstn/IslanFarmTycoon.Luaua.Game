# GPT model P1 harita grubu

Üretici: `tools/models/generate_p1_map.py`. Her dosya yazıldıktan hemen sonra XML, ad, pivot, parça sayısı ve Shape doğrulandı.

| Ad | Dosya yolu | Parça | Kutu (X×Y×Z) | Pivot | Not |
|---|---|---:|---|---|---|
| BridgeModule_8 | `assets/BridgeModels/BridgeModule_8.rbxmx` | 3 | 8.50×3.00×8.00 | (0,0,0), güverte üstü | Deck çarpışır; iki Rail çarpışmaz |
| BridgeModule_2 | `assets/BridgeModels/BridgeModule_2.rbxmx` | 3 | 8.50×3.00×2.00 | (0,0,0), güverte üstü | Kalan köprü uzunluğu modülü |
| IslandSign | `assets/SignModels/IslandSign.rbxmx` | 3 | 7.60×15.40×0.50 | (0,0,0), zemin | IslandSign yazı yüzeyi düz, çarpışmaz |
| Signpost_Direction | `assets/SignModels/Signpost_Direction.rbxmx` | 4 | 5.40×7.00×0.65 | (0,0,0), direk tabanı | Üç Board düz; kod yazıları ekler |
| SaleMarker | `assets/SignModels/SaleMarker.rbxmx` | 5 | 8.01×11.07×5.16 | (0,0,0), direk tabanı | SaleBanner düz; üç SaleStone kaynak ölçü/açıyla |

Toplam: **5 model, 18 Part**. Hepsi Block Shape=1; Script, ışık, GUI, etiket ve prompt yok. `python scripts/check-assets.py` ve Rojo 7.4.4 `build` geçti. Studio Edit'te Rojo ile `ServerStorage.Assets` altına geldi; `Workspace.ModelBench.P1_Map` altında beş test kopyası ve ekran görüntüsüyle kontrol edildi. Kaydedilmiş haritaya, Terrain'e, yerleşim koduna ve oyun koduna dokunulmadı; Studio Save/Publish yapılmadı.

Bu modelleri harita kodu henüz kullanmıyor. Entegrasyondan sonra gerçek köprü uzunlukları/yazı yüzleri Play'de test edilmeli. At adasındaki yuva konumu şikâyeti bu gruptan ayrıdır ve henüz düzeltilmedi.
