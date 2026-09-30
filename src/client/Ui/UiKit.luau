--!strict
-- Island Farm Tycoon arayüz standardı: renkler, yazı tipleri, boyutlar ve hazır bileşenler.
-- Tüm arayüz (HUD, Pazar, Yol Haritası, Adalar menüsü) bunu kullanır; yeni UI yazarken de kullan.
--
-- Kurallar:
--  * Emoji SADECE ikon kutusunda (iconChip) kullanılır; buton ve metinlerde emoji yok.
--  * Kapat / bildirim işaretleri font karakteri değil, çizilmiş şekillerdir.
--  * Renk, yazı tipi ve boyutlar aşağıdaki tablolardan seçilir; elle değer yazma.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")

local UiTheme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UiTheme"))
local Sfx = require(script.Parent.Parent:WaitForChild("Core"):WaitForChild("Sfx"))

local UiKit = {}

-- Renk, yazı tipi ve boyutlar dünyadaki tabelalarla ortak: shared/UiTheme
UiKit.Color = UiTheme.Color
UiKit.Font = UiTheme.Font
UiKit.TextSize = UiTheme.TextSize

function UiKit.colorText(text: string, color: Color3): string
	local escaped = text:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
	return `<font color="#{color:ToHex()}">{escaped}</font>`
end

UiKit.Radius = {
	Panel = 14,
	Card = 10,
	Button = 8,
}

export type Variant = "primary" | "warning" | "secondary" | "accent" | "danger" | "disabled" | "owned"

local VARIANT_COLORS: { [string]: Color3 } = {
	primary = UiKit.Color.Green,
	warning = UiKit.Color.Orange,
	secondary = UiKit.Color.SurfaceRaised,
	accent = UiKit.Color.Blue,
	danger = UiKit.Color.Red,
	disabled = UiKit.Color.Disabled,
	owned = UiKit.Color.GreenDark,
}

---------------------------------------------------------------------------
-- Temel yardımcılar
---------------------------------------------------------------------------

function UiKit.corner(parent: Instance, radius: number): UICorner
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
	return c
end

-- İnce, yarı saydam kenar çizgisi: paneller ve kartlar biraz "kabartmalı" görünsün
function UiKit.stroke(parent: Instance, transparency: number?): UIStroke
	local s = Instance.new("UIStroke")
	s.Color = UiKit.Color.Stroke
	s.Transparency = transparency or 0.9
	s.Thickness = 1
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

function UiKit.padding(parent: Instance, x: number, y: number?): UIPadding
	local p = Instance.new("UIPadding")
	p.PaddingLeft = UDim.new(0, x)
	p.PaddingRight = UDim.new(0, x)
	p.PaddingTop = UDim.new(0, y or x)
	p.PaddingBottom = UDim.new(0, y or x)
	p.Parent = parent
	return p
end

-- Form alanı da diğer ekran bileşenleriyle aynı tema kaynağını kullanır.
function UiKit.textInput(parent: Instance, placeholder: string): TextBox
	local input = Instance.new("TextBox")
	input.Size = UDim2.new(1, 0, 0, 44)
	input.BackgroundColor3 = UiKit.Color.SurfaceRaised
	input.TextColor3 = UiKit.Color.Text
	input.PlaceholderColor3 = UiKit.Color.TextMuted
	input.FontFace = UiKit.Font.Body
	input.TextSize = UiKit.TextSize.Body
	input.Text = ""
	input.PlaceholderText = placeholder
	input.ClearTextOnFocus = false
	input.TextXAlignment = Enum.TextXAlignment.Left
	input.Parent = parent
	UiKit.corner(input, UiKit.Radius.Button)
	UiKit.padding(input, 12, 0)
	return input
end

function UiKit.list(parent: Instance, gap: number, horizontal: boolean?): UIListLayout
	local l = Instance.new("UIListLayout")
	l.Padding = UDim.new(0, gap)
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.FillDirection = if horizontal then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical
	if horizontal then
		l.VerticalAlignment = Enum.VerticalAlignment.Center
	end
	l.Parent = parent
	return l
end

export type TextStyle = "Display" | "Title" | "Heading" | "Body" | "Caption"

-- Standart yazı. style boyutu ve yazı tipini belirler; yükseklik otomatik.
function UiKit.text(parent: Instance, text: string, style: TextStyle, color: Color3?): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextSize = UiKit.TextSize[style]
	label.FontFace = if style == "Display" or style == "Title"
		then UiKit.Font.Display
		elseif style == "Heading" then UiKit.Font.Bold
		else UiKit.Font.Body
	label.TextColor3 = color or (if style == "Caption" then UiKit.Color.TextMuted else UiKit.Color.Text)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.TextWrapped = true
	label.RichText = true
	label.Size = UDim2.new(1, 0, 0, 0)
	label.AutomaticSize = Enum.AutomaticSize.Y
	label.Parent = parent
	return label
end

-- Emoji için sabit boyutlu, renkli zeminli ikon kutusu
function UiKit.iconChip(parent: Instance, icon: string, size: number, tint: Color3?): TextLabel
	local chip = Instance.new("TextLabel")
	chip.Name = "Icon"
	chip.Size = UDim2.fromOffset(size, size)
	chip.BackgroundColor3 = tint or UiKit.Color.SurfaceRaised
	chip.BackgroundTransparency = if tint then 0.75 else 0
	chip.Text = icon
	chip.TextScaled = true
	chip.FontFace = UiKit.Font.Body
	chip.TextColor3 = UiKit.Color.Text
	chip.Parent = parent
	UiKit.corner(chip, math.floor(size * 0.28))
	UiKit.padding(chip, math.floor(size * 0.16))
	return chip
end

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

function UiKit.setVariant(target: TextButton, variant: Variant)
	target.BackgroundColor3 = VARIANT_COLORS[variant] or UiKit.Color.SurfaceRaised
	local interactive = variant ~= "disabled" and variant ~= "owned"
	target.Active = interactive
	target.AutoButtonColor = interactive
	target.TextColor3 = if interactive then UiKit.Color.Text else UiKit.Color.TextMuted
end

function UiKit.button(parent: Instance, text: string, variant: Variant): TextButton
	local b = Instance.new("TextButton")
	b.Text = text
	b.FontFace = UiKit.Font.Bold
	b.TextSize = UiKit.TextSize.Body
	b.Size = UDim2.fromOffset(104, 36)
	b.Selectable = true
	b.Parent = parent
	UiKit.corner(b, UiKit.Radius.Button)
	UiKit.setVariant(b, variant)
	addPressFeedback(b)
	return b
end

-- Menü karosu boyutu (HUD menü çubuğu ve Çiftliğim penceresindeki ızgara aynı ölçüyü kullanır)
UiKit.MenuTileSize = Vector2.new(76, 60)

-- Yönlendirme vurgusu: hedef düğmenin çevresinde yavaşça yanıp sönen altın çerçeve.
-- Dönen işlev vurguyu açar/kapatır; ReducedMotion açıkken çerçeve sabit kalır.
function UiKit.pulse(target: GuiObject): (enabled: boolean) -> ()
	local ring = Instance.new("UIStroke")
	ring.Name = "GuidePulse"
	ring.Color = UiKit.Color.Gold
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

-- Menü karosu: üstte ikon kutusu, altta kısa yazı, sağ üst köşede (klavye varsa) kısayol tuşu.
-- Yazı çevirilerde uzasa da karoya sığsın diye küçülür (TextScaled + üst sınır).
function UiKit.menuButton(parent: Instance, icon: string, text: string, tint: Color3, shortcut: string?): TextButton
	local b = Instance.new("TextButton")
	b.Text = ""
	b.Size = UDim2.fromOffset(UiKit.MenuTileSize.X, UiKit.MenuTileSize.Y)
	b.BackgroundColor3 = UiKit.Color.Panel
	b.BackgroundTransparency = 0.1
	b.AutoButtonColor = true
	b.Selectable = true
	b.Parent = parent
	UiKit.corner(b, UiKit.Radius.Card)
	UiKit.stroke(b)
	addPressFeedback(b)

	local chip = UiKit.iconChip(b, icon, 30, tint)
	chip.AnchorPoint = Vector2.new(0.5, 0)
	chip.Position = UDim2.new(0.5, 0, 0, 6)

	local label = UiKit.text(b, text, "Caption", UiKit.Color.Text)
	label.Name = "Label"
	label.FontFace = UiKit.Font.Bold
	label.AutomaticSize = Enum.AutomaticSize.None
	label.AnchorPoint = Vector2.new(0.5, 1)
	label.Position = UDim2.new(0.5, 0, 1, -4)
	label.Size = UDim2.new(1, -6, 0, 16)
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextWrapped = false
	label.TextScaled = true
	local fit = Instance.new("UITextSizeConstraint")
	fit.MaxTextSize = UiKit.TextSize.Caption
	fit.MinTextSize = 8
	fit.Parent = label

	if shortcut then
		local key = Instance.new("TextLabel")
		key.Name = "Shortcut"
		key.AnchorPoint = Vector2.new(1, 0)
		key.Position = UDim2.new(1, -4, 0, 4)
		key.Size = UDim2.fromOffset(16, 16)
		key.BackgroundColor3 = UiKit.Color.SurfaceRaised
		key.Text = shortcut
		key.FontFace = UiKit.Font.Bold
		key.TextSize = UiKit.TextSize.Caption
		key.TextColor3 = UiKit.Color.TextMuted
		key.Parent = b
		UiKit.corner(key, 4)
	end
	return b
end

-- Kaydırıcı (0..1): çizilmiş iz, dolgu ve tutamaç. Fare ve dokunmatikle sürüklenir.
-- Dönen ikinci değer değeri koddan ayarlar (onChanged'i tetiklemez).
function UiKit.slider(
	parent: Instance,
	initial: number,
	onChanged: (value: number) -> ()
): (Frame, (value: number) -> ())
	local root = Instance.new("Frame")
	root.BackgroundTransparency = 1
	root.Size = UDim2.new(1, 0, 0, 34)
	root.Parent = parent

	local track = Instance.new("Frame")
	track.AnchorPoint = Vector2.new(0, 0.5)
	track.Position = UDim2.new(0, 11, 0.5, 0)
	track.Size = UDim2.new(1, -22, 0, 8)
	track.BackgroundColor3 = UiKit.Color.SurfaceRaised
	track.BorderSizePixel = 0
	track.Parent = root
	UiKit.corner(track, 4)

	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(initial, 1)
	fill.BackgroundColor3 = UiKit.Color.Green
	fill.BorderSizePixel = 0
	fill.Parent = track
	UiKit.corner(fill, 4)

	local knob = Instance.new("Frame")
	knob.AnchorPoint = Vector2.new(0.5, 0.5)
	knob.Position = UDim2.fromScale(initial, 0.5)
	knob.Size = UDim2.fromOffset(22, 22)
	knob.BackgroundColor3 = UiKit.Color.Text
	knob.BorderSizePixel = 0
	knob.Parent = track
	UiKit.corner(knob, 11)

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

-- Çizilmiş X ile yuvarlak kapat düğmesi
function UiKit.closeButton(parent: Instance, onClose: () -> ()): TextButton
	local b = Instance.new("TextButton")
	b.Name = "Close"
	b.Text = ""
	b.Size = UDim2.fromOffset(30, 30)
	b.BackgroundColor3 = UiKit.Color.SurfaceRaised
	b.AutoButtonColor = true
	b.Parent = parent
	UiKit.corner(b, 15)
	addPressFeedback(b)

	for _, angle in { 45, -45 } do
		local line = Instance.new("Frame")
		line.AnchorPoint = Vector2.new(0.5, 0.5)
		line.Position = UDim2.fromScale(0.5, 0.5)
		line.Size = UDim2.fromOffset(14, 2)
		line.Rotation = angle
		line.BackgroundColor3 = UiKit.Color.Text
		line.BorderSizePixel = 0
		line.Parent = b
		UiKit.corner(line, 1)
	end

	b.MouseEnter:Connect(function()
		b.BackgroundColor3 = UiKit.Color.Red
	end)
	b.MouseLeave:Connect(function()
		b.BackgroundColor3 = UiKit.Color.SurfaceRaised
	end)
	b.Activated:Connect(onClose)
	return b
end

-- Düğmenin köşesinde kırmızı sayı rozeti + altın çerçeve. Dönen fonksiyonla sayı ayarlanır.
function UiKit.badge(target: GuiObject): (count: number) -> ()
	local badge = Instance.new("TextLabel")
	badge.Name = "Badge"
	badge.AnchorPoint = Vector2.new(0.5, 0.5)
	badge.Position = UDim2.fromScale(0, 0)
	badge.Size = UDim2.fromOffset(20, 20)
	badge.BackgroundColor3 = UiKit.Color.Red
	badge.TextColor3 = UiKit.Color.Text
	badge.FontFace = UiKit.Font.Bold
	badge.TextSize = UiKit.TextSize.Caption
	badge.Visible = false
	badge.ZIndex = 3
	badge.Parent = target
	UiKit.corner(badge, 10)

	local highlight = Instance.new("UIStroke")
	highlight.Color = UiKit.Color.Gold
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

---------------------------------------------------------------------------
-- Bayraklar: Roblox yazı tipleri bayrak emojisini göstermez, bu yüzden şekillerle çizilir (3:2 oran).
---------------------------------------------------------------------------

local function flagPart(
	parent: Instance,
	color: Color3,
	position: Vector2,
	size: Vector2,
	rotation: number?,
	round: boolean?
): Frame
	local part = Instance.new("Frame")
	part.BorderSizePixel = 0
	part.BackgroundColor3 = color
	part.AnchorPoint = Vector2.new(0.5, 0.5)
	part.Position = UDim2.fromScale(position.X, position.Y)
	part.Size = UDim2.fromScale(size.X, size.Y)
	part.Rotation = rotation or 0
	part.Parent = parent
	if round then
		local roundCorner = Instance.new("UICorner")
		roundCorner.CornerRadius = UDim.new(0.5, 0)
		roundCorner.Parent = part
	end
	return part
end

local FLAG_RED_TR = Color3.fromRGB(227, 10, 23)
local FLAG_WHITE = Color3.fromRGB(255, 255, 255)
local FLAG_BLUE_UK = Color3.fromRGB(1, 33, 105)
local FLAG_RED_UK = Color3.fromRGB(200, 16, 46)
local FLAG_DIAGONAL = math.deg(math.atan2(2, 3)) -- 3:2 bayrakta köşegenin açısı

local flagPainters: { [string]: (Frame) -> () } = {
	-- Kırmızı zemin, beyaz hilal (iki daire) ve yıldız (iki döndürülmüş kare)
	tr = function(flag: Frame)
		flag.BackgroundColor3 = FLAG_RED_TR
		flagPart(flag, FLAG_WHITE, Vector2.new(0.36, 0.5), Vector2.new(0.333, 0.5), 0, true)
		flagPart(flag, FLAG_RED_TR, Vector2.new(0.405, 0.5), Vector2.new(0.267, 0.4), 0, true)
		flagPart(flag, FLAG_WHITE, Vector2.new(0.585, 0.5), Vector2.new(0.1, 0.15), 0)
		flagPart(flag, FLAG_WHITE, Vector2.new(0.585, 0.5), Vector2.new(0.1, 0.15), 45)
	end,
	-- Birleşik Krallık bayrağı (Union Jack)
	en = function(flag: Frame)
		flag.BackgroundColor3 = FLAG_BLUE_UK
		flagPart(flag, FLAG_WHITE, Vector2.new(0.5, 0.5), Vector2.new(1.4, 0.2), FLAG_DIAGONAL)
		flagPart(flag, FLAG_WHITE, Vector2.new(0.5, 0.5), Vector2.new(1.4, 0.2), -FLAG_DIAGONAL)
		flagPart(flag, FLAG_RED_UK, Vector2.new(0.5, 0.5), Vector2.new(1.4, 0.07), FLAG_DIAGONAL)
		flagPart(flag, FLAG_RED_UK, Vector2.new(0.5, 0.5), Vector2.new(1.4, 0.07), -FLAG_DIAGONAL)
		flagPart(flag, FLAG_WHITE, Vector2.new(0.5, 0.5), Vector2.new(1, 0.34))
		flagPart(flag, FLAG_WHITE, Vector2.new(0.5, 0.5), Vector2.new(0.227, 1))
		flagPart(flag, FLAG_RED_UK, Vector2.new(0.5, 0.5), Vector2.new(1, 0.2))
		flagPart(flag, FLAG_RED_UK, Vector2.new(0.5, 0.5), Vector2.new(0.133, 1))
	end,
	-- Siyah / kırmızı / altın yatay şeritler
	de = function(flag: Frame)
		flag.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		flagPart(flag, Color3.fromRGB(221, 0, 0), Vector2.new(0.5, 0.5), Vector2.new(1, 0.334))
		flagPart(flag, Color3.fromRGB(255, 206, 0), Vector2.new(0.5, 0.833), Vector2.new(1, 0.334))
	end,
	-- Beyaz / mavi / kırmızı yatay şeritler
	ru = function(flag: Frame)
		flag.BackgroundColor3 = FLAG_WHITE
		flagPart(flag, Color3.fromRGB(0, 57, 166), Vector2.new(0.5, 0.5), Vector2.new(1, 0.334))
		flagPart(flag, Color3.fromRGB(213, 43, 30), Vector2.new(0.5, 0.833), Vector2.new(1, 0.334))
	end,
}

-- Ülke/dil kodundan (tr, en, de, ru) çizilmiş bayrak; genişlik piksel, yükseklik 2/3'ü.
function UiKit.flag(parent: Instance, code: string, width: number): Frame
	local flag = Instance.new("Frame")
	flag.Name = "Flag"
	flag.Size = UDim2.fromOffset(width, math.floor(width * 2 / 3))
	flag.BackgroundColor3 = UiKit.Color.SurfaceRaised
	flag.BorderSizePixel = 0
	flag.ClipsDescendants = true
	flag.Parent = parent
	UiKit.corner(flag, math.max(2, math.floor(width / 10)))
	local paint = flagPainters[code]
	if paint then
		paint(flag)
	end
	UiKit.stroke(flag, 0.6)
	return flag
end

---------------------------------------------------------------------------
-- Paneller, pencereler, kartlar
---------------------------------------------------------------------------

function UiKit.panel(parent: Instance): Frame
	local f = Instance.new("Frame")
	f.BackgroundColor3 = UiKit.Color.Panel
	f.BackgroundTransparency = 0.08
	f.Parent = parent
	UiKit.corner(f, UiKit.Radius.Panel)
	UiKit.stroke(f)
	return f
end

-- Dolum çubuğu; dönen fonksiyonla oran ve renk ayarlanır
function UiKit.progressBar(parent: Instance, height: number): (Frame, (ratio: number, color: Color3) -> ())
	local track = Instance.new("Frame")
	track.Size = UDim2.new(1, 0, 0, height)
	track.BackgroundColor3 = UiKit.Color.SurfaceRaised
	track.Parent = parent
	UiKit.corner(track, math.floor(height / 2))

	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = UiKit.Color.Green
	fill.Parent = track
	UiKit.corner(fill, math.floor(height / 2))

	return track,
		function(ratio: number, color: Color3)
			fill.Size = UDim2.fromScale(math.clamp(ratio, 0, 1), 1)
			fill.Visible = ratio > 0
			fill.BackgroundColor3 = color
		end
end

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
function UiKit.window(parent: Instance, options: WindowOptions): Window
	-- Pencere arka planı, Global sıralamada düşük ZIndex'li içeriğin önüne geçmesin.
	local screen = if parent:IsA("ScreenGui") then parent else parent:FindFirstAncestorOfClass("ScreenGui")
	if screen and screen:IsA("ScreenGui") then
		screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	end
	local frame = UiKit.panel(parent)
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
	UiKit.list(header, 10, true)
	UiKit.iconChip(header, options.icon, 34, options.tint).LayoutOrder = 1
	local title = UiKit.text(header, options.title, "Title")
	title.AutomaticSize = Enum.AutomaticSize.None
	title.Size = UDim2.new(1, -84, 1, 0)
	title.LayoutOrder = 2

	local divider = Instance.new("Frame")
	divider.Position = UDim2.fromOffset(14, 56)
	divider.Size = UDim2.new(1, -28, 0, 1)
	divider.BackgroundColor3 = UiKit.Color.Stroke
	divider.BackgroundTransparency = 0.9
	divider.BorderSizePixel = 0
	divider.Parent = frame

	local list = Instance.new("ScrollingFrame")
	list.Position = UDim2.fromOffset(10, 66)
	list.Size = UDim2.new(1, -20, 1, -76)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 4
	list.ScrollBarImageColor3 = UiKit.Color.TextMuted
	list.CanvasSize = UDim2.new()
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.Parent = frame
	UiKit.list(list, 8)
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
		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end
		local viewport = camera.ViewportSize
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
			frame.Visible = false
		end,
		isOpen = function()
			return frame.Visible
		end,
	}

	local closeButton = UiKit.closeButton(frame, window.close)
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

-- Bölüm başlığı: solda başlık, sağda küçük açıklama (ör. "2/3")
function UiKit.sectionHeader(parent: Instance, text: string, order: number): (TextLabel, TextLabel)
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, 28)
	row.LayoutOrder = order
	row.Parent = parent

	local title = UiKit.text(row, text, "Heading", UiKit.Color.Gold)
	title.AutomaticSize = Enum.AutomaticSize.None
	title.Size = UDim2.new(1, -60, 1, 0)

	local meta = UiKit.text(row, "", "Caption")
	meta.AutomaticSize = Enum.AutomaticSize.None
	meta.AnchorPoint = Vector2.new(1, 0)
	meta.Position = UDim2.fromScale(1, 0)
	meta.Size = UDim2.new(0, 60, 1, 0)
	meta.TextXAlignment = Enum.TextXAlignment.Right
	return title, meta
end

export type Card = {
	frame: Frame,
	icon: TextLabel,
	title: TextLabel,
	detail: TextLabel,
	action: TextButton,
}

-- Liste kartı: ikon kutusu | başlık + açıklama | aksiyon düğmesi
function UiKit.card(parent: Instance, order: number, icon: string): Card
	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(1, 0, 0, 0)
	frame.AutomaticSize = Enum.AutomaticSize.Y
	frame.BackgroundColor3 = UiKit.Color.Surface
	frame.LayoutOrder = order
	frame.Parent = parent
	UiKit.corner(frame, UiKit.Radius.Card)
	UiKit.stroke(frame, 0.94)
	UiKit.padding(frame, 12)
	UiKit.list(frame, 8)
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, 42)
	row.AutomaticSize = Enum.AutomaticSize.Y
	row.LayoutOrder = 1
	row.Parent = frame

	local chip = UiKit.iconChip(row, icon, 42, UiKit.Color.Gold)

	local texts = Instance.new("Frame")
	texts.BackgroundTransparency = 1
	texts.Position = UDim2.fromOffset(54, 0)
	texts.Size = UDim2.new(1, -54, 0, 0)
	texts.AutomaticSize = Enum.AutomaticSize.Y
	texts.Parent = row
	UiKit.list(texts, 2)

	local title = UiKit.text(texts, "", "Heading")
	title.LayoutOrder = 1
	local detail = UiKit.text(texts, "", "Caption")
	detail.LayoutOrder = 2

	local action = UiKit.button(frame, "", "primary")
	action.Size = UDim2.new(1, 0, 0, 40)
	action.LayoutOrder = 2

	return { frame = frame, icon = chip, title = title, detail = detail, action = action }
end

---------------------------------------------------------------------------
-- Bildirimler
---------------------------------------------------------------------------

export type ToastKind = "success" | "error" | "money" | "info"

local TOAST_COLORS: { [string]: Color3 } = {
	success = UiKit.Color.Green,
	error = UiKit.Color.Red,
	money = UiKit.Color.Gold,
	info = UiKit.Color.Blue,
}

-- Bildirim türüne göre çizilmiş işaret: tik, ünlem, para (daire), bilgi (nokta + çizgi)
local function drawToastMark(parent: Frame, kind: string)
	local color = UiKit.Color.Panel
	local function bar(size: Vector2, position: UDim2, rotation: number)
		local f = Instance.new("Frame")
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Size = UDim2.fromOffset(size.X, size.Y)
		f.Position = position
		f.Rotation = rotation
		f.BackgroundColor3 = color
		f.BorderSizePixel = 0
		f.Parent = parent
		UiKit.corner(f, 1)
	end
	if kind == "success" then
		bar(Vector2.new(6, 2), UDim2.new(0.5, -3, 0.5, 2), 45)
		bar(Vector2.new(10, 2), UDim2.new(0.5, 2, 0.5, 0), -50)
	elseif kind == "error" then
		bar(Vector2.new(2, 8), UDim2.new(0.5, 0, 0.5, -2), 0)
		bar(Vector2.new(2, 2), UDim2.new(0.5, 0, 0.5, 5), 0)
	elseif kind == "money" then
		-- Madeni para: içte halka
		local ring = Instance.new("Frame")
		ring.AnchorPoint = Vector2.new(0.5, 0.5)
		ring.Position = UDim2.fromScale(0.5, 0.5)
		ring.Size = UDim2.fromOffset(12, 12)
		ring.BackgroundTransparency = 1
		ring.Parent = parent
		UiKit.corner(ring, 6)
		local line = Instance.new("UIStroke")
		line.Color = color
		line.Thickness = 2
		line.Parent = ring
	else
		bar(Vector2.new(2, 2), UDim2.new(0.5, 0, 0.5, -4), 0)
		bar(Vector2.new(2, 7), UDim2.new(0.5, 0, 0.5, 2), 0)
	end
end

-- Ekranın üst ortasında bildirim yığını. Dönen fonksiyonla bildirim gösterilir.
function UiKit.toastHost(parent: Instance): (message: string, kind: string?) -> ()
	local holder = Instance.new("Frame")
	holder.Name = "Toasts"
	holder.AnchorPoint = Vector2.new(0.5, 0)
	holder.Position = UDim2.new(0.5, 0, 0, 12)
	holder.Size = UDim2.new(1, -24, 0, 0)
	holder.AutomaticSize = Enum.AutomaticSize.Y
	holder.ZIndex = 30
	local widthLimit = Instance.new("UISizeConstraint")
	widthLimit.MaxSize = Vector2.new(460, 10000)
	widthLimit.Parent = holder
	holder.BackgroundTransparency = 1
	holder.Parent = parent
	local layout = UiKit.list(holder, 6)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center

	local counter = 0
	return function(message: string, kind: string?)
		local resolvedKind = if kind and TOAST_COLORS[kind] then kind else "info"
		counter += 1

		-- CanvasGroup: tüm bildirim (işaret dahil) tek parça halinde solar
		local toast = Instance.new("CanvasGroup")
		toast.Size = UDim2.new(1, 0, 0, 40)
		toast.AutomaticSize = Enum.AutomaticSize.Y
		toast.BackgroundColor3 = UiKit.Color.Panel
		toast.BackgroundTransparency = 0.05
		toast.LayoutOrder = counter
		toast.Parent = holder
		UiKit.corner(toast, 19)
		local accent = UiKit.stroke(toast, 0.4)
		accent.Color = TOAST_COLORS[resolvedKind]
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0, 8)
		pad.PaddingRight = UDim.new(0, 16)
		pad.PaddingTop = UDim.new(0, 8)
		pad.PaddingBottom = UDim.new(0, 8)
		pad.Parent = toast
		UiKit.list(toast, 10, true)

		local mark = Instance.new("Frame")
		mark.Size = UDim2.fromOffset(24, 24)
		mark.BackgroundColor3 = TOAST_COLORS[resolvedKind]
		mark.LayoutOrder = 1
		mark.Parent = toast
		UiKit.corner(mark, 12)
		drawToastMark(mark, resolvedKind)

		local label = UiKit.text(toast, message, "Body")
		label.AutomaticSize = Enum.AutomaticSize.Y
		label.Size = UDim2.new(1, -34, 0, 24)
		label.TextWrapped = true
		label.FontFace = UiKit.Font.Bold
		label.LayoutOrder = 2

		-- En fazla 4 bildirim
		local toasts = {}
		for _, child in holder:GetChildren() do
			if child:IsA("CanvasGroup") then
				table.insert(toasts, child)
			end
		end
		if #toasts > 4 then
			table.sort(toasts, function(a, b)
				return a.LayoutOrder < b.LayoutOrder
			end)
			toasts[1]:Destroy()
		end

		task.delay(2.6, function()
			if not toast.Parent then
				return
			end
			TweenService:Create(toast, TweenInfo.new(0.35), { GroupTransparency = 1 }):Play()
			task.wait(0.35)
			toast:Destroy()
		end)
	end
end

return UiKit
