--!strict
-- Bölgelerin içindeki yapılar: inek barınağı, tavuk kümesi, at bölmeleri, yemlik, saman balyaları...
-- Bölge açılınca kurulur, kapanınca (ada boşalınca) silinir; kilitli bölge çıplak toprak görünür.
-- Koordinatlar bölge zemininin merkezine göre: -Z ön (doğma noktası), +Z arka.
-- Görseller hazır modellerdir (assets/ZoneDecor, ZoneFlags, ZoneLevels; kural docs/MODEL_SOZLESMESI.md); burada yalnızca yerleşim, tema seçimi ve çim tutamı vardır.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local WorldDecor = require(script.Parent.Parent:WaitForChild("World"):WaitForChild("WorldDecor"))
local ModelAssets = require(script.Parent.Parent:WaitForChild("World"):WaitForChild("ModelAssets"))
local IslandSiteParts = require(script.Parent.Parent:WaitForChild("World"):WaitForChild("IslandSiteParts"))

local ZoneVisualService = {}

local THEME_COUNT = Config.MAIN_FARM_LIMIT -- ana ada süsü çiftlik numarasına (tema) göre değişir: Decor_pasture_T<1-N>

local LOCKED_GROUND = Color3.fromRGB(150, 120, 90)

local function getGround(zone: Instance): BasePart?
	local ground = zone:FindFirstChild("Ground")
	if ground and ground:IsA("BasePart") then
		return ground
	end
	return nil
end

-- Bölge geliştirme bayrakları: her seviye için bölgenin ön kenarında bir flama (renk = o seviyenin türü).
-- Seviye değişince yenilenir; kinds boşsa kaldırılır.
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
		-- Hazır bayrak (assets/ZoneFlags/ZoneFlag_<tür>, pivot = direk dibi)
		local flag = ModelAssets.clone("ZoneFlags", `ZoneFlag_{kind}`)
		if flag then
			flag:PivotTo(top * CFrame.new(x, 0, z))
			flag.Name = "FlagSet"
			flag.Parent = model
		end
	end
	if withProps ~= false then
		-- Hazır seviye süsü (assets/ZoneLevels/ZoneLevel_<X>x<Z>_Lv<1-5>, pivot = zemin üst yüzü)
		local sizeKey = `{math.floor(ground.Size.X + 0.5)}x{math.floor(ground.Size.Z + 0.5)}`
		local levelProps = ModelAssets.clone("ZoneLevels", `ZoneLevel_{sizeKey}_Lv{math.clamp(#kinds, 1, 5)}`)
		if levelProps then
			levelProps:PivotTo(top)
			levelProps.Name = "LevelProps"
			levelProps.Parent = model
		end
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
	if existing then
		return
	end

	local origin = ground.CFrame * CFrame.new(0, ground.Size.Y / 2, 0)
	local plot = zone.Parent and zone.Parent.Parent
	local farmIndex = tonumber(plot and (plot:GetAttribute("ThemeIndex") or plot:GetAttribute("PlotId"))) or 1
	local themeIndex = ((farmIndex - 1) % THEME_COUNT) + 1
	-- Hazır bölge dekoru (assets/ZoneDecor/Decor_<bölge>; ana ada başlangıç/otlakta tema eki _T<1-6>, pivot = zemin üst yüzü) kurucusu
	local assetName = if zoneId == "starter" or zoneId == "pasture"
		then `Decor_{zoneId}_T{themeIndex}`
		else `Decor_{zoneId}`
	local decor = ModelAssets.clone("ZoneDecor", assetName)
	if not decor then
		-- Bu bölge türünün dekoru yok (ör. suyun üstündeki bölge); yalnızca zemin görünür
		return
	end
	decor:PivotTo(origin)
	ModelAssets.eachNamed(decor, { "Window" }, function(window: BasePart)
		if window.Material == Enum.Material.Glass then
			WorldDecor.markNightWindow(window)
		end
	end)
	decor.Name = "Decor"
	IslandSiteParts.markObstacles(decor) -- katı duvar/direk/yemlik: AnimalAnimator hayvanı bunların içine sokmaz
	decor:SetAttribute("VisualCreatedAt", game:GetService("Workspace"):GetServerTimeNow())
	-- Çimenli zeminlere çim tutamı ve çiçek (ön/orta şerit; arkadaki barınak ve yemlikler hariç)
	if
		(ground.Material == Enum.Material.Grass or ground.Material == Enum.Material.LeafyGrass)
		and zoneId ~= "fishpen"
	then
		-- Ada tabanındaki yamalar yükseltilmiş ağılların altında kalır.
		local wetPatches = Instance.new("Folder")
		wetPatches.Name = "GrassPatches"
		wetPatches.Parent = decor
		wetPatches:SetAttribute("WetFrame", origin)
		wetPatches:SetAttribute("WetBounds", ground.Size)
		wetPatches:SetAttribute("WetSeed", Random.new():NextInteger(1, 1000000))
		wetPatches:SetAttribute("WetGrid", true)
		for group = 1, 4 do
			for lobe = 1, 3 do
				local patch = ModelAssets.part("SurfaceModels", "GrassPatch")
				patch.CFrame = origin * CFrame.new(0, 0.025, 0) * patch.CFrame.Rotation
				patch.Color = ground.Color
				patch.Material = Enum.Material.Grass
				patch.Transparency = 1
				patch:SetAttribute("WetGroup", group)
				patch:SetAttribute("WetLobe", lobe)
				patch.Parent = wetPatches
			end
		end
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
