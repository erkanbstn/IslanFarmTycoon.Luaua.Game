--!strict
-- Başlıklı, kaydırılabilir listeli pencere (açılırken kayarak gelir; açık pencereler birbirini yönetir).
-- UiKit cephesi bunları birleştirir; bileşenleri `UiKit.<ad>` ile kullan.

local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local Tokens = require(script.Parent:WaitForChild("Tokens"))
local Base = require(script.Parent:WaitForChild("Base"))
local Controls = require(script.Parent:WaitForChild("Controls"))
local Screen = require(script.Parent:WaitForChild("Screen"))
local Sfx = require(script.Parent.Parent.Parent:WaitForChild("Core"):WaitForChild("Sfx"))

local Windows = {}

export type Window = {
	frame: Frame,
	list: ScrollingFrame,
	open: () -> (),
	close: () -> (),
	isOpen: () -> boolean,
	reset: (() -> ())?,
	focus: (() -> ())?,
	ownerParent: Instance?,
}

export type WindowOptions = {
	title: string,
	icon: string,
	tint: Color3,
	width: number,
	maxHeight: number,
	anchor: Vector2,
	position: UDim2,
}

-- Sağ kenardaki pencerelerin üstten bırakacağı gerçek piksel: Roblox üst çubuğu + sağ üst oyuncu listesi (6 oyuncuya kadar)
local TOP_RESERVE = 190
local SLIDE_TWEEN = TweenInfo.new(0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local CLOSE_TWEEN = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local SLIDE_DISTANCE = 20 -- açılış/kapanışta kayma payı (px)

local openWindows: { Window } = {}
local layer: ScreenGui? = nil
local layerRoot: Frame? = nil
local inputConnection: RBXScriptConnection? = nil

local function desktop(): boolean
	local viewport = Screen.viewport()
	return UserInputService.MouseEnabled and viewport.X >= 900 and viewport.Y >= 600
end

local function foreground(target: Window)
	local index = table.find(openWindows, target)
	if index then
		table.remove(openWindows, index)
	end
	table.insert(openWindows, target)
	for rank, window in openWindows do
		window.frame.ZIndex = 10 + rank
	end
end

local function host(parent: Instance): Instance
	local screen = if parent:IsA("ScreenGui") then parent else parent:FindFirstAncestorOfClass("ScreenGui")
	if not screen then
		return parent
	end
	if not layer then
		local gui = Instance.new("ScreenGui")
		gui.Name = "Windows"
		gui.ResetOnSpawn = false
		gui.DisplayOrder = 10 -- Bildirimler 20; Roblox ödeme onayı CoreGui'de kalır.
		gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		gui.Parent = screen.Parent
		layer = gui
		layerRoot = Screen.root(gui)
	end
	return layerRoot :: Frame
end

local function listen()
	if inputConnection then
		return
	end
	inputConnection = UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			local gui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
			if gui then
				for _, hit in gui:GetGuiObjectsAtPosition(input.Position.X, input.Position.Y) do
					for _, window in openWindows do
						if window.isOpen() and (hit == window.frame or hit:IsDescendantOf(window.frame)) then
							foreground(window)
							return
						end
					end
				end
			end
		elseif not processed and (input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB) then
			for index = #openWindows, 1, -1 do
				if openWindows[index].isOpen() then
					openWindows[index].close()
					return
				end
			end
		end
	end)
end

-- Başlıklı (ikon + başlık + kapat), kaydırılabilir listeli pencere; açılırken kayarak gelir
function Windows.window(parent: Instance, options: WindowOptions): Window
	-- Pencere arka planı, Global sıralamada düşük ZIndex'li içeriğin önüne geçmesin.
	local screen = if parent:IsA("ScreenGui") then parent else parent:FindFirstAncestorOfClass("ScreenGui")
	if screen and screen:IsA("ScreenGui") then
		screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	end
	local frame = Base.panel(host(parent))
	frame.Name = `Window_{options.title}`
	frame.Active = true
	frame.AnchorPoint = options.anchor
	frame.Position = options.position
	frame.Size = UDim2.new(0, options.width, 0.75, 0)
	frame.Visible = false
	frame.ZIndex = 10
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(options.width, options.maxHeight)
	limit.Parent = frame

	-- Başlık bandı: pencerenin vurgu renginden aşağı doğru sönen renkli şerit
	local band = Instance.new("Frame")
	band.BackgroundColor3 = options.tint or Tokens.Color.Gold
	band.BorderSizePixel = 0
	band.Size = UDim2.new(1, 0, 0, 60)
	band.Parent = frame
	Base.corner(band, Tokens.Radius.Panel)
	local bandFade = Instance.new("UIGradient")
	bandFade.Rotation = 90
	bandFade.Transparency = NumberSequence.new(0.84, 1)
	bandFade.Parent = band

	local header = Instance.new("Frame")
	header.BackgroundTransparency = 1
	header.Position = UDim2.fromOffset(14, 12)
	header.Size = UDim2.new(1, -28, 0, 34)
	header.Parent = frame
	Base.list(header, 10, true)
	Base.iconChip(header, options.icon, 34, options.tint).LayoutOrder = 1
	local title = Base.text(header, options.title, "Title")
	title.AutomaticSize = Enum.AutomaticSize.None
	title.Size = UDim2.new(1, -84, 1, 0)
	title.LayoutOrder = 2

	local divider = Instance.new("Frame")
	divider.Position = UDim2.fromOffset(14, 56)
	divider.Size = UDim2.new(1, -28, 0, 1)
	divider.BackgroundColor3 = Tokens.Color.Stroke
	divider.BackgroundTransparency = 0.9
	divider.BorderSizePixel = 0
	divider.Parent = frame

	local list = Instance.new("ScrollingFrame")
	list.Position = UDim2.fromOffset(10, 66)
	list.Size = UDim2.new(1, -20, 1, -76)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 4
	list.ScrollBarImageColor3 = Tokens.Color.TextMuted
	list.CanvasSize = UDim2.new()
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.Parent = frame
	Base.list(list, 8)
	local listPad = Instance.new("UIPadding")
	listPad.PaddingLeft = UDim.new(0, 4)
	listPad.PaddingRight = UDim.new(0, 10)
	listPad.PaddingTop = UDim.new(0, 2)
	listPad.PaddingBottom = UDim.new(0, 8)
	listPad.Parent = list

	local window: Window
	-- Pencerenin mantıksal durumu: `opened` hemen değişir, çerçeve kapanış animasyonu bitince gizlenir (animasyon sırasında yeniden
	-- aç/kapa tutarlı kalır). `token` eski kapanış animasyonunun yeni açılışı gizlemesini engeller.
	local opened = false
	local token = 0
	local selectedBefore: GuiObject? = nil
	local close: TextButton? = nil
	local targetPosition = options.position
	local dragStart: Vector2? = nil
	local defaultPosition = options.position
	local moved = false
	local animation: Tween? = nil
	local function stopAnimation()
		if animation then
			animation:Cancel()
			animation = nil
		end
	end
	local function bounds(): Vector2
		local root = frame.Parent
		if root and root:IsA("GuiObject") and root.AbsoluteSize.X > 0 then
			return root.AbsoluteSize / Screen.scale()
		end
		return Screen.viewport()
	end
	local function clampPosition(position: UDim2): UDim2
		local viewport = bounds()
		local width, height = frame.Size.X.Offset, frame.Size.Y.Offset
		local x = position.X.Scale * viewport.X + position.X.Offset
		local y = position.Y.Scale * viewport.Y + position.Y.Offset
		return UDim2.fromOffset(
			math.clamp(
				x,
				width * frame.AnchorPoint.X + 12,
				math.max(width * frame.AnchorPoint.X + 12, viewport.X - width * (1 - frame.AnchorPoint.X) - 12)
			),
			math.clamp(
				y,
				height * frame.AnchorPoint.Y + 12,
				math.max(height * frame.AnchorPoint.Y + 12, viewport.Y - height * (1 - frame.AnchorPoint.Y) - 12)
			)
		)
	end
	local function resize(forceDefault: boolean?)
		dragStart = nil
		if not Workspace.CurrentCamera then
			return
		end
		local viewport = Screen.viewport()
		local compact = not desktop()
		frame.AnchorPoint = if compact then Vector2.new(0.5, 0.5) else options.anchor
		defaultPosition = if compact then UDim2.fromScale(0.5, 0.5) else options.position
		local height = math.min(options.maxHeight, math.max(160, viewport.Y - 80))
		-- Sağ kenardaki pencereler Roblox'un sağ üst oyuncu listesinin altında başlar (üstten TOP_RESERVE px ayrılır)
		if not compact and options.anchor.X == 1 then
			local top = TOP_RESERVE / Screen.scale()
			frame.AnchorPoint = Vector2.new(1, 0)
			defaultPosition = UDim2.new(options.position.X.Scale, options.position.X.Offset, 0, top)
			height = math.min(options.maxHeight, math.max(160, viewport.Y - top - 12))
		end
		frame.Size = UDim2.fromOffset(math.min(options.width, math.max(200, viewport.X - 24)), height)
		stopAnimation()
		if compact or forceDefault then
			moved = false
		end
		targetPosition = clampPosition(if moved then targetPosition else defaultPosition)
		frame.Position = targetPosition
		if compact and opened then
			for index = #openWindows, 1, -1 do
				local other = openWindows[index]
				if other.isOpen() then
					if other ~= window then
						window.close()
					end
					break
				end
			end
		end
	end
	local cameraConnection: RBXScriptConnection? = nil
	local function watchCamera()
		if cameraConnection then
			cameraConnection:Disconnect()
		end
		local camera = Workspace.CurrentCamera
		if camera then
			cameraConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(resize)
		end
		resize()
	end
	local cameraChanged = Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera)
	watchCamera()
	window = {
		frame = frame,
		list = list,
		ownerParent = parent,
		reset = function()
			resize(true)
			foreground(window)
		end,
		focus = function()
			foreground(window)
		end,
		open = function()
			if opened then
				foreground(window)
				return
			end
			opened = true
			token += 1
			-- Dar/dokunmatik ekranda tek pencere; masaüstünde mevcut çalışma düzeni korunur.
			if not desktop() then
				for _, other in openWindows do
					if other ~= window then
						other.close()
					end
				end
			end
			selectedBefore = GuiService.SelectedObject
			resize(true)
			foreground(window)
			frame.Visible = true
			Sfx.play("ui_open", 0.04)
			if UserInputService.GamepadEnabled then
				GuiService.SelectedObject = close
			end
			if Players.LocalPlayer:GetAttribute("ReducedMotion") ~= true then
				frame.Position = targetPosition + UDim2.fromOffset(SLIDE_DISTANCE, 0)
				local tween = TweenService:Create(frame, SLIDE_TWEEN, { Position = targetPosition })
				animation = tween
				tween:Play()
			else
				frame.Position = targetPosition
			end
		end,
		close = function()
			if not opened then
				return
			end
			opened = false
			dragStart = nil
			token += 1
			stopAnimation()
			local mine = token
			if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(frame) then
				GuiService.SelectedObject = if selectedBefore and selectedBefore.Parent then selectedBefore else nil
			end
			Sfx.play("ui_close", 0.04)
			if Players.LocalPlayer:GetAttribute("ReducedMotion") == true then
				frame.Visible = false
				return
			end
			-- Açılışın tersi: kısa bir kayma, sonra gizlenir
			local tween = TweenService:Create(
				frame,
				CLOSE_TWEEN,
				{ Position = targetPosition + UDim2.fromOffset(SLIDE_DISTANCE, 0) }
			)
			animation = tween
			tween.Completed:Once(function()
				if token == mine and not opened then
					frame.Visible = false
					frame.Position = targetPosition
				end
			end)
			tween:Play()
		end,
		isOpen = function()
			return opened
		end,
	}

	local closeButton = Controls.closeButton(frame, window.close)
	close = closeButton
	closeButton.AnchorPoint = Vector2.new(1, 0)
	closeButton.Position = UDim2.new(1, -7, 0, 7) -- 44 px dokunma alanı, görünen 30 px daire eskisiyle aynı yerde
	closeButton.ZIndex = 3
	local handle = Instance.new("TextButton")
	handle.Name = "WindowDragHandle"
	handle.Text = ""
	handle.BackgroundTransparency = 1
	handle.AutoButtonColor = false
	handle.Selectable = false
	handle.Size = UDim2.new(1, -58, 0, 56)
	handle.ZIndex = 2
	handle.Parent = frame
	local dragPosition = targetPosition
	handle.InputBegan:Connect(function(input: InputObject)
		if opened and desktop() and input.UserInputType == Enum.UserInputType.MouseButton1 then
			stopAnimation()
			foreground(window)
			dragStart = Vector2.new(input.Position.X, input.Position.Y)
			dragPosition = targetPosition
		end
	end)
	local movement = UserInputService.InputChanged:Connect(function(input: InputObject)
		local start = dragStart
		if start and opened and desktop() and input.UserInputType == Enum.UserInputType.MouseMovement then
			local delta = (Vector2.new(input.Position.X, input.Position.Y) - start) / Screen.scale()
			targetPosition = clampPosition(dragPosition + UDim2.fromOffset(delta.X, delta.Y))
			moved = true
			frame.Position = targetPosition
		end
	end)
	local release = UserInputService.InputEnded:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragStart = nil
		end
	end)
	local unfocus = UserInputService.WindowFocusReleased:Connect(function()
		dragStart = nil
	end)
	table.insert(openWindows, window)
	listen()
	local ownerDestroyed = parent.Destroying:Connect(function()
		frame:Destroy()
	end)
	frame.Destroying:Connect(function()
		stopAnimation()
		movement:Disconnect()
		release:Disconnect()
		unfocus:Disconnect()
		ownerDestroyed:Disconnect()
		if cameraConnection then
			cameraConnection:Disconnect()
		end
		cameraChanged:Disconnect()
		local index = table.find(openWindows, window)
		if index then
			table.remove(openWindows, index)
		end
		if #openWindows == 0 then
			if inputConnection then
				inputConnection:Disconnect()
				inputConnection = nil
			end
			if layer then
				local old = layer
				layer, layerRoot = nil, nil
				old:Destroy()
			end
		end
	end)
	return window
end

-- Ortak açma yolları (menü karosu, kısayol, gamepad, dünya etkileşimi aynı kuralı kullanır):
--   toggle: açıksa kapatır; kapalıysa varsayılan konumunda açar.
--   show:   açıksa konumunu koruyarak öne gelir; kapalıysa açar.
function Windows.toggle(target: Window)
	if target.isOpen() then
		target.close()
	else
		if target.reset then
			target.reset()
		end
		target.open()
	end
end

function Windows.show(target: Window)
	if not target.isOpen() then
		target.open()
	elseif target.focus then
		target.focus()
	end
end

return Windows
