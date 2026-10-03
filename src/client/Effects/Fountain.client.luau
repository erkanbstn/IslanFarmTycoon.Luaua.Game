--!strict
-- Kalıcı çeşme modeli korunur; su akışı yalnız bir kez kurulan Beam/emitter efektidir.
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local EffectSettings = require(script.Parent.Parent:WaitForChild("Core"):WaitForChild("EffectSettings"))

type Fountain = { folder: Folder, beams: { Beam }, emitter: ParticleEmitter, enabled: boolean?, rate: number? }
local fountains: { [Model]: Fountain } = {}
local pending: { [Model]: boolean } = {}
local connections: { RBXScriptConnection } = {}
local running = true

local function attachment(part: BasePart, position: Vector3, axis: Vector3): Attachment
	local a = Instance.new("Attachment")
	a.Name = "FountainFlowAttachment"
	local side = if math.abs(axis:Dot(Vector3.xAxis)) > 0.9 then Vector3.zAxis else Vector3.xAxis
	a.CFrame = CFrame.fromMatrix(position, axis, side, axis:Cross(side))
	a.Parent = part
	return a
end

local function track(instance: Instance)
	if not instance:IsA("Model") or instance.Name ~= "Fountain" or fountains[instance] or pending[instance] then
		return
	end
	pending[instance] = true
	task.spawn(function()
		local nozzle = instance:WaitForChild("MainJetNozzle", 8)
		local water = instance:FindFirstChild("Water")
		pending[instance] = nil
		if
			not running
			or not instance:IsDescendantOf(Workspace)
			or not nozzle
			or not nozzle:IsA("BasePart")
			or not water
			or not water:IsA("BasePart")
		then
			return
		end
		local folder = Instance.new("Folder")
		folder.Name = "FountainFlow"
		local beams: { Beam } = {}
		for i = 1, 4 do
			local spout = instance:FindFirstChild(`Spout{i}`)
			if spout and spout:IsA("BasePart") then
				local angle = (i - 1) * math.pi / 2
				local landing = instance:GetPivot() * Vector3.new(math.sin(angle) * 2.75, 0.99, math.cos(angle) * 2.75)
				local start = attachment(spout, Vector3.zero, Vector3.yAxis)
				local finish = attachment(
					water,
					water.CFrame:PointToObjectSpace(landing),
					-water.CFrame:VectorToObjectSpace(Vector3.yAxis)
				)
				local beam = Instance.new("Beam")
				beam.Name = `WaterArc{i}`
				beam.Attachment0, beam.Attachment1 = start, finish
				beam.CurveSize0, beam.CurveSize1 = 1.4, 1.2
				beam.Width0, beam.Width1 = 0.16, 0.22
				beam.Color = ColorSequence.new(Color3.fromRGB(170, 225, 236))
				beam.Transparency = NumberSequence.new(0.35)
				beam.FaceCamera = true
				beam.Segments = 12
				beam.LightEmission = 0
				beam.LightInfluence = 1
				beam.Texture = "rbxasset://textures/particles/smoke_main.dds"
				beam.TextureLength = 0.35
				beam.TextureSpeed = 1.3
				beam.Enabled = false
				beam.Parent = folder
				table.insert(beams, beam)
			end
		end
		local jet = Instance.new("Attachment")
		jet.Name = "FountainFlowAttachment"
		jet.Parent = nozzle
		local emitter = Instance.new("ParticleEmitter")
		emitter.Name = "FountainSpray"
		emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
		emitter.Color = ColorSequence.new(Color3.fromRGB(189, 233, 242))
		emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.07), NumberSequenceKeypoint.new(1, 0.13) })
		emitter.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.2),
			NumberSequenceKeypoint.new(0.7, 0.45),
			NumberSequenceKeypoint.new(1, 1),
		})
		emitter.Speed = NumberRange.new(7, 9)
		emitter.Lifetime = NumberRange.new(0.8, 1.2)
		emitter.Acceleration = Vector3.new(0, -18, 0)
		emitter.SpreadAngle = Vector2.new(10, 10)
		emitter.LightEmission = 0
		emitter.LightInfluence = 1
		emitter.Rate = 0
		emitter.Enabled = false
		emitter.Parent = jet
		folder.Parent = instance
		fountains[instance] = { folder = folder, beams = beams, emitter = emitter }
	end)
end

local function untrack(instance: Instance)
	if not instance:IsA("Model") then
		return
	end
	pending[instance] = nil
	local state = fountains[instance]
	if state then
		state.folder:Destroy()
		for _, child in instance:GetDescendants() do
			if child:IsA("Attachment") and child.Name == "FountainFlowAttachment" then
				child:Destroy()
			end
		end
		fountains[instance] = nil
	end
end

table.insert(connections, Workspace.DescendantAdded:Connect(track))
table.insert(connections, Workspace.DescendantRemoving:Connect(untrack))
for _, instance in Workspace:GetDescendants() do
	track(instance)
end
local elapsed = 0
table.insert(
	connections,
	RunService.Heartbeat:Connect(function(dt: number)
		elapsed += dt
		if elapsed < 0.25 then
			return
		end
		elapsed = 0
		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end
		local quality = EffectSettings.quality()
		local rate = if quality == "high" then 32 elseif quality == "medium" then 16 else 5
		for model, state in fountains do
			local enabled = not EffectSettings.reducedMotion()
				and (model:GetPivot().Position - camera.CFrame.Position).Magnitude < 180
			if state.enabled ~= enabled then
				state.enabled = enabled
				for _, beam in state.beams do
					beam.Enabled = enabled
				end
				state.emitter.Enabled = enabled
			end
			if state.rate ~= rate then
				state.rate = rate
				state.emitter.Rate = rate
			end
		end
	end)
)
script.Destroying:Connect(function()
	running = false
	for _, connection in connections do
		connection:Disconnect()
	end
	for model in fountains do
		untrack(model)
	end
end)
