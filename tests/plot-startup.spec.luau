--!strict
-- Gerçek PlotService.init/assign/release; yalnızca dünya nesneleri ve görsel servisler taklit edilir.
return function(createPlotService: any, Config: any)
	local function fixture(invalidMap: boolean): any
		local ensureCalls, validateCalls = 0, 0
		local warnings: { string } = {}
		local profiles: { [any]: any } = {}
		local rendered: { [any]: any } = {}
		local pushes: { [any]: number } = {}
		local plots: { any } = {}
		local themes: { [any]: number } = {}
		local themeCalls = 0
		for index = 1, Config.MAP_PLOT_COUNT do
			local plot: any = { Name = `Plot{index}`, attributes = { PlotId = tostring(index) } }
			function plot:IsA(class: string): boolean
				return class == "Model"
			end
			function plot:GetAttribute(name: string): any
				return self.attributes[name]
			end
			function plot:SetAttribute(name: string, value: any)
				self.attributes[name] = value
			end
			function plot:FindFirstChild(): any
				return nil
			end
			table.insert(plots, plot)
		end
		local plotFolder = {
			GetChildren = function(): any
				return plots
			end,
		}
		local services: any = {
			Players = { MaxPlayers = Config.MAP_PLOT_COUNT + 20 },
			Workspace = {
				FindFirstChild = function(_self: any, name: string): any
					return if name == "Plots" then plotFolder else nil
				end,
			},
			ReplicatedStorage = {
				WaitForChild = function(): any
					return {}
				end,
			},
		}
		local engine = {
			GetService = function(_self: any, name: string): any
				return services[name]
			end,
		}
		local map = {
			ensure = function()
				ensureCalls += 1
			end,
			validate = function()
				validateCalls += 1
				assert(not invalidMap, "Injected malformed map")
			end,
			applyTheme = function(target: any, themeIndex: number): boolean
				themeCalls += 1
				themes[target] = themeIndex
				return true
			end,
		}
		local noop = function() end
		local service = createPlotService(
			engine,
			function(message: string)
				table.insert(warnings, message)
			end,
			{},
			{ setTag = noop, setSignText = noop },
			{
				tryGet = function(owner: any): any
					return profiles[owner]
				end,
				getFarmView = function(owner: any, id: string): any
					local profile = profiles[owner]
					return if profile then profile.mainFarms[id] else nil
				end,
				pushState = function(owner: any)
					pushes[owner] = (pushes[owner] or 0) + 1
				end,
			},
			map,
			{
				clear = function(target: any)
					rendered[target] = nil
				end,
				refresh = function(target: any, view: any)
					rendered[target] = view
				end,
			},
			{ applyForPlayer = noop },
			{ apply = noop },
			{ apply = noop },
			{ apply = noop },
			{ syncProductionSites = noop, syncMilkLoadingDecor = noop },
			{ reset = noop }
		)
		return {
			service = service,
			plots = plots,
			warnings = warnings,
			profiles = profiles,
			rendered = rendered,
			pushes = pushes,
			themes = themes,
			themeSwaps = function(): number
				return themeCalls
			end,
			calls = function(): (number, number)
				return ensureCalls, validateCalls
			end,
		}
	end
	local function player(index: number): any
		return {
			UserId = index,
			Name = `Player{index}`,
			DisplayName = `Player{index}`,
			attributes = {},
			GetAttribute = function(self: any, name: string): any
				return self.attributes[name]
			end,
			SetAttribute = function(self: any, name: string, value: any)
				self.attributes[name] = value
			end,
			CharacterAdded = {
				Connect = function(): any
					return { Disconnect = function() end }
				end,
			},
		}
	end
	local test = fixture(false)
	local initialized, problem = pcall(test.service.init)
	assert(initialized, `MaxPlayers above plot capacity must not abort startup: {problem}`)
	local ensured, validated = test.calls()
	assert(ensured == 1 and validated == 1, "startup must still ensure and validate the map")
	assert(#test.warnings == 1, "capacity mismatch must produce an actionable warning")
	assert(#test.service.getAllPlots() == Config.MAP_PLOT_COUNT, "valid plots remain available")
	local owners = {}
	for index = 1, Config.MAP_PLOT_COUNT do
		owners[index] = player(index)
		assert(test.service.assign(owners[index]), "each existing plot must accept an owner")
	end
	local overflow = player(Config.MAP_PLOT_COUNT + 1)
	assert(not test.service.assign(overflow), "only overflow player must be rejected")
	assert(test.service.getPlot(overflow) == nil, "overflow must not acquire another player's plot")
	assert(test.service.assign(owners[1]), "repeated assignment must preserve existing ownership")
	local freed = test.service.getPlot(owners[1])
	test.service.release(owners[1])
	assert(test.service.assign(overflow), "released plot must become available again")
	assert(test.service.getOwner(freed) == overflow, "new owner must hold the released plot")

	local invalid = fixture(true)
	assert(not pcall(invalid.service.init), "invalid map must still reject startup")
	local _, invalidChecks = invalid.calls()
	assert(invalidChecks == 1 and #invalid.service.getAllPlots() == 0, "failed validation cannot open plots")

	local multi = fixture(false)
	local service = multi.service
	service.init()
	local alice, bob = player(101), player(102)
	assert(
		service.assign(alice) and service.assign(bob),
		"every player gets exactly one physical plot before profile load"
	)
	local mine, theirs = service.getPlot(alice), service.getPlot(bob)
	assert(mine ~= nil and theirs ~= nil and mine ~= theirs, "each player gets a different random free plot")
	assert(service.getFarmId(mine) == "1", "every player starts on farm 1")
	assert(multi.themeSwaps() == 0, "assigning a plot before the profile loads must not rebuild any theme")
	local records: any = {}
	for index = 1, 4 do
		records[tostring(index)] = {
			barnLevel = index,
			stored = index * 123,
			animals = { { uid = `farm-{index}-animal` } },
			purchased = { [`farm-{index}-upgrade`] = true },
		}
	end
	multi.profiles[alice] = { activeMainFarmId = "2", mainFarms = records }
	multi.profiles[bob] = { activeMainFarmId = "1", mainFarms = { ["1"] = records["1"] } }
	assert(
		service.restoreMainFarms(alice, { "1", "2", "3" }, "2"),
		"saved active farm restores on the player's own plot"
	)
	assert(
		service.getPlot(alice) == mine and service.getFarmId(mine) == "2",
		"active logical id is shown on the player's plot"
	)
	assert(multi.themes[mine] == 2, "the plot is re-themed to the active farm")
	assert(service.getOwner(theirs) == bob and service.getFarmId(theirs) == "1", "other players are untouched")
	assert((multi.themes[theirs] or 1) == 1, "a farm 1 player keeps the base theme")
	assert(not service.restoreMainFarms(alice, { "1" }, "2"), "active farm must be one of the saved farms")
	assert(multi.rendered[mine] == records["2"], "only the active farm is rendered")
	assert(
		service.getMainFarmPlotId(alice, "2") == mine:GetAttribute("PlotId"),
		"active farm reports its physical plot"
	)
	assert(service.getMainFarmPlotId(alice, "1") == nil, "parked farms have no physical plot")
	local owned = service.getAllOwned(alice)
	local count = 0
	for _ in owned do
		count += 1
	end
	assert(count == 1 and owned["2"] == mine, "exactly one plot is owned")
	owned["2"] = nil
	assert(
		service.getMainFarmPlotId(alice, "2") == mine:GetAttribute("PlotId"),
		"caller cannot mutate ownership through returned mapping"
	)

	local offers = service.getMainFarmOffers()
	assert(#offers == Config.MAIN_FARM_LIMIT and offers[1].id == "1", "offers list every purchasable theme")
	assert(offers[1].ownerUserId == nil and offers[6].ownerUserId == nil, "themes are never reserved by other players")

	multi.profiles[alice].mainFarms["5"] = { barnLevel = 1, stored = 0, animals = {}, purchased = {} }
	assert(service.selectMainFarm(alice, "5"), "an owned farm can be activated")
	assert(multi.themes[mine] == 5 and service.getFarmId(mine) == "5", "activation re-themes the plot")
	assert(
		alice.attributes.ActiveMainFarmId == "5" and alice.attributes.ActivePlotId == mine:GetAttribute("PlotId"),
		"activation publishes both logical and physical context"
	)
	assert(service.getPlot(alice) == mine and service.getOwner(theirs) == bob, "activation keeps the same plot")
	assert(
		multi.profiles[alice].activeMainFarmId == "2",
		"plot service must leave data facade switching to backend transaction"
	)
	assert(not service.selectMainFarm(alice, "unknown"), "unowned logical farm cannot activate")
	assert(records["1"].stored == 123 and records["4"].stored == 492, "switching never mutates saved farm contents")

	local swapsBefore = multi.themeSwaps()
	service.release(alice)
	assert(multi.themeSwaps() == swapsBefore, "releasing a plot must not rebuild its theme")
	assert(service.getOwner(mine) == nil and multi.themes[mine] == 5, "a released plot keeps its theme (no reset)")
	local newcomer = player(108)
	assert(service.assign(newcomer), "a free plot is available again")
	local received = service.getPlot(newcomer)
	assert(received ~= theirs, "an occupied plot is never handed out")
	assert(service.getFarmId(received) == "1", "the next player starts on farm 1")
	print(
		"PASS plot startup: MaxPlayers warning, map validation, one plot per player, runtime theme swap, release reset"
	)
end
