--!strict
return function(createAdminPanel: any)
	local clockNow = 100
	local function signal(): any
		local listeners = {}
		return {
			Connect = function(_self: any, callback: any): any
				table.insert(listeners, callback)
				return { Disconnect = function() end }
			end,
			fire = function(...: any)
				for _, listener in listeners do
					listener(...)
				end
			end,
		}
	end
	local function node(): any
		local attributes, changed = {}, {}
		local result: any = {
			Activated = signal(),
			Destroying = signal(),
			WaitForChild = function(self: any): any
				return self
			end,
			GetChildren = function(): any
				return {}
			end,
			ReleaseFocus = function() end,
			GetAttribute = function(_self: any, name: string): any
				return attributes[name]
			end,
			SetAttribute = function(_self: any, name: string, value: any)
				attributes[name] = value
			end,
			GetAttributeChangedSignal = function(_self: any, name: string): any
				changed[name] = changed[name] or signal()
				return changed[name]
			end,
		}
		result.Parent = result
		return result
	end
	local player = node()
	player.DisplayName, player.UserId = "Owner", 123
	player:SetAttribute("IsAdmin", true)
	player:SetAttribute("DataPersistent", true)
	local services = node()
	services.LocalPlayer = player
	services.PlayerAdded, services.PlayerRemoving = signal(), signal()
	services.GetPlayers = function(): any
		return { player }
	end
	local engine = {
		GetService = function(): any
			return services
		end,
	}
	local buttons, inputs, texts, disclosures = {}, {}, {}, {}
	local opened = false
	local ui: any = {
		TouchTarget = 44,
		Color = {
			Green = "green",
			Blue = "blue",
			Gold = "gold",
			Red = "red",
			Orange = "orange",
			TextMuted = "muted",
			OnAccent = "white",
		},
		TextSize = { Button = 15 },
		list = function() end,
		tabs = function() end,
		setVariant = function(button: any, variant: string)
			button.Active = variant ~= "disabled" and variant ~= "owned"
		end,
	}
	ui.text = function(parent: any, text: string): any
		local label = node()
		label.Parent, label.Text = parent, text
		table.insert(texts, label)
		return label
	end
	ui.textInput = function(parent: any, placeholder: string): any
		local input = node()
		input.Parent, input.Text, input.PlaceholderText = parent, "", placeholder
		table.insert(inputs, input)
		return input
	end
	ui.button = function(parent: any, text: string, variant: string): any
		local button = node()
		button.Parent, button.Text = parent, text
		ui.setVariant(button, variant)
		table.insert(buttons, button)
		return button
	end
	ui.disclosure = function(parent: any): any
		local details = { frame = node(), body = node() }
		details.frame.Parent = parent
		details.body.Parent, details.body.Visible = details.frame, false
		table.insert(disclosures, details)
		return details
	end
	ui.actionRow = function(parent: any): any
		local row = node()
		row.Parent = parent
		return row
	end
	ui.actionButton = function(parent: any, order: number, text: string, variant: string): any
		local button = ui.button(parent, text, variant)
		button.LayoutOrder = order
		return button
	end
	local root = node()
	ui.window = function(): any
		local frame = node()
		frame.Parent = root
		return {
			frame = frame,
			list = node(),
			open = function()
				opened = true
			end,
			close = function()
				opened = false
			end,
			isOpen = function(): boolean
				return opened
			end,
		}
	end
	local requests = {}
	local adminResult = signal()
	local remotes = {
		get = function(name: string): any
			if name == "AdminResult" then
				return { OnClientEvent = adminResult }
			end
			return {
				FireServer = function(_self: any, ...: any)
					table.insert(requests, { name = name, arguments = { ... } })
				end,
			}
		end,
	}
	local dimensions = {
		new = function(): number
			return 0
		end,
		fromScale = function(): number
			return 0
		end,
		fromOffset = function(): number
			return 0
		end,
	}
	local enumeration: any = setmetatable({}, {
		__index = function(self: any): any
			return self
		end,
	})
	local admin = createAdminPanel(
		engine,
		remotes,
		{ formatMoney = tostring },
		ui,
		{
			get = function(): any
				return { cash = 100 }
			end,
			onChanged = function(): any
				return function() end
			end,
			requestSnapshot = function() end,
		},
		{ new = node },
		dimensions,
		dimensions,
		dimensions,
		enumeration,
		{
			clock = function(): number
				return clockNow
			end,
		},
		{
			delay = function() end,
			defer = function(callback: any)
				callback()
			end,
		}
	)
	admin.open(root)
	assert(opened and #disclosures == 3, "admin creates three optional detail groups and opens for the owner")
	for _, details in disclosures do
		assert(not details.body.Visible, "long helper content starts collapsed")
	end
	local resetButton, resetInput, warning = nil, nil, nil
	for _, button in buttons do
		if button.Text == "Herkesin verisini sıfırla" then
			resetButton = button
		end
	end
	for _, input in inputs do
		if input.PlaceholderText == "Onay için SIFIRLA yaz" then
			resetInput = input
		end
	end
	for _, label in texts do
		if string.find(label.Text, "Bütün oyuncuların (sen dahil", 1, true) then
			warning = label
		end
	end
	assert(
		resetButton and resetInput and warning and warning.Parent.Name == "Page_test",
		"irreversible reset warning stays outside collapsed details"
	)
	resetButton.Activated.fire()
	assert(#requests == 0, "an empty reset confirmation sends no command")
	resetInput.Text = "SIFIRLA"
	resetButton.Activated.fire()
	assert(
		#requests == 1 and requests[1].arguments[1] == "resetAllPlayers" and requests[1].arguments[2] == "confirm",
		"explicit reset confirmation preserves the server command contract"
	)
	for _, choice in
		{
			{ label = "Gezgin tüccarı çağır", action = "forceMerchant" },
			{ label = "Altın hayvanı çağır", action = "forceGolden" },
			{ label = "Mevsim hedefini tamamla", action = "completeSeason" },
			{ label = "Olayları sıfırla", action = "resetEvents" },
			{ label = "Envanteri boşalt", action = "clearItems" },
			{ label = "Ahır deposunu doldur", action = "fillBarn" },
		}
	do
		local last = requests[#requests]
		clockNow += 1
		adminResult.fire(last.arguments[3], true, "Done")
		local target = nil
		for _, button in buttons do
			if button.Text == choice.label then
				target = button
			end
		end
		assert(target and target.Active, "grouped administrative action stays accessible")
		target.Activated.fire()
		assert(
			requests[#requests].arguments[1] == choice.action,
			"grouped button keeps its own command rather than the group's first command"
		)
	end
	local requestCount = #requests
	player:SetAttribute("IsAdmin", false)
	player:GetAttributeChangedSignal("IsAdmin").fire()
	assert(not opened, "permission loss closes the administrative window")
	resetInput.Text = "SIFIRLA"
	resetButton.Activated.fire()
	assert(#requests == requestCount, "permission loss prevents commands even through stale UI callbacks")
	print(
		"PASS admin UI: optional details, visible irreversible warning, explicit reset confirmation and permission loss"
	)
end
