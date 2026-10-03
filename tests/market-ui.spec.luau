--!strict
return function(createStore: any, createMarket: any, createItemShop: any)
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
	local disclosures = {}
	local labels = {}
	local icons = {}
	ui.iconChip = function(parent: any, icon: string): any
		local object = node()
		object.Parent = parent
		object.Text = icon
		table.insert(icons, object)
		return object
	end
	ui.disclosure = function(parent: any): any
		local expanded = false
		local body = node()
		body.Visible = false
		local result = {
			frame = node(),
			body = body,
			isExpanded = function(): boolean
				return expanded
			end,
			setExpanded = function(value: boolean)
				expanded = value
				body.Visible = value
			end,
		}
		disclosures[parent] = result
		return result
	end
	ui.setText = function(target: any, text: string)
		target.Text = text
	end
	ui.setVariant = function(target: any, variant: string)
		target.variant = variant
		target.Active = variant ~= "owned" and variant ~= "disabled"
	end
	ui.text = function(parent: any, text: string): any
		local object = node()
		object.Parent = parent
		object.Text = text
		table.insert(labels, object)
		return object
	end
	ui.button = function(parent: any, text: string, variant: string): any
		local object = node()
		object.Parent = parent
		object.Text = text
		ui.setVariant(object, variant)
		table.insert(buttons, object)
		return object
	end
	ui.autoTile = function(): any
		local card = { frame = node(), icon = node(), title = node(), detail = node() } :: any
		card.action = ui.button(card.frame, "", "primary")
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
		ITEMS = {
			artisan_staff = {
				id = "artisan_staff",
				slot = "staff",
				price = 20000,
				displayName = "Zanaat Asası",
				icon = "staff",
			},
		},
		ITEM_SLOT_ORDER = { "staff" },
		ITEM_SLOTS = { staff = { displayName = "Asa", icon = "staff" } },
		PRODUCT_MIN_INCOME_PACK = 500,
		PRODUCTS = {
			passes = {
				auto_collector = {
					id = 0,
					effect = "autoCollect",
					displayName = "Toplayıcı",
					description = "Para kendiliğinden kasana gelir",
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
					description = "Para kendiliğinden kasana gelir",
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
			milestones = {},
			permanentOffers = {
				artisan_staff = { id = "artisan_staff", kind = "item", itemId = "artisan_staff", goldCost = 350 },
				auto_collect = { id = "auto_collect", kind = "convenience", goldCost = 300 },
			},
			gold = { island = 20, farm = 50, dailyLimit = 200, runLimit = 600 },
			perkOrder = {},
		},
	}
	local requests = {}
	local prompts = {}
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
				FireServer = function(_self: any, kind: string, key: string)
					table.insert(prompts, { kind = kind, key = key })
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
		additional = function(): string
			return "Ürün merkezi verimi: -%5"
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
	assert(
		collectorCard.detail.Text == "Para kendiliğinden kasana gelir",
		"permanent upgrades explain their benefit instead of gamepass jargon"
	)
	local collectorDetail: any = nil
	for _, label in labels do
		if label.Parent == disclosures[collectorCard.frame].body then
			collectorDetail = label
		end
	end
	assert(
		collectorDetail and collectorDetail.Text ~= collectorCard.detail.Text,
		"upgrade details add persistence information instead of repeating the summary"
	)
	for _, button in buttons do
		if button.Text == "İncele · 350 altın · Kalıcı" then
			staffGold = button
		end
	end
	assert(
		staffCard and staffGold and #previews == 1,
		"existing model is mounted and gold route is available without Robux ID"
	)
	assert(
		staffGold.Parent == staffCard.frame and staffCard.action.Parent == disclosures[staffCard.frame].body,
		"gold offer has one exterior CTA; the alternative Robux action belongs inside details"
	)
	assert(collectorCard.action.Parent == collectorCard.frame, "pass without a gold offer keeps its exterior CTA")
	staffCard.action.Activated.fire()
	assert(#requests == 0 and #prompts == 0, "disabled Robux action never sends a paid request")
	assert(
		not disclosures[staffCard.frame].isExpanded() and staffGold.Text == "İncele · 350 altın · Kalıcı",
		"product starts with an explicit review action"
	)
	staffGold.Activated.fire()
	assert(
		#requests == 0
			and disclosures[staffCard.frame].isExpanded()
			and staffGold.Text == "Satın al · 350 altın · Kalıcı",
		"first purchase intention exposes full effects and slot cost without debiting"
	)
	staffGold.Activated.fire()
	assert(
		#requests == 1 and requests[1].detail.offerId == "artisan_staff",
		"gold action uses canonical offer identifier"
	)
	save.progression.run = 2
	update(save)
	assert(not disclosures[staffCard.frame].isExpanded(), "changing run collapses an old financial review")
	definition.PRODUCTS.products.permanent_artisan_staff.id = 123
	update(save)
	staffCard.action.Activated.fire()
	assert(
		#prompts == 0 and disclosures[staffCard.frame].isExpanded(),
		"ready Robux alternative first reveals the same effect and penalty review"
	)
	staffCard.action.Activated.fire()
	assert(
		#prompts == 1 and prompts[1].kind == "product" and prompts[1].key == "permanent_artisan_staff",
		"reviewed Robux alternative requests the actual platform prompt"
	)
	definition.PRODUCTS.products.permanent_artisan_staff.id = 0
	save.owned.items.artisan_staff = true
	save.owned.conveniences.auto_collect = true
	update(save)
	assert(
		staffCard.action.variant == "owned" and staffGold.variant == "owned",
		"permanent ownership disables both currencies with one exterior owned label"
	)
	assert(
		collectorCard.action.variant == "owned",
		"permanent gold collector also owns equivalent gamepass functionality"
	)
	local itemText = {
		describe = function(): string
			return "Üretim süresi: -%15\nÜrün merkezi verimi: -%5"
		end,
		additional = function(): string
			return "Ürün merkezi verimi: -%5"
		end,
		slotNotice = function(): string
			return "Yuva: Asa · Takılı eşyanın yerine geçer."
		end,
		itemsOfSlot = function(): any
			return { definition.ITEMS.artisan_staff }
		end,
	}
	local cashShop = createItemShop(
		engine,
		definition,
		mathModule,
		{
			owns = function(state: any, id: string): boolean
				return state.inventory.items[id] == true
			end,
		},
		ui,
		{
			submit = function(remote: string, id: string)
				table.insert(requests, { remote = remote, action = id })
			end,
		},
		common,
		itemText,
		{ mount = function() end },
		dimensions,
		dimensions
	)
	local cashPanel = cashShop.create(root)
	local cashState: any = {
		activeMainFarmId = "1",
		cash = 20000,
		progression = { run = 1 },
		owned = { items = {} },
		inventory = { items = {} },
	}
	cashPanel.update(cashState)
	local cashCard = cards[#cards]
	assert(
		not disclosures[cashCard.frame].isExpanded() and cashCard.action.Text == "İncele · $ 20000",
		"cash item starts with an explicit review action"
	)
	assert(
		not string.find(cashCard.detail.Text, "Ürün merkezi verimi", 1, true),
		"summary shows one benefit without dumping every effect"
	)
	local beforeCash = #requests
	local fullCashDetail: any = nil
	for _, label in labels do
		if label.Parent == disclosures[cashCard.frame].body then
			fullCashDetail = label
		end
	end
	assert(
		fullCashDetail
			and string.find(fullCashDetail.Text, "Ürün merkezi verimi: -%5", 1, true)
			and string.find(fullCashDetail.Text, "Takılı eşyanın yerine geçer.", 1, true),
		"review preserves real penalty and slot replacement notice"
	)
	assert(
		not string.find(fullCashDetail.Text, "Üretim süresi: -%15", 1, true),
		"details exclude the main benefit already visible on the card"
	)
	cashCard.action.Activated.fire()
	assert(
		#requests == beforeCash
			and disclosures[cashCard.frame].isExpanded()
			and cashCard.action.Text == "Satın al · $ 20000",
		"cash purchase first reveals penalty and slot replacement before payment"
	)
	cashCard.action.Activated.fire()
	assert(
		#requests == beforeCash + 1 and requests[#requests].remote == "RequestBuyItem",
		"cash purchase remains available after review"
	)
	cashState.progression.run = 2
	cashPanel.update(cashState)
	assert(not disclosures[cashCard.frame].isExpanded(), "cash review collapses after a new run")
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
	assert(#icons == 1 and icons[1].Text == "🪙", "market wallet renders a gold coin chip")
	local wallet: any = nil
	for _, label in labels do
		if label.Parent == icons[1].Parent then
			wallet = label
		end
	end
	assert(
		wallet and wallet.Text == `Altın: {save.gold} · Rebirth'te kalır`,
		"wallet amount and persistence text stay in the coin's shared row"
	)
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
	local beforeConversion = #requests
	convert.Activated.fire()
	assert(
		requests[beforeConversion + 1].action == "convert"
			and requests[beforeConversion + 1].detail.amount == 3
			and requests[beforeConversion + 1].detail.expectedCash == 90,
		"conversion submits exact displayed quote through run-aware controller"
	)
	inputs[1].Text = "1.5"
	assert(not convert.Active, "fractional gold cannot be submitted")
	print(
		"PASS market UI: ID0 catalogue, no paid prompts, model reuse, gold purchase, permanent ownership parity and exact conversion quote"
	)
end
