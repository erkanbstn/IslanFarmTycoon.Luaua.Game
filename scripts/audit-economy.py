#!/usr/bin/env python3
"""Ekonomi denetimi: gerçek Config/FarmMath ile her çiftlik kademesi ve oyun evresinde oyuncuya görünen sayıları döker.

Evre = o çiftliğin yükseltmelerinin (alım sırasıyla) bir kısmı satın alınmış, bölgeler kapasitenin aynı kısmı kadar yetişkin hayvanla dolu.
Tablolar: ürün merkezi partisi (miktar, değer), sipariş ödülleri (ödül/ürün değeri, gelir dakikası, satır birimi), depo, büyük fiyatlar.
`--check` verirse uçuk değerlerde (Config.ECONOMY_LIMITS) hata kodu döner; `verify.ps1` bunu çalıştırır.

Kullanım: python scripts/audit-economy.py [--check] [--farms 1,2,...] [--windows 40]
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

AUDIT = r"""
local FARMS = __FARMS__
local PHASES = { { "baş", 0.25 }, { "orta", 0.6 }, { "son", 1.0 } }
local WINDOWS = __WINDOWS__
local CHECK = __CHECK__
local now = 600000 * 7 + 30
local serial = 0
local function uid(): string
	serial += 1
	return `audit-{serial}`
end

local function fmt(n: number): string
	if n >= 1e9 then return string.format("%.2fB", n / 1e9) end
	if n >= 1e6 then return string.format("%.2fM", n / 1e6) end
	if n >= 1e4 then return string.format("%.1fK", n / 1e3) end
	return string.format("%d", math.floor(n + 0.5))
end

local problems: { string } = {}
local function problem(text: string)
	table.insert(problems, text)
end

local function buildSave(farm: number, fraction: number): any
	local save: any = assert(SaveCodec.decode(nil, Config, FarmMath, now, uid), "fixture")
	save.activeMainFarmId = tostring(farm)
	local list = {}
	for _, upgrade in Config.UPGRADES do
		if not upgrade.leveled and Config.upgradeInTheme(upgrade, save.activeMainFarmId) then
			table.insert(list, upgrade)
		end
	end
	local count = math.max(1, math.floor(#list * fraction + 0.5))
	for index = 1, count do
		save.purchased[list[index].id] = true
	end
	FarmMath.applyDerived(save)
	save.animals = {}
	for zoneId in save.unlockedZones do
		local zone = Config.ZONES[zoneId]
		if not zone then continue end
		local animalId = nil
		for _, id in Config.ANIMAL_ORDER do
			if Config.zoneAllows(zone, id, save.activeMainFarmId) then
				animalId = id
				break
			end
		end
		if animalId then
			local capacity = FarmMath.getZoneCapacity(save, zoneId)
			for _ = 1, math.max(1, math.floor(capacity * fraction + 0.5)) do
				table.insert(save.animals, { uid = uid(), animalId = animalId, zoneId = zoneId, bornAt = 0, stage = "adult" })
			end
		end
	end
	save.barnLevel = save.barnLevel or 1
	return save
end

local function median(values: { number }): number
	table.sort(values)
	return values[math.max(1, math.ceil(#values / 2))] or 0
end

print("== A) ÜRÜN MERKEZİ PARTİSİ (job.forgone ile gerçek getGoodsYield) ==")
print("çiftlik evre  gelir/dk   merkez            ürün  adet  değer  parti değeri  başlatma  süre(sn)")
local maxYield = 0
for _, farm in FARMS do
	for _, phase in PHASES do
		local save = buildSave(farm, phase[2])
		local income = FarmMath.computeIncomePerSecond(save, now)
		for _, recipeId in Config.PRODUCTION_ORDER do
			local recipe = Config.PRODUCTION_RECIPES[recipeId]
			if recipe.output ~= "goods" or not save.purchased[recipe.upgradeId] or not save.unlockedIslands[recipe.island] then
				continue
			end
			local picked = FarmMath.pickProductionAnimals(save, recipe, now, nil)
			if not picked then continue end
			local duration = FarmMath.getFacilityDuration(save, recipe, nil)
			local forgone = FarmMath.estimateForgoneIncome(save, picked, duration)
			local job = { uid = "x", readyAt = now, startedAt = now, forgone = forgone }
			local amount = FarmMath.getGoodsYield(save, recipe, now, job)
			local good = Config.GOODS[recipe.goodsId]
			maxYield = math.max(maxYield, amount)
			print(string.format("Ç%d %-5s %9s  %-16s %-5s %4d %6s %12s %9s %6d", farm, phase[1], fmt(income * 60), recipeId, good.id, amount, fmt(good.value), fmt(amount * good.value), fmt(FarmMath.getFacilityCost(save, recipe)), duration))
		end
	end
end

print("")
print("== B) SİPARİŞLER (her evrede " .. WINDOWS .. " pencere; en çok/ortanca) ==")
print("çiftlik evre  gelir/dk  cap  ödül/değer(ort/en çok)  ödül dk-gelir(ort/en çok)  satır birimi(en çok)  en büyük ödül")
local worstRatio, worstMinutes, worstLine = 0, 0, 0
for _, farm in FARMS do
	for _, phase in PHASES do
		local save = buildSave(farm, phase[2])
		local income = FarmMath.computeIncomePerSecond(save, now)
		local cap = FarmMath.getGoodsCap(save)
		local ratios, minutes = {}, {}
		local maxRatio, maxMinutes, maxLine, maxReward = 0, 0, 0, 0
		for window = 0, WINDOWS - 1 do
			for _, offer in FarmMath.getContractOffers(save, now + window * Config.GOODS_CONTRACTS.seconds, 0) do
				local ratio = offer.reward / offer.worth
				local mins = offer.reward / math.max(income * 60, 1)
				table.insert(ratios, ratio)
				table.insert(minutes, mins)
				maxRatio = math.max(maxRatio, ratio)
				maxMinutes = math.max(maxMinutes, mins)
				maxReward = math.max(maxReward, offer.reward)
				for _, line in offer.lines do
					maxLine = math.max(maxLine, line.amount)
				end
			end
		end
		worstRatio = math.max(worstRatio, maxRatio)
		worstMinutes = math.max(worstMinutes, maxMinutes)
		worstLine = math.max(worstLine, maxLine)
		print(string.format("Ç%d %-5s %8s %4d  %6.2f / %6.2f          %7.2f / %7.2f            %4d            %10s", farm, phase[1], fmt(income * 60), cap, median(ratios), maxRatio, median(minutes), maxMinutes, maxLine, fmt(maxReward)))
	end
end

print("")
print("== D) ÜRÜN DEĞERİ ÖNERİSİ (tam yükseltilmiş çiftlik: taban değer = (kaçırılan gelir + başlatma) x MIN_RETURN; öneri = taban x 1.5 / 4 birim) ==")
local suggested: { [string]: number } = {}
for _, farm in FARMS do
	local save = buildSave(farm, 1.0)
	for _, recipeId in Config.PRODUCTION_ORDER do
		local recipe = Config.PRODUCTION_RECIPES[recipeId]
		if recipe.output ~= "goods" or not save.purchased[recipe.upgradeId] or not save.unlockedIslands[recipe.island] then
			continue
		end
		local picked = FarmMath.pickProductionAnimals(save, recipe, now, nil)
		if not picked then continue end
		local duration = FarmMath.getFacilityDuration(save, recipe, nil)
		local forgone = FarmMath.estimateForgoneIncome(save, picked, duration)
		local floorWorth = (forgone + FarmMath.getFacilityCost(save, recipe)) * Config.PRODUCTION_MIN_RETURN
		local good = Config.GOODS[recipe.goodsId]
		local value = floorWorth * 1.5 / 4
		suggested[good.id] = math.max(suggested[good.id] or 0, value)
		print(string.format("Ç%d %-16s %-14s taban %8s  şimdiki değer %6s  öneri %7s", farm, recipeId, good.id, fmt(floorWorth), fmt(good.value), fmt(value)))
	end
end

print("")
print("== C) BÜYÜK SAYILAR ==")
local biggest, biggestWhat = 0, ""
for _, farm in FARMS do
	local save = buildSave(farm, 0.01)
	for _, upgrade in Config.UPGRADES do
		local price = FarmMath.getPrice(save, "upgrade", upgrade.id, 0)
		if price ~= math.huge and price > biggest then
			biggest, biggestWhat = price, `Ç{farm} {upgrade.id}`
		end
	end
end
print(`en pahalı yükseltme: {fmt(biggest)} ({biggestWhat})`)
print(`en büyük parti: {maxYield} ürün; sipariş ödül/değer en çok {string.format("%.2f", worstRatio)}; ödül en çok {string.format("%.1f", worstMinutes)} dk gelir; satır en çok {worstLine}`)

local limits = Config.ECONOMY_LIMITS
if limits then
	if maxYield > limits.maxBatchUnits then problem(`parti {maxYield} > {limits.maxBatchUnits}`) end
	if worstRatio > limits.maxRewardRatio then problem(`ödül/değer {worstRatio} > {limits.maxRewardRatio}`) end
	if worstMinutes > limits.maxRewardMinutes then problem(`ödül {worstMinutes} dk > {limits.maxRewardMinutes}`) end
	if worstLine > limits.maxLineUnits then problem(`satır {worstLine} > {limits.maxLineUnits}`) end
	if biggest > limits.maxDisplayValue then problem(`fiyat {biggest} > {limits.maxDisplayValue}`) end
end
for _, text in problems do
	print("UÇUK: " .. text)
end
if CHECK and #problems > 0 then
	error("ekonomi denetimi başarısız")
end
"""


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--luau", help="Luau yorumlayıcısı yolu")
    parser.add_argument("--check", action="store_true", help="uçuk değerde hata ver")
    parser.add_argument("--farms", default="1,2,3,4,5,6")
    parser.add_argument("--windows", type=int, default=40)
    args = parser.parse_args()
    executable = args.luau or shutil.which("luau")
    if executable is None:
        bundled = ROOT / ".tools" / "luau" / ("luau.exe" if sys.platform == "win32" else "luau")
        executable = str(bundled) if bundled.is_file() else None
    if executable is None:
        parser.error("Luau yorumlayıcısı bulunamadı; --luau ile yol ver.")
    farms = "{" + ",".join(item.strip() for item in args.farms.split(",") if item.strip()) + "}"
    module = run_tests.module
    pieces = [
        "--!nocheck\n",
        "local Color3 = { fromRGB = function(r, g, b) return { R = r / 255, G = g / 255, B = b / 255 } end }\n",
        run_tests.config_bundle(),
        module("GameTypes", "src/shared/GameTypes.luau"),
        "local Environment = { getIncomeMultiplier = function() return 1 end }\n",
        run_tests.farm_math_bundle(),
        module("SessionLock", "src/server/Modules/SessionLock.luau"),
        module("FarmProfiles", "src/server/Modules/FarmProfiles.luau"),
        module("Preferences", "src/server/Modules/Preferences.luau"),
        run_tests.save_codec_bundle(),
        AUDIT.replace("__FARMS__", farms).replace("__WINDOWS__", str(args.windows)).replace("__CHECK__", "true" if args.check else "false"),
    ]
    output = ROOT / ".test-build" / "audit.luau"
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text("\n".join(pieces), encoding="utf-8")
    return subprocess.run([executable, str(output)], cwd=ROOT, check=False).returncode


if __name__ == "__main__":
    raise SystemExit(main())
