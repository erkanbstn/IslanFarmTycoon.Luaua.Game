--!strict
return function(createBase: any, createGrid: any)
	local objects = {}
	local instance = {
		new = function(class: string): any
			local attributes = {}
			local object = {
				ClassName = class,
				SetAttribute = function(_self: any, name: string, value: any)
					attributes[name] = value
				end,
				GetAttribute = function(_self: any, name: string): any
					return attributes[name]
				end,
			}
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
	print("PASS UI kit layout: round drawn gold, natural card height, stretched rows and wrapped actions")
end
