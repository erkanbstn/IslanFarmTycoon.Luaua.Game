--!strict
-- Config iç tutarlılığı: tablolar birbirine doğru referans veriyor mu, döngü ya da eksik kayıt var mı (saf, gerçek Config).
return function(Config: any, FarmMath: any)
	-- Hayvanlar
	local inOrder: { [string]: boolean } = {}
	for _, animalId in Config.ANIMAL_ORDER do
		assert(Config.ANIMALS[animalId], `ANIMAL_ORDER lists unknown animal {animalId}`)
		assert(not inOrder[animalId], `ANIMAL_ORDER repeats {animalId}`)
		inOrder[animalId] = true
	end
	for animalId, animal in Config.ANIMALS do
		assert(inOrder[animalId], `animal {animalId} is missing from ANIMAL_ORDER`)
		assert(
			animal.id == animalId and animal.price > 0 and animal.baseIncomePerSecond > 0,
			`animal {animalId} is malformed`
		)
	end

	-- Bölgeler ve adalar
	local zoneOrder: { [string]: boolean } = {}
	for _, zoneId in Config.ZONE_ORDER do
		assert(Config.ZONES[zoneId], `ZONE_ORDER lists unknown zone {zoneId}`)
		zoneOrder[zoneId] = true
	end
	for zoneId, zone in Config.ZONES do
		assert(zoneOrder[zoneId], `zone {zoneId} is missing from ZONE_ORDER`)
		assert(Config.FARM_ISLANDS[zone.island], `zone {zoneId} belongs to unknown island {zone.island}`)
		assert(zone.capacity > 0, `zone {zoneId} needs capacity`)
		for _, animalId in zone.allowedAnimals do
			assert(Config.ANIMALS[animalId], `zone {zoneId} allows unknown animal {animalId}`)
		end
	end
	local islandOrder: { [string]: boolean } = {}
	for _, islandId in Config.FARM_ISLAND_ORDER do
		assert(Config.FARM_ISLANDS[islandId], `FARM_ISLAND_ORDER lists unknown island {islandId}`)
		islandOrder[islandId] = true
	end
	for islandId in Config.FARM_ISLANDS do
		assert(islandOrder[islandId], `island {islandId} is missing from FARM_ISLAND_ORDER`)
	end
	for index, stage in Config.ROADMAP_STAGES do
		assert(stage.island == nil or Config.FARM_ISLANDS[stage.island], `roadmap stage {index} has an unknown island`)
	end

	-- Yükseltmeler
	local seenIds: { [string]: boolean } = {}
	for _, upgrade in Config.UPGRADES do
		assert(not seenIds[upgrade.id], `duplicate upgrade id {upgrade.id}`)
		seenIds[upgrade.id] = true
		assert(
			Config.ROADMAP_STAGES[upgrade.stage],
			`upgrade {upgrade.id} has stage {upgrade.stage}, which does not exist`
		)
		assert(
			upgrade.cost > 0 and upgrade.icon ~= "" and upgrade.displayName ~= "",
			`upgrade {upgrade.id} is malformed`
		)
		for _, requiredId in upgrade.requires do
			assert(Config.getUpgrade(requiredId), `upgrade {upgrade.id} requires unknown {requiredId}`)
			assert(requiredId ~= upgrade.id, `upgrade {upgrade.id} requires itself`)
		end
		for _, boostTable in { upgrade.incomeBoost, upgrade.growthBoost } do
			for key in boostTable or {} do
				assert(key == "home" or Config.ANIMALS[key], `upgrade {upgrade.id} boosts unknown animal {key}`)
			end
		end
		if upgrade.zoneId then
			assert(Config.ZONES[upgrade.zoneId], `upgrade {upgrade.id} opens unknown zone {upgrade.zoneId}`)
		end
		if upgrade.islandId then
			assert(
				Config.FARM_ISLANDS[upgrade.islandId],
				`upgrade {upgrade.id} opens unknown island {upgrade.islandId}`
			)
		end
	end
	-- Ön koşul döngüsü yok: her yükseltme, önceki alınabilirlerle sonunda açılır (yakınsama)
	local owned: { [string]: boolean } = {}
	local changed = true
	while changed do
		changed = false
		for _, upgrade in Config.UPGRADES do
			if not owned[upgrade.id] then
				local ready = true
				for _, requiredId in upgrade.requires do
					ready = ready and owned[requiredId] == true
				end
				if ready then
					owned[upgrade.id] = true
					changed = true
				end
			end
		end
	end
	for _, upgrade in Config.UPGRADES do
		assert(owned[upgrade.id], `upgrade {upgrade.id} sits in a prerequisite cycle`)
	end

	-- Mevsim, hava, hedefler
	for _, season in Config.SEASONS do
		assert(Config.SEASONAL_GOALS[season.id], `season {season.id} has no seasonal goal`)
		for weatherId in season.weather do
			assert(Config.WEATHER[weatherId], `season {season.id} uses unknown weather {weatherId}`)
		end
		for animalId in season.incomeModifiers do
			assert(Config.ANIMALS[animalId], `season {season.id} modifies unknown animal {animalId}`)
		end
	end
	for seasonId, goal in Config.SEASONAL_GOALS do
		local found = false
		for _, season in Config.SEASONS do
			found = found or season.id == seasonId
		end
		assert(found, `seasonal goal {seasonId} matches no season`)
		assert(goal.metric == "earned" or goal.metric == "invest", `seasonal goal {seasonId} has an unknown metric`)
	end

	-- Üretim tarifleri ve eklentiler: hayvan ve ada referansları
	for recipeId, recipe in Config.PRODUCTION_RECIPES do
		assert(Config.ANIMALS[recipe.animalId], `recipe {recipeId} uses unknown animal`)
		assert(Config.FARM_ISLANDS[recipe.island], `recipe {recipeId} uses unknown island`)
	end
	for extensionId, extension in Config.EXTENSIONS do
		assert(Config.ANIMALS[extension.animalId], `extension {extensionId} uses unknown animal`)
		assert(Config.ZONES[extension.sourceZoneId], `extension {extensionId} uses unknown source zone`)
	end

	-- Ses ve ürün kayıtları: kullanılan her tür tanımlı, hayvan sesleri bilinen hayvanlara ait
	for _, soundName in { "click", "coin", "success", "error", "build" } do
		assert(Config.SOUNDS[soundName], `sound {soundName} is missing`)
	end
	for animalId in Config.ANIMAL_SOUNDS do
		assert(Config.ANIMALS[animalId], `animal sound for unknown animal {animalId}`)
	end

	-- Bir çiftlik ilk dakikadan itibaren hayvan alabilmeli: ana ada hayvanı başlangıç bölgesinde yaşar
	for index in Config.THEMES do
		local farm: any = {
			cash = 0,
			stored = 0,
			purchased = {},
			animals = {},
			barnLevel = 1,
			unlockedIslands = {},
			unlockedZones = {},
			ordersCompleted = 0,
			production = {},
			activeMainFarmId = tostring(index),
		}
		FarmMath.applyDerived(farm)
		local homeAnimal = Config.getHomeAnimal(tostring(index))
		assert(FarmMath.getFreeSlots(farm, homeAnimal) > 0, `theme {index} cannot place its home animal at the start`)
	end
	print("PASS config: cross-references, prerequisite graph, seasonal goals and start state")
end
