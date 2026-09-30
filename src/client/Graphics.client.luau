--!strict
-- Grafik kalitesi: tercih (GraphicsMode: auto/low/medium/high) bu cihazdaki gerçek kalite kademesine çevrilir.
--   • EffectsQuality (low/medium/high): tüm parçacık/hayvan/balık/kuş efektlerinin bütçesi (var olan tüketiciler okur)
--   • Render profili: gölge, yansıma, parıltı, güneş ışınları, bulut, su, alan derinliği ve zemin süsü bu kademeye göre
-- "auto": cihazdan başlar (dokunmatik → düşük, bilgisayar → orta), kare hızı kalıcı kötüyse bir kademe iner,
-- kalıcı iyiyse tavana kadar çıkar (telefon: orta, bilgisayar: yüksek). Elle seçim her zaman kazanır.
-- Bu betik Lighting'in Enabled/ShadowSoftness/Specular alanlarını ve Terrain su/süs alanlarını yazar; ışık rengi/pozlama/sis
-- değerlerini DayNight ve WeatherEffects yazar (çakışma yok).

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

type Tier = "low" | "medium" | "high"
local TIERS: { Tier } = { "low", "medium", "high" }

type Profile = {
	globalShadows: boolean,
	shadowSoftness: number,
	specular: number,
	bloom: boolean,
	sunRays: boolean,
	clouds: boolean,
	depthOfField: boolean,
	decoration: boolean,
	waterReflectance: number,
	waterWaveSize: number,
}

local PROFILES: { [Tier]: Profile } = {
	low = {
		globalShadows = false,
		shadowSoftness = 0.5,
		specular = 0,
		bloom = false,
		sunRays = false,
		clouds = false,
		depthOfField = false,
		decoration = false,
		waterReflectance = 0,
		waterWaveSize = 0.1,
	},
	medium = {
		globalShadows = true,
		shadowSoftness = 0.3,
		specular = 0.6,
		bloom = true,
		sunRays = false,
		clouds = true,
		depthOfField = false,
		decoration = true,
		waterReflectance = 0.35,
		waterWaveSize = 0.25,
	},
	high = {
		globalShadows = true,
		shadowSoftness = 0.2,
		specular = 1,
		bloom = true,
		sunRays = true,
		clouds = true,
		depthOfField = true,
		decoration = true,
		waterReflectance = 0.7,
		waterWaveSize = 0.4,
	},
}

local function isTier(value: unknown): boolean
	return value == "low" or value == "medium" or value == "high"
end

local function tierIndex(tier: Tier): number
	return table.find(TIERS, tier) :: number
end

-- Cihaz: dokunmatik ve klavyesiz → telefon/tablet. Roblox'un kendi kalite ayarı bilgisayarda başlangıcı belirler.
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local function deviceCeiling(): Tier
	return if isMobile then "medium" else "high"
end
local function deviceStart(): Tier
	if isMobile then
		return "low"
	end
	local ok, level = pcall(function()
		return (UserSettings():GetService("UserGameSettings") :: any).SavedQualityLevel.Value
	end)
	if ok and typeof(level) == "number" then
		if level >= 1 and level <= 4 then
			return "low"
		end
	end
	return "medium"
end

-- Elle seçim (auto değil) bu cihazın tavanını aşabilir: oyuncu bilerek seçmiştir.
local autoTier: Tier = deviceStart()
local function resolvedTier(): Tier
	local mode = player:GetAttribute("GraphicsMode")
	if isTier(mode) then
		return mode :: Tier
	end
	return autoTier
end

local depthEffect: DepthOfFieldEffect? = nil

local function setEnabled(instance: Instance?, enabled: boolean)
	if instance and (instance :: any).Enabled ~= enabled then
		(instance :: any).Enabled = enabled
	end
end

local function applyProfile(tier: Tier)
	local profile = PROFILES[tier]
	Lighting.GlobalShadows = profile.globalShadows
	Lighting.ShadowSoftness = profile.shadowSoftness
	Lighting.EnvironmentSpecularScale = profile.specular
	setEnabled(Lighting:FindFirstChildOfClass("BloomEffect"), profile.bloom)
	setEnabled(Lighting:FindFirstChildOfClass("SunRaysEffect"), profile.sunRays)
	local terrain = Workspace.Terrain
	setEnabled(terrain:FindFirstChildOfClass("Clouds"), profile.clouds)
	pcall(function()
		terrain.Decoration = profile.decoration
	end)
	pcall(function()
		terrain.WaterReflectance = profile.waterReflectance
		terrain.WaterWaveSize = profile.waterWaveSize
	end)
	if profile.depthOfField and not depthEffect then
		-- Yüksek kalitede uzak ufuk hafifçe odak dışı (yakın ada net kalır)
		local dof = Instance.new("DepthOfFieldEffect")
		dof.Name = "QualityDepthOfField"
		dof.FarIntensity = 0.18
		dof.FocusDistance = 140
		dof.InFocusRadius = 110
		dof.NearIntensity = 0
		dof.Parent = Lighting
		depthEffect = dof
	end
	setEnabled(depthEffect, profile.depthOfField)
end

local appliedTier: Tier? = nil
local function refresh()
	local tier = resolvedTier()
	if player:GetAttribute("EffectsQuality") ~= tier then
		player:SetAttribute("EffectsQuality", tier)
	end
	player:SetAttribute("AutoGraphicsTier", autoTier)
	if appliedTier ~= tier then
		appliedTier = tier
		applyProfile(tier)
	end
end

-- Sunucudaki kayıtlı tercih (boş metin = hiç seçilmemiş → auto) uygulanır.
local function applySaved()
	local saved = player:GetAttribute("SavedGraphics")
	if
		typeof(saved) == "string"
		and (saved == "auto" or isTier(saved))
		and player:GetAttribute("GraphicsMode") ~= saved
	then
		player:SetAttribute("GraphicsMode", saved)
	end
end

if player:GetAttribute("GraphicsMode") == nil then
	player:SetAttribute("GraphicsMode", "auto")
end
player:GetAttributeChangedSignal("SavedGraphics"):Connect(function()
	applySaved()
	refresh()
end)
player:GetAttributeChangedSignal("GraphicsMode"):Connect(refresh)
applySaved()
refresh()

-- Otomatik kademe: kare hızı 8 sn'lik pencerelerle ölçülür; arka arkaya kötü/iyi pencere kademe değiştirir.
local WINDOW_SECONDS = 8
local SETTLE_SECONDS = 15 -- Oyuna giriş ve harita yüklemesi sırasındaki düşük kare hızı sayılmaz
local BAD_FPS = 28
local GOOD_FPS = 57
local frames = 0
local windowTime = 0
local sinceStart = 0
local badWindows = 0
local goodWindows = 0
RunService.Heartbeat:Connect(function(dt: number)
	sinceStart += dt
	if sinceStart < SETTLE_SECONDS or player:GetAttribute("GraphicsMode") ~= "auto" then
		frames, windowTime, badWindows, goodWindows = 0, 0, 0, 0
		return
	end
	frames += 1
	windowTime += dt
	if windowTime < WINDOW_SECONDS then
		return
	end
	local fps = frames / windowTime
	frames, windowTime = 0, 0
	if fps < BAD_FPS then
		badWindows += 1
		goodWindows = 0
	elseif fps >= GOOD_FPS then
		goodWindows += 1
		badWindows = 0
	else
		badWindows, goodWindows = 0, 0
	end
	local index = tierIndex(autoTier)
	if badWindows >= 2 and index > 1 then
		autoTier = TIERS[index - 1]
		badWindows = 0
		refresh()
	elseif goodWindows >= 4 and index < tierIndex(deviceCeiling()) then
		autoTier = TIERS[index + 1]
		goodWindows = 0
		refresh()
	end
end)
