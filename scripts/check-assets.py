#!/usr/bin/env python3
"""Hazır model (assets/**/*.rbxmx) kapsam denetimi: kodun beklediği her görünüm için asset var mı?

Kod kurucuları yedek olarak duruyor (asset yoksa onlar çizer). Yedek kodu silmeden önce bu betik yeşil olmalı:
eksik asset = kod silinince o görünüm kaybolur. Ayrıca XML sağlığı (ad, yasak sınıf, PrimaryPart, parça sayısı) ve
koda hiç bağlanmamış asset klasörleri raporlanır.

Kullanım: python scripts/check-assets.py [--strict-unwired]
Çıkış kodu 1: eksik/bozuk asset var. İzinli boşluklar ALLOWED_MISSING içinde, gerekçesiyle.
"""
from __future__ import annotations

import re
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
    "Script", "LocalScript", "ModuleScript", "ProximityPrompt", "SurfaceGui", "BillboardGui", "SpotLight", "MeshPart",
}
MAX_PARTS_BUILDING = 35
# Üretim yapmayan (tabelasız) binalar; diğer bütün binalarda SignBoard + 2 SignPost zorunlu.
NO_SIGN_BUILDINGS = {"silo", "milk_machine", "auto_collector", "egg_factory", "golden_horseshoe", "fishing_boat"}


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8-sig")


def top_level_keys(path: Path) -> set[str]:
    """Bir tablo dosyasında bir sekme girintili `anahtar = function(` satırları."""
    return set(re.findall(r"^\t(\w+) = function\(", read(path), re.M))


def expected() -> dict[str, set[str]]:
    exp: dict[str, set[str]] = {}

    # Hayvanlar: elle yazılan (Config/Animals ANIMAL_ORDER) + tür tablosundan türeyenler (Config/Species satırları)
    animals_cfg = read(SRC / "shared/Config/Animals.luau")
    order = re.search(r"ANIMAL_ORDER = \{([^}]*)\}", animals_cfg)
    animals = set(re.findall(r'"(\w+)"', order.group(1))) if order else set()
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

    # Bina seviyeleri: üretim tesisleri (silo/süt makinesi/otomatik toplayıcı/yumurta fabrikası/tekne hariç) x Sv.1-5 (BuildingLevels/<id>_Lv<N>)
    leveled = exp["Buildings"] - {"silo", "milk_machine", "auto_collector", "egg_factory", "golden_horseshoe", "fishing_boat"}
    exp["BuildingLevels"] = {f"{b}_Lv{i}" for b in leveled for i in range(1, 6)}

    # Bölge dekoru: ana adada tema eki (starter/pasture x 6 çiftlik teması), elle yazılan bölgeler + tür tablosundaki her bölge (<tür>_pen)
    themes = int(re.search(r"MAIN_FARM_LIMIT = (\d+)", read(SRC / "shared/Config/Core.luau")).group(1))
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
        match = re.search(r'id = "' + chain + r'",.*?costs = \{([^}]*)\}', cfg, re.S)
        return len([c for c in match.group(1).split(",") if c.strip()]) if match else 0

    exp["LevelProps"] = (
        {f"FeedStation_Lv{i}" for i in range(1, levels("feed_quality") + 1)}
        | {f"GrowthBeacon_Lv{i}" for i in range(1, levels("fast_growth") + 1)}
        | {f"StorageYard_Lv{i}" for i in range(1, levels("storage_expansion") + 1)}
    )
    exp["Lineage"] = {f"LineageMonument_Lv{i}" for i in range(1, 11)}
    exp["FacilityProps"] = (
        {"BuildSite_Unbuilt"}
        | {f"FacilityProps_Lv{i}" for i in range(1, 6)}
        | {f"FacilityRings_Lv{i}" for i in range(1, 6)}
    )

    # Yardımcılar: ana ada köpek (para) + kedi (ürün), deniz kurbağası, her ada kendi türü (iki görev)
    lp = read(SRC / "server/Presentation/UpgradeLevelProps.luau")
    block = re.search(r"PET_SPECIES: \{[^}]*\} = \{(.*?)\n\}", lp, re.S)
    species = set(re.findall(r"^\t(\w+) = \"(\w+)\"", block.group(1), re.M)) if block else set()
    pets = {"Pet_dog_cash", "Pet_cat_goods", "Pet_frog_cash", "Pet_frog_goods"}
    for _island, spec in species:
        pets |= {f"Pet_{spec}_cash", f"Pet_{spec}_goods"}
    exp["Pets"] = pets

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
    exp["SeasonModels"] = {"SnowCap_Bush", "SnowCap_Oak", "SnowCap_Pine", "Snowman"}
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
    "Birds": {"Gull", "Songbird"},
    "Fish": {"ReefFish", "ShoreFish_A", "ShoreFish_B"},
    "Sea": {
        "BranchCoral", "BrainCoral", "FanCoral", "SeaRock_A", "SeaRock_B", "SeaRock_C", "Starfish", "Jellyfish",
        "KelpBlade_A", "KelpBlade_B", "KelpBlade_C", "Seagrass_A", "Seagrass_B", "Seagrass_C", "SeaAnemone",
        "ShellCluster", "Bubble", "SurfaceWake", "BoatFoam", "AmbientBubbles", "VentBubbles", "EntryBubbles",
        "SwimBubbles", "Splash", "UnderwaterAtmosphere", "DiverChest", "ReefArch",
    },
    "PetProps": {"CarryAnimal", "CarryCrate", "CarryCoins"},
}


# Kullanıcı kararıyla gerçek ışık taşıyan tek istemci dip modelleri (devamlı açık küçük PointLight): her modelde tam bir tane.
LIGHT_MODELS = {("Sea", "DiverChest"), ("Sea", "ReefArch"), ("Sea", "SeaAnemone")}


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
            if value is not None and float(value.text) > limit:
                problems.append(f"PointLight {name} <= {limit} olmalı")
    return problems


def inspect(path: Path, folder: str) -> list[str]:
    problems: list[str] = []
    try:
        root = ET.parse(path).getroot()
    except ET.ParseError as error:
        return [f"XML okunamadı: {error}"]
    model = root.find("Item")
    if model is None or model.get("class") != "Model":
        return ["kök öğe Model değil"]
    name = model.find("Properties/string[@name='Name']")
    if name is None or name.text != path.stem:
        problems.append(f"model adı dosya adıyla uyuşmuyor ({name.text if name is not None else '?'})")
    if model.find("Properties/OptionalCoordinateFrame[@name='WorldPivotData']") is None:
        problems.append("WorldPivotData (pivot) yok")
    problems.extend(light_problems(model, (folder, path.stem) in LIGHT_MODELS))
    parts = 0
    for item in model.iter("Item"):
        cls = item.get("class")
        if cls in FORBIDDEN_CLASSES:
            problems.append(f"yasak sınıf: {cls}")
        if cls in ("Part", "WedgePart", "MeshPart"):
            parts += 1
        if cls == "Part":
            shape = item.find("Properties/token[@name='Shape']")
            size = item.find("Properties/Vector3[@name='Size']")
            if shape is not None and shape.text == "0" and size is not None:
                dims = [float(size.find(c).text) for c in "XYZ"]
                if max(dims) - min(dims) > 0.011:
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
    if folder in ("Animals", "Pets") and model.find("Properties/Ref[@name='PrimaryPart']") is None:
        problems.append("PrimaryPart yok")
    return problems


def main() -> int:
    strict_unwired = "--strict-unwired" in sys.argv
    exp = expected()
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
    print(f"\nÖzet: {total_expected} beklenen görünüm, {total_missing} eksik, {bad} bozuk dosya.")
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
