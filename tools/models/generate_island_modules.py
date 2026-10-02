"""Export the remaining fixed IslandBuilder visuals without game behavior."""

from __future__ import annotations

import math

from model_xml import METAL, NEON, PLANKS, WOOD, Piece, write_model


def main() -> None:
    # Source: IslandBuilder.luau, signCf = islandCf * (0, SURFACE_Y+16, -56).
    # Local pivot is at island surface between the two 18-stud posts.
    sign = [
        Piece("PlotSign", (9, 2.8, .5), (0, 16, 0), (85, 60, 40), PLANKS),
        Piece("SignFrame", (9.4, .3, .7), (0, 14.45, 0), (140, 100, 60), WOOD,
              collide=True),
        Piece("SignFrame", (9.4, .3, .7), (0, 17.55, 0), (140, 100, 60), WOOD,
              collide=True),
        Piece("SignPost", (.7, 18, .7), (-5.4, 9, 0), (140, 100, 60), WOOD,
              collide=True),
        Piece("SignPost", (.7, 18, .7), (5.4, 9, 0), (140, 100, 60), WOOD,
              collide=True),
    ]
    n, bounds = write_model("SignModels", "PlotSign", sign, 8)
    print(f"SignModels/PlotSign: {n} parts; bounding box {bounds}")

    # CollectorPad is visual only; the top-face sign, billboard, and interaction
    # remain the loader's responsibility. Source rotates Collector 180° about Y.
    pad = [
        Piece("CollectorRim", (7.4, .5, 7.4), (0, .25, 0),
              (230, 180, 50), METAL, collide=True),
        Piece("Collector", (6, .3, 6), (0, .6, 0),
              (60, 220, 90), NEON, collide=True, angles=(0, math.pi, 0)),
    ]
    n, bounds = write_model("ZoneBases", "CollectorPad", pad, 8)
    print(f"ZoneBases/CollectorPad: {n} parts; bounding box {bounds}")


if __name__ == "__main__":
    main()
