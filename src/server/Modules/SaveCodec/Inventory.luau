--!strict
-- Envanter (hesap düzeyi, isteğe bağlı): tanınmayan eşya atılır; takılı eşya sahipli ve kendi slotunda olmalı; hak kayıtları sınırlanır.
local SessionLock = require(script.Parent.Parent.SessionLock)

local Inventory = {}

function Inventory.decode(rawInventory: any, config: any): any
	local inventory: any = { items = {}, equipped = {}, uses = {} }
	if typeof(rawInventory) == "table" then
		if typeof(rawInventory.items) == "table" then
			for _, id in rawInventory.items do
				if typeof(id) == "string" and config.ITEMS[id] then
					inventory.items[id] = true
				end
			end
		end
		if typeof(rawInventory.equipped) == "table" then
			for slot, id in rawInventory.equipped do
				local item = if typeof(id) == "string" then config.ITEMS[id] else nil
				if typeof(slot) == "string" and item and item.slot == slot and inventory.items[id] then
					inventory.equipped[slot] = id
				end
			end
		end
		if typeof(rawInventory.uses) == "table" then
			for kind, entry in rawInventory.uses do
				if
					(
						kind == "season"
						or kind == "weather"
						or kind == "growth"
						or kind == "rush"
						or kind == "care"
						or kind == "collect"
					)
					and typeof(entry) == "table"
					and SessionLock.isFinite(entry.day)
					and SessionLock.isFinite(entry.count)
					and SessionLock.isFinite(entry.last)
				then
					inventory.uses[kind] = {
						day = math.clamp(math.floor(entry.day), 0, 1e7),
						count = math.clamp(math.floor(entry.count), 0, 1000),
						last = math.clamp(entry.last, 0, 1e12),
					}
				end
			end
		end
	end
	return inventory
end

function Inventory.encode(inventory: any): { [string]: any }
	local items = {}
	for id, owned in if inventory and inventory.items then inventory.items else {} do
		if owned then
			table.insert(items, id)
		end
	end
	table.sort(items)
	local uses = {}
	for kind, entry in if inventory and inventory.uses then inventory.uses else {} do
		uses[kind] = { day = entry.day, count = entry.count, last = entry.last }
	end
	return { items = items, equipped = if inventory then inventory.equipped or {} else {}, uses = uses }
end

return Inventory
