--!strict
-- Hayvan mevsim/hava göstergesi (sadece görsel, sadece bu oyuncunun ekranında): gelir çarpanı artıya geçen hayvanın isim
-- etiketinin kenarlığı yeşil, eksiye düşenin kırmızı olur; nötr hayvanda kenarlık yoktur. Dünyaya hiçbir parça/parçacık/halka eklenmez
-- (öncekiler yer halkası, ok ve ışık sütunuydu: gaz ya da dikdörtgen gibi görünüyordu).
-- Sinyal `FarmMath.getSeasonEffect` ile hesaplanır (Mevsim çubuğu ile aynı hesap) ve OLAY tabanlıdır:
-- mevsim/hava/bölge uyumu/hayvan listesi değişince yeniden hesaplanır; zamanlayıcı ya da kare başı iş yoktur.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local FarmMath = require(Shared:WaitForChild("Modules"):WaitForChild("FarmMath"))
local Environment = require(Shared:WaitForChild("Modules"):WaitForChild("Environment"))
local UiTheme = require(Shared:WaitForChild("UiTheme"))
local Core = script.Parent.Parent:WaitForChild("Core")
local ClientState = require(Core:WaitForChild("ClientState"))
local StartupGate = require(Core:WaitForChild("StartupGate"))

local Color = UiTheme.Color

local STROKE_NAME = "SeasonStroke"
local STROKE_THICKNESS = 2.5

local tracked: { [Model]: boolean } = {}

local function compute(model: Model): number
	local state = ClientState.get()
	local uid = model:GetAttribute("Uid")
	if not state or typeof(uid) ~= "string" then
		return 0
	end
	for _, animal in state.animals do
		if animal.uid == uid then
			return FarmMath.getSeasonEffect(state, animal.animalId, animal.zoneId).signal
		end
	end
	return 0
end

-- Etiketin yuvarlak kutusuna (Pill) renkli kenarlık koyar/kaldırır
local function apply(model: Model)
	local tag = model:FindFirstChild("NameTag", true)
	local pill = if tag then tag:FindFirstChild("Pill") else nil
	if not pill then
		return
	end
	local signal = compute(model)
	local stroke = pill:FindFirstChild(STROKE_NAME)
	if signal == 0 then
		if stroke then
			stroke:Destroy()
		end
		return
	end
	local ring: UIStroke
	if stroke and stroke:IsA("UIStroke") then
		ring = stroke
	else
		ring = Instance.new("UIStroke")
		ring.Name = STROKE_NAME
		ring.Thickness = STROKE_THICKNESS
		ring.Transparency = 0.1
		ring.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		ring.Parent = pill
	end
	ring.Color = if signal > 0 then Color.Green else Color.Red
end

local function recomputeAll()
	for model in tracked do
		apply(model)
	end
end

-- Hayvan görselleri: etiket eklenince/çıkınca izle (StreamingEnabled parçaları sonradan getirir/kaldırır)
local function onAdded(instance: Instance)
	if not instance:IsA("Model") then
		return
	end
	tracked[instance] = true
	apply(instance)
	-- Etiket model ile birlikte ya da biraz sonra gelebilir
	instance.DescendantAdded:Connect(function(descendant: Instance)
		if descendant.Name == "Pill" then
			apply(instance)
		end
	end)
end

task.spawn(function()
	StartupGate.wait(2)
	CollectionService:GetInstanceAddedSignal("Animal"):Connect(onAdded)
	CollectionService:GetInstanceRemovedSignal("Animal"):Connect(function(instance: Instance)
		if instance:IsA("Model") then
			tracked[instance] = nil
		end
	end)
	for _, instance in CollectionService:GetTagged("Animal") do
		onAdded(instance)
	end
	ClientState.onChanged(function(_state, structural)
		if structural then
			recomputeAll()
		end
	end)
	Environment.onChanged(recomputeAll)
end)
