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

local MAX_TASK_SECONDS = 86400

-- Hayvanın süreli görevi (üretim/eklenti): bozuk ya da tanınmayan kayıt görev yok sayılır (hayvan korunur).
local function decodeTask(value: any, config: any): any?
	if typeof(value) ~= "table" then
		return nil
	end
	local kind, id = value.kind, value.id
	if (kind ~= "production" and kind ~= "extension") or typeof(id) ~= "string" then
		return nil
	end
	if
		(kind == "production" and not config.PRODUCTION_RECIPES[id])
		or (kind == "extension" and not config.getExtension(id))
	then
		return nil
	end
	local startedAt, endsAt = value.startedAt, value.endsAt
	if
		not SessionLock.isFinite(startedAt)
		or not SessionLock.isFinite(endsAt)
		or startedAt < 0
		or endsAt <= startedAt
		or endsAt > 1e12
		or endsAt - startedAt > MAX_TASK_SECONDS
	then
		return nil
	end
	return { kind = kind, id = id, startedAt = startedAt, endsAt = endsAt }
end

-- Ahır deposu ve ahır siparişleri hesap düzeyindedir. Eski kayıtlarda çiftlik içinde durur (decodeFarm bunları okur,
-- üst düzey decode hepsini toplar). Ortak ayrıştırıcılar: bozuk girdi atılır, sayılar sıkıştırılır.
local function parseGoods(raw: any, config: any, cap: number): ({ [string]: number }?, number)
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

local function parseContracts(raw: any, config: any): (any?, number)
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
		if typeof(key) == "string" and #key <= 24 and flag == true and kept < #config.GOODS_CONTRACTS.tiers then
			kept += 1
			contracts.done[key] = true
		else
			repairs += 1
		end
	end
	return contracts, repairs
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
		cash = amount(
			source.cash,
			config.getStartingCash(if typeof(source.farmId) == "string" then source.farmId else "1")
		),
		stored = amount(source.stored, 0),
		purchased = {},
		animals = {},
		barnLevel = 1,
		unlockedIslands = {},
		unlockedZones = {},
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
	-- Ahır siparişleri ve deposu (isteğe bağlı; yeni kayıtlarda hesap düzeyinde, eski kayıtlarda çiftlik içinde)
	save.contracts = { window = 0, done = {}, completed = 0 }
	if source.contracts ~= nil then
		local parsed, fixed = parseContracts(source.contracts, config)
		if not parsed then
			return nil, 0, "Ahır siparişi kaydı bozuk; orijinal kayıt korunuyor"
		end
		save.contracts = parsed
		repairs += fixed
	end
	save.goods = {}
	if source.goods ~= nil then
		local parsed, fixed = parseGoods(source.goods, config, farmMath.getGoodsCap(save))
		if not parsed then
			return nil, 0, "Ahır deposu kaydı bozuk; orijinal kayıt korunuyor"
		end
		save.goods = parsed
		repairs += fixed
	end
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
			-- startedAt/forgone eski kayıtlarda yoktur (hayvan verilmemiş işler; ödül tabanı uygulanmaz)
			local startedAt: number? = nil
			if SessionLock.isFinite(job.startedAt) and job.startedAt >= 0 and job.startedAt <= job.readyAt then
				startedAt = job.startedAt
			end
			local forgone: number? = nil
			if SessionLock.isFinite(job.forgone) and job.forgone >= 0 then
				forgone = math.min(job.forgone, 1e15)
			end
			-- Parti kimliği yalnızca tarifin tanıdığı bir seçenek olabilir (yoksa ilk seçenek sayılır)
			local optionId: string? = nil
			if typeof(job.optionId) == "string" and recipe.options then
				for _, option in recipe.options do
					if option.id == job.optionId then
						optionId = option.id
					end
				end
			end
			save.production[recipeId] = {
				uid = job.uid,
				readyAt = job.readyAt,
				startedAt = startedAt,
				forgone = forgone,
				optionId = optionId,
			}
		end
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
			-- Eski kayıt: eklentiye kalıcı atanmış hayvan (görev yok). Ana bölge dolu sayılsa da kaybolmaz; eve döner.
			local task = decodeTask(entry.task, config)
			local legacyExtension = task == nil and typeof(entry.extensionId) == "string" and entry.extensionId ~= ""
			if
				not zone
				or not save.unlockedZones[zoneId]
				or not farmMath.zoneAllows(save, zone, animalId)
				or (
					not legacyExtension
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
			-- Eklenti görevi yalnızca satın alınmış eklentide, doğru tür/bölge ve kapasite içinde geçerlidir;
			-- eski kalıcı atamalar (görevsiz extensionId) eve döner.
			local extensionId: string? = nil
			if legacyExtension then
				repairs += 1
			end
			if task and task.kind == "extension" then
				local extension = config.getExtension(task.id)
				local upgrade = if extension then config.getExtensionUpgrade(extension.id) else nil
				if
					extension
					and upgrade
					and save.purchased[upgrade.id]
					and animalId == extension.animalId
					and zoneId == extension.sourceZoneId
					and farmMath.countInExtension(save, extension.id, task.startedAt)
						< farmMath.getExtensionCapacity(save, extension.id)
				then
					extensionId = extension.id
				else
					task = nil
					repairs += 1
				end
			elseif task and task.kind == "production" then
				local recipe = config.PRODUCTION_RECIPES[task.id]
				if not recipe or not save.production[recipe.id] or not table.find(recipe.animalIds, animalId) then
					task = nil
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
				task = task,
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
	-- Çevrimdışıyken süresi dolan görevler (tesis/eklenti) bitti: hayvanlar ana bölgesine döner. Gelir yukarıda
	-- görev penceresiyle hesaplandı.
	for _, animal in save.animals do
		if animal.task and animal.task.endsAt <= now then
			animal.task = nil
			animal.extensionId = nil
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
			task = animal.task,
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
		production[recipeId] = {
			uid = job.uid,
			readyAt = job.readyAt,
			startedAt = job.startedAt,
			forgone = job.forgone,
			optionId = job.optionId,
		}
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
	-- Eski kayıtlarda depo ve sipariş çiftlik içindeydi: hepsi toplanıp hesap düzeyine taşınır
	local legacyGoods: { [string]: number } = {}
	local legacyContracts: any = nil
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
	data.cash = math.min(1e15, amount(source.cash, config.getStartingCash(source.activeMainFarmId)) + refundedTotal)
	data.mainFarms = farms
	data.activeMainFarmId = source.activeMainFarmId
	-- Ortak ahır deposu (limit: tüm ahırların toplamı) ve ahır siparişleri
	local accountGoods: { [string]: number }
	if source.goods ~= nil then
		local parsed, fixed = parseGoods(source.goods, config, 1e9)
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
		local parsed, fixed = parseContracts(source.contracts, config)
		if not parsed then
			return nil, 0, "Ahır siparişi kaydı bozuk; orijinal kayıt korunuyor"
		end
		data.contracts = parsed
		repairTotal += fixed
	elseif legacyContracts then
		data.contracts = legacyContracts
	end
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

local function encodeGoods(goods: any): { [string]: number }
	local result = {}
	for goodId, count in if goods then goods else {} do
		if count > 0 then
			result[goodId] = count
		end
	end
	return result
end

local function encodeContracts(contracts: any): any
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
		goods = encodeGoods(save.goods),
		contracts = encodeContracts(save.contracts),
		receipts = save.receipts,
		lastSeen = now,
	}
end

return SaveCodec
