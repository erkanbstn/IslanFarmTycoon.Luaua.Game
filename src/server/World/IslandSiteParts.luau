--!strict
-- Uzman ada yapıları için ortak renkler ve yapı taşları (parça, tabela, yüzey).

local CollectionService = game:GetService("CollectionService")

-- Studio harita eklentisi modülleri kopyalayıp çalıştırır; Shared araması SharedRef'te (kopyadaki Shared'ı bulur).
local Shared = require(script.Parent:WaitForChild("SharedRef")) :: typeof(game.ReplicatedStorage.Shared)
local WorldUi = require(Shared:WaitForChild("WorldUi"))

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

local function sign(parent: Instance, cf: CFrame, title: string, icon: string)
	local board = part(
		parent,
		"SpecialtySign",
		Vector3.new(7, 2, 0.35),
		cf * CFrame.new(0, 9.6, 0),
		WOOD,
		Enum.Material.WoodPlanks
	)
	board.CanCollide = false
	part(parent, "SignPost", Vector3.new(0.5, 8.6, 0.5), cf * CFrame.new(0, 4.3, 0), WOOD, Enum.Material.Wood)
	WorldUi.sign(board, Enum.NormalId.Front, { text = title, icon = icon })
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
