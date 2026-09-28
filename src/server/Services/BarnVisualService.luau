--!strict
-- Ahır binasını seviyeye göre büyüterek kurar.
-- Konum: plot içindeki "BarnSpot" parçası (LookVector = kapı yönü).
-- BarnSpot yoksa başlangıç bölgesinin zemini kullanılır.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Studio plugin'i modülleri kopyalayıp taze Config ile çalıştırır; o durumda yanımızdaki "Shared" kullanılır.
local Shared = script.Parent.Parent:FindFirstChild("Shared") or ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local WorldUi = require(Shared:WaitForChild("WorldUi"))

local BarnVisualService = {}

local WALL_COLOR = Color3.fromRGB(170, 45, 38)
local TRIM_COLOR = Color3.fromRGB(240, 235, 225)
local ROOF_COLOR = Color3.fromRGB(70, 60, 55)

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

-- frame: zemin yüzeyinde, LookVector (-Z) kapı yönü
local function buildBarn(parent: Instance, frame: CFrame, barnLevel: number)
	local levelConfig = Config.getBarnLevelConfig(barnLevel)
	local s = if levelConfig then levelConfig.barnScale else 1

	local width, depth = 14 * s, 10 * s
	local wallH = 7 * s
	local doorW, doorH = 5 * s, 5 * s

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

	makePart("WallBack", Vector3.new(width, wallH, 1), frame * CFrame.new(0, wallY, depth / 2 - 0.5), WALL_COLOR, barn)
	for _, side in { -1, 1 } do
		makePart(
			"WallSide",
			Vector3.new(1, wallH, depth),
			frame * CFrame.new(side * (width / 2 - 0.5), wallY, 0),
			WALL_COLOR,
			barn
		)
		local frontW = (width - doorW) / 2
		makePart(
			"WallFront",
			Vector3.new(frontW, wallH, 1),
			frame * CFrame.new(side * (doorW / 2 + frontW / 2), wallY, -(depth / 2 - 0.5)),
			WALL_COLOR,
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
		WALL_COLOR,
		barn
	)

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
