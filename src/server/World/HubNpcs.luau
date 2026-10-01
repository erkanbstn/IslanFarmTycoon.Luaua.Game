--!strict
-- Meydandaki satıcı NPC'ler: blok gövdeli figürler, önlerinde tezgâh ve etkileşim noktası.
-- Her NPC bir "VendorPrompt" taşır; `Action` özniteliği client'ta hangi pencerenin açılacağını belirler.
-- Haritaya kaydedilir (MapBuilder çağırır). Yerel çerçeve: -Z ön, taban zemin yüzeyinde.

local CollectionService = game:GetService("CollectionService")

-- Studio harita eklentisi modülleri kopyalayıp çalıştırır; Shared araması SharedRef'te (kopyadaki Shared'ı bulur).
local Shared = require(script.Parent:WaitForChild("SharedRef")) :: typeof(game.ReplicatedStorage.Shared)
local WorldUi = require(Shared:WaitForChild("WorldUi"))

local HubNpcs = {}

export type NpcSpec = {
	name: string,
	title: string,
	icon: string,
	action: string, -- "orders" | "store" | "roadmap" | "upgrades" | "travel"
	blurb: string, -- Tabelada görünen tek satır işlev açıklaması (NPC adı etkileşim ipucunda)
	prompt: string,
	shirt: Color3,
	hat: Color3,
	awning: Color3,
}

local WOOD = Color3.fromRGB(150, 110, 70)
local DARK_WOOD = Color3.fromRGB(100, 70, 45)
local SKIN = Color3.fromRGB(240, 200, 165)
local PANTS = Color3.fromRGB(70, 75, 95)

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.Anchored = true
	p.CanTouch = false
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function figure(model: Model, base: CFrame, spec: NpcSpec)
	for _, x in { -0.55, 0.55 } do
		part(model, "Leg", Vector3.new(0.9, 2.6, 1), base * CFrame.new(x, 1.3, 0), PANTS, Enum.Material.Fabric)
		part(
			model,
			"Arm",
			Vector3.new(0.8, 2.4, 0.9),
			base * CFrame.new(x * 2.2, 3.9, -0.2),
			spec.shirt,
			Enum.Material.Fabric
		)
	end
	part(model, "Torso", Vector3.new(2.6, 2.8, 1.4), base * CFrame.new(0, 4, 0), spec.shirt, Enum.Material.Fabric)
	local head = part(model, "Head", Vector3.one * 1.9, base * CFrame.new(0, 6.1, 0), SKIN, Enum.Material.SmoothPlastic)
	head.Shape = Enum.PartType.Ball
	for _, x in { -0.4, 0.4 } do
		local eye = part(
			model,
			"Eye",
			Vector3.one * 0.25,
			base * CFrame.new(x, 6.25, -0.85),
			Color3.fromRGB(40, 40, 45),
			Enum.Material.SmoothPlastic
		)
		eye.Shape = Enum.PartType.Ball
		eye.CanCollide = false
	end
	-- Şapka: geniş kenar + alçak tepe
	part(model, "HatBrim", Vector3.new(3.2, 0.25, 3.2), base * CFrame.new(0, 6.95, 0), spec.hat, Enum.Material.Fabric)
	part(model, "HatTop", Vector3.new(1.9, 0.9, 1.9), base * CFrame.new(0, 7.4, 0), spec.hat, Enum.Material.Fabric)
end

function HubNpcs.vendor(parent: Instance, base: CFrame, spec: NpcSpec)
	local model = Instance.new("Model")
	model.Name = `Vendor_{spec.action}`
	model:SetAttribute("Action", spec.action)
	-- Client (HubNpcs.client) etiketli satıcıları canlandırır: göz teması, el sallama, konuşma balonu
	CollectionService:AddTag(model, "HubNpc")
	model.Parent = parent

	-- Satıcı tezgâhın arkasında durur, tezgâh -Z (meydan) yönüne bakar
	figure(model, base * CFrame.new(0, 0, 1.6), spec)
	part(model, "Counter", Vector3.new(7, 2.6, 2.2), base * CFrame.new(0, 1.3, -1.6), WOOD, Enum.Material.WoodPlanks)
	part(
		model,
		"CounterTop",
		Vector3.new(7.4, 0.3, 2.6),
		base * CFrame.new(0, 2.75, -1.6),
		DARK_WOOD,
		Enum.Material.WoodPlanks
	)
	for _, x in { -3.3, 3.3 } do
		part(model, "Post", Vector3.new(0.4, 8.4, 0.4), base * CFrame.new(x, 4.2, -2.5), DARK_WOOD, Enum.Material.Wood)
	end
	-- Yan paneller: tezgâhın içine girilip satıcının içinden geçilmesin (ön tezgâh, arka panel ve yanlar kapalı)
	for _, x in { -3.6, 3.6 } do
		part(
			model,
			"SidePanel",
			Vector3.new(0.4, 3.6, 6.4),
			base * CFrame.new(x, 1.8, 0.6),
			WOOD,
			Enum.Material.WoodPlanks
		)
	end
	-- Tente: öne doğru alçalan kumaş
	local awning = part(
		model,
		"Awning",
		Vector3.new(8.2, 0.3, 6),
		base * CFrame.new(0, 8.6, -0.6) * CFrame.Angles(math.rad(-10), 0, 0),
		spec.awning,
		Enum.Material.Fabric
	)
	awning.CanCollide = false
	part(
		model,
		"Backdrop",
		Vector3.new(7, 6.4, 0.4),
		base * CFrame.new(0, 3.2, 3.6),
		DARK_WOOD,
		Enum.Material.WoodPlanks
	)

	-- Tabela: tentenin önünde
	local board = part(
		model,
		"Sign",
		Vector3.new(6.4, 2.2, 0.3),
		base * CFrame.new(0, 10, -3.4),
		Color3.fromRGB(85, 60, 40),
		Enum.Material.WoodPlanks
	)
	board.CanCollide = false
	WorldUi.sign(board, Enum.NormalId.Front, { icon = spec.icon, title = spec.title, text = spec.blurb })

	local anchor =
		part(model, "VendorPromptAnchor", Vector3.one, base * CFrame.new(0, 3, -3.6), WOOD, Enum.Material.SmoothPlastic)
	anchor.Transparency = 1
	anchor.CanCollide = false
	anchor.CanQuery = false
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "VendorPrompt"
	prompt.ActionText = spec.prompt
	prompt.ObjectText = spec.name
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("Action", spec.action)
	prompt.Parent = anchor
end

---------------------------------------------------------------------------
-- Meydan dekoru: çeşme, bankler ve çiçeklikler (MapBuilder.buildHub çağırır; haritaya kaydedilir)
---------------------------------------------------------------------------

local STONE = Color3.fromRGB(150, 148, 140)

-- Dik silindir (Part silindirinin ekseni X'tir)
local function column(
	parent: Instance,
	name: string,
	diameter: number,
	height: number,
	cf: CFrame,
	color: Color3,
	material: Enum.Material
): Part
	local p = part(
		parent,
		name,
		Vector3.new(height, diameter, diameter),
		cf * CFrame.Angles(0, 0, math.rad(90)),
		color,
		material
	)
	p.Shape = Enum.PartType.Cylinder
	return p
end

function HubNpcs.fountain(parent: Instance, base: CFrame)
	local model = Instance.new("Model")
	model.Name = "Fountain"
	model.Parent = parent
	column(model, "Basin", 7.4, 1.4, base * CFrame.new(0, 0.7, 0), STONE, Enum.Material.Cobblestone)
	local water = column(
		model,
		"Water",
		6.4,
		0.2,
		-- Su yüzeyi havuz kenarının (1.4) üstünde: aynı yükseklikte olursa taş ile su titreşir (z-fighting).
		base * CFrame.new(0, 1.36, 0),
		Color3.fromRGB(80, 170, 225),
		Enum.Material.Glass
	)
	water.Transparency = 0.25
	water.CanCollide = false
	column(model, "Pillar", 1.2, 3.4, base * CFrame.new(0, 2.6, 0), STONE, Enum.Material.Cobblestone)
	column(model, "UpperBowl", 3.2, 0.6, base * CFrame.new(0, 4.1, 0), STONE, Enum.Material.Cobblestone)
	local top = column(
		model,
		"TopWater",
		2.6,
		0.2,
		base * CFrame.new(0, 4.5, 0), -- üst kase kenarı 4.4; su 4.6 (çakışan yüzey yok)
		Color3.fromRGB(110, 190, 235),
		Enum.Material.Glass
	)
	top.Transparency = 0.25
	top.CanCollide = false
	local drop = part(
		model,
		"Drop",
		Vector3.one * 0.9,
		base * CFrame.new(0, 5.2, 0),
		Color3.fromRGB(170, 220, 250),
		Enum.Material.Glass
	)
	drop.Shape = Enum.PartType.Ball
	drop.Transparency = 0.3
	drop.CanCollide = false
end

function HubNpcs.bench(parent: Instance, base: CFrame)
	local model = Instance.new("Model")
	model.Name = "Bench"
	model.Parent = parent
	part(model, "Seat", Vector3.new(5, 0.4, 1.8), base * CFrame.new(0, 1.6, 0), WOOD, Enum.Material.WoodPlanks)
	part(
		model,
		"Back",
		Vector3.new(5, 1.6, 0.3),
		base * CFrame.new(0, 2.6, 0.8) * CFrame.Angles(math.rad(-8), 0, 0),
		WOOD,
		Enum.Material.WoodPlanks
	)
	for _, x in { -2.2, 2.2 } do
		part(model, "Leg", Vector3.new(0.4, 1.6, 1.6), base * CFrame.new(x, 0.8, 0), DARK_WOOD, Enum.Material.Wood)
	end
end

function HubNpcs.planter(parent: Instance, base: CFrame, seed: number)
	local model = Instance.new("Model")
	model.Name = "Planter"
	model.Parent = parent
	part(model, "Box", Vector3.new(3.4, 1.2, 1.4), base * CFrame.new(0, 0.6, 0), WOOD, Enum.Material.WoodPlanks)
	local soil = part(
		model,
		"Soil",
		Vector3.new(3, 0.2, 1),
		base * CFrame.new(0, 1.25, 0),
		Color3.fromRGB(85, 60, 40),
		Enum.Material.Ground
	)
	soil.CanCollide = false
	local colors = {
		Color3.fromRGB(240, 90, 120),
		Color3.fromRGB(250, 210, 70),
		Color3.fromRGB(245, 245, 250),
		Color3.fromRGB(190, 110, 220),
	}
	for index = 0, 3 do
		local x = -1.2 + index * 0.8
		part(
			model,
			"Stem",
			Vector3.new(0.15, 0.8, 0.15),
			base * CFrame.new(x, 1.6, 0),
			Color3.fromRGB(70, 130, 60),
			Enum.Material.Grass
		).CanCollide =
			false
		local bloom = part(
			model,
			"Bloom",
			Vector3.one * 0.6,
			base * CFrame.new(x, 2.1, 0),
			colors[(seed + index) % #colors + 1],
			Enum.Material.SmoothPlastic
		)
		bloom.Shape = Enum.PartType.Ball
		bloom.CanCollide = false
	end
end

return HubNpcs
