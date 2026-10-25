--!strict
-- Hayvan Pazarı kartı: kartta doğrudan "Sat" düğmesi, FarmMath.getSellBlockReason metni, takas kartı yok.
-- Gerçek ShopWindow + gerçek Config/FarmMath; UiKit ve istemci çekirdeği sahte.
return function(createShop: any, config: any, codec: any, farmMath: any)
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
	local created: { any } = {}
	local function node(): any
		local object: any = { Activated = signal(), Visible = true, Active = true, Text = "" }
		object.GetPropertyChangedSignal = function(): any
			return signal()
		end
		table.insert(created, object)
		return object
	end

	local cards: { [string]: any } = {}
	local sellers: { [string]: any } = {}
	local cardCount = 0
	local disclosures: { [any]: any } = {}
	local ui: any = {
		Color = { Green = "green", TextMuted = "muted" },
		TextSize = { Button = 16 },
		TouchTarget = 44,
		list = function() end,
		padding = function() end,
		colorText = function(text: string): string
			return text
		end,
	}
	ui.window = function(): any
		return {
			list = node(),
			frame = node(),
			isOpen = function(): boolean
				return false
			end,
		}
	end
	ui.autoGrid = node
	ui.actionRow = node
	ui.text = function(parent: any, text: string): any
		local label = node()
		label.Parent = parent
		label.Text = text
		return label
	end
	ui.setText = function(target: any, text: string)
		target.Text = text
	end
	ui.setVariant = function(target: any, variant: string)
		target.variant = variant
		target.Active = variant ~= "disabled" and variant ~= "owned"
	end
	ui.button = function(parent: any, text: string, variant: string): any
		local button = node()
		button.Parent = parent
		button.Text = text
		ui.setVariant(button, variant)
		return button
	end
	ui.actionButton = function(parent: any, _order: number, text: string, variant: string): any
		return ui.button(parent, text, variant)
	end
	ui.disclosure = function(parent: any): any
		local expanded = false
		local body = node()
		body.Parent = parent
		body.Visible = false
		local result = {
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
	ui.setCardStatus = function(card: any, text: string?)
		card.status.Text = text or ""
		card.status.Visible = text ~= nil
	end
	ui.autoTile = function(_grid: any, index: number): any
		cardCount += 1
		local animalId = config.ANIMAL_ORDER[index]
		local card: any = { frame = node(), icon = node(), title = node(), detail = node(), status = node() }
		card.action = ui.button(card.frame, "", "primary")
		cards[animalId] = card
		return card
	end

	local save = assert(codec.decode(nil, config, farmMath, 1700000000, function()
		return "qa"
	end))
	local activeSave: any = save
	local requests: { any } = {}
	local controller = {
		isPending = function(): boolean
			return false
		end,
		submit = function(remote: string, ...: any)
			table.insert(requests, { remote = remote, args = { ... } })
			return true
		end,
	}
	local common = {
		setPurchaseButton = function(button: any, text: string, variant: string)
			button.Text = text
			ui.setVariant(button, variant)
		end,
	}
	local dimension = {
		new = function(): any
			return {}
		end,
	}
	local shop = createShop(
		{
			GetService = function(): any
				return {
					WaitForChild = function(self: any): any
						return self
					end,
				}
			end,
		},
		config,
		farmMath,
		{
			getIncomeMultiplier = function(): number
				return 1
			end,
		},
		{
			get = function(): any
				return activeSave
			end,
		},
		ui,
		controller,
		{
			get = function(): string
				return "home"
			end,
		},
		common,
		{ new = node },
		dimension,
		{
			new = function(): any
				return {}
			end,
		},
		{ AutomaticSize = { Y = "Y" } }
	)
	local panel = shop.create({}, {})
	assert(cardCount == #config.ANIMAL_ORDER, "one card per configured animal")

	-- Satış satırları kartın doğrudan çocuğudur (Ayrıntılar gövdesinin değil); ana düğme dışındaki kart düğmesi.
	local animalId = ""
	for _, id in config.ANIMAL_ORDER do
		if farmMath.hasUnlockedAnimalZone(save, id) then
			animalId = id
			break
		end
	end
	assert(animalId ~= "", "fresh save unlocks at least one animal zone")
	local card = cards[animalId]
	for _, object in created do
		if object.Parent == card.frame and object ~= card.action and object.variant ~= nil then
			sellers[animalId] = object
		end
	end
	local seller = assert(sellers[animalId], "sell button exists on the card itself")
	local zoneId = assert(farmMath.findZoneForAnimal(save, animalId), "animal has a free zone")

	local function animal(uid: string, task: any): any
		return { uid = uid, animalId = animalId, zoneId = zoneId, stage = "adult", bornAt = 0, task = task }
	end
	local function withAnimals(records: { any }): any
		local clone = table.clone(save)
		clone.animals = records
		activeSave = clone
		panel.update(clone, true)
		return clone
	end

	-- (1) Satılabilir hayvan: "Sat" + FarmMath iadesi, düğme açık, kartta görünür, Ayrıntılar kapalı.
	local sellable = withAnimals({ animal("a", nil), animal("b", nil) })
	local refund = farmMath.formatMoney(farmMath.getSellPrice(sellable, animalId))
	assert(
		string.find(seller.Text, "Sat", 1, true) and string.find(seller.Text, refund, 1, true),
		"sell button shows Sat and the FarmMath refund"
	)
	assert(seller.Active and seller.variant == "secondary", "sellable animal keeps an enabled sell button")
	assert(seller.Visible, "owned animal shows the sell button")
	assert(
		seller.Parent == card.frame and seller.Parent ~= disclosures[card.frame].body,
		"sell button sits on the card, not inside the collapsed details body"
	)
	assert(
		not disclosures[card.frame].isExpanded() and not disclosures[card.frame].body.Visible,
		"details stay collapsed"
	)

	-- (4a) Açık düğme tıklanınca RequestSellAnimal + hayvan kimliği gider.
	seller.Activated:fire()
	assert(
		#requests == 1 and requests[1].remote == "RequestSellAnimal" and requests[1].args[1] == animalId,
		"enabled sell button submits RequestSellAnimal with the animal id"
	)

	-- (2) Tek hayvan: neden metni, düğme kapalı, istek yok (4b).
	withAnimals({ animal("a", nil) })
	assert(
		seller.Text == "Son hayvan satılamaz" and not seller.Active and seller.variant == "disabled",
		"the only animal cannot be sold"
	)
	seller.Activated:fire()
	assert(#requests == 1, "disabled sell button submits nothing")

	-- (3) Görevdeki hayvanlar: "Hayvan görevde".
	local busy = { kind = "production", id = "x", startedAt = os.time(), endsAt = os.time() + 1000 }
	withAnimals({ animal("a", busy), animal("b", busy) })
	assert(
		seller.Text == "Hayvan görevde" and not seller.Active and seller.variant == "disabled",
		"animals in an active production task cannot be sold"
	)
	seller.Activated:fire()
	assert(#requests == 1, "task-blocked sell button submits nothing")

	-- Sahip olunmayan tür: satış düğmesi gizli.
	withAnimals({ animal("a", nil), animal("b", nil) })
	for _, id in config.ANIMAL_ORDER do
		if id ~= animalId and cards[id].frame.Visible then
			local other: any = nil
			for _, object in created do
				if object.Parent == cards[id].frame and object ~= cards[id].action and object.variant ~= nil then
					other = object
				end
			end
			assert(other and not other.Visible, "unowned species shows no sell button")
		end
	end

	-- (5) Eski büyük balık takası yok: metin ve istek.
	for _, object in created do
		if type(object.Text) == "string" then
			assert(not string.find(object.Text, "büyük balıkla", 1, true), "no replacement card text anywhere")
			assert(not string.find(object.Text, "Küçük balığı", 1, true), "no small-fish replacement title")
		end
	end
	for _, object in created do
		if object.Active and object.Activated then
			object.Activated:fire()
		end
	end
	for _, request in requests do
		assert(request.remote ~= "RequestReplaceFish", "no control submits RequestReplaceFish")
	end
	print("PASS shop window UI: card-level sell button, FarmMath block reasons, guarded submit and no fish replacement")
end
