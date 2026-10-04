"""Rebuild the single-part surface and pooled effect templates."""

import math
import xml.etree.ElementTree as ET

from model_xml import ROOT, Piece, write_model, NEON, SMOOTH, WOOD, STONE, SAND

LEAFY_GRASS = 1284


def generate(folder, name, size, color, material, *, cylinder=False,
             ball=False, mesh=False, collide=False, shadow=False, client=False,
             part_name=None):
    piece = Piece(part_name or name, size, (0, 0, 0), color, material=material,
                  shape=2 if cylinder else 0 if ball else 1, mesh_sphere=mesh,
                  collide=collide, transparency=1 if client else 0,
                  angles=(0, 0, math.pi / 2) if cylinder else (0, 0, 0))
    count, bounds = write_model(folder, name, [piece], 1, client=client)
    path = ROOT / ("client-assets" if client else "assets") / folder / f"{name}.rbxmx"
    tree = ET.parse(path)
    props = tree.getroot().find("Item/Item/Properties")
    for tag, key, value in (("bool", "CastShadow", str(shadow).lower()),
                            ("float", "Transparency", "1" if client else "0"),
                            ("token", "TopSurface", "0"),
                            ("token", "BottomSurface", "0")):
        node = props.find(f"{tag}[@name='{key}']")
        if node is None:
            node = ET.SubElement(props, tag, name=key)
        node.text = value
    ET.indent(tree, space="  ")
    tree.write(path, encoding="utf-8")
    print(f"{folder}/{name}: {count} part, bounds={bounds}")


def main():
    for name, size, color, material, cylinder, collide, shadow, part_name in (
        ("GroundDisc", (4, 16, 16), (92, 174, 76), LEAFY_GRASS, True, True, True, "Ground"),
        ("GroundBlock", (16, 1, 16), (92, 174, 76), LEAFY_GRASS, False, True, True, "Ground"),
        ("StonePath", (4, .16, 8), (150, 145, 135), STONE, False, True, False, "Path"),
        ("GrassPatch", (.05, 10, 10), (92, 174, 76), LEAFY_GRASS, True, False, False, "Patch"),
        ("BeachDisc", (5, 16, 16), (226, 208, 158), SAND, True, True, True, "Beach"),
    ):
        generate("SurfaceModels", name, size, color, material, cylinder=cylinder,
                 collide=collide, shadow=shadow, part_name=part_name)
    for name, size, color, material, ball, mesh in (
        ("Spark", (.22, .22, .22), (153, 96, 11), NEON, True, False),
        ("Dust", (1, 1, 1), (214, 200, 176), SMOOTH, True, False),
        ("NightHalo", (1, 1, 1), (255, 214, 130), NEON, True, False),
        ("SeasonFragment", (.22, .04, .42), (255, 255, 255), SMOOTH, False, True),
        ("WinterTwig", (4, 1.2, 2), (163, 162, 165), WOOD, False, False),
        ("LightningSegment", (4, 1.2, 2), (224, 237, 255), NEON, False, False),
    ):
        generate("Effects", name, size, color, material, ball=ball, mesh=mesh, client=True)


if __name__ == "__main__":
    main()
