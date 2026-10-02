--!strict
-- Mevsim ve havanın görsel tarafı (sadece bu oyuncunun ekranında):
--  * Yağmur / kar parçacıkları kameranın etrafında
--  * Fırtınada şimşek çakması
--  * Bulut yoğunluğu, ışık tonu ve pus havaya göre
--  * Ağaç yaprakları mevsime göre: ilkbahar taze yeşil, sonbahar turuncu-kırmızı, kış karlı
-- Gelire etkisi sunucuda hesaplanır (Environment); burası sadece görünüm.

local Players = game:GetService("Players")
local localPlayer = Players.LocalPlayer

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Environment = require(Shared:WaitForChild("Modules"):WaitForChild("Environment"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local connections: { RBXScriptConnection } = {}

-- Studio'daki F7 kısayolunun yetkisi sunucuda da ayrıca doğrulanır.
if RunService:IsStudio() then
	table.insert(
		connections,
		UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
			if
				not gameProcessed
				and input.KeyCode == Enum.KeyCode.F7
				and localPlayer:GetAttribute("IsAdmin") == true
			then
				Remotes.get("DebugCycleWeather"):FireServer()
			end
		end)
	)
end

local TRANSITION = TweenInfo.new(6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)

-- Havanın ve mevsimin görünümü Studio'da düzenlenir: Lighting.Presets/Weather/<havaId> ve Presets/Season/<mevsimId> (Core/LightingPresets).
-- Güneşli parlak ve berrak; bulutlu hafif karanlık; yağmur karanlık ve sisli; fırtına çok karanlık (+ şimşek); kar soğuk ve puslu.
local Presets = require(script.Parent.Parent:WaitForChild("Core"):WaitForChild("LightingPresets"))

local function weatherNumber(weatherId: string, name: string): number
	return Presets.number(`Weather/{weatherId}/{name}`)
end

---------------------------------------------------------------------------
-- Işık ve bulutlar
---------------------------------------------------------------------------

-- Sadece bu client'ta var olan renk düzeltmesi (sunucununkine dokunmaz)
local grade = Instance.new("ColorCorrectionEffect")
grade.Name = "WeatherGrade"
grade.Parent = Lighting
local lookTweens: { [Instance]: Tween } = {}
local originalProperties: { [Instance]: { [string]: any } } = {}
local function transition(target: Instance, properties: { [string]: any })
	local previous = lookTweens[target]
	if previous then
		previous:Cancel()
	end
	local original = originalProperties[target] or {}
	originalProperties[target] = original
	for property in properties do
		if original[property] == nil then
			original[property] = (target :: any)[property]
		end
	end
	if localPlayer:GetAttribute("ReducedMotion") == true then
		for property, value in properties do
			(target :: any)[property] = value
		end
		lookTweens[target] = nil
	else
		local tween = TweenService:Create(target, TRANSITION, properties)
		lookTweens[target] = tween
		tween:Play()
	end
end

local function multiplyColor(a: Color3, b: Color3): Color3
	return Color3.new(a.R * b.R, a.G * b.G, a.B * b.B)
end

local function applyLook()
	local season = Environment.getSeason()
	-- Tanımsız hava kimliği güneşliye düşer
	local id = Environment.getWeather().id
	if not table.find(Presets.names("Weather"), id) then
		id = "sunny"
	end
	local seasonTint = if table.find(Presets.names("Season"), season.id)
		then Presets.color(`Season/{season.id}`)
		else Color3.new(1, 1, 1)

	transition(grade, {
		TintColor = multiplyColor(Presets.color(`Weather/{id}/Tint`), seasonTint),
		Brightness = weatherNumber(id, "Brightness"),
		Saturation = weatherNumber(id, "Saturation"),
		Contrast = weatherNumber(id, "Contrast"),
	})
	-- Genel aydınlık: bulutlu/yağmurlu/fırtınalı havada etraf kararır. ExposureCompensation'ı
	-- DayNight tek başına yazar (hava hedefi + gece payı); burası yalnızca hedefi bildirir.
	Lighting:SetAttribute("WeatherExposure", weatherNumber(id, "Exposure"))
	local sunRays = Lighting:FindFirstChildOfClass("SunRaysEffect")
	if sunRays then
		transition(sunRays, { Intensity = weatherNumber(id, "SunRays") })
	end

	local clouds = Workspace.Terrain:FindFirstChildOfClass("Clouds")
	if clouds then
		transition(clouds, {
			Cover = weatherNumber(id, "CloudCover"),
			Density = weatherNumber(id, "CloudDensity"),
			Color = Presets.color(`Weather/{id}/CloudColor`),
		})
	end
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmosphere then
		transition(atmosphere, { Haze = weatherNumber(id, "Haze"), Density = weatherNumber(id, "Fog") })
	end
end

---------------------------------------------------------------------------
-- Yağmur ve kar: kameranın üstünde duran geniş bir alandan parçacık
---------------------------------------------------------------------------

local WeatherPrecip = require(script.Parent:WaitForChild("WeatherPrecip"))
local stopPrecipitation = WeatherPrecip.start()

---------------------------------------------------------------------------
-- Kar birikimi/erimesi, yaprak dökümü ve ilkbahar çiçekleri ayrı, sınırlı havuz kullanır.
local SeasonalScenery = require(script.Parent:WaitForChild("SeasonalScenery"))
local stopScenery = SeasonalScenery.start()
-- Dünya mevsimi/havası ve oyuncunun asa geçersiz kılması değişince görünüm yenilenir
Environment.onChanged(applyLook)
table.insert(connections, localPlayer:GetAttributeChangedSignal("ReducedMotion"):Connect(applyLook))
applyLook()
script.Destroying:Connect(function()
	for _, connection in connections do
		connection:Disconnect()
	end
	for _, tween in lookTweens do
		tween:Cancel()
	end
	for target, properties in originalProperties do
		if target.Parent then
			for property, value in properties do
				(target :: any)[property] = value
			end
		end
	end
	stopPrecipitation()
	stopScenery()
	grade:Destroy()
end)
