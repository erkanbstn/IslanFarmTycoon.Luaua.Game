--!strict
return function(createControls: any)
	local function signal(): any
		local callbacks = {}
		return {
			Connect = function(_self: any, callback: () -> ())
				table.insert(callbacks, callback)
				return { Disconnect = function() end }
			end,
			Fire = function()
				for _, callback in callbacks do
					callback()
				end
			end,
		}
	end
	local instances = 0
	local created: { any } = {}
	local instance = {
		new = function(class: string): any
			instances += 1
			local node = { ClassName = class, Activated = signal(), SetAttribute = function() end }
			table.insert(created, node)
			return node
		end,
	}
	local color = {
		Green = 1,
		Orange = 2,
		SurfaceRaised = 3,
		Blue = 4,
		Red = 5,
		Disabled = 6,
		GreenDark = 7,
		Text = 8,
		OnAccent = 9,
	}
	local tokens = {
		Color = color,
		Font = { Bold = 1 },
		TextSize = { Body = 18, Button = 17 },
		Radius = { Button = 8 },
		TouchTarget = 44,
	}
	local controls = createControls(
		{
			GetService = function(): any
				return { LocalPlayer = {
					GetAttribute = function(): boolean
						return true
					end,
				} }
			end,
		},
		{ play = function() end },
		tokens,
		{ list = function() end, corner = function() end, stroke = function() end, padding = function() end },
		instance,
		{
			new = function(...: any): any
				return { ... }
			end,
			fromOffset = function(...: any): any
				return { ... }
			end,
		},
		{
			AutomaticSize = { Y = 1 },
			EasingStyle = { Quad = 1 },
			EasingDirection = { Out = 1 },
			ApplyStrokeMode = { Border = 1 },
		},
		{
			new = function()
				return {}
			end,
		},
		{
			new = function(...: any): any
				return { ... }
			end,
		}
	)
	for _, inline in { true, false } do
		local setBadge = controls.badge({}, inline)
		local badge = created[#created - 1]
		assert(
			badge.Position[1] == 1 and badge.Position[3] == 0 and badge.Position[4] == 6,
			"Tab and menu counts stay in the upper-right corner, away from centered text"
		)
		setBadge(12)
		assert(badge.Visible and badge.Text == "9+", "Corner badges retain bounded counts")
		setBadge(0)
		assert(not badge.Visible, "Empty corner badges disappear")
	end
	local disclosure = controls.disclosure({}, 3, "Ayrıntılar")
	assert(not disclosure.isExpanded() and not disclosure.body.Visible, "explanations are hidden on first view")
	assert(disclosure.button.Size[4] == tokens.TouchTarget, "details remain usable by touch and gamepad")
	local initialInstances = instances
	for _ = 1, 300 do
		disclosure.button.Activated:Fire()
		assert(disclosure.isExpanded() and disclosure.body.Visible, "first activation reveals contextual controls")
		disclosure.setExpanded(true)
		assert(disclosure.body.Visible, "idempotent redraw cannot collapse the user's details")
		disclosure.button.Activated:Fire()
		assert(not disclosure.isExpanded() and not disclosure.body.Visible, "second activation restores a compact view")
	end
	assert(instances == initialInstances, "repeated disclosure never rebuilds UI instances")
	disclosure.setExpanded(true)
	disclosure.setExpanded(false)
	assert(
		not disclosure.body.Visible and disclosure.button.Active,
		"context reset collapses details while preserving the entry action"
	)
	print(
		"PASS UI disclosure: compact first view, touch target, contextual reveal, idempotent updates and 300 cycles without rebuilding"
	)
end
