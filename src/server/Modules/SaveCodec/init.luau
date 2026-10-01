--!strict
-- Roblox bağımsız şema sınırı. Config/FarmMath/UID üreteci testlerde enjekte edilir.
-- Tek giriş (decode/encode/newFarm); alan başına parçalar (Modules/SaveCodec/): Common, Goods (depo+sipariş), Inventory,
-- Tasks (hayvan görevi), Production (üretim kuyruğu), Animals, Account (hesap alanları), Farm (tek çiftlik kaydı).
local SessionLock = require(script.Parent.SessionLock)
local FarmProfiles = require(script.Parent.FarmProfiles)
local Common = require(script.Common)
local Goods = require(script.Goods)
local Inventory = require(script.Inventory)
local Account = require(script.Account)
local Farm = require(script.Farm)

local SaveCodec = {}

-- farmId: çiftlik numarası; başlangıç hayvanı temanın ana ada hayvanı olur
-- tier: alım sırası (1 = ilk çiftlik); fiyat çarpanını belirler
function SaveCodec.newFarm(
	config: any,
	farmMath: any,
	now: number,
	newUid: () -> string,
	farmId: string?,
	tier: number?
): any
	local farm = assert(
		Farm.decode({ farmId = farmId, tier = tier }, config, farmMath, now, newUid),
		"New farm initialization failed"
	)
	return FarmProfiles.extract(farm)
end

function SaveCodec.decode(
	raw: unknown,
	config: any,
	farmMath: any,
	now: number,
	newUid: () -> string
): (any?, number, string?, number?, number?)
	local problem = SessionLock.validate(raw)
	if problem then
		return nil, 0, problem
	end
	local source: any = if typeof(raw) == "table" then raw else {}
	if source.version ~= SessionLock.VERSION and source.mainFarms == nil then
		local data, earned, err, repairs, grown = Farm.decode(raw, config, farmMath, now, newUid)
		if data then
			FarmProfiles.ensure(data)
			-- Yeni ya da eski tek çiftlikli kayıtlar boş envanterle başlar
			data.inventory = data.inventory or { items = {}, equipped = {}, uses = {} }
		end
		return data, earned, err, repairs, grown
	end
	if typeof(source.mainFarms) ~= "table" or typeof(source.activeMainFarmId) ~= "string" then
		return nil, 0, "Çiftlik kayıtları geçersiz; orijinal kayıt korunuyor"
	end
	local farms = {}
	local count, earnedTotal, repairTotal, refundedTotal, grownTotal = 0, 0, 0, 0, 0
	-- Eski kayıtlarda depo ve sipariş çiftlik içindeydi: hepsi toplanıp hesap düzeyine taşınır
	local legacyGoods: { [string]: number } = {}
	local legacyContracts: any = nil
	-- Eski kayıtlarda alım sırası yoktu: eksik tier = 1 (var olan çiftliklerin fiyatı geriye dönük artmaz).
	-- Yalnızca bundan sonra satın alınan çiftlik sıradaki tier'ı alır (MainFarmService). tier çiftlik sayısını aşamaz.
	local farmTotal = 0
	for _ in source.mainFarms do
		farmTotal += 1
	end
	for id, rawFarm in source.mainFarms do
		count += 1
		local numberId = if typeof(id) == "string" then tonumber(id) else nil
		if
			count > config.MAIN_FARM_LIMIT
			or not numberId
			or numberId % 1 ~= 0
			or numberId < 1
			or numberId > config.MAIN_FARM_LIMIT
			or tostring(numberId) ~= id
			or typeof(rawFarm) ~= "table"
		then
			return nil, 0, "Çiftlik kimliği geçersiz; orijinal kayıt korunuyor"
		end
		local farmInput = table.clone(rawFarm)
		farmInput.farmId = id
		if id == "1" then
			farmInput.tier = 1 -- ilk çiftlik her zaman x1
		elseif SessionLock.isFinite(farmInput.tier) then
			farmInput.tier = math.min(farmInput.tier, math.max(farmTotal, 1))
		end
		farmInput.cash = 0 -- Cüzdan sadece kök kayıttan gelir; taşıma iadeleri ayrıca eklenir.
		local farm, earned, err, repairs, grown = Farm.decode(farmInput, config, farmMath, now, newUid)
		if not farm then
			return nil, 0, err
		end
		for goodId, amountStored in farm.goods or {} do
			legacyGoods[goodId] = (legacyGoods[goodId] or 0) + amountStored
		end
		if id == source.activeMainFarmId then
			legacyContracts = farm.contracts
		end
		farms[id] = FarmProfiles.extract(farm)
		refundedTotal += farm.cash
		earnedTotal += earned
		repairTotal += repairs or 0
		grownTotal += grown or 0
	end
	if not farms["1"] or not farms[source.activeMainFarmId] then
		return nil, 0, "Etkin çiftlik kaydı eksik; orijinal kayıt korunuyor"
	end
	local data: any = FarmProfiles.extract(farms[source.activeMainFarmId])
	data.cash = math.min(
		Common.MAX_MONEY,
		Common.amount(source.cash, config.getStartingCash(source.activeMainFarmId)) + refundedTotal
	)
	data.mainFarms = farms
	data.activeMainFarmId = source.activeMainFarmId
	-- Ortak ahır deposu (limit: tüm ahırların toplamı) ve ahır siparişleri
	local accountGoods: { [string]: number }
	if source.goods ~= nil then
		local parsed, fixed = Goods.parseGoods(source.goods, config, 1e9)
		if not parsed then
			return nil, 0, "Ahır deposu kaydı bozuk; orijinal kayıt korunuyor"
		end
		accountGoods = parsed
		repairTotal += fixed
	else
		accountGoods = legacyGoods
	end
	local goodsCap = farmMath.getGoodsCap(data)
	for goodId, stored in accountGoods do
		accountGoods[goodId] = math.min(stored, goodsCap)
	end
	data.goods = accountGoods
	data.contracts = { window = 0, done = {}, completed = 0 }
	if source.contracts ~= nil then
		local parsed, fixed = Goods.parseContracts(source.contracts, config)
		if not parsed then
			return nil, 0, "Ahır siparişi kaydı bozuk; orijinal kayıt korunuyor"
		end
		data.contracts = parsed
		repairTotal += fixed
	elseif legacyContracts then
		data.contracts = legacyContracts
	end
	Account.decode(source, data, config)
	data.inventory = Inventory.decode(source.inventory, config)
	Account.decodeLedger(source, data, config)
	return data, earnedTotal, nil, repairTotal, grownTotal
end

function SaveCodec.encode(save: any, now: number): { [string]: any }
	FarmProfiles.capture(save)
	local farms = {}
	for id, farm in save.mainFarms do
		farms[id] = Farm.encode(farm, now)
		farms[id].cash = 0
	end
	return {
		version = SessionLock.VERSION,
		cash = Common.amount(save.cash, 0),
		mainFarms = farms,
		activeMainFarmId = save.activeMainFarmId,
		language = save.language,
		graphics = save.graphics,
		audio = save.audio,
		reducedMotion = save.reducedMotion,
		lifetimeEarned = Common.amount(save.lifetimeEarned, 0),
		daily = save.daily,
		achievements = save.achievements,
		seasonal = save.seasonal,
		merchant = save.merchant,
		golden = save.golden,
		inventory = Inventory.encode(save.inventory),
		goods = Goods.encodeGoods(save.goods),
		contracts = Goods.encodeContracts(save.contracts),
		receipts = save.receipts,
		lastSeen = now,
	}
end

return SaveCodec
