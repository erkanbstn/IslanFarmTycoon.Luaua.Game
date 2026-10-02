"""Small deterministic Roblox XML writer for the remaining model work list."""

from __future__ import annotations

import math
import xml.etree.ElementTree as ET
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
V3 = tuple[float, float, float]
RGB = tuple[int, int, int]

PLASTIC = 256
SMOOTH = 272
NEON = 288
WOOD = 512
PLANKS = 528
SLATE = 800
CONCRETE = 816
BRICK = 848
STONE = 880
ROCK = 896
METAL = 1088
GRASS = 1280
SAND = 1296
FABRIC = 1312
SNOW = 1328
ICE = 1536
GLASS = 1568


@dataclass(frozen=True)
class Piece:
    name: str
    size: V3
    position: V3
    color: RGB
    material: int = SMOOTH
    shape: int = 1  # Part: Ball=0, Block=1, Cylinder=2
    kind: str = "Part"
    mesh_sphere: bool = False
    collide: bool = False
    transparency: float = 0.0
    angles: V3 = (0.0, 0.0, 0.0)


def _num(value: float) -> str:
    return f"{value:.9g}"


def _scalar(parent: ET.Element, tag: str, name: str, value: object) -> None:
    ET.SubElement(parent, tag, name=name).text = str(value)


def _vector(parent: ET.Element, tag: str, name: str, v: V3) -> None:
    node = ET.SubElement(parent, tag, name=name)
    for axis, value in zip("XYZ", v):
        ET.SubElement(node, axis).text = _num(value)


def _rotation(angles: V3) -> tuple[float, ...]:
    rx, ry, rz = angles
    cx, sx = math.cos(rx), math.sin(rx)
    cy, sy = math.cos(ry), math.sin(ry)
    cz, sz = math.cos(rz), math.sin(rz)
    return (
        cy * cz, -cy * sz, sy,
        cx * sz + sx * sy * cz, cx * cz - sx * sy * sz, -sx * cy,
        sx * sz - cx * sy * cz, sx * cz + cx * sy * sz, cx * cy,
    )


def _cframe(parent: ET.Element, name: str | None, position: V3, angles: V3 = (0, 0, 0)) -> None:
    attrs = {"name": name} if name else {}
    node = ET.SubElement(parent, "CoordinateFrame" if name else "CFrame", **attrs)
    for key, value in zip(
        ("X", "Y", "Z", "R00", "R01", "R02", "R10", "R11", "R12", "R20", "R21", "R22"),
        (*position, *_rotation(angles)),
    ):
        ET.SubElement(node, key).text = _num(value)


def bounding_box(pieces: list[Piece]) -> V3:
    low, high = [math.inf] * 3, [-math.inf] * 3
    for part in pieces:
        r = _rotation(part.angles)
        half = [dim / 2 for dim in part.size]
        for i in range(3):
            extent = sum(abs(r[i * 3 + j]) * half[j] for j in range(3))
            low[i] = min(low[i], part.position[i] - extent)
            high[i] = max(high[i], part.position[i] + extent)
    return tuple(high[i] - low[i] for i in range(3))  # type: ignore[return-value]


def write_model(folder: str, name: str, pieces: list[Piece], maximum: int, *,
                client: bool = False, primary: str | None = None) -> tuple[int, V3]:
    """Write one model and validate its XML before returning to the next model."""
    assert 0 < len(pieces) <= maximum, (name, len(pieces), maximum)
    assert not primary or [p.name for p in pieces].count(primary) == 1, name
    for part in pieces:
        assert part.kind in ("Part", "WedgePart"), (name, part.name)
        if part.kind == "Part":
            assert part.shape in (0, 1, 2)
            if part.shape == 0:
                assert max(part.size) - min(part.size) < 0.011, (name, part.name, part.size)
            if part.mesh_sphere:
                assert part.shape == 1, (name, part.name)
        else:
            assert not part.mesh_sphere, (name, part.name)
        assert all(v > 0 for v in part.size)
        assert all(0 <= c <= 255 for c in part.color)
    root = ET.Element("roblox", version="4")
    ET.SubElement(root, "Meta", name="ExplicitAutoJoints").text = "true"
    model = ET.SubElement(root, "Item", {"class": "Model", "referent": "RBXMODEL"})
    props = ET.SubElement(model, "Properties")
    _scalar(props, "string", "Name", name)
    pivot = ET.SubElement(props, "OptionalCoordinateFrame", name="WorldPivotData")
    _cframe(pivot, None, (0, 0, 0))
    if primary:
        index = next(i for i, p in enumerate(pieces, 1) if p.name == primary)
        _scalar(props, "Ref", "PrimaryPart", f"RBXPART{index}")
    for index, part in enumerate(pieces, 1):
        item = ET.SubElement(model, "Item", {"class": part.kind, "referent": f"RBXPART{index}"})
        p = ET.SubElement(item, "Properties")
        _scalar(p, "string", "Name", part.name)
        _vector(p, "Vector3", "Size", part.size)
        _cframe(p, "CFrame", part.position, part.angles)
        color = ET.SubElement(p, "Color3", name="Color")
        for axis, value in zip("RGB", part.color):
            ET.SubElement(color, axis).text = _num(value / 255)
        _scalar(p, "token", "Material", part.material)
        if part.kind == "Part":
            _scalar(p, "token", "Shape", part.shape)
        for key, value in (("Anchored", True), ("CanCollide", part.collide),
                           ("CanTouch", False), ("CanQuery", part.collide)):
            _scalar(p, "bool", key, str(value).lower())
        if part.transparency:
            _scalar(p, "float", "Transparency", _num(part.transparency))
        if part.mesh_sphere:
            mesh = ET.SubElement(item, "Item", {"class": "SpecialMesh", "referent": f"RBXMESH{index}"})
            mp = ET.SubElement(mesh, "Properties")
            _scalar(mp, "string", "Name", "SpecialMesh")
            _scalar(mp, "token", "MeshType", 3)
            _vector(mp, "Vector3", "Scale", (1, 1, 1))
            _vector(mp, "Vector3", "Offset", (0, 0, 0))
    ET.indent(root, space="")
    path = ROOT / ("client-assets" if client else "assets") / folder / f"{name}.rbxmx"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(ET.tostring(root, encoding="utf-8") + b"\n")
    parsed = ET.parse(path).getroot()
    models = parsed.findall("Item")
    assert len(models) == 1 and models[0].get("class") == "Model"
    assert models[0].find("Properties/string[@name='Name']").text == name
    assert models[0].find("Properties/OptionalCoordinateFrame[@name='WorldPivotData']/CFrame") is not None
    assert len(models[0].findall("Item")) == len(pieces)
    if primary:
        assert models[0].find("Properties/Ref[@name='PrimaryPart']") is not None
    return len(pieces), bounding_box(pieces)
