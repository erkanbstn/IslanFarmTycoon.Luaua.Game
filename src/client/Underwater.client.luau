--!strict
-- Su altı atmosferi: kamera su yüzeyinin altına inince (yüzerken ya da kamerayla dibe bakarken) ekran mavi-yeşile döner,
-- hafif bulanıklaşır, ses boğuklaşır, etrafta baloncuklar yükselir ve yağış kesilir (WeatherPrecip "Submerged"a bakar).
-- Suya giren/çıkan karakter küçük bir sıçrama ve baloncuk patlaması bırakır; yüzerken başından baloncuk çıkar.
-- Efekt sayıları EffectsQuality'ye, hareket ReducedMotion'a uyar.

local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

local WATER_LEVEL = 0 -- MapBuilder.WATER_Y: deniz yüzeyi
local ENTER_MARGIN = -0.3 -- Kamera bu kadar altına inince su altı sayılır (dalga payı)
local EXIT_MARGIN = 0.3
local FADE_SPEED = 3 -- saniyede (1 = tam su altı)
local BUBBLE_TEXTURE = "rbxasset://textures/smallWhiteCircle.png"

local WATER_TINT = Color3.fromRGB(150, 226, 240)
local BUBBLES = {
	low = { ambient = 4, burst = 6, swim = 3 },
	medium = { ambient = 10, burst = 14, swim = 6 },
	high = { ambient = 18, burst = 24, swim = 9 },
}

local function budget(): { ambient: number, burst: number, swim: number }
	local quality = player:GetAttribute("EffectsQuality")
	local entry = if quality == "low" then BUBBLES.low elseif quality == "high" then BUBBLES.high else BUBBLES.medium
	if player:GetAttribute("ReducedMotion") == true then
		return { ambient = entry.ambient / 2, burst = entry.burst / 2, swim = entry.swim / 2 }
	end
	return entry
end

local function reduced(): boolean
	return player:GetAttribute("ReducedMotion") == true
end

-- Sadece bu client'ta var olan renk düzeltmesi ve bulanıklık (DayNight/WeatherEffects kendi efektlerine dokunur)
local grade = Instance.new("ColorCorrectionEffect")
grade.Name = "UnderwaterGrade"
grade.Enabled = false
grade.Parent = Lighting
local blur = Instance.new("BlurEffect")
blur.Name = "UnderwaterBlur"
blur.Size = 0
blur.Enabled = false
blur.Parent = Lighting

local folder = Instance.new("Folder")
folder.Name = "LocalUnderwater"
folder.Parent = Workspace

-- Kameranın çevresinde yükselen baloncuk hacmi
local volume = Instance.new("Part")
volume.Name = "BubbleVolume"
volume.Anchored = true
volume.CanCollide, volume.CanTouch, volume.CanQuery = false, false, false
volume.CastShadow = false
volume.Transparency = 1
volume.Size = Vector3.new(30, 1, 30)
volume.Parent = folder

local function newBubbleEmitter(parent: Instance): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Bubbles"
	emitter.Texture = BUBBLE_TEXTURE
	emitter.Orientation = Enum.ParticleOrientation.FacingCamera
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Speed = NumberRange.new(1.5, 3)
	emitter.SpreadAngle = Vector2.new(12, 12)
	emitter.Acceleration = Vector3.new(0, 1.2, 0)
	emitter.Lifetime = NumberRange.new(3, 5)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.12, 0.05),
		NumberSequenceKeypoint.new(1, 0.3, 0.12),
	})
	emitter.Color = ColorSequence.new(Color3.fromRGB(200, 235, 255))
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.12, 0.55),
		NumberSequenceKeypoint.new(0.8, 0.7),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.LightEmission = 0.35
	emitter.LightInfluence = 0.3
	emitter.Rate = 0
	emitter.Enabled = false
	emitter.Parent = parent
	return emitter
end

local ambient = newBubbleEmitter(volume)
ambient.Shape = Enum.ParticleEmitterShape.Box
ambient.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
ambient.Lifetime = NumberRange.new(5, 8)

-- Sıçrama: su yüzeyinde kısa, küçük damlalar (karakter girerken ve çıkarken)
local function splash(position: Vector3)
	local anchor = Instance.new("Part")
	anchor.Name = "Splash"
	anchor.Anchored = true
	anchor.CanCollide, anchor.CanTouch, anchor.CanQuery = false, false, false
	anchor.CastShadow = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.Position = Vector3.new(position.X, WATER_LEVEL + 0.2, position.Z)
	anchor.Parent = folder
	local drops = Instance.new("ParticleEmitter")
	drops.Texture = BUBBLE_TEXTURE
	drops.Orientation = Enum.ParticleOrientation.FacingCamera
	drops.EmissionDirection = Enum.NormalId.Top
	drops.Speed = NumberRange.new(8, 14)
	drops.SpreadAngle = Vector2.new(35, 35)
	drops.Acceleration = Vector3.new(0, -38, 0)
	drops.Lifetime = NumberRange.new(0.6, 0.9)
	drops.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0.08) })
	drops.Color = ColorSequence.new(Color3.fromRGB(225, 242, 255))
	drops.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	drops.LightEmission = 0.2
	drops.Rate = 0
	drops.Parent = anchor
	drops:Emit(math.floor(budget().burst * 0.8))
	Debris:AddItem(anchor, 2)
end

local function bubbleBurst(root: BasePart)
	local found = root:FindFirstChild("EntryBubbles")
	local emitter: ParticleEmitter
	if found and found:IsA("ParticleEmitter") then
		emitter = found
	else
		emitter = newBubbleEmitter(root)
		emitter.Name = "EntryBubbles"
		emitter.Speed = NumberRange.new(2, 5)
		emitter.SpreadAngle = Vector2.new(40, 40)
		emitter.Enabled = true -- Enabled true, Rate 0: yalnızca Emit ile salınır
	end
	emitter:Emit(budget().burst)
end

local function swimEmitter(character: Model): ParticleEmitter?
	local head = character:FindFirstChild("Head")
	if not (head and head:IsA("BasePart")) then
		return nil
	end
	local existing = head:FindFirstChild("SwimBubbles")
	if existing and existing:IsA("ParticleEmitter") then
		return existing
	end
	local emitter = newBubbleEmitter(head)
	emitter.Name = "SwimBubbles"
	emitter.Speed = NumberRange.new(1, 2)
	emitter.Lifetime = NumberRange.new(1.5, 2.5)
	emitter.Enabled = true
	return emitter
end

local strength = 0 -- 0 = su üstü, 1 = tam su altı (yumuşak geçiş)
local submerged = false
local wasInWater = false
local elapsed = 0
local savedReverb: Enum.ReverbType = SoundService.AmbientReverb

local function setSubmerged(value: boolean)
	submerged = value
	player:SetAttribute("Submerged", value)
	if value then
		savedReverb = if SoundService.AmbientReverb == Enum.ReverbType.UnderWater
			then Enum.ReverbType.NoReverb
			else SoundService.AmbientReverb
		SoundService.AmbientReverb = Enum.ReverbType.UnderWater
	else
		SoundService.AmbientReverb = savedReverb
	end
	ambient.Enabled = value
end

RunService.RenderStepped:Connect(function(dt: number)
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local position = camera.CFrame.Position
	-- Yumuşak geçiş (hareket azaltmada anında)
	local target = if submerged then 1 else 0
	if reduced() then
		strength = target
	else
		strength += math.clamp(target - strength, -FADE_SPEED * dt, FADE_SPEED * dt)
	end
	local active = strength > 0.01
	grade.Enabled = active
	blur.Enabled = active
	if active then
		grade.TintColor = Color3.new(1, 1, 1):Lerp(WATER_TINT, strength * 0.85)
		grade.Saturation = 0.12 * strength
		grade.Brightness = -0.05 * strength
		grade.Contrast = 0.06 * strength
		blur.Size = 3 * strength
	end
	if submerged then
		volume.CFrame = CFrame.new(position.X, position.Y - 2, position.Z)
		ambient.Rate = budget().ambient
	end
end)

RunService.Heartbeat:Connect(function(dt: number)
	elapsed += dt
	if elapsed < 0.1 then
		return
	end
	elapsed = 0
	local camera = Workspace.CurrentCamera
	if camera then
		local y = camera.CFrame.Position.Y
		if not submerged and y < WATER_LEVEL + ENTER_MARGIN then
			setSubmerged(true)
		elseif submerged and y > WATER_LEVEL + EXIT_MARGIN then
			setSubmerged(false)
		end
	end
	-- Karakter: suya giriş/çıkış sıçraması ve yüzerken baş baloncukları
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if character and root and root:IsA("BasePart") then
		local inWater = root.Position.Y < WATER_LEVEL + 1.2
		if inWater ~= wasInWater then
			wasInWater = inWater
			splash(root.Position)
			if inWater then
				bubbleBurst(root)
			end
		end
		local emitter = swimEmitter(character)
		if emitter then
			emitter.Rate = if inWater then budget().swim else 0
		end
	else
		wasInWater = false
	end
end)

player:GetAttributeChangedSignal("EffectsQuality"):Connect(function()
	if submerged then
		ambient.Rate = budget().ambient
	end
end)
