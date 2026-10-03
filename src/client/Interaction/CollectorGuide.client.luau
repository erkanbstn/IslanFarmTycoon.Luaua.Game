--!strict
-- Oyuncuyu para toplama platformuna yönlendirir:
--  - Depo dolmaya başlayınca karakterden platforma yeşil bir yol çizgisi
--  - Platformda para varken parıltı; toplarken platformun kenarından kısa kavisle merkeze akan altın paralar
--    (client-assets/Coin: miktarın depo kapasitesine oranına göre küçük/orta/büyük görünüm) ve yükselen "+$X" yazısı

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local GameTypes = require(Shared:WaitForChild("GameTypes"))
local FarmMath = require(Shared:WaitForChild("Modules"):WaitForChild("FarmMath"))
local ClientState = require(script.Parent.Parent:WaitForChild("Core"):WaitForChild("ClientState"))
local ClientModelAssets = require(script.Parent.Parent:WaitForChild("Core"):WaitForChild("ClientModelAssets"))
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
	-- İlk adımlar (Onboarding) parayı toplamayı öğretirken ışın depo dolmadan da görünür
	wantGuide = not auto
		and cap > 0
		and (state.stored / cap >= GUIDE_RATIO or localPlayer:GetAttribute("TutorialGuide") == true)
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

-- Para akışı: toplama anında platformun kenarındaki 2-3 noktadan paralar 0.8-1.5 stud yükselip kısa kavisle merkeze (+0.7 yukarı)
-- toplanır, son %20'de küçülür ve solar. Yalnız bu dosyadaki Heartbeat sürer; aynı anda en çok MAX_COINS model, fazlası birleştirilir.
local MAX_COINS = 8
local COIN_DURATION = 0.8
local COIN_STAGGER = 0.05
local SHRINK_FROM = 0.8
type Flight = {
	model: Model,
	start: Vector3,
	target: Vector3,
	lift: number,
	born: number,
	spin: number,
	scale: number,
}
local flights: { Flight } = {}
local coinFolder: Folder? = nil

local function coinContainer(): Folder
	if coinFolder and coinFolder.Parent then
		return coinFolder
	end
	local folder = Instance.new("Folder")
	folder.Name = "LocalCoinFlight"
	folder.Parent = Workspace
	coinFolder = folder
	return folder
end

local function setTransparency(model: Model, value: number)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Transparency = value
		end
	end
end

-- Gösterim kademesi (yalnız görsel eşik): miktar / depo kapasitesi
local function coinSet(ratio: number?, quality: string?, reduced: boolean): { string }
	if reduced or quality == "low" then
		return { "Coin_Small" }
	end
	if ratio == nil or ratio < 0.25 then
		return { "Coin_Small", "Coin_Small", "Coin_Small" }
	elseif ratio < 0.75 then
		return { "Coin_Stack", "Coin_Stack", "Coin_Small", "Coin_Small" }
	end
	return { "Coin_Stack", "Coin_Stack", "CoinBurst_Chunk", "CoinBurst_Chunk", "CoinBurst_Chunk" }
end

local function launchCoins(part: BasePart, ratio: number?, quality: string?, reduced: boolean): boolean
	local names = coinSet(ratio, quality, reduced)
	local launched = false
	local radius = math.min(part.Size.X, part.Size.Z) * 0.4
	local top = part.Position.Y + part.Size.Y / 2
	local target = Vector3.new(part.Position.X, top + 0.7, part.Position.Z)
	local now = os.clock()
	local seed = math.random() * math.pi * 2
	for index, name in names do
		if #flights >= MAX_COINS then
			break
		end
		local model = ClientModelAssets.clone("Coin", name)
		if not model then
			break
		end
		launched = true
		local angle = seed + (index - 1) * (math.pi * 2 / #names)
		local start = Vector3.new(
			part.Position.X + math.cos(angle) * radius,
			top + 0.2,
			part.Position.Z + math.sin(angle) * radius
		)
		model:PivotTo(CFrame.new(if reduced then target else start))
		model.Parent = coinContainer()
		setTransparency(model, 1) -- gecikmeli başlayan para ilk karede görünmesin
		table.insert(flights, {
			model = model,
			start = start,
			target = target,
			lift = 0.8 + math.random() * 0.7,
			born = now + (index - 1) * COIN_STAGGER,
			spin = (math.random() - 0.5) * math.pi * 2,
			scale = 1,
		})
	end
	return launched
end

RunService.Heartbeat:Connect(function()
	if #flights == 0 then
		return
	end
	local now = os.clock()
	local reduced = localPlayer:GetAttribute("ReducedMotion") == true
	for index = #flights, 1, -1 do
		local flight = flights[index]
		local t = (now - flight.born) / COIN_DURATION
		if t >= 1 or not flight.model.Parent then
			flight.model:Destroy()
			table.remove(flights, index)
		elseif t >= 0 then
			if flight.model:GetAttribute("Shown") ~= true then
				flight.model:SetAttribute("Shown", true)
				setTransparency(flight.model, 0)
			end
			if reduced then
				-- Hareketi azalt: tek sabit para platformda görünür ve solar (kavis/dönüş/küçülme yok)
				if t > 0.5 then
					setTransparency(flight.model, math.clamp((t - 0.5) * 2, 0, 1))
				end
			else
				local eased = t * t * (3 - 2 * t)
				local position = flight.start:Lerp(flight.target, eased)
					+ Vector3.new(0, math.sin(math.pi * t) * flight.lift, 0)
				flight.model:PivotTo(CFrame.new(position) * CFrame.Angles(0, flight.spin * t, 0))
				if t > SHRINK_FROM then
					local scale = math.max(0.05, 1 - (t - SHRINK_FROM) / (1 - SHRINK_FROM) * 0.95)
					flight.model:ScaleTo(flight.model:GetScale() * scale / flight.scale)
					flight.scale = scale
				end
			end
		end
	end
end)

ClientState.onChanged(onState)
Remotes.get("Notify").OnClientEvent:Connect(function(_message: string, kind: string?, amount: number?)
	-- Yalnız gerçek para toplama (EconomyService) miktar taşır; gönderim/diğer para bildirimleri toplama efekti çalıştırmaz
	if kind ~= "money" or typeof(amount) ~= "number" then
		return
	end
	if not ensureSetup() then
		return
	end
	local reduced = localPlayer:GetAttribute("ReducedMotion") == true
	local quality = localPlayer:GetAttribute("EffectsQuality")
	local part = collector
	if not part then
		return
	end
	local state = ClientState.get()
	local cap = if state then FarmMath.getStorageCap(state) else 0
	local launched = launchCoins(part, if cap > 0 then amount / cap else nil, tostring(quality), reduced)
	-- Para modelleri yoksa eski altın parçacık patlaması
	if not launched and burst and not reduced then
		burst:Emit(if quality == "low" then 8 elseif quality == "high" then 40 else 20)
	end
	WorldUi.floatingMoney(part, `+{FarmMath.formatMoney(amount)}`, reduced)
end)
