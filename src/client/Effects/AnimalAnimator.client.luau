--!strict
-- Hayvanları kendi bölgeleri içinde yavaşça gezdirir (sadece görsel, sadece bu oyuncunun ekranında).
-- Sunucu hayvanı "Animal" etiketi ve AreaCFrame / AreaSize / HeightOffset attribute'larıyla işaretler.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local EffectSettings = require(script.Parent.Parent:WaitForChild("Core"):WaitForChild("EffectSettings"))

-- Kameradan uzaktaki hayvanlar hareket etmez; düşükte menzil dar ve hareketli hayvan sayısı sınırlı.
local QUALITY = {
	low = { distance = 50, maxActive = 20 },
	medium = { distance = 140, maxActive = math.huge },
	high = { distance = 140, maxActive = math.huge },
}
local NEAR_CHECK_INTERVAL = 0.25
local WALK_SPEED = 3
local TURN_SPEED = 4

type AnimalState = {
	model: Model,
	area: CFrame,
	halfSize: Vector3,
	heightOffset: number,
	position: Vector3, -- alan-yerel X/Z
	yaw: number,
	target: Vector3?,
	waitUntil: number,
	phase: number,
	track: boolean,
	trackAngle: number,
	parts: { BasePart }?, -- BulkMoveTo için model parçaları (nil = yeniden kurulacak)
	offsets: { CFrame }, -- parça CFrame'i, model pivotuna göre
	slot: number, -- Duran hayvanların yazım kareleri dağılsın diye
}

local states: { [Model]: AnimalState } = {}
local frameCount = 0
local random = Random.new()

local function randomPoint(state: AnimalState): Vector3
	return Vector3.new(
		random:NextNumber(-state.halfSize.X, state.halfSize.X),
		0,
		random:NextNumber(-state.halfSize.Z, state.halfSize.Z)
	)
end

local function trackReady(instance: Instance)
	if not instance:IsA("Model") or instance:GetAttribute("BuildPopActive") == true then
		return
	end
	local area = instance:GetAttribute("AreaCFrame")
	local size = instance:GetAttribute("AreaSize")
	local heightOffset = instance:GetAttribute("HeightOffset")
	if typeof(area) ~= "CFrame" or typeof(size) ~= "Vector3" or typeof(heightOffset) ~= "number" then
		return
	end

	local localCf = area:ToObjectSpace(instance:GetPivot())
	local look = localCf.LookVector
	local position = Vector3.new(localCf.Position.X, 0, localCf.Position.Z)
	local yaw = math.atan2(-look.X, -look.Z)

	-- Hayvan büyüyünce sunucu modeli yeniler; yenisi eskisinin durduğu yerden devam etsin
	local uid = instance:GetAttribute("Uid")
	if uid ~= nil then
		for other, otherState in states do
			if other ~= instance and other:GetAttribute("Uid") == uid then
				position, yaw = otherState.position, otherState.yaw
				break
			end
		end
	end

	local movement = instance:GetAttribute("MovementStyle")
	local isTrack = movement == "track"
	states[instance] = {
		model = instance,
		area = area,
		halfSize = size / 2,
		heightOffset = heightOffset,
		position = if isTrack then Vector3.new(0, 0, size.Z / 2 - 2) else position,
		yaw = yaw,
		target = nil,
		waitUntil = os.clock() + random:NextNumber(0, 4),
		phase = random:NextNumber(0, math.pi * 2),
		track = isTrack,
		trackAngle = random:NextNumber(0, math.pi * 2),
		near = true,
		nextNearCheck = 0,
		slot = random:NextInteger(0, 1),
	}
	-- İlk karede doğru yerde görünsün
	instance:PivotTo(area * CFrame.new(position.X, heightOffset, position.Z) * CFrame.Angles(0, yaw, 0))
end

local pending: { [Instance]: { RBXScriptConnection } } = {}
local function untrack(instance: Instance)
	if instance:IsA("Model") then
		states[instance] = nil
	end
	local connections = pending[instance]
	if connections then
		for _, connection in connections do
			connection:Disconnect()
		end
		pending[instance] = nil
	end
end

local function track(instance: Instance)
	if not instance:IsA("Model") or pending[instance] then
		return
	end
	local function retry()
		if
			not states[instance]
			and instance:IsDescendantOf(Workspace)
			and instance:FindFirstChildWhichIsA("BasePart", true)
		then
			trackReady(instance)
		end
	end
	pending[instance] = {
		instance.AttributeChanged:Connect(retry),
		instance.DescendantAdded:Connect(retry),
	}
	retry()
end
CollectionService:GetInstanceAddedSignal("Animal"):Connect(track)
CollectionService:GetInstanceRemovedSignal("Animal"):Connect(untrack)
for _, instance in CollectionService:GetTagged("Animal") do
	track(instance)
end

local function angleDelta(from: number, to: number): number
	return (to - from + math.pi) % (math.pi * 2) - math.pi
end

local function rebuildParts(state: AnimalState)
	local pivot = state.model:GetPivot()
	local parts: { BasePart } = {}
	local offsets: { CFrame } = {}
	for _, descendant in state.model:GetDescendants() do
		if descendant:IsA("BasePart") then
			table.insert(parts, descendant)
			table.insert(offsets, pivot:ToObjectSpace(descendant.CFrame))
		end
	end
	state.parts = parts
	state.offsets = offsets
end

-- Kameraya yakın ve (düşükte) en yakın N hayvan; her karede mesafe hesaplanmaz.
local active: { AnimalState } = {}
local nextNearCheck = 0
local ranked: { { state: AnimalState, distance: number } } = {}

local function refreshActive(cameraPos: Vector3, now: number)
	local config = QUALITY[EffectSettings.quality()] or QUALITY.medium
	table.clear(ranked)
	for model, state in states do
		if not model.Parent then
			states[model] = nil
			continue
		end
		local worldPos = state.area.Position + state.area:VectorToWorldSpace(state.position)
		local distance = (worldPos - cameraPos).Magnitude
		if distance <= config.distance then
			table.insert(ranked, { state = state, distance = distance })
		end
	end
	if #ranked > config.maxActive then
		table.sort(ranked, function(a, b)
			return a.distance < b.distance
		end)
	end
	table.clear(active)
	for index = 1, math.min(#ranked, config.maxActive) do
		active[index] = ranked[index].state
	end
	nextNearCheck = now + NEAR_CHECK_INTERVAL
end

local bulkParts: { BasePart } = {}
local bulkCFrames: { CFrame } = {}

-- Yakındaki hareket her çizim karesinde uygulanır (PreRender: kare çizilmeden hemen önce).
-- Zamanı biriktirip sıfırlayan 30 Hz kapısı değişken kare aralıklarında 20 Hz'e düşerek görünür
-- takılma yapıyordu. Tüm hayvanların parçaları tek BulkMoveTo ile taşınır (PivotTo başına bir çağrı yerine).
RunService.PreRender:Connect(function(dt: number)
	dt = math.min(dt, 1 / 15)
	if EffectSettings.reducedMotion() then
		return
	end
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local now = os.clock()
	if now >= nextNearCheck then
		refreshActive(camera.CFrame.Position, now)
	end
	frameCount += 1
	table.clear(bulkParts)
	table.clear(bulkCFrames)

	for index = #active, 1, -1 do
		local state = active[index]
		local model = state.model
		if not model.Parent then
			states[model] = nil
			table.remove(active, index)
			continue
		end
		-- ScaleTo efektinin pivotunu aynı karede geri yazma; bitince kaldığı yerden sürer.
		if model:GetAttribute("BuildPopActive") == true then
			continue
		end

		local moving = false
		if state.track then
			state.trackAngle += dt * 0.9
			local rx = math.min(state.halfSize.X, 6)
			local rz = math.min(state.halfSize.Z, 14)
			state.position = Vector3.new(math.cos(state.trackAngle) * rx, 0, math.sin(state.trackAngle) * rz)
			state.yaw = state.trackAngle + math.pi / 2
			moving = true
		elseif state.target == nil then
			if now >= state.waitUntil then
				state.target = randomPoint(state)
			end
		else
			local target = state.target :: Vector3
			local offset = target - state.position
			local distance = offset.Magnitude
			if distance < 0.3 then
				state.target = nil
				state.waitUntil = now + random:NextNumber(2, 7)
			else
				local desiredYaw = math.atan2(-offset.X, -offset.Z)
				local turn = angleDelta(state.yaw, desiredYaw)
				state.yaw += math.clamp(turn, -TURN_SPEED * dt, TURN_SPEED * dt)
				-- Önce dön, sonra yürü
				if math.abs(turn) < 0.6 then
					state.position += offset.Unit * math.min(WALK_SPEED * dt, distance)
					moving = true
				end
			end
		end

		state.phase += dt * (if moving then 10 else 2)
		local bob = if moving then math.abs(math.sin(state.phase)) * 0.25 else math.sin(state.phase) * 0.03
		local localCf = CFrame.new(state.position.X, state.heightOffset + bob, state.position.Z)
			* CFrame.Angles(0, state.yaw, 0)
		-- Duran hayvanın nefes hareketi çok küçüktür: yarım hızda yazmak yeter
		if moving or (frameCount + state.slot) % 2 == 0 then
			if not state.parts then
				rebuildParts(state)
			end
			local parts = state.parts :: { BasePart }
			local pivot = state.area * localCf
			local offsets = state.offsets
			for partIndex, part in parts do
				table.insert(bulkParts, part)
				table.insert(bulkCFrames, pivot * offsets[partIndex])
			end
		end
	end

	if #bulkParts > 0 then
		Workspace:BulkMoveTo(bulkParts, bulkCFrames, Enum.BulkMoveMode.FireCFrameChanged)
	end
end)
