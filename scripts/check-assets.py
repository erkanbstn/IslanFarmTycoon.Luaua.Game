#!/usr/bin/env python3
"""Hazır model (assets/**/*.rbxmx) kapsam denetimi: kodun beklediği her görünüm için asset var mı?

Görünen geometri hazır modellerden gelir; eksik asset = o görünüm çizilmez.
Ayrıca XML sağlığı (ad, yasak sınıf, PrimaryPart, parça sayısı) ve
koda hiç bağlanmamış asset klasörleri raporlanır. Beklenmeyen fazla .rbxmx (orphan) hata sayılır.

Kullanım: python scripts/check-assets.py [--strict-unwired]
Çıkış kodu 1: eksik/bozuk asset var. İzinli boşluklar ALLOWED_MISSING içinde, gerekçesiyle.
"""
from __future__ import annotations

import re
import math
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "src"
ASSETS = ROOT / "assets"

# Bilinçli olarak asset'siz kalanlar (kodda kalacak): gerekçe zorunlu.
ALLOWED_MISSING: dict[str, str] = {}
# Koda bağlanmamış (harita kurucuları) klasörler: bilgi amaçlı, hata sayılmaz.
UNWIRED_FOLDERS: set[str] = set()
FORBIDDEN_CLASSES = {
    "Script", "LocalScript", "ModuleScript", "ProximityPrompt", "SurfaceGui", "BillboardGui", "SpotLight", "SurfaceLight", "MeshPart",
}
MAX_PARTS_BUILDING = 35
# Üretim yapmayan (tabelasız) binalar; diğer bütün binalarda SignBoard + 2 SignPost zorunlu.
NO_SIGN_BUILDINGS = {"silo", "milk_machine", "auto_collector", "egg_factory", "golden_horseshoe", "fishing_boat"}


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8-sig")


def top_level_keys(path: Path) -> set[str]:
    """Bir tablo dosyasında bir sekme girintili `anahtar = function(` satırları."""
    return set(re.findall(r"^\t(\w+) = function\(", read(path), re.M))


def required_match(pattern: str, source: str, label: str, flags: int = 0) -> re.Match[str]:
    match = re.search(pattern, source, flags)
    if match is None:
        raise ValueError(f"beklenen model kapsamı okunamadı: {label}")
    return match


def expected() -> dict[str, set[str]]:
    exp: dict[str, set[str]] = {}

    # Hayvanlar: elle yazılan (Config/Animals ANIMAL_ORDER) + tür tablosundan türeyenler (Config/Species satırları)
    animals_cfg = read(SRC / "shared/Config/Animals.luau")
    order = required_match(r"ANIMAL_ORDER = \{([^}]*)\}", animals_cfg, "ANIMAL_ORDER")
    animals = set(re.findall(r'"(\w+)"', order.group(1)))
    animals |= set(re.findall(r'id = "(\w+)",\s*slot =', read(SRC / "shared/Config/Species.luau")))
    # Çiftlik temalarının balık görünümleri (Config/Islands THEMES[n].fish: id = model dosyası)
    animals |= set(re.findall(r'\{ id = "(\w+)", displayName = "[^"]*", icon = "[^"]*", product = "[^"]*" \}', read(SRC / "shared/Config/Islands.luau")))
    exp["Animals"] = animals

    # Binalar: üretim tarifleri (Production.luau + Species fabrikası/merkezi) + üretimsiz binalar
    production = read(SRC / "shared/Config/Production.luau")
    species_cfg = read(SRC / "shared/Config/Species.luau")
    exp["Buildings"] = (
        set(re.findall(r'upgradeId = "(\w+)"', production))
        | set(re.findall(r'factory = "(\w+)"', species_cfg))
        | set(re.findall(r'building = "(\w+)"', species_cfg))
        | {"silo", "milk_machine", "auto_collector", "egg_factory", "golden_horseshoe"}
    )

    # Irk kozmetiği: her hayvan görünümü x T2-T4 aksesuar (AnimalLineage/<modelId>_T<N>; yalnız yeni parçalar, PrimaryPart yok)
    exp["AnimalLineage"] = {f"{a}_T{i}" for a in exp["Animals"] for i in (2, 3, 4)}

    # Bina seviyeleri: üretim tesisleri (silo/süt makinesi/otomatik toplayıcı/yumurta fabrikası/tekne hariç) x Sv.1-5 (BuildingLevels/<id>_Lv<N>)
    leveled = exp["Buildings"] - {"silo", "milk_machine", "auto_collector", "egg_factory", "golden_horseshoe", "fishing_boat"}
    exp["BuildingLevels"] = {f"{b}_Lv{i}" for b in leveled for i in range(1, 6)}

    # Bölge dekoru: ana adada tema eki (starter/pasture x 6 çiftlik teması), elle yazılan bölgeler + tür tablosundaki her bölge (<tür>_pen)
    themes = int(required_match(r"MAIN_FARM_LIMIT = (\d+)", read(SRC / "shared/Config/Core.luau"), "MAIN_FARM_LIMIT").group(1))
    decor = {f"Decor_{z}_T{i}" for z in ("starter", "pasture") for i in range(1, themes + 1)}
    decor |= {f"Decor_{z}" for z in ("stable", "goatpen", "sheepfold", "pigpen", "poultry", "pond", "fishpen")}
    for animal, _slot, body in re.findall(r'id = "(\w+)",\s*slot = "(\w+)"(.*?)\n\t\},', species_cfg, re.S):
        if "zone = {" in body:
            decor.add(f"Decor_{animal}_pen")
    exp["ZoneDecor"] = decor

    exp["Barns"] = {f"Barn_Lv{i}" for i in range(1, 5)}
    exp["Collectors"] = {f"CollectorPile_Lv{i}" for i in range(1, 6)}
    exp["ZoneFlags"] = {f"ZoneFlag_{k}" for k in ("growth", "income", "season", "capacity")}
    exp["ZoneLevels"] = {f"ZoneLevel_{s}_Lv{i}" for s in ("30x24", "30x26") for i in range(1, 6)}

    cfg = "".join(read(p) for p in (SRC / "shared/Config").glob("*.luau"))

    def levels(chain: str) -> int:
        """Seviye zinciri (Config LEVEL_CHAINS): costs listesinin uzunluğu = seviye sayısı."""
        match = required_match(r'id = "' + chain + r'",.*?costs = \{([^}]*)\}', cfg, chain, re.S)
        return len([c for c in match.group(1).split(",") if c.strip()])

    exp["LevelProps"] = (
        {f"FeedStation_Lv{i}" for i in range(1, levels("feed_quality") + 1)}
        | {f"GrowthBeacon_Lv{i}" for i in range(1, levels("fast_growth") + 1)}
        | {f"StorageYard_Lv{i}" for i in range(1, levels("storage_expansion") + 1)}
    )
    exp["Lineage"] = {f"LineageMonument_Lv{i}" for i in range(1, 11)}
    exp["FacilityProps"] = (
        {"BuildSite_Unbuilt", "BuyPad"}
        | {f"FacilityProps_Lv{i}" for i in range(1, 6)}
        | {f"FacilityRings_Lv{i}" for i in range(1, 6)}
    )

    # Yardımcılar: ana ada köpek (para) + kedi (ürün), deniz kurbağası, her ada kendi türü (iki görev)
    lp = read(SRC / "server/Presentation/UpgradeLevelProps.luau")
    block = required_match(r"PET_SPECIES: \{[^}]*\} = \{(.*?)\n\}", lp, "PET_SPECIES", re.S)
    species = set(re.findall(r"^\t(\w+) = \"(\w+)\"", block.group(1), re.M))
    pets = {"Pet_dog_cash", "Pet_cat_goods", "Pet_frog_cash", "Pet_frog_goods"}
    for _island, spec in species:
        pets |= {f"Pet_{spec}_cash", f"Pet_{spec}_goods"}
    exp["Pets"] = pets

    # Dükkân eşyaları (karakterde görünen model): Config/Items.luau'daki her eşya kimliği
    items_src = read(SRC / "shared/Config/Items.luau")
    exp["Items"] = set(re.findall(r'id = "(\w+)"', items_src))

    # Eklentiler ve üretim zeminleri (IslandLayout)
    layout = read(SRC / "server/World/IslandLayout.luau")
    ext_block = layout[layout.index("IslandLayout.EXTENSIONS"): layout.index("IslandLayout.SITES")]
    ext_ids = set(re.findall(r"^\t(\w+) = \{", ext_block, re.M))
    exp["Extensions"] = ext_ids | {"MilkLoadingDecor"}
    exp["ExtensionCapacity"] = {f"CapacityProps_{e}_Cap{c}" for e in ext_ids for c in (3, 4)}
    sites_block = layout[layout.index("IslandLayout.SITES"):]
    exp["ProductionSites"] = {f"ProductionSite_{s}" for s in re.findall(r"^\t(\w+) = \{", sites_block, re.M)}

    # Harita/meydan/süs modelleri: kodda adla yerleştirilenler (World/Home*, HubNpcs, DecorNature/Props/Lights/Shore, MapParts, SatelliteBuilder...)
    exp["HomeModels"] = {
        "Beehives", "Farmhouse", "Granary", "MarketStall", "Orchard", "VegetableGarden", "Well", "Windmill",
    } | {f"Landmark_{kind}" for kind in ("cherry", "daisy", "pine", "rose", "sunflower", "tulip")}
    exp["HubProps"] = {"Bench", "Fountain", "Planter_seed2", "SpawnPlaza"} | {f"Vendor_{a}" for a in ("orders", "roadmap", "store", "travel")}
    exp["HubModels"] = {"HubTitleBoard", "HubTravelBoard", "HubPlayerBoard", "Hub_Statue", "Hub_Banner"}
    exp["BridgeModels"] = {"BridgeModule_2", "BridgeModule_8"}
    exp["SignModels"] = {"IslandSign", "PlotSign", "SaleMarker", "Signpost_Direction", "SpecialtySign"}
    exp["ShoreModels"] = {"DockDeck_5", "DockTip", "FishCrates", "FisherHut_Lv1", "NetDryingRack", "Pile"}
    exp["ZoneBases"] = {"CollectorPad", "FishWalkway_Module", "ZoneFence_Corner", "ZoneFence_Segment_4"}
    exp["SeasonModels"] = {"SnowCap_Bush", "SnowCap_Oak", "SnowCap_Pine", "Snowman", "IceFloe"}
    exp["SurfaceModels"] = {"GroundDisc", "GroundBlock", "StonePath", "GrassPatch", "BeachDisc"}
    exp["CommonDecor"] = (
        {f"OakTree_{c}" for c in "ABCD"}
        | {f"PineTree_{c}" for c in "ABC"}
        | {f"BirchTree_{c}" for c in "AB"}
        | {"Bush_A", "Bush_B", "Bush_Berry"}
        | {f"FlowerPatch_{c}" for c in ("Yellow", "Pink", "White", "Purple", "Orange")}
        | {"Crate_16", "Crate_20", "Crate_24", "Barrel", "Lamp", "SmallLamp", "Mailbox", "Fence_8", "HayBale_Single", "HayBale_Stack"}
        | {"Scarecrow", "Wheelbarrow", "GrassTuft", "GrassTuft_Flower", "LogPile", "Pumpkin", "Sunflower_Single", "Cattail"}
        | {f"Rock_{c}" for c in "ABC"}
        | {"Stump_A", "Stump_B", "Reed_A", "Reed_B", "PalmTree_A", "PalmTree_B"}
        | {f"Mushroom_{c}" for c in "ABC"}
    )
    return exp


# İstemci efekt modelleri (client-assets/<klasör>/<ad>): kodda ClientModelAssets ile klonlanır.
CLIENT_EXPECTED: dict[str, set[str]] = {
    "Effects": {"Spark", "Dust", "NightHalo", "SeasonFragment", "WinterTwig", "LightningSegment"},
    "Birds": {"Gull", "Songbird"},
    "Fish": {"ReefFish", "ShoreFish_A", "ShoreFish_B"},
    "Sea": {
        "BranchCoral", "BrainCoral", "FanCoral", "SeaRock_A", "SeaRock_B", "SeaRock_C", "Starfish", "Jellyfish",
        "KelpBlade_A", "KelpBlade_B", "KelpBlade_C", "Seagrass_A", "Seagrass_B", "Seagrass_C", "SeaAnemone",
        "ShellCluster", "Bubble", "SurfaceWake", "BoatFoam", "AmbientBubbles", "VentBubbles", "EntryBubbles",
        "SwimBubbles", "Splash", "UnderwaterAtmosphere", "DiverChest", "ReefArch",
    },
    "PetProps": {"CarryAnimal", "CarryCrate", "CarryCoins"},
    "Season": {"SeasonGlow_Good", "SeasonGlow_Bad"},
    "Coin": {"Coin_Small", "Coin_Stack", "CoinBurst_Chunk"},
}


# Kullanıcı kararıyla gerçek ışık taşıyan tek istemci dip modelleri (devamlı açık küçük PointLight): her modelde tam bir tane.
LIGHT_MODELS = {("Sea", "DiverChest"), ("Sea", "ReefArch"), ("Sea", "SeaAnemone")}


def orphan_models(exp: dict[str, set[str]], assets: Path | None = None, client_root: Path | None = None) -> list[str]:
    """Beklenen listede olmayan fazla .rbxmx dosyaları (bilinmeyen klasör dahil), kök göreli yollarla."""
    assets = assets or ASSETS
    client_root = client_root or ROOT / "client-assets"
    found: list[str] = []
    for base, expected_by_folder in ((assets, exp), (client_root, CLIENT_EXPECTED)):
        if not base.is_dir():
            continue
        for path in sorted(base.glob("*/*.rbxmx")):
            if path.stem not in expected_by_folder.get(path.parent.name, set()):
                found.append(f"{base.name}/{path.parent.name}/{path.name}")
        for path in sorted(base.rglob("*.rbxmx")):
            if path.parent.parent != base:
                found.append(f"{base.name}/{path.relative_to(base).as_posix()}")
    return found


def numeric_components(element: ET.Element | None, keys: str | tuple[str, ...]) -> list[float] | None:
    """Eksik, bozuk ve sonlu olmayan XML sayıları taramayı kesmeden reddet."""
    if element is None:
        return None
    try:
        values = [float(element.findtext(key)) for key in keys]
    except (TypeError, ValueError):
        return None
    return values if all(math.isfinite(value) for value in values) else None


CFRAME_COMPONENTS = ("X", "Y", "Z", "R00", "R01", "R02", "R10", "R11", "R12", "R20", "R21", "R22")


def moving_contract_problems(model: ET.Element, folder: str, name: str) -> list[str]:
    required: dict[str, str] = {}
    if folder == "Birds":
        required = {"Body": "Part", "LeftWing": "Part", "RightWing": "Part"}
    elif folder == "Fish":
        required = {"Body": "Part", "Tail": "WedgePart"}
    elif folder == "Sea" and name == "Jellyfish":
        required = {"JellyBell": "Part"}
    elif folder == "Sea" and name.startswith("KelpBlade_"):
        required = {"Lower": "Model", "Upper": "Model"}
    problems = []
    for part_name, cls in required.items():
        matches = [item for item in model.findall("Item")
                   if item.findtext("Properties/string[@name='Name']") == part_name]
        if len(matches) != 1 or matches[0].get("class") != cls:
            problems.append(f"hareketli model: doğrudan çocuk olarak tam bir {cls} {part_name} gerekir")
    return problems


def light_problems(model: ET.Element, allowed: bool) -> list[str]:
    problems: list[str] = []
    lights = []
    for part in model.iter("Item"):
        for child in part.findall("Item"):
            if child.get("class") == "PointLight":
                lights.append((part, child))
    if not lights:
        return [] if not allowed else ["bu modelde bir PointLight olmalı"]
    if not allowed:
        return ["PointLight yalnızca LIGHT_MODELS'teki dip modellerinde olabilir"]
    if len(lights) != 1:
        problems.append(f"tam bir PointLight olmalı ({len(lights)} var)")
    for part, light in lights:
        if part.get("class") not in ("Part", "WedgePart"):
            problems.append("PointLight bir BasePart çocuğu olmalı")
        shadows = light.find("Properties/bool[@name='Shadows']")
        if shadows is not None and shadows.text == "true":
            problems.append("PointLight Shadows=false olmalı")
        for name, limit in (("Brightness", 2.5), ("Range", 16)):
            value = light.find(f"Properties/float[@name='{name}']")
            try:
                number = float(value.text) if value is not None else None
            except (TypeError, ValueError):
                number = None
            if number is None or not math.isfinite(number) or not 0 <= number <= limit:
                problems.append(f"PointLight {name} sonlu ve 0..{limit} aralığında olmalı")
    return problems


def inspect(path: Path, folder: str) -> list[str]:
    problems: list[str] = []
    try:
        root = ET.parse(path).getroot()
    except ET.ParseError as error:
        return [f"XML okunamadı: {error}"]
    if root.tag != "roblox" or root.get("version") != "4":
        problems.append("kök roblox version=4 olmalı")
    if len(root.findall("Item")) != 1:
        problems.append("dosyada tam bir üst düzey Model olmalı")
    model = root.find("Item")
    if model is None or model.get("class") != "Model":
        return ["kök öğe Model değil"]
    name = model.find("Properties/string[@name='Name']")
    if name is None or name.text != path.stem:
        problems.append(f"model adı dosya adıyla uyuşmuyor ({name.text if name is not None else '?'})")
    if numeric_components(model.find("Properties/OptionalCoordinateFrame[@name='WorldPivotData']/CFrame"), CFRAME_COMPONENTS) is None:
        problems.append("WorldPivotData (pivot) eksik veya geçersiz")
    items = list(model.iter("Item"))
    referents = [item.get("referent") for item in items if item.get("referent")]
    if len(referents) != len(set(referents)):
        problems.append("yinelenen referent kimliği")
    primary = model.findtext("Properties/Ref[@name='PrimaryPart']")
    if primary not in (None, "null"):
        targets = [item for item in items if item.get("referent") == primary]
        if len(targets) != 1 or targets[0].get("class") not in ("Part", "WedgePart"):
            problems.append("PrimaryPart model içindeki geçerli bir BasePart'a bağlanmalı")
        elif folder in ("Birds", "Fish") or (folder == "Sea" and path.stem == "Jellyfish"):
            expected_primary = "JellyBell" if folder == "Sea" else "Body"
            if targets[0].findtext("Properties/string[@name='Name']") != expected_primary:
                problems.append(f"PrimaryPart {expected_primary} olmalı (animasyon pivotu)")
    if folder in ("Animals", "Pets", "Birds", "Fish") or (folder == "Sea" and path.stem == "Jellyfish"):
        if primary in (None, "null"):
            problems.append("PrimaryPart yok veya null")
    problems.extend(moving_contract_problems(model, folder, path.stem))
    problems.extend(light_problems(model, (folder, path.stem) in LIGHT_MODELS))
    parts = 0
    for item in model.iter("Item"):
        cls = item.get("class")
        if cls in FORBIDDEN_CLASSES:
            problems.append(f"yasak sınıf: {cls}")
        if cls in ("Part", "WedgePart", "MeshPart"):
            parts += 1
            dims = numeric_components(item.find("Properties/Vector3[@name='Size']"), "XYZ")
            if dims is None or min(dims) <= 0:
                problems.append("parça Size eksik, sonlu değil veya pozitif değil")
            if numeric_components(item.find("Properties/CoordinateFrame[@name='CFrame']"), CFRAME_COMPONENTS) is None:
                problems.append("parça CFrame eksik veya geçersiz")
        if cls == "Part":
            shape = item.find("Properties/token[@name='Shape']")
            size = item.find("Properties/Vector3[@name='Size']")
            if shape is not None and shape.text == "0" and size is not None:
                dims = numeric_components(size, "XYZ")
                if dims is not None and max(dims) - min(dims) > 0.011:
                    problems.append(f"eşit olmayan Ball ({dims}); elips için Block + SpecialMesh Sphere kullan")
        if cls == "SpecialMesh":
            mesh = item.find("Properties/token[@name='MeshType']")
            if mesh is None or mesh.text != "3":
                problems.append("SpecialMesh yalnızca MeshType=3 (Sphere) olabilir; mesh dosyası (FileMesh/MeshPart) yasak")
    if parts == 0:
        problems.append("hiç parça yok")
    sign_parts = sum(
        1 for n in model.findall("Item/Properties/string[@name='Name']") if n.text in ("SignBoard", "SignPost")
    )
    if folder == "Buildings" and parts - sign_parts > MAX_PARTS_BUILDING:
        problems.append(f"{parts - sign_parts} parça (bina bütçesi {MAX_PARTS_BUILDING}; tabela parçaları sayılmaz)")
    if folder == "Buildings" and path.stem not in NO_SIGN_BUILDINGS:
        names = [n.text for n in model.findall("Item/Properties/string[@name='Name']")]
        if names.count("SignBoard") != 1 or names.count("SignPost") != 2:
            problems.append("tabela eksik: 1 SignBoard + 2 SignPost gerekir")
    if folder == "FacilityProps" and path.stem in ("BuyPad", "BuildSite_Unbuilt"):
        problems.extend(facility_contract_problems(model, path.stem))
    if folder in ("Buildings", "BuildingLevels") or (folder == "Animals" and path.stem == "peacock"):
        problems.extend(surface_join_problems(model, path.stem))
    return problems


def surface_join_problems(model: ET.Element, name: str) -> list[str]:
    """Visible window corners and fan layers must not share/intersect their surface planes."""
    rows = []
    for item in model.iter("Item"):
        props = item.find("Properties")
        if props is None:
            continue
        size = numeric_components(props.find("Vector3[@name='Size']"), "XYZ")
        frame = numeric_components(props.find("CoordinateFrame[@name='CFrame']"), CFRAME_COMPONENTS)
        label = props.find("string[@name='Name']")
        if size and frame and label is not None:
            rows.append((label.text, size, frame))
    problems = []
    walls = [r for r in rows if r[0] in ("WallLeft", "WallRight")]
    for jamb in [r for r in rows if r[0] == "WindowJamb"]:
        for wall in walls:
            # These factory models use axis-aligned wall/jamb parts.
            if any(abs(r[2][i]) > 1e-6 for r in (jamb, wall) for i in (4, 5, 6, 8, 9, 10)):
                continue
            overlap = [min(r[2][i] + r[1][i] / 2 for r in (jamb, wall))
                       - max(r[2][i] - r[1][i] / 2 for r in (jamb, wall)) for i in range(3)]
            if min(overlap) > 1e-5:
                problems.append("WindowJamb yan duvarla köşede iç içe geçiyor")
    if name == "peacock":
        feathers = [r for r in rows if r[0] == "Feather"]
        if feathers:
            normal = [feathers[0][2][5], feathers[0][2][8], feathers[0][2][11]]
            layers = sorted((sum(r[2][i] * normal[i] for i in range(3)), r[1][2]) for r in feathers)
            for left, right in zip(layers, layers[1:]):
                if right[0] - left[0] < (left[1] + right[1]) / 2 + 0.005:
                    problems.append("tavus kuşu kuyruk katmanları kesişiyor")
                    break
    return problems


def facility_contract_problems(model: ET.Element, name: str) -> list[str]:
    """Kodun parça adıyla bulduğu satın alma/yapım alanı geometrisini koru."""
    problems: list[str] = []
    pivot = model.find("Properties/OptionalCoordinateFrame[@name='WorldPivotData']/CFrame")
    if pivot is not None:
        identity = {"X": 0, "Y": 0, "Z": 0, "R00": 1, "R01": 0, "R02": 0,
                    "R10": 0, "R11": 1, "R12": 0, "R20": 0, "R21": 0, "R22": 1}
        values = numeric_components(pivot, tuple(identity))
        if values is None or any(abs(actual - expected) > 0.0001
                                 for actual, expected in zip(values, identity.values())):
            problems.append("zemin pivotu sıfır ve dönüşü birim olmalı")
    primary = model.find("Properties/Ref[@name='PrimaryPart']")
    if primary is not None and primary.text not in (None, "null"):
        problems.append("PrimaryPart olmamalı (zemin pivotu kullanılır)")
    children = model.findall("Item")
    required = ("Pad", "Ring", "Inner", "Coin") if name == "BuyPad" else ("SignPole", "SiteSign")
    for part_name in required:
        matches = [item for item in children
                   if item.findtext("Properties/string[@name='Name']") == part_name]
        if len(matches) != 1 or matches[0].get("class") != "Part":
            problems.append(f"doğrudan çocuk olarak tam bir Part {part_name} gerekir")
    if name == "BuyPad":
        parts = [item for item in model.iter("Item") if item.get("class") in ("Part", "WedgePart")]
        if len(parts) > 14:
            problems.append(f"BuyPad bütçesi <=14 parça ({len(parts)} var)")
        for item in parts:
            part_name = item.findtext("Properties/string[@name='Name']")
            for flag in ("CanCollide", "CanQuery", "CanTouch"):
                if item.findtext(f"Properties/bool[@name='{flag}']") != "false":
                    problems.append(f"{part_name}: {flag}=false olmalı")
        for item in children:
            part_name = item.findtext("Properties/string[@name='Name']")
            if part_name in required and item.findtext("Properties/token[@name='Shape']") != "2":
                problems.append(f"{part_name}: Cylinder (Shape=2) olmalı")
    else:
        for item in children:
            part_name = item.findtext("Properties/string[@name='Name']")
            if part_name in required:
                expected_flag = "true" if part_name == "SignPole" else "false"
                if item.findtext("Properties/bool[@name='CanCollide']") != expected_flag:
                    problems.append(f"{part_name}: CanCollide={expected_flag} olmalı")
    return problems


def main() -> int:
    strict_unwired = "--strict-unwired" in sys.argv
    try:
        exp = expected()
    except (ValueError, OSError) as error:
        print(f"HATA: {error}")
        return 1
    failed = False
    total_expected = total_missing = 0
    for folder in sorted(exp):
        have = {p.stem for p in (ASSETS / folder).glob("*.rbxmx")} if (ASSETS / folder).is_dir() else set()
        need = exp[folder]
        missing = sorted(need - have)
        extra = sorted(have - need)
        total_expected += len(need)
        real_missing = [m for m in missing if f"{folder}/{m}" not in ALLOWED_MISSING]
        allowed = [m for m in missing if f"{folder}/{m}" in ALLOWED_MISSING]
        total_missing += len(real_missing)
        status = "OK" if not real_missing else "EKSİK"
        print(f"{status:6} {folder:18} beklenen {len(need):3} hazır {len(need & have):3}")
        for m in real_missing:
            print(f"         - eksik: {m}")
            failed = True
        for m in allowed:
            print(f"         ~ izinli boşluk: {m} ({ALLOWED_MISSING[f'{folder}/{m}']})")
        for m in extra:
            print(f"         ? koda karşılığı bulunamayan asset: {m}")
    client_root = ROOT / "client-assets"
    for folder, need in sorted(CLIENT_EXPECTED.items()):
        have = {p.stem for p in (client_root / folder).glob("*.rbxmx")} if (client_root / folder).is_dir() else set()
        missing = sorted(need - have)
        total_expected += len(need)
        total_missing += len(missing)
        print(f"{'OK' if not missing else 'EKSİK':6} client/{folder:12} beklenen {len(need):3} hazır {len(need & have):3}")
        for m in missing:
            print(f"         - eksik: {m}")
            failed = True
        for m in sorted(have - need):
            print(f"         ? koda karşılığı bulunamayan asset: {m}")
    orphans = orphan_models(exp)
    for orphan in orphans:
        print(f"FAZLA  {orphan}: kodun hiçbir yolla yüklemediği model (sil veya beklenen listeye bağla)")
        failed = True
    print()
    bad = 0
    for path in sorted(list(ASSETS.glob("*/*.rbxmx")) + list((ROOT / "client-assets").glob("*/*.rbxmx"))):
        for problem in inspect(path, path.parent.name):
            print(f"BOZUK  {path.relative_to(ROOT).as_posix()}: {problem}")
            bad += 1
    if bad:
        failed = True
    unwired = [d for d in sorted(UNWIRED_FOLDERS) if (ASSETS / d).is_dir()]
    if unwired:
        counts = ", ".join(f"{d} ({len(list((ASSETS / d).glob('*.rbxmx')))})" for d in unwired)
        print(f"BAĞLANMAMIŞ klasörler (haritayı kuran kod okumuyor): {counts}")
        if strict_unwired:
            failed = True
    print(f"\nÖzet: {total_expected} beklenen görünüm, {total_missing} eksik, {bad} bozuk dosya, {len(orphans)} fazla model.")
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
