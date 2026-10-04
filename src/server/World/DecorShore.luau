--!strict
-- Kıyı ve deniz: Terrain kayalık, kum plaj, kıyı kayaları, iskele direği ve iskele.
-- WorldDecor cephesi bunları birleştirir; her zaman `WorldDecor.<ad>` ile kullan.

local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")
local ModelAssets = require(script.Parent:WaitForChild("ModelAssets"))

local Shore = {}

local function terrain(): Terrain
	return Workspace.Terrain
end

-- Ada kıyısı: kum plaj PARÇA halkası (çimenin 1 stud altında) + su altında Terrain kayalık gövde.
-- Terrain yüzeyi 4 stud'luk ızgarada öngörülemez şekilde yukarı yuvarlandığı için ada yüzeyine yakın
-- hiçbir yerde Terrain kullanılmaz; kayalık gövdenin üstü suyun iyice altındadır.
-- withTerrain = false: Terrain zaten kayıtlı haritada duruyor; yalnızca kum plaj parçası kurulur (çalışma anında yeniden kurulum).
function Shore.terrainIsland(
	parent: Instance,
	center: Vector3,
	radius: number,
	surfaceY: number,
	beach: number,
	withTerrain: boolean?
)
	local base = Vector3.new(center.X, 0, center.Z)
	if withTerrain ~= false then
		terrain():FillCylinder(CFrame.new(base + Vector3.new(0, -14, 0)), 16, radius + beach - 1, Enum.Material.Rock)
	end

	local sandTop = surfaceY - 1
	local sandBottom = -2
	local sand = ModelAssets.part("SurfaceModels", "BeachDisc")
	sand.Size = Vector3.new(sandTop - sandBottom, (radius + beach) * 2, (radius + beach) * 2)
	sand.CFrame = CFrame.new(base + Vector3.new(0, (sandTop + sandBottom) / 2, 0)) * sand.CFrame.Rotation
	sand.Parent = parent
end

-- Kıyıya yarı gömülü kayalar. angles: adanın yerel açıları (derece, 0 = +Z)
function Shore.shoreRocks(islandCf: CFrame, radius: number, angles: { number }, seed: number)
	local random = Random.new(seed)
	for _, angle in angles do
		local a = math.rad(angle)
		local distance = radius + random:NextNumber(1, 5)
		local position = (islandCf * CFrame.new(math.sin(a) * distance, 0, math.cos(a) * distance)).Position
		terrain():FillBall(position, random:NextNumber(3, 4.5), Enum.Material.Rock)
	end
end

local FOLDER = "ShoreModels"
local missingWarned: { [string]: boolean } = {}

local function warnMissing(name: string)
	if not missingWarned[name] then
		missingWarned[name] = true
		warn(`[DecorShore] assets/{FOLDER}/{name}.rbxmx bulunamadı; çizilmedi`)
	end
end

-- Kazık üstü tahtanın içinde, altı deniz tabanının içinde kalır; su altında havada bitmez.
-- Hazır kazık modeli (assets/ShoreModels/Pile: tek silindir) alınır, boyu yerleşime göre ayarlanır.
function Shore.pierPile(parent: Instance, position: Vector3, surfaceY: number, seabedY: number): Part?
	local top, bottom = surfaceY - 0.3, seabedY - 0.5
	assert(top > bottom, "İskele tabanı yürüyüş yüzeyinden aşağıda olmalı.")
	local template = ModelAssets.clone(FOLDER, "Pile")
	local found = if template then template:FindFirstChildWhichIsA("BasePart") else nil
	if not found or not found:IsA("Part") then
		warnMissing("Pile")
		if template then
			template:Destroy()
		end
		return nil
	end
	local pile = found
	local rotation = pile.CFrame.Rotation
	-- Silindirin ekseni X'tir (dikey durur): uzunluk X'te
	pile.Size = Vector3.new(top - bottom, pile.Size.Y, pile.Size.Z)
	pile.CFrame = CFrame.new(position.X, (top + bottom) / 2, position.Z) * rotation
	-- Kazık katıdır (yüzenler/tekne içinden geçmesin) ve sorgulanabilir; model yalnızca geometri taşır
	pile.CanCollide, pile.CanQuery, pile.CanTouch = true, true, false
	pile:SetAttribute("SeabedY", seabedY)
	pile.Parent = parent
	if template then
		template:Destroy()
	end
	return pile
end

-- Adanın kenarından denize uzanan iskele: güverte modülleri (DockDeck_5) uç uca, altında kazıklar, ucunda fıçı + olta (DockTip),
-- başında balıkçı kulübesi (FisherHut_Lv1). surfaceY yürünebilir üst yüzeydir, parçanın merkezi değil.
function Shore.dock(parent: Instance, start: CFrame, length: number, surfaceY: number, seabedY: number)
	local model = Instance.new("Model")
	model.Name = "Dock"
	model.Parent = parent
	local function at(offset: CFrame, y: number): CFrame
		local world = start * offset
		return CFrame.new(world.Position.X, y, world.Position.Z) * world.Rotation
	end

	-- Güverte: 5 stud'luk modüller; sondaki modülün boyu kalan uzunluğa ayarlanır
	local full = math.floor(length / 5)
	local rest = length - full * 5
	local function layDeck(zStart: number, size: number)
		local deck = ModelAssets.clone(FOLDER, "DockDeck_5")
		if not deck then
			warnMissing("DockDeck_5")
			return
		end
		local board = deck:FindFirstChild("Deck")
		if board and board:IsA("BasePart") then
			board.Size = Vector3.new(board.Size.X, board.Size.Y, size)
			board:SetAttribute("WalkSurfaceY", surfaceY)
		end
		deck:PivotTo(at(CFrame.new(0, 0, -(zStart + size / 2)), surfaceY - 0.3)) -- PrimaryPart (Deck) merkezi pivottur
		for _, child in deck:GetChildren() do
			child.Parent = model
		end
		deck:Destroy()
	end
	for i = 0, full - 1 do
		layDeck(i * 5, 5)
	end
	if rest > 0.05 then
		layDeck(full * 5, rest)
	end

	local segments = math.max(1, math.ceil(length / 5))
	for i = 0, segments do
		for _, x in { -2.6, 2.6 } do
			local z = -(0.8 + (length - 1.6) * i / segments)
			local pos = (start * CFrame.new(x, 0, z)).Position
			Shore.pierPile(model, pos, surfaceY, seabedY)
		end
	end

	-- İskele başında küçük balıkçı kulübesi: balık kafesi geliştirilince belirir (DecorReveal: RevealZoneId/RevealZoneLevel).
	-- Modelin kendi kazıkları atılır; kazıklar deniz tabanına göre burada yeniden kurulur.
	local hut = ModelAssets.clone(FOLDER, "FisherHut_Lv1")
	if hut then
		for _, child in hut:GetChildren() do
			if child.Name == "Pile" then
				child:Destroy()
			end
		end
		hut:PivotTo(at(CFrame.new(5.8, 0, -8), surfaceY + 0.04)) -- model pivotu yüzeyin 0.04 üstündedir
		hut.Name = "FisherHut"
		hut:SetAttribute("RevealZoneId", "fishpen")
		hut:SetAttribute("RevealZoneLevel", 1)
		CollectionService:AddTag(hut, "RevealGate")
		ModelAssets.eachNamed(hut, { "HutLantern" }, ModelAssets.markLantern)
		hut.Parent = model
		local hutBase = start * CFrame.new(5.8, 0, -8)
		for _, corner in { Vector2.new(-2.2, -2), Vector2.new(2.2, -2), Vector2.new(-2.2, 2), Vector2.new(2.2, 2) } do
			Shore.pierPile(hut, (hutBase * CFrame.new(corner.X, 0, corner.Y)).Position, surfaceY, seabedY)
		end
	else
		warnMissing("FisherHut_Lv1")
	end

	-- İskele kenarında (kulübenin karşı yanında, yürüyüş yolunu açık bırakarak) ağ askısı ve balık sandıkları: yalnızca süs
	local function placeDeckProp(name: string, offset: CFrame)
		local prop = ModelAssets.clone(FOLDER, name)
		if not prop then
			warnMissing(name)
			return
		end
		prop:PivotTo(at(offset, surfaceY))
		prop.Parent = model
	end
	if length > 18 then
		placeDeckProp("NetDryingRack", CFrame.new(-2.45, 0, -11) * CFrame.Angles(0, math.rad(90), 0))
		placeDeckProp("FishCrates", CFrame.new(2.0, 0, -16.5) * CFrame.Angles(0, math.rad(90), 0))
	end

	-- İskele ucu: fıçı ve olta
	local tip = ModelAssets.clone(FOLDER, "DockTip")
	if tip then
		tip:PivotTo(at(CFrame.new(0, 0, -length + 2), surfaceY))
		tip.Parent = model
	else
		warnMissing("DockTip")
	end
end

return Shore
