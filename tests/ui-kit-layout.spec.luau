--!strict
return function(createBase: any, createGrid: any)
	local objects = {}
	local function signal(): any
		local entries = {}
		return {
			Connect = function(_self: any, callback: any): any
				local entry = { active = true, callback = callback }
				table.insert(entries, entry)
				return {
					Disconnect = function()
						entry.active = false
					end,
				}
			end,
			Fire = function(_self: any, ...: any)
				for _, entry in entries do
					if entry.active then
						entry.callback(...)
					end
				end
			end,
		}
	end
	local instance = {
		new = function(class: string): any
			local attributes = {}
			local changed = {}
			local object = {
				ClassName = class,
				Visible = true,
				LayoutOrder = 0,
				AbsoluteSize = { X = 600 },
				ChildAdded = signal(),
				ChildRemoved = signal(),
				Destroying = signal(),
				IsA = function(_self: any, kind: string): boolean
					return class == kind
				end,
				GetPropertyChangedSignal = function(_self: any, name: string): any
					if not changed[name] then
						changed[name] = signal()
					end
					return changed[name]
				end,
				Activated = {
					Connect = function(self: any, callback: any)
						self.fire = callback
					end,
				},
				SetAttribute = function(_self: any, name: string, value: any)
					attributes[name] = value
				end,
				GetAttribute = function(_self: any, name: string): any
					return attributes[name]
				end,
			}
			object.FindFirstChildOfClass = function(self: any, kind: string): any
				for _, child in objects do
					if child.Parent == self and child.ClassName == kind then
						return child
					end
				end
				return nil
			end
			object.GetChildren = function(self: any): any
				local children = {}
				for _, child in objects do
					if child.Parent == self then
						table.insert(children, child)
					end
				end
				return children
			end
			table.insert(objects, object)
			return object
		end,
	}
	local dim = {
		new = function(...: any): any
			return { ... }
		end,
	}
	local size = {
		new = dim.new,
		fromOffset = dim.new,
		fromScale = dim.new,
	}
	local enum = {
		ApplyStrokeMode = { Border = 1 },
		AutomaticSize = { Y = 1 },
		TextXAlignment = { Left = 1, Center = 2 },
		TextYAlignment = { Center = 1, Top = 2 },
		SortOrder = { LayoutOrder = 1 },
		FillDirection = { Horizontal = 1, Vertical = 2 },
		HorizontalAlignment = { Left = 1, Center = 2 },
		VerticalAlignment = { Top = 1, Center = 2 },
		DominantAxis = { Height = 1 },
		ItemLineAlignment = { Stretch = 1 },
		UIFlexAlignment = { Fill = 1, None = 2 },
	}
	local tokens = {
		Color = { Text = 1, TextMuted = 2, Gold = 3, GoldLight = 4, Surface = 5, Stroke = 6 },
		Font = { Body = 1, Bold = 2 },
		TextSize = { Caption = 14, Body = 16, Button = 15, Title = 24 },
		Radius = { Card = 10, Button = 8 },
		TouchTarget = 44,
	}
	local base = createBase(tokens, instance, dim, size, enum, {}, dim)
	local empty = base.emptyState({}, "📦", "Complete", "Nothing left to buy")
	assert(
		empty.title.TextSize == 24 and empty.description.TextSize == 16,
		"empty states use a prominent heading and readable body"
	)
	assert(
		empty.title.TextXAlignment == enum.TextXAlignment.Center and empty.description.TextWrapped,
		"empty state copy stays centered and wraps"
	)
	local emptyLayout = empty.frame:FindFirstChildOfClass("UIListLayout")
	assert(
		emptyLayout.HorizontalAlignment == enum.HorizontalAlignment.Center
			and emptyLayout.VerticalAlignment == enum.VerticalAlignment.Center,
		"empty state contents share a centered layout"
	)
	local detailsHost = { Name = "DisclosureBody" }
	local explanation = base.text(detailsHost, "Long explanation", "Caption", tokens.Color.TextMuted)
	assert(explanation.TextSize == tokens.TextSize.Body, "opened explanations use readable body size")
	assert(
		explanation.TextColor3 == tokens.Color.Text and explanation.LineHeight == 1.2,
		"details have contrast and line spacing"
	)
	assert(
		explanation.TextWrapped and explanation.AutomaticSize == enum.AutomaticSize.Y,
		"narrow details wrap and grow without shrinking text"
	)
	local colored = base.text(detailsHost, "Warning", "Caption", tokens.Color.Gold)
	assert(colored.TextColor3 == tokens.Color.Gold, "explicit semantic colors are preserved")
	local caption = base.text({}, "Short caption", "Caption")
	assert(
		caption.TextSize == tokens.TextSize.Caption and caption.TextColor3 == tokens.Color.TextMuted,
		"ordinary captions stay compact"
	)
	local icon = base.iconChip({}, "🪙", 30, tokens.Color.Gold)
	assert(icon.Text == "", "gold must use geometry instead of a platform-dependent emoji glyph")
	local coin, aspect
	for _, object in objects do
		if object.Name == "GoldCoin" then
			coin = object
		elseif object.ClassName == "UIAspectRatioConstraint" then
			aspect = object
		end
	end
	assert(
		coin and coin.Parent == icon and coin.BackgroundColor3 == tokens.Color.GoldLight,
		"gold coin belongs to its icon chip"
	)
	assert(aspect and aspect.Parent == coin and aspect.AspectRatio == 1, "gold preview has a square aspect constraint")
	assert(aspect.DominantAxis == enum.DominantAxis.Height, "wide preview chips must still draw a round coin")
	local grid = createGrid(tokens, base, {
		statusLabel = function(parent: any): any
			return { Parent = parent }
		end,
		button = function(parent: any): any
			local button = instance.new("TextButton")
			button.Parent = parent
			return button
		end,
		badge = function(button: any): any
			return function(count: number)
				button.badgeCount = count
			end
		end,
	}, instance, size, dim, enum)
	local actions = grid.actionRow({}, 0, 4, 86)
	local actionButtons = {}
	for index = 1, 5 do
		local button = grid.actionButton(actions, index, "Choice", "secondary")
		table.insert(actionButtons, button)
		actions.ChildAdded:Fire(button)
	end
	assert(
		actionButtons[1].Size[1] == 0.25 and actionButtons[5].Size[1] == 1,
		"four choices share a row and a last lone action fills it"
	)
	actions.AbsoluteSize.X = 200
	actions:GetPropertyChangedSignal("AbsoluteSize"):Fire()
	assert(actionButtons[1].Size[1] == 0.5, "narrow action group uses two columns")
	actions.AbsoluteSize.X = 100
	actions:GetPropertyChangedSignal("AbsoluteSize"):Fire()
	assert(
		actionButtons[1].Size[1] == 1 and actionButtons[1].Size[4] >= tokens.TouchTarget,
		"small cards preserve full touch targets"
	)
	actions.AbsoluteSize.X = 600
	actionButtons[5].Visible = false
	actionButtons[5]:GetPropertyChangedSignal("Visible"):Fire()
	assert(actionButtons[4].Size[1] == 0.25, "hidden actions do not reserve a slot")
	actions.Destroying:Fire()
	actions.AbsoluteSize.X = 100
	actions:GetPropertyChangedSignal("AbsoluteSize"):Fire()
	assert(actionButtons[1].Size[1] == 0.25, "destroyed action group disconnects resize listeners")
	local host = grid.autoGrid({}, 0, 2)
	for _, object in objects do
		if object.ClassName == "UIListLayout" and object.Parent == host then
			assert(object.ItemLineAlignment == enum.ItemLineAlignment.Stretch, "siblings stretch to their row height")
			assert(
				object.VerticalFlex ~= enum.UIFlexAlignment.Fill,
				"scrolling cards must not shrink to viewport height"
			)
		end
	end
	local tile = grid.autoTile(host, 0, "", nil)
	assert(tile.detail.AutomaticSize == enum.AutomaticSize.Y, "long localized details must grow rather than truncate")
	assert(
		tile.action.AutomaticSize == enum.AutomaticSize.Y and tile.action.Size[4] >= tokens.TouchTarget,
		"purchase actions wrap at a full touch target"
	)
	local selections = {}
	local row, selectTab, setBadge = grid.tabs(
		{},
		0,
		{ { id = "first", label = "First" }, { id = "second", label = "Second" } },
		function(id: string)
			table.insert(selections, id)
		end
	)
	local first, second
	for _, object in objects do
		if object.ClassName == "TextButton" and object.Parent == row then
			if object.Text == "First" then
				first = object
			else
				second = object
			end
		end
	end
	first.Activated.fire()
	assert(#selections == 0, "already selected tab does not rerender content")
	second.Activated.fire()
	second.Activated.fire()
	assert(#selections == 1 and selections[1] == "second", "new tab changes immediately and repeated clicks are no-ops")
	selectTab("first")
	first.Activated.fire()
	assert(#selections == 1, "programmatic selection is silent and synchronizes repeat click suppression")
	selectTab("unknown")
	first.Activated.fire()
	assert(#selections == 1, "invalid selection cannot clear the selected tab")
	setBadge("second", 2)
	assert(second.badgeCount == 2 and first.badgeCount == nil, "tab counts belong to their own button")
	assert(second:FindFirstChildOfClass("UIPadding").PaddingRight[2] == 34, "badge reserves label space")
	setBadge("second", 0)
	assert(
		second.badgeCount == 0 and second:FindFirstChildOfClass("UIPadding").PaddingRight[2] == 14,
		"zero clears count and restores space"
	)
	assert(#selections == 1, "updating badges never changes selected tab")
	print("PASS UI kit layout: round drawn gold, natural card height, stretched rows and wrapped actions")
end
