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

local SLIDE_TWEEN = TweenInfo.new(0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

local openWindows: { Window } = {}

-- Başlıklı (ikon + başlık + kapat), kaydırılabilir listeli pencere; açılırken kayarak gelir
function Windows.window(parent: Instance, options: WindowOptions): Window
	-- Pencere arka planı, Global sıralamada düşük ZIndex'li içeriğin önüne geçmesin.
	local screen = if parent:IsA("ScreenGui") then parent else parent:FindFirstAncestorOfClass("ScreenGui")
	if screen and screen:IsA("ScreenGui") then
		screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	end
	local frame = Base.panel(parent)
	frame.AnchorPoint = options.anchor
	frame.Position = options.position
	frame.Size = UDim2.new(0, options.width, 0.75, 0)
	frame.Visible = false
	frame.ZIndex = 10
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(options.width, options.maxHeight)
	limit.Parent = frame

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
	local selectedBefore: GuiObject? = nil
	local close: TextButton? = nil
	local targetPosition = options.position
	local function resize()
		if not Workspace.CurrentCamera then
			return
		end
		local viewport = Screen.viewport()
		local compact = viewport.X < 900 or viewport.Y < 600
		frame.AnchorPoint = if compact then Vector2.new(0.5, 0.5) else options.anchor
		targetPosition = if compact then UDim2.fromScale(0.5, 0.5) else options.position
		frame.Position = targetPosition
		frame.Size = UDim2.fromOffset(
			math.min(options.width, math.max(200, viewport.X - 24)),
			math.min(options.maxHeight, math.max(160, viewport.Y - 80))
		)
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
		open = function()
			if frame.Visible then
				return
			end
			for _, other in openWindows do
				if other ~= window then
					other.close()
				end
			end
			selectedBefore = GuiService.SelectedObject
			resize()
			frame.Visible = true
			Sfx.play("ui_open", 0.04)
			if UserInputService.GamepadEnabled then
				GuiService.SelectedObject = close
			end
			if Players.LocalPlayer:GetAttribute("ReducedMotion") ~= true then
				frame.Position = targetPosition + UDim2.fromOffset(20, 0)
				TweenService:Create(frame, SLIDE_TWEEN, { Position = targetPosition }):Play()
			end
		end,
		close = function()
			if frame.Visible and GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(frame) then
				GuiService.SelectedObject = if selectedBefore and selectedBefore.Parent then selectedBefore else nil
			end
			if frame.Visible then
				Sfx.play("ui_close", 0.04)
			end
			frame.Visible = false
		end,
		isOpen = function()
			return frame.Visible
		end,
	}

	local closeButton = Controls.closeButton(frame, window.close)
	close = closeButton
	closeButton.AnchorPoint = Vector2.new(1, 0)
	closeButton.Position = UDim2.new(1, -14, 0, 14)
	table.insert(openWindows, window)
	local inputConnection = UserInputService.InputBegan:Connect(function(input, processed)
		if
			not processed
			and frame.Visible
			and (input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB)
		then
			window.close()
		end
	end)
	frame.Destroying:Connect(function()
		if cameraConnection then
			cameraConnection:Disconnect()
		end
		cameraChanged:Disconnect()
		inputConnection:Disconnect()
		local index = table.find(openWindows, window)
		if index then
			table.remove(openWindows, index)
		end
	end)
	return window
end

return Windows
