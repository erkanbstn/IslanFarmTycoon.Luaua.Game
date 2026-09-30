--!strict
-- Yol, çit, fıçı, sandık, posta kutusu, saman balyası, korkuluk, el arabası ve toplu optimizasyon.
-- WorldDecor cephesi bunları birleştirir; her zaman `WorldDecor.<ad>` ile kullan.

local Parts = require(script.Parent:WaitForChild("DecorParts"))

local part = Parts.part
local ball = Parts.ball
local column = Parts.column

local Props = {}

-- Taş yol: zeminin hemen üstünde ince parça. Kesişen yollar aynı yükseklikte olursa titrer (z-fighting),
-- bu yüzden her yol bir öncekinden birkaç milim yüksek.
local pathLayer = 0

function Props.path(parent: Instance, from: Vector3, to: Vector3, width: number)
	local flat = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	local length = flat.Magnitude
	if length < 0.1 then
		return
	end
	pathLayer = (pathLayer + 1) % 6
	local y = from.Y + 0.08 + pathLayer * 0.03
	local a = Vector3.new(from.X, y, from.Z)
	local cf = CFrame.lookAt(a + flat / 2, a + flat)
	local p = part(
		parent,
		"Path",
		Vector3.new(width, 0.16, length + width * 0.6),
		cf,
		Color3.fromRGB(150, 145, 135),
		Enum.Material.Cobblestone
	)
	p.CastShadow = false
end

-- Çapraz iki ince levhadan oluşan çim tutamları ve ara sıra çiçekler. Çarpışmaz, sorgulanmaz.
-- base: ada/bölge yüzeyinde (Y yüzeyde) CFrame. Sabit tohum: aynı harita her seferinde aynı çıkar.
-- Çizim maliyeti: küçük süs parçaları gölge düşürmez; çarpışmayan parçalar ışın sorgularına girmez.
-- Kurulum/dekor bittikten sonra bir kez çağrılır (gölge haritası ve Raycast maliyetini düşürür).
function Props.optimize(root: Instance)
	for _, descendant in root:GetDescendants() do
		if descendant:IsA("BasePart") then
			if not descendant.CanCollide then
				descendant.CanQuery = false
			end
			local size = descendant.Size
			if descendant.CastShadow and math.max(size.X, size.Y, size.Z) < 1.6 then
				descendant.CastShadow = false
			end
		end
	end
end

function Props.barrel(parent: Instance, base: CFrame)
	local model = Instance.new("Model")
	model.Name = "Barrel"
	model.Parent = parent
	column(model, "Body", 2, 2.6, base * CFrame.new(0, 1.3, 0), Color3.fromRGB(135, 90, 55), Enum.Material.WoodPlanks)
	for _, y in { 0.5, 2.1 } do
		column(model, "Hoop", 2.1, 0.2, base * CFrame.new(0, y, 0), Color3.fromRGB(70, 70, 75), Enum.Material.Metal)
	end
end

function Props.crate(parent: Instance, base: CFrame, size: number)
	local model = Instance.new("Model")
	model.Name = "Crate"
	model.Parent = parent
	part(
		model,
		"Box",
		Vector3.one * size,
		base * CFrame.new(0, size / 2, 0),
		Color3.fromRGB(170, 125, 75),
		Enum.Material.WoodPlanks
	)
	-- Köşe çıtaları
	for _, x in { -1, 1 } do
		part(
			model,
			"Slat",
			Vector3.new(0.2, size + 0.05, 0.2),
			base * CFrame.new(x * (size / 2 - 0.05), size / 2, -(size / 2 - 0.05)),
			Color3.fromRGB(120, 85, 50),
			Enum.Material.Wood
		)
	end
end

function Props.mailbox(parent: Instance, base: CFrame)
	local model = Instance.new("Model")
	model.Name = "Mailbox"
	model.Parent = parent
	part(
		model,
		"Post",
		Vector3.new(0.4, 3.2, 0.4),
		base * CFrame.new(0, 1.6, 0),
		Color3.fromRGB(110, 80, 50),
		Enum.Material.Wood
	)
	part(
		model,
		"Box",
		Vector3.new(1, 0.9, 1.6),
		base * CFrame.new(0, 3.5, 0),
		Color3.fromRGB(200, 60, 55),
		Enum.Material.Metal
	)
	part(
		model,
		"Flag",
		Vector3.new(0.1, 0.8, 0.3),
		base * CFrame.new(0.55, 3.8, 0.3),
		Color3.fromRGB(250, 220, 80),
		Enum.Material.SmoothPlastic
	)
end

-- Alçak ahşap çit: iki nokta arası, direkler ve iki tahta (çarpışmaz; yalnızca yolu çerçeveler)
function Props.fenceRun(parent: Instance, from: Vector3, to: Vector3)
	local model = Instance.new("Model")
	model.Name = "Fence"
	model.Parent = parent
	local delta = to - from
	local length = delta.Magnitude
	if length < 1 then
		return
	end
	local dir = delta.Unit
	local posts = math.max(2, math.floor(length / 4) + 1)
	local wood = Color3.fromRGB(150, 110, 70)
	local dark = Color3.fromRGB(120, 85, 52)
	for i = 0, posts - 1 do
		local p = from + dir * (length * i / (posts - 1))
		local post = part(
			model,
			"Post",
			Vector3.new(0.4, 2.2, 0.4),
			CFrame.new(p + Vector3.new(0, 1.1, 0)),
			dark,
			Enum.Material.Wood
		)
		post.CanCollide = false
	end
	local mid = from + delta / 2
	for _, y in { 0.8, 1.6 } do
		local rail = part(
			model,
			"Rail",
			Vector3.new(0.18, 0.28, length),
			CFrame.lookAt(mid + Vector3.new(0, y, 0), mid + Vector3.new(0, y, 0) + dir),
			wood,
			Enum.Material.WoodPlanks
		)
		rail.CanCollide = false
	end
end

-- Saman balyası (küçük yığınlar için); stack: üstüne konacak ikinci bale
function Props.hayBale(parent: Instance, base: CFrame, stack: boolean?)
	local model = Instance.new("Model")
	model.Name = "HayBale"
	model.Parent = parent
	local straw = Color3.fromRGB(226, 190, 96)
	column(
		model,
		"Bale",
		2.2,
		2.6,
		base * CFrame.new(0, 1.1, 0) * CFrame.Angles(math.rad(90), 0, 0),
		straw,
		Enum.Material.Fabric
	)
	for _, z in { -0.55, 0.55 } do
		part(
			model,
			"Twine",
			Vector3.new(2.3, 0.08, 0.1),
			base * CFrame.new(0, 1.1, z),
			Color3.fromRGB(150, 110, 60),
			Enum.Material.Fabric
		)
	end
	if stack then
		column(
			model,
			"TopBale",
			2.2,
			2.6,
			base * CFrame.new(0.2, 3.1, 0) * CFrame.Angles(math.rad(90), math.rad(25), 0),
			straw,
			Enum.Material.Fabric
		)
	end
end

function Props.scarecrow(parent: Instance, base: CFrame)
	local model = Instance.new("Model")
	model.Name = "Scarecrow"
	model.Parent = parent
	local wood = Color3.fromRGB(120, 88, 54)
	part(model, "Pole", Vector3.new(0.35, 5.2, 0.35), base * CFrame.new(0, 2.6, 0), wood, Enum.Material.Wood)
	part(model, "Arms", Vector3.new(4, 0.3, 0.3), base * CFrame.new(0, 3.9, 0), wood, Enum.Material.Wood)
	part(
		model,
		"Shirt",
		Vector3.new(1.5, 1.8, 0.8),
		base * CFrame.new(0, 3.3, 0),
		Color3.fromRGB(190, 70, 60),
		Enum.Material.Fabric
	)
	ball(model, "Head", 1.3, base * CFrame.new(0, 5.2, 0), Color3.fromRGB(226, 190, 96), Enum.Material.Fabric)
	column(model, "HatBrim", 2.2, 0.15, base * CFrame.new(0, 5.8, 0), Color3.fromRGB(95, 70, 45), Enum.Material.Fabric)
	column(model, "HatTop", 1.1, 0.9, base * CFrame.new(0, 6.3, 0), Color3.fromRGB(95, 70, 45), Enum.Material.Fabric)
end

function Props.wheelbarrow(parent: Instance, base: CFrame)
	local model = Instance.new("Model")
	model.Name = "Wheelbarrow"
	model.Parent = parent
	part(
		model,
		"Tray",
		Vector3.new(2.2, 0.9, 3),
		base * CFrame.new(0, 1.3, 0),
		Color3.fromRGB(70, 130, 90),
		Enum.Material.Metal
	)
	part(
		model,
		"Hay",
		Vector3.new(1.8, 0.5, 2.5),
		base * CFrame.new(0, 1.85, 0),
		Color3.fromRGB(226, 190, 96),
		Enum.Material.Fabric
	)
	column(
		model,
		"Wheel",
		1.3,
		0.3,
		base * CFrame.new(0, 0.65, -1.8) * CFrame.Angles(0, math.rad(90), 0),
		Color3.fromRGB(45, 45, 50),
		Enum.Material.Rubber
	)
	for _, x in { -0.8, 0.8 } do
		part(
			model,
			"Handle",
			Vector3.new(0.18, 0.18, 2),
			base * CFrame.new(x, 1.1, 2.2),
			Color3.fromRGB(150, 110, 70),
			Enum.Material.Wood
		)
		part(
			model,
			"Leg",
			Vector3.new(0.2, 1.1, 0.2),
			base * CFrame.new(x, 0.55, 1.5),
			Color3.fromRGB(120, 85, 52),
			Enum.Material.Wood
		)
	end
end

return Props
