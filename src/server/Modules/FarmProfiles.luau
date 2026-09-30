--!strict
-- Eski düz kayıt etkin çiftliğin görünümüdür. Cüzdan tek, çiftlik envanterleri ayrıdır.
local FarmProfiles = {}
local FIELDS = {
	"stored",
	"purchased",
	"lineage",
	"goods",
	"expansions",
	"animals",
	"ordersCompleted",
	"order",
	"production",
	"barnLevel",
	"unlockedIslands",
	"unlockedZones",
}

function FarmProfiles.extract(data: any): any
	local farm = {}
	for _, key in FIELDS do
		farm[key] = data[key]
	end
	return farm
end

function FarmProfiles.ensure(data: any)
	if not data.mainFarms then
		data.activeMainFarmId = "1"
		data.mainFarms = { ["1"] = FarmProfiles.extract(data) }
	end
end

function FarmProfiles.capture(data: any)
	FarmProfiles.ensure(data)
	local farm = data.mainFarms[data.activeMainFarmId]
	assert(farm, "Active farm record missing")
	for _, key in FIELDS do
		farm[key] = data[key]
	end
end

function FarmProfiles.select(data: any, farmId: string): boolean
	FarmProfiles.capture(data)
	local farm = data.mainFarms[farmId]
	if not farm then
		return false
	end
	for _, key in FIELDS do
		data[key] = farm[key]
	end
	data.activeMainFarmId = farmId
	return true
end

function FarmProfiles.view(data: any, farmId: string): any
	FarmProfiles.capture(data)
	if farmId == data.activeMainFarmId then
		return data
	end
	local farm = data.mainFarms[farmId]
	if farm then
		farm.cash = data.cash
		farm.farmId = farmId
		farm.passes = data.passes -- Oyun geçitleri hesap düzeyindedir; etkin olmayan çiftliğe de uygulanır
		farm.inventory = data.inventory -- Envanter de hesap düzeyindedir: takılı eşyalar her çiftliğin gelirini etkiler
		farm.envOverride = data.envOverride -- Asa ile oyuncuya özel mevsim/hava her çiftliğin gelirini etkiler
	end
	return farm
end

function FarmProfiles.ids(data: any): { string }
	FarmProfiles.ensure(data)
	local ids = {}
	for id in data.mainFarms do
		table.insert(ids, id)
	end
	table.sort(ids, function(a: string, b: string): boolean
		return tonumber(a) < tonumber(b)
	end)
	return ids
end

function FarmProfiles.summaries(data: any, plotId: ((string) -> string?)?): { any }
	FarmProfiles.capture(data)
	local result = {}
	for _, id in FarmProfiles.ids(data) do
		local farm = data.mainFarms[id]
		local purchasedCount = 0
		for _, owned in farm.purchased do
			if owned then
				purchasedCount += 1
			end
		end
		table.insert(result, {
			id = id,
			plotId = if plotId then plotId(id) else nil,
			active = id == data.activeMainFarmId,
			animalCount = #farm.animals,
			purchasedCount = purchasedCount,
			stored = farm.stored,
		})
	end
	return result
end

return FarmProfiles
