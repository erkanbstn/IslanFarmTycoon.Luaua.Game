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
	assert(FarmMath.getStage(start, start + 44, 1) == "calf", "44s: calf boundary")
	assert(FarmMath.getStage(start, start + 45, 1) == "young", "45s: young boundary")
	assert(FarmMath.getStage(start, start + 134, 1) == "young", "134s: still young")
	assert(FarmMath.getStage(start, start + 135, 1) == "adult", "135s: adult boundary")
	-- Evre alanı yetişkin olsa da geçmiş gelir doğumdan hesaplanır.
	near(FarmMath.computeIncomeOverInterval(save, start, start + 135, true), 130.5)
	near(FarmMath.computeOfflineEarnings(save, start, start + 135), 65)
	near(FarmMath.computeIncomeOverInterval(save, start - 20, start, true), 0)
	near(FarmMath.computeOfflineEarnings(save, start + 1, start), 0)
	near(FarmMath.computeOfflineEarnings(save, 0 / 0, start), 0)
	near(FarmMath.computeOfflineEarnings(save, start, math.huge), 0)
	near(FarmMath.computeIncomeOverInterval(save, -math.huge, start, true), 0)
	local previousWeather = Environment.getIncomeMultiplier
	Environment.getIncomeMultiplier = function(): number
		return 0.2
	end
	local badWeather = FarmMath.computeOfflineEarnings(save, start, start + 135)
	Environment.getIncomeMultiplier = function(): number
		return 2
	end
	near(FarmMath.computeOfflineEarnings(save, start, start + 135), badWeather)
	Environment.getIncomeMultiplier = previousWeather

	-- Scheduler gecikmesi: parçalara bölmek veya tek aralık ödemek aynı sonucu verir.
	local regular = 0
	for elapsed = 1, 180 do
		regular += FarmMath.computeIncomeOverInterval(save, start + elapsed - 1, start + elapsed, true)
	end
	near(FarmMath.computeIncomeOverInterval(save, start, start + 180, true), regular)
	-- Çevrimdışı kazanç kasaya gider: dolu depo onu engellemez, üst sınır depo x OFFLINE_STORAGE_MULTIPLIER.
	save.stored = FarmMath.getStorageCap(save)
	near(FarmMath.computeOfflineEarnings(save, start, start + 135), 65)
	local offlineCap = FarmMath.getOfflineCap(save)
	near(offlineCap, FarmMath.getStorageCap(save) * Config.OFFLINE_STORAGE_MULTIPLIER)
	near(FarmMath.computeOfflineEarnings(save, start, start + Config.OFFLINE_MAX_HOURS * 3600), offlineCap)
	save.stored = 0

	-- Üretim ödülü: gerekenden fazla her yetişkin bonus verir, üst sınırda durur.
	local dairy = Config.PRODUCTION_RECIPES.dairy
	local farm = saveAt(0)
	farm.animals = {}
	for index = 1, dairy.requiredAdults do
		table.insert(
			farm.animals,
			{ uid = `d{index}`, animalId = "cow", zoneId = "starter", bornAt = 0, stage = "adult" }
		)
	end
	local baseReward, baseBonus = FarmMath.getProductionReward(farm, dairy, start)
	assert(baseReward == dairy.reward and baseBonus == 0, "required adults only: base reward")
	table.insert(farm.animals, { uid = "d-extra", animalId = "cow", zoneId = "starter", bornAt = 0, stage = "adult" })
	table.insert(farm.animals, { uid = "d-calf", animalId = "cow", zoneId = "starter", bornAt = start, stage = "calf" })
	local oneExtra = FarmMath.getProductionReward(farm, dairy, start)
	assert(
		oneExtra == math.floor(dairy.reward * (1 + Config.PRODUCTION_BONUS_PER_ADULT)),
		"one extra adult adds one bonus step; calves do not count"
	)
	for index = 1, Config.PRODUCTION_MAX_BONUS_ADULTS + 5 do
		table.insert(
			farm.animals,
			{ uid = `d-many{index}`, animalId = "cow", zoneId = "starter", bornAt = 0, stage = "adult" }
		)
	end
	local _, cappedBonus = FarmMath.getProductionReward(farm, dairy, start)
	near(cappedBonus, Config.PRODUCTION_MAX_BONUS_ADULTS * Config.PRODUCTION_BONUS_PER_ADULT)

	-- Hız yükseltmesi 44 saniyelik eski ilerlemeyi 88 saniyeye dönüştürmemeli.
	save = saveAt(start)
	local oldSpeeds = { cow = FarmMath.getGrowthSpeed(save, "cow") }
	save.purchased.silo = true
	FarmMath.applyDerived(save)
	FarmMath.preserveGrowthProgress(save, oldSpeeds, start + 44)
	near((start + 44 - save.animals[1].bornAt) * 2, 44)
	assert(save.animals[1].stage == "calf", "upgrade must preserve existing growth")
	assert(FarmMath.getStage(save.animals[1].bornAt, start + 44.5, 2) == "young", "new half-second grows at new speed")
	save.animals[1].bornAt = 0
	FarmMath.preserveGrowthProgress(save, oldSpeeds, start + 44)
	near(save.animals[1].bornAt, 0)

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
		table.find(FarmMath.themeIslands(view), "pig") and not table.find(FarmMath.themeIslands(view), "goat"),
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
	print("PASS economy: growth boundaries, integrated offline/elapsed income, cap, growth upgrade, fish pricing")
end
