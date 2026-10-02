#!/usr/bin/env python3
"""Generate the remaining models in docs/GPT_MODEL_IS_LISTESI.md."""

from __future__ import annotations

import math
from dataclasses import replace
from pathlib import Path

from model_xml import (
    BRICK, FABRIC, GLASS, GRASS, ICE, METAL, NEON, PLANKS, ROCK, SAND,
    SLATE, SMOOTH, SNOW, STONE, WOOD, Piece, ROOT, bounding_box, write_model,
)

Record = tuple[str, str, int, tuple[float, float, float], str]
records: list[Record] = []


def add(folder: str, name: str, pieces: list[Piece], maximum: int, *, client: bool = False,
        primary: str | None = None, note: str = "") -> None:
    count, box = write_model(folder, name, pieces, maximum, client=client, primary=primary)
    path = f"{'client-assets' if client else 'assets'}/{folder}/{name}.rbxmx"
    records.append((name, path, count, box, note))
    print(f"{path}: {count} parts, {box[0]:.2f} x {box[1]:.2f} x {box[2]:.2f}")


def ball(name: str, diameter: float, position: tuple[float, float, float],
         color: tuple[int, int, int], material: int = SMOOTH, **kwargs: object) -> Piece:
    return Piece(name, (diameter,) * 3, position, color, material, shape=0, **kwargs)


def ellipse(name: str, size: tuple[float, float, float], position: tuple[float, float, float],
            color: tuple[int, int, int], material: int = SMOOTH, **kwargs: object) -> Piece:
    return Piece(name, size, position, color, material, mesh_sphere=True, **kwargs)


def vertical_cylinder(name: str, diameter: float, height: float,
                      position: tuple[float, float, float], color: tuple[int, int, int],
                      material: int = WOOD) -> Piece:
    return Piece(name, (height, diameter, diameter), position, color, material,
                 shape=2, angles=(0, 0, math.pi / 2))


def resize_box(parts: list[Piece], target: tuple[float, float, float]) -> list[Piece]:
    """Scale a model's three local axes to a specified bounds size."""
    current = bounding_box(parts)
    factors = tuple(target[i] / current[i] for i in range(3))
    return [
        replace(p, size=tuple(p.size[i] * factors[i] for i in range(3)),
                position=tuple(p.position[i] * factors[i] for i in range(3)))
        for p in parts
    ]


def client_models() -> None:
    for name, body_color, wing_color, beak_color in (
        ("Gull", (245, 245, 245), (190, 195, 205), (245, 180, 60)),
        ("Songbird", (80, 70, 65), (60, 52, 48), (235, 190, 70)),
    ):
        parts = [
            ellipse("Body", (0.5, 0.45, 1.6), (0, 0, 0), body_color),
            Piece("LeftWing", (2.2, 0.08, 0.7), (-1.1, 0, 0.1), wing_color),
            Piece("RightWing", (2.2, 0.08, 0.7), (1.1, 0, 0.1), wing_color),
            ball("Head", 0.38, (0, 0.05, -0.65), body_color),
            Piece("Beak", (0.18, 0.12, 0.23), (0, 0.02, -0.83), beak_color, kind="WedgePart"),
            Piece("Tail", (0.45, 0.08, 0.22), (0, 0, 0.69), wing_color),
        ]
        add("Birds", name, parts, 8, client=True, primary="Body", note="Body/LeftWing/RightWing ayrı")

    fish = [
        ellipse("Body", (0.55, 0.5, 1.4), (0, 0, 0), (200, 200, 205)),
        Piece("Tail", (0.08, 0.55, 0.5), (0, 0, 0.7), (210, 210, 215), kind="WedgePart"),
        ball("Eye", 0.12, (-0.2, 0.1, -0.5), (15, 15, 15)),
        ball("Eye", 0.12, (0.2, 0.1, -0.5), (15, 15, 15)),
        Piece("Tint", (0.24, 0.25, 0.46), (0, 0.34, 0.02), (200, 200, 205), kind="WedgePart"),
        Piece("Snout", (0.2, 0.15, 0.3), (0, -0.05, -0.78), (200, 200, 205)),
    ]
    add("Fish", "ReefFish", fish, 8, client=True, primary="Body", note="Tail WedgePart; Tint yüzgeç")

    jelly = [ellipse("JellyBell", (2.4, 1.8, 2.4), (0, 0, 0),
                     (240, 150, 220), NEON, transparency=0.45)]
    for index in range(1, 6):
        angle = index / 5 * math.tau
        jelly.append(Piece("JellyTentacle", (0.12, 2.6, 0.12),
                           (math.cos(angle) * 0.7, -1.9, math.sin(angle) * 0.7),
                           (240, 150, 220), NEON, transparency=0.55))
    add("Sea", "Jellyfish", jelly, 10, client=True, primary="JellyBell", note="5 ayrı JellyTentacle")

    coral = [Piece("Tint", (0.55, 3.4, 0.55), (0, 1.7, 0), (240, 130, 110), SLATE)]
    branches = [(-0.85, 0, -0.3), (0.85, 0, 0.3), (0, -0.8, -0.3),
                (0, 0.8, 0.3), (-0.65, 0.65, -0.25)]
    for x, z, lean in branches:
        coral.append(Piece("Tint", (0.3, 1.8, 0.3), (x * 0.55, 2.9, z * 0.55),
                           (240, 130, 110), SLATE, angles=(0.18 * z, 0, lean)))
        coral.append(ball("Tip", 0.35, (x, 4.05, z), (255, 238, 214), SLATE))
    coral = [replace(p, position=(p.position[0] * 1.25, p.position[1], p.position[2] * 1.3))
             for p in coral]
    add("Sea", "BranchCoral", coral, 14, client=True, note="5 dallı, uçlar tepede")

    brain: list[Piece] = []
    for x, y, size in ((-1.7, 0.78, (1.9, 1.55, 2.7)),
                       (0, 0.88, (2.0, 1.75, 3.1)),
                       (1.7, 0.78, (1.9, 1.55, 2.7))):
        brain.append(ellipse("Tint", size, (x, y, 0), (225, 135, 150), SLATE))
    for x, z in ((-1.3, -0.25), (0.1, 0.4), (1.2, -0.3)):
        brain.append(ball("Tint", 0.75, (x, 1.5, z), (238, 153, 160), SLATE))
    add("Sea", "BrainCoral", brain, 10, client=True, note="3 yassı elips küme")

    fan: list[Piece] = []
    for x, y, z, width, angle in ((-1.35, 2.0, -0.32, 1.7, -0.13),
                                  (0, 2.15, 0, 1.8, 0),
                                  (1.35, 2.0, 0.32, 1.7, 0.13)):
        fan.append(ellipse("Tint", (width, 3.9, 0.2), (x, y, z),
                           (160, 130, 220), SLATE, angles=(0, angle, 0)))
        fan.append(Piece("Stem", (0.18, 0.9, 0.18), (x, 0.45, z), (130, 100, 170), SLATE))
    add("Sea", "FanCoral", fan, 10, client=True, note="dik duran 3 yelpaze")

    rock_configs = (
        ("SeaRock_A", (3.0, 2.0, 3.0), (-0.6, 0.5, 0.45)),
        ("SeaRock_B", (4.0, 2.5, 3.0), (0.7, 0.6, -0.2)),
        ("SeaRock_C", (2.5, 1.8, 2.5), (-0.35, 0.4, -0.35)),
    )
    for name, size, offset in rock_configs:
        sx, sy, sz = size
        rocks = [
            Piece("Tint", (sx * 0.62, sy * 0.68, sz * 0.7),
                  (0, sy * 0.34, 0), (110, 112, 118), SLATE, angles=(0, 0.3, 0)),
            Piece("Tint", (sx * 0.42, sy * 0.58, sz * 0.45),
                  (offset[0], sy * 0.29, offset[2]), (98, 105, 112), SLATE, angles=(0, -0.32, 0)),
            Piece("Tint", (sx * 0.4, sy * 0.43, sz * 0.52),
                  (-offset[0] * 0.8, sy * 0.215, -offset[2] * 0.7),
                  (120, 121, 124), SLATE, angles=(0, 0.6, 0)),
        ]
        rocks = resize_box(rocks, size)
        add("Sea", name, rocks, 6, client=True, note="düz tabanlı kaya yığını")

    star = [ellipse("Tint", (0.55, 0.3, 0.55), (0, 0.15, 0),
                    (240, 120, 70), SLATE)]
    for index in range(5):
        angle = index * math.tau / 5
        star.append(Piece("Tint", (0.5, 0.25, 1.5),
                          (math.sin(angle) * 0.7, 0.18, -math.cos(angle) * 0.7),
                          (240, 120, 70), SLATE, angles=(0, angle, 0)))
    add("Sea", "Starfish", star, 8, client=True, note="5 kol, merkezde birleşir")

    add("Season", "BareBranch", [Piece("Branch", (0.25, 3.0, 0.25),
                                            (0, 1.5, 0), (108, 76, 52), WOOD)],
        5, client=True, note="pivot dalın alt ucu")
    add("Season", "FallingLeaf", [ellipse("Tint", (0.22, 0.05, 0.42),
                                               (0, 0, 0), (207, 104, 37), FABRIC)],
        3, client=True, note="düşen yaprak; merkez pivot")


def common_variants() -> None:
    crown_colors = ((70, 140, 60), (85, 155, 65), (60, 125, 55), (100, 160, 70))
    crowns = (
        ((-1.25, 10.0, 0.2), (1.25, 10.3, 0), (0, 11.5, -1.0), (0, 11.2, 1.0)),
        ((-1.0, 10.7, -1.0), (1.4, 9.7, 0.4), (-0.2, 11.8, 1.0), (0.8, 11.3, -0.6)),
        ((-1.35, 9.9, 0.9), (1.2, 10.7, -0.8), (0, 11.7, 0), (0.5, 10.4, 1.1)),
        ((-1.2, 10.8, -0.4), (1.25, 10.0, 0.6), (0, 11.55, 1.0), (-0.3, 11.5, -1.0)),
    )
    for index, locations in enumerate(crowns):
        trunk = vertical_cylinder("Trunk", 1.8, 8, (0, 4, 0), (110, 78, 51))
        branch = Piece("Branch", (3.2, 0.55, 0.55), (0.3 if index % 2 else -0.3, 7.5, 0),
                       (110, 78, 51), WOOD, angles=(0, 0, 0.17 * (index - 1)))
        leaves = [ball("Leaves", 5.4 + (j % 2) * 0.6, p, crown_colors[(index + j) % 4], GRASS)
                  for j, p in enumerate(locations)]
        add("CommonDecor", f"OakTree_{'ABCD'[index]}", [trunk, branch, *leaves], 9,
            note="Trunk silindir; 4 mevsimlik Leaves")

    for index in range(3):
        trunk = vertical_cylinder("Trunk", 1.2, 11, (0, 5.5, 0), (95, 68, 46))
        needles = []
        for layer, width in enumerate((8.5, 6.9, 5.3, 3.8, 2.2)):
            shift_x = (index - 1) * 0.18 * (layer % 2)
            shift_z = (index - 1) * 0.12 * ((layer + 1) % 2)
            needles.append(ellipse("Needles", (width, 2.4, width),
                                   (shift_x, 5.5 + layer * 1.9, shift_z),
                                   (45, 100, 60) if (index + layer) % 2 == 0 else (38, 88, 52), GRASS))
        add("CommonDecor", f"PineTree_{'ABC'[index]}", [trunk, *needles], 8,
            note="5 elips iğne katmanı")

    bush_positions = (
        ((-0.75, 1.45, 0), (0.75, 1.55, 0.1), (0, 1.8, 1.3)),
        ((-0.9, 1.3, -0.4), (0.7, 1.7, 0.35), (0.1, 1.6, -0.75)),
        ((-0.75, 1.4, 0.2), (0.75, 1.55, -0.15), (0, 1.75, 1.2)),
    )
    for index, name in enumerate(("Bush_A", "Bush_B", "Bush_Berry")):
        parts: list[Piece] = [
            ball("Leaves", (2.6, 2.8, 2.5)[j], p,
                 ((70, 140, 60), (85, 155, 65), (60, 125, 55))[(index + j) % 3], GRASS)
            for j, p in enumerate(bush_positions[index])
        ]
        if name == "Bush_Berry":
            for x, y, z in ((-1.25, 1.7, -0.2), (1.25, 1.75, 0.1),
                            (-0.2, 2.65, 0.7), (0.45, 2.1, -1.0)):
                parts.append(ball("Berry", 0.45, (x, y, z), (220, 60, 70), SMOOTH))
        add("CommonDecor", name, parts, 8, note="Leaves/Berry mevsim adları")

    flowers = (
        ("Yellow", (250, 220, 80)), ("Pink", (240, 120, 160)),
        ("White", (250, 250, 250)), ("Purple", (170, 120, 230)),
        ("Orange", (245, 140, 60)),
    )
    for name, color in flowers:
        parts = []
        for index in range(7):
            angle = (index - 1) * math.tau / 6
            x_radius = 0 if index == 0 else 2.05
            z_radius = 0 if index == 0 else 1.75
            x, z = math.sin(angle) * x_radius, math.cos(angle) * z_radius
            height = 0.7 + (index % 4) * 0.1
            parts.append(Piece("Stem", (0.12, height, 0.12),
                               (x, height / 2, z), (70, 130, 60), GRASS))
            parts.append(ball("Bloom", 0.45, (x, height, z), color))
        add("CommonDecor", f"FlowerPatch_{name}", parts, 14, note="7 Stem + 7 Bloom")

    for size, suffix in ((1.6, "16"), (2.0, "20"), (2.4, "24")):
        parts = [Piece("Box", (size, size, size), (0, size / 2, 0), (170, 125, 75), PLANKS)]
        for y in (size * 0.3, size * 0.7):
            parts.append(Piece("Slat", (size, 0.2, 0.2), (0, y, -size / 2 - 0.05),
                               (170, 125, 75), PLANKS))
        add("CommonDecor", f"Crate_{suffix}", parts, 4, note=f"kenar {size:g} stud")

    grass_colors = ((88, 152, 64), (104, 168, 70), (72, 136, 58), (126, 176, 78))
    for index, name in enumerate(("GrassTuft", "GrassTuft_Flower")):
        parts = [
            Piece("Tuft", (0.14, 1, 1.2), (0, 0.5, 0), grass_colors[index * 2], GRASS),
            Piece("Tuft", (0.14, 1, 1.2), (0, 0.5, 0), grass_colors[index * 2 + 1],
                  GRASS, angles=(0, math.pi / 2, 0)),
        ]
        if index:
            parts.extend((
                Piece("Stem", (0.1, 0.65, 0.1), (0.5, 0.325, 0), (70, 130, 60), GRASS),
                ball("Bloom", 0.35, (0.5, 0.75, 0), (250, 220, 80)),
            ))
        add("CommonDecor", name, parts, 4, note="iki çapraz Tuft" + (" + çiçek" if index else ""))


def hub_models() -> None:
    add("HubModels", "HubTitleBoard", [
        Piece("Pole", (1, 18, 1), (0, 9, 0), (80, 60, 40), WOOD, collide=True),
        Piece("Title", (20, 6, 1), (0, 16, -0.5), (150, 45, 40), WOOD),
    ], 12, note="Title düz; kod yazı ekler")
    add("HubModels", "HubTravelBoard", [
        Piece("TravelPost", (0.45, 4, 0.45), (-2.5, 2, 0), (110, 80, 50), WOOD, collide=True),
        Piece("TravelPost", (0.45, 4, 0.45), (2.5, 2, 0), (110, 80, 50), WOOD, collide=True),
        Piece("TravelBoard", (6, 2.4, 0.4), (0, 4.5, 0), (150, 110, 70), PLANKS),
    ], 12, note="TravelBoard yazı yüzeyi")
    add("HubModels", "HubPlayerBoard", [
        Piece("PlayerPost", (0.55, 8, 0.55), (-7.6, 4, 0), (95, 65, 40), WOOD, collide=True),
        Piece("PlayerPost", (0.55, 8, 0.55), (7.6, 4, 0), (95, 65, 40), WOOD, collide=True),
        Piece("PlayerBoard", (16, 7.5, 0.4), (0, 7.5, 0), (60, 42, 30), PLANKS),
        Piece("FrameTop", (16.4, 0.3, 0.5), (0, 11.4, 0), (120, 88, 54), WOOD),
        Piece("FrameBottom", (16.4, 0.3, 0.5), (0, 3.6, 0), (120, 88, 54), WOOD),
    ], 12, note="PlayerBoard çarpışmaz")


def extras() -> None:
    for index, name in enumerate(("Rock_A", "Rock_B", "Rock_C")):
        scale = (1.0, 1.25, 0.85)[index]
        offsets = (
            ((-0.55, 0.1), (0.6, 0.25), (0.1, -0.6)),
            ((-0.7, -0.3), (0.65, 0.35), (0.2, 0.75)),
            ((-0.35, 0.55), (0.75, -0.2), (-0.6, -0.5)),
        )[index]
        parts = []
        for j, (x, z) in enumerate(offsets):
            height = (1.7, 1.3, 1.1)[j] * scale
            parts.append(Piece("Tint", ((1.7, 1.4, 1.25)[j] * scale, height,
                                         (1.5, 1.2, 1.1)[j] * scale),
                               (x * scale, height / 2, z * scale),
                               ((115, 116, 120), (100, 104, 108), (128, 128, 130))[j],
                               SLATE, angles=(0, (j - 1) * 0.24, 0)))
        add("CommonDecor", name, parts, 12, note="kara kayası")

    for index, name in enumerate(("Stump_A", "Stump_B")):
        height = 1.5 + index * 0.45
        diameter = 1.55 + index * 0.35
        parts = [
            vertical_cylinder("Trunk", diameter, height, (0, height / 2, 0),
                              (120, 82, 48), WOOD),
            vertical_cylinder("CutFace", diameter * 0.94, 0.12, (0, height + 0.04, 0),
                              (178, 137, 86), PLANKS),
            Piece("Root", (0.7, 0.3, 0.5), (0.6, 0.15, 0.2),
                  (110, 75, 45), WOOD, angles=(0, 0.4, 0)),
        ]
        add("CommonDecor", name, parts, 12, note="kesilmiş ağaç kütüğü")

    logs = []
    for x, y, z, length in ((-0.65, 0.45, 0, 2.8), (0.65, 0.45, 0.1, 2.7), (0, 1.25, 0.05, 2.6)):
        logs.append(Piece("Log", (length, 0.9, 0.9), (x, y, z),
                          (125, 84, 52), WOOD, shape=2))
    add("CommonDecor", "LogPile", logs, 12, note="3 yatay silindir")

    for index, name in enumerate(("Reed_A", "Reed_B")):
        reeds = []
        for stem in range(5):
            x = (stem - 2) * 0.35 + (index * 0.1 if stem % 2 else 0)
            z = ((stem * 3 + index) % 4 - 1.5) * 0.22
            height = 1.6 + ((stem + index) % 3) * 0.4
            reeds.append(Piece("Tint", (0.12, height, 0.12), (x, height / 2, z),
                               (72, 132, 74), GRASS, angles=(0, 0, (stem - 2) * 0.06)))
            reeds.append(Piece("Leaf", (0.65, 0.08, 0.18),
                               (x + (0.25 if stem % 2 else -0.25), height * 0.65, z),
                               (88, 150, 76), GRASS, angles=(0, 0, (stem % 2) * 0.2)))
        add("CommonDecor", name, reeds, 12, note="kıyı sazlığı")

    cattails = []
    for j in range(4):
        x, z = ((-0.55, -0.2), (-0.18, 0.35), (0.3, -0.35), (0.65, 0.25))[j]
        height = 2.1 + j * 0.18
        cattails.append(Piece("Tint", (0.12, height, 0.12), (x, height / 2, z),
                               (65, 125, 64), GRASS))
        cattails.append(ellipse("Head", (0.32, 0.85, 0.32), (x, height - 0.25, z),
                                (100, 70, 43), FABRIC))
    add("CommonDecor", "Cattail", cattails, 12, note="4 saz başağı")

    for index, name in enumerate(("PalmTree_A", "PalmTree_B")):
        palm = []
        for section in range(4):
            y = section * 2.2 + 1.1
            x = (index * 2 - 1) * section * 0.15
            palm.append(Piece("Trunk", (0.75 - section * 0.08, 2.25, 0.75 - section * 0.08),
                              (x, y, 0), (135, 97, 55), WOOD,
                              angles=(0, 0, (index * 2 - 1) * 0.07)))
        crown_x = (index * 2 - 1) * 0.45
        for leaf in range(6):
            angle = leaf * math.tau / 6 + index * 0.2
            palm.append(Piece("Leaves", (0.85, 0.18, 5.2),
                              (crown_x + math.sin(angle) * 2.0, 9.1, -math.cos(angle) * 2.0),
                              (55, 132, 70) if leaf % 2 else (70, 150, 78), GRASS,
                              angles=(-0.18, angle, 0)))
        add("CommonDecor", name, palm, 12, note="4 gövde + 6 palmiye yaprağı")

    for index, name in enumerate(("BirchTree_A", "BirchTree_B")):
        birch = [vertical_cylinder("Trunk", 1.1, 9.5, (0, 4.75, 0),
                                   (224, 219, 201), WOOD)]
        for stripe in range(3):
            birch.append(Piece("BarkMark", (0.12, 0.25, 0.45),
                               ((-0.05 if stripe % 2 else 0.05), 2.1 + stripe * 2.25, -0.54),
                               (55, 54, 49), WOOD))
        for leaf in range(4):
            angle = leaf * math.tau / 4 + index * 0.25
            birch.append(ball("Leaves", 3.6 + (leaf % 2) * 0.4,
                              (math.sin(angle) * 1.3, 9.8 + (leaf % 2) * 0.55,
                               math.cos(angle) * 1.3),
                              (105, 160, 76) if leaf % 2 else (92, 150, 69), GRASS))
        add("CommonDecor", name, birch, 12, note="beyaz gövde, 4 taç")

    for index, name in enumerate(("Mushroom_A", "Mushroom_B", "Mushroom_C")):
        height = 1.1 + index * 0.2
        width = 1.45 + index * 0.25
        cap_color = ((190, 62, 52), (175, 110, 70), (215, 178, 102))[index]
        mush = [
            vertical_cylinder("Stem", 0.38, height, (0, height / 2, 0),
                              (230, 215, 184), SMOOTH),
            ellipse("Cap", (width, 0.62, width),
                    (0, height + 0.18, 0), cap_color, SMOOTH),
        ]
        for j, (x, z) in enumerate(((-0.3, -0.15), (0.25, 0.1), (0, 0.35))):
            mush.append(ball("Spot", 0.16, (x, height + 0.48, z),
                             (247, 237, 213), SMOOTH))
        add("CommonDecor", name, mush, 12, note="elips mantar şapkası")

    add("CommonDecor", "Pumpkin", [
        ellipse("Tint", (2, 1.65, 2), (0, 0.825, 0), (220, 113, 38), SMOOTH),
        vertical_cylinder("Stem", 0.27, 0.45, (0, 1.83, 0), (75, 113, 50), WOOD),
        Piece("Leaf", (0.65, 0.08, 0.4), (0.4, 1.73, 0), (78, 135, 55), GRASS),
    ], 12, note="turuncu elips kabak")

    sunflower = [
        Piece("Stem", (0.18, 3.2, 0.18), (0, 1.6, 0), (55, 128, 57), GRASS),
        ball("Center", 0.9, (0, 3.3, 0), (95, 65, 36), SMOOTH),
    ]
    for j in range(8):
        a = j * math.tau / 8
        sunflower.append(Piece("Petal", (0.45, 0.12, 1.15),
                               (math.sin(a) * 0.66, 3.3, -math.cos(a) * 0.66),
                               (245, 197, 63), FABRIC, angles=(0, a, 0)))
    add("CommonDecor", "Sunflower_Single", sunflower, 12, note="8 altın taç yaprağı")

    add("ShoreModels", "Pile", [
        vertical_cylinder("Pile", 0.7, 12, (0, 6, 0), (126, 89, 54), WOOD),
    ], 12, note="tek 12 stud kazık; yükseklik yerleşim koduna bağlı")

    snow_caps = {
        "SnowCap_Oak": [(0, 12.2, 0, 6.4, 0.75), (-1.6, 11.4, 0.8, 3.4, 0.55),
                        (1.4, 11.5, -0.7, 3.6, 0.55)],
        "SnowCap_Pine": [(0, 7.0, 0, 7.2, 0.55), (0, 9.0, 0, 5.8, 0.5),
                         (0, 11.0, 0, 4.3, 0.45), (0, 13.0, 0, 2.5, 0.4)],
        "SnowCap_Bush": [(-0.65, 2.5, 0, 2.6, 0.4), (0.65, 2.65, 0.25, 2.6, 0.4),
                         (0, 2.9, -0.4, 2.2, 0.35)],
    }
    for name, caps in snow_caps.items():
        parts = [ellipse("Snow", (width, thick, width),
                         (x, y, z), (245, 247, 250), SNOW)
                 for x, y, z, width, thick in caps]
        add("SeasonModels", name, parts, 12, note="ağaç/çalı üstüne oturan kar")

    snowman = [
        ball("SnowBody", 1.8, (0, 0.9, 0), (245, 247, 250), SNOW),
        ball("SnowBody", 1.4, (0, 2.3, 0), (245, 247, 250), SNOW),
        ball("Head", 1.1, (0, 3.55, 0), (245, 247, 250), SNOW),
        vertical_cylinder("HatBrim", 1.25, 0.15, (0, 4.12, 0), (40, 42, 48), FABRIC),
        vertical_cylinder("HatTop", 0.85, 0.65, (0, 4.51, 0), (40, 42, 48), FABRIC),
        ball("Eye", 0.12, (-0.2, 3.67, -0.5), (25, 25, 28)),
        ball("Eye", 0.12, (0.2, 3.67, -0.5), (25, 25, 28)),
        Piece("Nose", (0.18, 0.18, 0.62), (0, 3.47, -0.75),
              (240, 135, 50), SMOOTH, kind="WedgePart"),
    ]
    add("SeasonModels", "Snowman", snowman, 12, note="8 parçalı kardan adam")

    statue = [
        Piece("Pedestal", (3.8, 1, 3.8), (0, 0.5, 0), (130, 130, 125), STONE, collide=True),
        Piece("Plinth", (2.7, 0.5, 2.7), (0, 1.25, 0), (170, 165, 150), STONE),
        Piece("Torso", (1.3, 2.2, 0.9), (0, 2.6, 0), (160, 155, 145), STONE),
        ball("Head", 0.9, (0, 4.1, 0), (160, 155, 145), STONE),
        Piece("Arm", (0.42, 1.9, 0.45), (-0.95, 2.9, 0), (160, 155, 145),
              STONE, angles=(0, 0, -0.25)),
        Piece("Arm", (0.42, 1.9, 0.45), (0.95, 2.9, 0), (160, 155, 145),
              STONE, angles=(0, 0, 0.25)),
    ]
    add("HubModels", "Hub_Statue", statue, 12, note="meydan heykeli")
    add("HubModels", "Hub_Banner", [
        Piece("Post", (0.4, 8, 0.4), (-3.2, 4, 0), (110, 76, 45), WOOD, collide=True),
        Piece("Post", (0.4, 8, 0.4), (3.2, 4, 0), (110, 76, 45), WOOD, collide=True),
        Piece("Banner", (6.1, 3, 0.18), (0, 6.1, 0), (181, 65, 62), FABRIC),
        Piece("Header", (6.6, 0.25, 0.25), (0, 7.8, 0), (145, 104, 65), WOOD),
    ], 12, note="meydan kumaş flaması")
    add("HubModels", "Hub_Flag", [
        Piece("Pole", (0.35, 9, 0.35), (0, 4.5, 0), (125, 88, 55), WOOD, collide=True),
        Piece("Flag", (3.5, 1.8, 0.12), (1.8, 7.8, 0), (196, 60, 52), FABRIC),
        ball("Finial", 0.48, (0, 9.2, 0), (255, 200, 60), METAL),
    ], 12, note="meydan bayrağı")


def main() -> None:
    client_models()
    common_variants()
    hub_models()
    extras()
    assert len(records) == 62, len(records)
    assert len({record[1] for record in records}) == len(records)
    print(f"{len(records)} models")

if __name__ == "__main__":
    main()
