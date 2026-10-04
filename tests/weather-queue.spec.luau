--!strict
-- Gerçek hava servisi ve ortam kaynaklarında kuyruk, hak tüketimi ve temizleme regresyonları.
return function(createService: any, createEnvironment: any, createLimiter: any, Config: any)
	local function fixture(): any
		local now = 2000000000
		local attributes: { [string]: any } = {}
		local callbacks: { [string]: any } = {}
		local messages: { [number]: { any } } = {}
		local onlinePlayers: { any } = {}
		for id = 1, 6 do
			onlinePlayers[id] = { UserId = id, Name = `Player{id}`, DisplayName = `Player {id}` }
			messages[id] = {}
		end
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
			Players = {
				GetPlayers = function(): { any }
					return onlinePlayers
				end,
				PlayerRemoving = {
					Connect = function(_self: any, callback: any)
						callbacks.remove = callback
					end,
				},
			},
			ReplicatedStorage = storage,
			RunService = {
				IsStudio = function(): boolean
					return true
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
		local remotes = {
			get = function(name: string): any
				return {
					OnServerEvent = {
						Connect = function(_self: any, callback: any)
							callbacks[name] = callback
						end,
					},
					FireClient = function(_self: any, player: any, payload: any)
						if name == "WeatherQueueOffer" then
							table.insert(messages[player.UserId], payload)
						end
					end,
				}
			end,
		}
		local loop: thread? = nil
		local tasks = {
			spawn = function(callback: any)
				loop = coroutine.create(callback)
				assert(coroutine.resume(loop :: thread))
			end,
			wait = function()
				coroutine.yield()
			end,
		}
		local environment = createEnvironment(engine)
		local limiter = createLimiter(engine, clock)
		local errors = 0
		local service = createService(engine, clock, random, remotes, tasks, environment, limiter, {
			increment = function(name: string)
				if name == "LoopError" then
					errors += 1
				end
			end,
		}, function() end)
		local settled = false
		for _, method in { "setSeason", "setWeather" } do
			local original = environment[method]
			environment[method] = function(...: any): any
				assert(settled, "queued weather must settle old income before changing global environment")
				settled = false
				return original(...)
			end
		end
		service.init(function()
			settled = true
		end)
		assert(service.setAdminSeason("summer"))
		local weather: string? = nil
		for id in environment.getSeason().weather do
			if id ~= environment.getWeather().id then
				weather = id
				break
			end
		end
		local selected = assert(weather, "staff fixture has another valid weather")
		assert(service.setPlayerWeather(selected, onlinePlayers[1]), "first staff activates immediately")
		local starts: { [number]: number } = {}
		local eligible: { [number]: boolean } = {}
		for id = 1, 6 do
			starts[id] = 0
			eligible[id] = true
		end
		local function offer(id: number): any
			assert(service.offerWeatherQueue(onlinePlayers[id], "weather_staff", selected))
			local history = messages[id]
			local payload = history[#history]
			assert(
				payload.kind == "offer" and payload.ownerName == attributes.WandWeatherOwnerName,
				"queue offer identifies the active staff owner"
			)
			assert(
				payload.endsAt == attributes.WeatherEndsAt and payload.expiresAt == now + 30,
				"queue offer carries authoritative effect and confirmation deadlines"
			)
			assert(starts[id] == 0, "preview cannot spend a use")
			return payload
		end
		local function confirm(id: number, payload: any): (boolean, string?)
			return service.confirmWeatherQueue(
				onlinePlayers[id],
				"weather_staff",
				selected,
				payload.token,
				function(): (boolean, string?)
					return eligible[id], "not eligible"
				end,
				function()
					starts[id] += 1
				end
			)
		end
		local function tick(seconds: number)
			now += seconds
			assert(coroutine.resume(loop :: thread))
			assert(errors == 0, "queue loop must not silently swallow failures")
		end
		return {
			service = service,
			attributes = attributes,
			players = onlinePlayers,
			messages = messages,
			starts = starts,
			eligible = eligible,
			offer = offer,
			confirm = confirm,
			tick = tick,
			remove = callbacks.remove,
			now = function(): number
				return now
			end,
		}
	end
	local f = fixture()
	local offer2 = f.offer(2)
	assert(
		not f.service.confirmWeatherQueue(
			f.players[3],
			"weather_staff",
			offer2.weatherId,
			offer2.token,
			function(): boolean
				return true
			end,
			function()
				error("foreign offer spent")
			end
		),
		"another player cannot confirm a token"
	)
	assert(
		not f.service.confirmWeatherQueue(f.players[2], "weather_staff", offer2.weatherId, "forged", function(): boolean
			return true
		end, function()
			error("bad token spent")
		end),
		"unknown token cannot queue"
	)
	assert(f.confirm(2, offer2) and f.starts[2] == 0, "confirmation queues without spending")
	assert(not f.confirm(2, offer2), "confirmation token can be consumed only once")
	assert(
		not f.service.offerWeatherQueue(f.players[2], "weather_staff", offer2.weatherId),
		"one pending queue per player"
	)
	local offer3 = f.offer(3)
	assert(
		offer3.startsAt == offer2.endsAt + Config.WEATHER_SECONDS_MIN,
		"preview includes preceding full queued duration"
	)
	assert(
		f.confirm(3, offer3) and f.starts[3] == 0,
		"second queued confirmation cannot consume a use before activation"
	)
	assert(
		f.messages[2][#f.messages[2]].position == 1 and f.messages[3][#f.messages[3]].position == 2,
		"FIFO positions publish"
	)
	f.tick(Config.WEATHER_SECONDS_MIN - 1)
	assert(f.starts[2] == 0 and f.attributes.WandWeatherOwnerId == 1, "second player cannot replace active staff")
	f.tick(1)
	assert(
		f.starts[2] == 1 and f.starts[3] == 0 and f.attributes.WandWeatherOwnerId == 2,
		"first queued player activates at deadline"
	)
	assert(
		not f.service.hasQueuedWeather(f.players[2]) and f.service.hasQueuedWeather(f.players[3]),
		"activation removes only the first pending entry"
	)
	f.tick(Config.WEATHER_SECONDS_MIN)
	assert(
		f.starts[2] == 1 and f.starts[3] == 1 and f.attributes.WandWeatherOwnerId == 3,
		"next player activates with one use each"
	)
	f.tick(Config.WEATHER_SECONDS_MIN)
	assert(
		f.attributes.WandWeatherActive == false and f.attributes.WeatherEndsAt > f.now(),
		"empty queue resumes natural weather"
	)
	f = fixture()
	assert(f.confirm(2, f.offer(2)))
	assert(f.confirm(3, f.offer(3)))
	assert(
		f.service.cancelQueuedWeather(f.players[2]) and not f.service.hasQueuedWeather(f.players[2]),
		"successful cancellation removes the player from the queue"
	)
	assert(not f.service.cancelQueuedWeather(f.players[2]), "repeat cancellation cannot affect another entry")
	assert(f.messages[3][#f.messages[3]].position == 1, "cancellation recomputes remaining positions")
	f.tick(Config.WEATHER_SECONDS_MIN)
	assert(
		f.starts[2] == 0 and f.starts[3] == 1 and f.attributes.WandWeatherOwnerId == 3,
		"cancelled entry spends nothing"
	)
	f = fixture()
	local expiring = f.offer(2)
	f.tick(30)
	assert(
		not f.confirm(2, expiring) and not f.service.hasQueuedWeather(f.players[2]),
		"offer expires at exact deadline"
	)
	f = fixture()
	local rejected = f.offer(2)
	f.eligible[2] = false
	assert(not f.confirm(2, rejected) and f.starts[2] == 0, "ineligible confirmation cannot enqueue or spend")
	f.eligible[2] = true
	assert(f.confirm(2, rejected))
	assert(f.confirm(3, f.offer(3)))
	f.eligible[2] = false
	f.tick(Config.WEATHER_SECONDS_MIN)
	assert(
		f.starts[2] == 0 and f.starts[3] == 1,
		"lost ownership/equipment/use skips entry without blocking later players"
	)
	f = fixture()
	assert(f.confirm(2, f.offer(2)))
	local pending = f.offer(3)
	f.remove(f.players[2])
	f.remove(f.players[3])
	assert(
		not f.service.hasQueuedWeather(f.players[2]) and not f.confirm(3, pending),
		"leaving clears queued entry and outstanding offer"
	)
	f.tick(Config.WEATHER_SECONDS_MIN)
	assert(
		f.starts[2] == 0 and f.starts[3] == 0 and f.attributes.WandWeatherActive == false,
		"disconnected entries cannot activate"
	)
	f = fixture()
	assert(f.confirm(2, f.offer(2)))
	pending = f.offer(3)
	assert(f.service.setAdminWeather("snow"))
	assert(
		not f.service.hasQueuedWeather(f.players[2]) and not f.confirm(3, pending),
		"admin lock clears queue and offers"
	)
	f.tick(Config.WEATHER_SECONDS_MIN)
	assert(
		f.starts[2] == 0 and f.attributes.Weather == "snow",
		"admin cancellation spends nothing and forced weather persists"
	)
	f = fixture()
	pending = f.offer(2)
	assert(f.service.setAdminSeason("winter"))
	-- Etkin asa süresi korunur; yöneticinin hava sabitlemesi eski teklifi kesin geçersiz kılar.
	assert(f.service.setAdminWeather("snow"))
	assert(not f.confirm(2, pending) and f.starts[2] == 0, "changed environment cannot approve a stale quote")
	print(
		"PASS weather queue: FIFO, deferred use, exact activation, cancellation, token ownership, expiry, eligibility, disconnect and admin cleanup"
	)
end
