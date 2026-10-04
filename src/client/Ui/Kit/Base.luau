--!strict
-- Temel bileşenler: yazı, ikon kutusu, panel, liste, çerçeve, girdi, ilerleme çubuğu, bölüm başlığı ve liste kartı.
-- UiKit cephesi bunları birleştirir; bileşenleri `UiKit.<ad>` ile kullan.

local Tokens = require(script.Parent:WaitForChild("Tokens"))

local Base = {}

function Base.colorText(text: string, color: Color3): string
	local escaped = text:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
	return `<font color="#{color:ToHex()}">{escaped}</font>`
end

---------------------------------------------------------------------------
-- Temel yardımcılar
---------------------------------------------------------------------------

function Base.corner(parent: Instance, radius: number): UICorner
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
	return c
end

-- İnce, yarı saydam kenar çizgisi: paneller ve kartlar biraz "kabartmalı" görünsün
function Base.stroke(parent: Instance, transparency: number?): UIStroke
	local s = Instance.new("UIStroke")
	s.Color = Tokens.Color.Stroke
	s.Transparency = transparency or 0.55
	s.Thickness = 1
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

function Base.padding(parent: Instance, x: number, y: number?): UIPadding
	local p = Instance.new("UIPadding")
	p.PaddingLeft = UDim.new(0, x)
	p.PaddingRight = UDim.new(0, x)
	p.PaddingTop = UDim.new(0, y or x)
	p.PaddingBottom = UDim.new(0, y or x)
	p.Parent = parent
	return p
end

-- Form alanı da diğer ekran bileşenleriyle aynı tema kaynağını kullanır.
function Base.textInput(parent: Instance, placeholder: string): TextBox
	local input = Instance.new("TextBox")
	input.Size = UDim2.new(1, 0, 0, 44)
	input.BackgroundColor3 = Tokens.Color.SurfaceRaised
	input.TextColor3 = Tokens.Color.Text
	input.PlaceholderColor3 = Tokens.Color.TextMuted
	input.FontFace = Tokens.Font.Body
	input.TextSize = Tokens.TextSize.Body
	input.Text = ""
	input.PlaceholderText = placeholder
	input.ClearTextOnFocus = false
	input.TextXAlignment = Enum.TextXAlignment.Left
	input.Parent = parent
	Base.corner(input, Tokens.Radius.Button)
	Base.stroke(input, 0.58)
	Base.padding(input, 12, 0)
	return input
end

function Base.list(parent: Instance, gap: number, horizontal: boolean?): UIListLayout
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
function Base.text(parent: Instance, text: string, style: TextStyle, color: Color3?): TextLabel
	-- Açılan ayrıntı ana içeriktir; küçük dipnot stili ve soluk varsayılan renk kullanılmaz.
	local inDetails = parent.Name == "DisclosureBody"
	local resolvedStyle = if inDetails and style == "Caption" then "Body" else style
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextSize = Tokens.TextSize[resolvedStyle]
	label.FontFace = if style == "Display" or style == "Title"
		then Tokens.Font.Display
		elseif style == "Heading" then Tokens.Font.Bold
		else Tokens.Font.Body
	label.TextColor3 = if inDetails and (color == nil or color == Tokens.Color.TextMuted)
		then Tokens.Color.Text
		else color or (if style == "Caption" then Tokens.Color.TextMuted else Tokens.Color.Text)
	if inDetails then
		label.LineHeight = 1.2
	end
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.TextWrapped = true
	label.RichText = true
	label.Size = UDim2.new(1, 0, 0, 0)
	label.AutomaticSize = Enum.AutomaticSize.Y
	label.Parent = parent
	return label
end

-- Sıcak yollarda (her saniye çalışan HUD güncellemeleri) metin aynıysa yazmaz. Localizer çeviriyi
-- Text'e geri yazdığı için ham `label.Text = kaynak` her seferinde değişiklik olayı + çeviri yazımı üretirdi;
-- burada son verilen kaynak metin tutulur (dil değişse de kaynak aynı kaldığı için doğru çalışır).
local lastSource: { [Instance]: string } = setmetatable({}, { __mode = "k" }) :: any

function Base.setText(label: TextLabel | TextButton, text: string)
	if lastSource[label] == text then
		return
	end
	lastSource[label] = text
	local target: any = label
	target.Text = text
end

-- Boş ve tamamlanmış listeler: okunaklı başlık, kısa açıklama ve ortak hizalama.
function Base.emptyState(
	parent: Instance,
	icon: string,
	title: string,
	description: string
): { frame: Frame, title: TextLabel, description: TextLabel }
	local frame = Instance.new("Frame")
	frame.Name = "EmptyState"
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.new(1, 0, 0, 220)
	frame.AutomaticSize = Enum.AutomaticSize.Y
	frame.Parent = parent
	Base.padding(frame, 16, 24)
	local layout = Base.list(frame, 12)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	local chip = Base.iconChip(frame, icon, 52, Tokens.Color.Gold)
	chip.LayoutOrder = 0
	local heading = Base.text(frame, title, "Title")
	heading.TextXAlignment = Enum.TextXAlignment.Center
	heading.LayoutOrder = 1
	local body = Base.text(frame, description, "Body")
	body.TextXAlignment = Enum.TextXAlignment.Center
	body.LayoutOrder = 2
	return { frame = frame, title = heading, description = body }
end

-- Emoji için sabit boyutlu, renkli zeminli ikon kutusu
function Base.iconChip(parent: Instance, icon: string, size: number, tint: Color3?): TextLabel
	local chip = Instance.new("TextLabel")
	chip.Name = "Icon"
	chip.Size = UDim2.fromOffset(size, size)
	chip.BackgroundColor3 = tint or Tokens.Color.SurfaceRaised
	chip.BackgroundTransparency = if tint then 0.82 else 0
	chip.Text = icon
	chip.TextScaled = true
	chip.FontFace = Tokens.Font.Body
	chip.TextColor3 = Tokens.Color.Text
	chip.Parent = parent
	Base.corner(chip, math.floor(size * 0.28))
	Base.padding(chip, math.floor(size * 0.16))
	-- Coin emojisi bazı Roblox yazı tiplerinde Robux işareti olarak çizilir.
	if icon == "🪙" then
		chip.Text = ""
		local coin = Instance.new("Frame")
		coin.Name = "GoldCoin"
		coin.AnchorPoint = Vector2.new(0.5, 0.5)
		coin.Position = UDim2.fromScale(0.5, 0.5)
		coin.Size = UDim2.fromScale(0.76, 0.76)
		coin.BackgroundColor3 = Tokens.Color.GoldLight
		coin.BorderSizePixel = 0
		coin.Parent = chip
		local aspect = Instance.new("UIAspectRatioConstraint")
		aspect.AspectRatio = 1
		aspect.DominantAxis = Enum.DominantAxis.Height
		aspect.Parent = coin
		Base.corner(coin, size)
		local rim = Base.stroke(coin, 0.1)
		rim.Color = Tokens.Color.Gold
		local face = Instance.new("Frame")
		face.Name = "CoinFace"
		face.AnchorPoint = Vector2.new(0.5, 0.5)
		face.Position = UDim2.fromScale(0.5, 0.5)
		face.Size = UDim2.fromScale(0.65, 0.65)
		face.BackgroundTransparency = 1
		face.BorderSizePixel = 0
		face.Parent = coin
		Base.corner(face, size)
		local inner = Base.stroke(face, 0.25)
		inner.Color = Tokens.Color.Gold
	end
	return chip
end

---------------------------------------------------------------------------
-- Paneller, pencereler, kartlar
---------------------------------------------------------------------------

function Base.panel(parent: Instance): Frame
	local f = Instance.new("Frame")
	f.BackgroundColor3 = Tokens.Color.Panel
	f.BackgroundTransparency = 0
	f.Parent = parent
	Base.corner(f, Tokens.Radius.Panel)
	Base.stroke(f, 0.35)
	-- Üstten alta hafif renk geçişi: düz gri yerine canlı, derinlikli yüzey
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(Tokens.Color.Panel, Tokens.Color.Panel:Lerp(Tokens.Color.PreviewMint, 0.14))
	gradient.Rotation = 90
	gradient.Parent = f
	return f
end

-- Dolum çubuğu; dönen fonksiyonla oran ve renk ayarlanır
function Base.progressBar(parent: Instance, height: number): (Frame, (ratio: number, color: Color3) -> ())
	local track = Instance.new("Frame")
	track.Size = UDim2.new(1, 0, 0, height)
	track.BackgroundColor3 = Tokens.Color.SurfaceRaised
	track.Parent = parent
	Base.corner(track, math.floor(height / 2))

	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = Tokens.Color.Green
	fill.Parent = track
	Base.corner(fill, math.floor(height / 2))

	return track,
		function(ratio: number, color: Color3)
			fill.Size = UDim2.fromScale(math.clamp(ratio, 0, 1), 1)
			fill.Visible = ratio > 0
			fill.BackgroundColor3 = color
		end
end

-- Bölüm başlığı: solda başlık, sağda küçük açıklama (ör. "2/3")
function Base.sectionHeader(parent: Instance, text: string, order: number): (TextLabel, TextLabel)
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, 28)
	row.AutomaticSize = Enum.AutomaticSize.Y
	row.LayoutOrder = order
	row.Parent = parent

	local title = Base.text(row, text, "Heading", Tokens.Color.Gold)
	title.AutomaticSize = Enum.AutomaticSize.Y
	title.Size = UDim2.new(1, -60, 0, 28)

	local meta = Base.text(row, "", "Caption")
	meta.AutomaticSize = Enum.AutomaticSize.None
	meta.AnchorPoint = Vector2.new(1, 0)
	meta.Position = UDim2.fromScale(1, 0)
	meta.Size = UDim2.new(0, 60, 0, 28)
	meta.TextXAlignment = Enum.TextXAlignment.Right
	return title, meta
end

return Base
