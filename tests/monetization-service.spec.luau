--!strict
-- Gelir servisi: gerçek servis kaynağı; makbuz işleme (çift ödeme yok, kayıt yazılamazsa tekrar), geçit ve ürün istemleri.
return function(createService: any, createHarness: any, createLimiter: any, codec: any, config: any, farmMath: any)
	local harness = createHarness(createLimiter, codec, config, farmMath)
	local decision = { NotProcessedYet = "NotProcessedYet", PurchaseGranted = "PurchaseGranted" }
	local fakeEnum = { ProductPurchaseDecision = decision }

	-- Ürün kimlikleri Creator Hub'da oluşturulana kadar 0'dır (kapalı); test için geçici olarak açılır.
	local products = config.PRODUCTS.products
	local passes = config.PRODUCTS.passes
	local saved = {
		income = products.income_pack.id,
		instant = products.instant_production.id,
		pass = passes.double_income.id,
		effect = products.income_pack.effect,
	}
	products.income_pack.id = 9001
	products.instant_production.id = 9002
	passes.double_income.id = 7001

	local function setup(): any
		local h = harness.new()
		local owned: { [number]: boolean } = { [7001] = true }
		local market: any = {
			PromptGamePassPurchaseFinished = { Connect = nil },
			productPrompts = {},
			passPrompts = {},
		}
		local finished = { callbacks = {} }
		market.PromptGamePassPurchaseFinished = {
			Connect = function(_self: any, callback: any)
				table.insert(finished.callbacks, callback)
			end,
		}
		market.UserOwnsGamePassAsync = function(_self: any, _userId: number, passId: number): boolean
			return owned[passId] == true
		end
		market.PromptProductPurchase = function(_self: any, player: any, id: number)
			table.insert(market.productPrompts, { player = player, id = id })
		end
		market.PromptGamePassPurchase = function(_self: any, player: any, id: number)
			table.insert(market.passPrompts, { player = player, id = id })
		end
		h.services.MarketplaceService = market
		h.market = market
		h.finishPass = function(player: any, passId: number, purchased: boolean)
			for _, callback in finished.callbacks do
				callback(player, passId, purchased)
			end
		end
		h.service = createService(h.game, h.remotes, h.dataService, h.limiter, h.metrics, fakeEnum, h.warn)
		h.service.init()
		h.receipt = function(purchaseId: any, productId: number, playerId: number?): any
			return { PurchaseId = purchaseId, ProductId = productId, PlayerId = playerId or h.player.UserId }
		end
		h.notifies = function(): number
			local count = 0
			for _, entry in h.sent do
				if entry.remote == "Notify" then
					count += 1
				end
			end
			return count
		end
		return h
	end

	-- init ProcessReceipt'i bağlar
	local h = setup()
	assert(h.market.ProcessReceipt == h.service.processReceipt, "init wires the receipt callback")
	local data = h.data

	-- Geçersiz makbuzlar ödül vermez
	assert(h.service.processReceipt(nil) == decision.NotProcessedYet, "a non-table receipt is not processed")
	assert(
		h.service.processReceipt({ ProductId = 9001, PlayerId = h.player.UserId }) == decision.NotProcessedYet,
		"no id"
	)
	assert(h.service.processReceipt(h.receipt("r-ghost", 9001, 999)) == decision.NotProcessedYet, "the player left")
	assert(
		h.service.processReceipt(h.receipt("r-unknown", 123456)) == decision.NotProcessedYet,
		"an unknown product is held"
	)
	assert(
		h.service.processReceipt(h.receipt("r-zero", 0)) == decision.NotProcessedYet,
		"product id 0 is never matched"
	)
	h.worldReady = false
	assert(h.service.processReceipt(h.receipt("r-early", 9001)) == decision.NotProcessedYet, "the world is not ready")
	h.worldReady = true
	products.income_pack.effect = "bogus"
	assert(
		h.service.processReceipt(h.receipt("r-bad-effect", 9001)) == decision.NotProcessedYet,
		"unsupported effects are held"
	)
	products.income_pack.effect = saved.effect
	assert(data.cash == 0 and (data.receipts == nil or #data.receipts == 0), "nothing was granted or recorded so far")

	-- Başarılı makbuz: ödül bir kez verilir, makbuz yazılır, kayıt diske gider
	local expected = math.floor(
		math.max(
			farmMath.computeIncomePerSecond(data) * 3600 * (products.income_pack.incomeHours or 1),
			config.PRODUCT_MIN_INCOME_PACK
		)
	)
	assert(h.service.processReceipt(h.receipt("r1", 9001)) == decision.PurchaseGranted, "a valid receipt is granted")
	assert(data.cash == expected, "the server-computed income pack is paid")
	assert(h.metricCounts.ProductsGranted == 1 and h.notifies() == 1, "the grant is counted and announced")
	assert(h.counters.saves == 1, "the save is written before PurchaseGranted")

	-- Aynı makbuz tekrar gelirse ödül ikinci kez verilmez ama Roblox'a "işlendi" denir
	assert(
		h.service.processReceipt(h.receipt("r1", 9001)) == decision.PurchaseGranted,
		"a repeated receipt is acknowledged"
	)
	assert(data.cash == expected and h.metricCounts.ProductsGranted == 1, "a repeated receipt pays nothing")

	-- Kayıt yazılamazsa: ödül verilir ama PurchaseGranted dönmez; yeniden deneme ödülü tekrarlamaz
	h.saveOk = false
	assert(
		h.service.processReceipt(h.receipt("r2", 9001)) == decision.NotProcessedYet,
		"no PurchaseGranted without a save"
	)
	local afterSecond = data.cash
	assert(afterSecond == expected * 2, "the reward itself was applied once")
	h.saveOk = true
	assert(
		h.service.processReceipt(h.receipt("r2", 9001)) == decision.PurchaseGranted,
		"the retry succeeds once the save works"
	)
	assert(data.cash == afterSecond, "the retry does not pay again")

	-- Üretimi bitir: bütün işler hemen hazır olur
	data.production = { { readyAt = 99999 }, { readyAt = 88888 } }
	assert(h.service.processReceipt(h.receipt("r3", 9002)) == decision.PurchaseGranted, "instant production is granted")
	assert(data.production[1].readyAt == 0 and data.production[2].readyAt == 0, "every job is ready now")

	-- Ödül verilemeyen etki: makbuz günlükten çıkar, tekrar denenir
	local savedHandlerData = data.production
	data.production = nil
	assert(h.service.processReceipt(h.receipt("r4", 9002)) == decision.NotProcessedYet, "a failing effect is held")
	assert(not (data.receipts and table.find(data.receipts, "r4")), "a failed grant leaves no receipt behind")
	data.production = savedHandlerData

	-- Ürün istemi: istemci yalnızca anahtar gönderir; kimlik sunucuda çözülür
	local prompt = setup()
	local function request(kind: any, key: any): any
		return prompt.fire("RequestPromptProduct", kind, key)
	end
	request("coupon", "income_pack")
	request("product", {})
	assert(#prompt.market.productPrompts == 0 and prompt.sentCount() == 0, "invalid kinds and keys are ignored")
	request("product", "income_pack")
	assert(
		#prompt.market.productPrompts == 1 and prompt.market.productPrompts[1].id == 9001,
		"the server resolves the product id"
	)
	local spam = prompt.fireRaw(prompt.player, "RequestPromptProduct", "product", "income_pack")
	assert(spam == nil and #prompt.market.productPrompts == 1, "prompt spam is limited")
	request("product", "no_such_product")
	assert(#prompt.market.productPrompts == 1, "an unknown key opens nothing")
	local closed = prompt.fire("RequestPromptProduct", "pass", "extra_storage")
	assert(
		closed and closed.remote == "Notify" and closed.args[1] == "Bu ürün henüz satışta değil",
		"an unreleased product is refused"
	)
	request("pass", "double_income")
	assert(#prompt.market.passPrompts == 1 and prompt.market.passPrompts[1].id == 7001, "a pass opens the pass prompt")
	prompt.data.passes = { double_income = true }
	local ownedReply = prompt.fire("RequestPromptProduct", "pass", "double_income")
	assert(
		ownedReply and ownedReply.args[1] == "Bu ürüne zaten sahipsin" and #prompt.market.passPrompts == 1,
		"owned pass"
	)
	prompt.worldReady = false
	request("product", "income_pack")
	assert(#prompt.market.productPrompts == 1, "nothing opens before the world is ready")

	-- Geçit satın alımı ve sahiplik okuma
	local pass = setup()
	pass.finishPass(pass.player, 7001, false)
	assert(pass.data.passes == nil and pass.sentCount() == 0, "a cancelled pass purchase changes nothing")
	pass.finishPass(pass.player, 424242, true)
	assert(pass.data.passes == nil, "an unknown pass id is ignored")
	pass.finishPass(pass.player, 7001, true)
	assert(pass.data.passes and pass.data.passes.double_income == true, "a purchased pass is recorded")
	assert(pass.metricCounts.PassesPurchased == 1 and pass.counters.pushes == 1, "counted and pushed")
	pass.finishPass(pass.stranger, 7001, true)
	assert(pass.metricCounts.PassesPurchased == 1, "a player without save data gets nothing")
	local refreshed = setup()
	refreshed.service.refreshPasses(refreshed.player)
	assert(
		refreshed.data.passes and refreshed.data.passes.double_income == true,
		"ownership is read from the marketplace"
	)
	assert(refreshed.data.passes.auto_collector == nil, "unreleased passes are skipped")

	products.income_pack.id, products.instant_production.id, passes.double_income.id =
		saved.income, saved.instant, saved.pass
	print(
		"PASS monetization service: actual service receipts (no double pay, save-gated), prompts, passes and unreleased products"
	)
end
