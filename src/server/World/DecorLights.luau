--!strict
-- Gece ışıkları: sokak feneri, küçük fener ve pencere işaretleme (NightLight/NightWindow etiketleri).
-- WorldDecor cephesi bunları birleştirir; her zaman `WorldDecor.<ad>` ile kullan.

local CollectionService = game:GetService("CollectionService")
local Parts = require(script.Parent:WaitForChild("DecorParts"))

local part = Parts.part
local column = Parts.column

local Lights = {}

---------------------------------------------------------------------------
-- Çiftlik eşyaları
---------------------------------------------------------------------------

function Lights.lamp(parent: Instance, base: CFrame)
	local model = Instance.new("Model")
	model.Name = "Lamp"
	model.Parent = parent
	local iron = Color3.fromRGB(45, 45, 50)
	column(model, "Pole", 0.5, 9.4, base * CFrame.new(0, 4.7, 0), iron, Enum.Material.Metal)
	part(model, "Arm", Vector3.new(1.8, 0.22, 0.22), base * CFrame.new(0.8, 9.3, 0), iron, Enum.Material.Metal)
	-- Fener geceleri yanar: DayNight (client) "NightLight" etiketli parçaların ışığını ve parlamasını yönetir.
	local lantern = part(
		model,
		"Lantern",
		Vector3.new(0.8, 1, 0.8),
		base * CFrame.new(1.6, 8.6, 0),
		Color3.fromRGB(205, 175, 115),
		Enum.Material.SmoothPlastic
	)
	lantern:SetAttribute("NightColor", Color3.fromRGB(255, 214, 130))
	CollectionService:AddTag(lantern, "NightLight")
	part(model, "Cap", Vector3.new(1, 0.2, 1), base * CFrame.new(1.6, 9.25, 0), iron, Enum.Material.Metal)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 205, 130)
	light.Range = 40
	light.Brightness = 4
	light.Shadows = false
	light.Enabled = false
	light.Parent = lantern
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
	local model = Instance.new("Model")
	model.Name = "SmallLamp"
	model.Parent = parent
	local iron = Color3.fromRGB(45, 45, 50)
	column(model, "Pole", 0.3, 3.6, base * CFrame.new(0, 1.8, 0), iron, Enum.Material.Metal)
	local lantern = part(
		model,
		"Lantern",
		Vector3.new(0.7, 0.8, 0.7),
		base * CFrame.new(0, 4, 0),
		Color3.fromRGB(205, 175, 115),
		Enum.Material.SmoothPlastic
	)
	lantern:SetAttribute("NightColor", Color3.fromRGB(255, 214, 130))
	CollectionService:AddTag(lantern, "NightLight")
	part(model, "Cap", Vector3.new(0.9, 0.18, 0.9), base * CFrame.new(0, 4.5, 0), iron, Enum.Material.Metal)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 205, 130)
	light.Range = 24
	light.Brightness = 3
	light.Shadows = false
	light.Enabled = false
	light.Parent = lantern
end

return Lights
