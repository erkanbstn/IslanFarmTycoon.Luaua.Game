#!/usr/bin/env python3
"""Ekonomi simülasyonu: Config değerleriyle "ideal oyuncu" ilerlemesini hesaplar.

Oyuncu her an kasası yettiği en iyi yatırımı alır (önce hayvan, sonra en ucuz yükseltme), parayı
anında toplar ve hiç boş durmaz. Çıktı: her önemli adıma kaç dakikada ulaşıldığı ve saatlik gelir.
Gerçek FarmMath/Config kullanılır (scripts/run-tests.py ile aynı birleştirme).

Kullanım:  python scripts/simulate-economy.py [--hours 8] [--farm 1..6] [--luau PATH]
"""

from __future__ import annotations

import argparse
import importlib.util
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("run_tests", ROOT / "scripts" / "run-tests.py")
run_tests = importlib.util.module_from_spec(spec)
spec.loader.exec_module(run_tests)  # type: ignore[union-attr]

SIMULATION = r"""
local HOURS = __HOURS__
local FARM = "__FARM__"
-- Ayar denemesi: yükseltme maliyetlerini (cost/BASE)^EXP ile büyüt, hayvan fiyat artışını değiştir (Config'e dokunmadan)
local COST_BASE, COST_EXP, PRICE_GROWTH = __COST_BASE__, __COST_EXP__, __PRICE_GROWTH__
if COST_EXP > 0 then
	for _, upgrade in Config.UPGRADES do
		if upgrade.cost > COST_BASE then
			local scaled = upgrade.cost * (upgrade.cost / COST_BASE) ^ COST_EXP
			local digits = 10 ^ (math.floor(math.log10(scaled)) - 1)
			upgrade.cost = math.floor(scaled / digits + 0.5) * digits
		end
	end
end
if PRICE_GROWTH > 0 then
	Config.ANIMAL_PRICE_GROWTH = PRICE_GROWTH
end
local STEP = 5 -- saniye
local START = 1000000

local save: any = {
	cash = Config.STARTING_CASH,
	stored = 0,
	purchased = {},
	animals = {},
	barnLevel = 1,
	unlockedIslands = {},
	unlockedZones = {},
	ordersCompleted = 0,
	production = {},
	activeMainFarmId = FARM,
}
local homeAnimal = Config.getHomeAnimal(FARM)
for index = 1, Config.STARTING_COW_COUNT do
	table.insert(save.animals, { uid = `start-{index}`, animalId = homeAnimal, zoneId = "starter", bornAt = 0, stage = "adult" })
end
FarmMath.applyDerived(save)

local themeIslands = FarmMath.themeIslands(save)
local function inTheme(upgrade: any): boolean
	return table.find(themeIslands, Config.getUpgradeIsland(upgrade)) ~= nil
end

local now = START
local milestones: { [string]: number } = {}
local order: { string } = {}
local function mark(name: string)
	if milestones[name] == nil then
		milestones[name] = (now - START) / 60
		table.insert(order, name)
	end
end

local function refreshStages()
	for _, animal in save.animals do
		animal.stage = FarmMath.getStage(animal.bornAt, now, FarmMath.getGrowthSpeed(save, animal.animalId))
	end
end

local function income(): number
	return FarmMath.computeIncomePerSecond(save)
end

local uidCounter = 0
local function buyAnimal(animalId: string, zoneId: string)
	uidCounter += 1
	save.cash -= FarmMath.getAnimalPrice(save, animalId)
	table.insert(save.animals, { uid = `sim-{uidCounter}`, animalId = animalId, zoneId = zoneId, bornAt = now, stage = "calf" })
	local count = FarmMath.countAnimals(save, animalId)
	if count == 1 then
		mark(`ilk {animalId}`)
	end
	if count == 10 then
		mark(`10. {animalId}`)
	end
end

local function buyUpgrade(upgrade: any)
	local speeds: { [string]: number } = {}
	for animalId in Config.ANIMALS do
		speeds[animalId] = FarmMath.getGrowthSpeed(save, animalId)
	end
	save.cash -= upgrade.cost
	save.purchased[upgrade.id] = true
	FarmMath.applyDerived(save)
	FarmMath.preserveGrowthProgress(save, speeds, now)
	mark(upgrade.id)
end

-- Bir hayvanın yetişkin olunca getireceği artış (ölçü: yatırımın geri dönüş süresi)
local function animalGain(animalId: string): number
	return FarmMath.getAnimalIncome(save, animalId)
end

local function upgradeGain(upgrade: any): number
	local before = income()
	save.purchased[upgrade.id] = true
	local after = income()
	save.purchased[upgrade.id] = nil
	return math.max(after - before, 0)
end

local cashSpent = 0
local lastReport = 0
local reports: { string } = {}
local steps = math.floor(HOURS * 3600 / STEP)
for step = 1, steps do
	now = START + step * STEP
	refreshStages()
	save.cash += income() * STEP

	-- Aç gözlü yatırım: hayvanlar önce (geri dönüşü en hızlı), sonra en ucuz yükseltme
	local bought = true
	while bought do
		bought = false
		local bestAnimal: string? = nil
		local bestZone: string? = nil
		local bestPayback = math.huge
		for _, animalId in Config.ANIMAL_ORDER do
			local zoneId = FarmMath.findZoneForAnimal(save, animalId)
			local price = FarmMath.getAnimalPrice(save, animalId)
			if zoneId and price <= save.cash then
				local payback = price / math.max(animalGain(animalId), 0.0001)
				if payback < bestPayback then
					bestPayback, bestAnimal, bestZone = payback, animalId, zoneId
				end
			end
		end
		if bestAnimal and bestZone then
			buyAnimal(bestAnimal, bestZone)
			bought = true
			continue
		end
		local cheapest: any = nil
		for _, upgrade in Config.UPGRADES do
			if inTheme(upgrade) and FarmMath.getUpgradeStatus(save, upgrade.id) == "available" and upgrade.cost <= save.cash then
				if not cheapest or upgrade.cost < cheapest.cost then
					cheapest = upgrade
				end
			end
		end
		if cheapest then
			buyUpgrade(cheapest)
			bought = true
		end
	end

	if milestones["TÜM YÜKSELTMELER"] == nil then
		local all = true
		for _, upgrade in Config.UPGRADES do
			if inTheme(upgrade) and not save.purchased[upgrade.id] then
				all = false
				break
			end
		end
		if all then
			mark("TÜM YÜKSELTMELER")
		end
	end
	local minute = (now - START) / 60
	if minute - lastReport >= 60 then
		lastReport += 60
		table.insert(reports, string.format("  %2d. saat: gelir %s/sn · %d hayvan · %d yükseltme", math.floor(minute / 60), FarmMath.formatRate(income()), #save.animals, (function()
			local n = 0
			for _ in save.purchased do n += 1 end
			return n
		end)()))
	end
end

print("ADIM ZAMANLARI (dakika, ideal oyuncu)")
local goals: { [string]: string } = {}
local theme = Config.getTheme(FARM)
print(`ÇİFTLİK {FARM} · {theme.displayName} · ana hayvan: {homeAnimal}`)
local targets = { 12, 40, 90 }
for index, islandId in theme.satellites do
	goals[Config.FARM_ISLANDS[islandId].upgradeId] = `hedef ~{targets[index]} dk`
end
goals["TÜM YÜKSELTMELER"] = "hedef 120-180 dk"
for _, name in order do
	print(string.format("  %8.1f dk  %s%s", milestones[name], name, if goals[name] then `   ({goals[name]})` else ""))
end
print("SAATLİK DURUM")
for _, line in reports do
	print(line)
end
local total, owned = 0, 0
for _, upgrade in Config.UPGRADES do
	total += 1
	if save.purchased[upgrade.id] then
		owned += 1
	end
end
print(string.format("Sonuç: %d/%d yükseltme alındı, kasa %s", owned, total, FarmMath.formatMoney(save.cash)))
"""


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--luau", help="Luau yorumlayıcısı yolu")
    parser.add_argument("--hours", type=float, default=6.0, help="Simüle edilecek süre (saat)")
    parser.add_argument("--farm", default="1", help="Çiftlik numarası (tema): 1-6")
    parser.add_argument("--cost-base", type=float, default=600, help="Deneme: bu değerin üstündeki yükseltme maliyetleri büyütülür")
    parser.add_argument("--cost-exp", type=float, default=0, help="Deneme: maliyet üssü (0 = kapalı)")
    parser.add_argument("--price-growth", type=float, default=0, help="Deneme: ANIMAL_PRICE_GROWTH (0 = Config değeri)")
    args = parser.parse_args()
    executable = args.luau or shutil.which("luau")
    if executable is None:
        bundled = ROOT / ".tools" / "luau" / ("luau.exe" if sys.platform == "win32" else "luau")
        if bundled.is_file():
            executable = str(bundled)
    if executable is None:
        parser.error("Luau yorumlayıcısı bulunamadı; --luau ile yol ver.")

    module = run_tests.module
    pieces = [
        "--!nocheck\n",
        "local Color3 = { fromRGB = function(r, g, b) return { R = r / 255, G = g / 255, B = b / 255 } end }\n",
        module("Config", "src/shared/Config.luau").replace("return table.freeze(Config)", "return Config"),  # ayar denemeleri değiştirebilsin
        module("GameTypes", "src/shared/GameTypes.luau"),
        "local Environment = { getIncomeMultiplier = function() return 1 end }\n",
        module("FarmMath", "src/shared/Modules/FarmMath.luau", {"Config", "GameTypes", "Environment"}),
        SIMULATION.replace("__HOURS__", str(args.hours)).replace("__FARM__", str(args.farm))
        .replace("__COST_BASE__", str(args.cost_base))
        .replace("__COST_EXP__", str(args.cost_exp))
        .replace("__PRICE_GROWTH__", str(args.price_growth)),
    ]
    output = ROOT / ".test-build" / "simulate.luau"
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text("\n".join(pieces), encoding="utf-8")
    return subprocess.run([executable, str(output)], cwd=ROOT, check=False).returncode


if __name__ == "__main__":
    raise SystemExit(main())
