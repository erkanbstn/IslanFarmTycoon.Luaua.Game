"""Export the dock, fence, and fish walkway modules requested in GPT_ILETISIM."""

from __future__ import annotations

import math

from model_xml import METAL, PLANKS, WOOD, Piece, write_model


def main() -> None:
    results = []

    # Pivot: center of the walkable top face. The source dock has one continuous
    # 6 x .6 plank; a 5-stud module can be repeated along its local Z axis.
    results.append(("ShoreModels/DockDeck_5", write_model(
        "ShoreModels", "DockDeck_5", [
            Piece("Deck", (6, .6, 5), (0, -.3, 0), (125, 90, 60), PLANKS, collide=True),
        ], 8, primary="Deck")))

    # Tip pivot is on the deck surface, at the source code's `tip` position.
    # Barrel reproduces the existing CommonDecor/Barrel dimensions and colors.
    results.append(("ShoreModels/DockTip", write_model(
        "ShoreModels", "DockTip", [
            Piece("Body", (2.6, 2, 2), (-1.8, 1.3, 0), (135, 90, 55), PLANKS,
                  shape=2, collide=True, angles=(0, 0, math.pi / 2)),
            Piece("HoopLower", (.2, 2.1, 2.1), (-1.8, .5, 0), (70, 70, 75), METAL,
                  shape=2, collide=True, angles=(0, 0, math.pi / 2)),
            Piece("HoopUpper", (.2, 2.1, 2.1), (-1.8, 2.1, 0), (70, 70, 75), METAL,
                  shape=2, collide=True, angles=(0, 0, math.pi / 2)),
            Piece("FishingRod", (.15, .15, 6), (1.8, 1.3, -2), (80, 60, 40), WOOD,
                  collide=True, angles=(math.radians(25), 0, 0)),
        ], 8)))

    # Fence modules run from local x=0 to x=4. The starting post belongs to
    # each segment; a corner/end post can close the final 4-stud span.
    results.append(("ZoneBases/ZoneFence_Segment_4", write_model(
        "ZoneBases", "ZoneFence_Segment_4", [
            Piece("Post", (.7, 3.4, .7), (0, 1.7, 0), (120, 85, 55), WOOD, collide=True),
            Piece("RailLower", (4, .45, .3), (2, 1.3, 0), (165, 125, 80), WOOD,
                  collide=True),
            Piece("RailUpper", (4, .45, .3), (2, 2.6, 0), (165, 125, 80), WOOD,
                  collide=True),
        ], 8)))

    results.append(("ZoneBases/ZoneFence_Corner", write_model(
        "ZoneBases", "ZoneFence_Corner", [
            Piece("Post", (.7, 3.4, .7), (0, 1.7, 0), (120, 85, 55), WOOD, collide=True),
        ], 8, primary="Post")))

    # A straight 5-stud deck strip; rotate by 90 degrees for the Z sides.
    # The fishpen's current path width is MapLayout.FISH_WALKWAY_WIDTH = 2.4.
    results.append(("ZoneBases/FishWalkway_Module", write_model(
        "ZoneBases", "FishWalkway_Module", [
            Piece("Deck", (5, .6, 2.4), (0, -.3, 0), (125, 90, 60), PLANKS,
                  collide=True),
        ], 8, primary="Deck")))

    for name, (count, bounds) in results:
        print(f"{name}: {count} parts; bounding box {bounds}")


if __name__ == "__main__":
    main()
