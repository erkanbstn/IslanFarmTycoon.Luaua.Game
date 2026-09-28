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
			{ syncProductionSites = noop, syncMilkLoadingDecor = noop }
		)
		return {
			service = service,
			plots = plots,
			warnings = warnings,
			profiles = profiles,
			rendered = rendered,
			pushes = pushes,
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
	test.service.release(owners[1])
	assert(test.service.assign(overflow), "released plot must become available again")
	assert(test.service.getOwner(test.plots[1]) == overflow, "new owner must hold the released plot")

	local invalid = fixture(true)
	assert(not pcall(invalid.service.init), "invalid map must still reject startup")
	local _, invalidChecks = invalid.calls()
	assert(invalidChecks == 1 and #invalid.service.getAllPlots() == 0, "failed validation cannot open plots")

	local multi = fixture(false)
	local service = multi.service
	service.init()
	local alice, bob = player(101), player(102)
	assert(service.assign(alice) and service.assign(bob), "primary slots reserve before profile load")
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
	assert(
		service.restoreMainFarms(alice, { "1", "2", "3" }, "2"),
		"saved active farm restores in reserved primary slot"
	)
	assert(
		service.getPlot(alice) == multi.plots[1] and service.getFarmId(multi.plots[1]) == "2",
		"active logical id controls primary physical mapping"
	)
	assert(service.getOwner(multi.plots[2]) == bob, "restoring additional farms cannot take another player's plot")
	assert(not service.reserveMainFarm(alice, "4", "2"), "occupied target cannot be bought")
	assert(not service.reserveMainFarm(alice, "2", "5"), "same logical farm cannot reserve a second plot")
	assert(not service.reserveMainFarm(alice, "4", "missing"), "unknown physical target is rejected")
	assert(service.reserveMainFarm(alice, "4", "5"), "empty requested physical plot can be reserved")
	assert(service.getPlot(alice) == multi.plots[1], "reserving farm never silently changes active context")
	assert(
		not service.cancelMainFarmReservation(bob, "4"),
		"reservation rollback cannot cancel another player's mapped farm"
	)
	assert(not service.cancelMainFarmReservation(alice, "2"), "rollback cannot release caller's active farm")
	assert(service.cancelMainFarmReservation(alice, "4"), "inactive reservation can be rolled back")
	assert(
		service.getOwner(multi.plots[5]) == nil and service.getMainFarmPlotId(alice, "4") == nil,
		"rollback releases physical ownership and logical mapping together"
	)
	assert(
		service.getPlot(alice) == multi.plots[1] and service.getOwner(multi.plots[2]) == bob,
		"rollback preserves caller's active slot and every other owner"
	)
	assert(records["4"].stored == 492, "reservation rollback never mutates profile data")
	assert(service.reserveMainFarm(alice, "4", "5"), "released reservation is available for a later transaction")
	local offers = service.getMainFarmOffers()
	assert(#offers == Config.MAP_PLOT_COUNT, "server offers include all physical plots without client streaming")
	assert(
		offers[1].id == "1" and offers[1].ownerUserId == alice.UserId,
		"offer reports authoritative occupied ownership"
	)
	assert(
		offers[6].id == "6" and offers[6].ownerUserId == nil,
		"unstreamed empty plot remains an available server offer"
	)
	offers[1].ownerUserId = -1
	assert(service.getMainFarmOffers()[1].ownerUserId == alice.UserId, "returned offers cannot mutate ownership")
	service.refreshPlayerWorld(alice)
	for id, ownedPlot in service.getAllOwned(alice) do
		assert(multi.rendered[ownedPlot] == records[id], "each physical farm must render its own record")
		assert(
			ownedPlot.attributes.MainFarmId == id and ownedPlot.attributes.OwnerUserId == alice.UserId,
			"replicated physical identity matches authoritative mapping"
		)
	end
	local copy = service.getAllOwned(alice)
	copy["2"] = nil
	assert(service.getMainFarmPlotId(alice, "2") == "1", "caller cannot mutate ownership through returned mapping")
	local charlie, dave = player(103), player(104)
	assert(service.assign(charlie), "last empty slot accepts another player")
	assert(service.assign(dave), "new arrival may park an inactive extra farm instead of being kicked")
	assert(
		service.getMainFarmPlotId(alice, "1") == nil and records["1"].stored == 123,
		"parking preserves logical progress"
	)
	assert(
		service.getPlot(alice) == multi.plots[1] and multi.pushes[alice] >= 1,
		"parking preserves active slot and updates owner summary"
	)
	assert(service.selectMainFarm(alice, "1"), "parked farm can activate even when every physical slot is occupied")
	assert(
		service.getPlot(alice) == multi.plots[1] and service.getMainFarmPlotId(alice, "2") == nil,
		"full-server activation swaps only caller's active slot"
	)
	assert(
		alice.attributes.ActiveMainFarmId == "1" and alice.attributes.ActivePlotId == "1",
		"activation publishes both logical and physical context"
	)
	assert(
		multi.profiles[alice].activeMainFarmId == "2",
		"plot service must leave data facade switching to backend transaction"
	)
	assert(not service.selectMainFarm(alice, "unknown"), "unowned logical farm cannot activate")
	multi.profiles[alice].activeMainFarmId = "1"
	assert(
		service.assign(player(105)) and service.assign(player(106)),
		"remaining inactive extras can park for active players"
	)
	assert(not service.assign(player(107)), "fully occupied active slots are never stolen")
	service.release(bob)
	assert(service.getMainFarmPlotId(alice, "2") == "2", "freed slot refills a saved parked farm")
	assert(service.getPlot(alice) == multi.plots[1], "refill never changes active farm")
	assert(multi.rendered[multi.plots[2]] == records["2"], "refilled slot renders preserved farm record")
	for index = 1, 4 do
		local record = records[tostring(index)]
		assert(
			record.stored == index * 123 and record.animals[1].uid == `farm-{index}-animal`,
			"parking, swapping and refilling cannot alter saved farm contents"
		)
	end
	print("PASS plot startup: MaxPlayers warning, map validation, existing capacity, overflow rejection, reassignment")
	print(
		"PASS main-farm plots: real service restoration, occupied target rejection, distinct views, parking, active-only swap, arrival reclaim and refill"
	)
end
