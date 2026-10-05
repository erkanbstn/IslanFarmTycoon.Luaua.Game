--!strict
-- Rebirth ve altın kararları saf hesaplanır; cüzdan/kayıt işlemini sunucu uygular.
local Config = require(script.Parent.Parent:WaitForChild("Config"))
local FarmMath = require(script.Parent:WaitForChild("FarmMath"))

local Progression = {}
Progression.permanentOffers = Config.PROGRESSION.permanentOffers
Progression.getPerkLevel = FarmMath.getPerkLevel
Progression.getPerkBonus = FarmMath.getPerkBonus
Progression.getMilestoneBonus = FarmMath.getMilestoneBonus
Progression.isReturnActive = FarmMath.isReturnActive

local requiredByFarm: { [string]: { string } } = {}
for index = 1, Config.MAIN_FARM_LIMIT do
	local id = tostring(index)
	local required: { string } = {}
	for _, upgrade in Config.UPGRADES do
		if not upgrade.leveled and not upgrade.optionalForCompletion and Config.upgradeInTheme(upgrade, id) then
			table.insert(required, upgrade.id)
		end
	end
	requiredByFarm[id] = required
end

function Progression.defaults(now: number, lifetime: number?): any
	return {
		run = 1,
		count = 0,
		perks = {},
		claims = {}, -- yalnız `terminal` (R30 son tur ödülü); eski ada/çiftlik anahtarları okunurken atılır
		startedAt = now,
		returnEndsAt = 0,
		returnEnded = true,
		runEarnedBase = lifetime or 0,
		convertedDay = -1,
		convertedDayGold = 0,
		convertedRunGold = 0,
		runDouble = false,
		doubleCredits = 0,
	}
end

local function farmView(root: any, farmId: string): any?
	if farmId == (root.farmId or root.activeMainFarmId) then
		return root
	end
	return if root.mainFarms then root.mainFarms[farmId] else nil
end

function Progression.getMilestone(level: number): any?
	return if level % 1 == 0
			and level >= 1
			and level <= Config.PROGRESSION.maxRebirth
		then Config.PROGRESSION.milestones[level]
		else nil
end

function Progression.getCompletionRequirements(root: any): any
	local count = if root.progression then root.progression.count else 0
	local selected = Config.PROGRESSION.completionRequirements[1]
	for _, requirement in Config.PROGRESSION.completionRequirements do
		if count >= requirement.fromCount then
			selected = requirement
		end
	end
	return selected
end

-- Sunucu, arayüz ve simülatör aynı satın alınabilir hedefleri izler.
function Progression.getRebirthTargets(root: any, farmId: string): { any }
	local requirement = Progression.getCompletionRequirements(root)
	local targets: { any } = {}
	local theme = Config.getTheme(farmId)
	for _, zoneId in Config.ZONE_ORDER do
		local zone = Config.ZONES[zoneId]
		if zone.island == "home" or table.find(theme.satellites, zone.island) then
			local level = if zoneId == "starter"
				then math.max(requirement.homeExpansionLevel, requirement.zoneExpansionLevel)
				else requirement.zoneExpansionLevel
			if level > 0 then
				table.insert(targets, { kind = "expansion", id = zoneId, level = level })
			end
		end
	end
	if requirement.homeLineageLevel > 0 then
		table.insert(targets, { kind = "lineage", id = theme.homeAnimal, level = requirement.homeLineageLevel })
	end
	if requirement.homeFacilityLevel > 0 then
		for recipeId, recipe in Config.PRODUCTION_RECIPES do
			if recipe.island == "home" and recipe.output == "cash" and recipe.animalId == theme.homeAnimal then
				table.insert(targets, { kind = "expansion", id = recipeId, level = requirement.homeFacilityLevel })
			end
		end
	end
	return targets
end

function Progression.isRebirthFarmComplete(root: any, farmId: string): boolean
	if not Progression.isFarmComplete(root, farmId) then
		return false
	end
	local farm = farmView(root, farmId)
	if not farm then
		return false
	end
	if not farm then
		return false
	end
	for _, target in Progression.getRebirthTargets(root, farmId) do
		local level = if target.kind == "lineage"
			then FarmMath.getLineageLevel(farm, target.id)
			else FarmMath.getExpansionLevel(farm, target.id)
		if level < target.level then
			return false
		end
	end
	return true
end

function Progression.grantRebirthRewards(root: any): boolean
	local changed = false
	root.owned = root.owned or { items = {}, conveniences = {} }
	root.inventory = root.inventory or { items = {}, equipped = {}, uses = {} }
	for level = 1, math.min(if root.progression then root.progression.count else 0, Config.PROGRESSION.maxRebirth) do
		local itemId = Config.PROGRESSION.milestones[level].itemId
		if itemId then
			if not root.owned.items[itemId] or not root.inventory.items[itemId] then
				changed = true
			end
			root.owned.items[itemId] = true
			root.inventory.items[itemId] = true
		end
	end
	return changed
end

function Progression.isFarmComplete(save: any, farmId: string?): boolean
	local id = farmId or save.farmId or save.activeMainFarmId
	local required = requiredByFarm[id]
	local farm = if id then farmView(save, id) else nil
	if not farm or not farm.purchased or not required or #required == 0 then
		return false
	end
	for _, upgradeId in required do
		if not farm.purchased[upgradeId] then
			return false
		end
	end
	return true
end

function Progression.progress(root: any): any
	if root.progressionStatus then
		return root.progressionStatus
	end
	local owned, complete = 0, 0
	for index = 1, Config.MAIN_FARM_LIMIT do
		local id = tostring(index)
		if farmView(root, id) then
			owned += 1
			if Progression.isRebirthFarmComplete(root, id) then
				complete += 1
			end
		end
	end
	local count = if root.progression then root.progression.count else 0
	return {
		farmsOwned = owned,
		farmsComplete = complete,
		farmsTotal = Config.MAIN_FARM_LIMIT,
		canRebirth = count < Config.PROGRESSION.maxRebirth
			and owned == Config.MAIN_FARM_LIMIT
			and complete == Config.MAIN_FARM_LIMIT,
		nextLevel = math.min(count + 1, Config.PROGRESSION.maxRebirth),
		maxRebirth = Config.PROGRESSION.maxRebirth,
		requirements = Progression.getCompletionRequirements(root),
	}
end

function Progression.canRebirth(root: any): boolean
	return Progression.progress(root).canRebirth
end

function Progression.canChoosePerk(save: any, id: unknown): boolean
	if save.progression and save.progression.count >= Config.PROGRESSION.maxRebirth then
		return false
	end
	if typeof(id) ~= "string" then
		return false
	end
	if id == "prestige" then
		return false
	end
	local definition = Config.PROGRESSION.perks[id]
	return definition ~= nil and Progression.getPerkLevel(save, id) < definition.maxLevel
end

function Progression.getIncomeMultiplier(save: any, itemMultiplier: number): number
	return math.min(
		Config.PROGRESSION.permanentIncomeCap,
		itemMultiplier * (1 + Progression.getPerkBonus(save, "incomeBonus"))
	)
end

-- Tek altın ödülü: rebirth ile (Rebirth.apply) ya da R30'da turun tamamlanmasıyla verilir; ada/çiftlik başına altın yoktur.
-- Tutar o ana kadarki rebirth sayısıyla hafifçe artar ve tamamlama altını (goldBonus) kilometre taşlarını içerir.
function Progression.rebirthGoldReward(save: any): number
	local state = save.progression
	local count = if state
			and typeof(state.count) == "number"
			and state.count == state.count
		then math.clamp(math.floor(state.count), 0, Config.PROGRESSION.maxRebirth)
		else 0
	local gold = Config.PROGRESSION.gold
	local base = gold.rebirthBase + gold.rebirthPerLevel * count
	return math.floor(base * (1 + Progression.getMilestoneBonus(save, "goldBonus")) + 0.5)
end

-- Altı çiftlik de tur gereksinimlerini bitirmiş mi (R30'dan sonra da hesaplanır; canRebirth ise R30'da kapalıdır).
function Progression.isRunComplete(root: any): boolean
	for index = 1, Config.MAIN_FARM_LIMIT do
		local id = tostring(index)
		if not farmView(root, id) or not Progression.isRebirthFarmComplete(root, id) then
			return false
		end
	end
	return true
end

-- R30'da (başka sıfırlama yok) tamamlanan son tur ödülü bir kez verilir; `claims.terminal` tekrarı engeller.
function Progression.collectTerminalGold(root: any): number
	local state = root.progression
	if not state or state.count < Config.PROGRESSION.maxRebirth or state.claims.terminal then
		return 0
	end
	local reward = Progression.rebirthGoldReward(root)
	local balance = root.gold or 0
	if balance + reward > Config.PROGRESSION.gold.maxBalance or not Progression.isRunComplete(root) then
		return 0
	end
	state.claims.terminal = true
	root.gold = balance + reward
	return reward
end

function Progression.goldCashQuote(save: any, amount: unknown, now: number): (number?, string?)
	local limits = Config.PROGRESSION.gold
	if typeof(amount) ~= "number" or amount ~= amount or amount % 1 ~= 0 or amount < 1 or amount > limits.runLimit then
		return nil, "invalid_amount"
	end
	if amount > (save.gold or 0) then
		return nil, "insufficient_gold"
	end
	local state = save.progression or Progression.defaults(now, save.lifetimeEarned)
	local day = math.floor(now / 86400)
	local daily = if state.convertedDay == day then state.convertedDayGold else 0
	if daily + amount > limits.dailyLimit then
		return nil, "daily_limit"
	end
	if state.convertedRunGold + amount > limits.runLimit then
		return nil, "run_limit"
	end
	local income = FarmMath.getPermanentReferenceIncome(save)
	local cash = math.floor(income * limits.cashSeconds * amount)
	if cash <= 0 then
		return nil, "no_income"
	end
	return math.min(1e15, cash), nil
end

function Progression.finishGoldQuote(save: any, kind: unknown, id: unknown, now: number): (number?, string?)
	if typeof(kind) ~= "string" or not Config.PROGRESSION.finishTargets[kind] then
		return nil, "unsupported_target"
	end
	if typeof(id) ~= "string" then
		return nil, "invalid_target"
	end
	local remaining: number? = nil
	if kind == "production" then
		local job = save.production and save.production[id]
		remaining = if job then job.readyAt - now else nil
	elseif kind == "growth" or kind == "extension" then
		for _, animal in save.animals do
			if animal.uid == id then
				if kind == "growth" then
					remaining = if animal.bornAt == 0
						then 0
						else animal.bornAt + FarmMath.getGrowthSeconds(save, animal.animalId, animal.zoneId, now) - now
				else
					remaining = if animal.task and animal.task.kind == "extension"
						then animal.task.endsAt - now
						else nil
				end
				break
			end
		end
	end
	if remaining == nil then
		return nil, "invalid_target"
	elseif remaining <= 0 then
		return nil, "already_ready"
	end
	local discount = Progression.getMilestoneBonus(save, "finishDiscount")
	return math.max(1, math.ceil(remaining / 60 * (1 - discount))), nil
end

function Progression.getStartingCash(save: any, farmId: string?): number
	local id = farmId or save.farmId or save.activeMainFarmId
	return Config.getStartingCash(id)
		* (
			1
			+ Progression.getPerkBonus(save, "startingAnimals")
			+ Progression.getMilestoneBonus(save, "startingAnimals")
		)
end

function Progression.applyReadyStart(save: any, now: number, newUid: () -> string)
	local level = Progression.getPerkLevel(save, "ready_start")
	if level >= 3 then
		local first = Config.getTheme("1").satellites[1]
		local island = Config.FARM_ISLANDS[first]
		save.purchased[island.upgradeId] = true
	end
	FarmMath.applyDerived(save)
	local adults = (if level >= 2 then 1 else 0) + (if level >= 4 then 1 else 0) + (if level >= 5 then 1 else 0)
	for _ = 1, adults do
		local animalId = Config.getHomeAnimal("1")
		local zoneId = FarmMath.findZoneForAnimal(save, animalId)
		if zoneId then
			table.insert(
				save.animals,
				{ uid = newUid(), animalId = animalId, zoneId = zoneId, stage = "adult", bornAt = 0 }
			)
		end
	end
	local state = save.progression
	if state and state.count > 0 then
		state.returnEndsAt = now + Config.PROGRESSION.returnSeconds
		state.returnEnded = false
	end
end

return Progression
