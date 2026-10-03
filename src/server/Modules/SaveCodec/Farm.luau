--!strict
-- Tek çiftlik kaydı (`mainFarms` girdileri ve yeni çiftlik): çiftlik alanları ve çevrimdışı kazanç. Göç yoktur (SaveCodec eski sürümü yeni oyuna çevirir).
-- Üretim, hayvan ve ahır deposu/siparişi ayrıştırıcıları kardeş modüllerdedir.
local SessionLock = require(script.Parent.Parent.SessionLock)
local Common = require(script.Parent.Common)
local Production = require(script.Parent.Production)
local Animals = require(script.Parent.Animals)

local Farm = {}

function Farm.decode(
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
	local save: any = {
		gold = source.gold,
		owned = source.owned,
		progression = source.progression,
		inventory = source.inventory,
		cash = Common.amount(
			source.cash,
			config.getStartingCash(if typeof(source.farmId) == "string" then source.farmId else "1")
		),
		stored = Common.amount(source.stored, 0),
		purchased = {},
		animals = {},
		barnLevel = 1,
		unlockedIslands = {},
		unlockedZones = {},
		production = {},
		autoRepeat = {},
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
				local upgrade = config.getUpgrade(id)
				if upgrade and config.upgradeInTheme(upgrade, save.farmId) then
					save.purchased[id] = true
				else
					-- Bilinmeyen ya da bu çiftliğin temasında olmayan yükseltme (yönetici aracı/eski kayıt) atılır:
					-- yoksa ördek çiftliğinde süt fabrikası gibi ikinci bir bina ve yanlış üretim tarifi çıkar.
					repairs += 1
				end
			else
				repairs += 1
			end
		end
	end
	farmMath.applyDerived(save)
	-- Ahır deposu ve siparişler hesap düzeyindedir (SaveCodec); çiftlik kaydında yoktur.
	save.contracts = { window = 0, done = {}, completed = 0 }
	save.goods = {}
	repairs += Production.decodeAutoRepeat(source, save, config, farmMath)
	local jobProblem, jobRepairs = Production.decodeJobs(source, save, config)
	if jobProblem then
		return nil, 0, jobProblem
	end
	repairs += jobRepairs
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
	local animalProblem, animalRepairs = Animals.decode(source, save, config, farmMath, now, newUid)
	if animalProblem then
		return nil, 0, animalProblem
	end
	repairs += animalRepairs
	save.stored = math.min(save.stored, farmMath.getStorageCap(save))
	local offlineEarned = 0
	local grown = 0
	if SessionLock.isFinite(source.lastSeen) and source.lastSeen >= 0 and source.lastSeen <= now then
		-- Çevrimdışı kazanç doğrudan kasaya yatar; oran ve süre Pasif Gelir'e göre değişir (FarmMath.getOfflineTerms).
		offlineEarned = farmMath.computeOfflineEarnings(save, source.lastSeen, now)
		save.cash = math.min(Common.MAX_MONEY, save.cash + offlineEarned)
		-- Sen yokken yetişkin olan hayvanlar (dönüş özeti için)
		local previousStages: { [string]: string } = {}
		if
			save.progression
			and not save.progression.returnEnded
			and save.progression.returnEndsAt > 0
			and save.progression.returnEndsAt <= now
		then
			for _, animal in save.animals do
				previousStages[animal.uid] = farmMath.getStage(
					animal.bornAt,
					source.lastSeen,
					farmMath.getGrowthSpeed(save, animal.animalId, animal.zoneId, source.lastSeen)
				)
			end
			local boundary = save.progression.returnEndsAt
			local speeds = farmMath.snapshotGrowthSpeeds(save, boundary - 0.001)
			farmMath.preserveGrowthProgress(save, speeds, boundary)
			for _, animal in save.animals do
				animal.stage = farmMath.getStage(
					animal.bornAt,
					now,
					farmMath.getGrowthSpeed(save, animal.animalId, animal.zoneId, now)
				)
			end
		end
		for _, animal in save.animals do
			if
				animal.bornAt ~= 0
				and animal.stage == "adult"
				and (
						previousStages[animal.uid]
						or farmMath.getStage(
							animal.bornAt,
							source.lastSeen,
							farmMath.getGrowthSpeed(save, animal.animalId, animal.zoneId)
						)
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

function Farm.encode(save: any, now: number): { [string]: any }
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
	return {
		version = 3,
		production = Production.encodeJobs(save.production),
		autoRepeat = table.clone(save.autoRepeat or {}),
		lineage = lineage,
		expansions = expansions,
		cash = Common.amount(save.cash, 0),
		stored = Common.amount(save.stored, 0),
		purchased = purchased,
		animals = Animals.encode(save.animals),
		lastSeen = now,
	}
end

return Farm
