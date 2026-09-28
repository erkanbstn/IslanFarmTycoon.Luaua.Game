--!strict
-- test.project.json ile üretilen AYRI test place'inde çalışır; normal oyun init'i yoktur.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")

assert(RunService:IsStudio(), "Test place'i yalnızca Studio'da çalıştırılmalıdır")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Modules = ServerScriptService:WaitForChild("Server"):WaitForChild("Modules")
local Config = require(Shared:WaitForChild("Config"))
local FarmMath = require(Shared:WaitForChild("Modules"):WaitForChild("FarmMath"))
local Environment = require(Shared:WaitForChild("Modules"):WaitForChild("Environment"))
local SessionLock = require(Modules:WaitForChild("SessionLock"))
local SaveCodec = require(Modules:WaitForChild("SaveCodec"))
local OrderRules = require(Modules:WaitForChild("OrderRules"))

require(script.Parent:WaitForChild("data.spec"))(SessionLock, SaveCodec, Config, FarmMath)
require(script.Parent:WaitForChild("economy.spec"))(FarmMath, Config, Environment)
require(script.Parent:WaitForChild("orders.spec"))(OrderRules, Config)
print("World spec edit modunda Command Bar üzerinden ayrıca çalıştırılmalıdır.")
print("PASS: Studio regression suite completed")
