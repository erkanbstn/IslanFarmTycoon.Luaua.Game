--!strict
return function(createStats: any, createGoal: any)
	local objects, disclosures = {}, {}
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
	local function node(): any
		local object = {
			Changed = signal(),
			Activated = signal(),
			GetPropertyChangedSignal = function(): any
				return signal()
			end,
			WaitForChild = function(self: any): any
				return self
			end,
		}
		table.insert(objects, object)
		return object
	end
	local dimensions = {
		new = function(xs: number, xo: number, ys: number, yo: number): any
			return { X = { Scale = xs, Offset = xo }, Y = { Scale = ys, Offset = yo } }
		end,
		fromOffset = function(x: number, y: number): any
			return { X = { Scale = 0, Offset = x }, Y = { Scale = 0, Offset = y } }
		end,
		fromScale = function(x: number, y: number): any
			return { X = { Scale = x, Offset = 0 }, Y = { Scale = y, Offset = 0 } }
		end,
	}
	local ui: any = {
		Color = {},
		Font = {},
		Radius = {},
		TextSize = { Heading = 22 },
		TouchTarget = 44,
		panel = function(parent: any): any
			local frame = node()
			frame.Parent = parent
			return frame
		end,
		padding = function() end,
		list = function() end,
		corner = function() end,
		stroke = node,
		text = function(parent: any, text: string): any
			local label = node()
			label.Parent = parent
			label.Text = text
			return label
		end,
		setText = function(label: any, text: string)
			label.Text = text
		end,
		button = function(parent: any, text: string): any
			local button = node()
			button.Parent = parent
			button.Text = text
			return button
		end,
		iconChip = function(parent: any, text: string, size: number): any
			local chip = node()
			chip.Parent = parent
			chip.Text = text
			chip.Size = dimensions.fromOffset(size, size)
			return chip
		end,
		progressBar = function(): any
			return node(), function() end
		end,
		disclosure = function(parent: any): any
			local disclosure = { frame = node(), body = node(), parent = parent }
			disclosure.frame.Parent = parent
			table.insert(disclosures, disclosure)
			return disclosure
		end,
	}
	local player = {
		GetAttribute = function(_self: any, key: string): any
			return if key == "DataStatus" then "Active" else nil
		end,
	}
	local service = node()
	service.GetServerTimeNow = function(): number
		return 100
	end
	service.LocalPlayer = player
	local gameMock = {
		GetService = function(): any
			return service
		end,
	}
	local enumeration = {
		AutomaticSize = { Y = "Y", None = "None" },
		TextTruncate = { AtEnd = "AtEnd" },
		TextYAlignment = { Center = "Center" },
		TextXAlignment = { Right = "Right", Left = "Left" },
	}
	local vectors = {
		new = function(): any
			return {}
		end,
	}
	local context = {
		name = function(): string
			return "Ana Ada"
		end,
		get = function(): string
			return "home"
		end,
	}
	local stats = createStats(gameMock, ui, context, { new = node }, dimensions, vectors, enumeration).create(node())
	local goldButton, goldIcon, goldAmount, rebirthLevel, barnIcon: any = nil, nil, nil, nil, nil
	for _, object in objects do
		if object.Name == "BarnIcon" then
			barnIcon = object
		end
		if object.Name == "GoldWallet" then
			goldButton = object
		end
		if object.Name == "GoldIcon" then
			goldIcon = object
		end
		if object.Name == "GoldAmount" then
			goldAmount = object
		end
		if object.Name == "RebirthLevel" then
			rebirthLevel = object
		end
	end
	assert(
		goldButton and goldIcon and goldAmount and rebirthLevel,
		"gold is a structured icon, amount and rebirth badge"
	)
	assert(
		goldIcon.Parent == goldButton and goldAmount.Parent == goldButton and rebirthLevel.Parent == goldButton,
		"badge children share the full-width click target"
	)
	assert(
		goldButton.Text == "" and goldButton.Size.X.Scale == 1 and goldButton.Size.Y.Offset >= ui.TouchTarget,
		"wallet children own the labels and share a full touch target"
	)
	stats.update({
		cash = 0,
		gold = 1530,
		progression = { count = 30 },
		stored = 0,
		barnLevel = 1,
		purchased = {},
		animals = {},
		unlockedZones = {},
		unlockedIslands = { home = true },
	}, 0)
	assert(
		goldAmount.Text == "Altın: 1530" and rebirthLevel.Text == "Rebirth: 30",
		"wallet names both currencies clearly instead of presenting ambiguous zero and R0"
	)
	assert(barnIcon and barnIcon.Text == "🛖", "starter barn is modest rather than ruined")
	local seenIcons = { [barnIcon.Text] = true }
	for level = 2, 4 do
		stats.update({
			cash = 0,
			gold = 0,
			stored = 0,
			barnLevel = level,
			purchased = {},
			animals = {},
			unlockedZones = {},
			unlockedIslands = { home = true },
		}, 0)
		assert(not seenIcons[barnIcon.Text], "each barn upgrade has a different HUD icon")
		seenIcons[barnIcon.Text] = true
	end
	stats.update({
		cash = 0,
		stored = 0,
		barnLevel = 1,
		purchased = {},
		animals = {},
		unlockedZones = {},
		unlockedIslands = { home = true },
	}, 0)
	assert(barnIcon.Text == "🛖", "farm reset restores starter barn icon")
	assert(
		goldAmount.Position.Y.Offset + goldAmount.Size.Y.Offset <= rebirthLevel.Position.Y.Offset,
		"gold amount and rebirth occupy separate non-overlapping rows"
	)
	local bannerTitle = ""
	local step = 1
	local goal = createGoal(gameMock, ui, { new = node }, dimensions, { AutomaticSize = { Y = "Y" } }, {
		purchaseHint = function()
			return ""
		end,
		upgradeAffordable = function()
			return false
		end,
	}, {
		get = function()
			return "home"
		end,
	}, {
		stepFor = function()
			return step
		end,
	}).create(stats.frame, {
		apply = function()
			return step
		end,
	}, {
		show = function(title)
			bannerTitle = title
		end,
		hide = function()
			assert(step == 0, "Fresh player banner must remain visible")
		end,
	})
	goal.updateGoal({
		cash = 75,
		stored = 0,
		barnLevel = 1,
		activeMainFarmId = "1",
		purchased = {},
		animals = {},
		unlockedZones = {},
		unlockedIslands = { home = true },
		expansions = {},
		lineage = {},
		production = {},
		inventory = { items = {}, equipped = {}, uses = {} },
		progression = { count = 0 },
	}, 0)
	assert(not goal.card.Visible and bannerTitle == "İLK ADIMLAR 1/4", "fresh goal updates the onboarding banner")
	step = 0
	local complete: any = {
		activeMainFarmId = "1",
		cash = 1e12,
		production = {},
		goods = {},
		purchased = {},
		animals = {},
		inventory = { items = {}, equipped = {}, uses = {} },
		progression = { count = 29 },
		progressionStatus = { canRebirth = true, farmsComplete = 6, farmsTotal = 6 },
	}
	goal.updateGoal(complete, 0)
	local function hasGoalText(text: string): boolean
		for _, object in objects do
			if object.Parent == goal.card and object.Text == text then
				return true
			end
		end
		return false
	end
	assert(
		goal.card.Visible and hasGoalText("REBIRTH HAZIR"),
		"rebirth ready takes priority over unbought optional expansions"
	)
	complete.progression.count = 30
	complete.progressionStatus.canRebirth = false
	goal.updateGoal(complete, 0)
	assert(hasGoalText("YOLCULUK TAMAMLANDI"), "terminal completed run never suggests another rebirth or optional goal")
	assert(goal.card.Parent == stats.frame and #disclosures == 2, "goal and island cards retain their HUD context")
	local islandDisclosure = disclosures[1]
	assert(
		islandDisclosure.parent.Parent == stats.frame and islandDisclosure.parent.Size.X.Scale == 1,
		"island details use the whole card width"
	)
	assert(
		islandDisclosure.parent.AutomaticSize == "Y",
		"expanding island details increases card height rather than overflowing a fixed header"
	)
	print("PASS HUD layout: icon gold wallet, full touch target, live values and full-width island details")
end
