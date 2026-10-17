#!/usr/bin/env python3
"""Salt okunur durum özeti: "ne değişti, hangi kural/skill, en küçük hangi kontrol?".

Git'teki değişen dosyalardan (veya --files ile verilenlerden) `.claude/rules/*.md` dosyalarının `paths:` alanından kural dosyalarını,
ilgili skill'i ve çalıştırılacak EN KÜÇÜK hedefli test/denetim komutlarını türetir; doctor ve depo hijyeni
özetini tek ekranda gösterir. Kurulum, ağ, Git değişikliği ve dosya yazımı yapmaz.
--run yalnız ucuz önerileri sırayla çalıştırır (verify.ps1 değildir); yavaş olanlar --include-slow ile.

  python scripts/triage.py                  # insan okunur Türkçe özet
  python scripts/triage.py --json           # makine okunur çıktı (schema 1)
  python scripts/triage.py --run            # ucuz hedefli kontrolleri çalıştır
  python scripts/triage.py --files src/client/Ui/Hud/GoalCard.luau tests/hud-layout.spec.luau
Çıkış 0: plan üretildi (ve --run ise hepsi geçti); 1: --run başarısız; 2: kullanım hatası.
"""

from __future__ import annotations

import argparse
import importlib.util
import json
import os
import re
import subprocess
import sys
import time
from pathlib import Path

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

ROOT = Path(__file__).resolve().parents[1]
SCHEMA = 1
MAX_TARGETED_SPECS = 12  # bunun üstünde hedefli yerine tüm saf Luau paketi önerilir

# ---------------------------------------------------------------------------------------------------
# Kural tablosu: .claude/rules/*.md dosyalarının `paths:` listesinden türetilir (tek kaynak; elle kopya yok).
# CLAUDE.md kural tablosuyla tutarlılığı tests/tooling.spec.py ve scripts/check-ai-docs.py doğrular.
# ---------------------------------------------------------------------------------------------------
def load_rules(root: Path) -> list[tuple[str, tuple[str, ...]]]:
    rules: list[tuple[str, tuple[str, ...]]] = []
    for path in sorted((root / ".claude" / "rules").glob("*.md")):
        text = path.read_text(encoding="utf-8-sig").replace("\r\n", "\n")
        match = re.match(r"^---\n(.*?)\n---", text, re.S)
        block = re.search(r"^paths:[ \t]*\n((?:[ \t]+-[^\n]*\n?)+)", match.group(1) + "\n", re.M) if match else None
        patterns = tuple(item.strip("\"'") for item in re.findall(r"^[ \t]+-\s*(.+?)\s*$", block.group(1), re.M)) if block else ()
        if patterns:
            rules.append((path.relative_to(root).as_posix(), patterns))
    return rules


RULES: list[tuple[str, tuple[str, ...]]] = load_rules(ROOT)

# Dosya yolu -> skill (bir dosya birden çok skill'e girebilir). roblox-verify her zaman eklenir.
SKILLS: list[tuple[str, tuple[str, ...]]] = [
    ("roblox-add-remote", ("src/shared/Remotes.luau", "src/server/Services/RequestGuard.luau")),
    ("roblox-add-ui", ("src/client/Ui/**", "src/shared/UiTheme.luau", "src/shared/WorldUi.luau", "src/first/**")),
    ("roblox-add-content", ("src/shared/Config/**", "src/shared/Modules/FarmMath/**")),
    ("roblox-map-change", ("src/server/World/**", "src/server/Presentation/**", "plugin/**", "assets/**", "client-assets/**", "src/shared/MapPaths.luau")),
    ("roblox-localize", ("src/shared/Locales/**", "src/shared/Localization.luau")),
    ("roblox-save-schema", ("src/server/Modules/SaveCodec/**", "src/server/Modules/SessionLock.luau", "src/server/Services/PlayerDataService.luau",
                            "src/server/Services/SaveStore.luau", "src/shared/GameTypes.luau")),
]

# Alan etiketi (özet sayacı için), ilk eşleşen kazanır.
AREAS: list[tuple[str, str]] = [
    ("src/server/", "sunucu"), ("src/client/", "istemci"), ("src/shared/", "ortak"), ("src/first/", "ilk-yükleme"),
    ("tests/", "test"), ("scripts/", "betik"), ("docs/", "belge"), ("assets/", "model"), ("client-assets/", "model"),
    ("plugin/", "eklenti"), ("tools/", "araç"), ("CLAUDE.md", "kural"), (".claude/", "kural"),
]

# Elle Studio kanıtı gerektiren alanlar (roblox-verify "Studio'da kalan kanıt").
MANUAL: list[tuple[str, tuple[str, ...]]] = [
    ("Harita/dünya değişti: Studio'da haritayı yeniden kur + test.project.json dünya testleri / MapToolRun=buildverify; plugin/ değiştiyse eklentiyi yeniden derle.",
     ("src/server/World/**", "src/server/Presentation/**", "plugin/**", "src/client/Effects/**", "assets/**", "client-assets/**")),
    ("Arayüz değişti: telefon/masaüstü, uzun çeviri ve gamepad'de gerçek görsel kontrol (saf UI mock'u render kanıtı değildir).",
     ("src/client/Ui/**", "src/shared/UiTheme.luau", "src/shared/WorldUi.luau", "src/first/**")),
    ("Kayıt/mali akış değişti: ayrı test DataStore'unda yeniden giriş, makbuz tekrarı ve kapanış senaryosu (QA fixture'ı kayıt yazmaz).",
     ("src/server/Modules/SaveCodec/**", "src/server/Modules/SessionLock.luau", "src/server/Services/SaveStore.luau",
      "src/server/Services/PlayerDataService.luau", "src/server/Services/MonetizationService.luau")),
    ("Denge değişti: aynı koşullu önce/sonra ölçümü -> python scripts/compare-economy.py run --baseline-ref HEAD --repeats 2 -- --persona hardcore --hours 6 --farm 1",
     ("src/shared/Config/**", "src/shared/Modules/FarmMath/**")),
]

# Çalıştırılacak araç yer tutucuları: {stylua} {luau} {luau-compile} {rojo} -> çalıştırma anında çözülür.
PLACEHOLDER = re.compile(r"\{(stylua|luau|luau-compile|rojo)\}")


# ------------------------------------------------------------------------------------------ yardımcılar
def load_script(name: str, root: Path):
    spec = importlib.util.spec_from_file_location("triage_" + name.replace("-", "_"), root / "scripts" / f"{name}.py")
    if spec is None or spec.loader is None:
        raise ImportError(name)
    sys.dont_write_bytecode = True
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def glob_regex(pattern: str) -> re.Pattern[str]:
    regex = re.escape(pattern).replace(r"\*\*/", "(?:.*/)?").replace(r"\*\*", ".*").replace(r"\*", "[^/]*")
    return re.compile("^" + regex + "$")


def matches(path: str, patterns: tuple[str, ...]) -> bool:
    return any(glob_regex(pattern).match(path) for pattern in patterns)


def norm_spec(value: str) -> str:
    """run-tests.py --only ile aynı ad normalizasyonu: 'hud-layout' == 'hudLayoutSpec'."""
    stem = value.replace("\\", "/").rsplit("/", 1)[-1].lower()
    stem = re.sub(r"\.spec\.luau$|\.luau$", "", stem)
    stem = re.sub(r"[^a-z0-9]", "", stem)
    return stem[:-4] if stem.endswith("spec") and len(stem) > 4 else stem


def area_of(path: str) -> str:
    for prefix, label in AREAS:
        if path.startswith(prefix):
            return label
    return "kök"


def git(root: Path, *args: str) -> str | None:
    try:
        environment = dict(os.environ, GIT_OPTIONAL_LOCKS="0")
        result = subprocess.run(["git", "-c", "core.fsmonitor=false", *args], cwd=root, env=environment, capture_output=True,
                                text=True, encoding="utf-8", errors="replace", timeout=30, check=False)
    except (OSError, subprocess.SubprocessError):
        return None
    return result.stdout if result.returncode == 0 else None


def git_state(root: Path) -> dict:
    """{'branch', 'available', 'changed': [{'path','status','deleted'}]} - yalnız okur."""
    raw = git(root, "status", "--porcelain=v1", "-z", "-uall")
    branch = (git(root, "symbolic-ref", "--short", "HEAD") or "").strip() or "detached/bilinmiyor"
    if raw is None:
        return {"available": False, "branch": branch, "changed": []}
    entries = raw.split("\0")
    changed, index = [], 0
    while index < len(entries):
        entry = entries[index]
        index += 1
        if len(entry) < 4:
            continue
        status, path = entry[:2], entry[3:]
        if status[0] in "RC":  # -z: eski ad ayrı alan
            index += 1
        deleted = "D" in status
        label = "silindi" if deleted else "yeni" if status == "??" or "A" in status else "yeniden-adlandı" if "R" in status else "değişti"
        changed.append({"path": path.replace("\\", "/"), "status": label, "deleted": deleted})
    return {"available": True, "branch": branch, "changed": changed}


# ------------------------------------------------------------------------------------ koşucu haritası
def runner_graph(root: Path) -> dict:
    """scripts/run-tests.py metninden modül->yol, bağımlılık ve spec çağrı bilgisini çıkarır (Luau çalıştırmaz)."""
    path = root / "scripts" / "run-tests.py"
    text = path.read_text(encoding="utf-8-sig") if path.is_file() else ""
    modules: dict[str, dict] = {}
    for match in re.finditer(r'module\(\s*"(\w+)",\s*"([^"]+)"(?:,\s*\{([^}]*)\})?', text):
        name, source, deps = match.groups()
        modules[name] = {"path": source, "deps": {norm_name(d) for d in re.findall(r'"(\w+)"', deps or "")}}
    calls = {}
    for match in re.finditer(r'^\s*"(\w+Spec)\(([^)\n]*)\)\\n",', text, re.MULTILINE):
        calls[match.group(1)] = {norm_name(arg.strip().split(".")[0]) for arg in match.group(2).split(",") if arg.strip()}
    specs = {}
    for name in calls:
        entry = modules.get(name)
        if entry and entry["path"].startswith("tests/"):
            specs[name] = {"path": entry["path"], "only": Path(entry["path"]).name.removesuffix(".spec.luau"), "uses": calls[name]}
    bundles = {"src/shared/Config/": "Config", "src/shared/Modules/FarmMath/": "FarmMath", "src/server/Modules/SaveCodec/": "SaveCodec"}
    return {"modules": modules, "specs": specs, "bundles": bundles, "text": text}


def norm_name(name: str) -> str:
    return name[:-7] if name.endswith("Factory") and len(name) > 7 else name


def affected_specs(root: Path, paths: list[str]) -> tuple[list[str], bool, list[str]]:
    """(--only adları, hepsini-çalıştır, spec bulunamayan src dosyaları)."""
    graph = runner_graph(root)
    modules, specs, bundles = graph["modules"], graph["specs"], graph["bundles"]
    spec_by_path = {data["path"]: data["only"] for data in specs.values()}
    chosen: set[str] = set()
    changed_modules: set[str] = set()
    unmapped: list[str] = []
    run_all = False
    for path in paths:
        if path.startswith("tests/") and path.endswith(".spec.luau"):
            if path in spec_by_path:
                chosen.add(spec_by_path[path])
            continue
        if not (path.startswith(("src/", "plugin/")) and path.endswith(".luau")):
            continue
        bundle = next((name for prefix, name in bundles.items() if path.startswith(prefix)), None)
        if bundle:
            changed_modules.add(bundle)
            continue
        names = [norm_name(name) for name, data in modules.items() if data["path"] == path]
        stem = Path(path).name.split(".")[0]
        found = bool(names)
        changed_modules.update(names)
        if not found:  # koşucuda modül değil: testlerde adı geçen spec'e düş
            for data in specs.values():
                spec_file = root / data["path"]
                if spec_file.is_file() and re.search(rf"\b{re.escape(stem)}\b", spec_file.read_text(encoding="utf-8-sig")):
                    chosen.add(data["only"])
                    found = True
        if not found:
            unmapped.append(path)
    affected = set(changed_modules)
    growing = True
    while growing:  # bağımlı modüllerin kapanışı
        growing = False
        for name, data in modules.items():
            if norm_name(name) not in affected and data["deps"] & affected:
                affected.add(norm_name(name))
                growing = True
    for data in specs.values():
        if data["uses"] & affected:
            chosen.add(data["only"])
    if len(chosen) > MAX_TARGETED_SPECS:
        run_all = True
    return sorted(chosen), run_all, unmapped


# ------------------------------------------------------------------------------------------------ plan
def command(identifier: str, argv: list[str], why: str, cost: str = "cheap") -> dict:
    return {"id": identifier, "argv": argv, "display": " ".join(PLACEHOLDER.sub(r"\1", part) for part in argv), "cost": cost, "why": why}


def build_plan(root: Path, changed: list[dict], *, git_available: bool = True, branch: str = "") -> dict:
    live = [item["path"] for item in changed if not item["deleted"]]
    paths = [item["path"] for item in changed]
    rules, skills, manual = [], [], []
    for rule, patterns in RULES:
        if any(matches(path, patterns) for path in paths):
            rules.append(rule)
    for skill, patterns in SKILLS:
        if any(matches(path, patterns) for path in paths):
            skills.append(skill)
    for message, patterns in MANUAL:
        if any(matches(path, patterns) for path in paths):
            manual.append(message)
    if paths:
        skills.append("roblox-verify")

    rows = []
    for item in changed:
        path = item["path"]
        rows.append({**item, "area": area_of(path),
                     "rules": [rule for rule, patterns in RULES if matches(path, patterns)],
                     "skills": [skill for skill, patterns in SKILLS if matches(path, patterns)]})
    unmapped = [row["path"] for row in rows if not row["rules"] and not row["skills"] and row["area"] == "kök"
                and not row["path"].endswith((".md", ".json", ".toml", ".gitignore"))]

    luau = [path for path in live if path.endswith(".luau") and path.startswith(("src/", "plugin/", "tests/"))]
    src_luau = [path for path in luau if path.startswith("src/")]
    commands: list[dict] = []
    if luau:
        commands.append(command("stylua", ["{stylua}", "--check", *luau], "biçim (yalnız değişen .luau; düzeltme için --check'siz, yalnız kendi dosyana)"))
        commands.append(command("luau-compile", ["{luau-compile}", "--null", *luau], "sözdizimi derlemesi (değişen dosyalar)"))
    specs, run_all, no_spec = affected_specs(root, live) if (src_luau or any(p.startswith("tests/") for p in live)) else ([], False, [])
    if any(path.startswith(("src/", "tests/", "scripts/run-tests.py")) for path in live):
        commands.append(command("test-deps", ["python", "scripts/check-test-dependencies.py"], "harness require/sıra bağımlılığı"))
    if run_all:
        commands.append(command("run-tests", ["python", "scripts/run-tests.py", "--luau", "{luau}"], f"etkilenen spec >{MAX_TARGETED_SPECS} -> tüm saf Luau paketi"))
    elif specs:
        commands.append(command("run-tests-only", ["python", "scripts/run-tests.py", "--luau", "{luau}", "--only", ",".join(specs)], f"etkilenen {len(specs)} saf Luau spec"))
    if src_luau:
        commands.append(command("architecture", ["python", "scripts/check-architecture.py"], "katman bağımlılık kuralları"))
    if any(path.startswith(("src/client/", "src/server/", "src/shared/")) for path in live):
        commands.append(command("locales", ["python", "scripts/check-locales.py", "--strict-literals"], "dil anahtarı eşliği + sabit metin"))
    if any(path.startswith("src/shared/Config/") for path in live):
        commands.append(command("config-locales", ["python", "scripts/check-config-locales.py"], "Config metin çevirileri"))
        commands.append(command("audit-economy", ["python", "scripts/audit-economy.py", "--luau", "{luau}", "--check"], "uçuk değer denetimi", "medium"))
    if any(path.startswith(("assets/", "client-assets/", "tools/models/", "docs/MODEL_SOZLESMESI", "src/server/World/", "src/server/Presentation/")) for path in live):
        commands.append(command("assets", ["python", "scripts/check-assets.py"], "model sözleşmesi/kapsamı", "medium"))
    if any(path.startswith(("docs/", ".claude/")) or path == "CLAUDE.md" for path in paths):
        commands.append(command("ai-docs", ["python", "scripts/check-ai-docs.py"], "rehber/kural/skill tutarlılığı"))
    if any(path.startswith(("scripts/", "tests/")) and path.endswith(".py") for path in live):
        commands.append(command("tooling", ["python", "tests/tooling.spec.py"], "araç regresyonları"))
    for path in live:
        name = Path(path).name
        if path.startswith("scripts/test-") and name.endswith(".py"):
            commands.append(command("py-" + name[:-3], ["python", path], "değişen araç testi"))
    if any(path.endswith(".project.json") for path in live):
        commands.append(command("rojo-game", ["{rojo}", "build", "default.project.json", "-o", ".test-build/game.rbxlx"], "proje derlemesi", "medium"))
    if changed:  # silme/yeniden adlandırma/yeni belge-betik her zaman ucuz hijyenle kapatılır
        commands.append(command("hygiene", ["python", "scripts/check-repo-hygiene.py"], "ölü yol/bağlantı, yetim dosya, izlenen çöp"))
    seen: set[str] = set()
    commands = [item for item in commands if not (item["id"] in seen or seen.add(item["id"]))]

    counts: dict[str, int] = {}
    for row in rows:
        counts[row["area"]] = counts.get(row["area"], 0) + 1
    hint = None
    if not changed:
        hint = ("Değişiklik yok" if git_available else "Git durumu okunamadı") + ": taban için powershell -ExecutionPolicy Bypass -File scripts/verify-fast.ps1; özet: python scripts/triage.py --files <yol...>"
    return {
        "schema": SCHEMA, "git": {"available": git_available, "branch": branch}, "nothing_changed": not changed, "hint": hint,
        "counts": counts, "changed": rows, "rules": rules, "skills": list(dict.fromkeys(skills)),
        "specs": {"only": specs, "run_all": run_all, "no_pure_spec": no_spec},
        "commands": commands, "manual": manual, "unmapped": unmapped, "health": None, "results": None,
    }


# --------------------------------------------------------------------------------------------- sağlık
def health(root: Path) -> dict:
    out: dict = {"doctor": None, "hygiene": None}
    try:
        report = load_script("doctor", root).diagnose(root)
        out["doctor"] = {"ok": report["ok"], "issues": [f"{i['code']} {i['severity']}: {i['message']}" for i in report["issues"]],
                         "luau_ready": all(report["luau"]["executables"].values()), "types_ready": report["types"]["tools_present"]}
    except Exception as error:  # teşhis hiçbir zaman planı düşürmez
        out["doctor"] = {"ok": False, "issues": [f"doctor çalışmadı: {error}"], "luau_ready": False, "types_ready": False}
    try:
        findings = load_script("check-repo-hygiene", root).check(root)
        out["hygiene"] = {"ok": not findings, "findings": list(findings)}
    except Exception as error:
        out["hygiene"] = {"ok": False, "findings": [f"hijyen çalışmadı: {error}"]}
    return out


# ------------------------------------------------------------------------------------------ çalıştırma
def resolve_tool(root: Path, name: str) -> str | None:
    extension = ".exe" if os.name == "nt" else ""
    if name in ("luau", "luau-compile"):
        candidate = root / ".tools" / "luau" / (name + extension)
        return str(candidate) if candidate.is_file() else None
    try:
        doctor = load_script("doctor", root)
        text = (root / "rokit.toml").read_text(encoding="utf-8-sig")
        pin = dict(re.findall(r'^\s*(\w+)\s*=\s*"([^"\n]+@[^"\n]+)"', text, re.MULTILINE)).get(name)
        return doctor.tool_path(root, name, pin)[0] if pin else None
    except Exception:
        return None


def run_commands(root: Path, commands: list[dict], include_slow: bool) -> list[dict]:
    results = []
    for item in commands:
        if item["cost"] != "cheap" and not include_slow:
            results.append({"id": item["id"], "status": "atlandı", "reason": "yavaş (--include-slow)", "seconds": 0.0})
            continue
        argv, missing = [], None
        for part in item["argv"]:
            for tool in PLACEHOLDER.findall(part):
                path = resolve_tool(root, tool)
                if path is None:
                    missing = tool
                part = part.replace("{" + tool + "}", path or tool)
            argv.append(part)
        if missing:
            results.append({"id": item["id"], "status": "atlandı", "reason": f"araç yok: {missing}", "seconds": 0.0})
            continue
        if argv[0] == "python":
            argv[0] = sys.executable
        started = time.monotonic()
        try:
            done = subprocess.run(argv, cwd=root, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=600, check=False)
            status, tail = ("geçti" if done.returncode == 0 else "BAŞARISIZ"), (done.stdout + done.stderr).strip().splitlines()[-6:]
        except (OSError, subprocess.SubprocessError) as error:
            status, tail = "BAŞARISIZ", [str(error)]
        results.append({"id": item["id"], "status": status, "seconds": round(time.monotonic() - started, 1), "tail": tail})
    return results


# --------------------------------------------------------------------------------------------- çıktı
def render(plan: dict) -> str:
    lines = []
    git_info = plan["git"]
    summary = ", ".join(f"{label} {count}" for label, count in sorted(plan["counts"].items(), key=lambda pair: -pair[1])) or "yok"
    lines.append(f"TRIAGE dal: {git_info['branch'] or '?'} | değişen: {len(plan['changed'])} ({summary})")
    status = plan.get("health")
    if status:
        doctor, hygiene = status["doctor"], status["hygiene"]
        lines.append(f"SAĞLIK doctor: {'hazır' if doctor['ok'] else 'EKSİK'} (Luau {'var' if doctor['luau_ready'] else 'YOK'}, tip araçları {'var' if doctor['types_ready'] else 'yok'})"
                     f" | hijyen: {'temiz' if hygiene['ok'] else str(len(hygiene['findings'])) + ' bulgu'}")
        for issue in doctor["issues"][:3]:
            lines.append("  ! " + issue)
        for finding in hygiene["findings"][:3]:
            lines.append("  ! " + finding)
    if plan["hint"]:
        lines.append(plan["hint"])
    for row in plan["changed"][:8]:
        lines.append(f"  {row['status'][:5]:<5} {row['path']}")
    if len(plan["changed"]) > 8:
        lines.append(f"  ... +{len(plan['changed']) - 8} dosya daha")
    if plan["rules"]:
        lines.append("OKU (kural): " + ", ".join(rule.removeprefix(".claude/rules/") for rule in plan["rules"]))
    if plan["skills"]:
        lines.append("SKILL: " + ", ".join(plan["skills"]) + "  (.claude/skills/<ad>/SKILL.md)")
    if plan["commands"]:
        lines.append("ÇALIŞTIR (küçükten büyüğe):")
        for index, item in enumerate(plan["commands"], 1):
            mark = " " if item["cost"] == "cheap" else "~"
            lines.append(f" {index:>2}.{mark}{item['display'] if len(item['display']) < 150 else item['display'][:147] + '...'}   # {item['why']}")
    if plan["specs"]["no_pure_spec"]:
        lines.append("SAF SPEC YOK (Studio/test.project.json veya elle): " + ", ".join(plan["specs"]["no_pure_spec"][:4]))
    for message in plan["manual"]:
        lines.append("STUDIO: " + message)
    if plan["unmapped"]:
        lines.append("EŞLEMESİZ (kural/skill yok, elle bak): " + ", ".join(plan["unmapped"][:5]))
    if plan.get("results"):
        lines.append("SONUÇ:")
        for result in plan["results"]:
            lines.append(f"  {result['status']:<10} {result['id']} ({result['seconds']}s)" + (f" - {result['reason']}" if result.get("reason") else ""))
            if result["status"] == "BAŞARISIZ":
                lines.extend("      " + row for row in result.get("tail", []))
    lines.append("Not: ~ = yavaş (--include-slow); bu özet verify.ps1 yerine geçmez. Full/Studio kanıtı ayrı: docs/HIZLI_AKSIYON.md")
    return "\n".join(lines)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--json", action="store_true", help="makine okunur çıktı")
    parser.add_argument("--run", action="store_true", help="önerilen ucuz hedefli kontrolleri sırayla çalıştır")
    parser.add_argument("--include-slow", action="store_true", help="--run ile yavaş (~) kontrolleri de çalıştır")
    parser.add_argument("--files", nargs="+", metavar="YOL", help="Git yerine bu repo-göreli yolları değişmiş say")
    parser.add_argument("--skip-health", action="store_true", help="doctor ve hijyen özetini atla")
    parser.add_argument("--root", type=Path, default=ROOT)
    args = parser.parse_args(argv)
    root = args.root.resolve()
    if not root.is_dir():
        parser.error("--root mevcut bir dizin olmalı")
    if args.files:
        files = [item.replace("\\", "/").removeprefix("./") for item in args.files]
        state = {"available": True, "branch": "(--files)", "changed": [
            {"path": item, "status": "değişti" if (root / item).exists() else "silindi", "deleted": not (root / item).exists()} for item in files]}
    else:
        state = git_state(root)
    plan = build_plan(root, state["changed"], git_available=state["available"], branch=state["branch"])
    if not args.skip_health:
        plan["health"] = health(root)
    exit_code = 0
    if args.run:
        plan["results"] = run_commands(root, plan["commands"], args.include_slow)
        exit_code = int(any(result["status"] == "BAŞARISIZ" for result in plan["results"]))
    print(json.dumps(plan, ensure_ascii=False) if args.json else render(plan))
    return exit_code


if __name__ == "__main__":
    raise SystemExit(main())
