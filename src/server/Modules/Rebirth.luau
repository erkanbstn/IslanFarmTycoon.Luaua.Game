--!strict
-- Sıfırlama saf ve tek kayıt üzerindedir; finansal haklar ve işlem işaretleri hiçbir zaman silinmez.
local Rebirth = {}

function Rebirth.apply(
	data: any,
	config: any,
	farmMath: any,
	progression: any,
	codec: any,
	now: number,
	newUid: () -> string,
	perkId: string
): boolean
	if not progression.canRebirth(data) or not progression.canChoosePerk(data, perkId) then
		return false
	end
	if data.transfers and (data.transfers.quarantined or next(data.transfers.outbox) ~= nil) then
		return false
	end
	local state = data.progression
	progression.collectGold(data, now)
	local claimed = 0
	for _ in state.claims do
		claimed += 1
	end
	if claimed < config.MAIN_FARM_LIMIT * 5 then
		return false
	end
	state.count += 1
	state.run += 1
	if perkId ~= "prestige" then
		state.perks[perkId] = (state.perks[perkId] or 0) + 1
	end
	state.claims = {}
	state.startedAt = now
	state.returnEndsAt = now + config.PROGRESSION.returnSeconds
	state.returnEnded = false
	state.runEarnedBase = data.lifetimeEarned or 0
	state.convertedRunGold = 0
	state.runDouble = (state.doubleCredits or 0) > 0
	if state.runDouble then
		state.doubleCredits -= 1
	end
	data.activeMainFarmId = "1"
	data.mainFarms = { ["1"] = codec.newFarm(config, farmMath, now, newUid, "1") }
	local farm = data.mainFarms["1"]
	for key, value in farm do
		data[key] = value
	end
	data.cash = progression.getStartingCash(data, "1")
	data.goods, data.contracts, data.achievements = {}, { window = 0, done = {}, completed = 0 }, {}
	data.seasonal, data.envOverride, data.adminForce = nil, nil, nil
	local previousInventory = data.inventory
	data.inventory = { items = {}, equipped = {}, uses = if previousInventory then previousInventory.uses else {} }
	for id in data.owned.items do
		data.inventory.items[id] = true
	end
	for slot, id in if previousInventory then previousInventory.equipped else {} do
		if data.owned.items[id] then
			data.inventory.equipped[slot] = id
		end
	end
	farmMath.applyDerived(data)
	progression.applyReadyStart(data, now, newUid)
	return true
end

return Rebirth
