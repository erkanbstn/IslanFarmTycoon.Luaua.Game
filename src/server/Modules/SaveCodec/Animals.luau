--!strict
-- Çiftlik hayvanları için şema sınırı (bölge/eklenti/görev doğrulaması).
local SessionLock = require(script.Parent.Parent.SessionLock)
local Common = require(script.Parent.Common)
local Tasks = require(script.Parent.Tasks)

local Animals = {}
local MAX_INPUT_ANIMALS = 1000

-- Hayvanları `save.animals`'a yazar (save.cash iadeleri dahil). Dönüş: (sorun mesajı ya da nil, onarım sayısı).
function Animals.decode(
	source: any,
	save: any,
	config: any,
	farmMath: any,
	now: number,
	newUid: () -> string
): (string?, number)
	local repairs = 0
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
				return "Hayvan kaydı sınırı aşıldı", 0
			end
			if typeof(entry) ~= "table" or typeof(entry.animalId) ~= "string" or not config.ANIMALS[entry.animalId] then
				return "Tanınmayan hayvan kaydı; orijinal kayıt korunuyor", 0
			end
			local animalId = entry.animalId
			local zoneId = entry.zoneId
			local zone = if typeof(zoneId) == "string" then config.ZONES[zoneId] else nil
			local task = Tasks.decodeTask(entry.task, config)
			if
				not zone
				or not save.unlockedZones[zoneId]
				or not farmMath.zoneAllows(save, zone, animalId)
				or farmMath.countInZone(save, zoneId) >= farmMath.getZoneCapacity(save, zoneId)
			then
				zoneId = farmMath.findZoneForAnimal(save, animalId)
				repairs += 1
			end
			if not zoneId then
				-- Geçerli hayvanın yeri kalkmış/dolmuşsa tek seferlik taban fiyat iadesi.
				save.cash = math.min(Common.MAX_MONEY, save.cash + config.ANIMALS[animalId].price)
				continue
			end
			local bornAt = if SessionLock.isFinite(entry.bornAt) then math.clamp(entry.bornAt, 0, now) else 0
			if bornAt ~= entry.bornAt then
				repairs += 1
			end
			-- Eklenti görevi yalnızca satın alınmış eklentide, doğru tür/bölge ve kapasite içinde geçerlidir.
			local extensionId: string? = nil
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
	return nil, repairs
end

-- Kayda yazılacak hayvan listesi.
function Animals.encode(animals: any): { any }
	local result = {}
	for _, animal in animals do
		table.insert(result, {
			uid = animal.uid,
			animalId = animal.animalId,
			zoneId = animal.zoneId,
			bornAt = animal.bornAt,
			extensionId = animal.extensionId,
			task = animal.task,
		})
	end
	return result
end

return Animals
