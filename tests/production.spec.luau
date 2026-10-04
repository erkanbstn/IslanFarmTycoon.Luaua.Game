--!strict
return function(createService: any, createLimiter: any, rules: any, codec: any, config: any, farmMath: any, logic: any)
	local function signal(): any
		local callbacks = {}
		return {
			Connect = function(_self: any, callback: any)
				table.insert(callbacks, callback)
			end,
			fire = function(...: any)
				for _, callback in callbacks do
					callback(...)
				end
			end,
		}
	end
	local now = 1000
	local serial = 0
	local function uid(): string
		serial += 1
		return `production-test-{serial}`
	end
	local fresh = assert(codec.decode(nil, config, farmMath, now, uid), "new profile must decode")
	assert(next(fresh.production) == nil, "legacy/new profiles start with empty production")
	local data: any = fresh
	local function reset()
		data = assert(codec.decode(nil, config, farmMath, now, uid), "fixture decode failed")
		data.cash = 100000
		for _, upgrade in config.UPGRADES do
			data.purchased[upgrade.id] = true
		end
		farmMath.applyDerived(data)
		data.animals = {}
		for _, animalId in
			{ "cow", "cow", "chicken", "chicken", "horse", "goat", "goat", "anchovy", "seabass", "anchovy" }
		do
			local zoneId = assert(farmMath.findZoneForAnimal(data, animalId), "fixture has room")
			table.insert(
				data.animals,
				{ uid = uid(), animalId = animalId, zoneId = zoneId, bornAt = 0, stage = "adult" }
			)
		end
	end
	reset()
	local player: any = {
		GetAttribute = function(): boolean
			return true
		end,
	}
	local stranger: any = {
		GetAttribute = function(): boolean
			return true
		end,
	}
	local players = { PlayerRemoving = signal() }
	local node: any = {}
	function node:WaitForChild(_name: string): any
		return self
	end
	local fakeGame = {
		GetService = function(_self: any, name: string): any
			if name == "Players" then
				return players
			end
			if name == "HttpService" then
				return { GenerateGUID = uid }
			end
			return node
		end,
	}
	local limiter = createLimiter(fakeGame, {
		clock = function(): number
			return now
		end,
	})
	local request = { OnServerEvent = signal() }
	local results: { any } = {}
	local remotes = {
		get = function(name: string): any
			if name == "RequestProductionAction" then
				return request
			end
			return {
				FireClient = function(_self: any, target: any, id: number, ok: boolean, message: string)
					table.insert(results, { target = target, id = id, ok = ok, message = message })
				end,
			}
		end,
	}
	local active = true
	local hasPlot = true
	local saves, pushes, refreshes, settlements = 0, 0, 0, 0
	local visualFailure = false
	local dataService = {
		tryGet = function(target: any): any
			return if active and target == player then data else nil
		end,
		trySpend = function(_target: any, price: number): boolean
			if data.cash < price then
				return false
			end
			data.cash -= price
			return true
		end,
		addCash = function(_target: any, value: number)
			data.cash = math.min(1e15, data.cash + value)
		end,
		pushState = function()
			pushes += 1
		end,
		requestSave = function()
			saves += 1
		end,
	}
	local service = createService(
		fakeGame,
		remotes,
		dataService,
		{
			settlePlayer = function()
				settlements += 1
			end,
		},
		{
			getPlot = function(): any
				return if hasPlot then {} else nil
			end,
			refreshPlayerWorld = function()
				refreshes += 1
				if visualFailure then
					error("injected world refresh failure")
				end
			end,
		},
		limiter,
		{
			now = function(): any
				return { UnixTimestampMillis = now * 1000 }
			end,
		},
		function() end,
		logic
	)
	service.init()
	service.init()
	local sequence = 0
	local function fire(action: any, recipe: any, job: any, target: any?): any
		now += 0.6
		sequence += 1
		request.OnServerEvent.fire(target or player, action, recipe, job, sequence, data.activeMainFarmId)
		return results[#results]
	end
	for _, badId in { 0, -1, 0 / 0, math.huge, 0.5, 2147483648, "1", {} } do
		assert(not rules.validRequestId(badId), "invalid sequence must be rejected")
		request.OnServerEvent.fire(player, "start", "packed_milk", "medium", badId)
	end
	assert(#results == 0 and next(data.production) == nil, "malformed request never mutates or replies")
	assert(not fire("start", "packed_milk", "medium", stranger).ok, "another profile cannot be accessed")
	active = false
	assert(not fire("start", "packed_milk", "medium").ok, "lost/failed profile cannot start")
	active = true
	hasPlot = false
	assert(not fire("start", "packed_milk", "medium").ok, "world must be assigned")
	hasPlot = true
	data.purchased.milk_factory = nil
	assert(not fire("start", "packed_milk", "medium").ok, "factory ownership is mandatory")
	data.purchased.milk_factory = true
	data.animals[1].bornAt = now
	assert(not fire("start", "packed_milk", "medium").ok, "calf with stale adult stage cannot satisfy requirement")
	data.animals[1].bornAt = 0
	data.cash = 0 -- para tesisleri başlatma ücreti almaz: parasız da başlar
	assert(not fire("start", {}, nil).ok and not fire("hack", "packed_milk", nil).ok, "malformed actions are rejected")
	assert(not fire("start", "packed_milk", "forged").ok, "start cannot provide its own uid or an unknown option")
	assert(not fire("start", "hatchery", "medium").ok, "a recipe without options rejects an option id")
	local before = data.cash
	now += 0.6
	sequence += 1
	request.OnServerEvent.fire(player, "start", "packed_milk", "medium", sequence, "2")
	assert(
		not results[#results].ok and next(data.production) == nil and data.cash == before,
		"delayed request for a different main farm cannot spend or create production"
	)
	local idleIncome = farmMath.computeIncomePerSecond(data, now)
	assert(fire("start", "packed_milk", "medium").ok, "qualified dairy starts")
	local job = data.production.packed_milk
	assert(
		data.cash == before and data.production.packed_milk.optionId == "medium",
		"cash batches are free and record the option"
	)
	-- Tesise verilen yetişkin inekler iş boyunca görevde: gelir getirmez, satılamaz, tekrar seçilemez.
	local busy = 0
	for _, animal in data.animals do
		if animal.task then
			busy += 1
			assert(
				animal.task.kind == "production" and animal.task.id == "packed_milk",
				"busy animals carry the production task"
			)
			assert(animal.task.endsAt == job.readyAt and animal.task.startedAt == job.startedAt, "task spans the job")
			assert(animal.animalId == "cow", "only the recipe's species is taken")
		end
	end
	assert(busy == 2, "exactly the option's adults are taken")
	assert(job.forgone ~= nil and job.forgone > 0, "job records the income the animals would have earned")
	assert(
		farmMath.computeIncomePerSecond(data, now) < idleIncome,
		"animals in the facility earn nothing while working"
	)
	assert(
		farmMath.countProductionAdults(data, config.PRODUCTION_RECIPES.packed_milk, now) >= busy,
		"own working animals still count for the bonus"
	)
	assert(farmMath.findSellableAnimal(data, "cow", now) == nil, "working animals cannot be sold")
	local startSequence = sequence
	now += 1
	request.OnServerEvent.fire(player, "start", "packed_milk", "medium", startSequence, data.activeMainFarmId)
	assert(data.production.packed_milk == job, "same sequence never starts a second batch")
	assert(not fire("start", "packed_milk", "medium").ok, "only one pending batch per recipe")
	assert(not fire("sell", "packed_milk", job.uid).ok, "cannot claim early")
	now = job.readyAt + 1
	assert(not fire("sell", "packed_milk", "forged").ok, "claim requires exact job uid")
	assert(
		not fire("keep", "packed_milk", job.uid).ok and data.production.packed_milk == job,
		"cash output cannot become animal"
	)
	assert(fire("sell", "packed_milk", job.uid).ok, "ready batch sells")
	local after = data.cash
	local dairy = config.PRODUCTION_RECIPES.packed_milk
	local option = farmMath.findProductionOption(dairy, "medium")
	local floorReward = math.ceil(job.forgone * option.returnMultiplier)
	assert(
		after == before + math.max(option.reward, floorReward),
		"reward is server configured and never below the option's forgone-income floor"
	)
	assert(after - before > job.forgone, "the facility always pays more than leaving the animals in place")
	for _, animal in data.animals do
		assert(animal.task == nil, "animals return to their zone when the job is claimed")
	end
	assert(not fire("sell", "packed_milk", job.uid).ok and data.cash == after, "double claim cannot pay")
	request.OnServerEvent.fire(player, "start", "packed_milk", "medium", startSequence, data.activeMainFarmId)
	assert(data.production.packed_milk == nil, "old start replay stays rejected even after claim")
	assert(fire("start", "packed_milk", "medium").ok, "production is repeatable with new sequence")
	local snap = codec.encode(data, now)
	assert(snap.version >= 4, "new jobs require schema 4+ to keep old servers from dropping them")
	local readyAt = snap.mainFarms["1"].production.packed_milk.readyAt
	data.production.packed_milk.readyAt += 100
	assert(
		snap.mainFarms["1"].production.packed_milk.readyAt == readyAt,
		"in-flight datastore snapshot owns nested job copy"
	)
	local reloaded, offlineEarned = codec.decode(snap, config, farmMath, now + 86400, uid)
	assert(reloaded, "offline pending batch reloads")
	assert(
		reloaded.production.packed_milk.readyAt == readyAt and reloaded.cash == data.cash + offlineEarned,
		"offline completion never automatically pays or repeats"
	)
	for _, animal in reloaded.animals do
		assert(animal.task == nil, "tasks that ended while offline return the animals home on load")
	end
	reloaded.production.packed_milk.readyAt += 1
	assert(snap.mainFarms["1"].production.packed_milk.readyAt == readyAt, "decoded jobs do not alias stored payload")
	for _, invalid in
		{ false, { unknown = { uid = "u", readyAt = now } }, { packed_milk = { uid = "u", readyAt = math.huge } } }
	do
		local corrupt = table.clone(snap)
		corrupt.mainFarms = table.clone(snap.mainFarms)
		corrupt.mainFarms["1"] = table.clone(snap.mainFarms["1"])
		corrupt.mainFarms["1"].production = invalid
		assert(
			codec.decode(corrupt, config, farmMath, now, uid) == nil,
			"corrupt jobs fail closed preserving original save"
		)
	end
	reset()
	assert(fire("start", "hatchery", nil).ok, "incubation starts")
	job = data.production.hatchery
	now = job.readyAt + 1
	while farmMath.countInZone(data, "poultry") < config.ZONES.poultry.capacity do
		table.insert(
			data.animals,
			{ uid = uid(), animalId = "chicken", zoneId = "poultry", bornAt = 0, stage = "adult" }
		)
	end
	assert(
		not fire("keep", "hatchery", job.uid).ok and data.production.hatchery == job,
		"full zone keeps paid batch available"
	)
	table.remove(data.animals)
	visualFailure = true
	local refreshesBefore = refreshes
	local count = #data.animals
	assert(fire("keep", "hatchery", job.uid).ok, "available space accepts chick")
	local chick = data.animals[#data.animals]
	assert(
		#data.animals == count + 1 and chick.animalId == "chicken" and chick.stage == "calf" and chick.bornAt == now,
		"kept chick is a new growing animal"
	)
	assert(
		chick.uid ~= job.uid and refreshes == refreshesBefore + 1 and data.production.hatchery == nil,
		"new UID and world refresh after single consumption"
	)
	assert(not fire("keep", "hatchery", job.uid).ok, "second keep cannot duplicate chick")
	assert(fire("start", "hatchery", nil).ok, "full coop can still incubate for sale")
	job = data.production.hatchery
	now = job.readyAt + 1
	assert(fire("sell", "hatchery", job.uid).ok, "full coop can sell ready chick")
	reset()
	for _, id in { "horse_training", "cheese", "fish_dispatch" } do
		assert(fire("start", id, nil).ok, "all specialist recipes can start")
		job = data.production[id]
		now = job.readyAt + 1
		assert(fire("sell", id, job.uid).ok, "all specialist recipes can complete")
	end
	-- Ürün merkezi: para yerine ahır deposuna ürün; hayvan kuralları aynı
	reset()
	local milk = config.PRODUCTION_RECIPES.milk_goods
	local cashBeforeGoods = data.cash
	assert(fire("start", "milk_goods", nil).ok, "a goods batch starts")
	assert(data.cash == cashBeforeGoods - milk.cost, "a goods batch charges its start cost")
	local goodsJob = data.production.milk_goods
	local working = 0
	for _, animal in data.animals do
		if animal.task and animal.task.id == "milk_goods" then
			working += 1
		end
	end
	assert(working == milk.requiredAdults, "goods batches also take the required adults")
	assert(not fire("sell", "milk_goods", goodsJob.uid).ok, "goods cannot be collected early")
	now = goodsJob.readyAt + 1
	cashBeforeGoods = data.cash
	local expectedAmount = farmMath.getGoodsYield(data, milk, now, goodsJob)
	assert(expectedAmount >= milk.goodsAmount, "the yield is at least the base amount")
	assert(fire("sell", "milk_goods", goodsJob.uid).ok, "a ready goods batch is collected")
	assert(data.cash == cashBeforeGoods, "goods batches pay no cash")
	assert(
		farmMath.getGoodsAmount(data, "milk") == math.min(expectedAmount, farmMath.getGoodsCap(data)),
		"the goods land in the barn"
	)
	assert(
		string.find(results[#results].message, "Ahıra eklendi", 1, true) ~= nil,
		"the player is told where the goods went"
	)
	assert(data.production.milk_goods == nil, "the job is consumed")
	for _, animal in data.animals do
		assert(animal.task == nil, "the animals are back after collecting")
	end
	assert(not fire("keep", "milk_goods", goodsJob.uid).ok, "goods batches cannot become animals")
	-- Parti hazırlanırken başka çiftlik/yardımcı depoyu doldurabilir; ürün ve taşan nakit bir kez teslim edilir.
	for _, freeSlots in { 0, 1 } do
		reset()
		assert(fire("start", "milk_goods", nil).ok, "goods start before shared storage fills")
		local pendingGoods = data.production.milk_goods
		now = pendingGoods.readyAt + 1
		local cap = farmMath.getGoodsCap(data)
		farmMath.addGoods(data, "milk", cap - freeSlots)
		local yield = farmMath.getGoodsYield(data, milk, now, pendingGoods)
		local walletBefore = data.cash
		local reply = fire("sell", "milk_goods", pendingGoods.uid)
		local compensation = farmMath.getGoodsCompensation(data, milk, pendingGoods, now, yield)
		assert(reply.ok and farmMath.getGoodsAmount(data, "milk") == cap, "claim preserves all available storage")
		assert(
			data.cash == walletBefore + farmMath.getGoodsSellValue("milk", yield - freeSlots) + compensation,
			"only overflow and floor compensation pay cash"
		)
		if freeSlots == 0 then
			assert(
				string.find(reply.message, "Depo dolu", 1, true) ~= nil
					and string.find(reply.message, "Ahıra eklendi", 1, true) == nil,
				"zero goods claim explains cash conversion instead of claiming inventory was added"
			)
		else
			assert(
				string.find(reply.message, "Depoya sığmayan", 1, true) ~= nil,
				"partial delivery explicitly explains the converted overflow"
			)
		end
		local walletAfter = data.cash
		assert(
			not fire("sell", "milk_goods", pendingGoods.uid).ok and data.cash == walletAfter,
			"full or partial delivery cannot pay overflow twice"
		)
	end
	-- Dolu depo yeni partiyi engeller
	farmMath.addGoods(data, "milk", farmMath.getGoodsCap(data))
	local fullBlocked = fire("start", "milk_goods", nil)
	assert(not fullBlocked.ok and data.production.milk_goods == nil, "a full barn blocks the next batch")
	assert(fire("start", "packed_milk", "medium").ok, "a full barn does not block cash recipes")
	-- Yardımcı ile otomatik tekrar: yalnızca yardımcısı olan çiftlikte ve tanınan partiyle açılır
	reset()
	data.purchased.pet_cash_lv1 = nil
	assert(
		not fire("auto", "packed_milk", "medium").ok and data.autoRepeat.packed_milk == nil,
		"no pet, no auto repeat"
	)
	data.purchased.pet_cash_lv1 = true
	assert(not fire("auto", "packed_milk", "fill").ok, "storage filling mode cannot select a cash recipe")
	assert(not fire("auto", "packed_milk", "huge").ok, "an unknown batch cannot be repeated")
	assert(not fire("auto", "hatchery", "default").ok, "the hatchery cannot be repeated (chicks are chosen by hand)")
	assert(fire("auto", "packed_milk", "small").ok and data.autoRepeat.packed_milk == "small", "the repeat turns on")
	assert(fire("start", "packed_milk", "medium").ok, "a manual start while repeating")
	assert(data.autoRepeat.packed_milk == "medium", "the latest manual choice becomes the repeated batch")
	assert(fire("auto", "packed_milk", "off").ok and data.autoRepeat.packed_milk == nil, "the repeat turns off")
	data.purchased[config.PRODUCTION_RECIPES.milk_goods.upgradeId] = nil
	assert(not fire("auto", "milk_goods", nil).ok, "auto repeat requires its production building")
	data.purchased[config.PRODUCTION_RECIPES.milk_goods.upgradeId] = true
	data.unlockedIslands.home = nil
	assert(not fire("auto", "milk_goods", nil).ok, "auto repeat requires its island")
	data.unlockedIslands.home = true
	data.purchased.pet_goods_lv1 = true
	assert(
		fire("auto", "milk_goods", nil).ok and data.autoRepeat.milk_goods == "default",
		"goods repeat without a batch size"
	)
	assert(
		fire("auto", "milk_goods", "fill").ok and data.autoRepeat.milk_goods == "fill",
		"goods helper can explicitly fill shared storage"
	)
	assert(not fire("start", "milk_goods", nil).ok, "storage policy does not bypass animals busy in cash factory")
	local busyCashJob = data.production.packed_milk
	now = busyCashJob.readyAt + 1
	assert(fire("sell", "packed_milk", busyCashJob.uid).ok, "claiming cash batch releases the shared cows")
	assert(fire("start", "milk_goods", nil).ok, "manual batch starts while filling storage")
	assert(data.autoRepeat.milk_goods == "fill", "manual start preserves the goods storage policy")
	-- Para tesisi seçenekleri: ücretsiz, her parti kendi hayvan sayısını ister ve seçilen partinin ödülünü verir
	reset()
	local milkRecipe = config.PRODUCTION_RECIPES.packed_milk
	local small = farmMath.findProductionOption(milkRecipe, "small")
	local large = farmMath.findProductionOption(milkRecipe, "large")
	assert(small.requiredAdults == 1 and large.requiredAdults == 4, "the options ask for different animal counts")
	local lacking = fire("start", "packed_milk", "large")
	assert(
		not lacking.ok and data.production.packed_milk == nil,
		"a batch that needs 4 cows cannot start with only 2 adults"
	)
	local cashBeforeSmall = data.cash
	assert(fire("start", "packed_milk", "small").ok, "a one-cow batch starts")
	local smallJob = data.production.packed_milk
	assert(
		data.cash == cashBeforeSmall and smallJob.optionId == "small",
		"cash batches are free and remember the option"
	)
	local smallWorking = 0
	for _, animal in data.animals do
		if animal.task and animal.task.id == "packed_milk" then
			smallWorking += 1
		end
	end
	assert(smallWorking == 1, "a small batch takes exactly one animal")
	assert(
		smallJob.readyAt - smallJob.startedAt == farmMath.getFacilityDuration(data, milkRecipe, "small"),
		"the batch runs for its own duration"
	)
	local reloadedSnap = codec.encode(data, now)
	local reloadedOptions = assert(codec.decode(reloadedSnap, config, farmMath, now, uid), "job with an option reloads")
	assert(reloadedOptions.production.packed_milk.optionId == "small", "the chosen option survives a reload")
	local bogus = table.clone(reloadedSnap)
	bogus.mainFarms = table.clone(reloadedSnap.mainFarms)
	bogus.mainFarms["1"] = table.clone(reloadedSnap.mainFarms["1"])
	bogus.mainFarms["1"].production = {
		packed_milk = table.clone(reloadedSnap.mainFarms["1"].production.packed_milk),
	}
	bogus.mainFarms["1"].production.packed_milk.optionId = "bogus"
	local repaired = assert(codec.decode(bogus, config, farmMath, now, uid), "an unknown option id is repaired")
	assert(repaired.production.packed_milk.optionId == nil, "an unknown option id falls back to the first option")
	now = smallJob.readyAt + 1
	local cashBeforeClaim = data.cash
	assert(fire("sell", "packed_milk", smallJob.uid).ok, "the small batch is claimed")
	assert(
		data.cash - cashBeforeClaim == math.max(small.reward, math.ceil(smallJob.forgone * small.returnMultiplier)),
		"the small batch pays the small option's reward"
	)
	-- Yeterli hayvan olunca en büyük parti de alınır ve hayvan başına daha çok öder
	for _ = 1, 2 do
		table.insert(data.animals, { uid = uid(), animalId = "cow", zoneId = "starter", bornAt = 0, stage = "adult" })
	end
	assert(fire("start", "packed_milk", "large").ok, "a four-cow batch starts once four adults are idle")
	local largeWorking = 0
	for _, animal in data.animals do
		if animal.task and animal.task.id == "packed_milk" then
			largeWorking += 1
		end
	end
	assert(largeWorking == 4, "the large batch takes four animals")
	assert(
		large.reward / large.requiredAdults > small.reward / small.requiredAdults,
		"more animals pay more per animal"
	)
	assert(saves == pushes and saves > 0 and settlements > 0, "each mutation pushes and schedules persistence")
	print(
		"PASS production: actual service ownership, adult/price checks, replay, timed claims, incubation capacity, persistence and schema4 migration"
	)
end
