--!strict
return function(policy: any, createService: any, createLimiter: any, config: any)
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
		return if name == "Players" then players else node
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
	local data: any = { cash = 50 }
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
	local seasons = {
		setAdminWeather = function(id: string?): boolean
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
	local farmMath = {
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
				if animal.zoneId == zoneId and animal.extensionId == nil then
					count += 1
				end
			end
			return count
		end,
		countInExtension = function(save: any, extensionId: string): number
			local count = 0
			for _, animal in save.animals do
				if animal.extensionId == extensionId then
					count += 1
				end
			end
			return count
		end,
	}
	local service = createService(fakeGame, remotes, dataService, economy, plots, farmMath, seasons, limiter)
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
	fire(owner, "growAll", "now", 207)
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
		elseif animal.zoneId == "poultry" then
			poultryZone += 1
		end
	end
	assert(poultryZone == config.ZONES.poultry.capacity, "fillSlots fills the zone to capacity")
	assert(extensionCount == config.EXTENSIONS.folluk_garden.capacity, "fillSlots fills purchased extensions")
	now += 1
	fire(owner, "fillSlots", "now", 210)
	assert(#data.animals == poultryZone + extensionCount, "filling twice must not exceed capacity")
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
	owner.attributes.SelectedFarmIsland = nil
	local newcomer = makePlayer(43)
	players.PlayerAdded.fire(newcomer)
	assert(newcomer.attributes.IsAdmin == false, "new players receive server-derived permissions")
	print(
		"admin: actual service ownership, spoofing, numeric guards, replay, throttling, save and environment actions passed"
	)
end
