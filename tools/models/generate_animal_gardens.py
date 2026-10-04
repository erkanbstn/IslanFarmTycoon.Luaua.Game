"""Rebuild specialist animal gardens. Run: python tools/models/generate_animal_gardens.py."""

from model_xml import Piece, write_model, PLANKS, GRASS, SAND, WOOD, FABRIC

SPECIES = {
    "rabbit": "burrow", "bee": "flowers", "camel": "oasis", "peacock": "flowers",
    "quail": "nest", "pigeon": "perch", "snail": "leaves", "llama": "pasture",
    "deer": "pasture", "falcon": "perch", "silkworm": "leaves", "parrot": "perch",
    "tortoise": "oasis",
}


def at(name, size, xyz, color, material=WOOD, collide=False):
    # Island surface is the pivot. Walkable area x=-29 +/-9, z=+/-14 is flat and clear.
    return Piece(name, size, (xyz[0] - 29, xyz[1], xyz[2]), color, material, collide=collide)


def garden(kind):
    pale = (173, 201, 128) if kind not in ("oasis", "burrow") else (224, 201, 143)
    parts = [at("GardenPad", (20, .08, 32), (0, .04, 0), pale, SAND if kind == "oasis" else GRASS)]
    for x in (-10, 10):
        for z in (-15, 0, 15):
            parts.append(at("Post", (.4, 2.8, .4), (x, 1.4, z), (124, 92, 65), collide=True))
        for y in (.9, 1.9):
            parts.append(at("TrainingRail", (.25, .22, 30), (x, y, 0), (170, 132, 85), collide=True))
    for y in (.9, 1.9):
        parts.append(at("TrainingRail", (20, .22, .25), (0, y, 15), (170, 132, 85), collide=True))
    # Props are behind the animal area, not within its initial spawn cells or motion paths.
    if kind in ("burrow", "nest"):
        for x in (-5, 5):
            parts.extend([
                at("HutBack", (4, 2.4, .3), (x, 1.2, 19), (155, 107, 69), PLANKS),
                at("HutSide", (.3, 2.4, 3.5), (x - 2, 1.2, 17.5), (155, 107, 69), PLANKS),
                at("HutSide", (.3, 2.4, 3.5), (x + 2, 1.2, 17.5), (155, 107, 69), PLANKS),
                at("ShelterRoof", (4.6, .4, 4.3), (x, 2.7, 17.5), (89, 139, 119)),
            ])
    elif kind == "perch":
        for x in (-5, 5):
            parts.extend([
                at("Post", (.45, 4, .45), (x, 2, 18), (115, 85, 62), collide=True),
                at("PerchRail", (4, .4, .4), (x, 4, 18), (175, 128, 76)),
            ])
    elif kind in ("flowers", "leaves"):
        for x in (-6, 0, 6):
            parts.extend([
                at("Planter", (3.5, .65, 2.5), (x, .325, 18), (159, 109, 67), PLANKS),
                at("Leaves", (3, .8, 2), (x, 1.05, 18), (81, 158, 97)),
            ])
            if kind == "flowers":
                parts.append(at("Bloom", (.8, .45, .8), (x, 1.6, 18), (247, 178, 97)))
    else:
        parts.extend([
            at("WaterTrough", (5, .8, 2), (-4, .4, 18), (104, 147, 165)),
            at("HayBale", (3, 1.5, 2.5), (4, .75, 18), (225, 193, 104)),
        ])
    return parts


def capacity(level):
    parts = [at("WaterTrough", (3, .8, 2), (0, .4, 21), (104, 147, 165))]
    if level == 4:
        for x in (-7, 7):
            for z in (16, 22):
                parts.append(at("ShelterPost", (.4, 4.4, .4), (x, 2.2, z), (124, 92, 65), collide=True))
        parts.append(at("ShelterRoof", (15, .4, 7), (0, 4.6, 19), (89, 139, 119), FABRIC))
    return parts


if __name__ == "__main__":
    for species, kind in SPECIES.items():
        name = f"{species}_garden"
        count, bounds = write_model("Extensions", name, garden(kind), 35)
        print(f"{name}: {count} parts, bounds {bounds}, pivot=surface origin")
        for level in (3, 4):
            write_model("ExtensionCapacity", f"CapacityProps_{name}_Cap{level}", capacity(level), 10)
