--!strict
-- Altın hayvan (rastgele olay): pencere açıkken etkin çiftlikteki bir hayvan parlar ve üstünde "Topla" düğmesi çıkar.
-- Hangi hayvanın parladığı Golden.current ile hesaplanır (sunucu aynı hesapla ödülü doğrular); burada yalnızca görsel.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local FarmMath = require(Shared:WaitForChild("Modules"):WaitForChild("FarmMath"))
local Golden = require(Shared:WaitForChild("Modules"):WaitForChild("Golden"))
local ClientState = require(script.Parent.Parent:WaitForChild("Core"):WaitForChild("ClientState"))
local UiKit = require(script.Parent.Parent:WaitForChild("Ui"):WaitForChild("UiKit"))
local PurchaseController = require(script.Parent.Parent:WaitForChild("Core"):WaitForChild("PurchaseController"))

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local CHECK_SECONDS = 0.5

local highlight: Highlight? = nil
local billboard: BillboardGui? = nil
local shownUid: string? = nil
local shownModel: Model? = nil
local countdown: TextLabel? = nil
local shownEndsAt = 0

local PROXIMITY_CHECK_SECONDS = 0.12
local CLAIM_RETRY_SECONDS = 1.2
local CLAIM_REACH = 6 -- hayvanın sınır kutusuna bu kadar yaklaşınca otomatik toplanır
local lastClaimAttempt = -math.huge

local function findModel(uid: string): Model?
	for _, instance in CollectionService:GetTagged("Animal") do
		if instance:IsA("Model") and instance:GetAttribute("Uid") == uid and instance:IsDescendantOf(Workspace) then
			return instance
		end
	end
	return nil
end

local function clear()
	if highlight then
		highlight:Destroy()
		highlight = nil
	end
	if billboard then
		billboard:Destroy()
		billboard = nil
	end
	countdown = nil
	shownUid = nil
	shownModel = nil
end

-- Pencere kapanınca fırsat kaybolur: kalan süre düğmenin altında geri sayar
local function updateCountdown()
	local label = countdown
	if label then
		label.Text = `{math.max(0, math.ceil(shownEndsAt - Workspace:GetServerTimeNow()))} sn`
	end
end

local function show(event: Golden.Event, model: Model)
	local anchor = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	if not anchor then
		return
	end
	local glow = Instance.new("Highlight")
	glow.Name = "GoldenGlow"
	glow.FillColor = UiKit.Color.Gold
	glow.FillTransparency = 0.5
	glow.OutlineColor = Color3.new(1, 1, 1)
	glow.DepthMode = Enum.HighlightDepthMode.Occluded
	glow.Adornee = model
	glow.Parent = model
	highlight = glow

	local _, boxSize = model:GetBoundingBox()
	local gui = Instance.new("BillboardGui")
	gui.Name = "GoldenClaim"
	gui.Adornee = anchor
	gui.Size = UDim2.fromOffset(150, 62)
	gui.StudsOffsetWorldSpace = Vector3.new(0, boxSize.Y / 2 + 3.5, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 150
	gui.ResetOnSpawn = false
	gui.Parent = playerGui
	local button = UiKit.button(gui, `Topla · {FarmMath.formatMoney(event.reward)}`, "primary")
	button.Size = UDim2.new(1, 0, 0, 40)
	local timer = Instance.new("TextLabel")
	timer.BackgroundTransparency = 1
	timer.Position = UDim2.fromOffset(0, 42)
	timer.Size = UDim2.new(1, 0, 0, 18)
	timer.FontFace = UiKit.Font.Bold
	timer.TextSize = 16
	timer.TextColor3 = UiKit.Color.Gold
	timer.TextStrokeTransparency = 0.4
	timer.Parent = gui
	countdown = timer
	shownEndsAt = event.endsAt
	button.Activated:Connect(function()
		if button.Active then
			PurchaseController.submit("RequestClaimGolden", "golden")
		end
	end)
	billboard = gui
	updateCountdown()
	shownUid = event.uid
	shownModel = model
end

local elapsed = 0
RunService.Heartbeat:Connect(function(dt: number)
	elapsed += dt
	if elapsed < CHECK_SECONDS then
		return
	end
	elapsed = 0
	local state = ClientState.get()
	local event = if state then Golden.current(state, localPlayer.UserId, Workspace:GetServerTimeNow()) else nil
	if not event then
		if shownUid then
			clear()
		end
		return
	end
	if shownUid == event.uid and billboard and billboard.Parent then
		updateCountdown()
		return
	end
	local model = findModel(event.uid)
	if not model then
		return -- Hayvan henüz yüklenmedi (streaming); bir sonraki turda tekrar dene
	end
	clear()
	show(event, model)
end)

-- Parlayan hayvanın yanına gelince (üstünden geçince) otomatik topla; düğme yedek olarak kalır.
-- Sunucu ödülü yine Golden.current ile doğrular; burada yalnızca tetikleme var.
local proximityElapsed = 0
RunService.Heartbeat:Connect(function(dt: number)
	proximityElapsed += dt
	if proximityElapsed < PROXIMITY_CHECK_SECONDS then
		return
	end
	proximityElapsed = 0
	local model = shownModel
	if not model or not model.Parent or not shownUid then
		return
	end
	local now = os.clock()
	if now - lastClaimAttempt < CLAIM_RETRY_SECONDS then
		return
	end
	local root = localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end
	local boxCf, boxSize = model:GetBoundingBox()
	local offset = root.Position - boxCf.Position
	local flat = math.sqrt(offset.X * offset.X + offset.Z * offset.Z)
	local reach = math.max(boxSize.X, boxSize.Z) / 2 + CLAIM_REACH
	if flat <= reach and math.abs(offset.Y) <= boxSize.Y / 2 + 8 then
		lastClaimAttempt = now
		PurchaseController.submit("RequestClaimGolden", "golden")
	end
end)
