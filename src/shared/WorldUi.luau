--!strict
-- Dünyadaki tabelaların standardı (ekrandaki UiKit'in dünya karşılığı). Sunucu kurar, herkes görür.
--
--  tag  → havada duran etiket (BillboardGui): hap şeklinde koyu panel, solda ikon kutusu, sağda yazı.
--         Boyut stud cinsinden: yakından okunur, uzaklaştıkça küçülür.
--  sign → tahta tabela yüzü (SurfaceGui): solda ikon kutusu, üstte altın başlık, altta krem ana yazı.
--
-- Kurallar UiKit ile aynı: emoji sadece ikon kutusunda, renk ve yazı tipi UiTheme'den.

local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local UiTheme = require(script.Parent:WaitForChild("UiTheme"))

local Color = UiTheme.Color
local Font = UiTheme.Font

local WorldUi = {}

local PAD_Y = 0.14 -- Etiket yüksekliğinin üst+alt boşluğu (oran)
local GAP = 0.25 -- İkon ile yazı arası (yükseklik oranı)

export type TagOptions = {
	text: string,
	icon: string?,
	tint: Color3?,
	widthStuds: number,
	heightStuds: number,
	offset: Vector3?, -- Ekran yönüne göre (StudsOffset)
	worldOffset: Vector3?, -- Dünya eksenine göre (StudsOffsetWorldSpace)
	maxDistance: number?,
}

local function iconChip(parent: Instance, icon: string, tint: Color3?): TextLabel
	local chip = Instance.new("TextLabel")
	chip.Name = "Icon"
	chip.Size = UDim2.fromScale(1, 1)
	chip.SizeConstraint = Enum.SizeConstraint.RelativeYY -- Kare: genişlik = yükseklik
	chip.BackgroundColor3 = tint or Color.SurfaceRaised
	chip.BackgroundTransparency = if tint then 0.6 else 0
	chip.Text = icon
	chip.TextScaled = true
	chip.FontFace = Font.Body
	chip.TextColor3 = Color.Text
	chip.LayoutOrder = 1
	chip.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.28, 0)
	corner.Parent = chip
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0.14, 0)
	pad.PaddingBottom = UDim.new(0.14, 0)
	pad.PaddingLeft = UDim.new(0.14, 0)
	pad.PaddingRight = UDim.new(0.14, 0)
	pad.Parent = chip
	return chip
end

function WorldUi.tag(parent: Instance, name: string, options: TagOptions): BillboardGui
	local w, h = options.widthStuds, options.heightStuds
	local gui = Instance.new("BillboardGui")
	gui.Name = name
	gui.Size = UDim2.fromScale(w, h)
	gui.LightInfluence = 0
	gui.MaxDistance = options.maxDistance or 90
	if options.offset then
		gui.StudsOffset = options.offset
	end
	if options.worldOffset then
		gui.StudsOffsetWorldSpace = options.worldOffset
	end
	gui.Parent = parent

	local pill = Instance.new("Frame")
	pill.Name = "Pill"
	pill.Size = UDim2.fromScale(1, 1)
	pill.BackgroundColor3 = Color.Panel
	pill.BackgroundTransparency = 0.12
	pill.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = pill

	-- Yatay boşluk yükseklikle orantılı olsun diye stud oranından hesaplanır
	local padX = (h * PAD_Y * 1.2) / w
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(PAD_Y, 0)
	pad.PaddingBottom = UDim.new(PAD_Y, 0)
	pad.PaddingLeft = UDim.new(padX, 0)
	pad.PaddingRight = UDim.new(padX * 1.4, 0)
	pad.Parent = pill

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.HorizontalAlignment = if options.icon then Enum.HorizontalAlignment.Left else Enum.HorizontalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = pill

	local contentW = w * (1 - padX * 2.4)
	local contentH = h * (1 - PAD_Y * 2)
	local textWidth = 1
	if options.icon then
		iconChip(pill, options.icon, options.tint)
		local gap = (contentH * GAP) / contentW
		layout.Padding = UDim.new(gap, 0)
		textWidth = 1 - contentH / contentW - gap
	end

	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.fromScale(textWidth, 0.78)
	label.BackgroundTransparency = 1
	label.FontFace = Font.Display
	label.TextScaled = true
	label.TextColor3 = Color.Cream
	label.TextXAlignment = if options.icon then Enum.TextXAlignment.Left else Enum.TextXAlignment.Center
	label.Text = options.text
	label.LayoutOrder = 2
	label.Parent = pill
	return gui
end

-- Etiketin yazısını (ve istenirse ikonunu/rengini) günceller
function WorldUi.setTag(billboard: Instance?, text: string, icon: string?, tint: Color3?)
	local pill = billboard and billboard:FindFirstChild("Pill")
	if not pill then
		return
	end
	local label = pill:FindFirstChild("Text")
	if label and label:IsA("TextLabel") then
		label.Text = text
	end
	local chip = pill:FindFirstChild("Icon")
	if chip and chip:IsA("TextLabel") then
		if icon then
			chip.Text = icon
		end
		if tint then
			chip.BackgroundColor3 = tint
		end
	end
end

export type SignOptions = {
	text: string,
	title: string?,
	icon: string?,
	tint: Color3?,
	textColor: Color3?,
}

-- Tabelanın bir yüzü. Ana yazının adı "Text", başlığın adı "Title" (sonradan güncellenebilir).
function WorldUi.sign(part: BasePart, face: Enum.NormalId, options: SignOptions): SurfaceGui
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.LightInfluence = 0.2
	-- Varsayılan FixedSize 800x600 tuvali yassı tabelaya sıkıştırıp düzeni bozar;
	-- stud başına sabit piksel ile tuval, tabelanın gerçek en-boy oranını alır.
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	gui.Parent = part

	local root = Instance.new("Frame")
	root.Name = "Content"
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundTransparency = 1
	root.Parent = gui
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0.12, 0)
	pad.PaddingBottom = UDim.new(0.12, 0)
	pad.PaddingLeft = UDim.new(0.04, 0)
	pad.PaddingRight = UDim.new(0.04, 0)
	pad.Parent = root

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0.03, 0)
	layout.Parent = root

	if options.icon then
		iconChip(root, options.icon, options.tint or Color.Gold)
	end

	-- İkon kare olduğu için yazı sütununun genişliği yüzün en-boy oranına göre hesaplanır
	local faceW, faceH = part.Size.X, part.Size.Y
	if face == Enum.NormalId.Top or face == Enum.NormalId.Bottom then
		faceH = part.Size.Z
	elseif face == Enum.NormalId.Left or face == Enum.NormalId.Right then
		faceW = part.Size.Z
	end
	local iconFraction = (faceH * 0.76) / (faceW * 0.92)
	local column = Instance.new("Frame")
	column.Name = "Column"
	column.BackgroundTransparency = 1
	column.Size = UDim2.fromScale(if options.icon then math.max(1 - iconFraction - 0.04, 0.3) else 1, 1)
	column.LayoutOrder = 2
	column.Parent = root
	local columnLayout = Instance.new("UIListLayout")
	columnLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	columnLayout.SortOrder = Enum.SortOrder.LayoutOrder
	columnLayout.Parent = column

	local align = if options.icon then Enum.TextXAlignment.Left else Enum.TextXAlignment.Center
	if options.title then
		local title = Instance.new("TextLabel")
		title.Name = "Title"
		title.Size = UDim2.fromScale(1, 0.4)
		title.BackgroundTransparency = 1
		title.FontFace = Font.Display
		title.TextScaled = true
		title.TextColor3 = Color.Gold
		title.TextXAlignment = align
		title.Text = options.title
		title.LayoutOrder = 1
		title.Parent = column
	end

	local text = Instance.new("TextLabel")
	text.Name = "Text"
	text.Size = UDim2.fromScale(1, if options.title then 0.56 else 0.8)
	text.BackgroundTransparency = 1
	text.FontFace = Font.Display
	text.TextScaled = true
	text.TextColor3 = options.textColor or Color.Cream
	text.TextXAlignment = align
	text.Text = options.text
	text.LayoutOrder = 2
	text.Parent = column
	return gui
end

-- Parçanın tüm yüzlerindeki ana yazıyı ("Text") günceller
function WorldUi.setSignText(part: Instance, text: string)
	for _, desc in part:GetDescendants() do
		if desc:IsA("TextLabel") and desc.Name == "Text" and desc:FindFirstAncestorOfClass("SurfaceGui") then
			desc.Text = text
		end
	end
end

-- Client'taki toplama bildirimi de aynı ikon/renk/yazı standardını kullanır.
function WorldUi.floatingMoney(parent: BasePart, text: string, reducedMotion: boolean?): BillboardGui
	local gui = WorldUi.tag(parent, "CollectedMoney", {
		text = text,
		icon = "💰",
		tint = Color.Gold,
		widthStuds = 6,
		heightStuds = 1.6,
		offset = Vector3.new(0, 2, 0),
		maxDistance = 100,
	})
	gui.AlwaysOnTop = true
	local info = TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	if not reducedMotion then
		TweenService:Create(gui, info, { StudsOffset = Vector3.new(0, 7, 0) }):Play()
	end
	for _, descendant in gui:GetDescendants() do
		if descendant:IsA("TextLabel") then
			TweenService:Create(descendant, info, { TextTransparency = 1, BackgroundTransparency = 1 }):Play()
		elseif descendant:IsA("Frame") then
			TweenService:Create(descendant, info, { BackgroundTransparency = 1 }):Play()
		end
	end
	Debris:AddItem(gui, 1.3)
	return gui
end

-- Satın alma / etkileşim balonunu tabela yazısının üstünde göster (yazıyı kapatmaması için).
function WorldUi.configureProximityPrompt(prompt: ProximityPrompt)
	prompt.UIOffset = Vector2.new(0, -92)
end

return WorldUi
