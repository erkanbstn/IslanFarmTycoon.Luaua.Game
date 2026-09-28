--!strict
-- Oyuncuyu para toplama platformuna yönlendirir:
--  - Depo dolmaya başlayınca karakterden platforma yeşil bir yol çizgisi
--  - Platformda para varken parıltı, toplarken para patlaması ve yükselen "+$X" yazısı

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local GameTypes = require(Shared:WaitForChild("GameTypes"))
local FarmMath = require(Shared:WaitForChild("Modules"):WaitForChild("FarmMath"))
local ClientState = require(script.Parent:WaitForChild("ClientState"))
local UiTheme = require(Shared:WaitForChild("UiTheme"))
local WorldUi = require(Shared:WaitForChild("WorldUi"))

type PlayerSave = GameTypes.PlayerSave

local GUIDE_RATIO = 0.3 -- Depo bu orana gelince yol çizgisi görünür
local GUIDE_HIDE_DISTANCE = 12

local localPlayer = Players.LocalPlayer
local GREEN = UiTheme.Color.Green
local GOLD = UiTheme.Color.Gold

local collector: BasePart? = nil
local sparkles: ParticleEmitter? = nil
local burst: ParticleEmitter? = nil
local targetAttachment: Attachment? = nil
local beam: Beam? = nil
local fromAttachment: Attachment? = nil
local wantGuide = false

local function findOwnCollector(): BasePart?
	local plots = Workspace:FindFirstChild("Plots")
	if not plots then
		return nil
	end
	for _, plot in plots:GetChildren() do
		if
			plot:GetAttribute("OwnerUserId") == localPlayer.UserId
			and plot:GetAttribute("PlotId") == localPlayer:GetAttribute("ActivePlotId")
		then
			local part = plot:FindFirstChild("Collector")
			if part and part:IsA("BasePart") then
				return part
			end
		end
	end
	return nil
end

local function makeEmitter(parent: Instance, color: Color3, rate: number): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = 1
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) })
	emitter.Transparency = NumberSequence.new(0.1)
	emitter.Lifetime = NumberRange.new(0.8, 1.4)
	emitter.Speed = NumberRange.new(4, 9)
	emitter.SpreadAngle = Vector2.new(35, 35)
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Acceleration = Vector3.new(0, -8, 0)
	emitter.Rate = rate
	emitter.Parent = parent
	return emitter
end

local function clearEffects()
	if beam then
		beam:Destroy()
		beam = nil
	end
	if fromAttachment then
		fromAttachment:Destroy()
		fromAttachment = nil
	end
	if targetAttachment then
		targetAttachment:Destroy()
		targetAttachment = nil
	end
	if sparkles then
		sparkles:Destroy()
		sparkles = nil
	end
	if burst then
		burst:Destroy()
		burst = nil
	end
	collector = nil
end

-- Kendi platformumuzu bulunca efektleri bir kez kurar
local function ensureSetup(): boolean
	local found = findOwnCollector()
	if found and found == collector and found:IsDescendantOf(Workspace) then
		return true
	end
	clearEffects()
	if not found then
		return false
	end
	collector = found
	sparkles = makeEmitter(found, GREEN, 0)
	burst = makeEmitter(found, GOLD, 0)
	local attachment = Instance.new("Attachment")
	attachment.Position = Vector3.new(0, 1, 0)
	attachment.Parent = found
	targetAttachment = attachment
	return true
end

local function ensureBeam(): Beam?
	local character = localPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not targetAttachment then
		return nil
	end
	if
		beam
		and beam.Parent
		and beam.Attachment0
		and beam.Attachment0.Parent == root
		and beam.Attachment1 == targetAttachment
	then
		return beam
	end
	if beam then
		beam:Destroy()
	end
	if fromAttachment then
		fromAttachment:Destroy()
	end
	local from = Instance.new("Attachment")
	fromAttachment = from
	from.Name = "GuideAttachment"
	from.Position = Vector3.new(0, -2.5, 0)
	from.Parent = root

	local newBeam = Instance.new("Beam")
	newBeam.Attachment0 = from
	newBeam.Attachment1 = targetAttachment
	newBeam.Color = ColorSequence.new(GREEN)
	newBeam.LightEmission = 1
	newBeam.FaceCamera = true
	newBeam.Width0 = 0.6
	newBeam.Width1 = 0.6
	newBeam.Transparency = NumberSequence.new(0.25)
	newBeam.Enabled = false
	newBeam.Parent = root
	beam = newBeam
	return newBeam
end

local function onState(state: PlayerSave)
	if not ensureSetup() then
		return
	end
	local cap = FarmMath.getStorageCap(state)
	local auto = FarmMath.hasAutoCollect(state)
	if sparkles then
		sparkles.Rate = if not auto
				and state.stored >= 1
				and localPlayer:GetAttribute("ReducedMotion") ~= true
				and localPlayer:GetAttribute("EffectsQuality") ~= "low"
			then 6
			else 0
	end
	wantGuide = not auto and cap > 0 and state.stored / cap >= GUIDE_RATIO
end

local lastCheck = 0
RunService.Heartbeat:Connect(function()
	if os.clock() - lastCheck < 0.2 then
		return
	end
	lastCheck = os.clock()
	local state = ClientState.get()
	if state then
		onState(state)
	end
	if not collector then
		return
	end
	local currentBeam = ensureBeam()
	if not currentBeam then
		return
	end
	local character = localPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local near = root ~= nil and (root.Position - (collector :: BasePart).Position).Magnitude < GUIDE_HIDE_DISTANCE
	currentBeam.Enabled = wantGuide and not near
end)

ClientState.onChanged(onState)
Remotes.get("Notify").OnClientEvent:Connect(function(_message: string, kind: string?, amount: number?)
	if kind ~= "money" then
		return
	end
	if not ensureSetup() then
		return
	end
	local reduced = localPlayer:GetAttribute("ReducedMotion") == true
	local quality = localPlayer:GetAttribute("EffectsQuality")
	if burst and not reduced then
		burst:Emit(if quality == "low" then 8 elseif quality == "high" then 40 else 20)
	end
	local part = collector
	if typeof(amount) == "number" and part then
		WorldUi.floatingMoney(part, `+{FarmMath.formatMoney(amount)}`, reduced)
	end
end)
