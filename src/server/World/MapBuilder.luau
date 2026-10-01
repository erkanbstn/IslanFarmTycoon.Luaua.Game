--!strict
-- Deniz, ortada meydan ve etrafında halka şeklinde oyuncu çiftlikleri (takımadalar) kurar.
-- Her çiftlik: ana ada (inek ağılı, otlak, ahır, depo, doğma noktası, tabela) + arkasında köprüyle bağlı
-- 3 uzman ada (Tavuk / At / Keçi). Uzman adalar yol haritasından açılır; kilitliyken toprak renginde durur.
-- Ana ada yerel ekseni: -Z meydana bakar (doğma noktası o tarafta), +Z arkası (ahır ve uzman adalar).
-- Parçalar: MapLayout (düzen), MapParts (yapı taşları), IslandBuilder, SatelliteBuilder, HubBuilder.

local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

-- Studio plugin'i modülleri kopyalayıp taze Config ile çalıştırır; Shared araması SharedRef'te (kopyadaki Shared'ı bulur).
local Shared = require(script.Parent:WaitForChild("SharedRef")) :: typeof(game.ReplicatedStorage.Shared)
local Config = require(Shared:WaitForChild("Config"))
local WorldDecor = require(script.Parent:WaitForChild("WorldDecor"))
local IslandSpecialization = require(script.Parent:WaitForChild("IslandSpecialization"))
local MapLayout = require(script.Parent:WaitForChild("MapLayout"))
local MapParts = require(script.Parent:WaitForChild("MapParts"))
local IslandBuilder = require(script.Parent:WaitForChild("IslandBuilder"))
local HubBuilder = require(script.Parent:WaitForChild("HubBuilder"))
local MapMountains = require(script.Parent:WaitForChild("MapMountains"))

local MapBuilder = {}

-- Harita düzenini (adalar, bölgeler, yapı yerleri) değiştirince bunu 1 artır:
-- oyun, place'e kaydedilmiş eski haritayı fark edip uyarır.
local MAP_VERSION = 51

local WATER_SIZE = MapLayout.WATER_SIZE
local WATER_DEPTH = MapLayout.WATER_DEPTH
local makePart = MapParts.makePart
local buildIsland = IslandBuilder.buildIsland
local buildHub = HubBuilder.buildHub
local buildBridge = HubBuilder.buildBridge

local function plotDirection(plotIndex: number): Vector3
	local angle = (plotIndex - 1) / Config.MAP_PLOT_COUNT * math.pi * 2
	return Vector3.new(math.sin(angle), 0, math.cos(angle))
end

-- LookVector (-Z) meydana baksın
local function plotCFrame(plotIndex: number): CFrame
	return CFrame.lookAt(plotDirection(plotIndex) * Config.ISLAND_RING_RADIUS, Vector3.zero)
end

-- Tema şablonları: temaya bağlı içerik (BuildSpots, Decor, Islands + uzman bölgeler) her tema için sunucu açılışında bir kez
-- ServerStorage.ThemeTemplates altında kurulur; çiftlik değişince şablon Clone + PivotTo ile adaya basılır (yordamsal kurulum yok).
-- Neden eklentide değil de açılışta: kayıtlı place 6 tema içeriği kadar (~3 bin parça/tema) şişmez, şablon her zaman güncel Config ile
-- kurulur (MAP_VERSION'a bağlı eski kayıt kalmaz) ve ServerStorage içeriği zaten ağa gitmez.
local TEMPLATE_FOLDER = "ThemeTemplates"
local TEMPLATE_PLOT_INDEX = 1 -- şablonlar bu fiziksel adanın çerçevesinde kurulur
local TEMPLATE_CONTENT = { "BuildSpots", "Decor", "Islands" }
local TEMPLATE_ATTRIBUTES = { "ThemeIndex", "IslandName", "IslandIcon" }
-- Dünya konumu taşıyan Vector3 öznitelikleri (AreaSize gibi boyut öznitelikleri taşınmaz)
local POSITION_VECTOR_ATTRIBUTES: { [string]: boolean } = { PathStart = true, PathEnd = true }
-- Dünya çerçevesinde CFrame öznitelikleri (yerel ofset tutan bir CFrame özniteliği buraya konmaz)
local POSITION_CFRAME_ATTRIBUTES: { [string]: boolean } = { AreaCFrame = true, IslandFrame = true }

local function templateFolder(): Folder
	local existing = ServerStorage:FindFirstChild(TEMPLATE_FOLDER)
	if existing and existing:IsA("Folder") and existing:GetAttribute("MapVersion") == MAP_VERSION then
		return existing
	end
	if existing then
		existing:Destroy()
	end
	local created = Instance.new("Folder")
	created.Name = TEMPLATE_FOLDER
	created:SetAttribute("MapVersion", MAP_VERSION)
	created.Parent = ServerStorage
	return created
end

local function buildTemplate(themeIndex: number): Model
	local frame = plotCFrame(TEMPLATE_PLOT_INDEX)
	local scratch = Instance.new("Model")
	scratch.Name = `Theme{themeIndex}`
	scratch:SetAttribute("PlotId", tostring(TEMPLATE_PLOT_INDEX))
	local zones = Instance.new("Folder")
	zones.Name = "Zones"
	zones.Parent = scratch
	IslandBuilder.buildThemeContent(scratch, themeIndex, frame, false)
	WorldDecor.optimize(scratch) -- şablonda bir kez; basılan kopyalar bu özellikleri taşır
	scratch.WorldPivot = frame
	scratch.Parent = templateFolder()
	return scratch
end

local function getTemplate(themeIndex: number): Model
	local existing = templateFolder():FindFirstChild(`Theme{themeIndex}`)
	if existing and existing:IsA("Model") then
		return existing
	end
	return buildTemplate(themeIndex)
end

-- Tüm temaların şablonunu (yoksa) kurar. Oyun açılışında MapBuilder.ensure çağırır; applyTheme eksik şablonu tembel kurar.
function MapBuilder.prepareTemplates()
	for themeIndex = 1, Config.MAIN_FARM_LIMIT do
		getTemplate(themeIndex)
	end
end

-- Şablonları siler (Studio düzenleme modunda testten sonra place'e kaydedilmesin diye; açılışta eskisi temizlenir).
function MapBuilder.clearTemplates()
	local existing = ServerStorage:FindFirstChild(TEMPLATE_FOLDER)
	if existing then
		existing:Destroy()
	end
end

-- PivotTo yalnızca parçaları taşır; dünya konumu taşıyan öznitelikleri (CFrame / yol uçları) aynı farkla taşı
local function remapPositions(root: Instance, delta: CFrame)
	local function remap(instance: Instance)
		for name, value in instance:GetAttributes() do
			if
				(typeof(value) == "CFrame" and POSITION_CFRAME_ATTRIBUTES[name])
				or (typeof(value) == "Vector3" and POSITION_VECTOR_ATTRIBUTES[name])
			then
				instance:SetAttribute(name, delta * value)
			end
		end
	end
	remap(root)
	for _, descendant in root:GetDescendants() do
		remap(descendant)
	end
end

-- Adadaki tema içeriğini siler: BuildSpots/Decor/Islands, uzman bölgeler; ana bölgelerde yalnızca Decor/LevelFlags (çalışma anı görselleri).
local function clearThemeContent(plot: Model)
	for _, name in TEMPLATE_CONTENT do
		local old = plot:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end
	local zones = plot:FindFirstChild("Zones")
	if zones then
		for _, zone in zones:GetChildren() do
			local zoneId = zone:GetAttribute("ZoneId")
			local zoneConfig = if typeof(zoneId) == "string" then Config.ZONES[zoneId] else nil
			if zoneConfig and zoneConfig.island == "home" then
				for _, name in { "Decor", "LevelFlags" } do
					local old = zone:FindFirstChild(name)
					if old then
						old:Destroy()
					end
				end
			else
				zone:Destroy()
			end
		end
	end
end

-- Fiziksel adanın temaya bağlı içeriğini (yapı yerleri, süsler, uzman adalar ve bölgeleri) çalışma anında değiştirir:
-- eskisini siler, tema şablonunu kopyalayıp adanın çerçevesine taşıyarak ekler.
-- Terrain, ana bölgeler, ahır, doğma noktası ve köprüler bütün adalarda aynı olduğundan dokunulmaz.
function MapBuilder.applyTheme(plot: Model, themeIndex: number): boolean
	if plot:GetAttribute("ThemeIndex") == themeIndex then
		return false
	end
	local plotIndex = tonumber(plot:GetAttribute("PlotId"))
	assert(plotIndex, "[Map] applyTheme: PlotId geçersiz")
	local template = getTemplate(themeIndex) -- eksikse burada kurulur; eski içerik silinmeden önce hata alınsın
	clearThemeContent(plot)

	local stamp = template:Clone()
	local targetFrame = plotCFrame(plotIndex)
	stamp:PivotTo(targetFrame)
	remapPositions(stamp, targetFrame * plotCFrame(TEMPLATE_PLOT_INDEX):Inverse())
	for _, name in TEMPLATE_ATTRIBUTES do
		plot:SetAttribute(name, stamp:GetAttribute(name))
	end
	local plotZones = plot:FindFirstChild("Zones")
	local stampZones = stamp:FindFirstChild("Zones")
	if plotZones and stampZones then
		for _, zone in stampZones:GetChildren() do
			zone.Parent = plotZones
		end
	end
	for _, name in TEMPLATE_CONTENT do
		local content = stamp:FindFirstChild(name)
		if content then
			content.Parent = plot
		end
	end
	stamp:Destroy()
	return true
end

-- Eski yordamsal kurulum: şablon kullanmadan içeriği doğrudan kurar. Oyun yolunda kullanılmaz; şablon kopyasının eşdeğerliğini
-- karşılaştıran Studio testi (tests/map-structure.spec) referans olarak çağırır. applyTheme'in aksine aynı temadayken de yeniden kurar.
function MapBuilder.applyThemeProcedural(plot: Model, themeIndex: number)
	local plotIndex = tonumber(plot:GetAttribute("PlotId"))
	assert(plotIndex, "[Map] applyThemeProcedural: PlotId geçersiz")
	clearThemeContent(plot)
	IslandBuilder.buildThemeContent(plot, themeIndex, plotCFrame(plotIndex), false)
	WorldDecor.optimize(plot)
end

-- Harita sözleşmesi: eksik dünyada ekonomik oturum açılmaz.
function MapBuilder.validate()
	local plots = Workspace:FindFirstChild("Plots")
	assert(plots and plots:IsA("Folder"), "[Map] Plots klasörü eksik; Haritayı Kur ile yeniden oluştur.")
	assert(
		plots:GetAttribute("MapVersion") == MAP_VERSION,
		"[Map] Harita sürümü uyumsuz; Haritayı Kur ve place kaydı gerekli."
	)
	local world = Workspace:FindFirstChild("World")
	local hub = world and world:FindFirstChild("HubSpawn", true)
	assert(hub and hub:IsA("BasePart"), "[Map] World/HubSpawn eksik.")
	local ids: { [string]: boolean } = {}
	local count = 0
	for _, plot in plots:GetChildren() do
		assert(plot:IsA("Model"), `[Map] Geçersiz plot: {plot.Name}`)
		local id = plot:GetAttribute("PlotId")
		assert(typeof(id) == "string" and id ~= "" and not ids[id], `[Map] Eksik/tekrarlı PlotId: {plot.Name}`)
		assert(typeof(plot:GetAttribute("ThemeIndex")) == "number", `[Map] {plot.Name}: ThemeIndex eksik.`)
		ids[id] = true
		count += 1
		for _, name in { "Spawn", "Collector", "BarnSpot" } do
			local part = plot:FindFirstChild(name)
			assert(part and part:IsA("BasePart"), `[Map] {plot.Name}/{name} eksik.`)
		end
		local zones = plot:FindFirstChild("Zones")
		assert(zones and zones:IsA("Folder"), `[Map] {plot.Name}/Zones eksik.`)
		local zoneIds: { [string]: boolean } = {}
		for _, zone in zones:GetChildren() do
			local zoneId = zone:GetAttribute("ZoneId")
			assert(
				typeof(zoneId) == "string" and Config.ZONES[zoneId] and not zoneIds[zoneId],
				`[Map] {plot.Name}: geçersiz/tekrarlı bölge.`
			)
			local ground = zone:FindFirstChild("Ground")
			assert(ground and ground:IsA("BasePart"), `[Map] {plot.Name}/{zone.Name}/Ground eksik.`)
			assert(ground.Size.X > 0 and ground.Size.Z > 0, "[Map] Geçersiz bölge boyutu.")
			zoneIds[zoneId] = true
		end
		local themeIslands = Config.getThemeIslands(tostring(plot:GetAttribute("ThemeIndex")))
		local inTheme: { [string]: boolean } = {}
		for _, themeIsland in themeIslands do
			inTheme[themeIsland] = true
		end
		for zoneId, zone in Config.ZONES do
			if inTheme[zone.island] then
				assert(zoneIds[zoneId], `[Map] {plot.Name}/{zoneId} bölgesi eksik.`)
			else
				assert(not zoneIds[zoneId], `[Map] {plot.Name}/{zoneId} bu adanın temasında olmamalı.`)
			end
		end
		local islands = plot:FindFirstChild("Islands")
		assert(islands and islands:IsA("Folder"), `[Map] {plot.Name}/Islands eksik.`)
		local islandIds: { [string]: boolean } = {}
		for _, island in islands:GetChildren() do
			local islandId = island:GetAttribute("FarmIslandId")
			assert(
				typeof(islandId) == "string" and Config.FARM_ISLANDS[islandId] and not islandIds[islandId],
				`[Map] {plot.Name}: geçersiz/tekrarlı uzman ada.`
			)
			local base = island:FindFirstChild("IslandBase")
			assert(base and base:IsA("BasePart"), `[Map] {plot.Name}/{island.Name}/IslandBase eksik.`)
			assert(island:FindFirstChild("Specialization"), `[Map] {plot.Name}/{island.Name}: uzmanlık alanı eksik.`)
			islandIds[islandId] = true
		end
		for islandId, island in Config.FARM_ISLANDS do
			if island.upgradeId and inTheme[islandId] then
				assert(islandIds[islandId], `[Map] {plot.Name}/{islandId} adası eksik.`)
			end
		end
		for islandId in islandIds do
			assert(inTheme[islandId], `[Map] {plot.Name}/{islandId} adası bu çiftliğin temasında değil.`)
		end
		local homeDecor = plot:FindFirstChild("Decor")
		assert(
			homeDecor and homeDecor:FindFirstChild("Specialization"),
			`[Map] {plot.Name}: süt işleme alanı eksik.`
		)
		local spots = plot:FindFirstChild("BuildSpots")
		assert(spots and spots:IsA("Folder"), `[Map] {plot.Name}/BuildSpots eksik.`)
		for upgradeId, site in IslandSpecialization.SITES do
			if inTheme[site.island] then
				local spot = spots:FindFirstChild(upgradeId)
				assert(spot and spot:IsA("BasePart"), `[Map] {plot.Name}/{upgradeId} üretim noktası eksik.`)
			end
		end
		for _, upgrade in Config.UPGRADES do
			if upgrade.kind == "boost" and inTheme[Config.getUpgradeIsland(upgrade)] then
				local spot = spots:FindFirstChild(upgrade.id)
				assert(spot and spot:IsA("BasePart"), `[Map] {plot.Name}/{upgrade.id} yapı noktası eksik.`)
			end
		end
	end
	assert(count == Config.MAP_PLOT_COUNT, `[Map] {Config.MAP_PLOT_COUNT} ada bekleniyor; {count} bulundu.`)
end

local function hasValidPlots(_plotsFolder: Instance): boolean
	local ok = pcall(MapBuilder.validate)
	return ok
end

function MapBuilder.warnIfNoPlots()
	local plotsFolder = Workspace:FindFirstChild("Plots")
	if plotsFolder and hasValidPlots(plotsFolder) then
		return
	end
	warn("[Map] Workspace'te ada yok. Studio'da 'Island Farm Tycoon → Haritayı Kur' butonuna bas.")
end

local function getOrCreate(parent: Instance, className: string): Instance
	local existing = parent:FindFirstChildOfClass(className)
	if existing then
		return existing
	end
	local created = Instance.new(className)
	created.Parent = parent
	return created
end

-- Sıcak, canlı bir öğleden sonra: yumuşak gölgeler, hafif parıltı, güneş ışınları, bulutlar.
-- (Lighting.Technology = Future, default.project.json'dan gelir; script ile ayarlanamıyor.)
local function applyLighting()
	Lighting.ClockTime = 14.5
	Lighting.GeographicLatitude = 35
	Lighting.Brightness = 2.4
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.25
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 1
	Lighting.OutdoorAmbient = Color3.fromRGB(135, 135, 150)
	Lighting.Ambient = Color3.fromRGB(70, 70, 80)

	local atmosphere = getOrCreate(Lighting, "Atmosphere") :: Atmosphere
	atmosphere.Density = 0.3
	atmosphere.Offset = 0.25
	atmosphere.Color = Color3.fromRGB(199, 220, 235)
	atmosphere.Decay = Color3.fromRGB(106, 135, 165)
	atmosphere.Glare = 0.2
	atmosphere.Haze = 1.3

	local bloom = getOrCreate(Lighting, "BloomEffect") :: BloomEffect
	bloom.Intensity = 0.5
	bloom.Size = 24
	bloom.Threshold = 1.8

	local sunRays = getOrCreate(Lighting, "SunRaysEffect") :: SunRaysEffect
	sunRays.Intensity = 0.05
	sunRays.Spread = 0.8

	local color = getOrCreate(Lighting, "ColorCorrectionEffect") :: ColorCorrectionEffect
	color.Saturation = 0.15
	color.Contrast = 0.08
	color.Brightness = 0.02
	color.TintColor = Color3.fromRGB(255, 250, 240)

	local clouds = getOrCreate(Workspace.Terrain, "Clouds") :: Clouds
	clouds.Cover = 0.55
	clouds.Density = 0.6
end

-- Deniz: su + kum taban + görünmez güvenlik zemini ve kenar duvarları.
-- Eskiden suyun altı boşluktu; dalan ya da dipten geçen oyuncu boşluğa düşüp ölüyordu.
-- Her açılışta da çağrılır (ensure): kayıtlı haritada su eksikse boş hücreleri suyla doldurur.
local function ensureSea()
	local terrain = Workspace.Terrain
	local half = WATER_SIZE / 2
	-- Boş (Air) hücreleri suyla doldur: adaların kayalarına dokunmaz
	local region = Region3.new(Vector3.new(-half, -WATER_DEPTH, -half), Vector3.new(half, 0, half)):ExpandToGrid(4)
	terrain:ReplaceMaterial(region, 4, Enum.Material.Air, Enum.Material.Water)
	-- Dipte kum: sudan bakınca deniz tabanı görünsün
	terrain:FillBlock(CFrame.new(0, -WATER_DEPTH - 2, 0), Vector3.new(WATER_SIZE, 4, WATER_SIZE), Enum.Material.Sand)

	local world = Workspace:FindFirstChild("World")
	if not world then
		world = Instance.new("Folder")
		world.Name = "World"
		world.Parent = Workspace
	end
	local worldFolder = world :: Instance
	if worldFolder:FindFirstChild("SeaSafety") then
		return
	end
	local safety = Instance.new("Model")
	safety.Name = "SeaSafety"
	safety.Parent = worldFolder

	local function invisible(name: string, size: Vector3, cf: CFrame)
		local p = makePart(name, size, cf, Color3.new(), safety)
		p.Transparency = 1
		p.CastShadow = false
		p.CanQuery = false
	end
	-- Kumun altında: ne olursa olsun kimse boşluğa düşmesin
	invisible("SafetyFloor", Vector3.new(WATER_SIZE + 200, 2, WATER_SIZE + 200), CFrame.new(0, -WATER_DEPTH - 6, 0))
	-- Haritanın kenarı: denizin sonuna görünmez duvar
	local wallHeight = 200
	for _, side in { -1, 1 } do
		invisible(
			"EdgeWall",
			Vector3.new(4, wallHeight, WATER_SIZE),
			CFrame.new(side * (half - 20), wallHeight / 2 - WATER_DEPTH, 0)
		)
		invisible(
			"EdgeWall",
			Vector3.new(WATER_SIZE, wallHeight, 4),
			CFrame.new(0, wallHeight / 2 - WATER_DEPTH, side * (half - 20))
		)
	end
end

-- Haritayı sıfırdan kurar (eskisini siler). Studio plugin'i düzenleme modunda bunu çağırır.
function MapBuilder.build(replaceGeneratedRegion: boolean?)
	-- Eklenti bu sınırlı alanı yeniden oluşturmayı açıkça ister. Çevresindeki kullanıcı
	-- Terrain'i ve Workspace'teki bağımsız modeller/doğma noktaları korunur.
	local half = WATER_SIZE / 2
	local generatedRegion = Region3.new(Vector3.new(-half, -32, -half), Vector3.new(half, 32, half)):ExpandToGrid(4)
	for _, name in { "Plots", "World" } do
		local old = Workspace:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end

	if replaceGeneratedRegion then
		Workspace.Terrain:FillRegion(generatedRegion, 4, Enum.Material.Air)
	end
	Workspace.Terrain:FillBlock(
		CFrame.new(0, -WATER_DEPTH / 2, 0),
		Vector3.new(WATER_SIZE, WATER_DEPTH, WATER_SIZE),
		Enum.Material.Water
	)

	local terrain = Workspace.Terrain
	-- Çimen yaprakları rüzgârda sallansın (bazı bağlamlarda script ile ayarlanamayabilir; o zaman
	-- Studio'da Terrain → Decoration kutusunu elle işaretle)
	pcall(function()
		(terrain :: any).Decoration = true
	end)
	terrain.WaterColor = Color3.fromRGB(35, 135, 170)
	terrain.WaterTransparency = 0.35
	terrain.WaterReflectance = 0.6
	terrain.WaterWaveSize = 0.15
	terrain.WaterWaveSpeed = 10
	applyLighting()

	local plotsFolder = Instance.new("Folder")
	plotsFolder.Name = "Plots"
	plotsFolder:SetAttribute("MapVersion", MAP_VERSION)
	plotsFolder.Parent = Workspace

	local world = Instance.new("Folder")
	world.Name = "World"
	world.Parent = Workspace
	MapMountains.build(world) -- çevre dağları ve görünmez halka duvarı (haritadan ötesine yüzülemez)
	buildHub(world)

	local count = Config.MAP_PLOT_COUNT
	for i = 1, count do
		local direction = plotDirection(i)
		-- Bütün fiziksel adalar aynı (1. tema) kurulur; oyuncunun etkin çiftliği çalışma anında applyTheme ile giydirilir
		buildIsland(i, plotCFrame(i), 1).Parent = plotsFolder
		buildBridge(world, direction)
	end

	WorldDecor.optimize(plotsFolder)
	WorldDecor.optimize(world)
	ensureSea()
	MapBuilder.validate()
	print(`[Map] {count} ada oluşturuldu (harita sürümü {MAP_VERSION}).`)
end

-- Oyun başlarken: place'e kaydedilmiş harita varsa onu kullan, yoksa kur
function MapBuilder.ensure()
	local existing = Workspace:FindFirstChild("Plots")
	if existing then
		MapBuilder.validate()
		ensureSea() -- Eski kayıtlı haritalarda da deniz tabanı ve güvenlik zemini olsun
	elseif Config.MAP_AUTO_BUILD then
		MapBuilder.build()
	end
	if RunService:IsRunning() and Workspace:FindFirstChild("Plots") then
		-- Oyuncular gelmeden tema şablonlarını hazırla (çiftlik değiştirme yalnızca kopyalar). Hata olursa applyTheme tembel kurar.
		MapBuilder.clearTemplates()
		xpcall(MapBuilder.prepareTemplates, function(err: any)
			warn(`[Map] Tema şablonları hazırlanamadı: {err}`)
		end)
	end
end

return MapBuilder
