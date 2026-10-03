--!strict
return function(Progression: any, FarmMath: any, Config: any, SaveCodec: any)
	local now = 1000000
	local function near(actual: number, expected: number)
		assert(math.abs(actual - expected) < 1e-6, `expected {expected}; actual {actual}`)
	end
	local function fresh(): any
		local save = assert(SaveCodec.decode(nil, Config, FarmMath, now, function()
			return "progression-animal"
		end))
		save.farmId = "1"
		save.activeMainFarmId = "1"
		save.progression = Progression.defaults(now)
		save.owned = { items = {}, conveniences = {} }
		save.gold = 1000
		return save
	end
	local function completeFarm(id: string): any
		local farm = fresh()
		farm.farmId = id
		farm.activeMainFarmId = id
		for _, upgrade in Config.UPGRADES do
			if not upgrade.leveled and Config.upgradeInTheme(upgrade, id) then
				farm.purchased[upgrade.id] = true
			end
		end
		FarmMath.applyDerived(farm)
		return farm
	end
	local save = completeFarm("1")
	assert(Progression.isFarmComplete(save), "base upgrades complete without leveled builds or animals")
	assert(not Progression.isFarmComplete(save, "invalid"), "invalid farms cannot complete")
	save.mainFarms = {}
	for index = 2, 6 do
		save.mainFarms[tostring(index)] = completeFarm(tostring(index))
	end
	assert(Progression.canRebirth(save), "six complete base farms permit rebirth")
	assert(Progression.collectGold(save, now) == 780, "24 islands plus six farms award 780 gold")
	assert(Progression.collectGold(save, now) == 0, "completion claims idempotent")
	local claims = 0
	for _ in save.progression.claims do
		claims += 1
	end
	assert(claims == 30, "exactly thirty bounded claim keys")
	for count, expected in { [3] = 858, [10] = 936 } do
		save.progression.claims = {}
		save.progression.count = count
		assert(Progression.collectGold(save, now) == expected, "rebirth completion reward bonus")
	end
	save.progression.claims = {}
	save.gold = Config.PROGRESSION.gold.maxBalance
	assert(
		Progression.collectGold(save, now) == 0 and next(save.progression.claims) == nil,
		"wallet cap retains unclaimed rewards"
	)
	save.gold -= 936
	assert(Progression.collectGold(save, now) == 936, "rewards collectible after making wallet room")
	save = fresh()
	save.animals = { { uid = "cow", animalId = "cow", zoneId = "starter", bornAt = 0, stage = "adult" } }
	FarmMath.applyDerived(save)
	local baseline = FarmMath.getPermanentReferenceIncome(save)
	assert(baseline > 0, "fixture has permanent income")
	near(assert(Progression.goldCashQuote(save, 200, now)), math.floor(baseline * 30 * 200))
	local _, problem = Progression.goldCashQuote(save, 201, now)
	assert(problem == "daily_limit", "UTC daily cap")
	save.progression.convertedDay = math.floor(now / 86400)
	save.progression.convertedDayGold = 200
	assert(select(2, Progression.goldCashQuote(save, 1, now)) == "daily_limit", "spent UTC quota")
	assert(Progression.goldCashQuote(save, 1, now + 86400), "daily counter resets at next UTC day")
	save.progression.convertedRunGold = 600
	assert(select(2, Progression.goldCashQuote(save, 1, now + 86400)) == "run_limit", "spent run quota")
	for _, amount in { 0, -1, 0.5, math.huge, 0 / 0 } do
		assert(
			select(2, Progression.goldCashQuote(save, amount, now)) == "invalid_amount",
			"reject malformed gold amounts"
		)
	end
	save.progression.count = 1
	save.progression.returnEnded = false
	save.progression.returnEndsAt = now + 10
	near(FarmMath.computeIncomeOverInterval(save, now, now + 20, true), baseline * 40)
	near(FarmMath.computeIncomeOverInterval(save, now - 10, now + 20, true), baseline * 50)
	save.animals[1].task = { kind = "production", id = "milk", startedAt = now + 5, endsAt = now + 15 }
	near(FarmMath.computeIncomeOverInterval(save, now, now + 20, true), baseline * 20)
	near(FarmMath.getPermanentReferenceIncome(save), baseline)
	save.animals[1].task = nil
	near(FarmMath.getPermanentReferenceIncome(save), baseline)
	near(
		FarmMath.estimateForgoneIncome(save, save.animals, 20, now),
		FarmMath.computeIncomeOverInterval(save, now, now + 20)
	)
	assert(not FarmMath.isReturnActive(save, now - 1), "Return starts at rebirth time")
	save.progression.runDouble = true
	near(FarmMath.getPermanentReferenceIncome(save), baseline)
	near(FarmMath.getAnimalMultiplier(save, "cow", true, "starter", now + 20), 2)
	save.passes = { double_income = true }
	near(FarmMath.getAnimalMultiplier(save, "cow", true, "starter", now + 20), 2)
	near(FarmMath.getPermanentReferenceIncome(save), baseline * 2)
	save.inventory = { items = {}, equipped = { head = "golden_crown" } }
	save.owned.items.golden_crown = true
	near(FarmMath.getPermanentReferenceIncome(save), baseline * 4)
	save.inventory.items.golden_crown = true
	near(FarmMath.getPermanentReferenceIncome(save), baseline * 4)
	save.inventory = { items = {}, equipped = {} }
	-- Büyüme hızının süresi dolunca geçmiş ilerleme korunur; tek aralık ve bölünmüş hesap aynı.
	save.passes = {}
	save.progression.runDouble = false
	save.animals[1].bornAt = now
	local speeds = FarmMath.snapshotGrowthSpeeds(save, now)
	local combined = FarmMath.computeIncomeOverInterval(save, now, now + 300, true)
	local before = FarmMath.computeIncomeOverInterval(save, now, now + 10, true)
	FarmMath.preserveGrowthProgress(save, speeds, now + 10)
	near(combined, before + FarmMath.computeIncomeOverInterval(save, now + 10, now + 300, true))
	save.progression.perks.income = 5
	near(Progression.getIncomeMultiplier(save, 3), 3)
	assert(
		not Progression.canChoosePerk(save, "income") and Progression.canChoosePerk(save, "growth"),
		"perk maximum enforced"
	)
	assert(not Progression.canChoosePerk(save, "prestige"), "prestige requires every perk maximum")
	for id in Config.PROGRESSION.perks do
		save.progression.perks[id] = 5
	end
	assert(Progression.canChoosePerk(save, "prestige"), "prestige available after forty perk levels")
	save = fresh()
	save.progression.count = 5
	save.progression.perks.ready_start = 5
	local serial = 0
	Progression.applyReadyStart(save, now, function()
		serial += 1
		return `ready-{serial}`
	end)
	assert(#save.animals == 3 and FarmMath.hasAutoCollect(save), "ready start adults and auto collection")
	assert(save.unlockedIslands[Config.getTheme("1").satellites[1]], "ready start first island")
	assert(Progression.collectGold(save, now) == 0, "opening first island does not complete its upgrades")
	save.production = { test = { readyAt = now + 61 } }
	assert(Progression.finishGoldQuote(save, "production", "test", now) == 1, "R5 finish discount before rounding")
	assert(
		select(2, Progression.finishGoldQuote(save, "production", "test", now + 61)) == "already_ready",
		"ready jobs cannot charge"
	)
	save.owned.conveniences.pet_goods = true
	assert(FarmMath.hasPet(save, "goods"), "permanent helper enabled")
	-- Actual configured recipes: nominal baseline remains profitable; boosted cap shortfall is cash, not inflated quantity.
	save = fresh()
	for _, upgrade in Config.UPGRADES do
		save.purchased[upgrade.id] = true
	end
	FarmMath.applyDerived(save)
	local goodsTested = 0
	for _, recipe in Config.PRODUCTION_RECIPES do
		if recipe.output == "goods" and recipe.goodsId then
			local good = Config.GOODS[recipe.goodsId]
			for index = 1, 6 do
				local id = tostring(index)
				if
					Config.themeHasIsland(id, recipe.island)
					and (recipe.island ~= "home" or Config.getHomeAnimal(id) == recipe.animalIds[1])
				then
					save = completeFarm(id)
					break
				end
			end
			save.animals = {}
			for index = 1, recipe.requiredAdults do
				local animalId = recipe.animalIds[1]
				local zoneId = assert(
					FarmMath.findZoneForAnimal(save, animalId),
					`recipe {recipe.id} has adult space for {animalId} on {save.farmId}`
				)
				table.insert(
					save.animals,
					{ uid = `goods-{index}`, animalId = animalId, zoneId = zoneId, bornAt = 0, stage = "adult" }
				)
			end
			local job: any = {
				forgone = FarmMath.estimateForgoneIncome(
					save,
					save.animals,
					FarmMath.getFacilityDuration(save, recipe),
					now
				),
				startCost = FarmMath.getFacilityCost(save, recipe),
			}
			local units = FarmMath.getGoodsYield(save, recipe, now, job)
			assert(FarmMath.getGoodsCompensation(save, recipe, job, now, units) == 0, "no baseline compensation")
			job.forgone = good.value * Config.PRODUCTION_MAX_BATCH_UNITS * 20
			job.startCost = 37
			units = FarmMath.getGoodsYield(save, recipe, now, job)
			local floor = math.ceil((job.forgone + 37) * Config.PRODUCTION_MIN_RETURN)
			local compensation = FarmMath.getGoodsCompensation(save, recipe, job, now, units)
			assert(
				units <= Config.PRODUCTION_MAX_BATCH_UNITS and units * good.value + compensation >= floor,
				"capped goods plus cash preserve floor"
			)
			near(FarmMath.getGoodsCompensation(save, recipe, job, now, units - 1, good.value), compensation)
			goodsTested += 1
		else
			assert(
				FarmMath.getGoodsCompensation(save, recipe, { forgone = 100000 }, now, 0) == 0,
				"cash recipes receive no second reward"
			)
		end
	end
	assert(goodsTested > 0, "actual goods recipes covered")
	print("progression.spec: completion, wallet, quotas, perks, Return, ownership and goods floor passed")
end
