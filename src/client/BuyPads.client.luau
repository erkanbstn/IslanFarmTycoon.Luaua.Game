--!strict
-- Dünyadaki satın alma butonlarının görünümü (yalnızca bu ekranda):
--  * Halka: kasa yetiyorsa altın rengi parlar, yetmiyorsa sönük gri.
--  * Altın para: havada döner ve hafifçe süzülür; kasa yetmiyorsa yarı saydamdır.
-- Satın alma sunucudaki ProximityPrompt ile yapılır; burası yalnızca görünüm.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local ClientState = require(script.Parent:WaitForChild("ClientState"))
local UiKit = require(script.Parent:WaitForChild("UiKit"))

local player = Players.LocalPlayer
local SPIN_DISTANCE = 90

local rings: { [BasePart]: number } = {}
local coins: { [BasePart]: number } = {}
local cash = 0

local function paint()
	for ring, cost in rings do
		local color = if cash >= cost then UiKit.Color.Gold else UiKit.Color.Disabled
		if ring.Color ~= color then
			ring.Color = color
		end
	end
	for coin, cost in coins do
		local transparency = if cash >= cost then 0 else 0.55
		if coin.Transparency ~= transparency then
			coin.Transparency = transparency
		end
	end
end

local function track(instance: Instance, into: { [BasePart]: number })
	if not instance:IsA("BasePart") then
		return
	end
	local cost = instance:GetAttribute("Cost")
	if typeof(cost) == "number" then
		into[instance] = cost
		paint()
	end
end

CollectionService:GetInstanceAddedSignal("BuyPad"):Connect(function(instance: Instance)
	track(instance, rings)
end)
CollectionService:GetInstanceAddedSignal("BuyPadSpin"):Connect(function(instance: Instance)
	track(instance, coins)
end)
CollectionService:GetInstanceRemovedSignal("BuyPad"):Connect(function(instance: Instance)
	if instance:IsA("BasePart") then
		rings[instance] = nil
	end
end)
CollectionService:GetInstanceRemovedSignal("BuyPadSpin"):Connect(function(instance: Instance)
	if instance:IsA("BasePart") then
		coins[instance] = nil
	end
end)
for _, instance in CollectionService:GetTagged("BuyPad") do
	track(instance, rings)
end
for _, instance in CollectionService:GetTagged("BuyPadSpin") do
	track(instance, coins)
end

ClientState.onChanged(function(state)
	if state.cash ~= cash then
		cash = state.cash
		paint()
	end
end)

local elapsed = 0
local connection = RunService.Heartbeat:Connect(function(dt: number)
	elapsed += dt
	if player:GetAttribute("ReducedMotion") == true then
		return
	end
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local cameraPosition = camera.CFrame.Position
	for coin in coins do
		local base = coin:GetAttribute("BasePos")
		if typeof(base) ~= "Vector3" or (base - cameraPosition).Magnitude > SPIN_DISTANCE then
			continue
		end
		coin.CFrame = CFrame.new(base + Vector3.new(0, math.sin(elapsed * 2) * 0.22, 0))
			* CFrame.Angles(0, elapsed * 2.4, 0)
	end
end)
script.Destroying:Connect(function()
	connection:Disconnect()
end)
