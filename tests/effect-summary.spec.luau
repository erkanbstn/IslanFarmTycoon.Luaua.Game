--!strict
return function(EffectSummary: any, Config: any, FarmMath: any, SaveCodec: any, Inventory: any, Progression: any)
	local now = 1000000
	local save = assert(
		SaveCodec.decode(nil, Config, FarmMath, now, function()
			return "effect-cow"
		end),
		"effect fixture loads"
	)
	save.farmId = "1"
	save.activeMainFarmId = "1"
	save.animals = { { uid = "cow", animalId = "cow", zoneId = "starter", bornAt = 0, stage = "adult" } }
	FarmMath.applyDerived(save)
	local initial = EffectSummary.snapshot(save, now)
	assert(initial.income == FarmMath.computeIncomePerSecond(save, now), "summary shows actual current farm income")
	assert(#initial.sources == 0, "closed source disclosure skips counterfactual calculations")
	Inventory.grant(save, "golden_crown")
	local owned = EffectSummary.snapshot(save, now, true)
	assert(
		owned.income == initial.income and #owned.equipment == 1,
		"owning an item without equipping grants no income"
	)
	assert(not owned.equipment[1].equipped, "inactive owned gear is explicit")
	for _, id in { "golden_crown", "golden_wings", "income_charm_3" } do
		Inventory.grant(save, id)
		assert(Inventory.equip(save, id), "income equipment equips")
	end
	save.progression = Progression.defaults(now)
	save.progression.count = 5
	save.progression.perks.income = 5
	local equippedId = save.inventory.equipped.back
	local capped = EffectSummary.snapshot(save, now, true)
	assert(
		capped.incomeCapped and capped.incomeFactor == Config.PROGRESSION.permanentIncomeCap,
		"actual joint cap is displayed"
	)
	assert(
		capped.uncappedIncomeFactor > capped.incomeFactor,
		"the unclamped arithmetic is not advertised as actual income"
	)
	assert(
		save.inventory.equipped.back == equippedId and save.progression.perks.income == 5,
		"source calculation never mutates live state"
	)
	local wingsDelta: number? = nil
	for _, source in capped.sources do
		if source.id == "golden_wings" then
			wingsDelta = source.incomeDelta
		end
	end
	Inventory.unequip(save, "back")
	assert(
		wingsDelta == capped.income - FarmMath.computeIncomePerSecond(save, now),
		"source contribution is the real capped removal difference"
	)
	assert(Inventory.equip(save, "golden_wings"), "restore back equipment")
	save.passes = { double_income = true }
	save.progression.runDouble = true
	local double = EffectSummary.snapshot(save, now, true)
	assert(double.passFactor == 2 and double.runDouble, "pass and run bonus are combined at2x")
	assert(double.income == capped.income * 2, "a pass plus a run product does not advertise4x")
	save.progression.returnEnded = false
	save.progression.returnEndsAt = now + 60
	local returning = EffectSummary.snapshot(save, now)
	assert(returning.returnActive and returning.returnSeconds == 60, "Return has a real expiry countdown")
	assert(
		returning.income == double.income * Config.PROGRESSION.returnIncomeMultiplier,
		"cow Return matches live income"
	)
	local ended = EffectSummary.snapshot(save, now + 60)
	assert(
		not ended.returnActive and ended.returnSeconds == 0 and ended.income == double.income,
		"Return expires at the exact boundary"
	)
	save.progression.returnEnded = true
	assert(
		not EffectSummary.snapshot(save, now).returnActive,
		"a purchased second farm ends Return even before the timer"
	)
	Inventory.unequip(save, "charm")
	Inventory.grant(save, "night_charm")
	assert(Inventory.equip(save, "night_charm"), "offline charm equips")
	local offline = EffectSummary.snapshot(save, now)
	local actualRate, actualHours = FarmMath.getOfflineTerms(save)
	assert(
		offline.offlineRate == actualRate and offline.offlineHours == actualHours,
		"offline shows capped rate and duration rather than bonus arithmetic"
	)
	assert(offline.storageCap == FarmMath.getStorageCap(save), "storage summary respects actual equipped state")
	Inventory.grant(save, "diamond_hammer")
	assert(Inventory.equip(save, "diamond_hammer"), "discount source equips")
	save.progression.count = 8
	save.progression.perks.upgrade_discount = 3
	local recipe: any = nil
	for _, candidate in Config.PRODUCTION_RECIPES do
		if candidate.output == "goods" and candidate.island == "home" and candidate.animalId == "cow" then
			recipe = candidate
			break
		end
	end
	assert(recipe, "current farm goods recipe")
	save.purchased[recipe.upgradeId] = true
	save.expansions[recipe.id] = 3
	save.expansions.starter = 2
	save.lineage.cow = 3
	local activities = EffectSummary.snapshot(save, now, true)
	local facility: any = nil
	for _, entry in activities.facilities do
		if entry.id == recipe.id then
			facility = entry
		end
	end
	assert(
		facility and facility.duration == FarmMath.getFacilityDuration(save, recipe),
		"production summary includes real facility and equipment duration"
	)
	assert(
		facility.goods == FarmMath.previewGoodsYield(save, recipe, now),
		"goods display uses actual start preview including yield bounds"
	)
	assert(
		activities.zones[1].capacity == FarmMath.getZoneCapacity(save, "starter") and activities.zones[1].lineage == 3,
		"zone capacity and lineage are actual current-farm values"
	)
	assert(
		activities.upgradeQuote and activities.upgradeQuote.price < activities.upgradeQuote.withoutEquipmentAndPerk,
		"discount example respects actual pricing rounding and caps"
	)
	assert(
		activities.contractBonus == FarmMath.getBonus(save, "contractBonus"),
		"current equipment and permanent order effects are present"
	)
	print(
		"PASS effect summary: actual income, equipped ownership, joint cap, non-mutating source differences,2x and Return boundaries"
	)
end
