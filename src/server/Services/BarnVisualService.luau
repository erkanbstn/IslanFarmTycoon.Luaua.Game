--!strict
-- Ahır binası: sabit ayak izi; seviye yükseldikçe malzeme ve ek parçalar değişir (ölçekleme yok).
-- Konum: plot içindeki "BarnSpot" parçası (LookVector = kapı yönü).
-- BarnSpot yoksa başlangıç bölgesinin zemini kullanılır.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Studio plugin'i modülleri kopyalayıp taze Config ile çalıştırır; o durumda yanımızdaki "Shared" kullanılır.
local Shared = script.Parent.Parent:FindFirstChild("Shared") or ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local WorldUi = require(Shared:WaitForChild("WorldUi"))

local BarnVisualService = {}

local WALL_COLOR = Color3.fromRGB(170, 45, 38)
local WALL_ACCENT = Color3.fromRGB(200, 75, 55)
local TRIM_COLOR = Color3.fromRGB(240, 235, 225)
local ROOF_COLOR = Color3.fromRGB(70, 60, 55)
local STONE_COLOR = Color3.fromRGB(120, 118, 110)

local function makePart(name: string, size: Vector3, cframe: CFrame, color: Color3, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Anchored = true
	part.Material = Enum.Material.WoodPlanks
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function getBarnFrame(plot: Model): CFrame?
	local spot = plot:FindFirstChild("BarnSpot")
	if spot and spot:IsA("BasePart") then
		return spot.CFrame
	end
	local zones = plot:FindFirstChild("Zones")
	if not zones then
		return nil
	end
	for _, zone in zones:GetChildren() do
		if zone:GetAttribute("ZoneId") == "starter" then
			local ground = zone:FindFirstChild("Ground")
			if ground and ground:IsA("BasePart") then
				return ground.CFrame * CFrame.new(0, ground.Size.Y / 2, 0)
			end
		end
	end
	return nil
end

-- Kapının iki yanında fener direkleri (tüm seviyelerde); geceleri DayNight (client) yakar.
local function addLanterns(barn: Model, frame: CFrame, doorW: number, depth: number)
	for _, x in { -doorW / 2 - 1.6, doorW / 2 + 1.6 } do
		local lamp = makePart(
			"LanternPost",
			Vector3.new(0.4, 7.6, 0.4),
			frame * CFrame.new(x, 3.8, -(depth / 2 + 1.1)),
			Color3.fromRGB(50, 40, 30),
			barn
		)
		local lantern = makePart(
			"Lantern",
			Vector3.new(0.9, 1.1, 0.9),
			lamp.CFrame * CFrame.new(0, 4.2, 0),
			Color3.fromRGB(205, 175, 115),
			barn
		)
		lantern.Material = Enum.Material.SmoothPlastic
		lantern:SetAttribute("NightColor", Color3.fromRGB(255, 214, 130))
		CollectionService:AddTag(lantern, "NightLight")
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 205, 130)
		light.Range = 22
		light.Brightness = 1.1
		light.Shadows = false
		light.Enabled = false
		light.Parent = lantern
	end
end

local function glowWindow(window: Part)
	window:SetAttribute("NightColor", Color3.fromRGB(255, 219, 140))
	CollectionService:AddTag(window, "NightWindow")
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 205, 130)
	light.Range = 9
	light.Brightness = 0.5
	light.Shadows = false
	light.Enabled = false
	light.Parent = window
end

local function addTierDetails(
	barn: Model,
	frame: CFrame,
	level: number,
	width: number,
	depth: number,
	wallH: number,
	doorW: number
)
	if level >= 2 then
		makePart(
			"StoneBase",
			Vector3.new(width + 1.2, 1.2, depth + 1.2),
			frame * CFrame.new(0, 0.6, 0),
			STONE_COLOR,
			barn
		).Material =
			Enum.Material.Cobblestone
		makePart(
			"TrimBand",
			Vector3.new(width + 0.4, 0.5, depth + 0.4),
			frame * CFrame.new(0, 1.25 + wallH * 0.55, 0),
			TRIM_COLOR,
			barn
		)
		local hayloft = makePart(
			"HayloftWindow",
			Vector3.new(3, 2, 0.2),
			frame * CFrame.new(0, 1 + wallH * 0.72, depth / 2 - 0.35),
			Color3.fromRGB(90, 120, 150),
			barn
		)
		hayloft.Material = Enum.Material.Glass
		glowWindow(hayloft)
	end
	if level >= 3 then
		for _, side in { -1, 1 } do
			local sideWindow = makePart(
				"SideWindow",
				Vector3.new(0.2, 2.2, 2.2),
				frame * CFrame.new(side * (width / 2 - 0.35), 1 + wallH * 0.55, 1.5),
				Color3.fromRGB(90, 120, 150),
				barn
			)
			sideWindow.Material = Enum.Material.Glass
			glowWindow(sideWindow)
		end
		local silo = makePart(
			"Silo",
			Vector3.new(3.5, 8, 3.5),
			frame * CFrame.new(width / 2 + 2.2, 4.5, depth / 2 - 2),
			TRIM_COLOR,
			barn
		)
		silo.Material = Enum.Material.Metal
	end
	if level >= 4 then
		makePart(
			"UpperWall",
			Vector3.new(width - 0.5, wallH * 0.35, depth - 0.5),
			frame * CFrame.new(0, 1 + wallH * 0.82, 0),
			WALL_ACCENT,
			barn
		)
		makePart(
			"Chimney",
			Vector3.new(1.4, 4.5, 1.4),
			frame * CFrame.new(-width / 2 + 2, 1 + wallH + 2.2, depth / 2 - 2),
			STONE_COLOR,
			barn
		).Material =
			Enum.Material.Brick
	end
end

-- frame: zemin yüzeyinde, LookVector (-Z) kapı yönü
local function buildBarn(parent: Instance, frame: CFrame, barnLevel: number)
	local levelConfig = Config.getBarnLevelConfig(barnLevel)
	local tier = math.clamp(barnLevel, 1, 4)

	-- Karakter (~5.5 stud) rahatça girsin: geniş ve yüksek kapı, yüksek iç mekân.
	local width, depth = 18, 12
	local wallH = 11
	local doorW, doorH = 8, 8.5

	local barn = Instance.new("Model")
	barn.Name = "Barn"

	local floor = makePart(
		"Floor",
		Vector3.new(width, 1, depth),
		frame * CFrame.new(0, 0.5, 0),
		Color3.fromRGB(139, 95, 55),
		barn
	)
	local wallY = 1 + wallH / 2
	local wallColor = if tier >= 4 then WALL_ACCENT else WALL_COLOR

	makePart("WallBack", Vector3.new(width, wallH, 1), frame * CFrame.new(0, wallY, depth / 2 - 0.5), wallColor, barn)
	for _, side in { -1, 1 } do
		makePart(
			"WallSide",
			Vector3.new(1, wallH, depth),
			frame * CFrame.new(side * (width / 2 - 0.5), wallY, 0),
			wallColor,
			barn
		)
		local frontW = (width - doorW) / 2
		makePart(
			"WallFront",
			Vector3.new(frontW, wallH, 1),
			frame * CFrame.new(side * (doorW / 2 + frontW / 2), wallY, -(depth / 2 - 0.5)),
			wallColor,
			barn
		)
		-- Beyaz köşe direkleri
		for _, z in { -1, 1 } do
			makePart(
				"Trim",
				Vector3.new(1.2, wallH, 1.2),
				frame * CFrame.new(side * (width / 2 - 0.5), wallY, z * (depth / 2 - 0.5)),
				TRIM_COLOR,
				barn
			)
		end
	end
	local aboveDoorH = wallH - doorH
	local aboveDoorY = 1 + doorH + aboveDoorH / 2
	makePart(
		"WallFrontTop",
		Vector3.new(doorW, aboveDoorH, 1),
		frame * CFrame.new(0, aboveDoorY, -(depth / 2 - 0.5)),
		wallColor,
		barn
	)

	addTierDetails(barn, frame, tier, width, depth, wallH, doorW)
	addLanterns(barn, frame, doorW, depth)

	-- Giriş basamağı (zemin 1 stud yüksekte) ve içeride samanlık/fıçılar
	makePart(
		"DoorStep",
		Vector3.new(doorW, 0.5, 2.4),
		frame * CFrame.new(0, 0.25, -(depth / 2 + 1.2)),
		STONE_COLOR,
		barn
	).Material =
		Enum.Material.Cobblestone
	local hayColor = Color3.fromRGB(225, 195, 110)
	for index, offset in { Vector3.new(-6.2, 0, 4), Vector3.new(-6.2, 0, 1.6), Vector3.new(6.2, 0, 4) } do
		makePart(
			"HayBale",
			Vector3.new(2.6, 1.6, 1.6),
			frame * CFrame.new(offset + Vector3.new(0, 1.8, 0)),
			hayColor,
			barn
		).Material =
			Enum.Material.Fabric
		if index == 1 then
			makePart("HayBale", Vector3.new(2.6, 1.6, 1.6), frame * CFrame.new(-6.2, 3.4, 3), hayColor, barn).Material =
				Enum.Material.Fabric
		end
	end
	local rail = makePart("StallRail", Vector3.new(0.3, 2.6, 5), frame * CFrame.new(6.2, 2.3, -1.2), TRIM_COLOR, barn)
	rail.CanCollide = false

	-- Beşik çatı: iki eğik levha
	local angle = math.rad(28)
	local halfW = (width / 2 + 1) / math.cos(angle)
	for _, side in { -1, 1 } do
		local roof = makePart(
			"Roof",
			Vector3.new(halfW, 0.8, depth + 2),
			frame
				* CFrame.new(side * (halfW / 2) * math.cos(angle), 1 + wallH + (halfW / 2) * math.sin(angle), 0)
				* CFrame.Angles(0, 0, -side * angle),
			ROOF_COLOR,
			barn
		)
		roof.Material = Enum.Material.Slate
	end

	local sign = makePart(
		"LevelSign",
		Vector3.new(doorW + 2, aboveDoorH * 0.8, 0.4),
		frame * CFrame.new(0, aboveDoorY, -(depth / 2) - 0.3),
		Color3.fromRGB(40, 30, 25),
		barn
	)
	WorldUi.sign(sign, Enum.NormalId.Front, {
		title = `Seviye {barnLevel}`,
		text = if levelConfig then levelConfig.displayName else "Ahır",
	})

	barn:SetAttribute("VisualCreatedAt", game:GetService("Workspace"):GetServerTimeNow())
	do
		local parts = 0
		for _, descendant in barn:GetDescendants() do
			if descendant:IsA("BasePart") then
				parts += 1
			end
		end
		barn:SetAttribute("PartCount", parts)
	end
	barn.PrimaryPart = floor
	barn.Parent = parent
end

function BarnVisualService.buildAt(plot: Model, barnLevel: number)
	local existing = plot:FindFirstChild("Barn")
	if existing then
		existing:Destroy()
	end
	local frame = getBarnFrame(plot)
	if not frame then
		warn(`[Barn] {plot.Name}: BarnSpot bulunamadı`)
		return
	end
	buildBarn(plot, frame, barnLevel)
end

-- Aynı seviye zaten kuruluysa yeniden inşa etme
function BarnVisualService.applyForPlayer(plot: Model, barnLevel: number)
	if plot:GetAttribute("BarnLevel") == barnLevel and plot:FindFirstChild("Barn") then
		return
	end
	plot:SetAttribute("BarnLevel", barnLevel)
	BarnVisualService.buildAt(plot, barnLevel)
end

return BarnVisualService
