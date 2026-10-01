--!strict
-- Hayvan altı mevsim/hava göstergesi (sadece görsel, sadece bu oyuncunun ekranında): gelir çarpanı artıya geçen
-- hayvanın altından yukarı süzülen, kuzey ışığı gibi çok soluk yeşilimsi parıltı (eksiye düşende kırmızımsı); nötr hayvanda hiçbir şey.
-- Sinyal `FarmMath.getSeasonEffect` ile hesaplanır (Mevsim çubuğu ile aynı hesap) ve OLAY tabanlıdır:
-- mevsim/hava/bölge uyumu/hayvan listesi değişince yeniden hesaplanır. Zamanlayıcı yalnızca mesafe seçer.
-- Yalnızca kameraya yakın, en yakın N hayvanda küçük bir havuzdaki ParticleEmitter'lar çalışır; ReducedMotion'da akış yok.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local FarmMath = require(Shared:WaitForChild("Modules"):WaitForChild("FarmMath"))
local Environment = require(Shared:WaitForChild("Modules"):WaitForChild("Environment"))
local UiTheme = require(Shared:WaitForChild("UiTheme"))
local Core = script.Parent.Parent:WaitForChild("Core")
local ClientState = require(Core:WaitForChild("ClientState"))
local EffectSettings = require(Core:WaitForChild("EffectSettings"))
local StartupGate = require(Core:WaitForChild("StartupGate"))

local Color = UiTheme.Color

-- Kalite başına: en fazla kaç hayvanda ve hangi uzaklığa kadar gösterilir.
local QUALITY = {
	low = { distance = 38, maxMarkers = 6 },
	medium = { distance = 60, maxMarkers = 12 },
	high = { distance = 75, maxMarkers = 20 },
}
local SELECT_INTERVAL = 0.5 -- mesafe seçimi (olay tabanlı sinyalden ayrı, seyrek)
local FOLLOW_INTERVAL = 1 / 20 -- ışıltı hayvanı bu aralıkla izler
local FACING_LIMIT = -0.3 -- kameranın tamamen arkasındaki hayvan seçilmez (bakış yönü ile nokta çarpımı)
local GLOW_MIN, GLOW_MAX = 2.5, 7 -- ışıltının yayıldığı taban çapı (stud)
local AURORA_UP = Color3.fromRGB(150, 255, 205) -- kuzey ışığı: yeşilden açık turkuaza yükselir
local AURORA_UP_BAD = Color3.fromRGB(255, 170, 150)

type Marker = {
	part: Part,
	emitter: ParticleEmitter,
	model: Model?,
	anchor: BasePart?,
	yOffset: number,
	phase: number,
}

local signals: { [Model]: number } = {} -- model -> -1 / 0 / +1 (yalnızca sıfırdan farklılar tutulur)
local tracked: { [Model]: boolean } = {}
local assigned: { [Model]: Marker } = {}
local active: { Marker } = {}
local free: { Marker } = {}

local ringFolder = Instance.new("Folder")
ringFolder.Name = "SeasonRings" -- yalnızca bu istemcide var
ringFolder.Parent = Workspace

local function createMarker(): Marker
	-- Görünmez ince bir kutu: üstündeki ParticleEmitter hayvanın altından yukarı doğru yavaşça süzülen, kuzey ışığı gibi hafif parıltılar çıkarır
	local part = Instance.new("Part")
	part.Name = "SeasonAurora"
	part.Size = Vector3.new(GLOW_MIN, 0.2, GLOW_MIN)
	part.Transparency = 1
	part.Anchored = true
	part.CanCollide, part.CanTouch, part.CanQuery, part.CastShadow = false, false, false, false
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	emitter.Orientation = Enum.ParticleOrientation.VelocityParallel
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.SpreadAngle = Vector2.new(6, 6)
	emitter.Lifetime = NumberRange.new(2.2, 3.4)
	emitter.Speed = NumberRange.new(0.8, 1.5)
	emitter.LightEmission = 1
	emitter.LightInfluence = 0
	emitter.Rotation = NumberRange.new(0, 0)
	emitter.RotSpeed = NumberRange.new(0, 0)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.5),
		NumberSequenceKeypoint.new(0.5, 1.3),
		NumberSequenceKeypoint.new(1, 0.4),
	})
	-- Çok soluk: en yoğun anda bile belli belirsiz (belli etmeden fark edilsin)
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.25, 0.82),
		NumberSequenceKeypoint.new(0.7, 0.9),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Rate = 0
	emitter.Enabled = false
	emitter.Parent = part
	part.Parent = ringFolder
	return { part = part, emitter = emitter, model = nil, anchor = nil, yOffset = 0, phase = 0 }
end

local function anchorOf(model: Model): BasePart?
	return model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
end

local function place(marker: Marker)
	local anchor = marker.anchor
	if anchor then
		marker.part.CFrame = CFrame.new(anchor.Position.X, anchor.Position.Y + marker.yOffset, anchor.Position.Z)
	end
end

-- Hayvanın altından yukarı süzülen hafif parıltı: artıda yeşilimsi, eksiye düşende kırmızımsı (ok/ikon/halka yok)
local function style(marker: Marker, signal: number, model: Model, anchor: BasePart)
	local good = signal > 0
	local base = if good then Color.Green else Color.Red
	marker.emitter.Color = ColorSequence.new(base, if good then AURORA_UP else AURORA_UP_BAD)
	local boxCf, boxSize = model:GetBoundingBox()
	local diameter = math.clamp(math.max(boxSize.X, boxSize.Z) * 0.9, GLOW_MIN, GLOW_MAX)
	marker.part.Size = Vector3.new(diameter, 0.2, diameter)
	marker.emitter.Rate = 3 + diameter * 0.8
	-- Hareketi azalt: akış yok, yalnızca zeminde çok soluk bir iz
	local still = EffectSettings.reducedMotion()
	marker.emitter.Enabled = not still
	marker.part.Transparency = if still then 0.93 else 1
	marker.part.Color = base
	marker.part.Material = Enum.Material.Neon
	marker.yOffset = boxCf.Position.Y - boxSize.Y / 2 - anchor.Position.Y + 0.1
	marker.anchor = anchor
	marker.model = model
	marker.phase = 0
	place(marker)
end

local function release(model: Model)
	local marker = assigned[model]
	if not marker then
		return
	end
	assigned[model] = nil
	marker.part.Transparency = 1
	marker.emitter.Enabled = false
	marker.anchor = nil
	marker.model = nil
	local index = table.find(active, marker)
	if index then
		table.remove(active, index)
	end
	table.insert(free, marker)
end

local function compute(model: Model): number
	local state = ClientState.get()
	local uid = model:GetAttribute("Uid")
	if not state or typeof(uid) ~= "string" then
		return 0
	end
	for _, animal in state.animals do
		if animal.uid == uid then
			return FarmMath.getSeasonEffect(state, animal.animalId, animal.zoneId).signal
		end
	end
	return 0
end

local function setSignal(model: Model, signal: number)
	if signal ~= 0 then
		signals[model] = signal
	else
		signals[model] = nil
	end
end

local function recomputeAll()
	for model in tracked do
		local signal = compute(model)
		setSignal(model, signal)
		-- Sinyal değiştiyse (yön ya da kayboldu) mevcut işareti bırak; seçim turu yeniden atar
		local marker = assigned[model]
		if marker and signals[model] == nil then
			release(model)
		elseif marker then
			local anchor = anchorOf(model)
			if anchor then
				style(marker, signal, model, anchor)
			end
		end
	end
end

local ranked: { { model: Model, distance: number } } = {}
local function pickMarkers()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local quality = QUALITY[EffectSettings.quality()] or QUALITY.medium
	local cameraPos, look = camera.CFrame.Position, camera.CFrame.LookVector
	table.clear(ranked)
	for model, signal in signals do
		local anchor = if model.Parent then anchorOf(model) else nil
		if not anchor or signal == 0 or model:GetAttribute("BuildPopActive") == true then
			continue
		end
		local offset = anchor.Position - cameraPos
		local distance = offset.Magnitude
		if distance <= quality.distance and (distance < 6 or offset.Unit:Dot(look) > FACING_LIMIT) then
			table.insert(ranked, { model = model, distance = distance })
		end
	end
	table.sort(ranked, function(a, b)
		return a.distance < b.distance
	end)
	local wanted: { [Model]: boolean } = {}
	for index = 1, math.min(#ranked, quality.maxMarkers) do
		wanted[ranked[index].model] = true
	end
	for model in assigned do
		if not wanted[model] then
			release(model)
		end
	end
	for model in wanted do
		if not assigned[model] then
			local marker = table.remove(free) or createMarker()
			local anchor = anchorOf(model)
			if anchor then
				assigned[model] = marker
				table.insert(active, marker)
				style(marker, signals[model] or 0, model, anchor)
			else
				table.insert(free, marker)
			end
		end
	end
end

-- Hayvan görselleri: etiket eklenince/çıkınca izle (StreamingEnabled parçaları sonradan getirir/kaldırır)
local function onAdded(instance: Instance)
	if not instance:IsA("Model") then
		return
	end
	local model = instance
	tracked[model] = true
	local signal = compute(model)
	setSignal(model, signal)
end
local function onRemoved(instance: Instance)
	if instance:IsA("Model") then
		release(instance)
		tracked[instance] = nil
		signals[instance] = nil
	end
end

task.spawn(function()
	StartupGate.wait(2)
	CollectionService:GetInstanceAddedSignal("Animal"):Connect(onAdded)
	CollectionService:GetInstanceRemovedSignal("Animal"):Connect(onRemoved)
	for _, instance in CollectionService:GetTagged("Animal") do
		onAdded(instance)
	end
	ClientState.onChanged(function(_state, structural)
		if structural then
			recomputeAll()
			pickMarkers()
		end
	end)
	Environment.onChanged(function()
		recomputeAll()
		pickMarkers()
	end)

	local selectElapsed, pulseElapsed = 0, 0
	RunService.Heartbeat:Connect(function(dt: number)
		selectElapsed += dt
		if selectElapsed >= SELECT_INTERVAL then
			selectElapsed = 0
			pickMarkers()
		end
		if #active == 0 then
			return
		end
		pulseElapsed += dt
		if pulseElapsed < FOLLOW_INTERVAL then
			return
		end
		pulseElapsed = 0
		for _, marker in active do
			place(marker) -- hayvan yürürken ışıltı onu izler
		end
	end)
end)
