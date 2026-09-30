--!strict
-- Haritanın çevresindeki dağ halkası: denizin sonuna yüzülemez, aşılamaz ve oradan öteye yüzülecek gibi de görünmez.
-- İki sıra Terrain dağı (iç sıra alçak kayalık, dış sıra karlı doruklar) ve iç kenarda görünmez dairesel duvar.
-- Oyun alanı ada halkasının dışında ~435 stud yarıçaptadır; dağlar oradan sonra başlar. Sabit tohum: aynı harita her kurulumda aynı çıkar.
-- Studio eklentisi (düzenleme modu) MapBuilder.build içinden çağırır; Terrain place'e kaydedilir.

local Workspace = game:GetService("Workspace")

local MapMountains = {}

local INNER_RING_RADIUS = 505 -- iç sıra merkezleri
local OUTER_RING_RADIUS = 575 -- dış sıra merkezleri
local WALL_RADIUS = 452 -- görünmez duvar (iç sıranın deniz seviyesindeki kıyısı ~450)
local WALL_HEIGHT = 320
local WALL_SEGMENTS = 96
local SEA_BOTTOM = -22

local function ring(radius: number, angle: number): Vector3
	return Vector3.new(math.sin(angle), 0, math.cos(angle)) * radius
end

-- Tek dağ: üst üste küçülen toplar (kaya, üstte arduvaz), tepede kar başlığı
local function mountain(terrain: Terrain, base: Vector3, radius: number, rise: number, snowy: boolean)
	-- gövde: deniz tabanından yüksele kadar geniş top
	terrain:FillBall(base + Vector3.new(0, rise * 0.15, 0), radius, Enum.Material.Rock)
	terrain:FillBall(base + Vector3.new(0, rise * 0.55, 0), radius * 0.78, Enum.Material.Rock)
	terrain:FillBall(base + Vector3.new(0, rise * 0.95, 0), radius * 0.52, Enum.Material.Slate)
	terrain:FillBall(base + Vector3.new(0, rise * 1.25, 0), radius * 0.3, Enum.Material.Slate)
	if snowy then
		terrain:FillBall(base + Vector3.new(0, rise * 1.45, 0), radius * 0.26, Enum.Material.Snow)
		terrain:FillBall(base + Vector3.new(0, rise * 1.15, 0), radius * 0.36, Enum.Material.Snow)
	end
end

function MapMountains.build(world: Instance)
	local terrain = Workspace.Terrain
	local random = Random.new(20260930)

	-- Önceki kurulumdan kalan dorukları temizle: MapBuilder'ın temizlediği bölgenin (y <= 32) üstü. Adalar ve deniz bundan önce/altında kalır.
	terrain:FillBlock(CFrame.new(0, 32 + 150, 0), Vector3.new(1500, 300, 1500), Enum.Material.Air)

	local innerCount = 46
	for index = 1, innerCount do
		local angle = (index - 1) / innerCount * math.pi * 2 + random:NextNumber(-0.02, 0.02)
		local radius = random:NextNumber(58, 78)
		local rise = random:NextNumber(55, 95)
		local base = ring(INNER_RING_RADIUS + random:NextNumber(-12, 12), angle)
		mountain(terrain, Vector3.new(base.X, SEA_BOTTOM + 8, base.Z), radius, rise, false)
	end
	local outerCount = 38
	for index = 1, outerCount do
		local angle = (index - 0.5) / outerCount * math.pi * 2 + random:NextNumber(-0.03, 0.03)
		local radius = random:NextNumber(72, 100)
		local rise = random:NextNumber(110, 190)
		local base = ring(OUTER_RING_RADIUS + random:NextNumber(-15, 15), angle)
		mountain(terrain, Vector3.new(base.X, SEA_BOTTOM + 10, base.Z), radius, rise, true)
	end

	-- Görünmez dairesel duvar: dağ kıyısına yüzülüp tepesinden bile aşılamasın
	local model = Instance.new("Model")
	model.Name = "MapRim"
	model.Parent = world
	local segmentLength = 2 * math.pi * WALL_RADIUS / WALL_SEGMENTS + 2
	for index = 1, WALL_SEGMENTS do
		local angle = (index - 0.5) / WALL_SEGMENTS * math.pi * 2
		local center = ring(WALL_RADIUS, angle)
		local wall = Instance.new("Part")
		wall.Name = "RimWall"
		wall.Anchored = true
		wall.Size = Vector3.new(segmentLength, WALL_HEIGHT, 4)
		wall.CFrame = CFrame.lookAt(
			Vector3.new(center.X, WALL_HEIGHT / 2 + SEA_BOTTOM, center.Z),
			Vector3.new(0, WALL_HEIGHT / 2 + SEA_BOTTOM, 0)
		)
		wall.Transparency = 1
		wall.CanQuery = false
		wall.CanTouch = false
		wall.CastShadow = false
		wall.Parent = model
	end
end

return MapMountains
