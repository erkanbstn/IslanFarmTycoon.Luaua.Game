--!strict
-- Yetişkin hayvanların üstünde arada bir sönük "+$X" çıkıp kaybolur: gelirin nereden geldiğini gösterir.
-- Yalnızca bu client'ta, yalnızca kendi çiftliğinin yakınındaki hayvanlarda; sunucuya yük yok.
-- Sınırlı havuz: aynı anda en fazla POOL_SIZE baloncuk vardır.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local FarmMath = require(Shared:WaitForChild("Modules"):WaitForChild("FarmMath"))
local ClientState = require(script.Parent.Parent:WaitForChild("Core"):WaitForChild("ClientState"))
local UiKit = require(script.Parent:WaitForChild("UiKit"))

local player = Players.LocalPlayer
local NEAR_DISTANCE = 42 -- Yalnızca kameraya bu kadar yakın hayvanlar
local POOL_SIZE = 6
local LIFETIME = 1.8
local RISE = 3.2 -- stud

-- Kalite: (baloncuk aralığı sn, tek seferde en fazla)
local QUALITY = {
	low = { interval = 6, burst = 1 },
	medium = { interval = 3.5, burst = 2 },
	high = { interval = 2.5, burst = 3 },
}

type Bubble = { gui: BillboardGui, label: TextLabel, busy: boolean }
local pool: { Bubble } = {}
for _ = 1, POOL_SIZE do
	local gui = Instance.new("BillboardGui")
	gui.Name = "IncomeBubble"
	gui.Size = UDim2.fromOffset(84, 24)
	gui.StudsOffset = Vector3.new(0, 3, 0)
	gui.AlwaysOnTop = false
	gui.LightInfluence = 0
	gui.MaxDistance = NEAR_DISTANCE + 10
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.FontFace = UiKit.Font.Bold
	label.TextSize = UiKit.TextSize.Caption
	label.TextColor3 = UiKit.Color.Green
	label.TextStrokeColor3 = Color3.new(0, 0, 0)
	label.TextStrokeTransparency = 0.6
	label.TextTransparency = 1
	label.Parent = gui
	table.insert(pool, { gui = gui, label = label, busy = false })
end

-- Hayvan adı "cow_<uid>" biçimindedir
local function animalIdOf(model: Model): string?
	local id = string.match(model.Name, "^([^_]+)_")
	return id
end

local function isOwnAdult(model: Model): boolean
	if model:GetAttribute("Stage") ~= "adult" then
		return false
	end
	local plot: Instance? = model.Parent
	while plot and (not plot.Parent or plot.Parent.Name ~= "Plots") do
		plot = plot.Parent
	end
	return plot ~= nil
		and plot:GetAttribute("OwnerUserId") == player.UserId
		and plot:GetAttribute("MainFarmId") == player:GetAttribute("ActiveMainFarmId")
end

local function show(model: Model, text: string)
	local anchor = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	if not anchor then
		return
	end
	for _, bubble in pool do
		if bubble.busy then
			continue
		end
		bubble.busy = true
		bubble.gui.Adornee = anchor
		bubble.gui.StudsOffset = Vector3.new(0, 3, 0)
		bubble.label.Text = text
		bubble.label.TextTransparency = 0.25
		bubble.gui.Enabled = true
		local info = TweenInfo.new(LIFETIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(bubble.gui, info, { StudsOffset = Vector3.new(0, 3 + RISE, 0) }):Play()
		local fade = TweenService:Create(bubble.label, info, { TextTransparency = 1, TextStrokeTransparency = 1 })
		fade.Completed:Once(function()
			bubble.gui.Enabled = false
			-- API tanımı Adornee'yi zorunlu sayar; havuza dönerken gerçek boş hedefi koru.
			local target = (bubble.gui :: unknown) :: { Adornee: Instance? }
			target.Adornee = nil
			bubble.label.TextStrokeTransparency = 0.6
			bubble.busy = false
		end)
		fade:Play()
		return
	end
end

local function tick()
	if player:GetAttribute("ReducedMotion") == true then
		return
	end
	local state = ClientState.get()
	local camera = Workspace.CurrentCamera
	if not state or not camera then
		return
	end
	local quality = QUALITY[player:GetAttribute("EffectsQuality") :: string] or QUALITY.medium
	local cameraPosition = camera.CFrame.Position
	local candidates: { Model } = {}
	for _, instance in CollectionService:GetTagged("Animal") do
		if
			instance:IsA("Model")
			and instance:IsDescendantOf(Workspace)
			and (instance:GetPivot().Position - cameraPosition).Magnitude <= NEAR_DISTANCE
			and isOwnAdult(instance)
		then
			table.insert(candidates, instance)
		end
	end
	local shown = 0
	while shown < quality.burst and #candidates > 0 do
		local index = math.random(1, #candidates)
		local model = table.remove(candidates, index) :: Model
		local animalId = animalIdOf(model)
		if animalId then
			-- Baloncuk aralığı boyunca biriken gelir: gerçek kazançla aynı ölçek
			local income = FarmMath.getAnimalIncome(state, animalId) * quality.interval
			show(model, `+{FarmMath.formatMoney(math.max(1, math.round(income)))}`)
			shown += 1
		end
	end
end

-- Kalite değişse de aralık her turda yeniden okunur (0.5 sn'lik ölçüm)
local elapsed = 0
local nextAt = 2
local connection = RunService.Heartbeat:Connect(function(dt: number)
	elapsed += dt
	if elapsed < nextAt then
		return
	end
	elapsed = 0
	local quality = QUALITY[player:GetAttribute("EffectsQuality") :: string] or QUALITY.medium
	nextAt = quality.interval
	tick()
end)
script.Destroying:Connect(function()
	connection:Disconnect()
	for _, bubble in pool do
		bubble.gui:Destroy()
	end
end)
