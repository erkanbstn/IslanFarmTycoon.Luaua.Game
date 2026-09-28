--!strict
-- Oyunun açılış yükleme ekranı (ReplicatedFirst: oyunda ilk çalışan client scripti).
-- Roblox'un düz yükleme ekranı yerine gösterilir; dünya yüklenip karakter adasında doğunca kaybolur.
-- UiTheme aynı kaynak dosyadan ReplicatedFirst'a da Rojo ile eşlenir.

local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local TweenService = game:GetService("TweenService")

local Theme = require(ReplicatedFirst:WaitForChild("UiTheme"))
local PANEL = Theme.Color.Panel
local SURFACE = Theme.Color.SurfaceRaised
local GOLD = Theme.Color.Gold
local GREEN = Theme.Color.Green
local MUTED = Theme.Color.TextMuted
local FREDOKA = Theme.Font.Display
local BUILDER = Theme.Font.Body

local MIN_SECONDS = 1.2
local MAX_SECONDS = 25

local player = Players.LocalPlayer
local started = os.clock()

local gui = Instance.new("ScreenGui")
gui.Name = "LoadingScreen"
gui.IgnoreGuiInset = true
gui.DisplayOrder = 100
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

-- CanvasGroup: kaybolurken her şey birlikte solar
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

-- Sırayla zıplayan hayvan ikonları
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
local status = label("Dünya yükleniyor", BUILDER, Theme.TextSize.LoadingStatus, MUTED, 120, 64)
-- Tema/GUI senkronizasyonu eksikse varsayılan ekranı erkenden kaldırıp boş gökyüzü gösterme.
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

-- Belirsiz ilerleme: soldan sağa kayan dolgu
local fill = Instance.new("Frame")
fill.Size = UDim2.fromScale(0.35, 1)
fill.Position = UDim2.fromScale(-0.35, 0)
fill.BackgroundColor3 = GREEN
fill.Parent = track
local fillCorner = Instance.new("UICorner")
fillCorner.CornerRadius = UDim.new(1, 0)
fillCorner.Parent = fill

local running = true
task.spawn(function()
	local step = 0
	while running do
		step += 1
		-- İkonlar
		local icon = iconLabels[(step - 1) % #iconLabels + 1]
		local basePosition = icon.Position
		TweenService:Create(icon, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = basePosition - UDim2.fromOffset(0, 12),
		}):Play()
		task.delay(0.18, function()
			if not running or not icon.Parent then
				return
			end
			TweenService:Create(icon, TweenInfo.new(0.22, Enum.EasingStyle.Bounce), { Position = basePosition }):Play()
		end)
		-- Çubuk
		if step % 3 == 1 then
			fill.Position = UDim2.fromScale(-0.35, 0)
			TweenService:Create(fill, TweenInfo.new(1.1, Enum.EasingStyle.Sine), { Position = UDim2.fromScale(1, 0) })
				:Play()
		end
		task.wait(0.4)
	end
end)

-- Tek bekleme bütün aşamaları kapsar; zaman aşımında boş oyuna geçmek yerine açık durum göster.
while true do
	local dataStatus = player:GetAttribute("DataStatus")
	local characterReady = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if
		game:IsLoaded()
		and characterReady
		and dataStatus == "Active"
		and player:GetAttribute("WorldReady") == true
		and player:GetAttribute("ClientStateReady") == true
	then
		break
	end
	if dataStatus == "Failed" then
		status.Text = tostring(player:GetAttribute("DataError") or "Kayıt yüklenemedi. Lütfen yeniden katıl.")
	elseif os.clock() - started > MAX_SECONDS then
		status.Text = "Yükleme uzadı. Bağlantını kontrol et; bekleyebilir veya yeniden katılabilirsin."
	elseif not game:IsLoaded() then
		status.Text = "Dünya yükleniyor"
	elseif dataStatus ~= "Active" then
		status.Text = "Çiftlik kaydın yükleniyor"
	else
		status.Text = "Çiftliğin hazırlanıyor"
	end
	task.wait(0.2)
end

-- 3) Kısa bir an etraf yüklensin; ekran çok hızlı yanıp sönmesin
status.Text = "Neredeyse hazır"
task.wait(math.max(0.4, MIN_SECONDS - (os.clock() - started)))

local fade = TweenService:Create(root, TweenInfo.new(0.6, Enum.EasingStyle.Quad), { GroupTransparency = 1 })
fade:Play()
fade.Completed:Wait()
running = false
gui:Destroy()
