--!strict
-- Bu script default.project.json'a dahil değildir. Ayrı, kayıtsız Studio QA place'i içindir.
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
if
	not RunService:IsStudio()
	or Workspace:GetAttribute("StudioQaEnabled") ~= true
	or Workspace:GetAttribute("StudioNonPersistentData") ~= true
then
	return
end
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Services = ServerScriptService:WaitForChild("Server"):WaitForChild("Services")
local Modules = ServerScriptService.Server:WaitForChild("Modules")
local Config = require(Shared:WaitForChild("Config"))
local FarmMath = require(Shared.Modules:WaitForChild("FarmMath"))
local Progression = require(Shared.Modules:WaitForChild("Progression"))
local SaveCodec = require(Modules:WaitForChild("SaveCodec"))
local PlayerDataService = require(Services:WaitForChild("PlayerDataService"))
local EconomyService = require(Services:WaitForChild("EconomyService"))
local PlotService = require(Services:WaitForChild("PlotService"))
local Fixtures = require(script.Parent:WaitForChild("ScenarioFixtures"))
local state = Instance.new("Folder")
state.Name = "StudioQaState"
state.Parent = ReplicatedStorage
local busy = false
local lastId: { [Player]: number } = {}
Players.PlayerRemoving:Connect(function(player)
	lastId[player] = nil
end)
local function result(request: any, status: string, extra: any?)
	local payload = { requestId = request.requestId, scenario = request.scenario, status = status }
	if extra then
		for key, value in extra do
			payload[key] = value
		end
	end
	state:SetAttribute("LastResult", HttpService:JSONEncode(payload))
end
local function handle()
	local raw = ServerStorage:GetAttribute("StudioQaRequest")
	if typeof(raw) ~= "string" or #raw > 1024 then
		return
	end
	local decoded, request = pcall(HttpService.JSONDecode, HttpService, raw)
	if not decoded or typeof(request) ~= "table" then
		return
	end
	if
		typeof(request.requestId) ~= "number"
		or request.requestId % 1 ~= 0
		or request.requestId <= 0
		or typeof(request.userId) ~= "number"
		or request.userId % 1 ~= 0
	then
		return
	end
	local player = Players:GetPlayerByUserId(request.userId)
	if
		not player
		or not Fixtures.allowed(
			RunService:IsStudio(),
			Workspace:GetAttribute("StudioQaEnabled"),
			Workspace:GetAttribute("StudioNonPersistentData"),
			player:GetAttribute("DataPersistent")
		)
	then
		result(request, "rejected", { reason = "Nonpersistent Studio session required" })
		return
	end
	if busy or player:GetAttribute("WorldReady") ~= true or (lastId[player] or 0) >= request.requestId then
		result(request, "rejected", { reason = "Busy, not ready, or stale request" })
		return
	end
	local data = PlayerDataService.tryGet(player)
	if not data then
		result(request, "rejected", { reason = "No loaded session" })
		return
	end
	busy = true
	local ready = player:GetAttribute("WorldReady")
	local original: any = nil
	local ok = pcall(function()
		local fixture = Fixtures.create(request.scenario, request.rebirthLevel or 0, os.time(), function()
			return HttpService:GenerateGUID(false)
		end, Config, FarmMath, SaveCodec, Progression)
		EconomyService.settlePlayer(player)
		original = table.clone(data)
		player:SetAttribute("WorldReady", false)
		table.clear(data)
		for key, value in fixture do
			data[key] = value
		end
		assert(
			PlotService.restoreMainFarms(player, PlayerDataService.getFarmIds(player), data.activeMainFarmId),
			"Fixture world restoration failed"
		)
		PlayerDataService.pushState(player)
		PlotService.teleportHome(player)
		lastId[player] = request.requestId
		result(request, "ok", {
			rebirthLevel = data.progression.count,
			farms = #PlayerDataService.getFarmIds(player),
			animals = #data.animals,
			canRebirth = Progression.canRebirth(data),
			persistent = false,
		})
	end)
	if not ok then
		if original then
			table.clear(data)
			for key, value in original do
				data[key] = value
			end
			pcall(function()
				PlotService.restoreMainFarms(player, PlayerDataService.getFarmIds(player), data.activeMainFarmId)
				PlayerDataService.pushState(player)
			end)
		end
		result(request, "failed", { reason = "Invalid fixture or world restoration failure; inspect Studio console" })
	end
	player:SetAttribute("WorldReady", ready)
	busy = false
end
ServerStorage:GetAttributeChangedSignal("StudioQaRequest"):Connect(handle)
