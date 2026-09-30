--!strict
-- Günlük ödül serisi, ödül miktarı ve başarım ilerlemesi (saf, gerçek Config/FarmMath ile).
return function(Rewards: any, Config: any, FarmMath: any)
	local DAY = 86400
	local function save(): any
		local data: any = {
			cash = 0,
			stored = 0,
			purchased = {},
			animals = {},
			barnLevel = 1,
			unlockedIslands = {},
			unlockedZones = {},
			ordersCompleted = 0,
			lifetimeEarned = 0,
			achievements = {},
		}
		FarmMath.applyDerived(data)
		return data
	end

	assert(
		Rewards.dayIndex(0) == 0 and Rewards.dayIndex(DAY - 1) == 0 and Rewards.dayIndex(DAY * 10) == 10,
		"UTC day index"
	)

	-- Seri: ilk alım, aynı gün, ertesi gün, bozulan seri, 7. günden sonra baştan
	local first = Rewards.dailyStatus(nil, DAY * 10)
	assert(first.canClaim and first.streak == 0 and first.nextStreak == 1, "first claim starts the streak")
	local same = Rewards.dailyStatus({ day = 10, streak = 3 }, DAY * 10 + 5000)
	assert(not same.canClaim and same.streak == 3, "same day cannot be claimed twice")
	local next = Rewards.dailyStatus({ day = 10, streak = 3 }, DAY * 11)
	assert(next.canClaim and next.nextStreak == 4, "consecutive day continues the streak")
	local broken = Rewards.dailyStatus({ day = 10, streak = 5 }, DAY * 12)
	assert(broken.canClaim and broken.nextStreak == 1, "a missed day resets the streak")
	local length = #Config.DAILY_REWARD_MULTIPLIERS
	local wrap = Rewards.dailyStatus({ day = 10, streak = length }, DAY * 11)
	assert(wrap.canClaim and wrap.nextStreak == 1, "the streak wraps after the last day")
	local future = Rewards.dailyStatus({ day = 50, streak = 2 }, DAY * 10)
	assert(not future.canClaim, "a clock that moved backwards cannot claim again")

	-- Ödül: en az taban, gelirle ve seriyle artar
	local poor = save()
	assert(Rewards.dailyAmount(poor, 1) == Config.DAILY_MIN_REWARD, "empty farm receives the minimum reward")
	local rich = save()
	for index = 1, 10 do
		table.insert(
			rich.animals,
			{ uid = `c{index}`, animalId = "cow", zoneId = "starter", bornAt = 0, stage = "adult" }
		)
	end
	local day1, day7 = Rewards.dailyAmount(rich, 1), Rewards.dailyAmount(rich, length)
	assert(day1 > Config.DAILY_MIN_REWARD, "income scales the daily reward")
	assert(
		day7 > day1
				and day7 == math.floor(
					day1 / Config.DAILY_REWARD_MULTIPLIERS[1] * Config.DAILY_REWARD_MULTIPLIERS[length]
				)
			or day7 > day1,
		"later streak days pay more"
	)
	assert(Rewards.dailyAmount(rich, 99) == Rewards.dailyAmount(rich, length), "unknown streak clamps to the last day")

	-- Başarım ilerlemesi
	local player = save()
	local function achievement(id: string): any
		for _, entry in Config.ACHIEVEMENTS do
			if entry.id == id then
				return entry
			end
		end
		error(`achievement {id} missing`)
	end
	assert(Rewards.progress(player, achievement("cows_10")) == 0, "no cows yet")
	for index = 1, 10 do
		table.insert(
			player.animals,
			{ uid = `x{index}`, animalId = "cow", zoneId = "starter", bornAt = 0, stage = "adult" }
		)
	end
	assert(Rewards.isComplete(player, achievement("cows_10")), "ten cows complete the cow achievement")
	assert(Rewards.progress(player, achievement("animals_25")) == 10, "animals metric counts every animal")
	assert(Rewards.progress(player, achievement("first_island")) == 1, "only the home island is open at the start")
	player.unlockedIslands.poultry = true
	assert(Rewards.isComplete(player, achievement("first_island")), "a second island completes the island achievement")
	player.lifetimeEarned = 10000
	assert(Rewards.isComplete(player, achievement("earned_10k")), "lifetime earnings complete the money achievement")
	assert(Rewards.progress(save(), achievement("earned_10k")) == 0, "missing lifetimeEarned counts as zero")
	player.ordersCompleted = 5
	assert(Rewards.isComplete(player, achievement("orders_5")), "delivered orders complete the order achievement")

	local claimable = Rewards.claimableCount(player)
	assert(claimable >= 3, "several achievements are claimable")
	player.achievements.cows_10 = true
	assert(Rewards.claimableCount(player) == claimable - 1, "claimed achievements are no longer claimable")
	for _, entry in Config.ACHIEVEMENTS do
		assert(entry.reward > 0 and entry.target > 0 and entry.id ~= "", "achievement config must be sane")
	end
	-- Mevsim hedefi: mevsim numarası/tanımı, canlı kazanç, yatırım sayacı, ödül ve yenilenme
	do
		local season = Config.SEASON_SECONDS
		local springNow = 0 -- mevsim numarası 0 = Config.SEASONS[1]
		assert(
			Rewards.seasonNumber(springNow + 5) == 0 and Rewards.seasonNumber(season + 1) == 1,
			"season numbers follow the clock"
		)
		assert(
			Rewards.seasonalDef(0).metric == Config.SEASONAL_GOALS[Config.SEASONS[1].id].metric,
			"definition follows the season"
		)
		local seasonal = save()
		seasonal.lifetimeEarned = 1000
		assert(not Rewards.seasonalClaimable(seasonal, springNow), "an unstored goal is never claimable")
		assert(Rewards.ensureSeasonal(seasonal, springNow) and seasonal.seasonal.key == 0, "first call stores the goal")
		assert(not Rewards.ensureSeasonal(seasonal, springNow + 10), "same season does not recreate the goal")
		local goal = seasonal.seasonal
		local def = Rewards.seasonalDef(0)
		assert(goal.base == 1000 and goal.target >= (def.minTarget or 1), "earned goals remember the starting earnings")
		assert(Rewards.seasonalProgress(seasonal, goal) == 0, "no progress before earning")
		seasonal.lifetimeEarned = 1000 + goal.target / 2
		assert(math.abs(Rewards.seasonalProgress(seasonal, goal) - goal.target / 2) < 1e-6, "earned progress is live")
		seasonal.lifetimeEarned = 1000 + goal.target * 5
		assert(Rewards.seasonalProgress(seasonal, goal) == goal.target, "progress never exceeds the target")
		assert(Rewards.seasonalClaimable(seasonal, springNow), "a completed stored goal is claimable")
		assert(
			Rewards.claimableCount(seasonal, springNow) == Rewards.claimableCount(seasonal) + 1,
			"claimable count includes the season goal"
		)
		goal.claimed = true
		assert(not Rewards.seasonalClaimable(seasonal, springNow), "a claimed goal cannot be claimed twice")
		assert(Rewards.seasonalReward(seasonal) >= Config.SEASONAL_MIN_REWARD, "reward has a floor")
		-- Yatırım sayacı yalnızca "invest" mevsiminde işler
		Rewards.recordInvest(seasonal, springNow)
		assert(seasonal.seasonal.progress == 0, "investments do not count in an earned season")
		local summerNow = season * 1
		assert(Rewards.seasonalDef(1).metric == "invest", "the second season counts investments")
		Rewards.recordInvest(seasonal, summerNow)
		assert(
			seasonal.seasonal.key == 1 and seasonal.seasonal.progress == 1 and not seasonal.seasonal.claimed,
			"a new season replaces the old goal"
		)
		for _ = 1, 20 do
			Rewards.recordInvest(seasonal, summerNow)
		end
		assert(
			seasonal.seasonal.progress == seasonal.seasonal.target and Rewards.seasonalClaimable(seasonal, summerNow),
			"the counter caps at the target"
		)
		seasonal.seasonal.claimed = true
		Rewards.recordInvest(seasonal, summerNow)
		assert(seasonal.seasonal.progress == seasonal.seasonal.target, "a claimed goal stops counting")
	end

	print("PASS rewards: daily streak, wrap, reward scaling and achievement progress")
end
