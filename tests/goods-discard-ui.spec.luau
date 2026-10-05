--!strict
-- Ürün silme onay paneli: gerçek kaynak, sahte UiKit. Onay şart, miktar sıkıştırılır, uyarı görünür, geçersizken onay kapalı,
-- ekipman/eşya kimlikleriyle panel hiç açılmaz.
return function(createPrompt: any, config: any, farmMath: any, goodsDiscard: any)
	local function signal(): any
		local listeners = {}
		return {
			Connect = function(_self: any, callback: any): any
				listeners[callback] = true
				return {
					Disconnect = function()
						listeners[callback] = nil
					end,
				}
			end,
			fire = function(...: any)
				for callback in listeners do
					callback(...)
				end
			end,
		}
	end
	local visible = signal()
	local opened = false
	local frame = {
		Parent = true,
		Destroying = signal(),
		GetPropertyChangedSignal = function(): any
			return visible
		end,
	}
	local window = {
		frame = frame,
		list = {},
		isOpen = function(): boolean
			return opened
		end,
		close = function()
			opened = false
			visible.fire()
		end,
	}
	local function button(text: string): any
		return { Activated = signal(), Active = true, Visible = true, Text = text }
	end
	local buttons: { [string]: any } = {}
	local labels: { any } = {}
	local card = { icon = {}, title = {}, detail = {}, action = button("") }
	local input: any = { FocusLost = signal(), Text = "" }
	local source = {
		WaitForChild = function(self: any): any
			return self
		end,
	}
	local engine = {
		GetService = function(_self: any, _name: string): any
			return source
		end,
	}
	local ui: any = {
		Color = { Red = "red", TextMuted = "muted" },
		TextSize = { Caption = 12 },
		TouchTarget = 44,
		window = function(): any
			return window
		end,
		card = function(): any
			return card
		end,
		text = function(_parent: any, text: string, _style: string, color: any): any
			local label = { Text = text, Color = color }
			table.insert(labels, label)
			return label
		end,
		list = function(): any
			return {}
		end,
		textInput = function(): any
			return input
		end,
		button = function(_parent: any, text: string, variant: string): any
			local created = button(text)
			created.Variant = variant
			buttons[text] = created
			return created
		end,
		actionRow = function(): any
			return {}
		end,
		actionButton = function(_parent: any, _order: number, text: string, variant: string): any
			local created = button(text)
			created.Variant = variant
			buttons[text] = created
			return created
		end,
		setText = function(label: any, text: string)
			label.Text = text
		end,
		setVariant = function(target: any, variant: string)
			target.Variant = variant
			target.Active = variant ~= "disabled"
		end,
		showWindow = function()
			opened = true
			visible.fire()
		end,
	}
	local pending = false
	local changed = signal()
	local requests: { any } = {}
	local controller = {
		Changed = changed,
		submit = function(remote: string, goodId: string, amount: any): boolean
			if pending then
				return false
			end
			table.insert(requests, { remote = remote, goodId = goodId, amount = amount })
			pending = true
			changed.fire()
			return true
		end,
	}
	local common = {
		setPurchaseButton = function(target: any, text: string, variant: string)
			target.Text = text
			target.Variant = variant
			target.Active = not pending and variant ~= "disabled"
		end,
	}
	local vector = { new = function() end }
	local udim = {
		new = function() end,
		fromOffset = function() end,
		fromScale = function() end,
	}
	local instance = {
		new = function(): any
			return { Parent = nil }
		end,
	}
	local enum = { TextXAlignment = { Center = "Center" } }
	local promptModule =
		createPrompt(engine, config, farmMath, goodsDiscard, ui, controller, common, vector, udim, instance, enum)
	local panel = promptModule.create({})
	local confirm = assert(buttons["Kalıcı olarak sil"], "a confirm button exists")
	local cancel = assert(buttons["Vazgeç"], "a cancel button exists")
	local minus, plus = assert(buttons["-"], "minus button exists"), assert(buttons["+"], "plus button exists")

	local state: any = { goods = { milk = 20, egg = 1 } }
	local function lastSummary(): string
		for index = #labels, 1, -1 do
			if string.find(labels[index].Text, "silinecek", 1, true) then
				return labels[index].Text
			end
		end
		return ""
	end

	-- Uyarı metni görünür ve kırmızıdır; "geri alınamaz" ve "para verilmez" açıkça yazar
	local warning: any = nil
	for _, label in labels do
		if label.Text == promptModule.WARNING or string.find(label.Text, "geri alınamaz", 1, true) then
			warning = label
		end
	end
	assert(warning and warning.Color == "red", "the irreversible warning is shown in red")
	assert(
		string.find(warning.Text, "geri alınamaz", 1, true) and string.find(warning.Text, "para verilmez", 1, true),
		"the warning says the action is irreversible and pays nothing"
	)

	-- Silme tek tıkla olmaz: panel açmak kimseyi silmez
	panel.open("milk", state)
	assert(opened, "opening the panel shows the window")
	assert(#requests == 0, "opening the confirmation sends nothing")
	assert(
		card.title.Text == config.GOODS.milk.displayName and string.find(card.detail.Text, "20", 1, true),
		"item and stock are shown"
	)
	assert(string.find(lastSummary(), "1 adet", 1, true), "the default selection is one unit, not the whole stack")
	assert(input.Text == "1", "the amount box shows the selection")
	assert(confirm.Variant == "danger" and confirm.Active, "a valid amount enables the danger confirm")
	assert(confirm.Variant ~= "primary", "the confirm is visually different from the sell actions")

	-- Miktar seçici: - / + sıkışır, hızlı düğmeler, yazılan değer
	assert(minus.Variant == "disabled", "minus is disabled at one")
	plus.Activated.fire()
	plus.Activated.fire()
	assert(input.Text == "3", "plus steps the amount")
	minus.Activated.fire()
	assert(input.Text == "2", "minus steps the amount")
	buttons["10"].Activated.fire()
	assert(input.Text == "10", "ten selects ten")
	buttons["Yarısı"].Activated.fire()
	assert(input.Text == "10", "half of 20 is 10")
	buttons["Hepsi"].Activated.fire()
	assert(input.Text == "20" and plus.Variant == "disabled", "all selects the stack and disables plus")
	buttons["1"].Activated.fire()
	assert(input.Text == "1", "one selects one")
	input.Text = "999"
	input.FocusLost.fire()
	assert(input.Text == "20", "a typed value above the stock clamps to the stock")
	input.Text = "-7"
	input.FocusLost.fire()
	assert(input.Text == "1", "a typed negative value clamps to one")
	input.Text = "abc"
	input.FocusLost.fire()
	assert(input.Text == "1" and confirm.Variant == "danger", "unreadable text keeps the selection and a valid confirm")
	input.Text = "2.7"
	input.FocusLost.fire()
	assert(input.Text == "2", "a fractional typed value floors to an integer")

	-- Onay: seçilen tam sayı ve ürün sunucuya gider; panel kapanır
	input.Text = "5"
	confirm.Activated.fire()
	assert(#requests == 1, "confirming sends exactly one request")
	assert(
		requests[1].remote == "RequestDiscardGoods" and requests[1].goodId == "milk" and requests[1].amount == 5,
		"the chosen good and amount are sent"
	)
	assert(not opened, "the panel closes after confirming")
	confirm.Activated.fire()
	assert(#requests == 1, "a stale confirm after closing sends nothing")
	pending = false

	-- Vazgeç ve ESC/kapat: hiçbir şey gönderilmez; yeniden açılış 1 adetle başlar
	panel.open("milk", state)
	buttons["Hepsi"].Activated.fire()
	cancel.Activated.fire()
	assert(not opened and #requests == 1, "cancel closes without sending")
	panel.open("milk", state)
	buttons["Hepsi"].Activated.fire()
	window.close()
	assert(#requests == 1, "closing with ESC or X sends nothing")
	panel.open("milk", state)
	assert(input.Text == "1", "reopening forgets the previous selection")

	-- Bekleyen işlemde onay kapalıdır (çift gönderim yok)
	pending = true
	changed.fire()
	assert(not confirm.Active, "confirm is inactive while another request is pending")
	confirm.Activated.fire()
	assert(#requests == 1, "a pending request blocks confirmation")
	pending = false
	changed.fire()

	-- Stok azalınca seçim sıkışır; stok bitince panel kapanır
	panel.open("milk", state)
	buttons["Hepsi"].Activated.fire()
	assert(input.Text == "20", "all of 20 is selected")
	panel.update({ goods = { milk = 4 } })
	assert(input.Text == "4", "a shrinking stock clamps the selection")
	panel.update({ goods = {} })
	assert(not opened, "the panel closes when the stock is gone")

	-- Ekipman/eşya kimlikleri ve boş ürün için panel hiç açılmaz (silinebilir tek şey ürün adedidir)
	panel.open("egg", { goods = {} })
	assert(not opened, "an empty stack opens nothing")
	for itemId in config.ITEMS do
		panel.open(itemId, { goods = { [itemId] = 5 } })
		assert(not opened, "equipment can never be opened for deletion")
	end
	panel.open("nope", state)
	assert(not opened and #requests == 1, "an unknown id opens nothing")
	print("PASS goods discard ui: confirmation, clamping, warning, disabled confirm, no equipment deletion")
end
