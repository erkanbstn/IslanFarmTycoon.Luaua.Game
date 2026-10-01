--!strict
-- Ahır deposu ve ürün merkezleri: yapılandırma tutarlılığı, depo işlemleri, kayıt ve verim tabanı.
return function(codec: any, config: any, farmMath: any, rules: any, logic: any)
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
			-- Bir hayvan türünün her adada (ana ada dahil) en çok bir ürün merkezi olur; tür ana ada ve kendi adasında ayrı kurulabilir
			local key = `{recipe.animalId}:{recipe.island}`
			goodsSpecies[key] = (goodsSpecies[key] or 0) + 1
			goodsSpecies[recipe.animalId] = (goodsSpecies[recipe.animalId] or 0) + 1
		else
			cashSpecies[recipe.animalId] = true
		end
	end
	-- Her hayvan türü için bir para, bir ürün merkezi
	for _, animalId in config.ANIMAL_ORDER do
		if animalId ~= "seabass" then -- balık tesisleri hamsi kimliğiyle tanımlıdır (animalIds: hamsi + levrek)
			assert(cashSpecies[animalId], `{animalId} has a cash center`)
			assert((goodsSpecies[animalId] or 0) >= 1, `{animalId} has a goods center`)
		end
	end
	for key, count in goodsSpecies do
		assert(count == 1 or not key:find(":"), `{key} has exactly one goods center on its island`)
	end
	for id, good in config.GOODS do
		assert(
			good.id == id and good.value > 0 and #good.displayName > 0 and #good.icon > 0,
			`good {id} is well formed`
		)
		assert(table.find(config.GOODS_ORDER, id), `good {id} is ordered`)
		assert(config.ANIMALS[good.animalId], `good {id} comes from a known animal`)
	end
	assert(
		#config.GOODS_ORDER == #config.ANIMAL_ORDER - 1,
		"one good per animal (the anchovy shares the fish good of the sea bass)"
	)
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
		encoded.goods.milk == 12 and encoded.goods.horseshoe == 7 and encoded.mainFarms["1"].goods == nil,
		"goods are saved once, at the account level (shared by every farm)"
	)
	local reloaded = assert(codec.decode(encoded, config, farmMath, now + 5, uid), "goods reload")
	assert(
		farmMath.getGoodsAmount(reloaded, "milk") == 12 and farmMath.getGoodsAmount(reloaded, "horseshoe") == 7,
		"goods survive a reload"
	)
	assert(next(codec.decode(nil, config, farmMath, now, uid).goods) == nil, "a new farm has an empty barn")
	-- Bozuk kayıt: bilinmeyen ürün atılır, sonsuz/negatif sıfırlanır, kapasite aşımı kısılır; hayvan ve para korunur
	local corrupt = codec.encode(stored, now)
	corrupt.goods = { milk = 1e9, egg = -5, ghost = 3, wool = 0 / 0, meat = 4.9 }
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
	corrupt.goods = "x"
	assert(
		codec.decode(corrupt, config, farmMath, now, uid) == nil,
		"a non-table barn fails closed, preserving the save"
	)

	-- Depo hesap düzeyindedir: çiftlik kayıtlarındaki eski `goods` alanı artık okunmaz (göç yok)
	local legacy = codec.encode(stored, now)
	legacy.goods = nil
	legacy.mainFarms["1"].goods = { milk = 5 }
	legacy.mainFarms["2"] = table.clone(legacy.mainFarms["1"])
	legacy.mainFarms["2"].goods = { milk = 9, egg = 4 }
	local folded = assert(codec.decode(legacy, config, farmMath, now, uid), "a per-farm barn field is ignored")
	assert(
		farmMath.getGoodsAmount(folded, "milk") == 0 and farmMath.getGoodsAmount(folded, "egg") == 0,
		"per-farm goods are not folded into the shared barn any more"
	)

	-- ------------------------------------------------------------------ ortak depo limiti
	local shared = newSave()
	local oneBarn = farmMath.getGoodsCap(shared)
	assert(oneBarn == config.BARN_LEVELS[shared.barnLevel].goodsCap, "one barn gives its own cap")
	shared.mainFarms["2"] = codec.newFarm(config, farmMath, now, uid, "2")
	shared.mainFarms["2"].barnLevel = 1
	assert(
		farmMath.getGoodsCap(shared) == oneBarn + config.BARN_LEVELS[1].goodsCap,
		"a second farm adds its barn to the shared cap"
	)
	shared.mainFarms["2"].barnLevel = 3
	assert(
		farmMath.getGoodsCap(shared) == oneBarn + config.BARN_LEVELS[3].goodsCap,
		"upgrading another farm's barn raises the total"
	)
	shared.barnLevel = 2
	assert(
		farmMath.getGoodsCap(shared) == config.BARN_LEVELS[2].goodsCap + config.BARN_LEVELS[3].goodsCap,
		"the active farm's live level counts too"
	)
	local total = farmMath.getGoodsCap(shared)
	assert(farmMath.addGoods(shared, "milk", total + 100) == total, "the shared barn holds the summed total per good")
	-- Ürün merkezi yalnızca başka çiftlikte kuruluysa da sipariş için ürün sayılır
	shared.purchased.milk_center = nil
	shared.mainFarms["2"].purchased.egg_center = true
	shared.mainFarms["2"].unlockedIslands.poultry = true
	local sources = farmMath.getContractGoods(shared)
	assert(table.find(sources, "egg") ~= nil, "a goods center on any farm makes the good orderable")

	-- ------------------------------------------------------------------ hızlı satış ve takas hesapları
	local trade = newSave()
	trade.goods = {}
	farmMath.addGoods(trade, "milk", 7)
	assert(farmMath.getGoodsSellAmount(trade, "milk", "all") == 7, "all sells the whole stack")
	assert(farmMath.getGoodsSellAmount(trade, "milk", "half") == 4, "half rounds up")
	assert(
		farmMath.getGoodsSellAmount(trade, "milk", "x") == 0 and farmMath.getGoodsSellAmount(trade, "nope", "all") == 0,
		"bad input sells nothing"
	)
	local cash, soldAmount = farmMath.sellGoods(trade, "milk", "half")
	assert(
		cash == math.floor(4 * config.GOODS.milk.value * config.GOODS_SELL.rate) and soldAmount == 4,
		"half pays value x rate"
	)
	assert(farmMath.getGoodsAmount(trade, "milk") == 3, "sold units leave the barn")
	assert(farmMath.sellGoods(trade, "egg", "all") == nil, "an empty stack sells nothing")
	assert(
		farmMath.getGoodsSellValue("milk", 0) == 0 and farmMath.getGoodsSellValue("milk", 0 / 0) == 0,
		"no value for nothing"
	)
	for goodsId, good in config.GOODS do
		assert(
			farmMath.getGoodsSellValue(goodsId, 10) <= 10 * good.value * config.GOODS_SELL.rate,
			"selling never pays above value x rate"
		)
	end

	-- Doluluk uyarısı: kapasitenin GOODS_FULL_WARNING oranına ulaşan ürünler listelenir
	local warn = newSave()
	warn.goods = {}
	assert(#farmMath.getFullGoods(warn) == 0, "an empty barn warns about nothing")
	local warnCap = farmMath.getGoodsCap(warn)
	local limit = math.ceil(warnCap * config.GOODS_FULL_WARNING)
	farmMath.addGoods(warn, "egg", limit - 1)
	assert(#farmMath.getFullGoods(warn) == 0, "just under the threshold is quiet")
	farmMath.addGoods(warn, "egg", 1)
	farmMath.addGoods(warn, "milk", warnCap)
	local fullList = farmMath.getFullGoods(warn)
	assert(#fullList == 2 and fullList[1] == "milk" and fullList[2] == "egg", "full goods follow the goods order")
	farmMath.sellGoods(warn, "milk", "all")
	assert(#farmMath.getFullGoods(warn) == 1, "selling clears the warning")

	-- Takas: yığılmış ürünlerden başlar, yeterli değilse plan yok, plan uygulanınca ürünler düşer
	local barter = newSave()
	barter.goods = {}
	farmMath.addGoods(barter, "milk", 10)
	farmMath.addGoods(barter, "cheese", 1)
	local worth = farmMath.getGoodsBarterWorth(barter)
	assert(
		worth
			== math.floor(10 * config.GOODS.milk.value * config.GOODS_BARTER.rate)
				+ math.floor(config.GOODS.cheese.value * config.GOODS_BARTER.rate),
		"barter worth is value x barter rate"
	)
	local unit = math.floor(config.GOODS.milk.value * config.GOODS_BARTER.rate)
	local plan, credited = farmMath.planGoodsBarter(barter, unit * 3)
	assert(
		plan and plan.milk == 3 and plan.cheese == nil and credited >= unit * 3,
		"the fullest stack pays first, only what is needed"
	)
	local none, have = farmMath.planGoodsBarter(barter, worth + 1)
	assert(none == nil and have == worth, "an unaffordable price has no plan and reports what the barn is worth")
	assert(farmMath.applyGoodsBarter(barter, plan :: any), "a plan applies")
	assert(
		farmMath.getGoodsAmount(barter, "milk") == 7 and farmMath.getGoodsAmount(barter, "cheese") == 1,
		"only the planned units leave"
	)
	assert(
		not farmMath.applyGoodsBarter(barter, { milk = 99 }) and farmMath.getGoodsAmount(barter, "milk") == 7,
		"a stale plan changes nothing"
	)
	local mixed = newSave()
	mixed.goods = {}
	farmMath.addGoods(mixed, "milk", 2)
	farmMath.addGoods(mixed, "egg", 2)
	local mixedWorth = farmMath.getGoodsBarterWorth(mixed)
	local mixedPlan = farmMath.planGoodsBarter(mixed, mixedWorth)
	assert(mixedPlan and mixedPlan.milk == 2 and mixedPlan.egg == 2, "a price equal to the whole barn takes everything")

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
		not blocked and string.find(reason :: string, "^Ahır deposunda bu ürün için yeterli yer yok %(") ~= nil,
		"a nearly full barn blocks the batch"
	)
	-- Fazla yetişkin bonusu teslim miktarını temel miktarın üstüne çıkarır: yalnızca temel miktar sığıyorsa da parti reddedilir
	local bonusSave = newSave()
	for _ = 1, recipe.requiredAdults + 4 do
		addAnimal(bonusSave, "cow", "starter")
	end
	local preview = farmMath.previewGoodsYield(bonusSave, recipe, now)
	assert(preview > recipe.goodsAmount, "extra adults raise the batch yield above the base amount")
	farmMath.addGoods(bonusSave, "milk", farmMath.getGoodsCap(bonusSave) - recipe.goodsAmount)
	assert(farmMath.getGoodsSpace(bonusSave, "milk") == recipe.goodsAmount, "only the base amount fits")
	local overflow, overflowReason = rules.canStart(bonusSave, recipe, farmMath, now)
	assert(
		not overflow and string.find(overflowReason :: string, tostring(preview), 1, true) ~= nil,
		"a batch whose real yield would overflow is refused with the amounts in the message"
	)
	farmMath.removeGoods(bonusSave, "milk", preview - recipe.goodsAmount)
	assert(rules.canStart(bonusSave, recipe, farmMath, now), "the same batch starts once the whole yield fits")
	-- Parti toplam kapasiteyi aşsa bile boş depoda başlar; sığmayan kısım teslimde "Hepsini sat" oranıyla paraya çevrilir
	local hugeMath = setmetatable({
		previewGoodsYield = function(): number
			return 1e7
		end,
	}, { __index = farmMath })
	local hugeSave = newSave()
	addAnimal(hugeSave, "cow", "starter")
	addAnimal(hugeSave, "cow", "starter")
	local hugeCap = farmMath.getGoodsCap(hugeSave)
	assert(
		rules.canStart(hugeSave, recipe, hugeMath, now),
		"an empty barn starts a batch larger than the whole capacity"
	)
	farmMath.addGoods(hugeSave, "milk", 1)
	assert(not rules.canStart(hugeSave, recipe, hugeMath, now), "a barn without room for the fitting part still blocks")
	hugeSave.goods = {}
	local cashed = 0
	local hooks: any = {
		settle = function() end,
		addCash = function(amount: number)
			cashed += amount
		end,
	}
	local job: any = { uid = "j", readyAt = now, startedAt = now - 10, forgone = 1e9 }
	local expectedYield = farmMath.getGoodsYield(hugeSave, recipe, now, job)
	assert(expectedYield > hugeCap, "the fixture batch exceeds the capacity")
	hugeSave.production[recipe.id] = job
	local reward = logic.claim(hugeSave, hugeSave, recipe, job, now, farmMath, config, hooks)
	assert(farmMath.getGoodsAmount(hugeSave, "milk") == hugeCap, "the fitting part is stored")
	assert(
		reward == math.floor((expectedYield - hugeCap) * config.GOODS.milk.value * config.GOODS_SELL.rate)
			and cashed == reward,
		"the overflow pays the bulk-sell rate in cash (never more than selling from the barn)"
	)
	local other = config.PRODUCTION_RECIPES.packed_milk
	assert(rules.canStart(startSave, other, farmMath, now), "a full barn does not block cash recipes")
	print("PASS goods: config consistency, barn storage, save/decode repairs, yield floor and start rule")
end
