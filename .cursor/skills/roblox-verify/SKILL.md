---
name: roblox-verify
description: Runs this Roblox project's automated checks (StyLua, Selene, Luau compile, pure Luau regression tests, locale coverage, Rojo builds) and lists the manual Studio checks that remain. Use after code changes, before committing, or when the user asks to test, lint, format or verify the project.
---

# Doğrulama

## Hızlı döngü (küçük değişiklik)
```
stylua src tests plugin
selene src
python scripts/run-tests.py
```

## Tam doğrulama (commit öncesi)
```
powershell -ExecutionPolicy Bypass -File scripts/verify.ps1
```
Sırasıyla (tam liste ve komutlar `scripts/verify.ps1`'dedir): StyLua kontrol, Selene, Luau derleme, regresyon testleri, ekonomi simülasyonu duman testi, `check-locales.py --strict-literals`,
rehber tutarlılığı (`check-ai-docs.py`), saf modül tip analizi, mimari bağımlılık kuralları (`check-architecture.py`, `docs/MIMARI.md`), tip analizi tabanı (`check-types.py`; yeni bulgu = hata),
oyun/eklenti/test Rojo derlemeleri, kurulu Studio eklentisinin bayatlık uyarısı.
- `.tools/luau-lsp` yoksa tip analizi atlanır ama görünür uyarı basılır (`-RequireTypes` ile hata sayılır); kurulum: `powershell scripts/setup-types.ps1`.
- Araçlar: Rojo/StyLua/Selene sürümleri `rokit.toml`'da (`rokit install`); Luau yorumlayıcı/derleyici/analizör `.tools/luau` altında (sürüm `verify.ps1`'de sabit; `-LuauDirectory` ile değiştirilir).
- CI yoktur: doğrulama yerelde `verify.ps1` ile yapılır.

## Otomatik testin kapsamadığı (kullanıcıya açıkça söyle)
- Studio görsel kontrol: HUD 1920x1080 / 1366x768 / telefon; gece ışıkları (yönetici: Gece + Güçlü).
- Harita değiştiyse: eklenti "Haritayı Kur" + place kaydı, sonra Play.
- Çok oyunculu (Test → Server + 2 Players), DataStore kesintisi, gamepad, FPS (MicroProfiler).
- Kod klasörü/eklenti yapısı ya da `plugin/` değiştiyse: eklentiyi yeniden üret (`rojo build plugin.project.json --plugin IslandFarmTycoonHarita.rbxm`), Rojo'yu yeniden Connect et.
- Dünya testleri: `rojo build test.project.json` place'inde `tests/run.server.luau`; harita yapısı için Studio eklenti panelinde **Haritayı Doğrula**
  (`tests/map-structure.spec.luau` + `tests/world.spec.luau`, eklentiye gömülü; kodu değiştirdiysen eklentiyi yeniden üret).

Sonuç raporunda hangi kontrolün koştuğunu ve hangisinin Studio'da bekleyeceğini ayrı yaz.
