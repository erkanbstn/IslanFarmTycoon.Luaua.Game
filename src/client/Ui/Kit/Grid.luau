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

export type TileOptions = {
	compact: boolean?,
}

-- Karoların dizildiği kap (yüksekliği içeriğe göre büyür); içine `Grid.tile` konur.
-- compact: aksiyonsuz, alçak karolar için. cellWidth/cellHeight verilirse karo boyutu onlardır (ör. 2 sütunlu yükseltme ızgarası).
function Grid.grid(parent: Instance, order: number, compact: boolean?, cellWidth: number?, cellHeight: number?): Frame
	local host = Instance.new("Frame")
	host.BackgroundTransparency = 1
	host.Size = UDim2.new(1, 0, 0, 0)
	host.AutomaticSize = Enum.AutomaticSize.Y
	host.LayoutOrder = order
	host.Parent = parent
	local layout = Instance.new("UIGridLayout")
	layout.CellSize =
		UDim2.fromOffset(cellWidth or TILE_WIDTH, cellHeight or (if compact then COMPACT_TILE_HEIGHT else TILE_HEIGHT))
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
function Grid.tile(
	parent: Instance,
	order: number,
	icon: string,
	compact: boolean?,
	detailHeight: number?
): Controls.Card
	local frame = Instance.new("Frame")
	frame.BackgroundColor3 = Tokens.Color.Surface
	frame.LayoutOrder = order
	frame.Parent = parent
	Base.corner(frame, Tokens.Radius.Card)
	Base.stroke(frame, 0.94)
	Base.padding(frame, 8)
	local layout = Base.list(frame, 4)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center

	local statusHolder = Instance.new("Frame")
	statusHolder.Name = "StatusHolder"
	statusHolder.BackgroundTransparency = 1
	statusHolder.Size = UDim2.new(1, 0, 0, 0)
	statusHolder.LayoutOrder = 0
	statusHolder.Parent = frame
	local status = Controls.statusLabel(statusHolder)
	local chip = Base.iconChip(frame, icon, 38, Tokens.Color.Gold)
	chip.LayoutOrder = 1
	local title = caption(frame, 30, 13, true, 2)
	local detail = caption(frame, detailHeight or (if compact then 30 else 88), 12, false, 3)
	local action = Controls.button(frame, "", "primary")
	action.Size = UDim2.new(1, 0, 0, 30)
	action.TextSize = Tokens.TextSize.Button
	action.LayoutOrder = 4
	return { frame = frame, icon = chip, title = title, detail = detail, action = action, status = status }
end

-- Esnek ızgara: karolar sütun sayısına göre pencere genişliğini paylaşır, yükseklikleri içeriğe göre büyür (sarmalı satırlar).
-- Sabit karo boyutu gerektirmediği için uzun yazılı ve ek düğmeli kartlar da (yükseltme, yol haritası, dükkân) sığar.
function Grid.autoGrid(parent: Instance, order: number, columns: number?): Frame
	local host = Instance.new("Frame")
	host.BackgroundTransparency = 1
	host.Size = UDim2.new(1, 0, 0, 0)
	host.AutomaticSize = Enum.AutomaticSize.Y
	host.LayoutOrder = order
	host:SetAttribute("Columns", columns or 2)
	host.Parent = parent
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Wraps = true
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	layout.VerticalAlignment = Enum.VerticalAlignment.Top
	layout.Padding = UDim.new(0, GAP)
	layout.Parent = host
	return host
end

local function autoCaption(parent: Instance, size: number, bold: boolean, order: number): TextLabel
	local label = Base.text(parent, "", "Caption", if bold then Tokens.Color.Text else nil)
	if bold then
		label.FontFace = Tokens.Font.Bold
	end
	label.TextSize = size
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.TextWrapped = true
	label.AutomaticSize = Enum.AutomaticSize.Y
	label.Size = UDim2.new(1, 0, 0, 0)
	label.LayoutOrder = order
	return label
end

-- Esnek karo (Card ile aynı alanlar): üstte ikon, başlık, açıklama (satır sayısı kadar uzar), altta aksiyon düğmesi.
function Grid.autoTile(grid: Frame, order: number, icon: string, options: TileOptions?): Controls.Card
	local compact = options ~= nil and options.compact == true
	local columns = (grid:GetAttribute("Columns") :: number?) or 2
	local frame = Instance.new("Frame")
	frame.BackgroundColor3 = Tokens.Color.Surface
	frame.LayoutOrder = order
	frame.Size = UDim2.new(1 / columns, -math.ceil(GAP * (columns - 1) / columns) - 1, 0, 0)
	frame.AutomaticSize = Enum.AutomaticSize.Y
	frame.Parent = grid
	Base.corner(frame, Tokens.Radius.Card)
	Base.stroke(frame, 0.94)
	Base.padding(frame, if compact then 6 else 8)
	local layout = Base.list(frame, if compact then 3 else 4)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center

	local statusHolder = Instance.new("Frame")
	statusHolder.Name = "StatusHolder"
	statusHolder.BackgroundTransparency = 1
	statusHolder.Size = UDim2.new(1, 0, 0, 0)
	statusHolder.LayoutOrder = 0
	statusHolder.Parent = frame
	local status = Controls.statusLabel(statusHolder)
	local chip = Base.iconChip(frame, icon, if compact then 42 else 34, Tokens.Color.Gold)
	chip.LayoutOrder = 1
	local title = autoCaption(frame, if compact then Tokens.TextSize.Caption else 13, true, 2)
	local detail = autoCaption(frame, if compact then Tokens.TextSize.Caption else 12, false, 3)
	local action = Controls.button(frame, "", "primary")
	action.Size = UDim2.new(1, 0, 0, if compact then Tokens.TouchTarget else 30)
	action.TextSize = Tokens.TextSize.Button
	action.LayoutOrder = 4
	return { frame = frame, icon = chip, title = title, detail = detail, action = action, status = status }
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
		button.TextSize = Tokens.TextSize.Tab
		button.AutoButtonColor = true
		button.AutomaticSize = Enum.AutomaticSize.X
		button.Size = UDim2.fromOffset(0, 38)
		button.LayoutOrder = index
		button.Selectable = true
		button.Parent = row
		Base.corner(button, Tokens.Radius.Button)
		Base.padding(button, 14, 0)
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
