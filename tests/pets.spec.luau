--!strict
-- Yardımcılar (pet): hazır partiyi teslim alma, otomatik tekrar, park edilmiş çiftlikte çalışma, ortak depo ve kayıt.
return function(codec: any, config: any, farmMath: any, logic: any)
	local now = 900000
	local serial = 0
	local function uid(): string
		serial += 1
		return `pets-test-{serial}`
	end
	local function newData(): any
		local data = assert(codec.decode(nil, config, farmMath, now, uid), "fixture decode failed")
		data.cash = 1e6
		for _, upgrade in config.UPGRADES do
			data.purchased[upgrade.id] = true
		end
		farmMath.applyDerived(data)
		data.animals = {}
		for _ = 1, 8 do
			table.insert(
				data.animals,
				{ uid = uid(), animalId = "cow", zoneId = "starter", bornAt = 0, stage = "adult" }
			)
		end
		data.autoRepeat = {}
		return data
	end
	local function hooksFor(data: any): any
		return {
			settle = function() end,
			trySpend = function(amount: number): boolean
				if data.cash < amount then
					return false
				end
				data.cash -= amount
				return true
			end,
			addCash = function(amount: number)
				data.cash += amount
			end,
			newUid = uid,
		}
	end
	local function run(data: any, at: number): any
		local ids = { "1" }
		for id in data.mainFarms do
			if id ~= "1" then
				table.insert(ids, id)
			end
		end
		return logic.runPets(data, ids, function(id: string): any
			return if id == data.activeMainFarmId then data else data.mainFarms[id]
		end, config.PRODUCTION_ORDER, at, farmMath, config, hooksFor(data))
	end

	-- Yardımcı satın alınabilir (çiftlik başına): yetenek FarmMath.hasPet ile sorulur
	local data = newData()
	assert(farmMath.hasPet(data, "cash") and farmMath.hasPet(data, "goods"), "both pets are purchasable upgrades")
	local cashRecipe = config.PRODUCTION_RECIPES.packed_milk
	local goodsRecipe = config.PRODUCTION_RECIPES.milk_goods

	local slots = logic.petSlots(data, config.PRODUCTION_ORDER, farmMath, config)
	local seenSlots: { [string]: boolean } = {}
	for _, slot in slots do
		seenSlots[`{slot.kind}:{slot.island}`] = true
	end
	assert(seenSlots["cash:home"] and seenSlots["goods:home"], "the home island has both pets")
	for recipeId in config.PRODUCTION_RECIPES do
		local recipe = config.PRODUCTION_RECIPES[recipeId]
		local kind = logic.petKind(recipe, farmMath)
		if kind and data.purchased[recipe.upgradeId] and data.unlockedIslands[recipe.island] then
			assert(
				seenSlots[`{kind}:{farmMath.petIsland(recipe)}`],
				`{recipe.island} has a {kind} pet for its facility`
			)
		end
	end
	-- Balık tesisleri (ana adadaki kafes) süt/yumurta tesisleriyle aynı yardımcıyı paylaşmaz: ayrı "sea" yardımcısı
	local seaData = newData()
	seaData.purchased.fishing_boat, seaData.purchased.fish_cannery = true, true
	farmMath.applyDerived(seaData)
	local seaSlots: { [string]: boolean } = {}
	for _, slot in logic.petSlots(seaData, config.PRODUCTION_ORDER, farmMath, config) do
		seaSlots[`{slot.kind}:{slot.island}`] = true
	end
	assert(
		seaSlots["cash:home"] and seaSlots["cash:sea"],
		"the boat gets its own cash pet besides the milk factory pet"
	)
	assert(seaSlots["goods:home"] and seaSlots["goods:sea"], "the cannery gets its own goods pet")
	local barePet = newData()
	barePet.purchased.pet_cash_lv1 = nil
	for _, slot in logic.petSlots(barePet, config.PRODUCTION_ORDER, farmMath, config) do
		assert(slot.kind ~= "cash", "no cash pet without the helper upgrade")
	end

	-- Elle başlatılmış partiler: hazır olunca yardımcı teslim alır (tekrar kapalıyken yenisini başlatmaz)
	local hooks = hooksFor(data)
	assert(logic.start(data, data, cashRecipe, "medium", now, farmMath, hooks), "a cash batch starts")
	assert(logic.start(data, data, goodsRecipe, nil, now, farmMath, hooks), "a goods batch starts")
	local early = run(data, now + 1)
	assert(next(early.changedFarms) == nil and early.cash == 0, "pets do nothing before the batch is ready")
	local cashBefore = data.cash
	local late = run(data, now + 1000)
	assert(late.cash > 0 and data.cash == cashBefore + late.cash, "the cash pet collects the finished batch")
	assert(data.production.packed_milk == nil and data.production.milk_goods == nil, "claimed jobs are cleared")
	local claims = late.claims[data.activeMainFarmId]
	assert(
		claims ~= nil and claims["cash:home"] == 1 and claims["goods:home"] == 1,
		"pet deliveries are counted per kind for the walk animation"
	)
	assert(farmMath.getGoodsAmount(data, "milk") > 0, "the goods pet stores products in the shared barn")
	assert(#late.goodsMessages == 1, "one barn message for the goods batch")
	for _, animal in data.animals do
		assert(animal.task == nil, "animals return when the pet collects")
	end

	-- Otomatik tekrar: aynı parti yeniden başlar
	data.autoRepeat.packed_milk = "medium"
	data.autoRepeat.milk_goods = "default"
	assert(logic.start(data, data, cashRecipe, "medium", now + 2000, farmMath, hooks), "manual start still works")
	local repeated = run(data, now + 5000)
	assert(repeated.cash > 0 and repeated.started >= 1, "a repeating batch is collected and restarted")
	assert(data.production.packed_milk ~= nil, "the cash batch runs again")
	assert(data.production.milk_goods ~= nil, "the goods batch runs again")
	assert(data.production.packed_milk.optionId == "medium", "the chosen batch size is repeated")

	-- Depo doluysa ürün partisi bekler (boşa gitmez)
	local full = newData()
	assert(
		logic.start(full, full, goodsRecipe, nil, now, farmMath, hooksFor(full)),
		"goods batch for the full-barn case"
	)
	farmMath.addGoods(full, "milk", farmMath.getGoodsCap(full))
	local blocked = run(full, now + 1000)
	assert(full.production.milk_goods ~= nil and #blocked.goodsMessages == 0, "a full barn keeps the batch waiting")
	farmMath.removeGoods(full, "milk", farmMath.getGoodsCap(full))
	run(full, now + 1001)
	assert(
		full.production.milk_goods == nil and farmMath.getGoodsAmount(full, "milk") > 0,
		"collected once there is room"
	)

	-- Yardımcı yoksa hiçbir şey yapmaz
	local lonely = newData()
	lonely.purchased.pet_cash_lv1 = nil
	lonely.purchased.pet_goods_lv1 = nil
	assert(logic.start(lonely, lonely, cashRecipe, "small", now, farmMath, hooksFor(lonely)), "batch without pets")
	lonely.autoRepeat.packed_milk = "small"
	assert(next(run(lonely, now + 1000).changedFarms) == nil, "without a pet nothing is collected or repeated")

	-- Park edilmiş çiftlik de çalışır; ürün ortak depoya gider
	local parked = newData()
	local second = codec.newFarm(config, farmMath, now, uid, "2")
	for _, upgrade in config.UPGRADES do
		second.purchased[upgrade.id] = true
	end
	second.unlockedIslands.home = true
	second.animals = {}
	for _ = 1, 6 do
		table.insert(second.animals, { uid = uid(), animalId = "cow", zoneId = "starter", bornAt = 0, stage = "adult" })
	end
	second.unlockedZones.starter = true
	second.barnLevel = 2
	second.autoRepeat = { milk_goods = "default" }
	second.inventory = parked.inventory
	parked.mainFarms["2"] = second
	local parkedHooks = hooksFor(parked)
	assert(logic.start(parked, second, goodsRecipe, nil, now, farmMath, parkedHooks), "a parked farm can run a batch")
	local parkedRun = run(parked, now + 1000)
	assert(parkedRun.changedFarms["2"] == true, "the parked farm's pet collected its batch")
	assert(farmMath.getGoodsAmount(parked, "milk") > 0, "parked farms feed the shared barn")
	assert(second.production.milk_goods ~= nil, "and restarted it")

	-- Kayıt: otomatik tekrar saklanır; yardımcısı olmayan çiftlikte atılır; bilinmeyen parti atılır
	local stored = newData()
	stored.autoRepeat = { packed_milk = "large", milk_goods = "default" }
	local snap = codec.encode(stored, now)
	assert(snap.mainFarms["1"].autoRepeat.packed_milk == "large", "the repeat choice is saved")
	local reloaded = assert(codec.decode(snap, config, farmMath, now, uid), "saved repeats reload")
	assert(
		reloaded.autoRepeat.packed_milk == "large" and reloaded.autoRepeat.milk_goods == "default",
		"the repeat choice survives a reload"
	)
	local bogus = table.clone(snap)
	bogus.mainFarms = table.clone(snap.mainFarms)
	bogus.mainFarms["1"] = table.clone(snap.mainFarms["1"])
	bogus.mainFarms["1"].autoRepeat =
		{ packed_milk = "huge", milk_goods = "default", ghost = "default", hatchery = "default" }
	local repaired = assert(codec.decode(bogus, config, farmMath, now, uid), "a bad repeat record is repaired")
	assert(
		repaired.autoRepeat.packed_milk == nil and repaired.autoRepeat.ghost == nil,
		"unknown batches and recipes are dropped"
	)
	assert(repaired.autoRepeat.hatchery == "default", "a hatchery repeat is a valid cash-pet repeat")
	assert(repaired.autoRepeat.milk_goods == "default", "a valid repeat is kept")

	-- Kuluçka (output = chicken): para yardımcısı partiyi teslim alır (civciv kümeye eklenir) ve tekrar başlatır
	do
		local hatchery = config.PRODUCTION_RECIPES.hatchery
		assert(logic.petKind(hatchery, farmMath) == "cash", "the hatchery is run by the cash pet")
		local function henHouse(): any
			local hd = newData()
			hd.animals = {}
			for _ = 1, 2 do
				table.insert(
					hd.animals,
					{ uid = uid(), animalId = "chicken", zoneId = "poultry", bornAt = 0, stage = "adult" }
				)
			end
			hd.autoRepeat = { hatchery = "default" }
			return hd
		end
		local hd = henHouse()
		assert(farmMath.findZoneForAnimal(hd, "chicken") ~= nil, "fixture has coop room")
		assert(logic.start(hd, hd, hatchery, nil, now, farmMath, hooksFor(hd)), "a hatch starts")
		local readyAt = hd.production.hatchery.readyAt
		local before = #hd.animals
		local hatchEarly = run(hd, now + 1)
		assert(next(hatchEarly.changedFarms) == nil and #hd.animals == before, "nothing hatches hatchEarly")
		local hatchLate = run(hd, readyAt + 1)
		assert(#hd.animals == before + 1, "the pet adds the chick to the coop")
		assert(
			hatchLate.claims["1"] ~= nil and hatchLate.claims["1"]["cash:poultry"] == 1,
			"the hatch counts as a cash-pet delivery"
		)
		assert(hd.production.hatchery ~= nil and hatchLate.started >= 1, "the hatchery restarts automatically")

		-- Yardımcı yoksa otomatik teslim olmaz (parti elle alınmayı bekler)
		local bare = henHouse()
		bare.purchased.pet_cash_lv1 = nil
		assert(not farmMath.hasPet(bare, "cash"), "fixture has no cash pet")
		assert(logic.start(bare, bare, hatchery, nil, now, farmMath, hooksFor(bare)), "hatch without pet starts")
		local bareBefore = #bare.animals
		run(bare, bare.production.hatchery.readyAt + 1)
		assert(#bare.animals == bareBefore and bare.production.hatchery ~= nil, "without the pet the hatch waits")
		assert(
			logic.canClaimAutomatically(bare, bare, hatchery, bare.production.hatchery, readyAt + 1, farmMath),
			"(room exists, only the pet is missing)"
		)

		-- Küme dolu: teslim bekler, hiçbir şey kaybolmaz; yer açılınca teslim edilir
		local fullCoop = henHouse()
		assert(
			logic.start(fullCoop, fullCoop, hatchery, nil, now, farmMath, hooksFor(fullCoop)),
			"hatch starts before the coop fills"
		)
		local cap = farmMath.getZoneCapacity(fullCoop, "poultry")
		while farmMath.findZoneForAnimal(fullCoop, "chicken") ~= nil do
			table.insert(
				fullCoop.animals,
				{ uid = uid(), animalId = "chicken", zoneId = "poultry", bornAt = 0, stage = "adult" }
			)
			assert(#fullCoop.animals <= cap + 50, "coop eventually fills")
		end
		local fullCount = #fullCoop.animals
		local waiting = run(fullCoop, fullCoop.production.hatchery.readyAt + 1)
		assert(
			#fullCoop.animals == fullCount and fullCoop.production.hatchery ~= nil and waiting.started == 0,
			"a fullCoop coop keeps the finished hatch waiting"
		)
		table.remove(fullCoop.animals)
		run(fullCoop, fullCoop.production.hatchery.readyAt + 2)
		assert(#fullCoop.animals == fullCount, "the chick is delivered once room opens")
	end
	print("PASS pets: auto-collect, auto-repeat, fullCoop barn wait, parked farms, shared barn and save repairs")
end
