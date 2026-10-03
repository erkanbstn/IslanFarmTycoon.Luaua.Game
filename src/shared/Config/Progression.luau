--!strict
-- Altın ve rebirth başlangıç ayarları; ölçümle yeniden ayarlanabilir.
export type PerkDefinition = { maxLevel: number, effects: { [string]: number } }
-- Creator Hub kimliği hazır olduğunda teklife robuxProductId eklenir; yoksa satış kapalıdır.
export type PermanentOffer = { id: string, kind: string, itemId: string?, goldCost: number, robuxProductId: number? }

local data = {
	gold = { island = 20, farm = 50, cashSeconds = 30, dailyLimit = 200, runLimit = 600, maxBalance = 1e9 },
	returnSeconds = 86400,
	returnIncomeMultiplier = 3,
	returnGrowthExcess = 0.5,
	permanentIncomeCap = 3,
	perkOrder = {
		"income",
		"growth",
		"starting_cash",
		"upgrade_discount",
		"facility_speed",
		"offline",
		"contract",
		"ready_start",
	},
	perks = {
		income = { maxLevel = 5, effects = { incomeBonus = 0.08 } },
		growth = { maxLevel = 5, effects = { growthExcess = 0.06 } },
		starting_cash = { maxLevel = 5, effects = { startingAnimals = 2 } },
		upgrade_discount = { maxLevel = 5, effects = { upgradeDiscount = 0.03 } },
		facility_speed = { maxLevel = 5, effects = { facilitySpeed = 0.05 } },
		offline = { maxLevel = 5, effects = { offlineBonus = 0.05, offlineHours = 0.5 } },
		contract = { maxLevel = 5, effects = { contractBonus = 0.04 } },
		ready_start = { maxLevel = 5, effects = {} },
	} :: { [string]: PerkDefinition },
	permanentOffers = {
		diamond_hammer = { id = "diamond_hammer", kind = "item", itemId = "diamond_hammer", goldCost = 600 },
		season_staff_inf = { id = "season_staff_inf", kind = "item", itemId = "season_staff_inf", goldCost = 1000 },
		weather_staff_inf = { id = "weather_staff_inf", kind = "item", itemId = "weather_staff_inf", goldCost = 800 },
		income_charm_3 = { id = "income_charm_3", kind = "item", itemId = "income_charm_3", goldCost = 800 },
		growth_charm_2 = { id = "growth_charm_2", kind = "item", itemId = "growth_charm_2", goldCost = 500 },
		storage_charm_2 = { id = "storage_charm_2", kind = "item", itemId = "storage_charm_2", goldCost = 300 },
		barn_charm_2 = { id = "barn_charm_2", kind = "item", itemId = "barn_charm_2", goldCost = 500 },
		contract_charm_2 = { id = "contract_charm_2", kind = "item", itemId = "contract_charm_2", goldCost = 500 },
		golden_crown = { id = "golden_crown", kind = "item", itemId = "golden_crown", goldCost = 1500 },
		golden_wings = { id = "golden_wings", kind = "item", itemId = "golden_wings", goldCost = 800 },
		auto_collect = { id = "auto_collect", kind = "convenience", goldCost = 300 },
		pet_cash = { id = "pet_cash", kind = "convenience", goldCost = 500 },
		pet_goods = { id = "pet_goods", kind = "convenience", goldCost = 500 },
	} :: { [string]: PermanentOffer },
}

return data
