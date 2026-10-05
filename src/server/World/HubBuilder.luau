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

-- Halka yerleşimi (açı: derece, yarıçap: stud; açıklama buildHub içinde). Köprü yolu yarı genişliği ~4 stud olduğundan
-- tahta/tezgâh kenarları köprü eksenlerinden uzak kalır.
local BOARD_RADIUS = 31 -- 16 stud tahtalar (açısal genişlik ~30 derece)
local VENDOR_RADIUS = 29 -- 8,2 stud tezgâhlar
local VENDOR_SPREAD = 9.5 -- iki tezgâhın boşluk ortasından ayrılma açısı
local TITLE_RADIUS = 33
local SIGN_RADIUS = 27
local PLANTER_RADIUS = 34
local PLANTER_OFFSET = 9.5 -- köprü ekseninin iki yanı
local BENCH_RADIUS = 13
local STATUE_RADIUS = 14
local SPAWN_ANGLE = 300
local SPAWN_RADIUS = 15

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

	-- Düzen: her şey meydanın kenarında, yüzü merkeze (çeşmeye, yani ortadaki oyuncuya) dönük bir halka üzerindedir.
	-- Köprüler 0°, 60°, ... yönlerinden gelir; aralarındaki altı boşluk (30°, 90°, ...) şöyle kullanılır
	-- (açı kuzeyden saat yönünde; x = sin, z = cos):
	--   270° 330° 30°   sıralama tahtaları yan yana (rebirth | sunucu | çiftlik)
	--   90°  150°       dörder değil ikişer satıcı yan yana (her boşlukta iki tezgâh)
	--   210°            karşılama tabelası, önünde Adalar tabelası
	-- Köprü girişlerinin iki yanında çiçeklik vardır; yürüyüş yolları boş kalır. İç halkada heykel, bankler, doğma
	-- platformu ve gezgin tüccar durur; tahtalar yürümeyi engellemez (yalnız direkleri katıdır).
	local center = Vector3.new(0, SURFACE_Y, 0)
	local function polar(angle: number, radius: number): Vector3
		local rad = math.rad(angle)
		return Vector3.new(math.sin(rad) * radius, SURFACE_Y, math.cos(rad) * radius)
	end
	-- Merkeze bakan yerleşim (yerel -Z ön)
	local function facingCenter(angle: number, radius: number): CFrame
		local pos = polar(angle, radius)
		return CFrame.lookAt(pos, center)
	end

	-- Satıcı NPC'ler: iki boşlukta ikişer tezgâh, hepsi merkeze bakar
	local vendors: { { angle: number, spec: HubNpcs.NpcSpec } } = {
		{
			angle = 90 - VENDOR_SPREAD,
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
			angle = 90 + VENDOR_SPREAD,
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
			angle = 150 - VENDOR_SPREAD,
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
			angle = 150 + VENDOR_SPREAD,
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
		HubNpcs.vendor(hub, facingCenter(vendor.angle, VENDOR_RADIUS), vendor.spec)
	end

	-- Çiçeklikler: her köprü girişinin iki yanında
	local plantersPlaced = 0
	for axis = 0, 300, 60 do
		for _, side in { -1, 1 } do
			plantersPlaced += 1
			HubNpcs.planter(hub, facingCenter(axis + side * PLANTER_OFFSET, PLANTER_RADIUS), plantersPlaced)
		end
	end

	-- İç halka: çeşme ortada; heykel kuzeyde, bankler çeşmeye bakar
	HubNpcs.fountain(hub, CFrame.new(center))
	for _, angle in { 60, 180, 240 } do
		HubNpcs.bench(hub, facingCenter(angle, BENCH_RADIUS))
	end

	-- Meydan süsleri (assets/HubModels): heykel
	local function placeHubDecor(name: string, cframe: CFrame): Model?
		local model = ModelAssets.clone("HubModels", name)
		if not model then
			warn(`[HubBuilder] assets/HubModels/{name}.rbxmx bulunamadı; çizilmedi`)
			return nil
		end
		model:PivotTo(cframe)
		model.Parent = hub
		return model
	end
	placeHubDecor("Hub_Statue", facingCenter(0, STATUE_RADIUS))

	-- Doğma noktası iç halkada: işlev SpawnLocation'da (görünmez); görünüm hazır model (assets/HubProps/SpawnPlaza: taş disk + bronz kenar).
	-- Üst yüzeyler eşit (0.3 stud) olsun diye SpawnLocation ince ve zeminle aynı yükseklikte durur.
	local spawnPosition = polar(SPAWN_ANGLE, SPAWN_RADIUS)
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

	-- Tabelalar: merkeze bakar. Büyük tabelanın tahtası ve çerçevesi birlikte yüklenir.
	local function placeBoardModel(name: string, angle: number, radius: number): Model?
		local model = ModelAssets.clone("HubModels", name)
		if not model then
			warn(`[HubBuilder] assets/HubModels/{name}.rbxmx bulunamadı; çizilmedi`)
			return nil
		end
		model:PivotTo(facingCenter(angle, radius))
		if name ~= "HubTravelBoard" then
			model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
			model.Parent = hub
			return model
		end
		for _, child in model:GetChildren() do
			child.Parent = hub
		end
		model:Destroy()
		return nil
	end

	-- Sıralama tahtaları (HubBoardService satırları günceller): rebirth | sunucu | çiftlik; yürümeyi engellemez
	for _, spec in
		{
			{ model = "HubRebirthBoard", part = "RebirthBoard", angle = 270, title = "En Çok Rebirth", icon = "🔄" },
			{
				model = "HubPlayerBoard",
				part = "PlayerBoard",
				angle = 330,
				title = "Sunucu Sıralaması",
				icon = "🏆",
			},
			{
				model = "HubFarmBoard",
				part = "FarmBoard",
				angle = 30,
				title = "En Çok Tamamlanan Çiftlik",
				icon = "🌾",
			},
		}
	do
		placeBoardModel(spec.model, spec.angle, BOARD_RADIUS)
		local rankingBoard = hub:FindFirstChild(spec.part, true)
		if rankingBoard and rankingBoard:IsA("BasePart") then
			WorldUi.board(
				rankingBoard,
				Enum.NormalId.Front,
				{ title = spec.title, icon = spec.icon, rows = Config.MAP_PLOT_COUNT }
			)
		end
	end

	-- Karşılama tabelası (direk + tahta) 210° boşluğunun ortasında, önünde Adalar tabelası
	local titleModel = placeBoardModel("HubTitleBoard", 210, TITLE_RADIUS)
	local title = titleModel and titleModel:FindFirstChild("Title")
	if title and title:IsA("BasePart") then
		for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
			WorldUi.sign(title, face, { text = Config.GAME_NAME })
		end
	end

	-- Yön tabelası: adalara ışınlanma menüsü
	placeBoardModel("HubTravelBoard", 210, SIGN_RADIUS)
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
