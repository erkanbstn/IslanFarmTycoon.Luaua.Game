#!/usr/bin/env python3
"""Ekonomi simülasyonu: Config değerleriyle oyuncu ilerlemesini hesaplar.

Varsayılan ("ideal" oyuncu): her an kasası yettiği en iyi yatırımı alır (önce hayvan, sonra en ucuz yükseltme),
parayı COLLECT sn'de bir toplar ve hiç boş durmaz; üretim, sipariş, ödül, çoklu çiftlik ve oturum modellenmez.
Çıktı: her önemli adıma kaç dakikada ulaşıldığı, saatlik gelir, dakikada eylem, depo dolu geçen süre ve gelir kaynakları.
Gerçek FarmMath/Config/Rewards/Golden/ProductionLogic/SaveCodec kullanılır (scripts/run-tests.py ile aynı
birleştirme); formül Python'a kopyalanmaz.

Her mekanik açılıp kapanabilir (bayraklar persona ön ayarını ezer):
  --persona idle|casual|hardcore   tüm mekanikleri açan hazır oyuncu tipi (varsayılan ideal = eski model)
  --session DK / --offline SAAT / --sessions-per-day N   oturum düzeni (--session 0 = hiç çıkma)
  --prod-interval SN   en iyi parti her SN'de yeniden başlar (yardımcı alınmışsa anında); 0 = üretim yok
  --ext-interval SN    eklentiler her SN'de yeniden doldurulur; 0 = eklenti yok
  --sell-above ORAN    ürün kapasitenin bu oranına ulaşınca yarısı satılır ("Yarısını sat"; persona ön ayarı; 0 = satma)
  --orders / --no-orders, --rewards / --no-rewards, --golden-chance 0..1, --farms N, --react SN
  --days N (= --hours N*24), --json (makine okunur çıktı)

Bilinen sınırlar (bilinçli sadeleştirme):
  - Çevrimdışı kazanç tüm sahip olunan çiftliklerde ayrı hesaplanır; yürüyüş ve menüde karar verme modellenmez.
  - Persona oturum düzeni --hours 6'da tek oturum üretir (casual: 20 dk çevrimiçi); persona karşılaştırması için --days kullan.
  - "Depo dolu" yalnızca toplama aralığına göre ölçülür, oturum içi AFK modellenmez.
  - Üretim ve eklenti yalnızca etkin çiftlikte elle yapılır; park edilmişlerde yalnızca yardımcılar (pet) çalışır.

Kullanım:  python scripts/simulate-economy.py [--hours 8] [--farm 1..6] [--persona casual --days 7] [--luau PATH]
"""

from __future__ import annotations

import argparse
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("run_tests", ROOT / "scripts" / "run-tests.py")
run_tests = importlib.util.module_from_spec(spec)
spec.loader.exec_module(run_tests)  # type: ignore[union-attr]

# Oyuncu tipi ön ayarları. ideal = eski model (yalnızca toplama aralığı); diğerleri tüm mekanikleri açar.
#   react: karar aralığı (sn; yatırım, ödül, sipariş), collect: platforma uğrama aralığı (sn),
#   session/sessions_per_day: oturum süresi (dk) ve günlük oturum sayısı, golden: altın hayvanı yakalama şansı.
PERSONAS: dict[str, dict[str, float | int | bool]] = {
    "ideal": {},
    "idle": {
        "react": 60, "collect": 600, "session": 10, "sessions_per_day": 2, "prod_interval": 300, "ext_interval": 0,
        "orders": True, "rewards": True, "golden": 0.15, "farms": 6,
    },
    "casual": {
        "react": 20, "collect": 180, "session": 20, "sessions_per_day": 3, "prod_interval": 120, "ext_interval": 300,
        "orders": True, "rewards": True, "golden": 0.6, "farms": 6, "sell_above": 0.8,
    },
    "hardcore": {
        "react": 5, "collect": 60, "session": 60, "sessions_per_day": 4, "prod_interval": 45, "ext_interval": 125,
        "orders": True, "rewards": True, "golden": 0.95, "farms": 6, "sell_above": 0.7,
    },
}

SIMULATION = r"""
local HOURS = __HOURS__
local FARM = "__FARM__"
-- Ayar denemesi: yükseltme maliyetlerini (cost/BASE)^EXP ile büyüt, hayvan fiyat artışını değiştir (Config'e dokunmadan)
local COST_BASE, COST_EXP, PRICE_GROWTH = __COST_BASE__, __COST_EXP__, __PRICE_GROWTH__
-- Gerçekçi toplama: COLLECT sn'de bir platforma gidilir (0 = anında); depo dolunca kazanç durur (otomatik toplayıcı alınınca sınırsız).
-- CAP_MULT: ahır depo kapasitelerini çarpar (deneme).
local COLLECT, CAP_MULT = __COLLECT__, __CAP_MULT__
-- Oyuncu tipi ve mekanik ayarları (Python'dan): react, session, period, prodInterval, extInterval, orders, rewards,
-- goldenChance, farms, sellAbove, persona, json
local S = __SETTINGS__
if CAP_MULT ~= 1 then
	for _, barn in Config.BARN_LEVELS do
		barn.storageCap = barn.storageCap * CAP_MULT
	end
end
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
for slot, premium in S.premium do
	Config.DIFFICULTY.islandPremium[slot] = { perTier = premium[1], power = premium[2] } -- ayar denemesi: ada açılış primi
end
if S.goodsTierGrowth then
	Config.DIFFICULTY.goods.tierGrowth = S.goodsTierGrowth
end
if #S.goodsStepBase > 0 then
	Config.DIFFICULTY.goods.stepBase = S.goodsStepBase
end
if S.slotSpread then
	Config.DIFFICULTY.slotSpread = S.slotSpread
end
for index, mult in S.mults do
	Config.DIFFICULTY.tiers[index].costMultiplier = mult -- ayar denemesi: kademe çiftlik çarpanları
end
local STEP = 5 -- saniye
local START = if S.carryAccount then S.carryAccount.progression.startedAt else 1036800 -- Gerçek tur geçişinde UTC zamanı korunur.
local TOTAL = HOURS * 3600
local USER_ID = 424242 -- altın hayvan pencereleri bu kimlikten türer (deterministik)

local save: any = {
	cash = Config.getStartingCash(FARM) * Config.DIFFICULTY.tiers[tonumber(FARM) or 1].costMultiplier, -- kademe = tema numarası
	stored = 0,
	purchased = {},
	animals = {},
	barnLevel = 1,
	unlockedIslands = {},
	unlockedZones = {},
	production = {},
	autoRepeat = {},
	goods = {},
	lifetimeEarned = 0,
	activeMainFarmId = FARM,
}
local homeAnimal = Config.getHomeAnimal(FARM)
for index = 1, Config.STARTING_COW_COUNT do
	table.insert(save.animals, { uid = `start-{index}`, animalId = homeAnimal, zoneId = "starter", bornAt = 0, stage = "adult" })
end
FarmMath.applyDerived(save)
save.mainFarms = { [FARM] = FarmProfiles.extract(save) }
save.gold = S.startingGold
save.owned = { items = {}, conveniences = {} }
save.inventory = { items = {}, equipped = {}, uses = {} }
save.progression = Progression.defaults(START, 0)
save.progression.count = S.rebirth
save.progression.run = S.rebirth + 1
save.progression.perks = S.perks
save.progression.runDouble = S.runDouble
if S.carryAccount then
	for key, value in S.carryAccount do
		save[key] = value
	end
end
if S.rebirth > 0 then
	save.progression.returnEndsAt = START + Config.PROGRESSION.returnSeconds
	save.progression.returnEnded = false
end
if S.runDouble then
	save.progression.runDouble = true
end
Progression.grantRebirthRewards(save)
-- Yeni ücretsiz ekipman boş yuvaya takılır; satın alınan seçim zorla değiştirilmez.
for _, milestone in Config.PROGRESSION.milestones do
	local itemId = milestone.itemId
	local item = if itemId then Config.ITEMS[itemId] else nil
	if item and save.owned.items[itemId] and not save.inventory.equipped[item.slot] then
		save.inventory.equipped[item.slot] = itemId
	end
end
for _, itemId in S.equipment do
	local item = assert(Config.ITEMS[itemId], `Unknown equipment: {itemId}`)
	save.owned.items[itemId] = true
	save.inventory.items[itemId] = true
	save.inventory.equipped[item.slot] = itemId
end
for _, key in S.conveniences do
	save.owned.conveniences[key] = true
end
save.cash = Progression.getStartingCash(save, FARM) * Config.DIFFICULTY.tiers[tonumber(FARM) or 1].costMultiplier
local readyUid = 0
if FARM == "1" then
	Progression.applyReadyStart(save, START, function(): string
		readyUid += 1
		return `ready-{readyUid}`
	end)
end

local themeIslands = FarmMath.themeIslands(save)
local function inTheme(upgrade: any): boolean
	return Config.upgradeInTheme(upgrade, save.activeMainFarmId)
end

local now = START
local goldEarned, goldSpent, goldCash = 0, 0, 0
local milestones: { [string]: number } = {}
local order: { string } = {}
-- Başka çiftliğe geçilince kilometre taşı adlarına "Ç<no> " öneki eklenir (ilk çiftlik eski adlarla kalır)
local function farmPrefix(): string
	return if save.activeMainFarmId == FARM then "" else `Ç{save.activeMainFarmId} `
end
local function mark(name: string, raw: boolean?)
	local key = if raw then name else farmPrefix() .. name
	if milestones[key] == nil then
		milestones[key] = (now - START) / 60
		table.insert(order, key)
	end
end

-- Sayaçlar: eylem, çevrimiçi süre, deponun dolu kaldığı süre, gelir kaynakları
local actions, onlineSeconds, fullSeconds = 0, 0, 0
local sources: { [string]: number } = {}
local sourceOrder: { string } = {}
local function earn(amount: number, source: string, lifetime: boolean?)
	if not (amount > 0) then
		return
	end
	save.cash += amount
	if lifetime ~= false then
		save.lifetimeEarned += amount
	end
	if sources[source] == nil then
		sources[source] = 0
		table.insert(sourceOrder, source)
	end
	sources[source] += amount
end

-- Ürün (ahır deposu) ölçümü: üretim/tüketim/doluluk. FarmMath.addGoods sarılır; ProductionLogic aynı tabloyu kullanır.
local goodsStat: { [string]: any } = {}
-- Sipariş ve parti ölçümü (ödül/değer oranı, ödülün gelir dakikası, satır ve parti birimi): "uçuk sayı" denetimi (docs/ZORLUK_VE_FIYAT.md)
local orderStat = { count = 0, ratioSum = 0, ratioMax = 0, minutesSum = 0, minutesMax = 0, lineMax = 0, batchMax = 0 }
local function gstat(goodsId: string): any
	local row = goodsStat[goodsId]
	if not row then
		row = { produced = 0, overflow = 0, ordered = 0, sold = 0, bartered = 0, fillSeconds = 0, fillSum = 0, fullSeconds = 0 }
		goodsStat[goodsId] = row
	end
	return row
end
do
	local baseAddGoods = FarmMath.addGoods
	FarmMath.addGoods = function(target: any, goodId: string, amount: number): number
		local added = baseAddGoods(target, goodId, amount)
		local row = gstat(goodId)
		row.produced += added
		row.overflow += math.max(0, math.floor(amount) - added)
		orderStat.batchMax = math.max(orderStat.batchMax, math.floor(amount))
		return added
	end
end
local function sampleGoods(seconds: number)
	local cap = FarmMath.getGoodsCap(save)
	for _, goodsId in FarmMath.getContractGoods(save) do
		local row = gstat(goodsId)
		local amount = FarmMath.getGoodsAmount(save, goodsId)
		row.fillSeconds += seconds
		row.fillSum += seconds * amount / math.max(cap, 1)
		if amount >= cap then
			row.fullSeconds += seconds
		end
	end
end

local function levelSum(levels: any): number
	local total = 0
	for _, level in levels or {} do
		total += level
	end
	return total
end

local function refreshStages()
	for _, animal in save.animals do
		animal.stage = FarmMath.getStage(animal.bornAt, now, FarmMath.getGrowthSpeed(save, animal.animalId, animal.zoneId, now))
		if animal.stage == "adult" and animal.bornAt ~= 0 then
			mark("ilk büyüyen yetişkin")
		end
	end
end

local function income(): number
	return FarmMath.computeIncomePerSecond(save, now)
end

local function invested()
	if S.rewards then
		Rewards.recordInvest(save, now)
	end
end

local uidCounter = 0
local function buyAnimal(animalId: string, zoneId: string)
	uidCounter += 1
	save.cash -= FarmMath.getAnimalPrice(save, animalId)
	local bornAt = FarmMath.getNewAnimalBornAt(save, now)
	table.insert(save.animals, { uid = `sim-{uidCounter}`, animalId = animalId, zoneId = zoneId, bornAt = bornAt, stage = if bornAt == 0 then "adult" else "calf" })
	actions += 1
	invested()
	local count = FarmMath.countAnimals(save, animalId)
	if count == 1 then
		mark(`ilk {animalId}`)
	end
	if count == 10 then
		mark(`10. {animalId}`)
	end
end

-- Para tesisi geri ödemesi: tesisin satın alma bedeli / (en iyi partinin sürekli çalışmasından saniyelik net kazanç).
-- Tesis kurulduktan sonra ilk uygun parti başlarken bir kez ölçülür (anahtar: Ç-öneki + tarif kimliği).
local facilityCosts: { [string]: number } = {}
local facilityPaybacks: { [string]: number } = {}
local facilityOrder: { string } = {}
local function recordFacilityPayback(farm: any, recipe: any, optionId: string?)
	local key = farmPrefix() .. recipe.id
	local cost = facilityCosts[key]
	if facilityPaybacks[key] ~= nil or not cost or not optionId then
		return
	end
	local animals = FarmMath.pickProductionAnimals(farm, recipe, now, optionId)
	if not animals then
		return
	end
	local duration = FarmMath.getFacilityDuration(farm, recipe, optionId)
	local forgone = FarmMath.estimateForgoneIncome(farm, animals, duration, now)
	local reward = FarmMath.getProductionReward(farm, recipe, now, { optionId = optionId, forgone = forgone })
	local net = (reward - forgone - FarmMath.getFacilityCost(farm, recipe)) / math.max(duration, 1)
	if net > 0 then
		facilityPaybacks[key] = cost / net / 60
		table.insert(facilityOrder, key)
	end
end

local unlockGoods: { [string]: number } = {} -- açılışlara harcanan ürünler (toplam)
local function buyUpgrade(upgrade: any)
	local speeds = FarmMath.snapshotGrowthSpeeds(save)
	local upgradeCost = FarmMath.getUpgradeCost(save, upgrade)
	for _, recipe in Config.PRODUCTION_RECIPES do
		if recipe.upgradeId == upgrade.id and recipe.options then
			facilityCosts[farmPrefix() .. recipe.id] = upgradeCost
		end
	end
	local goodsCost = FarmMath.getGoodsCost(save, upgrade)
	assert(FarmMath.removeGoodsBundle(save, goodsCost), `{upgrade.id}: ürün gereksinimi karşılanmadan alındı`)
	for goodsId, amount in goodsCost do
		unlockGoods[goodsId] = (unlockGoods[goodsId] or 0) + amount
	end
	save.cash -= upgradeCost
	save.purchased[upgrade.id] = true
	FarmMath.applyDerived(save)
	FarmMath.preserveGrowthProgress(save, speeds, now)
	actions += 1
	invested()
	mark(upgrade.id)
end

-- Bir hayvanın yetişkin olunca getireceği artış (ölçü: yatırımın geri dönüş süresi)
local function animalGain(animalId: string): number
	return FarmMath.getAnimalIncome(save, animalId)
end

local lineageTotal, lineageSpent = 0, 0
local lineageWorstByAnimal: { [string]: number } = {}
local lineageWorstPayback, lineageWorstLevel = 0, 0 -- saat; en kötü geri dönüş ve o satın almanın tür içi seviyesi
local expansionTotal, expansionSpent = 0, 0
local farmsBought = 0

---------------------------------------------------------------------------
-- Çoklu çiftlik: etkin çiftlik kökte durur, diğerleri park edilir (EconomyService.settlePlayer ile aynı hesap)
---------------------------------------------------------------------------
local function ownedFarmCount(): number
	local count = 0
	for _ in save.mainFarms do
		count += 1
	end
	return count
end

-- Alım sırası: S.order (tema numaraları; ör. 1,6,5) verilmişse ondan, yoksa en küçük sahip olunmayan tema
local function nextFarmId(): string?
	for _, index in S.order do
		if save.mainFarms[tostring(index)] == nil then
			return tostring(index)
		end
	end
	for index = 1, Config.MAIN_FARM_LIMIT do
		if save.mainFarms[tostring(index)] == nil then
			return tostring(index)
		end
	end
	return nil
end

local farmBuys: { any } = {} -- çiftlik alımları: tema, dakika, fiyat, alım öncesi kasa (en kötü sıra / fiyat tutarlılığı ölçümü)
local function buyFarm(farmId: string, price: number)
	table.insert(farmBuys, { id = farmId, minutes = math.floor(now / 6) / 10, price = price, cash = save.cash })
	save.cash -= price
	if save.progression and not save.progression.returnEnded and farmId ~= "1" then
		local speeds = FarmMath.snapshotGrowthSpeeds(save, now)
		save.progression.returnEnded = true
		FarmMath.preserveGrowthProgress(save, speeds, now)
	end
	local farm = SaveCodec.newFarm(Config, FarmMath, now, function(): string
		uidCounter += 1
		return `farm-{uidCounter}`
	end, farmId)
	FarmProfiles.capture(save)
	save.mainFarms[farmId] = farm
	farmsBought += 1
	actions += 1
	mark(`ÇİFTLİK {farmId} alındı`, true)
	FarmProfiles.select(save, farmId) -- yeni çiftliğe geçilir, öncekiler park edilir
	themeIslands = FarmMath.themeIslands(save)
	invested()
end

-- Park edilmiş çiftliklerin geliri: FarmMath.settleFarmIncome (toplayıcı varsa tamamı, yoksa PARKED_FARM_PAY_RATE kasaya)
local function accrueParked()
	for farmId in save.mainFarms do
		if farmId == save.activeMainFarmId then
			continue
		end
		local farm = FarmProfiles.view(save, farmId)
		local earned = FarmMath.computeIncomeOverInterval(farm, now - STEP, now)
		local collected, newStored = FarmMath.settleFarmIncome(farm, earned, true)
		farm.stored = newStored
		if collected > 0 then
			earn(collected, "park edilmiş çiftlik")
		end
	end
end

---------------------------------------------------------------------------
-- Üretim ve eklenti (oyuncunun elle yaptığı işler) + yardımcılar (pet)
---------------------------------------------------------------------------
local productionHooks = {
	settle = function() end,
	trySpend = function(amount: number): boolean
		if save.cash >= amount then
			save.cash -= amount
			return true
		end
		return false
	end,
	addCash = function(amount: number)
		earn(amount, "üretim (para)")
	end,
	newUid = function(): string
		uidCounter += 1
		return `job-{uidCounter}`
	end,
}

local function recipeBuilt(farm: any, recipe: any): boolean
	return farm.purchased[recipe.upgradeId] == true and farm.unlockedIslands[recipe.island] == true
end

-- En iyi parti: boştaki yetişkinlerle başlatılabilen seçenekler arasında (ödül - kaçırılan gelir - başlatma) / süre en yüksek olan
local function bestOption(farm: any, recipe: any): string?
	if not recipe.options then
		return nil
	end
	local bestId: string? = nil
	local bestScore = -math.huge
	for _, option in recipe.options do
		local animals = FarmMath.pickProductionAnimals(farm, recipe, now, option.id)
		if animals then
			local duration = FarmMath.getFacilityDuration(farm, recipe, option.id)
	local forgone = FarmMath.estimateForgoneIncome(farm, animals, duration, now)
			local reward = FarmMath.getProductionReward(farm, recipe, now, { optionId = option.id, forgone = forgone })
			local score = (reward - forgone - FarmMath.getFacilityCost(farm, recipe)) / math.max(duration, 1)
			if score > bestScore then
				bestScore, bestId = score, option.id
			end
		end
	end
	return bestId
end

local neededGoods: () -> { [string]: boolean }

-- Oyuncu önce açılış için gereken ürünü üretir (boştaki yetişkinler önce o merkezlere gider), sonra kalan tesisleri çalıştırır
local function productionOrder(): { string }
	local needed = neededGoods()
	local first: { string } = {}
	local rest: { string } = {}
	for _, recipeId in Config.PRODUCTION_ORDER do
		local recipe = Config.PRODUCTION_RECIPES[recipeId]
		table.insert(if recipe.output == "goods" and recipe.goodsId and needed[recipe.goodsId] then first else rest, recipeId)
	end
	table.move(rest, 1, #rest, #first + 1, first)
	return first
end

local function productionTick()
	for _, recipeId in productionOrder() do
		local recipe = Config.PRODUCTION_RECIPES[recipeId]
		local kind = ProductionLogic.petKind(recipe, FarmMath) -- kuluçka (chicken) simüle edilmez
		if not kind or not recipeBuilt(save, recipe) then
			continue
		end
		if FarmMath.hasPet(save, kind) then
			-- Yardımcı alınmış: oyuncu "otomatik tekrar"ı en iyi partiyle açar; teslim ve başlatma yardımcıda (anında)
			local option = bestOption(save, recipe)
			recordFacilityPayback(save, recipe, option)
			if save.autoRepeat[recipeId] == nil or option ~= nil then
				save.autoRepeat[recipeId] = option or "default"
			end
			continue
		end
		local job = save.production[recipeId]
		if job and job.readyAt <= now then
			ProductionLogic.claim(save, save, recipe, job, now, FarmMath, Config, productionHooks)
			actions += 1
		end
		if save.production[recipeId] == nil then
			local option = bestOption(save, recipe)
			recordFacilityPayback(save, recipe, option)
			local started = ProductionLogic.start(save, save, recipe, option, now, FarmMath, productionHooks)
			if started then
				actions += 1
			end
		end
	end
end

-- Ürün gereksinimi: parası yetse de ürünü eksik açılışların ihtiyaç duyduğu ürünler. Ideal oyuncu yalnızca bunları üretir (talebe göre üretim).
function neededGoods(): { [string]: boolean }
	local needed: { [string]: boolean } = {}
	for _, upgrade in Config.UPGRADES do
		if inTheme(upgrade) and upgrade.goodsCost and FarmMath.getUpgradeStatus(save, upgrade.id) == "available" then
			for _, missing in FarmMath.getGoodsShortfall(save, FarmMath.getGoodsCost(save, upgrade)) do
				needed[missing.goodsId] = true
			end
		end
	end
	return needed
end

-- Oyuncu açılış için biriktirdiği ürünü siparişe/satışa harcamaz: alınabilir açılışların gerektirdiği ürün miktarı rezerve edilir
local function reservedGoods(): { [string]: number }
	local reserved: { [string]: number } = {}
	for _, upgrade in Config.UPGRADES do
		if inTheme(upgrade) and upgrade.goodsCost and FarmMath.getUpgradeStatus(save, upgrade.id) == "available" then
			for goodsId, amount in FarmMath.getGoodsCost(save, upgrade) do
				reserved[goodsId] = math.max(reserved[goodsId] or 0, amount)
			end
		end
	end
	return reserved
end

local function goodsTick()
	local needed = neededGoods()
	for _, recipeId in Config.PRODUCTION_ORDER do
		local recipe = Config.PRODUCTION_RECIPES[recipeId]
		if recipe.output ~= "goods" or not recipeBuilt(save, recipe) then
			continue
		end
		local job = save.production[recipeId]
		if job and job.readyAt <= now then
			ProductionLogic.claim(save, save, recipe, job, now, FarmMath, Config, productionHooks)
			actions += 1
		end
		if save.production[recipeId] == nil and needed[recipe.goodsId] then
			if ProductionLogic.start(save, save, recipe, nil, now, FarmMath, productionHooks) then
				actions += 1
			end
		end
	end
end

local function runPets()
	local ids: { string } = FarmProfiles.ids(save)
	ProductionLogic.runPets(save, ids, function(farmId: string): any
		return FarmProfiles.view(save, farmId)
	end, Config.PRODUCTION_ORDER, now, FarmMath, Config, productionHooks)
end

-- Eklentiler: boştaki yetişkinler, kapasite dolana kadar gönderilir (ExtensionService.tryAssign ile aynı koşullar)
local extensionIds: { string } = {}
for extensionId in Config.EXTENSIONS do
	table.insert(extensionIds, extensionId)
end
table.sort(extensionIds)

local function extensionTick()
	for _, extensionId in extensionIds do
		local extension = Config.EXTENSIONS[extensionId]
		local upgrade = Config.getExtensionUpgrade(extensionId)
		if not (upgrade and save.purchased[upgrade.id]) then
			continue
		end
		while FarmMath.countInExtension(save, extensionId, now) < FarmMath.getExtensionCapacity(save, extensionId) do
			local picked: any = nil
			for _, animal in save.animals do
				if
					animal.animalId == extension.animalId
					and animal.zoneId == extension.sourceZoneId
					and save.unlockedZones[animal.zoneId]
					and FarmMath.getActiveTask(animal, now) == nil
					and FarmMath.getStage(animal.bornAt, now, FarmMath.getGrowthSpeed(save, animal.animalId, animal.zoneId)) == "adult"
				then
					picked = animal
					break
				end
			end
			if not picked then
				break
			end
			picked.extensionId = extensionId
			picked.task = { kind = "extension", id = extensionId, startedAt = now, endsAt = now + extension.stayDuration }
			actions += 1
		end
	end
end

-- Siparişler: bu pencerenin teklifleri arasından depodaki ürünlerle karşılanabilenleri teslim et
local function ordersTick()
	local reserve = reservedGoods()
	for _, offer in FarmMath.getContractOffers(save, now, 0) do
		local keepsReserve = true
		for _, line in offer.lines do
			if FarmMath.getGoodsAmount(save, line.goodsId) - line.amount < (reserve[line.goodsId] or 0) then
				keepsReserve = false
			end
		end
		if keepsReserve and not FarmMath.isContractDone(save, offer) and FarmMath.canFulfillContract(save, offer) then
			local reward = FarmMath.fulfillContract(save, offer.key, now, 0)
			if reward then
				local ratio = reward / math.max(offer.worth, 1)
				local minutes = reward / math.max(FarmMath.computeIncomePerSecond(save, now) * 60, 1)
				orderStat.count += 1
				orderStat.ratioSum += ratio
				orderStat.ratioMax = math.max(orderStat.ratioMax, ratio)
				orderStat.minutesSum += minutes
				orderStat.minutesMax = math.max(orderStat.minutesMax, minutes)
				for _, line in offer.lines do
					gstat(line.goodsId).ordered += line.amount
					orderStat.lineMax = math.max(orderStat.lineMax, line.amount)
				end
				earn(reward, "sipariş")
				actions += 1
				invested()
			end
		end
	end
end

-- Toplu satış: kapasitenin sellAbove oranına ulaşan ürünün yarısı "Yarısını sat" ile paraya çevrilir (FarmMath.sellGoods; sunucu ile aynı hesap)
local function sellTick()
	if S.sellAbove <= 0 then
		return
	end
	local cap = FarmMath.getGoodsCap(save)
	for _, goodsId in FarmMath.getContractGoods(save) do
		if FarmMath.getGoodsAmount(save, goodsId) >= cap * S.sellAbove and FarmMath.getGoodsAmount(save, goodsId) / 2 >= (reservedGoods()[goodsId] or 0) then
			local cash, amount = FarmMath.sellGoods(save, goodsId, "half")
			if cash and amount then
				gstat(goodsId).sold += amount
				earn(cash, "ürün satışı")
				actions += 1
			end
		end
	end
end

---------------------------------------------------------------------------
-- Ödül akışları: mevsim hedefi, günlük ödül, altın hayvan (EngagementService mantığı)
---------------------------------------------------------------------------
local function ensureSeason()
	if S.rewards then
		Rewards.ensureSeasonal(save, now)
	end
end

local function rewardsTick()
	if Rewards.seasonalClaimable(save, now) then
		local amount = Rewards.seasonalReward(save)
		save.seasonal.claimed = true
		earn(amount, "mevsim ödülü")
		actions += 1
	end
	local status = Rewards.dailyStatus(save.daily, now)
	if status.canClaim then
		local amount = Rewards.dailyAmount(save, status.nextStreak)
		save.daily = { day = Rewards.dayIndex(now), streak = status.nextStreak }
		earn(amount, "günlük ödül")
		actions += 1
	end
	local event = Golden.current(save, USER_ID, now)
	if event and Merchant.rand(USER_ID, event.cycle, 99) < S.goldenChance then
		save.golden = { key = event.cycle }
		earn(event.reward, "altın hayvan")
		actions += 1
	end
end

---------------------------------------------------------------------------
-- Yatırım: aç gözlü (hayvan > çiftlik > alan/yükseltme > ırk)
---------------------------------------------------------------------------
local function progressionTick()
	goldEarned += Progression.collectGold(save, now)
	if S.goldPolicy == "convert" then
		local state = save.progression
		local today = math.floor(now / 86400)
		local dayUsed = if state.convertedDay == today then state.convertedDayGold else 0
		local amount = math.min(save.gold, Config.PROGRESSION.gold.dailyLimit - dayUsed, Config.PROGRESSION.gold.runLimit - state.convertedRunGold)
		if amount > 0 then
			local cash = Progression.goldCashQuote(save, amount, now)
			if cash then
				save.gold -= amount
				state.convertedDay = today
				state.convertedDayGold = dayUsed + amount
				state.convertedRunGold += amount
				goldSpent += amount
				goldCash += cash
				earn(cash, "altın çevirme", false)
			end
		end
	elseif S.goldPolicy == "equipment" then
		-- Önceden belirtilen yatırım sırası; elde olmayan altınla ekipman satın alınmaz.
		for _, offerId in { "diamond_hammer", "auto_collect", "golden_crown", "income_charm_3", "golden_wings" } do
			local offer = Config.PROGRESSION.permanentOffers[offerId]
			local rights = if offer.kind == "item" then save.owned.items else save.owned.conveniences
			if not rights[offerId] then
				if save.gold < offer.goldCost then
					break
				end
				local speeds = FarmMath.snapshotGrowthSpeeds(save)
				save.gold -= offer.goldCost
				goldSpent += offer.goldCost
				rights[offerId] = true
				if offer.kind == "item" then
					local item = Config.ITEMS[offerId]
					save.inventory.items[offerId] = true
					save.inventory.equipped[item.slot] = offerId
				end
				FarmMath.preserveGrowthProgress(save, speeds, now)
			end
		end
	end
end

local function invest()
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
		-- Rebirth hedefindeki soy geliştirmesi, bütün isteğe bağlı yatırımların
		-- bitmesini beklemez. Gerçek FarmMath durumu ve fiyatı kullanılır.
		local requiredTargets = Progression.getRebirthTargets(save, save.activeMainFarmId)
		local boughtRequiredLineage = false
		for _, target in requiredTargets do
			if target.kind == "lineage" and FarmMath.getLineageLevel(save, target.id) < target.level then
				local status, _, cost = FarmMath.getLineageStatus(save, target.id)
				if status == "available" and cost <= save.cash then
					save.cash -= cost
					save.lineage = save.lineage or {}
					save.lineage[target.id] = FarmMath.getLineageLevel(save, target.id) + 1
					lineageTotal += 1
					lineageSpent += cost
					actions += 1
					invested()
					boughtRequiredLineage = true
					break
				end
			end
		end
		if boughtRequiredLineage then
			bought = true
			continue
		end
		local cheapest: any = nil
		local cheapestCost = math.huge
		local nextCost = math.huge -- alınabilir en ucuz yükseltme/genişletme (parası yetmese de)
		for _, upgrade in Config.UPGRADES do
			if inTheme(upgrade) and FarmMath.getUpgradeStatus(save, upgrade.id) == "available" then
				local upgradeCost = FarmMath.getUpgradeCost(save, upgrade)
				nextCost = math.min(nextCost, upgradeCost)
				local goodsOk = #FarmMath.getGoodsShortfall(save, FarmMath.getGoodsCost(save, upgrade)) == 0
				if goodsOk and upgradeCost <= save.cash and (not cheapest or upgradeCost < cheapestCost) then
					cheapest, cheapestCost = upgrade, upgradeCost
				end
			end
		end
		-- Alan genişletme: en ucuz yükseltmeyle yarışır (dolu bölgeler genişletilebilir)
		local expandZone: string? = nil
		local expandCost = math.huge
		for targetId, target in Config.BUILD_TARGETS do
			if table.find(themeIslands, target.island) then
				local status, _, cost = FarmMath.getExpansionStatus(save, targetId)
				if status == "available" then
					nextCost = math.min(nextCost, cost)
					if cost <= save.cash and cost < expandCost then
						expandZone, expandCost = targetId, cost
					end
				end
			end
		end
		-- Yeni çiftlik: fiyatı, bu çiftlikte alınabilecek en ucuz yatırımdan düşükse (ya da yatırım kalmadıysa) alınır
		local farmId = nextFarmId()
		local farmPrice = if farmId then FarmMath.getPrice(save, "farm", nil, tonumber(farmId)) else nil
		-- finishFirst: bir sonraki çiftlik yalnızca etkin çiftliğin tüm yükseltmeleri bitince alınır (çiftlik tamamlama süresi ölçümü)
		local farmDue = if S.finishFirst then (if S.completion == "basic" then Progression.isRebirthFarmComplete(save, save.activeMainFarmId) else milestones[farmPrefix() .. "TÜM YÜKSELTMELER"] ~= nil) else farmPrice ~= nil and farmPrice <= nextCost
		if S.farms > ownedFarmCount() and farmId and farmPrice and farmPrice <= save.cash and farmDue then
			buyFarm(farmId, farmPrice)
			bought = true
			continue
		end
		if expandZone and (not cheapest or expandCost < cheapestCost) then
			save.cash -= expandCost
			save.expansions = save.expansions or {}
			local speedsBefore = FarmMath.snapshotGrowthSpeeds(save)
			save.expansions[expandZone] = FarmMath.getExpansionLevel(save, expandZone) + 1
			FarmMath.preserveGrowthProgress(save, speedsBefore, now)
			expansionTotal += 1
			expansionSpent += expandCost
			actions += 1
			invested()
			local sum = levelSum(save.expansions)
			for _, mark_at in { 5, 15, 30 } do
				if sum == mark_at then
					mark(`ALAN toplam Sv.{mark_at}`)
				end
			end
			bought = true
		elseif cheapest then
			buyUpgrade(cheapest)
			bought = true
		elseif milestones[farmPrefix() .. "TÜM YÜKSELTMELER"] ~= nil then
			-- Oyun sonu: tüm yükseltmeler alındıysa kasa ırk geliştirmeye gider (en iyi geri dönüş önce)
			local bestLineage: string? = nil
			local bestLineagePayback = math.huge
			local bestCost = 0
			for _, animalId in Config.ANIMAL_ORDER do
				local status, _, cost = FarmMath.getLineageStatus(save, animalId)
				if status == "available" and cost <= save.cash then
					local before = income()
					save.lineage = save.lineage or {}
					save.lineage[animalId] = FarmMath.getLineageLevel(save, animalId) + 1
					local gain = income() - before
					save.lineage[animalId] -= 1
					local payback = cost / math.max(gain, 0.0001)
					if payback < bestLineagePayback then
						bestLineagePayback, bestLineage, bestCost = payback, animalId, cost
					end
				end
			end
			if bestLineage then
				save.cash -= bestCost
				save.lineage = save.lineage or {}
				lineageWorstByAnimal[bestLineage] = math.max(lineageWorstByAnimal[bestLineage] or 0, bestLineagePayback / 3600)
				if bestLineagePayback / 3600 > lineageWorstPayback then
					lineageWorstPayback = bestLineagePayback / 3600
					lineageWorstLevel = FarmMath.getLineageLevel(save, bestLineage) + 1
				end
				save.lineage[bestLineage] = FarmMath.getLineageLevel(save, bestLineage) + 1
				lineageTotal += 1
				lineageSpent += bestCost
				actions += 1
				invested()
				local sum = levelSum(save.lineage)
				for _, mark_at in { 10, 30, 60, 90 } do
					if sum == mark_at then
						mark(`IRK toplam Sv.{mark_at}`)
					end
				end
				bought = true
			end
		end
	end
end

---------------------------------------------------------------------------
-- Zaman döngüsü
---------------------------------------------------------------------------
local lastReport = 0
local reportEvery = if HOURS > 24 then 1440 else 60 -- dakika: 24 saatten uzun koşuda günlük özet
local reportUnit = if HOURS > 24 then "gün" else "saat"
local reports: { string } = {}
local hourly: { any } = {}
local function ownedUpgradeCount(): number
	local n = 0
	for _ in save.purchased do
		n += 1
	end
	return n
end

local function reportCheck()
	local minute = (now - START) / 60
	while minute - lastReport >= reportEvery do
		lastReport += reportEvery
		local label = math.floor(lastReport / reportEvery + 0.5)
		table.insert(reports, string.format("  %2d. %s: gelir %s/sn · depo %d sn · %d hayvan · %d yükseltme", label, reportUnit, FarmMath.formatRate(income()), math.floor(FarmMath.getStorageCap(save) / math.max(income(), 1e-9)), #save.animals, ownedUpgradeCount()))
		table.insert(hourly, {
			index = label,
			unit = reportUnit,
			incomePerSecond = income(),
			animals = #save.animals,
			upgrades = ownedUpgradeCount(),
			cash = save.cash,
			farm = save.activeMainFarmId,
		})
	end
end

local nextDecision, nextProd, nextExt = 0, 0, 0
local function onlineStep()
	local t = now - START
	refreshStages()
	local rate = income()
	local fullFraction = 0
	if COLLECT > 0 and not FarmMath.hasAutoCollect(save) then
		local cap = FarmMath.getStorageCap(save)
		if rate * COLLECT > cap then
			fullFraction = 1 - cap / (rate * COLLECT)
		end
		rate = math.min(rate * COLLECT, cap) / COLLECT
		actions += STEP / COLLECT
	end
	onlineSeconds += STEP
	fullSeconds += STEP * fullFraction
	sampleGoods(STEP)
	earn(rate * STEP, "hayvan geliri")
	accrueParked()
	if S.prodInterval > 0 then
		runPets()
	end
	ensureSeason()
	if t >= nextDecision then
		nextDecision = t + S.react
		if S.rewards then
			rewardsTick()
		end
		if S.orders and S.prodInterval <= 0 then
			ordersTick()
		end
		invest()
		progressionTick()
		if S.prodInterval <= 0 then
			goodsTick()
		end
	end
	if S.prodInterval > 0 and t >= nextProd then
		nextProd = t + S.prodInterval
		productionTick()
		if S.orders then
			ordersTick()
		end
		sellTick()
	end
	if S.extInterval > 0 and t >= nextExt then
		nextExt = t + S.extInterval
		extensionTick()
	end

	if milestones[farmPrefix() .. "TÜM YÜKSELTMELER"] == nil then
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
	reportCheck()
	if Progression.isFarmComplete(save) then
		mark("TEMEL YÜKSELTMELER")
	end
	if Progression.canRebirth(save) then
		mark("REBIRTH HAZIR", true)
	end
end

-- Çevrimdışı dönem: SaveCodec.decode gibi her çiftlik (park edilmişler dahil) kendi görünümüyle
-- computeOfflineEarnings hesaplar; hepsi ortak kasaya yatar (decodeFarm -> refundedTotal; ömür boyu kazanca sayılmaz).
local function goOffline(from: number, to: number)
	local lastSeen = START + from
	now = START + to
	for farmId in save.mainFarms do
		local farm = FarmProfiles.view(save, farmId)
		earn(FarmMath.computeOfflineEarnings(farm, lastSeen, now), "çevrimdışı", false)
		for _, animal in farm.animals do
			if animal.task and animal.task.endsAt <= now then
				animal.task = nil
				animal.extensionId = nil
			end
		end
	end
	refreshStages()
	reportCheck()
end

local sessions: { { number } } = {}
if S.session <= 0 then
	sessions = { { 0, TOTAL } }
else
	local n = 0
	local phase = START % S.period
	while n * S.period - phase < TOTAL do
		local from = n * S.period - phase
		local finish = math.min(from + S.session, TOTAL)
		if finish > math.max(0, from) then
			table.insert(sessions, { math.max(0, from), finish })
		end
		n += 1
	end
end

local lastSeenAt: number? = 0
for _, window in sessions do
	if lastSeenAt and window[1] > lastSeenAt then
		goOffline(lastSeenAt, window[1])
	end
	local t = window[1]
	while t + STEP <= window[2] do
		t += STEP
		now = START + t
		onlineStep()
		if S.stopAtRebirth and milestones["REBIRTH HAZIR"] then
			break
		end
	end
	lastSeenAt = t
	if S.stopAtRebirth and milestones["REBIRTH HAZIR"] then
		break
	end
end
if lastSeenAt and lastSeenAt < TOTAL and not (S.stopAtRebirth and milestones["REBIRTH HAZIR"]) then
	goOffline(lastSeenAt, TOTAL)
end
now = START + (lastSeenAt or 0)

---------------------------------------------------------------------------
-- Çıktı
---------------------------------------------------------------------------
local lines: { string } = {}
local function emit(text: string)
	table.insert(lines, text)
end

local theme = Config.getTheme(FARM)
local goals: { [string]: string } = {}
local targets = { 15, 45, 110 }
for index, islandId in theme.satellites do
	goals[Config.FARM_ISLANDS[islandId].upgradeId] = `hedef ~{targets[index]} dk`
end
goals["TÜM YÜKSELTMELER"] = "hedef 240-300 dk"

emit(`ADIM ZAMANLARI (dakika, {if S.persona == "ideal" then "ideal" else S.persona} oyuncu)`)
emit(`ÇİFTLİK {FARM} · {theme.displayName} · ana hayvan: {homeAnimal}`)
local milestoneRows: { any } = {}
for _, name in order do
	emit(string.format("  %8.1f dk  %s%s", milestones[name], name, if goals[name] then `   ({goals[name]})` else ""))
	table.insert(milestoneRows, { name = name, minutes = milestones[name] })
end
emit("SAATLİK DURUM")
for _, line in reports do
	emit(line)
end
local total, owned = 0, 0
for _, upgrade in Config.UPGRADES do
	total += 1
	if save.purchased[upgrade.id] then
		owned += 1
	end
end
emit(string.format("Sonuç: %d/%d yükseltme alındı, kasa %s", owned, total, FarmMath.formatMoney(save.cash)))
emit(string.format("Alan genişletme: toplam Sv.%d, harcanan %s", expansionTotal, FarmMath.formatMoney(expansionSpent)))
emit(string.format("Irk geliştirme: toplam Sv.%d, harcanan %s", lineageTotal, FarmMath.formatMoney(lineageSpent)))
emit(string.format("Irk geri dönüş: en kötü %.2f sa (Sv.%d satın alımı)", lineageWorstPayback, lineageWorstLevel))
do
	local parts = {}
	for _, animalId in Config.ANIMAL_ORDER do
		if lineageWorstByAnimal[animalId] then
			table.insert(parts, string.format("%s %.2f", animalId, lineageWorstByAnimal[animalId]))
		end
	end
	emit("  tür başına en kötü (sa): " .. table.concat(parts, " · "))
end

if #facilityOrder > 0 then
	local parts = {}
	for _, key in facilityOrder do
		table.insert(parts, string.format("%s %.0f", key, facilityPaybacks[key]))
	end
	emit("Tesis geri ödeme (dk, en iyi parti sürekli): " .. table.concat(parts, " · "))
end

-- Eylem, depo ve gelir kaynakları
local onlineMinutes = onlineSeconds / 60
local actionsPerMinute = if onlineMinutes > 0 then actions / onlineMinutes else 0
local fullPercent = if onlineSeconds > 0 then fullSeconds / onlineSeconds * 100 else 0
local sourceTotal = 0
for _, name in sourceOrder do
	sourceTotal += sources[name]
end
local sourceRows: { any } = {}
for _, name in sourceOrder do
	table.insert(sourceRows, { name = name, amount = sources[name], share = if sourceTotal > 0 then sources[name] / sourceTotal * 100 else 0 })
end
table.sort(sourceRows, function(a: any, b: any): boolean
	return a.amount > b.amount
end)
emit(`EYLEM VE DEPO (oyuncu: {S.persona}, oturum: {if S.session > 0 then `{S.session // 60} dk x {math.floor(86400 / S.period * 10 + 0.5) / 10}/gün` else "kesintisiz"})`)
emit(string.format("  çevrimiçi %.0f dk · %d eylem · dakikada %.2f eylem", onlineMinutes, math.floor(actions + 0.5), actionsPerMinute))
emit(string.format("  depo dolu geçen süre: %%%.1f (çevrimiçi sürenin)", fullPercent))
local goodsRows: { any } = {}
do
	emit("ÜRÜN DENGESİ (ahır deposu; birim/dk = çevrimiçi dakika başına)")
	local totalProduced, totalOrdered, totalSold, totalBartered, fillWeighted, fillSeconds = 0, 0, 0, 0, 0, 0
	for _, goodsId in Config.GOODS_ORDER do
		local row = goodsStat[goodsId]
		if row and row.fillSeconds > 0 then
			local minutes = math.max(onlineMinutes, 1e-9)
			local fill = row.fillSum / row.fillSeconds * 100
			local full = row.fullSeconds / row.fillSeconds * 100
			table.insert(goodsRows, {
				id = goodsId, produced = row.produced, ordered = row.ordered, sold = row.sold, bartered = row.bartered,
				overflow = row.overflow, fillPercent = fill, fullPercent = full,
			})
			emit(string.format("  %-10s üretim %6.2f/dk · pano %6.2f/dk · toptan %6.2f/dk · takas %6.2f/dk · taşan %5d · ort. doluluk %%%5.1f · dolu %%%5.1f", goodsId, row.produced / minutes, row.ordered / minutes, row.sold / minutes, row.bartered / minutes, row.overflow, fill, full))
			totalProduced += row.produced
			totalOrdered += row.ordered
			totalSold += row.sold
			totalBartered += row.bartered
			fillWeighted += row.fillSum
			fillSeconds += row.fillSeconds
		end
	end
	if fillSeconds > 0 then
		local minutes = math.max(onlineMinutes, 1e-9)
		emit(string.format("  TOPLAM     üretim %6.2f/dk · pano %6.2f/dk · toptan %6.2f/dk · takas %6.2f/dk · ort. doluluk %%%5.1f", totalProduced / minutes, totalOrdered / minutes, totalSold / minutes, totalBartered / minutes, fillWeighted / fillSeconds * 100))
	end
	if orderStat.count > 0 then
		emit(string.format("  SİPARİŞ ÖLÇÜMÜ: %d teslim · ödül/değer ort. %.2f, en çok %.2f · ödül ort. %.1f, en çok %.1f dk gelir · satır en çok %d birim · parti en çok %d birim", orderStat.count, orderStat.ratioSum / orderStat.count, orderStat.ratioMax, orderStat.minutesSum / orderStat.count, orderStat.minutesMax, orderStat.lineMax, orderStat.batchMax))
	end
	local unlockUnits, unlockWorth = 0, 0
	for goodsId, amount in unlockGoods do
		unlockUnits += amount
		unlockWorth += amount * Config.GOODS[goodsId].value
	end
	emit(string.format("  AÇILIŞ ÜRÜNÜ harcanan %d birim (değer %s) · üretilenin %%%.1f'i", unlockUnits, FarmMath.formatMoney(unlockWorth), if totalProduced > 0 then unlockUnits / totalProduced * 100 else 0))
end
emit(string.format("GELİR KAYNAKLARI (toplam %s)", FarmMath.formatMoney(sourceTotal)))
for _, row in sourceRows do
	emit(string.format("  %%%5.1f  %-22s %s", row.share, row.name, FarmMath.formatMoney(row.amount)))
end
local farmRows: { any } = {}
if ownedFarmCount() > 1 then
	emit(`ÇİFTLİKLER ({ownedFarmCount()} sahip · etkin: {save.activeMainFarmId})`)
end
for _, farmId in FarmProfiles.ids(save) do
	local farm = FarmProfiles.view(save, farmId)
	local count = 0
	for _ in farm.purchased do
		count += 1
	end
	local rate = FarmMath.computeIncomePerSecond(farm, now)
	table.insert(farmRows, { id = farmId, animals = #farm.animals, upgrades = count, incomePerSecond = rate, autoCollect = FarmMath.hasAutoCollect(farm) })
	if ownedFarmCount() > 1 then
		emit(string.format("  Ç%s: %d hayvan · %d yükseltme · gelir %s/sn%s", farmId, #farm.animals, count, FarmMath.formatRate(rate), if FarmMath.hasAutoCollect(farm) then " · otomatik" else ""))
	end
end

if not S.json then
	print(table.concat(lines, "\n"))
else
	local function encode(value: any): string
		local kind = typeof(value)
		if kind == "number" then
			if value ~= value or value == math.huge or value == -math.huge then
				return "null"
			end
			if value == math.floor(value) and math.abs(value) < 1e15 then
				return string.format("%d", value)
			end
			return string.format("%.6g", value)
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
	local nextAccount = nil
	if S.applyRebirth and Progression.canRebirth(save) then
		local function copy(value: any): any
			if typeof(value) ~= "table" then
				return value
			end
			local result = {}
			for key, child in value do
				result[key] = copy(child)
			end
			return result
		end
		local nextSave = copy(save)
		FarmProfiles.capture(nextSave)
		local choice = nil
		for offset = 0, #Config.PROGRESSION.perkOrder - 1 do
			local id = Config.PROGRESSION.perkOrder[(nextSave.progression.count + offset) % #Config.PROGRESSION.perkOrder + 1]
			if Progression.canChoosePerk(nextSave, id) then
				choice = id
				break
			end
		end
		assert(choice, "No perk available before configured rebirth cap")
		assert(Rebirth.apply(nextSave, Config, FarmMath, Progression, SaveCodec, now, function(): string
			readyUid += 1
			return `next-{readyUid}`
		end, choice), "Actual rebirth transformation failed")
		nextAccount = { gold = nextSave.gold, owned = nextSave.owned, inventory = nextSave.inventory,
			progression = nextSave.progression, lifetimeEarned = nextSave.lifetimeEarned }
	end
	print(encode({
		settings = {
			persona = S.persona, hours = HOURS, farm = FARM, collect = COLLECT, react = S.react,
			session = S.session / 60, period = S.period / 3600, prodInterval = S.prodInterval, extInterval = S.extInterval,
			orders = S.orders, rewards = S.rewards, goldenChance = S.goldenChance, farms = S.farms, sellAbove = S.sellAbove,
			completion = S.completion, rebirth = S.rebirth, goldPolicy = S.goldPolicy, runDouble = S.runDouble, equipment = S.equipment, perks = S.perks,
		},
		milestones = milestoneRows,
		hourly = hourly,
		totals = {
			upgradesOwned = owned,
			upgradesTotal = total,
			cash = save.cash,
			incomePerSecond = income(),
			animals = #save.animals,
			onlineMinutes = onlineMinutes,
			actions = math.floor(actions + 0.5),
			actionsPerMinute = actionsPerMinute,
			storageFullPercent = fullPercent,
			goods = goodsRows,
			orders = orderStat,
			unlockGoods = unlockGoods,
			expansionLevels = expansionTotal,
			expansionSpent = expansionSpent,
			lineageLevels = lineageTotal,
			lineageSpent = lineageSpent,
			lineageWorstPaybackHours = lineageWorstPayback,
			farmsOwned = ownedFarmCount(),
			lifetimeEarned = save.lifetimeEarned,
			allUpgradesMinutes = milestones["TÜM YÜKSELTMELER"],
			rebirthMinutes = milestones["REBIRTH HAZIR"],
			gold = save.gold, goldEarned = goldEarned, goldSpent = goldSpent, goldCash = goldCash,
		},
		sources = sourceRows,
		farms = farmRows,
		farmBuys = farmBuys,
		account = { gold = save.gold, owned = save.owned, inventory = save.inventory, progression = save.progression },
		nextAccount = nextAccount,
	}))
end
"""


def lua_literal(value: object) -> str:
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (int, float)):
        return repr(value)
    if isinstance(value, str):
        return json.dumps(value)
    if isinstance(value, list):
        return "{ " + ", ".join(lua_literal(item) for item in value) + " }"
    if isinstance(value, dict):
        return "{ " + ", ".join(f"[{lua_literal(key)}] = {lua_literal(item)}" for key, item in value.items()) + " }"
    raise TypeError(f"Luau değerine çevrilemedi: {value!r}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--luau", help="Luau yorumlayıcısı yolu")
    parser.add_argument("--hours", type=float, default=6.0, help="Simüle edilecek süre (saat)")
    parser.add_argument("--days", type=float, help="Simüle edilecek süre (gün); --hours'u ezer")
    parser.add_argument("--farm", default="1", help="Başlangıç çiftliği numarası (tema): 1-6")
    parser.add_argument("--order", default="", help="Çiftlik alım sırası (tema numaraları, virgülle; ör. 1,6,5,4,3,2 = en kötü sıra); boşsa 1,2,3...")
    parser.add_argument("--mults", default="", help="Deneme: kademe çiftlik çarpanları (virgülle: 1,2,3...); boşsa Config.DIFFICULTY")
    parser.add_argument("--premium", default="", help="Deneme: ada açılış primi, sıra başına perTier:power (virgülle: 5:0.72,1.7:0.78,1.3:0.1)")
    parser.add_argument("--goods-tier", type=float, default=None, help="Deneme: DIFFICULTY.goods.tierGrowth")
    parser.add_argument("--goods-step", default="", help="Deneme: DIFFICULTY.goods.stepBase (virgülle 3 değer)")
    parser.add_argument("--slot-spread", type=float, default=None, help="Deneme: DIFFICULTY.slotSpread")
    parser.add_argument("--cost-base", type=float, default=600, help="Deneme: bu değerin üstündeki yükseltme maliyetleri büyütülür")
    parser.add_argument("--cost-exp", type=float, default=0, help="Deneme: maliyet üssü (0 = kapalı)")
    parser.add_argument("--collect", type=float, default=None, help="Oyuncu platforma kaç saniyede bir uğrar (varsayılan 120 ya da persona; 0 = anında topla)")
    parser.add_argument("--cap-mult", type=float, default=1, help="Deneme: ahır depo kapasitelerinin çarpanı")
    parser.add_argument("--price-growth", type=float, default=0, help="Deneme: ANIMAL_PRICE_GROWTH (0 = Config değeri)")
    parser.add_argument("--persona", choices=sorted(PERSONAS), default="ideal", help="Oyuncu tipi ön ayarı (ideal = eski model)")
    parser.add_argument("--session", type=float, default=None, help="Oturum süresi (dk); 0 = hiç çıkma")
    parser.add_argument("--offline", type=float, default=None, help="Oturumlar arası çevrimdışı süre (saat); verilmezse 24 / --sessions-per-day")
    parser.add_argument("--sessions-per-day", type=float, default=None, help="Günlük oturum sayısı")
    parser.add_argument("--react", type=float, default=None, help="Tepki gecikmesi: karar aralığı (sn); 0 = her an")
    parser.add_argument("--prod-interval", type=float, default=None, help="Üretim partisi yeniden başlatma aralığı (sn); 0 = üretim yok")
    parser.add_argument("--ext-interval", type=float, default=None, help="Eklentileri yeniden doldurma aralığı (sn); 0 = eklenti yok")
    parser.add_argument("--orders", action=argparse.BooleanOptionalAction, default=None, help="Ahır siparişlerini teslim et")
    parser.add_argument("--rewards", action=argparse.BooleanOptionalAction, default=None, help="Günlük, mevsim ve altın hayvan ödüllerini al")
    parser.add_argument("--golden-chance", type=float, default=None, help="Altın hayvanı yakalama olasılığı (0-1)")
    parser.add_argument("--sell-above", type=float, default=None, help="Bir ürün depo kapasitesinin bu oranına ulaşınca yarısını sat (Yarısını sat; 0 = hiç satma)")
    parser.add_argument("--finish-first", action="store_true", help="Sonraki çiftlik yalnızca etkin çiftliğin tüm yükseltmeleri bitince alınır (çiftlik tamamlama süresi)")
    parser.add_argument("--completion", choices=["all", "basic"], default="all", help="Çiftlik bitiş filtresi: basic = rebirth koşulu, seviye zincirleri hariç")
    parser.add_argument("--rebirth", type=int, default=0, help="Başlangıçtaki rebirth sayısı; geçmiş turların süresini simüle etmez")
    parser.add_argument("--perks", default="", help="Başlangıç etki seviyeleri: income:1,growth:2; toplamı --rebirth ile aynı olmalı")
    parser.add_argument("--equipment", default="", help="Başlangıç kalıcı ekipman kimlikleri; önceden edinilmiş sahiplik senaryosu")
    parser.add_argument("--conveniences", default="", help="Başlangıç kalıcı kolaylıklar: auto_collect,pet_cash,pet_goods")
    parser.add_argument("--run-double", action="store_true", help="Bu tur 2x ürününün teslim edildiği senaryo")
    parser.add_argument("--starting-gold", type=int, default=0, help="Önceden birikmiş/satın alınmış altın")
    parser.add_argument("--gold-policy", choices=["save", "convert", "equipment"], default="save")
    parser.add_argument("--stop-at-rebirth", action="store_true", help="Rebirth hazır olunca koşuyu bitir")
    parser.add_argument("--carry-account", help="Önceki simülasyonun gerçek Rebirth.apply çıktısını taşıyan JSON dosyası")
    parser.add_argument("--apply-rebirth", action="store_true", help="Hazırsa gerçek rebirth dönüşümünü uygulayıp sonraki hesap durumunu döndür")
    parser.add_argument("--farms", type=int, default=None, help="Sahip olunacak en çok ana çiftlik sayısı (1 = çoklu çiftlik yok)")
    parser.add_argument("--json", action="store_true", help="Makine okunur JSON çıktısı")
    parser.add_argument("--smoke", action="store_true", help="Duman testi: JSON'u kendisi ayrıştırır ve hayvan sayısını doğrular (PowerShell boru hattı BOM'u olmadan)")
    args = parser.parse_args()
    carry_account = json.loads(Path(args.carry_account).read_text(encoding="utf-8")) if args.carry_account else None
    if carry_account:
        args.rebirth = carry_account["progression"]["count"]
        args.perks = ",".join(f"{key}:{level}" for key, level in carry_account["progression"]["perks"].items())
    if args.rebirth < 0 or args.rebirth > 1000000 or args.starting_gold < 0 or args.starting_gold > 1000000000:
        parser.error("Rebirth ve altın sınırları geçersiz")
    try:
        perk_pairs = [part.split(":") for part in args.perks.split(",") if part.strip()]
        perks = {key: int(level) for key, level in perk_pairs}
        if len(perks) != len(perk_pairs) or any(level < 1 or level > 5 for level in perks.values()):
            raise ValueError("invalid levels")
    except (ValueError, TypeError):
        parser.error("--perks kimlik:1..5 biçiminde olmalı; aynı kimlik iki kez kullanılamaz")
    perk_order = ["income", "growth", "starting_cash", "upgrade_discount", "facility_speed", "offline", "contract", "ready_start"]
    if any(key not in perk_order for key in perks):
        parser.error("Bilinmeyen etki")
    if not perks:
        left = min(args.rebirth, 40)
        for key in perk_order:
            level = min(left, 5)
            if level:
                perks[key] = level
            left -= level
    if sum(perks.values()) != min(args.rebirth, 40):
        parser.error("Etki seviyeleri toplamı rebirth sayısıyla uyuşmuyor")
    executable = args.luau or shutil.which("luau")
    if executable is None:
        bundled = ROOT / ".tools" / "luau" / ("luau.exe" if sys.platform == "win32" else "luau")
        if bundled.is_file():
            executable = str(bundled)
    if executable is None:
        parser.error("Luau yorumlayıcısı bulunamadı; --luau ile yol ver.")

    preset = PERSONAS[args.persona]

    def pick(name: str, cli: object, default: object) -> object:
        return cli if cli is not None else preset.get(name, default)

    hours = args.days * 24 if args.days is not None else args.hours
    collect = float(pick("collect", args.collect, 120))
    session = float(pick("session", args.session, 0))
    per_day = float(pick("sessions_per_day", args.sessions_per_day, 1))
    if per_day <= 0:
        parser.error("--sessions-per-day 0'dan büyük olmalı")
    offline = args.offline
    # Oturum başlangıçları arası süre: verilmişse oturum + çevrimdışı süre, yoksa bir gün / günlük oturum sayısı
    period = session * 60 + offline * 3600 if offline is not None else 86400 / per_day
    period = max(period, session * 60, 1)
    settings = {
        "persona": args.persona,
        "react": float(pick("react", args.react, 0)),
        "session": session * 60,
        "period": period,
        "prodInterval": float(pick("prod_interval", args.prod_interval, 0)),
        "extInterval": float(pick("ext_interval", args.ext_interval, 0)),
        "orders": bool(pick("orders", args.orders, False)),
        "rewards": bool(pick("rewards", args.rewards, False)),
        "goldenChance": float(pick("golden", args.golden_chance, 1.0)),
        "farms": int(pick("farms", args.farms, 1)),
        "order": [int(item) for item in args.order.split(",") if item.strip()],
        "finishFirst": args.finish_first,
        "completion": args.completion,
        "rebirth": args.rebirth,
        "perks": perks,
        "equipment": [item.strip() for item in args.equipment.split(",") if item.strip()],
        "conveniences": [item.strip() for item in args.conveniences.split(",") if item.strip()],
        "runDouble": args.run_double,
        "startingGold": args.starting_gold,
        "goldPolicy": args.gold_policy,
        "stopAtRebirth": args.stop_at_rebirth,
        "carryAccount": carry_account or False,
        "applyRebirth": args.apply_rebirth,
        "mults": [float(item) for item in args.mults.split(",") if item.strip()],
        "premium": [[float(value) for value in part.split(":")] for part in args.premium.split(",") if part.strip()],
        "slotSpread": args.slot_spread if args.slot_spread is not None else False,
        "goodsTierGrowth": args.goods_tier if args.goods_tier is not None else False,
        "goodsStepBase": [float(item) for item in args.goods_step.split(",") if item.strip()],
        "sellAbove": float(pick("sell_above", args.sell_above, 0)),
        "json": args.json or args.smoke,
    }

    module = run_tests.module
    pieces = [
        "--!nocheck\n",
        "local Color3 = { fromRGB = function(r, g, b) return { R = r / 255, G = g / 255, B = b / 255 } end }\n",
        run_tests.config_bundle(freeze=False),  # ayar denemeleri değiştirebilsin
        module("GameTypes", "src/shared/GameTypes.luau"),
        "local Environment = { getIncomeMultiplier = function() return 1 end }\n",
        run_tests.farm_math_bundle(),
        module("Progression", "src/shared/Modules/Progression.luau", {"Config", "FarmMath"}),
        module("SessionLock", "src/server/Modules/SessionLock.luau"),
        module("FarmProfiles", "src/server/Modules/FarmProfiles.luau"),
        module("Preferences", "src/server/Modules/Preferences.luau"),
        module("TransferRules", "src/server/Modules/TransferRules.luau"),
        module("TransferLedger", "src/server/Modules/TransferLedger.luau", {"TransferRules"}),
        run_tests.save_codec_bundle(),
        module("Rebirth", "src/server/Modules/Rebirth.luau"),
        module("ProductionRules", "src/server/Modules/ProductionRules.luau"),
        module("ProductionLogic", "src/server/Modules/ProductionLogic.luau", {"ProductionRules"}),
        module("Rewards", "src/shared/Modules/Rewards.luau", {"Config", "FarmMath"}),
        module("Merchant", "src/shared/Modules/Merchant.luau", {"Config", "FarmMath"}),
        module("Golden", "src/shared/Modules/Golden.luau", {"Config", "FarmMath", "Merchant"}),
        SIMULATION.replace("__HOURS__", str(hours)).replace("__FARM__", str(args.farm))
        .replace("__COST_BASE__", str(args.cost_base))
        .replace("__COST_EXP__", str(args.cost_exp))
        .replace("__PRICE_GROWTH__", str(args.price_growth))
        .replace("__COLLECT__", str(collect))
        .replace("__CAP_MULT__", str(args.cap_mult))
        .replace("__SETTINGS__", lua_literal(settings)),
    ]
    output = ROOT / ".test-build" / f"simulate-{os.getpid()}.luau"  # paralel koşular birbirinin dosyasını ezmesin
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text("\n".join(pieces), encoding="utf-8")
    try:
        if not (args.json or args.smoke):
            return subprocess.run([executable, str(output)], cwd=ROOT, check=False).returncode
        result = subprocess.run([executable, str(output)], cwd=ROOT, check=False, capture_output=True)
    finally:
        output.unlink(missing_ok=True)
    if result.returncode != 0:
        sys.stderr.write(result.stderr.decode("utf-8", errors="replace"))
        sys.stdout.write(result.stdout.decode("utf-8", errors="replace"))
        return result.returncode
    data = json.loads(result.stdout.decode("utf-8-sig"))
    if args.smoke:
        assert data["totals"]["animals"] > 0, "simülasyon hayvan üretmedi"
        print(f"Simülasyon duman testi tamam ({data['totals']['animals']} hayvan).")
        return 0
    sys.stdout.buffer.write(json.dumps(data, ensure_ascii=False).encode("utf-8") + b"\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
