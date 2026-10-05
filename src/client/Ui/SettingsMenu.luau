--!strict
-- Dil, grafik, ses düzeyleri, hareket azaltma ve başlangıç rehberi hesaba kaydedilir (ses/hareket: Core/Preferences.client).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UiKit = require(script.Parent:WaitForChild("UiKit"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Localization = require(Shared:WaitForChild("Localization"))
local Onboarding = require(script.Parent:WaitForChild("Hud"):WaitForChild("Onboarding"))
local player = Players.LocalPlayer
local SettingsMenu = {}
local window: UiKit.Window? = nil

-- Ses sürgüleri: canlı öznitelik (Core/Sfx grupları okur) ve ekrandaki başlık
local VOLUMES = {
	{ attribute = "SoundVolume", label = "Efekt sesleri: %{}", default = Config.AUDIO_DEFAULTS.sfx },
	{ attribute = "AmbienceVolume", label = "Ortam sesleri: %{}", default = Config.AUDIO_DEFAULTS.ambience },
	{ attribute = "MusicVolume", label = "Müzik: %{}", default = Config.AUDIO_DEFAULTS.music },
}

local function create(parent: Instance): UiKit.Window
	local created = UiKit.window(parent, {
		title = "Ayarlar",
		icon = "⚙️",
		tint = UiKit.Color.Blue,
		width = 480,
		maxHeight = 560,
		anchor = Vector2.new(0.5, 0.5),
		position = UDim2.fromScale(0.5, 0.5),
	})
	local details = UiKit.disclosure(created.list, 20, "Ayrıntılar")
	UiKit.text(details.body, "Tercihlerin hesabına kaydedilir. Gelirini ve oyun hızını değiştirmez.", "Caption").LayoutOrder =
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
	local languageNames: { [string]: TextLabel } = {}
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
		languageNames[code] = name
		button.Activated:Connect(function()
			Localization.set(code)
		end)
	end
	UiKit.text(created.list, "Ses", "Heading").LayoutOrder = 10
	local volumeLabels: { TextLabel } = {}
	local volumeSetters: { (value: number) -> () } = {}
	for index, volume in VOLUMES do
		local label = UiKit.text(created.list, "", "Caption")
		label.LayoutOrder = 9 + index * 2
		local current = player:GetAttribute(volume.attribute)
		local slider, setSlider = UiKit.slider(
			created.list,
			if typeof(current) == "number" then current else volume.default,
			function(value: number)
				player:SetAttribute(volume.attribute, value)
			end
		)
		slider.LayoutOrder = 10 + index * 2
		volumeLabels[index] = label
		volumeSetters[index] = setSlider
	end
	UiKit.text(created.list, "Grafik kalitesi", "Heading").LayoutOrder = 4
	local choices = Instance.new("Frame")
	choices.BackgroundTransparency = 1
	choices.Size = UDim2.new(1, 0, 0, 0)
	choices.AutomaticSize = Enum.AutomaticSize.Y
	choices.LayoutOrder = 5
	choices.Parent = created.list
	local qualityGrid = Instance.new("UIGridLayout")
	qualityGrid.CellSize = UDim2.new(0.5, -4, 0, UiKit.TouchTarget)
	qualityGrid.CellPadding = UDim2.fromOffset(8, 8)
	qualityGrid.SortOrder = Enum.SortOrder.LayoutOrder
	qualityGrid.Parent = choices
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
		button.Size = UDim2.new(0.5, -4, 0, UiKit.TouchTarget)
		button.TextScaled = false
		button.TextSize = UiKit.TextSize.Button
		button.LayoutOrder = index
		buttons[option.id] = button
		button.Activated:Connect(function()
			-- Tercih hesaba kaydedilir; uygulamayı Graphics.client yapar
			player:SetAttribute("GraphicsMode", option.id)
			Remotes.get("RequestSetGraphics"):FireServer(option.id)
		end)
	end
	local qualityInfo = UiKit.text(details.body, "", "Caption")
	qualityInfo.LayoutOrder = 2
	local qualityStatus = UiKit.text(created.list, "", "Caption")
	qualityStatus.LayoutOrder = 6
	UiKit.text(created.list, "Hareket", "Heading").LayoutOrder = 7
	local motion = UiKit.button(created.list, "", "secondary")
	motion.Size = UDim2.new(1, 0, 0, 44)
	motion.LayoutOrder = 8
	motion.Activated:Connect(function()
		player:SetAttribute("ReducedMotion", player:GetAttribute("ReducedMotion") ~= true)
	end)
	UiKit.text(
		details.body,
		"Hareketi azaltınca kuşlar, süs balıkları, hayvan gezinmesi ve şimşek kapanır; yağış azalır.",
		"Caption"
	).LayoutOrder =
		9
	UiKit.text(created.list, "Rehber", "Heading").LayoutOrder = 20
	local guide = UiKit.button(created.list, "", "secondary")
	guide.Size = UDim2.new(1, 0, 0, UiKit.TouchTarget)
	guide.LayoutOrder = 21
	guide.Activated:Connect(function()
		if Onboarding.isActive() then
			Onboarding.skip()
		else
			Onboarding.replay()
		end
	end)
	UiKit.text(
		details.body,
		"Rehber açıkken ilk adımlar ekranda yol gösterir; tamamladığın adımlar tekrar çıkmaz.",
		"Caption"
	).LayoutOrder =
		10
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
			languageNames[code].TextColor3 = if code == selected then UiKit.Color.OnAccent else UiKit.Color.Text
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
		UiKit.setText(qualityInfo, descriptions[selected])
		qualityStatus.Visible = selected == "auto"
		if selected == "auto" then
			local tierNames: { [string]: string } = { low = "Düşük", medium = "Orta", high = "Yüksek" }
			local current = player:GetAttribute("EffectsQuality")
			UiKit.setText(qualityStatus, `Şu an: {tierNames[current :: string] or "Orta"}`)
		end
		local reduced = player:GetAttribute("ReducedMotion") == true
		UiKit.setText(motion, if reduced then "Hareketi azalt: Açık" else "Hareketi azalt: Kapalı")
		UiKit.setVariant(motion, if reduced then "primary" else "secondary")
		local guideOn = Onboarding.isActive()
		UiKit.setText(guide, if guideOn then "Başlangıç rehberi: Açık" else "Başlangıç rehberi: Kapalı")
		UiKit.setVariant(guide, if guideOn then "primary" else "secondary")
	end
	local function refreshVolume()
		for index, volume in VOLUMES do
			local value = player:GetAttribute(volume.attribute)
			local level = if typeof(value) == "number" then value else volume.default
			-- Başlıktaki {} yerine yüzde sayısı gelir (etiketin "%" işareti metinde durur)
			volumeLabels[index].Text = (string.gsub(volume.label, "{}", tostring(math.round(level * 100))))
			volumeSetters[index](level)
		end
	end
	local connections = {
		player:GetAttributeChangedSignal("SoundVolume"):Connect(refreshVolume),
		player:GetAttributeChangedSignal("AmbienceVolume"):Connect(refreshVolume),
		player:GetAttributeChangedSignal("MusicVolume"):Connect(refreshVolume),
		player:GetAttributeChangedSignal("GraphicsMode"):Connect(refresh),
		player:GetAttributeChangedSignal("EffectsQuality"):Connect(refresh),
		player:GetAttributeChangedSignal("ReducedMotion"):Connect(refresh),
		Onboarding.Changed:Connect(refresh),
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
	if current then
		UiKit.toggleWindow(current)
		return
	end
	SettingsMenu.open(parent)
end

function SettingsMenu.open(parent: Instance)
	local current = window
	if current and (current.ownerParent or current.frame.Parent) ~= parent then
		current.frame:Destroy()
		current = nil
	end
	local opened = current or create(parent)
	window = opened
	opened.open()
end

return SettingsMenu
