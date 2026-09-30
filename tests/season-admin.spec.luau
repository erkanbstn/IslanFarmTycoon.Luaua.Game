--!strict
-- Gerçek SeasonService, Environment, AdminPolicy ve RateLimiter kaynakları kullanılır.
return function(createService: any, createEnvironment: any, createLimiter: any, Config: any)
	local now = 2000000000
	local studio = true
	local attributes: { [string]: any } = {}
	local players = {
		GetPlayers = function(): { any }
			return {}
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
	local clock = {
		time = function(): number
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
					FireClient = function() end,
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
	local service = createService(engine, clock, random, remotes, tasks, environment, limiter)
	local settlementPermit = false
	local settlements = 0
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

	-- Mevsim asası: seçilen mevsim tam süre sürer, sonra doğal döngüye dönülür; yönetici sabitlemesi önüne geçer
	local target = Config.SEASONS[environment.seasonIndexAt(now) % #Config.SEASONS + 1].id
	assert(
		service.setPlayerSeason(target) and environment.getSeason().id == target,
		"the season staff changes the season"
	)
	assert(environment.getSeasonEndsAt() == now + Config.SEASON_SECONDS, "a staff season lasts a full duration")
	assert(not service.setPlayerSeason("bad"), "unknown staff seasons are rejected")
	tick(Config.SEASON_SECONDS + 1)
	assert(
		environment.getSeason().id == Config.SEASONS[environment.seasonIndexAt(now)].id,
		"the season returns to the natural cycle after a staff season"
	)
	assert(service.setAdminSeason("winter"), "admin can pin the season")
	assert(
		not service.setPlayerSeason("summer") and environment.getSeason().id == "winter",
		"an admin-pinned season blocks the staff"
	)
	assert(service.setAdminSeason(nil), "admin releases the season")
	-- Hava asası: anlık hava değişir; yönetici sabitlemesi önüne geçer
	assert(
		service.setPlayerWeather("rain") and environment.getWeather().id == "rain",
		"the weather staff changes the weather"
	)
	assert(not service.setPlayerWeather("bad"), "unknown staff weather is rejected")
	assert(service.setAdminWeather("snow"), "admin can pin the weather")
	assert(
		not service.setPlayerWeather("rain") and environment.getWeather().id == "snow",
		"admin-pinned weather blocks the staff"
	)
	assert(service.setAdminWeather(nil), "admin releases the weather")

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
	print(
		"PASS season admin: forced/auto weather and seasons, timer renewal, settlement ordering, exact F7 authorization and throttle"
	)
end
