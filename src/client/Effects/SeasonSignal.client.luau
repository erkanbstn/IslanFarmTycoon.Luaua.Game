--!strict
-- Hayvan mevsim/hava göstergesi (sadece görsel, sadece bu oyuncunun ekranında): gelir çarpanı artıya geçen hayvanın ALTINDA
-- yeşil, eksiye düşenin altında kırmızı zemin ışıması olur (client-assets/Season/SeasonGlow_Good|Bad: yassı oval taban, halkalar ve
-- yönlü işaretler; hayvanın parçası olarak taşınır, nabız/işaret animasyonu bu dosyada). Bu modeller varsa isim etiketi gizlenir;
-- yoksa (geçiş dönemi) eski gösterge sürer: etiketin kenarlığı yeşil/kırmızı.
-- Sinyal `FarmMath.getSeasonEffect` ile hesaplanır (Mevsim çubuğu ile aynı hesap) ve OLAY tabanlıdır:
-- mevsim/hava/bölge uyumu/hayvan listesi değişince yeniden hesaplanır. Yalnız ışıma animasyonu 15 Hz çalışır.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local FarmMath = require(Shared:WaitForChild("Modules"):WaitForChild("FarmMath"))
local Environment = require(Shared:WaitForChild("Modules"):WaitForChild("Environment"))
local UiTheme = require(Shared:WaitForChild("UiTheme"))
local Core = script.Parent.Parent:WaitForChild("Core")
local ClientState = require(Core:WaitForChild("ClientState"))
local StartupGate = require(Core:WaitForChild("StartupGate"))
local ClientModelAssets = require(Core:WaitForChild("ClientModelAssets"))
local EffectSettings = require(Core:WaitForChild("EffectSettings"))

local SeasonGlow = require(script.Parent:WaitForChild("SeasonGlow"))

local Color = UiTheme.Color

local STROKE_NAME = "SeasonStroke"
local STROKE_THICKNESS = 2.5

local tracked: { [Model]: RBXScriptConnection } = {}

local GLOW_NAME = "SeasonGlow"
local GLOW_TEMPLATES = {
	good = ClientModelAssets.find("Season", "SeasonGlow_Good"),
	bad = ClientModelAssets.find("Season", "SeasonGlow_Bad"),
}
local USE_GLOW = GLOW_TEMPLATES.good ~= nil and GLOW_TEMPLATES.bad ~= nil
local glows: { [Model]: SeasonGlow.Glow } = {}

-- Işıma hayvanın ayak izine ölçeklenir (model birim yarıçaplı) ve hayvanın zemin/su seviyesine konur; hayvanın parçası olarak taşınır
local function buildGlow(model: Model, kind: string): Model?
	local template = GLOW_TEMPLATES[kind]
	local body = model.PrimaryPart or model:FindFirstChild("Body")
	if not (template and body and body:IsA("BasePart")) then
		return nil
	end
	local glow = template:Clone()
	glow.Name = GLOW_NAME
	glow:SetAttribute("Kind", kind)
	local size = model:GetExtentsSize()
	glow:ScaleTo(math.max(0.8, math.max(size.X, size.Z) * 0.5 * 0.9))
	local boxCf, boxSize = model:GetBoundingBox()
	local swimDepth = model:GetAttribute("SwimDepthOffset")
	local y = if typeof(swimDepth) == "number" and swimDepth > 0
		then body.Position.Y + swimDepth + 0.05
		else boxCf.Position.Y - boxSize.Y / 2 + 0.05
	local look = body.CFrame.LookVector
	glow:PivotTo(CFrame.new(body.Position.X, y, body.Position.Z) * CFrame.Angles(0, math.atan2(-look.X, -look.Z), 0))
	for _, part in glow:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide, part.CanQuery, part.CanTouch = false, false, false
		end
	end
	glow.Parent = model
	return glow
end

local function applyGlow(model: Model, signal: number)
	local record = glows[model]
	local existing: Model? = if record then record.model else nil
	if existing and not existing.Parent then
		existing = nil
		glows[model] = nil
	end
	local kind = if signal > 0 then "good" elseif signal < 0 then "bad" else nil
	if existing and (kind == nil or existing:GetAttribute("Kind") ~= kind) then
		existing:Destroy()
		glows[model] = nil
		existing = nil
	end
	if kind and not existing then
		local glow = buildGlow(model, kind)
		if glow then
			glows[model] = SeasonGlow.capture(glow)
		end
	end
end

-- Nabız ve işaret dalgası: yalnız saydamlık oynar (parçalar hayvanla birlikte taşındığı için konum oynamaz). Düşük kalitede
-- ya da hareketi azalt açıkken taban sabit kalır.
local PULSE_INTERVAL = 1 / 15
local pulseClock = 0
RunService.Heartbeat:Connect(function(dt: number)
	pulseClock += dt
	if pulseClock < PULSE_INTERVAL then
		return
	end
	pulseClock = 0
	if next(glows) == nil then
		return
	end
	local low = EffectSettings.quality() == "low"
	local reduced = EffectSettings.reducedMotion()
	local now = os.clock()
	for model, glow in glows do
		if not glow.model.Parent then
			glows[model] = nil
			continue
		end
		SeasonGlow.update(glow, now, low, reduced)
	end
end)

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
	if USE_GLOW then
		-- Zemin ışıması varken isim etiketi gösterilmez (kalabalık görünüyordu); ırk rozeti ayrı etikettir ve kalır
		if tag and tag:IsA("BillboardGui") then
			tag.Enabled = false
		end
		applyGlow(model, compute(model))
		return
	end
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
	if not instance:IsA("Model") or tracked[instance] then
		return
	end
	apply(instance)
	-- Etiket model ile birlikte ya da biraz sonra gelebilir
	tracked[instance] = instance.DescendantAdded:Connect(function(descendant: Instance)
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
			local connection = tracked[instance]
			if connection then
				connection:Disconnect()
				tracked[instance] = nil
			end
			local glow = glows[instance]
			if glow then
				glow.model:Destroy()
				glows[instance] = nil
			end
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
