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

type Look = {
	cloudCover: number,
	cloudDensity: number,
	cloudColor: Color3,
	tint: Color3,
	brightness: number,
	saturation: number,
	contrast: number,
	exposure: number, -- Genel aydınlık (negatif = karanlık)
	haze: number,
	fog: number, -- Atmosphere.Density (uzağı ne kadar sisli)
	sunRays: number,
}

-- Havanın görünümü: güneşli parlak ve berrak; bulutlu hafif karanlık; yağmur karanlık ve sisli;
-- fırtına çok karanlık (+ şimşek); kar soğuk ve puslu.
local WEATHER_LOOK: { [string]: Look } = {
	sunny = {
		cloudCover = 0.4,
		cloudDensity = 0.45,
		cloudColor = Color3.fromRGB(255, 255, 255),
		tint = Color3.fromRGB(255, 250, 240),
		brightness = 0.02,
		saturation = 0.05,
		contrast = 0.04,
		exposure = 0.1,
		haze = 1,
		fog = 0.26,
		sunRays = 0.08,
	},
	cloudy = {
		cloudCover = 0.8,
		cloudDensity = 0.75,
		cloudColor = Color3.fromRGB(215, 220, 228),
		tint = Color3.fromRGB(232, 236, 244),
		brightness = -0.03,
		saturation = -0.12,
		contrast = -0.02,
		exposure = -0.35,
		haze = 2,
		fog = 0.33,
		sunRays = 0.02,
	},
	rain = {
		cloudCover = 0.92,
		cloudDensity = 0.9,
		cloudColor = Color3.fromRGB(140, 146, 158),
		tint = Color3.fromRGB(205, 215, 232),
		brightness = -0.06,
		saturation = -0.22,
		contrast = -0.04,
		exposure = -0.75,
		haze = 2.8,
		fog = 0.42,
		sunRays = 0,
	},
	storm = {
		cloudCover = 0.98,
		cloudDensity = 1,
		cloudColor = Color3.fromRGB(85, 90, 102),
		tint = Color3.fromRGB(180, 192, 215),
		brightness = -0.1,
		saturation = -0.3,
		contrast = 0.02,
		exposure = -1.2,
		haze = 3.5,
		fog = 0.48,
		sunRays = 0,
	},
	snow = {
		cloudCover = 0.85,
		cloudDensity = 0.8,
		cloudColor = Color3.fromRGB(225, 230, 240),
		tint = Color3.fromRGB(222, 232, 255),
		brightness = 0.03,
		saturation = -0.25,
		contrast = -0.03,
		exposure = -0.25,
		haze = 2.6,
		fog = 0.4,
		sunRays = 0.01,
	},
}

-- Mevsimin ışık tonu (hava tonuyla çarpılır)
local SEASON_TINT: { [string]: Color3 } = {
	spring = Color3.fromRGB(250, 255, 250),
	summer = Color3.fromRGB(255, 248, 232),
	autumn = Color3.fromRGB(255, 235, 210),
	winter = Color3.fromRGB(232, 240, 255),
}

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
	local weather = Environment.getWeather()
	local look = WEATHER_LOOK[weather.id] or WEATHER_LOOK.sunny

	transition(grade, {
		TintColor = multiplyColor(look.tint, SEASON_TINT[season.id] or Color3.new(1, 1, 1)),
		Brightness = look.brightness,
		Saturation = look.saturation,
		Contrast = look.contrast,
	})
	-- Genel aydınlık: bulutlu/yağmurlu/fırtınalı havada etraf kararır. ExposureCompensation'ı
	-- DayNight tek başına yazar (hava hedefi + gece payı); burası yalnızca hedefi bildirir.
	Lighting:SetAttribute("WeatherExposure", look.exposure)
	local sunRays = Lighting:FindFirstChildOfClass("SunRaysEffect")
	if sunRays then
		transition(sunRays, { Intensity = look.sunRays })
	end

	local clouds = Workspace.Terrain:FindFirstChildOfClass("Clouds")
	if clouds then
		transition(clouds, {
			Cover = look.cloudCover,
			Density = look.cloudDensity,
			Color = look.cloudColor,
		})
	end
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmosphere then
		transition(atmosphere, { Haze = look.haze, Density = look.fog })
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
