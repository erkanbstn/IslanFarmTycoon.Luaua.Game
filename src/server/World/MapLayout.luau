--!strict
-- Harita düzeni: boyutlar, bölge/yapı yerleşimleri ve küçük ada ile ana ada yerleşim hesapları.
-- Buradaki değer değişirse `MapBuilder` içindeki MAP_VERSION artırılır (bkz. docs/MIMARI.md, world-map kuralı).

-- Studio plugin'i modülleri kopyalayıp taze Config ile çalıştırır; Shared araması SharedRef'te (kopyadaki Shared'ı bulur).
local Shared = require(script.Parent:WaitForChild("SharedRef")) :: typeof(game.ReplicatedStorage.Shared)
local Config = require(Shared:WaitForChild("Config"))
local IslandLooks = require(script.Parent:WaitForChild("IslandLooks"))

local SURFACE_Y = 4 -- Ada ve meydan yüzeyinin yüksekliği

local WATER_Y = 0 -- Deniz yüzeyi

local ISLAND_RADIUS = 70

local SATELLITE_RADIUS = 52

local HUB_RADIUS = 40

local WATER_SIZE = 1100

local WATER_DEPTH = 20

export type ZoneLayout = {
	id: string,
	offset: Vector3,
	size: Vector3,
	color: Color3,
	backReserve: number, -- Arkada hayvan konmayacak şerit (barınak, kümes...)
	water: boolean?, -- Denizdeki bölge (balık kafesi): zemin görünmez, çit yerine yüzen iskele
	material: Enum.Material?, -- Zemin dokusu; yoksa çim
}

local FISH_PEN_CENTER = Vector3.new(-40, 0, -95)

local FISH_PEN_SIZE = Vector3.new(20, 0.4, 20)

local FISH_WALKWAY_WIDTH = 2.4

-- Ana adadaki bölgeler (ana ada yerel koordinatı)
local HOME_ZONES: { ZoneLayout } = {
	{
		id = "starter",
		offset = Vector3.new(-20, 0, 2),
		size = Vector3.new(30, 0.4, 24),
		color = Color3.fromRGB(96, 150, 70),
		backReserve = 2.5,
	},
	{
		id = "pasture",
		offset = Vector3.new(20, 0, 2),
		size = Vector3.new(30, 0.4, 26),
		color = Color3.fromRGB(110, 170, 80),
		backReserve = 4,
	},
	-- Ana adanın ön-solunda denizde; iskeleyle bağlı (meydan köprüsünden ve komşu adalardan uzak)
	{
		id = "fishpen",
		offset = FISH_PEN_CENTER,
		size = FISH_PEN_SIZE,
		color = Color3.fromRGB(40, 110, 150),
		backReserve = 0,
		water = true,
	},
}

local DOCK_START = Vector3.new(-26.4, 0, -62.7) -- Ana adanın kenarında, kafese bakan nokta

-- Diyagonal iskelenin ucu yakın yürüyüş tahtasının merkezine ulaşır; sabit uzunlukta boşluk kalmaz.
local dockDirection = (FISH_PEN_CENTER - DOCK_START).Unit

local dockJoinZ = FISH_PEN_CENTER.Z + FISH_PEN_SIZE.Z / 2 + FISH_WALKWAY_WIDTH / 2

local DOCK_LENGTH = (dockJoinZ - DOCK_START.Z) / dockDirection.Z

local DOCK_SURFACE_Y = SURFACE_Y - 0.04 -- Kara/tahta birleşiminde üst üste yüzeyler titreşmesin.

-- Ana adadaki güçlendirme binalarının yerleri (UpgradeVisualService kullanır)
local HOME_BUILD_SPOTS: { [string]: Vector3 } = {
	silo = Vector3.new(-31, 0, 33),
	milk_machine = Vector3.new(31, 0, 33),
	auto_collector = Vector3.new(24, 0, -40),
	-- Ürün merkezleri (depoya ürün üretir): süt merkezi ahırın arkasında; balık merkezi iskelenin yanında (kapısı iskeleye bakar)
	milk_center = Vector3.new(-20, 0, 56),
	fish_cannery = Vector3.new(-34, 0, -46),
	-- Ana ada fabrikaları ve ürün merkezleri ana hayvana göre değişir (Config.upgradeInTheme): her ana hayvanın yuvası süt yuvalarıyla aynı yerdedir;
	-- bir çiftlikte yalnızca ana hayvanın yükseltmesi alınabildiği için üst üste binmezler (aşağıda Config.SPECIES'ten eklenir).
	duck_packer = Vector3.new(43, 0, -21),
	down_home_center = Vector3.new(-20, 0, 56),
}

-- Hayvan türü tablosundaki ana ada hayvanlarının fabrika ve ürün merkezi yuvaları (ana hayvan başına tek yuva çifti)
for _, species in Config.SPECIES do
	if species.slot == "home" then
		HOME_BUILD_SPOTS[species.cash.factory] = Vector3.new(43, 0, -21)
		HOME_BUILD_SPOTS[species.center.building] = Vector3.new(-20, 0, 56)
	end
end

-- Denizdeki bina yerleri (su seviyesinde): Balıkçı Teknesi kafesin dış kenarına bağlanır
local HOME_WATER_SPOTS: { [string]: { offset: Vector3, yaw: number } } = {
	fishing_boat = { offset = Vector3.new(-40, 0, -126), yaw = 90 },
}

export type SatelliteLayout = {
	id: string, -- Config.FARM_ISLANDS id
	offset: Vector3, -- Ana adaya göre konum
	groundColor: Color3,
	zone: ZoneLayout,
	buildSpot: { upgradeId: string, offset: Vector3 }?,
	itemSpot: { upgradeId: string, offset: Vector3 }?, -- ürün merkezi (depoya ürün üreten fabrika) yapı noktası
}

-- Uzman adalar (kendi yerel koordinatlarında -Z ana adaya, yani köprüye bakar).
-- Üç yuva her ana adada aynıdır; yuvaya hangi ada türünün konacağını ana çiftlik numarasının teması belirler
-- (Config.THEMES). Ada türünün zemini, bölgesi ve yapı noktası burada tanımlıdır.
-- Komşu çiftliklerin adalarına en az ~24 stud su kalacak biçimde hesaplandı (6 ada halkası, yarıçap 175).
local SATELLITE_SLOTS = { Vector3.new(-100, 0, 125), Vector3.new(100, 0, 125), Vector3.new(0, 0, 200) }

export type SatelliteType = {
	groundColor: Color3,
	zone: ZoneLayout,
	buildSpot: { upgradeId: string, offset: Vector3 }?,
	itemSpot: { upgradeId: string, offset: Vector3 }?, -- ürün merkezi (depoya ürün üreten fabrika) yapı noktası
}

local function satelliteZone(id: string, color: Color3, backReserve: number): ZoneLayout
	return {
		id = id,
		offset = Vector3.new(0, 0, 2),
		size = Vector3.new(30, 0.4, 24),
		color = color,
		backReserve = backReserve,
	}
end

-- Küçük ada türleri: Config.FARM_ISLANDS (zemin/bölge/yapı noktası yükseltmeleri) + IslandLooks (renk ve doku). Yeni ada = bir Config satırı + bir IslandLooks satırı.
local SATELLITE_TYPES: { [string]: SatelliteType } = {}
for islandId, island in Config.FARM_ISLANDS do
	if not island.upgradeId then
		continue -- ana ada
	end
	local look = IslandLooks[islandId]
	assert(look, `IslandLooks[{islandId}] eksik`)
	local zoneId: string? = nil
	for _, candidate in Config.ZONE_ORDER do
		if Config.ZONES[candidate].island == islandId then
			zoneId = candidate
			break
		end
	end
	assert(zoneId, `{islandId} adasının bölgesi yok`)
	local zone = satelliteZone(zoneId, look.zone, look.backReserve)
	zone.material = look.material
	SATELLITE_TYPES[islandId] = {
		groundColor = look.ground,
		zone = zone,
		buildSpot = { upgradeId = island.buildUpgradeId :: string, offset = Vector3.new(18, 0, 37) },
		itemSpot = { upgradeId = island.itemUpgradeId :: string, offset = Vector3.new(-18, 0, 37) },
	}
end

-- Bir ana adanın (fiziksel ada numarası = çiftlik numarası) küçük ada yerleşimleri
local function satelliteLayouts(plotIndex: number): { SatelliteLayout }
	local layouts: { SatelliteLayout } = {}
	for slot, islandId in Config.getTheme(tostring(plotIndex)).satellites do
		local kind = SATELLITE_TYPES[islandId]
		if kind then
			table.insert(layouts, {
				id = islandId,
				offset = SATELLITE_SLOTS[slot],
				groundColor = kind.groundColor,
				zone = kind.zone,
				buildSpot = kind.buildSpot,
				itemSpot = kind.itemSpot,
			})
		end
	end
	return layouts
end

-- Ana adanın yolları ve süsleri. Yollar: meydan köprüsü → doğma noktası → ağıllar → ahır → uzman ada köprüleri
-- Ana ada düzeni çiftlik numarasına (temaya) göre değişir: batı kümesinde bahçe↔ambar ve değirmen↔kovan yer değiştirir,
-- doğuda çiftlik evi↔meyve bahçesi yer değiştirir, kuyu iki yandan birinde durur. Yol, bölge ve yapı noktaları sabittir;
-- yalnızca bu listedeki yuvalar arasında permütasyon yapılır (her yuva aynı yöne, ada merkezine bakar).
export type HomePlacement = { x: number, z: number, yaw: number, hx: number, hz: number }

local FACE_EAST, FACE_WEST = math.rad(-90), math.rad(90) -- ön yüz +X / -X

local HOME_LAYOUT_FLAGS = {
	{ swapGarden = false, swapWindmill = false, swapEast = false, wellEast = false },
	{ swapGarden = true, swapWindmill = false, swapEast = false, wellEast = true },
	{ swapGarden = false, swapWindmill = true, swapEast = true, wellEast = false },
	{ swapGarden = true, swapWindmill = true, swapEast = false, wellEast = false },
	{ swapGarden = false, swapWindmill = false, swapEast = true, wellEast = true },
	{ swapGarden = true, swapWindmill = true, swapEast = true, wellEast = true },
}

local HOME_LANDMARK_SLOT = Vector2.new(59, -7) -- ana ada fabrikasının (43,-21) dışında; yoksa Ahır Sv.4 işareti fabrikanın içinde belirir

local function homePlacements(plotIndex: number): { [string]: HomePlacement }
	local flags = HOME_LAYOUT_FLAGS[(plotIndex - 1) % #HOME_LAYOUT_FLAGS + 1]
	local placements: { [string]: HomePlacement } = {}
	-- Batı yuvaları: w1 (-49,-18) w2 (-43,10) w3 (-42,-27) w4 (-46,32)
	local gardenSlot, granarySlot = Vector2.new(-43, 10), Vector2.new(-46, 32)
	if flags.swapGarden then
		gardenSlot, granarySlot = granarySlot, gardenSlot
	end
	local windmillSlot, hivesSlot = Vector2.new(-49, -18), Vector2.new(-42, -27)
	if flags.swapWindmill then
		windmillSlot, hivesSlot = hivesSlot, windmillSlot
	end
	placements.garden = { x = gardenSlot.X, z = gardenSlot.Y, yaw = 0, hx = 9, hz = 8 }
	placements.granary = { x = granarySlot.X, z = granarySlot.Y, yaw = FACE_EAST, hx = 8, hz = 9 }
	placements.windmill = { x = windmillSlot.X, z = windmillSlot.Y, yaw = FACE_EAST, hx = 8, hz = 8 }
	placements.hives = { x = hivesSlot.X, z = hivesSlot.Y, yaw = 0, hx = 7, hz = 7 }
	-- Doğu yuvaları: e1 (46,6) ve e2 (40,20); çiftlik evi e2'ye taşınınca bölgeye girmesin diye (45,26)
	if flags.swapEast then
		placements.orchard = { x = 46, z = 6, yaw = 0, hx = 9, hz = 10 }
		placements.farmhouse = { x = 45, z = 26, yaw = FACE_WEST, hx = 10, hz = 10 }
	else
		placements.farmhouse = { x = 46, z = 6, yaw = FACE_WEST, hx = 10, hz = 10 }
		placements.orchard = { x = 40, z = 20, yaw = 0, hx = 9, hz = 11 }
	end
	placements.well = { x = if flags.wellEast then 24 else -24, z = 21, yaw = 0, hx = 5, hz = 5 }
	placements.market = { x = -13, z = -40, yaw = FACE_EAST, hx = 6, hz = 7 }
	placements.landmark = { x = HOME_LANDMARK_SLOT.X, z = HOME_LANDMARK_SLOT.Y, yaw = 0, hx = 8, hz = 8 }
	return placements
end

-- Yapıların çim tutamı kaçınma dikdörtgenleri (yerleşimle birlikte değişir)
local function homeBuildingAvoidRects(plotIndex: number): { { x: number, z: number, hx: number, hz: number } }
	local rects = {}
	for _, spot in homePlacements(plotIndex) do
		table.insert(rects, { x = spot.x, z = spot.z, hx = spot.hx, hz = spot.hz })
	end
	-- Güçlendirme ve ürün merkezi binaları (yanlarındaki bidon/sandık gibi süsler dahil) da çim tutamı almaz
	for _, spot in HOME_BUILD_SPOTS do
		table.insert(rects, { x = spot.X, z = spot.Z, hx = 12, hz = 8 })
	end
	return rects
end

return {
	SURFACE_Y = SURFACE_Y,
	WATER_Y = WATER_Y,
	ISLAND_RADIUS = ISLAND_RADIUS,
	SATELLITE_RADIUS = SATELLITE_RADIUS,
	HUB_RADIUS = HUB_RADIUS,
	WATER_SIZE = WATER_SIZE,
	WATER_DEPTH = WATER_DEPTH,
	FISH_PEN_CENTER = FISH_PEN_CENTER,
	FISH_PEN_SIZE = FISH_PEN_SIZE,
	FISH_WALKWAY_WIDTH = FISH_WALKWAY_WIDTH,
	HOME_ZONES = HOME_ZONES,
	DOCK_START = DOCK_START,
	DOCK_LENGTH = DOCK_LENGTH,
	DOCK_SURFACE_Y = DOCK_SURFACE_Y,
	HOME_BUILD_SPOTS = HOME_BUILD_SPOTS,
	HOME_WATER_SPOTS = HOME_WATER_SPOTS,
	SATELLITE_TYPES = SATELLITE_TYPES,
	satelliteLayouts = satelliteLayouts,
	homePlacements = homePlacements,
	homeBuildingAvoidRects = homeBuildingAvoidRects,
}
