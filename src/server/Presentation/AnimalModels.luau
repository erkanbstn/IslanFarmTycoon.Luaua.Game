--!strict
-- Hayvan modelleri: ServerStorage.Assets.Animals içindeki model ya da koddan basit bloklarla üretilen hayvan.
-- Kendi modelini kullanmak için "cow", "horse", "chicken" gibi adla Model koy.

local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AssetSanitizer = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("AssetSanitizer"))

local STAGE_SCALE: { [string]: number } = {
	calf = 0.55,
	young = 0.8,
	adult = 1,
}

local function block(model: Model, name: string, size: Vector3, cframe: CFrame, color: Color3): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Anchored = true
	p.CanTouch = false
	p.CanCollide = false
	p.CanQuery = false
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end

-- Tüm ölçüler s (evre ölçeği) ile çarpılır. Model -Z yönüne (başı) bakar.
local function buildCow(model: Model, s: number)
	local white = Color3.fromRGB(245, 245, 240)
	local black = Color3.fromRGB(35, 35, 35)
	local pink = Color3.fromRGB(240, 170, 170)
	local legH = 2 * s
	local body = block(model, "Body", Vector3.new(3.2, 2.4, 5) * s, CFrame.new(0, legH + 1.2 * s, 0), white)
	block(model, "Spot1", Vector3.new(3.3, 1.2, 1.6) * s, body.CFrame * CFrame.new(0, 0.5 * s, 0.8 * s), black)
	block(model, "Spot2", Vector3.new(1.4, 1.3, 1.2) * s, body.CFrame * CFrame.new(1.0 * s, 0.2 * s, -1.4 * s), black)
	local head =
		block(model, "Head", Vector3.new(2, 1.8, 1.8) * s, body.CFrame * CFrame.new(0, 0.8 * s, -3.1 * s), white)
	block(model, "Snout", Vector3.new(1.8, 0.9, 0.6) * s, head.CFrame * CFrame.new(0, -0.45 * s, -1.1 * s), pink)
	for _, x in { -1, 1 } do
		block(
			model,
			"Horn",
			Vector3.new(0.3, 0.7, 0.3) * s,
			head.CFrame * CFrame.new(x * 0.7 * s, 1.2 * s, 0.2 * s),
			Color3.fromRGB(230, 220, 190)
		)
		block(
			model,
			"Eye",
			Vector3.new(0.3, 0.3, 0.1) * s,
			head.CFrame * CFrame.new(x * 0.5 * s, 0.3 * s, -0.91 * s),
			black
		)
		for _, z in { -1, 1 } do
			block(
				model,
				"Leg",
				Vector3.new(0.8 * s, legH, 0.8 * s),
				CFrame.new(x * 1.1 * s, legH / 2, z * 1.8 * s),
				white
			)
		end
	end
	block(model, "Udder", Vector3.new(1, 0.5, 1) * s, body.CFrame * CFrame.new(0, -1.35 * s, 1.2 * s), pink)
	block(model, "Tail", Vector3.new(0.25, 1.8, 0.25) * s, body.CFrame * CFrame.new(0, -0.3 * s, 2.6 * s), black)
	model.PrimaryPart = body
end

local function buildHorse(model: Model, s: number)
	local brown = Color3.fromRGB(125, 80, 45)
	local dark = Color3.fromRGB(45, 30, 20)
	local legH = 3 * s
	local body = block(model, "Body", Vector3.new(2.4, 2.4, 5.2) * s, CFrame.new(0, legH + 1.2 * s, 0), brown)
	local neck = block(
		model,
		"Neck",
		Vector3.new(1.4, 2.8, 1.4) * s,
		body.CFrame * CFrame.new(0, 1.8 * s, -2.4 * s) * CFrame.Angles(math.rad(-25), 0, 0),
		brown
	)
	local head =
		block(model, "Head", Vector3.new(1.3, 1.3, 2.6) * s, neck.CFrame * CFrame.new(0, 1.4 * s, -0.8 * s), brown)
	block(model, "Mane", Vector3.new(0.4, 2.8, 1.5) * s, neck.CFrame * CFrame.new(0, 0.2 * s, 0.5 * s), dark)
	for _, x in { -1, 1 } do
		block(
			model,
			"Eye",
			Vector3.new(0.1, 0.3, 0.3) * s,
			head.CFrame * CFrame.new(x * 0.66 * s, 0.2 * s, -0.4 * s),
			dark
		)
		block(
			model,
			"Ear",
			Vector3.new(0.3, 0.6, 0.3) * s,
			head.CFrame * CFrame.new(x * 0.4 * s, 0.9 * s, 0.7 * s),
			brown
		)
		for _, z in { -1, 1 } do
			block(
				model,
				"Leg",
				Vector3.new(0.7 * s, legH, 0.7 * s),
				CFrame.new(x * 0.8 * s, legH / 2, z * 2 * s),
				brown
			)
			block(model, "Hoof", Vector3.new(0.8, 0.4, 0.8) * s, CFrame.new(x * 0.8 * s, 0.2 * s, z * 2 * s), dark)
		end
	end
	block(
		model,
		"Tail",
		Vector3.new(0.5, 2.4, 0.5) * s,
		body.CFrame * CFrame.new(0, -0.2 * s, 2.9 * s) * CFrame.Angles(math.rad(20), 0, 0),
		dark
	)
	model.PrimaryPart = body
end

local function buildChicken(model: Model, s: number)
	local white = Color3.fromRGB(250, 250, 245)
	local red = Color3.fromRGB(220, 40, 40)
	local orange = Color3.fromRGB(245, 160, 40)
	local legH = 0.8 * s
	local body = block(model, "Body", Vector3.new(1.4, 1.3, 1.8) * s, CFrame.new(0, legH + 0.65 * s, 0), white)
	local head =
		block(model, "Head", Vector3.new(0.9, 0.9, 0.9) * s, body.CFrame * CFrame.new(0, 0.9 * s, -0.8 * s), white)
	block(model, "Comb", Vector3.new(0.25, 0.5, 0.7) * s, head.CFrame * CFrame.new(0, 0.6 * s, 0), red)
	block(model, "Beak", Vector3.new(0.35, 0.3, 0.4) * s, head.CFrame * CFrame.new(0, -0.05 * s, -0.6 * s), orange)
	block(model, "Wattle", Vector3.new(0.2, 0.35, 0.15) * s, head.CFrame * CFrame.new(0, -0.45 * s, -0.45 * s), red)
	block(model, "TailFeathers", Vector3.new(1, 0.9, 0.5) * s, body.CFrame * CFrame.new(0, 0.4 * s, 1 * s), white)
	for _, x in { -1, 1 } do
		block(model, "Leg", Vector3.new(0.2 * s, legH, 0.2 * s), CFrame.new(x * 0.35 * s, legH / 2, 0), orange)
		block(
			model,
			"Wing",
			Vector3.new(0.2, 0.8, 1.2) * s,
			body.CFrame * CFrame.new(x * 0.78 * s, 0.05 * s, 0.1 * s),
			Color3.fromRGB(235, 235, 230)
		)
	end
	model.PrimaryPart = body
end

local function buildGoat(model: Model, s: number)
	local coat = Color3.fromRGB(235, 228, 215)
	local patch = Color3.fromRGB(140, 100, 70)
	local horn = Color3.fromRGB(120, 115, 105)
	local dark = Color3.fromRGB(40, 35, 30)
	local legH = 1.7 * s
	local body = block(model, "Body", Vector3.new(1.7, 1.6, 3) * s, CFrame.new(0, legH + 0.8 * s, 0), coat)
	block(model, "Patch", Vector3.new(1.75, 0.9, 1.2) * s, body.CFrame * CFrame.new(0, 0.4 * s, 0.5 * s), patch)
	local head = block(
		model,
		"Head",
		Vector3.new(1, 1.1, 1.4) * s,
		body.CFrame * CFrame.new(0, 1 * s, -1.8 * s) * CFrame.Angles(math.rad(-15), 0, 0),
		coat
	)
	block(model, "Beard", Vector3.new(0.35, 0.7, 0.25) * s, head.CFrame * CFrame.new(0, -0.8 * s, -0.4 * s), coat)
	for _, x in { -1, 1 } do
		block(
			model,
			"Horn",
			Vector3.new(0.22, 0.9, 0.22) * s,
			head.CFrame * CFrame.new(x * 0.3 * s, 0.85 * s, 0.35 * s) * CFrame.Angles(math.rad(35), 0, 0),
			horn
		)
		block(
			model,
			"Ear",
			Vector3.new(0.6, 0.2, 0.3) * s,
			head.CFrame * CFrame.new(x * 0.7 * s, 0.25 * s, 0.1 * s) * CFrame.Angles(0, 0, x * math.rad(-20)),
			coat
		)
		block(
			model,
			"Eye",
			Vector3.new(0.1, 0.2, 0.2) * s,
			head.CFrame * CFrame.new(x * 0.51 * s, 0.15 * s, -0.35 * s),
			dark
		)
		for _, z in { -1, 1 } do
			block(
				model,
				"Leg",
				Vector3.new(0.4 * s, legH, 0.4 * s),
				CFrame.new(x * 0.55 * s, legH / 2, z * 1.1 * s),
				coat
			)
			block(
				model,
				"Hoof",
				Vector3.new(0.45, 0.25, 0.45) * s,
				CFrame.new(x * 0.55 * s, 0.12 * s, z * 1.1 * s),
				dark
			)
		end
	end
	block(
		model,
		"Tail",
		Vector3.new(0.25, 0.6, 0.25) * s,
		body.CFrame * CFrame.new(0, 0.7 * s, 1.55 * s) * CFrame.Angles(math.rad(-30), 0, 0),
		coat
	)
	model.PrimaryPart = body
end

-- Balık: elips gövde, açık renkli karın, yüzgeçler, çatal kuyruk. -Z yönüne yüzer.
local function buildFishModel(model: Model, s: number, back: Color3, belly: Color3, length: number)
	local body = block(model, "Body", Vector3.new(0.7, 0.8, length) * s, CFrame.new(0, 0, 0), back)
	local bodyMesh = Instance.new("SpecialMesh")
	bodyMesh.MeshType = Enum.MeshType.Sphere
	bodyMesh.Parent = body
	local bellyPart =
		block(model, "Belly", Vector3.new(0.6, 0.45, length * 0.85) * s, CFrame.new(0, -0.18 * s, 0), belly)
	local bellyMesh = Instance.new("SpecialMesh")
	bellyMesh.MeshType = Enum.MeshType.Sphere
	bellyMesh.Parent = bellyPart
	for _, x in { -1, 1 } do
		block(
			model,
			"Eye",
			Vector3.new(0.08, 0.14, 0.14) * s,
			CFrame.new(x * 0.3 * s, 0.1 * s, -length * 0.36 * s),
			Color3.fromRGB(20, 20, 25)
		)
		block(
			model,
			"Fin",
			Vector3.new(0.05, 0.3, 0.45) * s,
			CFrame.new(x * 0.36 * s, -0.1 * s, -length * 0.1 * s) * CFrame.Angles(0, 0, x * math.rad(40)),
			back
		)
	end
	block(model, "DorsalFin", Vector3.new(0.05, 0.4, length * 0.35) * s, CFrame.new(0, 0.5 * s, 0), back)
	for _, angle in { 30, -30 } do
		block(
			model,
			"Tail",
			Vector3.new(0.05, 0.55, 0.45) * s,
			CFrame.new(0, 0, length * 0.55 * s) * CFrame.Angles(math.rad(angle), 0, 0) * CFrame.new(0, 0, 0.15 * s),
			back
		)
	end
	model.PrimaryPart = body
end

local function buildAnchovy(model: Model, s: number)
	buildFishModel(model, s * 0.9, Color3.fromRGB(70, 110, 150), Color3.fromRGB(215, 225, 235), 2)
end

local function buildSeabass(model: Model, s: number)
	buildFishModel(model, s * 1.4, Color3.fromRGB(110, 120, 130), Color3.fromRGB(230, 232, 235), 2.4)
end

local function buildDuck(model: Model, s: number)
	local white = Color3.fromRGB(252, 250, 240)
	local yellow = Color3.fromRGB(248, 190, 50)
	local orange = Color3.fromRGB(245, 140, 40)
	local dark = Color3.fromRGB(30, 30, 30)
	local legH = 0.5 * s
	local body = block(model, "Body", Vector3.new(1.5, 1.2, 2.1) * s, CFrame.new(0, legH + 0.6 * s, 0), white)
	local neck =
		block(model, "Neck", Vector3.new(0.6, 0.9, 0.6) * s, body.CFrame * CFrame.new(0, 0.85 * s, -0.75 * s), white)
	local head =
		block(model, "Head", Vector3.new(0.85, 0.8, 0.9) * s, neck.CFrame * CFrame.new(0, 0.65 * s, -0.1 * s), white)
	block(model, "Bill", Vector3.new(0.6, 0.22, 0.55) * s, head.CFrame * CFrame.new(0, -0.1 * s, -0.7 * s), orange)
	block(
		model,
		"Tail",
		Vector3.new(0.7, 0.5, 0.5) * s,
		body.CFrame * CFrame.new(0, 0.35 * s, 1.15 * s) * CFrame.Angles(math.rad(25), 0, 0),
		white
	)
	for _, x in { -1, 1 } do
		block(
			model,
			"Eye",
			Vector3.new(0.1, 0.16, 0.16) * s,
			head.CFrame * CFrame.new(x * 0.44 * s, 0.12 * s, -0.25 * s),
			dark
		)
		block(
			model,
			"Wing",
			Vector3.new(0.2, 0.8, 1.3) * s,
			body.CFrame * CFrame.new(x * 0.8 * s, 0.05 * s, 0.15 * s),
			Color3.fromRGB(235, 232, 220)
		)
		block(model, "Foot", Vector3.new(0.45, 0.14, 0.7) * s, CFrame.new(x * 0.4 * s, 0.07 * s, -0.1 * s), yellow)
		block(model, "Leg", Vector3.new(0.14 * s, legH, 0.14 * s), CFrame.new(x * 0.4 * s, legH / 2, 0), orange)
	end
	model.PrimaryPart = body
end

local function buildSheep(model: Model, s: number)
	local wool = Color3.fromRGB(245, 242, 232)
	local face = Color3.fromRGB(60, 52, 48)
	local dark = Color3.fromRGB(25, 22, 20)
	local legH = 1.3 * s
	local body = block(model, "Body", Vector3.new(2.2, 1.9, 3) * s, CFrame.new(0, legH + 0.95 * s, 0), wool)
	body.Material = Enum.Material.Fabric
	for _, offset in
		{
			Vector3.new(-0.7, 1.1, -0.8),
			Vector3.new(0.7, 1.1, -0.2),
			Vector3.new(-0.5, 1.1, 0.9),
			Vector3.new(0.6, 1.05, 1.1),
		}
	do
		local tuft = block(model, "Wool", Vector3.new(1.1, 0.9, 1.1) * s, body.CFrame * CFrame.new(offset * s), wool)
		tuft.Material = Enum.Material.Fabric
	end
	local head =
		block(model, "Head", Vector3.new(1, 1.1, 1.2) * s, body.CFrame * CFrame.new(0, 0.5 * s, -1.9 * s), face)
	block(model, "Fringe", Vector3.new(1.2, 0.5, 0.9) * s, head.CFrame * CFrame.new(0, 0.75 * s, 0.2 * s), wool).Material =
		Enum.Material.Fabric
	for _, x in { -1, 1 } do
		block(
			model,
			"Ear",
			Vector3.new(0.6, 0.22, 0.35) * s,
			head.CFrame * CFrame.new(x * 0.75 * s, 0.25 * s, 0.1 * s) * CFrame.Angles(0, 0, x * math.rad(-25)),
			face
		)
		block(
			model,
			"Eye",
			Vector3.new(0.1, 0.2, 0.2) * s,
			head.CFrame * CFrame.new(x * 0.51 * s, 0.15 * s, -0.4 * s),
			Color3.fromRGB(240, 240, 235)
		)
		for _, z in { -1, 1 } do
			block(
				model,
				"Leg",
				Vector3.new(0.4 * s, legH, 0.4 * s),
				CFrame.new(x * 0.7 * s, legH / 2, z * 1.05 * s),
				face
			)
			block(model, "Hoof", Vector3.new(0.45, 0.2, 0.45) * s, CFrame.new(x * 0.7 * s, 0.1 * s, z * 1.05 * s), dark)
		end
	end
	model.PrimaryPart = body
end

local function buildPig(model: Model, s: number)
	local pink = Color3.fromRGB(245, 175, 180)
	local darkPink = Color3.fromRGB(225, 140, 150)
	local dark = Color3.fromRGB(35, 30, 30)
	local legH = 0.9 * s
	local body = block(model, "Body", Vector3.new(2.2, 1.9, 3.1) * s, CFrame.new(0, legH + 0.95 * s, 0), pink)
	local head =
		block(model, "Head", Vector3.new(1.5, 1.4, 1.3) * s, body.CFrame * CFrame.new(0, 0.2 * s, -2.05 * s), pink)
	block(model, "Snout", Vector3.new(0.95, 0.7, 0.4) * s, head.CFrame * CFrame.new(0, -0.15 * s, -0.8 * s), darkPink)
	block(
		model,
		"Tail",
		Vector3.new(0.2, 0.2, 0.7) * s,
		body.CFrame * CFrame.new(0, 0.5 * s, 1.75 * s) * CFrame.Angles(math.rad(-30), 0, 0),
		darkPink
	)
	for _, x in { -1, 1 } do
		block(
			model,
			"Ear",
			Vector3.new(0.45, 0.6, 0.2) * s,
			head.CFrame * CFrame.new(x * 0.6 * s, 0.85 * s, 0.1 * s) * CFrame.Angles(math.rad(-25), 0, x * math.rad(20)),
			darkPink
		)
		block(
			model,
			"Eye",
			Vector3.new(0.1, 0.2, 0.2) * s,
			head.CFrame * CFrame.new(x * 0.76 * s, 0.25 * s, -0.4 * s),
			dark
		)
		block(
			model,
			"Nostril",
			Vector3.new(0.12, 0.2, 0.05) * s,
			head.CFrame * CFrame.new(x * 0.22 * s, -0.15 * s, -1.02 * s),
			dark
		)
		for _, z in { -1, 1 } do
			block(
				model,
				"Leg",
				Vector3.new(0.5 * s, legH, 0.5 * s),
				CFrame.new(x * 0.7 * s, legH / 2, z * 1.1 * s),
				darkPink
			)
		end
	end
	model.PrimaryPart = body
end

local BUILDERS: { [string]: (Model, number) -> () } = {
	duck = buildDuck,
	sheep = buildSheep,
	pig = buildPig,
	cow = buildCow,
	horse = buildHorse,
	chicken = buildChicken,
	goat = buildGoat,
	anchovy = buildAnchovy,
	seabass = buildSeabass,
}

local function cloneAssetAnimal(animalId: string, scale: number): Model?
	local assets = ServerStorage:FindFirstChild("Assets") or ReplicatedStorage:FindFirstChild("Assets")
	local animalsFolder = assets and assets:FindFirstChild("Animals")
	local template = animalsFolder and animalsFolder:FindFirstChild(animalId)
	if not template or not template:IsA("Model") then
		return nil
	end

	local clone = AssetSanitizer.clone(template, false)
	if scale ~= 1 then
		clone:ScaleTo(clone:GetScale() * scale)
	end
	return clone
end

local function createAnimalVisual(animalId: string, stage: string): Model
	local scale = STAGE_SCALE[stage] or 1
	local asset = cloneAssetAnimal(animalId, scale)
	if asset then
		return asset
	end
	local model = Instance.new("Model")
	local builder = BUILDERS[animalId] or buildCow
	builder(model, scale)
	return model
end

return {
	createAnimalVisual = createAnimalVisual,
}
