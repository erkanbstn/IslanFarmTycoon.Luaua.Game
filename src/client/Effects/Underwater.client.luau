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
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

local WATER_LEVEL = 0 -- MapBuilder.WATER_Y: deniz yüzeyi
local ENTER_MARGIN = -0.3 -- Kamera bu kadar altına inince su altı sayılır (dalga payı)
local EXIT_MARGIN = 0.3
local FADE_SPEED = 3 -- saniyede (1 = tam su altı)
local BUBBLE_TEXTURE = "rbxasset://textures/smallWhiteCircle.png"

local WATER_TINT = Color3.fromRGB(185, 238, 246)
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

-- Baloncuğun yaşam süresi su yüzeyine kalan mesafeye sığdırılır (s = v*t + a*t^2/2 denkleminden): baloncuk suyun dışına çıkmaz.
local function lifetimeToSurface(depth: number, speed: number, acceleration: number): number
	if depth <= 0.1 then
		return 0.05
	end
	local half = acceleration / 2
	local seconds = if half > 0
		then (-speed + math.sqrt(speed * speed + 4 * half * depth)) / (2 * half)
		else depth / speed
	return math.max(seconds, 0.05)
end

local function fitLifetime(emitter: ParticleEmitter, depth: number, speed: number, acceleration: number)
	local seconds = lifetimeToSurface(depth, speed, acceleration)
	emitter.Lifetime = NumberRange.new(seconds * 0.6, seconds)
end

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

local function bubbleBurst(head: BasePart, depth: number)
	local found = head:FindFirstChild("EntryBubbles")
	local emitter: ParticleEmitter
	if found and found:IsA("ParticleEmitter") then
		emitter = found
	else
		emitter = newBubbleEmitter(head)
		emitter.Name = "EntryBubbles"
		emitter.Speed = NumberRange.new(1.5, 2.5)
		emitter.SpreadAngle = Vector2.new(25, 25)
		emitter.Acceleration = Vector3.zero
		emitter.Enabled = true -- Enabled true, Rate 0: yalnızca Emit ile salınır
	end
	fitLifetime(emitter, depth - 0.2, 2, 0)
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
	emitter.Speed = NumberRange.new(1.2, 1.8)
	emitter.Acceleration = Vector3.zero
	emitter.Enabled = true
	return emitter
end

-- Dipte sabit baloncuk sütunları: kameranın çevresindeki hücrelerden (40 stud) deterministik olarak seçilir; her sütun
-- gerçek deniz tabanına ışınla oturtulur (ada gövdesinin içinde çıkmaz). Havuz küçük ve kaliteye bağlıdır.
local VENT_CELL = 40
local VENT_RADIUS = 70
local VENT_POOL = { low = 2, medium = 4, high = 6 }
local ventFolder = Instance.new("Folder")
ventFolder.Name = "Vents"
ventFolder.Parent = folder
local ventEmitters: { ParticleEmitter } = {}
local ventAnchors: { Part } = {}
local floorParams = RaycastParams.new()
floorParams.FilterType = Enum.RaycastFilterType.Exclude
floorParams.IgnoreWater = true
floorParams.FilterDescendantsInstances = { folder }

local function ventPool(): number
	local quality = player:GetAttribute("EffectsQuality")
	return if quality == "low" then VENT_POOL.low elseif quality == "high" then VENT_POOL.high else VENT_POOL.medium
end

local function ensureVents(count: number)
	while #ventEmitters < count do
		local anchor = Instance.new("Part")
		anchor.Name = "VentAnchor"
		anchor.Anchored = true
		anchor.CanCollide, anchor.CanTouch, anchor.CanQuery = false, false, false
		anchor.CastShadow = false
		anchor.Transparency = 1
		anchor.Size = Vector3.one
		anchor.Parent = ventFolder
		local emitter = newBubbleEmitter(anchor)
		emitter.Name = "VentBubbles"
		emitter.Speed = NumberRange.new(3, 5)
		emitter.SpreadAngle = Vector2.new(5, 5)
		emitter.Lifetime = NumberRange.new(3, 4.5)
		emitter.Acceleration = Vector3.new(0, 0.8, 0)
		table.insert(ventEmitters, emitter)
		table.insert(ventAnchors, anchor)
	end
end

local function ventHash(cx: number, cz: number): number
	local h = (cx * 73856093 + cz * 19349663) % 2147483647
	return (h * 48271) % 2147483647
end

local function refreshVents(cameraPosition: Vector3)
	local count = ventPool()
	ensureVents(count)
	local used = 0
	local baseX = math.floor(cameraPosition.X / VENT_CELL)
	local baseZ = math.floor(cameraPosition.Z / VENT_CELL)
	for dx = -2, 2 do
		for dz = -2, 2 do
			if used >= count then
				break
			end
			local cx, cz = baseX + dx, baseZ + dz
			local hash = ventHash(cx, cz)
			if hash % 5 ~= 0 then
				continue
			end
			local x = (cx + (hash % 97) / 97) * VENT_CELL
			local z = (cz + ((hash // 97) % 89) / 89) * VENT_CELL
			if (Vector3.new(x, cameraPosition.Y, z) - cameraPosition).Magnitude > VENT_RADIUS then
				continue
			end
			local hit = Workspace:Raycast(Vector3.new(x, WATER_LEVEL - 1, z), Vector3.new(0, -60, 0), floorParams)
			-- Yalnızca derin taban (ada gövdesi ve sığ kıyı değil)
			if hit and hit.Position.Y < WATER_LEVEL - 6 then
				used += 1
				ventAnchors[used].Position = hit.Position + Vector3.new(0, 0.3, 0)
				ventEmitters[used].Rate = 5
				fitLifetime(ventEmitters[used], WATER_LEVEL - hit.Position.Y - 0.3, 4, 0.8)
			end
		end
	end
	for index = used + 1, #ventEmitters do
		ventEmitters[index].Rate = 0
	end
end

local function stopVents()
	for _, emitter in ventEmitters do
		emitter.Rate = 0
	end
end

-- Yüzme izi: yüzeyde genişleyip sönen halka (yalnızca hareket ederken, düşük kalitede yok)
local lastWake = 0
local function wake(position: Vector3)
	local ring = Instance.new("Part")
	ring.Name = "WakeRing"
	ring.Shape = Enum.PartType.Cylinder
	ring.Anchored = true
	ring.CanCollide, ring.CanTouch, ring.CanQuery = false, false, false
	ring.CastShadow = false
	ring.Material = Enum.Material.SmoothPlastic
	ring.Color = Color3.fromRGB(225, 242, 255)
	ring.Transparency = 0.55
	ring.Size = Vector3.new(0.05, 1.5, 1.5)
	ring.CFrame = CFrame.new(position.X, WATER_LEVEL + 0.12, position.Z) * CFrame.Angles(0, 0, math.rad(90))
	ring.Parent = folder
	TweenService:Create(
		ring,
		TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = Vector3.new(0.05, 7, 7), Transparency = 1 }
	):Play()
	Debris:AddItem(ring, 1.3)
end

local strength = 0 -- 0 = su üstü, 1 = tam su altı (yumuşak geçiş)
local submerged = false
local wasInWater = false
local wasHeadUnder = false
local elapsed = 0
local ventElapsed = 0
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

local gradeShown = false
RunService.RenderStepped:Connect(function(dt: number)
	-- Su üstünde ve geçiş bittiyse kare başına hiçbir iş yapma.
	if not submerged and strength == 0 and not gradeShown then
		return
	end
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
	if active ~= gradeShown then
		gradeShown = active
		grade.Enabled = active
		blur.Enabled = active
	end
	if active then
		grade.TintColor = Color3.new(1, 1, 1):Lerp(WATER_TINT, strength * 0.55)
		grade.Saturation = 0.08 * strength
		grade.Brightness = 0.06 * strength
		grade.Contrast = 0.025 * strength
		blur.Size = 1.3 * strength
	end
	if submerged then
		volume.CFrame = CFrame.new(position.X, position.Y - 2, position.Z)
		local depth = WATER_LEVEL - (position.Y - 2)
		-- Kamera yüzeye çok yakınken baloncuk çıkmaz; aksi halde yüzeyde biter
		ambient.Rate = if depth > 0.6 then budget().ambient else 0
		if depth > 0.6 then
			fitLifetime(ambient, depth, 2.25, 1.2)
		end
	end
end)

RunService.Heartbeat:Connect(function(dt: number)
	elapsed += dt
	if elapsed < 0.1 then
		return
	end
	local step = elapsed
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
	local cameraNow = Workspace.CurrentCamera
	ventElapsed += step
	if submerged and cameraNow then
		if ventElapsed >= 1 then
			ventElapsed = 0
			refreshVents(cameraNow.CFrame.Position)
		end
	elseif #ventEmitters > 0 and ventElapsed >= 1 then
		ventElapsed = 0
		stopVents()
	end
	-- Karakter: suya giriş/çıkış sıçraması ve yüzerken baş baloncukları
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if character and root and root:IsA("BasePart") then
		local inWater = root.Position.Y < WATER_LEVEL + 1.2
		if inWater ~= wasInWater then
			wasInWater = inWater
			splash(root.Position)
		end
		-- Baloncuklar yalnızca baş su yüzeyinin altındayken çıkar ve yüzeye varınca biter
		local head = character:FindFirstChild("Head")
		local headDepth = if head and head:IsA("BasePart") then WATER_LEVEL - head.Position.Y else -1
		local headUnder = headDepth > 0.4
		if headUnder ~= wasHeadUnder then
			wasHeadUnder = headUnder
			if headUnder and head and head:IsA("BasePart") then
				bubbleBurst(head, headDepth)
			end
		end
		local emitter = swimEmitter(character)
		if emitter then
			if headUnder then
				fitLifetime(emitter, headDepth - 0.2, 1.5, 0)
			end
			emitter.Rate = if headUnder then budget().swim else 0
		end
		if
			inWater
			and player:GetAttribute("EffectsQuality") ~= "low"
			and not reduced()
			and root.AssemblyLinearVelocity.Magnitude > 3
			and os.clock() - lastWake > 0.55
		then
			lastWake = os.clock()
			wake(root.Position)
		end
	else
		wasInWater = false
		wasHeadUnder = false
	end
end)

player:GetAttributeChangedSignal("EffectsQuality"):Connect(function()
	if submerged then
		ambient.Rate = budget().ambient
	end
end)
