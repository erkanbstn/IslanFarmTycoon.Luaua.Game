--!strict
return function(factory: any, config: any, codec: any, farmMath: any)
	local function signal(): any
		local callbacks = {}
		return {
			Connect = function(_self: any, callback: any)
				table.insert(callbacks, callback)
			end,
			fire = function()
				for _, callback in callbacks do
					callback()
				end
			end,
		}
	end
	local buttons = {}
	local save = assert(codec.decode(nil, config, farmMath, 1700000000, function()
		return "qa"
	end))
	local physical = "home"
	local globalWrites = 0
	local function node(): any
		return {
			Activated = signal(),
			Destroying = signal(),
			FindFirstChildOfClass = function()
				return nil
			end,
		}
	end
	local ui = {
		TextSize = { Tab = 16 },
		list = function() end,
		button = function(parent: any, label: string): any
			local button = node()
			button.Parent = parent
			button.label = label
			table.insert(buttons, button)
			return button
		end,
		setVariant = function(button: any, variant: string)
			button.variant = variant
		end,
		badge = function(button: any): any
			return function(count: number)
				button.badgeCount = count
			end
		end,
	}
	local gameMock = {
		GetService = function(): any
			return {
				WaitForChild = function(self: any): any
					return self
				end,
			}
		end,
	}
	local tabs = factory(
		gameMock,
		{
			get = function()
				return save
			end,
		},
		ui,
		{
			get = function()
				return physical
			end,
			setPreview = function()
				globalWrites += 1
			end,
		},
		{ new = node },
		{
			new = function()
				return {}
			end,
		},
		{ TextTruncate = { AtEnd = "AtEnd" } }
	)
	local windows = { { frame = node(), list = node() }, { frame = node(), list = node() } }
	local changes = { 0, 0 }
	local first = tabs.add(windows[1], function()
		changes[1] += 1
	end)
	local second = tabs.add(windows[2], function()
		changes[2] += 1
	end)
	tabs.update(save)
	local satellite = config.getTheme("1").satellites[1]
	local index = assert(table.find(config.FARM_ISLAND_ORDER, satellite))
	first.setBadges({ [satellite] = 2 })
	second.setBadges({ home = 1 })
	assert(
		buttons[index].badgeCount == 2 and buttons[index + #config.FARM_ISLAND_ORDER].badgeCount == 0,
		"each window's island badge is independent"
	)
	first.setBadges({})
	assert(buttons[index].badgeCount == 0, "completed action clears the island badge")
	buttons[index].Activated.fire()
	tabs.update(save)
	assert(first.get() == satellite and second.get() == "home", "click changes only its own window")
	assert(changes[1] == 1 and changes[2] == 0 and globalWrites == 0, "local tabs do not mutate world context")
	buttons[index].Activated.fire()
	assert(changes[1] == 1, "same tab does not redraw")
	physical = config.getTheme("1").satellites[2]
	tabs.update(save)
	assert(
		first.get() == satellite and second.get() == physical,
		"manual selection stays pinned while default follows physical island"
	)
	second.set(satellite)
	assert(first.get() == satellite and second.get() == satellite, "world prompt can locally focus its own window")
	first.set("not-an-island")
	assert(first.get() == satellite, "invalid local selection is ignored")
	local reborn = table.clone(save)
	reborn.progression = table.clone(save.progression)
	reborn.progression.run += 1
	save = reborn
	physical = "home"
	tabs.update(save)
	assert(first.get() == "home" and second.get() == "home", "rebirth clears pinned island context")
	first.set(satellite)
	local nextFarm = table.clone(save)
	nextFarm.activeMainFarmId = "2"
	save = nextFarm
	tabs.update(save)
	assert(first.get() == "home", "farm switch clears previous theme preview")
	windows[1].frame.Destroying.fire()
	local calls = 0
	ui.setVariant = function()
		calls += 1
	end
	tabs.update(save)
	assert(calls == #config.FARM_ISLAND_ORDER, "destroyed windows are removed from shared refresh registry")
	print("PASS island tabs: independent windows, no global writes, world focus, farm/rebirth reset and cleanup")
end
