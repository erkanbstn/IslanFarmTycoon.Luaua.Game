--!strict
-- Gece ışıkları: sokak feneri, küçük fener ve pencere işaretleme (NightLight/NightWindow etiketleri).
-- WorldDecor cephesi bunları birleştirir; her zaman `WorldDecor.<ad>` ile kullan.

local CollectionService = game:GetService("CollectionService")
local ModelAssets = require(script.Parent:WaitForChild("ModelAssets"))

local Lights = {}

local FOLDER = "CommonDecor"
local missingWarned: { [string]: boolean } = {}

-- Fener modeli (assets/CommonDecor); "Lantern" parçası geceleri yanar: DayNight (client) "NightLight" etiketli
-- parçaların ışığını ve parlamasını yönetir.
local function placeLamp(parent: Instance, name: string, base: CFrame, range: number, brightness: number)
	local model = ModelAssets.clone(FOLDER, name)
	if not model then
		if not missingWarned[name] then
			missingWarned[name] = true
			warn(`[DecorLights] assets/{FOLDER}/{name}.rbxmx bulunamadı; fener çizilmedi`)
		end
		return
	end
	ModelAssets.eachNamed(model, { "Lantern" }, function(lantern: BasePart)
		ModelAssets.markLantern(lantern, range, brightness)
	end)
	model:PivotTo(base)
	model.Parent = parent
end

function Lights.lamp(parent: Instance, base: CFrame)
	placeLamp(parent, "Lamp", base, 40, 4)
end

-- Pencere geceleri içeriden yanar: DayNight (client) "NightWindow" parçasını parlatır ve ışığını açar.
function Lights.markNightWindow(window: BasePart)
	window:SetAttribute("NightColor", Color3.fromRGB(255, 219, 140))
	CollectionService:AddTag(window, "NightWindow")
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 205, 130)
	light.Range = 14
	light.Brightness = 1.5
	light.Shadows = false
	light.Enabled = false
	light.Parent = window
end

-- Alçak fener: iskele, balık kafesi yürüme yolu gibi balıkçı noktaları için. Geceleri yanar (DayNight).
function Lights.smallLamp(parent: Instance, base: CFrame)
	placeLamp(parent, "SmallLamp", base, 24, 3)
end

return Lights
