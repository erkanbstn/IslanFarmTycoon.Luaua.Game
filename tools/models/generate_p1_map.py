#!/usr/bin/env python3
"""Generate the five P1 map models from the archived P1 list in docs/GPT_MODEL_IS_LISTESI.md (see git history)."""

from __future__ import annotations

import math
import xml.etree.ElementTree as ET
from dataclasses import dataclass
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
RGB = tuple[int, int, int]
V3 = tuple[float, float, float]

WOOD = 512
WOOD_PLANKS = 528
SLATE = 800
FABRIC = 1312


@dataclass(frozen=True)
class Part:
    name: str
    size: V3
    position: V3
    color: RGB
    material: int
    collide: bool = False
    angles: V3 = (0, 0, 0)


def scalar(parent: ET.Element, tag: str, name: str, value: str) -> None:
    ET.SubElement(parent, tag, name=name).text = value


def number(value: float) -> str:
    return f"{value:.9g}"


def vector(parent: ET.Element, tag: str, name: str, values: V3) -> None:
    element = ET.SubElement(parent, tag, name=name)
    for axis, value in zip("XYZ", values):
        ET.SubElement(element, axis).text = number(value)


def rotation(angles: V3) -> tuple[float, ...]:
    """CFrame.Angles(rx, ry, rz): Rx * Ry * Rz, row major."""
    rx, ry, rz = angles
    cx, sx = math.cos(rx), math.sin(rx)
    cy, sy = math.cos(ry), math.sin(ry)
    cz, sz = math.cos(rz), math.sin(rz)
    return (
        cy * cz, -cy * sz, sy,
        cx * sz + sx * sy * cz, cx * cz - sx * sy * sz, -sx * cy,
        sx * sz - cx * sy * cz, sx * cz + cx * sy * sz, cx * cy,
    )


def cframe(parent: ET.Element, name: str | None, position: V3, angles: V3 = (0, 0, 0)) -> None:
    attrs = {"name": name} if name else {}
    element = ET.SubElement(parent, "CoordinateFrame" if name else "CFrame", **attrs)
    values = (*position, *rotation(angles))
    for label, value in zip(("X", "Y", "Z", "R00", "R01", "R02", "R10", "R11", "R12", "R20", "R21", "R22"), values):
        ET.SubElement(element, label).text = number(value)


def serialize(name: str, parts: list[Part]) -> bytes:
    root = ET.Element("roblox", version="4")
    ET.SubElement(root, "Meta", name="ExplicitAutoJoints").text = "true"
    model = ET.SubElement(root, "Item", {"class": "Model", "referent": "RBXMODEL"})
    props = ET.SubElement(model, "Properties")
    scalar(props, "string", "Name", name)
    pivot = ET.SubElement(props, "OptionalCoordinateFrame", name="WorldPivotData")
    cframe(pivot, None, (0, 0, 0))
    for index, part in enumerate(parts, 1):
        item = ET.SubElement(model, "Item", {"class": "Part", "referent": f"RBXPART{index}"})
        properties = ET.SubElement(item, "Properties")
        scalar(properties, "string", "Name", part.name)
        vector(properties, "Vector3", "Size", part.size)
        cframe(properties, "CFrame", part.position, part.angles)
        color = ET.SubElement(properties, "Color3", name="Color")
        for channel, value in zip("RGB", part.color):
            ET.SubElement(color, channel).text = number(value / 255)
        scalar(properties, "token", "Material", str(part.material))
        scalar(properties, "token", "Shape", "1")
        for key, value in (("Anchored", True), ("CanCollide", part.collide), ("CanTouch", False), ("CanQuery", part.collide)):
            scalar(properties, "bool", key, str(value).lower())
    ET.indent(root, space="")
    return ET.tostring(root, encoding="utf-8", xml_declaration=False) + b"\n"


def bounds(parts: list[Part]) -> V3:
    low = [math.inf] * 3
    high = [-math.inf] * 3
    for part in parts:
        r = rotation(part.angles)
        half = [part.size[i] / 2 for i in range(3)]
        extent = [sum(abs(r[i * 3 + j]) * half[j] for j in range(3)) for i in range(3)]
        for i in range(3):
            low[i] = min(low[i], part.position[i] - extent[i])
            high[i] = max(high[i], part.position[i] + extent[i])
    return tuple(high[i] - low[i] for i in range(3))  # type: ignore[return-value]


def validate(path: Path, expected_name: str, expected_parts: int) -> None:
    root = ET.parse(path).getroot()
    assert root.tag == "roblox" and root.get("version") == "4"
    model, = root.findall("Item")
    assert model.get("class") == "Model"
    assert model.find("Properties/string[@name='Name']").text == expected_name
    assert model.find("Properties/OptionalCoordinateFrame[@name='WorldPivotData']/CFrame") is not None
    items = model.findall("Item")
    assert len(items) == expected_parts
    for item in items:
        assert item.get("class") == "Part"
        props = item.find("Properties")
        assert props is not None
        assert props.find("token[@name='Shape']").text == "1"
        assert props.find("bool[@name='Anchored']").text == "true"
        assert props.find("bool[@name='CanTouch']").text == "false"


def write(folder: str, name: str, parts: list[Part], maximum: int) -> None:
    assert 0 < len(parts) <= maximum
    destination = ROOT / "assets" / folder / f"{name}.rbxmx"
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_bytes(serialize(name, parts))
    validate(destination, name, len(parts))
    x, y, z = bounds(parts)
    print(f"{name} | {destination.relative_to(ROOT).as_posix()} | {len(parts)} | {x:.2f}×{y:.2f}×{z:.2f} | (0,0,0)")


def bridge(length: int) -> list[Part]:
    return [
        Part("Deck", (8, 1, length), (0, -0.5, 0), (140, 100, 60), WOOD_PLANKS, True),
        Part("Rail", (0.5, 2, length), (-4, 1, 0), (110, 80, 50), WOOD),
        Part("Rail", (0.5, 2, length), (4, 1, 0), (110, 80, 50), WOOD),
    ]


def main() -> None:
    write("BridgeModels", "BridgeModule_8", bridge(8), 8)
    write("BridgeModels", "BridgeModule_2", bridge(2), 8)
    write("SignModels", "IslandSign", [
        Part("SignPost", (0.5, 15.4, 0.5), (-3.55, 7.7, 0), (140, 100, 60), WOOD, True),
        Part("SignPost", (0.5, 15.4, 0.5), (3.55, 7.7, 0), (140, 100, 60), WOOD, True),
        Part("IslandSign", (6.4, 2.2, 0.35), (0, 13.6, 0), (85, 60, 40), WOOD_PLANKS),
    ], 10)
    write("SignModels", "Signpost_Direction", [
        Part("Post", (0.6, 7, 0.6), (0, 3.5, 0), (110, 80, 50), WOOD),
        *[Part("Board", (5.4, 1.3, 0.3), (0, y, -0.2), (150, 110, 70), WOOD_PLANKS)
          for y in (5.6, 4.0, 2.4)],
    ], 8)
    sale = [
        Part("SalePole", (0.45, 10, 0.45), (0, 5, 0), (120, 85, 55), WOOD),
        Part("SaleBanner", (4.2, 2.4, 0.2), (2.3, 8.6, 0), (196, 60, 52), FABRIC),
    ]
    for r in (1, 2, 3):
        sale.append(Part(
            "SaleStone", (1.6 + 0.5 * r, 1.2 + 0.2 * r, 1.8 + 0.4 * r),
            (1.3 * r - 3.4, 0.5, 1.6 + 0.5 * r), (120, 118, 110), SLATE, True,
            (0.1 * r, float(r), 0.05 * r),
        ))
    write("SignModels", "SaleMarker", sale, 8)


if __name__ == "__main__":
    main()
