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
	assert(save.gold == 1000, "completing islands and farms awards no gold before the rebirth")
	assert(Progression.isRunComplete(save), "six complete farms complete the run")
	local base = Config.PROGRESSION.gold
	assert(Progression.rebirthGoldReward(save) == base.rebirthBase, "R1 pays the base reward")
	assert(Progression.collectTerminalGold(save) == 0, "no terminal reward below the thirty rebirth cap")
	for count, expected in { [1] = 760, [3] = 858, [10] = 1020, [29] = 1248, [30] = 1260 } do
		save.progression.count = count
		assert(Progression.rebirthGoldReward(save) == expected, `rebirth reward at count {count} includes goldBonus`)
	end
	save.progression.count = 0
	local noProgression: any = { gold = 5 }
	assert(Progression.rebirthGoldReward(noProgression) == base.rebirthBase, "missing progression uses the base reward")
	assert(
		Progression.rebirthGoldReward({ progression = { count = 999 } })
			== Progression.rebirthGoldReward({ progression = { count = 30 } }),
		"out of range counts clamp to the terminal level"
	)
	for _, premiumItem in { "diamond_hammer", "foreman_mallet", "gold_hammer" } do
		local offer = Config.PROGRESSION.permanentOffers[premiumItem]
		assert(
			base.rebirthBase >= offer.goldCost * 0.8 and base.rebirthBase <= offer.goldCost * 1.5,
			`one first rebirth reward buys about one premium item ({premiumItem})`
		)
	end
	-- R30: son tur tamamlanınca aynı ödül bir kez verilir.
	local terminal = completeFarm("1")
	terminal.progression.count, terminal.progression.run = 30, 31
	assert(not Progression.isRunComplete(terminal), "other farms are missing")
	assert(Progression.collectTerminalGold(terminal) == 0 and terminal.gold == 1000, "incomplete R30 run pays nothing")
	terminal.progression.count, terminal.progression.run = 0, 1
	save.progression.claims = { terminal = true }
	save.progression.count = 30
	assert(Progression.collectTerminalGold(save) == 0, "claimed terminal reward never repeats")
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
	near(FarmMath.getPermanentReferenceIncome(save), baseline * 2 * (1 + Config.ITEMS.golden_crown.effects.incomeBonus))
	save.inventory.items.golden_crown = true
	near(FarmMath.getPermanentReferenceIncome(save), baseline * 2 * (1 + Config.ITEMS.golden_crown.effects.incomeBonus))
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
	assert(not Progression.canChoosePerk(save, "prestige"), "thirty rebirth limit replaces unlimited prestige resets")
	save = fresh()
	save.progression.count = 5
	save.progression.perks.ready_start = 5
	local serial = 0
	Progression.applyReadyStart(save, now, function()
		serial += 1
		return `ready-{serial}`
	end)
	assert(FarmMath.hasAutoCollect(save), "ready start auto collection")
	-- Hazır Başlangıç kademeleri: hayvanlar ve adalar seviyeyle artar, hepsi yetişkin, ada yükseltmeleri tamamlanmaz
	local theme = Config.getTheme("1")
	local homeAnimal = Config.getHomeAnimal("1")
	local function readyStart(level: number): any
		local started = fresh()
		started.progression.count = 5
		started.progression.perks.ready_start = level
		local count = 0
		Progression.applyReadyStart(started, now, function()
			count += 1
			return `ready-level-{level}-{count}`
		end)
		return started
	end
	local function countOf(started: any, animalId: string): number
		local total = 0
		for _, animal in started.animals do
			if animal.animalId == animalId then
				total += 1
				assert(animal.stage == "adult" and animal.bornAt == 0, "ready start animals are adults")
			end
		end
		return total
	end
	local firstIsland, secondIsland = theme.satellites[1], theme.satellites[2]
	local firstAnimal = Config.FARM_ISLANDS[firstIsland].animalId
	local secondAnimal = Config.FARM_ISLANDS[secondIsland].animalId
	local expected = {
		{ home = 0, first = 0, second = 0, islands = 0 },
		{ home = 1, first = 0, second = 0, islands = 0 },
		{ home = 1, first = 1, second = 0, islands = 1 },
		{ home = 2, first = 1, second = 1, islands = 2 },
		{ home = 3, first = 2, second = 2, islands = 2 },
	}
	local previousIncome = 0
	for level, want in expected do
		local started = readyStart(level)
		assert(countOf(started, homeAnimal) == want.home, `level {level}: main adults`)
		assert(countOf(started, firstAnimal) == want.first, `level {level}: first island adults`)
		assert(countOf(started, secondAnimal) == want.second, `level {level}: second island adults`)
		assert(
			(started.unlockedIslands[firstIsland] == true) == (want.islands >= 1)
				and (started.unlockedIslands[secondIsland] == true) == (want.islands >= 2),
			`level {level}: opened islands`
		)
		assert(not Progression.isFarmComplete(started), `level {level}: opening islands does not finish the farm`)
		local income = FarmMath.computeIncomePerSecond(started, now)
		assert(income >= previousIncome, `level {level}: starting income never drops`)
		previousIncome = income
	end
	assert(previousIncome > 0, "a maxed ready start earns from the first second")
	assert(save.unlockedIslands[Config.getTheme("1").satellites[1]], "ready start first island")
	assert(
		save.gold == 1000 and not Progression.isFarmComplete(save),
		"opening first island does not complete its upgrades or pay gold"
	)
	save.animals[1].task = { kind = "extension", id = "barn", startedAt = now, endsAt = now + 61 }
	assert(
		Progression.finishGoldQuote(save, "extension", save.animals[1].uid, now) == 1,
		"R5 finish discount before rounding"
	)
	assert(
		select(2, Progression.finishGoldQuote(save, "extension", save.animals[1].uid, now + 61)) == "already_ready",
		"ready extension tasks cannot charge"
	)
	save.production = { test = { readyAt = now + 61 } }
	for _, atTime in { now, now + 61 } do
		local quote, reason = Progression.finishGoldQuote(save, "production", "test", atTime)
		assert(
			quote == nil and reason == "unsupported_target",
			"production finishing stays unsupported even when the batch is ready"
		)
	end
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
