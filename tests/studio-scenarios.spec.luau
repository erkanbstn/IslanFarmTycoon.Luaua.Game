--!strict
return function(fixtures: any, codec: any, config: any, farmMath: any, progression: any)
	assert(fixtures.allowed(true, true, true, false), "isolated Studio permits fixtures")
	assert(not fixtures.allowed(false, true, true, false), "published servers reject fixtures")
	assert(not fixtures.allowed(true, false, true, false), "explicit QA mode required")
	assert(not fixtures.allowed(true, true, false, false), "persistent Studio places reject fixtures")
	assert(not fixtures.allowed(true, true, true, true), "persistent sessions reject fixtures")
	assert(not fixtures.allowed(true, true, true, nil), "unknown persistence rejects fixtures")
	local uid = 0
	local function nextUid(): string
		uid += 1
		return `qa-{uid}`
	end
	local function create(name: string, level: number): any
		return fixtures.create(name, level, 1700000000, nextUid, config, farmMath, codec, progression)
	end
	local fresh = create("fresh", 0)
	assert(#fresh.animals == 0 and fresh.cash == config.getStartingCash("1"), "fresh starts without purchased animals")
	local merchant = create("merchant", 0)
	assert(merchant.adminForce.merchantUntil > 1700000000, "merchant visit is active")
	local production = create("production", 0)
	assert(next(production.autoRepeat) ~= nil and #production.animals > 0, "production has adults and a repeat recipe")
	for _, level in { 0, 29, 30 } do
		local ready = create("rebirth-ready", level)
		assert(ready.progression.count == level, "fixture preserves requested rebirth level")
		for index = 1, config.MAIN_FARM_LIMIT do
			assert(
				progression.isRebirthFarmComplete(ready, tostring(index)),
				"all farms meet real rebirth requirements"
			)
		end
		assert(
			progression.canRebirth(ready) == (level < config.PROGRESSION.maxRebirth),
			"maximum rebirth remains terminal"
		)
	end
	local before = uid
	assert(not pcall(create, "unknown", 0), "invalid scenario is rejected")
	assert(not pcall(create, "fresh", 31), "out of range rebirth is rejected")
	assert(uid == before, "invalid requests cannot allocate a profile")
	print("PASS Studio scenarios: fail-closed guards, production and real six-farm rebirth requirements")
end
