Proje kuralları ve yapısı için @AGENTS.md dosyasını oku ve ona uy.

## Claude için kapsamlı kurallar

Cursor `.cursor/rules/*.mdc` dosyalarını otomatik yükler; Claude yüklemez. `@AGENTS.md` içindeki
**"Dokunduğun yere göre okunacak kural dosyası"** tablosuna bak: dokunacağın dosyanın satırındaki
kural dosyasını **bir kez** oku (hepsini baştan okuma). Tablo yalnızca `AGENTS.md`'de tutulur.

## Tek kaynak ve hızlı başlangıç

Kurallar `.cursor/rules/*.mdc`, iş akışları `.cursor/skills/<ad>/SKILL.md` içindedir (`.claude/skills/` yönlendirmedir). Oturumu `python scripts/triage.py` ile başlat; görev→komut tarifleri `docs/HIZLI_AKSIYON.md`, hızlı kontrol tablosu `AGENTS.md` içindedir.

## Mimari

Yeni dosya açmadan önce `docs/MIMARI.md` (katmanlar: sunucu `Modules → World → Presentation → Services`, istemci `Core → Effects → Ui → Interaction`).

## Skill'ler

`.claude/skills/*` yalnızca yönlendirir; tam metin `.cursor/skills/<ad>/SKILL.md` içindedir:
`roblox-add-remote`, `roblox-add-ui`, `roblox-add-content`, `roblox-map-change`,
`roblox-localize`, `roblox-save-schema`, `roblox-verify`.

## Devralma ve doğrulama

Yeni oturum için `docs/AI_DEVIR_REHBERI.md`; doğrulama için `roblox-verify` skill'ini kullan. Araç komutlarını burada çoğaltma. Önce hedef kaynak, tüketici ve testini izle; geniş çaplı inceleme istendiyse kapsamı aşamalara ayır. Studio'da gerçekten çalıştırılan ve bekleyen kontrolleri ayır.
