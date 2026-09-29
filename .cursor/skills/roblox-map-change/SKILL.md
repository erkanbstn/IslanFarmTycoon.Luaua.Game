---
name: roblox-map-change
description: Changes the generated island map, decor, lamps or build spots in MapBuilder/WorldDecor for this Roblox project, including MAP_VERSION bumps, the Studio map plugin rebuild, the validate() contract and night light tagging. Use when editing map layout, bridges, islands, decor, street lamps, windows, lighting or when the game says the map version is mismatched.
---

# Harita değişikliği

## Karar: place'e kaydedilen mi, çalışma anında mı?
- `MapBuilder.luau` / `WorldDecor.luau` (MapBuilder'dan çağrılan) → place'e kaydedilir →
  **MAP_VERSION +1** ve Studio'da yeniden kurulum gerekir.
- `*VisualService.luau` (ahır, bölge, yükseltme, hayvan, eklenti görselleri) → sunucu her oturumda
  kurar → sürüm gerekmez.

## Adımlar
```
- [ ] 1. Değişikliği yap (Shared'ı script.Parent.Parent üzerinden arayan yedeği koru)
- [ ] 2. MAP_VERSION +1 (yalnızca place'e kaydedilen değişiklikte)
- [ ] 3. Yeni zorunlu parça → MapBuilder.validate() + tests/world.spec.luau / tests/map-structure.spec.luau
- [ ] 3b. Dekor bitince WorldDecor.optimize; tabela eklediysen uzun direk + CanCollide=false (yüksekliği map-structure denetler)
- [ ] 4. rojo build (verify.ps1) + selene
- [ ] 5. Kullanıcıya: Studio'da eklenti → "Haritayı Kur" → place'i kaydet
```

## Gece ışığı ekleme
```luau
-- Hazır: WorldDecor.lamp(parent, cf) / WorldDecor.smallLamp(parent, cf) / WorldDecor.markNightWindow(part)
-- Elle:
lantern:SetAttribute("NightColor", Color3.fromRGB(255, 214, 130))
CollectionService:AddTag(lantern, "NightLight") -- pencere için "NightWindow"
local light = Instance.new("PointLight")
light.Brightness = 3 -- taban; DayNight rampa ve yönetici çarpanıyla ölçekler
light.Range = 24
light.Shadows = false
light.Enabled = false
light.Parent = lantern
```
Etiket olmadan ışık hep açık kalır ve yönetici panelinden kontrol edilemez.

## Sorun giderme
- "Harita sürümü uyumsuz" → place eski; "Haritayı Kur" + kaydet.
- Işık görünmüyor → etiket var mı, `PointLight` parçanın doğrudan çocuğu mu, gece gerçekten
  karanlık mı (DayNight NIGHT tablosu), Bloom eşiği Neon'u bastırıyor mu.
- Yönetici paneli: Saat = Gece, Işıklar = hep açık, Parlaklık = Güçlü ile hızlı test.
