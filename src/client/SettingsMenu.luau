--!strict
-- Görsel tercihler yalnızca bu cihazdaki açık oturum için geçerlidir.
local Players = game:GetService("Players")
local UiKit = require(script.Parent:WaitForChild("UiKit"))
local player = Players.LocalPlayer
local SettingsMenu = {}
local window: UiKit.Window? = nil

if player:GetAttribute("EffectsQuality") == nil then
	player:SetAttribute("EffectsQuality", "medium")
end
if player:GetAttribute("ReducedMotion") == nil then
	player:SetAttribute("ReducedMotion", false)
end

local function create(parent: ScreenGui): UiKit.Window
	local created = UiKit.window(parent, {
		title = "Görsel Ayarlar",
		icon = "⚙️",
		tint = UiKit.Color.Blue,
		width = 380,
		maxHeight = 430,
		anchor = Vector2.new(0.5, 0.5),
		position = UDim2.fromScale(0.5, 0.5),
	})
	UiKit.text(
		created.list,
		"Bu tercihler yalnızca bu oturumda geçerlidir. Gelirini ve oyun hızını değiştirmez.",
		"Caption"
	).LayoutOrder =
		1
	UiKit.text(created.list, "Efekt kalitesi", "Heading").LayoutOrder = 2
	local choices = Instance.new("Frame")
	choices.BackgroundTransparency = 1
	choices.Size = UDim2.new(1, 0, 0, 44)
	choices.LayoutOrder = 3
	choices.Parent = created.list
	UiKit.list(choices, 6, true)
	local buttons: { [string]: TextButton } = {}
	for index, option in
		{ { id = "low", title = "Düşük" }, { id = "medium", title = "Orta" }, { id = "high", title = "Yüksek" } }
	do
		local button = UiKit.button(choices, option.title, "secondary")
		button.Size = UDim2.new(1 / 3, -4, 1, 0)
		button.LayoutOrder = index
		buttons[option.id] = button
		button.Activated:Connect(function()
			player:SetAttribute("EffectsQuality", option.id)
		end)
	end
	local qualityInfo = UiKit.text(created.list, "", "Caption")
	qualityInfo.LayoutOrder = 4
	UiKit.text(created.list, "Hareket", "Heading").LayoutOrder = 5
	local motion = UiKit.button(created.list, "", "secondary")
	motion.Size = UDim2.new(1, 0, 0, 44)
	motion.LayoutOrder = 6
	motion.Activated:Connect(function()
		player:SetAttribute("ReducedMotion", player:GetAttribute("ReducedMotion") ~= true)
	end)
	UiKit.text(
		created.list,
		"Hareketi azaltınca kuşlar, süs balıkları, hayvan gezinmesi ve şimşek kapanır; yağış azalır.",
		"Caption"
	).LayoutOrder =
		7
	local descriptions: { [string]: string } = {
		low = "Daha az yağış ve süs hayvanı; daha kısa çizim mesafesi. Yakındaki hayvanlar akıcı hareket eder.",
		medium = "Dengeli görünüm: azaltılmış parçacıklar, akıcı hayvan hareketleri ve satın alma animasyonu.",
		high = "Tüm görsel efektler ve her karede hayvan hareketi. Güçlü cihazlar için.",
	}
	local function refresh()
		local quality = player:GetAttribute("EffectsQuality")
		local selected = if typeof(quality) == "string" and descriptions[quality] then quality else "medium"
		for id, button in buttons do
			-- Seçili seçenek tekrar tıklanabilir; diğer seçeneklere geçiş her zaman açık.
			UiKit.setVariant(button, if id == selected then "primary" else "secondary")
		end
		qualityInfo.Text = descriptions[selected]
		local reduced = player:GetAttribute("ReducedMotion") == true
		motion.Text = if reduced then "Hareketi azalt: Açık" else "Hareketi azalt: Kapalı"
		UiKit.setVariant(motion, if reduced then "primary" else "secondary")
	end
	local connections = {
		player:GetAttributeChangedSignal("EffectsQuality"):Connect(refresh),
		player:GetAttributeChangedSignal("ReducedMotion"):Connect(refresh),
	}
	created.frame.Destroying:Connect(function()
		for _, connection in connections do
			connection:Disconnect()
		end
		if window == created then
			window = nil
		end
	end)
	refresh()
	return created
end

function SettingsMenu.open(parent: ScreenGui)
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
