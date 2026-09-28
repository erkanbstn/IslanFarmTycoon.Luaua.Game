--!strict
return function(createService: any, createLimiter: any, rules: any, codec: any, config: any, farmMath: any)
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
		function() end
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
		request.OnServerEvent.fire(player, "start", "dairy", nil, badId)
	end
	assert(#results == 0 and next(data.production) == nil, "malformed request never mutates or replies")
	assert(not fire("start", "dairy", nil, stranger).ok, "another profile cannot be accessed")
	active = false
	assert(not fire("start", "dairy", nil).ok, "lost/failed profile cannot start")
	active = true
	hasPlot = false
	assert(not fire("start", "dairy", nil).ok, "world must be assigned")
	hasPlot = true
	data.purchased.milk_factory = nil
	assert(not fire("start", "dairy", nil).ok, "factory ownership is mandatory")
	data.purchased.milk_factory = true
	data.animals[1].bornAt = now
	assert(not fire("start", "dairy", nil).ok, "calf with stale adult stage cannot satisfy requirement")
	data.animals[1].bornAt = 0
	data.cash = 0
	assert(not fire("start", "dairy", nil).ok, "insufficient funds cannot create a job")
	data.cash = 10000
	assert(not fire("start", {}, nil).ok and not fire("hack", "dairy", nil).ok, "malformed actions are rejected")
	assert(not fire("start", "dairy", "forged").ok, "start cannot provide its own uid")
	local before = data.cash
	now += 0.6
	sequence += 1
	request.OnServerEvent.fire(player, "start", "dairy", nil, sequence, "2")
	assert(
		not results[#results].ok and next(data.production) == nil and data.cash == before,
		"delayed request for a different main farm cannot spend or create production"
	)
	assert(fire("start", "dairy", nil).ok, "qualified dairy starts")
	local job = data.production.dairy
	assert(data.cash == before - config.PRODUCTION_RECIPES.dairy.cost, "server charges exact configured cost")
	local startSequence = sequence
	now += 1
	request.OnServerEvent.fire(player, "start", "dairy", nil, startSequence, data.activeMainFarmId)
	assert(data.cash == before - config.PRODUCTION_RECIPES.dairy.cost, "same sequence never charges twice")
	assert(not fire("start", "dairy", nil).ok, "only one pending batch per recipe")
	assert(not fire("sell", "dairy", job.uid).ok, "cannot claim early")
	now = job.readyAt + 1
	assert(not fire("sell", "dairy", "forged").ok, "claim requires exact job uid")
	assert(not fire("keep", "dairy", job.uid).ok and data.production.dairy == job, "cash output cannot become animal")
	assert(fire("sell", "dairy", job.uid).ok, "ready batch sells")
	local after = data.cash
	assert(
		after == before - config.PRODUCTION_RECIPES.dairy.cost + config.PRODUCTION_RECIPES.dairy.reward,
		"reward is server configured"
	)
	assert(not fire("sell", "dairy", job.uid).ok and data.cash == after, "double claim cannot pay")
	request.OnServerEvent.fire(player, "start", "dairy", nil, startSequence, data.activeMainFarmId)
	assert(data.production.dairy == nil, "old start replay stays rejected even after claim")
	assert(fire("start", "dairy", nil).ok, "production is repeatable with new sequence")
	local snap = codec.encode(data, now)
	assert(snap.version == 4, "new jobs require schema4 to keep old servers from dropping them")
	local readyAt = snap.mainFarms["1"].production.dairy.readyAt
	data.production.dairy.readyAt += 100
	assert(snap.mainFarms["1"].production.dairy.readyAt == readyAt, "in-flight datastore snapshot owns nested job copy")
	local reloaded = assert(codec.decode(snap, config, farmMath, now + 86400, uid), "offline pending batch reloads")
	assert(
		reloaded.production.dairy.readyAt == readyAt and reloaded.cash == data.cash,
		"offline completion never automatically pays or repeats"
	)
	reloaded.production.dairy.readyAt += 1
	assert(snap.mainFarms["1"].production.dairy.readyAt == readyAt, "decoded jobs do not alias stored payload")
	for _, invalid in
		{ false, { unknown = { uid = "u", readyAt = now } }, { dairy = { uid = "u", readyAt = math.huge } } }
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
	local count = #data.animals
	assert(fire("keep", "hatchery", job.uid).ok, "available space accepts chick")
	local chick = data.animals[#data.animals]
	assert(
		#data.animals == count + 1 and chick.animalId == "chicken" and chick.stage == "calf" and chick.bornAt == now,
		"kept chick is a new growing animal"
	)
	assert(
		chick.uid ~= job.uid and refreshes == 1 and data.production.hatchery == nil,
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
	assert(saves == pushes and saves > 0 and settlements > 0, "each mutation pushes and schedules persistence")
	print(
		"PASS production: actual service ownership, adult/price checks, replay, timed claims, incubation capacity, persistence and schema4 migration"
	)
end
