"""Derive five new character-attachment item models from existing ones (same contract, new look).

Each target keeps its base's geometry contract (WorldPivotData, Attach attribute, Part/WedgePart only, part count,
part names the code and docs expect). Only the model name, part colours/materials and a few safe sizes change.
Idempotent: python tools/models/derive_new_item_models.py
"""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ITEMS = ROOT / "assets" / "Items"
BLOCK = re.compile(r'(<Item class="(?:Part|WedgePart)" referent="[^"]*">.*?</Item>)', re.S)
NAME = re.compile(r'<string name="Name">([\w-]+)</string>')
SMOOTH, WOOD, FABRIC, METAL = 272, 512, 1312, 1088


def _color(block: str, rgb: tuple[int, int, int]) -> str:
    r, g, b = (repr(v / 255) for v in rgb)
    return re.sub(
        r'(<Color3 name="Color">\s*<R>)[^<]*(</R>\s*<G>)[^<]*(</G>\s*<B>)[^<]*(</B>)',
        lambda m: f"{m[1]}{r}{m[2]}{g}{m[3]}{b}{m[4]}",
        block,
    )


def _material(block: str, material: int) -> str:
    return re.sub(r'(<token name="Material">)\d+(</token>)', lambda m: f"{m[1]}{material}{m[2]}", block)


def _stretch(block: str, size_y: float, pos_y: float) -> str:
    block = re.sub(
        r'(<Vector3 name="Size">\s*<X>[^<]*</X>\s*<Y>)[^<]*(</Y>)',
        lambda m: f"{m[1]}{size_y:.8f}{m[2]}",
        block,
        count=1,
    )
    return re.sub(
        r'(<CoordinateFrame name="CFrame">\s*<X>[^<]*</X>\s*<Y>)[^<]*(</Y>)',
        lambda m: f"{m[1]}{pos_y:.8f}{m[2]}",
        block,
        count=1,
    )


def _get(block: str, pattern: str) -> float:
    return float(re.search(pattern, block).group(1))


def _lift(block: str, delta: float) -> str:
    y = _get(block, r'<CoordinateFrame name="CFrame">\s*<X>[^<]*</X>\s*<Y>([^<]*)</Y>')
    size_y = _get(block, r'<Vector3 name="Size">\s*<X>[^<]*</X>\s*<Y>([^<]*)</Y>')
    return _stretch(block, size_y, y + delta)


def _tall_crown(block: str, name: str) -> str:
    """Tycoon hat: taller crown walls (bottom stays at the brim), crease and top follow."""
    if name.startswith("HollowCrown"):
        size_y = _get(block, r'<Vector3 name="Size">\s*<X>[^<]*</X>\s*<Y>([^<]*)</Y>')
        y = _get(block, r'<CoordinateFrame name="CFrame">\s*<X>[^<]*</X>\s*<Y>([^<]*)</Y>')
        bottom = y - size_y / 2
        new = 1.45
        return _stretch(block, new, bottom + new / 2)
    if name == "CreasedCrownTop":
        return _lift(block, 0.5)
    return block


# model -> (base, {part name or #index: (rgb, material|None)}, optional geometry hook)
GOLD = (226, 180, 65)
VARIANTS = {
    "foreman_mallet": (
        "iron_hammer",
        {
            "#0": ((140, 92, 52), WOOD),  # warm wood handle
            "GripBand1": ((184, 134, 58), METAL),  # brass bands
            "GripBand2": ((184, 134, 58), METAL),
            "GripBand3": ((184, 134, 58), METAL),
            "ButtCap": ((196, 146, 64), METAL),
            "Head": ((58, 62, 70), METAL),  # dark iron head
            "SteelStrikeFace": ((92, 98, 108), METAL),
            "ForgedClaw-1": ((46, 50, 58), METAL),
            "EyePlate": ((196, 146, 64), METAL),
        },
        None,
    ),
    "fortune_charm": (
        "income_charm_3",
        {
            "#0": ((70, 34, 112), METAL),  # deep purple medallion
            "SunFace": ((104, 58, 160), METAL),
            "SunRay": (GOLD, METAL),
            "SunHeart": ((255, 226, 120), SMOOTH),
        },
        None,
    ),
    "tycoon_crown": (
        "merchant_hat",
        {
            "#0": ((24, 78, 48), FABRIC),  # dark green brims / crown
            "RearBrim": ((24, 78, 48), FABRIC),
            "CurledBrim": ((24, 78, 48), FABRIC),
            "HollowCrownFront": ((28, 90, 56), FABRIC),
            "HollowCrownBack": ((28, 90, 56), FABRIC),
            "HollowCrownLeft": ((28, 90, 56), FABRIC),
            "HollowCrownRight": ((28, 90, 56), FABRIC),
            "RibbonFront": (GOLD, METAL),  # gold band
            "RibbonBack": (GOLD, METAL),
            "RibbonLeft": (GOLD, METAL),
            "RibbonRight": (GOLD, METAL),
            "CreasedCrownTop": ((20, 66, 40), FABRIC),
            "RibbonBuckle": ((250, 224, 120), METAL),
        },
        _tall_crown,
    ),
    "caravan_satchel": (
        "backpack",
        {
            "#0": ((196, 160, 112), FABRIC),  # tan leather body
            "RoundedLid": ((178, 142, 96), FABRIC),
            "FrontPocket": ((214, 178, 126), FABRIC),
            "PocketFlap": ((170, 130, 86), FABRIC),
            "ShoulderStrap": ((122, 86, 54), FABRIC),
            "SidePouch": ((168, 130, 88), FABRIC),
            "LeatherFastener": ((110, 72, 42), FABRIC),
            "Buckle": ((176, 112, 52), METAL),  # bronze
            "HandleLeg": ((176, 112, 52), METAL),
            "CarryHandle": ((122, 86, 54), FABRIC),
        },
        None,
    ),
    "eternal_shepherd_staff": (
        "season_staff_inf",
        {
            "#0": ((58, 38, 26), WOOD),  # dark wood rod
            "GripWrap1": ((34, 56, 38), FABRIC),
            "GripWrap2": ((34, 56, 38), FABRIC),
            "GripWrap3": ((34, 56, 38), FABRIC),
            "LowerCollar": ((46, 88, 58), METAL),
            "UpperCollar": ((46, 88, 58), METAL),
            "Heel": ((46, 88, 58), METAL),
            "HeadSeat": ((46, 88, 58), METAL),
            "HeadStem": ((46, 88, 58), METAL),
            "SeasonHeart": ((84, 236, 130), SMOOTH),  # green crystal
            "SeasonBranch0": ((46, 88, 58), METAL),
            "SeasonBranch1": ((46, 88, 58), METAL),
            "SeasonBranch2": ((46, 88, 58), METAL),
            "SeasonBranch3": ((46, 88, 58), METAL),
            "SeasonGem0": ((70, 214, 118), SMOOTH),
            "SeasonGem1": ((120, 242, 156), SMOOTH),
            "SeasonGem2": ((40, 170, 96), SMOOTH),
            "SeasonGem3": ((170, 255, 200), SMOOTH),
            "EternalRoot": ((206, 244, 206), METAL),
        },
        None,
    ),
}


def derive(model: str, base: str, colors: dict, hook) -> str:
    text = (ITEMS / f"{base}.rbxmx").read_text(encoding="utf-8")
    text = text.replace(f'<string name="Name">{base}</string>', f'<string name="Name">{model}</string>', 1)
    index = 0

    def edit(match: re.Match) -> str:
        nonlocal index
        block = match[1]
        name = NAME.search(block)[1]
        spec = colors.get(name) or (colors.get("#0") if index == 0 else None)
        index += 1
        if spec:
            block = _color(block, spec[0])
            if spec[1] is not None:
                block = _material(block, spec[1])
        return hook(block, name) if hook else block

    return BLOCK.sub(edit, text)


def main() -> None:
    for model, (base, colors, hook) in VARIANTS.items():
        derived = derive(model, base, colors, hook)
        target = ITEMS / f"{model}.rbxmx"
        if not target.exists() or target.read_text(encoding="utf-8") != derived:
            target.write_text(derived, encoding="utf-8", newline="\n")
            print(f"wrote {target.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
