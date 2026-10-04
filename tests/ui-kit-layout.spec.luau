--!strict
return function(createBase: any, createGrid: any)
	local objects = {}
	local instance = {
		new = function(class: string): any
			local attributes = {}
			local object = {
				ClassName = class,
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
		TextSize = { Caption = 14, Body = 16, Button = 15 },
		Radius = { Card = 10, Button = 8 },
		TouchTarget = 44,
	}
	local base = createBase(tokens, instance, dim, size, enum, {}, dim)
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
			return { Parent = parent }
		end,
		badge = function(button: any): any
			return function(count: number)
				button.badgeCount = count
			end
		end,
	}, instance, size, dim, enum)
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
