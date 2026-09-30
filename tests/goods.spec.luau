--!strict
-- Ahır deposu ve ürün merkezleri: yapılandırma tutarlılığı, depo işlemleri, kayıt ve verim tabanı.
return function(codec: any, config: any, farmMath: any, rules: any)
	local now = 200000
	local serial = 0
	local function uid(): string
		serial += 1
		return `goods-test-{serial}`
	end
	local function newSave(): any
		local save = assert(codec.decode(nil, config, farmMath, now, uid), "fixture decode failed")
		save.cash = 1e6
		for _, upgrade in config.UPGRADES do
			if not upgrade.leveled then
				save.purchased[upgrade.id] = true
			end
		end
		farmMath.applyDerived(save)
		save.animals = {}
		return save
	end
	local function addAnimal(save: any, animalId: string, zoneId: string): any
		local animal: any = { uid = uid(), animalId = animalId, zoneId = zoneId, bornAt = 0, stage = "adult" }
		table.insert(save.animals, animal)
		return animal
	end

	-- ------------------------------------------------------------------ yapılandırma
	local cashSpecies: { [string]: boolean } = {}
	local goodsSpecies: { [string]: number } = {}
	for id, recipe in config.PRODUCTION_RECIPES do
		assert(table.find(config.PRODUCTION_ORDER, id), `recipe {id} is listed in PRODUCTION_ORDER`)
		local upgrade = assert(config.getUpgrade(recipe.upgradeId), `recipe {id} needs its building upgrade`)
		assert(config.getUpgradeIsland(upgrade) == recipe.island, `recipe {id} building lives on its island`)
		if recipe.output == "goods" then
			local good = assert(config.GOODS[recipe.goodsId], `recipe {id} produces a known good`)
			assert(recipe.goodsAmount and recipe.goodsAmount > 0, `recipe {id} has a positive amount`)
			assert(
				recipe.reward == recipe.goodsAmount * good.value,
				`recipe {id} reward equals the worth of its goods (display and upgrade cost basis)`
			)
			assert(
				table.find(recipe.animalIds, good.animalId) or table.find(recipe.animalIds, recipe.animalId),
				`recipe {id} uses the good's animal`
			)
			goodsSpecies[recipe.animalId] = (goodsSpecies[recipe.animalId] or 0) + 1
		else
			cashSpecies[recipe.animalId] = true
		end
	end
	-- Her hayvan türü için bir para, bir ürün merkezi
	for _, animalId in { "cow", "chicken", "duck", "horse", "goat", "sheep", "pig", "anchovy" } do
		assert(cashSpecies[animalId], `{animalId} has a cash center`)
		assert(goodsSpecies[animalId] == 1, `{animalId} has exactly one goods center`)
	end
	for id, good in config.GOODS do
		assert(
			good.id == id and good.value > 0 and #good.displayName > 0 and #good.icon > 0,
			`good {id} is well formed`
		)
		assert(table.find(config.GOODS_ORDER, id), `good {id} is ordered`)
		assert(config.ANIMALS[good.animalId], `good {id} comes from a known animal`)
	end
	assert(#config.GOODS_ORDER == 8, "eight goods")
	local previousCap = 0
	for _, barn in config.BARN_LEVELS do
		assert(barn.goodsCap > previousCap, "barn levels raise the goods capacity")
		previousCap = barn.goodsCap
	end

	-- ------------------------------------------------------------------ depo işlemleri
	local save = newSave()
	assert(farmMath.getGoodsCap(save) == config.BARN_LEVELS[save.barnLevel].goodsCap, "capacity follows the barn level")
	local cap = farmMath.getGoodsCap(save)
	assert(
		farmMath.getGoodsAmount(save, "milk") == 0 and farmMath.getGoodsSpace(save, "milk") == cap,
		"the barn starts empty"
	)
	assert(farmMath.addGoods(save, "milk", 10) == 10 and farmMath.getGoodsAmount(save, "milk") == 10, "goods are added")
	assert(farmMath.addGoods(save, "milk", cap) == cap - 10, "only what fits is added")
	assert(
		farmMath.getGoodsAmount(save, "milk") == cap and farmMath.getGoodsSpace(save, "milk") == 0,
		"a full barn takes no more"
	)
	assert(farmMath.addGoods(save, "milk", 5) == 0, "no space means nothing is added")
	assert(farmMath.getGoodsAmount(save, "egg") == 0, "goods are counted per type")
	assert(
		farmMath.addGoods(save, "nope", 5) == 0
			and farmMath.addGoods(save, "egg", -1) == 0
			and farmMath.addGoods(save, "egg", 0 / 0) == 0,
		"bad input adds nothing"
	)
	assert(
		farmMath.removeGoods(save, "milk", 4) and farmMath.getGoodsAmount(save, "milk") == cap - 4,
		"goods are consumed"
	)
	assert(
		not farmMath.removeGoods(save, "milk", cap) and farmMath.getGoodsAmount(save, "milk") == cap - 4,
		"an over-draw changes nothing"
	)
	assert(
		not farmMath.removeGoods(save, "milk", 1.5)
			and not farmMath.removeGoods(save, "nope", 1)
			and not farmMath.removeGoods(save, "milk", 0),
		"bad consumption is rejected"
	)
	assert(
		farmMath.removeGoods(save, "milk", cap - 4) and farmMath.getGoodsAmount(save, "milk") == 0,
		"goods can be emptied"
	)
	farmMath.addGoods(save, "wool", 3)
	farmMath.addGoods(save, "meat", 2)
	assert(
		farmMath.getGoodsWorth(save) == 3 * config.GOODS.wool.value + 2 * config.GOODS.meat.value,
		"worth sums amount x value"
	)

	-- ------------------------------------------------------------------ kayıt
	local stored = newSave()
	farmMath.addGoods(stored, "milk", 12)
	farmMath.addGoods(stored, "horseshoe", 7)
	local encoded = codec.encode(stored, now)
	assert(
		encoded.mainFarms["1"].goods.milk == 12 and encoded.mainFarms["1"].goods.horseshoe == 7,
		"goods are saved per farm"
	)
	local reloaded = assert(codec.decode(encoded, config, farmMath, now + 5, uid), "goods reload")
	assert(
		farmMath.getGoodsAmount(reloaded, "milk") == 12 and farmMath.getGoodsAmount(reloaded, "horseshoe") == 7,
		"goods survive a reload"
	)
	assert(next(codec.decode(nil, config, farmMath, now, uid).goods) == nil, "a new farm has an empty barn")
	-- Bozuk kayıt: bilinmeyen ürün atılır, sonsuz/negatif sıfırlanır, kapasite aşımı kısılır; hayvan ve para korunur
	local corrupt = codec.encode(stored, now)
	corrupt.mainFarms["1"].goods = { milk = 1e9, egg = -5, ghost = 3, wool = 0 / 0, meat = 4.9 }
	local repaired = assert(codec.decode(corrupt, config, farmMath, now, uid), "corrupt goods must not reject the save")
	assert(
		farmMath.getGoodsAmount(repaired, "milk") == farmMath.getGoodsCap(repaired),
		`over-capacity is clamped ({farmMath.getGoodsAmount(repaired, "milk")} vs {farmMath.getGoodsCap(repaired)} barn {repaired.barnLevel})`
	)
	assert(
		farmMath.getGoodsAmount(repaired, "egg") == 0 and repaired.goods.ghost == nil,
		"negative and unknown goods are dropped"
	)
	assert(
		farmMath.getGoodsAmount(repaired, "wool") == 0 and farmMath.getGoodsAmount(repaired, "meat") == 4,
		"non-finite is dropped, fractions are floored"
	)
	corrupt.mainFarms["1"].goods = "x"
	assert(
		codec.decode(corrupt, config, farmMath, now, uid) == nil,
		"a non-table barn fails closed, preserving the save"
	)

	-- ------------------------------------------------------------------ verim
	local yieldSave = newSave()
	addAnimal(yieldSave, "cow", "starter")
	addAnimal(yieldSave, "cow", "starter")
	local recipe = config.PRODUCTION_RECIPES.milk_goods
	local base = farmMath.getGoodsYield(yieldSave, recipe, now)
	assert(base >= recipe.goodsAmount, "yield is at least the base amount")
	addAnimal(yieldSave, "cow", "starter")
	local withExtra, bonus = farmMath.getGoodsYield(yieldSave, recipe, now)
	assert(bonus > 0 and withExtra > base, "extra adults raise the yield")
	local floored = farmMath.getGoodsYield(yieldSave, recipe, now, { uid = "j", readyAt = now, forgone = 1e6 })
	assert(
		floored
			== math.ceil(
				(1e6 + farmMath.getFacilityCost(yieldSave, recipe))
					* config.PRODUCTION_MIN_RETURN
					/ config.GOODS.milk.value
			),
		"the yield never drops below the forgone-income floor"
	)
	assert(floored * config.GOODS.milk.value > 1e6, "goods are always worth more than the income the animals gave up")
	assert(
		farmMath.getGoodsYield(yieldSave, config.PRODUCTION_RECIPES.packed_milk, now) == 0,
		"cash recipes have no goods yield"
	)

	-- ------------------------------------------------------------------ başlatma kuralı
	local startSave = newSave()
	addAnimal(startSave, "cow", "starter")
	addAnimal(startSave, "cow", "starter")
	local allowed = rules.canStart(startSave, recipe, farmMath, now)
	assert(allowed, "an empty barn allows a goods batch")
	farmMath.addGoods(startSave, "milk", farmMath.getGoodsCap(startSave) - recipe.goodsAmount + 1)
	local blocked, reason = rules.canStart(startSave, recipe, farmMath, now)
	assert(
		not blocked and reason == "Ahır deposunda bu ürün için yeterli yer yok.",
		"a nearly full barn blocks the batch"
	)
	local other = config.PRODUCTION_RECIPES.packed_milk
	assert(rules.canStart(startSave, other, farmMath, now), "a full barn does not block cash recipes")
	print("PASS goods: config consistency, barn storage, save/decode repairs, yield floor and start rule")
end
