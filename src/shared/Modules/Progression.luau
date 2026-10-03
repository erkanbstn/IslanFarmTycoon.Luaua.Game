--!strict
-- Rebirth ve altın kararları saf hesaplanır; cüzdan/kayıt işlemini sunucu uygular.
local Config = require(script.Parent.Parent:WaitForChild("Config"))
local FarmMath = require(script.Parent:WaitForChild("FarmMath"))

local Progression = {}
Progression.permanentOffers = Config.PROGRESSION.permanentOffers
Progression.getPerkLevel = FarmMath.getPerkLevel
Progression.getPerkBonus = FarmMath.getPerkBonus
Progression.isReturnActive = FarmMath.isReturnActive

local requiredByFarm: { [string]: { string } } = {}
local requiredByIsland: { [string]: { [string]: { string } } } = {}
for index = 1, Config.MAIN_FARM_LIMIT do
	local id = tostring(index)
	local required: { string } = {}
	local islands: { [string]: { string } } = {}
	for _, upgrade in Config.UPGRADES do
		if not upgrade.leveled and Config.upgradeInTheme(upgrade, id) then
			table.insert(required, upgrade.id)
			local island = Config.getUpgradeIsland(upgrade)
			if island then
				local list = islands[island] or {}
				islands[island] = list
				table.insert(list, upgrade.id)
			end
		end
	end
	requiredByFarm[id] = required
	requiredByIsland[id] = islands
end

function Progression.defaults(now: number, lifetime: number?): any
	return {
		run = 1,
		count = 0,
		perks = {},
		claims = {},
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

function Progression.isIslandComplete(save: any, islandId: string, farmId: string?): boolean
	local id = farmId or save.farmId or save.activeMainFarmId
	local farm = if id then farmView(save, id) else nil
	local required = if requiredByIsland[id] then requiredByIsland[id][islandId] else nil
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
			if Progression.isFarmComplete(root, id) then
				complete += 1
			end
		end
	end
	return {
		farmsOwned = owned,
		farmsComplete = complete,
		farmsTotal = Config.MAIN_FARM_LIMIT,
		canRebirth = owned == Config.MAIN_FARM_LIMIT and complete == Config.MAIN_FARM_LIMIT,
	}
end

function Progression.canRebirth(root: any): boolean
	return Progression.progress(root).canRebirth
end

function Progression.canChoosePerk(save: any, id: unknown): boolean
	if typeof(id) ~= "string" then
		return false
	end
	if id == "prestige" then
		for perkId, definition in Config.PROGRESSION.perks do
			if Progression.getPerkLevel(save, perkId) < definition.maxLevel then
				return false
			end
		end
		return true
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

function Progression.collectGold(root: any, now: number): number
	local state = root.progression
	if not state then
		state = Progression.defaults(now, root.lifetimeEarned)
		root.progression = state
	end
	local bonus = if state.count >= 10 then 0.2 elseif state.count >= 3 then 0.1 else 0
	local earned = 0
	local balance = root.gold or 0
	for index = 1, Config.MAIN_FARM_LIMIT do
		local id = tostring(index)
		if not farmView(root, id) then
			continue
		end
		local islands = { "home" }
		for _, islandId in Config.getTheme(id).satellites do
			table.insert(islands, islandId)
		end
		for _, islandId in islands do
			local key = `island:{id}:{islandId}`
			local reward = math.floor(Config.PROGRESSION.gold.island * (1 + bonus) + 0.5)
			if
				not state.claims[key]
				and balance + earned + reward <= Config.PROGRESSION.gold.maxBalance
				and Progression.isIslandComplete(root, islandId, id)
			then
				state.claims[key] = true
				earned += reward
			end
		end
		local key = `farm:{id}`
		local reward = math.floor(Config.PROGRESSION.gold.farm * (1 + bonus) + 0.5)
		if
			not state.claims[key]
			and balance + earned + reward <= Config.PROGRESSION.gold.maxBalance
			and Progression.isFarmComplete(root, id)
		then
			state.claims[key] = true
			earned += reward
		end
	end
	local previous = root.gold or 0
	root.gold = math.min(Config.PROGRESSION.gold.maxBalance, previous + earned)
	return root.gold - previous
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
	local discount = if save.progression and save.progression.count >= 5 then 0.1 else 0
	return math.max(1, math.ceil(remaining / 60 * (1 - discount))), nil
end

function Progression.getStartingCash(save: any, farmId: string?): number
	local id = farmId or save.farmId or save.activeMainFarmId
	return Config.getStartingCash(id) * (1 + Progression.getPerkBonus(save, "startingAnimals"))
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
