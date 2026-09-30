--!strict
-- Kıyı ve deniz: Terrain kayalık, kum plaj, kıyı kayaları, iskele direği ve iskele.
-- WorldDecor cephesi bunları birleştirir; her zaman `WorldDecor.<ad>` ile kullan.

local Workspace = game:GetService("Workspace")
local Parts = require(script.Parent:WaitForChild("DecorParts"))
local Props = require(script.Parent:WaitForChild("DecorProps"))

local part = Parts.part
local column = Parts.column

local Shore = {}

local function terrain(): Terrain
	return Workspace.Terrain
end

-- Ada kıyısı: kum plaj PARÇA halkası (çimenin 1 stud altında) + su altında Terrain kayalık gövde.
-- Terrain yüzeyi 4 stud'luk ızgarada öngörülemez şekilde yukarı yuvarlandığı için ada yüzeyine yakın
-- hiçbir yerde Terrain kullanılmaz; kayalık gövdenin üstü suyun iyice altındadır.
function Shore.terrainIsland(parent: Instance, center: Vector3, radius: number, surfaceY: number, beach: number)
	local base = Vector3.new(center.X, 0, center.Z)
	terrain():FillCylinder(CFrame.new(base + Vector3.new(0, -14, 0)), 16, radius + beach - 1, Enum.Material.Rock)

	local sandTop = surfaceY - 1
	local sandBottom = -2
	column(
		parent,
		"Beach",
		(radius + beach) * 2,
		sandTop - sandBottom,
		CFrame.new(base + Vector3.new(0, (sandTop + sandBottom) / 2, 0)),
		Color3.fromRGB(226, 208, 158),
		Enum.Material.Sand
	)
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

-- Kazık üstü tahtanın içinde, altı deniz tabanının içinde kalır; su altında havada bitmez.
function Shore.pierPile(parent: Instance, position: Vector3, surfaceY: number, seabedY: number): Part
	local top, bottom = surfaceY - 0.3, seabedY - 0.5
	assert(top > bottom, "İskele tabanı yürüyüş yüzeyinden aşağıda olmalı.")
	local pile = column(
		parent,
		"Pile",
		0.7,
		top - bottom,
		CFrame.new(position.X, (top + bottom) / 2, position.Z),
		Color3.fromRGB(95, 70, 50),
		Enum.Material.Wood
	)
	pile:SetAttribute("SeabedY", seabedY)
	return pile
end

-- Adanın kenarından denize uzanan iskele (kazıklar + tahta + fıçı ve olta).
-- surfaceY yürünebilir üst yüzeydir, parçanın merkezi değil.
function Shore.dock(parent: Instance, start: CFrame, length: number, surfaceY: number, seabedY: number)
	local model = Instance.new("Model")
	model.Name = "Dock"
	model.Parent = parent
	local wood = Color3.fromRGB(125, 90, 60)
	local deckY = surfaceY - 0.3
	local deckCf = start * CFrame.new(0, 0, -length / 2)
	local deck = part(
		model,
		"Deck",
		Vector3.new(6, 0.6, length),
		CFrame.new(deckCf.Position.X, deckY, deckCf.Position.Z) * deckCf.Rotation,
		wood,
		Enum.Material.WoodPlanks
	)
	deck:SetAttribute("WalkSurfaceY", surfaceY)
	local segments = math.max(1, math.ceil(length / 5))
	for i = 0, segments do
		for _, x in { -2.6, 2.6 } do
			local z = -(0.8 + (length - 1.6) * i / segments)
			local pos = (start * CFrame.new(x, 0, z)).Position
			Shore.pierPile(model, pos, surfaceY, seabedY)
		end
	end
	-- İskele başında küçük balıkçı kulübesi (olta takımı ve ağ askısı)
	local hutBase = start * CFrame.new(5.6, 0, -7)
	local function hutPart(name: string, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material)
		local at = hutBase * offset
		return part(
			model,
			name,
			size,
			CFrame.new(at.Position.X, deckY + size.Y / 2 + offset.Y - 0.3, at.Position.Z) * at.Rotation,
			color,
			material
		)
	end
	hutPart("HutFloor", Vector3.new(5, 0.4, 4.6), CFrame.new(0, 0.3, 0), wood, Enum.Material.WoodPlanks)
	hutPart(
		"HutBody",
		Vector3.new(4.6, 3.2, 4.2),
		CFrame.new(0, 2.2, 0),
		Color3.fromRGB(96, 140, 165),
		Enum.Material.WoodPlanks
	)
	hutPart(
		"HutRoof",
		Vector3.new(5.6, 0.5, 5.2),
		CFrame.new(0, 4.3, 0),
		Color3.fromRGB(150, 70, 60),
		Enum.Material.Slate
	)
	hutPart(
		"HutDoor",
		Vector3.new(0.3, 2.2, 1.4),
		CFrame.new(-2.35, 1.9, 0),
		Color3.fromRGB(110, 72, 42),
		Enum.Material.Wood
	)
	hutPart(
		"HutRack",
		Vector3.new(0.25, 0.25, 3),
		CFrame.new(2.4, 3.6, 0),
		Color3.fromRGB(80, 60, 40),
		Enum.Material.Wood
	)
	for _, corner in { Vector2.new(-2.2, -2), Vector2.new(2.2, -2), Vector2.new(-2.2, 2), Vector2.new(2.2, 2) } do
		Shore.pierPile(model, (hutBase * CFrame.new(corner.X, 0, corner.Y)).Position, surfaceY, seabedY)
	end
	local tip = start * CFrame.new(0, 0, -length + 2)
	Props.barrel(model, CFrame.new(tip.Position.X, deckY + 0.3, tip.Position.Z) * tip.Rotation * CFrame.new(-1.8, 0, 0))
	-- Olta
	part(
		model,
		"FishingRod",
		Vector3.new(0.15, 0.15, 6),
		CFrame.new(tip.Position.X, deckY + 1.6, tip.Position.Z)
			* tip.Rotation
			* CFrame.new(1.8, 0, -2)
			* CFrame.Angles(math.rad(25), 0, 0),
		Color3.fromRGB(80, 60, 40),
		Enum.Material.Wood
	)
end

return Shore
