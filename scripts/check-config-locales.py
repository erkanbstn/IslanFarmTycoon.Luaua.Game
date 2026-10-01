#!/usr/bin/env python3
"""Config'teki oyuncuya görünen metinlerin (ad, açıklama, ürün, ada özelliği, aşama...) her dilde çevrildiğini denetler.

Config metinleri Türkçe kaynaktır ve çalışma anında `shared/Localization` ile çevrilir (tam eşleşme, `{}` şablon, " · " / ", " bölme).
Bu betik gerçek Config'i Luau ile yükler, metinleri toplar ve aynı algoritmanın Python karşılığıyla her sözlükte (en, de, ru, es, pt)
"tamamen çevrildi mi" diye bakar: çevrilmeyen ya da yalnızca kısmen çevrilen metin hata sayılır (`--list` ile eksik anahtarları yazdırır).

Kullanım:  python scripts/check-config-locales.py [--list] [--langs en,de]
"""

from __future__ import annotations

import argparse
import importlib.util
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
LOCALES = ROOT / "src" / "shared" / "Locales"
LANGS = ("en", "de", "ru", "es", "pt")
PAIR = re.compile(r'^\s*\["((?:[^"\\]|\\.)*)"\]\s*=\s*"((?:[^"\\]|\\.)*)"\s*,?\s*$', re.MULTILINE)
LETTER = re.compile(r"[A-Za-zÀ-￿]")
STRONG = ("\n", " · ")
# Bilinçli çevrilmeyen metinler: dil adları kendi dillerinde yazılır
IGNORE = {"Türkçe", "English", "Deutsch", "Русский", "Español", "Português"}

spec = importlib.util.spec_from_file_location("run_tests", ROOT / "scripts" / "run-tests.py")
run_tests = importlib.util.module_from_spec(spec)
assert spec.loader is not None
spec.loader.exec_module(run_tests)

# Config'te oyuncuya görünen metin alanları
FIELDS = ("displayName", "description", "trait", "product", "name", "eventName", "title", "text")

LUA_DUMP = r"""
local out = {}
local seen = {}
local FIELDS = __FIELDS__
local function add(text: any)
	if typeof(text) == "string" and text ~= "" and not seen[text] then
		seen[text] = true
		table.insert(out, text)
	end
end
local function walk(value: any, depth: number)
	if typeof(value) ~= "table" or depth > 8 then
		return
	end
	for key, child in value do
		if typeof(child) == "string" and FIELDS[key] then
			add(child)
		elseif typeof(child) == "table" then
			walk(child, depth + 1)
		end
	end
end
walk(Config, 0)
-- Kodda türetilen metinler: ana ada ağılı adı
for _, theme in Config.THEMES do
	local animal = Config.ANIMALS[theme.homeAnimal]
	add(`{animal.displayName} Ağılı`)
	add(`{theme.displayName}`)
end
local function esc(text: string): string
	text = string.gsub(text, "\\", "\\\\")
	text = string.gsub(text, '"', '\\"')
	text = string.gsub(text, "\n", "\\n")
	return text
end
local parts = {}
for _, text in out do
	table.insert(parts, '"' .. esc(text) .. '"')
end
print("[" .. table.concat(parts, ",") .. "]")
"""


def load_strings(executable: str) -> list[str]:
    fields = "{" + ", ".join(f"{name} = true" for name in FIELDS) + "}"
    prelude = (
        "--!nocheck\n"
        "local Color3 = { fromRGB = function(r, g, b) return { R = r / 255, G = g / 255, B = b / 255 } end }\n"
    )
    source = prelude + run_tests.config_bundle() + LUA_DUMP.replace("__FIELDS__", fields)
    output = ROOT / ".test-build" / f"config-strings-{os.getpid()}.luau"
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(source, encoding="utf-8")
    try:
        result = subprocess.run([executable, str(output)], cwd=ROOT, capture_output=True)
    finally:
        output.unlink(missing_ok=True)
    if result.returncode != 0:
        sys.stderr.write(result.stderr.decode("utf-8", errors="replace"))
        raise SystemExit(result.returncode)
    return json.loads(result.stdout.decode("utf-8"))


def unescape(text: str) -> str:
    return text.replace('\\"', '"').replace("\\n", "\n").replace("\\\\", "\\")


class Dictionary:
    def __init__(self, source: dict[str, str]) -> None:
        self.exact: dict[str, str] = {}
        self.strong: list[tuple[int, re.Pattern[str], str]] = []
        self.weak: list[tuple[int, re.Pattern[str], str]] = []
        for key, value in source.items():
            if "{}" in key:
                literals = key.split("{}")
                pattern = re.compile("^" + "(.*?)".join(re.escape(part) for part in literals) + "$", re.DOTALL)
                weight = sum(len(part) for part in literals)
                bucket = self.strong if (" · " in key or "\n" in key) else self.weak
                bucket.append((weight, pattern, value))
            else:
                self.exact[key] = value
        self.strong.sort(key=lambda item: (-item[0], item[1].pattern))
        self.weak.sort(key=lambda item: (-item[0], item[1].pattern))

    def covered(self, text: str, depth: int = 0) -> bool:
        """Metnin Türkçe harf içeren her parçası çevrilebiliyor mu (Localization.translateCore ile aynı sıra)?"""
        body = text.strip()
        if depth > 6 or not body or not LETTER.search(body):
            return True
        if body in self.exact:
            return True
        for _, pattern, target in self.strong:
            match = pattern.match(body)
            if match:
                return all(self.covered(group, depth + 1) for group in match.groups())
        for separator in STRONG:
            if separator in body:
                parts = body.split(separator)
                if all(self.covered(part, depth + 1) for part in parts):
                    return True
        for _, pattern, target in self.weak:
            match = pattern.match(body)
            if match:
                return all(self.covered(group, depth + 1) for group in match.groups())
        if ", " in body:
            return all(self.covered(part, depth + 1) for part in body.split(", "))
        return False


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--list", action="store_true", help="Eksik metinleri yazdır")
    parser.add_argument("--langs", default=",".join(LANGS))
    args = parser.parse_args()
    sys.stdout.reconfigure(encoding="utf-8")
    executable = shutil.which("luau")
    bundled = ROOT / ".tools" / "luau" / ("luau.exe" if sys.platform == "win32" else "luau")
    if executable is None and bundled.is_file():
        executable = str(bundled)
    if executable is None:
        print("Luau yorumlayıcısı bulunamadı (.tools/luau).", file=sys.stderr)
        return 2
    strings = load_strings(executable)
    failed = False
    for lang in [item for item in args.langs.split(",") if item]:
        source = {unescape(key): unescape(value) for key, value in PAIR.findall((LOCALES / f"{lang}.luau").read_text(encoding="utf-8"))}
        dictionary = Dictionary(source)
        missing = [text for text in strings if text not in IGNORE and not dictionary.covered(text)]
        if missing:
            failed = True
            print(f"[{lang}] {len(missing)} Config metni çevrilmemiş (toplam {len(strings)}):")
            if args.list:
                for text in missing:
                    print(f"  {text}")
        else:
            print(f"[{lang}] Config metinleri tamam ({len(strings)} metin).")
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
