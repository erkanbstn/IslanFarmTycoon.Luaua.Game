#!/usr/bin/env python3
"""Check translation dictionaries against each other and against UI literals.

Fails (exit 1) when en/de/ru do not share the same Turkish key set.
Also lists plain Turkish UI literals (UiKit.text/button/menuButton, `.Text = "..."`,
`title = "..."`) that have no exact dictionary key. That list is a hint only: the
runtime Localizer may still translate them by splitting on " · ", newlines or ", ".
Pass --strict-literals to fail on those too.
"""

from __future__ import annotations

import argparse
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
LOCALES = ROOT / "src" / "shared" / "Locales"
LANGS = ("en", "de", "ru")
KEY = re.compile(r'^\s*\["((?:[^"\\]|\\.)*)"\]\s*=', re.MULTILINE)
LITERAL_PATTERNS = [
    re.compile(r'UiKit\.(?:text|button)\([^,]+,\s*"((?:[^"\\]|\\.)+)"'),
    re.compile(r'UiKit\.menuButton\([^,]+,\s*"[^"]*",\s*"((?:[^"\\]|\\.)+)"'),
    re.compile(r'\.Text\s*=\s*"((?:[^"\\]|\\.)+)"'),
    re.compile(r'\btitle\s*=\s*"((?:[^"\\]|\\.)+)"'),
]
TURKISH = re.compile(r"[A-Za-zÇĞİÖŞÜçğıöşü]{2,}")
SPLITTERS = re.compile(r" · |\n|, ")
# Yalnızca oyun sahibinin gördüğü Türkçe araç paneli ve bilinçli istisnalar
IGNORE_FILES = {"src/client/Ui/AdminPanel.luau"}
IGNORE_TEXTS = {"Dil / Language", "+$0/sn"}


def keys(lang: str) -> set[str]:
    return set(KEY.findall((LOCALES / f"{lang}.luau").read_text(encoding="utf-8")))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--strict-literals", action="store_true")
    args = parser.parse_args()
    sys.stdout.reconfigure(encoding="utf-8")

    sets = {lang: keys(lang) for lang in LANGS}
    union = set().union(*sets.values())
    failed = False
    for lang, found in sets.items():
        missing = sorted(union - found)
        if missing:
            failed = True
            print(f"[{lang}] missing {len(missing)} key(s):")
            for key in missing:
                print(f"  {key}")

    known = sets["en"]
    candidates: dict[str, list[str]] = {}
    for path in sorted((ROOT / "src").rglob("*.luau")):
        relative = path.relative_to(ROOT).as_posix()
        if LOCALES in path.parents or relative in IGNORE_FILES:
            continue
        source = path.read_text(encoding="utf-8")
        for pattern in LITERAL_PATTERNS:
            for match in pattern.finditer(source):
                text = match.group(1)
                if not TURKISH.search(text) or text in known or text in IGNORE_TEXTS:
                    continue
                if all(part in known or not TURKISH.search(part) for part in SPLITTERS.split(text)):
                    continue
                line = source.count("\n", 0, match.start()) + 1
                candidates.setdefault(text, []).append(f"{relative}:{line}")

    if candidates:
        print(f"{len(candidates)} UI literal(s) without an exact translation key:")
        for text, places in sorted(candidates.items()):
            print(f"  {text!r}  ({', '.join(places)})")
        if args.strict_literals:
            failed = True
    if not failed:
        print(f"Locales OK: {len(union)} keys in {', '.join(LANGS)}.")
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
