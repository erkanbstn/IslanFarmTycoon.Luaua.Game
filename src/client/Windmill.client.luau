--!strict
-- Yel değirmeni kanatları: "Windmill" etiketli Model'leri kendi ekseninde (yerel Z) döndürür.
-- Yalnızca kameraya yakın olanlar döner (StreamingEnabled parçaları sonradan getirir/kaldırır).
-- "Hareketi azalt" açıkken dönmez.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local UPDATE_DISTANCE = 220
local blades: { [Model]: number } = {} -- model -> rad/sn

local function track(instance: Instance)
	if not instance:IsA("Model") then
		return
	end
	local speed = instance:GetAttribute("Speed")
	blades[instance] = if typeof(speed) == "number" then speed else 0.6
end

CollectionService:GetInstanceAddedSignal("Windmill"):Connect(track)
CollectionService:GetInstanceRemovedSignal("Windmill"):Connect(function(instance: Instance)
	if instance:IsA("Model") then
		blades[instance] = nil
	end
end)
for _, instance in CollectionService:GetTagged("Windmill") do
	track(instance)
end

local connection = RunService.Heartbeat:Connect(function(dt: number)
	if player:GetAttribute("ReducedMotion") == true then
		return
	end
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local cameraPosition = camera.CFrame.Position
	for model, speed in blades do
		if not model.PrimaryPart or not model:IsDescendantOf(Workspace) then
			continue
		end
		if (model:GetPivot().Position - cameraPosition).Magnitude > UPDATE_DISTANCE then
			continue
		end
		-- Fırtınada biraz daha hızlı döner
		local weather = game:GetService("ReplicatedStorage"):GetAttribute("Weather")
		local boost = if weather == "storm" then 2.2 elseif weather == "rain" then 1.4 else 1
		model:PivotTo(model:GetPivot() * CFrame.Angles(0, 0, speed * boost * dt))
	end
end)
script.Destroying:Connect(function()
	connection:Disconnect()
end)
