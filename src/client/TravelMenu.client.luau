--!strict
-- Dünya tabelası ve sağ menü aynı ada yönetim ekranını açar.
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local IslandManager = require(script.Parent:WaitForChild("IslandManager"))
local player = Players.LocalPlayer

ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt, who: Player?)
	if prompt.Name == "TravelPrompt" and (not who or who == player) then
		IslandManager.open()
	end
end)
