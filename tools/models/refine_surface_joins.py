"""Separate peacock fan layers and join window corners without intersecting side walls.

Idempotent asset edit: python tools/models/refine_surface_joins.py
"""
from pathlib import Path
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[2]


def parts(root):
    return [p for p in root.iter("Properties") if p.find('CoordinateFrame[@name="CFrame"]') is not None
            and p.find('Vector3[@name="Size"]') is not None]


def name(part):
    return part.find('string[@name="Name"]').text


def value(part, group, axis):
    return float(part.find(f'{group}/{axis}').text)


def put(part, group, axis, number):
    node = part.find(f'{group}/{axis}')
    if abs(float(node.text) - number) > 1e-7:
        node.text = f"{number:.9g}"


CF = 'CoordinateFrame[@name="CFrame"]'
SIZE = 'Vector3[@name="Size"]'


def windows(root):
    rows = parts(root)
    jambs = [p for p in rows if name(p) == "WindowJamb"]
    if not jambs:
        return
    for wall in [p for p in rows if name(p) in ("WallLeft", "WallRight")]:
        center = value(wall, CF, "X")
        outer = min(jambs, key=lambda p: abs(value(p, CF, "X") - center))
        if abs(value(outer, CF, "X") - center) > value(wall, SIZE, "X"):
            continue
        # The window-side corner fills the front strip. The side wall starts at its back edge.
        back_edge = value(wall, CF, "Z") + value(wall, SIZE, "Z") / 2
        front_edge = value(outer, CF, "Z") + value(outer, SIZE, "Z") / 2
        put(wall, SIZE, "Z", back_edge - front_edge)
        put(wall, CF, "Z", (back_edge + front_edge) / 2)
        put(outer, CF, "X", center)
        put(outer, SIZE, "X", value(wall, SIZE, "X"))


def fan(root):
    rows = parts(root)
    feathers = [p for p in rows if name(p) == "Feather"]
    if not feathers:
        return
    normal = [value(feathers[0], CF, "R" + str(i) + "2") for i in range(3)]
    depths = [sum(value(p, CF, a) * n for a, n in zip("XYZ", normal)) for p in feathers]
    center = sum(depths) / len(depths)
    layers = {id(p): center + (i - (len(feathers) - 1) / 2) * 0.085 for i, p in enumerate(feathers)}
    owner = None
    for p in rows:
        if name(p) == "Feather":
            owner = p
            put(p, SIZE, "X", 0.60)
            put(p, SIZE, "Z", 0.06)
            target = layers[id(p)]
        elif name(p) == "Eyespot" and owner is not None:
            put(p, SIZE, "Z", 0.035)
            target = layers[id(owner)] + 0.06 / 2 + 0.035 / 2 + 0.012
        else:
            continue
        depth = sum(value(p, CF, a) * n for a, n in zip("XYZ", normal))
        for a, n in zip("XYZ", normal):
            put(p, CF, a, value(p, CF, a) + (target - depth) * n)


def main():
    paths = [ROOT / "assets/Animals/peacock.rbxmx"]
    paths += sorted((ROOT / "assets/Buildings").glob("*.rbxmx"))
    paths += sorted((ROOT / "assets/BuildingLevels").glob("*.rbxmx"))
    changed = 0
    for path in paths:
        tree = ET.parse(path)
        before = ET.tostring(tree.getroot())
        (fan if path.stem == "peacock" else windows)(tree.getroot())
        if ET.tostring(tree.getroot()) != before:
            tree.write(path, encoding="utf-8", xml_declaration=True)
            changed += 1
    print(f"Updated {changed} models")


if __name__ == "__main__":
    main()
