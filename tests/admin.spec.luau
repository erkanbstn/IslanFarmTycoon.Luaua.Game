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
	}
	local service = createService(fakeGame, remotes, dataService, economy, seasons, limiter)
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
	local newcomer = makePlayer(43)
	players.PlayerAdded.fire(newcomer)
	assert(newcomer.attributes.IsAdmin == false, "new players receive server-derived permissions")
	print(
		"admin: actual service ownership, spoofing, numeric guards, replay, throttling, save and environment actions passed"
	)
end
