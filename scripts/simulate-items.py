#!/usr/bin/env python3
"""Ekipman gücü ölçümü: her eşyanın ve standart takımın tur süresine gerçek katkısı.

Gerçek Config/FarmMath/Progression, `simulate-economy.py` üzerinden çalışır (formül kopyalanmaz; eşya sayıları
koda yazılmaz, hepsi Config'ten okunur). Her oyuncu (ideal/casual/idle) ve rebirth durumu (R0, R5...) için:
  - taban koşu: o durumdaki ücretsiz kazanımlarla altı çiftlikli temel tur (rebirth hazır takvim günü),
  - tek eşya koşusu: aynı koşu, eşya sahip olunup takılı (yuvasındakinin yerine); kazanılan gün ve yüzde,
  - standart takımlar: starter (yalnız nakit eşyalar), mid (nakit + nakit/altın), premium (satın alınabilen en iyiler),
    endgame (premium + rebirth ödülleri); yuva başına tek ölçülmüş en iyi eşya,
  - değer: 100 altın başına ve 1 milyon nakit başına kazanılan gün; altın formülü ve yuva/kademe sırası tutarlılığı,
  - bir rebirth altınıyla kaç eşya alınabildiği (Progression.rebirthGoldReward).
`--probe` (koşusuz, saniyeler) her eşya etkisinin gerçek FarmMath tüketicilerine aktığını ve tavanların tuttuğunu doğrular.

Sınırlar: oyuncu davranışı basit politikadır (canlı oyuncu ölçümü değil). Casual/idle süreleri oturum aralığına kuantalıdır
(casual 8 sa, idle 12 sa); bu aralıktan küçük kazançlar 0 görünür. Hareket hızı, hayvan satış geliri (`sellBonus`) ve asa
güçleri (mevsim/hava/büyüme/üretim/toplama/bakım) simülasyonda modellenmez: bunlara yaslanan eşyaların değeri alt sınırdır
(`unmodeled` alanı). Ideal oyuncu sipariş vermez (`contractBonus` ideal'de 0'dır); üretim yalnız açılışın ihtiyacı kadardır.
Kullanım: python scripts/simulate-items.py --probe | [--states ideal:5,casual:5,ideal:0] [--workers 12] [--output yol]
"""
from __future__ import annotations

import argparse
from concurrent.futures import ThreadPoolExecutor
import hashlib
from importlib.util import module_from_spec, spec_from_file_location
import json
import math
import os
from pathlib import Path
import shutil
import statistics
import subprocess
import sys
import threading
import time

ROOT = Path(__file__).resolve().parents[1]
PERSONAS = ("ideal", "casual", "idle", "hardcore")
DEFAULT_STATES = "ideal:5,casual:5,ideal:0"
DEAD_PCT = 0.5       # tek eşya turu bundan az kısaltıyorsa ölü yük
STRONG_PCT = 10.0    # tek eşya turu bundan çok kısaltıyorsa fazla güçlü
UNMODELED_EFFECTS = ("movementSpeed", "sellBonus")
QUANTUM_DAYS = {"ideal": 0.01, "casual": 8 / 24, "idle": 12 / 24, "hardcore": 0.01}
SOURCE_GLOBS = ("src/shared/Config/*.luau", "src/shared/Modules/FarmMath/*.luau", "src/shared/Modules/Progression.luau",
                "src/shared/Modules/Rewards.luau", "src/server/Modules/Rebirth.luau", "src/server/Modules/ProductionLogic.luau",
                "scripts/simulate-economy.py", "scripts/simulate-rebirth.py", "scripts/run-tests.py")


def _load(name: str, path: str):
    spec = spec_from_file_location(name, ROOT / path)
    module = module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


# ---------------------------------------------------------------------------
# Saf yardımcılar (testler bunları koşusuz çağırır)
# ---------------------------------------------------------------------------
def formula_gold(price: float) -> int:
    """Progression.luau yorumundaki altın formülü: min(1500, yuvarla10(150 + 100 * sqrt(fiyat / 100000)))."""
    return int(min(1500, math.floor((150 + 100 * math.sqrt(price / 100000)) / 10 + 0.5) * 10))


def perks_for(count: int, order: list[str], max_level: int = 5) -> str:
    """Kampanyanın perk politikası: her rebirth'te sırayla (döner) ilk dolmamış etkiyi seçer."""
    levels: dict[str, int] = {}
    for turn in range(count):
        for offset in range(len(order)):
            key = order[(turn + offset) % len(order)]
            if levels.get(key, 0) < max_level:
                levels[key] = levels.get(key, 0) + 1
                break
    return ",".join(f"{key}:{level}" for key, level in levels.items())


def parse_states(text: str) -> list[tuple[str, int]]:
    states: list[tuple[str, int]] = []
    for part in text.split(","):
        part = part.strip()
        if not part:
            continue
        persona, _, level = part.partition(":")
        if persona not in PERSONAS or not level.isdigit() or not 0 <= int(level) <= 30:
            raise ValueError(f"Geçersiz durum {part!r}: kişi:rebirth biçiminde olmalı (kişi {'/'.join(PERSONAS)}, rebirth 0..30)")
        if (persona, int(level)) not in states:
            states.append((persona, int(level)))
    if not states:
        raise ValueError("En az bir durum gerekli")
    return states


def state_key(persona: str, rebirth: int) -> str:
    return f"{persona}:R{rebirth}"


def effective_pct(result: dict | None, key: str = "") -> float | None:
    """Gürültü tabanı altındaki (en çok bir oturum kuantası) fark 0 sayılır; ölçüm yoksa None. key = 'kişi:Rn'."""
    if result is None:
        return None
    persona = key.split(":")[0]
    below = abs(result["savedDays"]) <= QUANTUM_DAYS[persona] + 1e-3 if persona in QUANTUM_DAYS else result.get("belowResolution")
    return 0.0 if below else result["pct"]


def classify(pct: float | None, dead: float = DEAD_PCT, strong: float = STRONG_PCT) -> str:
    if pct is None:
        return "unmeasured"
    if pct < dead:
        return "dead"
    if pct > strong:
        return "strong"
    return "ok"


def spearman(xs: list[float], ys: list[float]) -> float | None:
    """Sıra korelasyonu (eşit değerler ortalama sıra); veri yetersizse ya da sabitse None."""
    if len(xs) != len(ys) or len(xs) < 3:
        return None

    def ranks(values: list[float]) -> list[float]:
        order = sorted(range(len(values)), key=lambda index: values[index])
        result = [0.0] * len(values)
        position = 0
        while position < len(order):
            end = position
            while end + 1 < len(order) and values[order[end + 1]] == values[order[position]]:
                end += 1
            for index in range(position, end + 1):
                result[order[index]] = (position + end) / 2 + 1
            position = end + 1
        return result

    rx, ry = ranks(xs), ranks(ys)
    mx, my = statistics.fmean(rx), statistics.fmean(ry)
    denominator = math.sqrt(sum((a - mx) ** 2 for a in rx) * sum((b - my) ** 2 for b in ry))
    if denominator == 0:
        return None
    return sum((a - mx) * (b - my) for a, b in zip(rx, ry)) / denominator


def ordering_inversions(rows: list[dict], cost_key: str = "cost", benefit_key: str = "pct", tolerance: float = 0.25) -> list[dict]:
    """Aynı yuvada daha pahalı eşyanın daha az fayda verdiği çiftler (tolerans puan altındaki fark gürültü sayılır)."""
    inversions: list[dict] = []
    for slot in sorted({row["slot"] for row in rows}):
        group = sorted((row for row in rows if row["slot"] == slot and row.get(cost_key) is not None and row.get(benefit_key) is not None),
                       key=lambda row: (row[cost_key], row["id"]))
        for index, cheap in enumerate(group):
            for dear in group[index + 1:]:
                if dear[cost_key] > cheap[cost_key] and dear[benefit_key] + tolerance < cheap[benefit_key]:
                    inversions.append({"slot": slot, "cheap": cheap["id"], "dear": dear["id"], "cheapCost": cheap[cost_key],
                                       "dearCost": dear[cost_key], "cheapPct": cheap[benefit_key], "dearPct": dear[benefit_key]})
    return inversions


def cumulative_gold(rewards: list[int], rebirths: int) -> list[int]:
    """k. rebirth sonunda (k = 1..rebirths) toplam altın; rewards[c] = o anki rebirth sayısı c iken ödül."""
    total, result = 0, []
    for turn in range(rebirths):
        total += rewards[min(turn, len(rewards) - 1)]
        result.append(total)
    return result


def rebirth_to_afford(cumulative: list[int], cost: int) -> int | None:
    """Toplam altın bu bedele ilk kaç rebirth sonunda yeter (yetmiyorsa None)."""
    for index, total in enumerate(cumulative):
        if total >= cost:
            return index + 1
    return None


def greedy_purchases(options: list[dict], rewards: list[int], rebirths: int) -> list[dict]:
    """Her rebirth sonunda kasadaki altınla, yuvasındaki mevcut eşyaya göre en çok gün kazandıran eşyayı al (yuva başına tek eşya).

    Seçenek: id, gold, savedDays, slot (yoksa kendi yuvası). Zaman çizelgesi: alınanlar, kalan altın ve takılı eşyaların birleşik
    kazancı (kazançlar çarpımsal birleştirilir: 1 - ürün(1 - pay); tek eşya kazancı ana kişinin taban süresi paydasındadır).
    """
    pool = [row for row in options if row.get("gold") and row.get("savedDays", 0) > 0]
    wallet, equipped, timeline = 0, {}, []
    for turn in range(rebirths):
        wallet += rewards[min(turn, len(rewards) - 1)]
        bought = []
        while True:
            affordable = []
            for row in pool:
                slot = row.get("slot", row["id"])
                gain = row["savedDays"] - (equipped[slot]["savedDays"] if slot in equipped else 0)
                if row["gold"] <= wallet and gain > 1e-9 and equipped.get(slot, {}).get("id") != row["id"]:
                    affordable.append((gain, -row["gold"], row["id"], row))
            if not affordable:
                break
            gain, _, _, row = max(affordable)
            wallet -= row["gold"]
            equipped[row.get("slot", row["id"])] = row
            bought.append(row["id"])
        timeline.append({"rebirth": turn + 1, "bought": bought, "wallet": wallet, "equipped": sorted(row["id"] for row in equipped.values()),
                         "savedDays": round(sum(row["savedDays"] for row in equipped.values()), 3)})
    return timeline


def scale_for_target(effect: float, current_pct: float, target_pct: float) -> float | None:
    """Etkiyi doğrusal varsayıp hedef yüzdeye ulaşmak için çarpan (ölçüm yok/sıfırsa None)."""
    if current_pct <= 0:
        return None
    return round(effect * target_pct / current_pct, 4)


def modeled_effects(item: dict) -> list[str]:
    return [key for key in item["effects"] if key not in UNMODELED_EFFECTS]


def unmodeled(item: dict) -> list[str]:
    result = [key for key in item["effects"] if key in UNMODELED_EFFECTS]
    if item.get("power"):
        result.append(f"power:{item['power']}")
    return result


def cost_of(item: dict) -> dict:
    """Karşılaştırma maliyetleri: gerçek altın bedeli, yoksa formül karşılığı (türetilmiş); nakit referans fiyat."""
    if item["channel"] == "reward":
        return {"gold": None, "goldDerived": False, "cash": None}
    gold = item.get("goldCost")
    derived = gold is None
    if derived:
        gold = formula_gold(item["price"])
    return {"gold": gold, "goldDerived": derived, "cash": None if item["noCash"] else item["price"]}


def candidates_for(items: list[dict], tier: str) -> list[dict]:
    allowed = {"starter": {"cash"}, "mid": {"cash", "cashGold"}, "premium": {"cash", "cashGold", "goldRobux", "gold"},
               "endgame": {"cash", "cashGold", "goldRobux", "gold", "reward"}}[tier]
    return [item for item in items if item["channel"] in allowed]


def best_per_slot(items: list[dict], tier: str, score: dict[str, float], slots: list[str]) -> list[str]:
    """Her yuvada ölçülmüş skoru en yüksek eşya (eşitlikte ucuz olan); skoru 0 olan eşya yuvayı doldurmaz."""
    picks = []
    pool = candidates_for(items, tier)
    for slot in slots:
        group = [item for item in pool if item["slot"] == slot and score.get(item["id"], 0) > 0]
        if group:
            best = max(group, key=lambda item: (round(score[item["id"]], 6), -(cost_of(item)["gold"] or 0), item["id"]))
            picks.append(best["id"])
    return picks


# ---------------------------------------------------------------------------
# Luau köprüsü: katalog + etki akışı sondası (gerçek Config/FarmMath)
# ---------------------------------------------------------------------------
BRIDGE = r"""
local PROBE = __SETTINGS__
local function encode(value: any): string
	local kind = typeof(value)
	if kind == "number" then
		if value ~= value or value == math.huge or value == -math.huge then
			return "null"
		end
		if value == math.floor(value) and math.abs(value) < 1e15 then
			return string.format("%d", value)
		end
		return string.format("%.9g", value)
	elseif kind == "boolean" then
		return tostring(value)
	elseif kind == "string" then
		local escaped = string.gsub(value, '[%c"\\]', function(char: string): string
			if char == '"' then
				return '\\"'
			elseif char == "\\" then
				return "\\\\"
			end
			return string.format("\\u%04x", string.byte(char))
		end)
		return `"{escaped}"`
	elseif kind == "table" then
		if #value > 0 or next(value) == nil then
			local items: { string } = {}
			for _, item in value do
				table.insert(items, encode(item))
			end
			return `[{table.concat(items, ",")}]`
		end
		local keys: { string } = {}
		for key in value do
			table.insert(keys, key)
		end
		table.sort(keys)
		local items: { string } = {}
		for _, key in keys do
			table.insert(items, `{encode(key)}:{encode(value[key])}`)
		end
		return `\{{table.concat(items, ",")}}`
	end
	return "null"
end

local START = 1036800
local NOW = START + 3600

local function newSave(equipped: { string }): any
	local save: any = {
		cash = 0, stored = 0, purchased = {}, animals = {}, barnLevel = 1, unlockedIslands = {}, unlockedZones = {},
		production = {}, autoRepeat = {}, goods = {}, lifetimeEarned = 0, activeMainFarmId = "1",
	}
	for index = 1, math.max(Config.STARTING_COW_COUNT, Config.STARTER_ADULT_ANIMALS) do
		table.insert(save.animals, { uid = `probe-{index}`, animalId = "cow", zoneId = "starter", bornAt = 0, stage = "adult" })
	end
	FarmMath.applyDerived(save)
	save.gold = 0
	save.owned = { items = {}, conveniences = {} }
	save.inventory = { items = {}, equipped = {}, uses = {} }
	save.progression = Progression.defaults(START, 0)
	for _, itemId in equipped do
		local item = Config.ITEMS[itemId]
		save.inventory.items[itemId] = true
		save.inventory.equipped[item.slot] = itemId
	end
	return save
end

-- Örnek tüketiciler: en pahalı yükseltme, bir bölge genişletmesi, en büyük partili tarif
local sampleUpgrade: any = nil
for _, upgrade in Config.UPGRADES do
	if Config.upgradeInTheme(upgrade, "1") and (sampleUpgrade == nil or upgrade.cost > sampleUpgrade.cost) then
		sampleUpgrade = upgrade
	end
end
local sampleRecipe: any = nil
for _, recipe in Config.PRODUCTION_RECIPES do
	if recipe.goodsId and recipe.goodsAmount and (sampleRecipe == nil or recipe.goodsAmount > sampleRecipe.goodsAmount) then
		sampleRecipe = recipe
	end
end

local function observe(save: any): any
	local observed: { [string]: number } = {}
	observed.income = FarmMath.computeIncomePerSecond(save, NOW)
	observed.upgradeCost = FarmMath.getUpgradeCost(save, sampleUpgrade)
	observed.expansionCost = FarmMath.getPrice(save, "expansion", "starter", 0)
	observed.storageCap = FarmMath.getStorageCap(save)
	observed.offlineRate = (FarmMath.getOfflineTerms(save))
	observed.facilitySeconds = FarmMath.getFacilityDuration(save, sampleRecipe, nil)
	observed.growthSpeed = FarmMath.getGrowthSpeed(save, "cow", "starter", NOW)
	observed.sellPrice = FarmMath.getSellPrice(save, "cow")
	observed.movement = FarmMath.getMovementSpeedMultiplier(save)
	local raw: { [string]: number } = {}
	for _, key in { "incomeBonus", "upgradeDiscount", "expansionDiscount", "sellBonus", "contractBonus", "goodsYield", "facilitySpeed", "storageBonus", "offlineBonus", "movementSpeed" } do
		raw[key] = FarmMath.getEquippedBonus(save, key)
	end
	raw.bonusContract = FarmMath.getBonus(save, "contractBonus")
	return { observed = observed, raw = raw }
end

local items = {}
local conveniences = {}
for _, id in Config.ITEM_ORDER do
	local item = Config.ITEMS[id]
	local offer = Config.PROGRESSION.permanentOffers[id]
	table.insert(items, {
		id = id, name = item.displayName, slot = item.slot, level = item.level, price = item.price,
		noCash = item.noCash == true, rewardOnly = item.rewardOnly == true, channel = Config.getItemChannel(id),
		effects = item.effects or {}, tradeoffs = item.tradeoffs or {},
		power = if item.power then item.power.kind else false, powerUses = if item.power and item.power.usesPerDay then item.power.usesPerDay else false,
		goldCost = if offer then offer.goldCost else false, robux = offer ~= nil and (offer.robuxProductId or 0) ~= 0,
	})
end
for id, offer in Config.PROGRESSION.permanentOffers do
	if offer.kind == "convenience" then
		table.insert(conveniences, { id = id, goldCost = offer.goldCost, robux = (offer.robuxProductId or 0) ~= 0 })
	end
end
table.sort(conveniences, function(a: any, b: any): boolean
	return a.id < b.id
end)
local milestones = {}
for level, milestone in Config.PROGRESSION.milestones do
	if milestone.itemId then
		table.insert(milestones, { level = level, itemId = milestone.itemId })
	end
end
local rewards = {}
for count = 0, Config.PROGRESSION.maxRebirth do
	table.insert(rewards, Progression.rebirthGoldReward({ progression = { count = count } }))
end

local recipes = {}
for id, recipe in Config.PRODUCTION_RECIPES do
	if recipe.goodsId and recipe.goodsAmount then
		table.insert(recipes, { id = id, goodsAmount = recipe.goodsAmount })
	end
end
table.sort(recipes, function(a: any, b: any): boolean
	return a.id < b.id
end)

local naked = observe(newSave({}))
local single = {}
for _, item in items do
	single[item.id] = observe(newSave({ item.id }))
end
local loadouts = {}
for name, ids in PROBE.loadouts do
	loadouts[name] = observe(newSave(ids))
end

print(encode({
	items = items, conveniences = conveniences, milestones = milestones, rewards = rewards,
	slotOrder = Config.ITEM_SLOT_ORDER, perkOrder = Config.PROGRESSION.perkOrder, maxRebirth = Config.PROGRESSION.maxRebirth,
	limits = {
		movementCap = Config.MOVEMENT_SPEED_BONUS_CAP, incomeCap = Config.PROGRESSION.permanentIncomeCap,
		offlineMaxRate = Config.OFFLINE_MAX_TOTAL_RATE, contractMax = Config.GOODS_CONTRACTS.maxBonus,
		yieldMaxMult = Config.PRODUCTION_YIELD_MAX_MULT, growthCap = Config.GROWTH_SPEED_CAP,
		discountMax = 0.9, facilityClamp = 0.5, expansionClamp = 0.5,
	},
	gold = Config.PROGRESSION.gold, recipes = recipes, maxBatch = Config.PRODUCTION_MAX_BATCH_UNITS,
	probe = { naked = naked, single = single, loadouts = loadouts, sampleUpgrade = sampleUpgrade.id, sampleRecipe = sampleRecipe.id },
}))
"""


def lua_literal(value: object) -> str:
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (int, float)):
        return repr(value)
    if isinstance(value, str):
        return json.dumps(value)
    if isinstance(value, (list, tuple)):
        return "{ " + ", ".join(lua_literal(item) for item in value) + " }"
    if isinstance(value, dict):
        return "{ " + ", ".join(f"[{lua_literal(key)}] = {lua_literal(item)}" for key, item in value.items()) + " }"
    raise TypeError(f"Luau değerine çevrilemedi: {value!r}")


def find_luau(explicit: str | None) -> str | None:
    executable = explicit or shutil.which("luau")
    if executable is None:
        bundled = ROOT / ".tools" / "luau" / ("luau.exe" if sys.platform == "win32" else "luau")
        if bundled.is_file():
            executable = str(bundled)
    return executable


def run_bridge(executable: str, loadouts: dict[str, list[str]]) -> dict:
    run_tests = _load("items_run_tests", "scripts/run-tests.py")
    module = run_tests.module
    pieces = [
        "--!nocheck\n",
        "local Color3 = { fromRGB = function(r, g, b) return { R = r / 255, G = g / 255, B = b / 255 } end }\n",
        run_tests.config_bundle(freeze=False),
        module("GameTypes", "src/shared/GameTypes.luau"),
        "local Environment = { getIncomeMultiplier = function() return 1 end }\n",
        run_tests.farm_math_bundle(),
        module("Progression", "src/shared/Modules/Progression.luau", {"Config", "FarmMath"}),
        BRIDGE.replace("__SETTINGS__", lua_literal({"loadouts": loadouts})),
    ]
    output = ROOT / ".test-build" / f"items-bridge-{os.getpid()}.luau"
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text("\n".join(pieces), encoding="utf-8")
    try:
        result = subprocess.run([executable, str(output)], cwd=ROOT, capture_output=True, check=False)
    finally:
        output.unlink(missing_ok=True)
    if result.returncode != 0:
        raise RuntimeError(result.stderr.decode("utf-8", errors="replace") + result.stdout.decode("utf-8", errors="replace"))
    return normalize(json.loads(result.stdout.decode("utf-8-sig")))


def normalize(catalog: dict) -> dict:
    """Luau boş tabloyu [] kodlar ve eksik değeri false yapar; Python'da boş sözlük/None kullan."""
    for item in catalog["items"]:
        for field in ("effects", "tradeoffs"):
            if isinstance(item[field], list):
                item[field] = {}
        for field in ("power", "powerUses", "goldCost"):
            if item[field] is False:
                item[field] = None
    return catalog


# ---------------------------------------------------------------------------
# Etki akışı denetimi: her eşya etkisi gerçek FarmMath tüketicisinde görünür mü, tavanlar tutuyor mu
# ---------------------------------------------------------------------------
def net_effect(item: dict, key: str) -> float:
    return item["effects"].get(key, 0) - item["tradeoffs"].get(key, 0)


FLOW_CHECKS = {
    # etki anahtarı: (tüketici gözlemi, beklenen oran(net etki), mutlak tolerans)
    "incomeBonus": ("income", lambda net: 1 + net, 0.002),
    "upgradeDiscount": ("upgradeCost", lambda net: 1 - net, 0.01),
    "expansionDiscount": ("expansionCost", lambda net: 1 - net, 0.06),  # fiyat 2 anlamlı basamağa yuvarlanır
    "storageBonus": ("storageCap", lambda net: 1 + net, 0.01),
    "offlineBonus": ("offlineRate", lambda net: 1 + net, 0.002),
    "facilitySpeed": ("facilitySeconds", lambda net: 1 - net, 0.03),
    "growthSpeed": ("growthSpeed", None, 0.002),
    "sellBonus": ("sellPrice", lambda net: 1 + net, 0.1),
    "movementSpeed": ("movement", lambda net: 1 + min(max(net, 0), 0.25), 0.002),
}


def flow_audit(probe: dict, items: list[dict]) -> list[dict]:
    """Tek eşya sondası: her etki için gözlenen tüketici oranı beklenenle uyuşuyor mu (yuvarlama toleranslı)."""
    findings: list[dict] = []
    naked = probe["naked"]["observed"]
    for item in items:
        observed = probe["single"][item["id"]]["observed"]
        for key in sorted(set(item["effects"]) | set(item["tradeoffs"])):
            if key in ("contractBonus", "goodsYield"):
                field = "bonusContract" if key == "contractBonus" else "goodsYield"
                got = probe["single"][item["id"]]["raw"][field] - probe["naked"]["raw"][field]
                expected = net_effect(item, key)
                ok = abs(got - expected) < 1e-9
                findings.append({"item": item["id"], "key": key, "expected": expected, "observed": got, "ok": ok})
                continue
            if key == "growthSpeed":
                ratio = observed["growthSpeed"] - naked["growthSpeed"]
                expected = item["effects"].get(key, 1) - 1
                ok = ratio > 0 if expected > 0 else abs(ratio) < 1e-6
                findings.append({"item": item["id"], "key": key, "expected": expected, "observed": ratio, "ok": ok})
                continue
            consumer, expected_ratio, tolerance = FLOW_CHECKS[key]
            if not naked[consumer]:
                continue
            ratio = observed[consumer] / naked[consumer]
            expected = expected_ratio(net_effect(item, key))
            findings.append({"item": item["id"], "key": key, "expected": round(expected, 6), "observed": round(ratio, 6),
                             "ok": abs(ratio - expected) <= tolerance})
    return findings


def cap_audit(probe: dict, items: list[dict], loadouts: dict[str, list[str]], limits: dict) -> list[dict]:
    """Takım başına ham toplam ile tüketicinin tavanlanmış gözlemi; tavanı aşan sızıntıyı ve devreye giren tavanı bildirir."""
    by_id = {item["id"]: item for item in items}
    rows: list[dict] = []
    naked = probe["naked"]["observed"]
    for name, ids in loadouts.items():
        result = probe["loadouts"][name]
        observed, raw = result["observed"], result["raw"]
        sums = {key: sum(net_effect(by_id[item_id], key) for item_id in ids) for key in
                ("incomeBonus", "movementSpeed", "upgradeDiscount", "facilitySpeed", "offlineBonus", "goodsYield", "storageBonus")}
        income_ratio = observed["income"] / naked["income"] if naked["income"] else 1
        checks = [
            ("movement", sums["movementSpeed"], observed["movement"] - 1, limits["movementCap"], observed["movement"] - 1 <= limits["movementCap"] + 1e-9),
            ("income", sums["incomeBonus"], income_ratio - 1, limits["incomeCap"] - 1, income_ratio <= limits["incomeCap"] + 1e-9),
            ("upgradeDiscount", sums["upgradeDiscount"], 1 - observed["upgradeCost"] / naked["upgradeCost"], limits["discountMax"],
             1 - observed["upgradeCost"] / naked["upgradeCost"] <= limits["discountMax"] + 1e-3),
            ("facilitySpeed", sums["facilitySpeed"], 1 - observed["facilitySeconds"] / naked["facilitySeconds"], limits["facilityClamp"],
             1 - observed["facilitySeconds"] / naked["facilitySeconds"] <= limits["facilityClamp"] + 0.03),
            ("offlineRate", naked["offlineRate"] * (1 + sums["offlineBonus"]), observed["offlineRate"], limits["offlineMaxRate"],
             observed["offlineRate"] <= limits["offlineMaxRate"] + 1e-9),
        ]
        for label, raw_sum, effective, cap, within in checks:
            rows.append({"loadout": name, "key": label, "rawSum": round(raw_sum, 4), "effective": round(effective, 4), "cap": round(cap, 4),
                         "capBinds": raw_sum > cap + 1e-9, "ok": within})
    return rows


# ---------------------------------------------------------------------------
# Koşu
# ---------------------------------------------------------------------------
def source_hash() -> str:
    digest = hashlib.sha256()
    for pattern in SOURCE_GLOBS:
        for path in sorted(ROOT.glob(pattern)):
            digest.update(path.name.encode())
            digest.update(path.read_bytes())
    return digest.hexdigest()[:16]


class Runner:
    """Simülasyon koşuları: önbellekli (kaynak karması değişince geçersiz), thread havuzuyla paralel."""

    def __init__(self, luau: str, perk_order: list[str], cache_path: Path | None, workers: int):
        self.luau, self.perk_order, self.cache_path, self.workers = luau, perk_order, cache_path, workers
        self.comparison = _load("items_rebirth", "scripts/simulate-rebirth.py")
        self.lock = threading.Lock()
        self.hash = source_hash()
        self.cache: dict[str, dict] = {}
        if cache_path and cache_path.is_file():
            try:
                stored = json.loads(cache_path.read_text(encoding="utf-8"))
                if stored.get("hash") == self.hash:
                    self.cache = stored["runs"]
            except (OSError, ValueError, KeyError):
                self.cache = {}
        self.done = 0
        self.total = 0

    def key(self, persona: str, rebirth: int, equipment: tuple[str, ...], conveniences: tuple[str, ...], free: bool = False,
            overrides: tuple[str, ...] = ()) -> str:
        return f"{persona}|{rebirth}|{','.join(sorted(equipment))}|{','.join(sorted(conveniences))}|{'free' if free else 'naked'}|{','.join(overrides)}"

    def run_one(self, persona: str, rebirth: int, equipment: tuple[str, ...], conveniences: tuple[str, ...], free: bool = False,
                overrides: tuple[str, ...] = ()) -> dict:
        """free=True: rebirth'ün ücretsiz kilometre taşı eşyaları takılı; aksi halde yalın taban (hepsi çıkarılmış)."""
        key = self.key(persona, rebirth, equipment, conveniences, free, overrides)
        with self.lock:
            hit = self.cache.get(key)
        if hit is None:
            extra: list[str] = []
            if rebirth:
                extra += ["--rebirth", str(rebirth), "--perks", perks_for(rebirth, self.perk_order)]
                if not free:
                    extra += ["--clear-equipment"]
            if equipment:
                extra += ["--equipment", ",".join(equipment)]
            if conveniences:
                extra += ["--conveniences", ",".join(conveniences)]
            if overrides:
                extra += ["--item-effect", ",".join(overrides)]
            extra += ["--luau", self.luau]
            row = self.comparison.run(persona, "items", extra)
            hit = {"calendarDays": row["calendarHours"] / 24, "activeHours": row["activeHours"],
                   "equipped": ((row["account"].get("inventory") or {}).get("equipped")) or {}}
            with self.lock:
                self.cache[key] = hit
                self.write_cache()
        with self.lock:
            self.done += 1
            if self.done % 10 == 0 or self.done == self.total:
                print(f"  {self.done}/{self.total} koşu tamam", flush=True)
        return hit

    def write_cache(self) -> None:
        if self.cache_path:
            self.cache_path.parent.mkdir(parents=True, exist_ok=True)
            self.cache_path.write_text(json.dumps({"hash": self.hash, "runs": self.cache}), encoding="utf-8")

    def run_many(self, jobs: list[tuple]) -> list[dict]:
        self.done, self.total = 0, len(jobs)
        with ThreadPoolExecutor(max_workers=self.workers) as pool:
            return [future.result() for future in [pool.submit(self.run_one, *job) for job in jobs]]


def measure(base: float, days: float, persona: str) -> dict:
    saved = base - days
    return {"days": round(days, 4), "savedDays": round(saved, 4), "pct": round(saved / base * 100, 3),
            "belowResolution": abs(saved) <= QUANTUM_DAYS[persona] + 1e-6}


def evaluate(runner: Runner, catalog: dict, states: list[tuple[str, int]], item_ids: list[str] | None, skip_singles: bool) -> dict:
    items = catalog["items"]
    conveniences = catalog["conveniences"]
    singles = [item for item in items if item["channel"] != "none" and (item_ids is None or item["id"] in item_ids)]
    conv = [row for row in conveniences if item_ids is None or row["id"] in item_ids]
    print(f"Durumlar: {', '.join(state_key(*state) for state in states)}; {len(singles)} eşya + {len(conv)} kolaylık", flush=True)

    base_jobs = [(persona, rebirth, (), ()) for persona, rebirth in states]
    bases = runner.run_many(base_jobs)
    baseline = {state_key(*state): row["calendarDays"] for state, row in zip(states, bases)}
    print("Taban (yalın):", {key: round(value, 3) for key, value in baseline.items()}, flush=True)
    free_states = [state for state in states if state[1] > 0]
    free = {state_key(*state): row["calendarDays"] for state, row in zip(free_states, runner.run_many([(p, r, (), (), True) for p, r in free_states]))}

    results: dict[str, dict[str, dict]] = {}
    if not skip_singles:
        jobs, labels = [], []
        for item in singles:
            for persona, rebirth in states:
                jobs.append((persona, rebirth, (item["id"],), ()))
                labels.append((item["id"], persona, rebirth))
        for row in conv:
            for persona, rebirth in states:
                jobs.append((persona, rebirth, (), (row["id"],)))
                labels.append((row["id"], persona, rebirth))
        for (item_id, persona, rebirth), row in zip(labels, runner.run_many(jobs)):
            results.setdefault(item_id, {})[state_key(persona, rebirth)] = measure(baseline[state_key(persona, rebirth)], row["calendarDays"], persona)
    return {"baseline": baseline, "free": free, "singles": results}


def build_item_rows(catalog: dict, singles: dict[str, dict], states: list[tuple[str, int]]) -> list[dict]:
    rows = []
    for item in catalog["items"]:
        if item["channel"] == "none":
            continue
        cost = cost_of(item)
        rows.append({"id": item["id"], "name": item["name"], "kind": "item", "slot": item["slot"], "level": item["level"],
                     "channel": item["channel"], "price": item["price"], "effects": item["effects"], "tradeoffs": item["tradeoffs"],
                     "power": item["power"], "modeled": modeled_effects(item), "unmodeled": unmodeled(item),
                     "gold": cost["gold"], "goldDerived": cost["goldDerived"], "cash": cost["cash"],
                     "robux": item["robux"], "results": singles.get(item["id"], {})})
    for row in catalog["conveniences"]:
        rows.append({"id": row["id"], "name": row["id"], "kind": "convenience", "slot": "convenience", "level": 0,
                     "channel": "gold", "price": 0, "effects": {}, "tradeoffs": {}, "power": False, "modeled": [], "unmodeled": [],
                     "gold": row["goldCost"], "goldDerived": False, "cash": None, "robux": row["robux"],
                     "results": singles.get(row["id"], {})})
    return rows


def primary_state(states: list[tuple[str, int]]) -> str:
    """Sıralama/analiz için ana durum: en yüksek rebirth'teki ideal, yoksa ilk durum."""
    ideals = [state for state in states if state[0] == "ideal"]
    return state_key(*(max(ideals, key=lambda state: state[1]) if ideals else states[0]))


def ols(xs: list[float], ys: list[float]) -> tuple[float, float]:
    """En küçük kareler doğrusu y = a + b*x (a, b); veri yetersizse (0, 0)."""
    if len(xs) < 2 or len(set(xs)) < 2:
        return 0.0, 0.0
    mx, my = statistics.fmean(xs), statistics.fmean(ys)
    slope = sum((x - mx) * (y - my) for x, y in zip(xs, ys)) / sum((x - mx) ** 2 for x in xs)
    return my - slope * mx, slope


def loadout_scores(rows: list[dict], states: list[tuple[str, int]], rebirth: int) -> dict[str, float]:
    """Takım seçimi skoru: o rebirth düzeyindeki tüm kişilerin yüzde kazancı ortalaması."""
    keys = [state_key(*state) for state in states if state[1] == rebirth]
    scores: dict[str, float] = {}
    for row in rows:
        if row["kind"] != "item":
            continue
        values = [effective_pct(row["results"][key], key) for key in keys if key in row["results"]]
        if values:
            scores[row["id"]] = statistics.fmean(values)
    return scores


def analyze(rows: list[dict], loadouts: dict[str, dict], catalog: dict, states: list[tuple[str, int]], baseline: dict[str, float]) -> dict:
    primary = primary_state(states)
    items = [row for row in rows if row["kind"] == "item"]
    measured = [row for row in items if primary in row["results"]]
    analysis: dict = {"primary": primary, "deadPct": DEAD_PCT, "strongPct": STRONG_PCT}

    def pct(row: dict, key: str = primary) -> float | None:
        return row["results"][key]["pct"] if key in row["results"] else None

    purchasable = [row for row in measured if row["gold"]]
    analysis["dead"] = [row["id"] for row in measured if pct(row) is not None and pct(row) < DEAD_PCT and row["modeled"]]
    analysis["unmeasurable"] = [row["id"] for row in measured if not row["modeled"]]
    analysis["strong"] = [row["id"] for row in measured if (pct(row) or 0) > STRONG_PCT]

    # Altın formülü tutarlılığı: altın bedeli ile ölçülen fayda ilişkisi
    xs = [row["gold"] for row in purchasable if row["modeled"]]
    ys = [pct(row) for row in purchasable if row["modeled"]]
    analysis["goldVsBenefitSpearman"] = spearman(xs, ys) if xs else None
    by_level: dict[str, dict] = {}
    for level in sorted({row["level"] for row in purchasable}):
        group = [row for row in purchasable if row["level"] == level]
        by_level[str(level)] = {"count": len(group), "medianGold": statistics.median(row["gold"] for row in group),
                                "medianPct": round(statistics.median(pct(row) for row in group), 3),
                                "maxPct": round(max(pct(row) for row in group), 3),
                                "pctPer100Gold": round(statistics.median(pct(row) / row["gold"] * 100 for row in group), 4)}
    analysis["byLevel"] = by_level
    gold_formula_diffs = [{"id": row["id"], "price": row["price"], "gold": row["gold"], "formula": formula_gold(row["price"])}
                          for row in items if row["gold"] and not row["goldDerived"] and row["channel"] != "reward"
                          and row["gold"] != formula_gold(row["price"])]
    analysis["goldFormulaMismatches"] = gold_formula_diffs
    analysis["inversionsByGold"] = ordering_inversions([dict(row, cost=row["gold"], pct=pct(row)) for row in purchasable if row["modeled"]])
    # Ödül eşyaları ödüllü olmayan aynı yuvadaki eşyalarla ilişkilendirilir (altınsız): ayrı rapor
    analysis["rewardItems"] = [{"id": row["id"], "slot": row["slot"], "pct": pct(row)} for row in measured if row["channel"] == "reward"]

    # Çok kişili sınıflandırma: aynı rebirth düzeyindeki tüm kişilerden en iyisi (gürültü tabanı altı 0 sayılır)
    reference = int(primary.split("R")[1])
    keys = [state_key(persona, rebirth) for persona, rebirth in states if rebirth == reference]
    per_item: dict[str, dict] = {}
    for row in measured:
        values = {key: effective_pct(row["results"].get(key), key) for key in keys}
        best = max((value for value in values.values() if value is not None), default=None)
        per_item[row["id"]] = {"byState": values, "best": best, "class": classify(best) if row["modeled"] else "unmeasured"}
    analysis["perItem"] = per_item
    analysis["deadAll"] = [item_id for item_id, entry in per_item.items() if entry["class"] == "dead"]
    analysis["offlineDriven"] = [item_id for item_id, entry in per_item.items()
                                 if (entry["byState"].get(primary) or 0) < DEAD_PCT and (entry["best"] or 0) >= 4.0]
    analysis["strongAny"] = [item_id for item_id, entry in per_item.items() if (entry["best"] or 0) > STRONG_PCT]
    fit_rows = [row for row in purchasable if row["modeled"] and (per_item[row["id"]]["best"] or 0) >= DEAD_PCT]
    intercept, slope = ols([row["gold"] for row in fit_rows], [per_item[row["id"]]["best"] for row in fit_rows])
    analysis["fit"] = {"intercept": round(intercept, 4), "pctPerGold": round(slope, 6), "points": len(fit_rows)}
    suggestions = []
    for row in purchasable:
        best = per_item[row["id"]]["best"]
        if best is None or row["channel"] == "reward":
            continue
        fair = max(0.0, intercept + slope * row["gold"])
        fair_gold = None if slope <= 0 or best is None else int(min(1500, max(150, math.floor((max(best, 0) - intercept) / slope / 10 + 0.5) * 10)))
        verdict = "ok"
        if not row["modeled"]:
            verdict = "unmeasured"
        elif best > STRONG_PCT and best > 1.6 * fair:
            verdict = "nerf"
        elif best < 0.5 * fair and fair >= 1.0:
            verdict = "buff-or-reprice"
        suggestions.append({"id": row["id"], "gold": row["gold"], "best": best, "fairPctAtGold": round(fair, 2),
                            "fairGoldAtBenefit": fair_gold, "verdict": verdict})
    analysis["suggestions"] = suggestions

    # Kademe sırası: yuva başına her kademenin en iyi (gürültü tabanlı) faydası; kademe artarken düşüş = sıra ihlali
    tier_best: dict[str, dict[str, float]] = {}
    for row in purchasable:
        if row["modeled"]:
            level_best = tier_best.setdefault(row["slot"], {})
            level_best[str(row["level"])] = max(level_best.get(str(row["level"]), -99.0), per_item[row["id"]]["best"] or 0)
    analysis["tierBestBySlot"] = tier_best
    analysis["tierInversions"] = [{"slot": slot, "lowerLevel": int(low), "upperLevel": int(high), "lowerBest": levels[low], "upperBest": levels[high]}
                                  for slot, levels in tier_best.items() for low in sorted(levels) for high in sorted(levels)
                                  if int(high) > int(low) and levels[high] + 0.5 < levels[low]]

    # Rebirth altını ile erişilebilirlik
    rewards = catalog["rewards"]
    cumulative = cumulative_gold(rewards, catalog["maxRebirth"])
    analysis["rebirthGold"] = {"perRebirth": rewards[:6] + [rewards[-1]], "cumulative": cumulative}
    options = [{"id": row["id"], "gold": row["gold"], "slot": row["slot"],
                "savedDays": (row["results"][primary]["savedDays"] if primary in row["results"] else 0)}
               for row in rows if row["gold"] and row["kind"] in {"item", "convenience"}]
    analysis["greedy"] = greedy_purchases([option for option in options if option["gold"] and not any(
        r["id"] == option["id"] and r["goldDerived"] for r in rows)], rewards, 30)
    for name, loadout in loadouts.items():
        # Kalıcı sahiplik maliyeti (altın eşdeğeri; yalnız nakit satılan eşya için formül karşılığı); ödül eşyaları ücretsizdir.
        gold = sum(row["gold"] or 0 for row in items if row["id"] in loadout["items"] and row["channel"] != "reward")
        loadout["goldCost"] = gold
        loadout["rebirthToAfford"] = rebirth_to_afford(cumulative, gold) if gold else 0
    return analysis


def loadouts_for(rows: list[dict], catalog: dict, states: list[tuple[str, int]]) -> dict[str, dict]:
    """Tier başına yuva başına ölçülmüş en iyi eşya (R5 ağırlıklı; R5 yoksa en yüksek rebirth)."""
    levels = sorted({state[1] for state in states})
    reference = 5 if 5 in levels else levels[-1]
    scores = loadout_scores(rows, states, reference)
    items = [item for item in catalog["items"] if item["channel"] != "none"]
    result = {}
    for tier in ("starter", "mid", "premium", "endgame"):
        picks = best_per_slot(items, tier, scores, catalog["slotOrder"])
        result[tier] = {"items": picks, "scoreRebirth": reference}
    return result


# ---------------------------------------------------------------------------
# Çıktı
# ---------------------------------------------------------------------------
def fmt(value: float | None, digits: int = 2) -> str:
    return "-" if value is None else f"{value:.{digits}f}"


def render(report: dict) -> str:
    lines: list[str] = []
    states = report["states"]
    keys = [state_key(persona, rebirth) for persona, rebirth in states]
    lines.append("TABAN, yalın (takvim günü): " + ", ".join(f"{key} {report['baseline'][key]:.2f}" for key in keys))
    if report.get("freeLoadout"):
        lines.append("Ücretsiz kilometre taşı eşyaları takılıyken: " + ", ".join(f"{key} {row['days']:.2f} ({row['pct']:+.1f}%)" for key, row in report["freeLoadout"].items()))
    lines.append("")
    primary = report["analysis"]["primary"]
    rows = [row for row in report["items"] if primary in row["results"]]
    rows.sort(key=lambda row: -row["results"][primary]["pct"])
    header = f"{'eşya':24} {'yuva':8} {'k':>2} {'kanal':9} {'altın':>6} " + " ".join(f"{key + ' %':>11}" for key in keys) + f" {'gün/100alt':>10} {'gün/Mnakit':>10}  modellenmeyen"
    lines.append(header)
    for row in rows:
        results = row["results"]
        cells = " ".join(f"{fmt(results[key]['pct']) if key in results else '-':>11}" for key in keys)
        saved = results[primary]["savedDays"]
        per_gold = saved / row["gold"] * 100 if row["gold"] else None
        per_cash = saved / row["cash"] * 1e6 if row["cash"] else None
        marker = "*" if row["goldDerived"] else " "
        lines.append(f"{row['id']:24} {row['slot']:8} {row['level']:>2} {row['channel']:9} {(str(row['gold']) + marker) if row['gold'] else '-':>6} {cells} "
                     f"{fmt(per_gold, 3):>10} {fmt(per_cash, 3):>10}  {','.join(row['unmodeled'])}")
    lines.append("(* altın bedeli formül karşılığıdır; eşya yalnız nakitle satılır)")
    lines.append("")
    lines.append("TAKIMLAR")
    for name, loadout in report["loadouts"].items():
        cells = ", ".join(f"{key}: {fmt(loadout['results'][key]['pct'])}% ({fmt(loadout['results'][key]['savedDays'])} g)" for key in keys if key in loadout["results"])
        lines.append(f"  {name:8} [{', '.join(loadout['items'])}] altın {loadout['goldCost']} rebirth {loadout['rebirthToAfford']} -> {cells}")
    return "\n".join(lines)


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    try:
        states = parse_states(args.states)
        if args.idle:
            states = parse_states(",".join([state_key(*s).replace("R", "") for s in states] + [f"idle:{level}" for level in sorted({s[1] for s in states})]))
    except ValueError as error:
        parser.error(str(error))
    luau = find_luau(args.luau)
    if luau is None:
        parser.error("Luau yorumlayıcısı bulunamadı; --luau ile yol ver.")
    sys.stdout.reconfigure(encoding="utf-8")
    item_ids = [part.strip() for part in args.items.split(",") if part.strip()] or None
    started = time.time()
    catalog = run_bridge(luau, {})
    if args.probe:
        return print_probe(catalog, luau, args)
    if args.reanalyze:
        return reanalyze(args, luau, catalog)
    if args.what_if:
        return what_if(args, luau, catalog, states)
    cache_path = None if args.no_cache else ROOT / args.cache
    runner = Runner(luau, catalog["perkOrder"], cache_path, args.workers)
    evaluated = evaluate(runner, catalog, states, item_ids, args.skip_singles)
    rows = build_item_rows(catalog, evaluated["singles"], states)
    loadouts = {} if args.skip_loadouts else loadouts_for(rows, catalog, states)
    baseline = evaluated["baseline"]
    if loadouts:
        jobs, labels = [], []
        for name, loadout in loadouts.items():
            for persona, rebirth in states:
                jobs.append((persona, rebirth, tuple(loadout["items"]), ()))
                labels.append((name, persona, rebirth))
        print(f"Takımlar: {len(jobs)} koşu", flush=True)
        for (name, persona, rebirth), row in zip(labels, runner.run_many(jobs)):
            loadouts[name].setdefault("results", {})[state_key(persona, rebirth)] = measure(baseline[state_key(persona, rebirth)], row["calendarDays"], persona)
        singles_sum = {}
        for name, loadout in loadouts.items():
            for key in loadout.get("results", {}):
                singles_sum[key] = sum(row["results"][key]["pct"] for row in rows if row["id"] in loadout["items"] and key in row["results"])
            loadout["sumOfSinglesPct"] = {key: round(value, 3) for key, value in singles_sum.items()}
    probe_data = run_bridge(luau, {name: loadout["items"] for name, loadout in loadouts.items()})
    items_only = [item for item in catalog["items"] if item["channel"] != "none"]
    flow = flow_audit(probe_data["probe"], items_only)
    caps = cap_audit(probe_data["probe"], items_only, {name: loadout["items"] for name, loadout in loadouts.items()}, catalog["limits"]) if loadouts else []
    analysis = analyze(rows, loadouts, catalog, states, baseline) if rows else {}
    free = {key: measure(baseline[key], days, key.split(":")[0]) for key, days in evaluated["free"].items()}
    report = {"limitations": __doc__, "schema": 1, "states": states, "baseline": baseline, "freeLoadout": free, "items": rows, "loadouts": loadouts,
              "analysis": analysis, "flowAudit": flow, "capAudit": caps, "limits": catalog["limits"], "rewards": catalog["rewards"],
              "seconds": round(time.time() - started, 1), "sourceHash": runner.hash}
    output = ROOT / args.output
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(report, ensure_ascii=False, indent=1), encoding="utf-8")
    if rows and any(primary_state(states) in row["results"] for row in rows):
        print(render(report))
    print(f"\nYazıldı: {output} ({report['seconds']} sn)")
    bad = [row for row in flow if not row["ok"]]
    if bad:
        print(f"UYARI: {len(bad)} etki tüketiciye beklenen oranda akmıyor (--probe ile bak)")
    return 0


def parse_what_if(text: str) -> dict[str, list[tuple[str, float]]]:
    """'kimlik:etki=değer,etki=değer;kimlik2:etki=değer' -> {kimlik: [(etki, değer)]}."""
    result: dict[str, list[tuple[str, float]]] = {}
    for part in [part.strip() for part in text.split(";") if part.strip()]:
        item_id, _, effects = part.partition(":")
        pairs = []
        for pair in [pair.strip() for pair in effects.split(",") if pair.strip()]:
            key, _, value = pair.partition("=")
            try:
                pairs.append((key, float(value)))
            except ValueError as error:
                raise ValueError(f"Geçersiz what-if {pair!r}: etki=değer olmalı") from error
        if not item_id or not pairs:
            raise ValueError(f"Geçersiz what-if {part!r}: kimlik:etki=değer biçiminde olmalı")
        result[item_id] = pairs
    if not result:
        raise ValueError("what-if boş")
    return result


def what_if(args: argparse.Namespace, luau: str, catalog: dict, states: list[tuple[str, int]]) -> int:
    """Önerilen etki değerlerini Config'e dokunmadan dener: mevcut ve değiştirilmiş değerle tek eşya kazancı."""
    try:
        specs = parse_what_if(args.what_if)
    except ValueError as error:
        raise SystemExit(f"hata: {error}")
    known = {item["id"] for item in catalog["items"]}
    unknown = [item_id for item_id in specs if item_id not in known]
    if unknown:
        raise SystemExit(f"hata: bilinmeyen eşya {unknown}")
    runner = Runner(luau, catalog["perkOrder"], None if args.no_cache else ROOT / args.cache, args.workers)
    base_days = {state_key(*state): row["calendarDays"] for state, row in zip(states, runner.run_many([(p, r, (), ()) for p, r in states]))}
    jobs, labels = [], []
    for item_id, pairs in specs.items():
        overrides = tuple(f"{item_id}:{key}={value}" for key, value in pairs)
        for persona, rebirth in states:
            jobs.append((persona, rebirth, (item_id,), (), False, ()))
            labels.append((item_id, persona, rebirth, "current"))
            jobs.append((persona, rebirth, (item_id,), (), False, overrides))
            labels.append((item_id, persona, rebirth, "proposed"))
    rows: dict[str, dict] = {}
    for (item_id, persona, rebirth, variant), row in zip(labels, runner.run_many(jobs)):
        key = state_key(persona, rebirth)
        rows.setdefault(item_id, {}).setdefault(key, {})[variant] = measure(base_days[key], row["calendarDays"], persona)
    sys.stdout.reconfigure(encoding="utf-8")
    print("WHAT-IF (yalın tabana göre kazanılan yüzde; öneri = Config'e yazılmamış deneme)")
    for item_id, by_state in rows.items():
        change = ", ".join(f"{key}={value}" for key, value in specs[item_id])
        print(f"  {item_id} [{change}]")
        for key, variants in by_state.items():
            print(f"     {key:11} şimdi {variants['current']['pct']:6.2f}% ({variants['current']['savedDays']:.2f} g) -> öneri {variants['proposed']['pct']:6.2f}% ({variants['proposed']['savedDays']:.2f} g)")
    output = ROOT / args.output
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps({"schema": 1, "mode": "what-if", "baseline": base_days, "specs": {k: v for k, v in specs.items()}, "rows": rows}, ensure_ascii=False, indent=1), encoding="utf-8")
    return 0


def reanalyze(args: argparse.Namespace, luau: str, catalog: dict) -> int:
    """Önceki koşu çıktısındaki ölçümlerden analizi ve denetimleri yeniden üretir (simülasyon çalıştırmaz)."""
    old = json.loads((ROOT / args.reanalyze).read_text(encoding="utf-8"))
    states = [tuple(state) for state in old["states"]]
    loadouts = old["loadouts"]
    names = {name: loadout["items"] for name, loadout in loadouts.items()}
    probe_data = run_bridge(luau, names)
    items_only = [item for item in catalog["items"] if item["channel"] != "none"]
    old["flowAudit"] = flow_audit(probe_data["probe"], items_only)
    old["capAudit"] = cap_audit(probe_data["probe"], items_only, names, catalog["limits"]) if names else []
    old["analysis"] = analyze(old["items"], loadouts, catalog, states, old["baseline"])
    old["limits"], old["rewards"] = catalog["limits"], catalog["rewards"]
    sys.stdout.reconfigure(encoding="utf-8")
    output = ROOT / args.output
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(old, ensure_ascii=False, indent=1), encoding="utf-8")
    print(render(old))
    print(f"\nYazıldı: {output}")
    return 0


def print_probe(catalog: dict, luau: str, args: argparse.Namespace) -> int:
    items = [item for item in catalog["items"] if item["channel"] != "none"]
    flow = flow_audit(catalog["probe"], items)
    bad = [row for row in flow if not row["ok"]]
    print(f"Etki akışı: {len(flow)} etki, {len(flow) - len(bad)} uyumlu, {len(bad)} uyumsuz")
    for row in bad:
        print(f"  UYUMSUZ {row['item']}.{row['key']}: beklenen {row['expected']}, gözlenen {row['observed']}")
    levels = {}
    for item in items:
        levels.setdefault(item["slot"], {})
    # En yüksek yığılma: her etki için yuva başına en büyük net değer toplamı (tavan baskısı)
    ceiling = {}
    for key in ("incomeBonus", "movementSpeed", "upgradeDiscount", "facilitySpeed", "offlineBonus", "storageBonus", "goodsYield", "contractBonus", "expansionDiscount", "sellBonus"):
        ceiling[key] = sum(max([net_effect(item, key) for item in items if item["slot"] == slot] + [0]) for slot in catalog["slotOrder"])
    limits = catalog["limits"]
    print("Yuva başına en iyi değerlerin teorik toplamı (kuramsal üst sınır):")
    for key, value in ceiling.items():
        cap = {"incomeBonus": limits["incomeCap"] - 1, "movementSpeed": limits["movementCap"], "upgradeDiscount": limits["discountMax"],
               "facilitySpeed": limits["facilityClamp"], "offlineBonus": limits["offlineMaxRate"], "contractBonus": limits["contractMax"],
               "expansionDiscount": limits["expansionClamp"]}.get(key)
        note = "" if cap is None else (f"  (tavan {cap}: {'AŞIYOR' if value > cap else 'altında'})")
        print(f"  {key:18} {value:.3f}{note}")
    return 1 if bad else 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--luau", help="Luau yorumlayıcısı yolu")
    parser.add_argument("--states", default=DEFAULT_STATES, help="Ölçülecek durumlar kişi:rebirth (virgülle); ilk ideal en yüksek rebirth ana durumdur")
    parser.add_argument("--idle", action="store_true", help="Seçilen her rebirth düzeyi için idle kişisini de ekle (yavaş)")
    parser.add_argument("--items", default="", help="Yalnız bu eşya/kolaylık kimlikleri (virgülle); boşsa hepsi")
    parser.add_argument("--skip-singles", action="store_true", help="Tek eşya koşularını atla (yalnız taban ve takımlar)")
    parser.add_argument("--skip-loadouts", action="store_true", help="Standart takım koşularını atla")
    parser.add_argument("--workers", type=int, default=12, help="Paralel simülasyon sayısı")
    parser.add_argument("--reanalyze", default="", help="Önceki JSON çıktıdan analizi yeniden üret (koşu yok)")
    parser.add_argument("--what-if", default="", help="Etki değişikliğini dene: kimlik:etki=değer,etki=değer;kimlik2:... (Config'e yazılmaz)")
    parser.add_argument("--probe", action="store_true", help="Koşusuz etki akışı ve tavan denetimi (saniyeler)")
    parser.add_argument("--output", default=".test-build/items-power.json", help="JSON çıktı yolu")
    parser.add_argument("--cache", default=".test-build/items-cache.json", help="Koşu önbelleği (kaynak karması değişince geçersiz)")
    parser.add_argument("--no-cache", action="store_true", help="Önbelleği kullanma ve yazma")
    return parser


if __name__ == "__main__":
    raise SystemExit(main())
