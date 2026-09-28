--!strict
-- Hayvanları kendi bölgeleri içinde yavaşça gezdirir (sadece görsel, sadece bu oyuncunun ekranında).
-- Sunucu hayvanı "Animal" etiketi ve AreaCFrame / AreaSize / HeightOffset attribute'larıyla işaretler.

local Players = game:GetService("Players")
local localPlayer = Players.LocalPlayer

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local ANIMATE_DISTANCE = 140 -- Kameradan uzaktaki hayvanlar hareket etmez (performans)
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
}

local states: { [Model]: AnimalState } = {}
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

-- Yakındaki hareket her çizim karesinde uygulanır. Zamanı biriktirip sıfırlayan
-- 30 Hz kapısı değişken kare aralıklarında 20 Hz'e düşerek görünür takılma yapıyordu.
RunService.RenderStepped:Connect(function(dt: number)
	dt = math.min(dt, 1 / 15)
	local quality = localPlayer:GetAttribute("EffectsQuality")
	if localPlayer:GetAttribute("ReducedMotion") == true then
		return
	end
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local cameraPos = camera.CFrame.Position
	local now = os.clock()

	for model, state in states do
		if not model.Parent then
			states[model] = nil
			continue
		end
		-- ScaleTo efektinin pivotunu aynı karede geri yazma; bitince kaldığı yerden sürer.
		if model:GetAttribute("BuildPopActive") == true then
			continue
		end
		local worldPos = state.area * state.position
		if (worldPos - cameraPos).Magnitude > (if quality == "low" then 80 else ANIMATE_DISTANCE) then
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
		model:PivotTo(state.area * localCf)
	end
end)
