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
			Destroying = signal(),
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
	local textWrites: { [any]: number } = {}
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
		textWrites[target] = (textWrites[target] or 0) + 1
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
	-- Config.getItemChannel / isCashItem ile aynı sözleşme (gerçek Config'i tests/config.spec.luau denetler)
	definition.isCashItem = function(item: any): boolean
		return not item.rewardOnly and not item.noCash and item.price > 0
	end
	definition.getItemChannel = function(itemId: string): string
		local item = definition.ITEMS[itemId]
		if not item then
			return "none"
		end
		if item.rewardOnly then
			return "reward"
		end
		local offer = definition.PROGRESSION.permanentOffers[itemId]
		local robux = offer ~= nil and (offer.robuxProductId or 0) ~= 0
		if item.noCash then
			return if robux then "goldRobux" elseif offer then "gold" else "none"
		end
		return if offer then "cashGold" else "cash"
	end
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
	local conversionQuotes = 0
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
			conversionQuotes += 1
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
	local store = createStore(
		engine,
		definition,
		remotes,
		mathModule,
		progression,
		ui,
		{
			mount = function(_icon: any, id: string)
				table.insert(previews, id)
			end,
		},
		{
			describe = function(): string
				return "Üretim hızı +%15"
			end,
			additional = function(): string
				return "Ürün merkezi verimi: -%5"
			end,
			slotNotice = function(): string
				return "Yuva: Asa · Takılı eşyanın yerine geçer."
			end,
			channelNotice = function(item: any): string
				return `[{definition.getItemChannel(item.id)}]`
			end,
		},
		controller,
		common,
		dimensions,
		{
			Changed = signal(),
			get = function(): (number, string)
				return 149, "ready"
			end,
		}
	)
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
	local collectorWrites = textWrites[collectorCard.detail] or 0
	staffGold.Activated.fire()
	assert(
		(textWrites[collectorCard.detail] or 0) == collectorWrites,
		"opening one review must not redraw unrelated catalogue cards"
	)
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
	assert(staffCard.action.Text == "İncele · 149 Robux", "Robux action shows platform price before review")
	staffCard.action.Activated.fire()
	assert(
		#prompts == 0 and disclosures[staffCard.frame].isExpanded(),
		"ready Robux alternative first reveals the same effect and penalty review"
	)
	assert(staffCard.action.Text == "Satın al · 149 Robux", "reviewed action keeps the platform price")
	staffCard.action.Activated.fire()
	assert(
		#prompts == 1 and prompts[1].kind == "product" and prompts[1].key == "permanent_artisan_staff",
		"reviewed Robux alternative requests the actual platform prompt"
	)
	local untouched = textWrites[collectorCard.detail] or 0
	for _ = 1, 100 do
		disclosures[staffCard.frame].setExpanded(false)
		disclosures[staffCard.frame].setExpanded(true)
	end
	assert((textWrites[collectorCard.detail] or 0) == untouched, "repeated review toggles never redraw other products")
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
	definition.ITEMS.foreman_mallet = {
		id = "foreman_mallet",
		slot = "staff",
		price = 0,
		noCash = true,
		level = 5,
		displayName = "Ustabaşı Çekici",
		icon = "staff",
	}
	definition.ITEMS.tycoon_crown = {
		id = "tycoon_crown",
		slot = "staff",
		price = 0,
		noCash = true,
		level = 5,
		displayName = "Patron Tacı",
		icon = "staff",
	}
	definition.ITEMS.apprentice_staff =
		{ id = "apprentice_staff", slot = "staff", price = 500, displayName = "Çırak Asası", icon = "staff" }
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
		channelNotice = function(item: any): string
			return `[{definition.getItemChannel(item.id)}]`
		end,
		itemsOfSlot = function(): any
			return {
				definition.ITEMS.artisan_staff,
				definition.ITEMS.apprentice_staff,
				definition.ITEMS.foreman_mallet,
				definition.ITEMS.tycoon_crown,
			}
		end,
	}
	local cardsBeforeShop = #cards
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
	assert(
		#cards == cardsBeforeShop + 2,
		"noCash items never get a card in the cash list (no dead button, no zero price)"
	)
	for index = cardsBeforeShop + 1, #cards do
		assert(
			not string.find(cards[index].action.Text, "$ 0", 1, true)
				and not string.find(cards[index].title.Text, "Ustabaşı", 1, true)
				and not string.find(cards[index].title.Text, "Patron", 1, true),
			"cash list shows neither noCash titles nor a zero cash price"
		)
	end
	local cashCard = cards[#cards - 1]
	local otherCashCard = cards[#cards]
	assert(
		not disclosures[cashCard.frame].isExpanded() and cashCard.action.Text == "İncele · $ 20000 · Bu tur",
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
			and string.find(fullCashDetail.Text, "Rebirth yapınca bu eşya silinir.", 1, true)
			and string.find(fullCashDetail.Text, "Takılı eşyanın yerine geçer.", 1, true)
			and string.find(fullCashDetail.Text, "[cashGold]", 1, true),
		"review preserves real penalty and slot replacement notice and names the sale channel"
	)
	assert(
		not string.find(fullCashDetail.Text, "Üretim süresi: -%15", 1, true),
		"details exclude the main benefit already visible on the card"
	)
	local otherWrites = textWrites[otherCashCard.detail] or 0
	cashCard.action.Activated.fire()
	assert((textWrites[otherCashCard.detail] or 0) == otherWrites, "cash item review refreshes only its own card")
	assert(
		#requests == beforeCash
			and disclosures[cashCard.frame].isExpanded()
			and cashCard.action.Text == "Satın al · $ 20000 · Bu tur",
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
	-- Kalıcı teklifler: yalnız altın (kimlik 0) tek altın düğmesi gösterir; altın+Robux ikisini de korur
	definition.PROGRESSION.permanentOffers.foreman_mallet =
		{ id = "foreman_mallet", kind = "item", itemId = "foreman_mallet", goldCost = 1500 }
	definition.PROGRESSION.permanentOffers.tycoon_crown =
		{ id = "tycoon_crown", kind = "item", itemId = "tycoon_crown", goldCost = 1200, robuxProductId = 555 }
	definition.PRODUCTS.products.permanent_foreman_mallet = {
		id = 0,
		effect = "permanentOffer",
		offerId = "foreman_mallet",
		displayName = "Ustabaşı Çekici",
		description = "Kalıcı",
		icon = "staff",
	}
	definition.PRODUCTS.products.permanent_tycoon_crown = {
		id = 555,
		effect = "permanentOffer",
		offerId = "tycoon_crown",
		displayName = "Patron Tacı",
		description = "Kalıcı",
		icon = "staff",
	}
	local priceLookups: { number } = {}
	local channelStore = createStore(
		engine,
		definition,
		remotes,
		mathModule,
		progression,
		ui,
		{ mount = function() end },
		itemText,
		controller,
		common,
		dimensions,
		{
			Changed = signal(),
			get = function(_kind: string, id: number): (number, string)
				table.insert(priceLookups, id)
				return 149, "ready"
			end,
		}
	)
	local channelBase = #cards
	local channelList = node()
	local updateChannel = channelStore.create(channelList, "permanent")
	local channelSave: any = {
		gold = 5000,
		owned = { items = {}, conveniences = {} },
		passes = {},
		progression = { count = 0, run = 1, convertedRunGold = 0 },
		production = {},
		animals = {},
	}
	updateChannel(channelSave)
	local malletCard, crownCard, malletOrder, crownOrder = nil, nil, 0, 0
	for index = channelBase + 1, #cards do
		local card = cards[index]
		if card.frame.Name == "permanent_foreman_mallet" then
			malletCard, malletOrder = card, index
		elseif card.frame.Name == "permanent_tycoon_crown" then
			crownCard, crownOrder = card, index
		end
	end
	assert(malletCard and crownCard, "gold-only and gold+Robux offers are both listed on the permanent tab")
	assert(crownOrder < malletOrder, "within one catalogue level offers are ordered by gold cost")
	local function actionsOf(card: any): { any }
		local found = {}
		for _, button in buttons do
			if button.Parent == card.frame then
				table.insert(found, button)
			end
		end
		return found
	end
	local function noteOf(card: any): any
		for _, label in labels do
			if
				label.Parent == disclosures[card.frame].body
				and label.Text == "Altın biriktirmeden hemen almak için Robux"
			then
				return label
			end
		end
		return nil
	end
	local malletButtons = actionsOf(malletCard)
	assert(
		#malletButtons == 1 and malletButtons[1].Text == "İncele · 1500 altın · Kalıcı",
		"gold-only offer exposes one exterior gold button"
	)
	assert(malletCard.action.Visible == false, "gold-only offer hides its Robux button")
	assert(noteOf(malletCard) == nil, "gold-only offer has no fast-Robux caption")
	assert(malletCard.action.Text == "", "gold-only offer has no Robux label text such as Robux ile al")
	assert(string.find(malletCard.detail.Text, "[gold]", 1, true), "gold-only card names its channel in the summary")
	for _, id in priceLookups do
		assert(id ~= 0, "closed product ids never trigger a price lookup")
	end
	assert(#priceLookups >= 1, "gold+Robux offer still asks the platform price")
	assert(
		crownCard.action.Visible ~= false and crownCard.action.Text == "İncele · 149 Robux",
		"gold+Robux offer keeps its Robux action with the platform price"
	)
	local crownNote = noteOf(crownCard)
	assert(crownNote and crownNote.Visible ~= false, "Robux is presented as the fast alternative for gold prices")
	assert(string.find(crownCard.detail.Text, "[goldRobux]", 1, true), "gold+Robux card names its channel")
	definition.PRODUCTS.products.permanent_tycoon_crown.id = 0
	updateChannel(channelSave)
	assert(
		crownCard.action.variant == "disabled" and crownCard.action.Text == "Robux · Yakında",
		"a closed Robux id disables the Robux action exactly like other closed products"
	)
	assert(crownNote.Visible == false, "closed Robux hides the fast-Robux caption")
	definition.PRODUCTS.products.permanent_tycoon_crown.id = 555
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
	local initialQuotes = conversionQuotes
	panel.open("gold")
	assert(conversionQuotes == initialQuotes, "gold catalogue does not calculate hidden conversion quotes")
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
	tabCallbacks[#tabCallbacks]("convert")
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
	local quotesBeforeSwitch = conversionQuotes
	tabCallbacks[#tabCallbacks]("permanent")
	inputs[1].Text = "2"
	assert(
		conversionQuotes == quotesBeforeSwitch,
		"switching away and hidden input changes do not calculate conversion quotes"
	)
	tabCallbacks[#tabCallbacks]("convert")
	assert(
		conversionQuotes == quotesBeforeSwitch + 1 and convert.Active,
		"returning to conversion computes a fresh current quote"
	)
	print(
		"PASS market UI: ID0 catalogue, no paid prompts, model reuse, gold purchase, permanent ownership parity and exact conversion quote"
	)
end
