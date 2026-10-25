--!strict
-- Yükseltme servisi: gerçek servis kaynağı; sahip, parası yok, zaten alınmış, kilitli, tekrar istek, yanlış çiftlik, hız sınırı.
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
			h.guard
		).init()
		return h
	end
	local function buy(h: any, upgradeId: any, farmId: any?, requestId: any?): any
		return h.fire("RequestBuyUpgrade", upgradeId, requestId or h.nextId(), farmId or h.data.activeMainFarmId)
	end
	local function findByStatus(data: any, wanted: string): any
		for _, upgrade in config.UPGRADES do
			if
				upgrade.kind ~= "island"
				and config.themeHasIsland(data.activeMainFarmId, config.getUpgradeIsland(upgrade))
				and farmMath.getUpgradeStatus(data, upgrade.id) == wanted
			then
				return upgrade
			end
		end
		return nil
	end

	-- Başarılı alım: fiyat sunucuda hesaplanır, sahiplik yazılır, durum itilir ve kaydedilir
	local h = setup()
	local data = h.data
	local upgrade = assert(findByStatus(data, "available"), "a fresh save has an available upgrade")
	local cost = farmMath.getUpgradeCost(data, upgrade)
	data.cash = cost + 5
	local reply = buy(h, upgrade.id)
	assert(reply and reply.remote == "PurchaseResult" and reply.ok == true, "the owner can buy")
	assert(data.purchased[upgrade.id] == true and data.cash == 5, "ownership is written and exactly the cost is spent")
	assert(
		h.counters.pushes == 1 and h.counters.saves == 1 and h.counters.refreshes == 1,
		"state pushed, saved, redrawn"
	)
	assert(h.counters.settles == 1 and h.metricCounts.UpgradesPurchased == 1, "income settled, purchase counted")
	assert(string.find(reply.message, upgrade.displayName, 1, true) ~= nil, "the player is told what was bought")

	-- Zaten alınmış: ikinci kez para düşmez
	data.cash = cost * 10
	local owned = buy(h, upgrade.id)
	assert(
		owned and owned.ok == false and owned.message == "Buna zaten sahipsin",
		"an owned upgrade cannot be bought twice"
	)
	assert(data.cash == cost * 10, "no money is taken for an owned upgrade")

	-- Parası yok
	local poor = setup()
	local candidate = assert(findByStatus(poor.data, "available"), "available upgrade")
	poor.data.cash = farmMath.getUpgradeCost(poor.data, candidate) - 1
	local broke = buy(poor, candidate.id)
	assert(broke and broke.ok == false and string.find(broke.message, "Yeterli para yok", 1, true) ~= nil, "no cash")
	assert(poor.data.purchased[candidate.id] == nil and poor.counters.saves == 0, "a refused purchase changes nothing")
	assert(poor.metricCounts.PurchaseRejected == 1, "the rejection is counted")

	-- Kilitli: ön koşulu olmayan alınamaz
	local locked = setup()
	local lockedUpgrade = assert(findByStatus(locked.data, "locked"), "a fresh save has a locked upgrade")
	locked.data.cash = 1e12
	local blocked = buy(locked, lockedUpgrade.id)
	assert(blocked and blocked.ok == false and string.find(blocked.message, "Önce:", 1, true) ~= nil, "locked")
	assert(
		locked.data.cash == 1e12 and locked.data.purchased[lockedUpgrade.id] == nil,
		"a locked purchase changes nothing"
	)

	-- Geçersiz kimlikler
	local unknown = buy(locked, "no_such_upgrade")
	assert(unknown and unknown.ok == false and unknown.message == "Bilinmeyen yükseltme", "unknown id")
	local badType = buy(locked, 12)
	assert(badType and badType.ok == false and badType.message == "Geçersiz istek", "non-string id")
	locked.worldReady = false
	local early = buy(locked, lockedUpgrade.id)
	assert(early and early.ok == false and early.message == "Veri henüz yüklenmedi", "world not ready")

	-- Tekrar eden istek kimliği
	local replayed = setup()
	local target = assert(findByStatus(replayed.data, "available"), "available upgrade")
	replayed.data.cash = 1e9
	local id = replayed.nextId()
	assert(buy(replayed, target.id, nil, id).ok == true, "first request processed")
	local cashAfter = replayed.data.cash
	assert(buy(replayed, target.id, nil, id) == nil, "a replayed request id is ignored without reply")
	assert(replayed.data.cash == cashAfter and replayed.counters.saves == 1, "a replay changes nothing")

	-- Yanlış çiftlik kimliği ve yabancı oyuncu
	local wrong = setup()
	local wrongTarget = assert(findByStatus(wrong.data, "available"), "available upgrade")
	wrong.data.cash = 1e9
	local stale = buy(wrong, wrongTarget.id, "bogus-farm")
	assert(
		stale and stale.ok == false and string.find(stale.message, "Etkin çiftlik değişti", 1, true) ~= nil,
		"stale farm"
	)
	assert(wrong.data.cash == 1e9 and wrong.data.purchased[wrongTarget.id] == nil, "a stale farm id changes nothing")
	local foreign =
		wrong.fireAs(wrong.stranger, "RequestBuyUpgrade", wrongTarget.id, wrong.nextId(), wrong.data.activeMainFarmId)
	assert(foreign and foreign.ok == false, "a player without save data is refused")
	assert(wrong.data.cash == 1e9 and wrong.data.purchased[wrongTarget.id] == nil, "nothing leaks to another save")
	local staleExpand = wrong.fire("RequestExpandZone", "starter", wrong.nextId(), "bogus-farm")
	assert(
		staleExpand and staleExpand.ok == false and string.find(staleExpand.message, "Etkin çiftlik", 1, true) ~= nil,
		"expand"
	)
	local staleLineage = wrong.fire("RequestUpgradeLineage", "cow", wrong.nextId(), "bogus-farm")
	assert(
		staleLineage
			and staleLineage.ok == false
			and string.find(staleLineage.message, "Etkin çiftlik", 1, true) ~= nil,
		"lineage"
	)

	-- Hız sınırı: ikinci alım aynı anda gelirse "çok hızlı" cevabı verilir ve para yalnızca bir kez düşer
	local limited = setup()
	limited.data.cash = 1e9
	local first = assert(findByStatus(limited.data, "available"), "available upgrade")
	assert(buy(limited, first.id).ok == true, "first purchase passes")
	local second = assert(findByStatus(limited.data, "available"), "a second available upgrade")
	local cashBefore = limited.data.cash
	local spam =
		limited.fireRaw(limited.player, "RequestBuyUpgrade", second.id, limited.nextId(), limited.data.activeMainFarmId)
	assert(
		spam and spam.ok == false and spam.message == "Çok hızlı işlem yapıyorsun; biraz bekle.",
		"throttle reply"
	)
	assert(
		limited.data.cash == cashBefore and limited.data.purchased[second.id] == nil,
		"the throttled request changes nothing"
	)

	-- Irk geliştirme ve bölge genişletme: parası yok reddedilir, para varken ücret sunucudan düşer
	local growth = setup()
	local lineageStatus, _, lineageCost = farmMath.getLineageStatus(growth.data, "cow")
	if lineageStatus == "available" then
		local levelBefore = farmMath.getLineageLevel(growth.data, "cow")
		growth.data.cash = lineageCost - 1
		local lineageBroke = growth.fire("RequestUpgradeLineage", "cow", growth.nextId(), growth.data.activeMainFarmId)
		assert(lineageBroke and lineageBroke.ok == false, "lineage upgrade without cash is refused")
		growth.data.cash = lineageCost
		local lineageOk = growth.fire("RequestUpgradeLineage", "cow", growth.nextId(), growth.data.activeMainFarmId)
		assert(lineageOk and lineageOk.ok == true and growth.data.cash == 0, "lineage upgrade spends exactly its cost")
		assert(farmMath.getLineageLevel(growth.data, "cow") == levelBefore + 1, "lineage level rises by one")
	end
	local badLineage = growth.fire("RequestUpgradeLineage", "dragon", growth.nextId(), growth.data.activeMainFarmId)
	assert(badLineage and badLineage.ok == false and badLineage.message == "Geçersiz istek", "unknown lineage animal")
	local badZone = growth.fire("RequestExpandZone", "no_such_zone", growth.nextId(), growth.data.activeMainFarmId)
	assert(badZone and badZone.ok == false and badZone.message == "Geçersiz istek", "unknown expansion target")
	local expandStatus, _, expandCost = farmMath.getExpansionStatus(growth.data, "starter")
	assert(expandStatus == "available", "an unlocked zone can be expanded without being full")
	do
		growth.data.cash = expandCost - 1
		local expandBroke = growth.fire("RequestExpandZone", "starter", growth.nextId(), growth.data.activeMainFarmId)
		assert(expandBroke and expandBroke.ok == false, "expansion without cash is refused")
		growth.data.cash = expandCost
		local expanded = growth.fire("RequestExpandZone", "starter", growth.nextId(), growth.data.activeMainFarmId)
		assert(expanded and expanded.ok == true and growth.data.cash == 0, "expansion spends exactly its cost")
		assert(farmMath.getExpansionLevel(growth.data, "starter") == 1, "expansion level rises")
	end

	-- Ürünle açılış: para ve ürün tek adımda düşer; biri yetmezse hiçbir şey düşmez; yanlış çiftlik ve tekrar istek ödeme almaz
	local gated = setup()
	local themeTwo = config.THEMES[2]
	local gate = assert(
		config.getUpgrade(config.FARM_ISLANDS[themeTwo.satellites[1]].upgradeId),
		"the first island of theme 2 asks goods (tier = theme number)"
	)
	local gd = gated.data
	gd.activeMainFarmId = "2"
	gd.purchased.barn_2 = true
	farmMath.applyDerived(gd)
	local goodsId, need = next(farmMath.getGoodsCost(gd, gate))
	assert(goodsId ~= nil and need ~= nil and need >= 1, "a tier 2 farm asks goods for its first island")
	local gatePrice = farmMath.getUpgradeCost(gd, gate)
	gd.cash = gatePrice * 3
	local noGoods = buy(gated, gate.id)
	assert(
		noGoods and noGoods.ok == false and string.find(noGoods.message, "Yeterli ürün yok", 1, true) ~= nil,
		"cash alone is not enough"
	)
	assert(
		gd.cash == gatePrice * 3 and gd.purchased[gate.id] == nil and next(gd.goods or {}) == nil,
		"a refusal for missing goods takes nothing"
	)
	gd.goods = { [goodsId] = need - 1 }
	local partial = buy(gated, gate.id)
	assert(partial and partial.ok == false, "one unit short is refused")
	assert(gd.cash == gatePrice * 3 and gd.goods[goodsId] == need - 1, "a partial stock is not consumed")
	gd.goods = { [goodsId] = need + 3 }
	gd.cash = gatePrice - 1
	local poorButStocked = buy(gated, gate.id)
	assert(poorButStocked and poorButStocked.ok == false, "enough goods do not replace missing cash")
	assert(gd.cash == gatePrice - 1 and gd.goods[goodsId] == need + 3, "goods stay when cash is short")
	gd.cash = gatePrice + 7
	local staleGoods = buy(gated, gate.id, "bogus-farm")
	assert(staleGoods and staleGoods.ok == false, "the wrong farm is refused")
	assert(
		gd.cash == gatePrice + 7 and gd.goods[goodsId] == need + 3,
		"a wrong farm id charges neither money nor goods"
	)
	local requestId = gated.nextId()
	local paid = buy(gated, gate.id, nil, requestId)
	assert(paid and paid.ok == true and gd.purchased[gate.id] == true, "cash and goods together buy the unlock")
	assert(gd.cash == 7 and gd.goods[goodsId] == 3, "exactly the price and the required goods are taken")
	assert(buy(gated, gate.id, nil, requestId) == nil, "a replayed request id is ignored")
	assert(gd.cash == 7 and gd.goods[goodsId] == 3, "a replay never charges twice")
	local again = buy(gated, gate.id)
	assert(again and again.ok == false and gd.goods[goodsId] == 3, "an owned unlock takes no goods")
	-- İstemci fiyat ya da ürün gönderemez: fazladan alanlar yok sayılır, tür dışı kimlik reddedilir
	local forged = setup()
	forged.data.activeMainFarmId = "2"
	forged.data.purchased.barn_2 = true
	farmMath.applyDerived(forged.data)
	forged.data.cash = gatePrice * 2
	local forgedReply =
		forged.fire("RequestBuyUpgrade", gate.id, forged.nextId(), forged.data.activeMainFarmId, { [goodsId] = 0 }, -5)
	assert(forgedReply and forgedReply.ok == false, "a client cannot waive or reduce the goods cost")
	assert(
		forged.data.cash == gatePrice * 2 and forged.data.purchased[gate.id] == nil,
		"forged arguments change nothing"
	)
	local rapid = setup()
	rapid.data.activeMainFarmId = "2"
	rapid.data.purchased.barn_2 = true
	farmMath.applyDerived(rapid.data)
	rapid.data.cash = gatePrice * 2
	rapid.data.goods = { [goodsId] = need * 2 }
	assert(buy(rapid, gate.id).ok == true, "the first goods purchase passes")
	local goodsAfter = rapid.data.goods[goodsId]
	local rapidAgain =
		rapid.fireRaw(rapid.player, "RequestBuyUpgrade", gate.id, rapid.nextId(), rapid.data.activeMainFarmId)
	assert(rapidAgain and rapidAgain.ok == false, "an immediate second request is throttled")
	assert(rapid.data.goods[goodsId] == goodsAfter, "the throttled request takes no goods")

	-- Kilitli adanın tabelasındaki prompt: başka çiftliğin adasını alamaz
	local prompt: any = {
		Name = "BuyIslandPrompt",
		IsDescendantOf = function(): boolean
			return false
		end,
	}
	local promptHarness = setup()
	promptHarness.services.ProximityPromptService.PromptTriggered.fire(prompt, promptHarness.player)
	assert(promptHarness.sentCount() == 0, "a prompt outside every plot does nothing")
	print(
		"PASS upgrade service: actual service ownership, owned/locked/no-cash, replay, stale farm, throttling, lineage and expansion"
	)
end
