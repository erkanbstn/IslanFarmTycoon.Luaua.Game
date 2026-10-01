--!strict
-- Köprüde koşarken hız artar (Sprint.client "OnBridge" özniteliğini okuyup hızı çarpar), köprüden inince normale döner.
-- Hız artarken karakterin arkasında rüzgâr çizgileri (Trail) belirir. Hareketi azalt ve düşük efekt kalitesinde çizgi yoktur.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

local CHECK_SECONDS = 0.1
local GRACE_SECONDS = 0.35 -- köprü ucunda kısa kesintiler hızı titretmesin
local RAY_LENGTH = 8
local MIN_MOVE_SPEED = 4

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.IgnoreWater = true

type Wind = { trails: { Trail }, root: BasePart }
local wind: Wind? = nil
local lastOnBridgeAt = -math.huge
local elapsed = 0

local function destroyWind()
	if wind then
		for _, trail in wind.trails do
			trail.Enabled = false
		end
	end
end

-- Kök parçaya üç çizgi: iki yan ve bir üst (hepsi arkaya doğru solar)
local function buildWind(root: BasePart): Wind
	local trails: { Trail } = {}
	for _, offset in { Vector3.new(-1.3, 0.6, 0.4), Vector3.new(1.3, 0.6, 0.4), Vector3.new(0, 1.8, 0.4) } do
		local first = Instance.new("Attachment")
		first.Name = "WindStart"
		first.Position = offset
		first.Parent = root
		local second = Instance.new("Attachment")
		second.Name = "WindEnd"
		second.Position = offset + Vector3.new(0, 0.5, 0)
		second.Parent = root
		local trail = Instance.new("Trail")
		trail.Name = "WindStreak"
		trail.Attachment0, trail.Attachment1 = first, second
		trail.Lifetime = 0.28
		trail.MinLength = 0.1
		trail.FaceCamera = true
		trail.LightEmission = 0.5
		trail.LightInfluence = 0
		trail.Color = ColorSequence.new(Color3.fromRGB(235, 245, 255))
		trail.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.45),
			NumberSequenceKeypoint.new(1, 1),
		})
		trail.WidthScale = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(1, 0.2),
		})
		trail.Enabled = false
		trail.Parent = root
		table.insert(trails, trail)
	end
	return { trails = trails, root = root }
end

local function windAllowed(): boolean
	return player:GetAttribute("ReducedMotion") ~= true and player:GetAttribute("EffectsQuality") ~= "low"
end

local function update()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not root or not root:IsA("BasePart") or not humanoid or humanoid.Health <= 0 then
		player:SetAttribute("OnBridge", false)
		destroyWind()
		return
	end
	params.FilterDescendantsInstances = { character }
	local hit = workspace:Raycast(root.Position, Vector3.new(0, -RAY_LENGTH, 0), params)
	local onBridgeNow = hit ~= nil and hit.Instance.Name == "Bridge"
	local now = os.clock()
	if onBridgeNow then
		lastOnBridgeAt = now
	end
	local onBridge = onBridgeNow or now - lastOnBridgeAt < GRACE_SECONDS
	if (player:GetAttribute("OnBridge") == true) ~= onBridge then
		player:SetAttribute("OnBridge", onBridge)
	end
	local moving = root.AssemblyLinearVelocity.Magnitude > MIN_MOVE_SPEED
	if onBridge and moving and windAllowed() then
		if not wind or wind.root ~= root or not wind.root.Parent then
			wind = buildWind(root)
		end
		for _, trail in (wind :: Wind).trails do
			trail.Enabled = true
		end
	else
		destroyWind()
	end
end

RunService.Heartbeat:Connect(function(dt: number)
	elapsed += dt
	if elapsed < CHECK_SECONDS then
		return
	end
	elapsed = 0
	local ok, err = pcall(function()
		update()
	end)
	if not ok then
		warn(`[BridgeBoost] {err}`)
	end
end)

player.CharacterAdded:Connect(function()
	wind = nil
	lastOnBridgeAt = -math.huge
	player:SetAttribute("OnBridge", false)
end)
