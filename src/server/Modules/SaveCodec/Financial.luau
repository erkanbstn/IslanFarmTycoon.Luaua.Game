--!strict
-- Altın ve kalıcı haklar bozuksa kırpılmaz: orijinal kaydı korumak için decode reddedilir.
local Financial = {}

local function finite(value: any, minimum: number, maximum: number): boolean
	return typeof(value) == "number" and value == value and value >= minimum and value <= maximum
end

local function integer(value: any, minimum: number, maximum: number): boolean
	return typeof(value) == "number" and value == value and value >= minimum and value <= maximum and value % 1 == 0
end

function Financial.decode(source: any, config: any, now: number): any?
	local gold = if source.gold == nil then 0 else source.gold
	if not integer(gold, 0, config.PROGRESSION.gold.maxBalance) then
		return nil
	end
	local earnedItems: { [string]: boolean } = {}
	for _, milestone in config.PROGRESSION.milestones do
		if milestone.itemId then
			earnedItems[milestone.itemId] = true
		end
	end
	local owned: any = { items = {}, conveniences = {} }
	if source.owned ~= nil then
		if
			typeof(source.owned) ~= "table"
			or typeof(source.owned.items) ~= "table"
			or typeof(source.owned.conveniences) ~= "table"
		then
			return nil
		end
		local groups: { [string]: any } = { items = source.owned.items, conveniences = source.owned.conveniences }
		for kind, values in groups do
			for id, value in values :: any do
				local offer: any = config.PROGRESSION.permanentOffers[id]
				local expectedKind = if kind == "items" then "item" else "convenience"
				if
					value ~= true
					or (not (offer and offer.kind == expectedKind) and not (kind == "items" and earnedItems[id]))
				then
					return nil
				end
				owned[kind][id] = true
			end
		end
	end
	local progression: any = {
		run = 1,
		count = 0,
		perks = {},
		claims = {},
		startedAt = now,
		returnEndsAt = 0,
		returnEnded = true,
		runEarnedBase = 0,
		convertedDay = -1,
		convertedDayGold = 0,
		convertedRunGold = 0,
		runDouble = false,
		doubleCredits = 0,
	}
	if source.progression ~= nil then
		local raw: any = source.progression
		if
			typeof(raw) ~= "table"
			or typeof(raw.perks) ~= "table"
			or (raw.claims ~= nil and typeof(raw.claims) ~= "table")
		then
			return nil
		end
		local bounds: { [string]: { number } } = {
			run = { 1, 1e9 },
			count = { 0, 1e9 },
			startedAt = { 0, 1e12 },
			returnEndsAt = { 0, 1e12 },
			runEarnedBase = { 0, 1e18 },
			convertedDay = { -1, 1e7 },
			convertedDayGold = { 0, config.PROGRESSION.gold.dailyLimit },
			convertedRunGold = { 0, config.PROGRESSION.gold.runLimit },
		}
		for key, limits in bounds do
			local continuous = key == "startedAt" or key == "returnEndsAt" or key == "runEarnedBase"
			if
				not (
					if continuous
						then finite(raw[key], limits[1], limits[2])
						else integer(raw[key], limits[1], limits[2])
				)
			then
				return nil
			end
			progression[key] = raw[key]
		end
		if raw.run ~= raw.count + 1 or typeof(raw.returnEnded) ~= "boolean" or typeof(raw.runDouble) ~= "boolean" then
			return nil
		end
		progression.returnEnded, progression.runDouble = raw.returnEnded, raw.runDouble
		progression.doubleCredits = if raw.doubleCredits == nil then 0 else raw.doubleCredits
		if not integer(progression.doubleCredits, 0, 1e9) then
			return nil
		end
		local perkTotal = 0
		for id, level in raw.perks do
			local perk = config.PROGRESSION.perks[id]
			if not perk or not integer(level, 0, perk.maxLevel) then
				return nil
			end
			progression.perks[id] = level
			perkTotal += level
		end
		if perkTotal ~= math.min(raw.count, 40) then
			return nil
		end
		-- Eski ada/çiftlik hak anahtarları (`island:*`, `farm:*`) artık anlam taşımaz; zararsızca atılır.
		-- Yalnız R30 son tur ödülü işareti (`terminal`) korunur.
		for id, done in (raw.claims or {}) :: { [any]: any } do
			if typeof(id) ~= "string" then
				return nil
			end
			if id == "terminal" and done == true and raw.count >= config.PROGRESSION.maxRebirth then
				progression.claims.terminal = true
			end
		end
	end
	return { gold = gold, owned = owned, progression = progression }
end

local function clone(value: any): any
	if typeof(value) ~= "table" then
		return value
	end
	local result = {}
	for key, entry in value do
		result[key] = clone(entry)
	end
	return result
end

function Financial.encode(save: any): any
	return { gold = save.gold, owned = clone(save.owned), progression = clone(save.progression) }
end

return Financial
