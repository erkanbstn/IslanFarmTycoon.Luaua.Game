--!strict
-- Client giriş noktası (StarterPlayerScripts/Client)
-- UI, input, kamera ve görsel efektler burada. Önemli kararlar sunucuda verilir.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))

local localPlayer = Players.LocalPlayer

print(`[Client] Merhaba {localPlayer.Name}! {Config.GAME_NAME} yüklendi.`)
