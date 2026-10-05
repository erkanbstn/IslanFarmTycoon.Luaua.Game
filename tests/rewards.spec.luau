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
	-- Günlük ödül tavanı: geç oyunda 8 dk'lık ödül hissedilmiyordu; yeni ödül en çok 12,5 dk (7. gün) ve 7 günlük toplam bir günün gelirinin %3'ünden azdır
	-- (rebirth temposunu kaydırmaz); seri çarpanları azalmaz, son gün en büyüktür.
	local weekMinutes, lastMultiplier = 0, 0
	for _, multiplier in Config.DAILY_REWARD_MULTIPLIERS do
		assert(multiplier >= lastMultiplier, "the streak never pays less on a later day")
		lastMultiplier = multiplier
		weekMinutes += multiplier * Config.DAILY_MINUTES
	end
	assert(
		Config.DAILY_MINUTES * lastMultiplier >= 10,
		"the last streak day is meaningful in the late game (>= 10 income minutes)"
	)
	assert(Config.DAILY_MINUTES * lastMultiplier <= 15, "the last streak day stays a bonus, not a main income source")
	assert(weekMinutes <= 0.03 * 24 * 60, "a full week of daily rewards stays under 3% of one day's income")
	local lateIncome = FarmMath.getReferenceIncome(rich)
	assert(
		math.abs(
			Rewards.dailyAmount(rich, length)
				- math.floor(math.max(lateIncome * 60 * Config.DAILY_MINUTES, Config.DAILY_MIN_REWARD) * lastMultiplier)
		) <= 1,
		"the daily reward scales with the reference income"
	)

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
	assert(Rewards.progress(player, achievement("home_10")) == 0, "no cows yet")
	for index = 1, 10 do
		table.insert(
			player.animals,
			{ uid = `x{index}`, animalId = "cow", zoneId = "starter", bornAt = 0, stage = "adult" }
		)
	end
	assert(Rewards.isComplete(player, achievement("home_10")), "ten cows complete the cow achievement")
	assert(Rewards.progress(player, achievement("animals_25")) == 10, "animals metric counts every animal")
	assert(Rewards.progress(player, achievement("first_island")) == 1, "only the home island is open at the start")
	player.unlockedIslands.poultry = true
	assert(Rewards.isComplete(player, achievement("first_island")), "a second island completes the island achievement")
	player.lifetimeEarned = 10000
	assert(Rewards.isComplete(player, achievement("earned_10k")), "lifetime earnings complete the money achievement")
	assert(Rewards.progress(save(), achievement("earned_10k")) == 0, "missing lifetimeEarned counts as zero")
	player.contracts = { window = 0, done = {}, completed = 5 }
	assert(Rewards.isComplete(player, achievement("orders_5")), "delivered orders complete the order achievement")

	local claimable = Rewards.claimableCount(player)
	assert(claimable >= 3, "several achievements are claimable")
	player.achievements.home_10 = true
	assert(Rewards.claimableCount(player) == claimable - 1, "claimed achievements are no longer claimable")
	for _, entry in Config.ACHIEVEMENTS do
		assert(entry.reward > 0 and entry.target > 0 and entry.id ~= "", "achievement config must be sane")
	end
	-- Ödül merdiveni tutarlı: aynı metrikte hedef büyüdükçe ödül büyür; başarımlar yalnız nakit öder (altın yalnız rebirth'te)
	do
		local ladders: { [string]: { any } } = {}
		for _, entry in Config.ACHIEVEMENTS do
			assert((entry :: any).gold == nil, `achievement {entry.id} must not pay gold`)
			ladders[entry.metric] = ladders[entry.metric] or {}
			table.insert(ladders[entry.metric], entry)
		end
		for metric, ladder in ladders do
			table.sort(ladder, function(a: any, b: any): boolean
				return a.target < b.target
			end)
			for index = 2, #ladder do
				assert(
					ladder[index].target > ladder[index - 1].target and ladder[index].reward > ladder[index - 1].reward,
					`{metric}: {ladder[index].id} must pay more than {ladder[index - 1].id}`
				)
			end
		end
		-- İlk dakikalar: ilk günlük ödülle (en az DAILY_MIN_REWARD) alınabilen küçük bir kazanım vardır
		local quick = achievement("home_3")
		local firstHerdCost = quick.target * Config.ANIMALS.cow.price * Config.ANIMAL_PRICE_GROWTH ^ (quick.target - 1)
		assert(
			firstHerdCost <= Config.DAILY_MIN_REWARD + Config.STARTING_CASH,
			"the first herd fits the first daily reward"
		)
		assert(
			achievement("earned_1k").target == 1000
				and achievement("earned_1k").reward < achievement("earned_10k").reward,
			"a quick earnings milestone exists below the first 10K"
		)
	end

	-- Altın öğretisi: yalnız hiç başarım almamış, altını olmayan, ilk turdaki hesaba bir kez; boyut rebirth ödülünün %5'i içinde
	do
		local gift = Rewards.FIRST_ACHIEVEMENT_GOLD
		assert(
			gift > 0 and gift <= Config.PROGRESSION.gold.rebirthBase * 0.05,
			"the gold gift stays within 5% of a rebirth"
		)
		local fresh = save()
		fresh.gold = 0
		assert(Rewards.firstAchievementGold(fresh) == gift, "a fresh account receives the gift")
		fresh.progression = { count = 0 }
		assert(Rewards.firstAchievementGold(fresh) == gift, "run 1 with zero rebirths receives the gift")
		fresh.achievements = { home_3 = true }
		assert(Rewards.firstAchievementGold(fresh) == 0, "a claimed achievement ends the gift")
		local reborn = save()
		reborn.gold = 0
		reborn.progression = { count = 1 }
		assert(Rewards.firstAchievementGold(reborn) == 0, "after a rebirth (claims reset) the gift never returns")
		local funded = save()
		funded.gold = 10
		assert(Rewards.firstAchievementGold(funded) == 0, "an account that already has gold needs no lesson")
		assert(Config.PROGRESSION.gold.maxBalance > gift, "the wallet cap leaves room for the gift")
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
		-- Yönetici testi: hedefi tamamlanmış sayar (kazanç ve yatırım hedeflerinde)
		local forced = save()
		forced.lifetimeEarned = 50
		Rewards.ensureSeasonal(forced, springNow)
		Rewards.forceCompleteSeasonal(forced, springNow)
		assert(Rewards.seasonalClaimable(forced, springNow), "forced completion works for earned goals")
		local forcedInvest = save()
		Rewards.ensureSeasonal(forcedInvest, season)
		Rewards.forceCompleteSeasonal(forcedInvest, season)
		assert(Rewards.seasonalClaimable(forcedInvest, season), "forced completion works for invest goals")
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

	-- Yeni başarım metrikleri
	local stats = save()
	stats.animals = {
		{ uid = "a", animalId = "cow", zoneId = "starter", bornAt = 0, stage = "adult" },
		{ uid = "b", animalId = "chicken", zoneId = "starter", bornAt = 0, stage = "adult" },
		{ uid = "c", animalId = "anchovy", zoneId = "starter", bornAt = 0, stage = "adult" },
		{ uid = "d", animalId = "seabass", zoneId = "starter", bornAt = 0, stage = "adult" },
	}
	stats.unlockedZones = { starter = true, pasture = true, poultry = true }
	stats.barnLevel = 3
	stats.expansions = { starter = 2, packed_milk = 1 }
	stats.goods = { milk = 30, egg = 25 }
	stats.inventory = { items = { farmer_hat = true, flat_cap = true }, equipped = {} }
	stats.purchased = { milk_factory = true, milk_center = true, egg_center = true, hatchery = true }
	local function progressOf(id: string): number
		return Rewards.progress(stats, achievement(id))
	end
	assert(progressOf("species_4") == 4, "distinct species are counted")
	assert(progressOf("fish_10") == 2, "both fish species count as fish")
	assert(progressOf("zones_4") == 3, "unlocked zones are counted")
	assert(progressOf("barn_3") == 3, "the barn level is the metric")
	assert(progressOf("expansions_5") == 3, "upgrade levels are summed")
	assert(progressOf("facilities_1") == 1, "cash factories are counted (the hatchery is neither cash nor goods)")
	assert(progressOf("centers_1") == 2, "goods centers are counted")
	assert(progressOf("goods_50") == 55, "stored goods are summed")
	assert(progressOf("items_1") == 2, "owned items are counted")
	-- Alınabilirler claimableCount'a girer
	stats.goods = { milk = 60 }
	assert(Rewards.isComplete(stats, achievement("goods_50")), "enough stored goods complete the goods achievement")

	-- Her başarım her temada ulaşılabilir olmalı (çiftlik yalnızca kendi adalarını alabilir)
	for index, theme in Config.THEMES do
		local farmId = tostring(index)
		local purchasable, capacity, homeCapacity = 0, 0, 0
		for _, upgrade in Config.UPGRADES do
			if Config.themeHasIsland(farmId, Config.getUpgradeIsland(upgrade)) then
				purchasable += 1
			end
		end
		for _, zone in Config.ZONES do
			if Config.themeHasIsland(farmId, zone.island) then
				-- Alan genişletmesiyle ulaşılabilecek en büyük kapasite
				local maxCapacity = FarmMath.getMaxZoneCapacity(zone.id)
				capacity += maxCapacity
				if Config.zoneAllows(zone, Config.getHomeAnimal(farmId), farmId) then
					homeCapacity += maxCapacity
				end
			end
		end
		-- Temaya göre üst sınırlar: bölge, tür, tesis ve ürün merkezi sayıları yalnızca çiftliğin kendi adalarıyla sınırlıdır
		local zoneCount, targetCount, facilityCount, centerCount = 0, 0, 0, 0
		local species: { [string]: boolean } = {}
		local speciesCount = 0
		for _, zone in Config.ZONES do
			if Config.themeHasIsland(farmId, zone.island) then
				zoneCount += 1
				targetCount += 1
				for animalId in Config.ANIMALS do
					if not species[animalId] and Config.zoneAllows(zone, animalId, farmId) then
						species[animalId] = true
						speciesCount += 1
					end
				end
			end
		end
		for _, recipe in Config.PRODUCTION_RECIPES do
			if Config.themeHasIsland(farmId, recipe.island) then
				targetCount += 1
				if recipe.output == "goods" then
					centerCount += 1
				elseif recipe.output == "cash" then
					facilityCount += 1
				end
			end
		end
		for _, entry in Config.ACHIEVEMENTS do
			local reachable = if entry.metric == "purchases"
				then purchasable
				elseif entry.metric == "animals" then capacity
				elseif entry.metric == "home" then homeCapacity
				elseif entry.metric == "islands" then #Config.getThemeIslands(farmId)
				elseif entry.metric == "zones" then zoneCount
				elseif entry.metric == "species" then speciesCount
				elseif entry.metric == "facilities" then facilityCount
				elseif entry.metric == "centers" then centerCount
				elseif entry.metric == "expansions" then targetCount * Config.BUILD_UPGRADES.maxLevel
				elseif entry.metric == "barn" then #Config.BARN_LEVELS
				elseif entry.metric == "items" then #Config.ITEM_ORDER
				else math.huge
			assert(
				entry.target <= reachable,
				`achievement {entry.id} is unreachable in theme {index} ({theme.id}): {entry.target} > {reachable}`
			)
		end
	end

	-- Referans gelir: etkin çiftlik değil, sahip olunan çiftlikler arasındaki en yüksek gelir (günlük/mevsim ödülü, sipariş tavanı)
	local function farmRecord(cows: number): any
		local animals = {}
		for index = 1, cows do
			table.insert(
				animals,
				{ uid = `ref-{index}`, animalId = "cow", zoneId = "starter", bornAt = 0, stage = "adult" }
			)
		end
		return {
			purchased = {},
			animals = animals,
			barnLevel = 1,
			unlockedIslands = {},
			unlockedZones = { starter = true },
			expansions = {},
			lineage = {},
		}
	end
	local small: any = save()
	small.animals = farmRecord(1).animals
	small.unlockedZones = { starter = true }
	small.activeMainFarmId = "1"
	small.mainFarms = { ["1"] = {}, ["2"] = farmRecord(10) }
	local alone: any = save()
	alone.animals = farmRecord(10).animals
	alone.unlockedZones = { starter = true }
	local activeIncome = FarmMath.computeIncomePerSecond(small)
	local richIncome = FarmMath.computeIncomePerSecond(alone)
	assert(richIncome > activeIncome, "the parked farm out-earns the active one in the fixture")
	assert(
		math.abs(FarmMath.getReferenceIncome(small) - richIncome) < 1e-9,
		"the reference income is the best income among owned farms, not the active farm's"
	)
	assert(
		math.abs(FarmMath.getParkedIncomeBest(small) - richIncome) < 1e-9,
		"the parked best is computed from full farm records"
	)
	local clientView: any = save()
	clientView.animals = small.animals
	clientView.unlockedZones = { starter = true }
	clientView.mainFarms =
		{ ["1"] = { barnLevel = 1 }, ["2"] = { barnLevel = 1, purchased = {}, unlockedIslands = {} } }
	assert(
		FarmMath.getReferenceIncome(clientView) == FarmMath.computeIncomePerSecond(clientView),
		"the client's light view cannot see parked animals: only the active farm without the payload"
	)
	clientView.parkedIncomeBest = richIncome
	assert(
		math.abs(FarmMath.getReferenceIncome(clientView) - richIncome) < 1e-9,
		"the server's parkedIncomeBest lets the client reach the same reference"
	)
	assert(
		Rewards.dailyAmount(small, 1) == Rewards.dailyAmount(clientView, 1)
			and Rewards.dailyAmount(small, 1)
				== math.floor(math.max(richIncome * Config.DAILY_MINUTES * 60, Config.DAILY_MIN_REWARD)),
		"the daily reward follows the reference income on server and client"
	)
	assert(
		Rewards.seasonalReward(small)
			== math.max(Config.SEASONAL_MIN_REWARD, math.floor(richIncome * Config.SEASONAL_REWARD_SECONDS)),
		"the seasonal reward follows the reference income"
	)

	print("PASS rewards: daily streak, wrap, reward scaling and achievement progress")
end
