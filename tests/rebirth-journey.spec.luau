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
				if not upgrade.leveled and Config.upgradeInTheme(upgrade, id) then
					farm.purchased[upgrade.id] = true
				end
			end
			if index > 1 then
				data.mainFarms[id] = farm
			end
		end
		return data
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
			assert(
				Config.ITEMS[milestone.itemId].rewardOnly and not Config.PROGRESSION.permanentOffers[milestone.itemId],
				"earned items are never paid prerequisites"
			)
		end
	end
	assert(rewards == 5, "five milestone equipment alternatives")
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
