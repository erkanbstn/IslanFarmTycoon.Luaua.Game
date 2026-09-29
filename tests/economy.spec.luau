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
	print("PASS economy: growth boundaries, integrated offline/elapsed income, cap, growth upgrade, fish pricing")
end
