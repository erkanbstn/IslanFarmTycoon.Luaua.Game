--!strict
-- Bitki örtüsü: ağaç çeşitleri, çalı, çiçek, çim tutamları ve çim yamaları.
-- WorldDecor cephesi bunları birleştirir; her zaman `WorldDecor.<ad>` ile kullan.

local ModelAssets = require(script.Parent:WaitForChild("ModelAssets"))
local Parts = require(script.Parent:WaitForChild("DecorParts"))

local part = Parts.part

local Nature = {}

---------------------------------------------------------------------------
-- Bitki örtüsü
---------------------------------------------------------------------------

local FLOWER_COLORS = {
	Color3.fromRGB(250, 220, 80),
	Color3.fromRGB(240, 120, 160),
	Color3.fromRGB(250, 250, 250),
	Color3.fromRGB(170, 120, 230),
	Color3.fromRGB(245, 140, 60),
}

-- Ağaçlar, çalı ve çiçek tarhı hazır modellerden gelir (assets/CommonDecor); her tür birkaç varyanttır, tohum varyantı,
-- ölçeği ve dönüşü seçer. Yerleşen modelin adı türün adıdır (OakTree, PineTree, Bush, Flowers): SeasonalScenery (client)
-- mevsim rengini bu ad + parça adlarıyla (Trunk, Leaves, Needles, Berry, Bloom, Stem) bulur.
local FOLDER = "CommonDecor"
local missingWarned: { [string]: boolean } = {}

local OAK_VARIANTS = { "OakTree_A", "OakTree_B", "OakTree_C", "OakTree_D" }
local PINE_VARIANTS = { "PineTree_A", "PineTree_B", "PineTree_C" }
local BIRCH_VARIANTS = { "BirchTree_A", "BirchTree_B" }
local BUSH_VARIANTS = { "Bush_A", "Bush_B", "Bush_Berry" }
local FLOWER_VARIANTS =
	{ "FlowerPatch_Yellow", "FlowerPatch_Pink", "FlowerPatch_White", "FlowerPatch_Purple", "FlowerPatch_Orange" }

local function placeVaried(
	parent: Instance,
	variants: { string },
	displayName: string,
	base: CFrame,
	seed: number,
	minScale: number,
	maxScale: number
): Model?
	local random = Random.new(seed)
	local name = variants[random:NextInteger(1, #variants)]
	local model = ModelAssets.clone(FOLDER, name)
	if not model then
		if not missingWarned[name] then
			missingWarned[name] = true
			warn(`[DecorNature] assets/{FOLDER}/{name}.rbxmx bulunamadı; süs çizilmedi`)
		end
		return nil
	end
	model.Name = displayName
	model:ScaleTo(random:NextNumber(minScale, maxScale))
	model:PivotTo(base * CFrame.Angles(0, random:NextNumber(0, math.pi * 2), 0))
	model.Parent = parent
	return model
end

-- Yuvarlak taçlı ağaç (meşe)
function Nature.oakTree(parent: Instance, base: CFrame, seed: number)
	placeVaried(parent, OAK_VARIANTS, "OakTree", base, seed, 0.85, 1.2)
end

-- Çam
function Nature.pineTree(parent: Instance, base: CFrame, seed: number)
	placeVaried(parent, PINE_VARIANTS, "PineTree", base, seed, 0.9, 1.25)
end

-- Huş (mevsim rengi şimdilik yok: yaprakları "Leaves" adını taşımıyorsa SeasonalScenery dokunmaz)
function Nature.birchTree(parent: Instance, base: CFrame, seed: number)
	placeVaried(parent, BIRCH_VARIANTS, "BirchTree", base, seed, 0.9, 1.2)
end

function Nature.bush(parent: Instance, base: CFrame, seed: number)
	placeVaried(parent, BUSH_VARIANTS, "Bush", base, seed, 0.85, 1.25)
end

-- Küçük çiçek tarhı: varyant (çiçek rengi) tohuma göre seçilir
function Nature.flowerPatch(parent: Instance, base: CFrame, seed: number)
	placeVaried(parent, FLOWER_VARIANTS, "Flowers", base, seed, 0.9, 1.15)
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
		local withFlower = random:NextNumber() < flowerChance
		local tuft = ModelAssets.clone(FOLDER, if withFlower then "GrassTuft_Flower" else "GrassTuft")
		if not tuft then
			if not missingWarned.GrassTuft then
				missingWarned.GrassTuft = true
				warn(`[DecorNature] assets/{FOLDER}/GrassTuft.rbxmx bulunamadı; çim çizilmedi`)
			end
			break
		end
		ModelAssets.eachNamed(tuft, { "Tuft" }, function(blade: BasePart)
			blade.Color = color
		end)
		if withFlower then
			local bloomColor = FLOWER_COLORS[random:NextInteger(1, #FLOWER_COLORS)]
			ModelAssets.eachNamed(tuft, { "Bloom" }, function(bloom: BasePart)
				bloom.Color = bloomColor
			end)
		end
		tuft:ScaleTo(height)
		tuft:PivotTo(base * CFrame.new(x, 0, z) * CFrame.Angles(0, yaw, 0))
		tuft.Parent = folder
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
