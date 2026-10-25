--!strict
-- Hayvan servisi: gerçek servis kaynağı; sahip, parası yok, tekrar istek, yanlış çiftlik, hız sınırı ve satış.
return function(createService: any, createHarness: any, createLimiter: any, codec: any, config: any, farmMath: any)
	local harness = createHarness(createLimiter, codec, config, farmMath)
	local function setup(): any
		local h = harness.new()
		createService(
			h.game,
			h.remotes,
			h.dataService,
			h.plotService,
			h.economyService,
			h.limiter,
			h.metrics,
			h.dateTime,
			h.task,
			h.guard
		).init()
		return h
	end
	local function buy(h: any, animalId: any, count: any?, farmId: any?, requestId: any?): any
		return h.fire("RequestBuyAnimal", animalId, requestId or h.nextId(), farmId or h.data.activeMainFarmId, count)
	end

	-- Başarılı alım: tutar sunucuda hesaplanır, hayvan yavru olarak eklenir, durum itilir ve kaydedilir
	local h = setup()
	local data = h.data
	local animalsBefore = #data.animals
	assert(farmMath.getFreeSlots(data, "cow") >= 2, "the fixture has room for cows")
	local price = farmMath.getBulkPrice(data, "cow", 1)
	data.cash = price + 7
	local reply = buy(h, "cow")
	assert(reply and reply.remote == "PurchaseResult" and reply.ok == true, "the owner can buy")
	assert(data.cash == 7, "exactly the server-computed price is spent")
	assert(#data.animals == animalsBefore + 1, "one animal is added")
	local starterCount = config.STARTER_ADULT_ANIMALS
	local cowsBeforeBuy = 0
	for index = 1, animalsBefore do
		if data.animals[index].animalId == "cow" then
			cowsBeforeBuy += 1
		end
	end
	local newest = data.animals[#data.animals]
	assert(
		newest.stage == (if cowsBeforeBuy < starterCount then "adult" else "calf")
			and (newest.bornAt == 0) == (cowsBeforeBuy < starterCount),
		"the farm's first animals of each species are bought adult, later ones as calves"
	)
	assert(
		h.counters.pushes == 1 and h.counters.saves == 1 and h.counters.refreshes == 1,
		"state pushed, saved, redrawn"
	)
	assert(h.counters.settles == 1 and h.metricCounts.AnimalsPurchased == 1, "income settled, purchase counted")

	-- Başlangıç hayvanları dolduktan sonra alınanlar yavru olur
	while #data.animals < starterCount do
		table.insert(data.animals, { uid = `fill-{#data.animals}`, animalId = "cow", zoneId = "starter", bornAt = 0 })
	end
	data.cash = farmMath.getBulkPrice(data, "cow", 1) + 7
	assert(buy(h, "cow").ok == true, "a purchase beyond the starter animals works")
	assert(
		data.animals[#data.animals].stage == "calf" and data.animals[#data.animals].bornAt > 0,
		"later animals start as calves"
	)
	price = farmMath.getBulkPrice(data, "cow", 1)
	animalsBefore = #data.animals - 1

	-- Parası yok: hiçbir şey değişmez, oyuncu nedenini görür
	data.cash = price - 1
	local broke = buy(h, "cow")
	assert(broke and broke.ok == false, "a player without enough cash is refused")
	assert(string.find(broke.message, "Yeterli para yok", 1, true) ~= nil, "the reason mentions the missing cash")
	assert(data.cash == price - 1 and #data.animals == animalsBefore + 1, "a refused purchase changes nothing")
	assert(h.metricCounts.PurchaseRejected == 1, "the rejection is counted")

	-- Tekrar eden istek kimliği: ikinci kez işlenmez
	data.cash = price * 10
	local id = h.nextId()
	local first = buy(h, "cow", nil, nil, id)
	assert(first and first.ok == true, "the first request is processed")
	local animalsAfterFirst, cashAfterFirst = #data.animals, data.cash
	local replay = buy(h, "cow", nil, nil, id)
	assert(replay == nil, "a replayed request id gets no second purchase and no reply")
	assert(#data.animals == animalsAfterFirst and data.cash == cashAfterFirst, "a replay spends nothing")

	-- Yanlış (eski) çiftlik kimliği: işlem yapılmaz, oyuncuya söylenir
	local wrongFarm = buy(h, "cow", nil, "bogus-farm")
	assert(wrongFarm and wrongFarm.ok == false, "a stale farm id is refused")
	assert(
		string.find(wrongFarm.message, "Etkin çiftlik değişti", 1, true) ~= nil,
		"the player is told the farm changed"
	)
	assert(data.cash == cashAfterFirst and #data.animals == animalsAfterFirst, "a stale farm id changes nothing")

	-- Verisi olmayan (yabancı) oyuncu: para ve hayvan hiçbir yere gitmez
	local strangerReply = h.fireAs(h.stranger, "RequestBuyAnimal", "cow", h.nextId(), data.activeMainFarmId, nil)
	assert(strangerReply and strangerReply.ok == false, "a player without save data is refused")
	assert(data.cash == cashAfterFirst and #data.animals == animalsAfterFirst, "no purchase leaks to another save")

	-- Dünya hazır değil / geçersiz girdiler
	h.worldReady = false
	local early = buy(h, "cow")
	assert(
		early and early.ok == false and string.find(early.message, "Veri henüz yüklenmedi", 1, true) ~= nil,
		"not ready"
	)
	h.worldReady = true
	local unknown = buy(h, "dragon")
	assert(unknown and unknown.ok == false and unknown.message == "Bilinmeyen hayvan", "unknown animal id is rejected")
	local badType = buy(h, 5)
	assert(badType and badType.ok == false, "a non-string animal id is rejected")
	local badCount = buy(h, "cow", 4)
	assert(
		badCount and badCount.ok == false and badCount.message == "Geçersiz miktar",
		"a non-listed bulk count is rejected"
	)
	local fractional = buy(h, "cow", 2.5)
	assert(fractional and fractional.ok == false, "a fractional count is rejected")
	local tooMany = buy(h, "cow", 5)
	assert(
		tooMany and tooMany.ok == false and string.find(tooMany.message, "Yeterli yer yok", 1, true) ~= nil,
		"no room"
	)

	-- Hız sınırı: aynı anda ikinci alım reddedilir ve "çok hızlı" cevabı gelir; para yalnızca bir kez düşer
	local limited = setup()
	limited.data.cash = price * 10
	local firstBuy = buy(limited, "cow")
	assert(firstBuy and firstBuy.ok == true, "the first purchase passes the limiter")
	local cashAfter = limited.data.cash
	local spam =
		limited.fireRaw(limited.player, "RequestBuyAnimal", "cow", limited.nextId(), limited.data.activeMainFarmId, nil)
	assert(
		spam and spam.ok == false and spam.message == "Çok hızlı işlem yapıyorsun; biraz bekle.",
		"spam gets the throttle reply"
	)
	assert(limited.data.cash == cashAfter, "the throttled request spends nothing")
	local spamAgain =
		limited.fireRaw(limited.player, "RequestBuyAnimal", "cow", limited.nextId(), limited.data.activeMainFarmId, nil)
	assert(spamAgain == nil, "throttle replies are rate limited too")

	-- Satış: aynı türün en genci, fiyatın yarısı geri; son hayvan satılamaz
	local seller = setup()
	local sdata = seller.data
	for index = 1, 3 do
		table.insert(
			sdata.animals,
			{ uid = `extra-cow-{index}`, animalId = "cow", zoneId = "starter", stage = "adult", bornAt = 0 }
		)
	end
	local cowsBefore = farmMath.countAnimals(sdata, "cow")
	assert(cowsBefore >= 3, "the fixture has several cows to sell")
	local animalsBeforeSale = #sdata.animals
	local refund = farmMath.getSellPrice(sdata, "cow")
	local sold = seller.fire("RequestSellAnimal", "cow", seller.nextId(), sdata.activeMainFarmId)
	assert(sold and sold.ok == true and sdata.cash == refund, "selling refunds the server-computed price")
	assert(#sdata.animals == animalsBeforeSale - 1, "one animal is removed")
	assert(seller.metricCounts.AnimalsSold == 1, "the sale is counted")
	local onlyCow = sdata.animals[table.find(sdata.animals, farmMath.findSellableAnimal(sdata, "cow"))]
	sdata.animals = { onlyCow }
	local cashBeforeLast = sdata.cash
	local last = seller.fire("RequestSellAnimal", "cow", seller.nextId(), sdata.activeMainFarmId)
	assert(last and last.ok == false and sdata.cash == cashBeforeLast, "the last animal cannot be sold")
	local wrongSell = seller.fire("RequestSellAnimal", "cow", seller.nextId(), "bogus-farm")
	assert(
		wrongSell and wrongSell.ok == false and string.find(wrongSell.message, "Etkin çiftlik", 1, true) ~= nil,
		"farm"
	)

	-- Ürünle takas: ürünler düşer + hayvan gelir (tek adım), nakit harcanmaz; yetmeyen ürün, dolu bölge, tekrar, yanlış çiftlik reddedilir
	local barter = setup()
	local bdata = barter.data
	local function barterBuy(h2: any, animalId: any, farmId: any?, requestId: any?): any
		return h2.fire("RequestBarterAnimal", animalId, requestId or h2.nextId(), farmId or h2.data.activeMainFarmId)
	end
	local bprice = farmMath.getBulkPrice(bdata, "cow", 1)
	bdata.goods = {}
	bdata.cash = 123
	local nothingYet = barterBuy(barter, "cow")
	assert(
		nothingYet
			and nothingYet.ok == false
			and string.find(nothingYet.message, "Ürünlerin değeri yetmiyor", 1, true) ~= nil,
		"an empty barn cannot barter"
	)
	assert(bdata.cash == 123, "a refused barter changes nothing")
	local unitValue = math.floor(config.GOODS.milk.value * config.GOODS_BARTER.rate)
	local needed = math.ceil(bprice / unitValue)
	farmMath.addGoods(bdata, "milk", math.min(needed - 1, farmMath.getGoodsCap(bdata)))
	assert(farmMath.getGoodsAmount(bdata, "milk") < needed, "the short stack stays under the price")
	do
		local short = barterBuy(barter, "cow")
		assert(short and short.ok == false, "goods worth just under the price are refused")
		assert(
			farmMath.getGoodsAmount(bdata, "milk") == math.min(needed - 1, farmMath.getGoodsCap(bdata)),
			"the goods are untouched"
		)
	end
	-- Yeterli ürün: gereken kadar ürün düşer, hayvan eklenir, para değişmez
	bdata.goods = {}
	local capNow = farmMath.getGoodsCap(bdata)
	local giveAll = math.min(capNow, needed + 3)
	assert(farmMath.addGoods(bdata, "milk", giveAll) == giveAll, "the barn holds the test goods")
	assert(giveAll >= needed, "the fixture barn can hold enough milk to pay for a cow")
	do
		local animalsBeforeBarter = #bdata.animals
		local pushesBefore = barter.counters.pushes
		local ok = barterBuy(barter, "cow")
		assert(ok and ok.ok == true, "enough goods buys the animal")
		assert(
			#bdata.animals == animalsBeforeBarter + 1 and bdata.cash == 123,
			"one animal arrives and no cash is spent"
		)
		assert(farmMath.getGoodsAmount(bdata, "milk") == giveAll - needed, "only the needed units leave the barn")
		assert(
			barter.counters.pushes == pushesBefore + 1 and barter.metricCounts.AnimalsBartered == 1,
			"state is pushed and the barter counted"
		)
		assert(string.find(ok.message, "Ürünlerle takas edildi", 1, true) ~= nil, "the player gets a confirmation")
		assert(needed * unitValue >= bprice, "the goods that left cover the price")
		assert(
			farmMath.getGoodsSellValue("milk", needed) >= needed * unitValue,
			"bartering never pays more than selling the same goods"
		)
	end

	-- Toplu takas (x5): bedel 5 hayvanın toplam fiyatıdır, 5 hayvan gelir; geçersiz çarpan ve yetmeyen ürün reddedilir
	do
		local bulk = setup()
		local kdata = bulk.data
		local bulkPrice = farmMath.getBulkPrice(kdata, "cow", 5)
		kdata.cash = 77
		kdata.goods = {}
		farmMath.addGoods(kdata, "milk", farmMath.getGoodsCap(kdata))
		local plan = farmMath.planGoodsBarter(kdata, bulkPrice)
		assert(plan, "the fixture barn holds enough goods for five cows")
		local goodsBefore = farmMath.getGoodsAmount(kdata, "milk")
		local invalid = bulk.fire("RequestBarterAnimal", "cow", bulk.nextId(), kdata.activeMainFarmId, 7)
		assert(invalid and invalid.ok == false, "a multiplier outside BULK_MULTIPLIERS is refused")
		assert(farmMath.getGoodsAmount(kdata, "milk") == goodsBefore, "a refused bulk barter changes nothing")
		local animalsBeforeBulk = #kdata.animals
		local bulkOk = bulk.fire("RequestBarterAnimal", "cow", bulk.nextId(), kdata.activeMainFarmId, 5)
		assert(bulkOk and bulkOk.ok == true, "x5 barter succeeds with enough goods")
		assert(#kdata.animals == animalsBeforeBulk + 5 and kdata.cash == 77, "five animals arrive and no cash is spent")
		assert(
			farmMath.getGoodsAmount(kdata, "milk") == goodsBefore - (plan.milk or 0),
			"the goods for five animals leave the barn"
		)
		assert(bulk.metricCounts.AnimalsBartered == 5, "five barters are counted")
		-- Ürün beş hayvanın bedelinin bir birim altında: hiçbir şey değişmez: hiçbir şey değişmez
		local poorBulk = setup()
		local pdata = poorBulk.data
		pdata.goods = {}
		local milkUnit = math.floor(config.GOODS.milk.value * config.GOODS_BARTER.rate)
		local unitsForFive = math.ceil(farmMath.getBulkPrice(pdata, "cow", 5) / milkUnit)
		assert(unitsForFive >= 2, "five cows need more than one unit of milk")
		farmMath.addGoods(pdata, "milk", unitsForFive - 1)
		local animalsPoor = #pdata.animals
		local short = poorBulk.fire("RequestBarterAnimal", "cow", poorBulk.nextId(), pdata.activeMainFarmId, 5)
		assert(
			short and short.ok == false and #pdata.animals == animalsPoor,
			"goods just short of the five-cow price cannot buy five"
		)
	end

	-- Doğrulama: bilinmeyen tür, yanlış çiftlik, yabancı, tekrar, kilitli ve dolu bölge, hız sınırı
	local guardBarter = setup()
	local gdata = guardBarter.data
	gdata.goods = {}
	farmMath.addGoods(gdata, "cheese", farmMath.getGoodsCap(gdata))
	gdata.cash = 5
	local stock = farmMath.getGoodsAmount(gdata, "cheese")
	assert(stock > 0, "the fixture holds goods")
	for _, bad in { "dragon", 5, "", {} } do
		local refusedReply = barterBuy(guardBarter, bad)
		assert(refusedReply and refusedReply.ok == false, "an unknown animal is refused")
	end
	local staleFarm = barterBuy(guardBarter, "cow", "bogus-farm")
	assert(
		staleFarm
			and staleFarm.ok == false
			and string.find(staleFarm.message, "Etkin çiftlik değişti", 1, true) ~= nil,
		"farm"
	)
	local strangerBarter = guardBarter.fireAs(
		guardBarter.stranger,
		"RequestBarterAnimal",
		"cow",
		guardBarter.nextId(),
		gdata.activeMainFarmId
	)
	assert(
		strangerBarter and strangerBarter.ok == false and farmMath.getGoodsAmount(gdata, "cheese") == stock,
		"a player without data cannot barter"
	)
	local before2 = #gdata.animals
	local fixedId = guardBarter.nextId()
	local firstBarter = barterBuy(guardBarter, "cow", nil, fixedId)
	assert(firstBarter and firstBarter.ok == true and #gdata.animals == before2 + 1, "cheese pays for a cow")
	local stockAfter = farmMath.getGoodsAmount(gdata, "cheese")
	assert(
		guardBarter.fireRaw(guardBarter.player, "RequestBarterAnimal", "cow", fixedId, gdata.activeMainFarmId) == nil,
		"a replayed request id is ignored"
	)
	assert(
		#gdata.animals == before2 + 1 and farmMath.getGoodsAmount(gdata, "cheese") == stockAfter,
		"a replay trades nothing"
	)
	local barterSpam = guardBarter.fireRaw(
		guardBarter.player,
		"RequestBarterAnimal",
		"cow",
		guardBarter.nextId(),
		gdata.activeMainFarmId
	)
	assert(
		barterSpam and barterSpam.ok == false and barterSpam.message == "Çok hızlı işlem yapıyorsun; biraz bekle.",
		"spam gets the throttle reply"
	)
	assert(
		farmMath.getGoodsAmount(gdata, "cheese") == stockAfter and #gdata.animals == before2 + 1,
		"the throttled request trades nothing"
	)
	-- Dolu bölge: ürün düşmez
	local fullBarter = setup()
	local fdata = fullBarter.data
	fdata.goods = {}
	farmMath.addGoods(fdata, "cheese", farmMath.getGoodsCap(fdata))
	while farmMath.getFreeSlots(fdata, "cow") > 0 do
		table.insert(fdata.animals, { uid = `full-{#fdata.animals}`, animalId = "cow", zoneId = "starter", bornAt = 0 })
	end
	local cheeseBefore = farmMath.getGoodsAmount(fdata, "cheese")
	local full = barterBuy(fullBarter, "cow")
	assert(
		full and full.ok == false and farmMath.getGoodsAmount(fdata, "cheese") == cheeseBefore,
		"a full zone refuses the barter and keeps the goods"
	)
	fullBarter.worldReady = false
	local notReady = barterBuy(fullBarter, "cow")
	assert(notReady and notReady.ok == false and farmMath.getGoodsAmount(fdata, "cheese") == cheeseBefore, "not ready")

	-- Küçük balık satışı: çiftlikte başka hayvan varken tek hamsi de satılır; görevdeki satılmaz ve sebep söylenir
	local fish = setup()
	local fishData = fish.data
	fishData.unlockedZones.fishpen = true
	local lone: any = { uid = "lone-fish", animalId = "anchovy", zoneId = "fishpen", bornAt = 0, stage = "adult" }
	table.insert(
		fishData.animals,
		{ uid = "pen-cow", animalId = "cow", zoneId = "starter", stage = "adult", bornAt = 0 }
	)
	table.insert(fishData.animals, lone)
	assert(farmMath.countAnimals(fishData, "anchovy") == 1, "the farm has exactly one small fish")
	assert(farmMath.getSellBlockReason(fishData, "anchovy") == nil, "a lone small fish is sellable")
	assert(farmMath.getSellBlockReason(fishData, "seabass") == "Bu hayvandan yok", "an unowned species has no sale")
	assert(farmMath.getSellBlockReason(fishData, "no-such-animal") == "Bilinmeyen hayvan", "unknown species")
	local fishRefund = farmMath.getSellPrice(fishData, "anchovy")
	assert(fishRefund > 0, "the small fish refunds money")
	for _, kind in { "production", "extension" } do
		lone.task = { kind = kind, id = "fish_dispatch", startedAt = 0, endsAt = math.huge }
		assert(farmMath.getSellBlockReason(fishData, "anchovy") == "Hayvan görevde", "a task animal reports why")
		local busy = fish.fire("RequestSellAnimal", "anchovy", fish.nextId(), fishData.activeMainFarmId)
		assert(
			busy
				and busy.ok == false
				and busy.message == "Hayvan görevde"
				and fishData.cash == 0
				and table.find(fishData.animals, lone) ~= nil,
			"a busy small fish is refused with the reason and keeps the money"
		)
	end
	lone.task = nil
	local fishSale = fish.fire("RequestSellAnimal", "anchovy", fish.nextId(), fishData.activeMainFarmId)
	assert(
		fishSale
			and fishSale.ok == true
			and fishData.cash == fishRefund
			and farmMath.countAnimals(fishData, "anchovy") == 0
			and table.find(fishData.animals, lone) == nil,
		"the lone small fish is sold for the server refund"
	)
	local soleFish: any = { uid = "sole-fish", animalId = "anchovy", zoneId = "fishpen", bornAt = 0, stage = "adult" }
	fishData.animals = { soleFish }
	assert(farmMath.getSellBlockReason(fishData, "anchovy") == "Son hayvan satılamaz", "the last animal reports why")

	-- Satış tamamlanmayı bozmaz: tamamlanma satın alınan yükseltme/geliştirme/ırk seviyesinden okunur; gerçek servisle satış bunlara dokunmaz
	local keeper = setup()
	local kdata = keeper.data
	for index = 1, 4 do
		table.insert(
			kdata.animals,
			{ uid = `keep-cow-{index}`, animalId = "cow", zoneId = "starter", stage = "adult", bornAt = 0 }
		)
	end
	kdata.expansions = { starter = 2 }
	kdata.lineage = { cow = 2 }
	kdata.purchased.keep_marker = true
	local function levels(): string
		local parts = {}
		for purchasedId in kdata.purchased do
			table.insert(parts, `p:{purchasedId}`)
		end
		for zoneKey, level in kdata.expansions do
			table.insert(parts, `e:{zoneKey}={level}`)
		end
		for animalKey, level in kdata.lineage do
			table.insert(parts, `l:{animalKey}={level}`)
		end
		table.sort(parts)
		return table.concat(parts, ",")
	end
	local levelsBefore = levels()
	local soldCows = 0
	while farmMath.getSellBlockReason(kdata, "cow") == nil do
		local saleReply = keeper.fire("RequestSellAnimal", "cow", keeper.nextId(), kdata.activeMainFarmId)
		assert(saleReply and saleReply.ok == true, "every allowed sale goes through the real service")
		soldCows += 1
		assert(soldCows < 100, "selling terminates")
	end
	assert(soldCows >= 3 and #kdata.animals == 1, "selling continues down to the farm's last animal")
	assert(
		levels() == levelsBefore,
		"selling animals through the service never changes purchases, expansions or lineage"
	)
	print(
		"PASS animal service: actual service ownership, no-cash, replay, stale farm, throttling, sell, small-fish sale and completion-safe selling"
	)
end
