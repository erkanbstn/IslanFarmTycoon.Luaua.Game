--!strict
-- Uzman ekipmanları gerçek hesap, sahiplik, yuva ve kayıt akışında sınanır.
return function(Config: any, FarmMath: any, SaveCodec: any, Inventory: any)
	local now = 1000000
	local function fresh(): any
		local save = assert(
			SaveCodec.decode(nil, Config, FarmMath, now, function()
				return "market-cow"
			end),
			"a new market fixture can be decoded"
		)
		save.farmId = "1"
		save.animals = { { uid = "cow", animalId = "cow", zoneId = "starter", bornAt = 0 } }
		FarmMath.applyDerived(save)
		return save
	end
	local function equip(save: any, id: string)
		Inventory.grant(save, id)
		assert(Inventory.equip(save, id), `equipment {id} can be equipped after ownership`)
	end
	local newItems = {
		"artisan_hammer",
		"artisan_staff",
		"night_charm",
		"logistics_charm",
		"orchard_charm",
		"merchant_hat",
		"expedition_pack",
		"artisan_cape",
	}
	for _, id in newItems do
		local offer = assert(Config.PROGRESSION.permanentOffers[id], `permanent offer exists for {id}`)
		local product = assert(Config.PRODUCTS.products[`permanent_{id}`], `Robux configuration exists for {id}`)
		assert(offer.itemId == id and offer.goldCost > 0, "each new item has a free permanent gold route")
		assert(product.effect == "permanentOffer" and product.offerId == id, "Robux grants the same permanent right")
		assert(product.id == (offer.robuxProductId or 0), "Robux catalogue uses the permanent offer's configured ID")
		assert(Config.ITEMS[id].effects.incomeBonus == nil, "specialist choices do not add an income stack")
	end
	local save = fresh()
	local baseIncome = FarmMath.computeIncomePerSecond(save, now)
	local baseStorage = FarmMath.getStorageCap(save)
	Inventory.grant(save, "logistics_charm")
	assert(FarmMath.getStorageCap(save) == baseStorage, "owned but unequipped gear gives no passive bonus")
	equip(save, "logistics_charm")
	assert(FarmMath.getStorageCap(save) == math.floor(baseStorage * 1.7), "logistics increases the cash storage cap")
	equip(save, "night_charm")
	assert(FarmMath.getStorageCap(save) == baseStorage, "switching the charm removes the old storage bonus")
	local rate = FarmMath.getOfflineTerms(save)
	assert(math.abs(rate - Config.OFFLINE_EARNING_RATE * 1.45) < 1e-6, "night charm increases actual offline earnings")
	equip(save, "expedition_pack")
	local combinedRate = FarmMath.getOfflineTerms(save)
	assert(math.abs(combinedRate - Config.OFFLINE_EARNING_RATE * 1.65) < 1e-6, "offline equipment bonuses add")
	assert(combinedRate <= Config.OFFLINE_MAX_TOTAL_RATE, "offline cap is preserved")
	equip(save, "orchard_charm")
	assert(
		FarmMath.getGrowthSpeed(save, "cow", "starter", now) == 1.5,
		"filiz charm shortens growth through the shared formula"
	)
	assert(
		FarmMath.getEquippedBonus(save, "offlineBonus") == 0.2,
		"replacing night charm removes its offline contribution"
	)
	local recipe: any = nil
	for _, candidate in Config.PRODUCTION_RECIPES do
		if candidate.output == "goods" then
			recipe = candidate
			break
		end
	end
	assert(recipe, "there is a real goods recipe")
	local productionSave = fresh()
	local originalDuration = FarmMath.getFacilityDuration(productionSave, recipe)
	equip(productionSave, "artisan_hammer")
	equip(productionSave, "artisan_staff")
	equip(productionSave, "artisan_cape")
	assert(
		FarmMath.getFacilityDuration(productionSave, recipe) == math.max(10, math.floor(recipe.duration * 0.56)),
		"three workshop slots add speed rather than multiply it"
	)
	assert(
		FarmMath.getFacilityDuration(productionSave, recipe) < originalDuration,
		"workshop setup changes production duration"
	)
	assert(
		math.abs(FarmMath.getEquippedBonus(productionSave, "goodsYield") - 0.2) < 1e-6,
		"staff and cape improve goods yield"
	)
	assert(
		FarmMath.getGoodsYield(productionSave, recipe, now)
			== math.clamp(math.floor(recipe.goodsAmount * 1.2), 1, Config.PRODUCTION_MAX_BATCH_UNITS),
		"workshop goods bonus reaches the real delivery calculation without bypassing the batch cap"
	)
	equip(productionSave, "merchant_hat")
	assert(
		FarmMath.getEquippedBonus(productionSave, "contractBonus") == 0.1,
		"merchant hat affects the contract formula"
	)
	assert(
		FarmMath.computeIncomePerSecond(productionSave, now) == baseIncome,
		"a specialist setup leaves animal income unchanged"
	)
	for _, id in newItems do
		Inventory.grant(productionSave, id)
		productionSave.owned.items[id] = true
	end
	local loaded = assert(
		SaveCodec.decode(SaveCodec.encode(productionSave, now), Config, FarmMath, now, function()
			return "market-loaded"
		end),
		"new permanent equipment can be decoded"
	)
	for _, id in newItems do
		assert(loaded.owned.items[id] and Inventory.owns(loaded, id), `permanent ownership for {id} survives reload`)
	end
	assert(loaded.inventory.equipped.tool == "artisan_hammer", "new equipped models retain their IDs after reload")
	-- Altın-yalnız ekipman gerçek hesaplara bağlanır: Robux ürünü kapalı (kimlik 0), sahiplik altın teklifinden gelir
	local goldOnlyIds =
		{ "foreman_mallet", "fortune_charm", "tycoon_crown", "caravan_satchel", "eternal_shepherd_staff" }
	for _, id in goldOnlyIds do
		assert(Config.PRODUCTS.products[`permanent_{id}`].id == 0, `{id}: no Robux product exists`)
	end
	local foreman = fresh()
	local plainCost = FarmMath.getUpgradeCost(foreman, Config.getUpgrade("barn_2"))
	equip(foreman, "foreman_mallet")
	assert(
		FarmMath.getUpgradeCost(foreman, Config.getUpgrade("barn_2")) < plainCost,
		"foreman mallet discounts upgrades through the shared formula"
	)
	local fortune = fresh()
	equip(fortune, "fortune_charm")
	assert(
		FarmMath.computeIncomePerSecond(fortune, now) > FarmMath.computeIncomePerSecond(fresh(), now),
		"fortune charm raises income"
	)
	assert(
		math.abs(FarmMath.getEquippedBonus(fortune, "offlineBonus") - Config.ITEMS.fortune_charm.effects.offlineBonus)
			< 1e-9,
		"fortune charm adds offline earnings"
	)
	local caravan = fresh()
	local caravanBase = FarmMath.getStorageCap(caravan)
	equip(caravan, "caravan_satchel")
	assert(FarmMath.getStorageCap(caravan) > caravanBase, "caravan satchel raises storage")
	local tycoon = fresh()
	equip(tycoon, "tycoon_crown")
	assert(
		FarmMath.getEquippedBonus(tycoon, "contractBonus") > Config.ITEMS.merchant_hat.effects.contractBonus,
		"tycoon crown is the strongest non-golden trade hat"
	)
	local products = Config.PRODUCTS.products
	assert(
		products.income_pack_small.incomeHours == 0.25 and products.income_pack.incomeHours == 1,
		"small and standard cash packs"
	)
	assert(products.income_pack_large.incomeHours == 3, "large cash pack uses the same bounded income effect")
	print(
		"PASS market-products: specialist equipment, slot tradeoffs, permanent ownership and safe product configuration"
	)
end
