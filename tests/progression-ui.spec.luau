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
			permanentIncomeCap = 3,
			returnSeconds = 86400,
			perkOrder = { "income", "growth" },
			perks = {
				income = { maxLevel = 5, effects = { incomeBonus = 0.08 } },
				growth = { maxLevel = 5, effects = { growthExcess = 0.06 } },
			},
		},
	}
	local progression = {
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
		string.find(labels[3].Text, "ek gelir: +%0", 1, true),
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
	assert(not panel.window.isOpen(), "rebirth window closes when no longer ready")
	local maxed: any = { ready = true, allMax = true, progression = { run = 3, count = 40 } }
	panel.update(maxed)
	panel.window.open()
	assert(cards[3].frame.Visible, "all effects at maximum exposes prestige fallback")
	cards[3].action.Activated.fire()
	begin.Activated.fire()
	confirm.Activated.fire()
	assert(#submissions == 2 and submissions[2].perk == "prestige", "maxed account can explicitly choose prestige")
	print(
		"PASS progression UI: exact run/quote transport, one request per intention, timeout, effect choice, second confirmation, stale runs and prestige"
	)
end
