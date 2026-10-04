--!strict
-- Gerçek TradePolicyService: PolicyService yanıtı, yeniden deneme, geçersiz yanıt, oyuncu ayrılınca temizlik ve istemci sahteciliği.
return function(createService: any)
	local function signal(): any
		local callbacks = {}
		return {
			Connect = function(_self: any, callback: any)
				table.insert(callbacks, callback)
			end,
			fire = function(...: any)
				for _, callback in callbacks do
					callback(...)
				end
			end,
		}
	end

	local function setup(): any
		local h: any = {
			clock = 0,
			waits = {},
			queue = {},
			calls = {},
			pushes = {},
			warnings = 0,
			rateAllowed = true,
			-- Varsayılan: iki oyuncu da izinli; testler yalnız ilgilendiği oyuncuyu değiştirir.
			policy = { [1] = { IsPaidItemTradingAllowed = true }, [2] = { IsPaidItemTradingAllowed = true } },
			players = {},
			list = {},
			remotes = {},
		}
		local function addPlayer(id: number): any
			local player: any = { UserId = id, DisplayName = `player{id}`, Parent = true }
			h.players[id] = player
			table.insert(h.list, player)
			return player
		end
		addPlayer(1)
		addPlayer(2)
		local playersService = {
			PlayerAdded = signal(),
			PlayerRemoving = signal(),
			GetPlayers = function(): any
				return h.list
			end,
		}
		local policyService = {
			GetPolicyInfoForPlayerAsync = function(_self: any, player: any): any
				local id = player.UserId
				h.calls[id] = (h.calls[id] or 0) + 1
				local scripted = h.policy[id]
				if typeof(scripted) == "function" then
					return scripted(h.calls[id])
				end
				return scripted
			end,
		}
		local node: any = {}
		node.WaitForChild = function(): any
			return node
		end
		local services: any = { Players = playersService, PolicyService = policyService, ReplicatedStorage = node }
		local game = {
			GetService = function(_self: any, name: string): any
				return services[name]
			end,
		}
		local remotes = {
			get = function(name: string): any
				if not h.remotes[name] then
					h.remotes[name] = {
						OnServerEvent = signal(),
						FireClient = function(_self: any, player: any, ...: any)
							table.insert(h.pushes, { name = name, userId = player.UserId, args = { ... } })
						end,
					}
				end
				return h.remotes[name]
			end,
		}
		local limiter = {
			allow = function(): boolean
				return h.rateAllowed
			end,
		}
		local fakeTask = {
			-- Yield eden gerçek çağrıyı taklit eder: iş kuyruğa girer, flush() ile çalışır.
			spawn = function(callback: any, ...: any)
				local args = { ... }
				table.insert(h.queue, function()
					callback(table.unpack(args))
				end)
			end,
			wait = function(seconds: number): number
				table.insert(h.waits, seconds)
				h.clock += seconds
				return seconds
			end,
		}
		local fakeOs = {
			clock = function(): number
				return h.clock
			end,
		}
		h.service = createService(game, remotes, limiter, fakeTask, fakeOs, function()
			h.warnings += 1
		end)
		h.flush = function()
			while #h.queue > 0 do
				table.remove(h.queue, 1)()
			end
		end
		h.join = function(id: number): any
			local player = h.players[id] or addPlayer(id)
			playersService.PlayerAdded.fire(player)
			return player
		end
		h.leave = function(id: number)
			local player = h.players[id]
			playersService.PlayerRemoving.fire(player)
			player.Parent = nil
		end
		h.lastPush = function(id: number): any
			for index = #h.pushes, 1, -1 do
				if h.pushes[index].userId == id and h.pushes[index].name == "TradePolicyState" then
					return h.pushes[index].args[1]
				end
			end
			return nil
		end
		h.service.init()
		return h
	end

	-- İki oyuncuya da izin verilmesi; her oyuncu yalnız kendi durumunu alır.
	local ok = setup()
	ok.policy[1] = { IsPaidItemTradingAllowed = true }
	ok.policy[2] = { IsPaidItemTradingAllowed = true }
	assert(ok.service.status(ok.players[1]) == "loading", "status is loading until the first response")
	assert(not ok.service.canTrade(ok.players[1]), "loading never permits trading")
	ok.flush()
	assert(ok.service.canTrade(ok.players[1]) and ok.service.canTrade(ok.players[2]), "true allows both players")
	assert(ok.lastPush(1) == "allowed" and ok.lastPush(2) == "allowed", "each client is told its own status")
	assert(ok.calls[1] == 1 and ok.calls[2] == 1, "one API call per player; repeated queries use the cache")
	for _ = 1, 5 do
		ok.service.status(ok.players[1])
	end
	assert(ok.calls[1] == 1, "cached session value is not re-fetched")

	-- Açıkça false: kısıtlı, yeniden deneme yok.
	local restricted = setup()
	restricted.policy[1] = { IsPaidItemTradingAllowed = false }
	restricted.flush()
	assert(restricted.service.status(restricted.players[1]) == "restricted", "false restricts")
	assert(not restricted.service.canTrade(restricted.players[1]), "restricted cannot trade")
	assert(restricted.calls[1] == 1 and #restricted.waits == 0, "a definitive false is not retried")
	assert(restricted.lastPush(1) == "restricted", "restricted status reaches the client")

	-- Geçici API hatası: sınırlı yeniden deneme sonra başarı.
	local flaky = setup()
	flaky.policy[1] = function(call: number): any
		if call < 3 then
			error("HttpError: temporarily unavailable")
		end
		return { IsPaidItemTradingAllowed = true }
	end
	flaky.flush()
	assert(
		flaky.service.status(flaky.players[1]) == "allowed" and flaky.calls[1] == 3,
		"two transient failures then success"
	)
	assert(
		flaky.waits[1] == 2 and flaky.waits[2] == 5 and #flaky.waits == 2,
		"retries are bounded with 2s then 5s backoff"
	)

	-- Kalıcı hata: unavailable, izin yok; 30 sn dolmadan yeni çağrı yapılmaz, sonra tembel yeniden deneme.
	local down = setup()
	down.policy[1] = function(): any
		error("service down")
	end
	down.flush()
	assert(
		down.service.status(down.players[1]) == "unavailable" and down.calls[1] == 3,
		"exhausted retries become unavailable"
	)
	assert(not down.service.canTrade(down.players[1]) and down.warnings == 1, "unavailable never permits trading")
	assert(down.lastPush(1) == "unavailable", "unavailable reaches the client")
	down.service.status(down.players[1])
	down.flush()
	assert(down.calls[1] == 3, "no retry storm inside the cool-down")
	down.policy[1] = { IsPaidItemTradingAllowed = true }
	down.clock += 29
	assert(
		down.service.status(down.players[1]) == "unavailable" and down.calls[1] == 3,
		"29s after the last attempt is still cooling down"
	)
	down.clock += 1
	assert(down.service.status(down.players[1]) == "loading", "a later query after the cool-down restarts loading")
	down.flush()
	assert(down.service.canTrade(down.players[1]), "recovery after an outage grants trading from the fresh answer")

	-- Eksik / geçersiz yanıtlar izin sayılmaz.
	local invalidResponses = {
		{ label = "nil", value = false },
		{ label = "empty table", value = {} },
		{ label = "string flag", value = { IsPaidItemTradingAllowed = "true" } },
		{ label = "number flag", value = { IsPaidItemTradingAllowed = 1 } },
		{ label = "wrong key", value = { IsPaidItemTradingAllow = true } },
		{ label = "non-table", value = "allowed" },
	}
	for _, case in invalidResponses do
		local h = setup()
		h.policy[1] = function(): any
			if case.label == "nil" then
				return nil
			end
			return case.value
		end
		h.flush()
		assert(
			h.service.status(h.players[1]) == "unavailable",
			"invalid response (" .. case.label .. ") is not permission"
		)
		assert(not h.service.canTrade(h.players[1]), "invalid response (" .. case.label .. ") cannot trade")
		assert(h.calls[1] == 3, "invalid response (" .. case.label .. ") uses the bounded retries")
	end

	-- Oyuncu ayrılınca önbellek temizlenir; uçuştaki yanıt yazılmaz; ayrılmış oyuncu yeniden izlenmez.
	local leaving = setup()
	leaving.policy[1] = { IsPaidItemTradingAllowed = true }
	leaving.flush()
	assert(leaving.service.canTrade(leaving.players[1]), "player allowed before leaving")
	leaving.players[1].Parent = true
	leaving.service.forget(leaving.players[1])
	assert(leaving.service.status(leaving.players[1]) == "loading", "forgetting drops the cached permission")
	leaving.flush()
	local late = setup()
	late.policy[1] = { IsPaidItemTradingAllowed = true }
	late.service.status(late.players[1])
	late.leave(1)
	late.flush()
	assert(late.calls[1] == 1, "only the already in-flight request ran")
	assert(late.lastPush(1) == nil, "an answer arriving after leaving is discarded and never pushed")
	assert(late.service.status(late.players[1]) == "unavailable", "a departed player is not tracked again")
	late.flush()
	assert(not late.service.canTrade(late.players[1]), "a departed player can never trade")
	local calls = late.calls[1]
	late.service.status(late.players[1])
	late.flush()
	assert(late.calls[1] == calls, "no API call for a departed player")

	-- İstemci sahteciliği: RequestTradePolicy argümanları yok sayılır, yalnız sunucu durumunu döndürür; hız sınırlıdır.
	local forged = setup()
	forged.policy[1] = { IsPaidItemTradingAllowed = false }
	forged.flush()
	local requestEvent = forged.remotes.RequestTradePolicy.OnServerEvent
	local pushedBefore = #forged.pushes
	requestEvent.fire(forged.players[1], true, "allowed", { IsPaidItemTradingAllowed = true })
	assert(
		forged.lastPush(1) == "restricted" and #forged.pushes == pushedBefore + 1,
		"client-sent flags never change the answer"
	)
	assert(not forged.service.canTrade(forged.players[1]), "forged flags do not grant permission")
	forged.rateAllowed = false
	local count = #forged.pushes
	requestEvent.fire(forged.players[1])
	assert(#forged.pushes == count, "state requests are rate limited")

	print(
		"PASS trade policy: strict true-only cache, bounded retry, invalid responses, leave cleanup and forged client flags"
	)
end
