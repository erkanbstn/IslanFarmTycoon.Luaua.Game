--!strict
-- Gün-gece döngüsü (sadece görünüm; gelire etkisi yok).
--  * Saat sunucu saatinden türetilir (Environment.getClockTime): herkes aynı saati görür.
--  * Lighting.ClockTime, ortam ışığı, atmosfer ve renk tonu geceye göre kayar; hava durumu ve mevsim
--    (WeatherEffects) bunun üstüne kendi katmanını uygular.
--  * "NightLight" (fener) ve "NightWindow" (pencere) etiketli parçalar geceleri yanar, gündüz söner.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Environment = require(Shared:WaitForChild("Modules"):WaitForChild("Environment"))

local TICK = 0.1
-- Hava pozlamasına geçiş hızı (saniye); WeatherEffects'in 6 sn'lik geçişiyle aynı hissi verir.
local EXPOSURE_SMOOTHING = 2

-- Gece gerçekten kararmalı; yoksa fenerler ve pencereler ortam ışığında kaybolur.
local DAY = {
	brightness = 2.4,
	outdoor = Color3.fromRGB(135, 135, 150),
	ambient = Color3.fromRGB(70, 70, 80),
	atmosphere = Color3.fromRGB(199, 220, 235),
	decay = Color3.fromRGB(106, 135, 165),
}
local NIGHT = {
	brightness = 1.1,
	exposure = -0.2,
	outdoor = Color3.fromRGB(72, 84, 128),
	ambient = Color3.fromRGB(46, 54, 84),
	atmosphere = Color3.fromRGB(40, 52, 86),
	decay = Color3.fromRGB(18, 24, 46),
	tint = Color3.fromRGB(190, 204, 246),
}
local MAX_LIGHT_RANGE = 60 -- Roblox PointLight.Range üst sınırı
-- Tüm gece ışıklarının genel yoğunluğu. Haritadaki taban değerler place'e kayıtlı olduğundan
-- ince ayar burada yapılır (harita yeniden kurulmadan). "Normal" yönetici seviyesi = bu değerler.
local LIGHT_BRIGHTNESS_SCALE = 0.6
local LIGHT_RANGE_SCALE = 0.8
local LIGHT_FADE_SECONDS = 1
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
-- Özgün değer ışığın kendi (yerel) özniteliğinde saklanır. Zayıf anahtarlı tablo kullanılamaz:
-- Roblox Instance sarmalayıcısını toplar, gündüz 0'a çekilmiş parlaklık "özgün" diye yeniden okunur.
local function baseValue(light: Light, attribute: string, current: number): number
	local stored = light:GetAttribute(attribute)
	if typeof(stored) == "number" then
		return stored
	end
	light:SetAttribute(attribute, current)
	return current
end

local function publishCount()
	local parts, lights = 0, 0
	for part in glows do
		parts += 1
		for _, child in part:GetChildren() do
			if child:IsA("Light") then
				lights += 1
			end
		end
	end
	Lighting:SetAttribute("NightLightParts", parts)
	Lighting:SetAttribute("NightLightSources", lights)
end

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
			local base = baseValue(child, "BaseBrightness", child.Brightness)
			child.Enabled = on
			child.Brightness = base * LIGHT_BRIGHTNESS_SCALE * ramp * multiplier
			-- Parlaklık seçimi menzili de etkiler; yalnızca Brightness çarpmak gözle zor fark edilir.
			if child:IsA("PointLight") or child:IsA("SpotLight") then
				local range = baseValue(child, "BaseRange", child.Range)
				child.Range = math.min(range * LIGHT_RANGE_SCALE * (0.6 + 0.4 * multiplier), MAX_LIGHT_RANGE)
			end
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
	publishCount()
	instance.ChildAdded:Connect(function(child: Instance)
		if child:IsA("Light") and glows[instance] then
			applyGlow(glow)
			publishCount()
		end
	end)
end

local function untrack(instance: Instance)
	if instance:IsA("BasePart") and glows[instance] then
		glows[instance] = nil
		publishCount()
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

local weatherExposure: number? = nil
local firstUpdate = true

local function targetWeatherExposure(): number
	local value = Lighting:GetAttribute("WeatherExposure")
	return if typeof(value) == "number" and value == value then value else 0
end

local function updateSky(dt: number)
	local clock = Environment.getClockTime(Workspace:GetServerTimeNow())
	local night = Environment.getNightFactor(clock)
	Lighting.ClockTime = clock
	Lighting.Brightness = DAY.brightness + (NIGHT.brightness - DAY.brightness) * night

	local target = targetWeatherExposure()
	local current = weatherExposure
	if current == nil or Players.LocalPlayer:GetAttribute("ReducedMotion") == true then
		current = target
	else
		current += (target - current) * math.min(1, dt / EXPOSURE_SMOOTHING)
	end
	weatherExposure = current
	Lighting.ExposureCompensation = (current :: number) + NIGHT.exposure * night

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
		-- Neon fenerler gece hafif bir hale alsın ama çevresi beyaza boğulmasın.
		bloom.Intensity = 0.5 - 0.15 * night
		bloom.Threshold = 1.8 + 0.6 * night
	end
	nightGrade.TintColor = Color3.new(1, 1, 1):Lerp(NIGHT.tint, night)
	nightGrade.Saturation = -0.08 * night
	nightGrade.Brightness = 0.01 * night

	local targetRamp = Environment.getLightFactor(clock)
	-- Yönetici testi: ışıkları zorla aç/kapat ve parlaklığı ayarla
	local lightsOverride = Environment.getLightsOverride()
	if lightsOverride == "on" then
		targetRamp = 1
	elseif lightsOverride == "off" then
		targetRamp = 0
	end
	-- Işıklar aniden çakmasın: oyuna girişte ve ani değişimlerde ~1 sn'de yumuşakça açılır/kısılır.
	local newRamp = targetRamp
	if
		not firstUpdate
		and math.abs(targetRamp - ramp) > 0.01
		and Players.LocalPlayer:GetAttribute("ReducedMotion") ~= true
	then
		newRamp = ramp + (targetRamp - ramp) * math.min(1, dt / LIGHT_FADE_SECONDS)
	end
	local newMultiplier = Environment.getLightMultiplier()
	if math.abs(newRamp - ramp) > 0.005 or (newRamp == 0) ~= (ramp == 0) or newMultiplier ~= multiplier then
		ramp = newRamp
		multiplier = newMultiplier
		for _, glow in glows do
			applyGlow(glow)
		end
		-- Yönetici panelindeki teşhis satırı için (yalnızca bu client)
		Lighting:SetAttribute("NightLightRamp", math.round(ramp * 100))
	end
end

local elapsed = TICK
local resyncAt = 0
local connection = RunService.Heartbeat:Connect(function(dt: number)
	elapsed += dt
	if elapsed >= TICK then
		local step = elapsed
		elapsed = 0
		updateSky(step)
		-- Geç gelen ışık nesneleri ve yayın gecikmeleri için birkaç saniyede bir tam eşitleme
		if os.clock() >= resyncAt then
			resyncAt = os.clock() + 3
			for _, glow in glows do
				applyGlow(glow)
			end
		end
	end
end)
updateSky(TICK)
firstUpdate = false
-- Gündüz-gece ışığı ilk kez doğru kuruldu: yükleme ekranı kalkınca sahne karanlıkta kalmaz.
Lighting:SetAttribute("DayNightReady", true)

script.Destroying:Connect(function()
	connection:Disconnect()
	nightGrade:Destroy()
end)
