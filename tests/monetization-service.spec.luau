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
		h.dataService.pushEconomy = function() end
		h.dirtyCount = 0
		h.dataService.markDirty = function()
			h.dirtyCount += 1
		end
		h.telemetry = { economy = function() end }
		h.service = createService(
			h.game,
			h.remotes,
			h.dataService,
			h.limiter,
			h.metrics,
			fakeEnum,
			h.warn,
			h.task,
			h.telemetry,
			h.economyService,
			h.plotService
		)
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
	local quarantined = setup()
	quarantined.data.transfers = { outbox = {}, received = {}, quarantined = true }
	assert(
		quarantined.service.processReceipt(quarantined.receipt("backup-replay", 9001)) == decision.NotProcessedYet,
		"a recovered backup cannot re-award an uncertain purchase history"
	)
	assert(quarantined.data.cash == 0 and quarantined.counters.saves == 0, "quarantine performs no receipt mutation")

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
			farmMath.getPermanentReferenceIncome(data) * 3600 * (products.income_pack.incomeHours or 1),
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

	-- Yan etki hataları uygulanmış ödülün makbuzunu silemez; tekrar nakit ya da yeni işleri ödüllendirmez.
	local presentation = setup()
	presentation.dataService.pushEconomy = function()
		error("client presentation unavailable")
	end
	assert(
		presentation.service.processReceipt(presentation.receipt("presentation-error", 9001))
			== decision.PurchaseGranted,
		"presentation failures preserve a granted receipt"
	)
	assert(
		presentation.data.cash == expected and presentation.data.lifetimeEarned == expected,
		"presentation failure keeps the complete persisted reward"
	)
	assert(presentation.dirtyCount == 1, "the receipt checkpoint is marked before fallible presentation")
	assert(
		presentation.service.processReceipt(presentation.receipt("presentation-error", 9001))
			== decision.PurchaseGranted,
		"presentation failures preserve a granted receipt"
	)
	assert(presentation.data.cash == expected, "a presentation error cannot cause a second payout")
	for _, failure in { "telemetry", "notify" } do
		local sideEffect = setup()
		local function fail()
			error(`{failure} unavailable`)
		end
		if failure == "telemetry" then
			sideEffect.telemetry.economy = fail
		else
			sideEffect.remotes.get("Notify").FireClient = fail
		end
		assert(
			sideEffect.service.processReceipt(sideEffect.receipt(`error-{failure}`, 9001)) == decision.PurchaseGranted,
			`{failure} errors keep the receipt acknowledged`
		)
		assert(
			sideEffect.service.processReceipt(sideEffect.receipt(`error-{failure}`, 9001)) == decision.PurchaseGranted,
			`{failure} errors keep the receipt acknowledged`
		)
		assert(
			sideEffect.data.cash == expected and sideEffect.dirtyCount == 1,
			`{failure} failures cannot replay a reward`
		)
	end
	local instantError = setup()
	instantError.data.production = { { readyAt = 1234 } }
	instantError.dataService.pushState = function()
		error("state push failed")
	end
	assert(
		instantError.service.processReceipt(instantError.receipt("instant-error", 9002)) == decision.PurchaseGranted,
		"push failure preserves instant-product acknowledgment"
	)
	instantError.data.production = { { readyAt = 9999 } }
	assert(
		instantError.service.processReceipt(instantError.receipt("instant-error", 9002)) == decision.PurchaseGranted,
		"push failure preserves instant-product acknowledgment"
	)
	assert(instantError.data.production[1].readyAt == 9999, "a failed push cannot finish newly started jobs on replay")
	local partial = setup()
	partial.data.production = { { readyAt = 4444 }, "invalid-job" }
	assert(
		partial.service.processReceipt(partial.receipt("invalid-production", 9002)) == decision.NotProcessedYet,
		"invalid production defers the receipt"
	)
	assert(partial.data.production[1].readyAt == 4444, "invalid jobs are detected before any mutation")

	-- Kaydedilmiş ödülün platform onayı kaybolabilir; 201 yeni makbuz ve oturum yeniden yükleme sonrası tekrar.
	local replay = setup()
	assert(
		replay.service.processReceipt(replay.receipt("pending-old", 9001)) == decision.PurchaseGranted,
		"initial reward is saved"
	)
	for index = 1, 201 do
		assert(
			replay.service.processReceipt(replay.receipt(`later-{index}`, 9001)) == decision.PurchaseGranted,
			"later rewards are saved"
		)
	end
	local persisted = codec.encode(replay.data, replay.now)
	local restarted = setup()
	local restored = assert(codec.decode(persisted, config, farmMath, replay.now, function()
		return "restored-uid"
	end))
	restarted.dataService.tryGet = function(): any
		return restored
	end
	local restoredCash = restored.cash
	assert(
		restarted.service.processReceipt(restarted.receipt("pending-old", 9001)) == decision.PurchaseGranted,
		"old pending receipt is acknowledged after restart"
	)
	assert(
		restored.cash == restoredCash and restarted.metricCounts.ProductsGranted == nil,
		"saved replay survives restart and 201 later receipts"
	)

	-- Yazılmadan çöküş: yeni oturum yalnız son kalıcı görüntüyü görür; yeniden deneme bir kez ödüllendirir.
	local crashed = setup()
	local beforeCrash = codec.encode(crashed.data, crashed.now)
	beforeCrash.receipts = table.clone(crashed.data.receipts or {})
	crashed.saveOk = false
	assert(
		crashed.service.processReceipt(crashed.receipt("unsaved", 9001)) == decision.NotProcessedYet,
		"unsaved reward is not acknowledged"
	)
	local afterCrash = setup()
	local restoredBefore = assert(codec.decode(beforeCrash, config, farmMath, crashed.now, function()
		return "before-crash-uid"
	end))
	afterCrash.dataService.tryGet = function(): any
		return restoredBefore
	end
	assert(
		afterCrash.service.processReceipt(afterCrash.receipt("unsaved", 9001)) == decision.PurchaseGranted,
		"restarted retry persists the reward"
	)
	assert(restoredBefore.cash == expected, "an unsaved crash neither loses nor doubles persisted cash")

	local capacity = setup()
	capacity.data.receipts = table.create(20000)
	for index = 1, 20000 do
		capacity.data.receipts[index] = `capacity-{index}`
	end
	assert(
		capacity.service.processReceipt(capacity.receipt("over-capacity", 9001)) == decision.NotProcessedYet,
		"new receipt is deferred at capacity"
	)
	assert(capacity.data.cash == 0 and capacity.counters.saves == 0, "full ledger does not grant or save a new reward")
	assert(capacity.metricCounts.ReceiptCapacityBlocked == 1, "capacity deferral has a diagnostic counter")
	assert(
		capacity.service.processReceipt(capacity.receipt("capacity-1", 9001)) == decision.PurchaseGranted,
		"duplicate is acknowledged at capacity"
	)
	assert(capacity.data.cash == 0, "old receipts can be acknowledged even at capacity")

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
	assert(#refreshed.delays == 0, "no retry when every query succeeds")

	-- Sorgu hatası: önceki sahiplik korunur, geçit düşmez; sınırlı sayıda yeniden denenir
	local realQuery = refreshed.market.UserOwnsGamePassAsync
	refreshed.market.UserOwnsGamePassAsync = function(): boolean
		error("Roblox service unavailable")
	end
	refreshed.service.refreshPasses(refreshed.player)
	assert(refreshed.data.passes.double_income == true, "a failed query keeps the previously owned pass")
	assert(#refreshed.delays == 1, "a failed query schedules one retry")
	for _ = 1, 5 do
		local retry = table.remove(refreshed.delays)
		if not retry then
			break
		end
		retry.callback(table.unpack(retry.args))
	end
	assert(refreshed.data.passes.double_income == true, "retries keep the pass while the service is down")
	assert(#refreshed.delays == 0, "retries are bounded")
	refreshed.market.UserOwnsGamePassAsync = realQuery

	-- Yield sırasında satın alma tamamlanırsa eski false yanıtı yeni sahipliği silemez.
	local raced = setup()
	raced.data.passes = {}
	raced.market.UserOwnsGamePassAsync = function(): boolean
		raced.finishPass(raced.player, 7001, true)
		return false
	end
	raced.service.refreshPasses(raced.player)
	assert(raced.data.passes.double_income == true, "a stale query cannot erase a completed purchase")

	-- Eski oturumun sorgusu yeni profil nesnesine sahiplik yazamaz.
	local replaced = setup()
	local newProfile = { passes = {} }
	replaced.market.UserOwnsGamePassAsync = function(): boolean
		replaced.dataService.tryGet = function(): any
			return newProfile
		end
		return true
	end
	replaced.service.refreshPasses(replaced.player)
	assert(next(newProfile.passes) == nil, "an old ownership query cannot mutate a replacement profile")
	assert(replaced.counters.pushes == 0, "a replaced profile is not pushed by the stale query")

	-- Yeni para ve kalıcı haklar gerçek makbuz yolundan geçer; ikinci makbuz ücretli hakkı yok etmez.
	local newProducts = {
		gold_100 = 9101,
		run_double_income = 9102,
		permanent_golden_crown = 9103,
	}
	local previousIds: { [string]: number } = {}
	for key, id in newProducts do
		previousIds[key] = products[key].id
		products[key].id = id
	end
	local gold = setup()
	assert(
		gold.service.processReceipt(gold.receipt("gold-first", 9101)) == decision.PurchaseGranted,
		"first gold delivery is acknowledged after saving"
	)
	assert(gold.data.gold == 100, "gold package uses its configured amount")
	assert(
		gold.service.processReceipt(gold.receipt("gold-first", 9101)) == decision.PurchaseGranted,
		"saved gold receipt replay is acknowledged"
	)
	assert(gold.data.gold == 100, "gold replay is not a second grant")
	gold.data.gold = config.PROGRESSION.gold.maxBalance - 50
	assert(
		gold.service.processReceipt(gold.receipt("gold-full", 9101)) == decision.NotProcessedYet,
		"full gold wallet defers delivery"
	)
	assert(gold.data.gold == config.PROGRESSION.gold.maxBalance - 50, "paid gold is never silently truncated")
	assert(not table.find(gold.data.receipts, "gold-full"), "deferred gold leaves no granted marker")
	gold.data.gold = 0
	assert(
		gold.service.processReceipt(gold.receipt("gold-full", 9101)) == decision.PurchaseGranted,
		"deferred gold receipt is acknowledged after capacity relief"
	)
	assert(gold.data.gold == 100, "capacity relief delivers the entire deferred purchase")
	local run = setup()
	assert(
		run.service.processReceipt(run.receipt("run-first", 9102)) == decision.PurchaseGranted,
		"run bonus receipt is acknowledged"
	)
	assert(run.data.progression.runDouble, "run bonus is delivered")
	assert(
		run.service.processReceipt(run.receipt("run-first", 9102)) == decision.PurchaseGranted,
		"run bonus replay is acknowledged"
	)
	assert(run.data.progression.doubleCredits == 0, "receipt replay never adds a future run")
	assert(
		run.service.processReceipt(run.receipt("run-second", 9102)) == decision.PurchaseGranted,
		"separate late run bonus delivery is acknowledged"
	)
	assert(run.data.progression.doubleCredits == 1, "second late purchase becomes one future run credit")
	run.fire("RequestPromptProduct", "product", "run_double_income")
	assert(#run.market.productPrompts == 0, "active run bonus cannot be sold again through the UI")
	local permanent = setup()
	permanent.data.inventory.items.golden_crown = true -- bu turda nakitle alınmış, henüz kalıcı değil
	assert(
		permanent.service.processReceipt(permanent.receipt("crown-first", 9103)) == decision.PurchaseGranted,
		"permanent crown delivery is acknowledged"
	)
	assert(
		permanent.data.owned.items.golden_crown and permanent.data.inventory.items.golden_crown,
		"cash crown can become a permanent owned right"
	)
	assert(
		permanent.service.processReceipt(permanent.receipt("crown-first", 9103)) == decision.PurchaseGranted,
		"permanent crown replay is acknowledged"
	)
	assert(permanent.data.gold == 0, "replayed permanent receipt never creates compensation")
	assert(
		permanent.service.processReceipt(permanent.receipt("crown-second", 9103)) == decision.PurchaseGranted,
		"separately paid duplicate crown is compensated and acknowledged"
	)
	assert(
		permanent.data.gold == config.PROGRESSION.permanentOffers.golden_crown.goldCost,
		"a separately paid duplicate has its full gold-equivalent value"
	)
	permanent.fire("RequestPromptProduct", "product", "permanent_golden_crown")
	assert(#permanent.market.productPrompts == 0, "owned permanent product has no purchase prompt")
	local parked = setup()
	parked.data.permanentParkedIncomeBest = 12345
	assert(
		parked.service.processReceipt(parked.receipt("parked-pack", 9001)) == decision.PurchaseGranted,
		"income pack delivery is acknowledged"
	)
	assert(parked.data.cash == 12345 * 3600, "income pack uses the account permanent reference, not active farm")
	for key, id in previousIds do
		products[key].id = id
	end

	products.income_pack.id, products.instant_production.id, passes.double_income.id =
		saved.income, saved.instant, saved.pass
	print(
		"PASS monetization service: actual service receipts (no double pay, save-gated), prompts, passes and unreleased products"
	)
end
