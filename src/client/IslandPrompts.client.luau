--!strict
-- Prompt görünürlüğü yerel; sahiplik ve satın alma doğrulaması sunucuda kalır.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local localPlayer = Players.LocalPlayer
local connections: { [ProximityPrompt]: { RBXScriptConnection } } = {}

local function discover(instance: Instance)
	if
		not instance:IsA("ProximityPrompt")
		or (instance.Name ~= "BuyIslandPrompt" and instance.Name ~= "ProductionPrompt")
		or connections[instance]
	then
		return
	end
	local plot = instance.Parent
	while plot and (not plot.Parent or plot.Parent.Name ~= "Plots") do
		plot = plot.Parent
	end
	if not plot then
		return
	end
	local owner = plot
	local function update()
		instance.Enabled = owner:GetAttribute("OwnerUserId") == localPlayer.UserId
			and owner:GetAttribute("MainFarmId") == localPlayer:GetAttribute("ActiveMainFarmId")
			and (instance.Name == "ProductionPrompt" or instance:GetAttribute("Locked") == true)
	end
	connections[instance] = {
		instance:GetAttributeChangedSignal("Locked"):Connect(update),
		owner:GetAttributeChangedSignal("OwnerUserId"):Connect(update),
		owner:GetAttributeChangedSignal("MainFarmId"):Connect(update),
		localPlayer:GetAttributeChangedSignal("ActiveMainFarmId"):Connect(update),
	}
	update()
end

Workspace.DescendantAdded:Connect(discover)
Workspace.DescendantRemoving:Connect(function(instance: Instance)
	if instance:IsA("ProximityPrompt") then
		local watches = connections[instance]
		if watches then
			for _, connection in watches do
				connection:Disconnect()
			end
			connections[instance] = nil
		end
	end
end)
for _, instance in Workspace:GetDescendants() do
	discover(instance)
end
