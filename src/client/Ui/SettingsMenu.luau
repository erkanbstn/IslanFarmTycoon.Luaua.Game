--!strict
-- Hareket azaltma yalnızca bu oturum içindir; dil ve grafik tercihi hesaba kaydedilir.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UiKit = require(script.Parent:WaitForChild("UiKit"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Localization = require(Shared:WaitForChild("Localization"))
local player = Players.LocalPlayer
local SettingsMenu = {}
local window: UiKit.Window? = nil

if player:GetAttribute("ReducedMotion") == nil then
	player:SetAttribute("ReducedMotion", false)
end

local function create(parent: Instance): UiKit.Window
	local created = UiKit.window(parent, {
		title = "Ayarlar",
		icon = "⚙️",
		tint = UiKit.Color.Blue,
		width = 380,
		maxHeight = 430,
		anchor = Vector2.new(0.5, 0.5),
		position = UDim2.fromScale(0.5, 0.5),
	})
	UiKit.text(
		created.list,
		"Görsel tercihler yalnızca bu oturumda geçerlidir. Gelirini ve oyun hızını değiştirmez. Dil tercihin kaydedilir.",
		"Caption"
	).LayoutOrder =
		1
	-- Başlık iki dilli: dili yanlış seçen oyuncu da menüyü bulabilsin.
	UiKit.text(created.list, "Dil / Language", "Heading").LayoutOrder = 2
	local languageGrid = Instance.new("Frame")
	languageGrid.BackgroundTransparency = 1
	languageGrid.Size = UDim2.new(1, 0, 0, 0)
	languageGrid.AutomaticSize = Enum.AutomaticSize.Y
	languageGrid.LayoutOrder = 3
	languageGrid.Parent = created.list
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.new(0.5, -4, 0, 44)
	grid.CellPadding = UDim2.fromOffset(8, 8)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = languageGrid
	local languageButtons: { [string]: TextButton } = {}
	for index, code in Config.LANGUAGE_ORDER do
		local language = Config.LANGUAGES[code]
		local button = UiKit.button(languageGrid, "", "secondary")
		button.LayoutOrder = index
		UiKit.flag(button, code, 30).Position = UDim2.new(0, 10, 0.5, -10)
		local name = UiKit.text(button, language.name, "Body")
		name.AutomaticSize = Enum.AutomaticSize.None
		name.Position = UDim2.fromOffset(50, 0)
		name.Size = UDim2.new(1, -56, 1, 0)
		name.TextWrapped = false
		name.TextTruncate = Enum.TextTruncate.AtEnd
		name.Active = false
		languageButtons[code] = button
		button.Activated:Connect(function()
			Localization.set(code)
		end)
	end
	UiKit.text(created.list, "Ses", "Heading").LayoutOrder = 10
	local volumeValue = player:GetAttribute("SoundVolume")
	local volumeLabel = UiKit.text(created.list, "", "Caption")
	volumeLabel.LayoutOrder = 11
	local volumeSlider, setVolumeSlider = UiKit.slider(
		created.list,
		if typeof(volumeValue) == "number" then volumeValue else 0.8,
		function(value: number)
			player:SetAttribute("SoundVolume", value)
		end
	)
	volumeSlider.LayoutOrder = 12
	UiKit.text(created.list, "Ses düzeyi yalnızca bu oturumda geçerlidir.", "Caption").LayoutOrder = 13
	UiKit.text(created.list, "Grafik kalitesi", "Heading").LayoutOrder = 4
	local choices = Instance.new("Frame")
	choices.BackgroundTransparency = 1
	choices.Size = UDim2.new(1, 0, 0, 44)
	choices.LayoutOrder = 5
	choices.Parent = created.list
	UiKit.list(choices, 6, true)
	local buttons: { [string]: TextButton } = {}
	for index, option in
		{
			{ id = "auto", title = "Otomatik" },
			{ id = "low", title = "Düşük" },
			{ id = "medium", title = "Orta" },
			{ id = "high", title = "Yüksek" },
		}
	do
		local button = UiKit.button(choices, option.title, "secondary")
		button.Size = UDim2.new(1 / 4, -5, 1, 0)
		button.TextScaled = false
		button.TextSize = 14
		button.LayoutOrder = index
		buttons[option.id] = button
		button.Activated:Connect(function()
			-- Tercih hesaba kaydedilir; uygulamayı Graphics.client yapar
			player:SetAttribute("GraphicsMode", option.id)
			Remotes.get("RequestSetGraphics"):FireServer(option.id)
		end)
	end
	local qualityInfo = UiKit.text(created.list, "", "Caption")
	qualityInfo.LayoutOrder = 6
	UiKit.text(created.list, "Hareket", "Heading").LayoutOrder = 7
	local motion = UiKit.button(created.list, "", "secondary")
	motion.Size = UDim2.new(1, 0, 0, 44)
	motion.LayoutOrder = 8
	motion.Activated:Connect(function()
		player:SetAttribute("ReducedMotion", player:GetAttribute("ReducedMotion") ~= true)
	end)
	UiKit.text(
		created.list,
		"Hareketi azaltınca kuşlar, süs balıkları, hayvan gezinmesi ve şimşek kapanır; yağış azalır.",
		"Caption"
	).LayoutOrder =
		9
	local descriptions: { [string]: string } = {
		auto = "Cihazına göre başlar, akıcılık düşerse kendiliğinden iner, rahatsa yükselir.",
		low = "Gölge, yansıma, parıltı ve bulut kapalı; az yağış ve süs hayvanı. En akıcı ve en az pil harcayan.",
		medium = "Gölgeler, hafif yansıma ve parıltı açık; dengeli parçacık ve hayvan hareketi.",
		high = "Keskin gölgeler, tam yansıma, güneş ışınları, ufukta odak bulanıklığı ve tüm efektler. Güçlü cihazlar için.",
	}
	local function refreshLanguage()
		local selected = Localization.get()
		for code, button in languageButtons do
			UiKit.setVariant(button, if code == selected then "primary" else "secondary")
			-- Seçili dil tekrar tıklanabilir kalsın (kaydı yeniden gönderir); yalnızca renk değişir.
			button.Active = true
		end
	end
	local function refresh()
		local mode = player:GetAttribute("GraphicsMode")
		local selected = if typeof(mode) == "string" and descriptions[mode] then mode else "auto"
		for id, button in buttons do
			-- Seçili seçenek tekrar tıklanabilir; diğer seçeneklere geçiş her zaman açık.
			UiKit.setVariant(button, if id == selected then "primary" else "secondary")
		end
		qualityInfo.Text = descriptions[selected]
		if selected == "auto" then
			local tierNames: { [string]: string } = { low = "Düşük", medium = "Orta", high = "Yüksek" }
			local current = player:GetAttribute("EffectsQuality")
			qualityInfo.Text ..= `\nŞu an: {tierNames[current :: string] or "Orta"}`
		end
		local reduced = player:GetAttribute("ReducedMotion") == true
		motion.Text = if reduced then "Hareketi azalt: Açık" else "Hareketi azalt: Kapalı"
		UiKit.setVariant(motion, if reduced then "primary" else "secondary")
	end
	local function refreshVolume()
		local value = player:GetAttribute("SoundVolume")
		local volume = if typeof(value) == "number" then value else 0.8
		volumeLabel.Text = `Ses düzeyi: %{math.round(volume * 100)}`
		setVolumeSlider(volume)
	end
	local connections = {
		player:GetAttributeChangedSignal("SoundVolume"):Connect(refreshVolume),
		player:GetAttributeChangedSignal("GraphicsMode"):Connect(refresh),
		player:GetAttributeChangedSignal("EffectsQuality"):Connect(refresh),
		player:GetAttributeChangedSignal("ReducedMotion"):Connect(refresh),
	}
	local stopLanguageWatch = Localization.onChanged(refreshLanguage)
	created.frame.Destroying:Connect(function()
		for _, connection in connections do
			connection:Disconnect()
		end
		stopLanguageWatch()
		if window == created then
			window = nil
		end
	end)
	refresh()
	refreshVolume()
	refreshLanguage()
	return created
end

function SettingsMenu.toggle(parent: Instance)
	local current = window
	if current and current.isOpen() then
		current.close()
		return
	end
	SettingsMenu.open(parent)
end

function SettingsMenu.open(parent: Instance)
	local current = window
	if current and current.frame.Parent ~= parent then
		current.frame:Destroy()
		current = nil
	end
	if not current then
		current = create(parent)
		window = current
	end
	current.open()
end

return SettingsMenu
