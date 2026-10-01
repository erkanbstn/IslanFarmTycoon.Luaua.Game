--!strict
-- Hayvan servisi: gerçek servis kaynağı; sahip, parası yok, tekrar istek, yanlış çiftlik, hız sınırı, satış ve tüccar.
return function(
	createService: any,
	createHarness: any,
	createLimiter: any,
	codec: any,
	config: any,
	farmMath: any,
	merchant: any
)
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
			h.task
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
	assert(data.animals[#data.animals].stage == "calf", "bought animals start as calves")
	assert(
		h.counters.pushes == 1 and h.counters.saves == 1 and h.counters.refreshes == 1,
		"state pushed, saved, redrawn"
	)
	assert(h.counters.settles == 1 and h.metricCounts.AnimalsPurchased == 1, "income settled, purchase counted")

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

	-- Gezgin tüccar: teklif yokken reddedilir; teklif varken bir kez alınır, tekrar alınamaz
	local trader = setup()
	local tdata = trader.data
	local noOffer = trader.fire("RequestBuyMerchantOffer", nil, trader.nextId(), tdata.activeMainFarmId)
	assert(noOffer and noOffer.ok == false, "no offer, no purchase")
	tdata.adminForce = { merchantUntil = trader.now + 600 }
	local offer = assert(merchant.offer(tdata, trader.player.UserId, trader.now), "the forced visit makes an offer")
	tdata.cash = offer.price - 1
	local poor = trader.fire("RequestBuyMerchantOffer", nil, trader.nextId(), tdata.activeMainFarmId)
	assert(poor and poor.ok == false and tdata.merchant == nil, "an unaffordable offer is refused")
	tdata.cash = offer.price
	local animalsBeforeOffer = #tdata.animals
	local bought = trader.fire("RequestBuyMerchantOffer", nil, trader.nextId(), tdata.activeMainFarmId)
	assert(bought and bought.ok == true and tdata.cash == 0, "the offer is bought at the server price")
	assert(#tdata.animals == animalsBeforeOffer + offer.count, "the offered animals arrive")
	assert(tdata.merchant and tdata.merchant.bought == true, "the bought mark is written immediately")
	tdata.cash = offer.price
	local again = trader.fire("RequestBuyMerchantOffer", nil, trader.nextId(), tdata.activeMainFarmId)
	assert(again and again.ok == false and tdata.cash == offer.price, "a second purchase in the same visit is refused")

	-- Balık değiştirme: bilinmeyen kimlik reddedilir (para düşmez)
	local fish = setup()
	fish.data.cash = 1e6
	local missing = fish.fire("RequestReplaceFish", "no-such-animal", fish.nextId(), fish.data.activeMainFarmId)
	assert(missing and missing.ok == false and fish.data.cash == 1e6, "an unknown fish uid is refused")
	print(
		"PASS animal service: actual service ownership, no-cash, replay, stale farm, throttling, sell, merchant and fish guards"
	)
end
