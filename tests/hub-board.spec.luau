--!strict
return function(createService: any, config: any)
	local board = {}
	local available = false
	local players = { { DisplayName = "Ada" }, { DisplayName = "Bora" }, { DisplayName = "Cem" } }
	local saves: { [any]: any } = {
		[players[1]] = { cash = 100.9, progression = { count = 30 }, farms = { "1", "2" } },
		[players[2]] = { cash = 200, farms = { "1" } },
	}
	local rows: { any } = {}
	local starts = 0
	local worker: thread? = nil
	local node: any = {}
	function node:WaitForChild(_name: string): any
		return self
	end
	local workspaceMock: any = {}
	function workspaceMock:FindFirstChild(_name: string): any
		return if available
			then {
				FindFirstChild = function(_self: any, name: string, recursive: boolean): any
					assert(name == "PlayerBoard" and recursive, "ranking searches the modeled board recursively")
					return board
				end,
			}
			else nil
	end
	local gameMock: any = {}
	function gameMock:GetService(name: string): any
		if name == "Players" then
			return {
				GetPlayers = function(): any
					return players
				end,
			}
		elseif name == "Workspace" then
			return workspaceMock
		end
		return node
	end
	local taskMock = {
		spawn = function(callback: () -> ())
			starts += 1
			worker = coroutine.create(callback)
		end,
		wait = function(seconds: number)
			assert(seconds == 3, "ranking retains its bounded refresh interval")
			coroutine.yield()
		end,
	}
	local function tick()
		local ok, err = coroutine.resume(worker :: thread)
		assert(ok, tostring(err))
	end
	local service = createService(gameMock, taskMock, config, {
		formatMoney = function(cash: number): string
			return `${cash}`
		end,
	}, {
		setBoardRow = function(actualBoard: any, index: number, name: string, value: string)
			assert(actualBoard == board, "ranking updates only the found board")
			rows[index] = { name = name, value = value }
		end,
	}, {
		tryGet = function(player: any): any
			return saves[player]
		end,
		getFarmIds = function(player: any): any
			return saves[player].farms
		end,
	})
	service.init()
	service.init()
	assert(starts == 1, "ranking initializes only one worker")
	tick()
	assert(next(rows) == nil, "missing world is safely retried")
	available = true
	tick()
	assert(rows[1].name == "1. Bora" and rows[2].name == "2. Ada", "cash ranking remains descending")
	assert(rows[1].value == "$200 · 1 ada\nRebirth: 0", "legacy profile displays zero rebirth")
	assert(rows[2].value == "$100 · 2 ada\nRebirth: 30", "terminal rebirth count and farm count appear alongside cash")
	assert(rows[3].name == "" and rows[3].value == "", "unloaded player cannot occupy a ranking row")
	saves[players[1]].progression.count = 29
	saves[players[1]].cash = 300
	tick()
	assert(
		rows[1].name == "1. Ada" and rows[1].value == "$300 · 2 ada\nRebirth: 29",
		"live rebirth/cash changes refresh together"
	)
	saves[players[1]] = nil
	tick()
	assert(rows[2].name == "" and rows[2].value == "", "departed profile clears stale ranking text")
	for index = 3, config.MAP_PLOT_COUNT do
		assert(rows[index].name == "" and rows[index].value == "", "unused modeled rows are cleared")
	end
	print("PASS hub board: cash order, live rebirth, legacy zero, missing world and stale row cleanup")
end
