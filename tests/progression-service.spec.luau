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
		h.equipmentRefreshes = 0
		service.configureEquipmentRefresh(function()
			h.equipmentRefreshes += 1
		end)
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
	local collector = setup()
	collector.data.passes = { auto_collector = true }
	local collectorBalance = collector.data.gold
	assert(
		not collector.fire(
			"RequestGoldAction",
			"buy",
			collector.nextId(),
			"1",
			{ expectedRun = 1, offerId = "auto_collect" }
		).ok,
		"existing collector pass blocks an equivalent permanent gold purchase"
	)
	assert(
		collector.data.gold == collectorBalance and collector.counters.saves == 0,
		"equivalent ownership never debits or saves"
	)
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
	-- Üretim hızlı bitirmesi kapalı: sürmekte olan ve zaten hazır partiler ödeme/durum değiştirmez.
	for _, readyAt in { h.now + 120, h.now - 1 } do
		h.data.production.test = { uid = "batch", readyAt = readyAt }
		h.data.animals[1].task = { kind = "production", id = "test", startedAt = h.now - 20, endsAt = readyAt }
		local beforeGold, beforeCash = h.data.gold, h.data.cash
		local batch, task = h.data.production.test, h.data.animals[1].task
		assert(
			not gold(
				"finish",
				{ expectedRun = 1, targetKind = "production", targetId = "test", uid = "batch", expectedCost = 2 }
			).ok,
			"production finishing rejects both working and ready batches"
		)
		assert(
			h.data.gold == beforeGold
				and h.data.cash == beforeCash
				and h.data.production.test == batch
				and batch.readyAt == readyAt
				and h.data.animals[1].task == task
				and task.endsAt == readyAt,
			"unsupported production finish preserves both wallets, batch and working animals"
		)
	end
	h.data.animals[1].task = { kind = "extension", id = "barn", startedAt = h.now, endsAt = h.now + 120 }
	h.data.animals[1].extensionId = "barn"
	local cost = assert(progression.finishGoldQuote(h.data, "extension", "income", h.now), "extension quotes finish")
	local function finishRequest(uid: string, expectedCost: number, startedAt: number?): any
		return {
			expectedRun = 1,
			targetKind = "extension",
			uid = uid,
			expectedCost = expectedCost,
			expectedEndsAt = h.now + 120,
			expectedStartedAt = startedAt or h.now,
		}
	end
	assert(not gold("finish", finishRequest("old", cost)).ok, "stale animal cannot be finished")
	assert(
		not gold("finish", finishRequest("income", cost, h.now - 1)).ok,
		"same animal on a new task rejects old preview"
	)
	assert(not gold("finish", finishRequest("income", cost - 1)).ok, "higher server cost rejects stale preview")
	local beforeFinish = h.data.gold
	local finishId = h.nextId()
	assert(
		h.fire("RequestGoldAction", "finish", finishId, "1", finishRequest("income", cost + 1)).ok,
		"lower live cost is accepted"
	)
	assert(
		h.data.gold == beforeFinish - cost and h.data.animals[1].task == nil and h.data.animals[1].extensionId == nil,
		"only live cost is charged and the extension animal returns"
	)
	assert(
		h.fire("RequestGoldAction", "finish", finishId, "1", finishRequest("income", cost + 1)) == nil
			and h.data.gold == beforeFinish - cost,
		"same finish request cannot replay"
	)
	assert(
		not gold("finish", finishRequest("income", cost)).ok and h.data.gold == beforeFinish - cost,
		"already finished extension cannot charge again"
	)
	h.data.animals[1].task = { kind = "extension", id = "barn", startedAt = h.now - 120, endsAt = h.now }
	assert(not gold("finish", {
		expectedRun = 1,
		targetKind = "extension",
		uid = "income",
		expectedCost = cost,
		expectedEndsAt = h.now,
		expectedStartedAt = h.now - 120,
	}).ok and h.data.gold == beforeFinish - cost, "naturally ready extension cannot charge")
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
	local beforeLegacy = codec.encode(h.data, h.now)
	assert(
		not h.fire("RequestRebirth", "prestige", h.nextId(), "1", { expectedRun = 41 }).ok,
		"legacy accounts above thirty cannot bypass terminal cap with prestige"
	)
	assert(
		h.data.progression.count == 40 and h.data.progression.run == 41,
		"legacy generations and perk rights remain untouched"
	)
	local decodedLegacy = assert(codec.decode(beforeLegacy, config, farmMath, h.now, function(): string
		return "legacy"
	end))
	assert(
		decodedLegacy.progression.count == 40 and decodedLegacy.progression.perks.income == 5,
		"legacy forty points are not clamped or overwritten"
	)
	assert(service.collect(h.player), "legacy earned permanent rewards are repaired inside the financial checkpoint")
	local savedAfterRepair = h.counters.saves
	for _ = 1, 30 do
		assert(not service.collect(h.player), "reward reconciliation replay is idempotent")
	end
	assert(h.counters.saves == savedAfterRepair, "thirty repeated claims produce no additional checkpoint")
	h.data.progression.doubleCredits = 3
	h.data.gold = config.PROGRESSION.gold.maxBalance
	assert(
		not service.collect(h.player) and h.data.progression.doubleCredits == 3,
		"legacy prepaid terminal credits are retained when wallet is full"
	)
	h.data.gold = 0
	assert(service.collect(h.player), "legacy prepaid credits are reconciled when capacity becomes available")
	assert(
		h.data.gold == 3 * config.PROGRESSION.terminalDoubleGold and h.data.progression.doubleCredits == 0,
		"legacy prepaid rights convert in full exactly once"
	)
	assert(not service.collect(h.player), "legacy credit recovery cannot replay")
	assert(h.equipmentRefreshes == 0, "rejected terminal resets never change equipped presentation")
	h.data.progression.count, h.data.progression.run, h.data.progression.perks = 0, 1, {}
	assert(
		h.fire("RequestRebirth", "income", h.nextId(), "1", { expectedRun = 1 }).ok,
		"valid server rebirth still advances below the cap"
	)
	assert(h.equipmentRefreshes == 1, "durable reset refreshes equipment after removing run-only items")
	-- Gerçek döngü ve collect: bir oyuncunun kalıcı yazımı yield ederken diğeri tamamlanır.
	local slow = harness.new({ unlockAll = true })
	local secondData =
		assert(codec.decode(codec.encode(slow.data, slow.now), config, farmMath, slow.now, function(): string
			return "second-profile"
		end))
	local firstData = slow.data
	slow.playersList = { slow.player, slow.stranger }
	local cohort = { [slow.player] = firstData, [slow.stranger] = secondData }
	for index = 3, 30 do
		local player = table.clone(slow.stranger)
		player.UserId = slow.stranger.UserId + index
		table.insert(slow.playersList, player)
		cohort[player] =
			assert(codec.decode(codec.encode(secondData, slow.now), config, farmMath, slow.now, function(): string
				return `cohort-{index}`
			end))
	end
	local stopped = false
	local failFirst = false
	slow.dataService.tryGet = function(player: any): any
		if player == slow.player then
			if failFirst then
				error("injected player failure")
			end
			return firstData
		end
		return cohort[player]
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
	assert(#slow.spawned == 31, "one worker is scheduled for each of thirty concurrent players")
	local blocked = coroutine.create(slow.spawned[2])
	local started, marker = coroutine.resume(blocked)
	assert(started and marker == "slow datastore", "first player's real collect waits for durability")
	for index = 3, 31 do
		slow.spawned[index]()
	end
	assert(secondData.gold > 0 and firstData.gold == 0, "another player's claim completes before the slow save resumes")
	slow.runSpawned(1)
	assert(#slow.spawned == 60, "in-flight player never accumulates extra workers while twenty-nine players continue")
	for index = 32, 60 do
		slow.spawned[index]()
	end
	assert(coroutine.resume(blocked) and firstData.gold > 0, "slow player's claim eventually completes")
	slow.runSpawned(1)
	assert(#slow.spawned == 90, "finished player can be scheduled again across the thirty-player cohort")
	failFirst = true
	slow.spawned[61]()
	failFirst = false
	for index = 62, 90 do
		slow.spawned[index]()
	end
	slow.runSpawned(1)
	assert(#slow.spawned == 120, "exception clears the per-player worker guard without leaking thirty-player jobs")
	for index = 91, 120 do
		slow.spawned[index]()
	end
	print(
		"PASS progression service: Remote context, replay, permanent ownership, exact quote, stale jobs, finish cost, quarantine, terminal cap, legacy rights and isolated bounded workers"
	)
end
