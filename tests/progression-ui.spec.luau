--!strict
return function(createController: any, createRebirthWindow: any)
	local function signal(): any
		local callbacks = {}
		return {
			Connect = function(_self: any, callback: any): any
				callbacks[callback] = true
				return {
					Disconnect = function()
						callbacks[callback] = nil
					end,
				}
			end,
			fire = function(...: any)
				for callback in callbacks do
					callback(...)
				end
			end,
		}
	end
	local function node(): any
		local properties = {}
		local changed = {}
		local object: any = {
			Activated = signal(),
			WaitForChild = function(self: any): any
				return self
			end,
			GetPropertyChangedSignal = function(_self: any, key: string): any
				if not changed[key] then
					changed[key] = signal()
				end
				return changed[key]
			end,
		}
		object.Parent = object
		return setmetatable(object, {
			__index = function(_self: any, key: string): any
				return properties[key]
			end,
			__newindex = function(_self: any, key: string, value: any)
				local previous = properties[key]
				properties[key] = value
				if previous ~= value and changed[key] then
					changed[key].fire()
				end
			end,
		})
	end
	local root = node()
	local engine = {
		GetService = function(): any
			return root
		end,
	}
	local state: any = { activeMainFarmId = "1", progression = { run = 9 } }
	local requests = {}
	local result = signal()
	local snapshots = 0
	local delays = {}
	local controller = createController(engine, {
		get = function(name: string): any
			if name == "PurchaseResult" then
				return { OnClientEvent = result }
			end
			return {
				FireServer = function(_self: any, ...: any)
					table.insert(requests, { name = name, arguments = { ... } })
				end,
			}
		end,
	}, {
		get = function(): any
			return state
		end,
		requestSnapshot = function()
			snapshots += 1
		end,
	}, { play = function() end }, {
		new = function(): any
			local event = signal()
			return {
				Event = event,
				Fire = function(_self: any, ...: any)
					event.fire(...)
				end,
			}
		end,
	}, {
		clock = function(): number
			return 100
		end,
	}, {
		delay = function(seconds: number, callback: any)
			table.insert(delays, { seconds = seconds, callback = callback })
		end,
	})
	local detail = { amount = 3, expectedCash = 900, expectedRun = 42 }
	assert(controller.submitWithRun("RequestGoldAction", "convert", detail), "first intention is submitted")
	assert(requests[1].arguments[4].expectedRun == 9, "caller cannot inject another run")
	assert(detail.expectedRun == 42, "controller clones caller payload")
	assert(requests[1].arguments[4].expectedCash == 900, "exact quote survives controller transport")
	assert(not controller.submitWithRun("RequestGoldAction", "convert", detail), "pending request blocks double click")
	assert(#requests == 1, "double click sends one request")
	delays[1].callback()
	assert(snapshots == 1 and not controller.isPending(), "timeout requests fresh state without repeating a purchase")
	state.progression = nil
	assert(not controller.submitWithRun("RequestRebirth", "income"), "missing run context cannot submit")

	local buttons = {}
	local cards = {}
	local labels = {}
	local dimensions = { new = function() end, fromScale = function() end }
	local uiKit: any = {
		Color = {},
		TouchTarget = 44,
		list = function() end,
		tabs = function(): any
			return node(), function() end
		end,
		autoGrid = function(): any
			return node()
		end,
		text = function(_parent: any, text: string): any
			local label = node()
			label.Text = text
			table.insert(labels, label)
			return label
		end,
		setText = function(target: any, text: string)
			target.Text = text
		end,
		setVariant = function(target: any, variant: string)
			target.Active = variant ~= "disabled" and variant ~= "owned"
		end,
	}
	uiKit.button = function(_parent: any, text: string, variant: string): any
		local button = node()
		button.Text = text
		uiKit.setVariant(button, variant)
		table.insert(buttons, button)
		return button
	end
	uiKit.autoTile = function(): any
		local card = { frame = node(), title = node(), detail = node(), action = uiKit.button(nil, "", "primary") }
		table.insert(cards, card)
		return card
	end
	uiKit.window = function(): any
		local frame = node()
		local opened = false
		return {
			frame = frame,
			list = node(),
			open = function()
				opened = true
				frame.Visible = true
			end,
			close = function()
				opened = false
				frame.Visible = false
			end,
			isOpen = function(): boolean
				return opened
			end,
		}
	end
	local submissions = {}
	local definition = {
		PROGRESSION = {
			maxRebirth = 30,
			permanentIncomeCap = 3,
			returnSeconds = 86400,
			perkOrder = { "income", "growth" },
			permanentOffers = {
				cheap = { itemId = "cheap_item", goldCost = 100 },
				mid = { itemId = "mid_item", goldCost = 300 },
				rich = { itemId = "rich_item", goldCost = 500 },
				owned = { itemId = "owned_item", goldCost = 50 },
				extra = { itemId = "extra_item", goldCost = 350 },
				unreachable = { itemId = "far_item", goldCost = 5000 },
			},
			perks = {
				income = { maxLevel = 5, effects = { incomeBonus = 0.08 } },
				growth = { maxLevel = 5, effects = { growthExcess = 0.06 } },
			},
		},
	}
	definition.ITEMS = {
		cheap_item = { displayName = "Cheap Item" },
		mid_item = { displayName = "Mid Item" },
		rich_item = { displayName = "Rich Item" },
		owned_item = { displayName = "Owned Item" },
		extra_item = { displayName = "Extra Item" },
		far_item = { displayName = "Far Item" },
		reward_item = { displayName = "Reward Item" },
	}
	local progression = {
		rebirthGoldReward = function(save: any): number
			return save.reward or 400
		end,
		getMilestone = function(level: number): any
			return if level > 0
				then {
					displayName = `Milestone {level}`,
					description = `Reward {level}`,
					itemId = if level == 2 then "reward_item" else nil,
				}
				else nil
		end,
		getCompletionRequirements = function(): any
			return { description = "Meaningful farm requirements" }
		end,
		progress = function(save: any): any
			return { farmsComplete = if save.ready then 6 else 2, farmsTotal = 6 }
		end,
		getIncomeMultiplier = function(_save: any, itemMultiplier: number): number
			return math.min(3, itemMultiplier)
		end,
		canRebirth = function(save: any): boolean
			return save.ready
		end,
		canChoosePerk = function(save: any, id: string): boolean
			return if id == "prestige" then save.allMax == true else not save.allMax
		end,
		getPerkLevel = function(save: any, _id: string): number
			return if save.allMax then 5 else 0
		end,
	}
	local rebirth = createRebirthWindow(
		engine,
		definition,
		progression,
		uiKit,
		{
			submitWithRun = function(remote: string, perk: string)
				table.insert(submissions, { remote = remote, perk = perk })
			end,
		},
		{
			setPurchaseButton = function(button: any, text: string, variant: string)
				uiKit.setText(button, text)
				uiKit.setVariant(button, variant)
			end,
		},
		{ new = node },
		dimensions,
		dimensions,
		{ AutomaticSize = { Y = "Y" } },
		root,
		{
			getEquippedBonus = function(): number
				return 2
			end,
		},
		{
			create = function(): any
				return { update = function() end, reset = function() end }
			end,
		}
	)
	local panel = rebirth.create(root)
	local ready: any = { ready = true, progression = { run = 1, count = 0, runDouble = true } }
	panel.update(ready)
	panel.window.open()
	local begin = buttons[4]
	local confirm = buttons[5]
	begin.Activated.fire()
	confirm.Activated.fire()
	assert(#submissions == 0, "no effect selection cannot reset")
	cards[1].action.Activated.fire()
	assert(
		(function(): boolean
			for _, label in labels do
				if label.Name == "SelectedPerk" then
					return string.find(label.Text, "ek gelir: +%0", 1, true) ~= nil
				end
			end
			return false
		end)(),
		"income preview shows zero marginal gain when equipped items already reach the cap"
	)
	begin.Activated.fire()
	assert(#submissions == 0, "first confirmation only shows the review step")
	local switched: any = { ready = true, progression = { run = 2, count = 1, runDouble = false } }
	panel.update(switched)
	confirm.Activated.fire()
	assert(#submissions == 0, "changed run clears selection and confirmation")
	cards[2].action.Activated.fire()
	begin.Activated.fire()
	confirm.Activated.fire()
	assert(
		#submissions == 1 and submissions[1].perk == "growth",
		"selected effect plus explicit second confirmation submits once"
	)
	confirm.Activated.fire()
	assert(#submissions == 1, "repeated confirmation requires a fresh review")
	switched.ready = false
	panel.update(switched)
	assert(panel.window.isOpen(), "unfinished farms keep the journey available for inspection")
	assert(not begin.Active and not confirm.Active, "unfinished farms cannot submit a reset")
	local journeyCount = 0
	for _, label in labels do
		if label.Name and string.find(label.Name, "MilestoneTitleR", 1, true) then
			journeyCount += 1
		end
		if label.Name == "NextMilestone" then
			assert(string.find(label.Text, "Milestone 1", 1, true), "earned milestone is shown as latest reward")
		end
		if label.Name == "RebirthNextReward" then
			assert(string.find(label.Text, "R2", 1, true), "next reward follows current rebirth count")
			assert(string.find(label.Text, "Milestone 2", 1, true), "next milestone name is shown before confirming")
			assert(string.find(label.Text, "Reward Item", 1, true), "next milestone item is named")
		end
	end
	assert(journeyCount == 30, "all 30 earned milestones can be inspected")
	local function labelText(name: string): any
		for _, label in labels do
			if label.Name == name then
				return label
			end
		end
		error(`missing label {name}`)
	end
	-- Rebirth altın paneli: ödül yardımcıdan gelir, alınabilir liste sahip olunanları dışlar
	local owned: any = { items = { owned_item = true } }
	local offers = rebirth.affordableOffers({ owned = owned } :: any, 450)
	assert(#offers.affordable == 3, "affordable list is capped at three")
	assert(
		offers.affordable[1].itemId == "cheap_item"
			and offers.affordable[2].itemId == "mid_item"
			and offers.affordable[3].itemId == "extra_item",
		"cheapest unowned offers come first and owned items are excluded"
	)
	local none = rebirth.affordableOffers({ owned = owned } :: any, 40)
	assert(
		#none.affordable == 0 and none.nearest and none.nearest.itemId == "cheap_item",
		"nearest unowned offer shown when nothing is affordable"
	)
	panel.update({ ready = true, gold = 50, reward = 400, owned = owned, progression = { run = 40, count = 1 } } :: any)
	local gainReward = labelText("RebirthGoldReward").Text
	assert(string.find(gainReward, "+400", 1, true), "gold reward comes from Progression.rebirthGoldReward")
	local gainList = labelText("RebirthAffordable").Text
	assert(
		string.find(gainList, "Cheap Item", 1, true)
			and string.find(gainList, "Mid Item", 1, true)
			and not string.find(gainList, "Owned Item", 1, true)
			and not string.find(gainList, "Far Item", 1, true),
		"panel lists affordable unowned items only"
	)
	panel.update({ ready = false, gold = 0, reward = 20, owned = owned, progression = { run = 41, count = 1 } } :: any)
	local missingText = labelText("RebirthAffordable").Text
	assert(
		string.find(missingText, "Cheap Item", 1, true) and string.find(missingText, "80 altın eksik", 1, true),
		"nothing affordable shows the cheapest item and the missing gold"
	)
	local maxed: any = { ready = false, allMax = true, progression = { run = 31, count = 30 } }
	panel.update(maxed)
	assert(panel.window.isOpen(), "R30 journey remains available after completion")
	assert(not begin.Visible and not confirm.Active, "R30 hides further reset and disables confirmation")
	for _, label in labels do
		if label.Name == "RebirthRequirements" then
			assert(string.find(label.Text, "yeni sıfırlama yok", 1, true), "R30 explains the journey has ended")
		end
		if label.Name == "NextMilestone" then
			assert(string.find(label.Text, "Milestone 30", 1, true), "final milestone replaces unavailable R31 reward")
		end
		if label.Name == "RebirthGoldReward" then
			assert(
				string.find(label.Text, "Milestone", 1, true) == nil,
				"R30 shows no next milestone in the gold reward line"
			)
		end
	end
	confirm.Activated.fire()
	assert(#submissions == 1, "completed journey never sends another reset")
	print(
		"PASS progression UI: exact run/quote transport, confirmation, stale runs, 30 milestone journey and R30 terminal state"
	)
end
