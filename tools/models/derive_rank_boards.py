"""Derive the two global ranking boards from the server ranking board model (same geometry, new part names).

HubBoardService looks the writable surface up by part name: RebirthBoard / FarmBoard (PlayerBoard stays the server board).
Idempotent: python tools/models/derive_rank_boards.py
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets" / "HubModels" / "HubPlayerBoard.rbxmx"
VARIANTS = (
    ("HubRebirthBoard", "RebirthBoard", "RebirthPost"),
    ("HubFarmBoard", "FarmBoard", "FarmPost"),
)


def main() -> None:
    text = SOURCE.read_text(encoding="utf-8")
    for model, board, post in VARIANTS:
        derived = (
            text.replace("HubPlayerBoard", model)
            .replace("PlayerBoard", board)
            .replace("PlayerPost", post)
        )
        target = SOURCE.with_name(f"{model}.rbxmx")
        if not target.exists() or target.read_text(encoding="utf-8") != derived:
            target.write_text(derived, encoding="utf-8", newline="\n")
            print(f"wrote {target.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
