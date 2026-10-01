--!strict
-- Hayvan üstü mevsim/hava göstergesi (sadece görsel, sadece bu oyuncunun ekranında): gelir çarpanı artıya geçen
-- hayvanın yanında yeşil yukarı ok, eksiye düşenin yanında kırmızı aşağı ok; nötr hayvanda hiçbir şey.
-- Sinyal `FarmMath.getSeasonEffect` ile hesaplanır (Mevsim çubuğu ile aynı hesap) ve OLAY tabanlıdır:
-- mevsim/hava/bölge uyumu/hayvan listesi değişince yeniden hesaplanır. Zamanlayıcı yalnızca mesafe seçer.
-- Yalnızca kameraya yakın, en yakın N hayvanda küçük bir havuzdaki BillboardGui'ler gösterilir; düşük kalitede aura yok,
-- ReducedMotion'da nabız yok.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
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

-- Kalite başına: en fazla kaç hayvanda ve hangi uzaklığa kadar gösterilir; aura yalnızca orta/yüksekte.
local QUALITY = {
	low = { distance = 38, maxMarkers = 6, aura = false },
	medium = { distance = 60, maxMarkers = 12, aura = true },
	high = { distance = 75, maxMarkers = 20, aura = true },
}
local SELECT_INTERVAL = 0.5 -- mesafe seçimi (olay tabanlı sinyalden ayrı, seyrek)
local PULSE_INTERVAL = 1 / 20
local FACING_LIMIT = -0.3 -- kameranın tamamen arkasındaki hayvan seçilmez (bakış yönü ile nokta çarpımı)
local PULSE_SPEED = 2.4
local SIZE = 36 -- piksel; ok 36x36 kutuya çizilir
local SIDE_OFFSET = 2.6 -- ad etiketinin yanına (kameraya göre sağ), stud
local STROKE = Color3.fromRGB(20, 22, 28)

type Marker = {
	gui: BillboardGui,
	aura: Frame,
	auraStroke: UIStroke,
	arrow: Frame,
	bars: { Frame },
	model: Model?,
	phase: number,
}

local player = Players.LocalPlayer
local signals: { [Model]: number } = {} -- model -> -1 / 0 / +1 (yalnızca sıfırdan farklılar tutulur)
local tracked: { [Model]: boolean } = {}
local assigned: { [Model]: Marker } = {}
local active: { Marker } = {}
local free: { Marker } = {}

local function bar(parent: Instance, size: Vector2, position: Vector2, rotation: number): Frame
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Size = UDim2.fromOffset(size.X, size.Y)
	frame.Position = UDim2.fromOffset(position.X, position.Y)
	frame.Rotation = rotation
	frame.BorderSizePixel = 0
	frame.BackgroundColor3 = Color.Green
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 3)
	corner.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Color = STROKE
	stroke.Thickness = 1.5
	stroke.Transparency = 0.2
	stroke.Parent = frame
	frame.Parent = parent
	return frame
end

local function createMarker(): Marker
	local gui = Instance.new("BillboardGui")
	gui.Name = "SeasonSignal"
	gui.Size = UDim2.fromOffset(SIZE, SIZE)
	gui.LightInfluence = 0
	gui.ResetOnSpawn = false
	gui.Active = false
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local aura = Instance.new("Frame")
	aura.Name = "Aura"
	aura.AnchorPoint = Vector2.new(0.5, 0.5)
	aura.Position = UDim2.fromScale(0.5, 0.5)
	aura.Size = UDim2.fromScale(1, 1)
	aura.BorderSizePixel = 0
	aura.BackgroundTransparency = 0.78
	local auraCorner = Instance.new("UICorner")
	auraCorner.CornerRadius = UDim.new(1, 0)
	auraCorner.Parent = aura
	local auraStroke = Instance.new("UIStroke")
	auraStroke.Thickness = 2
	auraStroke.Transparency = 0.45
	auraStroke.Parent = aura
	aura.Parent = gui

	-- Yukarı ok: sap + iki kanat (45 derece döndürülmüş çubuklar). Aşağı ok aynı grubun 180 derece döndürülmesidir.
	local arrow = Instance.new("Frame")
	arrow.Name = "Arrow"
	arrow.AnchorPoint = Vector2.new(0.5, 0.5)
	arrow.Position = UDim2.fromScale(0.5, 0.5)
	arrow.Size = UDim2.fromOffset(SIZE, SIZE)
	arrow.BackgroundTransparency = 1
	arrow.Parent = gui
	local bars = {
		bar(arrow, Vector2.new(6, 20), Vector2.new(18, 20), 0),
		bar(arrow, Vector2.new(6, 16), Vector2.new(12.3, 11.7), 45),
		bar(arrow, Vector2.new(6, 16), Vector2.new(23.7, 11.7), -45),
	}
	return {
		gui = gui,
		aura = aura,
		auraStroke = auraStroke,
		arrow = arrow,
		bars = bars,
		model = nil,
		phase = 0,
	}
end

local function anchorOf(model: Model): BasePart?
	return model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
end

local function style(marker: Marker, signal: number, model: Model, anchor: BasePart, aura: boolean)
	local color = if signal > 0 then Color.Green else Color.Red
	for _, frame in marker.bars do
		frame.BackgroundColor3 = color
	end
	marker.arrow.Rotation = if signal > 0 then 0 else 180
	marker.arrow.Position = UDim2.fromScale(0.5, 0.5)
	marker.aura.Visible = aura
	marker.aura.BackgroundColor3 = color
	marker.auraStroke.Color = color
	-- Ad etiketinin yanında, kutunun üstünde (balıkta suyun üstüne: ad etiketiyle aynı yükseklik kuralı)
	local _, boxSize = model:GetBoundingBox()
	local depth = model:GetAttribute("SwimDepthOffset")
	local height = boxSize.Y / 2 + 1 + (if typeof(depth) == "number" then depth else 0)
	marker.gui.StudsOffsetWorldSpace = Vector3.new(0, height, 0)
	marker.gui.StudsOffset = Vector3.new(SIDE_OFFSET, 0, 0)
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
			local quality = QUALITY[EffectSettings.quality()] or QUALITY.medium
			if anchor then
				style(marker, signal, model, anchor, quality.aura)
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
				style(marker, signals[model] or 0, model, anchor, quality.aura)
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
		if #active == 0 or EffectSettings.reducedMotion() then
			return
		end
		pulseElapsed += dt
		if pulseElapsed < PULSE_INTERVAL then
			return
		end
		clock += pulseElapsed
		pulseElapsed = 0
		for _, marker in active do
			local wave = math.sin(clock * PULSE_SPEED + marker.phase)
			local up = if marker.arrow.Rotation == 0 then 1 else -1
			marker.arrow.Position = UDim2.new(0.5, 0, 0.5, -wave * 2 * up)
			if marker.aura.Visible then
				marker.aura.BackgroundTransparency = 0.78 + wave * 0.08
				marker.aura.Size = UDim2.fromScale(1 + wave * 0.06, 1 + wave * 0.06)
			end
		end
	end)
end)
