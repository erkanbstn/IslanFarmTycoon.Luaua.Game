--!strict
return function(createEffectsSection: any)
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
		return {
			Activated = signal(),
			GetPropertyChangedSignal = function(): any
				return signal()
			end,
		}
	end
	local cards, labels, disclosures, sourceRequests = {}, {}, {}, {}
	local ui: any = {
		Color = {},
		TextSize = {},
		Font = {},
		autoGrid = node,
		autoTile = function(): any
			local card = { title = node(), detail = node(), action = node() }
			table.insert(cards, card)
			return card
		end,
		text = function(_parent: any, text: string): any
			local label = { Text = text }
			table.insert(labels, label)
			return label
		end,
		setText = function(label: any, text: string)
			label.Text = text
		end,
		disclosure = function(): any
			local expanded = false
			local disclosure = {
				body = node(),
				button = node(),
				setExpanded = function(value: boolean)
					expanded = value
				end,
				isExpanded = function(): boolean
					return expanded
				end,
			}
			disclosure.button.Activated:Connect(function()
				expanded = not expanded
			end)
			table.insert(disclosures, disclosure)
			return disclosure
		end,
	}
	local mathModule = { formatMoney = tostring }
	local summary = {
		snapshot = function(_save: any, _now: number, details: boolean): any
			table.insert(sourceRequests, details)
			return {
				income = 200,
				incomeFactor = 3,
				growthSpeed = 2,
				movementMultiplier = 1.15,
				offlineRate = 0.5,
				offlineHours = 2,
				passFactor = 2,
				runDouble = true,
				returnActive = false,
				count = 0,
				storageCap = 500,
				incomeCapped = true,
				contractBonus = 0,
				facilities = {},
				zones = {},
				islands = {},
				equipment = {},
				sources = { { label = "Altın Taç", incomeDelta = 80 } },
			}
		end,
	}
	local workspaceMock = {
		GetServerTimeNow = function(): number
			return 1000000
		end,
	}
	local engine = {
		GetService = function(_self: any, id: string): any
			return if id == "Workspace"
				then workspaceMock
				else {
					WaitForChild = function(self: any): any
						return self
					end,
				}
		end,
	}
	local environment = {
		getSeason = function(): any
			return { displayName = "İlkbahar" }
		end,
		getWeather = function(): any
			return { displayName = "Güneşli" }
		end,
	}
	local module = createEffectsSection(
		engine,
		{ MOVEMENT_SPEED_BONUS_CAP = 0.25, PROGRESSION = { maxRebirth = 30, permanentIncomeCap = 3 } },
		summary,
		mathModule,
		environment,
		ui,
		{}
	)
	local panel = module.create(node())
	panel.update({})
	assert(#cards == 4 and cards[1].detail.Text == "200/sn", "first view has four actual large values")
	assert(
		cards[2].detail.Text == "3x" and cards[4].detail.Text == "%50 · 2 saat",
		"cap and absolute offline rate are readable"
	)
	assert(
		not sourceRequests[1] and not disclosures[1].isExpanded(),
		"details and expensive source calculations start closed"
	)
	disclosures[1].button.Activated.fire()
	assert(sourceRequests[#sourceRequests], "opening source disclosure immediately computes its details")
	local found = false
	for _, label in labels do
		if string.find(label.Text, "Altın Taç · 80/sn fark", 1, true) then
			found = true
		end
	end
	assert(found, "source difference appears when requested")
	panel.reset()
	panel.update({})
	assert(
		not sourceRequests[#sourceRequests] and not disclosures[1].isExpanded(),
		"closing the window resets details to the compact view"
	)
	assert(#cards == 4 and #disclosures == 3, "updates do not rebuild cards or disclosure connections")
	print(
		"PASS effects section: actual compact values, lazy detail calculation, immediate reveal and contextual collapse"
	)
end
