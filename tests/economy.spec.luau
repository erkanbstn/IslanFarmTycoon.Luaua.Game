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
	save.stored = FarmMath.getStorageCap(save) - 7
	near(FarmMath.computeOfflineEarnings(save, start, start + 135), 7)
	save.stored = FarmMath.getStorageCap(save)
	near(FarmMath.computeOfflineEarnings(save, start, start + 135), 0)

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
	print("PASS economy: growth boundaries, integrated offline/elapsed income, cap, growth upgrade, fish pricing")
end
