--!strict
return function(factory: any, config: any, codec: any, farmMath: any, createOnboarding: any, steps: any)
	local objects, grids, tiles = {}, {}, {}
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
	local function node(class: string?, parent: any?): any
		local result: any =
			{ ClassName = class, Parent = parent, Activated = signal(), GetPropertyChangedSignal = signal }
		result.IsA = function(self: any, kind: string): boolean
			return self.ClassName == kind
		end
		result.GetChildren = function(self: any): { any }
			local children = {}
			for _, object in objects do
				if object.Parent == self then
					table.insert(children, object)
				end
			end
			return children
		end
		table.insert(objects, result)
		return result
	end
	local ui: any = { Color = {}, Radius = {}, TouchTarget = 44 }
	ui.text = function(parent: any, text: string): any
		local n = node("TextLabel", parent)
		n.Text = text
		return n
	end
	ui.setText = function(label: any, text: string)
		label.Text = text
	end
	ui.list = function() end
	ui.button = function(parent: any): any
		return node("TextButton", parent)
	end
	ui.setVariant = function(button: any, variant: string)
		button.Active = variant ~= "disabled" and variant ~= "owned"
	end
	ui.setCardStatus = function() end
	ui.autoGrid = function(parent: any): any
		local grid = node("Frame", parent)
		table.insert(grids, grid)
		return grid
	end
	ui.autoTile = function(parent: any): any
		local tile = { frame = node("Frame", parent), title = node(), detail = node(), action = node() }
		table.insert(tiles, tile)
		return tile
	end
	ui.disclosure = function(parent: any): any
		return { frame = node("Frame", parent), body = node(), setExpanded = function() end }
	end
	ui.cardDetails = function(): any
		return { setExpanded = function() end }
	end
	ui.sectionHeader = function(parent: any): (any, any)
		return node("TextLabel", node("Frame", parent)), node()
	end
	local tabSelect: any = nil
	local tabs: any = nil
	ui.tabs = function(parent: any, _order: number, entries: any, callback: any): (any, any)
		tabs = node("Frame", parent)
		tabSelect = callback
		for index in entries do
			local button = node("TextButton", tabs)
			button.LayoutOrder = index
		end
		return tabs, function(id: string)
			tabs.selected = tonumber(id)
		end
	end
	ui.window = function(_parent: any, options: any): any
		assert(
			options.width == 600 and options.maxHeight == 560 and options.anchor.X == 0.5,
			"roadmap shares centered generous layout"
		)
		return {
			frame = node(),
			list = node(),
			isOpen = function()
				return true
			end,
		}
	end
	local island = "home"
	local gameMock = {
		GetService = function(): any
			return {
				WaitForChild = function(self: any): any
					return self
				end,
			}
		end,
	}
	local dims = {
		fromScale = function()
			return {}
		end,
		new = function()
			return {}
		end,
	}
	local vectors = {
		new = function(x: number, y: number): any
			return { X = x, Y = y }
		end,
		zero = {},
	}
	local common = {
		setPurchaseButton = function(button: any, text: string, variant: string)
			button.Text = text
			button.Active = variant == "primary"
		end,
		goodsNeedText = function()
			return nil
		end,
		upgradeVariant = function()
			return "primary"
		end,
	}
	local roadmap = factory(gameMock, ui, { new = node }, dims, vectors, common, {
		add = function()
			return {
				get = function()
					return island
				end,
				name = function()
					return island
				end,
				update = function() end,
			}
		end,
	}, {
		get = function()
			return island
		end,
		name = function()
			return island
		end,
		upgradeIsland = config.getUpgradeIsland,
	}, { submit = function() end }, {
		get = function()
			return { FireServer = function() end }
		end,
	}).create(node(), {})
	local save = assert(codec.decode(nil, config, farmMath, 1700000000, function()
		return "qa"
	end))
	for _, upgrade in config.UPGRADES do
		if upgrade.optionalForCompletion then
			local rendered = false
			for _, tile in tiles do
				if tile.title.Text == upgrade.displayName then
					rendered = true
					assert(tile.action.Activated, "optional garden retains roadmap purchase action")
				end
			end
			assert(rendered, "optional garden is rendered in actual roadmap factory")
		end
	end

	roadmap.update(save, true)
	local function visibleCount(): number
		local count = 0
		for _, grid in grids do
			if grid.Visible then
				count += 1
			end
		end
		return count
	end
	assert(visibleCount() == 1, "initial roadmap shows only one stage")
	local firstTitles = {}
	local firstStage = tabs.selected
	local function visibleCards(): number
		local count = 0
		for _, object in objects do
			if object.Parent == grids[firstStage] and object.Visible then
				count += 1
			end
		end
		return count
	end
	assert(visibleCards() <= 7, "dense stages display six upgrades plus the initial gift")
	local nextButton: any = nil
	for _, object in objects do
		if object.Name == "NextPage" then
			nextButton = object
		end
	end
	assert(nextButton and nextButton.Active, "dense initial stage has another page")
	for _, object in objects do
		if object.Parent == grids[firstStage] and object.Visible then
			firstTitles[object] = true
		end
	end
	nextButton.Activated.fire()
	assert(visibleCards() <= 6, "second page is bounded and excludes the initial gift")
	for card in firstTitles do
		assert(not card.Visible, "previous page cards are hidden")
	end

	local other: number? = nil
	for _, button in tabs:GetChildren() do
		if button.Visible and button.LayoutOrder ~= tabs.selected then
			other = button.LayoutOrder
			break
		end
	end
	assert(other, "home island has another reachable stage tab")
	tabSelect(tostring(other))
	assert(
		tabs.selected == other and grids[other].Visible and visibleCount() == 1,
		"stage selection refreshes and hides previous stage"
	)
	roadmap.update(save, false)
	assert(tabs.selected == other and visibleCount() == 1, "wallet updates preserve manual stage selection")
	island = config.getTheme("1").satellites[1]
	roadmap.update(save, true)
	assert(visibleCount() == 1, "island preview resets to one relevant stage")
	assert(not grids[other].Visible, "previous island stage cannot leak into new context")
	local attributes, highlights = {}, {}
	local player = {
		GetAttribute = function(_self: any, name: string): any
			return attributes[name]
		end,
		SetAttribute = function(_self: any, name: string, value: any)
			attributes[name] = value
		end,
	}
	local guidanceUi = {
		pulse = function(button: any): any
			return function(active: boolean)
				highlights[button] = active
			end
		end,
		pointer = function(button: any): any
			return function(active: boolean)
				highlights[`pointer:{button}`] = active
			end
		end,
	}
	local guidanceGame = {
		GetService = function(_self: any, name: string): any
			if name == "Players" then
				return { LocalPlayer = player }
			end
			return {
				WaitForChild = function(self: any): any
					return self
				end,
			}
		end,
	}
	local onboarding = createOnboarding(guidanceGame, guidanceUi, steps)
	local guide =
		onboarding.create({ shop = "shop", upgrades = "upgrades", roadmap = "roadmap", production = "production" })
	assert(
		guide.apply(save, false, nil) == 1 and highlights.shop and attributes.TutorialMarker == "market",
		"fresh tutorial guides to market"
	)
	onboarding.skip()
	assert(
		onboarding.stepFor(save) == 0 and attributes.TutorialMarker == "" and not attributes.TutorialGuide,
		"skip clears actual world guidance"
	)
	for _, active in highlights do
		assert(not active, "skip cancels every pulse and pointer")
	end
	print("PASS roadmap UI: centered layout, single-stage navigation, wallet stability and island context reset")
end
