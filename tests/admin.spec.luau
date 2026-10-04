--!strict
return function(policy: any, createService: any, createLimiter: any, config: any, realFarmMath: any)
	assert(policy.isAllowed(11641916529), "verified owner UserId must be authorized")
	for _, value in { 0, -1, 11641916530, "11641916529", "Geo_Geyo", 0 / 0, math.huge, {} } do
		assert(not policy.isAllowed(value), "no name, coercion or other account can authorize admin")
	end
	for _, value in { -1, 0 / 0, math.huge, -math.huge, 1e12 + 1, 0.5, "10", {} } do
		assert(not policy.validCash(value), "invalid cash must be rejected")
	end
	assert(policy.validCash(0) and not policy.validCash(0, true), "set zero is valid; add zero is rejected")
	assert(policy.validCash(1e12, true), "upper command limit must be supported")
	for _, value in { 0, -1, 0 / 0, math.huge, 2147483648, 0.5, "1" } do
		assert(not policy.validRequestId(value), "request id must be bounded finite integer")
	end
	local function signal(): any
		local callbacks: { (...any) -> () } = {}
		return {
			Connect = function(_self: any, callback: (...any) -> ())
				table.insert(callbacks, callback)
				return { Disconnect = function() end }
			end,
			fire = function(...: any)
				for _, callback in callbacks do
					callback(...)
				end
			end,
		}
	end
	local function makePlayer(userId: number): any
		return {
			UserId = userId,
			Name = "Geo_Geyo",
			attributes = { IsAdmin = true, WorldReady = true },
			SetAttribute = function(self: any, key: string, value: any)
				self.attributes[key] = value
			end,
			GetAttribute = function(self: any, key: string): any
				return self.attributes[key]
			end,
		}
	end
	local owner = makePlayer(11641916529)
	local stranger = makePlayer(42)
	local players: any = { PlayerAdded = signal(), PlayerRemoving = signal() }
	function players:GetPlayers(): any
		return { owner, stranger }
	end
	local node: any = {}
	function node:WaitForChild(_name: string): any
		return self
	end
	local fakeGame: any = {}
	function fakeGame:GetService(name: string): any
		if name == "Players" then
			return players
		elseif name == "HttpService" then
			return {
				GenerateGUID = function(): string
					return "guid"
				end,
			}
		end
		return node
	end
	local now = 0
	local limiter = createLimiter(fakeGame, {
		clock = function(): number
			return now
		end,
	})
	local request = { OnServerEvent = signal() }
	local results: { any } = {}
	local reply = {
		FireClient = function(_self: any, player: any, id: number, ok: boolean, message: string)
			table.insert(results, { player = player, id = id, ok = ok, message = message })
		end,
	}
	local remotes = {
		get = function(name: string): any
			return if name == "RequestAdminAction" then request else reply
		end,
	}
	local data: any = { cash = 50, activeMainFarmId = "1" }
	local active = true
	local pushes, saves = 0, 0
	local trace: { string } = {}
	local dataService = {
		tryGet = function(player: any): any
			return if player == owner and active then data else nil
		end,
		pushState = function(player: any)
			assert(player == owner, "admin money must affect only self")
			pushes += 1
			table.insert(trace, "push")
		end,
		requestSave = function(player: any)
			assert(player == owner, "save must target owner only")
			saves += 1
			table.insert(trace, "save")
		end,
	}
	local economy = {
		settlePlayer = function(player: any)
			assert(player == owner, "money command settles only self")
			table.insert(trace, "settle")
		end,
	}
	local overrides: { any } = {}
	local failNextWeather = false
	local seasons = {
		setAdminWeather = function(id: string?): boolean
			if failNextWeather then
				failNextWeather = false
				error("injected service failure")
			end
			table.insert(overrides, { kind = "weather", id = id })
			return true
		end,
		setAdminSeason = function(id: string?): boolean
			table.insert(overrides, { kind = "season", id = id })
			return true
		end,
		setAdminClock = function(id: string?): boolean
			table.insert(overrides, { kind = "clock", id = id })
			return id == nil or id == "night"
		end,
		setAdminLights = function(id: string?): boolean
			table.insert(overrides, { kind = "lights", id = id })
			return id == nil or id == "on" or id == "off"
		end,
		setAdminLightLevel = function(id: string?): boolean
			table.insert(overrides, { kind = "level", id = id })
			return id == nil or id == "dim"
		end,
	}
	local refreshes = 0
	local plots = {
		refreshPlayerWorld = function(player: any)
			assert(player == owner, "world refresh must target owner only")
			refreshes += 1
		end,
	}
	local growthPreservations = 0
	local lastGrowthEquipment: string? = nil
	local farmMath = {
		getStorageCap = function(_save: any): number
			return 1e9
		end,
		snapshotGrowthSpeeds = function(save: any)
			lastGrowthEquipment = if save.inventory then save.inventory.equipped.tool else nil
			return {}
		end,
		preserveGrowthProgress = function(_save: any, _speeds: any, _now: number)
			growthPreservations += 1
		end,
		applyDerived = function(save: any)
			save.derived = true
			save.unlockedZones = { poultry = save.purchased.island_poultry == true }
		end,
		getZoneCapacity = function(_save: any, zoneId: string): number
			return config.ZONES[zoneId].capacity
		end,
		countInZone = function(save: any, zoneId: string): number
			local count = 0
			for _, animal in save.animals do
				if animal.zoneId == zoneId then
					count += 1
				end
			end
			return count
		end,
		countInExtension = function(save: any, extensionId: string, atTime: number?): number
			local count = 0
			for _, animal in save.animals do
				local task = animal.task
				if task and task.kind == "extension" and task.id == extensionId and (atTime or 0) < task.endsAt then
					count += 1
				end
			end
			return count
		end,
		getExtensionCapacity = function(_save: any, extensionId: string): number
			return config.EXTENSIONS[extensionId].capacity
		end,
		getActiveTask = function(animal: any, atTime: number?): any?
			local task = animal.task
			if task and (atTime or 0) < task.endsAt then
				return task
			end
			return nil
		end,
	}
	local resetCalls = 0
	local dataReset = {
		resetAll = function(): (boolean, string)
			resetCalls += 1
			return true, "reset"
		end,
	}
	local warningCount = 0
	local service = createService(
		fakeGame,
		remotes,
		dataService,
		economy,
		plots,
		farmMath,
		seasons,
		limiter,
		dataReset,
		{
			current = function(preview: any): any
				assert(
					preview.golden == nil and preview.adminForce.goldenUntil > os.time(),
					"golden preflight uses the forced canonical event with a cleared preview claim"
				)
				return if #preview.animals > 0 then {} else nil
			end,
		},
		function()
			warningCount += 1
		end
	)
	service.init()
	service.init()
	assert(
		owner.attributes.IsAdmin == true and stranger.attributes.IsAdmin == false,
		"init must publish trusted UI hints"
	)
	stranger.attributes.IsAdmin = true
	local function fire(player: any, action: any, value: any, id: any)
		request.OnServerEvent.fire(player, action, value, id)
	end
	fire(stranger, "resetAllPlayers", "confirm", 900)
	assert(resetCalls == 0, "only the verified owner can reset every player")
	fire(stranger, "setCash", 999, 1)
	fire(stranger, "setWeather", "snow", 2)
	fire(stranger, "setSeason", "winter", 3)
	assert(
		data.cash == 50 and #results == 0 and #overrides == 0 and #trace == 0,
		"spoofed IsAdmin and name must grant no actions or responses"
	)
	fire(owner, "setCash", 0, 1)
	assert(
		data.cash == 0 and saves == 1 and pushes == 1 and #results == 1 and results[1].ok,
		"authorized setCash must save and reply once"
	)
	assert(table.concat(trace, ",") == "settle,push,save", "old income must settle before new cash is sent/saved")
	now += 1
	fire(owner, "addCash", 25, 2)
	assert(data.cash == 25 and saves == 2 and results[2].id == 2, "authorized addCash must change self balance")
	now += 1
	fire(owner, "addCash", 25, 2)
	fire(owner, "addCash", 25, 1)
	assert(data.cash == 25 and #results == 2, "duplicate and out-of-order ids cannot replay money")
	local invalidValues = { 0 / 0, math.huge, -1, 1e12 + 1, 1.25, "99", {} }
	for index, value in invalidValues do
		fire(owner, "setCash", value, 10 + index)
	end
	assert(data.cash == 25 and #results == 2 and saves == 2, "malformed money must be silent and never mutate")
	fire(owner, "setCash", 99, 17)
	assert(data.cash == 25, "invalid payload must still consume its validated request id")
	owner.attributes.WorldReady = false
	fire(owner, "setCash", 99, 20)
	assert(data.cash == 25 and not results[#results].ok, "not-ready owner cannot change profile")
	owner.attributes.WorldReady = true
	now += 1
	active = false
	fire(owner, "setCash", 99, 21)
	assert(data.cash == 25 and not results[#results].ok, "inactive profile cannot be changed")
	active = true
	now += 1
	local countBefore = #trace
	fire(owner, "setWeather", "unknown_weather", 22)
	assert(
		#overrides == 0 and #trace == countBefore and not results[#results].ok,
		"unknown weather must reject before any settlement"
	)
	now += 1
	fire(owner, "setWeather", "snow", 23)
	assert(
		overrides[1].kind == "weather" and overrides[1].id == "snow" and results[#results].ok,
		"authorized valid weather must forward validated override"
	)
	now += 1
	fire(owner, "setSeason", config.SEASONS[1].id, 24)
	assert(
		overrides[2].kind == "season" and overrides[2].id == config.SEASONS[1].id,
		"authorized season must forward validated override"
	)
	now += 1
	fire(owner, "setWeather", "auto", 25)
	assert(overrides[3].kind == "weather" and overrides[3].id == nil, "auto weather must clear override")
	now += 1
	fire(owner, "setSeason", "auto", 26)
	assert(overrides[4].kind == "season" and overrides[4].id == nil, "auto season must clear override")
	local responsesBefore = #results
	for id = 27, 126 do
		fire(owner, "addCash", 1, id)
	end
	assert(
		data.cash == 25 and #results <= responsesBefore + 1,
		"throttled attempts must not mutate or amplify responses"
	)
	now += 1
	fire(owner, "addCash", 1, 126)
	assert(data.cash == 25, "throttled id must be consumed")
	fire(owner, "addCash", 1e12, 127)
	assert(data.cash == 1e12 + 25 and saves == 3, "upper bounded command must succeed after throttle window")
	-- Gün-gece, ışık ve test araçları: yalnızca yönetici, doğrulanmış kimliklerle
	local overridesBefore = #overrides
	now += 1
	fire(stranger, "setTime", "night", 200)
	fire(stranger, "growAll", "now", 201)
	assert(#overrides == overridesBefore and refreshes == 0, "strangers cannot use time, light or test tools")
	now += 1
	fire(owner, "setTime", "night", 202)
	assert(
		overrides[#overrides].kind == "clock" and overrides[#overrides].id == "night" and results[#results].ok,
		"time preset"
	)
	now += 1
	fire(owner, "setTime", "midday_x", 203)
	assert(not results[#results].ok, "unknown time preset must be rejected by the service")
	now += 1
	fire(owner, "setLights", "on", 204)
	assert(
		overrides[#overrides].kind == "lights" and overrides[#overrides].id == "on" and results[#results].ok,
		"lights on"
	)
	now += 1
	fire(owner, "setLights", "auto", 205)
	assert(overrides[#overrides].kind == "lights" and overrides[#overrides].id == nil, "auto lights clears override")
	now += 1
	fire(owner, "setLightLevel", "dim", 206)
	assert(
		overrides[#overrides].kind == "level" and overrides[#overrides].id == "dim" and results[#results].ok,
		"light level"
	)
	now += 1
	data.animals = { { animalId = "cow", zoneId = "starter", bornAt = 123, stage = "calf", uid = "a" } }
	data.purchased = {}
	local growthTraceStart = #trace
	fire(owner, "growAll", "now", 207)
	assert(trace[growthTraceStart + 1] == "settle", "growth changes settle old income before any push/save")
	assert(
		data.animals[1].stage == "adult" and data.animals[1].bornAt == 0 and refreshes == 1 and results[#results].ok,
		"growAll makes own animals adult and refreshes the world"
	)
	now += 1
	owner.attributes.SelectedFarmIsland = "poultry"
	fire(owner, "unlockIslands", "now", 208)
	assert(
		data.purchased.island_poultry == true and data.derived == true and refreshes == 2 and results[#results].ok,
		"unlock opens the selected island and derives state"
	)
	assert(data.purchased.ext_folluk_garden == true, "unlock must include the island's extensions")
	assert(data.purchased.island_horse == nil, "unlock must not open other islands")
	now += 1
	data.animals = {}
	fire(owner, "fillSlots", "now", 209)
	local poultryZone, extensionCount = 0, 0
	for _, animal in data.animals do
		assert(animal.stage == "adult" and animal.bornAt == 0, "filled animals must be adult")
		if animal.extensionId == "folluk_garden" then
			extensionCount += 1
			assert(animal.animalId == "chicken" and animal.zoneId == "poultry", "extension animals use the source zone")
			assert(
				animal.task and animal.task.kind == "extension" and animal.task.id == "folluk_garden",
				"extension animals carry a timed task"
			)
		end
		if animal.zoneId == "poultry" then
			poultryZone += 1
		end
	end
	assert(
		poultryZone == config.ZONES.poultry.capacity,
		"fillSlots fills the zone to capacity (extension animals keep their zone slot)"
	)
	assert(
		extensionCount == config.EXTENSIONS.folluk_garden.capacity,
		"fillSlots sends idle adults to purchased extensions"
	)
	now += 1
	fire(owner, "fillSlots", "now", 210)
	assert(#data.animals == poultryZone, "filling twice must not exceed capacity")
	-- Rastgele olay test araçları: yalnızca yönetici, çalışma anı işareti koyar / sıfırlar
	now += 1
	fire(stranger, "forceMerchant", "now", 211)
	assert(data.adminForce == nil, "strangers cannot force events")
	now += 1
	data.merchant = { key = 5, bought = true }
	data.golden = { key = 5 }
	fire(owner, "forceMerchant", "now", 212)
	assert(
		results[#results].ok
			and data.adminForce.merchantUntil > os.time()
			and data.merchant == nil
			and data.golden ~= nil,
		"forceMerchant opens a visit and clears the bought marker"
	)
	now += 1
	fire(owner, "forceGolden", "now", 213)
	assert(
		results[#results].ok and data.adminForce.goldenUntil > os.time() and data.golden == nil,
		"forceGolden opens a window"
	)
	now += 1
	fire(owner, "completeSeason", "now", 214)
	assert(
		results[#results].ok and data.adminForce.completeSeason == true,
		"completeSeason flags the goal for the engagement service"
	)
	now += 1
	data.seasonal = { key = 1, progress = 0, target = 3, base = 0, claimed = false }
	fire(owner, "resetEvents", "now", 215)
	assert(
		results[#results].ok
			and data.adminForce == nil
			and data.seasonal == nil
			and data.merchant == nil
			and data.golden == nil,
		"resetEvents clears every event marker"
	)
	-- Envanter test araçları
	now += 1
	fire(stranger, "grantItems", "now", 216)
	assert(data.inventory == nil, "strangers cannot grant items")
	now += 1
	fire(owner, "grantItems", "now", 217)
	local itemCount, total = 0, 0
	for itemId in config.ITEMS do
		total += 1
		if data.inventory.items[itemId] then
			itemCount += 1
		end
	end
	assert(
		results[#results].ok and itemCount == total and next(data.inventory.equipped) == nil,
		"grantItems gives every item without equipping"
	)
	now += 1
	data.inventory.equipped.tool = "copper_hammer"
	local previousPreservations = growthPreservations
	fire(owner, "clearItems", "now", 218)
	assert(
		growthPreservations == previousPreservations + 1 and lastGrowthEquipment == "copper_hammer",
		"clearing equipped items snapshots old growth and preserves young animal progress"
	)
	assert(
		results[#results].ok and next(data.inventory.items) == nil and next(data.inventory.equipped) == nil,
		"clearItems empties the inventory"
	)
	-- Kilitli adayı seçmek mümkün olmadığından ada kimliği ya da "all" değeriyle de açılabilir
	now += 1
	owner.attributes.SelectedFarmIsland = "home"
	fire(owner, "unlockIslands", "horse", 219)
	assert(data.purchased.island_horse == true and results[#results].ok, "unlock accepts an explicit island id")
	now += 1
	fire(owner, "unlockIslands", "all", 220)
	assert(data.purchased.island_goat == true, "unlock all opens every island of the theme")
	now += 1
	data.animals = {}
	-- Verify maxAll with the real derived island/zone mapping, beyond the narrow command mock.
	farmMath.applyDerived = realFarmMath.applyDerived
	fire(owner, "maxAll", "now", 221)
	assert(results[#results].ok and #data.animals > 0, "maxAll opens, grows and fills every island")
	local farmCount = 0
	for _ in data.mainFarms do
		farmCount += 1
	end
	assert(farmCount == config.MAIN_FARM_LIMIT, "maxAll adds every missing main farm for free")
	for farmId, farm in data.mainFarms do
		for zoneId in farm.unlockedZones do
			for _, animalId in config.getZoneAnimals(config.ZONES[zoneId], farmId) do
				assert(
					realFarmMath.getLineageLevel(farm, animalId) == config.LINEAGE.maxLevel,
					"maxAll completes authoritative animal lineage in every farm for rebirth testing"
				)
			end
		end
	end
	for _, animal in data.animals do
		assert(animal.stage == "adult", "maxAll animals are adult")
	end
	owner.attributes.SelectedFarmIsland = nil
	local newcomer = makePlayer(43)
	players.PlayerAdded.fire(newcomer)
	assert(newcomer.attributes.IsAdmin == false, "new players receive server-derived permissions")
	now += 1
	local oldAnimals, oldForce, oldGolden = data.animals, data.adminForce, data.golden
	data.animals = {}
	fire(owner, "forceGolden", "now", 5000)
	assert(
		not results[#results].ok and data.adminForce == oldForce and data.golden == oldGolden,
		"a golden force with no eligible animal rejects without changing markers"
	)
	data.animals = oldAnimals
	-- Herkesi sıfırla: onay değeri şart, tam bir kez çalışır (stranger zaten yukarıda reddedildi)
	now += 1
	fire(owner, "resetAllPlayers", "now", 5001)
	assert(resetCalls == 0, "the reset needs the explicit confirm value")
	now += 1
	fire(owner, "resetAllPlayers", "confirm", 5002)
	assert(resetCalls == 1, "the owner's confirmed reset runs exactly once")

	now += 1
	failNextWeather = true
	fire(owner, "setWeather", "snow", 5003)
	assert(
		not results[#results].ok and results[#results].id == 5003 and warningCount == 1,
		"service failure returns a matching error instead of leaving the UI pending"
	)
	local failedResultCount = #results
	fire(owner, "setWeather", "snow", 5003)
	assert(#results == failedResultCount, "a failed admin request cannot replay a partly applied operation")

	print(
		"admin: actual service ownership, spoofing, numeric guards, replay, throttling, save and environment actions passed"
	)
end
