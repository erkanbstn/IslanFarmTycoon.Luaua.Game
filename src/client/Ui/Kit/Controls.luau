--!strict
-- Etkileşimli bileşenler: düğme, menü karosu, kaydırıcı, kapat düğmesi, rozet, vurgu (pulse).
-- UiKit cephesi bunları birleştirir; bileşenleri `UiKit.<ad>` ile kullan.

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local Sfx = require(script.Parent.Parent.Parent:WaitForChild("Core"):WaitForChild("Sfx"))
local Tokens = require(script.Parent:WaitForChild("Tokens"))
local Base = require(script.Parent:WaitForChild("Base"))

local Controls = {}

export type Variant = "primary" | "warning" | "secondary" | "accent" | "danger" | "disabled" | "owned"

local VARIANT_COLORS: { [string]: Color3 } = {
	primary = Tokens.Color.Green,
	warning = Tokens.Color.Orange,
	secondary = Tokens.Color.SurfaceRaised,
	accent = Tokens.Color.Blue,
	danger = Tokens.Color.Red,
	disabled = Tokens.Color.Disabled,
	owned = Tokens.Color.GreenDark,
}

---------------------------------------------------------------------------
-- Butonlar
---------------------------------------------------------------------------

local PRESS_TWEEN = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

-- Basınca hafifçe küçülüp geri gelsin
local function addPressFeedback(target: GuiButton)
	local scale = Instance.new("UIScale")
	scale.Parent = target
	target.Activated:Connect(function()
		if not target.Active then
			return
		end
		Sfx.play("click", 0.06)
		if Players.LocalPlayer:GetAttribute("ReducedMotion") == true then
			return
		end
		scale.Scale = 0.92
		TweenService:Create(scale, PRESS_TWEEN, { Scale = 1 }):Play()
	end)
end

function Controls.setVariant(target: TextButton, variant: Variant)
	target.BackgroundColor3 = VARIANT_COLORS[variant] or Tokens.Color.SurfaceRaised
	local interactive = variant ~= "disabled" and variant ~= "owned"
	target.Active = interactive
	target.AutoButtonColor = interactive
	target.TextColor3 = if variant == "disabled"
		then Tokens.Color.TextMuted
		elseif variant == "secondary" then Tokens.Color.Text
		else Tokens.Color.OnAccent
end

function Controls.button(parent: Instance, text: string, variant: Variant): TextButton
	local b = Instance.new("TextButton")
	b.Text = text
	b.FontFace = Tokens.Font.Bold
	b.TextSize = Tokens.TextSize.Body
	b.TextWrapped = true
	b.Size = UDim2.fromOffset(104, 36)
	b.Selectable = true
	b.Parent = parent
	Base.corner(b, Tokens.Radius.Button)
	Base.stroke(b, 0.64)
	Controls.setVariant(b, variant)
	addPressFeedback(b)
	return b
end

export type Disclosure = {
	frame: Frame,
	body: Frame,
	button: TextButton,
	setExpanded: (boolean) -> (),
	isExpanded: () -> boolean,
}

-- Açıklamalar ve ikincil işlemler istenince açılır; ana aksiyon dışarıda kalır.
function Controls.disclosure(parent: Instance, order: number, title: string): Disclosure
	local frame = Instance.new("Frame")
	frame.Name = "Disclosure"
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.new(1, 0, 0, 0)
	frame.AutomaticSize = Enum.AutomaticSize.Y
	frame.LayoutOrder = order
	frame.Parent = parent
	Base.list(frame, 6)
	local button = Controls.button(frame, title, "secondary")
	button.Name = "DisclosureToggle"
	button.Size = UDim2.new(1, 0, 0, Tokens.TouchTarget)
	button.AutomaticSize = Enum.AutomaticSize.Y
	Base.padding(button, 8, 6)
	button.LayoutOrder = 0
	button.TextSize = Tokens.TextSize.Button
	local body = Instance.new("Frame")
	body.Name = "DisclosureBody"
	body.BackgroundTransparency = 1
	body.Size = UDim2.new(1, 0, 0, 0)
	body.AutomaticSize = Enum.AutomaticSize.Y
	body.LayoutOrder = 1
	body.Visible = false
	body.Parent = frame
	Base.list(body, 6)
	local expanded = false
	local function setExpanded(value: boolean)
		if expanded == value then
			return
		end
		expanded = value
		body.Visible = value
		button:SetAttribute("Expanded", value)
		Controls.setVariant(button, if value then "accent" else "secondary")
	end
	button.Activated:Connect(function()
		setExpanded(not expanded)
	end)
	return {
		frame = frame,
		body = body,
		button = button,
		setExpanded = setExpanded,
		isExpanded = function(): boolean
			return expanded
		end,
	}
end

-- Yönlendirme vurgusu: hedef düğmenin çevresinde yavaşça yanıp sönen altın çerçeve.
-- Dönen işlev vurguyu açar/kapatır; ReducedMotion açıkken çerçeve sabit kalır.
function Controls.pulse(target: GuiObject): (enabled: boolean) -> ()
	local ring = Instance.new("UIStroke")
	ring.Name = "GuidePulse"
	ring.Color = Tokens.Color.Gold
	ring.Thickness = 3
	ring.Transparency = 0.15
	ring.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	ring.Enabled = false
	ring.Parent = target
	local tween: Tween? = nil
	return function(enabled: boolean)
		if ring.Enabled == enabled then
			return
		end
		ring.Enabled = enabled
		if tween then
			tween:Cancel()
			tween = nil
		end
		ring.Transparency = 0.15
		if enabled and Players.LocalPlayer:GetAttribute("ReducedMotion") ~= true then
			local loop = TweenService:Create(
				ring,
				TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
				{ Transparency = 0.8 }
			)
			tween = loop
			loop:Play()
		end
	end
end

-- Yönlendirme oku: hedef düğmenin yanında zıplayan altın etiket. Ekranın sağ kenarındaki düğmelerde (menü sütunu)
-- etiket sola, diğerlerinde düğmenin altına çıkar. Dönen işlev oku açar/kapatır; ReducedMotion açıkken ok sabit kalır.
function Controls.pointer(target: GuiObject, text: string): (enabled: boolean) -> ()
	local holder = Instance.new("Frame")
	holder.Name = "GuidePointer"
	holder.BackgroundTransparency = 1
	holder.AutomaticSize = Enum.AutomaticSize.XY
	holder.Size = UDim2.fromOffset(0, 0)
	holder.Active = false
	holder.Visible = false
	holder.ZIndex = 20
	holder.Parent = target
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, -6)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = holder

	local arrow = Instance.new("Frame")
	arrow.Name = "Arrow"
	arrow.BackgroundColor3 = Tokens.Color.Gold
	arrow.BorderSizePixel = 0
	arrow.Size = UDim2.fromOffset(14, 14)
	arrow.Rotation = 45
	arrow.ZIndex = 20
	arrow.Parent = holder

	local pill = Instance.new("Frame")
	pill.Name = "Pill"
	pill.BackgroundColor3 = Tokens.Color.Gold
	pill.BorderSizePixel = 0
	pill.AutomaticSize = Enum.AutomaticSize.XY
	pill.Size = UDim2.fromOffset(0, 0)
	pill.ZIndex = 21
	pill.Parent = holder
	Base.corner(pill, Tokens.Radius.Button)
	Base.padding(pill, 10, 5)
	local label = Base.text(pill, text, "Caption", Tokens.Color.OnAccent)
	label.FontFace = Tokens.Font.Bold
	label.AutomaticSize = Enum.AutomaticSize.XY
	label.Size = UDim2.fromOffset(0, 0)
	label.TextWrapped = false
	label.ZIndex = 22

	local tween: Tween? = nil
	return function(enabled: boolean)
		if holder.Visible == enabled then
			return
		end
		holder.Visible = enabled
		if tween then
			tween:Cancel()
			tween = nil
		end
		if not enabled then
			return
		end
		local camera = Workspace.CurrentCamera
		local sideways = camera ~= nil
			and target.AbsolutePosition.X + target.AbsoluteSize.X / 2 > camera.ViewportSize.X * 0.6
		local from: UDim2
		local to: UDim2
		if sideways then
			list.FillDirection = Enum.FillDirection.Horizontal
			list.VerticalAlignment = Enum.VerticalAlignment.Center
			pill.LayoutOrder = 1
			arrow.LayoutOrder = 2
			holder.AnchorPoint = Vector2.new(1, 0.5)
			from = UDim2.new(0, -4, 0.5, 0)
			to = UDim2.new(0, -14, 0.5, 0)
		else
			list.FillDirection = Enum.FillDirection.Vertical
			list.HorizontalAlignment = Enum.HorizontalAlignment.Center
			arrow.LayoutOrder = 1
			pill.LayoutOrder = 2
			holder.AnchorPoint = Vector2.new(0.5, 0)
			from = UDim2.new(0.5, 0, 1, 4)
			to = UDim2.new(0.5, 0, 1, 14)
		end
		holder.Position = from
		if Players.LocalPlayer:GetAttribute("ReducedMotion") ~= true then
			local loop = TweenService:Create(
				holder,
				TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
				{ Position = to }
			)
			tween = loop
			loop:Play()
		end
	end
end

-- Menü karosu: üstte ikon kutusu, altta kısa yazı, sağ üst köşede (klavye varsa) kısayol tuşu.
-- Yazı çevirilerde uzasa da karoya sığsın diye küçülür (TextScaled + üst sınır).
function Controls.menuButton(parent: Instance, icon: string, text: string, tint: Color3, shortcut: string?): TextButton
	local b = Instance.new("TextButton")
	b.Text = ""
	b.Size = UDim2.fromOffset(Tokens.MenuTileSize.X, Tokens.MenuTileSize.Y)
	-- Zemin karonun rengine doğru tonlanır: sıradaki karolar renkten ayırt edilir
	b.BackgroundColor3 = Tokens.Color.Panel:Lerp(tint, 0.12)
	b.BackgroundTransparency = 0
	b.AutoButtonColor = true
	b.Selectable = true
	b.Parent = parent
	Base.corner(b, Tokens.Radius.Card)
	local tileStroke = Base.stroke(b, 0.55)
	tileStroke.Color = tint
	addPressFeedback(b)

	local chip = Base.iconChip(b, icon, 30, tint)
	chip.AnchorPoint = Vector2.new(0.5, 0)
	chip.Position = UDim2.new(0.5, 0, 0, 6)

	local label = Base.text(b, text, "Caption", Tokens.Color.Text)
	label.Name = "Label"
	label.FontFace = Tokens.Font.Bold
	label.AutomaticSize = Enum.AutomaticSize.None
	label.AnchorPoint = Vector2.new(0.5, 1)
	label.Position = UDim2.new(0.5, 0, 1, -4)
	label.Size = UDim2.new(1, -6, 0, 16)
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextWrapped = false
	label.TextScaled = true
	local fit = Instance.new("UITextSizeConstraint")
	fit.MaxTextSize = Tokens.TextSize.Caption
	fit.MinTextSize = 11 -- menü karosu başlığı (en uzunu "Yükseltmeler") karoya sığmalı; genel alt sınır (12) burada fazla büyük
	fit.Parent = label

	if shortcut then
		local key = Instance.new("TextLabel")
		key.Name = "Shortcut"
		key.AnchorPoint = Vector2.new(1, 0)
		key.Position = UDim2.new(1, -4, 0, 4)
		key.Size = UDim2.fromOffset(16, 16)
		key.BackgroundColor3 = Tokens.Color.SurfaceRaised
		key.Text = shortcut
		key.FontFace = Tokens.Font.Bold
		key.TextSize = Tokens.TextSize.Caption
		key.TextColor3 = Tokens.Color.TextMuted
		key.Parent = b
		Base.corner(key, 4)
	end
	return b
end

-- Kaydırıcı (0..1): çizilmiş iz, dolgu ve tutamaç. Fare ve dokunmatikle sürüklenir.
-- Dönen ikinci değer değeri koddan ayarlar (onChanged'i tetiklemez).
function Controls.slider(
	parent: Instance,
	initial: number,
	onChanged: (value: number) -> ()
): (Frame, (value: number) -> ())
	local root = Instance.new("Frame")
	root.BackgroundTransparency = 1
	root.Size = UDim2.new(1, 0, 0, Tokens.TouchTarget)
	root.Parent = parent

	local track = Instance.new("Frame")
	track.AnchorPoint = Vector2.new(0, 0.5)
	track.Position = UDim2.new(0, 11, 0.5, 0)
	track.Size = UDim2.new(1, -22, 0, 8)
	track.BackgroundColor3 = Tokens.Color.SurfaceRaised
	track.BorderSizePixel = 0
	track.Parent = root
	Base.corner(track, 4)

	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(initial, 1)
	fill.BackgroundColor3 = Tokens.Color.Green
	fill.BorderSizePixel = 0
	fill.Parent = track
	Base.corner(fill, 4)

	local knob = Instance.new("Frame")
	knob.AnchorPoint = Vector2.new(0.5, 0.5)
	knob.Position = UDim2.fromScale(initial, 0.5)
	knob.Size = UDim2.fromOffset(22, 22)
	knob.BackgroundColor3 = Tokens.Color.Text
	knob.BorderSizePixel = 0
	knob.Parent = track
	Base.corner(knob, 11)

	local hit = Instance.new("TextButton")
	hit.Text = ""
	hit.BackgroundTransparency = 1
	hit.Size = UDim2.fromScale(1, 1)
	hit.ZIndex = 5
	hit.Parent = root

	local function set(value: number)
		local clamped = math.clamp(value, 0, 1)
		fill.Size = UDim2.fromScale(clamped, 1)
		knob.Position = UDim2.fromScale(clamped, 0.5)
	end
	local function fromInput(position: Vector3): number
		return math.clamp((position.X - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
	end
	local dragging = false
	hit.InputBegan:Connect(function(input: InputObject)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			dragging = true
			local value = fromInput(input.Position)
			set(value)
			onChanged(value)
		end
	end)
	local moved = UserInputService.InputChanged:Connect(function(input: InputObject)
		if
			dragging
			and (
				input.UserInputType == Enum.UserInputType.MouseMovement
				or input.UserInputType == Enum.UserInputType.Touch
			)
		then
			local value = fromInput(input.Position)
			set(value)
			onChanged(value)
		end
	end)
	local ended = UserInputService.InputEnded:Connect(function(input: InputObject)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			if dragging then
				dragging = false
				Sfx.play("click")
			end
		end
	end)
	root.Destroying:Connect(function()
		moved:Disconnect()
		ended:Disconnect()
	end)
	return root, set
end

-- Çizilmiş X ile yuvarlak kapat düğmesi. Görünen daire 30 px, dokunma alanı TouchTarget (44 px).
function Controls.closeButton(parent: Instance, onClose: () -> ()): TextButton
	local b = Instance.new("TextButton")
	b.Name = "Close"
	b.Text = ""
	b.Size = UDim2.fromOffset(Tokens.TouchTarget, Tokens.TouchTarget)
	b.BackgroundTransparency = 1
	b.AutoButtonColor = false
	b.Selectable = true
	b.Parent = parent
	addPressFeedback(b)

	local disc = Instance.new("Frame")
	disc.Name = "Disc"
	disc.AnchorPoint = Vector2.new(0.5, 0.5)
	disc.Position = UDim2.fromScale(0.5, 0.5)
	disc.Size = UDim2.fromOffset(30, 30)
	disc.BackgroundColor3 = Tokens.Color.SurfaceRaised
	disc.Active = false
	disc.Parent = b
	Base.corner(disc, 15)

	for _, angle in { 45, -45 } do
		local line = Instance.new("Frame")
		line.AnchorPoint = Vector2.new(0.5, 0.5)
		line.Position = UDim2.fromScale(0.5, 0.5)
		line.Size = UDim2.fromOffset(14, 2)
		line.Rotation = angle
		line.BackgroundColor3 = Tokens.Color.Text
		line.BorderSizePixel = 0
		line.Parent = disc
		Base.corner(line, 1)
	end

	b.MouseEnter:Connect(function()
		disc.BackgroundColor3 = Tokens.Color.Red
	end)
	b.MouseLeave:Connect(function()
		disc.BackgroundColor3 = Tokens.Color.SurfaceRaised
	end)
	b.Activated:Connect(onClose)
	return b
end

-- Düğmenin köşesinde kırmızı sayı rozeti + altın çerçeve. Dönen fonksiyonla sayı ayarlanır.
function Controls.badge(target: GuiObject): (count: number) -> ()
	local badge = Instance.new("TextLabel")
	badge.Name = "Badge"
	badge.AnchorPoint = Vector2.new(0.5, 0.5)
	badge.Position = UDim2.fromScale(0, 0)
	badge.Size = UDim2.fromOffset(22, 22)
	badge.Active = false -- dokunuş altındaki karoya geçer (karo zaten >= TouchTarget)
	badge.BackgroundColor3 = Tokens.Color.Red
	badge.TextColor3 = Tokens.Color.OnAccent
	badge.FontFace = Tokens.Font.Bold
	badge.TextSize = Tokens.TextSize.Caption
	badge.Visible = false
	badge.ZIndex = 3
	badge.Parent = target
	Base.corner(badge, 11)

	local highlight = Instance.new("UIStroke")
	highlight.Color = Tokens.Color.Gold
	highlight.Thickness = 2
	highlight.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	highlight.Enabled = false
	highlight.Parent = target

	return function(count: number)
		badge.Visible = count > 0
		badge.Text = if count > 9 then "9+" else tostring(count)
		highlight.Enabled = count > 0
	end
end

export type Card = {
	frame: Frame,
	icon: TextLabel,
	title: TextLabel,
	detail: TextLabel,
	action: TextButton,
	status: TextLabel, -- Sağ üstte kırmızı durum yazısı ("Dolu", "Kilitli"): düğme yerine; boşken gizli
}

function Controls.cardDetails(card: Card, title: string): Disclosure
	local details = Controls.disclosure(card.frame, card.action.LayoutOrder + 1, title)
	card.detail.Parent = details.body
	card.detail.LayoutOrder = 0
	card.detail.Size = UDim2.new(1, 0, 0, 0)
	card.detail.AutomaticSize = Enum.AutomaticSize.Y
	return details
end

-- Kartın sağ üst köşesindeki durum yazısı. parent bir düzen (UIListLayout) altındaysa sıfır yükseklikli bir tutucuya konur.
function Controls.statusLabel(parent: Instance): TextLabel
	local label = Base.text(parent, "", "Caption", Tokens.Color.Red)
	label.Name = "Status"
	label.AutomaticSize = Enum.AutomaticSize.Y
	label.Size = UDim2.new(1, 0, 0, 0)
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Right
	label.LayoutOrder = 0
	label.ZIndex = 3
	label.Visible = false
	return label
end

-- Durum kendi satırını kullanır; başlık ve açıklamanın üstüne binmez.
function Controls.setStatus(card: Card, text: string?)
	card.status.Visible = text ~= nil
	if text then
		card.status.Text = text
	end
	card.action.Visible = text == nil
end

-- Liste kartı: ikon kutusu | başlık + açıklama | aksiyon düğmesi
function Controls.card(parent: Instance, order: number, icon: string): Card
	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(1, 0, 0, 0)
	frame.AutomaticSize = Enum.AutomaticSize.Y
	frame.BackgroundColor3 = Tokens.Color.Surface
	frame.LayoutOrder = order
	frame.Parent = parent
	Base.corner(frame, Tokens.Radius.Card)
	Base.stroke(frame, 0.5)
	Base.padding(frame, 12)
	Base.list(frame, 8)
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, 42)
	row.AutomaticSize = Enum.AutomaticSize.Y
	row.LayoutOrder = 1
	row.Parent = frame

	local chip = Base.iconChip(row, icon, 42, Tokens.Color.Gold)

	local texts = Instance.new("Frame")
	texts.BackgroundTransparency = 1
	texts.Position = UDim2.fromOffset(54, 0)
	texts.Size = UDim2.new(1, -54, 0, 0)
	texts.AutomaticSize = Enum.AutomaticSize.Y
	texts.Parent = row
	Base.list(texts, 2)

	local title = Base.text(texts, "", "Heading")
	title.LayoutOrder = 1
	local detail = Base.text(texts, "", "Caption")
	detail.LayoutOrder = 2

	local action = Controls.button(frame, "", "primary")
	action.Size = UDim2.new(1, 0, 0, Tokens.TouchTarget)
	action.AutomaticSize = Enum.AutomaticSize.Y
	Base.padding(action, 8, 6)
	action.LayoutOrder = 2

	local status = Controls.statusLabel(frame)
	return { frame = frame, icon = chip, title = title, detail = detail, action = action, status = status }
end

return Controls
