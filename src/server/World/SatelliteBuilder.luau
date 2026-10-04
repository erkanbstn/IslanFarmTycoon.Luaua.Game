--!strict
-- Uzman (küçük) adalar: zemin, köprü, bölge, yapı noktası, dekor ve satılık adanın tabelası.

-- Studio plugin'i modülleri kopyalayıp taze Config ile çalıştırır; Shared araması SharedRef'te (kopyadaki Shared'ı bulur).
local Shared = require(script.Parent:WaitForChild("SharedRef")) :: typeof(game.ReplicatedStorage.Shared)
local Config = require(Shared:WaitForChild("Config"))
local UiTheme = require(Shared:WaitForChild("UiTheme"))
local WorldUi = require(Shared:WaitForChild("WorldUi"))
local WorldDecor = require(script.Parent:WaitForChild("WorldDecor"))
local IslandSpecialization = require(script.Parent:WaitForChild("IslandSpecialization"))
local MapLayout = require(script.Parent:WaitForChild("MapLayout"))
local IslandLooks = require(script.Parent:WaitForChild("IslandLooks"))
local MapParts = require(script.Parent:WaitForChild("MapParts"))
local ModelAssets = require(script.Parent:WaitForChild("ModelAssets"))

local SURFACE_Y = MapLayout.SURFACE_Y
local ISLAND_RADIUS = MapLayout.ISLAND_RADIUS
local SATELLITE_RADIUS = MapLayout.SATELLITE_RADIUS
local SATELLITE_TYPES = MapLayout.SATELLITE_TYPES
type SatelliteLayout = MapLayout.SatelliteLayout
local makePart = MapParts.makePart
local makeDisc = MapParts.makeDisc
local makePromptAnchor = MapParts.makePromptAnchor
local seedFrom = MapParts.seedFrom
local buildZone = MapParts.buildZone
local addBuildSpot = MapParts.addBuildSpot
local buildBridgeBetween = MapParts.buildBridgeBetween
local addIslandGrass = MapParts.addIslandGrass
local lampsAlong = MapParts.lampsAlong

-- Adaya özel süsler ve yollar (açık/kilitli fark etmez; adanın karakterini gösterir)
local warned: { [string]: boolean } = {}
local function warnMissing(name: string)
	if not warned[name] then
		warned[name] = true
		warn(`[SatelliteBuilder] assets/SignModels/{name}.rbxmx bulunamadı; çizilmedi`)
	end
end

local function buildSatelliteDecor(islandId: string, parent: Instance, cf: CFrame)
	local function at(x: number, z: number): CFrame
		return cf * CFrame.new(x, SURFACE_Y, z)
	end
	-- Ortak köprü girişi açık kalır; her adanın çalışma alanı farklı kenardadır.
	WorldDecor.path(parent, at(0, -(SATELLITE_RADIUS - 2)).Position, at(0, -11).Position, 5)
	-- Işıklandırma: köprü yolu boyunca eşit aralıklı, bölge çitinin dört köşesinde ve üretim alanı önünde.
	lampsAlong(parent, at, Vector2.new(0, -(SATELLITE_RADIUS - 6)), Vector2.new(0, -12), 20, 3.9, -1)
	for _, corner in { Vector2.new(-19, -13), Vector2.new(19, -13), Vector2.new(-19, 17), Vector2.new(19, 17) } do
		WorldDecor.lamp(parent, at(corner.X, corner.Y) * CFrame.Angles(0, if corner.X > 0 then math.pi else 0, 0))
	end
	local look = IslandLooks[islandId]
	if look and look.props then
		-- Veri odaklı süsler (Çiftlik 2'den sonraki adalar): IslandLooks[ada].props
		for index, item in look.props do
			local seed = item.seed or (seedFrom(cf) + index * 7)
			local spot = at(item.x, item.z)
			if item.kind == "oak" then
				WorldDecor.oakTree(parent, spot, seed)
			elseif item.kind == "pine" then
				WorldDecor.pineTree(parent, spot, seed)
			elseif item.kind == "bush" then
				WorldDecor.bush(parent, spot, seed)
			elseif item.kind == "flowers" then
				WorldDecor.flowerPatch(parent, spot, seed)
			elseif item.kind == "hay" then
				WorldDecor.hayBale(parent, spot * CFrame.Angles(0, math.rad(index * 37), 0), false)
			elseif item.kind == "scarecrow" then
				WorldDecor.scarecrow(parent, spot)
			elseif item.kind == "barrel" then
				WorldDecor.barrel(parent, spot)
			elseif item.kind == "crate" then
				WorldDecor.crate(parent, spot, item.size or 2)
			elseif item.kind == "wheelbarrow" then
				WorldDecor.wheelbarrow(parent, spot * CFrame.Angles(0, math.rad(index * 53), 0))
			elseif item.kind == "mailbox" then
				WorldDecor.mailbox(parent, spot)
			end
		end
	elseif islandId == "pig" then
		-- Trüf ormanı: yoğun çam ve çalı, bölgenin çevresinde
		for index, spot in
			{
				Vector2.new(-6, 49),
				Vector2.new(8, 50),
				Vector2.new(-41, 14),
				Vector2.new(41, 10),
				Vector2.new(-38, -10),
				Vector2.new(36, -18),
			}
		do
			WorldDecor.pineTree(parent, at(spot.X, spot.Y), seedFrom(cf) + index * 7)
		end
		WorldDecor.bush(parent, at(-36, 30), 31)
		WorldDecor.bush(parent, at(35, -26), 33)
	elseif islandId == "goat" then
		WorldDecor.pineTree(parent, at(41, 12), seedFrom(cf))
		WorldDecor.bush(parent, at(33, -28), 23)
	else
		for _, x in { -41, 41 } do
			if islandId == "horse" then
				WorldDecor.pineTree(parent, at(x, 18), seedFrom(cf) + x)
			else
				WorldDecor.oakTree(parent, at(x, 17), seedFrom(cf) + x)
			end
		end
		WorldDecor.bush(parent, at(35, 30), 21 + #islandId)
	end
	IslandSpecialization.build(parent, islandId, cf * CFrame.new(0, SURFACE_Y, 0))
	local layoutZone = if SATELLITE_TYPES[islandId] then SATELLITE_TYPES[islandId].zone else nil
	addIslandGrass(
		parent,
		cf * CFrame.new(0, SURFACE_Y, 0),
		islandId,
		SATELLITE_RADIUS,
		if layoutZone then { layoutZone } else {},
		{
			{ x = 0, z = -31, hx = 4, hz = 23 }, -- köprü yolu
			{ x = 18, z = 37, hx = 12, hz = 8 }, -- üretim binası yeri
			{ x = -18, z = 37, hx = 12, hz = 8 }, -- ürün merkezi yeri
		},
		45,
		seedFrom(cf)
	)
end

-- Uzman ada: gövde, bölge, tabela (satın alma düğmesiyle), uzaktan görünen ad, bina yeri, köprü
local function buildSatellite(
	plotModel: Model,
	islandsFolder: Instance,
	buildSpots: Instance,
	homeCf: CFrame,
	layout: SatelliteLayout,
	withTerrain: boolean?
)
	local islandConfig = Config.FARM_ISLANDS[layout.id]
	local upgrade = if islandConfig.upgradeId then Config.getUpgrade(islandConfig.upgradeId) else nil

	local islandModel = Instance.new("Model")
	islandModel.Name = islandConfig.displayName
	islandModel:SetAttribute("FarmIslandId", layout.id)
	islandModel.Parent = islandsFolder

	local center = homeCf * CFrame.new(layout.offset)
	local cf = CFrame.lookAt(center.Position, homeCf.Position) -- -Z ana adaya (köprüye) bakar
	-- Yardımcıların yol ağı: ada çerçevesi (yüzeyde), köprü girişi ve yolun bölgeye varan ucu
	islandModel:SetAttribute("IslandFrame", cf * CFrame.new(0, SURFACE_Y, 0))
	islandModel:SetAttribute("PathStart", (cf * CFrame.new(0, SURFACE_Y, -(SATELLITE_RADIUS - 2))).Position)
	islandModel:SetAttribute("PathEnd", (cf * CFrame.new(0, SURFACE_Y, -11)).Position)

	-- Kıyı Terrain (kaya + kum plaj); üstü düz çimen parça
	WorldDecor.terrainIsland(islandModel, cf.Position, SATELLITE_RADIUS, SURFACE_Y, 7, withTerrain)
	if withTerrain ~= false then
		WorldDecor.shoreRocks(cf, SATELLITE_RADIUS, { 35, -35, 90, -90, 140, -140 }, seedFrom(cf))
	end
	local base = makeDisc(
		"IslandBase",
		SATELLITE_RADIUS * 2,
		4,
		cf * CFrame.new(0, SURFACE_Y - 2, 0),
		layout.groundColor,
		islandModel
	)
	-- Ada yüzeyi: tam düz parça (kilitliyken PlotService toprak rengine çevirir)
	base.Material = Enum.Material.LeafyGrass
	base:SetAttribute("OpenColor", layout.groundColor)
	base:SetAttribute("Radius", SATELLITE_RADIUS)
	islandModel.PrimaryPart = base

	buildZone(plotModel, cf, layout.zone)
	if layout.buildSpot then
		local spotCf = cf * CFrame.new(layout.buildSpot.offset.X, SURFACE_Y, layout.buildSpot.offset.Z)
		addBuildSpot(buildSpots, layout.buildSpot.upgradeId, spotCf)
	end
	if layout.itemSpot then
		local itemCf = cf * CFrame.new(layout.itemSpot.offset.X, SURFACE_Y, layout.itemSpot.offset.Z)
		addBuildSpot(buildSpots, layout.itemSpot.upgradeId, itemCf)
	end
	for upgradeId, site in IslandSpecialization.SITES do
		if site.island == layout.id then
			local marker =
				addBuildSpot(buildSpots, upgradeId, cf * CFrame.new(site.offset + Vector3.new(0, SURFACE_Y, 0)))
			marker:SetAttribute("FarmIslandId", layout.id)
		end
	end
	buildSatelliteDecor(layout.id, islandModel, cf)

	-- Satılık ada süsü: henüz alınmamış adada "SATILIK" flamaları ve taş yığınları; ada açılınca gizlenir
	-- (PlotService). Böylece kilitli ada bomboş toprak yerine sahipsiz ama davetkar bir yer gibi görünür.
	local forSale = Instance.new("Model")
	forSale.Name = "LockedDecor"
	forSale.Parent = islandModel
	for index, spot in { Vector2.new(-35, -14), Vector2.new(35, -14), Vector2.new(-34, 30), Vector2.new(34, 30) } do
		local saleBase = cf * CFrame.new(spot.X, SURFACE_Y, spot.Y) * CFrame.Angles(0, math.rad(index * 40), 0)
		local marker = ModelAssets.clone("SignModels", "SaleMarker")
		if marker then
			local banner = marker:FindFirstChild("SaleBanner")
			if banner and banner:IsA("BasePart") then
				for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
					WorldUi.sign(banner, face, { text = "SATILIK", textColor = Color3.fromRGB(255, 240, 210) })
				end
			end
			marker:PivotTo(saleBase)
			marker.Parent = forSale
		else
			warnMissing("SaleMarker")
		end
	end

	-- Köprü girişinin yanında, yolun dışında tek direkli küçük ada tabelası: ad + özellik;
	-- kilitliyken "Satın Al" düğmesi. Alt kenarı karakter boyunun üstünde, yürümeye engel olmaz.
	local signX, signZ = 9.5, -(SATELLITE_RADIUS - 8)
	local signModel = ModelAssets.clone("SignModels", "IslandSign")
	if signModel then
		local sign = signModel:FindFirstChild("IslandSign")
		if sign and sign:IsA("BasePart") then
			for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
				WorldUi.sign(
					sign,
					face,
					{ icon = islandConfig.icon, title = islandConfig.displayName, text = islandConfig.trait }
				)
			end
		end
		signModel:PivotTo(cf * CFrame.new(signX, SURFACE_Y, signZ))
		-- Direkler ve tahta doğrudan ada modelinin çocuğu olur (PlotService "IslandSign" parçasını burada arar)
		for _, child in signModel:GetChildren() do
			child.Parent = islandModel
		end
		signModel:Destroy()
	else
		warnMissing("IslandSign")
	end
	local promptAnchor = makePromptAnchor(islandModel, (cf * CFrame.new(signX, SURFACE_Y + 2, signZ - 1.5)).Position)
	if upgrade then
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "BuyIslandPrompt"
		prompt.ActionText = "Satın Al"
		prompt.ObjectText = islandConfig.displayName
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.HoldDuration = 0.5
		prompt.MaxActivationDistance = 14
		prompt.RequiresLineOfSight = false
		prompt:SetAttribute("UpgradeId", upgrade.id)
		prompt:SetAttribute("Locked", true)
		prompt.Parent = promptAnchor
	end

	-- Uzaktan görünen ad (kilitliyken fiyatı da yazar; metni PlotService günceller)
	local nameAnchor = makePart(
		"IslandLabelAnchor",
		Vector3.new(1, 1, 1),
		cf * CFrame.new(0, SURFACE_Y + 22, 0),
		Color3.new(),
		islandModel
	)
	nameAnchor.Transparency = 1
	nameAnchor.CanCollide = false
	nameAnchor.CanQuery = false
	WorldUi.tag(nameAnchor, "IslandLabel", {
		text = islandConfig.displayName,
		icon = islandConfig.icon,
		tint = UiTheme.Color.Gold,
		widthStuds = 16,
		heightStuds = 2.8,
		maxDistance = 400,
	})

	-- Ana adadan uzman adaya köprü (iki adanın kenarları arası)
	local direction = (cf.Position - homeCf.Position).Unit
	buildBridgeBetween(
		islandModel,
		homeCf.Position + direction * (ISLAND_RADIUS - 2),
		cf.Position - direction * (SATELLITE_RADIUS - 2)
	)
end

return {
	buildSatellite = buildSatellite,
}
