--!strict
-- Saf modüller gerçek Config/FarmMath ile runner tarafından enjekte edilir.
return function(lock: any, codec: any, config: any, farmMath: any)
	local now = 2000000000
	local first = assert(lock.acquire(nil, "server-a", now, 180))
	assert(lock.owns(first, "server-a", now))
	assert(lock.acquire(first, "server-b", now + 1, 180) == nil, "live owner must block a second server")
	local reacquired = assert(lock.acquire(first, "server-a", now + 2, 180))
	assert(reacquired._revision == 0, "lost acquire response must be idempotent")
	local snapshot = { version = 2, cash = 123, stored = 4, animals = {}, purchased = {}, lastSeen = now }
	local committed = assert(lock.commit(reacquired, "server-a", 0, "write-1", snapshot, now + 3, 180, false))
	assert(committed._revision == 1 and committed.cash == 123, "commit must advance revision and preserve payload")
	local retry = assert(lock.commit(committed, "server-a", 0, "write-1", snapshot, now + 4, 180, false))
	assert(retry._revision == 1, "uncertain write response must not write twice")
	assert(
		lock.commit(committed, "server-a", 0, "stale", snapshot, now + 5, 180, false) == nil,
		"old revision must be rejected"
	)
	local takeover = assert(lock.acquire(committed, "server-b", now + 184, 180))
	assert(
		lock.commit(takeover, "server-a", 1, "old-owner", snapshot, now + 185, 180, false) == nil,
		"expired owner must never overwrite"
	)
	local released = assert(lock.commit(takeover, "server-b", 1, "release-1", snapshot, now + 185, 180, true))
	assert(released._session == nil and released._revision == 2, "release must clear ownership atomically")
	local releaseRetry = assert(lock.commit(released, "server-b", 1, "release-1", snapshot, now + 186, 180, true))
	assert(releaseRetry._revision == 2, "release response loss must be recoverable")
	assert(lock.acquire({ version = 999 }, "server-a", now, 180) == nil, "future schema must not be overwritten")
	assert(lock.acquire({ version = 0 / 0 }, "server-a", now, 180) == nil, "NaN schema must be rejected")
	assert(lock.acquire({ _revision = 1e20 }, "server-a", now, 180) == nil, "unsafe integer revision must be rejected")
	assert(
		lock.acquire({ _session = { owner = "x", expiresAt = math.huge } }, "server-a", now, 180) == nil,
		"infinite lease must be rejected"
	)
	local counter = 0
	local function uid(): string
		counter += 1
		return `test-{counter}`
	end
	local save, offline, problem = codec.decode(nil, config, farmMath, now, uid)
	assert(save and not problem and offline == 0, "new save must decode without offline income")
	assert(
		#save.animals == config.STARTING_COW_COUNT and save.cash == config.STARTING_CASH,
		"new save defaults must match Config"
	)
	assert(save.ordersCompleted == 0 and save.order == nil, "older profiles must default new order fields")
	local corrupt = { version = 1, cash = math.huge, stored = 0 / 0, purchased = { "unknown" }, animals = {} }
	for i = 1, config.ZONES.starter.capacity + 4 do
		table.insert(corrupt.animals, {
			uid = "duplicate",
			animalId = "cow",
			zoneId = "starter",
			bornAt = if i == 1 then now - 2.5 else now + 100,
		})
	end
	local normalized = assert(codec.decode(corrupt, config, farmMath, now, uid))
	assert(lock.isFinite(normalized.cash) and normalized.stored == 0, "corrupt money must normalize to finite values")
	assert(#normalized.animals <= config.ZONES.starter.capacity, "loaded animals must fit zone capacity")
	local ids = {}
	for _, animal in normalized.animals do
		assert(not ids[animal.uid], "UIDs must be unique")
		ids[animal.uid] = true
		assert(animal.bornAt <= now, "future births must be normalized")
	end
	assert(normalized.animals[1].bornAt == now - 2.5, "fractional age must be preserved")
	local encoded = codec.encode(normalized, now)
	local second = assert(codec.decode(encoded, config, farmMath, now, uid))
	assert(second.cash == normalized.cash and #second.animals == #normalized.animals, "migration must be idempotent")
	assert(codec.decode({ version = 999 }, config, farmMath, now, uid) == nil, "future save schema must fail closed")
	assert(
		codec.decode({ version = 2, animals = { { animalId = "removed-species" } } }, config, farmMath, now, uid) == nil,
		"unknown assets must be quarantined, not silently lost"
	)
	local missingZone = assert(codec.decode({
		version = 1,
		animals = { { uid = string.rep("x", 100), animalId = "cow", zoneId = "removed-zone", bornAt = 0 } },
	}, config, farmMath, now, uid))
	assert(
		#missingZone.animals == 1 and missingZone.animals[1].zoneId == "starter",
		"legacy missing zone must rehome the animal"
	)
	assert(#missingZone.animals[1].uid <= 64, "normalized IDs must fit remote validation")
	local orderRaw = codec.encode(save, now)
	orderRaw.mainFarms["1"].ordersCompleted = 7
	orderRaw.mainFarms["1"].order = { uid = "order-1", animalId = "cow", progress = 3.25, target = config.ORDER_UNITS }
	local withOrder = assert(codec.decode(orderRaw, config, farmMath, now + 100, uid))
	assert(
		withOrder.order.progress == 3.25 and withOrder.ordersCompleted == 7,
		"offline time must not produce order progress"
	)
	assert(
		codec.encode(withOrder, now).mainFarms["1"].order.progress == 3.25,
		"fractional order progress must survive saves"
	)
	local future = assert(codec.decode({ version = 1, lastSeen = now + 100 }, config, farmMath, now, uid))
	assert(future.stored == 0, "future timestamp cannot award income")
	local languageRaw = codec.encode(save, now)
	assert(languageRaw.language == nil, "language must stay unset until the player chooses one")
	languageRaw.language = "de"
	local withLanguage = assert(codec.decode(languageRaw, config, farmMath, now, uid))
	assert(withLanguage.language == "de", "chosen language must load")
	assert(codec.encode(withLanguage, now).language == "de", "chosen language must survive saves")
	languageRaw.language = "klingon"
	local unknownLanguage = assert(codec.decode(languageRaw, config, farmMath, now, uid))
	assert(unknownLanguage.language == nil, "unknown language codes must be ignored")
	languageRaw.language = { "de" }
	assert(assert(codec.decode(languageRaw, config, farmMath, now, uid)).language == nil, "language must be a string")
	print("data: lock ownership, response-loss retries, revision, migration, numeric and capacity guards passed")
end
