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
	-- Irk seviyeleri (isteğe bağlı): tanınmayan tür atılır, seviye 1..maxLevel'a sıkıştırılır
	save.lineage = {}
	if source.lineage ~= nil then
		if typeof(source.lineage) ~= "table" then
			return nil, 0, "Irk kaydı bozuk; orijinal kayıt korunuyor"
		end
		for animalId, level in source.lineage do
			if typeof(animalId) == "string" and config.ANIMALS[animalId] and SessionLock.isFinite(level) then
				local clamped = math.clamp(math.floor(level), 0, config.LINEAGE.maxLevel)
				if clamped > 0 then
					save.lineage[animalId] = clamped
				end
			else
				repairs += 1
			end
		end
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
	-- Yapı geliştirme seviyeleri (isteğe bağlı; bölge ya da tesis): tanınmayan hedef atılır, seviye sıkıştırılır
	save.expansions = {}
	if source.expansions ~= nil then
		if typeof(source.expansions) ~= "table" then
			return nil, 0, "Alan genişletme kaydı bozuk; orijinal kayıt korunuyor"
		end
		for zoneId, level in source.expansions do
			local known = typeof(zoneId) == "string" and (config.ZONES[zoneId] or config.PRODUCTION_RECIPES[zoneId])
			if known and SessionLock.isFinite(level) then
				local clamped = math.clamp(math.floor(level), 0, config.BUILD_UPGRADES.maxLevel)
				if clamped > 0 then
					save.expansions[zoneId] = clamped
				end
			else
				repairs += 1
			end
		end
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
				or (
					not pendingExtension
					and farmMath.countInZone(save, zoneId) >= farmMath.getZoneCapacity(save, zoneId)
				)
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
				stage = farmMath.getStage(bornAt, now, farmMath.getGrowthSpeed(save, animalId, zoneId)),
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
						farmMath.getGrowthSpeed(save, animal.animalId, animal.zoneId)
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
	local expansions = {}
	for zoneId, level in save.expansions or {} do
		if level > 0 then
			expansions[zoneId] = level
		end
	end
	local lineage = {}
	for animalId, level in save.lineage or {} do
		if level > 0 then
			lineage[animalId] = level
		end
	end
	local production = {}
	for recipeId, job in save.production or {} do
		production[recipeId] = { uid = job.uid, readyAt = job.readyAt }
	end
	return {
		version = 3,
		production = production,
		lineage = lineage,
		expansions = expansions,
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
	-- Grafik tercihi: yalnızca bilinen modlar kabul edilir
	if typeof(source.graphics) == "string" and config.GRAPHICS_MODES and config.GRAPHICS_MODES[source.graphics] then
		data.graphics = source.graphics
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
	-- Mevsim hedefi (isteğe bağlı): bozuk kayıt sessizce atılır, yeni mevsimde yenisi oluşur
	local seasonal = source.seasonal
	if
		typeof(seasonal) == "table"
		and SessionLock.isFinite(seasonal.key)
		and seasonal.key >= 0
		and seasonal.key <= 1e9
		and seasonal.key % 1 == 0
		and SessionLock.isFinite(seasonal.progress)
		and seasonal.progress >= 0
		and seasonal.progress <= 1e15
		and SessionLock.isFinite(seasonal.target)
		and seasonal.target > 0
		and seasonal.target <= 1e15
		and SessionLock.isFinite(seasonal.base)
		and seasonal.base >= 0
		and seasonal.base <= 1e18
		and typeof(seasonal.claimed) == "boolean"
	then
		data.seasonal = {
			key = seasonal.key,
			progress = math.min(seasonal.progress, seasonal.target),
			target = seasonal.target,
			base = seasonal.base,
			claimed = seasonal.claimed,
		}
	end
	-- Gezgin tüccar (isteğe bağlı): yalnızca geçerli döngü numarası ve alındı işareti kabul edilir
	local merchant = source.merchant
	if
		typeof(merchant) == "table"
		and SessionLock.isFinite(merchant.key)
		and merchant.key >= 0
		and merchant.key <= 1e9
		and merchant.key % 1 == 0
		and typeof(merchant.bought) == "boolean"
	then
		data.merchant = { key = merchant.key, bought = merchant.bought }
	end
	-- Altın hayvan (isteğe bağlı): yalnızca geçerli döngü numarası kabul edilir
	local golden = source.golden
	if
		typeof(golden) == "table"
		and SessionLock.isFinite(golden.key)
		and golden.key >= 0
		and golden.key <= 1e9
		and golden.key % 1 == 0
	then
		data.golden = { key = golden.key }
	end
	-- Envanter (isteğe bağlı): tanınmayan eşya atılır; takılı eşya sahipli ve kendi slotunda olmalı; hak kayıtları sınırlanır
	local inventory: any = { items = {}, equipped = {}, uses = {} }
	local rawInventory = source.inventory
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
					(kind == "season" or kind == "weather")
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
	data.inventory = inventory
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

local function encodeInventory(inventory: any): { [string]: any }
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
		graphics = save.graphics,
		lifetimeEarned = amount(save.lifetimeEarned, 0),
		daily = save.daily,
		achievements = save.achievements,
		seasonal = save.seasonal,
		merchant = save.merchant,
		golden = save.golden,
		inventory = encodeInventory(save.inventory),
		receipts = save.receipts,
		lastSeen = now,
	}
end

return SaveCodec
