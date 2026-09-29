--!strict
-- Makbuz günlüğü (çift ödeme koruması), oyun geçidi etkileri ve makbuz kaydı sınırları.
return function(ReceiptLog: any, FarmMath: any, Config: any, SaveCodec: any)
	-- Makbuz günlüğü: ilk ekleme başarılı, tekrar reddedilir, sınırlı
	local save: any = {}
	assert(not ReceiptLog.has(save, "r1"), "empty log has no receipts")
	assert(ReceiptLog.add(save, "r1"), "a new receipt is recorded")
	assert(ReceiptLog.has(save, "r1"), "recorded receipts are found")
	assert(not ReceiptLog.add(save, "r1"), "the same receipt cannot be granted twice")
	assert(#save.receipts == 1, "duplicate did not grow the log")
	assert(not ReceiptLog.add(save, ""), "empty ids are rejected")
	assert(not ReceiptLog.add(save, string.rep("x", 41)), "oversized ids are rejected")
	for index = 1, ReceiptLog.MAX + 50 do
		ReceiptLog.add(save, `id{index}`)
	end
	assert(#save.receipts == ReceiptLog.MAX, "the log is bounded")
	assert(
		not ReceiptLog.has(save, "r1") and ReceiptLog.has(save, `id{ReceiptLog.MAX + 50}`),
		"oldest receipts are dropped first"
	)

	-- Oyun geçidi etkileri (sunucu doğrular; FarmMath yalnızca uygular)
	local function farm(): any
		local data: any = {
			cash = 0,
			stored = 0,
			purchased = {},
			animals = {},
			barnLevel = 1,
			unlockedIslands = {},
			unlockedZones = {},
		}
		FarmMath.applyDerived(data)
		for index = 1, 4 do
			table.insert(
				data.animals,
				{ uid = `c{index}`, animalId = "cow", zoneId = "starter", bornAt = 0, stage = "adult" }
			)
		end
		return data
	end
	local plain = farm()
	local baseIncome, baseCap = FarmMath.computeIncomePerSecond(plain), FarmMath.getStorageCap(plain)
	assert(not FarmMath.hasAutoCollect(plain), "no auto collect without a pass")
	local pass = farm()
	pass.passes = { double_income = true }
	assert(math.abs(FarmMath.computeIncomePerSecond(pass) - baseIncome * 2) < 0.0001, "the income pass doubles income")
	pass.passes = { extra_storage = true }
	assert(FarmMath.getStorageCap(pass) > baseCap, "the storage pass raises capacity")
	pass.passes = { auto_collector = true }
	assert(FarmMath.hasAutoCollect(pass), "the auto collector pass collects automatically")
	pass.passes = { not_a_pass = true }
	assert(
		FarmMath.computeIncomePerSecond(pass) == baseIncome and not FarmMath.hasAutoCollect(pass),
		"unknown passes do nothing"
	)
	for key, product in Config.PRODUCTS.passes do
		assert(typeof(product.id) == "number" and product.id >= 0, `pass {key} id must be a non-negative number`)
	end
	for key, product in Config.PRODUCTS.products do
		assert(
			product.effect == "instantProduction" or product.effect == "incomePack",
			`product {key} needs a known effect`
		)
	end

	-- Kayıtta makbuzlar: geçerli olanlar korunur, sahtesi elenir
	local raw = SaveCodec.encode(farm(), 1000)
	raw.receipts = { "a1", "b2", 5, "", string.rep("z", 60), { "x" } }
	local decoded = assert(SaveCodec.decode(raw, Config, FarmMath, 2000, function()
		return "u"
	end))
	assert(
		#decoded.receipts == 2 and decoded.receipts[1] == "a1" and decoded.receipts[2] == "b2",
		"only valid receipt ids load"
	)
	raw.receipts = "many"
	assert(#assert(SaveCodec.decode(raw, Config, FarmMath, 2000, function()
		return "u"
	end)).receipts == 0, "non-table receipts are ignored")
	local big = {}
	for index = 1, 500 do
		big[index] = `r{index}`
	end
	raw.receipts = big
	assert(#assert(SaveCodec.decode(raw, Config, FarmMath, 2000, function()
		return "u"
	end)).receipts == 200, "loaded receipts are bounded")
	local kept = farm()
	kept.receipts = { "keep1" }
	assert(SaveCodec.encode(kept, 1000).receipts[1] == "keep1", "receipts survive saves")
	assert(SaveCodec.encode(farm(), 1000).passes == nil, "passes are runtime only and never saved")
	print("PASS monetization: receipt log, pass effects, receipt save bounds")
end
