--!strict
-- Gerçek Remote işleyicileri; finansal mutex'in dayanıklılığı ayrı gerçek PDS spec'inde sınanır.
return function(factory: any, harness: any, codec: any, config: any, farmMath: any, progression: any)
	local function setup(): (any, any)
		local h = harness.new()
		h.player.SetAttribute = function(_self: any, name: string, value: any)
			if name == "WorldReady" then
				h.worldReady = value
			end
		end
		h.plotService.restoreMainFarms = function(): boolean
			return true
		end
		h.plotService.teleportHome = function() end
		-- Gerçek API after callback'i oyuncuyla çağırır.
		local transaction = h.dataService.transactAccount
		h.dataService.transactAccount = function(player: any, mutate: any, after: any): (boolean, string?)
			return transaction(
				player,
				mutate,
				if after
					then function()
						after(player)
					end
					else nil
			)
		end
		local service = factory(
			h.game,
			h.remotes,
			h.dataService,
			h.plotService,
			h.economyService,
			h.guard,
			h.limiter,
			h.dateTime,
			h.task,
			h.warn
		)
		service.init()
		h.data.gold = 1000
		h.data.transfers = { outbox = {}, received = {} }
		return h, service
	end
	local h, service = setup()
	local function gold(action: any, detail: any, farm: any?): any
		return h.fire("RequestGoldAction", action, h.nextId(), farm or "1", detail)
	end
	local original = h.data.gold
	assert(not gold("buy", nil).ok, "missing payload is rejected")
	assert(not gold("buy", { expectedRun = 2, offerId = "auto_collect" }).ok, "stale run is rejected")
	assert(not gold("buy", { expectedRun = 1, offerId = "auto_collect" }, "2").ok, "wrong farm is rejected")
	h.worldReady = false
	assert(not gold("buy", { expectedRun = 1, offerId = "auto_collect" }).ok, "unready world is rejected")
	h.worldReady = true
	assert(not gold("buy", { expectedRun = 1, offerId = "unknown" }).ok, "unknown paid right is rejected")
	assert(h.data.gold == original and h.counters.saves == 0, "invalid contexts never persist or debit")
	h.data.gold = 0
	assert(not gold("buy", { expectedRun = 1, offerId = "auto_collect" }).ok, "insufficient gold never grants a right")
	h.data.gold = 1000
	assert(gold("buy", { expectedRun = 1, offerId = "auto_collect" }).ok, "permanent purchase persists")
	local boughtBalance = h.data.gold
	assert(
		h.data.owned.conveniences.auto_collect and not gold("buy", { expectedRun = 1, offerId = "auto_collect" }).ok,
		"owned purchase cannot charge twice"
	)
	assert(h.data.gold == boughtBalance, "duplicate ownership preserves wallet")
	local requestId = h.nextId()
	assert(
		h.fire("RequestGoldAction", "buy", requestId, "1", { expectedRun = 1, offerId = "pet_cash" }).ok,
		"new request succeeds"
	)
	local after = h.data.gold
	assert(
		h.fire("RequestGoldAction", "buy", requestId, "1", { expectedRun = 1, offerId = "pet_cash" }) == nil
			and h.data.gold == after,
		"same request ID cannot replay"
	)
	h.data.animals = { { uid = "income", animalId = "cow", zoneId = "starter", stage = "adult", bornAt = 0 } }
	local cash = assert(progression.goldCashQuote(h.data, 1, h.now), "income fixture quotes conversion")
	assert(
		not gold("convert", { expectedRun = 1, amount = 1, expectedCash = cash + 1 }).ok,
		"changed cash preview cannot charge"
	)
	local oldCash = h.data.cash
	assert(
		gold("convert", { expectedRun = 1, amount = 1, expectedCash = cash }).ok and h.data.cash == oldCash + cash,
		"exact cash quote is delivered"
	)
	h.data.production.test = { uid = "batch", readyAt = h.now + 120 }
	local cost = assert(progression.finishGoldQuote(h.data, "production", "test", h.now), "batch quotes finish")
	assert(
		not gold(
			"finish",
			{ expectedRun = 1, targetKind = "production", targetId = "test", uid = "old", expectedCost = cost }
		).ok,
		"stale batch cannot be finished"
	)
	assert(
		not gold(
			"finish",
			{ expectedRun = 1, targetKind = "production", targetId = "test", uid = "batch", expectedCost = cost - 1 }
		).ok,
		"higher server cost rejects stale preview"
	)
	local beforeFinish = h.data.gold
	assert(
		gold(
			"finish",
			{ expectedRun = 1, targetKind = "production", targetId = "test", uid = "batch", expectedCost = cost + 1 }
		).ok,
		"lower live cost is accepted"
	)
	assert(h.data.gold == beforeFinish - cost and h.data.production.test.readyAt == h.now, "only live cost is charged")
	assert(
		not gold(
			"finish",
			{ expectedRun = 1, targetKind = "production", targetId = "test", uid = "batch", expectedCost = cost }
		).ok,
		"ready batch cannot charge again"
	)
	h.data.animals[1].task = { kind = "extension", id = "barn", startedAt = h.now, endsAt = h.now + 120 }
	assert(not gold("finish", {
		expectedRun = 1,
		targetKind = "extension",
		uid = "income",
		expectedCost = 2,
		expectedEndsAt = h.now + 120,
		expectedStartedAt = h.now - 1,
	}).ok, "same animal on a new task rejects old preview")
	h.data.transfers.quarantined = true
	assert(not gold("buy", { expectedRun = 1, offerId = "pet_goods" }).ok, "backup quarantine blocks financial actions")
	h.data.transfers.quarantined = nil
	h.data.transfers.outbox.pending = {}
	assert(
		not h.fire("RequestRebirth", "income", h.nextId(), "1", { expectedRun = 1 }).ok,
		"pending transfer blocks rebirth"
	)
	h.data.transfers.outbox = {}
	for index = 1, config.MAIN_FARM_LIMIT do
		local id = tostring(index)
		local farm = codec.newFarm(config, farmMath, h.now, function(): string
			return "rebirth-animal"
		end, id)
		for _, upgrade in config.UPGRADES do
			if not upgrade.leveled and config.upgradeInTheme(upgrade, id) then
				farm.purchased[upgrade.id] = true
			end
		end
		farmMath.applyDerived(farm)
		h.data.mainFarms[id] = farm
	end
	for key, value in h.data.mainFarms["1"] do
		h.data[key] = value
	end
	h.data.progression.count, h.data.progression.run = 40, 41
	for _, id in config.PROGRESSION.perkOrder do
		h.data.progression.perks[id] = 5
	end
	assert(
		not h.fire("RequestRebirth", "income", h.nextId(), "1", { expectedRun = 41 }).ok,
		"maxed perk cannot exceed its bound"
	)
	assert(
		h.fire("RequestRebirth", "prestige", h.nextId(), "1", { expectedRun = 41 }).ok,
		"all-max prestige keeps rebirth available"
	)
	assert(
		h.data.progression.count == 41 and h.data.progression.run == 42 and h.data.progression.perks.income == 5,
		"prestige advances generation without an extra point"
	)
	assert(
		not h.fire("RequestRebirth", "prestige", h.nextId(), "1", { expectedRun = 41 }).ok,
		"old rebirth run cannot replay"
	)
	assert(not service.collect(h.player), "incomplete fresh run causes no repeated claim write")
	-- Gerçek döngü ve collect: bir oyuncunun kalıcı yazımı yield ederken diğeri tamamlanır.
	local slow = harness.new({ unlockAll = true })
	local secondData =
		assert(codec.decode(codec.encode(slow.data, slow.now), config, farmMath, slow.now, function(): string
			return "second-profile"
		end))
	local firstData = slow.data
	slow.playersList = { slow.player, slow.stranger }
	local stopped = false
	local failFirst = false
	slow.dataService.tryGet = function(player: any): any
		if player == slow.player then
			if failFirst then
				error("injected player failure")
			end
			return firstData
		end
		return if player == slow.stranger then secondData else nil
	end
	slow.dataService.transactAccount = function(player: any, mutate: any, afterCallback: any): (boolean, string?)
		if player == slow.player and not stopped then
			stopped = true
			coroutine.yield("slow datastore")
		end
		local ok, message = mutate(slow.dataService.tryGet(player))
		if ok and afterCallback then
			afterCallback(player)
		end
		return ok, message
	end
	local isolated = factory(
		slow.game,
		slow.remotes,
		slow.dataService,
		slow.plotService,
		slow.economyService,
		slow.guard,
		slow.limiter,
		slow.dateTime,
		slow.task,
		slow.warn
	)
	isolated.init()
	isolated.init()
	assert(#slow.spawned == 1, "reinitialization cannot create a second polling loop")
	slow.runSpawned(1)
	assert(#slow.spawned == 3, "one worker is scheduled for each player")
	local blocked = coroutine.create(slow.spawned[2])
	local started, marker = coroutine.resume(blocked)
	assert(started and marker == "slow datastore", "first player's real collect waits for durability")
	slow.spawned[3]()
	assert(secondData.gold > 0 and firstData.gold == 0, "another player's claim completes before the slow save resumes")
	slow.runSpawned(1)
	assert(#slow.spawned == 4, "in-flight player never accumulates extra workers")
	slow.spawned[4]()
	assert(coroutine.resume(blocked) and firstData.gold > 0, "slow player's claim eventually completes")
	slow.runSpawned(1)
	assert(#slow.spawned == 6, "finished player can be scheduled again")
	failFirst = true
	slow.spawned[5]()
	failFirst = false
	slow.spawned[6]()
	slow.runSpawned(1)
	assert(#slow.spawned == 8, "exception clears the per-player worker guard")
	slow.spawned[7]()
	slow.spawned[8]()
	print(
		"PASS progression service: Remote context, replay, permanent ownership, exact quote, stale jobs, finish cost, quarantine, prestige and isolated bounded workers"
	)
end
