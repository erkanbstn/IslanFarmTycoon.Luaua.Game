--!strict
return function(
	createService: any,
	createEconomy: any,
	createLimiter: any,
	profiles: any,
	codec: any,
	config: any,
	farmMath: any
)
	local function signal(): any
		local handlers = {}
		return {
			Connect = function(_self: any, cb: any)
				table.insert(handlers, cb)
			end,
			fire = function(...: any)
				for _, cb in handlers do
					cb(...)
				end
			end,
		}
	end
	local now, serial = 100000, 0 -- eski ineğin (bornAt = 0) yetişkin sayılması için büyüme süresinden büyük
	local function uid(): string
		serial += 1
		return `farm-test-{serial}`
	end
	local data = assert(
		codec.decode({
			version = 3,
			cash = 3000000,
			stored = 17,
			purchased = { "zone_pasture" },
			animals = { { uid = "old-cow", animalId = "cow", zoneId = "starter", bornAt = 0 } },
			production = {},
		}, config, farmMath, now, uid),
		"legacy migration"
	)
	assert(
		data.activeMainFarmId == "1"
			and #profiles.ids(data) == 1
			and data.purchased.zone_pasture
			and data.animals[1].uid == "old-cow",
		"v3 assets migrate unchanged to primary farm"
	)
	local player: any = {
		attributes = { WorldReady = true },
		GetAttribute = function(self: any, key: string): any
			return self.attributes[key]
		end,
		SetAttribute = function(self: any, key: string, value: any)
			self.attributes[key] = value
		end,
	}
	local active = true
	local players = { PlayerRemoving = signal() }
	local node: any = {
		WaitForChild = function(): any
			return {}
		end,
	}
	local engine = {
		GetService = function(_self: any, name: string): any
			if name == "Players" then
				return players
			elseif name == "HttpService" then
				return { GenerateGUID = uid }
			else
				return node
			end
		end,
	}
	local request = { OnServerEvent = signal() }
	local results = {}
	local remotes = {
		get = function(name: string): any
			if name == "RequestMainFarmAction" then
				return request
			end
			return {
				FireClient = function(_self: any, _p: any, id: number, ok: boolean, msg: string)
					table.insert(results, { id = id, ok = ok, message = msg })
				end,
			}
		end,
	}
	local pushes, saves = 0, 0
	local resolver: any = nil
	local dataService = {
		tryGet = function(): any
			return if active then data else nil
		end,
		getFarmIds = function(): any
			return profiles.ids(data)
		end,
		getFarmView = function(_p: any, id: string): any
			return profiles.view(data, id)
		end,
		setActiveMainFarm = function(_p: any, id: string): boolean
			return profiles.select(data, id)
		end,
		setMainFarmOffersResolver = function(_fn: any) end,
		setFarmPlotResolver = function(fn: any)
			resolver = fn
		end,
		pushState = function()
			pushes += 1
		end,
		requestSave = function()
			saves += 1
		end,
		pushEconomy = function() end,
	}
	local mappings: any = { ["1"] = "1" }
	local fakePlot = {
		FindFirstChild = function(): any
			return nil
		end,
	}
	local failSelect = false
	local teleports = 0
	local plots = {
		getPlot = function(): any
			return fakePlot
		end,
		getAllOwned = function(): any
			local result = {}
			for id in mappings do
				result[id] = fakePlot
			end
			return result
		end,
		getMainFarmOffers = function(): any
			return {}
		end,
		getMainFarmPlotId = function(_p: any, id: string): string?
			return mappings[id]
		end,
		selectMainFarm = function(_p: any, id: string): boolean
			return not (failSelect and id ~= "1") and data.mainFarms[id] ~= nil
		end,
		refreshPlayerWorld = function() end,
		teleportHome = function()
			teleports += 1
		end,
	}
	local clock = {
		clock = function(): number
			return now
		end,
	}
	local dateTime = {
		now = function(): any
			return { UnixTimestampMillis = now * 1000 }
		end,
	}
	local limiter = createLimiter(engine, clock)
	local economy = createEconomy(
		engine,
		{},
		dataService,
		plots,
		limiter,
		{ Color = { Blue = {}, Red = {}, Gold = {} } },
		{ setTag = function() end },
		{ increment = function() end },
		clock,
		dateTime,
		{},
		function() end
	)
	economy.startPlayer(player)
	local service = createService(engine, remotes, dataService, plots, economy, limiter, dateTime, function() end)
	service.init()
	service.init()
	assert(resolver ~= nil, "live physical summary resolver must be registered")
	local sequence = 0
	local function fire(action: any, target: any): any
		now += if action == "select" then config.MAIN_FARM_SWITCH_COOLDOWN_SECONDS + 0.1 else 0.7
		sequence += 1
		request.OnServerEvent.fire(player, action, target, sequence)
		return results[#results]
	end
	local before = data.cash
	assert(
		not fire("buy", "1").ok and data.cash == before and #profiles.ids(data) == 1,
		"an already owned farm cannot be bought again or charged"
	)
	failSelect = true
	assert(
		not fire("buy", "2").ok and data.cash == before and data.mainFarms["2"] == nil,
		"injected selection failure rolls the purchase back and never charges"
	)
	failSelect = false
	assert(fire("buy", "2").ok, "a new farm theme can be bought")
	assert(
		data.cash == before - config.MAIN_FARM_PRICES[2] and data.activeMainFarmId == "2",
		"buy charges server price and selects new independent farm"
	)
	assert(
		not data.purchased.zone_pasture and #data.animals == config.STARTING_COW_COUNT,
		"new farm starts separately without copying old upgrades"
	)
	local boughtSequence = sequence
	request.OnServerEvent.fire(player, "buy", "3", boughtSequence)
	assert(#profiles.ids(data) == 2, "duplicate buy cannot create another farm")
	data.stored = 23
	data.purchased.silo = true
	economy.settlePlayer(player) -- park edilmiş çiftlik geliri kasaya yattığı için geçişten önce hesabı kapat
	local cash = data.cash
	assert(
		fire("select", "1").ok and data.purchased.zone_pasture and not data.purchased.silo,
		"selection restores the correct upgrade set"
	)
	-- Geçiş öncesi hesap kapanırken park edilmiş çiftlik geliri kasaya yatabilir; ondan fazlası üretilemez, cüzdan sıfırlanamaz
	local walletRise = 0
	for _, id in profiles.ids(data) do
		walletRise += farmMath.computeIncomePerSecond(profiles.view(data, id)) * (config.MAIN_FARM_SWITCH_COOLDOWN_SECONDS + 0.2)
	end
	assert(data.cash >= cash and data.cash - cash <= walletRise, "switch cannot mint or reset shared wallet")
	assert(
		profiles.view(data, "2").stored >= 23 and profiles.view(data, "2").purchased.silo,
		"old active scalars and tables survive switch"
	)
	assert(not fire("select", "6").ok and data.activeMainFarmId == "1", "unowned logical farm cannot be selected")
	assert(
		not fire("activate", "2").ok and data.activeMainFarmId == "1",
		"walking onto other islands no longer switches farms"
	)
	local teleportsBefore = teleports
	assert(
		fire("select", "2").ok and teleports == teleportsBefore + 1,
		"activation teleports the player home on the re-themed island"
	)
	assert(fire("select", "1").ok and data.activeMainFarmId == "1", "the first farm can be reactivated")
	local switchesBefore = teleports
	now += 1
	sequence += 1
	request.OnServerEvent.fire(player, "select", "2", sequence)
	local tooSoon = results[#results]
	assert(
		not tooSoon.ok and tooSoon.message ~= "" and data.activeMainFarmId == "1" and teleports == switchesBefore,
		"a second farm switch inside the cooldown is rejected with a message"
	)
	now += config.MAIN_FARM_SWITCH_COOLDOWN_SECONDS
	sequence += 1
	request.OnServerEvent.fire(player, "select", "2", sequence)
	assert(results[#results].ok and data.activeMainFarmId == "2", "the switch works again after the cooldown")
	assert(fire("select", "1").ok and data.activeMainFarmId == "1", "restore the first farm for the income checks")
	economy.settlePlayer(player)
	local oldStored = data.stored
	local second = profiles.view(data, "2")
	second.stored = 0
	if #second.animals == 0 then
		table.insert(
			second.animals,
			{ uid = "parked-home", animalId = config.getHomeAnimal(second.farmId), zoneId = "starter", bornAt = 0 }
		)
	end
	local secondIncome = farmMath.computeIncomePerSecond(second)
	local firstIncome = farmMath.computeIncomePerSecond(data)
	assert(secondIncome > 0, "the parked farm has income to settle")
	local cashBeforeParked = data.cash
	now += 10
	economy.settlePlayer(player)
	assert(
		math.abs(data.stored - oldStored - firstIncome * 10) < 0.001,
		"the active farm fills its own storage using its own animals and upgrades"
	)
	assert(
		second.stored == 0
			and math.abs(data.cash - cashBeforeParked - secondIncome * 10 * config.PARKED_FARM_PAY_RATE) < 0.001,
		"a parked farm without a collector pays PARKED_FARM_PAY_RATE of its income straight to the wallet"
	)
	second.purchased.auto_collector = true
	local cashBeforeAuto = data.cash
	local storedBeforeAuto = second.stored
	now += 2
	economy.settlePlayer(player)
	assert(
		second.stored == 0 and math.abs(data.cash - cashBeforeAuto - storedBeforeAuto - secondIncome * 2) < 0.001,
		"inactive auto collector pays shared wallet exactly once"
	)
	local encoded = codec.encode(data, now)
	assert(
		encoded.version == 4 and encoded.mainFarms["1"] and encoded.mainFarms["2"],
		"all independent farms are persisted in protected schema4"
	)
	data.purchased.zone_pasture = nil
	assert(
		table.find(encoded.mainFarms["1"].purchased, "zone_pasture") ~= nil,
		"write snapshot cannot alias active purchased table"
	)
	local roundtrip = assert(codec.decode(encoded, config, farmMath, now, uid), "multi farm reload")
	assert(
		roundtrip.cash == encoded.cash and roundtrip.purchased.zone_pasture and roundtrip.mainFarms["2"].purchased.silo,
		"wallet and independent farm state roundtrip"
	)
	local later = assert(codec.decode(encoded, config, farmMath, now + 86400, uid), "offline multi farm reload")
	for _, id in profiles.ids(later) do
		local farm = profiles.view(later, id)
		assert(farm.stored <= farmMath.getStorageCap(farm), "offline income stays capped per farm")
	end
	-- İstemci yükü (hafif mainFarms) ile sunucu kaydı ortak FarmMath hesaplarında aynı sonucu vermeli.
	profiles.capture(later)
	local clientView = profiles.clientState(later, {}, {})
	assert(
		farmMath.getGoodsCap(clientView) == farmMath.getGoodsCap(later),
		"client goods cap matches the server across all farms"
	)
	local serverGoods, clientGoods = farmMath.getContractGoods(later), farmMath.getContractGoods(clientView)
	assert(table.concat(clientGoods, ",") == table.concat(serverGoods, ","), "client sees the same producible goods")
	-- Gösterilen = alınan: istemci özeti para fiyatını ve ürün gereksinimini sunucuyla aynı hesaplar (özette eksik alan yok)
	later.goods = { milk = 7, egg = 3 }
	local displayState = profiles.clientState(later, {}, {})
	for _, upgrade in config.UPGRADES do
		assert(
			farmMath.getUpgradeCost(displayState, upgrade) == farmMath.getUpgradeCost(later, upgrade),
			`client price of {upgrade.id} matches the server`
		)
		local serverCost, clientCost =
			farmMath.getGoodsCost(later, upgrade), farmMath.getGoodsCost(displayState, upgrade)
		assert(
			farmMath.formatGoodsCost(clientCost) == farmMath.formatGoodsCost(serverCost),
			`client goods cost of {upgrade.id} matches the server`
		)
		assert(
			#farmMath.getGoodsShortfall(displayState, clientCost) == #farmMath.getGoodsShortfall(later, serverCost),
			`client shortfall of {upgrade.id} matches the server`
		)
	end
	for animalId in config.ANIMALS do
		assert(
			farmMath.getAnimalPrice(displayState, animalId) == farmMath.getAnimalPrice(later, animalId),
			`client price of {animalId} matches the server`
		)
	end
	local malformed = table.clone(encoded)
	malformed.activeMainFarmId = "6"
	assert(codec.decode(malformed, config, farmMath, now, uid) == nil, "missing active farm fails closed")
	malformed = table.clone(encoded)
	malformed.mainFarms = table.clone(encoded.mainFarms)
	malformed.mainFarms["7"] = encoded.mainFarms["2"]
	assert(codec.decode(malformed, config, farmMath, now, uid) == nil, "farm count/ID cannot exceed Config")
	active = false
	assert(not fire("buy", "3").ok, "inactive profile cannot buy")
	active = true
	data.cash = 0
	assert(not fire("buy", "3").ok and data.mainFarms["3"] == nil, "insufficient cash cannot create a farm")
	assert(pushes == saves + 1 and saves >= 2, "all farm mutations persist")
	print(
		"PASS main farm economy: real buy/select, owned/no-money/replay guards, shared wallet, v3 migration, independent/all-farm income, offline caps and snapshots"
	)
end
