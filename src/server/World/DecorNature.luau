--!strict
-- Bitki örtüsü: ağaç çeşitleri, çalı, çiçek, çim tutamları ve çim yamaları.
-- WorldDecor cephesi bunları birleştirir; her zaman `WorldDecor.<ad>` ile kullan.

local Parts = require(script.Parent:WaitForChild("DecorParts"))

local part = Parts.part
local ball = Parts.ball
local column = Parts.column

local Nature = {}

---------------------------------------------------------------------------
-- Bitki örtüsü
---------------------------------------------------------------------------

local LEAF_COLORS = {
	Color3.fromRGB(70, 140, 60),
	Color3.fromRGB(85, 155, 65),
	Color3.fromRGB(60, 125, 55),
	Color3.fromRGB(100, 160, 70),
}

-- Yuvarlak taçlı ağaç: gövde + dal + birkaç farklı tonda yaprak kümesi
function Nature.oakTree(parent: Instance, base: CFrame, seed: number)
	local random = Random.new(seed)
	local scale = random:NextNumber(0.85, 1.2)
	local model = Instance.new("Model")
	model.Name = "OakTree"
	model.Parent = parent

	local bark = Color3.fromRGB(100, 70, 45)
	column(model, "Trunk", 1.8 * scale, 8 * scale, base * CFrame.new(0, 4 * scale, 0), bark, Enum.Material.Wood)
	part(
		model,
		"Branch",
		Vector3.new(0.7, 3.5, 0.7) * scale,
		base * CFrame.new(1 * scale, 6.5 * scale, 0) * CFrame.Angles(0, 0, math.rad(-40)),
		bark,
		Enum.Material.Wood
	)
	local crown: { { offset: Vector3, size: number } } = {
		{ offset = Vector3.new(0, 10, 0), size = 8 },
		{ offset = Vector3.new(2.6, 9, 1.2), size = 6 },
		{ offset = Vector3.new(-2.4, 9.2, -1), size = 6.2 },
		{ offset = Vector3.new(0.6, 12, -1.6), size = 5.5 },
		{ offset = Vector3.new(-1, 8.6, 2.6), size = 5 },
	}
	for i, leaf in crown do
		local p = ball(
			model,
			"Leaves",
			leaf.size * scale,
			base * CFrame.new(leaf.offset * scale),
			LEAF_COLORS[(i + seed) % #LEAF_COLORS + 1],
			Enum.Material.LeafyGrass
		)
		p.CanCollide = false
	end
end

-- Çam: ince uzun gövde + yukarı doğru küçülen koyu yaprak katmanları
function Nature.pineTree(parent: Instance, base: CFrame, seed: number)
	local random = Random.new(seed)
	local scale = random:NextNumber(0.9, 1.25)
	local model = Instance.new("Model")
	model.Name = "PineTree"
	model.Parent = parent

	column(
		model,
		"Trunk",
		1.2 * scale,
		11 * scale,
		base * CFrame.new(0, 5.5 * scale, 0),
		Color3.fromRGB(90, 60, 40),
		Enum.Material.Wood
	)
	-- Aşağıdan yukarı daralan yassı katmanlar (koni silueti)
	local layers = { { 4, 8.5 }, { 6.4, 7 }, { 8.6, 5.4 }, { 10.6, 3.8 }, { 12.3, 2.2 } }
	for index, layer in layers do
		local p = part(
			model,
			"Needles",
			Vector3.new(layer[2], 2.4, layer[2]) * scale,
			base * CFrame.new(0, layer[1] * scale, 0),
			if index % 2 == 0 then Color3.fromRGB(45, 100, 60) else Color3.fromRGB(38, 88, 52),
			Enum.Material.LeafyGrass
		)
		p.CanCollide = false
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
	end
end

function Nature.bush(parent: Instance, base: CFrame, seed: number)
	local random = Random.new(seed)
	local model = Instance.new("Model")
	model.Name = "Bush"
	model.Parent = parent
	for i = 1, 3 do
		local size = random:NextNumber(2.2, 3.4)
		local p = ball(
			model,
			"Leaves",
			size,
			base * CFrame.new(random:NextNumber(-1.2, 1.2), size * 0.35, random:NextNumber(-1.2, 1.2)),
			LEAF_COLORS[(i + seed) % #LEAF_COLORS + 1],
			Enum.Material.LeafyGrass
		)
		p.CanCollide = false
	end
	-- Bazı çalılarda küçük çiçekler/meyveler
	if seed % 2 == 0 then
		for _ = 1, 4 do
			local p = ball(
				model,
				"Berry",
				0.45,
				base * CFrame.new(random:NextNumber(-1.4, 1.4), random:NextNumber(1, 2), random:NextNumber(-1.4, 1.4)),
				Color3.fromRGB(220, 60, 70),
				Enum.Material.SmoothPlastic
			)
			p.CanCollide = false
		end
	end
end

local FLOWER_COLORS = {
	Color3.fromRGB(250, 220, 80),
	Color3.fromRGB(240, 120, 160),
	Color3.fromRGB(250, 250, 250),
	Color3.fromRGB(170, 120, 230),
	Color3.fromRGB(245, 140, 60),
}

-- Küçük çiçek tarhı: saplı, renkli çiçekler
function Nature.flowerPatch(parent: Instance, base: CFrame, seed: number)
	local random = Random.new(seed)
	local model = Instance.new("Model")
	model.Name = "Flowers"
	model.Parent = parent
	local color = FLOWER_COLORS[seed % #FLOWER_COLORS + 1]
	for _ = 1, 7 do
		local offset = CFrame.new(random:NextNumber(-2, 2), 0, random:NextNumber(-2, 2))
		local height = random:NextNumber(0.6, 1.1)
		local stem = part(
			model,
			"Stem",
			Vector3.new(0.12, height, 0.12),
			base * offset * CFrame.new(0, height / 2, 0),
			Color3.fromRGB(70, 130, 60),
			Enum.Material.SmoothPlastic
		)
		stem.CanCollide = false
		local bloom =
			ball(model, "Bloom", 0.45, base * offset * CFrame.new(0, height, 0), color, Enum.Material.SmoothPlastic)
		bloom.CanCollide = false
	end
end

local GRASS_COLORS = {
	Color3.fromRGB(88, 152, 64),
	Color3.fromRGB(104, 168, 70),
	Color3.fromRGB(72, 136, 58),
	Color3.fromRGB(126, 176, 78),
}

export type GrassRect = { x: number, z: number, hx: number, hz: number }

export type GrassSpec = {
	count: number,
	seed: number,
	-- Yuvarlak alan (ada): merkezden iç/dış yarıçap
	minRadius: number?,
	maxRadius: number?,
	-- Dikdörtgen alan (bölge): x -halfX..halfX, z zMin..zMax
	halfX: number?,
	zMin: number?,
	zMax: number?,
	avoid: { GrassRect }?, -- yerel koordinatta çim çıkmayacak dikdörtgenler (yol, bina, bölge)
	flowerChance: number?,
}

function Nature.grassTufts(parent: Instance, base: CFrame, spec: GrassSpec): Folder
	local random = Random.new(spec.seed)
	local folder = Instance.new("Folder")
	folder.Name = "GrassTufts"
	folder.Parent = parent
	local avoid: { GrassRect } = spec.avoid or {}
	local flowerChance = spec.flowerChance or 0.12
	local placed, attempts = 0, 0
	while placed < spec.count and attempts < spec.count * 8 do
		attempts += 1
		local x, z
		if spec.maxRadius then
			local minR = spec.minRadius or 0
			local angle = random:NextNumber(0, math.pi * 2)
			local r = math.sqrt(random:NextNumber(minR * minR, spec.maxRadius * spec.maxRadius))
			x, z = math.cos(angle) * r, math.sin(angle) * r
		else
			local halfX = spec.halfX or 10
			x = random:NextNumber(-halfX, halfX)
			z = random:NextNumber(spec.zMin or -10, spec.zMax or 10)
		end
		local blocked = false
		for _, rect in avoid do
			if math.abs(x - rect.x) < rect.hx and math.abs(z - rect.z) < rect.hz then
				blocked = true
				break
			end
		end
		if blocked then
			continue
		end
		placed += 1
		local yaw = random:NextNumber(0, math.pi)
		local height = random:NextNumber(0.7, 1.3)
		local color = GRASS_COLORS[random:NextInteger(1, #GRASS_COLORS)]
		local origin = base * CFrame.new(x, 0, z) * CFrame.Angles(0, yaw, 0)
		for blade = 0, 1 do
			local p = part(
				folder,
				"Tuft",
				Vector3.new(0.14, height, random:NextNumber(0.9, 1.5)),
				origin
					* CFrame.Angles(0, blade * math.pi / 2, random:NextNumber(-0.12, 0.12))
					* CFrame.new(0, height / 2 - 0.05, 0),
				color,
				Enum.Material.Grass
			)
			p.CanCollide, p.CanQuery, p.CastShadow = false, false, false
		end
		if random:NextNumber() < flowerChance then
			local stemH = random:NextNumber(0.9, 1.4)
			local stem = part(
				folder,
				"Stem",
				Vector3.new(0.12, stemH, 0.12),
				origin * CFrame.new(0.5, stemH / 2, 0.4),
				Color3.fromRGB(70, 130, 60),
				Enum.Material.SmoothPlastic
			)
			local bloom = ball(
				folder,
				"Bloom",
				0.5,
				origin * CFrame.new(0.5, stemH, 0.4),
				FLOWER_COLORS[random:NextInteger(1, #FLOWER_COLORS)],
				Enum.Material.SmoothPlastic
			)
			for _, p in { stem, bloom } do
				p.CanCollide, p.CanQuery, p.CastShadow = false, false, false
			end
		end
	end
	return folder
end

-- Düz çimen zeminde renk çeşitliliği: hafif farklı tonda, çok ince yassı daireler.
function Nature.grassPatches(
	parent: Instance,
	base: CFrame,
	count: number,
	minRadius: number,
	maxRadius: number,
	seed: number
)
	local random = Random.new(seed)
	local folder = Instance.new("Folder")
	folder.Name = "GrassPatches"
	folder.Parent = parent
	for _ = 1, count do
		local angle = random:NextNumber(0, math.pi * 2)
		local r = random:NextNumber(minRadius, maxRadius)
		local diameter = random:NextNumber(6, 14)
		local tone = random:NextNumber(-14, 16)
		local p = part(
			folder,
			"Patch",
			Vector3.new(0.05, diameter, diameter),
			base * CFrame.new(math.cos(angle) * r, 0.03, math.sin(angle) * r) * CFrame.Angles(0, 0, math.rad(90)),
			Color3.fromRGB(
				math.clamp(96 + tone, 0, 255),
				math.clamp(160 + tone, 0, 255),
				math.clamp(74 + tone * 0.6, 0, 255)
			),
			Enum.Material.Grass
		)
		p.Shape = Enum.PartType.Cylinder
		p.CanCollide, p.CanQuery, p.CastShadow = false, false, false
	end
end

return Nature
