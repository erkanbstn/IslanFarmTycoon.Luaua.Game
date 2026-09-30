--!strict
-- Meydan (hub): merkez ada, satıcılar, dekor ve meydanı ana adalara bağlayan köprüler.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Studio plugin'i modülleri kopyalayıp taze Config ile çalıştırır; o durumda yanımızdaki "Shared" kullanılır.
local Shared = script.Parent.Parent:FindFirstChild("Shared") or ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local UiTheme = require(Shared:WaitForChild("UiTheme"))
local WorldUi = require(Shared:WaitForChild("WorldUi"))
local WorldDecor = require(script.Parent:WaitForChild("WorldDecor"))
local HubNpcs = require(script.Parent:WaitForChild("HubNpcs"))
local MapLayout = require(script.Parent:WaitForChild("MapLayout"))
local MapParts = require(script.Parent:WaitForChild("MapParts"))

local SURFACE_Y = MapLayout.SURFACE_Y
local ISLAND_RADIUS = MapLayout.ISLAND_RADIUS
local HUB_RADIUS = MapLayout.HUB_RADIUS
local makePart = MapParts.makePart
local makeDisc = MapParts.makeDisc
local addTravelPrompt = MapParts.addTravelPrompt

local function buildHub(parent: Instance)
	local hub = Instance.new("Model")
	hub.Name = "Hub"
	hub.Parent = parent

	-- Meydan: kıyısı Terrain, zemini düz arnavut kaldırımı parça; çevresinde fenerler
	WorldDecor.terrainIsland(hub, Vector3.zero, HUB_RADIUS, SURFACE_Y, 6)
	local floor =
		makeDisc("Floor", HUB_RADIUS * 2, 4, CFrame.new(0, SURFACE_Y - 2, 0), Color3.fromRGB(165, 160, 150), hub)
	floor.Material = Enum.Material.Cobblestone
	for i = 1, 6 do
		local angle = (i - 0.5) / 6 * math.pi * 2
		local p = Vector3.new(math.sin(angle), 0, math.cos(angle)) * (HUB_RADIUS - 4)
		WorldDecor.lamp(hub, CFrame.lookAt(p + Vector3.new(0, SURFACE_Y, 0), Vector3.new(0, SURFACE_Y, 0)))
	end

	-- Satıcı NPC'ler: köprü aralarında, yüzleri meydanın ortasına dönük
	local vendors: { { angle: number, spec: HubNpcs.NpcSpec } } = {
		{
			angle = 90,
			spec = {
				name = "Tüccar Tarık",
				title = "Siparişler",
				icon = "📋",
				action = "orders",
				blurb = "Ödüllü görevler",
				prompt = "Siparişlere bak",
				shirt = Color3.fromRGB(70, 130, 90),
				hat = Color3.fromRGB(120, 85, 50),
				awning = Color3.fromRGB(190, 70, 55),
			},
		},
		{
			angle = 150,
			spec = {
				name = "Usta Ömer",
				title = "Eşyalar",
				icon = "🎒",
				action = "store",
				blurb = "Kalıcı eşyalar",
				prompt = "Eşyalara bak",
				shirt = Color3.fromRGB(150, 90, 170),
				hat = Color3.fromRGB(60, 50, 90),
				awning = Color3.fromRGB(120, 80, 170),
			},
		},
		{
			angle = 210,
			spec = {
				name = "Rehber Rana",
				title = "Yol Haritası",
				icon = "🗺️",
				action = "roadmap",
				blurb = "Sıradaki adımlar",
				prompt = "Konuş",
				shirt = Color3.fromRGB(60, 120, 190),
				hat = Color3.fromRGB(230, 200, 90),
				awning = Color3.fromRGB(60, 120, 190),
			},
		},
		{
			angle = 270,
			spec = {
				name = "Kaptan Kemal",
				title = "Adalar",
				icon = "⚓",
				action = "travel",
				blurb = "Adalara yolculuk",
				prompt = "Adalara Git",
				shirt = Color3.fromRGB(235, 235, 240),
				hat = Color3.fromRGB(30, 50, 100),
				awning = Color3.fromRGB(240, 240, 245),
			},
		},
	}
	for _, vendor in vendors do
		local rad = math.rad(vendor.angle)
		local pos = Vector3.new(math.sin(rad), 0, math.cos(rad)) * 24 + Vector3.new(0, SURFACE_Y, 0)
		HubNpcs.vendor(hub, CFrame.lookAt(pos, Vector3.new(0, SURFACE_Y, 0)), vendor.spec)
	end

	-- Meydan dekoru: boş yay üzerinde çeşme, ortaya bakan banklar ve satıcıların yanında çiçeklikler
	local center = Vector3.new(0, SURFACE_Y, 0)
	local function onRing(angle: number, radius: number): Vector3
		local rad = math.rad(angle)
		return Vector3.new(math.sin(rad), 0, math.cos(rad)) * radius + center
	end
	HubNpcs.fountain(hub, CFrame.new(onRing(330, 20)))
	for _, angle in { 120, 180, 240 } do
		local pos = onRing(angle, 15)
		HubNpcs.bench(hub, CFrame.lookAt(pos, center))
	end
	for index, vendor in vendors do
		for side, offset in { -16, 16 } do
			local pos = onRing(vendor.angle + offset, 26)
			HubNpcs.planter(hub, CFrame.lookAt(pos, center), index * 2 + side)
		end
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(10, 0.4, 10)
	spawn.CFrame = CFrame.new(0, SURFACE_Y + 0.2, 0)
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Color = Color3.fromRGB(240, 200, 80)
	spawn.Parent = hub

	-- Tabela iki köprünün arasına, meydanın ortasına bakacak şekilde
	local betweenBridges = math.pi / Config.MAP_PLOT_COUNT
	local signPos = Vector3.new(math.sin(betweenBridges), 0, math.cos(betweenBridges)) * (HUB_RADIUS - 8)
	local signCf = CFrame.lookAt(signPos, Vector3.zero)
	local sign = makePart(
		"Title",
		Vector3.new(20, 6, 1),
		signCf + Vector3.new(0, SURFACE_Y + 12, 0),
		Color3.fromRGB(150, 45, 40),
		hub
	)
	sign.Material = Enum.Material.Wood
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		WorldUi.sign(sign, face, { icon = "🐄", title = "Hoş geldin", text = Config.GAME_NAME })
	end
	makePart(
		"Pole",
		Vector3.new(1, 9, 1),
		signCf * CFrame.new(0, SURFACE_Y + 4.5, 0.9),
		Color3.fromRGB(80, 60, 40),
		hub
	)

	-- Direğin önünde yön tabelası: adalara ışınlanma menüsü
	local board = makePart(
		"TravelBoard",
		Vector3.new(6, 2.4, 0.4),
		signCf * CFrame.new(0, SURFACE_Y + 3.5, 0.2),
		Color3.fromRGB(85, 60, 40),
		hub
	)
	board.Material = Enum.Material.WoodPlanks
	WorldUi.sign(board, Enum.NormalId.Front, { icon = "🧭", text = "Adalar", tint = UiTheme.Color.Blue })
	addTravelPrompt(board, "Meydan")
end

local function buildBridge(parent: Instance, direction: Vector3)
	local startDist = HUB_RADIUS - 2
	local endDist = Config.ISLAND_RING_RADIUS - ISLAND_RADIUS + 2
	local length = endDist - startDist
	local mid = direction * (startDist + length / 2)
	-- Üst yüzey, ada/meydan zemininin 0.05 altında: uçlar zeminle aynı düzlemde çakışıp titremesin
	local y = SURFACE_Y - 0.55
	local cf = CFrame.lookAt(Vector3.new(mid.X, y, mid.Z), Vector3.new(0, y, 0))
	local bridge = makePart("Bridge", Vector3.new(8, 1, length), cf, Color3.fromRGB(140, 100, 60), parent)
	bridge.Material = Enum.Material.WoodPlanks
	for _, side in { -4, 4 } do
		local rail = makePart(
			"Rail",
			Vector3.new(0.5, 2, length),
			cf * CFrame.new(side, 1.5, 0),
			Color3.fromRGB(110, 80, 50),
			parent
		)
		rail.Material = Enum.Material.Wood
	end
end

return {
	buildHub = buildHub,
	buildBridge = buildBridge,
}
