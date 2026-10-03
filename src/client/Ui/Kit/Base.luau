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
	s.Transparency = transparency or 0.9
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
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextSize = Tokens.TextSize[style]
	label.FontFace = if style == "Display" or style == "Title"
		then Tokens.Font.Display
		elseif style == "Heading" then Tokens.Font.Bold
		else Tokens.Font.Body
	label.TextColor3 = color or (if style == "Caption" then Tokens.Color.TextMuted else Tokens.Color.Text)
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
	Base.stroke(f, 0.78)
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
	row.LayoutOrder = order
	row.Parent = parent

	local title = Base.text(row, text, "Heading", Tokens.Color.Gold)
	title.AutomaticSize = Enum.AutomaticSize.None
	title.Size = UDim2.new(1, -60, 1, 0)

	local meta = Base.text(row, "", "Caption")
	meta.AutomaticSize = Enum.AutomaticSize.None
	meta.AnchorPoint = Vector2.new(1, 0)
	meta.Position = UDim2.fromScale(1, 0)
	meta.Size = UDim2.new(0, 60, 1, 0)
	meta.TextXAlignment = Enum.TextXAlignment.Right
	return title, meta
end

return Base
