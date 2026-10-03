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
	for index = 1, 250 do
		ReceiptLog.add(save, `id{index}`)
	end
	assert(#save.receipts == 251 and ReceiptLog.has(save, "r1"), "more than 200 purchases never evict an old receipt")
	local full: any = { receipts = table.create(ReceiptLog.MAX) }
	for index = 1, ReceiptLog.MAX do
		full.receipts[index] = `full{index}`
	end
	assert(not ReceiptLog.add(full, "new"), "a full ledger rejects new receipts without eviction")
	assert(#full.receipts == ReceiptLog.MAX and ReceiptLog.has(full, "full1"), "capacity never removes old receipts")
	local capacityApplied = false
	assert(ReceiptLog.grant(full, "new", function(): boolean
		capacityApplied = true
		return true
	end) == "full" and not capacityApplied, "capacity blocks rewards before applying them")
	assert(ReceiptLog.grant(full, "full1", function(): boolean
		error("duplicate must not apply")
	end) == "duplicate", "a full ledger still acknowledges old receipts")

	-- Ödül verilemezse makbuz günlükte kalmaz; başarıda kalır, tekrar "duplicate" döner
	local grantSave: any = {}
	local applied = 0
	assert(ReceiptLog.grant(grantSave, "g1", function(): boolean
		applied += 1
		return false
	end) == "failed", "a failed grant is reported")
	assert(not ReceiptLog.has(grantSave, "g1"), "a failed grant leaves no receipt behind")
	assert(ReceiptLog.grant(grantSave, "g1", function(): boolean
		error("boom")
	end) == "failed" and not ReceiptLog.has(grantSave, "g1"), "an erroring grant is rolled back too")
	assert(ReceiptLog.grant(grantSave, "g1", function(): boolean
		applied += 1
		return true
	end) == "granted" and ReceiptLog.has(grantSave, "g1"), "the retry after a failure grants the reward")
	assert(ReceiptLog.grant(grantSave, "g1", function(): boolean
		applied += 1
		return true
	end) == "duplicate" and applied == 2, "a granted receipt is never rewarded twice")
	assert(ReceiptLog.grant(grantSave, "", function(): boolean
		return true
	end) == "failed", "an invalid receipt id is not granted")

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
			product.effect == "instantProduction"
				or product.effect == "incomePack"
				or product.effect == "goldPack"
				or product.effect == "runDouble"
				or product.effect == "permanentOffer",
			`product {key} needs a known effect`
		)
	end

	-- Kayıtta makbuzlar: geçerli olanlar korunur, sahtesi elenir
	local raw = SaveCodec.encode(farm(), 1000)
	raw.receipts = { "a1", "b2", "a1", 5, "", string.rep("z", 60), { "x" } }
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
	end)).receipts == 500, "loading never evicts valid receipt history")
	raw.receipts = full.receipts
	table.insert(raw.receipts, "legacy-over-capacity")
	local over = assert(SaveCodec.decode(raw, Config, FarmMath, 2000, function()
		return "u"
	end))
	assert(#over.receipts == ReceiptLog.MAX + 1, "over-capacity existing history is preserved")
	assert(not ReceiptLog.add(over, "new"), "over-capacity profiles cannot grow the receipt ledger")
	local reloaded = assert(SaveCodec.decode(SaveCodec.encode(over, 2000), Config, FarmMath, 2000, function()
		return "u"
	end))
	assert(
		ReceiptLog.has(reloaded, "full1") and ReceiptLog.has(reloaded, "legacy-over-capacity"),
		"save/reload preserves every tombstone"
	)
	local kept = farm()
	kept.receipts = { "keep1" }
	assert(SaveCodec.encode(kept, 1000).receipts[1] == "keep1", "receipts survive saves")
	local checkpoint = SaveCodec.encode(kept, 1000)
	local checkpointCash = checkpoint.cash
	assert(ReceiptLog.grant(kept, "later-receipt", function(): boolean
		kept.cash += 100
		return true
	end) == "granted", "a later receipt updates the live profile")
	assert(
		checkpoint.cash == checkpointCash and #checkpoint.receipts == 1,
		"a pending snapshot cannot gain a receipt marker without its matching cash"
	)
	assert(not table.find(checkpoint.receipts, "later-receipt"), "encoded receipts are detached from subsequent grants")
	ReceiptLog.remove(kept, "keep1")
	assert(checkpoint.receipts[1] == "keep1", "live receipt removal cannot alter the pending snapshot")
	assert(SaveCodec.encode(farm(), 1000).passes == nil, "passes are runtime only and never saved")
	print("PASS monetization: receipt log, pass effects, receipt save bounds")
end
