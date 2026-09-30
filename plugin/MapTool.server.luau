--!strict
-- Island Farm Tycoon Studio eklentisi: sabit işlemleri tek tıkla çalıştıran bir panel.
--   * Haritayı Kur      : haritayı DÜZENLEME modunda kurar, böylece place'e kaydedilir (Play gerekmez).
--   * Haritayı Doğrula  : MapBuilder.validate + harita yapı testi + dünya testi (sonuç panelde ve Output'ta).
--   * Harita Bilgisi    : place'teki harita sürümü, ada sayısı, meydan durumu.
--   * Rojo Kontrolü     : oyun kodu bu place'e senkronize mi?
-- Harita kodu tek kaynaktır: src/server/Services/MapBuilder.luau (eklenti kodun kopyasını taşımaz; her işlemde
-- Rojo ile gelen güncel kodu kopyalayıp çalıştırır). Testler eklentinin içinde gömülüdür (tests/*.spec.luau).
--
-- Kurulum (bir kez):  rojo build plugin.project.json --plugin IslandFarmTycoonHarita.rbxm

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")

-- Play sırasında panel görünmesin
if RunService:IsRunning() then
	return
end

local TAG = "[Island Farm Tycoon]"

---------------------------------------------------------------------------
-- Panel
---------------------------------------------------------------------------

local toolbar = plugin:CreateToolbar("Island Farm Tycoon")
local panelButton = toolbar:CreateButton("Panel", "Sabit işlemler panelini aç/kapat.", "")
local buildButton = toolbar:CreateButton(
	"Haritayı Kur",
	"Denizi, meydanı ve adaları koddan sıfırdan kurar. Plots/World ve merkezdeki Terrain alanı yenilenir (Ctrl+Z ile geri alınabilir).",
	""
)
panelButton.ClickableWhenViewportHidden = true
buildButton.ClickableWhenViewportHidden = true

-- Yeni Studio sürümleri CreateDockWidgetPluginGuiAsync ister, eskiler yalnızca CreateDockWidgetPluginGui bilir.
local widgetInfo = DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Right, false, false, 340, 520, 260, 300)
local pluginAny = plugin :: any
local hasAsync = pcall(function()
	return pluginAny.CreateDockWidgetPluginGuiAsync
end)
local widget: DockWidgetPluginGui = if hasAsync
	then pluginAny:CreateDockWidgetPluginGuiAsync("IslandFarmTycoonPanel", widgetInfo)
	else pluginAny:CreateDockWidgetPluginGui("IslandFarmTycoonPanel", widgetInfo)
widget.Title = "Island Farm Tycoon"
widget.Name = "IslandFarmTycoonPanel"

local COLORS = {
	background = Color3.fromRGB(32, 34, 40),
	button = Color3.fromRGB(58, 64, 78),
	buttonHover = Color3.fromRGB(76, 84, 102),
	text = Color3.fromRGB(235, 237, 242),
	muted = Color3.fromRGB(160, 166, 180),
	ok = Color3.fromRGB(110, 210, 130),
	warn = Color3.fromRGB(245, 200, 90),
	error = Color3.fromRGB(240, 110, 110),
	accent = Color3.fromRGB(70, 140, 220),
}

local root = Instance.new("Frame")
root.Size = UDim2.fromScale(1, 1)
root.BackgroundColor3 = COLORS.background
root.BorderSizePixel = 0
root.Parent = widget

local rootPadding = Instance.new("UIPadding")
rootPadding.PaddingTop = UDim.new(0, 8)
rootPadding.PaddingBottom = UDim.new(0, 8)
rootPadding.PaddingLeft = UDim.new(0, 8)
rootPadding.PaddingRight = UDim.new(0, 8)
rootPadding.Parent = root

local actionsFrame = Instance.new("Frame")
actionsFrame.Name = "Actions"
actionsFrame.BackgroundTransparency = 1
actionsFrame.Size = UDim2.new(1, 0, 0, 0)
actionsFrame.AutomaticSize = Enum.AutomaticSize.Y
actionsFrame.Parent = root
local actionsLayout = Instance.new("UIListLayout")
actionsLayout.Padding = UDim.new(0, 6)
actionsLayout.SortOrder = Enum.SortOrder.LayoutOrder
actionsLayout.Parent = actionsFrame

local logFrame = Instance.new("ScrollingFrame")
logFrame.Name = "Log"
logFrame.BackgroundColor3 = Color3.fromRGB(22, 24, 28)
logFrame.BorderSizePixel = 0
logFrame.ScrollBarThickness = 6
logFrame.CanvasSize = UDim2.new()
logFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
logFrame.Parent = root
local logLayout = Instance.new("UIListLayout")
logLayout.Padding = UDim.new(0, 2)
logLayout.SortOrder = Enum.SortOrder.LayoutOrder
logLayout.Parent = logFrame
local logPadding = Instance.new("UIPadding")
logPadding.PaddingLeft = UDim.new(0, 6)
logPadding.PaddingRight = UDim.new(0, 6)
logPadding.PaddingTop = UDim.new(0, 4)
logPadding.Parent = logFrame

-- Günlük alanı, eylemler düğmelerinin altını kaplar
local function layoutLog()
	local top = actionsFrame.AbsoluteSize.Y + 14
	logFrame.Position = UDim2.new(0, 0, 0, top)
	logFrame.Size = UDim2.new(1, 0, 1, -top)
end
actionsFrame:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutLog)

local logCount = 0
local function log(kind: string, text: string)
	logCount += 1
	local line = Instance.new("TextLabel")
	line.BackgroundTransparency = 1
	line.Size = UDim2.new(1, 0, 0, 0)
	line.AutomaticSize = Enum.AutomaticSize.Y
	line.TextWrapped = true
	line.TextXAlignment = Enum.TextXAlignment.Left
	line.TextYAlignment = Enum.TextYAlignment.Top
	line.Font = Enum.Font.Code
	line.TextSize = 13
	line.TextColor3 = if kind == "ok"
		then COLORS.ok
		elseif kind == "warn" then COLORS.warn
		elseif kind == "error" then COLORS.error
		else COLORS.text
	line.Text = `{if kind == "ok"
		then "✔ "
		elseif kind == "error" then "✖ "
		elseif kind == "warn" then "! "
		else "· "}{text}`
	line.LayoutOrder = logCount
	line.Parent = logFrame
	logFrame.CanvasPosition = Vector2.new(0, 1e6)
	if kind == "error" then
		warn(`{TAG} {text}`)
	else
		print(`{TAG} {text}`)
	end
end

local function clearLog()
	for _, child in logFrame:GetChildren() do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end
end

---------------------------------------------------------------------------
-- Taze kod yükleme
---------------------------------------------------------------------------

-- Studio require sonuçlarını önbelleğe alır; Rojo kodu güncellese bile eski hali çalışırdı.
-- Bu yüzden modüllerin kopyasını alıp kopyayı çalıştırıyoruz (her işlemde en güncel kod).
local function loadFreshMapBuilder(): (any, Instance)
	local shared = ReplicatedStorage:FindFirstChild("Shared")
	local server = ServerScriptService:FindFirstChild("Server")
	local services = server and server:FindFirstChild("Services")
	if not shared or not services then
		error("Oyun kodu bulunamadı. Önce 'rojo serve' çalıştırıp Rojo eklentisinden Connect'e bas.")
	end

	local sandbox = Instance.new("Folder")
	sandbox.Name = "AhirTycoonMapSandbox"
	shared:Clone().Parent = sandbox
	local servicesCopy = services:Clone()
	servicesCopy.Parent = sandbox

	local module = servicesCopy:FindFirstChild("MapBuilder")
	if not module or not module:IsA("ModuleScript") then
		sandbox:Destroy()
		error("MapBuilder modülü bulunamadı.")
	end
	local ok, result = pcall(require :: any, module)
	if not ok then
		sandbox:Destroy()
		error(result)
	end
	return result, sandbox
end

-- Taze MapBuilder ve Config ile bir işlem çalıştırır; sandbox her durumda temizlenir.
local function withFresh(callback: (mapBuilder: any, config: any) -> ())
	local mapBuilder, sandbox = loadFreshMapBuilder()
	local ok, err = pcall(function()
		local sharedCopy = sandbox:FindFirstChild("Shared") :: Instance
		local config = require(sharedCopy:FindFirstChild("Config") :: ModuleScript)
		callback(mapBuilder, config)
	end)
	sandbox:Destroy()
	if not ok then
		error(err, 0)
	end
end

---------------------------------------------------------------------------
-- Eylemler
---------------------------------------------------------------------------

local busy = false

local function buildMap()
	local recording = ChangeHistoryService:TryBeginRecording("Island Farm Tycoon haritasını kur")
	if not recording then
		log("error", "Geri alma kaydı açılamadı; harita değiştirilmedi.")
		return
	end
	log("info", "Harita kuruluyor (birkaç saniye sürebilir)...")
	local ok, err = pcall(function()
		withFresh(function(mapBuilder)
			mapBuilder.build(true)
		end)
	end)
	ChangeHistoryService:FinishRecording(
		recording,
		if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel
	)
	if ok then
		log("ok", "Harita kuruldu. Kaydetmek için Ctrl+S (ya da File → Publish).")
	else
		log("error", `Harita kurulamadı: {err}`)
	end
end

local function verifyMap()
	log("info", "Harita doğrulanıyor...")
	local ok, err = pcall(function()
		withFresh(function(mapBuilder, config)
			mapBuilder.validate()
			log("ok", "MapBuilder.validate(): harita sözleşmesi ve sürümü geçerli.")
			local context = { mapBuilder = mapBuilder, Config = config }
			for _, spec in
				{
					{
						name = "Harita yapısı (tema, tabela, meydan, düzen)",
						module = script:FindFirstChild("MapStructureSpec"),
					},
					{
						name = "Dünya (iskele, üretim noktaları, sanitizer)",
						module = script:FindFirstChild("WorldSpec"),
					},
				}
			do
				if not spec.module or not spec.module:IsA("ModuleScript") then
					log("error", `{spec.name}: test modülü eklentide yok (eklentiyi yeniden üret).`)
					continue
				end
				local specOk, specErr = pcall(function()
					(require(spec.module) :: any)(context)
				end)
				if specOk then
					log("ok", `{spec.name}: geçti.`)
				else
					log("error", `{spec.name}: {specErr}`)
				end
			end
		end)
	end)
	if not ok then
		log("error", `Doğrulama çalışmadı: {err}`)
	end
end

local function mapInfo()
	local plots = Workspace:FindFirstChild("Plots")
	if not plots then
		log("warn", "Place'te harita yok (Workspace.Plots bulunamadı). 'Haritayı Kur'a bas.")
		return
	end
	local version = plots:GetAttribute("MapVersion")
	log(
		"info",
		`Harita sürümü (place'te kayıtlı): {if typeof(version) == "number" then version else "bilinmiyor"}`
	)
	log("info", `Ada sayısı: {#plots:GetChildren()}`)
	local world = Workspace:FindFirstChild("World")
	local hub = world and world:FindFirstChild("Hub")
	log(if hub then "ok" else "warn", if hub then "Meydan (Hub) mevcut." else "Meydan (Hub) bulunamadı.")
	local vendors = 0
	if hub then
		for _, child in hub:GetChildren() do
			if string.sub(child.Name, 1, 7) == "Vendor_" then
				vendors += 1
			end
		end
	end
	log("info", `Meydandaki satıcı sayısı: {vendors}`)
	local sites = 0
	for _, plot in plots:GetChildren() do
		local folder = plot:FindFirstChild("Sites")
		if folder then
			sites += #folder:GetChildren()
		end
	end
	log("info", `Yapım alanı (çalışma anı nesnesi, kayıtlı haritada olmaz): {sites}`)
end

local function rojoCheck()
	local checks = {
		{ "ReplicatedStorage.Shared", ReplicatedStorage:FindFirstChild("Shared") },
		{ "ServerScriptService.Server", ServerScriptService:FindFirstChild("Server") },
		{
			"StarterPlayer.StarterPlayerScripts.Client",
			StarterPlayer:FindFirstChild("StarterPlayerScripts")
				and (StarterPlayer:FindFirstChild("StarterPlayerScripts") :: Instance):FindFirstChild("Client"),
		},
	}
	local allOk = true
	for _, check in checks do
		local found = check[2] ~= nil
		allOk = allOk and found
		log(if found then "ok" else "error", `{check[1]}: {if found then "var" else "YOK"}`)
	end
	if allOk then
		log("ok", "Oyun kodu bu place'e senkronize görünüyor.")
	else
		log("error", "Kod senkronize değil: 'rojo serve' çalıştır ve Rojo eklentisinden Connect'e bas.")
	end
end

type Action = { label: string, description: string, run: () -> (), accent: boolean? }

local actions: { Action } = {
	{
		label = "Haritayı Kur",
		description = "Haritayı koddan sıfırdan kurar. Sonra Ctrl+S ile kaydet.",
		run = buildMap,
		accent = true,
	},
	{
		label = "Haritayı Doğrula",
		description = "validate() + harita yapı testi + dünya testi. Kurulumdan sonra çalıştır.",
		run = verifyMap,
	},
	{ label = "Harita Bilgisi", description = "Place'teki sürüm, ada ve meydan durumu.", run = mapInfo },
	{ label = "Rojo Kontrolü", description = "Oyun kodu bu place'e senkronize mi?", run = rojoCheck },
	{ label = "Günlüğü Temizle", description = "Aşağıdaki sonuç listesini temizler.", run = clearLog },
}

local function runAction(action: Action)
	if busy then
		return
	end
	busy = true
	local ok, err = pcall(action.run)
	if not ok then
		log("error", tostring(err))
	end
	busy = false
end

for index, action in actions do
	local button = Instance.new("TextButton")
	button.Name = action.label
	button.LayoutOrder = index
	button.Size = UDim2.new(1, 0, 0, 44)
	button.BackgroundColor3 = if action.accent then COLORS.accent else COLORS.button
	button.BorderSizePixel = 0
	button.AutoButtonColor = true
	button.Text = ""
	button.Parent = actionsFrame
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = button
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(10, 4)
	title.Size = UDim2.new(1, -20, 0, 18)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 14
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = COLORS.text
	title.Text = action.label
	title.Parent = button
	local description = Instance.new("TextLabel")
	description.BackgroundTransparency = 1
	description.Position = UDim2.fromOffset(10, 22)
	description.Size = UDim2.new(1, -20, 0, 16)
	description.Font = Enum.Font.Gotham
	description.TextSize = 11
	description.TextXAlignment = Enum.TextXAlignment.Left
	description.TextColor3 = if action.accent then COLORS.text else COLORS.muted
	description.Text = action.description
	description.Parent = button
	button.Activated:Connect(function()
		runAction(action)
	end)
end
layoutLog()

panelButton.Click:Connect(function()
	widget.Enabled = not widget.Enabled
	panelButton:SetActive(widget.Enabled)
end)
widget:GetPropertyChangedSignal("Enabled"):Connect(function()
	panelButton:SetActive(widget.Enabled)
end)

-- Araç çubuğundaki hızlı düğme panelden bağımsız çalışır; sonuç panele ve Output'a yazılır.
buildButton.Click:Connect(function()
	buildButton:SetActive(false)
	widget.Enabled = true
	runAction(actions[1])
end)

log("info", "Panel hazır. Haritayı kurduktan sonra 'Haritayı Doğrula'yı çalıştır.")
