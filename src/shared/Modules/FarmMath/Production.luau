--!strict
-- Büyüme hızı ve üretim: yetişkin sayısı, üretim ödülü, büyüme ilerlemesini koruma.
-- FarmMath cephesi (init.luau) bunları birleştirir; her zaman `FarmMath.<ad>` ile kullan.

local Config = require(script.Parent.Parent.Parent:WaitForChild("Config"))
local GameTypes = require(script.Parent.Parent.Parent:WaitForChild("GameTypes"))
local Core = require(script.Parent:WaitForChild("Core"))
local Expansion = require(script.Parent:WaitForChild("Expansion"))

type PlayerSave = GameTypes.PlayerSave

local Production = {}

-- Bir hayvan türünün büyüme hızı: genel güçlendirmeler (silo) x o türe özel (ör. Tavuk Adası) x takılı muska
function Production.getGrowthSpeed(save: PlayerSave, animalId: string, zoneId: string?): number
	local speed = Core.getEquippedMultiplier(save, "growthSpeed")
	if zoneId then
		speed *= Expansion.getBuildMultiplier(save, zoneId, "growthSpeed") -- bölge geliştirmesi (ör. yemlik, kuluçka)
	end
	for _, upgrade in Config.UPGRADES do
		if not save.purchased[upgrade.id] then
			continue
		end
		if upgrade.growthSpeed then
			speed *= upgrade.growthSpeed
		end
		local perAnimal = upgrade.growthBoost
		if perAnimal and perAnimal[animalId] then
			speed *= perAnimal[animalId]
		end
	end
	return speed
end

-- Üretimde sayılan yetişkin hayvanlar (açık bölgede, tarifin türlerinden)
function Production.countProductionAdults(save: PlayerSave, recipe: Config.ProductionRecipeConfig, now: number): number
	local count = 0
	local speeds: { [string]: number } = {}
	for _, animal in save.animals do
		if not save.unlockedZones[animal.zoneId] or not table.find(recipe.animalIds, animal.animalId) then
			continue
		end
		local cacheKey = `{animal.animalId}|{animal.zoneId}`
		local speed = speeds[cacheKey]
		if speed == nil then
			speed = Production.getGrowthSpeed(save, animal.animalId, animal.zoneId)
			speeds[cacheKey] = speed
		end
		if Core.getStage(animal.bornAt, now, speed :: number) == "adult" then
			count += 1
		end
	end
	return count
end

-- Gerekenden fazla yetişkin başına ödül artar; bonus oranı (0.5 = +%50) ve ödül döner.
function Production.getProductionReward(
	save: PlayerSave,
	recipe: Config.ProductionRecipeConfig,
	now: number
): (number, number)
	local extra = math.clamp(
		Production.countProductionAdults(save, recipe, now) - recipe.requiredAdults,
		0,
		Config.PRODUCTION_MAX_BONUS_ADULTS
	)
	local bonus = extra * Config.PRODUCTION_BONUS_PER_ADULT
	local facilityYield = 1 + Expansion.getBuildBonus(save, recipe.id, "yield") -- tesis geliştirmesi
	return math.floor(recipe.reward * (1 + bonus) * facilityYield), bonus
end

-- Büyüme hızı değişmeden önce her hayvanın (tür|bölge) hızını kaydeder; preserveGrowthProgress ile birlikte kullanılır.
function Production.snapshotGrowthSpeeds(save: PlayerSave): { [string]: number }
	local speeds: { [string]: number } = {}
	for _, animal in save.animals do
		local key = `{animal.animalId}|{animal.zoneId}`
		if speeds[key] == nil then
			speeds[key] = Production.getGrowthSpeed(save, animal.animalId, animal.zoneId)
		end
	end
	return speeds
end

-- Yeni büyüme hızı yalnızca değişiklikten sonraki süreye uygulanır.
function Production.preserveGrowthProgress(save: PlayerSave, previousSpeeds: { [string]: number }, now: number)
	for _, animal in save.animals do
		local previous = previousSpeeds[`{animal.animalId}|{animal.zoneId}`]
		if previous and animal.bornAt ~= 0 then
			local speed = Production.getGrowthSpeed(save, animal.animalId, animal.zoneId)
			local growUp = Config.GROWTH_SECONDS.calf + Config.GROWTH_SECONDS.young
			if Core.getStage(animal.bornAt, now, previous) == "adult" then
				-- Zaten yetişkin: yetişkinliğin başladığı an değişmez (sipariş ve gelir geçmişi doğru kalır)
				animal.bornAt = (animal.bornAt + growUp / previous) - growUp / speed
			else
				local age = math.max(0, now - animal.bornAt) * previous
				animal.bornAt = now - age / speed
			end
			animal.stage = Core.getStage(animal.bornAt, now, speed)
		end
	end
end

return Production
