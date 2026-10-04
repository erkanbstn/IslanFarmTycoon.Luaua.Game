--!strict
-- Koşma: bilgisayarda Shift basılı tutulunca, telefonda ekrandaki "Koş" düğmesiyle (aç/kapa).
-- Karakter hareketini client yönettiği için hız burada ayarlanır. Koşarken kamera hafifçe genişler.
-- Not: Shift, Roblox'un "Shift Lock" kamerasıyla çakışmasın diye default.project.json'da o özellik kapalı.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local ACTION = "Sprint"
local NORMAL_FOV = 70
local SPRINT_FOV = 80
local BRIDGE_FOV = 78 -- Köprüde (BridgeBoost) kamera hafifçe genişler
local FOV_TWEEN = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local localPlayer = Players.LocalPlayer
local sprinting = false
local cameraTween: Tween? = nil

local function getHumanoid(): Humanoid?
	local character = localPlayer.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function apply()
	local humanoid = getHumanoid()
	local onBridge = localPlayer:GetAttribute("OnBridge") == true
	if humanoid then
		local base = if sprinting then Config.SPRINT_SPEED else Config.WALK_SPEED
		local value = localPlayer:GetAttribute("MovementSpeedMultiplier")
		local equipment = if typeof(value) == "number" and value == value
			then math.clamp(value, 1, 1 + Config.MOVEMENT_SPEED_BONUS_CAP)
			else 1
		humanoid.WalkSpeed = base * equipment * (if onBridge then Config.BRIDGE_SPEED_MULTIPLIER else 1)
	end
	local camera = Workspace.CurrentCamera
	if camera then
		local fov = if sprinting then SPRINT_FOV elseif onBridge then BRIDGE_FOV else NORMAL_FOV
		if cameraTween then
			cameraTween:Cancel()
		end
		local tween = TweenService:Create(camera, FOV_TWEEN, { FieldOfView = fov })
		cameraTween = tween
		tween:Play()
	end
end
localPlayer:GetAttributeChangedSignal("OnBridge"):Connect(apply)
localPlayer:GetAttributeChangedSignal("MovementSpeedMultiplier"):Connect(apply)
Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(apply)

local function setSprinting(value: boolean)
	if sprinting == value then
		return
	end
	sprinting = value
	apply()
end

local function onAction(_name: string, state: Enum.UserInputState, input: InputObject): Enum.ContextActionResult
	if input.UserInputType == Enum.UserInputType.Touch then
		-- Telefonda basılı tutmak zor: düğme aç/kapa çalışır
		if state == Enum.UserInputState.Begin then
			setSprinting(not sprinting)
		end
	elseif state == Enum.UserInputState.Begin then
		setSprinting(true)
	elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
		setSprinting(false)
	end
	return Enum.ContextActionResult.Pass
end

UserInputService.WindowFocusReleased:Connect(function()
	setSprinting(false)
end)

ContextActionService:BindAction(ACTION, onAction, true, Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL3)
ContextActionService:SetTitle(ACTION, "Koş")
-- Roblox'un zıplama düğmesi sağ altta (en fazla ~90 px, alttan ~110 px'e kadar); koşu düğmesi onun hemen üstünde durur, çakışmaz.
ContextActionService:SetPosition(ACTION, UDim2.new(1, -120, 1, -205))

-- Yeniden doğunca normal hızla başla
localPlayer.CharacterAdded:Connect(function(character: Model)
	sprinting = false
	local humanoid = character:WaitForChild("Humanoid", 10)
	if localPlayer.Character == character and humanoid and humanoid:IsA("Humanoid") then
		apply()
	end
end)
if localPlayer.Character then
	apply()
end
