Proje kuralları ve yapısı için @AGENTS.md dosyasını oku ve ona uy.

## Claude için kapsamlı kurallar

Cursor `.cursor/rules/*.mdc` dosyalarını otomatik yükler; Claude yüklemez. `@AGENTS.md` içindeki
**"Dokunduğun yere göre okunacak kural dosyası"** tablosuna bak: dokunacağın dosyanın satırındaki
kural dosyasını **bir kez** oku (hepsini baştan okuma). Tablo yalnızca `AGENTS.md`'de tutulur.

## Mimari

Yeni dosya açmadan önce `docs/MIMARI.md` (katmanlar: sunucu `Modules → World → Presentation → Services`, istemci `Core → Effects → Ui → Interaction`).

## Skill'ler

`.claude/skills/*` yalnızca yönlendirir; tam metin `.cursor/skills/<ad>/SKILL.md` içindedir:
`roblox-add-remote`, `roblox-add-ui`, `roblox-add-content`, `roblox-map-change`,
`roblox-localize`, `roblox-save-schema`, `roblox-verify`.

## Çalışma biçimi
- Kapsamlı iş: yalnızca ilgili dosyayı ve en yakın tüketicisini/testini aç; repoyu baştan tarama.
- Değişiklik sonrası hızlı döngü: `stylua src tests plugin` → `selene src` → `python scripts/run-tests.py`.
  Commit öncesi: `powershell -ExecutionPolicy Bypass -File scripts/verify.ps1`.
- Studio'da görülmesi gerekenleri (HUD, ışık, harita yeniden kurulumu) kullanıcıya ayrıca yaz.
