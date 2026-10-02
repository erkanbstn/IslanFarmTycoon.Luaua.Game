#!/usr/bin/env python3
"""Eşit olmayan Ball parçaları Block + SpecialMesh(Sphere) çiftine çevirir (Roblox'ta eşit olmayan Ball küre çizilir).

Kaynak kod kurucuları elipsi `Part + SpecialMesh(Sphere)` ile çiziyordu; eski dışa aktarım bunu Ball'a çevirmişti ve görünüm küçülüyordu.
Kullanım: python scripts/fix-ellipsoid-balls.py [--dry-run]
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PART = re.compile(r'<Item class="Part" referent="([^"]+)"><Properties>(.*?)</Properties></Item>', re.S)


def fix(text: str) -> tuple[str, int]:
    count = 0

    def repl(match: re.Match) -> str:
        nonlocal count
        referent, props = match.group(1), match.group(2)
        shape = re.search(r'<token name="Shape">(\d)</token>', props)
        size = re.search(r'<Vector3 name="Size"><X>([^<]*)</X><Y>([^<]*)</Y><Z>([^<]*)</Z></Vector3>', props)
        if not shape or shape.group(1) != "0" or not size:
            return match.group(0)
        dims = [float(v) for v in size.groups()]
        if max(dims) - min(dims) <= 0.011:
            return match.group(0)
        count += 1
        props = props.replace(shape.group(0), '<token name="Shape">1</token>')
        mesh = (f'<Item class="SpecialMesh" referent="{referent}_MESH"><Properties>\n'
                '<token name="MeshType">3</token>\n</Properties></Item>')
        return f'<Item class="Part" referent="{referent}"><Properties>{props}</Properties>{mesh}</Item>'

    return PART.sub(repl, text), count


def main() -> int:
    dry = "--dry-run" in sys.argv
    total = files = 0
    roots = [ROOT / "assets", ROOT / "client-assets"]
    for root in roots:
        for path in sorted(root.rglob("*.rbxmx")):
            text = path.read_text(encoding="utf-8")
            new, n = fix(text)
            if n:
                total += n
                files += 1
                if not dry:
                    path.write_text(new, encoding="utf-8", newline="")
    print(f"{files} dosyada {total} parça {'(deneme)' if dry else 'dönüştürüldü'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
