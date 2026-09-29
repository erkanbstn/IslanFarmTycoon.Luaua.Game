--!strict
-- Roblox bağımsız şema sınırı. Config/FarmMath/UID üreteci testlerde enjekte edilir.
local SessionLock = require(script.Parent.SessionLock)
local FarmProfiles = require(script.Parent.FarmProfiles)

local SaveCodec = {}
local MAX_MONEY = 1e15
local MAX_INPUT_ANIMALS = 1000

local function amount(value: unknown, fallback: number): number
	return if SessionLock.isFinite(value) then math.clamp(value :: number, 0, MAX_MONEY) else fallback
end

local function decodeFarm(
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
	local source: { [string]: any } = if typeof(raw) == "table" then raw :: { [string]: any } else {}
	if source.animals ~= nil and typeof(source.animals) ~= "table" then
		return nil, 0, "Hayvan kaydı bozuk; orijinal kayıt korunuyor"
	end
	if source.purchased ~= nil and typeof(source.purchased) ~= "table" then
		return nil, 0, "Yükseltme kaydı bozuk; orijinal kayıt korunuyor"
	end
	local repairs = 0
	-- V1/V2 → V3: eski yükseltmeler normalleştirilir; eksik üretim kuyruğu boş başlar.
	local save: any = {
		cash = amount(source.cash, config.STARTING_CASH),
		stored = amount(source.stored, 0),
		purchased = {},
		animals = {},
		barnLevel = 1,
		unlockedIslands = {},
		unlockedZones = {},
		ordersCompleted = math.floor(amount(source.ordersCompleted, 0)),
		order = nil,
		production = {},
		farmId = if typeof(source.farmId) == "string" then source.farmId else "1",
	}
	if source.cash ~= nil and save.cash ~= source.cash then
		repairs += 1
	end
	if source.stored ~= nil and save.stored ~= source.stored then
		repairs += 1
	end
	if typeof(source.purchased) == "table" then
		for _, id in source.purchased do
			if typeof(id) == "string" then
				local resolved = config.LEGACY_UPGRADES[id] or id
				if config.getUpgrade(resolved) then
					save.purchased[resolved] = true
				else
					repairs += 1
				end
			else
				repairs += 1
			end
		end
	end
	farmMath.applyDerived(save)
	if source.production ~= nil then
		if typeof(source.production) ~= "table" then
			return nil, 0, "Üretim kaydı bozuk; orijinal kayıt korunuyor"
		end
		local count = 0
		local seenJobs: { [string]: boolean } = {}
		for recipeId, job in source.production do
			count += 1
			local recipe = if typeof(recipeId) == "string" then config.PRODUCTION_RECIPES[recipeId] else nil
			if
				count > #config.PRODUCTION_ORDER
				or not recipe
				or typeof(job) ~= "table"
				or typeof(job.uid) ~= "string"
				or #job.uid == 0
				or #job.uid > 64
				or seenJobs[job.uid]
				or not SessionLock.isFinite(job.readyAt)
				or job.readyAt < 0
				or job.readyAt > 1e12
				or not save.purchased[recipe.upgradeId]
				or not save.unlockedIslands[recipe.island]
			then
				return nil, 0, "Üretim kaydı geçersiz; orijinal kayıt korunuyor"
			end
			seenJobs[job.uid] = true
			save.production[recipeId] = { uid = job.uid, readyAt = job.readyAt }
		end
	end
	if source.order ~= nil then
		local order = source.order
		if
			typeof(order) ~= "table"
			or typeof(order.uid) ~= "string"
			or #order.uid == 0
			or #order.uid > 64
			or typeof(order.animalId) ~= "string"
			or not config.ANIMALS[order.animalId]
		then
			return nil, 0, "Sipariş kaydı geçersiz; orijinal kayıt korunuyor"
		end
		-- Panodan seçilen sipariş farklı hedef ve ödül çarpanı taşıyabilir; ikisi de sınırlanır.
		local maxUnits = config.ORDER_UNITS
		for _, tier in config.ORDER_TIERS do
			maxUnits = math.max(maxUnits, tier.units)
		end
		local target = if SessionLock.isFinite(order.target)
			then math.clamp(math.floor(order.target), 1, maxUnits)
			else config.ORDER_UNITS
		local factor = if SessionLock.isFinite(order.rewardFactor) then math.clamp(order.rewardFactor, 0.5, 3) else 1
		save.order = {
			uid = order.uid,
			animalId = order.animalId,
			progress = math.clamp(amount(order.progress, 0), 0, target),
			target = target,
			rewardFactor = factor,
		}
	end
	local seen: { [string]: boolean } = {}
	local function uniqueUid(candidate: unknown): string
		local uid = if typeof(candidate) == "string"
				and #candidate > 0
				and #candidate <= 64
			then candidate
			else newUid()
		while seen[uid] do
			uid = newUid()
		end
		if candidate ~= nil and candidate ~= uid then
			repairs += 1
		end
		seen[uid] = true
		return uid
	end
	if typeof(source.animals) == "table" then
		local count = 0
		for _, entry in source.animals do
			count += 1
			if count > MAX_INPUT_ANIMALS then
				return nil, 0, "Hayvan kaydı sınırı aşıldı"
			end
			if typeof(entry) ~= "table" or typeof(entry.animalId) ~= "string" or not config.ANIMALS[entry.animalId] then
				return nil, 0, "Tanınmayan hayvan kaydı; orijinal kayıt korunuyor"
			end
			local animalId = entry.animalId
			local zoneId = entry.zoneId
			local zone = if typeof(zoneId) == "string" then config.ZONES[zoneId] else nil
			local pendingExtension = typeof(entry.extensionId) == "string" and entry.extensionId ~= ""
			if
				not zone
				or not save.unlockedZones[zoneId]
				or not farmMath.zoneAllows(save, zone, animalId)
				or (not pendingExtension and farmMath.countInZone(save, zoneId) >= zone.capacity)
			then
				zoneId = farmMath.findZoneForAnimal(save, animalId)
				repairs += 1
			end
			if not zoneId then
				-- Geçerli eski hayvanın yeri kalkmış/dolmuşsa tek seferlik taban fiyat iadesi.
				save.cash = math.min(MAX_MONEY, save.cash + config.ANIMALS[animalId].price)
				continue
			end
			local bornAt = if SessionLock.isFinite(entry.bornAt) then math.clamp(entry.bornAt, 0, now) else 0
			if bornAt ~= entry.bornAt then
				repairs += 1
			end
			local extensionId: string? = nil
			if typeof(entry.extensionId) == "string" and entry.extensionId ~= "" then
				local extension = config.getExtension(entry.extensionId)
				local upgrade = if extension then config.getExtensionUpgrade(extension.id) else nil
				if
					extension
					and upgrade
					and save.purchased[upgrade.id]
					and animalId == extension.animalId
					and zoneId == extension.sourceZoneId
					and farmMath.countInExtension(save, extension.id) < extension.capacity
				then
					extensionId = extension.id
				else
					repairs += 1
				end
			end
			table.insert(save.animals, {
				uid = uniqueUid(entry.uid),
				animalId = animalId,
				zoneId = zoneId,
				bornAt = bornAt,
				stage = farmMath.getStage(bornAt, now, farmMath.getGrowthSpeed(save, animalId)),
				extensionId = extensionId,
			})
		end
	else
		for _ = 1, config.STARTING_COW_COUNT do
			local homeAnimal = config.getHomeAnimal(save.farmId)
			local zoneId = farmMath.findZoneForAnimal(save, homeAnimal)
			if zoneId then
				table.insert(
					save.animals,
					{ uid = uniqueUid(nil), animalId = homeAnimal, zoneId = zoneId, stage = "adult", bornAt = 0 }
				)
			end
		end
	end
	save.stored = math.min(save.stored, farmMath.getStorageCap(save))
	local offlineEarned = 0
	local grown = 0
	if SessionLock.isFinite(source.lastSeen) and source.lastSeen >= 0 and source.lastSeen <= now then
		offlineEarned = farmMath.computeOfflineEarnings(save, source.lastSeen, now)
		save.cash = math.min(MAX_MONEY, save.cash + offlineEarned)
		-- Sen yokken yetişkin olan hayvanlar (dönüş özeti için)
		for _, animal in save.animals do
			if
				animal.bornAt ~= 0
				and animal.stage == "adult"
				and farmMath.getStage(
						animal.bornAt,
						source.lastSeen,
						farmMath.getGrowthSpeed(save, animal.animalId)
					)
					~= "adult"
			then
				grown += 1
			end
		end
	end
	save.farmId = nil
	return save, offlineEarned, nil, repairs, grown
end

local function encodeFarm(save: any, now: number): { [string]: any }
	local animals = {}
	for _, animal in save.animals do
		table.insert(animals, {
			uid = animal.uid,
			animalId = animal.animalId,
			zoneId = animal.zoneId,
			bornAt = animal.bornAt,
			extensionId = animal.extensionId,
		})
	end
	local purchased = {}
	for id, owned in save.purchased do
		if owned then
			table.insert(purchased, id)
		end
	end
	table.sort(purchased)
	local production = {}
	for recipeId, job in save.production or {} do
		production[recipeId] = { uid = job.uid, readyAt = job.readyAt }
	end
	return {
		version = 3,
		production = production,
		cash = amount(save.cash, 0),
		stored = amount(save.stored, 0),
		purchased = purchased,
		animals = animals,
		lastSeen = now,
		ordersCompleted = math.floor(amount(save.ordersCompleted, 0)),
		order = if save.order
			then {
				uid = save.order.uid,
				animalId = save.order.animalId,
				progress = save.order.progress,
				target = save.order.target,
				rewardFactor = save.order.rewardFactor,
			}
			else nil,
	}
end

-- farmId: çiftlik numarası; başlangıç hayvanı temanın ana ada hayvanı olur
function SaveCodec.newFarm(config: any, farmMath: any, now: number, newUid: () -> string, farmId: string?): any
	local farm =
		assert(decodeFarm({ farmId = farmId }, config, farmMath, now, newUid), "New farm initialization failed")
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
	if source.version ~= 4 and source.mainFarms == nil then
		local data, earned, err, repairs, grown = decodeFarm(raw, config, farmMath, now, newUid)
		if data then
			FarmProfiles.ensure(data)
		end
		return data, earned, err, repairs, grown
	end
	if typeof(source.mainFarms) ~= "table" or typeof(source.activeMainFarmId) ~= "string" then
		return nil, 0, "Çiftlik kayıtları geçersiz; orijinal kayıt korunuyor"
	end
	local farms = {}
	local count, earnedTotal, repairTotal, refundedTotal, grownTotal = 0, 0, 0, 0, 0
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
		farmInput.cash = 0 -- Cüzdan sadece kök kayıttan gelir; taşıma iadeleri ayrıca eklenir.
		local farm, earned, err, repairs, grown = decodeFarm(farmInput, config, farmMath, now, newUid)
		if not farm then
			return nil, 0, err
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
	data.cash = math.min(1e15, amount(source.cash, config.STARTING_CASH) + refundedTotal)
	data.mainFarms = farms
	data.activeMainFarmId = source.activeMainFarmId
	-- Arayüz dili: yalnızca Config.LANGUAGES'taki kodlar kabul edilir; bilinmeyen değer yok sayılır.
	if typeof(source.language) == "string" and config.LANGUAGES and config.LANGUAGES[source.language] then
		data.language = source.language
	end
	-- Hesap düzeyi ilerleme: ömür boyu kazanç, günlük ödül serisi ve alınmış başarımlar (hepsi isteğe bağlı).
	data.lifetimeEarned = amount(source.lifetimeEarned, 0)
	local daily = source.daily
	if
		typeof(daily) == "table"
		and SessionLock.isFinite(daily.day)
		and SessionLock.isFinite(daily.streak)
		and daily.day >= 0
		and daily.day <= 1e7
		and daily.day % 1 == 0
		and daily.streak >= 1
		and daily.streak <= #config.DAILY_REWARD_MULTIPLIERS
		and daily.streak % 1 == 0
	then
		data.daily = { day = daily.day, streak = daily.streak }
	end
	local achievements: { [string]: boolean } = {}
	if typeof(source.achievements) == "table" then
		for _, achievement in config.ACHIEVEMENTS do
			if source.achievements[achievement.id] == true then
				achievements[achievement.id] = true
			end
		end
	end
	data.achievements = achievements
	-- İşlenmiş satın alma makbuzları: yalnızca sınırlı sayıda kısa metin kimliği kabul edilir.
	local receipts: { string } = {}
	if typeof(source.receipts) == "table" then
		for _, id in source.receipts do
			if typeof(id) == "string" and #id > 0 and #id <= 40 and #receipts < 200 then
				table.insert(receipts, id)
			end
		end
	end
	data.receipts = receipts
	return data, earnedTotal, nil, repairTotal, grownTotal
end

function SaveCodec.encode(save: any, now: number): { [string]: any }
	FarmProfiles.capture(save)
	local farms = {}
	for id, farm in save.mainFarms do
		farms[id] = encodeFarm(farm, now)
		farms[id].cash = 0
	end
	return {
		version = 4,
		cash = amount(save.cash, 0),
		mainFarms = farms,
		activeMainFarmId = save.activeMainFarmId,
		language = save.language,
		lifetimeEarned = amount(save.lifetimeEarned, 0),
		daily = save.daily,
		achievements = save.achievements,
		receipts = save.receipts,
		lastSeen = now,
	}
end

return SaveCodec
