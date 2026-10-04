--!strict
return function(createWindows: any)
	local function signal(): any
		local listeners = {}
		local function connect(callback: any, once: boolean): any
			local listener = { callback = callback, live = true, once = once }
			table.insert(listeners, listener)
			return {
				Disconnect = function()
					listener.live = false
				end,
			}
		end
		return {
			Connect = function(_self: any, callback: any): any
				return connect(callback, false)
			end,
			Once = function(_self: any, callback: any): any
				return connect(callback, true)
			end,
			Fire = function(_self: any, ...: any)
				for _, listener in table.clone(listeners) do
					if listener.live then
						if listener.once then
							listener.live = false
						end
						listener.callback(...)
					end
				end
			end,
			Count = function(): number
				local count = 0
				for _, listener in listeners do
					if listener.live then
						count += 1
					end
				end
				return count
			end,
		}
	end
	local vectors: any = {}
	local vectorMeta: any = {}
	vectors.new = function(x: number, y: number): any
		return setmetatable({ X = x, Y = y }, vectorMeta)
	end
	vectorMeta.__sub = function(a: any, b: any): any
		return vectors.new(a.X - b.X, a.Y - b.Y)
	end
	vectorMeta.__div = function(a: any, b: number): any
		return vectors.new(a.X / b, a.Y / b)
	end
	local dimensions: any = {}
	local dimensionMeta: any = {}
	dimensions.new = function(xs: number?, xo: number?, ys: number?, yo: number?): any
		return setmetatable(
			{ X = { Scale = xs or 0, Offset = xo or 0 }, Y = { Scale = ys or 0, Offset = yo or 0 } },
			dimensionMeta
		)
	end
	dimensions.fromOffset = function(x: number, y: number): any
		return dimensions.new(0, x, 0, y)
	end
	dimensions.fromScale = function(x: number, y: number): any
		return dimensions.new(x, 0, y, 0)
	end
	dimensionMeta.__add = function(a: any, b: any): any
		return dimensions.new(
			a.X.Scale + b.X.Scale,
			a.X.Offset + b.X.Offset,
			a.Y.Scale + b.Y.Scale,
			a.Y.Offset + b.Y.Offset
		)
	end
	local objects = {}
	local instance: any = {}
	instance.new = function(class: string): any
		local properties = {}
		local object: any = {
			ClassName = class,
			Destroying = signal(),
			InputBegan = signal(),
			Activated = signal(),
			AbsoluteSize = vectors.new(1200, 800),
		}
		object.IsA = function(_self: any, kind: string): boolean
			return class == kind
				or (
					kind == "GuiObject"
					and (class == "Frame" or class == "TextButton" or class == "TextLabel" or class == "ScrollingFrame")
				)
		end
		object.GetPropertyChangedSignal = function(_self: any, name: string): any
			properties[name] = properties[name] or signal()
			return properties[name]
		end
		object.IsDescendantOf = function(self: any, ancestor: any): boolean
			local current = self.Parent
			while current do
				if current == ancestor then
					return true
				end
				current = current.Parent
			end
			return false
		end
		object.FindFirstAncestorOfClass = function(self: any, kind: string): any
			local current = self.Parent
			while current do
				if current:IsA(kind) then
					return current
				end
				current = current.Parent
			end
			return nil
		end
		object.Destroy = function(self: any)
			if self.destroyed then
				return
			end
			self.destroyed = true
			self.Destroying:Fire()
			for _, child in table.clone(objects) do
				if child.Parent == self then
					child:Destroy()
				end
			end
			self.Parent = nil
		end
		table.insert(objects, object)
		return object
	end
	local viewport = vectors.new(1200, 800)
	local scale = 1
	local root: any = nil
	local playerGui = instance.new("PlayerGui")
	local hits = {}
	playerGui.GetGuiObjectsAtPosition = function(): any
		return hits
	end
	local reduced = true
	local player = {
		GetAttribute = function(): boolean
			return reduced
		end,
		FindFirstChildOfClass = function(): any
			return playerGui
		end,
	}
	local input = {
		MouseEnabled = true,
		GamepadEnabled = false,
		InputBegan = signal(),
		InputChanged = signal(),
		InputEnded = signal(),
		WindowFocusReleased = signal(),
	}
	local camera = instance.new("Camera")
	local workspaceMock = instance.new("Workspace")
	workspaceMock.CurrentCamera = camera
	local tweens = {}
	local tweenService = {
		Create = function(_self: any, frame: any, _info: any, target: any): any
			local tween: any = { Completed = signal(), cancelled = false }
			tween.Play = function() end
			tween.Cancel = function()
				tween.cancelled = true
				tween.Completed:Fire()
			end
			tween.Finish = function()
				if not tween.cancelled then
					for key, value in target do
						frame[key] = value
					end
				end
				tween.Completed:Fire()
			end
			table.insert(tweens, tween)
			return tween
		end,
	}
	local services = {
		TweenService = tweenService,
		Workspace = workspaceMock,
		GuiService = {},
		UserInputService = input,
		Players = { LocalPlayer = player },
	}
	local gameMock = {
		GetService = function(_self: any, name: string): any
			return services[name]
		end,
	}
	local function child(parent: any, class: string): any
		local object = instance.new(class)
		object.Parent = parent
		return object
	end
	local base = {
		panel = function(parent: any): any
			return child(parent, "Frame")
		end,
		corner = function() end,
		list = function() end,
		iconChip = function(parent: any): any
			return child(parent, "Frame")
		end,
		text = function(parent: any): any
			return child(parent, "TextLabel")
		end,
	}
	local controls = {
		closeButton = function(parent: any, callback: any): any
			local button = child(parent, "TextButton")
			button.Activated:Connect(callback)
			return button
		end,
	}
	local screen = {
		viewport = function(): any
			return viewport
		end,
		scale = function(): number
			return scale
		end,
		root = function(parent: any): any
			root = child(parent, "Frame")
			root.AbsoluteSize = viewport
			return root
		end,
	}
	local enums = {
		EasingStyle = { Quint = 1, Quad = 2 },
		EasingDirection = { Out = 1, In = 2 },
		ZIndexBehavior = { Sibling = 1 },
		AutomaticSize = { None = 0, Y = 1 },
		UserInputType = { MouseButton1 = 1, MouseMovement = 2 },
		KeyCode = { Escape = 1, ButtonB = 2 },
	}
	local windows = createWindows(
		gameMock,
		{ Color = {}, Radius = {} },
		base,
		controls,
		screen,
		{ play = function() end },
		instance,
		dimensions,
		vectors,
		enums,
		{
			new = function()
				return {}
			end,
		},
		{
			new = function()
				return {}
			end,
		},
		{
			new = function()
				return {}
			end,
		}
	)
	local function make(title: string, gui: any, width: number?, maxHeight: number?): any
		return windows.window(gui, {
			title = title,
			icon = "",
			width = width or 400,
			maxHeight = maxHeight or 500,
			anchor = vectors.new(0.5, 0.5),
			position = dimensions.fromScale(0.5, 0.5),
		})
	end
	local guiA = child(playerGui, "ScreenGui")
	local guiB = child(playerGui, "ScreenGui")
	local a, b = make("A", guiA), make("B", guiB)
	assert(a.frame.Parent == b.frame.Parent, "Separate ScreenGuis must share the window layer")
	assert(
		root.Parent.Name == "Windows" and root.Parent.DisplayOrder == 10,
		"Windows layer must remain below notifications"
	)
	a.open()
	b.open()
	assert(a.isOpen() and b.isOpen(), "Desktop must retain both windows")
	assert(b.frame.ZIndex > a.frame.ZIndex, "Last opened window must be in front")
	local function handle(window: any): any
		for _, object in objects do
			if object.Parent == window.frame and object.Name == "WindowDragHandle" then
				return object
			end
		end
		error("Drag handle missing")
	end
	local function mouse(kind: number, x: number, y: number): any
		return { UserInputType = kind, Position = vectors.new(x, y) }
	end
	local function drag(window: any, dx: number, dy: number)
		handle(window).InputBegan:Fire(mouse(1, 100, 100))
		input.InputChanged:Fire(mouse(2, 100 + dx, 100 + dy))
		input.InputEnded:Fire(mouse(1, 100 + dx, 100 + dy))
	end
	drag(a, 100, 40)
	assert(a.frame.Position.X.Offset == 700 and a.frame.Position.Y.Offset == 440, "Header drag must apply mouse delta")
	assert(a.frame.ZIndex > b.frame.ZIndex, "Dragging must focus window")
	windows.show(b)
	assert(b.frame.ZIndex > a.frame.ZIndex, "Showing another window must focus it")
	windows.show(a)
	assert(a.frame.Position.X.Offset == 700, "Showing an open window must preserve its layout")
	windows.toggle(a)
	assert(not a.isOpen() and b.isOpen(), "Desktop menu click must close only its own open window")
	windows.toggle(a)
	assert(a.isOpen() and b.isOpen(), "Reopening must preserve other desktop windows")
	assert(
		a.frame.Position.X.Offset == 600 and a.frame.Position.Y.Offset == 400,
		"Menu click must restore default placement"
	)
	hits = { b.list }
	input.InputBegan:Fire(mouse(1, 300, 300), false)
	assert(b.frame.ZIndex > a.frame.ZIndex, "Content click must bring its owner to front")
	local previous = b.frame.Position
	b.list.InputBegan:Fire(mouse(1, 100, 100))
	input.InputChanged:Fire(mouse(2, 200, 200))
	assert(b.frame.Position == previous, "Content drag must not move window")
	input.InputBegan:Fire({ KeyCode = enums.KeyCode.Escape }, true)
	assert(a.isOpen() and b.isOpen(), "Processed Escape must be ignored")
	input.InputBegan:Fire({ KeyCode = enums.KeyCode.Escape }, false)
	assert(a.isOpen() and not b.isOpen(), "Escape must close only foreground window")
	b.open()
	scale = 2
	root.AbsoluteSize = vectors.new(1200, 800)
	viewport = vectors.new(1200, 800)
	-- Root has physical pixels; scaled viewport contains logical units.
	viewport = vectors.new(1000, 650)
	root.AbsoluteSize = vectors.new(2000, 1300)
	camera:GetPropertyChangedSignal("ViewportSize"):Fire()
	drag(b, 100, 40)
	assert(
		b.frame.Position.X.Offset == 550 and b.frame.Position.Y.Offset == 345,
		"Drag delta must account for UI scale"
	)
	drag(b, 10000, 10000)
	assert(
		b.frame.Position.X.Offset == 788 and b.frame.Position.Y.Offset == 388,
		"Dragging must clamp right and bottom edges"
	)
	drag(b, -10000, -10000)
	assert(
		b.frame.Position.X.Offset == 212 and b.frame.Position.Y.Offset == 262,
		"Dragging must clamp left and top edges"
	)
	handle(b).InputBegan:Fire(mouse(1, 100, 100))
	input.WindowFocusReleased:Fire()
	previous = b.frame.Position
	input.InputChanged:Fire(mouse(2, 900, 900))
	assert(b.frame.Position == previous, "Losing application focus must cancel drag")
	b.focus()
	viewport = vectors.new(700, 500)
	root.AbsoluteSize = viewport
	scale = 1
	camera:GetPropertyChangedSignal("ViewportSize"):Fire()
	assert(b.isOpen() and not a.isOpen(), "Narrow viewport must preserve foreground window")
	windows.toggle(b)
	assert(not b.isOpen(), "Compact menu click must toggle closed")
	a.open()
	b.open()
	assert(b.isOpen() and not a.isOpen(), "Compact layout must retain one window")
	viewport = vectors.new(1200, 800)
	root.AbsoluteSize = viewport
	camera:GetPropertyChangedSignal("ViewportSize"):Fire()
	reduced = false
	a.open()
	local opening = tweens[#tweens]
	a.close()
	assert(opening.cancelled, "Closing must cancel pending opening tween")
	local closing = tweens[#tweens]
	a.open()
	assert(closing.cancelled, "Reopening must cancel pending close tween")
	closing.Finish()
	assert(a.isOpen() and a.frame.Visible, "Old close completion must not hide reopened window")
	local replacement = instance.new("Camera")
	workspaceMock.CurrentCamera = replacement
	workspaceMock:GetPropertyChangedSignal("CurrentCamera"):Fire()
	assert(
		camera:GetPropertyChangedSignal("ViewportSize").Count() == 0,
		"Camera replacement must disconnect previous camera"
	)
	assert(
		replacement:GetPropertyChangedSignal("ViewportSize").Count() == 2,
		"Both windows must watch replacement camera"
	)
	guiA:Destroy()
	assert(a.frame.destroyed and not b.frame.destroyed, "Owner destruction must remove only owned window")
	guiB:Destroy()
	assert(b.frame.destroyed and root.Parent == nil, "Last owner must destroy shared window layer")
	assert(
		input.InputBegan.Count() == 0
			and input.InputChanged.Count() == 0
			and input.InputEnded.Count() == 0
			and input.WindowFocusReleased.Count() == 0,
		"Last window must disconnect global input handlers"
	)
	assert(
		camera:GetPropertyChangedSignal("ViewportSize").Count() == 0
			and replacement:GetPropertyChangedSignal("ViewportSize").Count() == 0
			and workspaceMock:GetPropertyChangedSignal("CurrentCamera").Count() == 0,
		"Destroyed windows must release camera listeners"
	)
	-- Geniş içerik pencereleri telefonda güvenli alana küçülür; büyük masaüstü ölçüsü taşmaz.
	viewport = vectors.new(390, 500)
	reduced = true
	local phoneOwner = child(playerGui, "ScreenGui")
	local largeWindow = make("InventorySized", phoneOwner, 600, 560)
	largeWindow.open()
	assert(
		largeWindow.frame.Size.X.Offset == 366 and largeWindow.frame.Size.Y.Offset == 420,
		"A large content window must shrink to the phone viewport"
	)
	assert(
		largeWindow.frame.Position.X.Offset == 195 and largeWindow.frame.Position.Y.Offset == 250,
		"A resized phone window must remain centered"
	)
	phoneOwner:Destroy()
	viewport = vectors.new(1200, 800)
	reduced = false
	for index = 1, 10 do
		local owner = child(playerGui, "ScreenGui")
		local fresh = make(`Fresh{index}`, owner)
		fresh.open()
		assert(input.InputBegan.Count() == 1, "Recreating windows must install exactly one shared input listener")
		owner:Destroy()
		assert(
			input.InputBegan.Count() == 0 and input.InputChanged.Count() == 0,
			"Repeated destruction must not accumulate input listeners"
		)
	end
	print("  window stacking, reset, scaled drag, compact layout and cleanup OK")
end
