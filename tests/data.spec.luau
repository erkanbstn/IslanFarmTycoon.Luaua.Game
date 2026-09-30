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
	-- Irk geliştirme: seviyeler sıkıştırılır, tanınmayan tür atılır, bozuk kayıt reddedilir
	local lineageRaw = codec.encode(save, now)
	assert(next(lineageRaw.mainFarms["1"].lineage) == nil, "new farms start without lineage")
	lineageRaw.mainFarms["1"].lineage = { cow = 3, chicken = 99, ghost = 5, goat = -2, duck = 0 }
	local withLineage = assert(codec.decode(lineageRaw, config, farmMath, now, uid))
	assert(
		withLineage.lineage.cow == 3
			and withLineage.lineage.chicken == config.LINEAGE.maxLevel
			and withLineage.lineage.ghost == nil
			and withLineage.lineage.goat == nil
			and withLineage.lineage.duck == nil,
		"lineage levels must be clamped and unknown species dropped"
	)
	assert(codec.encode(withLineage, now).mainFarms["1"].lineage.cow == 3, "lineage must survive saves")
	lineageRaw.mainFarms["1"].lineage = "broken"
	assert(codec.decode(lineageRaw, config, farmMath, now, uid) == nil, "corrupt lineage must fail closed")
	-- Alan genişletme: seviyeler sıkıştırılır, tanınmayan bölge atılır, bozuk kayıt reddedilir
	local expansionRaw = codec.encode(save, now)
	assert(next(expansionRaw.mainFarms["1"].expansions) == nil, "new farms start without expansions")
	expansionRaw.mainFarms["1"].expansions = { starter = 2, pasture = 99, ghost = 3, poultry = -1 }
	local withExpansion = assert(codec.decode(expansionRaw, config, farmMath, now, uid))
	assert(
		withExpansion.expansions.starter == 2
			and withExpansion.expansions.pasture == config.BUILD_UPGRADES.maxLevel
			and withExpansion.expansions.ghost == nil
			and withExpansion.expansions.poultry == nil,
		"expansion levels must be clamped and unknown zones dropped"
	)
	assert(codec.encode(withExpansion, now).mainFarms["1"].expansions.starter == 2, "expansions must survive saves")
	-- Tesis kimlikleri de geçerli hedeftir
	expansionRaw.mainFarms["1"].expansions = { hatchery = 3, cheese = 99, nothing = 2 }
	local withFacility = assert(codec.decode(expansionRaw, config, farmMath, now, uid))
	assert(
		withFacility.expansions.hatchery == 3
			and withFacility.expansions.cheese == config.BUILD_UPGRADES.maxLevel
			and withFacility.expansions.nothing == nil,
		"facility upgrade levels must be kept, clamped and validated"
	)
	expansionRaw.mainFarms["1"].expansions = 5
	assert(codec.decode(expansionRaw, config, farmMath, now, uid) == nil, "corrupt expansions must fail closed")
	-- Mevsim hedefi: geçerli kayıt korunur, bozuk kayıt sessizce atılır
	local seasonalRaw = codec.encode(save, now)
	assert(seasonalRaw.seasonal == nil, "new accounts have no season goal yet")
	seasonalRaw.seasonal = { key = 7, progress = 3, target = 6, base = 1200, claimed = false }
	local withSeasonal = assert(codec.decode(seasonalRaw, config, farmMath, now, uid))
	assert(
		withSeasonal.seasonal.key == 7
			and withSeasonal.seasonal.progress == 3
			and withSeasonal.seasonal.claimed == false,
		"season goal must load"
	)
	assert(codec.encode(withSeasonal, now).seasonal.target == 6, "season goal must survive saves")
	seasonalRaw.seasonal = { key = 7, progress = 99, target = 6, base = 1200, claimed = false }
	assert(
		assert(codec.decode(seasonalRaw, config, farmMath, now, uid)).seasonal.progress == 6,
		"progress is capped at the target"
	)
	seasonalRaw.seasonal = { key = -1, progress = 0, target = 6, base = 0, claimed = false }
	assert(
		assert(codec.decode(seasonalRaw, config, farmMath, now, uid)).seasonal == nil,
		"corrupt season goals are dropped"
	)
	-- Gezgin tüccar: geçerli işaret korunur, bozuk kayıt atılır
	local merchantRaw = codec.encode(save, now)
	assert(merchantRaw.merchant == nil, "new accounts have no merchant marker")
	merchantRaw.merchant = { key = 42, bought = true }
	local withMerchant = assert(codec.decode(merchantRaw, config, farmMath, now, uid))
	assert(withMerchant.merchant.key == 42 and withMerchant.merchant.bought == true, "merchant marker must load")
	assert(codec.encode(withMerchant, now).merchant.key == 42, "merchant marker must survive saves")
	merchantRaw.merchant = { key = -5, bought = "yes" }
	assert(assert(codec.decode(merchantRaw, config, farmMath, now, uid)).merchant == nil, "corrupt marker is dropped")
	-- Altın hayvan: geçerli pencere işareti korunur, bozuk kayıt atılır
	local goldenRaw = codec.encode(save, now)
	assert(goldenRaw.golden == nil, "new accounts have no golden marker")
	goldenRaw.golden = { key = 12 }
	local withGolden = assert(codec.decode(goldenRaw, config, farmMath, now, uid))
	assert(withGolden.golden.key == 12, "golden marker must load")
	assert(codec.encode(withGolden, now).golden.key == 12, "golden marker must survive saves")
	goldenRaw.golden = { key = 1.5 }
	assert(
		assert(codec.decode(goldenRaw, config, farmMath, now, uid)).golden == nil,
		"corrupt golden marker is dropped"
	)
	-- Hesap düzeyi ilerleme: ömür boyu kazanç, günlük ödül serisi, alınmış başarımlar
	local accountRaw = codec.encode(save, now)
	assert(
		accountRaw.daily == nil and accountRaw.lifetimeEarned == 0,
		"new accounts start without daily or lifetime data"
	)
	accountRaw.lifetimeEarned = 12345
	accountRaw.daily = { day = 100, streak = 3 }
	accountRaw.achievements = { cows_10 = true, not_an_achievement = true }
	local account = assert(codec.decode(accountRaw, config, farmMath, now, uid))
	assert(account.lifetimeEarned == 12345, "lifetime earnings must load")
	assert(account.daily and account.daily.day == 100 and account.daily.streak == 3, "daily streak must load")
	assert(
		account.achievements.cows_10 == true and account.achievements.not_an_achievement == nil,
		"only known achievements load"
	)
	local reEncoded = codec.encode(account, now)
	assert(
		reEncoded.lifetimeEarned == 12345 and reEncoded.daily.streak == 3 and reEncoded.achievements.cows_10,
		"account progress must survive saves"
	)
	for _, badDaily in
		{
			{ day = -1, streak = 1 },
			{ day = 5, streak = 0 },
			{ day = 5, streak = 99 },
			{ day = 0 / 0, streak = 1 },
			{ day = 5.5, streak = 1 },
			"x",
			{ day = 5 },
		}
	do
		accountRaw.daily = badDaily
		local repaired = assert(codec.decode(accountRaw, config, farmMath, now, uid))
		assert(repaired.daily == nil, "invalid daily records must be dropped")
	end
	accountRaw.lifetimeEarned = 0 / 0
	assert(
		assert(codec.decode(accountRaw, config, farmMath, now, uid)).lifetimeEarned == 0,
		"NaN lifetime earnings fall back to zero"
	)
	accountRaw.lifetimeEarned = -50
	assert(
		assert(codec.decode(accountRaw, config, farmMath, now, uid)).lifetimeEarned == 0,
		"negative lifetime earnings clamp to zero"
	)
	accountRaw.achievements = "all"
	assert(
		next(assert(codec.decode(accountRaw, config, farmMath, now, uid)).achievements) == nil,
		"non-table achievements are ignored"
	)
	local _, _, _, _, grown = codec.decode(codec.encode(save, now - 100000), config, farmMath, now, uid)
	assert(typeof(grown) == "number" and grown >= 0, "decode reports animals grown while away")
	print(
		"data: lock ownership, response-loss retries, revision, migration, numeric, capacity and account guards passed"
	)
end
