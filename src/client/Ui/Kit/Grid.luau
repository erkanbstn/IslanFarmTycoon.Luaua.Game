--!strict
-- Izgara düzeni: kategori sekmeleri ve sıkı karolar. Uzun dikey listeler yerine çok sayıda öğeyi yan yana gösterir.
-- Karo, `UiKit.card` ile aynı alanlara (frame, icon, title, detail, action) sahiptir; bu yüzden kart kodu karoyla aynen çalışır.
-- UiKit cephesi bunları birleştirir; bileşenleri `UiKit.<ad>` ile kullan.

local Tokens = require(script.Parent:WaitForChild("Tokens"))
local Base = require(script.Parent:WaitForChild("Base"))
local Controls = require(script.Parent:WaitForChild("Controls"))

local Grid = {}

local TILE_WIDTH = 108
local TILE_HEIGHT = 214
local COMPACT_TILE_HEIGHT = 124 -- aksiyon düğmesiz karolar (ör. ahır deposu)
local GAP = 8

-- Karoların dizildiği kap (yüksekliği içeriğe göre büyür); içine `Grid.tile` konur.
-- compact: aksiyonsuz, alçak karolar için.
function Grid.grid(parent: Instance, order: number, compact: boolean?): Frame
	local host = Instance.new("Frame")
	host.BackgroundTransparency = 1
	host.Size = UDim2.new(1, 0, 0, 0)
	host.AutomaticSize = Enum.AutomaticSize.Y
	host.LayoutOrder = order
	host.Parent = parent
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.fromOffset(TILE_WIDTH, if compact then COMPACT_TILE_HEIGHT else TILE_HEIGHT)
	layout.CellPadding = UDim2.fromOffset(GAP, GAP)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	layout.Parent = host
	return host
end

local function caption(parent: Instance, height: number, size: number, bold: boolean, order: number): TextLabel
	local label = Base.text(parent, "", "Caption", if bold then Tokens.Color.Text else nil)
	if bold then
		label.FontFace = Tokens.Font.Bold
	end
	label.TextSize = size
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.AutomaticSize = Enum.AutomaticSize.None
	label.Size = UDim2.new(1, 0, 0, height)
	label.LayoutOrder = order
	return label
end

-- Karo: üstte ikon, altında başlık ve kısa açıklama, en altta tek aksiyon düğmesi.
function Grid.tile(parent: Instance, order: number, icon: string, compact: boolean?): Controls.Card
	local frame = Instance.new("Frame")
	frame.BackgroundColor3 = Tokens.Color.Surface
	frame.LayoutOrder = order
	frame.Parent = parent
	Base.corner(frame, Tokens.Radius.Card)
	Base.stroke(frame, 0.94)
	Base.padding(frame, 8)
	local layout = Base.list(frame, 4)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center

	local chip = Base.iconChip(frame, icon, 38, Tokens.Color.Gold)
	chip.LayoutOrder = 1
	local title = caption(frame, 30, 13, true, 2)
	local detail = caption(frame, if compact then 30 else 88, 12, false, 3)
	local action = Controls.button(frame, "", "primary")
	action.Size = UDim2.new(1, 0, 0, 30)
	action.TextSize = 13
	action.LayoutOrder = 4
	return { frame = frame, icon = chip, title = title, detail = detail, action = action }
end

-- Kategori sekmeleri: biri seçiliyken diğerleri soluk; tıklanınca onSelect(id) çağrılır.
-- Dönen ikinci işlev seçimi koddan değiştirir (onSelect'i tetiklemez).
function Grid.tabs(
	parent: Instance,
	order: number,
	entries: { { id: string, label: string } },
	onSelect: (id: string) -> ()
): (Frame, (id: string) -> ())
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, 0)
	row.AutomaticSize = Enum.AutomaticSize.Y
	row.LayoutOrder = order
	row.Parent = parent
	local layout = Base.list(row, 6, true)
	layout.Wraps = true
	layout.VerticalAlignment = Enum.VerticalAlignment.Top

	local buttons: { [string]: TextButton } = {}
	local function choose(id: string)
		for buttonId, button in buttons do
			local active = buttonId == id
			button.BackgroundColor3 = if active then Tokens.Color.Gold else Tokens.Color.SurfaceRaised
			button.TextColor3 = if active then Tokens.Color.Panel else Tokens.Color.Text
		end
	end
	for index, entry in entries do
		local button = Instance.new("TextButton")
		button.Text = entry.label
		button.FontFace = Tokens.Font.Bold
		button.TextSize = 13
		button.AutoButtonColor = true
		button.AutomaticSize = Enum.AutomaticSize.X
		button.Size = UDim2.fromOffset(0, 30)
		button.LayoutOrder = index
		button.Selectable = true
		button.Parent = row
		Base.corner(button, Tokens.Radius.Button)
		Base.padding(button, 12, 0)
		buttons[entry.id] = button
		button.Activated:Connect(function()
			choose(entry.id)
			onSelect(entry.id)
		end)
	end
	if entries[1] then
		choose(entries[1].id)
	end
	return row, choose
end

return Grid
