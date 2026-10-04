--!strict
-- Gerçek SeasonService, Environment, AdminPolicy ve RateLimiter kaynakları kullanılır.
return function(createService: any, createEnvironment: any, createLimiter: any, Config: any)
	local now = 2000000000
	local studio = true
	local attributes: { [string]: any } = {}
	local onlinePlayers = {}
	for userId = 1, 6 do
		table.insert(onlinePlayers, { UserId = userId })
	end
	local players = {
		GetPlayers = function(): { any }
			return onlinePlayers
		end,
		PlayerRemoving = { Connect = function() end },
	}
	local storage = {
		WaitForChild = function(): any
			return {}
		end,
		GetAttribute = function(_self: any, name: string): any
			return attributes[name]
		end,
		SetAttribute = function(_self: any, name: string, value: any)
			attributes[name] = value
		end,
	}
	local services: any = {
		Players = players,
		ReplicatedStorage = storage,
		RunService = {
			IsStudio = function(): boolean
				return studio
			end,
		},
		Workspace = {
			GetServerTimeNow = function(): number
				return now
			end,
		},
	}
	local engine = {
		GetService = function(_self: any, name: string): any
			return services[name]
		end,
	}
	local failClock = false
	local clock = {
		time = function(): number
			if failClock then
				error("saat hatası")
			end
			return now
		end,
		clock = function(): number
			return now
		end,
	}
	local random = {
		new = function(): any
			return {
				NextNumber = function(_self: any, low: number): number
					return low
				end,
				NextInteger = function(_self: any, low: number): number
					return low
				end,
			}
		end,
	}
	local notifications: { [number]: number } = {}
	local events: { [string]: any } = {}
	local remotes = {
		get = function(name: string): any
			if not events[name] then
				events[name] = {
					OnServerEvent = {
						Connect = function(_self: any, callback: any)
							events[name].callback = callback
						end,
					},
					FireClient = function(_self: any, player: any)
						notifications[player.UserId] = (notifications[player.UserId] or 0) + 1
					end,
				}
			end
			return events[name]
		end,
	}
	local loop: thread? = nil
	local tasks = {
		spawn = function(callback: any)
			loop = coroutine.create(callback)
			assert(coroutine.resume(loop :: thread), "season loop must start")
		end,
		wait = function()
			coroutine.yield()
		end,
	}
	local environment = createEnvironment(engine)
	local limiter = createLimiter(engine, clock)
	local loopErrors = 0
	local metrics = {
		increment = function(name: string)
			if name == "LoopError" then
				loopErrors += 1
			end
		end,
	}
	local service = createService(engine, clock, random, remotes, tasks, environment, limiter, metrics, function() end)
	local settlementPermit = false
	local settlements = 0
	local settledWeatherByPlayer: { [number]: string } = {}
	for _, method in { "setSeason", "setWeather" } do
		local original = environment[method]
		environment[method] = function(...: any)
			assert(settlementPermit, "income settlement must precede each environment mutation")
			settlementPermit = false
			return original(...)
		end
	end
	service.init(function()
		settlements += 1
		for _, player in onlinePlayers do
			settledWeatherByPlayer[player.UserId] = environment.getWeather().id
		end
		settlementPermit = true
	end)
	local function tick(seconds: number)
		now += seconds
		assert(coroutine.resume(loop :: thread), "season loop update must succeed")
	end

	assert(service.setAdminWeather("snow"), "configured weather can be forced")
	assert(
		attributes.AdminWeatherOverride == "snow" and environment.getWeather().id == "snow",
		"weather override replicates"
	)
	assert(service.setAdminSeason("summer"), "configured season can be forced")
	assert(
		environment.getSeason().id == "summer" and environment.getWeather().id == "snow",
		"season override preserves forced weather"
	)
	assert(
		environment.getSeasonEndsAt() == now + Config.SEASON_SECONDS,
		"forced season starts with a complete duration"
	)
	tick(Config.SEASON_SECONDS + 1)
	assert(
		environment.getSeason().id == "summer" and environment.getWeather().id == "snow",
		"forced season repeats without discarding weather"
	)
	assert(
		environment.getSeasonEndsAt() > now and environment.getSeasonEndsAt() <= now + Config.SEASON_SECONDS,
		"forced timer renews"
	)
	assert(
		not service.setAdminSeason("bad") and not service.setAdminWeather("bad"),
		"unknown override IDs are rejected"
	)
	assert(
		attributes.AdminSeasonOverride == "summer" and attributes.AdminWeatherOverride == "snow",
		"rejected values cannot mutate overrides"
	)
	assert(service.setAdminSeason(nil), "nil restores automatic season")
	assert(attributes.AdminSeasonOverride == nil, "auto mode clears replicated override")
	assert(
		environment.getSeason().id == Config.SEASONS[environment.seasonIndexAt(now)].id,
		"auto mode immediately rejoins the global cycle"
	)
	assert(
		environment.getSeasonEndsAt() == (math.floor(now / Config.SEASON_SECONDS) + 1) * Config.SEASON_SECONDS,
		"auto timer matches global phase"
	)
	tick(Config.SEASON_SECONDS)
	assert(environment.getWeather().id == "snow", "automatic season transition still preserves forced weather")
	assert(service.setAdminWeather(nil) and attributes.AdminWeatherOverride == nil, "nil restores automatic weather")
	assert(
		Config.SEASONS[environment.seasonIndexAt(now)].weather[environment.getWeather().id],
		"auto weather belongs to current season"
	)

	local before = environment.getWeather().id
	local beforeSettlements = settlements
	events.DebugCycleWeather.callback({ UserId = 42, Name = "Geo_Geyo" })
	assert(
		environment.getWeather().id == before and attributes.AdminWeatherOverride == nil,
		"unlisted Studio player cannot use F7"
	)
	assert(settlements == beforeSettlements, "unauthorized F7 cannot trigger economic settlement")
	local owner = { UserId = 11641916529 }
	events.DebugCycleWeather.callback(owner)
	assert(
		environment.getWeather().id ~= before and attributes.AdminWeatherOverride ~= nil,
		"exact authorized Studio owner can use F7"
	)
	local forced = environment.getWeather().id
	events.DebugCycleWeather.callback(owner)
	assert(environment.getWeather().id == forced, "repeated F7 is rate limited")
	now += 1
	studio = false
	events.DebugCycleWeather.callback(owner)
	assert(environment.getWeather().id == forced, "F7 remains Studio-only even for authorized owner")
	-- Oyuncu asası: tüm sunucu, altı bildirim, eski gelir ve tam doğal süre.
	assert(not service.setPlayerWeather("rain"), "player staff cannot override admin weather")
	assert(service.setAdminWeather(nil), "release admin weather before normal play")
	now = (math.floor(now / Config.SEASON_SECONDS) + 1) * Config.SEASON_SECONDS - 10
	tick(0)
	local originalWeather = environment.getWeather().id
	local picked: string? = nil
	for id in environment.getSeason().weather do
		if id ~= originalWeather then
			picked = id
			break
		end
	end
	local selected = assert(picked, "season has another weather available for the staff")
	local oldDeadline = attributes.WeatherEndsAt
	local unchangedSettlements = settlements
	assert(not service.setPlayerWeather("unknown"), "invalid player weather is rejected")
	assert(not service.setPlayerWeather(originalWeather), "same weather consumes no change")
	local unavailable: string? = nil
	for id in Config.WEATHER do
		if not environment.getSeason().weather[id] then
			unavailable = id
			break
		end
	end
	if unavailable then
		assert(not service.setPlayerWeather(unavailable), "global season pool is enforced")
	end
	assert(
		settlements == unchangedSettlements and attributes.WeatherEndsAt == oldDeadline,
		"rejected changes preserve income and timer"
	)
	local notificationBefore = table.clone(notifications)
	assert(service.setPlayerWeather(selected), "valid equipped staff weather can be applied by the inventory service")
	assert(
		attributes.WandWeatherActive == true and attributes.AdminWeatherOverride == nil,
		"wand weather is temporary, not an admin lock"
	)
	local deadline = attributes.WeatherEndsAt
	assert(deadline == now + Config.WEATHER_SECONDS_MIN, "wand uses the same randomized duration as natural weather")
	for _, player in onlinePlayers do
		assert(
			settledWeatherByPlayer[player.UserId] == originalWeather,
			"all six players settle with the old weather first"
		)
		assert(
			notifications[player.UserId] == (notificationBefore[player.UserId] or 0) + 1,
			"all six players receive the weather change"
		)
		local personal =
			{ seasonId = "winter", seasonEndsAt = now + 900, weatherId = originalWeather, weatherEndsAt = now + 900 }
		assert(
			environment.getWeather(personal).id == selected,
			"personal season and legacy weather cannot hide global wand weather"
		)
	end
	tick(11)
	assert(
		environment.getWeather().id == selected and attributes.WeatherEndsAt == deadline,
		"season seam does not shorten the chosen weather duration"
	)
	tick(deadline - now - 1)
	assert(attributes.WandWeatherActive == true, "weather remains active until its full deadline")
	tick(1)
	assert(
		attributes.WandWeatherActive == false and attributes.WeatherEndsAt > now,
		"expiry resumes the normal weather timer automatically"
	)
	assert(
		environment.getSeason().weather[environment.getWeather().id],
		"expiry selects weather valid for the new season"
	)
	assert(
		environment.getWeather({ weatherId = selected, weatherEndsAt = now + 900 }).id == environment.getWeather().id,
		"legacy weather cannot reappear after expiry"
	)
	failClock = true
	local resumed, resumeError = coroutine.resume(loop :: thread)
	assert(resumed, tostring(resumeError))
	failClock = false
	assert(loopErrors == 1, "loop failure is counted")
	tick(1)
	assert(loopErrors == 1, "season loop keeps running after a failure")
	print(
		"PASS season admin: forced/auto weather and seasons, timer renewal, settlement ordering, exact F7 authorization and throttle"
	)
end
