--!strict
-- Oyunda ölüm yok: karakterin "ölü" durumu kapatılır, canı hep dolu tutulur.
-- Bir şekilde haritanın altına düşerse (ör. bir boşluktan) kendi adasına (yoksa meydana) ışınlanır.
-- Karakter fiziğini bu client yönettiği için bunlar burada yapılır; sunucuda yedek olarak hızlı doğma var.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local RESCUE_BELOW_Y = -35 -- Deniz tabanının (-20) ve güvenlik zemininin (-26) altı

local localPlayer = Players.LocalPlayer

local function findSafeSpot(): CFrame?
	local plots = Workspace:FindFirstChild("Plots")
	if plots then
		for _, plot in plots:GetChildren() do
			if
				plot:GetAttribute("OwnerUserId") == localPlayer.UserId
				and plot:GetAttribute("PlotId") == localPlayer:GetAttribute("ActivePlotId")
			then
				local spawn = plot:FindFirstChild("Spawn")
				if spawn and spawn:IsA("BasePart") then
					return spawn.CFrame + Vector3.new(0, 4, 0)
				end
			end
		end
	end
	local world = Workspace:FindFirstChild("World")
	local hubSpawn = world and world:FindFirstChild("HubSpawn", true)
	if hubSpawn and hubSpawn:IsA("BasePart") then
		return hubSpawn.CFrame + Vector3.new(0, 4, 0)
	end
	return nil
end

local function protect(character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid or not humanoid:IsA("Humanoid") then
		return
	end
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
	humanoid.BreakJointsOnDeath = false
	humanoid.HealthChanged:Connect(function(health: number)
		if health < humanoid.MaxHealth then
			humanoid.Health = humanoid.MaxHealth
		end
	end)
end

localPlayer.CharacterAdded:Connect(protect)
if localPlayer.Character then
	task.spawn(protect, localPlayer.Character)
end

-- Düşme kurtarması
local lastCheck = 0
local lastRescueRequest = -math.huge
RunService.Heartbeat:Connect(function()
	local now = os.clock()
	if now - lastCheck < 0.25 then
		return
	end
	lastCheck = now
	local character = localPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if character and root and root:IsA("BasePart") and root.Position.Y < RESCUE_BELOW_Y then
		root.AssemblyLinearVelocity = Vector3.zero
		local safe = findSafeSpot()
		if safe then
			character:PivotTo(safe)
		elseif now - lastRescueRequest >= 2 then
			-- Streaming hedefi client'tan kaldırmış olabilir; sunucu gerçek spawn'ı bilir.
			lastRescueRequest = now
			Remotes.get("RequestGoHome"):FireServer()
		end
	end
end)
