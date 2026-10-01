--!strict
-- Büyüme hızı ve üretim: yetişkin sayısı, üretim ödülü, büyüme ilerlemesini koruma.
-- FarmMath cephesi (init.luau) bunları birleştirir; her zaman `FarmMath.<ad>` ile kullan.

local Config = require(script.Parent.Parent.Parent:WaitForChild("Config"))
local GameTypes = require(script.Parent.Parent.Parent:WaitForChild("GameTypes"))
local Core = require(script.Parent:WaitForChild("Core"))
local Expansion = require(script.Parent:WaitForChild("Expansion"))
local Counts = require(script.Parent:WaitForChild("Counts"))
local Recipes = require(script.Parent:WaitForChild("Recipes"))

type PlayerSave = GameTypes.PlayerSave

local Production = {}

-- Toplam hız artısını (çarpan - 1 toplamı) hıza çevirir: KNEE'ye kadar doğrusal (1 + artı), üstü azalan getiri.
-- Hız her zaman artıyla birlikte artar (sıkı monoton) ve GROWTH_SPEED_CAP'in altında kalır.
function Production.combineGrowthExcess(excess: number): number
	local knee = Config.GROWTH_SPEED_KNEE
	if excess <= knee then
		return 1 + math.max(0, excess)
	end
	local room = Config.GROWTH_SPEED_CAP - 1 - knee -- sıkışan bölümün üst sınırı
	local over = excess - knee
	return 1 + knee + over * room / (over + room)
end

-- Bir hayvan türünün büyüme hızı: genel güçlendirmeler (silo, Hızlı Büyüme) + o türe özel + bölge geliştirmesi + takılı muska.
-- Artılar toplanır, toplam combineGrowthExcess ile azalan getiriye sokulur (çarpım birikmez).
function Production.getGrowthSpeed(save: PlayerSave, animalId: string, zoneId: string?): number
	local excess = Core.getEquippedExcess(save, "growthSpeed")
	if zoneId then
		excess += Expansion.getBuildExcess(save, zoneId, "growthSpeed") -- bölge geliştirmesi (ör. yemlik, kuluçka)
	end
	for _, upgrade in Config.UPGRADES do
		if not save.purchased[upgrade.id] then
			continue
		end
		if upgrade.growthSpeed then
			excess += upgrade.growthSpeed - 1
		end
		local perAnimal = upgrade.growthBoost
		if perAnimal and perAnimal[animalId] then
			excess += perAnimal[animalId] - 1
		end
	end
	return Production.combineGrowthExcess(excess)
end

-- Yavrunun yetişkin olması için gereken saniye (arayüz ve test bunu kullanır; elle çarpma yok)
function Production.getGrowthSeconds(save: PlayerSave, animalId: string, zoneId: string?): number
	return (Config.GROWTH_SECONDS.calf + Config.GROWTH_SECONDS.young)
		/ Production.getGrowthSpeed(save, animalId, zoneId)
end

-- Yetişkin ve boşta hayvanlar (açık bölgede, tarifin türlerinden; eklentide duranlar ve başka bir tesise verilmiş
-- olanlar sayılmaz; bu tarifin kendi işine verilmiş olanlar dönecekleri için sayılır). En yaşlıdan başlayarak sıralı.
local function idleAdults(
	save: PlayerSave,
	recipe: Config.ProductionRecipeConfig,
	now: number
): { GameTypes.AnimalRecord }
	local result: { GameTypes.AnimalRecord } = {}
	local speeds: { [string]: number } = {}
	for _, animal in save.animals do
		local task = Counts.getActiveTask(animal, now)
		if
			not save.unlockedZones[animal.zoneId]
			or not table.find(recipe.animalIds, animal.animalId)
			or (task ~= nil and not (task.kind == "production" and task.id == recipe.id))
		then
			continue
		end
		local cacheKey = `{animal.animalId}|{animal.zoneId}`
		local speed = speeds[cacheKey]
		if speed == nil then
			speed = Production.getGrowthSpeed(save, animal.animalId, animal.zoneId)
			speeds[cacheKey] = speed
		end
		if Core.getStage(animal.bornAt, now, speed :: number) == "adult" then
			table.insert(result, animal)
		end
	end
	table.sort(result, function(a: GameTypes.AnimalRecord, b: GameTypes.AnimalRecord): boolean
		if a.bornAt ~= b.bornAt then
			return a.bornAt < b.bornAt
		end
		return a.uid < b.uid
	end)
	return result
end

function Production.countProductionAdults(save: PlayerSave, recipe: Config.ProductionRecipeConfig, now: number): number
	return #idleAdults(save, recipe, now)
end

-- Tesise verilecek hayvanlar: boştaki yetişkinlerden seçilen partinin gerektirdiği sayıda (yetmiyorsa nil)
function Production.pickProductionAnimals(
	save: PlayerSave,
	baseRecipe: Config.ProductionRecipeConfig,
	now: number,
	optionId: string?
): { GameTypes.AnimalRecord }?
	local recipe = Recipes.resolve(baseRecipe, optionId)
	local adults = idleAdults(save, recipe, now)
	if #adults < recipe.requiredAdults then
		return nil
	end
	local picked: { GameTypes.AnimalRecord } = {}
	for index = 1, recipe.requiredAdults do
		table.insert(picked, adults[index])
	end
	return picked
end

-- Partinin ödülü (parti job.optionId ile seçilir; yoksa ilk seçenek). Seçenekli para tesislerinde hayvan sayısını seçenek
-- belirler; seçeneksiz tariflerde gerekenden fazla yetişkin başına ödül artar. (ödül, bonus oranı 0.5 = +%50) döner.
-- job verilirse ödül, (kaçırılan gelir + başlatma maliyeti) x parti çarpanı (yoksa PRODUCTION_MIN_RETURN) tabanından az olamaz.
function Production.getProductionReward(
	save: PlayerSave,
	baseRecipe: Config.ProductionRecipeConfig,
	now: number,
	job: GameTypes.ProductionJob?
): (number, number)
	local recipe = Recipes.resolve(baseRecipe, if job then job.optionId else nil)
	local extra = 0
	if not baseRecipe.options then
		extra = math.clamp(
			Production.countProductionAdults(save, recipe, now) - recipe.requiredAdults,
			0,
			Config.PRODUCTION_MAX_BONUS_ADULTS
		)
	end
	local bonus = extra * Config.PRODUCTION_BONUS_PER_ADULT
	local facilityYield = 1 + Expansion.getBuildBonus(save, recipe.id, "yield") -- tesis geliştirmesi
	local reward = math.floor(recipe.reward * (1 + bonus) * facilityYield)
	if job and job.forgone then
		local floorReward = math.ceil(
			(job.forgone + Expansion.getFacilityCost(save, recipe))
				* math.min(recipe.returnMultiplier or Config.PRODUCTION_MIN_RETURN, Config.PRODUCTION_MAX_RETURN)
		)
		reward = math.max(reward, floorReward)
	end
	return reward, bonus
end

-- Ürün merkezinin teslim miktarı: temel miktar x çarpan; çarpan = 1 + yetişkin bonusu + tesis verimi + muska (artılar TOPLANIR, toplam
-- PRODUCTION_YIELD_MAX_MULT'ı aşamaz). job verilirse miktar, kaçırılan gelirin (+ başlatma maliyetinin) PRODUCTION_MIN_RETURN katı kadar
-- para değerinin altına inmemeye çalışır, ama PRODUCTION_MAX_BATCH_UNITS'i asla aşmaz: asgari getiri miktarı şişirerek değil, ürünün birim
-- değeriyle sağlanır (Config/Goods.luau). (miktar, yetişkin bonusu) döner.
function Production.getGoodsYield(
	save: PlayerSave,
	recipe: Config.ProductionRecipeConfig,
	now: number,
	job: GameTypes.ProductionJob?
): (number, number)
	local good = if recipe.goodsId then Config.GOODS[recipe.goodsId] else nil
	if not good or not recipe.goodsAmount then
		return 0, 0
	end
	local extra = math.clamp(
		Production.countProductionAdults(save, recipe, now) - recipe.requiredAdults,
		0,
		Config.PRODUCTION_MAX_BONUS_ADULTS
	)
	local bonus = extra * Config.PRODUCTION_BONUS_PER_ADULT
	local multiplier = math.min(
		1
			+ bonus
			+ Expansion.getBuildBonus(save, recipe.id, "yield") -- tesis geliştirmesi
			+ Core.getBonus(save, "goodsYield"), -- takılı ambar muskası
		Config.PRODUCTION_YIELD_MAX_MULT
	)
	local amount = math.floor(recipe.goodsAmount * multiplier)
	if job and job.forgone then
		local floorAmount = math.ceil(
			(job.forgone + Expansion.getFacilityCost(save, recipe)) * Config.PRODUCTION_MIN_RETURN / good.value
		)
		amount = math.max(amount, floorAmount)
	end
	return math.clamp(amount, 1, Config.PRODUCTION_MAX_BATCH_UNITS), bonus
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
