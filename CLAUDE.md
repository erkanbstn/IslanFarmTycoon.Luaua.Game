Proje kuralları ve yapısı için @AGENTS.md dosyasını oku ve ona uy.

## Claude için kapsamlı kurallar

Cursor bu kuralları dosya türüne göre otomatik yükler; Claude yüklemez. Aşağıdaki dosyalara
dokunmadan önce karşısındaki kural dosyasını **bir kez** oku (hepsini baştan okuma):

| Dokunduğun yer | Oku |
|---|---|
| Herhangi bir `.luau` | `.cursor/rules/luau-style.mdc` |
| `src/server/**` | `.cursor/rules/server-security.mdc` |
| `src/client/**`, `UiTheme`, `WorldUi`, `src/first/**` | `.cursor/rules/client-ui.mdc` |
| Oyuncuya görünen metin | `.cursor/rules/localization.mdc` |
| `MapBuilder`, `WorldDecor`, `*VisualService`, `plugin/**`, `DayNight`, `WeatherEffects` | `.cursor/rules/world-map.mdc` |
| `Config`, `FarmMath`, `GameTypes`, `SaveCodec`, `PlayerDataService`, `EconomyService` | `.cursor/rules/economy-data.mdc` |
| `src/client/*.client.luau` efekt/görsel scriptleri | `.cursor/rules/client-performance.mdc` |
| `tests/**`, `scripts/**`, proje/araç ayarları | `.cursor/rules/tests-tooling.mdc` |

## Skill'ler

`.claude/skills/*` yalnızca yönlendirir; tam metin `.cursor/skills/<ad>/SKILL.md` içindedir:
`roblox-add-remote`, `roblox-add-ui`, `roblox-add-content`, `roblox-map-change`,
`roblox-localize`, `roblox-save-schema`, `roblox-verify`.

## Çalışma biçimi
- Kapsamlı iş: yalnızca ilgili dosyayı ve en yakın tüketicisini/testini aç; repoyu baştan tarama.
- Değişiklik sonrası hızlı döngü: `stylua src tests plugin` → `selene src` → `python scripts/run-tests.py`.
  Commit öncesi: `powershell -ExecutionPolicy Bypass -File scripts/verify.ps1`.
- Studio'da görülmesi gerekenleri (HUD, ışık, harita yeniden kurulumu) kullanıcıya ayrıca yaz.
