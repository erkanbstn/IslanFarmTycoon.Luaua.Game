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
					local free = tier == 1 and spec.step <= settings.tutorialSteps
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
		-- Çiftlik 1'de ürün yükü paranın yanında küçük kalır (referans tempo korunur): tüm açılışların ürün değeri para fiyatlarının %25'inden az (en az 1 birim kuralı, değerli üründe oranı yükseltir)
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
				goodsTotal < moneyTotal * 0.25,
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
			tier.rewardFactor >= 1 and tier.rewardFactor <= 2 and tier.units >= 1 and tier.lines >= 1,
			`{tier.id}: tier shape`
		)
	end
	assert(sellRate * cheapestTier < 1, "an order always pays more than bulk selling the same goods")
	-- Sipariş sayıları küçük kalır (okunabilirlik); ödül ürün değerine bağlıdır (gelir tabanı yoktur)
	local limits = Config.ECONOMY_LIMITS
	assert(
		Config.GOODS_CONTRACTS.maxLineUnits <= limits.maxLineUnits and Config.GOODS_CONTRACTS.unitRefValue > 0,
		"order lines stay within the readable unit limit"
	)
	assert(
		(Config.GOODS_CONTRACTS :: any).incomeSeconds == nil and (Config.GOODS_CONTRACTS :: any).floorWeight == nil,
		"order rewards no longer follow the player's income"
	)
	assert(
		Config.PRODUCTION_MAX_BATCH_UNITS <= limits.maxBatchUnits and Config.PRODUCTION_YIELD_MAX_MULT >= 1,
		"production batches stay small"
	)
	-- Çiftlik çeşitliliği (docs/ADA_TASARIMI.md): 6 çiftlik x (1 ana + 3 küçük ada) x tek hayvan = 24 benzersiz hayvan; Süt Adası yok
	do
		local seenAnimals: { [string]: number } = {}
		for index, theme in Config.THEMES do
			local farmId = tostring(index)
			local themeAnimals = { theme.homeAnimal }
			assert(#theme.satellites == 3, `theme {index} has exactly 3 small islands`)
			for _, islandId in theme.satellites do
				local animalId = Config.getIslandAnimal(farmId, islandId)
				assert(animalId and Config.ANIMALS[animalId], `island {islandId} must name its single animal`)
				table.insert(themeAnimals, animalId)
				-- Adadaki bölgelerde yalnızca o hayvan yaşar
				for _, zone in Config.ZONES do
					if zone.island == islandId then
						assert(
							#zone.allowedAnimals == 1 and zone.allowedAnimals[1] == animalId,
							`zone {zone.id} must host only {animalId}`
						)
					end
				end
			end
			assert(#themeAnimals == 4, `theme {index} has 4 animals`)
			for _, animalId in themeAnimals do
				assert(not seenAnimals[animalId], `{animalId} lives in two farms ({seenAnimals[animalId]} and {index})`)
				seenAnimals[animalId] = index
				assert(Config.getAnimalTheme(animalId) == index, `{animalId} maps back to its farm`)
			end
		end
		local animalCount = 0
		for _ in seenAnimals do
			animalCount += 1
		end
		assert(animalCount == 24, `24 unique animals across the farms, got {animalCount}`)
		for _, fishId in { "anchovy", "seabass" } do
			assert(Config.getAnimalTheme(fishId) == nil, "the sea branch belongs to every farm, not to one theme")
		end
		-- Süt Adası kalktı: inek yalnızca Çiftlik 1'in ana adasında yaşar
		assert(Config.FARM_ISLANDS.dairy == nil and Config.ZONES.dairy == nil, "no dairy island or zone")
		assert(
			Config.getUpgrade("island_dairy") == nil
				and Config.getUpgrade("dairy_factory") == nil
				and Config.getUpgrade("dairy_center") == nil
				and Config.PRODUCTION_RECIPES.dairy_packing == nil
				and Config.PRODUCTION_RECIPES.dairy_goods == nil,
			"no dairy upgrades or recipes"
		)
		assert(
			Config.getAnimalTheme("cow") == 1 and Config.getHomeAnimal("1") == "cow",
			"the cow lives on farm 1's home island"
		)
		for _, island in Config.FARM_ISLANDS do
			assert(
				island.id == "home" or (island.animalId and island.buildUpgradeId and island.itemUpgradeId),
				`island {island.id} is fully described`
			)
		end
		-- Her hayvanın en az bir ürün (ürün merkezi) ve bir para fabrikası var; fabrika yalnızca kendi adasında/ana hayvanıyla kurulur ve ürünler benzersizdir
		local goodsOwner: { [string]: string } = {}
		for goodsId, good in Config.GOODS do
			assert(not goodsOwner[good.animalId], `{good.animalId} has more than one good`)
			goodsOwner[good.animalId] = goodsId
		end
		for index in Config.THEMES do
			local farmId = tostring(index)
			for _, recipe in Config.PRODUCTION_RECIPES do
				local upgrade = Config.getUpgrade(recipe.upgradeId) :: any
				if recipe.animalId ~= "anchovy" and Config.upgradeInTheme(upgrade, farmId) then
					assert(
						Config.getIslandAnimal(farmId, recipe.island) == recipe.animalId,
						`theme {index}: recipe {recipe.id} can only be built where {recipe.animalId} lives`
					)
				end
			end
		end
	end
	-- Balık çeşitliliği: Çiftlik 1 Hamsi/Levrek; diğer her çiftlik kendi küçük (anchovy) ve büyük (seabass) balığını taşır.
	-- Kimlik/fiyat aynı kalır (yalnızca görünüm değişir); model dosya kimlikleri benzersizdir ve ANIMALS ile çakışmaz.
	do
		local seenModels: { [string]: string } = {}
		for index, theme in Config.THEMES do
			local farmId = tostring(index)
			local small = Config.getAnimalLook("anchovy", farmId)
			local large = Config.getAnimalLook("seabass", farmId)
			if index == 1 then
				assert(theme.fish == nil, "theme 1 keeps the default Hamsi/Levrek")
				assert(
					small.modelId == "anchovy" and large.modelId == "seabass",
					"theme 1 fish models are anchovy/seabass"
				)
			else
				assert(
					theme.fish and theme.fish.anchovy and theme.fish.seabass,
					`theme {index}: needs a small and a large fish skin`
				)
				assert(
					small.modelId ~= "anchovy" and large.modelId ~= "seabass" and small.modelId ~= large.modelId,
					`theme {index}: fish skins must be new fish`
				)
				for _, look in { small, large } do
					assert(
						Config.ANIMALS[look.modelId] == nil,
						`theme {index}: fish skin {look.modelId} collides with an ANIMALS id`
					)
					assert(
						look.displayName ~= "" and look.product ~= "" and look.icon ~= "",
						`theme {index}: incomplete fish skin`
					)
					assert(not seenModels[look.modelId], `fish model {look.modelId} is used by two themes`)
					seenModels[look.modelId] = farmId
				end
			end
		end
		assert(Config.getAnimalLook("cow", "2").modelId == "cow", "non-fish animals keep their own model")
	end

	-- Eşya etkileri: her eşyanın katkısı var, anahtarlar motorun bildiği listeden, slot içinde fiyat ↔ güç tutarlı
	do
		local KNOWN_EFFECTS = {
			movementSpeed = 0.5,
			upgradeDiscount = 1,
			expansionDiscount = 1,
			sellBonus = 1,
			facilitySpeed = 1,
			contractBonus = 1,
			goodsYield = 1,
			storageBonus = 0.5,
			offlineBonus = 0.5,
			growthSpeed = 0.5, -- çarpan: (değer - 1) artı sayılır
			incomeBonus = 1,
		}
		-- Anahtarlar aynı değerde olmadığı için güç, ağırlıklı artı toplamıdır (depo/çevrimdışı/büyüme yarım sayılır)
		local function power(item: any): number
			local total = 0
			for key, value in item.effects do
				total += (if key == "growthSpeed" then value - 1 else value) * KNOWN_EFFECTS[key]
			end
			return total
		end
		local bySlot: { [string]: { any } } = {}
		for _, itemId in Config.ITEM_ORDER do
			local item = Config.ITEMS[itemId]
			local count = 0
			for key, value in item.effects or {} do
				assert(KNOWN_EFFECTS[key], `item {itemId} uses unknown effect {key}`)
				assert(typeof(value) == "number" and value > 0, `item {itemId} effect {key} must be positive`)
				count += 1
			end
			assert(count >= 1, `item {itemId} must have at least one effect`)
			if not item.rewardOnly then
				bySlot[item.slot] = bySlot[item.slot] or {}
				table.insert(bySlot[item.slot], item)
			end
			for key, value in item.tradeoffs or {} do
				assert(
					key == "goodsYield" or key == "facilitySpeed" or key == "offlineBonus",
					"tradeoff has an implemented formula"
				)
				assert(
					typeof(value) == "number" and value > 0 and value <= 0.5,
					"equipment drawbacks are bounded positive penalties"
				)
			end
			if item.rewardOnly then
				assert(
					Config.PROGRESSION.permanentOffers[itemId] == nil,
					"achievement items cannot be bought with gold or Robux"
				)
			end
		end
		for _, slotId in { "head", "back" } do
			local list = bySlot[slotId]
			table.sort(list, function(a, b)
				return a.price < b.price
			end)
			for index = 2, #list do
				assert(
					power(list[index]) > power(list[index - 1]),
					`slot {slotId}: {list[index].id} costs more than {list[index - 1].id}, so it must be stronger`
				)
			end
		end

		-- Satış kanalları: her ekipman bir yoldan alınabilir; kanal fiyat kademesinden ve teklif tablosundan türer
		local CASH_ONLY_MAX = 150000 -- bu referans fiyata kadar yalnız nakit (teklif yok)
		local PREMIUM_MIN = 1500000 -- bundan pahalı ekipman nakitle satılmaz (noCash)
		local offers = Config.PROGRESSION.permanentOffers
		local channelCounts = { reward = 0, cash = 0, cashGold = 0, goldRobux = 0, gold = 0 }
		local robuxSeen: { [number]: string } = {}
		for _, itemId in Config.ITEM_ORDER do
			local item = Config.ITEMS[itemId]
			local channel = Config.getItemChannel(itemId)
			local offer = offers[itemId]
			assert(channelCounts[channel] ~= nil, `item {itemId} must be obtainable somewhere (channel {channel})`)
			channelCounts[channel] += 1
			if item.rewardOnly then
				assert(
					channel == "reward" and offer == nil and not Config.isCashItem(item),
					`{itemId}: earned-only is never sold`
				)
			elseif channel == "cash" then
				assert(offer == nil and Config.isCashItem(item), `{itemId}: cash-only items have no permanent offer`)
				assert(item.price <= CASH_ONLY_MAX, `{itemId}: cash-only items stay in the early price band`)
			elseif channel == "cashGold" then
				assert(offer ~= nil and Config.isCashItem(item), `{itemId}: cashGold sells for cash and has an offer`)
				assert(
					item.price > CASH_ONLY_MAX and item.price < PREMIUM_MIN,
					`{itemId}: cashGold items sit in the middle price band`
				)
			else
				assert(item.noCash and not Config.isCashItem(item), `{itemId}: premium items are not sold for cash`)
				assert(offer ~= nil and offer.kind == "item", `{itemId}: noCash items need a permanent offer`)
				assert(item.price >= PREMIUM_MIN, `{itemId}: noCash items are top gear`)
				if channel == "gold" then
					assert(offer.robuxProductId == nil, `{itemId}: gold-only offers must not carry a Robux product`)
				else
					assert((offer.robuxProductId or 0) ~= 0, `{itemId}: goldRobux offers keep a Robux product`)
				end
			end
			if offer and offer.robuxProductId then
				assert(robuxSeen[offer.robuxProductId] == nil, `Robux product of {itemId} is reused`)
				robuxSeen[offer.robuxProductId] = itemId
			end
		end
		assert(
			channelCounts.reward == 9 and channelCounts.cash > 0 and channelCounts.cashGold > 0,
			"all sales bands are populated"
		)
		assert(channelCounts.goldRobux >= 10 and channelCounts.gold >= 5, "premium gear has Robux and gold-only lanes")
		for offerId, offer in offers do
			if offer.kind == "item" then
				assert(
					Config.ITEMS[offer.itemId] and offer.id == offerId,
					`offer {offerId} must point at a defined item`
				)
			end
		end

		-- Altın bedeli ölçülen tempo kazancından türer (Progression.luau açıklaması):
		--   goldCost = min(1500, yuvarla10(taban(kanal) + 28 * puan)), puan = TEMPO_POINTS + 15 x hareket + 8 x satış.
		-- TEMPO_POINTS = `python scripts/simulate-items.py` tek eşya ölçümü: (ideal R5 % + max(casual R5 % - 2, 0)) / 2
		-- (casual 8 sa kuantasından gelen ~%2 gürültü çıkarılır). Hareket/satış simüle edilmez, bu yüzden küçük sabit kredi alır.
		-- Eşya etkisi değişince önce ölç, tabloyu güncelle; tablo olmayan bir teklif testi bilerek düşürür.
		local TEMPO_POINTS: { [string]: number } = {
			wind_charm = 0.9,
			iron_hammer = 5.7,
			gold_hammer = 9.2,
			diamond_hammer = 11.3,
			season_staff_3 = 0.0,
			season_staff_5 = 0.0,
			season_staff_inf = 0.0,
			weather_staff_3 = 2.8,
			weather_staff_5 = 4.2,
			weather_staff_inf = 0.1,
			storage_charm_2 = 1.9,
			growth_charm_2 = 0.1,
			income_charm_2 = 5.9,
			income_charm_3 = 9.5,
			golden_crown = 27.2,
			angel_wings = 5.3,
			golden_wings = 9.6,
			barn_charm_2 = 4.0,
			contract_charm_2 = 0.9,
			peacock_tail = 0.0,
			artisan_hammer = 11.7,
			artisan_staff = 0.1,
			night_charm = 5.9,
			logistics_charm = 2.8,
			orchard_charm = 0.4,
			merchant_hat = 3.1,
			expedition_pack = 5.7,
			artisan_cape = 0.0,
			trade_charm = 4.9,
			warehouse_pack = 5.7,
			breeder_staff = 0.1,
			foreman_mallet = 13.9,
			fortune_charm = 15.4,
			tycoon_crown = 6.8,
			caravan_satchel = 2.0,
			eternal_shepherd_staff = 7.7,
			crystal_wings = 5.9,
			engineer_wrench = 12.5,
			scholar_charm = 4.3,
			captain_hat = 3.1,
			courier_pack = 1.0,
			merchant_seal = 2.8,
		}
		local GOLD_BASE = { cashGold = 150, goldRobux = 400, gold = 400 } -- kanal tabanı: ucuz yararlı eşya, premium en az 400
		local GOLD_PER_POINT = 28
		local function tempoPoints(itemId: string): number
			local effects = Config.ITEMS[itemId].effects
			return assert(TEMPO_POINTS[itemId], `{itemId}: missing measured tempo points`)
				+ 15 * (effects.movementSpeed or 0)
				+ 8 * (effects.sellBonus or 0)
		end
		local function goldFor(itemId: string): number
			local channel = Config.getItemChannel(itemId)
			return math.min(
				1500,
				math.floor((GOLD_BASE[channel] + GOLD_PER_POINT * tempoPoints(itemId)) / 10 + 0.5) * 10
			)
		end
		local priced = {}
		for _, itemId in Config.ITEM_ORDER do
			local offer = offers[itemId]
			if offer then
				assert(
					offer.goldCost == goldFor(itemId),
					`{itemId}: gold cost must follow the tempo rule ({goldFor(itemId)})`
				)
				table.insert(priced, {
					id = itemId,
					gold = offer.goldCost,
					points = tempoPoints(itemId),
					channel = Config.getItemChannel(itemId),
				})
			end
		end
		-- Aynı kanalda daha çok tempo veren eşya daha ucuz olamaz (altın fayda ile birlikte artar)
		for _, a in priced do
			for _, b in priced do
				if a.channel == b.channel and a.points > b.points then
					assert(a.gold >= b.gold, `gold cost must not fall with benefit: {a.id} vs {b.id}`)
				end
			end
		end
		-- En çok tempo veren eşya (Altın Taç) en pahalı tekliftir
		local maxPoints, maxId = -1, ""
		for _, row in priced do
			if row.points > maxPoints then
				maxPoints, maxId = row.points, row.id
			end
		end
		assert(
			maxId == "golden_crown" and offers.golden_crown.goldCost >= 1000,
			"the crown is still the priciest, strongest offer"
		)
		local gold = Config.PROGRESSION.gold
		local runGold = gold.rebirthBase -- bir rebirth'in tek altın ödülü (R1; sonrası hafifçe artar)
		assert(
			gold.island == nil and gold.farm == nil and gold.rebirthBase > 0 and gold.rebirthPerLevel >= 0,
			"per-island and per-farm gold awards no longer exist"
		)
		for _, row in priced do
			assert(row.gold >= 100, `{row.id}: gold cost out of range`)
			if row.id ~= "golden_crown" then
				assert(row.gold <= runGold * 1.25, `{row.id}: only the crown may exceed about one rebirth run of gold`)
			end
		end
		-- Tek bir mağaza/kalıcı eşya gelir tavanını tek başına kırmaz (x3 sert tavan çok eşyayla birleşir)
		for _, itemId in Config.ITEM_ORDER do
			local item = Config.ITEMS[itemId]
			if not item.rewardOnly then
				assert(
					(item.effects.incomeBonus or 0) <= 0.5,
					`{itemId}: a single shop item stays at or under +50% income`
				)
			end
		end
		assert(
			Config.ITEMS.golden_crown.effects.incomeBonus >= 0.3
				and Config.ITEMS.golden_crown.effects.incomeBonus <= 0.5,
			"the crown stays the strongest income item without doubling income"
		)
		-- Ölü yük artık yok: ana etkisi sipariş/ürün verimi olan her satılık ekipman gerçek ikinci bir etki taşır
		for _, itemId in { "merchant_hat", "trade_charm", "scholar_charm", "tycoon_crown", "captain_hat" } do
			assert(Config.ITEMS[itemId].effects.incomeBonus, `{itemId}: trade gear carries a real income effect`)
		end
		assert(
			Config.ITEMS.artisan_hammer.effects.upgradeDiscount
				and Config.ITEMS.night_charm.effects.offlineBonus <= 0.25,
			"specialist tools keep a measurable effect and the night charm stays bounded"
		)
		for _, itemId in Config.ITEM_ORDER do
			assert(
				Config.ITEMS[itemId].price <= Config.ITEMS.golden_crown.price,
				"the crown keeps the top reference price"
			)
		end

		-- Prim ekipman kendi yuvasındaki başlangıç (yalnız nakit) ekipmanından açıkça güçlüdür
		for _, slotId in { "tool", "staff", "charm", "head", "back" } do
			local bestStarter, weakestPremium = 0, math.huge
			local starterId, premiumId = "", ""
			for _, itemId in Config.ITEM_ORDER do
				local item = Config.ITEMS[itemId]
				local channel = Config.getItemChannel(itemId)
				if item.slot == slotId then
					local value = power(item)
					if channel == "cash" and value > bestStarter then
						bestStarter, starterId = value, itemId
					elseif item.noCash and value < weakestPremium then
						weakestPremium, premiumId = value, itemId
					end
				end
			end
			assert(
				weakestPremium > bestStarter,
				`slot {slotId}: premium {premiumId} must out-power starter {starterId}`
			)
		end

		-- Altın-yalnız beş ekipman: rol, kanal ve üst sınırlar
		local goldOnly = {
			foreman_mallet = "tool",
			fortune_charm = "charm",
			tycoon_crown = "head",
			caravan_satchel = "back",
			eternal_shepherd_staff = "staff",
		}
		for itemId, slotId in goldOnly do
			local item = assert(Config.ITEMS[itemId], `{itemId} exists`)
			assert(
				item.slot == slotId and Config.getItemChannel(itemId) == "gold",
				`{itemId}: gold-only in slot {slotId}`
			)
			assert(
				offers[itemId].goldCost >= 400 and offers[itemId].goldCost <= 950,
				`{itemId}: at most about one run of gold`
			)
			assert((item.effects.movementSpeed or 0) <= 0.06, `{itemId}: movement stays small under the 25 percent cap`)
			assert((item.effects.incomeBonus or 0) <= 0.1, `{itemId}: income stays below the top charm`)
		end
		local shepherd = Config.ITEMS.eternal_shepherd_staff
		assert(
			shepherd.power.kind == "collect" and shepherd.power.usesPerDay == nil,
			"the eternal shepherd staff collects without a daily limit"
		)

		-- Ek on ekipman: dört rebirth ödülü ve altı yalnız-altın ürün (kanal, rol ve üst sınırlar)
		local newRewards = {
			lucky_clover = { slot = "charm", level = 9 },
			harvest_sickle = { slot = "tool", level = 15 },
			victory_laurel = { slot = "head", level = 21 },
			phoenix_wings = { slot = "back", level = 27 },
		}
		for itemId, expected in newRewards do
			local item = assert(Config.ITEMS[itemId], `{itemId} exists`)
			assert(
				item.slot == expected.slot and item.rewardOnly and item.noCash == nil,
				`{itemId}: reward in its slot`
			)
			assert(Config.getItemChannel(itemId) == "reward" and offers[itemId] == nil, `{itemId}: never sold`)
			assert(not Config.isCashItem(item), `{itemId}: not a cash item (merchant never offers it)`)
			assert(
				Config.PROGRESSION.milestones[expected.level].itemId == itemId,
				`{itemId}: granted by the R{expected.level} milestone`
			)
			assert(power(item) < power(Config.ITEMS.master_crown), `{itemId}: weaker than the final reward`)
			assert(
				power(item) < power(Config.ITEMS.night_cape) or itemId ~= "phoenix_wings",
				"phoenix wings stay below the night cape"
			)
			for _, otherId in Config.ITEM_ORDER do
				local other = Config.ITEMS[otherId]
				if other.slot == item.slot and Config.getItemChannel(otherId) == "cashGold" then
					assert(power(item) > power(other), `{itemId}: out-powers cash+gold {otherId}`)
				end
			end
		end
		-- Her rebirth ödül eşyası tam olarak bir kilometre taşından gelir
		local milestoneItems: { [string]: number } = {}
		for _, milestone in Config.PROGRESSION.milestones do
			if milestone.itemId then
				milestoneItems[milestone.itemId] = (milestoneItems[milestone.itemId] or 0) + 1
			end
		end
		for _, itemId in Config.ITEM_ORDER do
			if Config.ITEMS[itemId].rewardOnly then
				assert(milestoneItems[itemId] == 1, `{itemId}: reward item has exactly one milestone`)
			end
		end
		local newGold = {
			crystal_wings = "back",
			engineer_wrench = "tool",
			scholar_charm = "charm",
			captain_hat = "head",
			courier_pack = "back",
			merchant_seal = "charm",
		}
		for itemId, slotId in newGold do
			local item = assert(Config.ITEMS[itemId], `{itemId} exists`)
			local offer = assert(offers[itemId], `{itemId} has an offer`)
			assert(
				item.slot == slotId and item.noCash and not item.rewardOnly and Config.getItemChannel(itemId) == "gold",
				`{itemId}: gold-only in slot {slotId}`
			)
			assert(offer.kind == "item" and offer.robuxProductId == nil, `{itemId}: gold only, no Robux product`)
			assert(offer.goldCost >= 400 and offer.goldCost <= 800, `{itemId}: priced at under one run of gold`)
			assert((item.effects.movementSpeed or 0) < 0.12, `{itemId}: movement below the golden wings`)
			assert((item.effects.incomeBonus or 0) <= 0.1, `{itemId}: income stays below the top charm`)
			assert(not Config.isCashItem(item), `{itemId}: merchant and cash shop never offer it`)
		end
		assert(
			Config.ITEMS.crystal_wings.effects.movementSpeed > Config.ITEMS.angel_wings.effects.movementSpeed
				and Config.ITEMS.crystal_wings.effects.movementSpeed
					< Config.ITEMS.golden_wings.effects.movementSpeed,
			"crystal wings sit between angel and golden wings"
		)
		assert(
			Config.ITEMS.courier_pack.effects.storageBonus and Config.ITEMS.courier_pack.effects.movementSpeed,
			"the courier pack is movement plus storage"
		)
		print("PASS config: item sales channels, gold formula and premium power tiers")
	end
	print("PASS config: cross-references, prerequisite graph, seasonal goals and start state")
end
