"""Make only the tree trunks solid in the existing CommonDecor XML assets."""

from __future__ import annotations

import re
import xml.etree.ElementTree as ET
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
PART = re.compile(r'(<Item class="Part" referent="[^"]+">\s*<Properties>)(.*?)(</Properties>\s*</Item>)', re.S)
TREE_COUNTS = {
    **{f"OakTree_{letter}": 1 for letter in "ABCD"},
    **{f"PineTree_{letter}": 1 for letter in "ABC"},
    **{f"BirchTree_{letter}": 1 for letter in "AB"},
    **{f"PalmTree_{letter}": 4 for letter in "AB"},
}


def fix(name: str, expected: int) -> None:
    path = ROOT / "assets" / "CommonDecor" / f"{name}.rbxmx"
    source = path.read_text(encoding="utf-8")
    changed = 0
    found = 0

    def update(match: re.Match[str]) -> str:
        nonlocal changed, found
        opening, properties, closing = match.groups()
        if '<string name="Name">Trunk</string>' not in properties:
            return match.group(0)
        found += 1
        if '<bool name="CanCollide">true</bool>' in properties:
            assert '<bool name="CanQuery">true</bool>' in properties, path
            return match.group(0)
        for key in ("CanCollide", "CanQuery"):
            old = f'<bool name="{key}">false</bool>'
            new = f'<bool name="{key}">true</bool>'
            assert properties.count(old) == 1, (path, key)
            properties = properties.replace(old, new)
        changed += 1
        return opening + properties + closing

    updated = PART.sub(update, source)
    assert found == expected, (path, found, expected)
    if changed:
        path.write_text(updated, encoding="utf-8", newline="")
    model = ET.parse(path).getroot().find("Item")
    assert model is not None
    trunks = [
        part for part in model.findall("Item")
        if part.find("Properties/string[@name='Name']").text == "Trunk"
    ]
    assert len(trunks) == expected
    assert all(
        part.find("Properties/bool[@name='CanCollide']").text == "true"
        and part.find("Properties/bool[@name='CanQuery']").text == "true"
        for part in trunks
    )
    print(f"{path.relative_to(ROOT)}: {changed} trunk part(s) updated, {expected} solid")


if __name__ == "__main__":
    for tree, count in TREE_COUNTS.items():
        fix(tree, count)
