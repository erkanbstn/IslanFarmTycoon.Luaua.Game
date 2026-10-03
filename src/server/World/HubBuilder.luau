--!strict
-- Meydan (hub): merkez ada, satıcılar, dekor ve meydanı ana adalara bağlayan köprüler.

-- Studio plugin'i modülleri kopyalayıp taze Config ile çalıştırır; Shared araması SharedRef'te (kopyadaki Shared'ı bulur).
local Shared = require(script.Parent:WaitForChild("SharedRef")) :: typeof(game.ReplicatedStorage.Shared)
local Config = require(Shared:WaitForChild("Config"))
local UiTheme = require(Shared:WaitForChild("UiTheme"))
local WorldUi = require(Shared:WaitForChild("WorldUi"))
local WorldDecor = require(script.Parent:WaitForChild("WorldDecor"))
local HubNpcs = require(script.Parent:WaitForChild("HubNpcs"))
local ModelAssets = require(script.Parent:WaitForChild("ModelAssets"))
local MapLayout = require(script.Parent:WaitForChild("MapLayout"))
local MapParts = require(script.Parent:WaitForChild("MapParts"))

local SURFACE_Y = MapLayout.SURFACE_Y
local ISLAND_RADIUS = MapLayout.ISLAND_RADIUS
local HUB_RADIUS = MapLayout.HUB_RADIUS
local makeDisc = MapParts.makeDisc
local addTravelPrompt = MapParts.addTravelPrompt
local buildBridgeBetween = MapParts.buildBridgeBetween

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
	HubNpcs.fountain(hub, CFrame.new(center)) -- meydanın tam ortası
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

	-- Meydan süsleri (assets/HubModels): heykel ve flama (doğma noktasının arkasında). Köprü girişlerinin bayrakları kullanıcı isteğiyle kaldırıldı.
	-- Yüzleri meydanın ortasına dönüktür.
	local function placeHubDecor(name: string, pos: Vector3)
		local model = ModelAssets.clone("HubModels", name)
		if not model then
			warn(`[HubBuilder] assets/HubModels/{name}.rbxmx bulunamadı; çizilmedi`)
			return
		end
		model:PivotTo(CFrame.lookAt(pos, center))
		model.Parent = hub
	end
	placeHubDecor("Hub_Statue", onRing(300, 14))
	placeHubDecor("Hub_Banner", onRing(330, 33))

	-- Doğma noktası: işlev SpawnLocation'da (görünmez); görünüm hazır model (assets/HubProps/SpawnPlaza: taş disk + bronz kenar).
	-- Üst yüzeyler eşit (0.3 stud) olsun diye SpawnLocation ince ve zeminle aynı yükseklikte durur.
	local spawnPosition = onRing(330, 20) -- merkez çeşmeye ayrıldı
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(10, 0.2, 10)
	spawn.CFrame = CFrame.new(spawnPosition + Vector3.new(0, 0.2, 0))
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Transparency = 1
	spawn.CastShadow = false
	for _, child in spawn:GetChildren() do
		if child:IsA("Decal") or child:IsA("Texture") then
			child:Destroy()
		end
	end
	spawn.Parent = hub
	local plaza = ModelAssets.clone("HubProps", "SpawnPlaza")
	if plaza then
		plaza:PivotTo(CFrame.new(spawnPosition))
		plaza.Parent = hub
	else
		warn("[HubBuilder] assets/HubProps/SpawnPlaza.rbxmx bulunamadı; doğma platformu çizilmedi")
	end

	-- Tabela iki köprünün arasına, meydanın ortasına bakacak şekilde
	local betweenBridges = math.pi / Config.MAP_PLOT_COUNT
	local signPos = Vector3.new(math.sin(betweenBridges), 0, math.cos(betweenBridges)) * (HUB_RADIUS - 8)
	local signCf = CFrame.lookAt(signPos, Vector3.zero) + Vector3.new(0, SURFACE_Y, 0)

	-- Hazır model (assets/HubModels); parçalar doğrudan meydan modelinin çocuğu olur (HubBoardService "PlayerBoard" parçasını
	-- burada arar). Yerel -Z meydanın ortasına bakar.
	local function placeBoardModel(name: string, offset: CFrame): Model?
		local model = ModelAssets.clone("HubModels", name)
		if not model then
			warn(`[HubBuilder] assets/HubModels/{name}.rbxmx bulunamadı; çizilmedi`)
			return nil
		end
		model:PivotTo(signCf * offset)
		for _, child in model:GetChildren() do
			child.Parent = hub
		end
		model:Destroy()
		return model
	end

	-- Karşılama tabelası (direk + tahta)
	placeBoardModel("HubTitleBoard", CFrame.new())
	local title = hub:FindFirstChild("Title")
	if title and title:IsA("BasePart") then
		for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
			WorldUi.sign(title, face, { icon = "🐄", title = "Hoş geldin", text = Config.GAME_NAME })
		end
	end

	-- Sunucudaki oyuncuların para ve ada durumu (HubBoardService satırları günceller); yürümeyi engellemez
	placeBoardModel("HubPlayerBoard", CFrame.new(0, 0, -2))
	local ranking = hub:FindFirstChild("PlayerBoard")
	if ranking and ranking:IsA("BasePart") then
		WorldUi.board(
			ranking,
			Enum.NormalId.Front,
			{ title = "Sunucu Sıralaması", icon = "🏆", rows = Config.MAP_PLOT_COUNT }
		)
	end

	-- Yön tabelası, sıralamanın sağında: adalara ışınlanma menüsü
	placeBoardModel("HubTravelBoard", CFrame.new(-13, 0, -2))
	local board = hub:FindFirstChild("TravelBoard")
	if board and board:IsA("BasePart") then
		WorldUi.sign(board, Enum.NormalId.Front, { icon = "🧭", text = "Adalar", tint = UiTheme.Color.Blue })
		addTravelPrompt(board, "Meydan")
	end
end

local function buildBridge(parent: Instance, direction: Vector3)
	local startDist = HUB_RADIUS - 2
	local endDist = Config.ISLAND_RING_RADIUS - ISLAND_RADIUS + 2
	buildBridgeBetween(parent, direction * startDist, direction * endDist)
end

return {
	buildHub = buildHub,
	buildBridge = buildBridge,
}
