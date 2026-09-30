--!strict
-- Bölgelerin içindeki yapılar: inek barınağı, tavuk kümesi, at bölmeleri, yemlik, saman balyaları...
-- Bölge açılınca kurulur, kapanınca (ada boşalınca) silinir; kilitli bölge çıplak toprak görünür.
-- Koordinatlar bölge zemininin merkezine göre: -Z ön (doğma noktası), +Z arka.
-- Parçalar: ZoneParts (ortak yapı taşları), ZoneBuildersHome/Pens/Water (bölge görselleri).

local WorldDecor = require(script.Parent.Parent:WaitForChild("World"):WaitForChild("WorldDecor"))
local ZoneParts = require(script.Parent:WaitForChild("ZoneParts"))
local ZoneLevelDecor = require(script.Parent:WaitForChild("ZoneLevelDecor"))
local BuildersHome = require(script.Parent:WaitForChild("ZoneBuildersHome"))
local BuildersPens = require(script.Parent:WaitForChild("ZoneBuildersPens"))
local BuildersWater = require(script.Parent:WaitForChild("ZoneBuildersWater"))

local ZoneVisualService = {}

type Builder = ZoneParts.Builder
local part = ZoneParts.part
local THEME_LOOKS = ZoneParts.THEME_LOOKS
local Look = ZoneParts.Look

local LOCKED_GROUND = Color3.fromRGB(150, 120, 90)

-- Bölge id -> görsel kurucu (gruplar ayrı dosyalarda)
local BUILDERS: { [string]: Builder } = {}
for _, group in { BuildersHome, BuildersPens, BuildersWater } do
	for id, builder in group do
		BUILDERS[id] = builder
	end
end

-- Süt Adası çayırı: ağıl yapısı, çevresi açık. (Tablonun kendi başlatıcısında BUILDERS henüz yerel değildir; bu yüzden sonradan atanır.)
BUILDERS.dairy = function(decor, o, size)
	BUILDERS.starter(decor, o, size)
end

local function getGround(zone: Instance): BasePart?
	local ground = zone:FindFirstChild("Ground")
	if ground and ground:IsA("BasePart") then
		return ground
	end
	return nil
end

-- Bölge geliştirme bayrakları: her seviye için bölgenin ön kenarında bir flama (renk = o seviyenin türü).
-- Seviye değişince yenilenir; kinds boşsa kaldırılır.
local FLAG_COLORS: { [string]: Color3 } = {
	growth = Color3.fromRGB(96, 190, 110),
	income = Color3.fromRGB(245, 195, 70),
	season = Color3.fromRGB(96, 170, 230),
	capacity = Color3.fromRGB(235, 232, 220),
}
-- withProps: seviye süsleri (yemlik, gölgelik...) de kurulsun (denizdeki bölgede kurulmaz)
function ZoneVisualService.applyLevelFlags(zone: Instance, kinds: { string }, withProps: boolean?)
	local signature = table.concat(kinds, ",") .. (if withProps == false then "|flags" else "")
	local existing = zone:FindFirstChild("LevelFlags")
	if existing and existing:GetAttribute("Signature") == signature then
		return
	end
	if existing then
		existing:Destroy()
	end
	local ground = getGround(zone)
	if not ground or #kinds == 0 then
		return
	end
	local model = Instance.new("Model")
	model.Name = "LevelFlags"
	model:SetAttribute("Signature", signature)
	local top = ground.CFrame * CFrame.new(0, ground.Size.Y / 2, 0)
	for index, kind in kinds do
		local x = -ground.Size.X / 2 + 2.2 + (index - 1) * 2.4
		local z = -ground.Size.Z / 2 + 1.4
		local pole = part(
			model,
			"FlagPole",
			Vector3.new(0.25, 5, 0.25),
			top * CFrame.new(x, 2.5, z),
			Color3.fromRGB(235, 235, 235),
			Enum.Material.Metal
		)
		pole.CanCollide = false
		local cloth = part(
			model,
			"Flag",
			Vector3.new(1.7, 1.05, 0.08),
			top * CFrame.new(x + 0.95, 4.4, z),
			FLAG_COLORS[kind] or FLAG_COLORS.capacity,
			Enum.Material.Fabric
		)
		cloth.CanCollide = false
	end
	if withProps ~= false then
		ZoneLevelDecor.build(model, top, ground.Size, #kinds)
	end
	model.Parent = zone
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
	local plot = zone.Parent and zone.Parent.Parent
	local farmIndex = tonumber(plot and plot:GetAttribute("PlotId")) or 1
	Look.current = THEME_LOOKS[((farmIndex - 1) % #THEME_LOOKS) + 1]
	Look.barnColor = Look.current.barn
	builder(decor, origin, ground.Size)
	-- Çimenli zeminlere çim tutamı ve çiçek (ön/orta şerit; arkadaki barınak ve yemlikler hariç)
	if ground.Material == Enum.Material.Grass and zoneId ~= "fishpen" then
		local backReserve = ground:GetAttribute("BackReserve")
		local reserve = if typeof(backReserve) == "number" then backReserve else 4
		local hz = ground.Size.Z / 2
		WorldDecor.grassTufts(decor, origin, {
			count = 30,
			seed = #zoneId * 131 + math.floor(ground.Position.X + ground.Position.Z),
			halfX = ground.Size.X / 2 - 2,
			zMin = -hz + 2,
			zMax = hz - reserve - 8,
			flowerChance = 0.18,
		})
	end
	do
		local parts = 0
		for _, descendant in decor:GetDescendants() do
			if descendant:IsA("BasePart") then
				parts += 1
			end
		end
		decor:SetAttribute("PartCount", parts)
	end
	WorldDecor.optimize(decor)
	decor.Parent = zone
end

return ZoneVisualService
