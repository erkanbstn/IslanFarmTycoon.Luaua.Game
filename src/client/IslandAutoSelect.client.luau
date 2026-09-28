--!strict
-- Karakter kendi çiftliğinin bir adasına (yürüyerek ya da ışınlanarak) girince o ada seçilir:
-- Yükseltmeler ve Yol Haritası otomatik o adanın listesine geçer. Ada sekmelerinden elle seçilen ada,
-- karakter başka bir adaya geçene kadar korunur.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local ClientState = require(script.Parent:WaitForChild("ClientState"))
local IslandContext = require(script.Parent:WaitForChild("IslandContext"))

local player = Players.LocalPlayer
local CHECK_INTERVAL = 0.4
local lastDetected: string? = nil

-- Etkin ana çiftliğin plot'u
local function ownPlot(): Model?
	local plots = Workspace:FindFirstChild("Plots")
	if not plots then
		return nil
	end
	local farmId = player:GetAttribute("ActiveMainFarmId")
	for _, plot in plots:GetChildren() do
		if
			plot:IsA("Model")
			and plot:GetAttribute("OwnerUserId") == player.UserId
			and plot:GetAttribute("MainFarmId") == farmId
		then
			return plot
		end
	end
	return nil
end

-- Karakterin üstünde durduğu ada (ana ada = "home"); hiçbirinde değilse nil
local function islandUnderCharacter(plot: Model, position: Vector3): string?
	local function inside(base: Instance?): boolean
		if not base or not base:IsA("BasePart") then
			return false
		end
		-- MapBuilder silindirleri X ekseni çevrilmiş disklerdir; yatay çap Size.Y'dedir.
		local flat = Vector3.new(position.X - base.Position.X, 0, position.Z - base.Position.Z)
		return flat.Magnitude <= base.Size.Y / 2 - 2
	end
	local islands = plot:FindFirstChild("Islands")
	if islands then
		for _, island in islands:GetChildren() do
			local islandId = island:GetAttribute("FarmIslandId")
			if typeof(islandId) == "string" and inside(island:FindFirstChild("IslandBase")) then
				return islandId
			end
		end
	end
	if inside(plot:FindFirstChild("PlotBase")) then
		return "home"
	end
	return nil
end

local function check()
	local state = ClientState.get()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not state or not root or not root:IsA("BasePart") then
		return
	end
	local plot = ownPlot()
	if not plot then
		return
	end
	local detected = islandUnderCharacter(plot, root.Position)
	if detected == nil or detected == lastDetected then
		return
	end
	lastDetected = detected
	if detected ~= IslandContext.get() and state.unlockedIslands[detected] then
		Remotes.get("RequestTravelIsland"):FireServer(detected, true)
	end
end

task.spawn(function()
	while true do
		task.wait(CHECK_INTERVAL)
		check()
	end
end)
-- Çiftlik değişince ilk tespit yeniden yapılsın
player:GetAttributeChangedSignal("ActiveMainFarmId"):Connect(function()
	lastDetected = nil
end)
