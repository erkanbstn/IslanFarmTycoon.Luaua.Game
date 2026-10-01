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

	-- Fabrika x ada x hayvan uyumu (değişmez; yeni hayvan/tema eklenince de koşar, sabit liste yok).
	-- (i) Çiftliğin temasında bulunan her fabrika yalnızca kendi adasında ve o adada yaşayan hayvanla kurulur.
	local function islandAnimals(islandId: string, farmId: string): { [string]: boolean }
		local set: { [string]: boolean } = {}
		for _, zone in Config.ZONES do
			if zone.island == islandId then
				for _, animalId in Config.getZoneAnimals(zone, farmId) do
					set[animalId] = true
				end
			end
		end
		return set
	end
	local recipeByUpgrade: { [string]: any } = {}
	for _, recipe in Config.PRODUCTION_RECIPES do
		assert(not recipeByUpgrade[recipe.upgradeId], `upgrade {recipe.upgradeId} hosts two recipes`)
		recipeByUpgrade[recipe.upgradeId] = recipe
	end
	local recipeLives: { [string]: boolean } = {}
	for themeIndex, theme in Config.THEMES do
		local farmId = tostring(themeIndex)
		local homeGoods, homeCash = 0, 0
		for _, recipe in Config.PRODUCTION_RECIPES do
			local upgrade = Config.getUpgrade(recipe.upgradeId)
			assert(upgrade, `recipe {recipe.id} has no upgrade`)
			if not Config.upgradeInTheme(upgrade, farmId) then
				continue
			end
			recipeLives[recipe.id] = true
			assert(
				Config.getUpgradeIsland(upgrade) == recipe.island,
				`recipe {recipe.id}: upgrade island differs from recipe island`
			)
			local allowed = islandAnimals(recipe.island, farmId)
			for _, animalId in recipe.animalIds do
				assert(
					allowed[animalId],
					`theme {theme.id}: recipe {recipe.id} uses {animalId}, which does not live on {recipe.island}`
				)
			end
			-- (iv) ana adada ana hayvanın fabrikaları (balık kafesi ayrı); başka kara hayvanının fabrikası kurulamaz
			if recipe.island == "home" and recipe.animalId ~= "anchovy" and recipe.animalId ~= "seabass" then
				assert(
					recipe.animalId == theme.homeAnimal,
					`theme {theme.id}: home factory {recipe.id} serves {recipe.animalId}, not the home animal {theme.homeAnimal}`
				)
				if recipe.output == "goods" then
					homeGoods += 1
				elseif FarmMath.petKindFor(recipe) == "cash" then
					homeCash += 1
				end
			end
		end
		assert(homeGoods >= 1 and homeCash >= 1, `theme {theme.id}: the home animal needs a goods and a cash factory`)
		-- Başka temanın ana ada fabrikası bu çiftlikte alınamaz (ör. ördek ana adada süt fabrikası)
		for _, other in Config.THEMES do
			if other.homeAnimal ~= theme.homeAnimal then
				for _, recipe in Config.PRODUCTION_RECIPES do
					local upgrade = Config.getUpgrade(recipe.upgradeId) :: any
					if upgrade.homeAnimal == other.homeAnimal then
						assert(not Config.upgradeInTheme(upgrade, farmId), `{recipe.id} leaks into theme {theme.id}`)
					end
				end
			end
		end
	end
	for recipeId in Config.PRODUCTION_RECIPES do
		assert(recipeLives[recipeId], `recipe {recipeId} is available in no theme`)
	end
	-- (ii) her hayvan türünün en az bir ürün (goods) ve bir para (cash) fabrikası var
	for _, animalId in Config.ANIMAL_ORDER do
		local goods, cash = 0, 0
		for _, recipe in Config.PRODUCTION_RECIPES do
			if table.find(recipe.animalIds, animalId) then
				if recipe.output == "goods" then
					goods += 1
				elseif FarmMath.petKindFor(recipe) == "cash" then
					cash += 1
				end
			end
		end
		assert(goods >= 1 and cash >= 1, `animal {animalId} needs a goods factory and a cash factory`)
	end
	-- (iii) her ada türünün (ana ada dahil) bölgesi, ürün merkezi ve para fabrikası var
	for _, islandId in Config.FARM_ISLAND_ORDER do
		local zones, goods, cash = 0, 0, 0
		for _, zone in Config.ZONES do
			zones += if zone.island == islandId then 1 else 0
		end
		for _, recipe in Config.PRODUCTION_RECIPES do
			if recipe.island == islandId then
				if recipe.output == "goods" then
					goods += 1
				elseif FarmMath.petKindFor(recipe) == "cash" then
					cash += 1
				end
			end
		end
		assert(zones >= 1 and goods >= 1 and cash >= 1, `island {islandId} needs a zone, a goods and a cash factory`)
	end

	-- Ürünle açılış (goodsCost): her temada ve kademede çözülebilir, ahır kapasitesine sığar, karşılanamaz gereksinim (deadlock) yok,
	-- ürünü satıp açılış almak kâr bırakmaz (ürün yalnızca paranın üstüne gelen küçük bir ek maliyettir).
	do
		local settings = Config.DIFFICULTY.goods
		local function dependsOn(upgradeId: string, ancestorId: string, seen: { [string]: boolean }?): boolean
			local visited = seen or {}
			if visited[upgradeId] then
				return false
			end
			visited[upgradeId] = true
			local upgrade = Config.getUpgrade(upgradeId)
			for _, requiredId in if upgrade then upgrade.requires else {} do
				if requiredId == ancestorId or dependsOn(requiredId, ancestorId, visited) then
					return true
				end
			end
			return false
		end
		local withGoods = 0
		for _, upgrade in Config.UPGRADES do
			local spec = upgrade.goodsCost
			if not spec then
				continue
			end
			withGoods += 1
			assert(spec.step >= 1 and spec.step <= #settings.stepBase, `{upgrade.id}: goodsCost step`)
			local totalShare = 0
			for source, share in spec.shares do
				assert(share > 0, `{upgrade.id}: positive share for {source}`)
				totalShare += share
			end
			assert(totalShare > 0 and totalShare <= 0.25, `{upgrade.id}: goods are a small addition to the money price`)
			assert(
				upgrade.kind ~= "level" or upgrade.id:find("_lv1$") ~= nil,
				`{upgrade.id}: only the first level of a chain asks goods`
			)
			local isCenter = false
			for _, recipe in Config.PRODUCTION_RECIPES do
				isCenter = isCenter or (recipe.upgradeId == upgrade.id and recipe.output == "goods")
			end
			assert(not isCenter, `{upgrade.id}: goods centers must not ask goods (production could never start)`)
			for themeIndex, theme in Config.THEMES do
				local farmId = tostring(themeIndex)
				if not Config.upgradeInTheme(upgrade, farmId) then
					continue
				end
				for source in spec.shares do
					local goodsId = Config.resolveGoodsSource(farmId, source, Config.getUpgradeIsland(upgrade))
					assert(goodsId, `theme {theme.id}: {upgrade.id} source {source} resolves to no goods`)
					-- Üretilebilir olmalı: temada kurulabilen, bu yükseltmenin önünde alınabilen bir ürün merkezi
					local producible = false
					for _, recipe in Config.PRODUCTION_RECIPES do
						local producer = Config.getUpgrade(recipe.upgradeId) :: any
						if
							recipe.output == "goods"
							and recipe.goodsId == goodsId
							and Config.upgradeInTheme(producer, farmId)
							and producer.id ~= upgrade.id
							and not dependsOn(producer.id, upgrade.id)
							and producer.goodsCost == nil
						then
							producible = true
						end
					end
					assert(
						producible,
						`theme {theme.id}: {upgrade.id} needs {goodsId}, which nothing can produce before it`
					)
				end
				-- Her kademede miktar tam sayı, en az 1 (Çiftlik 1'in erken adımı hariç) ve ahır kapasitesine sığar
				local barn = Config.getBarnLevelConfig(Config.getMinBarnLevel(upgrade.id)) or Config.BARN_LEVELS[1]
				do
					local tier = themeIndex -- kademe = tema numarası
					local cost = FarmMath.getGoodsCost({ farmId = farmId, activeMainFarmId = farmId }, upgrade)
					local free = settings.tutorialFree and tier == 1 and spec.step <= 1
					assert(
						(next(cost) == nil) == free,
						`{upgrade.id} theme {theme.id} tier {tier}: free only in the tutorial step`
					)
					local worth = 0
					for goodsId, amount in cost do
						assert(amount >= 1 and amount % 1 == 0, `{upgrade.id}: whole positive amount`)
						assert(
							amount <= math.floor(barn.goodsCap * settings.capShare),
							`{upgrade.id} theme {theme.id} tier {tier}: {goodsId} x{amount} exceeds the barn capacity at level {barn.level}`
						)
						worth += amount * Config.GOODS[goodsId].value
					end
					-- Ürünü satıp açılış almak kâr bırakmaz: gereken ürünün satış değeri paranın yanında küçük kalır
					assert(
						worth * Config.GOODS_SELL.rate
							< FarmMath.getUpgradeCost(
								{ farmId = farmId, activeMainFarmId = farmId, purchased = {} },
								upgrade
							),
						`{upgrade.id} theme {theme.id} tier {tier}: goods sell worth stays below the money price`
					)
				end
			end
		end
		assert(withGoods >= 8, "several unlocks ask goods")
		-- Çiftlik 1'de ürün yükü paranın yanında küçük kalır (referans tempo korunur): tüm açılışların ürün değeri para fiyatlarının %15'inden az
		for themeIndex = 1, #Config.THEMES do
			local reference = { farmId = tostring(themeIndex), activeMainFarmId = tostring(themeIndex), purchased = {} }
			local moneyTotal, goodsTotal = 0, 0
			for _, upgrade in Config.UPGRADES do
				if upgrade.goodsCost and Config.upgradeInTheme(upgrade, reference.farmId) then
					moneyTotal += FarmMath.getUpgradeCost(reference, upgrade)
					for goodsId, amount in FarmMath.getGoodsCost(reference, upgrade) do
						goodsTotal += amount * Config.GOODS[goodsId].value
					end
				end
			end
			assert(
				goodsTotal < moneyTotal * 0.15,
				`farm 1 style tier in theme {themeIndex}: goods stay a small extra cost`
			)
		end
		assert(
			Config.GOODS_BARTER.rate <= Config.GOODS_SELL.rate,
			"bartering never beats selling the goods (no sell-then-buy arbitrage)"
		)
	end
	for extensionId, extension in Config.EXTENSIONS do
		assert(Config.ANIMALS[extension.animalId], `extension {extensionId} uses unknown animal`)
		assert(Config.ZONES[extension.sourceZoneId], `extension {extensionId} uses unknown source zone`)
		-- Kalış süresi 120 -> 360 sn yapılırken toplam bonus (incomeBonus x süre = 120) korunur: sıklık düşer, kazanç aynı kalır
		assert(
			math.abs(extension.incomeBonus * extension.stayDuration - 120) < 0.001,
			`extension {extensionId} total bonus drifted from 120`
		)
		assert(
			extension.stayDuration == Config.EXTENSION_STAY_SECONDS,
			`extension {extensionId} stay differs from the constant`
		)
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
			production = {},
			activeMainFarmId = tostring(index),
		}
		FarmMath.applyDerived(farm)
		local homeAnimal = Config.getHomeAnimal(tostring(index))
		assert(FarmMath.getFreeSlots(farm, homeAnimal) > 0, `theme {index} cannot place its home animal at the start`)
	end
	-- Simgeler çiftliğin temasına uyar: ana ada ağılı kendi hayvanının simgesini taşır (İnek/Tavuk/Ördek Ağılı).
	for index in Config.THEMES do
		local farmId = tostring(index)
		local animal = Config.ANIMALS[Config.getHomeAnimal(farmId)]
		assert(Config.getHomeAnimalIcon(farmId) == animal.icon, `theme {index} home icon follows its animal`)
		assert(
			Config.getZoneIcon(Config.ZONES.starter, farmId) == animal.icon,
			`theme {index} pen icon follows its animal`
		)
		assert(
			Config.getBuildTargetIcon("starter", farmId) == animal.icon,
			`theme {index} pen upgrade icon follows its animal`
		)
		assert(
			Config.getZoneName(Config.ZONES.starter, farmId) == `{animal.displayName} Ağılı`,
			`theme {index} pen name follows its animal`
		)
	end
	for zoneId, zone in Config.ZONES do
		if zoneId ~= "starter" then
			assert(Config.getZoneIcon(zone, "3") == zone.icon, `zone {zoneId} keeps its own icon`)
		end
	end
	for recipeId, recipe in Config.PRODUCTION_RECIPES do
		assert(Config.ZONES[recipeId] == nil, `recipe id {recipeId} must not collide with a zone id`)
		assert(Config.getBuildTargetIcon(recipeId, "1") == recipe.icon, `facility {recipeId} keeps its own icon`)
		assert(Config.BUILD_TARGETS[recipeId].isZone == false, `{recipeId} is registered as a facility`)
	end
	for zoneId in Config.ZONES do
		assert(Config.PRODUCTION_RECIPES[zoneId] == nil, `zone id {zoneId} must not collide with a recipe id`)
	end
	-- Para tesisleri: ücretsiz başlar, 2+ parti seçeneği sunar; çok hayvan isteyen seçenek hayvan başına daha çok öder
	local cashRecipes = 0
	for recipeId, recipe in Config.PRODUCTION_RECIPES do
		if recipe.output ~= "cash" then
			assert(recipe.options == nil, `{recipeId}: only cash recipes have options`)
			continue
		end
		cashRecipes += 1
		local options = assert(recipe.options, `{recipeId}: cash recipes have batch options`)
		assert(recipe.cost == 0, `{recipeId}: cash recipes are free to start`)
		assert(#options >= 2, `{recipeId}: at least two batch options`)
		local first = options[1]
		assert(
			recipe.requiredAdults == first.requiredAdults and recipe.duration == first.duration,
			`{recipeId}: top-level fields mirror the first option`
		)
		local seen: { [string]: boolean } = {}
		local previous: Config.ProductionOptionConfig? = nil
		for _, option in options do
			assert(not seen[option.id], `{recipeId}: option ids are unique`)
			seen[option.id] = true
			assert(
				option.requiredAdults >= 1 and option.duration > 0 and option.reward > 0,
				`{recipeId}/{option.id} values`
			)
			assert(option.returnMultiplier > 1, `{recipeId}/{option.id}: pays more than the animals would have earned`)
			assert(
				option.returnMultiplier <= Config.PRODUCTION_MAX_RETURN,
				`{recipeId}/{option.id}: batch multiplier stays within PRODUCTION_MAX_RETURN`
			)
			if previous then
				assert(
					option.requiredAdults > previous.requiredAdults,
					`{recipeId}: options ask for more animals in order`
				)
				assert(
					option.reward / option.requiredAdults > previous.reward / previous.requiredAdults,
					`{recipeId}: more animals pay more per animal`
				)
				assert(
					option.returnMultiplier > previous.returnMultiplier,
					`{recipeId}: the bigger batch has the better floor`
				)
			end
			previous = option
		end
	end
	assert(cashRecipes >= 7, "the cash facilities all have options")
	-- Ahır deposu: hızlı satış ve takas oranları sipariş ödülünü ve birbirini aşmaz (ürünü satıp hayvan almaktan kârlı kaçak yok)
	local sellRate, barterRate = Config.GOODS_SELL.rate, Config.GOODS_BARTER.rate
	assert(sellRate > 0 and sellRate < 1, "bulk selling pays only part of the goods' value")
	assert(barterRate > 0 and barterRate <= sellRate, "bartering never beats selling the goods and buying the animal")
	local cheapestTier = math.huge
	for _, tier in Config.GOODS_CONTRACTS.tiers do
		cheapestTier = math.min(cheapestTier, tier.rewardFactor)
		assert(
			tier.rewardFactor >= 1 and tier.units >= 1 and tier.capShare > 0 and tier.lines >= 1,
			`{tier.id}: tier shape`
		)
	end
	assert(sellRate * cheapestTier < 1, "an order always pays more than bulk selling the same goods")
	assert(Config.GOODS_CONTRACTS.maxLineUnits >= 20, "wholesale orders can reach 20+ units")
	assert(
		Config.GOODS_CONTRACTS.floorExponent > 0 and Config.GOODS_CONTRACTS.floorExponent <= 1,
		"the order income floor grows with size but never faster than linearly"
	)
	assert(
		Config.GOODS_CONTRACTS.floorWeight == 3 * Config.GOODS_CONTRACTS.unitRefValue,
		"the reference order is 3 units"
	)
	print("PASS config: cross-references, prerequisite graph, seasonal goals and start state")
end
