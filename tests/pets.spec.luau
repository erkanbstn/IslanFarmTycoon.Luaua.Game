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
		claims ~= nil and claims.cash == 1 and claims.goods == 1,
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
		repaired.autoRepeat.packed_milk == nil
			and repaired.autoRepeat.ghost == nil
			and repaired.autoRepeat.hatchery == nil,
		"unknown batches, recipes and non-pet recipes are dropped"
	)
	assert(repaired.autoRepeat.milk_goods == "default", "a valid repeat is kept")
	print("PASS pets: auto-collect, auto-repeat, full barn wait, parked farms, shared barn and save repairs")
end
