--!strict
-- Bitki örtüsü: ağaç çeşitleri, çalı, çiçek, çim tutamları ve çim yamaları.
-- WorldDecor cephesi bunları birleştirir; her zaman `WorldDecor.<ad>` ile kullan.

local ModelAssets = require(script.Parent:WaitForChild("ModelAssets"))

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

-- Hangi türün hangi kar başlığını aldığı (assets/SeasonModels)
local SNOW_CAPS: { [string]: string } = {
	OakTree = "SnowCap_Oak",
	BirchTree = "SnowCap_Oak",
	PineTree = "SnowCap_Pine",
	Bush = "SnowCap_Bush",
}

-- Mevsim modelleri (kar başlığı, kardan adam) yazın görünmez durur; client karlı mevsimde Transparency'yi açar
local function hideSeasonModel(model: Model)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Transparency = 1
			descendant.CastShadow = false
		end
	end
end

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
	local scale = random:NextNumber(minScale, maxScale)
	local placement = base * CFrame.Angles(0, random:NextNumber(0, math.pi * 2), 0)
	model:ScaleTo(scale)
	model:PivotTo(placement)
	-- Kış kar başlığı (assets/SeasonModels): ağaca/çalıya oturur, gizli gelir; SeasonalScenery (client) karlı mevsimde açar
	local capName = SNOW_CAPS[displayName]
	local cap = if capName then ModelAssets.clone("SeasonModels", capName) else nil
	if cap then
		cap.Name = "SnowCap"
		cap:ScaleTo(scale)
		cap:PivotTo(placement)
		hideSeasonModel(cap)
		cap.Parent = model
	end
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

-- Ada serpiştirmeleri (assets/CommonDecor): kıyıya yakın halkada kaya, saz, kuyruklu saz ve palmiye; içeride kütük, kütük
-- yığını, mantar, kabak, ayçiçeği, huş ve kaya. Yerleşim tohumdan türer, `avoid` dikdörtgenlerinden (yol, bina, bölge) kaçınır.
local SHORE_PROPS: { { variants: { string }, name: string, minScale: number, maxScale: number } } = {
	{ variants = { "Rock_A", "Rock_B", "Rock_C" }, name = "Rock", minScale = 0.8, maxScale = 1.4 },
	{ variants = { "Reed_A", "Reed_B" }, name = "Reed", minScale = 0.9, maxScale = 1.3 },
	{ variants = { "Cattail" }, name = "Cattail", minScale = 0.9, maxScale = 1.3 },
	{ variants = { "PalmTree_A", "PalmTree_B" }, name = "PalmTree", minScale = 0.9, maxScale = 1.2 },
}
local INLAND_PROPS: { { variants: { string }, name: string, minScale: number, maxScale: number } } = {
	{ variants = { "Stump_A", "Stump_B" }, name = "Stump", minScale = 0.9, maxScale = 1.3 },
	{ variants = { "LogPile" }, name = "LogPile", minScale = 0.9, maxScale = 1.2 },
	{ variants = { "Mushroom_A", "Mushroom_B", "Mushroom_C" }, name = "Mushroom", minScale = 0.9, maxScale = 1.4 },
	{ variants = { "Pumpkin" }, name = "Pumpkin", minScale = 0.9, maxScale = 1.3 },
	{ variants = { "Sunflower_Single" }, name = "Sunflower", minScale = 0.9, maxScale = 1.3 },
	{ variants = BIRCH_VARIANTS, name = "BirchTree", minScale = 0.9, maxScale = 1.2 },
	{ variants = { "Rock_A", "Rock_B", "Rock_C" }, name = "Rock", minScale = 0.8, maxScale = 1.3 },
}
local SHORE_BAND = 9 -- dış kenardan bu kadar içerideki halka "kıyı" sayılır

function Nature.scatterProps(
	parent: Instance,
	base: CFrame,
	spec: {
		count: number,
		seed: number,
		minRadius: number,
		maxRadius: number,
		avoid: { GrassRect }?,
	}
): Folder
	local random = Random.new(spec.seed)
	local folder = Instance.new("Folder")
	folder.Name = "ScatterProps"
	folder.Parent = parent
	local avoid: { GrassRect } = spec.avoid or {}
	local placed, attempts = 0, 0
	while placed < spec.count and attempts < spec.count * 10 do
		attempts += 1
		local angle = random:NextNumber(0, math.pi * 2)
		local r = math.sqrt(random:NextNumber(spec.minRadius ^ 2, spec.maxRadius ^ 2))
		local x, z = math.cos(angle) * r, math.sin(angle) * r
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
		local pool = if r > spec.maxRadius - SHORE_BAND then SHORE_PROPS else INLAND_PROPS
		if pool == INLAND_PROPS and random:NextNumber() < 0.12 then
			-- Kardan adam: yalnızca karlı mevsimde görünür (SeasonalScenery)
			local snowman = ModelAssets.clone("SeasonModels", "Snowman")
			if snowman then
				hideSeasonModel(snowman)
				snowman:PivotTo(base * CFrame.new(x, 0, z) * CFrame.Angles(0, random:NextNumber(0, math.pi * 2), 0))
				snowman.Parent = folder
			end
			continue
		end
		local kind = pool[random:NextInteger(1, #pool)]
		placeVaried(
			folder,
			kind.variants,
			kind.name,
			base * CFrame.new(x, 0, z),
			random:NextInteger(1, 1000000),
			kind.minScale,
			kind.maxScale
		)
	end
	return folder
end

local GRASS_COLORS = {
	Color3.fromRGB(78, 129, 65),
	Color3.fromRGB(96, 145, 73),
	Color3.fromRGB(68, 116, 57),
	Color3.fromRGB(111, 155, 81),
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
	local flowerChance = spec.flowerChance or 0.16
	local clusters: { { x: number, z: number } } = {}
	if spec.maxRadius then
		for _ = 1, 12 do
			local angle = random:NextNumber(0, math.pi * 2)
			local minR = spec.minRadius or 0
			local r = math.sqrt(random:NextNumber(minR * minR, spec.maxRadius * spec.maxRadius))
			table.insert(clusters, { x = math.cos(angle) * r, z = math.sin(angle) * r })
		end
	end
	local placed, attempts = 0, 0
	while placed < spec.count and attempts < spec.count * 8 do
		attempts += 1
		local x, z
		if spec.maxRadius then
			local minR = spec.minRadius or 0
			local cluster = clusters[random:NextInteger(1, #clusters)]
			x, z = cluster.x + random:NextNumber(-6, 6), cluster.z + random:NextNumber(-6, 6)
			if x * x + z * z < minR * minR or x * x + z * z > spec.maxRadius * spec.maxRadius then
				continue
			end
		else
			local halfX = spec.halfX or 10
			x = random:NextNumber(-halfX, halfX)
			z = random:NextNumber(spec.zMin or -10, spec.zMax or 10)
		end
		local blocked = false
		for _, rect in avoid do
			if math.abs(x - rect.x) < rect.hx + 1 and math.abs(z - rect.z) < rect.hz + 1 then
				blocked = true
				break
			end
		end
		if blocked then
			continue
		end
		placed += 1
		local yaw = random:NextNumber(0, math.pi)
		local height = random:NextNumber(0.75, 1.15)
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
			blade.Color = color:Lerp(blade.Color, 0.25)
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

return Nature
