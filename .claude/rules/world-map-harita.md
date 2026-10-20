---
description: Harita üretimi/sözleşmesi, çalışma anı çiftlik geçişi, taş yollar ve zemin modelleri
paths:
  - "src/server/World/**"
  - "plugin/**"
  - "src/server/Presentation/**"
---

# Harita ve dünya: Harita

Giriş dosyası: `.claude/rules/world-map.md` (konu haritası).

- Harita `MapBuilder.build()` ile üretilir; Studio'da `plugin/` "Haritayı Kur" butonu düzenleme
  modunda kurar, place kaydedilir. Sunucu `MapBuilder.validate()` ile `MapVersion`'ı doğrular:
  uyuşmazsa oyun açılmaz.
- MapBuilder/WorldDecor ile üretilen (place'e kaydedilen) her şeyde değişiklik → `MAP_VERSION` +1
  ve kullanıcıya "Haritayı Kur + place kaydet" hatırlat. `src/server/Presentation/*` (çalışma anı görselleri) sürüm gerektirmez.
- Klasörler: `World/` = place'e kaydedilen statik harita (oyun servislerine bağlanmaz; eklenti bu klasörü kopyalayıp çalıştırır, klasör adı/yapısı
  değişirse `plugin/MapTool.server.luau` ve `test.project.json` güncellenir, eklenti yeniden üretilir); `Presentation/` = oyuncu durumundan çalışma anında çizilenler.
- Harita sözleşmesi (Plots/Zones/Islands/BuildSpots/HubSpawn) `validate()` içindedir; yeni zorunlu
  parça eklersen oraya ve `tests/world.spec.luau` / `tests/map-structure.spec.luau`'ya ekle (Studio düzenleme modu).

## Çalışma anında ana çiftlik geçişi
- `MapBuilder.applyTheme` mevcut ağacı `ThemePatch` ile uzlaştırır; ortak ada tabanı/çit/dekor kimliği korunur. Büyük tema ağacını tek `Clone()` ile değiştirme.
- Geçişler `MainFarmService` kuyruğunda, `VisualWorkBudget` ortak kare bütçesiyle işler; bekleme sonrası sahiplik/kayıt koruması yeniden kontrol edilir. `WorldTransition` süresince normal görsel yenilemeleri ve kurulum efektleri durur.
- Bu çalışma anı yükleme düzeni, yerleşim veya place geometrisi değişmiyorsa MAP_VERSION artışı gerektirmez.

- Taş yollar `Shared/MapPaths` içindeki listeden çizilir (`homeSegments`); yardımcıların rotası aynı listeyi (`route`) kullanır, yol eklerken yalnızca oraya ekle. Haritada yardımcılar için öznitelikler: plot `HomeFrame`/`HomeRadius`, uzman ada modeli `IslandFrame`/`PathStart`/`PathEnd`. Yardımcılar ada başına (tür, ada) yuvasıdır (`ProductionLogic.petSlots`; tür/renk `UpgradeLevelProps.PET_SPECIES`).

- Tek parçalı görünür zeminler `SurfaceModels` (GroundDisc/GroundBlock/StonePath/GrassPatch/BeachDisc) üzerinden `ModelAssets.part` ile alınır; zorunlu yüzey eksik/bozuksa kurulum durur. Kod yalnız boyut/yerleşim uygular. İstemci havuz geometrisi `ClientModelAssets.clonePart` ile `client-assets/Effects` şablonlarından gelir. Yeniden üretim: `tools/models/generate_surfaces_effects.py`; işlevsiz Part yedeği ekleme. Terrain ve görünmez fizik/emitter çapaları kodda kalabilir.
