--!strict
-- Satın alma butonları: gerçek BuyPadService + gerçek UpgradeService; kaide seçimi, sahip kontrolü, parası yok, yanlış çiftlik, hız sınırı.
return function(
	createService: any,
	createUpgradeService: any,
	createHarness: any,
	createLimiter: any,
	codec: any,
	config: any,
	farmMath: any
)
	local harness = createHarness(createLimiter, codec, config, farmMath)
	local fakeVector2 = {
		new = function(x: number, y: number): any
			return { X = x, Y = y }
		end,
	}
	local function setup(): any
		local h = harness.new()
		local upgrades = createUpgradeService(
			h.game,
			h.remotes,
			h.dataService,
			h.plotService,
			h.economyService,
			h.limiter,
			h.metrics,
			h.dateTime
		)
		-- Hiçbir yapım alanı yok: kaideler çizilmez, dünya yenileme yolu Instance gerektirmez
		local visuals = {
			hasBuildSite = function(): boolean
				return true
			end,
		}
		h.upgrades = upgrades
		h.service = createService(
			h.game,
			h.remotes,
			h.limiter,
			{},
			{},
			h.dataService,
			h.plotService,
			upgrades,
			visuals,
			h.task,
			h.warn,
			fakeVector2
		)
		h.service.init()
		return h
	end
	local function availableUpgrade(data: any): any
		for _, upgrade in config.UPGRADES do
			if
				upgrade.kind ~= "island"
				and upgrade.kind ~= "extension"
				and config.themeHasIsland(data.activeMainFarmId, config.getUpgradeIsland(upgrade))
				and farmMath.getUpgradeStatus(data, upgrade.id) == "available"
			then
				return upgrade
			end
		end
		return nil
	end
	local function notifies(h: any): { any }
		local result = {}
		for _, entry in h.sent do
			if entry.remote == "Notify" then
				table.insert(result, entry)
			end
		end
		return result
	end

	-- Kaide seçimi (saf): yalnızca alınabilir olanlar, ucuzdan pahalıya, sınır ve atlama listesi uygulanır
	local h = setup()
	local picked = h.service.pickUpgrades(h.data, "home", 3, nil)
	assert(#picked <= 3, "the limit is respected")
	for index, upgrade in picked do
		assert(farmMath.getUpgradeStatus(h.data, upgrade.id) == "available", "only available upgrades get a pad")
		assert(
			upgrade.kind ~= "island" and upgrade.kind ~= "extension",
			"islands and extensions are sold by their own signs"
		)
		assert(config.getUpgradeIsland(upgrade) == "home", "pads only show the island's own upgrades")
		if index > 1 then
			assert(picked[index - 1].cost <= upgrade.cost, "pads are sorted from cheapest to dearest")
		end
	end
	if #picked > 0 then
		local skipped = h.service.pickUpgrades(h.data, "home", 3, function(id: string): boolean
			return id == picked[1].id
		end)
		for _, upgrade in skipped do
			assert(upgrade.id ~= picked[1].id, "skipped upgrades never get a pad")
		end
	end
	assert(#h.service.pickUpgrades(h.data, "no_such_island", 3, nil) == 0, "an unknown island has no pads")

	-- Sahibi başarıyla alır: gerçek UpgradeService fiyatı sunucuda düşer, oyuncuya bildirim gider
	local owner = setup()
	local upgrade = assert(availableUpgrade(owner.data), "a fresh save has an available upgrade")
	local cost = farmMath.getUpgradeCost(owner.data, upgrade)
	owner.data.cash = cost + 11
	owner.service.buyFromWorld(owner.player, owner.plot, upgrade.id)
	assert(owner.data.purchased[upgrade.id] == true and owner.data.cash == 11, "the owner buys at the server price")
	local sent = notifies(owner)
	assert(#sent == 1 and sent[1].args[2] == "success", "the owner is told the purchase succeeded")
	assert(string.find(sent[1].args[1], upgrade.displayName, 1, true) ~= nil, "the notice names the upgrade")

	-- Parası yok: hiçbir şey alınmaz, sebep hata bildirimiyle iletilir
	local poor = setup()
	local target = assert(availableUpgrade(poor.data), "available upgrade")
	poor.data.cash = farmMath.getUpgradeCost(poor.data, target) - 1
	poor.service.buyFromWorld(poor.player, poor.plot, target.id)
	assert(poor.data.purchased[target.id] == nil, "nothing is bought without enough cash")
	local errors = notifies(poor)
	assert(#errors == 1 and errors[1].args[2] == "error", "the missing cash is reported")
	assert(string.find(errors[1].args[1], "Yeterli para yok", 1, true) ~= nil, "the reason names the missing cash")

	-- Başka oyuncunun / başka çiftliğin arazisinden alım olmaz; bilinmeyen kimlik atılır
	local foreign = setup()
	foreign.data.cash = 1e12
	local foreignTarget = assert(availableUpgrade(foreign.data), "available upgrade")
	foreign.service.buyFromWorld(foreign.stranger, foreign.plot, foreignTarget.id)
	assert(
		foreign.data.purchased[foreignTarget.id] == nil and foreign.sentCount() == 0,
		"a non-owner cannot buy from a plot"
	)
	foreign.service.buyFromWorld(foreign.player, {}, foreignTarget.id)
	assert(
		foreign.data.purchased[foreignTarget.id] == nil and foreign.sentCount() == 0,
		"another plot is not this player's plot"
	)
	foreign.service.buyFromWorld(foreign.player, foreign.plot, "no_such_upgrade")
	assert(foreign.sentCount() == 0 and foreign.data.cash == 1e12, "an unknown upgrade id is dropped")

	-- Başka menüden alınmış yükseltmenin kaidesi: para düşmez, dünya yenilenir (hız sınırlı)
	local stale = setup()
	local staleTarget = assert(availableUpgrade(stale.data), "available upgrade")
	stale.data.cash = 1e9
	stale.data.purchased[staleTarget.id] = true
	stale.service.buyFromWorld(stale.player, stale.plot, staleTarget.id)
	assert(
		stale.data.cash == 1e9 and stale.counters.refreshes == 1 and stale.sentCount() == 0,
		"an owned pad just refreshes the world"
	)
	stale.service.buyFromWorld(stale.player, stale.plot, staleTarget.id)
	assert(stale.counters.refreshes == 1, "pad refreshes are rate limited")

	-- Hız sınırı: aynı anda ikinci alım yok sayılır (UpgradeService sınırı), para yalnızca bir kez düşer
	local limited = setup()
	limited.data.cash = 1e12
	local first = assert(availableUpgrade(limited.data), "available upgrade")
	limited.service.buyFromWorld(limited.player, limited.plot, first.id)
	local second = assert(availableUpgrade(limited.data), "a second available upgrade")
	local cashBefore = limited.data.cash
	limited.service.buyFromWorld(limited.player, limited.plot, second.id)
	assert(
		limited.data.cash == cashBefore and limited.data.purchased[second.id] == nil,
		"the throttled purchase changes nothing"
	)

	-- Yapım alanı tabelası promptu: sahibi alır, aynı anda ikinci tetikleme hız sınırına takılır
	local prompted = setup()
	prompted.data.cash = 1e12
	local site = assert(availableUpgrade(prompted.data), "available upgrade")
	local attributes = { UpgradeId = site.id }
	local prompt: any = {
		Name = "BuySitePrompt",
		GetAttribute = function(_self: any, name: string): any
			return attributes[name]
		end,
		IsDescendantOf = function(_self: any, ancestor: any): boolean
			return ancestor == prompted.plot
		end,
	}
	local trigger = prompted.services.ProximityPromptService.PromptTriggered
	trigger.fire({ Name = "SomethingElse" }, prompted.player)
	assert(prompted.data.purchased[site.id] == nil, "unrelated prompts are ignored")
	trigger.fire(prompt, prompted.player)
	assert(prompted.data.purchased[site.id] == true, "the owner buys through the site prompt")
	local afterPrompt = prompted.data.cash
	local nextSite = assert(availableUpgrade(prompted.data), "next available upgrade")
	attributes.UpgradeId = nextSite.id
	trigger.fire(prompt, prompted.player)
	assert(prompted.data.cash == afterPrompt and prompted.data.purchased[nextSite.id] == nil, "prompt spam is limited")
	prompted.clockNow += 10
	attributes.UpgradeId = 5
	trigger.fire(prompt, prompted.player)
	assert(prompted.data.cash == afterPrompt, "a non-string upgrade id on a prompt is ignored")
	print(
		"PASS buy pads: pad selection, owner/plot checks, real UpgradeService purchase, no-cash notice, refresh and throttling"
	)
end
