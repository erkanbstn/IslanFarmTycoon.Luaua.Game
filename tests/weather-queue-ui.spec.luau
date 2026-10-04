--!strict
return function(createPrompt: any)
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
	local frame = {
		Parent = true,
		Destroying = signal(),
		GetPropertyChangedSignal = function(): any
			return visible
		end,
	}
	local opened = false
	local window = {
		frame = frame,
		list = {},
		isOpen = function(): boolean
			return opened
		end,
		close = function()
			opened = false
		end,
	}
	local function button(): any
		return { Activated = signal(), Active = true, Visible = true }
	end
	local card = { title = {}, detail = {}, action = button() }
	local cancel = button()
	local labels = {}
	local source = {
		WaitForChild = function(self: any): any
			return self
		end,
	}
	local now = 100
	local engine = {
		GetService = function(_self: any, name: string): any
			return if name == "Workspace"
				then {
					GetServerTimeNow = function(): number
						return now
					end,
				}
				else source
		end,
	}
	local event = signal()
	local changed = signal()
	local pending = false
	local requests = {}
	local ui: any = {
		Color = {},
		window = function(): any
			return window
		end,
		card = function(): any
			return card
		end,
		text = function(): any
			local label = {}
			table.insert(labels, label)
			return label
		end,
		button = function(): any
			return cancel
		end,
		setText = function(label: any, text: string)
			label.Text = text
		end,
		showWindow = function()
			opened = true
		end,
	}
	local controller = {
		Changed = changed,
		submit = function(remote: string, itemId: string, detail: any): boolean
			if pending then
				return false
			end
			table.insert(requests, { remote = remote, itemId = itemId, detail = detail })
			pending = true
			changed.fire()
			return true
		end,
	}
	local common = {
		setPurchaseButton = function(target: any, text: string, variant: string)
			target.Text = text
			target.Active = not pending and variant ~= "disabled"
		end,
	}
	local prompt = createPrompt(engine, { WEATHER = { rain = { displayName = "Yağmurlu" } } }, {
		get = function(): any
			return { OnClientEvent = event }
		end,
	}, ui, controller, common, { new = function() end }, { fromScale = function() end }, { spawn = function() end }).create({})
	local offer = {
		kind = "offer",
		itemId = "weather_wand",
		weatherId = "rain",
		token = "server-token",
		ownerName = "Player One",
		weatherName = "Güneşli",
		endsAt = 150,
		startsAt = 150,
		expiresAt = 130,
	}
	event.fire(offer)
	assert(opened and prompt.hasEntry(), "server offer opens confirmation")
	assert(string.find(card.detail.Text, "Player One", 1, true), "current owner is shown")
	assert(string.find(labels[1].Text, "50", 1, true), "server-time effect countdown is shown")
	window.close()
	event.fire(offer)
	assert(opened, "using the staff again reopens a renewed offer")
	card.action.Activated.fire()
	card.action.Activated.fire()
	assert(#requests == 1, "pending confirmation cannot enqueue twice")
	assert(
		requests[1].detail.queueToken == "server-token" and requests[1].detail.weatherId == "rain",
		"confirmation preserves server quote identity"
	)
	pending = false
	event.fire({ kind = "queued", itemId = "weather_wand", weatherId = "rain", startsAt = 150, position = 2 })
	assert(not card.action.Visible and cancel.Text == "Sıradan çık", "queued screen exposes cancellation")
	window.close()
	event.fire({ kind = "queued", itemId = "weather_wand", weatherId = "rain", startsAt = 145, position = 1 })
	assert(not opened and prompt.hasEntry(), "background queue updates do not reopen a dismissed screen")
	prompt.open()
	cancel.Activated.fire()
	assert(
		#requests == 2 and requests[2].detail.queueAction == "cancel",
		"cancellation uses queued original item without relying on equipped staff"
	)
	event.fire({ kind = "closed" })
	assert(not opened and not prompt.hasEntry(), "activation or cancellation clears local queue")
	pending = false
	now = 131
	event.fire(offer)
	card.action.Activated.fire()
	assert(#requests == 2 and not card.action.Active, "expired offer never submits")
	cancel.Activated.fire()
	assert(not prompt.hasEntry() and #requests == 2, "declining offer sends no purchase or usage request")
	frame.Destroying.fire()
	event.fire(offer)
	assert(not prompt.hasEntry(), "destroyed host disconnects remote listener")
end
