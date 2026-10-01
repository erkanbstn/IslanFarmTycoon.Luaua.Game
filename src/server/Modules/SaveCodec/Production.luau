--!strict
-- Çiftlik üretim kuyruğu ve yardımcıyla otomatik tekrar için şema sınırı.
local SessionLock = require(script.Parent.Parent.SessionLock)

local Production = {}

-- Yardımcı ile otomatik tekrar (isteğe bağlı): yalnızca tanınan tarif, geçerli parti ve satın alınmış yardımcı kabul edilir.
-- Dönüş: onarım sayısı.
function Production.decodeAutoRepeat(source: any, save: any, config: any, farmMath: any): number
	local repairs = 0
	if typeof(source.autoRepeat) == "table" then
		for recipeId, optionId in source.autoRepeat do
			local recipe = if typeof(recipeId) == "string" then config.PRODUCTION_RECIPES[recipeId] else nil
			local kind = if recipe then farmMath.petKindFor(recipe) else nil
			local optionOk = typeof(optionId) == "string"
				and (optionId == "default" or farmMath.findProductionOption(recipe, optionId) ~= nil)
			if recipe and kind and farmMath.hasPet(save, kind) and optionOk then
				save.autoRepeat[recipe.id] = optionId
			else
				repairs += 1
			end
		end
	end
	return repairs
end

-- Süren işler. Dönüş: (sorun mesajı ya da nil, onarım sayısı); sorun varsa kayıt reddedilir.
function Production.decodeJobs(source: any, save: any, config: any): (string?, number)
	local repairs = 0
	if source.production == nil then
		return nil, repairs
	end
	if typeof(source.production) ~= "table" then
		return "Üretim kaydı bozuk; orijinal kayıt korunuyor", 0
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
			return "Üretim kaydı geçersiz; orijinal kayıt korunuyor", 0
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
	return nil, repairs
end

-- Kayda yazılacak üretim kuyruğu.
function Production.encodeJobs(production: any): { [string]: any }
	local result = {}
	for recipeId, job in production or {} do
		result[recipeId] = {
			uid = job.uid,
			readyAt = job.readyAt,
			startedAt = job.startedAt,
			forgone = job.forgone,
			optionId = job.optionId,
		}
	end
	return result
end

return Production
