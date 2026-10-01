--!strict
-- Deniz dibi: yosun ormanları, mercanlar, kayalar, deniz yıldızları, kabarcıklar, dipte ve orta suda
-- yüzen balık sürüleri ve denizanaları.
-- Sadece görsel ve sadece bu oyuncunun ekranında (sunucuya yük yok). Dekor kameranın çevresindeki
-- hücrelerde üretilir/silinir; uzaktaki hücreler ve sürüler güncellenmez. Yosunlar dalgalanır.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local StartupGate = require(script.Parent.Parent:WaitForChild("Core"):WaitForChild("StartupGate"))
StartupGate.wait(3.5)

local localPlayer = Players.LocalPlayer

local SEABED_Y = -20 -- MapBuilder: WATER_DEPTH; kum yüzeyi
local WATER_Y = 0
local CELL = 36
local HUB_RADIUS = 40
local ANIMATE_DISTANCE = 80
local CELLS_PER_FRAME = 2
-- Kamera su yüzeyinin bu kadar üstündeyse deniz dibi uzaktır: 15 Hz yeter (sahnede zaten kıpırtısı seçilmez).
local HIGH_CAMERA_Y = 40
local HIGH_CAMERA_INTERVAL = 1 / 15

local QUALITY = {
	-- kelp: yosun; bubbles: kabarcık; jellyPulse: denizanası çanı nabız atar (Size yazar; yalnızca yüksekte)
	low = { radius = 55, schools = 3, jellies = 0, bubbles = false, kelp = false, jellyPulse = false },
	medium = { radius = 85, schools = 6, jellies = 2, bubbles = true, kelp = true, jellyPulse = false },
	high = { radius = 110, schools = 10, jellies = 4, bubbles = true, kelp = true, jellyPulse = true },
}

local KELP_COLORS = {
	Color3.fromRGB(46, 128, 62),
	Color3.fromRGB(64, 152, 74),
	Color3.fromRGB(92, 164, 70),
	Color3.fromRGB(38, 110, 82),
}
local CORAL_COLORS = {
	Color3.fromRGB(240, 110, 130),
	Color3.fromRGB(245, 150, 70),
	Color3.fromRGB(170, 100, 220),
	Color3.fromRGB(250, 205, 80),
	Color3.fromRGB(90, 200, 200),
}
local FISH_COLORS = {
	Color3.fromRGB(240, 140, 50),
	Color3.fromRGB(80, 150, 230),
	Color3.fromRGB(250, 215, 70),
	Color3.fromRGB(200, 210, 225),
	Color3.fromRGB(230, 90, 110),
	Color3.fromRGB(110, 210, 170),
}

local random = Random.new()
local folder = Instance.new("Folder")
folder.Name = "SeabedLife"
folder.Parent = Workspace

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include
rayParams.FilterDescendantsInstances = { Workspace.Terrain }
rayParams.IgnoreWater = true

local function newPart(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material,
	shape: Enum.PartType?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.Anchored = true
	p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = false, false, false, false
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	if shape then
		p.Shape = shape
	end
	p.Parent = parent
	return p
end

---------------------------------------------------------------------------
-- Adalar / açık su
---------------------------------------------------------------------------

type Circle = { x: number, z: number, radius: number }
local circles: { Circle } = {}

local function collectCircles()
	table.clear(circles)
	table.insert(circles, { x = 0, z = 0, radius = HUB_RADIUS + 12 })
	local plots = Workspace:FindFirstChild("Plots")
	if plots then
		for _, desc in plots:GetDescendants() do
			if desc:IsA("BasePart") and (desc.Name == "PlotBase" or desc.Name == "IslandBase") then
				-- Silindirin çapı Size.Y (ekseni X); kıyı kayaları ve plaj için pay bırak
				table.insert(circles, { x = desc.Position.X, z = desc.Position.Z, radius = desc.Size.Y / 2 + 14 })
			elseif desc:IsA("BasePart") and desc:GetAttribute("SwimDepth") then
				table.insert(
					circles,
					{ x = desc.Position.X, z = desc.Position.Z, radius = math.max(desc.Size.X, desc.Size.Z) / 2 + 8 }
				)
			end
		end
	end
end

local function isOpenWater(x: number, z: number): boolean
	for _, circle in circles do
		local dx, dz = x - circle.x, z - circle.z
		if dx * dx + dz * dz < circle.radius * circle.radius then
			return false
		end
	end
	return true
end

-- Deniz tabanının gerçek yüksekliği (Terrain'e ışın); bulunamazsa nil
local function seabedAt(x: number, z: number): number?
	local result = Workspace:Raycast(Vector3.new(x, WATER_Y - 1, z), Vector3.new(0, -40, 0), rayParams)
	if result and result.Instance == Workspace.Terrain and result.Position.Y < WATER_Y - 6 then
		return result.Position.Y
	end
	return nil
end

---------------------------------------------------------------------------
-- Dip dekoru hücreleri
---------------------------------------------------------------------------

type Blade = { lower: Part, upper: Part, base: CFrame, height: number, phase: number, amplitude: number }
type Bubble = { part: Part, x: number, z: number, floorY: number, speed: number, offset: number, wobble: number }
type Cell = { model: Model, center: Vector3, blades: { Blade }, bubbles: { Bubble } }
local cells: { [string]: Cell } = {}

local function buildKelp(cell: Cell, x: number, z: number, y: number, rng: Random)
	local count = rng:NextInteger(4, 7)
	local color = KELP_COLORS[rng:NextInteger(1, #KELP_COLORS)]
	for _ = 1, count do
		local height = rng:NextNumber(6, 13)
		local half = height / 2
		local offset = Vector3.new(rng:NextNumber(-2, 2), 0, rng:NextNumber(-2, 2))
		local base = CFrame.new(x + offset.X, y - 0.3, z + offset.Z) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0)
		local shade = color:Lerp(Color3.fromRGB(120, 190, 80), rng:NextNumber(0, 0.35))
		table.insert(cell.blades, {
			lower = newPart(cell.model, "Kelp", Vector3.new(0.35, half, 1.1), base, shade, Enum.Material.Grass),
			upper = newPart(cell.model, "Kelp", Vector3.new(0.3, half, 0.75), base, shade, Enum.Material.Grass),
			base = base,
			height = height,
			phase = rng:NextNumber(0, math.pi * 2),
			amplitude = rng:NextNumber(0.10, 0.22),
		})
	end
end

local function buildCoral(cell: Cell, x: number, z: number, y: number, rng: Random)
	local color = CORAL_COLORS[rng:NextInteger(1, #CORAL_COLORS)]
	local kind = rng:NextInteger(1, 3)
	local origin = CFrame.new(x, y, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	if kind == 1 then
		-- Dallı mercan
		for _ = 1, rng:NextInteger(4, 6) do
			local height = rng:NextNumber(2.2, 4.4)
			local tilt =
				CFrame.Angles(rng:NextNumber(-0.5, 0.5), rng:NextNumber(0, math.pi * 2), rng:NextNumber(-0.5, 0.5))
			local branch = newPart(
				cell.model,
				"Coral",
				Vector3.new(height, 0.6, 0.6),
				origin
					* CFrame.new(rng:NextNumber(-0.9, 0.9), 0, rng:NextNumber(-0.9, 0.9))
					* tilt
					* CFrame.new(0, height / 2, 0)
					* CFrame.Angles(0, 0, math.rad(90)),
				color,
				Enum.Material.SmoothPlastic,
				Enum.PartType.Cylinder
			)
			newPart(
				cell.model,
				"CoralTip",
				Vector3.one * 0.9,
				branch.CFrame * CFrame.new(0, 0, 0) * CFrame.new(-height / 2, 0, 0),
				color:Lerp(Color3.new(1, 1, 1), 0.25),
				Enum.Material.SmoothPlastic,
				Enum.PartType.Ball
			)
		end
	elseif kind == 2 then
		-- Beyin mercanı: yassı yarım küre kümesi
		for i = 1, 3 do
			local size = rng:NextNumber(1.8, 3.2)
			newPart(
				cell.model,
				"Coral",
				Vector3.new(size, size * 0.6, size),
				origin * CFrame.new((i - 2) * 1.6, size * 0.15, rng:NextNumber(-0.7, 0.7)),
				color:Lerp(Color3.fromRGB(200, 170, 120), 0.2 * i),
				Enum.Material.Slate,
				Enum.PartType.Ball
			)
		end
	else
		-- Yelpaze mercanı: dik, geniş, ince disk
		for i = 1, 3 do
			local size = rng:NextNumber(2.6, 4.2)
			newPart(
				cell.model,
				"Coral",
				Vector3.new(0.2, size, size),
				origin
					* CFrame.new(i * 1.3 - 2.6, size / 2 - 0.3, rng:NextNumber(-0.6, 0.6))
					* CFrame.Angles(0, rng:NextNumber(-0.5, 0.5), math.rad(90)),
				color,
				Enum.Material.Neon,
				Enum.PartType.Cylinder
			).Transparency =
				0.15
		end
	end
end

local function buildRocks(cell: Cell, x: number, z: number, y: number, rng: Random)
	for _ = 1, rng:NextInteger(2, 4) do
		local size = Vector3.new(rng:NextNumber(1.5, 4.5), rng:NextNumber(1, 3), rng:NextNumber(1.5, 4.5))
		newPart(
			cell.model,
			"Rock",
			size,
			CFrame.new(x + rng:NextNumber(-3, 3), y + size.Y * 0.25, z + rng:NextNumber(-3, 3))
				* CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, math.pi * 2), rng:NextNumber(-0.3, 0.3)),
			Color3.fromRGB(110, 112, 118):Lerp(Color3.fromRGB(70, 95, 90), rng:NextNumber(0, 0.6)),
			Enum.Material.Slate
		)
	end
end

local function buildStarfish(cell: Cell, x: number, z: number, y: number, rng: Random)
	local color = Color3.fromRGB(240, 120, 70):Lerp(Color3.fromRGB(230, 90, 120), rng:NextNumber())
	local origin = CFrame.new(x, y + 0.12, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	for arm = 0, 4 do
		newPart(
			cell.model,
			"Starfish",
			Vector3.new(0.5, 0.25, 1.5),
			origin * CFrame.Angles(0, arm * math.pi * 2 / 5, 0) * CFrame.new(0, 0, 0.7),
			color,
			Enum.Material.SmoothPlastic
		)
	end
end

local function addBubbles(cell: Cell, x: number, z: number, y: number, rng: Random)
	for index = 1, 4 do
		local size = rng:NextNumber(0.3, 0.6)
		local bubble = newPart(
			cell.model,
			"Bubble",
			Vector3.one * size,
			CFrame.new(x, y, z),
			Color3.fromRGB(225, 245, 255),
			Enum.Material.Glass,
			Enum.PartType.Ball
		)
		bubble.Transparency = 0.45
		table.insert(cell.bubbles, {
			part = bubble,
			x = x,
			z = z,
			floorY = y + 1,
			speed = rng:NextNumber(2.2, 3.6),
			offset = index / 4 * 100,
			wobble = rng:NextNumber(0.2, 0.5),
		})
	end
end

local function cellKey(cx: number, cz: number): string
	return `{cx},{cz}`
end

local function createCell(cx: number, cz: number, withBubbles: boolean, withKelp: boolean)
	local key = cellKey(cx, cz)
	local rng = Random.new(math.abs(cx * 73856093 + cz * 19349663) % 2147483646 + 1)
	local model = Instance.new("Model")
	model.Name = `Seabed_{key}`
	local cell: Cell = {
		model = model,
		center = Vector3.new((cx + 0.5) * CELL, SEABED_Y, (cz + 0.5) * CELL),
		blades = {},
		bubbles = {},
	}
	local function spot(): (number?, number?, number?)
		local x = (cx + rng:NextNumber(0.08, 0.92)) * CELL
		local z = (cz + rng:NextNumber(0.08, 0.92)) * CELL
		if not isOpenWater(x, z) then
			return nil, nil, nil
		end
		local y = seabedAt(x, z)
		if not y then
			return nil, nil, nil
		end
		return x, z, y
	end
	-- Düşükte yosun kurulmaz (kalite değişince hücreler zaten sıfırdan kurulur)
	for _ = 1, rng:NextInteger(2, 3) do
		local x, z, y = spot()
		if x and z and y and withKelp then
			buildKelp(cell, x, z, y, rng)
		end
	end
	local coralSpots = 0
	for _ = 1, rng:NextInteger(1, 2) do
		local x, z, y = spot()
		if x and z and y then
			buildCoral(cell, x, z, y, rng)
			coralSpots += 1
			if withBubbles and rng:NextNumber() < 0.5 then
				addBubbles(cell, x, z, y + 2, rng)
			end
		end
	end
	for _ = 1, rng:NextInteger(1, 2) do
		local x, z, y = spot()
		if x and z and y then
			buildRocks(cell, x, z, y, rng)
		end
	end
	if rng:NextNumber() < 0.6 then
		local x, z, y = spot()
		if x and z and y then
			buildStarfish(cell, x, z, y, rng)
		end
	end
	model.Parent = folder
	cells[key] = cell
end

local function clearCells()
	for _, cell in cells do
		cell.model:Destroy()
	end
	table.clear(cells)
end

---------------------------------------------------------------------------
-- Balıklar ve denizanaları
---------------------------------------------------------------------------

type Fish = { body: Part, tail: Part, offset: Vector3, phase: number }
type School = { fish: { Fish }, center: Vector3, angle: number, speed: number, turn: number, seed: number }
type Jelly = { bell: Part, tentacles: { Part }, center: Vector3, phase: number, drift: Vector3 }
local schools: { School } = {}
local jellies: { Jelly } = {}
local creatures = Instance.new("Folder")
creatures.Name = "Creatures"
creatures.Parent = folder

local function makeFish(color: Color3, size: number): Fish
	local body = newPart(
		creatures,
		"Fish",
		Vector3.new(0.55, 0.55, 1.5) * size,
		CFrame.new(),
		color,
		Enum.Material.SmoothPlastic
	)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = body
	local tail = Instance.new("WedgePart")
	tail.Name = "Tail"
	tail.Size = Vector3.new(0.08, 0.6, 0.55) * size
	tail.Color = color:Lerp(Color3.new(1, 1, 1), 0.2)
	tail.Material = Enum.Material.SmoothPlastic
	tail.Anchored = true
	tail.CanCollide, tail.CanQuery, tail.CanTouch, tail.CastShadow = false, false, false, false
	tail.Parent = creatures
	return {
		body = body,
		tail = tail,
		offset = Vector3.new(random:NextNumber(-2.5, 2.5), random:NextNumber(-1, 1), random:NextNumber(-2.5, 2.5)),
		phase = random:NextNumber(0, math.pi * 2),
	}
end

local function pickWaterPoint(cameraPos: Vector3, minDistance: number, maxDistance: number): Vector3?
	for _ = 1, 8 do
		local angle = random:NextNumber(0, math.pi * 2)
		local distance = random:NextNumber(minDistance, maxDistance)
		local x = cameraPos.X + math.sin(angle) * distance
		local z = cameraPos.Z + math.cos(angle) * distance
		if isOpenWater(x, z) and math.abs(x) < 500 and math.abs(z) < 500 then
			return Vector3.new(x, 0, z)
		end
	end
	return nil
end

local function spawnSchool(cameraPos: Vector3)
	local point = pickWaterPoint(cameraPos, 30, 110)
	if not point then
		return
	end
	local color = FISH_COLORS[random:NextInteger(1, #FISH_COLORS)]
	local size = random:NextNumber(0.8, 1.5)
	local fish: { Fish } = {}
	for _ = 1, random:NextInteger(5, 8) do
		table.insert(fish, makeFish(color, size * random:NextNumber(0.85, 1.1)))
	end
	table.insert(schools, {
		fish = fish,
		center = Vector3.new(point.X, random:NextNumber(SEABED_Y + 4, -5), point.Z),
		angle = random:NextNumber(0, math.pi * 2),
		speed = random:NextNumber(3, 6),
		turn = random:NextNumber(-0.25, 0.25),
		seed = random:NextNumber(0, 100),
	})
end

local function destroySchool(index: number)
	local school = schools[index]
	for _, fish in school.fish do
		fish.body:Destroy()
		fish.tail:Destroy()
	end
	table.remove(schools, index)
end

local function spawnJelly(cameraPos: Vector3)
	local point = pickWaterPoint(cameraPos, 25, 90)
	if not point then
		return
	end
	local color = Color3.fromRGB(240, 150, 220):Lerp(Color3.fromRGB(150, 190, 255), random:NextNumber())
	local bell = newPart(
		creatures,
		"JellyBell",
		Vector3.new(2.4, 1.8, 2.4),
		CFrame.new(),
		color,
		Enum.Material.Neon,
		Enum.PartType.Ball
	)
	bell.Transparency = 0.45
	local tentacles = {}
	for _ = 1, 5 do
		local t =
			newPart(creatures, "JellyTentacle", Vector3.new(0.12, 2.6, 0.12), CFrame.new(), color, Enum.Material.Neon)
		t.Transparency = 0.55
		table.insert(tentacles, t)
	end
	table.insert(jellies, {
		bell = bell,
		tentacles = tentacles,
		center = Vector3.new(point.X, random:NextNumber(SEABED_Y + 5, -4), point.Z),
		phase = random:NextNumber(0, math.pi * 2),
		drift = Vector3.new(random:NextNumber(-0.6, 0.6), 0, random:NextNumber(-0.6, 0.6)),
	})
end

local function destroyJelly(index: number)
	local jelly = jellies[index]
	jelly.bell:Destroy()
	for _, t in jelly.tentacles do
		t:Destroy()
	end
	table.remove(jellies, index)
end

---------------------------------------------------------------------------
-- Döngü
---------------------------------------------------------------------------

local currentQuality = "high"
local function settings()
	local q = localPlayer:GetAttribute("EffectsQuality")
	currentQuality = if q == "low" or q == "medium" or q == "high" then q else "high"
	return QUALITY[currentQuality]
end

local lastCellCheck = 0
local pending: { { cx: number, cz: number, distance: number } } = {}
local bulkParts: { BasePart } = {}
local bulkCFrames: { CFrame } = {}

local function queueMove(part: BasePart, cf: CFrame)
	table.insert(bulkParts, part)
	table.insert(bulkCFrames, cf)
end

local function refreshCells(cameraPos: Vector3, config: typeof(QUALITY.high))
	local radius = config.radius
	local minCx, maxCx = math.floor((cameraPos.X - radius) / CELL), math.floor((cameraPos.X + radius) / CELL)
	local minCz, maxCz = math.floor((cameraPos.Z - radius) / CELL), math.floor((cameraPos.Z + radius) / CELL)
	-- Menzil dışına çıkan hücreleri sil
	for key, cell in cells do
		if (cell.center.X - cameraPos.X) ^ 2 + (cell.center.Z - cameraPos.Z) ^ 2 > (radius + CELL * 1.5) ^ 2 then
			cell.model:Destroy()
			cells[key] = nil
		end
	end
	table.clear(pending)
	for cx = minCx, maxCx do
		for cz = minCz, maxCz do
			local centerX, centerZ = (cx + 0.5) * CELL, (cz + 0.5) * CELL
			local distance = math.sqrt((centerX - cameraPos.X) ^ 2 + (centerZ - cameraPos.Z) ^ 2)
			if
				distance <= radius
				and not cells[cellKey(cx, cz)]
				and math.abs(centerX) < 520
				and math.abs(centerZ) < 520
			then
				table.insert(pending, { cx = cx, cz = cz, distance = distance })
			end
		end
	end
	table.sort(pending, function(a, b)
		return a.distance > b.distance -- sondan al: en yakın hücre önce oluşsun
	end)
end

local pendingDt = 0
local function update(frameDt: number)
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local cameraPos = camera.CFrame.Position
	pendingDt += frameDt
	if cameraPos.Y > HIGH_CAMERA_Y and pendingDt < HIGH_CAMERA_INTERVAL then
		return
	end
	local dt = pendingDt
	pendingDt = 0
	local config = settings()
	local reduced = localPlayer:GetAttribute("ReducedMotion") == true
	local now = os.clock()

	if now - lastCellCheck > 0.5 then
		lastCellCheck = now
		refreshCells(cameraPos, config)
	end
	for _ = 1, CELLS_PER_FRAME do
		local nextCell = table.remove(pending)
		if not nextCell then
			break
		end
		if not cells[cellKey(nextCell.cx, nextCell.cz)] then
			createCell(nextCell.cx, nextCell.cz, config.bubbles, config.kelp)
		end
	end

	table.clear(bulkParts)
	table.clear(bulkCFrames)

	if not reduced then
		-- Yosunlar dalgalanır, kabarcıklar yükselir (yakın hücrelerde)
		for _, cell in cells do
			local dx, dz = cell.center.X - cameraPos.X, cell.center.Z - cameraPos.Z
			if dx * dx + dz * dz > ANIMATE_DISTANCE * ANIMATE_DISTANCE then
				continue
			end
			for _, blade in cell.blades do
				local segment = blade.height / 2
				local a = math.sin(now * 1.1 + blade.phase) * blade.amplitude
				local b = math.sin(now * 1.5 + blade.phase + 1.2) * blade.amplitude * 1.5
				local pivot = blade.base * CFrame.Angles(a * 0.4, 0, a)
				local pivotTop = pivot * CFrame.new(0, segment, 0) * CFrame.Angles(b * 0.4, 0, b)
				queueMove(blade.lower, pivot * CFrame.new(0, segment / 2, 0))
				queueMove(blade.upper, pivotTop * CFrame.new(0, segment / 2, 0))
			end
			for _, bubble in cell.bubbles do
				local rise = (now * bubble.speed + bubble.offset) % (WATER_Y - 1 - bubble.floorY)
				queueMove(
					bubble.part,
					CFrame.new(
						bubble.x + math.sin(now * 2 + bubble.offset) * bubble.wobble,
						bubble.floorY + rise,
						bubble.z + math.cos(now * 1.7 + bubble.offset) * bubble.wobble
					)
				)
			end
		end

		-- Balık sürüleri
		while #schools < config.schools do
			local before = #schools
			spawnSchool(cameraPos)
			if #schools == before then
				break
			end
		end
		for index = #schools, 1, -1 do
			local school = schools[index]
			local flat = Vector3.new(school.center.X - cameraPos.X, 0, school.center.Z - cameraPos.Z)
			if flat.Magnitude > 150 or not isOpenWater(school.center.X, school.center.Z) or index > config.schools then
				destroySchool(index)
				continue
			end
			school.angle += (school.turn + math.sin(now * 0.2 + school.seed) * 0.25) * dt
			local heading = Vector3.new(math.sin(school.angle), 0, math.cos(school.angle))
			school.center += heading * school.speed * dt
			local bob = math.sin(now * 0.5 + school.seed) * 1.2
			local base = CFrame.lookAt(
				Vector3.new(school.center.X, school.center.Y + bob, school.center.Z),
				Vector3.new(school.center.X, school.center.Y + bob, school.center.Z) + heading
			)
			for _, fish in school.fish do
				local wobble = math.sin(now * 1.8 + fish.phase) * 0.5
				local cf = base
					* CFrame.new(fish.offset.X + wobble, fish.offset.Y, fish.offset.Z)
					* CFrame.Angles(0, math.sin(now * 3 + fish.phase) * 0.18, 0)
				queueMove(fish.body, cf)
				queueMove(
					fish.tail,
					cf
						* CFrame.new(0, 0, fish.body.Size.Z / 2 + fish.tail.Size.Z / 2 - 0.1)
						* CFrame.Angles(0, math.sin(now * 12 + fish.phase) * 0.55, 0)
				)
			end
		end

		-- Denizanaları: çan nabız gibi atar, dokunaçlar sallanır
		while #jellies < config.jellies do
			local before = #jellies
			spawnJelly(cameraPos)
			if #jellies == before then
				break
			end
		end
		for index = #jellies, 1, -1 do
			local jelly = jellies[index]
			local flat = Vector3.new(jelly.center.X - cameraPos.X, 0, jelly.center.Z - cameraPos.Z)
			if flat.Magnitude > 130 or not isOpenWater(jelly.center.X, jelly.center.Z) or index > config.jellies then
				destroyJelly(index)
				continue
			end
			local pulse = math.sin(now * 2.2 + jelly.phase)
			jelly.center += jelly.drift * dt + Vector3.new(0, pulse * 0.6 * dt, 0)
			jelly.center = Vector3.new(jelly.center.X, math.clamp(jelly.center.Y, SEABED_Y + 4, -3), jelly.center.Z)
			if config.jellyPulse then
				jelly.bell.Size = Vector3.new(2.4 - pulse * 0.25, 1.8 + pulse * 0.3, 2.4 - pulse * 0.25)
			end
			queueMove(jelly.bell, CFrame.new(jelly.center))
			for i, tentacle in jelly.tentacles do
				local angle = i / #jelly.tentacles * math.pi * 2
				local sway = math.sin(now * 2 + i + jelly.phase) * 0.25
				queueMove(
					tentacle,
					CFrame.new(jelly.center + Vector3.new(math.cos(angle) * 0.7, -1.9, math.sin(angle) * 0.7))
						* CFrame.Angles(sway, 0, sway * 0.6)
				)
			end
		end
	else
		while #schools > 0 do
			destroySchool(#schools)
		end
		while #jellies > 0 do
			destroyJelly(#jellies)
		end
	end

	if #bulkParts > 0 then
		Workspace:BulkMoveTo(bulkParts, bulkCFrames, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

-- Kalite değişince dekoru sıfırdan kur; adalar geç yüklenirse (streaming) daire listesini yenile.
localPlayer:GetAttributeChangedSignal("EffectsQuality"):Connect(function()
	clearCells()
	lastCellCheck = 0
end)
local rebuildScheduled = false
Workspace.DescendantAdded:Connect(function(instance: Instance)
	if
		instance:IsA("BasePart")
		and (instance.Name == "PlotBase" or instance.Name == "IslandBase" or instance.Name == "Ground")
		and not rebuildScheduled
	then
		rebuildScheduled = true
		task.defer(function()
			rebuildScheduled = false
			collectCircles()
			clearCells()
			lastCellCheck = 0
		end)
	end
end)

-- Su biraz daha berrak: dip görünsün (sadece bu client'ta).
pcall(function()
	Workspace.Terrain.WaterTransparency = 0.25
end)

collectCircles()
RunService.Heartbeat:Connect(update)
