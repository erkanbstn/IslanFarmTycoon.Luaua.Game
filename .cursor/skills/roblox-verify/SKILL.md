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
Sırasıyla: StyLua kontrol, Selene, Luau derleme, regresyon testleri, `check-locales.py
--strict-literals`, yapay zeka rehber dosyaları denetimi (`check-ai-docs.py`), saf modül tip analizi, **mimari bağımlılık kuralları**
(`check-architecture.py`, `docs/MIMARI.md`), **tip analizi tabanı** (`check-types.py`; yeni bulgu = hata, araçlar `.tools/luau-lsp` yoksa atlanır:
`powershell scripts/setup-types.ps1`), oyun/eklenti/test Rojo derlemeleri. Araçlar `rokit.toml` sürümleri ve
`.tools/luau` (Luau 0.740). Eksikse: `rokit install`.

## Otomatik testin kapsamadığı (kullanıcıya açıkça söyle)
- Studio görsel kontrol: HUD 1920x1080 / 1366x768 / telefon; gece ışıkları (yönetici: Gece + Güçlü).
- Harita değiştiyse: eklenti "Haritayı Kur" + place kaydı, sonra Play.
- Çok oyunculu (Test → Server + 2 Players), DataStore kesintisi, gamepad, FPS (MicroProfiler).
- Kod klasörü/eklenti yapısı değiştiyse: eklentiyi yeniden üret (`rojo build plugin.project.json --plugin IslandFarmTycoonHarita.rbxm`), Rojo'yu yeniden Connect et.
- Dünya testleri: `rojo build test.project.json` place'inde `tests/run.server.luau`; harita yapısı için Studio eklenti panelinde **Haritayı Doğrula**
  (`tests/map-structure.spec.luau` + `tests/world.spec.luau`, eklentiye gömülü; kodu değiştirdiysen eklentiyi yeniden üret).

Sonuç raporunda hangi kontrolün koştuğunu ve hangisinin Studio'da bekleyeceğini ayrı yaz.
