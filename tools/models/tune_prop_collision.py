"""Apply a small physical-body/decorative-trim collision policy to model XML."""

from __future__ import annotations

import re
import xml.etree.ElementTree as ET
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
PART_PROPERTIES = re.compile(
    r'(<Item class="(?:Part|WedgePart)" referent="[^"]+">\s*<Properties>)(.*?)(</Properties>)',
    re.S,
)
# Each list corresponds to repeated parts of that name, in asset order.
POLICY: dict[str, dict[str, list[bool]]] = {
    **{f"CommonDecor/Crate_{size}": {"Box": [True]} for size in ("16", "20", "24")},
    **{f"CommonDecor/Rock_{letter}": {"Tint": [True, False, False]} for letter in "ABC"},
    **{f"CommonDecor/Stump_{letter}": {"Trunk": [True]} for letter in "AB"},
    "CommonDecor/LogPile": {"Log": [True, True, True]},
    "CommonDecor/Barrel": {"Hoop": [False, False]},
    "CommonDecor/HayBale_Single": {"Twine": [False, False]},
    "CommonDecor/HayBale_Stack": {"Twine": [False, False]},
    "CommonDecor/Mailbox": {"Flag": [False]},
    "CommonDecor/Wheelbarrow": {"Hay": [False], "Handle": [False, False]},
    "CommonDecor/Lamp": {"Arm": [False], "Lantern": [False], "Cap": [False]},
    "CommonDecor/SmallLamp": {"Lantern": [False], "Cap": [False]},
    "ShoreModels/DockTip": {
        "HoopLower": [False], "HoopUpper": [False], "FishingRod": [False],
    },
}


def tune(relative: str, rules: dict[str, list[bool]]) -> None:
    path = ROOT / "assets" / f"{relative}.rbxmx"
    source = path.read_text(encoding="utf-8")
    seen: dict[str, int] = {name: 0 for name in rules}
    changed = 0

    def replace_part(match: re.Match[str]) -> str:
        nonlocal changed
        opening, props, closing = match.groups()
        name_match = re.search(r'<string name="Name">([^<]+)</string>', props)
        assert name_match is not None, path
        name = name_match.group(1)
        if name not in rules:
            return match.group(0)
        index = seen[name]
        assert index < len(rules[name]), (path, name, index)
        seen[name] += 1
        value = str(rules[name][index]).lower()
        for key in ("CanCollide", "CanQuery"):
            pattern = re.compile(rf'(<bool name="{key}">)(true|false)(</bool>)')
            assert len(pattern.findall(props)) == 1, (path, name, key)
            props, count = pattern.subn(lambda m: m.group(1) + value + m.group(3), props)
            assert count == 1
        updated = opening + props + closing
        if updated != match.group(0):
            changed += 1
        return updated

    updated = PART_PROPERTIES.sub(replace_part, source)
    assert all(seen[name] == len(values) for name, values in rules.items()), (path, seen)
    if changed:
        path.write_text(updated, encoding="utf-8", newline="")
    root = ET.parse(path).getroot()
    assert root.find("Item/Properties/string[@name='Name']").text == path.stem
    print(f"{relative}: {changed} part(s) changed")


if __name__ == "__main__":
    for model_name, part_rules in POLICY.items():
        tune(model_name, part_rules)
