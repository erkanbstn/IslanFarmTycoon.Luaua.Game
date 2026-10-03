--!strict
return function(createStore: any, createMarket: any)
	local function signal(): any
		local callbacks = {}
		return {
			Connect = function(_self: any, callback: any): any
				table.insert(callbacks, callback)
				return { Disconnect = function() end }
			end,
			fire = function(...: any)
				for _, callback in callbacks do
					callback(...)
				end
			end,
		}
	end
	local function node(): any
		local changed = {}
		local properties = {}
		return setmetatable({
			Activated = signal(),
			GetPropertyChangedSignal = function(_self: any, key: string): any
				changed[key] = changed[key] or signal()
				return changed[key]
			end,
			WaitForChild = function(self: any): any
				return self
			end,
		}, {
			__index = properties,
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
	root.LocalPlayer = {
		GetAttribute = function(): string
			return "Active"
		end,
	}
	root.GetServerTimeNow = function(): number
		return 1000
	end
	local buttons, cards, inputs, tabCallbacks = {}, {}, {}, {}
	local ui: any = { Color = {}, TouchTarget = 44, list = function() end, autoGrid = node }
	ui.setText = function(target: any, text: string)
		target.Text = text
	end
	ui.setVariant = function(target: any, variant: string)
		target.variant = variant
		target.Active = variant ~= "owned" and variant ~= "disabled"
	end
	ui.text = function(_parent: any, text: string): any
		local object = node()
		object.Text = text
		return object
	end
	ui.button = function(_parent: any, text: string, variant: string): any
		local object = node()
		object.Text = text
		ui.setVariant(object, variant)
		table.insert(buttons, object)
		return object
	end
	ui.autoTile = function(): any
		local card =
			{ frame = node(), icon = node(), title = node(), detail = node(), action = ui.button(nil, "", "primary") }
		table.insert(cards, card)
		return card
	end
	ui.card = ui.autoTile
	ui.textInput = function(): any
		local input = node()
		table.insert(inputs, input)
		return input
	end
	ui.tabs = function(_parent: any, _order: number, _entries: any, callback: any): any
		table.insert(tabCallbacks, callback)
		return node(), function() end
	end
	ui.window = function(): any
		local opened = false
		return {
			list = node(),
			frame = node(),
			isOpen = function(): boolean
				return opened
			end,
			open = function()
				opened = true
			end,
		}
	end
	ui.showWindow = function(window: any)
		window.open()
	end
	local dimensions = { new = function() end, fromScale = function() end }
	local definition: any = {
		ITEMS = { artisan_staff = { price = 20000, displayName = "Zanaat Asası", icon = "staff" } },
		PRODUCT_MIN_INCOME_PACK = 500,
		PRODUCTS = {
			passes = {
				auto_collector = {
					id = 0,
					effect = "autoCollect",
					displayName = "Toplayıcı",
					description = "Kalıcı",
					icon = "robot",
				},
			},
			products = {
				permanent_artisan_staff = {
					id = 0,
					effect = "permanentOffer",
					offerId = "artisan_staff",
					displayName = "Zanaat Asası",
					description = "Üretim",
					icon = "staff",
				},
				permanent_auto_collect = {
					id = 0,
					effect = "permanentOffer",
					offerId = "auto_collect",
					displayName = "Toplayıcı",
					description = "Kalıcı",
					icon = "robot",
				},
				gold_100 = {
					id = 0,
					effect = "goldPack",
					goldAmount = 100,
					displayName = "100 Altın",
					description = "Altın",
					icon = "gold",
				},
			},
		},
		PROGRESSION = {
			permanentOffers = {
				artisan_staff = { id = "artisan_staff", kind = "item", itemId = "artisan_staff", goldCost = 350 },
				auto_collect = { id = "auto_collect", kind = "convenience", goldCost = 300 },
			},
			gold = { island = 20, farm = 50, dailyLimit = 200, runLimit = 600 },
			perkOrder = {},
		},
	}
	local requests = {}
	local controller = {
		isPending = function(): boolean
			return false
		end,
		submitWithRun = function(remote: string, action: string, detail: any)
			table.insert(requests, { remote = remote, action = action, detail = detail })
		end,
	}
	local remotes = {
		get = function(): any
			return {
				FireServer = function()
					error("ID0 product must not prompt")
				end,
			}
		end,
	}
	local common = {
		setPurchaseButton = function(button: any, text: string, variant: string)
			ui.setText(button, text)
			ui.setVariant(button, variant)
		end,
	}
	local mathModule = {
		formatMoney = function(amount: number): string
			return `$ {amount}`
		end,
		getPermanentReferenceIncome = function(): number
			return 1
		end,
	}
	local progression = {
		canRebirth = function(): boolean
			return false
		end,
		getPerkLevel = function(): number
			return 0
		end,
		isReturnActive = function(): boolean
			return false
		end,
		finishGoldQuote = function(): any
			return nil
		end,
		goldCashQuote = function(save: any, amount: number): (number?, string?)
			if amount <= 0 or amount % 1 ~= 0 then
				return nil, "invalid_amount"
			end
			if amount > save.gold then
				return nil, "insufficient_gold"
			end
			return amount * 30, nil
		end,
	}
	local previews = {}
	local store = createStore(engine, definition, remotes, mathModule, progression, ui, {
		mount = function(_icon: any, id: string)
			table.insert(previews, id)
		end,
	}, {
		describe = function(): string
			return "Üretim hızı +%15"
		end,
		slotNotice = function(): string
			return "Yuva: Asa · Takılı eşyanın yerine geçer."
		end,
	}, controller, common, dimensions)
	local update = store.create(root, "permanent")
	local save: any = {
		gold = 400,
		owned = { items = {}, conveniences = {} },
		passes = {},
		progression = { count = 0, run = 1, convertedRunGold = 0 },
		production = {},
		animals = {},
	}
	update(save)
	local staffCard, staffGold, collectorCard = nil, nil, nil
	for _, card in cards do
		if card.frame.Name == "permanent_artisan_staff" then
			staffCard = card
		end
		if card.frame.Name == "auto_collector" then
			collectorCard = card
		end
		assert(card.action.variant == "disabled", "ID0 catalogue is visible but every Robux action is disabled")
	end
	for _, button in buttons do
		if button.Text == "350 altın · Kalıcı" then
			staffGold = button
		end
	end
	assert(
		staffCard and staffGold and #previews == 1,
		"existing model is mounted and gold route is available without Robux ID"
	)
	staffCard.action.Activated.fire()
	assert(#requests == 0, "disabled Robux action never sends a paid request")
	staffGold.Activated.fire()
	assert(
		#requests == 1 and requests[1].detail.offerId == "artisan_staff",
		"gold action uses canonical offer identifier"
	)
	save.owned.items.artisan_staff = true
	save.owned.conveniences.auto_collect = true
	update(save)
	assert(
		staffCard.action.variant == "owned" and staffGold.variant == "owned",
		"permanent ownership disables both currencies"
	)
	assert(
		collectorCard.action.variant == "owned",
		"permanent gold collector also owns equivalent gamepass functionality"
	)
	local market = createMarket(
		engine,
		definition,
		mathModule,
		progression,
		ui,
		controller,
		common,
		store,
		{ perkNames = {} },
		{ new = node },
		dimensions,
		dimensions,
		{ AutomaticSize = { Y = "Y" } }
	)
	local panel = market.create(root)
	panel.update(save)
	panel.open("gold")
	local goldCard: any = nil
	for _, card in cards do
		if card.frame.Name == "gold_100" then
			goldCard = card
		end
	end
	assert(
		goldCard and goldCard.detail.Text == "100 altın · Rebirth'te kalır",
		"gold category updates the advertised persistent currency"
	)
	tabCallbacks[1]("convert")
	inputs[1].Text = "3"
	local convert: any = nil
	for _, button in buttons do
		if button.Text == "3 altın → $ 90" then
			convert = button
		end
	end
	assert(convert and convert.Active, "converter quotes within the unified market")
	convert.Activated.fire()
	assert(
		requests[2].action == "convert" and requests[2].detail.amount == 3 and requests[2].detail.expectedCash == 90,
		"conversion submits exact displayed quote through run-aware controller"
	)
	inputs[1].Text = "1.5"
	assert(not convert.Active, "fractional gold cannot be submitted")
	print(
		"PASS market UI: ID0 catalogue, no paid prompts, model reuse, gold purchase, permanent ownership parity and exact conversion quote"
	)
end
