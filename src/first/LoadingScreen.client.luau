--!strict
-- Oyunun açılış yükleme ekranı (ReplicatedFirst: oyunda ilk çalışan client scripti).
-- Roblox'un düz yükleme ekranı yerine gösterilir; dünya yüklenip karakter adasında doğunca kaybolur.

local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Theme = require(ReplicatedFirst:WaitForChild("UiTheme"))
local PANEL = Theme.Color.Panel
local SURFACE = Theme.Color.SurfaceRaised
local GOLD = Theme.Color.Gold
local GREEN = Theme.Color.Green
local MUTED = Theme.Color.TextMuted
local FREDOKA = Theme.Font.Display
local BUILDER = Theme.Font.Body

local MIN_SECONDS = 0.9
local MAX_SECONDS = 30
local SNAPSHOT_POLL = 1.0
local FORCE_ENTER_AFTER = 28

local player = Players.LocalPlayer
local started = os.clock()

local gui = Instance.new("ScreenGui")
gui.Name = "LoadingScreen"
gui.IgnoreGuiInset = true
gui.DisplayOrder = 100
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local root = Instance.new("CanvasGroup")
root.Size = UDim2.fromScale(1, 1)
root.BackgroundColor3 = PANEL
root.Parent = gui
local gradient = Instance.new("UIGradient")
gradient.Color = ColorSequence.new(PANEL:Lerp(GREEN, 0.12), PANEL)
gradient.Rotation = 90
gradient.Parent = root

local center = Instance.new("Frame")
center.AnchorPoint = Vector2.new(0.5, 0.5)
center.Position = UDim2.fromScale(0.5, 0.5)
center.Size = UDim2.new(1, -32, 0, 240)
local centerLimit = Instance.new("UISizeConstraint")
centerLimit.MaxSize = Vector2.new(420, 240)
centerLimit.Parent = center
center.BackgroundTransparency = 1
center.Parent = root

local function label(text: string, font: Font, size: number, color: Color3, y: number, height: number): TextLabel
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Position = UDim2.fromOffset(0, y)
	t.Size = UDim2.new(1, 0, 0, height)
	t.FontFace = font
	t.TextSize = size
	t.TextColor3 = color
	t.Text = text
	t.TextWrapped = true
	t.Parent = center
	return t
end

local icons = { "🐄", "🐔", "🐟", "🐎", "🐐" }
local iconLabels: { TextLabel } = {}
for index, icon in icons do
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.AnchorPoint = Vector2.new(0.5, 0)
	t.Position = UDim2.new(0.5, (index - 3) * 52, 0, 0)
	t.Size = UDim2.fromOffset(44, 44)
	t.TextScaled = true
	t.FontFace = BUILDER
	t.Text = icon
	t.Parent = center
	table.insert(iconLabels, t)
end

label("Ahır Tycoon", FREDOKA, Theme.TextSize.LoadingTitle, GOLD, 58, 64)
local status = label("Bağlanılıyor", BUILDER, Theme.TextSize.LoadingStatus, MUTED, 120, 64)
ReplicatedFirst:RemoveDefaultLoadingScreen()

local track = Instance.new("Frame")
track.AnchorPoint = Vector2.new(0.5, 0)
track.Position = UDim2.new(0.5, 0, 0, 200)
track.Size = UDim2.fromOffset(260, 8)
track.BackgroundColor3 = SURFACE
track.ClipsDescendants = true
track.Parent = center
local trackCorner = Instance.new("UICorner")
trackCorner.CornerRadius = UDim.new(1, 0)
trackCorner.Parent = track

local fill = Instance.new("Frame")
fill.Size = UDim2.fromScale(0.42, 1)
fill.Position = UDim2.fromScale(-0.42, 0)
fill.BackgroundColor3 = GREEN
fill.Parent = track
local fillCorner = Instance.new("UICorner")
fillCorner.CornerRadius = UDim.new(1, 0)
fillCorner.Parent = fill

local running = true
local animClock = 0
local animConnection = RunService.Heartbeat:Connect(function(dt: number)
	if not running then
		return
	end
	animClock += dt
	for index, icon in iconLabels do
		local phase = animClock * 2.0 + index * 0.85
		local bob = math.sin(phase) * 5
		icon.Position = UDim2.new(0.5, (index - 3) * 52, 0, bob)
	end
	local sweep = (math.sin(animClock * 1.1) + 1) * 0.5
	fill.Position = UDim2.fromScale(-0.42 + sweep * 1.0, 0)
end)

-- ReplicatedFirst'te IsLoaded() uzun süre false kalabilir; Loaded olayını arka planda bekle.
task.spawn(function()
	if not game:IsLoaded() then
		game.Loaded:Wait()
	end
end)

local farmStateSynced = player:GetAttribute("ClientStateReady") == true
player:GetAttributeChangedSignal("ClientStateReady"):Connect(function()
	if player:GetAttribute("ClientStateReady") == true then
		farmStateSynced = true
	end
end)

task.spawn(function()
	local remotesFolder = ReplicatedStorage:WaitForChild("Remotes", 90)
	if not remotesFolder then
		return
	end
	local playerState = remotesFolder:WaitForChild("PlayerState", 15)
	local requestState = remotesFolder:WaitForChild("RequestPlayerState", 15)
	if
		not playerState
		or not playerState:IsA("RemoteEvent")
		or not requestState
		or not requestState:IsA("RemoteEvent")
	then
		return
	end
	playerState.OnClientEvent:Connect(function()
		farmStateSynced = true
	end)
	local lastAsk = -math.huge
	while running and not farmStateSynced do
		if os.clock() - lastAsk >= SNAPSHOT_POLL then
			lastAsk = os.clock()
			requestState:FireServer()
		end
		task.wait(0.2)
	end
end)

local function characterReady(): boolean
	local character = player.Character
	return character ~= nil and character:FindFirstChild("HumanoidRootPart") ~= nil
end

local function canEnterGame(): boolean
	if player:GetAttribute("DataStatus") == "Failed" then
		return false
	end
	if player:GetAttribute("DataStatus") ~= "Active" then
		return false
	end
	if player:GetAttribute("WorldReady") ~= true then
		return false
	end
	if not characterReady() then
		return false
	end
	return farmStateSynced or player:GetAttribute("ClientStateReady") == true
end

while running do
	local elapsed = os.clock() - started
	local dataStatus = player:GetAttribute("DataStatus")

	if dataStatus == "Failed" then
		status.Text = tostring(player:GetAttribute("DataError") or "Kayıt yüklenemedi. Lütfen yeniden katıl.")
	elseif elapsed > FORCE_ENTER_AFTER and dataStatus == "Active" and player:GetAttribute("WorldReady") == true then
		-- Menü snapshot'ı gecikse bile oyuna gir (ClientState arka planda tamamlar).
		break
	elseif canEnterGame() then
		break
	elseif elapsed > MAX_SECONDS then
		status.Text = "Yükleme uzadı. Sunucu Output'unu kontrol et veya yeniden katıl."
	elseif dataStatus ~= "Active" then
		status.Text = "Çiftlik kaydın yükleniyor"
	elseif not characterReady() then
		status.Text = "Karakterin hazırlanıyor"
	elseif player:GetAttribute("WorldReady") ~= true then
		status.Text = "Çiftliğin hazırlanıyor"
	elseif not farmStateSynced then
		status.Text = "Menü verisi senkronize ediliyor"
	else
		status.Text = "Bağlanılıyor"
	end
	task.wait(0.12)
end

if player:GetAttribute("DataStatus") ~= "Failed" then
	status.Text = "Neredeyse hazır"
	task.wait(math.max(0.3, MIN_SECONDS - (os.clock() - started)))
end

running = false
animConnection:Disconnect()

local fade = TweenService:Create(root, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
	GroupTransparency = 1,
})
fade:Play()
fade.Completed:Wait()
gui:Destroy()
