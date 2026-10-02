"""Add LevelSign to the four existing barn assets and export SpecialtySign."""

from __future__ import annotations

import xml.etree.ElementTree as ET

from model_xml import PLANKS, WOOD, ROOT, Piece, _cframe, _scalar, _vector, write_model


def add_level_sign() -> None:
    for level in range(1, 5):
        path = ROOT / "assets" / "Barns" / f"Barn_Lv{level}.rbxmx"
        source = path.read_text(encoding="utf-8")
        model = ET.fromstring(source).find("Item")
        assert model is not None
        existing = [
            item for item in model.findall("Item")
            if item.find("Properties/string[@name='Name']").text == "LevelSign"
        ]
        if existing:
            assert len(existing) == 1, path
            size = existing[0].find("Properties/Vector3[@name='Size']")
            assert size is not None
            assert tuple(float(size.find(axis).text) for axis in "XYZ") == (10, 2, .4), path
            print(f"Barns/Barn_Lv{level}: LevelSign already present")
            continue
        pivot = model.find("Properties/OptionalCoordinateFrame[@name='WorldPivotData']/CFrame")
        assert pivot is not None
        px, py, pz = (float(pivot.find(axis).text) for axis in "XYZ")
        # Existing BarnVisualService fallback: frame * (0, 10.75, -6.3).
        part = ET.Element("Item", {"class": "Part", "referent": f"RBXLEVELSIGN{level}"})
        props = ET.SubElement(part, "Properties")
        _scalar(props, "string", "Name", "LevelSign")
        _vector(props, "Vector3", "Size", (10, 2, .4))
        _cframe(props, "CFrame", (px, py + 10.75, pz - 6.3))
        color = ET.SubElement(props, "Color3", name="Color")
        for channel, value in zip("RGB", (40, 30, 25)):
            ET.SubElement(color, channel).text = f"{value / 255:.9g}"
        _scalar(props, "token", "Material", PLANKS)
        _scalar(props, "token", "Shape", 1)
        for name, value in (
            ("Anchored", True), ("CanCollide", True),
            ("CanTouch", False), ("CanQuery", True),
        ):
            _scalar(props, "bool", name, str(value).lower())
        ET.SubElement(props, "token", name="TopSurface").text = "0"
        ET.SubElement(props, "token", name="BottomSurface").text = "0"

        closing = "\n</Item>\n</roblox>"
        assert source.endswith(closing + "\n"), path
        snippet = ET.tostring(part, encoding="unicode")
        updated = source[: -len(closing + "\n")] + "\n" + snippet + closing + "\n"
        path.write_text(updated, encoding="utf-8", newline="")
        parsed = ET.parse(path).getroot().find("Item")
        assert parsed is not None
        matches = [
            item for item in parsed.findall("Item")
            if item.find("Properties/string[@name='Name']").text == "LevelSign"
        ]
        assert len(matches) == 1, path
        print(f"Barns/Barn_Lv{level}: +1 LevelSign, {len(parsed.findall('Item'))} parts total")


def specialty_sign() -> None:
    # IslandSiteParts.sign: board at y=9.6, post centered at y=4.3.
    parts = [
        Piece("SpecialtySign", (7, 2, .35), (0, 9.6, 0),
              (131, 93, 58), PLANKS),
        Piece("SpecialtyPost", (.5, 8.6, .5), (0, 4.3, 0),
              (131, 93, 58), WOOD, collide=True),
    ]
    count, bounds = write_model("SignModels", "SpecialtySign", parts, 8)
    print(f"SignModels/SpecialtySign: {count} parts; bounding box {bounds}")


def main() -> None:
    add_level_sign()
    specialty_sign()


if __name__ == "__main__":
    main()
