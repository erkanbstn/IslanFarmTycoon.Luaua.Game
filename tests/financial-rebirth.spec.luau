--!strict
-- Gerçek codec ve saf reset: eski kayıt, bozuk finansal alanlar, bağımsız snapshot ve kalıcı haklar.
return function(codec: any, config: any, farmMath: any, progression: any, rebirth: any)
	local now = 2000000000
	local serial = 0
	local function uid(): string
		serial += 1
		return `financial-{serial}`
	end
	local function fresh(): any
		return assert(codec.decode(nil, config, farmMath, now, uid), "new profile decodes")
	end
	local old = fresh()
	old.lifetimeEarned = 1e6
	local legacy = codec.encode(old, now)
	legacy.gold, legacy.owned, legacy.progression = nil, nil, nil
	local migrated =
		assert(codec.decode(legacy, config, farmMath, now, uid), "same-version optional legacy fields initialize")
	assert(
		migrated.gold == 0 and migrated.progression.run == 1 and migrated.progression.runEarnedBase == 0,
		"legacy earned achievements retain their first-run baseline"
	)
	assert(migrated.lifetimeEarned == 1e6, "adding financial fields never resets existing progress")
	for _, bad in { -1, 0.5, math.huge, 0 / 0, "100", config.PROGRESSION.gold.maxBalance + 1 } do
		local raw = codec.encode(migrated, now)
		raw.gold = bad
		assert(
			codec.decode(raw, config, farmMath, now, uid) == nil,
			"invalid financial balance preserves the original record"
		)
	end
	local raw = codec.encode(migrated, now)
	raw.owned.items.unknown_paid_item = true
	assert(
		codec.decode(raw, config, farmMath, now, uid) == nil,
		"unknown permanent rights are never silently discarded"
	)
	raw = codec.encode(migrated, now)
	raw.progression.count = 1
	assert(codec.decode(raw, config, farmMath, now, uid) == nil, "run and perk count must agree")
	raw = codec.encode(migrated, now)
	-- Eski ada/çiftlik hak anahtarları (ve bilinmeyen anahtarlar) zararsızca atılır; altın artık hak anahtarına bağlı değil.
	raw.progression.claims["unknown-reward"] = true
	raw.progression.claims["island:1:home"] = true
	raw.progression.claims["farm:1"] = true
	raw.progression.claims.terminal = true
	local legacyClaims =
		assert(codec.decode(raw, config, farmMath, now, uid), "legacy per-island claim keys decode harmlessly")
	assert(next(legacyClaims.progression.claims) == nil, "old claims are dropped; terminal needs R30")
	raw.progression.claims = nil
	assert(codec.decode(raw, config, farmMath, now, uid), "claims table is optional")
	raw.progression.claims = "bad"
	assert(codec.decode(raw, config, farmMath, now, uid) == nil, "a non-table claims value is still rejected")
	raw = codec.encode(migrated, now)
	raw.progression.count, raw.progression.run = config.PROGRESSION.maxRebirth, config.PROGRESSION.maxRebirth + 1
	raw.progression.perks =
		{ income = 5, growth = 5, starting_cash = 5, upgrade_discount = 5, facility_speed = 5, offline = 5 }
	raw.progression.claims = { terminal = true, ["farm:2"] = true }
	local terminal = assert(codec.decode(raw, config, farmMath, now, uid), "terminal claim decodes at R30")
	local kept = 0
	for _ in terminal.progression.claims do
		kept += 1
	end
	assert(terminal.progression.claims.terminal and kept == 1, "only terminal survives")
	migrated.gold = 1000
	migrated.owned.items.golden_crown = true
	migrated.inventory.items.golden_crown = true
	migrated.inventory.items.diamond_hammer = true
	migrated.inventory.uses.weather = { day = math.floor(now / 86400), count = 1, last = now }
	migrated.owned.conveniences.auto_collect = true
	migrated.receipts = { "paid-before-rebirth" }
	migrated.transfers = { outbox = {}, received = { completed = true } }
	migrated.daily = { day = math.floor(now / 86400), streak = 3 }
	migrated.merchant, migrated.golden = { key = 1, bought = true }, { key = 1 }
	migrated.progression.convertedDay, migrated.progression.convertedDayGold = math.floor(now / 86400), 50
	migrated.progression.doubleCredits = 1
	migrated.achievements = { earned_1m = true }
	for index = 1, config.MAIN_FARM_LIMIT do
		local id = tostring(index)
		local farm = codec.newFarm(config, farmMath, now, uid, id)
		for _, upgrade in config.UPGRADES do
			if not upgrade.leveled and config.upgradeInTheme(upgrade, id) then
				farm.purchased[upgrade.id] = true
			end
		end
		farmMath.applyDerived(farm)
		migrated.mainFarms[id] = farm
	end
	for key, value in migrated.mainFarms["1"] do
		migrated[key] = value
	end
	assert(progression.canRebirth(migrated), "completed six-farm fixture unlocks rebirth")
	assert(migrated.gold == 1000, "completing the run grants no gold before the rebirth itself")
	local rebirthReward = progression.rebirthGoldReward(migrated)
	assert(rebirthReward == config.PROGRESSION.gold.rebirthBase, "R1 reward is the base amount")
	local before = codec.encode(migrated, now)
	local pending = assert(codec.decode(before, config, farmMath, now, uid), "pending profile decodes")
	pending.transfers.outbox.pending = { senderId = 1, targetId = 2, amount = 100, epoch = 0 }
	assert(
		not rebirth.apply(pending, config, farmMath, progression, codec, now, uid, "income"),
		"rebirth retains pending transfers"
	)
	pending.transfers.outbox = {}
	pending.transfers.quarantined = true
	assert(
		not rebirth.apply(pending, config, farmMath, progression, codec, now, uid, "income"),
		"backup quarantine blocks financial reset"
	)
	assert(
		rebirth.apply(migrated, config, farmMath, progression, codec, now, uid, "income"),
		"valid selected effect and reset apply together"
	)
	assert(
		migrated.progression.run == 2 and migrated.progression.count == 1 and migrated.progression.perks.income == 1,
		"rebirth records one selection and generation"
	)
	assert(
		migrated.gold == 1000 + rebirthReward and #migrated.receipts == 1 and migrated.transfers.received.completed,
		"the single rebirth reward is granted atomically and financial tombstones survive"
	)
	assert(
		migrated.owned.items.golden_crown
			and migrated.inventory.items.golden_crown
			and not migrated.inventory.items.diamond_hammer,
		"only permanent paid items survive"
	)
	assert(
		migrated.daily.streak == 3 and migrated.merchant.bought and migrated.golden.key == 1,
		"real-time claim guards survive"
	)
	assert(
		migrated.progression.convertedDayGold == 50 and migrated.progression.convertedRunGold == 0,
		"daily quota survives while run quota resets"
	)
	assert(
		migrated.progression.runDouble and migrated.progression.doubleCredits == 0,
		"a prepaid next-run credit is consumed exactly once"
	)
	assert(
		next(migrated.achievements) == nil and migrated.progression.runEarnedBase == migrated.lifetimeEarned,
		"achievements reset against a fresh earned baseline"
	)
	assert(before.progression.run == 1 and before.gold == 1000, "encoded account metadata never aliases a later reset")
	assert(migrated.inventory.uses.weather.count == 1, "rebirth cannot reset real-time staff usage limits")
	assert(
		not rebirth.apply(migrated, config, farmMath, progression, codec, now, uid, "growth"),
		"a new incomplete run cannot replay rebirth"
	)
	local reloaded = assert(
		codec.decode(codec.encode(migrated, now), config, farmMath, now, uid),
		"financial reset round trip is valid"
	)
	assert(
		reloaded.progression.perks.income == 1 and reloaded.owned.items.golden_crown,
		"new account rights round trip without a version reset"
	)
	reloaded.animals = { { uid = "late-calf", animalId = "cow", zoneId = "starter", stage = "calf", bornAt = now } }
	reloaded.progression.returnEndsAt = now + 10
	local oldSpeed = farmMath.getGrowthSpeed(reloaded, "cow", "starter", now + 9)
	local newSpeed = farmMath.getGrowthSpeed(reloaded, "cow", "starter", now + 10)
	local expired =
		assert(codec.decode(codec.encode(reloaded, now), config, farmMath, now + 20, uid), "expired Return decodes")
	local expectedBornAt = now + 10 - 10 * oldSpeed / newSpeed
	assert(
		math.abs(expired.animals[1].bornAt - expectedBornAt) < 0.001,
		"offline growth remaps at expiry instead of login"
	)
	assert(expired.progression.returnEnded, "expired bonus is recorded once")
	local twice = assert(
		codec.decode(codec.encode(expired, now + 20), config, farmMath, now + 20, uid),
		"expired snapshot round trips"
	)
	assert(twice.animals[1].bornAt == expired.animals[1].bornAt, "reloading does not remap growth twice")
	-- Gerçek saf reset + codec ile otuz turun tamamı; her tur yeni altı çiftlik kurulur.
	local journey = fresh()
	journey.receipts = { "original-paid-right" }
	journey.owned.items.golden_crown = true
	journey.inventory.items.golden_crown = true
	for level = 1, config.PROGRESSION.maxRebirth do
		for index = 1, config.MAIN_FARM_LIMIT do
			local id = tostring(index)
			local farm = codec.newFarm(config, farmMath, now, uid, id)
			for _, upgrade in config.UPGRADES do
				if not upgrade.leveled and config.upgradeInTheme(upgrade, id) then
					farm.purchased[upgrade.id] = true
				end
			end
			for target in config.BUILD_TARGETS do
				farm.expansions[target] = config.BUILD_UPGRADES.maxLevel
			end
			farm.lineage[config.getTheme(id).homeAnimal] = config.LINEAGE.maxLevel
			farmMath.applyDerived(farm)
			journey.mainFarms[id] = farm
		end
		for key, value in journey.mainFarms["1"] do
			journey[key] = value
		end
		local perk = nil
		for _, id in config.PROGRESSION.perkOrder do
			if progression.canChoosePerk(journey, id) then
				perk = id
				break
			end
		end
		assert(perk and progression.canRebirth(journey), `level {level} has a valid effect and completion`)
		if level == config.PROGRESSION.maxRebirth then
			journey.progression.doubleCredits = 5
		end
		local goldBefore = journey.gold
		local expectedReward = progression.rebirthGoldReward(journey)
			+ (if level == config.PROGRESSION.maxRebirth then 4 * config.PROGRESSION.terminalDoubleGold else 0)
		assert(rebirth.apply(journey, config, farmMath, progression, codec, now, uid, perk), `rebirth {level} applies`)
		assert(journey.gold == goldBefore + expectedReward, `rebirth {level} pays exactly the helper amount once`)
		assert(
			journey.progression.count == level and journey.progression.run == level + 1,
			"exactly one generation advances"
		)
		journey = assert(
			codec.decode(codec.encode(journey, now), config, farmMath, now, uid),
			`rebirth {level} financial snapshot reloads`
		)
		assert(
			journey.owned.items.golden_crown and #journey.receipts == 1,
			"old paid rights and receipt history survive every turn"
		)
	end
	assert(
		journey.progression.doubleCredits == 0 and journey.progression.runDouble,
		"terminal turn consumes one credit and compensates remaining unusable credits"
	)
	for _, milestone in config.PROGRESSION.milestones do
		if milestone.itemId then
			assert(
				journey.owned.items[milestone.itemId] and journey.inventory.items[milestone.itemId],
				"every free milestone is permanent and reloadable"
			)
		end
	end
	assert(
		not rebirth.apply(journey, config, farmMath, progression, codec, now, uid, "income"),
		"thirty-one cannot bypass pure server cap"
	)
	print(
		"PASS financial rebirth: optional legacy data, strict money/rights/claims, snapshots, gold completion and reset preservation"
	)
end
