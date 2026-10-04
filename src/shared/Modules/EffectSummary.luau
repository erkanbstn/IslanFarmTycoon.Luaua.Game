--!strict
-- Gösterim hesapları gerçek FarmMath kurallarını kullanır; kaynak farkları birbirine eklenmez.
local Config = require(script.Parent.Parent:WaitForChild("Config"))
local FarmMath = require(script.Parent:WaitForChild("FarmMath"))
local Progression = require(script.Parent:WaitForChild("Progression"))
local GameTypes = require(script.Parent.Parent:WaitForChild("GameTypes"))

type PlayerSave = GameTypes.PlayerSave
local EffectSummary = {}

export type Equipment = { id: string, slot: string, equipped: boolean, permanent: boolean }
export type Source = { id: string, label: string, incomeDelta: number }
export type Snapshot = {
	income: number,
	incomeFactor: number,
	uncappedIncomeFactor: number,
	incomeCapped: boolean,
	passFactor: number,
	runDouble: boolean,
	returnActive: boolean,
	returnSeconds: number,
	offlineRate: number,
	offlineHours: number,
	storageCap: number,
	growthSpeed: number,
	movementMultiplier: number,
	homeAnimal: string,
	count: number,
	equipment: { Equipment },
	sources: { Source },
	contractBonus: number,
	facilities: { { id: string, duration: number, goods: number? } },
	zones: { { id: string, capacity: number, growthSpeed: number, lineage: number } },
	islands: { string },
	upgradeQuote: { id: string, price: number, withoutEquipmentAndPerk: number }?,
}

function EffectSummary.snapshot(save: PlayerSave, now: number, includeSources: boolean?): Snapshot
	local income = FarmMath.computeIncomePerSecond(save, now)
	local itemBonus = FarmMath.getEquippedBonus(save, "incomeBonus")
	local raw = (1 + itemBonus) * (1 + FarmMath.getPerkBonus(save, "incomeBonus"))
	local factor = Progression.getIncomeMultiplier(save, 1 + itemBonus)
	local record = save.progression
	local passFactor = 1
	for id, pass in Config.PRODUCTS.passes do
		if pass.incomeMultiplier and save.passes and save.passes[id] then
			passFactor *= pass.incomeMultiplier
		end
	end
	local runDouble = record ~= nil and record.runDouble == true
	if runDouble then
		passFactor = math.max(passFactor, 2)
	end
	local homeAnimal = Config.getHomeAnimal(save.farmId or save.activeMainFarmId)
	local returnActive = homeAnimal == "cow" and FarmMath.isReturnActive(save, now)
	local offlineRate, offlineHours = FarmMath.getOfflineTerms(save)
	local equipment: { Equipment } = {}
	for _, id in Config.ITEM_ORDER do
		local item = Config.ITEMS[id]
		local permanent = save.owned ~= nil and save.owned.items[id] == true
		local inventory = save.inventory
		if permanent or (inventory and inventory.items[id] == true) then
			local entry: Equipment = {
				id = id,
				slot = item.slot,
				equipped = inventory ~= nil and inventory.equipped[item.slot] == id,
				permanent = permanent,
			}
			table.insert(equipment, entry)
		end
	end
	local sources: { Source } = {}
	local facilities: { { id: string, duration: number, goods: number? } } = {}
	local zones: { { id: string, capacity: number, growthSpeed: number, lineage: number } } = {}
	local islands: { string } = {}
	local upgradeQuote: { id: string, price: number, withoutEquipmentAndPerk: number }? = nil
	local function source(id: string, label: string, alternative: PlayerSave)
		table.insert(
			sources,
			{ id = id, label = label, incomeDelta = income - FarmMath.computeIncomePerSecond(alternative, now) }
		)
	end
	if includeSources then
		for _, id in Config.getTheme(save.farmId or save.activeMainFarmId).satellites do
			if save.unlockedIslands[id] then
				table.insert(islands, id)
			end
		end
		for id, recipe in Config.PRODUCTION_RECIPES do
			if
				save.purchased[recipe.upgradeId]
				and Config.upgradeInTheme(
					Config.getUpgrade(recipe.upgradeId) :: Config.UpgradeConfig,
					save.farmId or save.activeMainFarmId
				)
			then
				table.insert(facilities, {
					id = id,
					duration = FarmMath.getFacilityDuration(save, recipe),
					goods = if recipe.output == "goods" then FarmMath.previewGoodsYield(save, recipe, now) else nil,
				})
			end
		end
		table.sort(facilities, function(a, b)
			return a.id < b.id
		end)
		for _, id in Config.ZONE_ORDER do
			if save.unlockedZones[id] then
				local zone = Config.ZONES[id]
				local animal = if zone.themed then homeAnimal else zone.allowedAnimals[1]
				table.insert(zones, {
					id = id,
					capacity = FarmMath.getZoneCapacity(save, id),
					growthSpeed = FarmMath.getGrowthSpeed(save, animal, id, now),
					lineage = FarmMath.getLineageLevel(save, animal),
				})
			end
		end
		for _, upgrade in Config.UPGRADES do
			if
				not save.purchased[upgrade.id] and Config.upgradeInTheme(upgrade, save.farmId or save.activeMainFarmId)
			then
				local alternative: any = table.clone(save)
				if save.inventory then
					alternative.inventory = table.clone(save.inventory)
					alternative.inventory.equipped = {}
				end
				if record then
					alternative.progression = table.clone(record)
					alternative.progression.perks = table.clone(record.perks)
					alternative.progression.perks.upgrade_discount = nil
				end
				upgradeQuote = {
					id = upgrade.id,
					price = FarmMath.getUpgradeCost(save, upgrade),
					withoutEquipmentAndPerk = FarmMath.getUpgradeCost(alternative, upgrade),
				}
				break
			end
		end
		for _, entry in equipment do
			if entry.equipped and save.inventory then
				local alternative: any = table.clone(save)
				alternative.inventory = table.clone(save.inventory)
				alternative.inventory.equipped = table.clone(save.inventory.equipped)
				alternative.inventory.equipped[entry.slot] = nil
				source(entry.id, Config.ITEMS[entry.id].displayName, alternative)
			end
		end
		if record and FarmMath.getPerkLevel(save, "income") > 0 then
			local alternative: any = table.clone(save)
			alternative.progression = table.clone(record)
			alternative.progression.perks = table.clone(record.perks)
			alternative.progression.perks.income = nil
			source("income_perk", "Kalıcı Gelir", alternative)
		end
		if passFactor > 1 then
			local alternative: any = table.clone(save)
			alternative.passes = {}
			if record then
				alternative.progression = table.clone(record)
				alternative.progression.runDouble = false
			end
			source("double", "2 Kat Gelir", alternative)
		end
		if returnActive and record then
			local alternative: any = table.clone(save)
			alternative.progression = table.clone(record)
			alternative.progression.returnEnded = true
			source("return", "Dönüş Etkisi", alternative)
		end
	end
	return {
		income = income,
		incomeFactor = factor,
		uncappedIncomeFactor = raw,
		incomeCapped = raw > factor,
		passFactor = passFactor,
		runDouble = runDouble,
		returnActive = returnActive,
		returnSeconds = if returnActive and record then math.max(0, record.returnEndsAt - now) else 0,
		offlineRate = offlineRate,
		offlineHours = offlineHours,
		storageCap = FarmMath.getStorageCap(save),
		movementMultiplier = FarmMath.getMovementSpeedMultiplier(save),
		growthSpeed = FarmMath.getGrowthSpeed(save, homeAnimal, "starter", now),
		homeAnimal = homeAnimal,
		count = if record then record.count else 0,
		equipment = equipment,
		sources = sources,
		contractBonus = FarmMath.getBonus(save, "contractBonus"),
		facilities = facilities,
		zones = zones,
		islands = islands,
		upgradeQuote = upgradeQuote,
	}
end

return EffectSummary
