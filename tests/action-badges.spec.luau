--!strict
return function(factory: any, Config: any, FarmMath: any, SaveCodec: any, Rewards: any)
	local now = 1700000000
	local save = assert(
		SaveCodec.decode(nil, Config, FarmMath, now, function()
			return "badge"
		end),
		"badge profile"
	)
	local service = {
		WaitForChild = function(self: any): any
			return self
		end,
	}
	local badges = factory({
		GetService = function(): any
			return service
		end,
	}, {
		upgradeAffordable = function(state: any, upgrade: any): boolean
			return state.cash >= FarmMath.getUpgradeCost(state, upgrade)
				and #FarmMath.getGoodsShortfall(state, FarmMath.getGoodsCost(state, upgrade)) == 0
		end,
	}, Config, FarmMath, Rewards)
	local home, satellite: any = nil, nil
	for _, recipe in Config.PRODUCTION_RECIPES do
		if recipe.island == "home" then
			home = recipe
		elseif Config.themeHasIsland("1", recipe.island) then
			satellite = recipe
		end
	end
	assert(home and satellite, "home and satellite production fixtures")
	save.production = {
		[home.id] = { readyAt = now },
		[satellite.id] = { readyAt = now + 1 },
		unknown = { readyAt = now - 1 },
	}
	local total, islands = badges.production(save, now)
	assert(
		total == 1 and islands.home == 1 and islands[satellite.island] == nil,
		"only ready jobs mark their own island"
	)
	total, islands = badges.production(save, now + 1)
	assert(total == 2 and islands[satellite.island] == 1, "timer boundary adds the new island count")
	save.production[home.id] = nil
	total, islands = badges.production(save, now + 1)
	assert(total == 1 and islands.home == nil, "delivery removes the matching counter without hiding other work")
	local otherFarm = table.clone(save)
	otherFarm.activeMainFarmId = "6"
	total = badges.production(otherFarm, now + 1)
	assert(total == 0, "wrong theme jobs cannot leak into another farm's tabs")

	save.lifetimeEarned = 0
	save.achievements = {}
	save.seasonal = Rewards.newSeasonalGoal(save, Rewards.seasonNumber(now))
	save.seasonal.progress = save.seasonal.target
	save.lifetimeEarned = save.seasonal.base + save.seasonal.target
	local _, definition = Rewards.seasonalDef(save.seasonal.key)
	assert(definition, "season exists")
	for _, achievement in Config.ACHIEVEMENTS do
		save.achievements[achievement.id] = true
	end
	local rewardTotal, daily, achievements = badges.rewards(save, now)
	assert(
		rewardTotal == 2 and daily == 2 and achievements == 0,
		"daily and seasonal rewards both belong to Daily, never Achievements"
	)
	save.seasonal.claimed = true
	save.daily = { day = math.floor(now / 86400), streak = 1 }
	rewardTotal, daily, achievements = badges.rewards(save, now)
	assert(
		rewardTotal == 0 and daily == 0 and achievements == 0,
		"claimed rewards clear both parent and category badges"
	)

	save.cash = 1e12
	local upgradeTotal, counts = badges.upgrades(save)
	assert(
		upgradeTotal > 0 and counts.home and counts.home.upgrades > 0,
		"available construction marks its category and island"
	)
	local homeCounts = counts.home
	assert(
		homeCounts.total == homeCounts.upgrades + homeCounts.levels + homeCounts.expansions,
		"parent count is the sum of visible categories"
	)
	save.cash = 0
	local poorTotal = badges.upgrades(save)
	assert(poorTotal < upgradeTotal, "unaffordable choices never advertise an available purchase")
	print("PASS action badges: production timer/delivery, farm isolation, reward routing and affordable upgrades")
end
