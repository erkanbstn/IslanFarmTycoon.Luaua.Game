--!strict
-- Hayvan altı mevsim/hava göstergesi (sadece görsel, sadece bu oyuncunun ekranında): gelir çarpanı artıya geçen
-- hayvanın üstüne binen, yukarı eriyen çok soluk yeşilimsi ışık sütunu (kuzey ışığı gibi; eksiye düşende kırmızımsı); nötr hayvanda hiçbir şey.
-- Sinyal `FarmMath.getSeasonEffect` ile hesaplanır (Mevsim çubuğu ile aynı hesap) ve OLAY tabanlıdır:
-- mevsim/hava/bölge uyumu/hayvan listesi değişince yeniden hesaplanır. Zamanlayıcı yalnızca mesafe seçer.
-- Yalnızca kameraya yakın, en yakın N hayvanda küçük bir havuzdaki BillboardGui sütunları gösterilir; ReducedMotion'da dalgalanma yok.

local Players = game:GetService("Players")
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
local FOLLOW_INTERVAL = 1 / 15
local SHIMMER_SPEED = 1.1
local FACING_LIMIT = -0.3 -- kameranın tamamen arkasındaki hayvan seçilmez (bakış yönü ile nokta çarpımı)
local AURORA_UP = Color3.fromRGB(150, 255, 205) -- kuzey ışığı: yeşilden açık turkuaza yükselir
local AURORA_UP_BAD = Color3.fromRGB(255, 170, 150)

type Marker = {
	gui: BillboardGui,
	glow: Frame,
	gradient: UIGradient,
	model: Model?,
	phase: number,
}

local signals: { [Model]: number } = {} -- model -> -1 / 0 / +1 (yalnızca sıfırdan farklılar tutulur)
local tracked: { [Model]: boolean } = {}
local assigned: { [Model]: Marker } = {}
local active: { Marker } = {}
local free: { Marker } = {}

local player = Players.LocalPlayer

local function createMarker(): Marker
	-- Hayvanın üstüne binen, kameraya dönük tek bir yumuşak ışık sütunu: altı hafif parlak, yukarı doğru eriyip kaybolur (parçacık/halka yok)
	local gui = Instance.new("BillboardGui")
	gui.Name = "SeasonGlow"
	gui.Size = UDim2.fromOffset(120, 150)
	gui.LightInfluence = 0
	gui.ResetOnSpawn = false
	gui.Active = false
	gui.Enabled = false
	gui.AlwaysOnTop = false
	gui.StudsOffsetWorldSpace = Vector3.new(0, 1.2, 0)
	gui.Parent = player:WaitForChild("PlayerGui")
	local glow = Instance.new("Frame")
	glow.Name = "Glow"
	glow.AnchorPoint = Vector2.new(0.5, 1)
	glow.Position = UDim2.fromScale(0.5, 1)
	glow.Size = UDim2.fromScale(1, 1)
	glow.BorderSizePixel = 0
	glow.BackgroundColor3 = Color.Green
	glow.BackgroundTransparency = 0
	glow.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = glow
	-- Dikey saydamlık geçişi: dipte belli belirsiz, tepede tamamen saydam
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.35, 0.86),
		NumberSequenceKeypoint.new(0.75, 0.94),
		NumberSequenceKeypoint.new(1, 1),
	})
	gradient.Parent = glow
	return { gui = gui, glow = glow, gradient = gradient, model = nil, phase = 0 }
end

local function anchorOf(model: Model): BasePart?
	return model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
end

-- Hayvanın üstünde çok soluk, yukarı eriyen ışık sütunu: artıda yeşilimsi, eksiye düşende kırmızımsı (ok/ikon/halka/parçacık yok)
local function style(marker: Marker, signal: number, model: Model, anchor: BasePart)
	local good = signal > 0
	marker.glow.BackgroundColor3 = if good then Color.Green else Color.Red
	marker.gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, if good then Color.Green else Color.Red),
		ColorSequenceKeypoint.new(1, if good then AURORA_UP else AURORA_UP_BAD),
	})
	local _, boxSize = model:GetBoundingBox()
	local depth = model:GetAttribute("SwimDepthOffset")
	-- Dipte ayakların hizası (balıkta su altı payı dahil), sütun hayvanın boyundan biraz uzun
	local width = math.clamp(boxSize.X * 18, 70, 150)
	marker.gui.Size = UDim2.fromOffset(width, math.clamp(boxSize.Y * 38 + 60, 90, 190))
	marker.gui.StudsOffsetWorldSpace =
		Vector3.new(0, -boxSize.Y / 2 + (if typeof(depth) == "number" then depth else 0), 0)
	marker.gui.Adornee = anchor
	marker.gui.Enabled = true
	marker.model = model
	marker.phase = (model:GetAttribute("Uid") and #tostring(model:GetAttribute("Uid")) or 0) * 0.7
end

local function release(model: Model)
	local marker = assigned[model]
	if not marker then
		return
	end
	assigned[model] = nil
	marker.gui.Enabled = false
	marker.gui.Adornee = nil :: any
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

	local selectElapsed, pulseElapsed, clock = 0, 0, 0
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
		clock += pulseElapsed
		pulseElapsed = 0
		if EffectSettings.reducedMotion() then
			return
		end
		-- Çok yavaş, hafif dalgalanma: sütun nefes alır gibi (kuzey ışığı)
		for _, marker in active do
			marker.gradient.Offset = Vector2.new(0, math.sin(clock * SHIMMER_SPEED + marker.phase) * 0.06)
		end
	end)
end)
