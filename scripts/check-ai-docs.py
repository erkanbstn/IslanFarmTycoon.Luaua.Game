#!/usr/bin/env python3
"""Yapay zeka rehberinin (CLAUDE.md, .claude/rules, .claude/skills, devir belgeleri) tutarlılığını denetler.

Denetimler:
  * CLAUDE.md tek giriş dosyasıdır; kural tablosu, skill listesi, çıpalar ve "Hızlı kontrol komutları" bölümü vardır.
  * Her .claude/rules/*.md: description + boş olmayan `paths:` listesi var, her glob en az bir dosyayla eşleşir, CLAUDE.md'de anılır.
  * Her .claude/skills/<ad>/SKILL.md: name == klasör adı, description var, yönlendirme değil tam metin; CLAUDE.md `ad` ile listeler.
  * Rehber dosyalarında geçen repo yolları (src/..., tests/..., .claude/...) gerçekten vardır.
  * Tek kaynak: kural/skill yalnız .claude altında; .cursor, .cursorrules, AGENTS.md, .github/copilot-instructions.md,
    .github/instructions, .github/prompts ve herhangi bir .mdc dosyası yoktur.
Test için kök AI_DOCS_ROOT ile değiştirilebilir.
"""

from __future__ import annotations

import os
import re
import sys
from pathlib import Path

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

ROOT = Path(os.environ.get("AI_DOCS_ROOT") or Path(__file__).resolve().parent.parent)
errors: list[str] = []
FRONTMATTER = re.compile(r"^---\r?\n(.*?)\r?\n---\r?\n", re.S)


def fail(message: str) -> None:
    errors.append(message)


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def frontmatter(text: str) -> dict[str, str | list[str]]:
    """Basit YAML alt kümesi: `anahtar: değer` ve `anahtar:` + `  - "öğe"` listeleri."""
    match = FRONTMATTER.match(text)
    if not match:
        return {}
    fields: dict[str, str | list[str]] = {}
    current: str | None = None
    for line in match.group(1).splitlines():
        item = re.match(r"^\s+-\s+(.*?)\s*$", line)
        if item and current is not None:
            value = item.group(1).strip("\"'")
            existing = fields.get(current)
            if isinstance(existing, list):
                existing.append(value)
            continue
        if ":" in line and not line.startswith((" ", "\t")):
            key, value = line.split(":", 1)
            current = key.strip()
            fields[current] = value.strip() if value.strip() else []
    return fields


def text_field(fields: dict[str, str | list[str]], key: str) -> str:
    value = fields.get(key, "")
    return value if isinstance(value, str) else ""


def list_field(fields: dict[str, str | list[str]], key: str) -> list[str]:
    value = fields.get(key, [])
    return value if isinstance(value, list) else []


# ---------------------------------------------------------------- giriş dosyası
claude_md = ROOT / "CLAUDE.md"
if not claude_md.exists():
    fail("CLAUDE.md yok")
    claude_text = ""
else:
    claude_text = read(claude_md)

all_files = [p for p in ROOT.rglob("*") if p.is_file() and ".git" not in p.parts and ".test-build" not in p.parts and ".tools" not in p.parts]
relative_files = [p.relative_to(ROOT).as_posix() for p in all_files]

# ---------------------------------------------------------------- kurallar
rules_dir = ROOT / ".claude" / "rules"
rule_files = sorted(rules_dir.glob("*.md")) if rules_dir.exists() else []
if not rule_files:
    fail(".claude/rules altında kural yok")


def glob_matches(pattern: str) -> bool:
    regex = re.escape(pattern)
    regex = regex.replace(r"\*\*/", "(?:.*/)?").replace(r"\*\*", ".*").replace(r"\*", "[^/]*")
    compiled = re.compile("^" + regex + "$")
    return any(compiled.match(f) for f in relative_files)


for rule in rule_files:
    fields = frontmatter(read(rule))
    rel = rule.relative_to(ROOT).as_posix()
    if not text_field(fields, "description"):
        fail(f"{rel}: description eksik")
    patterns = list_field(fields, "paths")
    if not patterns:
        fail(f"{rel}: paths listesi eksik veya boş")
    for pattern in patterns:
        if not glob_matches(pattern):
            fail(f"{rel}: glob hiçbir dosyayla eşleşmiyor: {pattern}")
    if rel not in claude_text:
        fail(f"CLAUDE.md tablosunda {rel} geçmiyor")

# ---------------------------------------------------------------- skill'ler
skills_dir = ROOT / ".claude" / "skills"
names = sorted(p.name for p in skills_dir.iterdir() if p.is_dir()) if skills_dir.exists() else []
if not names:
    fail(".claude/skills altında skill yok")
MIN_SKILL_BODY_LINES = 12  # bundan kısa gövde yönlendirme taslağıdır; talimat burada yaşamalı
for name in names:
    skill = skills_dir / name / "SKILL.md"
    rel = f".claude/skills/{name}/SKILL.md"
    if not skill.exists():
        fail(f"{rel} yok")
        continue
    text = read(skill)
    fields = frontmatter(text)
    if text_field(fields, "name") != name:
        fail(f"{rel}: name alanı klasör adıyla eşleşmiyor")
    if not text_field(fields, "description"):
        fail(f"{rel}: description eksik")
    body = FRONTMATTER.sub("", text, count=1).strip()
    body_lines = [line for line in body.splitlines() if line.strip()]
    if len(body_lines) < MIN_SKILL_BODY_LINES:
        fail(f"{rel}: gövde {len(body_lines)} satır (< {MIN_SKILL_BODY_LINES}); yönlendirme taslağı değil tam talimat olmalı")
    for other in re.findall(r"[\w./-]*SKILL\.md", body):
        if other not in (rel, "SKILL.md") and not other.startswith(".claude/skills/"):
            fail(f"{rel}: başka bir kaynak skill dosyasına yönlendiriyor: {other}")
    if claude_md.exists() and f"`{name}`" not in claude_text:
        fail(f"CLAUDE.md skill'i listelemiyor: {name}")

# ---------------------------------------------------------------- yol referansları
PATH_PATTERN = re.compile(r"`((?:src|tests|scripts|plugin|docs|assets|\.claude)/[A-Za-z0-9_./-]+\.(?:luau|md|py|ps1|json|toml))`")
guide_files = [claude_md, *rule_files, *sorted(skills_dir.glob("*/SKILL.md"))]
for doc in guide_files:
    if not doc.exists():
        continue
    for match in PATH_PATTERN.finditer(read(doc)):
        reference = match.group(1)
        if any(ch in reference for ch in "*<>"):
            continue
        if not (ROOT / reference).exists():
            fail(f"{doc.relative_to(ROOT).as_posix()}: var olmayan yol: {reference}")

# ---------------------------------------------------------------- mimari belgesi
architecture = ROOT / "docs" / "MIMARI.md"
if not architecture.exists():
    fail("docs/MIMARI.md yok")
else:
    architecture_text = read(architecture)
    if claude_md.exists() and "MIMARI.md" not in claude_text:
        fail("CLAUDE.md docs/MIMARI.md'ye referans vermiyor")
    for side in ("server", "client"):
        for directory in sorted((ROOT / "src" / side).iterdir()):
            if directory.is_dir() and f"`{directory.name}/`" not in architecture_text:
                fail(f"docs/MIMARI.md src/{side}/{directory.name}/ katmanını anlatmıyor")
    for reference in PATH_PATTERN.finditer(architecture_text):
        if not any(ch in reference.group(1) for ch in "*<>") and not (ROOT / reference.group(1)).exists():
            fail(f"docs/MIMARI.md: var olmayan yol: {reference.group(1)}")

# ---------------------------------------------------------------- MIMARI.md dosya listeleri ↔ klasörler
# Katman satırları ("| 2 | `World/` | ... |") o klasördeki her .luau dosyasını adıyla anmalı ve var olmayan dosya adı anmamalı.
# Kısaltma: `X`/`Y` biçimi (ör. `DecorProps`/`DecorShore`) ortak öneki olan iki dosyayı birden anar (ilk adın son sözcüğü atılır).
if architecture.exists():
    layer_rows: dict[str, str] = {}
    for line in architecture_text.splitlines():
        row = re.match(r"\|\s*(?:\d+|—)\s*\|\s*`([A-Za-z]+)/`\s*\|", line)
        if row:
            layer_rows[row.group(1)] = line

    def module_name(file: Path) -> str:
        return re.sub(r"(\.client|\.server)?\.luau$", "", file.name)

    def listed_names(line: str) -> set[str]:
        names = set(re.findall(r"`([A-Za-z][A-Za-z0-9]*)`", line))
        for group in re.finditer(r"`(\w+)`((?:/`\w+`)+)", line):
            prefix = re.sub(r"[A-Z][a-z0-9]*$", "", group.group(1))
            rests = re.findall(r"`(\w+)`", group.group(2))
            names.difference_update(rests)
            names.update(prefix + rest for rest in rests)
        return names

    existing_everywhere = {module_name(p).lower() for p in (ROOT / "src").rglob("*.luau")}
    existing_everywhere |= {p.name.lower() for p in (ROOT / "src").rglob("*") if p.is_dir()}
    for side in ("server", "client"):
        for directory in sorted((ROOT / "src" / side).iterdir()):
            row_text = layer_rows.get(directory.name)
            if not directory.is_dir() or row_text is None:
                continue
            listed = listed_names(row_text)
            for file in sorted(directory.glob("*.luau")):
                if module_name(file) != "init" and module_name(file) not in listed:
                    fail(f"docs/MIMARI.md: {directory.name}/ satırı {side}/{directory.name}/{file.name} dosyasını anmıyor")
            for name in sorted(listed):
                if name[:1].isupper() and name.lower() not in existing_everywhere:
                    fail(f"docs/MIMARI.md: {directory.name}/ satırındaki `{name}` src altında yok (silinmiş ya da yeniden adlandırılmış)")

# ---------------------------------------------------------------- tek kaynak: kural/skill yalnız .claude altında
# Başka yerde kural/skill kaynağı açılırsa AI'lar farklı yerlere bakar; eski Cursor/Copilot/AGENTS kalıntıları geri gelmemeli.
STRAY_PATHS = (".cursor", ".cursorrules", "AGENTS.md", ".github/copilot-instructions.md", ".github/instructions", ".github/prompts")
for stray in STRAY_PATHS:
    if (ROOT / stray).exists():
        fail(f"{stray}: ikinci kural/skill kaynağı; tek kaynak CLAUDE.md + .claude/rules + .claude/skills")
for path in relative_files:
    if path.endswith(".mdc"):
        fail(f"{path}: .mdc (Cursor) kural biçimi yasak; kural .claude/rules/*.md olmalı")
    if path.endswith("/SKILL.md") and not path.startswith(".claude/skills/"):
        fail(f"{path}: skill dosyası .claude/skills dışında")
    if path.endswith(".md") and not path.startswith(".claude/rules/") and "paths" in frontmatter(read(ROOT / path)):
        fail(f"{path}: kural dosyası .claude/rules dışında")
    if path.startswith(".claude/skills/") and not path.endswith("/SKILL.md"):
        fail(f"{path}: .claude/skills altında yalnız SKILL.md olmalı")
    if path.startswith(".claude/skills/") and path.count("/") == 2:
        fail(f"{path}: skill klasörü dışında dosya")
    if path.startswith(".claude/rules/") and (not path.endswith(".md") or path.count("/") != 2):
        fail(f"{path}: .claude/rules altında yalnız düz *.md kural dosyası olmalı")

# ---------------------------------------------------------------- CLAUDE.md ortak çıpaları göstermeli
ANCHORS = (".claude/rules", ".claude/skills", "scripts/triage.py", "docs/HIZLI_AKSIYON.md", "docs/AI_DEVIR_REHBERI.md", "docs/MIMARI.md")
if claude_md.exists():
    for anchor in ANCHORS:
        if anchor not in claude_text:
            fail(f"CLAUDE.md: '{anchor}' çıpasını anmıyor")

# ---------------------------------------------------------------- CLAUDE.md hızlı kontrol tablosu
QUICK_COMMANDS = (
    "scripts/triage.py",
    "scripts/doctor.py",
    "scripts/smoke-quick.py",
    "scripts/check-repo-hygiene.py",
    "scripts/check-ai-docs.py",
    "scripts/verify-fast.ps1",
    "scripts/verify.ps1",
    "scripts/check-assets.py",
)
if claude_md.exists():
    for command in QUICK_COMMANDS:
        if command not in claude_text:
            fail(f"CLAUDE.md hızlı kontrol tablosu {command} komutunu listelemiyor")
        elif not (ROOT / command).exists():
            fail(f"CLAUDE.md: {command} dosyası yok")
    if "Hızlı kontrol komutları" not in claude_text:
        fail("CLAUDE.md 'Hızlı kontrol komutları' bölümü eksik")
    for doc in ("docs/HIZLI_AKSIYON.md", "docs/AI_DEVIR_REHBERI.md", "docs/DEVIR_DURUMU.md"):
        if not (ROOT / doc).exists():
            fail(f"{doc} yok")
    handover = ROOT / "docs" / "AI_DEVIR_REHBERI.md"
    if handover.exists():
        text = read(handover)
        for command in ("scripts/triage.py", "scripts/doctor.py", "scripts/check-repo-hygiene.py"):
            if command not in text:
                fail(f"docs/AI_DEVIR_REHBERI.md {command} komutunu anmıyor")

if errors:
    print("Yapay zeka rehber dosyaları tutarsız:")
    for message in errors:
        print(f"  - {message}")
    sys.exit(1)
print(f"AI docs OK: {len(rule_files)} kural, {len(names)} skill, CLAUDE.md tek kaynak olarak tutarlı.")
