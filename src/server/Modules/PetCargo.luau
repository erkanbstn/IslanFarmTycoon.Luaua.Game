--!strict
-- Görevdeki gerçek hayvan ve ağılı; balık tarifinin varsayılan türü yalnız eski/eksik görevlerde kullanılır.
local PetCargo = {}

function PetCargo.select(animals: { any }, recipe: any, job: any?): (string, string, boolean)
	for _, animal in animals do
		if animal.task and animal.task.kind == "production" and animal.task.id == recipe.id then
			return animal.animalId, animal.zoneId, true
		end
	end
	if job and typeof(job.cargoAnimalId) == "string" and typeof(job.cargoZoneId) == "string" then
		return job.cargoAnimalId, job.cargoZoneId, true
	end
	return recipe.animalId, "", false
end

-- Süresi dolup serbest kalan hayvanın görünümü yalnız aynı parti için korunur.
function PetCargo.resolve(
	modelId: string,
	zoneId: string,
	assigned: boolean,
	uid: string,
	previousUid: unknown,
	previousModel: unknown,
	previousZone: unknown
): (string, string)
	if not assigned and previousUid == uid and typeof(previousModel) == "string" then
		return previousModel, if typeof(previousZone) == "string" then previousZone else zoneId
	end
	return modelId, zoneId
end

return PetCargo
