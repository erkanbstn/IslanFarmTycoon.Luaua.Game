--!strict
-- Yalnız kayıtsız Studio QA place'inin tekrarlanabilir profilleri; canlı kayıt yüklemez/yazmaz.
local ScenarioFixtures = {}

function ScenarioFixtures.allowed(
	studio: boolean,
	enabled: unknown,
	nonpersistent: unknown,
	persistent: unknown
): boolean
	return studio and enabled == true and nonpersistent == true and persistent == false
end

function ScenarioFixtures.create(
	scenario: string,
	rebirthLevel: number,
	now: number,
	newUid: () -> string,
	config: any,
	farmMath: any,
	codec: any,
	progression: any
): any
	assert(table.find({ "fresh", "merchant", "production", "rebirth-ready" }, scenario), "Unknown QA scenario")
	assert(
		rebirthLevel == rebirthLevel
			and rebirthLevel % 1 == 0
			and rebirthLevel >= 0
			and rebirthLevel <= config.PROGRESSION.maxRebirth,
		"Invalid QA rebirth level"
	)
	local data = assert(codec.decode(nil, config, farmMath, now, newUid), "QA fresh profile failed")
	data.language = "tr"
	data.progression.count = rebirthLevel
	data.progression.run = rebirthLevel + 1
	local remaining = rebirthLevel
	local perkIds = {}
	for id in config.PROGRESSION.perks do
		table.insert(perkIds, id)
	end
	table.sort(perkIds)
	for _, id in perkIds do
		local amount = math.min(remaining, config.PROGRESSION.perks[id].maxLevel)
		data.progression.perks[id] = amount
		remaining -= amount
	end
	assert(remaining == 0, "QA perk allocation failed")
	progression.grantRebirthRewards(data)
	if scenario == "fresh" then
		return data
	end
	if scenario == "merchant" then
		local budget = config.getStartingCash("1")
		for _, item in config.ITEMS do
			budget = math.max(budget, item.price or 0)
		end
		data.cash = budget
		data.adminForce = { merchantUntil = now + config.MERCHANT.visitSeconds }
		return data
	end
	local count = if scenario == "rebirth-ready" then config.MAIN_FARM_LIMIT else 1
	for index = 1, count do
		local farmId = tostring(index)
		local farm = if index == 1 then data else codec.newFarm(config, farmMath, now, newUid, farmId)
		farm.farmId = farmId
		for _, upgrade in config.UPGRADES do
			if config.upgradeInTheme(upgrade, farmId) then
				farm.purchased[upgrade.id] = true
			end
		end
		farmMath.applyDerived(farm)
		farm.expansions, farm.lineage, farm.animals = {}, {}, {}
		for zoneId in farm.unlockedZones do
			local zone = config.ZONES[zoneId]
			farm.expansions[zoneId] = config.BUILD_UPGRADES.maxLevel
			for _, animalId in config.getZoneAnimals(zone, farmId) do
				farm.lineage[animalId] = config.LINEAGE.maxLevel
			end
		end
		for recipeId, recipe in config.PRODUCTION_RECIPES do
			if farm.purchased[recipe.upgradeId] then
				farm.expansions[recipeId] = config.BUILD_UPGRADES.maxLevel
			end
		end
		farmMath.applyDerived(farm)
		for zoneId in farm.unlockedZones do
			local zone = config.ZONES[zoneId]
			local animalId = config.getZoneAnimals(zone, farmId)[1]
			for _ = 1, farmMath.getZoneCapacity(farm, zoneId) do
				table.insert(farm.animals, {
					uid = newUid(),
					animalId = animalId,
					zoneId = zoneId,
					bornAt = 0,
					stage = "adult",
				})
			end
		end
		data.mainFarms[farmId] = if index == 1 then data.mainFarms["1"] else farm
		if scenario == "production" then
			farm.autoRepeat = {}
			for _, recipeId in config.PRODUCTION_ORDER do
				local recipe = config.PRODUCTION_RECIPES[recipeId]
				if recipe.output == "goods" and farm.purchased[recipe.upgradeId] then
					farm.autoRepeat[recipeId] = "default"
					break
				end
			end
		end
	end
	-- Etkin çiftlikteki alanları şema sınırından geçir: mainFarms[1] ile kökün referansları aynı kalır.
	local snapshot = codec.encode(data, now)
	local restored, _, problem = codec.decode(snapshot, config, farmMath, now, newUid)
	return assert(restored, problem or "QA fixture round trip failed")
end

return ScenarioFixtures
