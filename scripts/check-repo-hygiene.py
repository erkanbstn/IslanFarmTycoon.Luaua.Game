#!/usr/bin/env python3
"""Depo hijyeni: bayat/ölü referansları, yetim belge-betik-modülleri ve izlenen çöpü yakalar.

Salt okunur; ağ ve kurulum yapmaz. Denetimler:
  * Belge, kural, betik ve kaynaklarda geçen repo yolları (src/..., docs/..., assets/... ) gerçekten vardır.
    Uzantısız önek yazımı (assets/ZoneDecor/Decor_) kabul edilir; "git geçmişi/arşiv" geçen satırlar tarihsel sayılır.
  * Markdown göreli bağlantıları ([ad](docs/X.md)) çözülür.
  * docs/ altındaki her belge ve scripts/ altındaki her betik başka bir dosyada adıyla anılır (yetim değildir).
  * src/ altındaki her modül (init ve istemci/sunucu giriş betikleri hariç) başka bir dosyada adıyla anılır.
  * Git'te izlenen log/yedek/önbellek/derleme çıktısı yoktur.
  * docs/*.md 400 satırı aşmaz (iş günlüğüne dönüşen belge özetlenip arşivlenmeli).
  * docs/DEVIR_DURUMU.md içinde anılan commit kimlikleri depoda vardır.
  * Luau: yalnızca tanımı olan (hiç çağrılmayan) `function Mod.ad` / `Mod:ad`; yorum satırına alınmış kod;
    Remotes.luau'daki olayın istemci ya da sunucu tarafında hiç geçmemesi.
  * Locales: dört dilde de bulunan ama anahtarındaki ≥4 harfli bir kelime kodda hiç geçmeyen çeviri anahtarı.
"""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

DEFAULT_ROOT = Path(__file__).resolve().parent.parent
TEXT_SUFFIXES = {".md", ".mdc", ".py", ".ps1", ".luau", ".json", ".toml", ".txt"}
SKIP_PARTS = {".git", ".tools", ".test-build", ".cleanup-archive", "build", "__pycache__", "node_modules"}
SKIP_FILES = {"sourcemap.json"}
# Sahte yol içeren bilinçli fixture'lar; yalnız bu dosyalar atlanır.
FIXTURE_FILES = {"scripts/check-repo-hygiene.py", "scripts/check-ai-docs.py", "tests/tooling.spec.py", "scripts/test-check-types.py", "scripts/test-compare-economy.py", "scripts/test-studio-qa.py", "scripts/test-check-assets.py"}
HISTORICAL_MARK = re.compile(r"git ge[çc]mi[şs]|git history|ar[şs]iv|archived|silindi", re.I)
PATH_REF = re.compile(
    r"(?<![\w/.\-])((?:src|tests|scripts|plugin|docs|assets|client-assets|tools|artwork|\.cursor|\.claude|\.github)/[A-Za-z0-9_./\-]*[A-Za-z0-9_])"
)
MD_LINK = re.compile(r"\]\(([^)\s]+)\)")
JUNK_SUFFIXES = {".log", ".tmp", ".bak", ".orig", ".rej", ".swp", ".pyc"}
JUNK_PREFIXES = (".test-build/", "build/", ".tools/", ".cleanup-archive/")
DOC_LINE_CAP = 400
SHA = re.compile(r"\b(?=[0-9a-f]*\d)(?=[0-9a-f]*[a-f])[0-9a-f]{7,12}\b")


def run_git(root: Path, *args: str) -> str | None:
    try:
        result = subprocess.run(["git", *args], cwd=root, capture_output=True, text=True, encoding="utf-8", timeout=60)
    except (OSError, subprocess.SubprocessError):
        return None
    return result.stdout if result.returncode == 0 else None


def project_files(root: Path) -> tuple[list[Path], list[str] | None]:
    """Izlenen + izlenmeyen ama yoksayılmayan dosyalar; ikinci değer yalnız izlenenler (git yoksa None)."""
    listed = run_git(root, "ls-files", "--cached", "--others", "--exclude-standard")
    tracked = run_git(root, "ls-files", "--cached")
    if listed is None:
        files = [p for p in root.rglob("*") if p.is_file() and not (set(p.relative_to(root).parts) & SKIP_PARTS)]
        return files, None
    files = [root / line for line in dict.fromkeys(listed.splitlines()) if line and (root / line).is_file()]
    return files, (tracked.splitlines() if tracked is not None else None)


def rel(root: Path, path: Path) -> str:
    return path.relative_to(root).as_posix()


def read(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        return ""


def is_text_source(root: Path, path: Path) -> bool:
    name = rel(root, path)
    return (
        path.suffix in TEXT_SUFFIXES
        and path.name not in SKIP_FILES
        and not (set(path.relative_to(root).parts) & SKIP_PARTS)
        and not name.startswith(("assets/", "client-assets/", "artwork/"))
    )


def module_name(path: Path) -> str:
    return re.sub(r"(\.client|\.server)?\.luau$", "", path.name)


def check(root: Path) -> list[str]:
    errors: list[str] = []
    files, tracked = project_files(root)
    names = {rel(root, p) for p in files}
    sources = [p for p in files if is_text_source(root, p)]
    texts = {p: read(p) for p in sources}

    def exists_or_prefix(ref: str) -> bool:
        if ref in names or (root / ref).exists():
            return True
        return any(n.startswith(ref) for n in names)

    # 1) ölü yol referansları
    for path, text in texts.items():
        name = rel(root, path)
        if name in FIXTURE_FILES:
            continue
        for number, line in enumerate(text.splitlines(), 1):
            if HISTORICAL_MARK.search(line):
                continue
            for match in PATH_REF.finditer(line):
                ref = match.group(1).rstrip(".")
                if any(ch in ref for ch in "*<>{}") or ref.startswith((".test-build", "build/", ".tools")):
                    continue
                if not exists_or_prefix(ref):
                    errors.append(f"{name}:{number}: var olmayan yol: {ref}")

    # 2) markdown bağlantıları
    for path, text in texts.items():
        if path.suffix != ".md":
            continue
        for number, line in enumerate(text.splitlines(), 1):
            for match in MD_LINK.finditer(line):
                target = match.group(1).split("#", 1)[0]
                if not target or re.match(r"^[a-z]+:", target) or target.startswith("/"):
                    continue
                resolved = (path.parent / target).resolve()
                try:
                    resolved.relative_to(root.resolve())
                except ValueError:
                    continue
                if not resolved.exists():
                    errors.append(f"{rel(root, path)}:{number}: kırık bağlantı: {target}")

    def mentioned_elsewhere(path: Path, token: str) -> bool:
        pattern = re.compile(r"(?<![\w-])" + re.escape(token) + r"(?![\w])")
        return any(other != path and pattern.search(text) for other, text in texts.items())

    # 3) yetim belge ve betikler
    for path in files:
        name = rel(root, path)
        parts = name.split("/")
        if len(parts) == 2 and parts[0] == "docs" and path.suffix in {".md", ".csv"}:
            if not mentioned_elsewhere(path, path.name) and not mentioned_elsewhere(path, name):
                errors.append(f"{name}: hiçbir dosyada anılmıyor (yetim belge; bağla ya da kaldır)")
        if len(parts) == 2 and parts[0] == "scripts" and path.suffix in {".py", ".ps1"}:
            if not mentioned_elsewhere(path, path.name) and not mentioned_elsewhere(path, name):
                errors.append(f"{name}: hiçbir dosyada anılmıyor (yetim betik; bağla ya da kaldır)")

    # 4) yetim Luau modülleri
    luau_pool = {p: t for p, t in texts.items() if p.suffix in {".luau", ".json", ".py", ".ps1", ".md", ".mdc"}}
    for path in files:
        name = rel(root, path)
        if not name.startswith("src/") or path.suffix != ".luau" or path.name.endswith((".client.luau", ".server.luau")):
            continue
        token = module_name(path)
        if token == "init":
            continue
        pattern = re.compile(r"(?<![\w])" + re.escape(token) + r"(?![\w])")
        if not any(other != path and pattern.search(text) for other, text in luau_pool.items()):
            errors.append(f"{name}: hiçbir yerde anılmıyor (kullanılmayan modül; bağla ya da kaldır)")

    # 5) izlenen çöp
    if tracked is not None:
        for name in tracked:
            if not (root / name).exists():
                continue
            lowered = name.lower()
            if Path(lowered).suffix in JUNK_SUFFIXES or "__pycache__" in lowered or lowered.startswith(JUNK_PREFIXES):
                errors.append(f"{name}: git'te izlenen çıktı/log/önbellek dosyası (kaldır ve .gitignore'a bağla)")

    # 6) şişmiş belge
    for path in files:
        name = rel(root, path)
        parts = name.split("/")
        if len(parts) == 2 and parts[0] == "docs" and path.suffix == ".md":
            count = len(read(path).splitlines())
            if count > DOC_LINE_CAP:
                errors.append(f"{name}: {count} satır (> {DOC_LINE_CAP}); iş günlüğüne dönüşmüş, özetleyip eskisini arşivle")

    # 7) devir belgesindeki commit kimlikleri
    handover = root / "docs" / "DEVIR_DURUMU.md"
    if handover.exists() and run_git(root, "rev-parse", "--git-dir") is not None:
        for sha in sorted(set(SHA.findall(read(handover)))):
            if run_git(root, "cat-file", "-e", f"{sha}^{{commit}}") is None:
                errors.append(f"docs/DEVIR_DURUMU.md: depoda olmayan commit kimliği: {sha}")

    errors.extend(check_luau(root, files))
    return errors


MODULE_FUNCTION = re.compile(r"^function\s+[A-Za-z_]\w*[.:]([A-Za-z_]\w*)\s*\(", re.M)
COMMENTED_CODE = re.compile(r"^\s*--\s*(?:local\s+\w+\s*=|if\s.+\sthen\s*$|for\s.+\sdo\s*$|return\s+\S|[A-Za-z_][\w.:]*\([^)]*\)\s*$)")
LOCALE_KEY = re.compile(r'^\s*\["((?:[^"\\]|\\.)*)"\]\s*=', re.M)
WORD = re.compile(r"[^\W\d_]{4,}")
EVENT_NAME = re.compile(r'"([A-Z]\w+)"')
LOCALES = ("en", "de", "ru", "es", "pt")


def check_luau(root: Path, files: list[Path]) -> list[str]:
    errors: list[str] = []
    luau = [p for p in files if p.suffix == ".luau" and rel(root, p).startswith(("src/", "plugin/", "tests/"))]
    if not luau:
        return errors
    texts = {p: read(p) for p in luau}
    extra = [read(p) for p in files if p.suffix in {".py", ".json", ".ps1"} and p.name not in SKIP_FILES and not rel(root, p).startswith(("assets/", "client-assets/"))]
    pool = "\n".join(list(texts.values()) + extra)
    counts: dict[str, int] = {}
    for token in re.findall(r"[A-Za-z_]\w*", pool):
        counts[token] = counts.get(token, 0) + 1

    # yalnızca tanımı olan modül fonksiyonları
    for path, text in texts.items():
        name = rel(root, path)
        if not name.startswith("src/"):
            continue
        for match in MODULE_FUNCTION.finditer(text):
            if counts.get(match.group(1), 0) <= 1:
                line = text.count("\n", 0, match.start()) + 1
                errors.append(f"{name}:{line}: `{match.group(1)}` yalnızca tanımlı, hiçbir yerde çağrılmıyor (ölü fonksiyon)")

    # yorum satırına alınmış kod
    for path, text in texts.items():
        for number, line in enumerate(text.splitlines(), 1):
            if COMMENTED_CODE.match(line):
                errors.append(f"{rel(root, path)}:{number}: yorum satırına alınmış kod: {line.strip()[:60]}")

    # Remotes olayları
    remotes = root / "src" / "shared" / "Remotes.luau"
    if remotes.exists():
        type_block = re.search(r"export type EventName =(.*?)\n\n", read(remotes), re.S)
        client = "\n".join(t for p, t in texts.items() if rel(root, p).startswith("src/client/"))
        server = "\n".join(t for p, t in texts.items() if rel(root, p).startswith("src/server/"))
        shared = "\n".join(t for p, t in texts.items() if rel(root, p).startswith("src/shared/") and p != remotes)
        for event in dict.fromkeys(EVENT_NAME.findall(type_block.group(1) if type_block else "")):
            word = re.compile(r"(?<![\w])" + event + r"(?![\w])")
            for side, body in (("istemci", client + shared), ("sunucu", server + shared)):
                if not word.search(body):
                    errors.append(f"src/shared/Remotes.luau: `{event}` olayı {side} tarafında hiç geçmiyor (yarım ya da ölü Remote)")

    # ölü çeviri anahtarları
    locale_dir = root / "src" / "shared" / "Locales"
    keysets = []
    for code in LOCALES:
        file = locale_dir / f"{code}.luau"
        if not file.exists():
            return errors
        keysets.append(set(LOCALE_KEY.findall(read(file))))
    outside = "\n".join(t for p, t in texts.items() if "/Locales/" not in rel(root, p)) + "\n" + "\n".join(extra)
    outside = outside.lower()
    for key in sorted(set.intersection(*keysets)):
        words = WORD.findall(re.sub(r"\\.|\{[^}]*\}", " ", key).lower())
        missing = [w for w in words if w not in outside]
        if missing:
            errors.append(f"src/shared/Locales: ölü çeviri anahtarı (`{missing[0]}` kodda hiç geçmiyor): {key[:60]}")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--root", type=Path, default=DEFAULT_ROOT, help="denetlenecek depo kökü (varsayılan: bu depo)")
    args = parser.parse_args()
    errors = check(args.root.resolve())
    if errors:
        print("Depo hijyeni bulguları:")
        for message in errors:
            print(f"  - {message}")
        return 1
    print("Depo hijyeni tamam: ölü referans, yetim belge/betik/modül ve izlenen çöp yok.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
