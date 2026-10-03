--!strict
-- Uzman ada yapıları için ortak renkler ve yapı taşları (parça, tabela, yüzey).

local CollectionService = game:GetService("CollectionService")

-- Studio harita eklentisi modülleri kopyalayıp çalıştırır; Shared araması SharedRef'te (kopyadaki Shared'ı bulur).
local Shared = require(script.Parent:WaitForChild("SharedRef")) :: typeof(game.ReplicatedStorage.Shared)
local WorldUi = require(Shared:WaitForChild("WorldUi"))
local ModelAssets = require(script.Parent:WaitForChild("ModelAssets"))

local WOOD = Color3.fromRGB(131, 93, 58)
local CREAM = Color3.fromRGB(235, 224, 192)
local STRAW = Color3.fromRGB(210, 180, 92)
local ROCK = Color3.fromRGB(121, 121, 113)

local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material
): Part
	local p = Instance.new("Part")
	p.Name, p.Size, p.CFrame, p.Color, p.Material = name, size, cf, color, material
	p.Anchored, p.CanTouch = true, false
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- Tabela: hazır model (assets/SignModels/SpecialtySign: SpecialtySign tahtası + SpecialtyPost direği), parçalar doğrudan `parent`
-- içine konur. Yazı ve ikon kodla eklenir; `boardName` verilirse tahtanın adı o olur (ör. satılık eklenti tabelası).
local signWarned = false
local function sign(parent: Instance, cf: CFrame, title: string, icon: string, boardName: string?, text: string?)
	local model = ModelAssets.clone("SignModels", "SpecialtySign")
	if not model then
		if not signWarned then
			signWarned = true
			warn("[IslandSiteParts] assets/SignModels/SpecialtySign.rbxmx bulunamadı; tabela çizilmedi")
		end
		return
	end
	model:PivotTo(cf)
	local board = model:FindFirstChild("SpecialtySign")
	if board and board:IsA("BasePart") then
		if boardName then
			board.Name = boardName
		end
		WorldUi.sign(
			board,
			Enum.NormalId.Front,
			{ title = if text then title else nil, text = text or title, icon = icon }
		)
	end
	for _, child in model:GetChildren() do
		child.Parent = parent
	end
	model:Destroy()
end

-- Hayvanların içinden geçmemesi gereken katı küçük dekor parçaları ("AnimalObstacle" etiketi); AnimalAnimator hedef seçerken bunları atlar.
-- Zemin kaplamaları, yollar, teraslar ve çatılar (hayvan altından geçer) etiketlenmez.
local OBSTACLE_NAMES = {
	WaterTrough = true,
	HayBale = true,
	ShelterPost = true,
	MushroomStem = true,
	MushroomCap = true,
	GroveLog = true,
	HillWall = true,
	NestBack = true,
	NestSide = true,
	JumpStandard = true,
	TrainingRail = true,
	FlagPole = true,
	TerraceStep = true,
	CliffStep = true,
	-- Eklenti yapıları (kulübe/yuva duvarları, engel direkleri, ağaç gövdeleri)
	Box = true,
	Slat = true,
	HutBack = true,
	HutFront = true,
	HutHeader = true,
	HutSide = true,
	Hoop = true,
	Trunk = true,
	-- Bölge dekoru (ağıl/kümes/kafes/kuyu duvarları, direkler, yemlikler, kayalar)
	Post = true,
	Rock = true,
	Trough = true,
	FeedTrough = true,
	FeedTable = true,
	BackWall = true,
	StoneWall = true,
	WellWall = true,
	Log = true,
	Stump = true,
	SaltBase = true,
	SaltBlock = true,
	HiveBox = true,
	HiveStand = true,
	RackShelf = true,
	StyBack = true,
	StyFront = true,
	StySide = true,
	CoopBack = true,
	CoopFront = true,
	CoopSide = true,
	Coop = true,
	NestBox = true,
	Stilt = true,
	Hutch = true,
	HutchLeg = true,
	HutchSide = true,
	DuckHouseBack = true,
	DuckHouseFront = true,
	DuckHouseSide = true,
	PierPost = true,
	Tower = true,
	TowerBase = true,
	ArchSide = true,
}

local function markObstacles(root: Instance)
	for _, descendant in root:GetDescendants() do
		if descendant:IsA("BasePart") and OBSTACLE_NAMES[descendant.Name] then
			CollectionService:AddTag(descendant, "AnimalObstacle")
		end
	end
end

return {
	markObstacles = markObstacles,
	WOOD = WOOD,
	CREAM = CREAM,
	STRAW = STRAW,
	ROCK = ROCK,
	part = part,
	sign = sign,
}
