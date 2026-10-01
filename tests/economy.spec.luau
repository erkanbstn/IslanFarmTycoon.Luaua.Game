--!strict
-- Gerçek FarmMath/Config ile çalıştırılır; test runner Roblox servislerini sağlar.
return function(FarmMath: any, Config: any, Environment: any)
	local function near(actual: number, expected: number)
		assert(math.abs(actual - expected) < 0.000001, `Beklenen {expected}, sonuç {actual}`)
	end
	local function saveAt(bornAt: number): any
		local save = {
			cash = 100000,
			stored = 0,
			purchased = {},
			animals = { { uid = "cow-1", animalId = "cow", zoneId = "starter", bornAt = bornAt, stage = "adult" } },
			barnLevel = 1,
			unlockedIslands = {},
			unlockedZones = {},
		}
		FarmMath.applyDerived(save)
		return save
	end
	local start = 1000000
	local save = saveAt(start)
	local calfSeconds, youngSeconds = Config.GROWTH_SECONDS.calf, Config.GROWTH_SECONDS.young
	local growSeconds = calfSeconds + youngSeconds
	assert(FarmMath.getStage(start, start + calfSeconds - 1, 1) == "calf", "calf boundary")
	assert(FarmMath.getStage(start, start + calfSeconds, 1) == "young", "young boundary")
	assert(FarmMath.getStage(start, start + growSeconds - 1, 1) == "young", "still young")
	assert(FarmMath.getStage(start, start + growSeconds, 1) == "adult", "adult boundary")
	-- Evre alanı yetişkin olsa da geçmiş gelir doğumdan hesaplanır (inek saniyede 2).
	local growIncome = 2
		* (calfSeconds * Config.STAGE_INCOME_MULTIPLIER.calf + youngSeconds * Config.STAGE_INCOME_MULTIPLIER.young)
	near(FarmMath.computeIncomeOverInterval(save, start, start + growSeconds, true), growIncome)
	near(
		FarmMath.computeOfflineEarnings(save, start, start + growSeconds),
		math.floor(growIncome * Config.OFFLINE_EARNING_RATE)
	)
	near(FarmMath.computeIncomeOverInterval(save, start - 20, start, true), 0)
	near(FarmMath.computeOfflineEarnings(save, start + 1, start), 0)
	near(FarmMath.computeOfflineEarnings(save, 0 / 0, start), 0)
	near(FarmMath.computeOfflineEarnings(save, start, math.huge), 0)
	near(FarmMath.computeIncomeOverInterval(save, -math.huge, start, true), 0)
	local previousWeather = Environment.getIncomeMultiplier
	Environment.getIncomeMultiplier = function(): number
		return 0.2
	end
	local badWeather = FarmMath.computeOfflineEarnings(save, start, start + growSeconds)
	Environment.getIncomeMultiplier = function(): number
		return 2
	end
	near(FarmMath.computeOfflineEarnings(save, start, start + growSeconds), badWeather)
	Environment.getIncomeMultiplier = previousWeather

	-- Scheduler gecikmesi: parçalara bölmek veya tek aralık ödemek aynı sonucu verir.
	local regular = 0
	for elapsed = 1, 180 do
		regular += FarmMath.computeIncomeOverInterval(save, start + elapsed - 1, start + elapsed, true)
	end
	near(FarmMath.computeIncomeOverInterval(save, start, start + 180, true), regular)
	-- Çevrimdışı kazanç kasaya gider ve depoya bağlı değildir: dolu depo onu engellemez; sınır "saat x gelir"dir.
	save.stored = FarmMath.getStorageCap(save)
	near(
		FarmMath.computeOfflineEarnings(save, start, start + growSeconds),
		math.floor(growIncome * Config.OFFLINE_EARNING_RATE)
	)
	save.stored = 0
	local crowded = saveAt(start)
	for index = 2, 40 do
		local copy = table.clone(crowded.animals[1])
		copy.uid = `crowd-{index}`
		table.insert(crowded.animals, copy)
	end
	-- Pasif Gelir yokken: gelirin OFFLINE_EARNING_RATE'i, en çok OFFLINE_MAX_HOURS saat; fazla uzaklık ek kazanç vermez.
	local baseRate, baseHours = FarmMath.getOfflineTerms(crowded)
	assert(baseRate == Config.OFFLINE_EARNING_RATE and baseHours == Config.OFFLINE_MAX_HOURS, "base offline terms")
	local atLimit = FarmMath.computeOfflineEarnings(crowded, start, start + baseHours * 3600)
	near(
		atLimit,
		math.floor(FarmMath.computeIncomeOverInterval(crowded, start, start + baseHours * 3600, true) * baseRate)
	)
	near(FarmMath.computeOfflineEarnings(crowded, start, start + 100 * 3600), atLimit)
	assert(atLimit > 0, "an away player without the upgrade still earns")
	-- Pasif Gelir: oran ve süre artar; sınır yine saat x gelirdir (depo büyüklüğü fark etmez).
	crowded.purchased.offline_income_lv1 = true
	local upgradedRate, upgradedHours = FarmMath.getOfflineTerms(crowded)
	assert(
		upgradedRate == Config.OFFLINE_UPGRADED_EARNING_RATE and upgradedHours == Config.OFFLINE_UPGRADED_MAX_HOURS,
		"upgraded offline terms"
	)
	assert(upgradedRate > baseRate and upgradedHours > baseHours, "the upgrade improves both rate and duration")
	local upgradedLimit = FarmMath.computeOfflineEarnings(crowded, start, start + upgradedHours * 3600)
	near(
		upgradedLimit,
		math.floor(
			FarmMath.computeIncomeOverInterval(crowded, start, start + upgradedHours * 3600, true) * upgradedRate
		)
	)
	near(FarmMath.computeOfflineEarnings(crowded, start, start + 100 * 3600), upgradedLimit)
	assert(upgradedLimit > atLimit * 2, "the upgraded limit is far above the base limit")
	crowded.purchased.offline_income_lv1 = nil

	-- Üretim ödülü (seçeneksiz tarif): gerekenden fazla her yetişkin bonus verir, üst sınırda durur.
	local dairy = Config.PRODUCTION_RECIPES.hatchery
	local farm = saveAt(0)
	farm.animals = {}
	for index = 1, dairy.requiredAdults do
		table.insert(
			farm.animals,
			{ uid = `d{index}`, animalId = "chicken", zoneId = "starter", bornAt = 0, stage = "adult" }
		)
	end
	local baseReward, baseBonus = FarmMath.getProductionReward(farm, dairy, start)
	assert(baseReward == dairy.reward and baseBonus == 0, "required adults only: base reward")
	table.insert(
		farm.animals,
		{ uid = "d-extra", animalId = "chicken", zoneId = "starter", bornAt = 0, stage = "adult" }
	)
	table.insert(
		farm.animals,
		{ uid = "d-calf", animalId = "chicken", zoneId = "starter", bornAt = start, stage = "calf" }
	)
	local oneExtra = FarmMath.getProductionReward(farm, dairy, start)
	assert(
		oneExtra == math.floor(dairy.reward * (1 + Config.PRODUCTION_BONUS_PER_ADULT)),
		"one extra adult adds one bonus step; calves do not count"
	)
	for index = 1, Config.PRODUCTION_MAX_BONUS_ADULTS + 5 do
		table.insert(
			farm.animals,
			{ uid = `d-many{index}`, animalId = "chicken", zoneId = "starter", bornAt = 0, stage = "adult" }
		)
	end
	local _, cappedBonus = FarmMath.getProductionReward(farm, dairy, start)
	near(cappedBonus, Config.PRODUCTION_MAX_BONUS_ADULTS * Config.PRODUCTION_BONUS_PER_ADULT)

	-- Hız yükseltmesi mevcut ilerlemeyi ikiye katlamamalı (yavru evresinin son saniyesinde yükseltme).
	save = saveAt(start)
	local oldSpeeds = FarmMath.snapshotGrowthSpeeds(save)
	save.purchased.silo = true
	FarmMath.applyDerived(save)
	FarmMath.preserveGrowthProgress(save, oldSpeeds, start + calfSeconds - 1)
	near((start + calfSeconds - 1 - save.animals[1].bornAt) * 2, calfSeconds - 1)
	assert(save.animals[1].stage == "calf", "upgrade must preserve existing growth")
	assert(
		FarmMath.getStage(save.animals[1].bornAt, start + calfSeconds - 0.5, 2) == "young",
		"new half-second grows at new speed"
	)
	save.animals[1].bornAt = 0
	FarmMath.preserveGrowthProgress(save, oldSpeeds, start + calfSeconds - 1)
	near(save.animals[1].bornAt, 0)

	-- Zaten yetişkin hayvanın yetişkinlik başlangıcı hız değişiminde kaymaz.
	save = saveAt(start)
	oldSpeeds = FarmMath.snapshotGrowthSpeeds(save)
	save.purchased.silo = true
	FarmMath.applyDerived(save)
	FarmMath.preserveGrowthProgress(save, oldSpeeds, start + growSeconds + 1000)
	near(save.animals[1].bornAt + growSeconds / 2, start + growSeconds)
	assert(save.animals[1].stage == "adult", "an adult stays adult after a speed change")

	-- Satış: fiyatın yarısı, en genç hayvan, son hayvan satılmaz, görevdeki (eklenti/tesis) hayvan satılmaz.
	save = saveAt(start)
	save.animals = {
		{ uid = "a", animalId = "cow", zoneId = "starter", bornAt = 0, stage = "adult" },
		{ uid = "b", animalId = "cow", zoneId = "starter", bornAt = start + 10, stage = "calf" },
		{
			uid = "c",
			animalId = "cow",
			zoneId = "starter",
			bornAt = start + 20,
			stage = "calf",
			extensionId = "x",
			task = { kind = "extension", id = "x", startedAt = start, endsAt = start + 1000 },
		},
	}
	near(
		FarmMath.getSellPrice(save, "cow"),
		math.floor(Config.ANIMALS.cow.price * Config.ANIMAL_PRICE_GROWTH ^ 2 * 0.5)
	)
	local sellable = FarmMath.findSellableAnimal(save, "cow", start + 30)
	assert(sellable and sellable.uid == "b", "the youngest animal without an active task is sold first")
	assert(FarmMath.findSellableAnimal(save, "chicken") == nil, "a missing species cannot be sold")
	save.animals = { save.animals[1] }
	assert(FarmMath.findSellableAnimal(save, "cow") == nil, "the last animal of a farm cannot be sold")
	assert(
		FarmMath.getSellPrice(save, "cow") < FarmMath.getAnimalPrice(save, "cow"),
		"selling must always lose money versus buying"
	)

	-- İade taban fiyata bağlı; hamsi sayısını artırmak değişim ücretini düşürmez.
	save = saveAt(start)
	save.animals = {}
	local replacementPrice = FarmMath.getFishReplacementPrice(save)
	for index = 1, 10 do
		table.insert(
			save.animals,
			{ uid = `fish-{index}`, animalId = "anchovy", zoneId = "fish", bornAt = 0, stage = "adult" }
		)
	end
	near(FarmMath.getFishReplacementPrice(save), replacementPrice)
	assert(
		replacementPrice >= Config.ANIMALS.seabass.price - Config.ANIMALS.anchovy.price,
		"refund must not exceed base cost"
	)
	-- Gerçek bölge ID'sini config'ten seç; kilitliyken değişim önerilmez.
	local fishZone = nil
	for zoneId, zone in Config.ZONES do
		if table.find(zone.allowedAnimals, "anchovy") and table.find(zone.allowedAnimals, "seabass") then
			fishZone = zoneId
		end
	end
	assert(fishZone, "config must have a shared fish zone")
	for _, animal in save.animals do
		animal.zoneId = fishZone
	end
	assert(FarmMath.findReplaceableFish(save) == nil, "locked zone fish cannot be replaced")
	save.unlockedZones[fishZone] = true
	assert(FarmMath.findZoneForAnimal(save, "seabass") == nil, "all 10 fish slots are full")
	assert(FarmMath.findReplaceableFish(save).uid == "fish-1", "full zone permits replacement")
	save.animals[1].animalId = "seabass"
	assert(FarmMath.getFishReplacementPrice(save) > replacementPrice, "next seabass price must grow")
	assert(#save.animals == 10, "replacement preserves total capacity")
	-- Büyük sayılar kısaltılır; küçükler tam okunur.
	local money = {
		{ 0, "$0" },
		{ 999, "$999" },
		{ 9999, "$9,999" },
		{ 10000, "$10K" },
		{ 12400, "$12.4K" },
		{ 99950, "$100K" },
		{ 250000, "$250K" },
		{ 999400, "$999K" },
		{ 999949, "$1M" },
		{ 3100000, "$3.1M" },
		{ 1e9, "$1B" },
		{ 2.5e12, "$2.5T" },
		{ 1e15, "$1Qa" },
		{ -5000, "-$5,000" },
		{ -12400, "-$12.4K" },
		{ 12.9, "$12" },
	}
	for _, case in money do
		assert(
			FarmMath.formatMoney(case[1]) == case[2],
			`formatMoney({case[1]}) beklenen {case[2]}, sonuç {FarmMath.formatMoney(case[1])}`
		)
	end
	assert(FarmMath.formatMoney(0 / 0) == "$0", "NaN must not crash formatting")
	-- Depo yığını seviyesi: boş, kademeler ve tam dolu.
	assert(
		FarmMath.getStorageLevel(0, 250) == 0 and FarmMath.getStorageLevel(0.5, 250) == 0,
		"empty storage has no pile"
	)
	assert(FarmMath.getStorageLevel(1, 250) == 1, "any stored money shows the smallest pile")
	assert(FarmMath.getStorageLevel(125, 250) == 3, "half full shows a mid pile")
	assert(FarmMath.getStorageLevel(249, 250) == 4, "almost full is level 4")
	assert(
		FarmMath.getStorageLevel(250, 250) == 5 and FarmMath.getStorageLevel(999, 250) == 5,
		"full shows the top pile"
	)
	assert(FarmMath.getStorageLevel(5, 0) == 0, "zero capacity is safe")
	-- Toplu alım: fiyat ardışık tek tek alımlarla aynı; boş yer sayısı bölge kapasitesinden gelir.
	local bulk = saveAt(start)
	local cow = Config.ANIMALS.cow
	local single = FarmMath.getAnimalPrice(bulk, "cow")
	assert(FarmMath.getBulkPrice(bulk, "cow", 1) == single, "x1 bulk price equals the single price")
	local expectedThree = 0
	for index = 0, 2 do
		expectedThree += math.floor(cow.price * Config.ANIMAL_PRICE_GROWTH ^ (1 + index))
	end
	assert(FarmMath.getBulkPrice(bulk, "cow", 3) == expectedThree, "x3 bulk price sums growing prices")
	assert(FarmMath.getBulkPrice(bulk, "cow", 2) > FarmMath.getBulkPrice(bulk, "cow", 1), "more animals cost more")
	assert(FarmMath.getBulkPrice(bulk, "cow", 0) == math.huge, "zero animals are invalid")
	assert(FarmMath.getBulkPrice(bulk, "unknown_animal", 2) == math.huge, "unknown animal is invalid")
	local freeBefore = FarmMath.getFreeSlots(bulk, "cow")
	assert(freeBefore >= 1, "starter zone has free cow slots")
	table.insert(bulk.animals, { uid = "cow-2", animalId = "cow", zoneId = "starter", bornAt = start, stage = "adult" })
	assert(FarmMath.getFreeSlots(bulk, "cow") == freeBefore - 1, "an added animal removes one free slot")
	assert(FarmMath.getFreeSlots(bulk, "goat") == 0, "locked zones give no free slots")
	local multipliers = Config.BULK_MULTIPLIERS
	assert(multipliers[1] == 1 and table.find(multipliers, 2) and table.find(multipliers, 3), "x1/x2/x3 are offered")
	-- Ada temaları: her çiftlik numarası kendi 3 küçük adasına sahip, temalar birbirinden farklı
	assert(#Config.THEMES == Config.MAP_PLOT_COUNT, "one theme per physical island")
	local seenThemes: { [string]: boolean } = {}
	for index, theme in Config.THEMES do
		assert(#theme.satellites == 3, `theme {index} needs exactly 3 small islands`)
		local key = table.concat(theme.satellites, ",")
		assert(not seenThemes[key], `theme {index} repeats another theme`)
		seenThemes[key] = true
		local lastBarn = 0
		for _, islandId in theme.satellites do
			local island = Config.FARM_ISLANDS[islandId]
			assert(island and island.upgradeId, `island {islandId} must be purchasable`)
			local upgrade = Config.getUpgrade(island.upgradeId)
			assert(
				upgrade and upgrade.kind == "island" and upgrade.islandId == islandId,
				"island upgrade must open its island"
			)
			-- Bağımsızlık: ada yalnızca ahır seviyesine bağlıdır, yoksa tema sırası bozulur
			local barnLevel = 0
			for _, required in upgrade.requires do
				local level = tonumber(string.match(required, "^barn_(%d)$"))
				assert(level, `island {islandId} must only require barn levels, got {required}`)
				barnLevel = math.max(barnLevel, level)
			end
			assert(barnLevel >= lastBarn, `theme {index} lists islands from early to late`)
			lastBarn = barnLevel
			local hasZone = false
			for _, zone in Config.ZONES do
				if zone.island == islandId then
					hasZone = true
					for _, animalId in zone.allowedAnimals do
						assert(Config.ANIMALS[animalId], `zone animal {animalId} must exist`)
					end
				end
			end
			assert(hasZone, `island {islandId} needs a zone`)
		end
	end
	assert(
		Config.getTheme("1").satellites[1] == "poultry" and Config.getTheme(nil).id == Config.THEMES[1].id,
		"farm 1 is the classic theme"
	)
	assert(
		Config.getTheme("99").id == Config.THEMES[1].id and Config.getTheme("x").id == Config.THEMES[1].id,
		"unknown farm ids use the first theme"
	)
	assert(
		Config.themeHasIsland("2", "dairy") and not Config.themeHasIsland("2", "poultry"),
		"themes limit the available islands"
	)
	assert(Config.themeHasIsland("1", "home"), "the main island is always present")
	local themed = saveAt(start)
	themed.activeMainFarmId = "2"
	local owned, total = FarmMath.countIslands(themed)
	assert(owned == 1 and total == 4, "every farm has the main island plus three small islands")
	local nextIsland = FarmMath.getNextIsland(themed)
	assert(nextIsland and nextIsland.id == "dairy", "the cheapest island of the farm's theme comes next")
	themed.activeMainFarmId = "1"
	assert(FarmMath.getNextIsland(themed).id == "poultry", "farm 1 starts with the poultry island")
	local view = saveAt(start)
	view.farmId = "3"
	assert(
		table.find(FarmMath.themeIslands(view), "dairy") and not table.find(FarmMath.themeIslands(view), "poultry"),
		"inactive farm views use their own farm id"
	)
	for _, upgrade in Config.UPGRADES do
		if upgrade.kind == "boost" or upgrade.kind == "island" then
			assert(
				Config.FARM_ISLANDS[Config.getUpgradeIsland(upgrade)],
				`upgrade {upgrade.id} must map to a real island`
			)
		end
	end
	-- Üretim tarifleri ve eklentiler: her biri gerçek bir ada, bölge, hayvan ve yükseltmeye bağlı olmalı
	for id, recipe in Config.PRODUCTION_RECIPES do
		assert(table.find(Config.PRODUCTION_ORDER, id), `recipe {id} must be listed in PRODUCTION_ORDER`)
		local upgrade = Config.getUpgrade(recipe.upgradeId)
		assert(upgrade and upgrade.kind == "boost", `recipe {id} needs a boost upgrade`)
		assert(Config.getUpgradeIsland(upgrade) == recipe.island, `recipe {id} island must match its building`)
		assert(Config.ANIMALS[recipe.animalId], `recipe {id} animal must exist`)
		assert(
			recipe.reward > recipe.cost and recipe.duration > 0 and recipe.requiredAdults >= 1,
			`recipe {id} must be profitable`
		)
	end
	for _, id in Config.PRODUCTION_ORDER do
		assert(Config.PRODUCTION_RECIPES[id], `PRODUCTION_ORDER entry {id} must exist`)
	end
	for id, extension in Config.EXTENSIONS do
		local zone = Config.ZONES[extension.sourceZoneId]
		assert(zone and zone.island == extension.island, `extension {id} source zone must be on its island`)
		assert(
			table.find(zone.allowedAnimals, extension.animalId),
			`extension {id} animal must live in its source zone`
		)
		assert(extension.capacity < zone.capacity, `extension {id} must not exceed its source zone`)
		local upgrade = Config.getExtensionUpgrade(id)
		assert(
			upgrade and Config.getUpgradeIsland(upgrade) == extension.island,
			`extension {id} needs an upgrade on its island`
		)
		assert(
			table.find(upgrade.requires, Config.FARM_ISLANDS[extension.island].upgradeId),
			`extension {id} requires its island`
		)
	end
	-- Ana ada hayvanı: her tema kendi hayvanıyla başlar; o hayvanın ayrıca küçük adası olmaz, inek bir yerde bulunur
	local homeAnimals: { [string]: boolean } = {}
	for index, theme in Config.THEMES do
		local farmId = tostring(index)
		assert(Config.ANIMALS[theme.homeAnimal], `theme {index} home animal must exist`)
		homeAnimals[theme.homeAnimal] = true
		local hasCow = theme.homeAnimal == "cow"
		for _, islandId in theme.satellites do
			for _, zone in Config.ZONES do
				if zone.island == islandId then
					assert(
						not table.find(zone.allowedAnimals, theme.homeAnimal),
						`theme {index} repeats its home animal on {islandId}`
					)
					hasCow = hasCow or table.find(zone.allowedAnimals, "cow") ~= nil
				end
			end
		end
		assert(hasCow, `theme {index} must offer cows on the home or a small island`)
		local themeFarm = saveAt(start)
		themeFarm.activeMainFarmId = farmId
		assert(
			FarmMath.findZoneForAnimal(themeFarm, theme.homeAnimal) == "starter",
			`theme {index} home animal lives in the starter zone`
		)
		local other = if theme.homeAnimal == "cow" then "chicken" else "cow"
		assert(
			not FarmMath.findZoneForAnimal(themeFarm, other)
				or Config.ZONES[FarmMath.findZoneForAnimal(themeFarm, other) :: string].island ~= "home",
			`theme {index} home zones reject other animals`
		)
	end
	assert(homeAnimals.cow and homeAnimals.chicken and homeAnimals.duck, "home animals differ between farms")
	-- Irk geliştirme: seviye, maliyet eğrisi, yetişkin koşulu ve gelir etkisi
	local lineageFarm = saveAt(start)
	assert(FarmMath.getLineageLevel(lineageFarm, "cow") == 0, "lineage starts at level 0")
	local lineageBase = FarmMath.getAnimalMultiplier(lineageFarm, "cow", true)
	local lineageStatus, _, lineageCost = FarmMath.getLineageStatus(lineageFarm, "cow")
	assert(
		lineageStatus == "available" and lineageCost == FarmMath.getLineageCost("cow", 0),
		"an adult cow unlocks lineage"
	)
	local previousCost = 0
	for level = 0, Config.LINEAGE.maxLevel - 1 do
		local cost = FarmMath.getLineageCost("cow", level)
		assert(cost > previousCost and cost < math.huge, "lineage costs must grow with each level")
		previousCost = cost
	end
	assert(FarmMath.getLineageCost("cow", Config.LINEAGE.maxLevel) == math.huge, "no level past the maximum")
	-- Denge değişmezi (sim: "Irk geri dönüş" <= 2 sa): havuz ne çok ucuz (erken biter) ne çok pahalı (geri dönüş uzar) olsun
	for animalId, animalConfig in Config.ANIMALS do
		local pool = 0
		for level = 0, Config.LINEAGE.maxLevel - 1 do
			pool += FarmMath.getLineageCost(animalId, level)
		end
		local lastCost = FarmMath.getLineageCost(animalId, Config.LINEAGE.maxLevel - 1)
		assert(pool >= animalConfig.price * 500, `lineage pool for {animalId} collapsed (too cheap)`)
		assert(lastCost <= animalConfig.price * 250, `lineage last level for {animalId} too expensive (payback > 2h)`)
	end
	assert(FarmMath.getLineageCost("ghost", 0) == math.huge, "unknown species cannot be upgraded")
	lineageFarm.lineage = { cow = 2 }
	local lineageRatio = FarmMath.getAnimalMultiplier(lineageFarm, "cow", true) / lineageBase
	assert(
		math.abs(lineageRatio - (1 + 2 * Config.LINEAGE.incomePerLevel)) < 1e-9,
		"lineage levels add income linearly"
	)
	assert(
		FarmMath.getAnimalMultiplier(lineageFarm, "chicken", true)
			== FarmMath.getAnimalMultiplier(saveAt(start), "chicken", true),
		"lineage only affects its own species"
	)
	-- Irk ve eşya geliri toplanan bonusa eklenmez, ayrı çarpandır: gelir = taban x (1 + diğer) x (1 + ırk) x (1 + eşya)
	local stackFarm = saveAt(start)
	stackFarm.purchased["milk_machine"] = true
	stackFarm.lineage = { cow = 5 }
	stackFarm.inventory = { items = { income_charm_3 = true }, equipped = { charm = "income_charm_3" } }
	local stackPlain = saveAt(start)
	stackPlain.purchased["milk_machine"] = true
	local stackExpected = (1 + 5 * Config.LINEAGE.incomePerLevel)
		* (1 + FarmMath.getEquippedBonus(stackFarm, "incomeBonus"))
	assert(
		math.abs(
			FarmMath.getAnimalMultiplier(stackFarm, "cow", true) / FarmMath.getAnimalMultiplier(stackPlain, "cow", true)
				- stackExpected
		) < 1e-9,
		"lineage and item income multiply instead of adding to other bonuses"
	)
	lineageFarm.lineage = { cow = Config.LINEAGE.maxLevel + 50 }
	assert(FarmMath.getLineageLevel(lineageFarm, "cow") == Config.LINEAGE.maxLevel, "levels are clamped")
	assert(FarmMath.getLineageStatus(lineageFarm, "cow") == "max", "maximum level is reported")
	lineageFarm.lineage = {}
	lineageFarm.animals = { { uid = "calf", animalId = "cow", zoneId = "starter", bornAt = start, stage = "calf" } }
	assert(FarmMath.getLineageStatus(lineageFarm, "cow") == "locked", "lineage needs an adult animal of the species")
	-- Alan genişletme: kapasite, maliyet eğrisi, dolu-bölge şartı ve boş yer hesabı
	local expandFarm = saveAt(start)
	local starterZone = Config.ZONES.starter
	assert(
		FarmMath.getZoneCapacity(expandFarm, "starter") == starterZone.capacity,
		"no expansion keeps the base capacity"
	)
	local expandStatus, _, expandCost = FarmMath.getExpansionStatus(expandFarm, "starter")
	assert(
		expandStatus == "locked" and expandCost == FarmMath.getExpansionCost(expandFarm, "starter"),
		"a non-full zone cannot be expanded"
	)
	while FarmMath.countInZone(expandFarm, "starter") < FarmMath.getZoneCapacity(expandFarm, "starter") do
		table.insert(
			expandFarm.animals,
			{ uid = `fill-{#expandFarm.animals}`, animalId = "cow", zoneId = "starter", bornAt = 0, stage = "adult" }
		)
	end
	assert(FarmMath.getExpansionStatus(expandFarm, "starter") == "available", "a full unlocked zone can be expanded")
	local expandFreeBefore = FarmMath.getFreeSlots(expandFarm, "cow")
	expandFarm.expansions = { starter = 1 }
	assert(
		FarmMath.getZoneCapacity(expandFarm, "starter") == starterZone.capacity + FarmMath.getExpansionStep(starterZone),
		"a capacity level adds one step"
	)
	assert(
		FarmMath.getFreeSlots(expandFarm, "cow") == expandFreeBefore + FarmMath.getExpansionStep(starterZone),
		"expansion opens free slots"
	)
	local previousExpansionCost = 0
	for level = 0, Config.BUILD_UPGRADES.maxLevel - 1 do
		expandFarm.expansions = { starter = level }
		local cost = FarmMath.getExpansionCost(expandFarm, "starter")
		assert(cost > previousExpansionCost and cost < math.huge, "expansion costs grow with each level")
		previousExpansionCost = cost
	end
	expandFarm.expansions = { starter = Config.BUILD_UPGRADES.maxLevel + 9 }
	assert(FarmMath.getExpansionLevel(expandFarm, "starter") == Config.BUILD_UPGRADES.maxLevel, "levels are clamped")
	assert(FarmMath.getExpansionStatus(expandFarm, "starter") == "max", "maximum expansion is reported")
	assert(
		FarmMath.getZoneCapacity(expandFarm, "ghost") == 0
			and FarmMath.getExpansionCost(expandFarm, "ghost") == math.huge,
		"unknown zones are inert"
	)
	expandFarm.unlockedZones.pasture = false
	assert(FarmMath.getExpansionStatus(expandFarm, "pasture") == "locked", "a locked zone cannot be expanded")
	-- Çok etkili geliştirme: her seviye işlevine uygun fayda verir ve sayılar birikir
	local effectFarm = saveAt(start)
	local function cowIncome(): number
		return FarmMath.getAnimalIncome(
			effectFarm,
			"cow",
			{ uid = "x", animalId = "cow", zoneId = "starter", bornAt = 0, stage = "adult" }
		)
	end
	local incomeBase = cowIncome()
	local speedBase = FarmMath.getGrowthSpeed(effectFarm, "cow", "starter")
	effectFarm.expansions = { starter = 2 }
	assert(
		FarmMath.getGrowthSpeed(effectFarm, "cow", "starter") > speedBase * 1.05,
		"growth-speed levels must speed animals up in that zone"
	)
	assert(
		FarmMath.getGrowthSpeed(effectFarm, "cow", "meadow") == speedBase or Config.ZONES.meadow == nil,
		"zone growth bonuses must not leak into other zones"
	)
	effectFarm.expansions = { starter = 3 }
	assert(cowIncome() > incomeBase, "income levels must raise animal income")
	-- Tesis: süre kısalır, başlatma maliyeti düşer, ödül artar; hiçbiri sıfıra ya da negatife inmez
	local facilityFarm = saveAt(start)
	local cheese = Config.PRODUCTION_RECIPES.cheese
	local durationBase = FarmMath.getFacilityDuration(facilityFarm, cheese)
	local cheeseGoods = Config.PRODUCTION_RECIPES.cheese_goods
	local costBase = FarmMath.getFacilityCost(facilityFarm, cheeseGoods)
	assert(FarmMath.getFacilityCost(facilityFarm, cheese) == 0, "cash facilities charge nothing to start")
	local rewardBase = FarmMath.getProductionReward(facilityFarm, cheese, 0)
	facilityFarm.expansions = { cheese = Config.BUILD_UPGRADES.maxLevel, cheese_goods = Config.BUILD_UPGRADES.maxLevel }
	assert(FarmMath.getFacilityDuration(facilityFarm, cheese) < durationBase, "facility levels shorten production")
	assert(FarmMath.getFacilityCost(facilityFarm, cheeseGoods) < costBase, "facility levels cut the start cost")
	assert(FarmMath.getFacilityCost(facilityFarm, cheese) == 0, "a free facility stays free")
	assert(FarmMath.getProductionReward(facilityFarm, cheese, 0) > rewardBase, "facility levels raise the reward")
	assert(FarmMath.getFacilityCost(facilityFarm, cheeseGoods) >= 1, "a paid start cost stays positive")
	-- Bir tesis geliştirmesi tesis kurulmadan alınamaz
	local emptyFarm = saveAt(start)
	emptyFarm.purchased[cheese.upgradeId] = nil
	assert(FarmMath.getExpansionStatus(emptyFarm, "cheese") == "locked", "an unbuilt facility cannot be upgraded")
	-- Her bölge ve tesis, her temada sonlu ve artan maliyetle geliştirilebilir; boş fayda demeti yok
	for farmId in Config.THEMES do
		local costFarm = saveAt(start)
		costFarm.farmId = farmId
		for zoneId, zone in Config.ZONES do
			if Config.themeHasIsland(farmId, zone.island) then
				local previous = 0
				for level = 0, Config.BUILD_UPGRADES.maxLevel - 1 do
					costFarm.expansions = { [zoneId] = level }
					local cost = FarmMath.getExpansionCost(costFarm, zoneId)
					assert(
						cost > previous and cost < math.huge,
						`zone {zoneId} cost must be finite and growing ({farmId})`
					)
					previous = cost
				end
			end
		end
	end
	for name, profile in Config.BUILD_UPGRADES.profiles do
		for level, bundle in profile do
			assert(next(bundle) ~= nil, `{name} level {level} must give a benefit`)
		end
	end
	-- Her profilin seviye sayısı maxLevel ile aynı; her hedef bir profile bağlı
	for name, profile in Config.BUILD_UPGRADES.profiles do
		assert(#profile == Config.BUILD_UPGRADES.maxLevel, `{name} profile must have maxLevel levels`)
	end
	for zoneId, zone in Config.ZONES do
		assert(Config.BUILD_UPGRADES.profiles[zone.upgradeProfile or "barn"], `zone {zoneId} has a profile`)
		assert(FarmMath.getMaxZoneCapacity(zoneId) > zone.capacity, `zone {zoneId} must be able to grow`)
	end
	for recipeId, recipe in Config.PRODUCTION_RECIPES do
		assert(Config.BUILD_UPGRADES.profiles[recipe.upgradeProfile or "factory"], `recipe {recipeId} has a profile`)
	end
	-- Her tema erken (Ahır 2), orta (Ahır 3) ve geç (Ahır 4) birer ada türü içerir: yeni ada arası boşluk kalmaz
	for index, theme in Config.THEMES do
		local needed: { [number]: boolean } = {}
		for _, islandId in theme.satellites do
			local upgrade = assert(Config.getUpgrade(Config.FARM_ISLANDS[islandId].upgradeId), "island upgrade exists")
			local barn = 1
			for _, requiredId in upgrade.requires do
				local barnLevel = tonumber(string.match(requiredId, "^barn_(%d+)$"))
				if barnLevel then
					barn = barnLevel
				end
			end
			needed[barn] = true
		end
		assert(needed[2] and needed[3] and needed[4], `theme {index} needs one island each for barn 2, 3 and 4`)
	end
	-- Her tema kendine özgü bir işaret yapısı kullanır (HomeBuildings.landmark türleri)
	local landmarkKinds = { daisy = true, tulip = true, sunflower = true, rose = true, pine = true, cherry = true }
	local seenLandmarks: { [string]: boolean } = {}
	for index, theme in Config.THEMES do
		assert(landmarkKinds[theme.landmark], `theme {index} needs a known landmark`)
		assert(not seenLandmarks[theme.landmark], `theme {index} repeats another theme's landmark`)
		seenLandmarks[theme.landmark] = true
	end
	-- Temada olmayan adanın yükseltmesi hiçbir zaman "available" olmaz (HUD hedefi ve sipariş kilidi buna dayanır)
	local offTheme = saveAt(start)
	offTheme.activeMainFarmId = "2"
	offTheme.purchased.barn_2 = true
	offTheme.purchased.barn_3 = true
	assert(
		FarmMath.getUpgradeStatus(offTheme, "island_horse") == "locked",
		"an island outside the theme cannot be offered"
	)
	assert(
		FarmMath.getUpgradeStatus(offTheme, "island_sheep") ~= "locked"
			or FarmMath.getUpgradeStatus(offTheme, "barn_4") == "available",
		"in-theme islands stay normal"
	)
	assert(FarmMath.isUpgradeInTheme(offTheme, Config.getUpgrade("island_sheep")), "sheep belongs to farm 2's theme")
	-- Ulaşılabilirlik: her temada, alınabilir her yükseltmenin ön koşul zinciri de aynı temada olmalı (yoksa asla açılmaz)
	for index in Config.THEMES do
		local farmId = tostring(index)
		local function inTheme(id: string): boolean
			local upgrade = Config.getUpgrade(id)
			return upgrade ~= nil and Config.themeHasIsland(farmId, Config.getUpgradeIsland(upgrade))
		end
		for _, upgrade in Config.UPGRADES do
			if inTheme(upgrade.id) then
				for _, requiredId in upgrade.requires do
					assert(
						Config.getUpgrade(requiredId) ~= nil and inTheme(requiredId),
						`theme {index}: {upgrade.id} requires {requiredId}, which this farm can never buy`
					)
				end
			end
		end
		-- Simülasyon: temadaki her şeyi ön koşul sırasıyla satın alabiliyor muyuz?
		local probe = saveAt(start)
		probe.activeMainFarmId = farmId
		local progressed = true
		while progressed do
			progressed = false
			for _, upgrade in Config.UPGRADES do
				if FarmMath.getUpgradeStatus(probe, upgrade.id) == "available" then
					probe.purchased[upgrade.id] = true
					FarmMath.applyDerived(probe)
					progressed = true
				end
			end
		end
		for _, upgrade in Config.UPGRADES do
			if inTheme(upgrade.id) then
				assert(probe.purchased[upgrade.id], `theme {index}: {upgrade.id} can never become available`)
			else
				assert(not probe.purchased[upgrade.id], `theme {index}: off-theme {upgrade.id} must stay unavailable`)
			end
		end
	end
	-- Ada özellikleri ve eşya etkileri: hayvandan bağımsız genel faydalar (Core.getBonus = eşya + yükseltme)
	local perks = saveAt(start)
	perks.animals = {
		{ uid = "p1", animalId = "cow", zoneId = "starter", bornAt = 0, stage = "adult" },
		{ uid = "p2", animalId = "cow", zoneId = "starter", bornAt = 0, stage = "adult" },
	}
	perks.purchased = { milk_factory = true, milk_center = true }
	FarmMath.applyDerived(perks)
	local milkRecipe = Config.PRODUCTION_RECIPES.milk_goods
	local baseDuration = FarmMath.getFacilityDuration(perks, milkRecipe)
	local baseSell = FarmMath.getSellPrice(perks, "cow")
	local baseExpand = FarmMath.getExpansionCost(perks, "starter")
	local baseOffline = FarmMath.getOfflineTerms(perks)
	perks.purchased.island_poultry = true
	assert(FarmMath.getFacilityDuration(perks, milkRecipe) < baseDuration, "the poultry island speeds production up")
	perks.purchased.island_duck = true
	assert(FarmMath.getSellPrice(perks, "cow") > baseSell, "the duck island raises sale prices")
	perks.purchased.island_pig = true
	assert(FarmMath.getExpansionCost(perks, "starter") < baseExpand, "the pig island cuts upgrade costs")
	perks.purchased.island_goat = true
	assert(FarmMath.getOfflineTerms(perks) > baseOffline, "the goat island raises offline earnings")
	-- Takılı eşya aynı anahtarlara eklenir
	perks.inventory = { items = { diamond_hammer = true }, equipped = { tool = "diamond_hammer" } }
	assert(
		FarmMath.getBonus(perks, "expansionDiscount") > FarmMath.getUpgradeBonus(perks, "expansionDiscount"),
		"items add to island perks"
	)
	assert(FarmMath.getBonus(perks, "sellBonus") > 0.15, "the diamond hammer adds sell bonus on top of the island")
	-- Çiftlik numarası (alım sırası) fiyat çarpanı: tier 1 = x1, sonrası 1 + FARM_COST_STEP x (tier-1)
	do
		local first, second = saveAt(start), saveAt(start)
		second.tier = 2
		local upgrade = Config.getUpgrade("barn_2") or Config.UPGRADES[1]
		local mult = 1 + Config.FARM_COST_STEP
		assert(FarmMath.getFarmCostMultiplier(first) == 1, "farms without tier cost x1")
		assert(
			FarmMath.getUpgradeCost(second, upgrade) == FarmMath.getUpgradeCost(first, upgrade) * mult,
			"tier 2 upgrade"
		)
		-- Hayvan fiyatları tam sayıya yuvarlandığı için çarpan en çok 1 yuvarlama payıyla tutar
		local function nearMultiple(actual: number, base: number)
			assert(math.abs(actual - base * mult) <= mult, `Beklenen ~{base * mult}, sonuç {actual}`)
		end
		nearMultiple(FarmMath.getAnimalPrice(second, "cow"), FarmMath.getAnimalPrice(first, "cow"))
		nearMultiple(FarmMath.getSellPrice(second, "cow"), FarmMath.getSellPrice(first, "cow"))
		assert(
			FarmMath.getExpansionCost(second, "starter") > FarmMath.getExpansionCost(first, "starter"),
			"tier 2 expansion costs more"
		)
		second.tier = 3
		assert(FarmMath.getFarmCostMultiplier(second) == 1 + 2 * Config.FARM_COST_STEP, "multiplier grows per farm")
	end
	-- Gelir dağılımı: toplayıcılı çiftlik her şeyi kasaya yatırır; toplayıcısız park edilmiş çiftlik PARKED_FARM_PAY_RATE kadar
	do
		local farm = saveAt(start)
		farm.stored = 40
		local cash, stored = FarmMath.settleFarmIncome(farm, 100, true)
		near(cash, 100 * Config.PARKED_FARM_PAY_RATE)
		near(stored, 40)
		cash, stored = FarmMath.settleFarmIncome(farm, 100, false)
		near(cash, 0)
		near(stored, math.min(140, FarmMath.getStorageCap(farm)))
		farm.purchased.auto_collector = true
		cash, stored = FarmMath.settleFarmIncome(farm, 100, true)
		near(cash, 140)
		near(stored, 0)
	end
	print("PASS economy: growth boundaries, integrated offline/elapsed income, cap, growth upgrade, fish pricing")
end
