--!strict
-- Gün-gece döngüsü (sadece görünüm; gelire etkisi yok).
--  * Saat sunucu saatinden türetilir (Environment.getClockTime): herkes aynı saati görür.
--  * Lighting.ClockTime, ortam ışığı, atmosfer ve renk tonu geceye göre kayar; hava durumu ve mevsim
--    (WeatherEffects) bunun üstüne kendi katmanını uygular.
--  * "NightLight" (fener) ve "NightWindow" (pencere) etiketli parçalar geceleri yanar, gündüz söner.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Environment = require(Shared:WaitForChild("Modules"):WaitForChild("Environment"))

local TICK = 0.1

local DAY = {
	outdoor = Color3.fromRGB(135, 135, 150),
	ambient = Color3.fromRGB(70, 70, 80),
	atmosphere = Color3.fromRGB(199, 220, 235),
	decay = Color3.fromRGB(106, 135, 165),
}
local NIGHT = {
	outdoor = Color3.fromRGB(92, 104, 152),
	ambient = Color3.fromRGB(56, 62, 96),
	atmosphere = Color3.fromRGB(58, 72, 112),
	decay = Color3.fromRGB(28, 36, 66),
	tint = Color3.fromRGB(196, 208, 246),
}
local TWILIGHT_SHIFT = Color3.fromRGB(255, 150, 90)

-- Sadece bu client'ta var olan gece renk düzeltmesi
local nightGrade = Instance.new("ColorCorrectionEffect")
nightGrade.Name = "NightGrade"
nightGrade.Parent = Lighting

---------------------------------------------------------------------------
-- Işık kaynakları
---------------------------------------------------------------------------

type Glow = {
	part: BasePart,
	material: Enum.Material,
	color: Color3,
	nightColor: Color3,
	glowMaterial: Enum.Material,
	lit: boolean,
}
local glows: { [BasePart]: Glow } = {}
local ramp = 0
local multiplier = 1 -- Yönetici ışık parlaklığı çarpanı
-- Işıklar parçadan sonra çoğalabilir; bu yüzden her uygulamada çocuklar yeniden taranır.
-- Özgün parlaklık ilk görüldüğünde (henüz değiştirilmeden) saklanır.
local baseBrightness: { [Light]: number } = setmetatable({}, { __mode = "k" })

local function applyGlow(glow: Glow)
	local part = glow.part
	local on = ramp > 0.05
	if on ~= glow.lit then
		glow.lit = on
		part.Material = if on then glow.glowMaterial else glow.material
		part.Color = if on then glow.nightColor else glow.color
	end
	for _, child in part:GetChildren() do
		if child:IsA("Light") then
			local base = baseBrightness[child]
			if base == nil then
				base = child.Brightness
				baseBrightness[child] = base
			end
			child.Enabled = on
			child.Brightness = (base :: number) * ramp * multiplier
		end
	end
end

local function track(instance: Instance)
	if not instance:IsA("BasePart") or glows[instance] then
		return
	end
	local nightColor = instance:GetAttribute("NightColor")
	local glow: Glow = {
		part = instance,
		material = instance.Material,
		color = instance.Color,
		nightColor = if typeof(nightColor) == "Color3" then nightColor else instance.Color,
		-- Pencereler parlak renkli düz malzeme (Neon değil): büyük yüzeylerde ekranı beyaza boğan parıltıyı önler.
		glowMaterial = if CollectionService:HasTag(instance, "NightWindow")
			then Enum.Material.SmoothPlastic
			else Enum.Material.Neon,
		lit = false,
	}
	glows[instance] = glow
	applyGlow(glow)
	instance.ChildAdded:Connect(function(child: Instance)
		if child:IsA("Light") and glows[instance] then
			applyGlow(glow)
		end
	end)
end

local function untrack(instance: Instance)
	if instance:IsA("BasePart") then
		glows[instance] = nil
	end
end

for _, tag in { "NightLight", "NightWindow" } do
	CollectionService:GetInstanceAddedSignal(tag):Connect(track)
	CollectionService:GetInstanceRemovedSignal(tag):Connect(untrack)
	for _, instance in CollectionService:GetTagged(tag) do
		track(instance)
	end
end

---------------------------------------------------------------------------
-- Gökyüzü ve ortam
---------------------------------------------------------------------------

local function updateSky()
	local clock = Environment.getClockTime(Workspace:GetServerTimeNow())
	local night = Environment.getNightFactor(clock)
	Lighting.ClockTime = clock

	Lighting.OutdoorAmbient = DAY.outdoor:Lerp(NIGHT.outdoor, night)
	Lighting.Ambient = DAY.ambient:Lerp(NIGHT.ambient, night)
	-- Gün doğumu ve batımında ufka sıcak bir ton
	local twilight = math.sin(night * math.pi)
	Lighting.ColorShift_Top = Color3.new(0, 0, 0):Lerp(TWILIGHT_SHIFT, twilight * 0.55)

	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmosphere then
		atmosphere.Color = DAY.atmosphere:Lerp(NIGHT.atmosphere, night)
		atmosphere.Decay = DAY.decay:Lerp(NIGHT.decay, night)
	end
	local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
	if bloom then
		-- Gece parlama azalır: fener ve pencere çevresi beyaza boğulmasın
		bloom.Intensity = 0.5 - 0.32 * night
		bloom.Threshold = 1.8 + 1.2 * night
	end
	nightGrade.TintColor = Color3.new(1, 1, 1):Lerp(NIGHT.tint, night)
	nightGrade.Saturation = -0.08 * night
	nightGrade.Brightness = 0.01 * night

	local newRamp = Environment.getLightFactor(clock)
	-- Yönetici testi: ışıkları zorla aç/kapat ve parlaklığı ayarla
	local lightsOverride = Environment.getLightsOverride()
	if lightsOverride == "on" then
		newRamp = 1
	elseif lightsOverride == "off" then
		newRamp = 0
	end
	local newMultiplier = Environment.getLightMultiplier()
	if math.abs(newRamp - ramp) > 0.005 or (newRamp == 0) ~= (ramp == 0) or newMultiplier ~= multiplier then
		ramp = newRamp
		multiplier = newMultiplier
		for _, glow in glows do
			applyGlow(glow)
		end
	end
end

local elapsed = TICK
local resyncAt = 0
local connection = RunService.Heartbeat:Connect(function(dt: number)
	elapsed += dt
	if elapsed >= TICK then
		elapsed = 0
		updateSky()
		-- Geç gelen ışık nesneleri ve yayın gecikmeleri için birkaç saniyede bir tam eşitleme
		if os.clock() >= resyncAt then
			resyncAt = os.clock() + 3
			for _, glow in glows do
				applyGlow(glow)
			end
		end
	end
end)
updateSky()

script.Destroying:Connect(function()
	connection:Disconnect()
	nightGrade:Destroy()
end)
