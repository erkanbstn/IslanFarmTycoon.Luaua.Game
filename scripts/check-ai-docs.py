#!/usr/bin/env python3
"""Yapay zeka rehber dosyalarının (AGENTS.md, CLAUDE.md, .cursorrules, Copilot, kurallar, skill'ler) tutarlılığını denetler.

Denetimler:
  * Yönlendirme dosyaları AGENTS.md'ye referans verir; CLAUDE.md `@AGENTS.md` içe aktarır.
  * Her .cursor/rules/*.mdc: description + globs var, her glob en az bir dosyayla eşleşir, AGENTS.md tablosunda geçer.
  * Her .cursor/skills/<ad>/SKILL.md ile .claude/skills/<ad>/SKILL.md eşleşir (aynı ad/açıklama, doğru yönlendirme).
  * AGENTS.md ve CLAUDE.md tüm skill adlarını listeler.
  * Rehber dosyalarında geçen repo yolları (src/..., tests/..., .cursor/... ) gerçekten vardır.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

ROOT = Path(__file__).resolve().parent.parent
errors: list[str] = []


def fail(message: str) -> None:
    errors.append(message)


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def frontmatter(text: str) -> dict[str, str]:
    match = re.match(r"^---\n(.*?)\n---\n", text, re.S)
    if not match:
        return {}
    fields: dict[str, str] = {}
    for line in match.group(1).splitlines():
        if ":" in line:
            key, value = line.split(":", 1)
            fields[key.strip()] = value.strip()
    return fields


# ---------------------------------------------------------------- giriş dosyaları
agents = ROOT / "AGENTS.md"
if not agents.exists():
    fail("AGENTS.md yok")
    agents_text = ""
else:
    agents_text = read(agents)

for name in ("CLAUDE.md", ".cursorrules", ".github/copilot-instructions.md"):
    path = ROOT / name
    if not path.exists():
        fail(f"{name} yok (AGENTS.md'ye yönlendirmeli)")
    elif "AGENTS.md" not in read(path):
        fail(f"{name} AGENTS.md'ye referans vermiyor")
claude = ROOT / "CLAUDE.md"
if claude.exists() and "@AGENTS.md" not in read(claude):
    fail("CLAUDE.md '@AGENTS.md' içe aktarmıyor")

# ---------------------------------------------------------------- kurallar
rules_dir = ROOT / ".cursor" / "rules"
rule_files = sorted(rules_dir.glob("*.mdc"))
if not rule_files:
    fail(".cursor/rules altında kural yok")
all_files = [p for p in ROOT.rglob("*") if p.is_file() and ".git" not in p.parts and ".test-build" not in p.parts and ".tools" not in p.parts]
relative_files = [p.relative_to(ROOT).as_posix() for p in all_files]


def glob_matches(pattern: str) -> bool:
    regex = re.escape(pattern)
    regex = regex.replace(r"\*\*/", "(?:.*/)?").replace(r"\*\*", ".*").replace(r"\*", "[^/]*")
    compiled = re.compile("^" + regex + "$")
    return any(compiled.match(f) for f in relative_files)


for rule in rule_files:
    fields = frontmatter(read(rule))
    rel = rule.relative_to(ROOT).as_posix()
    if not fields.get("description"):
        fail(f"{rel}: description eksik")
    globs = fields.get("globs", "")
    if not globs:
        fail(f"{rel}: globs eksik")
    for pattern in [g.strip() for g in globs.split(",") if g.strip()]:
        if not glob_matches(pattern):
            fail(f"{rel}: glob hiçbir dosyayla eşleşmiyor: {pattern}")
    if rel not in agents_text:
        fail(f"AGENTS.md tablosunda {rel} geçmiyor")

# ---------------------------------------------------------------- skill'ler
cursor_skills = ROOT / ".cursor" / "skills"
claude_skills = ROOT / ".claude" / "skills"
names = sorted(p.name for p in cursor_skills.iterdir() if p.is_dir()) if cursor_skills.exists() else []
if not names:
    fail(".cursor/skills altında skill yok")
for name in names:
    source = cursor_skills / name / "SKILL.md"
    redirect = claude_skills / name / "SKILL.md"
    if not source.exists():
        fail(f".cursor/skills/{name}/SKILL.md yok")
        continue
    src_fields = frontmatter(read(source))
    if src_fields.get("name") != name:
        fail(f".cursor/skills/{name}: name alanı klasör adıyla eşleşmiyor")
    if not src_fields.get("description"):
        fail(f".cursor/skills/{name}: description eksik")
    if not redirect.exists():
        fail(f".claude/skills/{name}/SKILL.md yok")
    else:
        text = read(redirect)
        red_fields = frontmatter(text)
        if red_fields.get("name") != name:
            fail(f".claude/skills/{name}: name uyuşmuyor")
        if red_fields.get("description") != src_fields.get("description"):
            fail(f".claude/skills/{name}: description .cursor kaynağıyla aynı değil")
        if f".cursor/skills/{name}/SKILL.md" not in text:
            fail(f".claude/skills/{name}: kaynak skill'e yönlendirmiyor")
    for doc in ("AGENTS.md", "CLAUDE.md"):
        path = ROOT / doc
        if path.exists() and f"`{name}`" not in read(path):
            fail(f"{doc} skill'i listelemiyor: {name}")
if claude_skills.exists():
    for path in claude_skills.iterdir():
        if path.is_dir() and path.name not in names:
            fail(f".claude/skills/{path.name}: kaynağı .cursor/skills altında yok")

# ---------------------------------------------------------------- yol referansları
PATH_PATTERN = re.compile(r"`((?:src|tests|scripts|plugin|docs|assets|\.cursor|\.claude|\.github)/[A-Za-z0-9_./-]+\.(?:luau|mdc|md|py|ps1|json|toml))`")
guide_files = [ROOT / "AGENTS.md", ROOT / "CLAUDE.md", ROOT / ".github" / "copilot-instructions.md"]
guide_files += rule_files
guide_files += sorted(cursor_skills.glob("*/SKILL.md")) if cursor_skills.exists() else []
guide_files += sorted(claude_skills.glob("*/SKILL.md")) if claude_skills.exists() else []
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
    for doc in ("AGENTS.md", "CLAUDE.md", ".cursorrules", ".github/copilot-instructions.md"):
        path = ROOT / doc
        if path.exists() and "MIMARI.md" not in read(path):
            fail(f"{doc} docs/MIMARI.md'ye referans vermiyor")
    for side in ("server", "client"):
        for directory in sorted((ROOT / "src" / side).iterdir()):
            if directory.is_dir() and f"`{directory.name}/`" not in architecture_text:
                fail(f"docs/MIMARI.md src/{side}/{directory.name}/ katmanını anlatmıyor")
    for reference in PATH_PATTERN.finditer(architecture_text):
        if not any(ch in reference.group(1) for ch in "*<>") and not (ROOT / reference.group(1)).exists():
            fail(f"docs/MIMARI.md: var olmayan yol: {reference.group(1)}")

if errors:
    print("Yapay zeka rehber dosyaları tutarsız:")
    for message in errors:
        print(f"  - {message}")
    sys.exit(1)
print(f"AI docs OK: {len(rule_files)} kural, {len(names)} skill, yönlendirme dosyaları tutarlı.")
