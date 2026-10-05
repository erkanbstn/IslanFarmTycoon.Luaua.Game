--!strict
return function(Config: any, FarmMath: any, Progression: any, SaveCodec: any, Inventory: any)
	local now = 1000000
	local function fresh(): any
		local data = assert(
			SaveCodec.decode(nil, Config, FarmMath, now, function()
				return "journey-animal"
			end),
			"new journey account"
		)
		data.farmId = "1"
		data.mainFarms = {}
		for index = 1, Config.MAIN_FARM_LIMIT do
			local id = tostring(index)
			local farm: any = if index == 1 then data else { purchased = {}, expansions = {}, lineage = {} }
			for _, upgrade in Config.UPGRADES do
				if not upgrade.leveled and not upgrade.optionalForCompletion and Config.upgradeInTheme(upgrade, id) then
					farm.purchased[upgrade.id] = true
				end
			end
			if index > 1 then
				data.mainFarms[id] = farm
			end
		end
		return data
	end
	local optional = {}
	for _, upgrade in Config.UPGRADES do
		if upgrade.optionalForCompletion then
			table.insert(optional, upgrade)
		end
	end
	assert(#optional == 13, "all new animal gardens are optional completion content")
	for _, upgrade in optional do
		local present = false
		for index = 1, Config.MAIN_FARM_LIMIT do
			local id = tostring(index)
			if Config.upgradeInTheme(upgrade, id) then
				present = true
				local root = fresh()
				local farm = if index == 1 then root else root.mainFarms[id]
				farm.farmId = id
				assert(not farm.purchased[upgrade.id], "journey never purchases optional garden")
				assert(
					FarmMath.getUpgradeStatus(farm, upgrade.id) == "available",
					"optional garden remains purchasable after normal progression"
				)
				assert(
					upgrade.cost > 0 and Config.ROADMAP_STAGES[upgrade.stage],
					"optional garden has a real price and roadmap stage"
				)
				assert(
					Progression.isRebirthFarmComplete(root, id) or Progression.isFarmComplete(root, id),
					"optional garden does not withhold farm completion"
				)
			end
		end
		assert(present, "every optional garden belongs to a playable theme")
	end

	assert(#Config.PROGRESSION.milestones == 30, "every attainable level has a reward")
	for count = 0, 29 do
		local data = fresh()
		data.progression.count = count
		local targetsTotal = 0
		for index = 1, Config.MAIN_FARM_LIMIT do
			local id = tostring(index)
			local farm = if index == 1 then data else data.mainFarms[id]
			local targets = Progression.getRebirthTargets(data, id)
			if count >= 5 then
				assert(
					not Progression.isRebirthFarmComplete(data, id),
					"basic purchases alone do not pass advanced runs"
				)
			end
			for _, target in targets do
				targetsTotal += 1
				if target.kind == "lineage" then
					assert(target.level <= Config.LINEAGE.maxLevel, "lineage requirement is reachable")
					farm.lineage[target.id] = target.level
				else
					assert(target.level <= Config.BUILD_UPGRADES.maxLevel, "building requirement is reachable")
					assert(
						Config.ZONES[target.id] or Config.PRODUCTION_RECIPES[target.id],
						"required target is real content"
					)
					farm.expansions[target.id] = target.level
				end
			end
			assert(Progression.isRebirthFarmComplete(data, id), "all free requirements suffice without equipped items")
		end
		assert(Progression.canRebirth(data), `run {count + 1} has an attainable completion state`)
		assert(count < 5 or targetsTotal >= 12, "advanced runs engage existing building and lineage gameplay")
		local milestone = assert(Progression.getMilestone(count + 1), "next level reward exists")
		assert(milestone.effects or milestone.itemId, "no empty rebirth rewards")
	end
	local data = fresh()
	data.progression.count = 30
	for index = 1, Config.MAIN_FARM_LIMIT do
		assert(
			Progression.isFarmComplete(data, tostring(index)),
			"terminal R30 farm completion also excludes optional content"
		)
	end
	assert(
		not Progression.canRebirth(data) and not Progression.canChoosePerk(data, "income"),
		"R30 prevents another reset"
	)
	assert(Progression.grantRebirthRewards(data), "achievement ownership is granted")
	assert(not Progression.grantRebirthRewards(data), "reward grant is idempotent without extra claim ledger")
	local rewards = 0
	for _, milestone in Config.PROGRESSION.milestones do
		if milestone.itemId then
			rewards += 1
			assert(
				data.owned.items[milestone.itemId] and Inventory.owns(data, milestone.itemId),
				"free rewards survive rebirth via permanent rights"
			)
			local item = Config.ITEMS[milestone.itemId]
			assert(
				(item.rewardOnly and not Config.PROGRESSION.permanentOffers[milestone.itemId])
					or Config.getItemChannel(milestone.itemId) == "cashGold",
				"earned items are either reward-only or an early cash+gold shop item"
			)
		end
	end
	assert(rewards == 14, "nine later milestone items plus five early R1-R5 items")
	local seen: { [string]: number } = {}
	for _, milestone in Config.PROGRESSION.milestones do
		if milestone.itemId then
			seen[milestone.itemId] = (seen[milestone.itemId] or 0) + 1
			assert(seen[milestone.itemId] == 1, `{milestone.itemId} is granted by only one milestone`)
		end
	end
	-- Erken ödüller: R1..R5 hem sabit etki hem kalıcı eşya verir; bir önceki seviyede eşya yoktur.
	for level, expected in
		{
			[1] = "wind_charm",
			[2] = "merchant_hat",
			[3] = "storage_charm_2",
			[4] = "growth_charm_2",
			[5] = "contract_charm_2",
		}
	do
		local milestone = assert(Config.PROGRESSION.milestones[level], "milestone exists")
		assert(milestone.itemId == expected and milestone.effects, `R{level} grants {expected} and keeps its stat`)
		assert(string.find(milestone.description, " · Kalıcı ", 1, true), `R{level} description names the item`)
		local before = fresh()
		before.progression.count = level - 1
		Progression.grantRebirthRewards(before)
		assert(not Inventory.owns(before, expected), `{expected} is not granted before R{level}`)
		local reached = fresh()
		reached.progression.count = level
		assert(Progression.grantRebirthRewards(reached), `R{level} grants ownership`)
		assert(
			reached.owned.items[expected] and reached.inventory.items[expected] and Inventory.owns(reached, expected),
			`{expected} is owned at R{level}`
		)
		assert(Inventory.equip(reached, expected), `{expected} equips`)
		assert(not Progression.grantRebirthRewards(reached), `{expected} grant is idempotent`)
		assert(Config.PROGRESSION.permanentOffers[expected], `{expected} stays a shop item (duplicates refund in gold)`)
	end
	-- Yeni ara ödüller: ilgili seviyede hem sabit etki hem eşya verilir; bir önceki seviyede eşya yoktur.
	for level, expected in
		{ [9] = "lucky_clover", [15] = "harvest_sickle", [21] = "victory_laurel", [27] = "phoenix_wings" }
	do
		local milestone = assert(Config.PROGRESSION.milestones[level], "milestone exists")
		assert(milestone.itemId == expected and milestone.effects, `R{level} grants {expected} and keeps its stat`)
		local before = fresh()
		before.progression.count = level - 1
		Progression.grantRebirthRewards(before)
		assert(not Inventory.owns(before, expected), `{expected} is not granted before R{level}`)
		local reached = fresh()
		reached.progression.count = level
		assert(Progression.grantRebirthRewards(reached), `R{level} grants ownership`)
		assert(
			reached.owned.items[expected] and reached.inventory.items[expected] and Inventory.owns(reached, expected),
			`{expected} is owned and in the inventory at R{level}`
		)
		assert(Inventory.equip(reached, expected), `{expected} equips`)
		assert(not Progression.grantRebirthRewards(reached), `{expected} grant is idempotent`)
	end
	assert(
		math.abs(Progression.getMilestoneBonus(data, "goldBonus") - 0.2) < 1e-6,
		"completion gold bonus bounded at20 percent"
	)
	assert(
		math.abs(Progression.getMilestoneBonus(data, "facilitySpeed") - 0.07) < 1e-6,
		"automatic factory speed stays bounded"
	)
	assert(Progression.getMilestoneBonus(data, "offlineHours") == 0.5, "milestone offline limit is half an hour")
	local recipe: any = nil
	for _, candidate in Config.PRODUCTION_RECIPES do
		if candidate.output == "goods" and (not recipe or candidate.goodsAmount > recipe.goodsAmount) then
			recipe = candidate
		end
	end
	assert(recipe, "real goods recipe")
	local save = assert(
		SaveCodec.decode(nil, Config, FarmMath, now, function()
			return "drawback-animal"
		end),
		"new drawback account"
	)
	FarmMath.applyDerived(save)
	local duration = FarmMath.getFacilityDuration(save, recipe)
	Inventory.grant(save, "warehouse_pack")
	assert(Inventory.equip(save, "warehouse_pack"), "warehouse pack equips")
	assert(
		FarmMath.getFacilityDuration(save, recipe) == math.max(10, math.floor(recipe.duration * 1.05)),
		"larger storage really slows production"
	)
	assert(FarmMath.getFacilityDuration(save, recipe) > duration, "storage penalty is observable")
	Inventory.unequip(save, "back")
	Inventory.grant(save, "trade_charm")
	assert(Inventory.equip(save, "trade_charm"), "trade charm equips")
	assert(
		FarmMath.getGoodsYield(save, recipe, now)
			== math.clamp(math.floor(recipe.goodsAmount * 0.9), 1, Config.PRODUCTION_MAX_BATCH_UNITS),
		"better contracts really sacrifice goods yield"
	)
	Inventory.unequip(save, "charm")
	Inventory.grant(save, "breeder_staff")
	assert(Inventory.equip(save, "breeder_staff"), "breeder staff equips")
	assert(
		math.abs(FarmMath.getOfflineTerms(save) - Config.OFFLINE_EARNING_RATE * 0.85) < 1e-6,
		"faster growth really sacrifices offline earnings"
	)
	assert(
		FarmMath.getGrowthSpeed(save, "cow", "starter", now) == 1.3,
		"growth benefit reaches real growth calculation"
	)
	print(
		"PASS rebirth journey: thirty reachable runs, bounded milestone effects, free equipment, terminal state and real tradeoffs"
	)
end
