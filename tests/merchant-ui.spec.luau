--!strict
return function(createMerchant: any, merchant: any, config: any, farmMath: any)
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
		local changed, attributes = {}, {}
		local object: any = { Activated = signal() }
		function object:WaitForChild(): any
			return self
		end
		function object:GetPropertyChangedSignal(key: string): any
			changed[key] = changed[key] or signal()
			return changed[key]
		end
		function object:GetAttribute(key: string): any
			return attributes[key]
		end
		function object:SetAttribute(key: string, value: any)
			attributes[key] = value
		end
		return object
	end
	local now = 1760000010
	local root = node()
	root.LocalPlayer = { UserId = 777 }
	root.GetServerTimeNow = function(): number
		return now
	end
	local engine = {
		GetService = function(): any
			return root
		end,
	}
	local cards, labels, buttons, disclosures, requests, travels, previews = {}, {}, {}, {}, {}, {}, {}
	local ui: any = { Color = {}, TouchTarget = 44, list = function() end, autoGrid = node }
	ui.setText = function(target: any, text: string)
		target.Text = text
	end
	ui.text = function(parent: any, text: string): any
		local label = node()
		label.Parent = parent
		label.Text = text
		table.insert(labels, label)
		return label
	end
	local empty: any
	ui.emptyState = function(parent: any, _icon: string, title: string, description: string): any
		empty = { frame = node(), title = ui.text(parent, title), description = ui.text(parent, description) }
		return empty
	end
	ui.button = function(parent: any, text: string): any
		local button = node()
		button.Parent = parent
		button.Text = text
		table.insert(buttons, button)
		return button
	end
	ui.autoTile = function(): any
		local card = { frame = node(), title = node(), detail = node(), icon = node(), action = ui.button(nil, "") }
		table.insert(cards, card)
		return card
	end
	ui.disclosure = function(parent: any): any
		local expanded = false
		local body = node()
		local disclosure = {
			body = body,
			isExpanded = function(): boolean
				return expanded
			end,
			setExpanded = function(value: boolean)
				local changed = value ~= expanded
				expanded = value
				body.Visible = value
				if changed then
					body:GetPropertyChangedSignal("Visible").fire()
				end
			end,
		}
		disclosures[parent] = disclosure
		return disclosure
	end
	ui.window = function(): any
		local window = { frame = node(), list = node() }
		window.isOpen = function(): boolean
			return window.frame.Visible == true
		end
		return window
	end
	local dimensions = { new = function() end, fromScale = function() end }
	local function build(cfg: any): any
		return createMerchant(
			engine,
			cfg,
			merchant,
			farmMath,
			{
				get = function(): any
					return {
						FireServer = function(_self: any, destination: string)
							table.insert(travels, destination)
						end,
					}
				end,
			},
			ui,
			{
				submit = function(remote: string, itemId: string, quote: any)
					table.insert(requests, { remote = remote, itemId = itemId, quote = quote })
				end,
			},
			{
				setPurchaseButton = function(button: any, text: string, variant: string)
					button.Text = text
					button.variant = variant
					button.Active = variant == "primary"
				end,
			},
			{
				mount = function(_parent: any, itemId: string)
					table.insert(previews, itemId)
				end,
			},
			{
				describe = function(): string
					return "Üretim süresi: -%15\nÜrün merkezi verimi: -%5"
				end,
				additional = function(): string
					return "Ürün merkezi verimi: -%5"
				end,
				slotNotice = function(): string
					return "Yuva: Asa · Takılı eşyanın yerine geçer."
				end,
				channelNotice = function(): string
					return "Nakitle bu tur, altın veya Robux ile kalıcı"
				end,
			},
			dimensions,
			dimensions
		)
	end
	local source = build(config)
	local panel = source.create(root)
	local cashCount, hidden: string? = 0, nil
	for _, itemId in config.ITEM_ORDER do
		if config.isCashItem(config.ITEMS[itemId]) then
			cashCount += 1
			hidden = hidden or itemId
		end
	end
	assert(#cards == cashCount, "merchant window builds one card per cash item only")
	local state: any = {
		cash = 1e12,
		activeMainFarmId = "1",
		progression = { run = 1 },
		inventory = { items = {}, equipped = {} },
		adminForce = { merchantUntil = now + 100 },
	}
	panel.update(state)
	assert(#previews == 0, "closed merchant window does not mount item previews")
	panel.window.frame.Visible = true
	panel.update(state)
	local offered = merchant.status(state, 777, now).offers
	local visible, first = 0, nil
	for _, card in cards do
		if card.frame.Visible then
			visible += 1
			first = first or card
		end
	end
	assert(
		visible == config.MERCHANT.stock and #previews == visible,
		"only finite offered stock gets previews and visible cards"
	)
	assert(
		first and string.find(first.detail.Text, "Normal:", 1, true),
		"actual normal price and discount remain visible"
	)
	local firstId = nil
	for _, offer in offered do
		local item = config.ITEMS[offer.itemId]
		if `{item.displayName} · Sv.{item.level or 1}` == first.title.Text then
			firstId = offer.itemId
		end
	end
	local detail = disclosures[first.frame]
	local penaltyVisible = false
	for _, label in labels do
		if label.Parent == detail.body and string.find(label.Text, "-%5", 1, true) then
			penaltyVisible = true
		end
	end
	assert(penaltyVisible, "financial review preserves the item's real downside")
	assert(not detail.isExpanded(), "merchant cards start compact")
	first.action.Activated.fire()
	assert(#requests == 0 and detail.isExpanded(), "first click reviews the slot and real penalty before any debit")
	first.action.Activated.fire()
	local quote = merchant.findOffer(state, 777, now, firstId)
	assert(
		#requests == 1
			and requests[1].remote == "RequestBuyMerchantOffer"
			and requests[1].itemId == firstId
			and requests[1].quote.cycle == quote.cycle
			and requests[1].quote.expectedPrice == quote.price,
		"second click submits exact displayed item/visit/price"
	)
	buttons[1].Activated.fire()
	assert(travels[1] == "hub", "travel action uses existing server-authoritative hub travel")
	state.progression.run = 2
	panel.update(state)
	assert(not detail.isExpanded(), "rebirth/run changes close stale financial review")
	state.merchant = { key = quote.cycle, bought = true }
	panel.update(state)
	for _, card in cards do
		assert(not card.frame.Visible, "one purchase exhausts this visit's catalogue")
	end
	assert(not buttons[1].Visible, "completed visit does not offer another purchase trip")
	assert(
		empty.frame.Visible and empty.title.Text == "Bu ziyaret tamamlandı",
		"completed visit gets a distinct readable state"
	)
	assert(not labels[1].Visible and not labels[2].Visible, "completed visit hides transaction instructions")
	state.merchant = nil
	for _, itemId in config.ITEM_ORDER do
		state.inventory.items[itemId] = true
	end
	panel.update(state)
	assert(
		empty.frame.Visible and empty.title.Text == "Tüm tüccar eşyalarına sahipsin",
		"fully owned catalogue is explained instead of left blank"
	)
	state.adminForce = nil
	while merchant.status(state, 777, now).visit do
		now += 60
	end
	panel.update(state)
	assert(empty.frame.Visible and empty.title.Text == "Tüccar yolda", "absent merchant has its own empty state")
	-- noCash eşya hiçbir koşulda tüccar kartı olmaz: ilk nakit eşyayı noCash sayan vekil Config ile bir pencere daha kur.
	local proxy = setmetatable({
		isCashItem = function(item: any): boolean
			return item.id ~= hidden and config.isCashItem(item)
		end,
	}, { __index = config })
	local cardsBeforeProxy = #cards
	build(proxy).create(root)
	assert(
		#cards - cardsBeforeProxy == cashCount - 1,
		"an item that stops being a cash item never gets a merchant card"
	)
	print(
		"PASS merchant UI: finite live catalog, lazy previews, explicit review, exact quote, travel and exhausted visit"
	)
end
