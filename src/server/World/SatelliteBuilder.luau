--!strict
-- Uzman (küçük) adalar: zemin, köprü, bölge, yapı noktası, dekor ve satılık adanın tabelası.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Studio plugin'i modülleri kopyalayıp taze Config ile çalıştırır; o durumda yanımızdaki "Shared" kullanılır.
local Shared = script.Parent.Parent:FindFirstChild("Shared") or ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local UiTheme = require(Shared:WaitForChild("UiTheme"))
local WorldUi = require(Shared:WaitForChild("WorldUi"))
local WorldDecor = require(script.Parent:WaitForChild("WorldDecor"))
local IslandSpecialization = require(script.Parent:WaitForChild("IslandSpecialization"))
local MapLayout = require(script.Parent:WaitForChild("MapLayout"))
local MapParts = require(script.Parent:WaitForChild("MapParts"))

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
	if islandId == "pig" then
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
	layout: SatelliteLayout
)
	local islandConfig = Config.FARM_ISLANDS[layout.id]
	local upgrade = if islandConfig.upgradeId then Config.getUpgrade(islandConfig.upgradeId) else nil

	local islandModel = Instance.new("Model")
	islandModel.Name = islandConfig.displayName
	islandModel:SetAttribute("FarmIslandId", layout.id)
	islandModel.Parent = islandsFolder

	local center = homeCf * CFrame.new(layout.offset)
	local cf = CFrame.lookAt(center.Position, homeCf.Position) -- -Z ana adaya (köprüye) bakar

	-- Kıyı Terrain (kaya + kum plaj); üstü düz çimen parça
	WorldDecor.terrainIsland(islandModel, cf.Position, SATELLITE_RADIUS, SURFACE_Y, 7)
	WorldDecor.shoreRocks(cf, SATELLITE_RADIUS, { 35, -35, 90, -90, 140, -140 }, seedFrom(cf))
	local base = makeDisc(
		"IslandBase",
		SATELLITE_RADIUS * 2,
		4,
		cf * CFrame.new(0, SURFACE_Y - 2, 0),
		layout.groundColor,
		islandModel
	)
	-- Ada yüzeyi: tam düz parça (kilitliyken PlotService toprak rengine çevirir)
	base.Material = Enum.Material.Grass
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
		local pole = makePart(
			"SalePole",
			Vector3.new(0.45, 10, 0.45),
			saleBase * CFrame.new(0, 5, 0),
			Color3.fromRGB(120, 85, 55),
			forSale
		)
		pole.Material = Enum.Material.Wood
		local banner = makePart(
			"SaleBanner",
			Vector3.new(4.2, 2.4, 0.2),
			saleBase * CFrame.new(2.3, 8.6, 0),
			Color3.fromRGB(196, 60, 52),
			forSale
		)
		banner.Material = Enum.Material.Fabric
		for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
			WorldUi.sign(banner, face, { text = "SATILIK", textColor = Color3.fromRGB(255, 240, 210) })
		end
		for rock = 1, 3 do
			local stone = makePart(
				"SaleStone",
				Vector3.new(1.6 + rock * 0.5, 1.2 + rock * 0.2, 1.8 + rock * 0.4),
				saleBase * CFrame.new(rock * 1.3 - 3.4, 0.5, 1.6 + rock * 0.5) * CFrame.Angles(0.1 * rock, rock, 0.05),
				Color3.fromRGB(120, 118, 110),
				forSale
			)
			stone.Material = Enum.Material.Slate
		end
	end

	-- Köprü girişinin yanında, yolun dışında tek direkli küçük ada tabelası: ad + özellik;
	-- kilitliyken "Satın Al" düğmesi. Alt kenarı karakter boyunun üstünde, yürümeye engel olmaz.
	local signX, signZ = 9.5, -(SATELLITE_RADIUS - 8)
	local frameColor = Color3.fromRGB(140, 100, 60)
	local boardWidth = 6.4
	-- İki yan direk tabelanın DIŞINDA durur; tahta direklerin içine girmez, yolun ortası boş kalır.
	for _, side in { -1, 1 } do
		local post = makePart(
			"SignPost",
			Vector3.new(0.5, 15.4, 0.5),
			cf * CFrame.new(signX + side * (boardWidth / 2 + 0.35), SURFACE_Y + 7.7, signZ),
			frameColor,
			islandModel
		)
		post.Material = Enum.Material.Wood
	end
	local sign = makePart(
		"IslandSign",
		Vector3.new(boardWidth, 2.2, 0.35),
		cf * CFrame.new(signX, SURFACE_Y + 13.6, signZ),
		Color3.fromRGB(85, 60, 40),
		islandModel
	)
	sign.Material = Enum.Material.WoodPlanks
	sign.CanCollide = false
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		WorldUi.sign(
			sign,
			face,
			{ icon = islandConfig.icon, title = islandConfig.displayName, text = islandConfig.trait }
		)
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
