--!strict
-- Bölgelerin içindeki yapılar: inek barınağı, tavuk kümesi, at bölmeleri, yemlik, saman balyaları...
-- Bölge açılınca kurulur, kapanınca (ada boşalınca) silinir; kilitli bölge çıplak toprak görünür.
-- Koordinatlar bölge zemininin merkezine göre: -Z ön (doğma noktası), +Z arka.

local ZoneVisualService = {}

type Builder = (decor: Model, origin: CFrame, size: Vector3) -> ()

local WOOD = Color3.fromRGB(150, 110, 70)
local DARK_WOOD = Color3.fromRGB(100, 70, 45)
local BARN_RED = Color3.fromRGB(170, 45, 38)
local ROOF = Color3.fromRGB(70, 60, 55)
local STRAW = Color3.fromRGB(225, 195, 110)
local WATER = Color3.fromRGB(70, 160, 220)
local METAL = Color3.fromRGB(150, 155, 160)

local LOCKED_GROUND = Color3.fromRGB(150, 120, 90)

local function part(
	decor: Model,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.Wood
	p.Anchored = true
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = decor
	return p
end

-- Arkası (+Z) önünden yüksek, eğimli çatı
local function slopedRoof(
	decor: Model,
	origin: CFrame,
	width: number,
	zFront: number,
	zBack: number,
	yFront: number,
	yBack: number
)
	local depth = zBack - zFront
	local rise = yBack - yFront
	local length = math.sqrt(depth * depth + rise * rise) + 1
	local angle = math.atan2(rise, depth)
	local cf = origin * CFrame.new(0, (yFront + yBack) / 2, (zFront + zBack) / 2) * CFrame.Angles(-angle, 0, 0)
	part(decor, "Roof", Vector3.new(width, 0.5, length), cf, ROOF, Enum.Material.Slate)
end

local function hayBale(decor: Model, cf: CFrame)
	part(decor, "HayBale", Vector3.new(2.6, 1.6, 1.6), cf * CFrame.new(0, 0.8, 0), STRAW, Enum.Material.Fabric)
	-- Bağ ipleri
	for _, x in { -0.6, 0.6 } do
		part(decor, "Twine", Vector3.new(0.15, 1.65, 1.65), cf * CFrame.new(x, 0.8, 0), DARK_WOOD, Enum.Material.Fabric).CanCollide =
			false
	end
end

local function waterTrough(decor: Model, cf: CFrame, length: number)
	part(decor, "Trough", Vector3.new(1.8, 1.2, length), cf * CFrame.new(0, 0.6, 0), METAL, Enum.Material.Metal)
	local water = part(
		decor,
		"Water",
		Vector3.new(1.4, 0.1, length - 0.4),
		cf * CFrame.new(0, 1.24, 0),
		WATER,
		Enum.Material.Glass
	)
	water.Transparency = 0.2
	water.CanCollide = false
end

local function feedTrough(decor: Model, cf: CFrame, length: number)
	part(decor, "FeedTrough", Vector3.new(length, 1.2, 1.6), cf * CFrame.new(0, 0.6, 0), WOOD)
	part(decor, "Feed", Vector3.new(length - 0.4, 0.1, 1.2), cf * CFrame.new(0, 1.24, 0), STRAW, Enum.Material.Grass).CanCollide =
		false
end

local BUILDERS: { [string]: Builder } = {
	-- İnek barınağı: arkada çatılı, samanlı, kırmızı duvarlı ahır bölmesi
	starter = function(decor, o, size)
		local hx, hz = size.X / 2, size.Z / 2
		local zFront, zBack = hz - 10, hz - 0.8
		part(
			decor,
			"Straw",
			Vector3.new(size.X - 2, 0.1, zBack - zFront),
			o * CFrame.new(0, 0.05, (zFront + zBack) / 2),
			STRAW,
			Enum.Material.Fabric
		).CanCollide =
			false
		part(
			decor,
			"BackWall",
			Vector3.new(size.X - 2, 7.5, 0.8),
			o * CFrame.new(0, 3.75, zBack),
			BARN_RED,
			Enum.Material.WoodPlanks
		)
		for _, x in { -1, 1 } do
			part(
				decor,
				"SideWall",
				Vector3.new(0.8, 6.5, zBack - zFront),
				o * CFrame.new(x * (hx - 1), 3.25, (zFront + zBack) / 2),
				BARN_RED,
				Enum.Material.WoodPlanks
			)
		end
		for _, x in { -(hx - 1), hx - 1 } do
			part(
				decor,
				"Post",
				Vector3.new(0.9, 6.4, 0.9),
				o * CFrame.new(x, 3.2, zFront),
				Color3.fromRGB(240, 235, 225)
			)
		end
		slopedRoof(decor, o, size.X, zFront - 1, zBack + 0.6, 6.6, 8)
		feedTrough(decor, o * CFrame.new(0, 0, zBack - 1.4), size.X - 10)
		-- Barınağın arka köşeleri: bir yanda balyalar, bir yanda suluk
		waterTrough(decor, o * CFrame.new(-(hx - 2.5), 0, zBack - 3), 4)
		hayBale(decor, o * CFrame.new(hx - 2.8, 0, zBack - 1.6))
		hayBale(decor, o * CFrame.new(hx - 2.8, 0, zBack - 3.4))
		hayBale(decor, o * CFrame.new(hx - 2.8, 1.6, zBack - 2.5))
	end,

	-- Otlak: balyalar, suluk, çiçekler
	pasture = function(decor, o, size)
		local hx, hz = size.X / 2, size.Z / 2
		hayBale(decor, o * CFrame.new(-(hx - 4), 0, hz - 3))
		hayBale(decor, o * CFrame.new(-(hx - 7), 0, hz - 3))
		hayBale(decor, o * CFrame.new(-(hx - 5.5), 1.6, hz - 3))
		waterTrough(decor, o * CFrame.new(hx - 3, 0, -(hz - 6)), 6)
		local flowerColors =
			{ Color3.fromRGB(250, 220, 80), Color3.fromRGB(240, 120, 160), Color3.fromRGB(250, 250, 250) }
		for i, spot in
			{ Vector2.new(-8, -9), Vector2.new(6, 9), Vector2.new(10, 2), Vector2.new(-3, 4), Vector2.new(-11, -2) }
		do
			local flower = part(
				decor,
				"Flower",
				Vector3.new(0.7, 0.7, 0.7),
				o * CFrame.new(spot.X, 0.35, spot.Y),
				flowerColors[(i % 3) + 1],
				Enum.Material.SmoothPlastic
			)
			flower.Shape = Enum.PartType.Ball
			flower.CanCollide = false
		end
	end,

	-- Kümes: ayaklar üstünde küçük ev, rampa, folluklar, yemlik
	poultry = function(decor, o, size)
		local hx, hz = size.X / 2, size.Z / 2
		local coop = o * CFrame.new(-(hx - 6), 0, hz - 4.5)
		local wall = Color3.fromRGB(235, 205, 145)
		for _, x in { -3.5, 3.5 } do
			for _, z in { -2, 2 } do
				part(decor, "Stilt", Vector3.new(0.5, 1.4, 0.5), coop * CFrame.new(x, 0.7, z), DARK_WOOD)
			end
		end
		part(decor, "CoopBody", Vector3.new(8, 4, 5), coop * CFrame.new(0, 3.4, 0), wall, Enum.Material.WoodPlanks)
		slopedRoof(decor, coop, 9, -3, 3, 5.6, 6.8)
		part(decor, "Door", Vector3.new(1.4, 1.8, 0.1), coop * CFrame.new(1.8, 2.4, -2.55), Color3.fromRGB(40, 30, 25))
		part(
			decor,
			"Window",
			Vector3.new(1.4, 1, 0.1),
			coop * CFrame.new(-1.8, 3.8, -2.55),
			Color3.fromRGB(120, 180, 220),
			Enum.Material.Glass
		)
		part(
			decor,
			"Ramp",
			Vector3.new(1.4, 0.2, 3.4),
			coop * CFrame.new(1.8, 0.8, -4.1) * CFrame.Angles(math.rad(-25), 0, 0),
			WOOD
		)
		for i = 0, 2 do
			local nest = o * CFrame.new(hx - 3 - i * 2.4, 0, hz - 2)
			part(decor, "NestBox", Vector3.new(2, 1.4, 2), nest * CFrame.new(0, 0.7, 0), WOOD)
			part(decor, "Nest", Vector3.new(1.6, 0.1, 1.6), nest * CFrame.new(0, 1.45, 0), STRAW, Enum.Material.Fabric)
		end
		feedTrough(decor, o * CFrame.new(4, 0, -(hz - 4)), 5)
	end,

	-- At ahırı: arkada bölmeli, çatılı ahır; önde otlama alanı
	stable = function(decor, o, size)
		local hx, hz = size.X / 2, size.Z / 2
		local zFront, zBack = hz - 7, hz - 0.8
		part(
			decor,
			"BackWall",
			Vector3.new(size.X - 2, 8, 0.8),
			o * CFrame.new(0, 4, zBack),
			Color3.fromRGB(120, 80, 50),
			Enum.Material.WoodPlanks
		)
		part(
			decor,
			"Straw",
			Vector3.new(size.X - 2, 0.1, zBack - zFront),
			o * CFrame.new(0, 0.05, (zFront + zBack) / 2),
			STRAW,
			Enum.Material.Fabric
		).CanCollide =
			false
		local stalls = 4
		local stallW = (size.X - 2) / stalls
		for i = 0, stalls do
			local x = -(hx - 1) + i * stallW
			part(
				decor,
				"Divider",
				Vector3.new(0.6, 4, zBack - zFront),
				o * CFrame.new(x, 2, (zFront + zBack) / 2),
				WOOD,
				Enum.Material.WoodPlanks
			)
			part(decor, "Post", Vector3.new(0.8, 7, 0.8), o * CFrame.new(x, 3.5, zFront), DARK_WOOD)
		end
		slopedRoof(decor, o, size.X, zFront - 1, zBack + 0.6, 7, 8.6)
		-- Her bölmenin arkasında yemlik (bölme duvarları yemliği ayırır)
		feedTrough(decor, o * CFrame.new(0, 0, zBack - 1.3), size.X - 3)
		hayBale(decor, o * CFrame.new(-(hx - 3.5), 0, zFront + 1.5))
	end,

	-- Keçi ağılı: arkada alçak, çatılı barınak; samanlık ve suluk barınağın içinde
	goatpen = function(decor, o, size)
		local hx, hz = size.X / 2, size.Z / 2
		local zFront, zBack = hz - 5, hz - 0.8
		part(
			decor,
			"BackWall",
			Vector3.new(size.X - 2, 5, 0.8),
			o * CFrame.new(0, 2.5, zBack),
			Color3.fromRGB(150, 120, 90),
			Enum.Material.WoodPlanks
		)
		for _, x in { -(hx - 1), hx - 1 } do
			part(decor, "Post", Vector3.new(0.8, 4.8, 0.8), o * CFrame.new(x, 2.4, zFront), DARK_WOOD)
		end
		slopedRoof(decor, o, size.X, zFront - 0.5, zBack + 0.6, 4.9, 5.9)
		part(
			decor,
			"Straw",
			Vector3.new(size.X - 2, 0.1, zBack - zFront),
			o * CFrame.new(0, 0.05, (zFront + zBack) / 2),
			STRAW,
			Enum.Material.Fabric
		).CanCollide =
			false
		feedTrough(decor, o * CFrame.new(2, 0, zBack - 1.3), size.X - 12)
		waterTrough(decor, o * CFrame.new(-(hx - 2.5), 0, zBack - 2.2), 3)
	end,

	-- Balık kafesi: suya sarkan ağ duvarları ve köşelerde yüzen şamandıralar (origin = su yüzeyi)
	fishpen = function(decor, o, size)
		local hx, hz = size.X / 2, size.Z / 2
		local net = Color3.fromRGB(30, 55, 65)
		local walls = {
			{ Vector3.new(size.X, 3.6, 0.1), Vector3.new(0, -1.2, hz) },
			{ Vector3.new(size.X, 3.6, 0.1), Vector3.new(0, -1.2, -hz) },
			{ Vector3.new(0.1, 3.6, size.Z), Vector3.new(hx, -1.2, 0) },
			{ Vector3.new(0.1, 3.6, size.Z), Vector3.new(-hx, -1.2, 0) },
		}
		for _, wall in walls do
			local p = part(decor, "Net", wall[1], o * CFrame.new(wall[2]), net, Enum.Material.Fabric)
			p.Transparency = 0.55
			p.CanCollide = false
			p.CastShadow = false
		end
		for index, spot in
			{
				Vector2.new(-hx, -hz),
				Vector2.new(hx, -hz),
				Vector2.new(-hx, hz),
				Vector2.new(hx, hz),
				Vector2.new(0, -hz),
				Vector2.new(0, hz),
			}
		do
			local buoy = part(
				decor,
				"Buoy",
				Vector3.new(1.1, 1.1, 1.1),
				o * CFrame.new(spot.X, 0.25, spot.Y),
				if index % 2 == 0 then Color3.fromRGB(240, 240, 240) else Color3.fromRGB(235, 110, 50),
				Enum.Material.SmoothPlastic
			)
			buoy.Shape = Enum.PartType.Ball
			buoy.CanCollide = false
		end
	end,
}

local function getGround(zone: Instance): BasePart?
	local ground = zone:FindFirstChild("Ground")
	if ground and ground:IsA("BasePart") then
		return ground
	end
	return nil
end

function ZoneVisualService.apply(zone: Instance, zoneId: string, unlocked: boolean)
	local ground = getGround(zone)
	if not ground then
		return
	end

	local openColor = ground:GetAttribute("OpenColor")
	if typeof(openColor) ~= "Color3" then
		openColor = ground.Color
		ground:SetAttribute("OpenColor", openColor)
	end
	if ground:GetAttribute("Locked") ~= not unlocked then
		ground.Color = if unlocked then openColor :: Color3 else LOCKED_GROUND
		ground:SetAttribute("Locked", not unlocked)
	end

	local existing = zone:FindFirstChild("Decor")
	if not unlocked then
		if existing then
			existing:Destroy()
		end
		return
	end
	local builder = BUILDERS[zoneId]
	if existing or not builder then
		return
	end

	local decor = Instance.new("Model")
	decor.Name = "Decor"
	decor:SetAttribute("VisualCreatedAt", game:GetService("Workspace"):GetServerTimeNow())
	local origin = ground.CFrame * CFrame.new(0, ground.Size.Y / 2, 0)
	builder(decor, origin, ground.Size)
	decor.Parent = zone
end

return ZoneVisualService
