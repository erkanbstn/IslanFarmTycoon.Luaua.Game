#!/usr/bin/env python3
"""Luau tip analizi (luau-lsp analyze) + taban çizgisi karşılaştırması.

Roblox kodunda analizör çok sayıda gürültü üretir (ör. `{ Vector2, Color3 }` gibi karma tablolar,
`pcall` dönüşleri, eklenti için özel `require` yolları). Bu yüzden mevcut bulgular
`scripts/types-baseline.json` dosyasına kaydedilir ve yalnızca YENİ ya da ARTAN bulgular hata sayılır.

Kullanım:
  python scripts/check-types.py            # yeni bulgu varsa exit 1
  python scripts/check-types.py --update   # tabanı mevcut duruma göre yeniden yaz (bulguları gözden geçirdikten sonra)
  python scripts/check-types.py --all      # tabandaki bulgular dahil hepsini yazdır

Araçlar (git'e girmez, `.tools/` altında): scripts/setup-types.ps1 indirir. Araçlar yoksa adım atlanır (exit 0).
"""

import collections
import json
import os
import re
import shutil
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TOOLS = os.path.join(ROOT, ".tools", "luau-lsp")
BASELINE = os.path.join(ROOT, "scripts", "types-baseline.json")
LINE = re.compile(r"^(?:[A-Za-z]:)?[^\[]*?[\\/](src[\\/][^\s\[]+) \[[^\]]*\]\((\d+),(\d+)\): (\w+): (.*)$")


def find_rojo() -> str | None:
    found = shutil.which("rojo")
    if found:
        return found
    base = os.path.join(os.path.expanduser("~"), ".rokit", "tool-storage", "rojo-rbx", "rojo")
    if os.path.isdir(base):
        for version in sorted(os.listdir(base), reverse=True):
            for name in ("rojo.exe", "rojo"):
                candidate = os.path.join(base, version, name)
                if os.path.exists(candidate):
                    return candidate
    return None


def analyze() -> list[tuple[str, int, str]] | None:
    exe = os.path.join(TOOLS, "luau-lsp.exe" if os.name == "nt" else "luau-lsp")
    definitions = os.path.join(TOOLS, "globalTypes.d.luau")
    rojo = find_rojo()
    if not (os.path.exists(exe) and os.path.exists(definitions) and rojo):
        return None
    subprocess.run(
        [rojo, "sourcemap", "default.project.json", "-o", "sourcemap.json"],
        cwd=ROOT,
        check=True,
        capture_output=True,
    )
    result = subprocess.run(
        [exe, "analyze", f"--definitions={definitions}", "--sourcemap=sourcemap.json", "src"],
        cwd=ROOT,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    findings: list[tuple[str, int, str]] = []
    for line in (result.stdout + "\n" + result.stderr).splitlines():
        match = LINE.match(line)
        if not match:
            continue
        message = match.group(5).strip()
        # Konum ve değişken uzunluktaki parçalar kararlı bir anahtar için sadeleştirilir
        message = re.sub(r"[A-Za-z]:\\[^\s\]]+", "<yol>", message)
        findings.append((match.group(1).replace("\\", "/"), int(match.group(2)), message[:160]))
    return findings


def keyed(findings: list[tuple[str, int, str]]) -> collections.Counter:
    return collections.Counter(f"{path}|{message}" for path, _line, message in findings)


def main() -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    findings = analyze()
    if findings is None:
        print("Tip analizi ATLANDI: araçlar yok. `powershell scripts/setup-types.ps1` ile kur (.tools/luau-lsp).")
        return 0
    current = keyed(findings)
    if "--update" in sys.argv:
        with open(BASELINE, "w", encoding="utf-8", newline="\n") as handle:
            json.dump(dict(sorted(current.items())), handle, ensure_ascii=False, indent=1)
            handle.write("\n")
        print(f"Taban güncellendi: {len(findings)} bulgu, {len(current)} farklı anahtar.")
        return 0
    baseline: dict[str, int] = {}
    if os.path.exists(BASELINE):
        with open(BASELINE, encoding="utf-8") as handle:
            baseline = json.load(handle)
    new_items = {k: v - baseline.get(k, 0) for k, v in current.items() if v > baseline.get(k, 0)}
    if "--all" in sys.argv:
        for path, line, message in findings:
            print(f"{path}:{line} {message}")
    if new_items:
        print(f"Tip analizi: {sum(new_items.values())} YENİ bulgu (taban dışı):")
        first_lines = {f"{p}|{m}": line for p, line, m in findings}
        for key, count in sorted(new_items.items()):
            path, message = key.split("|", 1)
            print(f"  {path}:{first_lines.get(key, '?')} (+{count}) {message}")
        print("Gerçek hataysa düzelt; gürültüyse bilinçli olarak `python scripts/check-types.py --update` çalıştır.")
        return 1
    fixed = sum(max(0, baseline[k] - current.get(k, 0)) for k in baseline)
    print(f"Tip analizi tamam: yeni bulgu yok ({len(findings)} bilinen bulgu, tabandan {fixed} azalma).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
