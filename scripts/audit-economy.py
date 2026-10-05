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
	-- Geç oyun: alan/tesis geliştirmeleri ve ırk seviyeleri evre kısmı kadar (son evre = hepsi en üst seviye); gelir ve kaçırılan gelir gerçeğe yaklaşır
	save.expansions = {}
	save.lineage = {}
	for zoneId, zone in Config.ZONES do
		if save.unlockedZones[zoneId] or save.purchased[zone.island] then
			save.expansions[zoneId] = math.floor(Config.BUILD_UPGRADES.maxLevel * fraction)
		end
	end
	for recipeId in Config.PRODUCTION_RECIPES do
		save.expansions[recipeId] = math.floor(Config.BUILD_UPGRADES.maxLevel * fraction)
	end
	for animalId in Config.ANIMALS do
		save.lineage[animalId] = math.floor(Config.LINEAGE.maxLevel * fraction)
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
print("çiftlik evre  gelir/dk  cap  ödül/değer(ort/en çok)  ödül dk-gelir(ort/en çok)  satır birimi(en çok)  en büyük ödül  pano(teklif/slot)  pano dk-gelir/pencere  bütçe dk")
local worstRatio, worstMinutes, worstLine = 0, 0, 0
local worstBonusRatio = 0
local lateTruncated = 0
for _, farm in FARMS do
	for _, phase in PHASES do
		local save = buildSave(farm, phase[2])
		local income = FarmMath.computeIncomePerSecond(save, now)
		local cap = FarmMath.getGoodsCap(save)
		local ratios, minutes = {}, {}
		local maxRatio, maxMinutes, maxLine, maxReward = 0, 0, 0, 0
		local boardCount, boardSlots, boardMinutes = 0, 0, 0
		local refPerSecond = FarmMath.getContractReferenceIncome(save, now)
		for window = 0, WINDOWS - 1 do
			local at = now + window * Config.GOODS_CONTRACTS.seconds
			local board = FarmMath.getContractOffers(save, at, 0)
			local slotsNow = FarmMath.getContractSlotCount(#FarmMath.getContractGoods(save, at))
			boardCount += #board
			boardSlots += slotsNow
			if phase[2] >= 1.0 and #board < slotsNow then
				lateTruncated += 1
			end
			-- Bonuslar dahil üst sınır: dev bonus (eşya + ada + mevsim yığını) verilse de ödül/değer maxRewardRatio'yu aşmaz
			for _, offer in FarmMath.getContractOffers(save, at, 10) do
				worstBonusRatio = math.max(worstBonusRatio, offer.uncappedReward / offer.worth)
			end
			for _, offer in board do
				boardMinutes += offer.reward / math.max(income * 60, 1)
			end
			for _, offer in board do
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
		print(string.format("Ç%d %-5s %8s %4d  %6.2f / %6.2f          %7.2f / %7.2f            %4d            %10s      %5.1f/%4.1f          %6.1f            %4.1f", farm, phase[1], fmt(income * 60), cap, median(ratios), maxRatio, median(minutes), maxMinutes, maxLine, fmt(maxReward), boardCount / WINDOWS, boardSlots / WINDOWS, boardMinutes / WINDOWS, FarmMath.getContractBudgetMinutes(refPerSecond)))
	end
end

print("")
print("== D) ÜRÜN DEĞERİ ÖNERİSİ (tam yükseltilmiş çiftlik: taban değer = (kaçırılan gelir + başlatma) x MIN_RETURN; değer / taban 1,2-2,6 bandında olmalı; öneri = taban x 1.7) ==")
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
		local value = floorWorth * 1.7
		suggested[good.id] = math.max(suggested[good.id] or 0, value)
		print(string.format("Ç%d %-16s %-14s taban %8s  şimdiki değer %7s (x%.1f)  öneri %7s  raw=%d", farm, recipeId, good.id, fmt(floorWorth), fmt(good.value), good.value / floorWorth, fmt(value), floorWorth))
		local limitsD = Config.ECONOMY_LIMITS
		if limitsD and (good.value / floorWorth < limitsD.valueToFloorMin or good.value / floorWorth > limitsD.valueToFloorMax) then
			problem(`{good.id} değer/taban {good.value / floorWorth} bantta değil (Ç{farm})`)
		end
	end
end

print("")
print("== E) AÇILIŞ ÜRÜNÜ (goodsCost: birim ve değerin para fiyatına oranı) ==")
for _, farm in FARMS do
	local reference = { farmId = tostring(farm), activeMainFarmId = tostring(farm), purchased = {} }
	local units, worthTotal, moneyTotal, count = 0, 0, 0, 0
	local maxUnits = 0
	for _, upgrade in Config.UPGRADES do
		if upgrade.goodsCost and Config.upgradeInTheme(upgrade, reference.farmId) then
			local money = FarmMath.getUpgradeCost(reference, upgrade)
			for goodsId, amount in FarmMath.getGoodsCost(reference, upgrade) do
				units += amount
				maxUnits = math.max(maxUnits, amount)
				worthTotal += amount * Config.GOODS[goodsId].value
				count += 1
			end
			moneyTotal += money
		end
	end
	print(string.format("Ç%d  %d kalem · toplam %d birim (kalem başına en çok %d) · ürün değeri / para fiyatı = %.3f", farm, count, units, maxUnits, worthTotal / math.max(moneyTotal, 1)))
end

print("")
print("== F) ÜRÜN MERKEZİ EKONOMİSİ (tam yükseltilmiş çiftlik; tek parti: 2 birim = taban miktar; tam parti = getGoodsYield) ==")
print("çiftlik merkez           ürün            süre(taban) yet. kaçırılan  başl.  birim değer  sipariş(2b,x1.2)/maliyet  satış(tam parti)/maliyet  merkez fiyatı  geri ödeme(dk, 2b)")
local settingsF = Config.GOODS_CONTRACTS
local cheapestFactor = math.huge
for _, tier in settingsF.tiers do
	cheapestFactor = math.min(cheapestFactor, tier.rewardFactor)
end
if cheapestFactor / Config.GOODS_SELL.rate < 10 then
	problem(`sipariş/satış oranı {cheapestFactor / Config.GOODS_SELL.rate} < 10 (satış siparişe rakip olmasın)`)
end
if Config.GOODS_BARTER.rate > Config.GOODS_SELL.rate then
	problem("takas oranı satış oranını aşıyor")
end
for _, farm in FARMS do
	local save = buildSave(farm, 1.0)
	local reference = { farmId = tostring(farm), activeMainFarmId = tostring(farm), purchased = {} }
	for _, recipeId in Config.PRODUCTION_ORDER do
		local recipe = Config.PRODUCTION_RECIPES[recipeId]
		if recipe.output ~= "goods" or not save.purchased[recipe.upgradeId] or not save.unlockedIslands[recipe.island] then
			continue
		end
		local picked = FarmMath.pickProductionAnimals(save, recipe, now, nil)
		if not picked then
			continue
		end
		local duration = FarmMath.getFacilityDuration(save, recipe, nil)
		local forgone = FarmMath.estimateForgoneIncome(save, picked, duration)
		local start = FarmMath.getFacilityCost(save, recipe)
		local good = Config.GOODS[recipe.goodsId]
		local full = FarmMath.getGoodsYield(save, recipe, now, { uid = "x", readyAt = now, startedAt = now, forgone = forgone })
		local centerPrice = FarmMath.getUpgradeCost(reference, Config.getUpgrade(recipe.upgradeId))
		local netPerMinute = (recipe.goodsAmount * good.value * 1.2 - forgone - start) / duration * 60
		print(string.format("Ç%d %-16s %-15s %4d(%4d) %d %9s %6s %8s        %6.1f                    %6.2f              %9s     %8.1f", farm, recipeId, good.id, duration, recipe.duration, recipe.requiredAdults, fmt(forgone), fmt(start), fmt(good.value), recipe.goodsAmount * good.value * 1.2 / (forgone + start), full * good.value * Config.GOODS_SELL.rate / (forgone + start), fmt(centerPrice), centerPrice / math.max(netPerMinute, 1)))
	end
end

print("")
print("== G) SİPARİŞ KARŞILANABİLİRLİĞİ (satır ≤ depo sınırı; talep ve üretim birim/pencere) ==")
local capBarn1 = Config.BARN_LEVELS[1].goodsCap
local fromEmptyWorst, fromEmptyWho = 0, ""
for _, recipe in Config.PRODUCTION_RECIPES do
	if recipe.output ~= "goods" then
		continue
	end
	local maxAmount = 0
	for _, tier in settingsF.tiers do
		local base = FarmMath.getContractBaseUnits(tier, recipe.goodsId)
		local high = math.max(math.floor(base * (1 + settingsF.variation) + 0.5), settingsF.minHighUnits)
		maxAmount = math.max(maxAmount, math.min(high, settingsF.maxLineUnits))
	end
	if maxAmount > capBarn1 then
		problem(`{recipe.id}: en büyük satır {maxAmount} > en küçük ahır deposu {capBarn1}`)
	end
	local fromEmpty = math.ceil(maxAmount / recipe.goodsAmount) * recipe.duration
	if fromEmpty > fromEmptyWorst then
		fromEmptyWorst, fromEmptyWho = fromEmpty, recipe.id
	end
	if fromEmpty > 2 * settingsF.seconds then
		problem(`{recipe.id}: en büyük satır ({maxAmount} birim) boştan {fromEmpty} sn sürer (> 2 pencere)`)
	end
end
print(string.format("en küçük ahır deposu %d birim; en büyük satır tabandaki merkezle boştan en uzun %d sn (%s; pencere %d sn)", capBarn1, fromEmptyWorst, fromEmptyWho, settingsF.seconds))
print("çiftlik evre  ürün talep ort/en çok (birim/pencere) ve üretim (birim/pencere)")
for _, farm in FARMS do
	for _, phase in { { "orta", 0.6 }, { "son", 1.0 } } do
		local save = buildSave(farm, phase[2])
		local income = FarmMath.computeIncomePerSecond(save, now)
		local demand: { [string]: { number } } = {}
		local rewardTotal = 0
		for window = 0, WINDOWS - 1 do
			local perGoods: { [string]: number } = {}
			for _, offer in FarmMath.getContractOffers(save, now + window * settingsF.seconds, 0) do
				rewardTotal += offer.reward
				for _, line in offer.lines do
					perGoods[line.goodsId] = (perGoods[line.goodsId] or 0) + line.amount
					if line.amount > FarmMath.getGoodsCap(save) then
						problem(`Ç{farm} {phase[1]}: {line.goodsId} satırı {line.amount} > depo {FarmMath.getGoodsCap(save)}`)
					end
				end
			end
			for goodsId, amount in perGoods do
				demand[goodsId] = demand[goodsId] or {}
				table.insert(demand[goodsId], amount)
			end
		end
		local parts: { string } = {}
		for _, recipeId in Config.PRODUCTION_ORDER do
			local recipe = Config.PRODUCTION_RECIPES[recipeId]
			local list = if recipe.goodsId then demand[recipe.goodsId] else nil
			if recipe.output ~= "goods" or not list then
				continue
			end
			local picked = FarmMath.pickProductionAnimals(save, recipe, now, nil)
			if not picked then
				continue
			end
			local duration = FarmMath.getFacilityDuration(save, recipe, nil)
			local forgone = FarmMath.estimateForgoneIncome(save, picked, duration)
			local yield = FarmMath.getGoodsYield(save, recipe, now, { uid = "x", readyAt = now, startedAt = now, forgone = forgone })
			local sum, top = 0, 0
			for _, amount in list do
				sum += amount
				top = math.max(top, amount)
			end
			table.insert(parts, string.format("%s %.1f/%d üretim %d", recipe.goodsId, sum / WINDOWS, top, math.floor(settingsF.seconds / duration) * yield))
		end
		print(string.format("Ç%d %-5s %s · sipariş değeri %.1f dk gelir/pencere", farm, phase[1], table.concat(parts, " | "), rewardTotal / WINDOWS / math.max(income * 60, 1)))
	end
end

print("")
print("== H) PARA TESİSİ GETİRİSİ (parti ödülü / (kaçırılan gelir + başlatma); sınır: PRODUCTION_MAX_RETURN x 1.15 yuvarlama payı) ==")
local worstReturn: { [string]: number } = {}
for _, farm in FARMS do
	for _, fraction in { 0.4, 0.6, 1.0 } do
		local save = buildSave(farm, fraction)
		for _, recipeId in Config.PRODUCTION_ORDER do
			local base = Config.PRODUCTION_RECIPES[recipeId]
			local upgrade = Config.getUpgrade(base.upgradeId)
			if
				base.output ~= "cash"
				or not base.options
				or not upgrade
				or not Config.upgradeInTheme(upgrade, tostring(farm))
				or not save.unlockedIslands[base.island]
			then
				continue
			end
			local owned = save.purchased[base.upgradeId]
			save.purchased[base.upgradeId] = true
			for _, option in base.options do
				local picked = FarmMath.pickProductionAnimals(save, base, now, option.id)
				if picked then
					local recipe = FarmMath.resolveRecipe(base, option.id)
					local duration = FarmMath.getFacilityDuration(save, recipe, nil)
					local forgone = FarmMath.estimateForgoneIncome(save, picked, duration)
					local reward = FarmMath.getProductionReward(save, base, now, { uid = "x", readyAt = now, startedAt = now, forgone = forgone, optionId = option.id })
					local ratio = reward / math.max(forgone + FarmMath.getFacilityCost(save, recipe), 1)
					local key = `{recipeId}/{option.id}`
					worstReturn[key] = math.max(worstReturn[key] or 0, ratio)
				end
			end
			save.purchased[base.upgradeId] = owned
		end
	end
end
local returnKeys: { string } = {}
for key in worstReturn do
	table.insert(returnKeys, key)
end
table.sort(returnKeys)
local returnParts: { string } = {}
for _, key in returnKeys do
	if worstReturn[key] > Config.PRODUCTION_MAX_RETURN * 1.05 or string.sub(key, -6) == "/large" then
		table.insert(returnParts, string.format("%s %.2f", key, worstReturn[key]))
	end
	if worstReturn[key] > Config.PRODUCTION_MAX_RETURN * 1.15 then
		problem(`{key}: getiri {worstReturn[key]} > PRODUCTION_MAX_RETURN x 1.15`)
	end
end
print("en yüksek getiri (tüm çiftlik/evre; büyük parti ve sınırı aşanlar):", table.concat(returnParts, " · "))

print("")
print("== C) BÜYÜK SAYILAR ==")
local biggest, biggestWhat = 0, ""
for _, farm in FARMS do
	local save = buildSave(farm, 0.01)
	local tierBiggest, tierWhat = 0, ""
	local function consider(price: number, what: string)
		if price ~= math.huge and price > tierBiggest then
			tierBiggest, tierWhat = price, what
		end
	end
	local farmId = tostring(farm)
	for _, upgrade in Config.UPGRADES do
		if Config.upgradeInTheme(upgrade, farmId) then
			consider(FarmMath.getPrice(save, "upgrade", upgrade.id, 0), upgrade.id)
		end
	end
	for animalId in Config.ANIMALS do
		consider(FarmMath.getPrice(save, "animal", animalId, 30), `hayvan {animalId}`)
	end
	for targetId, zone in Config.ZONES do
		if Config.themeHasIsland(farmId, zone.island) then
			for level = 0, Config.BUILD_UPGRADES.maxLevel - 1 do
				consider(FarmMath.getPrice(save, "expansion", targetId, level), `genişletme {targetId} Sv.{level}`)
			end
		end
	end
	for targetId, recipe in Config.PRODUCTION_RECIPES do
		if Config.themeHasIsland(farmId, recipe.island) then
			for level = 0, Config.BUILD_UPGRADES.maxLevel - 1 do
				consider(FarmMath.getPrice(save, "expansion", targetId, level), `tesis {targetId} Sv.{level}`)
			end
		end
	end
	local ceiling = Config.DIFFICULTY.tiers[farm].maxPrice
	print(string.format("Ç%d en pahalı kalem: %s (%s) · tavan %s", farm, fmt(tierBiggest), tierWhat, ceiling and fmt(ceiling) or "-"))
	if ceiling and tierBiggest > ceiling then
		problem(`Ç{farm} fiyat {tierBiggest} > kademe tavanı {ceiling} ({tierWhat})`)
	end
	if tierBiggest > biggest then
		biggest, biggestWhat = tierBiggest, `Ç{farm} {tierWhat}`
	end
end
print(`en pahalı kalem: {fmt(biggest)} ({biggestWhat})`)
print(`bonus tavanı: dev bonusla (+10) ödül/değer en çok {string.format("%.2f", worstBonusRatio)} (sınır {Config.ECONOMY_LIMITS.maxRewardRatio}); geç evrede kırpılan pencere: {lateTruncated}`)
do
	local parts: { string } = {}
	local week = 0
	for day, multiplier in Config.DAILY_REWARD_MULTIPLIERS do
		week += multiplier * Config.DAILY_MINUTES
		table.insert(parts, string.format("g%d %.1f", day, multiplier * Config.DAILY_MINUTES))
	end
	table.insert(parts, string.format("hafta %.1f dk = bir günün %%%.2f'si", week, week / 1440 * 100))
	if week > 0.03 * 1440 then
		problem(`günlük ödül haftası {week} dk > bir günün %3'ü`)
	end
	print("günlük ödül (gelir dakikası): " .. table.concat(parts, " · "))
end
print(`en büyük parti: {maxYield} ürün; sipariş ödül/değer en çok {string.format("%.2f", worstRatio)}; ödül en çok {string.format("%.1f", worstMinutes)} dk gelir; satır en çok {worstLine}`)

local limits = Config.ECONOMY_LIMITS
if limits then
	if maxYield > limits.maxBatchUnits then problem(`parti {maxYield} > {limits.maxBatchUnits}`) end
	if worstRatio > limits.maxRewardRatio then problem(`ödül/değer {worstRatio} > {limits.maxRewardRatio}`) end
	if worstMinutes > limits.maxRewardMinutes then problem(`ödül {worstMinutes} dk > {limits.maxRewardMinutes}`) end
	if worstLine > limits.maxLineUnits then problem(`satır {worstLine} > {limits.maxLineUnits}`) end
	local budgetCfg = Config.GOODS_CONTRACTS.windowBudget
	if budgetCfg.graceIncome > 0.25 * budgetCfg.highIncome then problem(`pano bütçesiz başlangıç aralığı {budgetCfg.graceIncome}/sn geç oyuna taşıyor`) end
	if budgetCfg.highMinutes < 8 then problem(`pano bütçesi üst sınırı {budgetCfg.highMinutes} dk tam panoyu (~5-6 dk) bağlayabilir`) end
	if worstBonusRatio > limits.maxRewardRatio + 1e-9 then problem(`bonus yığınıyla ödül/değer {worstBonusRatio} > {limits.maxRewardRatio}`) end
	if lateTruncated > 0 then problem(`geç oyunda (tam yükseltilmiş çiftlik) pano bütçesi {lateTruncated} pencerede panoyu kırptı`) end
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
