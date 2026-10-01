--!strict
-- Gerçek EconomyService döngüsü: bir oyuncudaki hata diğer oyuncunun gelirini durdurmamalı.
return function(createEconomy: any, createLimiter: any, codec: any, config: any, farmMath: any)
	local now = 100000
	local serial = 0
	local function newData(): any
		local function nextUid(): string
			serial += 1
			return `loop-test-{serial}`
		end
		local seed = assert(codec.decode(nil, config, farmMath, now, nextUid), "new account")
		seed.cash, seed.stored, seed.purchased = 10, 0, {}
		seed.animals = { { uid = "cow-1", animalId = "cow", zoneId = "starter", bornAt = 0, stage = "adult" } }
		seed.production = {}
		return assert(codec.decode(codec.encode(seed, now), config, farmMath, now, nextUid), "decode")
	end
	local healthy: any = { Parent = {} }
	local broken: any = { Parent = {} }
	local datas = { [healthy] = newData(), [broken] = newData() }
	local players = {
		PlayerRemoving = { Connect = function() end },
		GetPlayers = function(): { any }
			return { broken, healthy }
		end,
	}
	local node: any = {
		WaitForChild = function(): any
			return {}
		end,
	}
	local engine = {
		GetService = function(_self: any, name: string): any
			return if name == "Players" then players else node
		end,
	}
	local plot = {
		FindFirstChild = function(): any
			return nil
		end,
	}
	local explode = true
	local dataService = {
		tryGet = function(player: any): any
			return datas[player]
		end,
		getFarmIds = function(player: any): { string }
			if player == broken and explode then
				error("bozuk oyuncu verisi")
			end
			return { "1" }
		end,
		getFarmView = function(player: any): any
			return datas[player]
		end,
		pushEconomy = function() end,
	}
	local plots = {
		getPlot = function(): any
			return plot
		end,
		getAllOwned = function(): any
			return {}
		end,
		getOwner = function(): any
			return nil
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
	local loopErrors = 0
	local metrics = {
		increment = function(name: string)
			if name == "LoopError" then
				loopErrors += 1
			end
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
		metrics,
		clock,
		dateTime,
		{},
		function() end
	)
	economy.startPlayer(broken)
	economy.startPlayer(healthy)
	now += 30
	economy.tick()
	assert(loopErrors == 1, `failing player is counted once ({loopErrors})`)
	assert(datas[healthy].stored > 0, "healthy player's income is still processed")
	local after = datas[healthy].stored
	explode = false
	now += 30
	economy.tick()
	assert(loopErrors == 1, "no new error after the player recovers")
	assert(datas[healthy].stored > after and datas[broken].stored > 0, "loop keeps running for everyone")
	print("PASS economy service: per-player error isolation in the income loop")
end
