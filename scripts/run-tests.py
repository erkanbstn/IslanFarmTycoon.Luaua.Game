#!/usr/bin/env python3
"""Run pure Luau regression specs against the real project source.

Only module-loading declarations are substituted. Config values and all production
functions are copied verbatim, so the harness cannot silently test a Python port.
Roblox instance/world tests remain in the isolated test.project.json Studio place.
"""

from __future__ import annotations

import argparse
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
    if factory_args:
        return f"-- Source: {path}\nlocal {name} = function({factory_args})\n{source}\nend\n"
    return f"-- Source: {path}\nlocal {name} = (function()\n{source}\nend)()\n"


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
    return "".join(["local Config = (function()\n", parts, init, "\nreturn ConfigInit\nend)()\n"])


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
    return "".join(["local FarmMath = (function()\n", parts, init, "\nreturn FarmMathInit\nend)()\n"])


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
    return "".join(["local SaveCodec = (function()\n", parts, init, "\nreturn SaveCodecInit\nend)()\n"])


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--luau", help="Path to the standalone Luau interpreter (not Lua)")
    args = parser.parse_args()
    executable = args.luau or shutil.which("luau")
    if executable is None:
        bundled = ROOT / ".tools" / "luau" / ("luau.exe" if sys.platform == "win32" else "luau")
        if bundled.is_file():
            executable = str(bundled)
    if executable is None:
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
        module("progressionSpec", "tests/progression.spec.luau"),
        module("PurchaseControllerFactory", "src/client/Core/PurchaseController.luau", {"Remotes", "ClientState", "Sfx"},
               "game, Remotes, ClientState, Sfx, Instance, os, task"),
        module("RebirthWindowFactory", "src/client/Ui/Hud/RebirthWindow.luau", {"Config", "GameTypes", "Progression", "FarmMath", "UiKit", "PurchaseController", "HudCommon"},
               "game, Config, Progression, UiKit, PurchaseController, HudCommon, Instance, UDim2, Vector2, Enum, script, FarmMath"),
        module("progressionUiSpec", "tests/progression-ui.spec.luau"),
        module("SessionLock", "src/server/Modules/SessionLock.luau"),
        module("SaveBackup", "src/server/Modules/SaveBackup.luau"),
        module("FarmProfiles", "src/server/Modules/FarmProfiles.luau"),
        module("Preferences", "src/server/Modules/Preferences.luau"),
        module("TransferRules", "src/server/Modules/TransferRules.luau"),
        module("TransferLedger", "src/server/Modules/TransferLedger.luau", {"TransferRules"}),
        save_codec_bundle(),
        module("Rebirth", "src/server/Modules/Rebirth.luau"),
        module("financialRebirthSpec", "tests/financial-rebirth.spec.luau"),
        module("Rewards", "src/shared/Modules/Rewards.luau", {"Config", "FarmMath"}),
        module("Merchant", "src/shared/Modules/Merchant.luau", {"Config", "FarmMath"}),
        module("merchantSpec", "tests/merchant.spec.luau"),
        module("configSpec", "tests/config.spec.luau"),
        module("Inventory", "src/shared/Modules/Inventory.luau", {"Config"}),
        module("inventorySpec", "tests/inventory.spec.luau"),
        module("Golden", "src/shared/Modules/Golden.luau", {"Config", "FarmMath", "Merchant"}),
        module("goldenSpec", "tests/golden.spec.luau"),
        module("OnboardingSteps", "src/shared/Modules/OnboardingSteps.luau", {"Config", "FarmMath"}),
        module("onboardingSpec", "tests/onboarding.spec.luau"),
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
               {"Config", "GameTypes", "Remotes", "FarmMath", "PlayerDataService", "EconomyService", "PlotService", "SeasonService", "SaveCodec", "FarmProfiles", "AdminPolicy", "RateLimiter", "DataResetService"},
               "game, Remotes, PlayerDataService, EconomyService, PlotService, FarmMath, SeasonService, RateLimiter, DataResetService"),
        module("adminSpec", "tests/admin.spec.luau"),
        module("transferSpec", "tests/transfer.spec.luau"),
        module("transferLedgerSpec", "tests/transfer-ledger.spec.luau"),
        module("transferServiceSpec", "tests/transfer-service.spec.luau"),
        module("saveStoreTransferSpec", "tests/save-store-transfer.spec.luau"),
        module("TransferServiceFactory", "src/server/Services/TransferService.luau",
               {"Remotes", "FarmMath", "PlayerDataService", "SaveStore", "EconomyService", "RequestGuard", "RateLimiter", "TransferRules", "TransferLedger"},
               "game, Remotes, PlayerDataService, SaveStore, EconomyService, RequestGuard, RateLimiter, task, os, warn"),

        module("SeasonServiceFactory", "src/server/Services/SeasonService.luau",
               {"Config", "Remotes", "Environment", "AdminPolicy", "RateLimiter", "Metrics"},
               "game, os, Random, Remotes, task, Environment, RateLimiter, Metrics, warn"),
        module("seasonAdminSpec", "tests/season-admin.spec.luau"),
        module("ProductionRules", "src/server/Modules/ProductionRules.luau"),
        module("ProductionLogic", "src/server/Modules/ProductionLogic.luau", {"ProductionRules"}),
        module("goodsSpec", "tests/goods.spec.luau"),
        module("contractsSpec", "tests/contracts.spec.luau"),
        module("petsSpec", "tests/pets.spec.luau"),
        module("MapPaths", "src/shared/MapPaths.luau"),
        module("mapPathsSpec", "tests/map-paths.spec.luau"),
        module("PetMotion", "src/shared/Modules/PetMotion.luau"),
        module("petMotionSpec", "tests/pet-motion.spec.luau"),
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
        module("JobProgressFactory", "src/client/Interaction/JobProgress.client.luau", {"UiKit"}, "game, UiKit, Instance, UDim2, Vector2, Color3, Enum, script"),
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
               {"Config", "Remotes", "GameTypes", "FarmMath", "InstanceUtil", "JobMarks", "WorldUi", "IslandSpecialization", "ModelAssets", "ExtensionAreas"},
               "game, script, Instance, Vector3, Vector2, CFrame, Enum, DateTime, Config, Remotes, GameTypes, FarmMath, InstanceUtil, JobMarks, WorldUi, IslandSpecialization, ModelAssets, ExtensionAreas"),
        module("extensionVisualSpec", "tests/extension-visual.spec.luau"),
        module("serviceHarnessFactory", "tests/service-harness.luau"),
        "local function serviceHarness(createLimiter, codec, config, farmMath)\n"
        "\treturn serviceHarnessFactory(createLimiter, codec, config, farmMath, RequestGuardFactory)\n"
        "end\n",
        module("AnimalServiceFactory", "src/server/Services/AnimalService.luau",
               {"Config", "Remotes", "FarmMath", "Rewards", "Merchant", "PlayerDataService", "PlotService", "EconomyService", "RateLimiter", "Metrics", "RequestGuard", "TelemetryService"},
               "game, Remotes, PlayerDataService, PlotService, EconomyService, RateLimiter, Metrics, DateTime, task, RequestGuard"),
        module("animalServiceSpec", "tests/animal-service.spec.luau"),
        module("UpgradeServiceFactory", "src/server/Services/UpgradeService.luau",
               {"Config", "Remotes", "FarmMath", "Rewards", "PlayerDataService", "PlotService", "EconomyService", "RateLimiter", "Metrics", "RequestGuard", "TelemetryService"},
               "game, Remotes, PlayerDataService, PlotService, EconomyService, RateLimiter, Metrics, DateTime, RequestGuard"),
        module("upgradeServiceSpec", "tests/upgrade-service.spec.luau"),
        module("InventoryServiceFactory", "src/server/Services/InventoryService.luau",
               {"Config", "Remotes", "FarmMath", "Environment", "Inventory", "PlayerDataService", "PlotService", "EconomyService", "RateLimiter", "Metrics", "RequestGuard", "ModelAssets"},
               "game, Remotes, PlayerDataService, PlotService, EconomyService, RateLimiter, Metrics, DateTime, task, os, Environment, RequestGuard, ModelAssets"),
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
        "progressionSpec(Progression, FarmMath, Config, SaveCodec)\n",
        "progressionUiSpec(PurchaseControllerFactory, RebirthWindowFactory)\n",
        "progressionServiceSpec(ProgressionServiceFactory, serviceHarness(RateLimiterFactory, SaveCodec, Config, FarmMath), SaveCodec, Config, FarmMath, Progression)\n",
        "transferLedgerSpec(TransferLedger, SaveCodec, Config, FarmMath, SessionLock)\n",
        "transferServiceSpec(TransferServiceFactory, TransferLedger, TransferRules)\n",
        "saveStoreTransferSpec(SaveStoreFactory)\n",
        "economySpec(FarmMath, Config, Environment)\n",
        "rewardsSpec(Rewards, Config, FarmMath)\n",
        "merchantSpec(Merchant, Config, FarmMath)\n",
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
        "adminSpec(AdminPolicy, AdminServiceFactory, RateLimiterFactory, Config)\n",
        "seasonAdminSpec(SeasonServiceFactory, EnvironmentFactory, RateLimiterFactory, Config)\n",
        "productionSpec(ProductionServiceFactory, RateLimiterFactory, ProductionRules, SaveCodec, Config, FarmMath, ProductionLogic)\n",
        "mainFarmSpec(MainFarmServiceFactory, EconomyServiceFactory, RateLimiterFactory, FarmProfiles, SaveCodec, Config, FarmMath)\n",
        "economyServiceSpec(EconomyServiceFactory, RateLimiterFactory, SaveCodec, Config, FarmMath)\n",
        "tasksSpec(ExtensionServiceFactory, AnimalTaskServiceFactory, RateLimiterFactory, SaveCodec, Config, FarmMath)\n",
        "goodsSpec(SaveCodec, Config, FarmMath, ProductionRules, ProductionLogic)\n",
        "contractsSpec(SaveCodec, Config, FarmMath, FarmProfiles)\n",
        "petsSpec(SaveCodec, Config, FarmMath, ProductionLogic)\n",
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
        "animalServiceSpec(AnimalServiceFactory, serviceHarness, RateLimiterFactory, SaveCodec, Config, FarmMath, Merchant)\n",
        "upgradeServiceSpec(UpgradeServiceFactory, serviceHarness, RateLimiterFactory, SaveCodec, Config, FarmMath)\n",
        "inventoryServiceSpec(InventoryServiceFactory, serviceHarness, RateLimiterFactory, EnvironmentFactory, SaveCodec, Config, FarmMath, Inventory)\n",
        "engagementServiceSpec(EngagementServiceFactory, serviceHarness, RateLimiterFactory, SaveCodec, Config, FarmMath, Rewards)\n",
        "monetizationServiceSpec(MonetizationServiceFactory, serviceHarness, RateLimiterFactory, SaveCodec, Config, FarmMath)\n",
        "buyPadServiceSpec(BuyPadServiceFactory, UpgradeServiceFactory, serviceHarness, RateLimiterFactory, SaveCodec, Config, FarmMath)\n",
        "requestGuardSpec(serviceHarness, RateLimiterFactory, SaveCodec, Config, FarmMath)\n",
    ]
    output = ROOT / ".test-build" / "run.luau"
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text("\n".join(pieces), encoding="utf-8")
    result = subprocess.run([executable, str(output)], cwd=ROOT, check=False)
    if result.returncode == 0:
        print("Pure Luau regression suite passed. Roblox runtime/world tests require Studio.", flush=True)
    return result.returncode


if __name__ == "__main__":
    raise SystemExit(main())
