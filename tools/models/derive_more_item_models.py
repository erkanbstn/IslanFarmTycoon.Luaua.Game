"""Generate ten more character-attachment item models from parts (no meshes), contract-identical to assets/Items/*.

Contract kept for every model (see docs/MODEL_SOZLESMESI.md, docs/model-ureticileri/review_item_models.py):
Part/WedgePart only, WorldPivotData = identity, `Attach` attribute follows the slot (tool->hip, staff->hand,
charm->chest, head, back), every part Anchored/Massless with CanCollide/CanTouch/CanQuery/CastShadow false,
no PrimaryPart, 6 <= parts <= (head 16, chest/hip 14, hand/back 20). Templates follow the existing items: wings share
the golden_wings/angel_wings fan structure (straps, harness, roots, fanned feathers, coverts), the sickle and the
wrench share the iron_hammer handle layout (x axis at y -0.85, z 0.62), the hat shares flat_cap's shell/visor layout,
charms sit on the chest in front (z about -0.65, y 0.15-1.1), the courier pack reuses the backpack straps.
Idempotent: python tools/models/derive_more_item_models.py (writes only changed files).
"""

from __future__ import annotations

import base64
import math
import struct
from dataclasses import dataclass
from pathlib import Path

from model_xml import FABRIC, GLASS, ICE, METAL, NEON, SMOOTH, WOOD

ROOT = Path(__file__).resolve().parents[2]
ITEMS = ROOT / "assets" / "Items"
V3 = tuple[float, float, float]
RGB = tuple[int, int, int]
LIMITS = {"head": 16, "chest": 14, "hip": 14, "hand": 20, "back": 20}


def _mul(a, b):
    return [[sum(a[i][k] * b[k][j] for k in range(3)) for j in range(3)] for i in range(3)]


def rot(rx: float = 0, ry: float = 0, rz: float = 0):
    """Rotation matrix Rz * Ry * Rx (degrees): X first, then Y, then Z about the world axes."""
    ax, ay, az = (math.radians(v) for v in (rx, ry, rz))
    cx, sx, cy, sy, cz, sz = math.cos(ax), math.sin(ax), math.cos(ay), math.sin(ay), math.cos(az), math.sin(az)
    rx_m = [[1, 0, 0], [0, cx, -sx], [0, sx, cx]]
    ry_m = [[cy, 0, sy], [0, 1, 0], [-sy, 0, cy]]
    rz_m = [[cz, -sz, 0], [sz, cz, 0], [0, 0, 1]]
    return _mul(rz_m, _mul(ry_m, rx_m))


@dataclass(frozen=True)
class Prt:
    name: str
    kind: str  # Part | WedgePart
    size: V3
    pos: V3
    color: RGB
    material: int = SMOOTH
    shape: int = 1  # Part: Ball 0, Block 1, Cylinder 2 (cylinder axis is local X)
    angles: V3 = (0, 0, 0)
    transparency: float = 0.0


def block(name, size, pos, color, material=SMOOTH, angles=(0, 0, 0), transparency=0.0):
    return Prt(name, "Part", size, pos, color, material, 1, angles, transparency)


def ball(name, d, pos, color, material=SMOOTH):
    return Prt(name, "Part", (d, d, d), pos, color, material, 0)


def cyl(name, length, d, pos, color, material=METAL, angles=(0, 0, 0)):
    """Cylinder whose axis is local X; rotate with angles to face another axis."""
    return Prt(name, "Part", (length, d, d), pos, color, material, 2, angles)


def wedge(name, size, pos, color, material=SMOOTH, angles=(0, 0, 0), transparency=0.0):
    return Prt(name, "WedgePart", size, pos, color, material, 1, angles, transparency)


def seg(name, a, b, width, thick, z, color, material=SMOOTH, overlap=1.0):
    """Flat bar in the XY plane from a to b (width across the bar, thick along Z)."""
    dx, dy = b[0] - a[0], b[1] - a[1]
    length = math.hypot(dx, dy) * overlap
    return block(
        name,
        (width, length, thick),
        ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2, z),
        color,
        material,
        (0, 0, math.degrees(math.atan2(-dx, dy))),
    )


def tip(name, base, direction_deg, length, width, thick, z, color, material=METAL):
    """Flat triangle in the XY plane: base centre at `base`, point `length` away along direction_deg."""
    d = (math.cos(math.radians(direction_deg)), math.sin(math.radians(direction_deg)))
    centre = (base[0] + d[0] * length / 2, base[1] + d[1] * length / 2, z)
    return wedge(name, (thick, width, length), centre, color, material, (0, 90, direction_deg - 180))


def _mat(m):
    return [round(v, 10) for row in m for v in row]


def _f(v: float, digits: int = 8) -> str:
    return f"{v:.{digits}f}"


def _bytes_attach(slot: str) -> str:
    payload = struct.pack("<II", 1, 6) + b"Attach" + b"\x02" + struct.pack("<I", len(slot)) + slot.encode()
    return base64.b64encode(payload).decode()


def _hull(part: Prt) -> list[V3]:
    x, y, z = (v / 2 for v in part.size)
    if part.kind == "WedgePart":
        pts = [(-x, -y, -z), (x, -y, -z), (-x, -y, z), (x, -y, z), (-x, y, z), (x, y, z)]
    else:
        pts = [(sx * x, sy * y, sz * z) for sx in (-1, 1) for sy in (-1, 1) for sz in (-1, 1)]
    m = rot(*part.angles)
    return [tuple(sum(m[i][j] * p[j] for j in range(3)) + part.pos[i] for i in range(3)) for p in pts]


def bounds(parts: list[Prt]) -> V3:
    pts = [p for part in parts for p in _hull(part)]
    return tuple(max(p[i] for p in pts) - min(p[i] for p in pts) for i in range(3))  # type: ignore[return-value]


def render(name: str, slot: str, parts: list[Prt]) -> str:
    assert 6 <= len(parts) <= LIMITS[slot], (name, len(parts))
    out = [
        "<?xml version='1.0' encoding='utf-8'?>",
        '<roblox version="4">',
        f'  <Item class="Model" referent="{name}">',
        "    <Properties>",
        f'      <string name="Name">{name}</string>',
        f'      <BinaryString name="AttributesSerialize">{_bytes_attach(slot)}</BinaryString>',
        '      <OptionalCoordinateFrame name="WorldPivotData">',
        "        <CFrame>",
        "          <X>0.00000000</X>",
        "          <Y>0.00000000</Y>",
        "          <Z>0.00000000</Z>",
        "          <R00>1.0000000000</R00>",
        "          <R01>-0.0000000000</R01>",
        "          <R02>0.0000000000</R02>",
        "          <R10>0.0000000000</R10>",
        "          <R11>1.0000000000</R11>",
        "          <R12>-0.0000000000</R12>",
        "          <R20>0.0000000000</R20>",
        "          <R21>0.0000000000</R21>",
        "          <R22>1.0000000000</R22>",
        "        </CFrame>",
        "      </OptionalCoordinateFrame>",
        "    </Properties>",
    ]
    for i, p in enumerate(parts):
        assert p.kind in ("Part", "WedgePart") and all(v > 0 for v in p.size), (name, p.name)
        assert all(0 <= c <= 255 for c in p.color), (name, p.name)
        if p.kind == "Part" and p.shape == 0:
            assert max(p.size) - min(p.size) < 1e-6, (name, p.name)
        r, g, b = (repr(c / 255) for c in p.color)
        m = _mat(rot(*p.angles))
        out += [
            f'    <Item class="{p.kind}" referent="{name}_{i}">',
            "      <Properties>",
            f'        <string name="Name">{p.name}</string>',
            '        <bool name="Anchored">true</bool>',
            '        <bool name="Massless">true</bool>',
            '        <bool name="CanCollide">false</bool>',
            '        <bool name="CanTouch">false</bool>',
            '        <bool name="CanQuery">false</bool>',
            '        <bool name="CastShadow">false</bool>',
            f'        <token name="Material">{p.material}</token>',
        ]
        if p.kind == "Part":
            out.append(f'        <token name="Shape">{p.shape}</token>')
        out += [
            '        <Color3 name="Color">',
            f"          <R>{r}</R>",
            f"          <G>{g}</G>",
            f"          <B>{b}</B>",
            "        </Color3>",
            '        <Vector3 name="Size">',
            *(f"          <{a}>{_f(v, 6).rstrip('0').rstrip('.')}</{a}>" for a, v in zip("XYZ", p.size)),
            "        </Vector3>",
            '        <CoordinateFrame name="CFrame">',
            *(f"          <{a}>{_f(v)}</{a}>" for a, v in zip("XYZ", p.pos)),
            *(
                f"          <R{i // 3}{i % 3}>{_f(v, 10)}</R{i // 3}{i % 3}>"
                for i, v in enumerate(m)
            ),
            "        </CoordinateFrame>",
            f'        <float name="Transparency">{p.transparency:g}</float>',
            "      </Properties>",
            "    </Item>",
        ]
    out += ["  </Item>", "</roblox>", ""]
    return "\n".join(out)


# ---------------------------------------------------------------------------------------------------------------
# palette
GOLD = (236, 190, 60)
BRIGHT_GOLD = (255, 218, 96)
BRASS = (196, 146, 64)
BRONZE = (176, 112, 52)
STEEL = (178, 186, 198)
DARK_STEEL = (96, 104, 116)
WARM_WOOD = (148, 96, 54)
LEATHER = (122, 86, 54)


def mirrored(parts_for_side):
    """Build both wings: callable(sign) -> list of parts (sign -1 left, +1 right)."""
    return [p for sign in (-1, 1) for p in parts_for_side(sign)]


def wing_straps(strap, harness):
    """Same straps/harness as golden_wings and angel_wings."""
    return [
        block("ShoulderStrap", (0.14, 1.66, 0.12), (-0.53, 0.62, 0.55), strap, FABRIC, (0, 0, 5)),
        block("ShoulderStrap", (0.14, 1.66, 0.12), (0.53, 0.62, 0.55), strap, FABRIC, (0, 0, -5)),
        block("WingHarness", (0.95, 0.42, 0.19), (0.0, 0.88, 0.72), harness, METAL),
    ]


# ---------------------------------------------------------------------------------------------------------------
def lucky_clover() -> tuple[str, list[Prt]]:
    cx, cy, z = 0.0, 0.52, -0.66
    greens = [(52, 176, 74), (84, 206, 96), (52, 176, 74), (84, 206, 96)]
    parts: list[Prt] = []
    for i, (dx, dy) in enumerate([(0, 1), (1, 0), (0, -1), (-1, 0)]):
        # heart-shaped leaf: a diamond pointing at the centre plus a round outer lobe
        parts.append(block("CloverLeaf", (0.2, 0.2, 0.07), (cx + dx * 0.15, cy + dy * 0.15, z), greens[i], SMOOTH, (0, 0, 45)))
        parts.append(ball("CloverLobe", 0.2, (cx + dx * 0.27, cy + dy * 0.27, z), greens[i]))
    parts.append(ball("CloverCenter", 0.16, (cx, cy, z - 0.07), BRIGHT_GOLD, METAL))
    parts.append(seg("CloverStem", (0.05, cy - 0.3), (0.2, cy - 0.5), 0.045, 0.04, z, (40, 128, 56)))
    parts.append(seg("CordLeft", (-0.04, cy + 0.37), (-0.19, 1.1), 0.035, 0.03, z, (120, 82, 46), FABRIC))
    parts.append(seg("CordRight", (0.04, cy + 0.37), (0.19, 1.1), 0.035, 0.03, z, (120, 82, 46), FABRIC))
    return "chest", parts


def harvest_sickle() -> tuple[str, list[Prt]]:
    y0, z = -0.85, 0.62
    parts = [
        block("Handle", (1.62, 0.22, 0.22), (-0.17, y0, z), WARM_WOOD, WOOD),
        block("GripBand1", (0.14, 0.26, 0.26), (-0.62, y0, z), LEATHER, FABRIC),
        block("GripBand2", (0.14, 0.26, 0.26), (-0.38, y0, z), LEATHER, FABRIC),
        block("ButtCap", (0.1, 0.29, 0.29), (-0.98, y0, z), BRASS, METAL),
        block("BladeCollar", (0.12, 0.3, 0.3), (0.62, y0, z), BRASS, METAL),
        block("BladeTang", (0.3, 0.14, 0.07), (0.78, y0, z), DARK_STEEL, METAL),
    ]
    rc, start, end = 0.5, 0.0, 205.0
    centre = (0.9, y0 + rc)
    widths = [0.2, 0.19, 0.17, 0.14, 0.11, 0.08]
    steps = len(widths)
    colors = [(186, 194, 206), (176, 184, 196), (188, 196, 208), (176, 184, 196), (190, 198, 210), (200, 208, 218)]

    def point(phi):
        a = math.radians(phi)
        return (centre[0] + rc * math.sin(a), centre[1] - rc * math.cos(a))

    for i in range(steps):
        a = start + (end - start) * i / steps
        b = start + (end - start) * (i + 1) / steps
        parts.append(seg("BladeCurve", point(a), point(b), widths[i], 0.06, z, colors[i], METAL, 1.12))
    phi = math.radians(end)
    tangent = math.degrees(math.atan2(math.sin(phi), math.cos(phi)))
    parts.append(tip("BladePoint", point(end), tangent, 0.26, 0.08, 0.06, z, (214, 222, 232)))
    parts.append(ball("BladeRivet", 0.09, (0.78, y0, z + 0.06), BRIGHT_GOLD, METAL))
    return "hip", parts


def victory_laurel() -> tuple[str, list[Prt]]:
    y = 0.64
    parts = [
        block("RingFront", (2.04, 0.16, 0.13), (0.0, y, -0.82), GOLD, METAL),
        block("RingBack", (2.04, 0.16, 0.13), (0.0, y, 0.82), GOLD, METAL),
        block("RingLeft", (0.13, 0.16, 1.52), (-0.95, y, 0.0), GOLD, METAL),
        block("RingRight", (0.13, 0.16, 1.52), (0.95, y, 0.0), GOLD, METAL),
    ]
    greens = [(46, 150, 62), (78, 186, 86)]
    n = 0

    def leaf(x, z, roll):
        nonlocal n
        n += 1
        parts.append(block("LaurelLeaf", (0.27, 0.07, 0.27), (x, y + 0.1, z), greens[n % 2], FABRIC, (0, 45, roll)))

    for sign in (-1, 1):
        for z in (-0.52, -0.17, 0.18, 0.53):  # side branches
            leaf(sign * 1.02, z, sign * 24)
        leaf(sign * 0.5, -0.88, sign * 6)  # converging at the front
        leaf(sign * 0.45, 0.88, sign * 6)  # tucked at the back
    return "head", parts


def _wing_side(
    sign, *, feathers, lengths, widths, angles, colors, start, step, z0, feather_material, root, root_material,
    under=None, covert=None, edge=None, feather_transparency=0.0, covert_materials=None
):
    side = []
    side.append(block("WingRoot", (0.5 if root[1] else 0.46, root[2], 0.24), (sign * 0.69, 0.85, 0.9), root[0], root_material, (0, 0, -sign * 24)))
    for i in range(feathers):
        px = sign * (start[0] + step[0] * i)
        py = start[1] + step[1] * i
        side.append(
            wedge(
                "FlightFeather",
                (widths[i], lengths[i], 0.14),
                (px, py, z0 + 0.015 * i),
                colors[i],
                feather_material,
                (0, 0, -sign * angles[i]),
                feather_transparency,
            )
        )
    if under:
        side.append(under(sign))
    if covert:
        side.append(covert(sign))
    if edge:
        side.append(edge(sign))
    return side


def phoenix_wings() -> tuple[str, list[Prt]]:
    lengths = [2.2, 2.45, 2.65, 2.85, 3.0]
    gradient = [(176, 22, 20), (218, 52, 20), (244, 100, 20), (255, 154, 30), (255, 206, 62)]  # crimson -> orange -> gold

    def side(sign):
        return _wing_side(
            sign,
            feathers=5,
            lengths=lengths,
            widths=[0.42] * 5,
            angles=[20, 29, 38, 47, 56],
            colors=gradient,
            start=(0.83, 0.82),
            step=(0.33, -0.24),
            z0=1.06,
            feather_material=METAL,
            root=((150, 18, 24), True, 1.3),
            root_material=FABRIC,
            under=lambda s: wedge(
                "FeatherLayer", (1.0, 2.1, 0.14), (s * 1.5, 0.46, 0.94), (120, 14, 26), METAL, (0, 0, -s * 34)
            ),
            covert=lambda s: wedge(
                "WingCovert", (0.46, 0.9, 0.18), (s * 1.05, 1.12, 1.19), (255, 176, 56), NEON, (0, 0, -s * 30)
            ),
        )

    parts = wing_straps((150, 72, 34), (222, 150, 44)) + mirrored(side)
    parts.append(wedge("TailFlame", (0.5, 1.7, 0.14), (0.0, -0.1, 1.12), (255, 150, 36), METAL, (0, 0, 0)))
    return "back", parts


def crystal_wings() -> tuple[str, list[Prt]]:
    lengths = [1.62, 1.77, 1.92, 2.07, 2.22]
    angles = [16, 25, 34, 43, 52]
    tints = [(214, 238, 255), (238, 250, 255), (206, 234, 255), (240, 250, 255), (196, 228, 255)]
    start, step = (0.83, 0.82), (0.28, -0.2)

    def edge(sign):
        # glowing strip riding the outer (leading) edge of the first feather
        a = math.radians(angles[0])
        n = (-sign * math.cos(a), math.sin(a))
        reach = 0.18 + 0.04
        return block(
            "NeonEdge",
            (0.06, lengths[0] * 1.04, 0.1),
            (sign * start[0] + n[0] * reach, start[1] + n[1] * reach, 1.06),
            (112, 230, 255),
            NEON,
            (0, 0, -sign * angles[0]),
        )

    def side(sign):
        return _wing_side(
            sign,
            feathers=5,
            lengths=lengths,
            widths=[0.36] * 5,
            angles=angles,
            colors=tints,
            start=start,
            step=step,
            z0=1.06,
            feather_material=ICE,
            feather_transparency=0.12,
            root=((150, 200, 238), False, 1.24),
            root_material=SMOOTH,
            covert=lambda s: wedge(
                "WingCovert", (0.4, 0.82, 0.18), (s * 1.12, 1.04, 1.19), (170, 220, 250), GLASS, (0, 0, -s * 24), 0.25
            ),
            edge=edge,
        )

    parts = wing_straps((120, 170, 214), (168, 210, 240)) + mirrored(side)
    parts.append(ball("CrystalCore", 0.22, (0.0, 0.88, 0.86), (126, 226, 255), NEON))
    return "back", parts


def engineer_wrench() -> tuple[str, list[Prt]]:
    y0, z = -0.85, 0.62
    parts = [
        block("Handle", (1.7, 0.2, 0.1), (-0.13, y0, z), STEEL, METAL),
        block("HandleGroove", (1.1, 0.06, 0.12), (-0.38, y0, z), DARK_STEEL, METAL),
        block("GripCollar1", (0.1, 0.27, 0.15), (-0.6, y0, z), BRASS, METAL),
        block("GripCollar2", (0.1, 0.27, 0.15), (0.3, y0, z), BRASS, METAL),
        block("ButtEye", (0.16, 0.3, 0.12), (-0.98, y0, z), BRASS, METAL),
        block("HeadBody", (0.36, 0.78, 0.12), (0.84, y0, z), STEEL, METAL),
        block("FixedJaw", (0.48, 0.22, 0.12), (1.26, y0 + 0.27, z), (190, 198, 210), METAL),
        block("MovableJaw", (0.48, 0.22, 0.12), (1.26, y0 - 0.27, z), (190, 198, 210), METAL),
        block("JawTooth", (0.1, 0.06, 0.12), (1.38, y0 + 0.13, z), DARK_STEEL, METAL),
        block("JawTooth", (0.1, 0.06, 0.12), (1.38, y0 - 0.13, z), DARK_STEEL, METAL),
        cyl("AdjustWorm", 0.5, 0.15, (1.0, y0 - 0.02, z + 0.1), BRASS, METAL, (0, 0, 90)),
        cyl("AdjustWheel", 0.1, 0.3, (1.0, y0 - 0.34, z + 0.1), BRONZE, METAL, (0, 0, 90)),
        ball("PivotRivet", 0.1, (0.7, y0, z + 0.07), BRIGHT_GOLD, METAL),
    ]
    return "hip", parts


def scholar_charm() -> tuple[str, list[Prt]]:
    cy, z = 0.62, -0.64
    navy, deep = (24, 52, 124), (14, 32, 88)
    page = (240, 228, 196)
    parts = []
    for sign, name in ((-1, "L"), (1, "R")):
        parts.append(block(f"BookCover{name}", (0.34, 0.5, 0.05), (sign * 0.17, cy, z + 0.03), navy, FABRIC, (0, sign * 14, 0)))
        parts.append(block(f"BookPage{name}", (0.28, 0.42, 0.04), (sign * 0.165, cy, z - 0.01), page, FABRIC, (0, sign * 14, 0)))
        parts.append(block(f"PageLine{name}", (0.18, 0.025, 0.045), (sign * 0.17, cy + 0.06, z - 0.034), deep, SMOOTH, (0, sign * 14, 0)))
        parts.append(ball(f"CornerTop{name}", 0.07, (sign * 0.34, cy + 0.25, z - 0.03), GOLD, METAL))
        parts.append(ball(f"CornerLow{name}", 0.07, (sign * 0.34, cy - 0.25, z - 0.03), GOLD, METAL))
    parts.append(block("BookSpine", (0.05, 0.54, 0.07), (0.0, cy, z + 0.01), GOLD, METAL))
    parts.append(block("Bookmark", (0.06, 0.26, 0.025), (0.0, cy - 0.38, z - 0.04), (190, 40, 52), FABRIC))
    parts.append(ball("WisdomGem", 0.1, (0.0, cy + 0.34, z - 0.03), (120, 210, 255), SMOOTH))
    return "chest", parts


def captain_hat() -> tuple[str, list[Prt]]:
    navy, navy_dark = (22, 38, 84), (14, 26, 62)
    parts = [
        block("CapShellFront", (1.92, 0.42, 0.13), (0.0, 0.79, -0.76), navy, FABRIC),
        block("CapShellBack", (1.92, 0.42, 0.13), (0.0, 0.79, 0.76), navy, FABRIC),
        block("CapShellLeft", (0.13, 0.42, 1.39), (-0.9, 0.79, 0.0), navy, FABRIC),
        block("CapShellRight", (0.13, 0.42, 1.39), (0.9, 0.79, 0.0), navy, FABRIC),
        block("FlaredTop", (2.3, 0.16, 2.1), (0.0, 1.08, -0.03), navy, FABRIC),
        block("CrownTop", (1.8, 0.14, 1.6), (0.0, 1.22, -0.03), navy_dark, FABRIC),
        block("PeakVisor", (1.5, 0.1, 0.8), (0.0, 0.6, -1.08), (12, 18, 36), SMOOTH, (-9, 0, 0)),
        block("VisorTrim", (1.54, 0.05, 0.1), (0.0, 0.5, -1.46), GOLD, METAL, (-9, 0, 0)),
        cyl("BadgeDisc", 0.05, 0.4, (0.0, 0.8, -0.86), (14, 26, 62), SMOOTH, (0, 90, 0)),
        block("AnchorShank", (0.05, 0.3, 0.04), (0.0, 0.8, -0.9), BRIGHT_GOLD, METAL),
        block("AnchorStock", (0.2, 0.045, 0.04), (0.0, 0.88, -0.9), BRIGHT_GOLD, METAL),
        block("AnchorArm", (0.04, 0.2, 0.04), (-0.09, 0.7, -0.9), BRIGHT_GOLD, METAL, (0, 0, -52)),
        block("AnchorArm", (0.04, 0.2, 0.04), (0.09, 0.7, -0.9), BRIGHT_GOLD, METAL, (0, 0, 52)),
        ball("AnchorRing", 0.1, (0.0, 0.97, -0.9), BRIGHT_GOLD, METAL),
        ball("SideButton", 0.12, (-0.93, 0.72, -0.62), GOLD, METAL),
        ball("SideButton", 0.12, (0.93, 0.72, -0.62), GOLD, METAL),
    ]
    return "head", parts


def courier_pack() -> tuple[str, list[Prt]]:
    teal, teal_dark, teal_light = (38, 140, 148), (28, 104, 112), (62, 170, 176)
    parts = [
        block("ShoulderStrap", (0.14, 1.66, 0.12), (-0.53, 0.62, 0.55), LEATHER, FABRIC, (0, 0, 5)),
        block("ShoulderStrap", (0.14, 1.66, 0.12), (0.53, 0.62, 0.55), LEATHER, FABRIC, (0, 0, -5)),
        block("PackBody", (1.4, 1.5, 0.42), (0.0, 0.25, 0.88), teal, FABRIC),
        cyl("BodyRoll", 1.5, 0.48, (0.0, 1.12, 0.9), teal_light, FABRIC),
        cyl("RollCap", 0.06, 0.52, (-0.78, 1.12, 0.9), LEATHER, FABRIC),
        cyl("RollCap", 0.06, 0.52, (0.78, 1.12, 0.9), LEATHER, FABRIC),
        block("RearFlap", (1.3, 0.8, 0.08), (0.0, 0.5, 1.12), teal_dark, FABRIC),
        block("FlapStrap", (0.12, 1.3, 0.05), (-0.34, 0.45, 1.17), LEATHER, FABRIC),
        block("FlapStrap", (0.12, 1.3, 0.05), (0.34, 0.45, 1.17), LEATHER, FABRIC),
        block("BuckleBar", (0.84, 0.1, 0.05), (0.0, 0.22, 1.18), LEATHER, FABRIC),
        block("Buckle", (0.24, 0.22, 0.06), (0.0, 0.22, 1.21), BRONZE, METAL),
        block("BuckleTongue", (0.07, 0.12, 0.07), (0.0, 0.22, 1.25), BRASS, METAL),
        block("ZipPocket", (0.8, 0.46, 0.14), (0.0, -0.28, 1.16), teal, FABRIC),
        block("PocketPull", (0.14, 0.05, 0.06), (0.0, -0.1, 1.25), BRONZE, METAL),
        block("CarryHandle", (0.62, 0.1, 0.12), (0.0, 1.62, 0.9), LEATHER, FABRIC),
        block("HandleLeg", (0.12, 0.26, 0.12), (-0.28, 1.46, 0.9), LEATHER, FABRIC),
        block("HandleLeg", (0.12, 0.26, 0.12), (0.28, 1.46, 0.9), LEATHER, FABRIC),
    ]
    return "back", parts


def merchant_seal() -> tuple[str, list[Prt]]:
    cy, z = 0.78, -0.68
    crimson, deep = (176, 24, 44), (132, 14, 32)
    face = (0, 90, 0)
    parts = [cyl("SealDisc", 0.07, 0.52, (0.0, cy, z), crimson, SMOOTH, face)]
    for k in range(6):
        a = math.radians(30 + 60 * k)
        parts.append(ball("SealScallop", 0.15, (0.27 * math.cos(a), cy + 0.27 * math.sin(a), z), crimson))
    parts.append(cyl("SealRing", 0.04, 0.4, (0.0, cy, z - 0.035), GOLD, METAL, face))
    parts.append(cyl("SealInner", 0.04, 0.3, (0.0, cy, z - 0.055), deep, SMOOTH, face))
    parts.append(block("SealStar", (0.15, 0.15, 0.04), (0.0, cy, z - 0.085), BRIGHT_GOLD, METAL, (0, 0, 45)))
    parts.append(block("RibbonLeft", (0.13, 0.46, 0.03), (-0.1, cy - 0.5, z + 0.03), (150, 18, 38), FABRIC, (0, 0, -12)))
    parts.append(block("RibbonRight", (0.13, 0.46, 0.03), (0.1, cy - 0.5, z + 0.03), (150, 18, 38), FABRIC, (0, 0, 12)))
    return "chest", parts


MODELS = {
    "lucky_clover": lucky_clover,
    "harvest_sickle": harvest_sickle,
    "victory_laurel": victory_laurel,
    "phoenix_wings": phoenix_wings,
    "crystal_wings": crystal_wings,
    "engineer_wrench": engineer_wrench,
    "scholar_charm": scholar_charm,
    "captain_hat": captain_hat,
    "courier_pack": courier_pack,
    "merchant_seal": merchant_seal,
}


def main() -> None:
    for name, build in MODELS.items():
        slot, parts = build()
        text = render(name, slot, parts)
        target = ITEMS / f"{name}.rbxmx"
        if not target.exists() or target.read_text(encoding="utf-8") != text:
            target.write_text(text, encoding="utf-8", newline="\n")
            print(f"wrote {target.relative_to(ROOT)}")
        size = bounds(parts)
        print(f"  {name}: {slot} {len(parts)} parts, size {size[0]:.2f} x {size[1]:.2f} x {size[2]:.2f}")


if __name__ == "__main__":
    main()
