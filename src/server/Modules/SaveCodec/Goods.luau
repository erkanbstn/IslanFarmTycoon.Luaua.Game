--!strict
-- Ahır deposu ve ahır siparişleri (hesap düzeyi). Eski kayıtlarda çiftlik içinde durur (Farm bunları okur,
-- üst düzey decode hepsini toplar). Ortak ayrıştırıcılar: bozuk girdi atılır, sayılar sıkıştırılır.
local SessionLock = require(script.Parent.Parent.SessionLock)

local Goods = {}

function Goods.parseGoods(raw: any, config: any, cap: number): ({ [string]: number }?, number)
	if typeof(raw) ~= "table" then
		return nil, 0
	end
	local goods: { [string]: number } = {}
	local repairs = 0
	for goodId, count in raw do
		if typeof(goodId) == "string" and config.GOODS[goodId] and SessionLock.isFinite(count) then
			local clamped = math.clamp(math.floor(count), 0, cap)
			if clamped > 0 then
				goods[goodId] = clamped
			end
			if clamped ~= count then
				repairs += 1
			end
		else
			repairs += 1
		end
	end
	return goods, repairs
end

function Goods.parseContracts(raw: any, config: any): (any?, number)
	if typeof(raw) ~= "table" or typeof(raw.done) ~= "table" then
		return nil, 0
	end
	local contracts = { window = 0, done = {}, completed = 0 }
	local repairs = 0
	if SessionLock.isFinite(raw.window) then
		contracts.window = math.clamp(math.floor(raw.window), 0, 1e9)
	end
	if SessionLock.isFinite(raw.completed) then
		contracts.completed = math.clamp(math.floor(raw.completed), 0, 1e9)
	end
	local kept = 0
	for key, flag in raw.done do
		if typeof(key) == "string" and #key <= 24 and flag == true and kept < config.GOODS_CONTRACTS.slots then
			kept += 1
			contracts.done[key] = true
		else
			repairs += 1
		end
	end
	return contracts, repairs
end

function Goods.encodeGoods(goods: any): { [string]: number }
	local result = {}
	for goodId, count in if goods then goods else {} do
		if count > 0 then
			result[goodId] = count
		end
	end
	return result
end

function Goods.encodeContracts(contracts: any): any
	if not contracts then
		return nil
	end
	local done = {}
	for key, flag in contracts.done do
		if flag then
			done[key] = true
		end
	end
	return { window = contracts.window, done = done, completed = contracts.completed }
end

return Goods
