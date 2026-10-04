#!/usr/bin/env python3
"""Run pure Luau regression specs against the real project source.

Only module-loading declarations are substituted. Config values and all production
functions are copied verbatim, so the harness cannot silently test a Python port.
Roblox instance/world tests remain in the isolated test.project.json Studio place.
"""

from __future__ import annotations

import argparse
import importlib.util
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys


ROOT = Path(__file__).resolve().parents[1]
# Tek ya da çok satırlı (stylua ile bölünmüş) `local X = require(...)`; iç içe parantez üç düzeye kadar eşleşir.
REQUIRE_LINE = re.compile(
    r"^local (\w+) =\s+require\((?:[^()]|\((?:[^()]|\([^()]*\))*\))*\)\r?$", re.MULTILINE
)


def type_only_dependencies(source: str, dependencies: set[str]) -> list[str]:
    """Recognize imports used only in Luau type declarations/annotations."""
    result = []
    for dependency in sorted(dependencies):
        occurrences = []
        for line in source.splitlines():
            code = line.split("--", 1)[0]
            for match in re.finditer(rf"\b{re.escape(dependency)}\b", code):
                prefix = code[:match.start()]
                annotation = bool(
                    re.match(r"\s*(?:export\s+)?type\b", prefix)
                    or re.search(r"::\s*[\w\[\]{}:,.?|<> ]*$", prefix)
                    or re.match(r"\s*(?:local\s+)?function\s+[\w.:]+\([^)]*$", prefix)
                    or (re.match(r"\s*(?:local\s+)?function\s+[\w.:]+\(.*\)\s*:[^=]*$", prefix) and not re.search(r"\breturn\b", prefix))
                    or re.match(r"\s*\)\s*:\s*[\w\[\]{}:,.?|<> ]*$", prefix)
                    or re.match(r"\s*local\s+\w+\s*:[^=]*$", prefix)
                    or re.match(r"\s*\w+\s*:\s*[\w\[\]{}:,.?|<> ]*$", prefix)
                )
                occurrences.append(annotation)
        if occurrences and all(occurrences):
            result.append(dependency)
    return result


def module(name: str, path: str, dependencies: set[str] | None = None, factory_args: str = "") -> str:
    source = (ROOT / path).read_text(encoding="utf-8-sig")
    expected = dependencies or set()
    found: set[str] = set()

    def inject(match: re.Match[str]) -> str:
        dependency = match.group(1)
        if dependency not in expected:
            raise ValueError(f"Unexpected dependency {dependency!r} in {path}; update the harness explicitly")
        found.add(dependency)
        return f"-- Injected dependency: {dependency} (outer production module)."

    source = REQUIRE_LINE.sub(inject, source)
    if found != expected:
        raise ValueError(f"Dependency mismatch in {path}: expected {expected}, found {found}")
    if re.search(r"\brequire\s*\(", source):
        raise ValueError(f"Unresolved require in {path}; the runner only substitutes complete require lines")
    metadata = "-- Harness module: " + json.dumps({"name": name, "path": path, "dependencies": sorted(expected), "factory_args": factory_args, "type_only_dependencies": type_only_dependencies(source, expected)}) + "\n"
    finish = f"\n-- Harness endmodule: {name}\n"
    if factory_args:
        return metadata + f"-- Source: {path}\nlocal {name} = function({factory_args})\n{source}\nend\n" + finish
    return metadata + f"-- Source: {path}\nlocal {name} = (function()\n{source}\nend)()\n" + finish


CONFIG_PARTS = [
    "Types", "Species", "Core", "Weather", "Economy", "Difficulty", "Shop", "Achievements", "Audio", "Goods", "Islands", "Upgrades", "Production",
    "Animals", "Items", "Progression",
]


def config_bundle(freeze: bool = True) -> str:
    """`src/shared/Config/` klasörünü tek `Config` yerel değişkeni olarak birleştirir.

    Parçalar kendi kapsamında yüklenir; init.luau parça adlarını dışarıdan enjekte edilmiş sayar.
    """
    parts = ""
    for name in CONFIG_PARTS:
        path = f"src/shared/Config/{name}.luau"
        # Tip kullanan parçalar `Types`'ı dışarıdan enjekte edilmiş sayar.
        text = (ROOT / path).read_text(encoding="utf-8-sig")
        deps = {dep for dep in ("Types", "Species") if f"local {dep} = require(" in text}
        parts += module(name, path, deps or None)
    init = module("ConfigInit", "src/shared/Config/init.luau", set(CONFIG_PARTS))
    if not freeze:
        init = init.replace("return table.freeze(Config)", "return Config")
    return "".join(["-- Harness scope: Config\nlocal Config = (function()\n", parts, init, "\nreturn ConfigInit\nend)()\n-- Harness endscope: Config\n"])


FARM_MATH_PARTS = ["Format", "Core", "Goods", "Recipes", "Counts", "Pricing", "Islands", "Lineage", "Expansion", "Production", "Income", "Contracts", "Animals"]


def _declared_dependencies(path: str) -> set[str]:
    text = (ROOT / path).read_text(encoding="utf-8-sig")
    return set(re.findall(r"^local (\w+) =\s+require\(", text, re.MULTILINE))


def farm_math_bundle() -> str:
    """`src/shared/Modules/FarmMath/` klasörünü tek `FarmMath` yerel değişkeni olarak birleştirir.

    Parçalar yalnızca Config/GameTypes/Environment ve kendilerinden önceki parçalara bağlanır.
    """
    parts = ""
    for name in FARM_MATH_PARTS:
        path = f"src/shared/Modules/FarmMath/{name}.luau"
        parts += module(name, path, _declared_dependencies(path))
    init = module("FarmMathInit", "src/shared/Modules/FarmMath/init.luau", set(FARM_MATH_PARTS))
    return "".join(["-- Harness scope: FarmMath\nlocal FarmMath = (function()\n", parts, init, "\nreturn FarmMathInit\nend)()\n-- Harness endscope: FarmMath\n"])


SAVE_CODEC_PARTS = ["Common", "Goods", "Tasks", "Inventory", "Production", "Animals", "Account", "Financial", "Farm"]


def save_codec_bundle() -> str:
    """`src/server/Modules/SaveCodec/` klasörünü tek `SaveCodec` yerel değişkeni olarak birleştirir.

    Parçalar SessionLock/Preferences'ı dışarıdan, kendilerinden önceki parçaları sırayla alır; init FarmProfiles'ı dışarıdan alır.
    """
    parts = ""
    for name in SAVE_CODEC_PARTS:
        path = f"src/server/Modules/SaveCodec/{name}.luau"
        parts += module(name, path, _declared_dependencies(path))
    init = module(
        "SaveCodecInit",
        "src/server/Modules/SaveCodec/init.luau",
        _declared_dependencies("src/server/Modules/SaveCodec/init.luau"),
    )
    return "".join(["-- Harness scope: SaveCodec\nlocal SaveCodec = (function()\n", parts, init, "\nreturn SaveCodecInit\nend)()\n-- Harness endscope: SaveCodec\n"])


SPEC_CALL = re.compile(r"^(\w+Spec)\(")
MODULE_META = re.compile(r"^-- Harness module: (\{.*\})$", re.MULTILINE)


def normalize_spec(value: str) -> str:
    """'hud-layout', 'hud-layout.spec.luau', 'tests/hud-layout.spec.luau' and 'hudLayoutSpec' -> 'hudlayout'."""
    stem = value.replace("\\", "/").rsplit("/", 1)[-1].lower()
    stem = re.sub(r"\.spec\.luau$|\.luau$", "", stem)
    stem = re.sub(r"[^a-z0-9]", "", stem)
    return stem[:-4] if stem.endswith("spec") and len(stem) > 4 else stem


def spec_catalog(pieces: list[str]) -> dict[str, set[str]]:
    """Invocation name (e.g. 'hudLayoutSpec') -> accepted --only aliases (from the real module() metadata)."""
    catalog: dict[str, set[str]] = {}
    for piece in pieces:
        match = MODULE_META.match(piece)
        if not match:
            continue
        meta = json.loads(match.group(1))
        if meta["name"].endswith("Spec") and meta["path"].startswith("tests/"):
            catalog[meta["name"]] = {normalize_spec(meta["name"]), normalize_spec(meta["path"])}
    return catalog


def select_specs(pieces: list[str], only: list[str]) -> tuple[list[str], list[str]]:
    """Drop invocations of unselected specs; module definitions stay (cheap, keeps load order). Returns (pieces, unknown)."""
    catalog = spec_catalog(pieces)
    wanted = {normalize_spec(item) for entry in only for item in entry.split(",") if item.strip()}
    known = set().union(*catalog.values()) if catalog else set()
    unknown = sorted(name for name in wanted if name not in known)
    chosen = {name for name, aliases in catalog.items() if aliases & wanted}
    kept = []
    for piece in pieces:
        call = SPEC_CALL.match(piece)
        if call and call.group(1) not in chosen:
            continue
        kept.append(piece)
    return kept, unknown


def main(argv: list[str] | None = None, dependency_reporter=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--luau", help="Path to the standalone Luau interpreter (not Lua)")
    parser.add_argument("--check-dependencies", action="store_true", help="Check actual harness imports and lexical module order without running Luau or writing generated files")
    parser.add_argument("--only", action="append", default=[], metavar="SPEC", help="Run only these specs (repeatable or comma separated; e.g. --only hud-layout,admin). Subset result is not the full suite")
    parser.add_argument("--list", action="store_true", help="List spec names accepted by --only and exit (no Luau needed)")
    args = parser.parse_args(argv)
    executable = args.luau or shutil.which("luau")
    if executable is None:
        bundled = ROOT / ".tools" / "luau" / ("luau.exe" if sys.platform == "win32" else "luau")
        if bundled.is_file():
            executable = str(bundled)
    if executable is None and not args.check_dependencies and not args.list:
        parser.error("Luau interpreter missing. Install Luau 0.740 or provide --luau PATH.")

    pieces = [
        "--!nocheck\n-- Generated by scripts/run-tests.py; do not edit.\n",
        "-- Config uses colors as data only; no production color behavior is simulated.\n",
        "local Color3 = { fromRGB = function(r, g, b) return { R = r / 255, G = g / 255, B = b / 255 } end }\n",
        config_bundle(),
        module("GameTypes", "src/shared/GameTypes.luau"),
        "-- Pure economy specs replace this multiplier to check weather independence.\n",
        "local Environment = { getIncomeMultiplier = function() return 1 end }\n",
        farm_math_bundle(),
        module("Progression", "src/shared/Modules/Progression.luau", {"Config", "FarmMath"}),
        module("EffectSummary", "src/shared/Modules/EffectSummary.luau", {"Config", "FarmMath", "Progression", "GameTypes"}),
        module("effectSummarySpec", "tests/effect-summary.spec.luau"),
        module("EffectsSectionFactory", "src/client/Ui/Hud/EffectsSection.luau",
               {"Config", "GameTypes", "EffectSummary", "FarmMath", "Environment", "UiKit", "ItemText"},
               "game, Config, EffectSummary, FarmMath, Environment, UiKit, ItemText"),
        module("effectsSectionSpec", "tests/effects-section.spec.luau"),
        module("StatsPanelFactory", "src/client/Ui/Hud/StatsPanel.luau",
               {"Config", "GameTypes", "FarmMath", "IslandContext", "UiKit"},
               "game, UiKit, IslandContext, Instance, UDim2, Vector2, Enum"),
        module("GoalCardFactory", "src/client/Ui/Hud/GoalCard.luau",
               {"Config", "GameTypes", "FarmMath", "Progression", "IslandContext", "UiKit", "HudCommon", "Onboarding", "OnboardingBanner", "OnboardingSteps"},
               "game, UiKit, Instance, UDim2, Enum, HudCommon, IslandContext, Onboarding, OnboardingSteps"),
        module("hudLayoutSpec", "tests/hud-layout.spec.luau"),
        module("BridgeSurface", "src/client/Core/BridgeSurface.luau"),
        module("bridgeSurfaceSpec", "tests/bridge-surface.spec.luau"),
        module("BridgeBoostFactory", "src/client/Interaction/BridgeBoost.client.luau", {"BridgeSurface"},
               "game, BridgeSurface, script, RaycastParams, Enum, Vector3, Instance, os, ColorSequence, Color3, NumberSequence, NumberSequenceKeypoint, warn"),
        module("bridgeBoostSpec", "tests/bridge-boost.spec.luau"),
        module("AnimalAnimatorFactory", "src/client/Effects/AnimalAnimator.client.luau", {"EffectSettings"},
               "game, EffectSettings, Vector3, CFrame, Random, RaycastParams, Enum, typeof, os"),
        module("animalAnimatorSpec", "tests/animal-animator.spec.luau"),
        module("BoardSectionFactory", "src/client/Ui/Hud/BoardSection.luau",
               {"Config", "GameTypes", "FarmMath", "Environment", "UiKit", "PurchaseController"},
               "game, Config, FarmMath, Environment, UiKit, PurchaseController"),
        module("boardUiSpec", "tests/board-ui.spec.luau"),
        module("ClientModelAssetsFactory", "src/client/Core/ClientModelAssets.luau", set(), "game, warn"),
        module("clientModelAssetsSpec", "tests/client-model-assets.spec.luau"),
        module("ModelAssetsFactory", "src/server/World/ModelAssets.luau", {"VisualWorkBudget"}, "game, VisualWorkBudget"),
        module("modelAssetsSpec", "tests/model-assets.spec.luau"),
        module("AnimalModelsFactory", "src/server/Presentation/AnimalModels.luau", {"AssetSanitizer"},
               "game, AssetSanitizer, Color3, warn, Instance, script"),
        module("DecorShoreFactory", "src/server/World/DecorShore.luau", {"ModelAssets"},
               "game, Parts, ModelAssets, warn, Instance, Vector3, CFrame, Color3, Enum, Random, Vector2, script"),
        module("missingModelsSpec", "tests/missing-models.spec.luau"),
        module("ToastsFactory", "src/client/Ui/Kit/Toasts.luau",
               {"Tokens", "Base", "Screen", "EffectSettings"},
               "game, Tokens, Base, Screen, EffectSettings, Instance, UDim2, UDim, Vector2, Enum, task, TweenInfo"),
        module("MerchantBadgeFactory", "src/client/Ui/Hud/MerchantBadge.luau",
               {"GameTypes", "Merchant", "Sfx", "UiKit"},
               "game, Merchant, Sfx, UiKit, Instance, Vector2, UDim2, Enum"),
        module("toastsSpec", "tests/toasts.spec.luau"),
        module("HubBoardServiceFactory", "src/server/Services/HubBoardService.luau",
               {"Config", "FarmMath", "WorldUi", "PlayerDataService"},
               "game, task, Config, FarmMath, WorldUi, PlayerDataService"),
        module("hubBoardSpec", "tests/hub-board.spec.luau"),
        module("RoadmapWindowFactory", "src/client/Ui/Hud/RoadmapWindow.luau",
               {"Config", "Remotes", "GameTypes", "FarmMath", "Progression", "UiKit", "PurchaseController", "IslandContext", "HudCommon", "IslandTabs"},
               "game, UiKit, Instance, UDim2, Vector2, HudCommon, IslandTabs, IslandContext, PurchaseController, Remotes"),
        module("roadmapUiSpec", "tests/roadmap-ui.spec.luau"),
        module("IslandTabsFactory", "src/client/Ui/Hud/IslandTabs.luau",
               {"Config", "GameTypes", "FarmMath", "ClientState", "UiKit", "IslandContext"},
               "game, ClientState, UiKit, IslandContext, Instance, UDim2, Enum, UDim"),
        module("islandTabsSpec", "tests/island-tabs.spec.luau"),
        module("progressionSpec", "tests/progression.spec.luau"),
        module("ControlsFactory", "src/client/Ui/Kit/Controls.luau", {"Sfx", "Tokens", "Base"},
               "game, Sfx, Tokens, Base, Instance, UDim2, Enum, TweenInfo, Vector2"),
        module("uiDisclosureSpec", "tests/ui-disclosure.spec.luau"),
        module("BaseFactory", "src/client/Ui/Kit/Base.luau", {"Tokens"},
               "Tokens, Instance, UDim, UDim2, Enum, ColorSequence, Vector2"),
        module("GridFactory", "src/client/Ui/Kit/Grid.luau", {"Tokens", "Base", "Controls"},
               "Tokens, Base, Controls, Instance, UDim2, UDim, Enum"),
        module("uiKitLayoutSpec", "tests/ui-kit-layout.spec.luau"),
        module("ProductionContextFactory", "src/client/Ui/Hud/ProductionContext.luau", {"Config"}, "game, Config"),
        module("productionContextSpec", "tests/production-context.spec.luau"),
        module("WindowsFactory", "src/client/Ui/Kit/Windows.luau", {"Tokens", "Base", "Controls", "Screen", "Sfx"},
               "game, Tokens, Base, Controls, Screen, Sfx, Instance, UDim2, Vector2, Enum, TweenInfo, NumberSequence, UDim"),
        module("windowsSpec", "tests/windows.spec.luau"),
        module("VisitTargets", "src/client/Ui/Hud/VisitTargets.luau"),
        module("visitTargetsSpec", "tests/visit-targets.spec.luau"),
        module("rebirthJourneySpec", "tests/rebirth-journey.spec.luau"),
        module("PurchaseControllerFactory", "src/client/Core/PurchaseController.luau", {"Remotes", "ClientState", "Sfx"},
               "game, Remotes, ClientState, Sfx, Instance, os, task"),
        module("RebirthWindowFactory", "src/client/Ui/Hud/RebirthWindow.luau", {"Config", "GameTypes", "Progression", "FarmMath", "UiKit", "PurchaseController", "HudCommon", "EffectsSection"},
               "game, Config, Progression, UiKit, PurchaseController, HudCommon, Instance, UDim2, Vector2, Enum, script, FarmMath, EffectsSection"),
        module("progressionUiSpec", "tests/progression-ui.spec.luau"),
        module("WeatherQueuePromptFactory", "src/client/Ui/Hud/WeatherQueuePrompt.luau",
               {"Config", "Remotes", "UiKit", "PurchaseController", "HudCommon"},
               "game, Config, Remotes, UiKit, PurchaseController, HudCommon, Vector2, UDim2, task"),
        module("weatherQueueUiSpec", "tests/weather-queue-ui.spec.luau"),
        module("marketProductsSpec", "tests/market-products.spec.luau"),
        module("ItemTextFactory", "src/client/Ui/Hud/ItemText.luau", {"Config"}, "game, Config"),
        module("itemTextSpec", "tests/item-text.spec.luau"),
        module("StoreSectionFactory", "src/client/Ui/Hud/StoreSection.luau",
               {"Config", "Remotes", "GameTypes", "FarmMath", "Progression", "UiKit", "ItemPreview", "ItemText", "PurchaseController", "HudCommon", "ProductPrices"},
               "game, Config, Remotes, FarmMath, Progression, UiKit, ItemPreview, ItemText, PurchaseController, HudCommon, UDim2, ProductPrices"),
        module("ProductPricesFactory", "src/client/Core/ProductPrices.luau", {"Config"},
               "game, Config, Instance, task, os, Enum"),
        module("productPricesSpec", "tests/product-prices.spec.luau"),
        module("ActionBadgesFactory", "src/client/Ui/Hud/ActionBadges.luau", {"Config", "FarmMath", "Rewards", "HudCommon"}, "game, HudCommon, Config, FarmMath, Rewards"),
        module("actionBadgesSpec", "tests/action-badges.spec.luau"),
        module("MarketWindowFactory", "src/client/Ui/Hud/MarketWindow.luau",
               {"Config", "GameTypes", "FarmMath", "Progression", "UiKit", "PurchaseController", "HudCommon", "StoreSection", "RebirthWindow"},
               "game, Config, FarmMath, Progression, UiKit, PurchaseController, HudCommon, StoreSection, RebirthWindow, Instance, UDim2, Vector2, Enum"),
        module("marketUiSpec", "tests/market-ui.spec.luau"),
        module("ItemShopWindowFactory", "src/client/Ui/Hud/ItemShopWindow.luau",
               {"Config", "GameTypes", "FarmMath", "Inventory", "UiKit", "PurchaseController", "HudCommon", "ItemText", "ItemPreview"},
               "game, Config, FarmMath, Inventory, UiKit, PurchaseController, HudCommon, ItemText, ItemPreview, UDim2, Vector2"),
        module("AdminPanelFactory", "src/client/Ui/AdminPanel.luau", {"Remotes", "FarmMath", "UiKit", "ClientState"},
               "game, Remotes, FarmMath, UiKit, ClientState, Instance, UDim2, Vector2, UDim, Enum, os, task"),
        module("adminUiSpec", "tests/admin-ui.spec.luau"),
        module("SessionLock", "src/server/Modules/SessionLock.luau"),
        module("SaveBackup", "src/server/Modules/SaveBackup.luau"),
        module("FarmProfiles", "src/server/Modules/FarmProfiles.luau"),
        module("Preferences", "src/server/Modules/Preferences.luau"),
        module("TransferRules", "src/server/Modules/TransferRules.luau"),
        module("TransferLedger", "src/server/Modules/TransferLedger.luau", {"TransferRules"}),
        save_codec_bundle(),
        module("Rebirth", "src/server/Modules/Rebirth.luau"),
        module("financialRebirthSpec", "tests/financial-rebirth.spec.luau"),
        module("ScenarioFixtures", "tests/studio/ScenarioFixtures.luau"),
        module("studioScenariosSpec", "tests/studio-scenarios.spec.luau"),
        module("Rewards", "src/shared/Modules/Rewards.luau", {"Config", "FarmMath"}),
        module("Inventory", "src/shared/Modules/Inventory.luau", {"Config"}),
        module("Merchant", "src/shared/Modules/Merchant.luau", {"Config", "Inventory"}),
        module("merchantSpec", "tests/merchant.spec.luau"),
        module("MerchantVisualFactory", "src/server/Presentation/MerchantVisualService.luau", {"Config", "HubNpcs", "MapLayout"}, "game, Config, HubNpcs, MapLayout, Vector3, CFrame, Instance, Enum, task, warn"),
        module("merchantVisualSpec", "tests/merchant-visual.spec.luau"),
        module("MerchantWindowFactory", "src/client/Ui/Hud/MerchantWindow.luau", {"Config", "GameTypes", "Merchant", "FarmMath", "Remotes", "UiKit", "PurchaseController", "HudCommon", "ItemPreview", "ItemText"}, factory_args="game, Config, Merchant, FarmMath, Remotes, UiKit, PurchaseController, HudCommon, ItemPreview, ItemText, UDim2, Vector2"),
        module("merchantUiSpec", "tests/merchant-ui.spec.luau"),
        module("configSpec", "tests/config.spec.luau"),
        module("inventorySpec", "tests/inventory.spec.luau"),
        module("Golden", "src/shared/Modules/Golden.luau", {"Config", "FarmMath", "Merchant"}),
        module("goldenSpec", "tests/golden.spec.luau"),
        module("OnboardingSteps", "src/shared/Modules/OnboardingSteps.luau", {"Config", "FarmMath"}),
        module("onboardingSpec", "tests/onboarding.spec.luau"),
        module("OnboardingFactory", "src/client/Ui/Hud/Onboarding.luau", {"GameTypes", "OnboardingSteps", "UiKit"}, "game, UiKit, OnboardingSteps"),
        module("rewardsSpec", "tests/rewards.spec.luau"),
        module("ReceiptLog", "src/server/Modules/ReceiptLog.luau"),
        module("monetizationSpec", "tests/monetization.spec.luau"),
        module("dataSpec", "tests/data.spec.luau"),
        module("economySpec", "tests/economy.spec.luau"),
        "-- Telemetri diğer servis testlerinde etkisiz: gerçek hali tests/telemetry.spec.luau'da sınanır.\n",
        "local TelemetryService = setmetatable({}, { __index = function() return function() end end })\n",
        module("TelemetryLogic", "src/server/Modules/TelemetryLogic.luau"),
        module("TelemetryServiceFactory", "src/server/Services/TelemetryService.luau", {"TelemetryLogic", "Metrics"},
               "game, task, os, Enum, Metrics, warn, print"),
        module("telemetrySpec", "tests/telemetry.spec.luau"),
        # DataStore katmanı (SaveStore) her fixture'da sahte game/task/os ile kurulur; PlayerDataService onu kullanır.
        module("SaveStoreFactory", "src/server/Services/SaveStore.luau",
               {"Config", "SessionLock", "Metrics", "SaveBackup", "TransferLedger"},
               "game, task, os, Metrics, warn"),
        module("PlayerDataFactoryBody", "src/server/Services/PlayerDataService.luau",
               {"Config", "GameTypes", "Remotes", "FarmMath", "Progression", "SessionLock", "SaveCodec", "FarmProfiles", "Metrics", "SaveBackup", "Preferences", "TelemetryService", "SaveStore"},
               "game, task, Instance, os, Remotes, DateTime, Metrics, warn, SaveStore"),
        "local function PlayerDataFactory(game, task, Instance, os, Remotes, DateTime, Metrics, warn)\n"
        "\treturn PlayerDataFactoryBody(game, task, Instance, os, Remotes, DateTime, Metrics, warn,\n"
        "\t\tSaveStoreFactory(game, task, os, Metrics, warn))\n"
        "end\n",
        module("playerDataSpec", "tests/player-data-service.spec.luau"),
        module("RateLimiterFactory", "src/server/Modules/RateLimiter.luau", factory_args="game, os"),
        module("rateLimiterSpec", "tests/rate-limiter.spec.luau"),
        module("SeasonVisuals", "src/shared/Modules/SeasonVisuals.luau"),
        module("EnvironmentFactory", "src/shared/Modules/Environment.luau", {"Config"}, factory_args="game"),
        module("seasonsSpec", "tests/seasons.spec.luau"),
        module("PlotServiceFactory", "src/server/Services/PlotService.luau",
               {"Config", "GameTypes", "FarmMath", "UiTheme", "WorldUi", "PlayerDataService", "MapBuilder",
                "AnimalVisualService", "BarnVisualService", "UpgradeVisualService", "ZoneVisualService",
                "ExtensionVisualService", "IslandSpecialization", "DecorReveal", "VisualWorkBudget"},
               "game, warn, UiTheme, WorldUi, PlayerDataService, MapBuilder, AnimalVisualService, BarnVisualService, UpgradeVisualService, ZoneVisualService, ExtensionVisualService, IslandSpecialization, DecorReveal, Vector3, CFrame, VisualWorkBudget"),
        module("plotStartupSpec", "tests/plot-startup.spec.luau"),
        module("islandTravelSpec", "tests/island-travel.spec.luau"),
        module("AdminPolicy", "src/server/Modules/AdminPolicy.luau"),
        module("AdminServiceFactory", "src/server/Services/AdminService.luau",
               {"Config", "GameTypes", "Remotes", "FarmMath", "PlayerDataService", "EconomyService", "PlotService", "SeasonService", "SaveCodec", "FarmProfiles", "AdminPolicy", "RateLimiter", "DataResetService", "Golden"},
               "game, Remotes, PlayerDataService, EconomyService, PlotService, FarmMath, SeasonService, RateLimiter, DataResetService, Golden, warn"),
        module("adminSpec", "tests/admin.spec.luau"),
        module("transferSpec", "tests/transfer.spec.luau"),
        module("transferLedgerSpec", "tests/transfer-ledger.spec.luau"),
        module("transferServiceSpec", "tests/transfer-service.spec.luau"),
        module("tradePolicySpec", "tests/trade-policy.spec.luau"),
        module("TradePolicyServiceFactory", "src/server/Services/TradePolicyService.luau",
               {"Remotes", "RateLimiter"},
               "game, Remotes, RateLimiter, task, os, warn"),
        module("saveStoreTransferSpec", "tests/save-store-transfer.spec.luau"),
        module("TransferServiceFactory", "src/server/Services/TransferService.luau",
               {"Remotes", "FarmMath", "PlayerDataService", "SaveStore", "EconomyService", "TradePolicyService", "RequestGuard", "RateLimiter", "TransferRules", "TransferLedger"},
               "game, Remotes, PlayerDataService, SaveStore, EconomyService, TradePolicyService, RequestGuard, RateLimiter, task, os, warn"),

        module("SeasonServiceFactory", "src/server/Services/SeasonService.luau",
               {"Config", "Remotes", "Environment", "AdminPolicy", "RateLimiter", "Metrics"},
               "game, os, Random, Remotes, task, Environment, RateLimiter, Metrics, warn"),
        module("seasonAdminSpec", "tests/season-admin.spec.luau"),
        module("weatherQueueSpec", "tests/weather-queue.spec.luau"),
        module("ProductionRules", "src/server/Modules/ProductionRules.luau"),
        module("ProductionLogic", "src/server/Modules/ProductionLogic.luau", {"ProductionRules"}),
        module("goodsSpec", "tests/goods.spec.luau"),
        module("contractsSpec", "tests/contracts.spec.luau"),
        module("petsSpec", "tests/pets.spec.luau"),
        module("ProductionAutomationFactory", "src/client/Ui/Hud/ProductionAutomation.luau", {"Config", "FarmMath"}, "game, Config, FarmMath"),
        module("productionAutomationUiSpec", "tests/production-automation-ui.spec.luau"),
        module("MapPaths", "src/shared/MapPaths.luau"),
        module("mapPathsSpec", "tests/map-paths.spec.luau"),
        module("PetMotion", "src/shared/Modules/PetMotion.luau"),
        module("petMotionSpec", "tests/pet-motion.spec.luau"),
        module("PetCargo", "src/server/Modules/PetCargo.luau"),
        module("petCargoSpec", "tests/pet-cargo.spec.luau"),
        module("WearableFit", "src/server/Modules/WearableFit.luau"),
        module("wearableFitSpec", "tests/wearable-fit.spec.luau"),
        module("UiScale", "src/shared/Modules/UiScale.luau"),
        module("uiScaleSpec", "tests/ui-scale.spec.luau"),
        module("preferencesSpec", "tests/preferences.spec.luau"),
        module("ContractServiceFactory", "src/server/Services/ContractService.luau",
               {"Config", "Remotes", "FarmMath", "Environment", "Rewards", "PlayerDataService", "RateLimiter", "Metrics", "RequestGuard"},
               "game, Remotes, FarmMath, Environment, Rewards, PlayerDataService, RateLimiter, Metrics, DateTime, RequestGuard"),
        module("contractServiceSpec", "tests/contract-service.spec.luau"),
        module("ProductionServiceFactory", "src/server/Services/ProductionService.luau",
               {"Config", "Remotes", "FarmMath", "PlayerDataService", "EconomyService", "PlotService", "ProductionRules", "ProductionLogic", "RateLimiter"},
               "game, Remotes, PlayerDataService, EconomyService, PlotService, RateLimiter, DateTime, warn, ProductionLogic"),
        module("productionSpec", "tests/production.spec.luau"),
        module("ExtensionServiceFactory", "src/server/Services/ExtensionService.luau",
               {"Config", "Remotes", "FarmMath", "PlayerDataService", "EconomyService", "PlotService", "RateLimiter"},
               "game, Remotes, PlayerDataService, EconomyService, PlotService, RateLimiter, DateTime"),
        module("AnimalTaskServiceFactory", "src/server/Services/AnimalTaskService.luau",
               {"PlayerDataService", "PlotService", "EconomyService"},
               "game, task, DateTime, warn, PlayerDataService, PlotService, EconomyService"),
        module("tasksSpec", "tests/tasks.spec.luau"),
        module("MainFarmServiceFactory", "src/server/Services/MainFarmService.luau",
               {"Config", "Remotes", "FarmMath", "PlayerDataService", "PlotService", "EconomyService", "SaveCodec", "FarmProfiles", "RateLimiter", "ProductionRules", "TelemetryService", "VisualWorkBudget"},
               "game, Remotes, PlayerDataService, PlotService, EconomyService, RateLimiter, DateTime, warn, task, VisualWorkBudget"),
        module("EconomyServiceFactory", "src/server/Services/EconomyService.luau",
               {"Config", "Remotes", "FarmMath", "UiTheme", "WorldUi", "PlayerDataService", "PlotService", "RateLimiter", "Metrics", "TelemetryService"},
               "game, Remotes, PlayerDataService, PlotService, RateLimiter, UiTheme, WorldUi, Metrics, os, DateTime, task, warn"),
        module("mainFarmSpec", "tests/main-farm.spec.luau"),
        module("economyServiceSpec", "tests/economy-service.spec.luau"),
        module("ClientStateFactory", "src/client/Core/ClientState.luau", {"Remotes", "GameTypes"}, "game, Remotes, task, os, warn"),
        module("clientFarmStateSpec", "tests/client-farm-state.spec.luau"),
        module("LocalizerFactory", "src/client/Core/Localizer.client.luau", {"Localization"}, "game, Localization"),
        module("clientLocalizerSpec", "tests/client-localizer.spec.luau"),
        module("JobProgressFactory", "src/client/Interaction/JobProgress.client.luau", {"UiKit", "ProductionPanel"}, "game, UiKit, Instance, UDim2, Vector2, Color3, Enum, script, ProductionPanel"),
        module("clientJobProgressSpec", "tests/client-job-progress.spec.luau"),
        module("RequestGuardFactory", "src/server/Services/RequestGuard.luau",
               {"Remotes", "PlayerDataService", "RateLimiter", "Metrics"},
               "game, Remotes, PlayerDataService, RateLimiter, Metrics"),
        module("SeasonGlow", "src/client/Effects/SeasonGlow.luau"),
        module("seasonGlowSpec", "tests/season-glow.spec.luau"),
        module("SeasonSignalFactory", "src/client/Effects/SeasonSignal.client.luau",
               {"FarmMath", "Environment", "UiTheme", "ClientState", "StartupGate", "ClientModelAssets", "EffectSettings", "SeasonGlow"},
               "game, task, script, FarmMath, Environment, UiTheme, ClientState, StartupGate, ClientModelAssets, EffectSettings, SeasonGlow"),
        module("seasonSignalSpec", "tests/season-signal.spec.luau"),
        module("ExtensionVisualFactory", "src/server/Presentation/ExtensionVisualService.luau",
               {"Config", "Remotes", "GameTypes", "FarmMath", "InstanceUtil", "JobMarks", "WorldUi", "IslandSpecialization", "ModelAssets"},
               "game, script, Instance, Vector3, Vector2, CFrame, Enum, DateTime, Config, Remotes, GameTypes, FarmMath, InstanceUtil, JobMarks, WorldUi, IslandSpecialization, ModelAssets"),
        module("extensionVisualSpec", "tests/extension-visual.spec.luau"),
        module("serviceHarnessFactory", "tests/service-harness.luau"),
        "local function serviceHarness(createLimiter, codec, config, farmMath)\n"
        "\treturn serviceHarnessFactory(createLimiter, codec, config, farmMath, RequestGuardFactory)\n"
        "end\n",
        module("AnimalServiceFactory", "src/server/Services/AnimalService.luau",
               {"Config", "Remotes", "FarmMath", "Rewards", "PlayerDataService", "PlotService", "EconomyService", "RateLimiter", "Metrics", "RequestGuard", "TelemetryService"},
               "game, Remotes, PlayerDataService, PlotService, EconomyService, RateLimiter, Metrics, DateTime, task, RequestGuard"),
        module("animalServiceSpec", "tests/animal-service.spec.luau"),
        module("UpgradeServiceFactory", "src/server/Services/UpgradeService.luau",
               {"Config", "Remotes", "FarmMath", "Rewards", "PlayerDataService", "PlotService", "EconomyService", "RateLimiter", "Metrics", "RequestGuard", "TelemetryService"},
               "game, Remotes, PlayerDataService, PlotService, EconomyService, RateLimiter, Metrics, DateTime, RequestGuard"),
        module("upgradeServiceSpec", "tests/upgrade-service.spec.luau"),
        module("InventoryServiceFactory", "src/server/Services/InventoryService.luau",
               {"Config", "Remotes", "FarmMath", "Environment", "Inventory", "PlayerDataService", "PlotService", "EconomyService", "RateLimiter", "Metrics", "RequestGuard", "ModelAssets", "Merchant", "SeasonService", "WearableFit"},
               "game, Remotes, PlayerDataService, PlotService, EconomyService, RateLimiter, Metrics, DateTime, task, os, Environment, RequestGuard, ModelAssets, Merchant, SeasonService"),
        module("inventoryServiceSpec", "tests/inventory-service.spec.luau"),
        module("EngagementServiceFactory", "src/server/Services/EngagementService.luau",
               {"Config", "Remotes", "FarmMath", "Rewards", "Golden", "PlayerDataService", "EconomyService", "PlotService", "RateLimiter", "Metrics", "RequestGuard"},
               "game, Remotes, PlayerDataService, EconomyService, PlotService, RateLimiter, Metrics, DateTime, task, warn, RequestGuard"),
        module("engagementServiceSpec", "tests/engagement-service.spec.luau"),
        module("MonetizationServiceFactory", "src/server/Services/MonetizationService.luau",
               {"Config", "Remotes", "FarmMath", "Progression", "PlayerDataService", "RateLimiter", "ReceiptLog", "Metrics", "TelemetryService", "EconomyService", "PlotService"},
               "game, Remotes, PlayerDataService, RateLimiter, Metrics, Enum, warn, task, TelemetryService, EconomyService, PlotService"),
        module("monetizationServiceSpec", "tests/monetization-service.spec.luau"),
        module("ProgressionServiceFactory", "src/server/Services/ProgressionService.luau",
               {"Config", "Remotes", "FarmMath", "Progression", "SaveCodec", "Rebirth", "PlayerDataService", "PlotService", "EconomyService", "RequestGuard", "RateLimiter"},
               "game, Remotes, PlayerDataService, PlotService, EconomyService, RequestGuard, RateLimiter, DateTime, task, warn"),
        module("progressionServiceSpec", "tests/progression-service.spec.luau"),
        module("BuyPadServiceFactory", "src/server/Services/BuyPadService.luau",
               {"Config", "Remotes", "FarmMath", "RateLimiter", "UiTheme", "WorldUi", "ModelAssets", "PlayerDataService", "PlotService", "UpgradeService", "UpgradeVisualService"},
               "game, Remotes, RateLimiter, UiTheme, WorldUi, PlayerDataService, PlotService, UpgradeService, UpgradeVisualService, task, warn, Vector2, ModelAssets"),
        module("buyPadServiceSpec", "tests/buypad-service.spec.luau"),
        module("requestGuardSpec", "tests/request-guard.spec.luau"),
        "dataSpec(SessionLock, SaveCodec, Config, FarmMath)\n",
        "financialRebirthSpec(SaveCodec, Config, FarmMath, Progression, Rebirth)\n",
        "studioScenariosSpec(ScenarioFixtures, SaveCodec, Config, FarmMath, Progression)\n",
        "progressionSpec(Progression, FarmMath, Config, SaveCodec)\n",
        "progressionUiSpec(PurchaseControllerFactory, RebirthWindowFactory)\n",
        "weatherQueueUiSpec(WeatherQueuePromptFactory)\n",
        "marketProductsSpec(Config, FarmMath, SaveCodec, Inventory)\n",
        "uiDisclosureSpec(ControlsFactory)\n",
        "uiKitLayoutSpec(BaseFactory, GridFactory)\n",
        "productionContextSpec(ProductionContextFactory, Config)\n",
        "windowsSpec(WindowsFactory)\n",
        "visitTargetsSpec(VisitTargets)\n",
        "effectSummarySpec(EffectSummary, Config, FarmMath, SaveCodec, Inventory, Progression)\n",
        "effectsSectionSpec(EffectsSectionFactory)\n",
        "hudLayoutSpec(StatsPanelFactory, GoalCardFactory)\n",
        "bridgeSurfaceSpec(BridgeSurface)\n",
        "bridgeBoostSpec(BridgeBoostFactory, BridgeSurface)\n",
        "animalAnimatorSpec(AnimalAnimatorFactory)\n",
        "boardUiSpec(BoardSectionFactory)\n",
        "clientModelAssetsSpec(ClientModelAssetsFactory)\n",
        "modelAssetsSpec(ModelAssetsFactory)\n",
        "missingModelsSpec(AnimalModelsFactory, DecorShoreFactory)\n",
        "toastsSpec(ToastsFactory, MerchantBadgeFactory)\n",
        "hubBoardSpec(HubBoardServiceFactory, Config)\n",
        "roadmapUiSpec(RoadmapWindowFactory, Config, SaveCodec, FarmMath, OnboardingFactory, OnboardingSteps)\n",
        "islandTabsSpec(IslandTabsFactory, Config, SaveCodec, FarmMath)\n",
        "rebirthJourneySpec(Config, FarmMath, Progression, SaveCodec, Inventory)\n",
        "itemTextSpec(ItemTextFactory)\n",
        "marketUiSpec(StoreSectionFactory, MarketWindowFactory, ItemShopWindowFactory)\n",
        "productPricesSpec(ProductPricesFactory)\n",
        "actionBadgesSpec(ActionBadgesFactory, Config, FarmMath, SaveCodec, Rewards)\n",
        "adminUiSpec(AdminPanelFactory)\n",
        "progressionServiceSpec(ProgressionServiceFactory, serviceHarness(RateLimiterFactory, SaveCodec, Config, FarmMath), SaveCodec, Config, FarmMath, Progression)\n",
        "transferLedgerSpec(TransferLedger, SaveCodec, Config, FarmMath, SessionLock)\n",
        "transferServiceSpec(TransferServiceFactory, TransferLedger, TransferRules)\n",
        "tradePolicySpec(TradePolicyServiceFactory)\n",
        "saveStoreTransferSpec(SaveStoreFactory)\n",
        "economySpec(FarmMath, Config, Environment)\n",
        "rewardsSpec(Rewards, Config, FarmMath)\n",
        "merchantSpec(Merchant, Config, FarmMath)\n",
        "merchantVisualSpec(MerchantVisualFactory, Config, Merchant)\n",
        "merchantUiSpec(MerchantWindowFactory, Merchant, Config, FarmMath)\n",
        "goldenSpec(Golden, Config, FarmMath)\n",
        "onboardingSpec(OnboardingSteps, Config, FarmMath)\n",
        "configSpec(Config, FarmMath)\n",
        "inventorySpec(Inventory, Config, FarmMath, SaveCodec, SessionLock, FarmProfiles)\n",
        "monetizationSpec(ReceiptLog, FarmMath, Config, SaveCodec)\n",
        "playerDataSpec(PlayerDataFactory, Config, SessionLock.VERSION)\n",
        "rateLimiterSpec(RateLimiterFactory)\n",
        "seasonsSpec(SeasonVisuals, EnvironmentFactory, Config)\n",
        "plotStartupSpec(PlotServiceFactory, Config)\n",
        "islandTravelSpec(PlotServiceFactory, Config)\n",
        "adminSpec(AdminPolicy, AdminServiceFactory, RateLimiterFactory, Config, FarmMath)\n",
        "seasonAdminSpec(SeasonServiceFactory, EnvironmentFactory, RateLimiterFactory, Config)\n",
        "weatherQueueSpec(SeasonServiceFactory, EnvironmentFactory, RateLimiterFactory, Config)\n",
        "productionSpec(ProductionServiceFactory, RateLimiterFactory, ProductionRules, SaveCodec, Config, FarmMath, ProductionLogic)\n",
        "mainFarmSpec(MainFarmServiceFactory, EconomyServiceFactory, RateLimiterFactory, FarmProfiles, SaveCodec, Config, FarmMath)\n",
        "economyServiceSpec(EconomyServiceFactory, RateLimiterFactory, SaveCodec, Config, FarmMath)\n",
        "tasksSpec(ExtensionServiceFactory, AnimalTaskServiceFactory, RateLimiterFactory, SaveCodec, Config, FarmMath)\n",
        "goodsSpec(SaveCodec, Config, FarmMath, ProductionRules, ProductionLogic)\n",
        "contractsSpec(SaveCodec, Config, FarmMath, FarmProfiles)\n",
        "petsSpec(SaveCodec, Config, FarmMath, ProductionLogic)\n",
        "petCargoSpec(PetCargo)\n",
        "wearableFitSpec(WearableFit)\n",
        "productionAutomationUiSpec(ProductionAutomationFactory, SaveCodec, Config, FarmMath)\n",
        "mapPathsSpec(MapPaths)\n",
        "uiScaleSpec(UiScale)\n",
        "preferencesSpec(Preferences, SaveCodec, Config, FarmMath)\n",
        "contractServiceSpec(ContractServiceFactory, RateLimiterFactory, SaveCodec, Config, FarmMath, RequestGuardFactory, Rewards)\n",
        "clientFarmStateSpec(ClientStateFactory)\n",
        "clientLocalizerSpec(LocalizerFactory)\n",
        "clientJobProgressSpec(JobProgressFactory)\n",
        "seasonGlowSpec(SeasonGlow)\n",
        "extensionVisualSpec(ExtensionVisualFactory)\n",
        "seasonSignalSpec(SeasonSignalFactory)\n",
        "telemetrySpec(TelemetryServiceFactory, TelemetryLogic, Config)\n",
        "animalServiceSpec(AnimalServiceFactory, serviceHarness, RateLimiterFactory, SaveCodec, Config, FarmMath)\n",
        "upgradeServiceSpec(UpgradeServiceFactory, serviceHarness, RateLimiterFactory, SaveCodec, Config, FarmMath)\n",
        "inventoryServiceSpec(InventoryServiceFactory, serviceHarness, RateLimiterFactory, EnvironmentFactory, SaveCodec, Config, FarmMath, Inventory, Merchant)\n",
        "engagementServiceSpec(EngagementServiceFactory, serviceHarness, RateLimiterFactory, SaveCodec, Config, FarmMath, Rewards)\n",
        "monetizationServiceSpec(MonetizationServiceFactory, serviceHarness, RateLimiterFactory, SaveCodec, Config, FarmMath)\n",
        "buyPadServiceSpec(BuyPadServiceFactory, UpgradeServiceFactory, serviceHarness, RateLimiterFactory, SaveCodec, Config, FarmMath)\n",
        "requestGuardSpec(serviceHarness, RateLimiterFactory, SaveCodec, Config, FarmMath)\n",
    ]
    if args.check_dependencies:
        sys.dont_write_bytecode = True
        spec = importlib.util.spec_from_file_location("test_dependency_checker", ROOT / "scripts/check-test-dependencies.py")
        assert spec and spec.loader
        checker = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(checker)
        return (dependency_reporter or checker.report)(checker.check_bundle("\n".join(pieces)))
    if args.list:
        for name, aliases in sorted(spec_catalog(pieces).items()):
            print(f"{','.join(sorted(aliases))}	{name}")
        return 0
    if args.only:
        pieces, unknown = select_specs(pieces, args.only)
        if unknown:
            print(f"Unknown spec(s): {', '.join(unknown)}. Use --list.", file=sys.stderr)
            return 2
    output = ROOT / ".test-build" / "run.luau"
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text("\n".join(pieces), encoding="utf-8")
    result = subprocess.run([executable, str(output)], cwd=ROOT, check=False)
    if result.returncode == 0:
        scope = "Selected pure Luau specs passed (SUBSET, not the full suite)." if args.only else "Pure Luau regression suite passed."
        print(scope + " Roblox runtime/world tests require Studio.", flush=True)
    return result.returncode


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (ValueError, OSError) as error:
        if "--check-dependencies" in sys.argv:
            print(f"TD001: {error}")
            raise SystemExit(1)
        raise
