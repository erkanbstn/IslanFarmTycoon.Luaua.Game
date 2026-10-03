--!strict
return function(createState: any)
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
	local packets = { PlayerState = { OnClientEvent = signal() }, EconomyTick = { OnClientEvent = signal() } }
	local snapshotRequests = 0
	local remotes = {
		get = function(name: string): any
			if name == "RequestPlayerState" then
				return {
					FireServer = function()
						snapshotRequests += 1
					end,
				}
			end
			return packets[name]
		end,
	}
	local node: any = {
		WaitForChild = function(self: any): any
			return self
		end,
	}
	local engine = {
		GetService = function(_self: any, name: string): any
			if name == "Players" then
				return { LocalPlayer = { SetAttribute = function() end } }
			end
			return node
		end,
	}
	local warnings, notified = 0, 0
	local state = createState(engine, remotes, { spawn = function() end }, {
		clock = function(): number
			return 100
		end,
	}, function(message: string)
		assert(message:find("failing listener", 1, true) ~= nil, "Listener failures must retain their diagnostic")
		warnings += 1
	end)
	local disconnect = state.onChanged(function()
		error("failing listener")
	end)
	state.onChanged(function()
		notified += 1
	end)
	local function snapshot(id: string, cash: number, stored: number, revision: number)
		packets.PlayerState.OnClientEvent.fire({ activeMainFarmId = id, cash = cash, stored = stored }, revision)
	end
	snapshot("1", 100, 11, 10)
	packets.EconomyTick.OnClientEvent.fire(300, 99, 12, "2")
	assert(
		state.get().activeMainFarmId == "1" and state.get().stored == 11 and state.get().cash == 300,
		"early other-farm tick updates shared cash but never contaminates current storage"
	)
	snapshot("2", 250, 90, 11)
	assert(
		state.get().activeMainFarmId == "2" and state.get().cash == 300 and state.get().stored == 99,
		"late structural switch merges only matching farm's newer economy packet"
	)
	packets.EconomyTick.OnClientEvent.fire(999, 999, 9, "1")
	assert(state.get().stored == 99 and state.get().cash == 300, "stale old farm packet ignored")
	snapshot("1", 400, 13, 13)
	packets.EconomyTick.OnClientEvent.fire(500, 77, 15, "2")
	snapshot("1", 450, 14, 14)
	assert(
		state.get().stored == 14 and state.get().cash == 500,
		"snapshot of another farm must not import newest packet's storage"
	)
	packets.EconomyTick.OnClientEvent.fire(550, 18, 16, "1")
	assert(state.get().stored == 18, "matching active tick updates normal progression")
	assert(snapshotRequests > 0, "cross-farm unknown structural context requests a fresh snapshot")
	assert(warnings > 0 and warnings == notified, "A failed listener must not interrupt other listeners")
	disconnect()
	local previousWarnings = warnings
	packets.EconomyTick.OnClientEvent.fire(560, 19, 17, "1")
	assert(
		warnings == previousWarnings and notified == previousWarnings + 1,
		"Disconnected failures must stop without removing healthy listeners"
	)
	print(
		"PASS client farm state: actual source interleaved structural/economy packets preserve wallet and isolate farm storage"
	)
end
