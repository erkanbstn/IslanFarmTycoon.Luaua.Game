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
local ClientModelAssets = require(script.Parent.Parent:WaitForChild("Core"):WaitForChild("ClientModelAssets"))

local WATER_LEVEL = 0 -- MapBuilder.WATER_Y: deniz yüzeyi
local ENTER_MARGIN = -0.3 -- Kamera bu kadar altına inince su altı sayılır (dalga payı)
local EXIT_MARGIN = 0.3
local FADE_SPEED = 3 -- saniyede (1 = tam su altı)

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

-- Hazır su altı görünümü (client-assets/Sea/*): atmosfer (renk düzeltmesi + bulanıklık), baloncuk/sıçrama parçacık şablonları,
-- yüzme izi. Değerler modellerdedir; kod yalnızca klonlar, konumlar, Enabled/Rate/ömür ve güce göre yumuşak geçişi yönetir.
local missingWarned: { [string]: boolean } = {}
local function warnMissing(name: string)
	if not missingWarned[name] then
		missingWarned[name] = true
		warn(`[Underwater] client-assets/Sea/{name}.rbxmx bulunamadı; çizilmedi`)
	end
end

local function templateModel(name: string): Model?
	local model = ClientModelAssets.clone("Sea", name)
	if not model then
		warnMissing(name)
	end
	return model
end

-- Şablonun ilk ParticleEmitter'ının kopyası `parent`e konur (şablon yoksa nil)
local function cloneEmitter(name: string, parent: Instance): ParticleEmitter?
	local template = ClientModelAssets.find("Sea", name)
	local emitter = if template then template:FindFirstChildWhichIsA("ParticleEmitter", true) else nil
	if not emitter then
		warnMissing(name)
		return nil
	end
	local copy = emitter:Clone()
	copy.Parent = parent
	return copy
end

-- Sadece bu client'ta var olan renk düzeltmesi ve bulanıklık (DayNight/WeatherEffects kendi efektlerine dokunur)
local atmosphere = ClientModelAssets.find("Sea", "UnderwaterAtmosphere")
local gradeTemplate = if atmosphere then atmosphere:FindFirstChild("UnderwaterGrade") else nil
local blurTemplate = if atmosphere then atmosphere:FindFirstChild("UnderwaterBlur") else nil
if not (gradeTemplate and blurTemplate) then
	warnMissing("UnderwaterAtmosphere")
end
local grade: ColorCorrectionEffect = if gradeTemplate and gradeTemplate:IsA("ColorCorrectionEffect")
	then gradeTemplate:Clone()
	else Instance.new("ColorCorrectionEffect")
grade.Name = "UnderwaterGrade"
local blur: BlurEffect = if blurTemplate and blurTemplate:IsA("BlurEffect")
	then blurTemplate:Clone()
	else Instance.new("BlurEffect")
blur.Name = "UnderwaterBlur"
-- Tam güç (strength 1) değerleri şablondan okunur; güç 0..1 ile ölçeklenir
local FULL_TINT = grade.TintColor
local FULL_BRIGHTNESS, FULL_CONTRAST, FULL_SATURATION = grade.Brightness, grade.Contrast, grade.Saturation
local FULL_BLUR = blur.Size
grade.TintColor = Color3.new(1, 1, 1)
grade.Brightness, grade.Contrast, grade.Saturation = 0, 0, 0
blur.Size = 0
grade.Enabled = false
blur.Enabled = false
grade.Parent = Lighting
blur.Parent = Lighting

local folder = Instance.new("Folder")
folder.Name = "LocalUnderwater"
folder.Parent = Workspace

-- Kameranın çevresinde yükselen baloncuk hacmi (şablon: BubbleVolume parçası + "Bubbles" emitter'ı)
local ambientModel = templateModel("AmbientBubbles")
local volume: BasePart? = if ambientModel then ambientModel:FindFirstChild("BubbleVolume") :: BasePart? else nil
local ambient: ParticleEmitter? = if ambientModel
	then ambientModel:FindFirstChildWhichIsA("ParticleEmitter", true)
	else nil
if ambientModel then
	ambientModel.Parent = folder
end

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

if ambient then
	ambient.Shape = Enum.ParticleEmitterShape.Box
	ambient.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
end

-- Sıçrama: su yüzeyinde kısa, küçük damlalar (karakter girerken ve çıkarken)
local function splash(position: Vector3)
	local model = templateModel("Splash")
	local drops = if model then model:FindFirstChildWhichIsA("ParticleEmitter", true) else nil
	if not (model and drops) then
		if model then
			model:Destroy()
		end
		return
	end
	model:PivotTo(CFrame.new(position.X, WATER_LEVEL + 0.2, position.Z))
	model.Parent = folder
	drops:Emit(math.floor(budget().burst * 0.8))
	Debris:AddItem(model, 2)
end

local function bubbleBurst(head: BasePart, depth: number)
	local found = head:FindFirstChild("EntryBubbles")
	local emitter: ParticleEmitter? = if found and found:IsA("ParticleEmitter")
		then found
		else cloneEmitter("EntryBubbles", head)
	if not emitter then
		return
	end
	emitter.Enabled = true -- Enabled true, Rate 0: yalnızca Emit ile salınır
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
	local emitter = cloneEmitter("SwimBubbles", head)
	if emitter then
		emitter.Enabled = true
	end
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
local ventAnchors: { BasePart } = {}
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
		local model = templateModel("VentBubbles")
		local anchor = if model then model:FindFirstChild("VentAnchor") else nil
		local emitter = if model then model:FindFirstChildWhichIsA("ParticleEmitter", true) else nil
		if not (model and anchor and anchor:IsA("BasePart") and emitter) then
			if model then
				model:Destroy()
			end
			return
		end
		model.Parent = ventFolder
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
				ventEmitters[used].Enabled = true -- şablon kapalı gelir; kullanılan sütun açılır
				ventEmitters[used].Rate = 5
				fitLifetime(ventEmitters[used], WATER_LEVEL - hit.Position.Y - 0.3, 4, 0.8)
			end
		end
	end
	for index = used + 1, #ventEmitters do
		ventEmitters[index].Rate = 0
		ventEmitters[index].Enabled = false
	end
end

local function stopVents()
	for _, emitter in ventEmitters do
		emitter.Rate = 0
		emitter.Enabled = false
	end
end

-- Yüzme izi: yüzeyde genişleyip sönen halka (yalnızca hareket ederken, düşük kalitede yok)
local lastWake = 0
local function wake(position: Vector3)
	local model = templateModel("SurfaceWake")
	local ring = if model then model:FindFirstChild("WakeRing") else nil
	if not (model and ring and ring:IsA("BasePart")) then
		if model then
			model:Destroy()
		end
		return
	end
	model:PivotTo(CFrame.new(position.X, WATER_LEVEL + 0.12, position.Z))
	model.Parent = folder
	TweenService:Create(
		ring,
		TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = Vector3.new(0.05, 7, 7), Transparency = 1 }
	):Play()
	Debris:AddItem(model, 1.3)
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
	if ambient then
		ambient.Enabled = value
	end
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
		grade.TintColor = Color3.new(1, 1, 1):Lerp(FULL_TINT, strength)
		grade.Saturation = FULL_SATURATION * strength
		grade.Brightness = FULL_BRIGHTNESS * strength
		grade.Contrast = FULL_CONTRAST * strength
		blur.Size = FULL_BLUR * strength
	end
	if submerged and volume and ambient then
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
	if submerged and ambient then
		ambient.Rate = budget().ambient
	end
end)
