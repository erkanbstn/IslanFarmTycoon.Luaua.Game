--!strict
-- Görünürlük yardımcıdır; her komutun yetkisini ve değerini sunucu yeniden doğrular.
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local FarmMath = require(Shared:WaitForChild("Modules"):WaitForChild("FarmMath"))
local UiKit = require(script.Parent:WaitForChild("UiKit"))
local ClientState = require(script.Parent.Parent:WaitForChild("Core"):WaitForChild("ClientState"))
local player = Players.LocalPlayer
local AdminPanel = {}

local window: UiKit.Window? = nil
local render: (() -> ())? = nil
local MAX_COMMAND_CASH = 1e12 -- Kullanıcı girdisi; asıl sınır sunucudaki AdminPolicy tarafından doğrulanır.
local sequence = 0
local pending: number? = nil
local nextSendAt = 0
local resultText = "Bir işlem seç. Sonuç sunucudan doğrulanınca burada gösterilir."
local resultSuccess: boolean? = nil

local function refresh()
	if render then
		render()
	end
end

local function submit(action: string, value: string | number)
	if player:GetAttribute("IsAdmin") ~= true or pending ~= nil or os.clock() < nextSendAt then
		return
	end
	sequence += 1
	local id = sequence
	pending = id
	nextSendAt = os.clock() + 0.6
	resultText = "Sunucu yanıtı bekleniyor."
	resultSuccess = nil
	refresh()
	Remotes.get("RequestAdminAction"):FireServer(action, value, id)
	task.delay(0.6, refresh)
	task.delay(10, function()
		if pending ~= id then
			return
		end
		pending = nil
		resultText = "Yanıt gecikti. Komut tekrarlanmadı; yeniden denemeden önce sonucu kontrol et."
		resultSuccess = false
		ClientState.requestSnapshot()
		refresh()
	end)
end

Remotes.get("AdminResult").OnClientEvent:Connect(function(id: number, success: boolean, message: string?)
	if pending ~= id then
		return
	end
	pending = nil
	resultSuccess = success
	resultText = if typeof(message) == "string"
		then message
		else if success then "İşlem tamamlandı." else "İşlem uygulanamadı."
	refresh()
end)

player:GetAttributeChangedSignal("IsAdmin"):Connect(function()
	if player:GetAttribute("IsAdmin") ~= true then
		pending = nil
		resultText = "Yönetici yetkisi artık etkin değil."
		resultSuccess = false
		local current = window
		if current then
			current.close()
		end
	end
	refresh()
end)

type Control = { button: TextButton, action: string, value: string? }

local function create(parent: ScreenGui): UiKit.Window
	local created = UiKit.window(parent, {
		title = "Yönetici",
		icon = "🛠️",
		tint = UiKit.Color.Orange,
		width = 400,
		maxHeight = 620,
		anchor = Vector2.new(0.5, 0.5),
		position = UDim2.fromScale(0.5, 0.5),
	})
	UiKit.text(
		created.list,
		"Para işlemleri yalnızca kendi kasanı değiştirir. Hava, mevsim, saat ve ışıklar bu sunucudaki herkesi etkiler.",
		"Caption"
	).LayoutOrder =
		1
	local persistence = UiKit.text(created.list, "", "Caption")
	persistence.LayoutOrder = 2
	local status = UiKit.text(created.list, "", "Body")
	status.RichText = false
	status.LayoutOrder = 3
	local controls: { Control } = {}

	local cashHeading = UiKit.text(created.list, "Kendi kasam", "Heading")
	cashHeading.LayoutOrder = 4
	local function updateBalance()
		local state = ClientState.get()
		cashHeading.Text = if state
			then `Kendi kasam: {FarmMath.formatMoney(state.cash)}`
			else "Kendi kasam: yükleniyor"
	end
	local amount = UiKit.textInput(created.list, "Tutar (örnek: 1000)")
	amount.Name = "CashAmount"
	amount.LayoutOrder = 5

	local function row(order: number): Frame
		local frame = Instance.new("Frame")
		frame.BackgroundTransparency = 1
		frame.Size = UDim2.new(1, 0, 0, 44)
		frame.LayoutOrder = order
		frame.Parent = created.list
		UiKit.list(frame, 6, true)
		return frame
	end
	local cashRow = row(6)
	for index, option in { { id = "addCash", label = "Kasaya ekle" }, { id = "setCash", label = "Bakiyeyi ayarla" } } do
		local button = UiKit.button(cashRow, option.label, "primary")
		button.Size = UDim2.new(0.5, -3, 1, 0)
		button.LayoutOrder = index
		table.insert(controls, { button = button, action = option.id, value = nil })
		button.Activated:Connect(function()
			if not button.Active then
				return
			end
			local number = tonumber(amount.Text)
			if not number or number ~= number or number == math.huge or number < 0 or number % 1 ~= 0 then
				resultText = "Sıfır veya daha büyük bir tam sayı yaz."
				resultSuccess = false
				refresh()
				return
			end
			if option.id == "addCash" and number < 1 then
				resultText = "Eklemek için en az 1 yaz. Sıfırlamak için Bakiyeyi ayarla kullanılır."
				resultSuccess = false
				refresh()
				return
			end
			if number > MAX_COMMAND_CASH then
				resultText = "Bir komutun tutarı en fazla 1 trilyon olabilir."
				resultSuccess = false
				refresh()
				return
			end
			amount:ReleaseFocus()
			submit(option.id, number)
		end)
	end
	UiKit.text(
		created.list,
		"Bakiyeyi ayarla, mevcut tutarın üzerine yazdığı için parayı azaltabilir.",
		"Caption"
	).LayoutOrder =
		7

	UiKit.text(created.list, "Sunucu havası", "Heading").LayoutOrder = 8
	local weatherStatus = UiKit.text(created.list, "", "Caption")
	weatherStatus.LayoutOrder = 9
	local weather = {
		{ id = "sunny", label = "Güneşli" },
		{ id = "cloudy", label = "Bulutlu" },
		{ id = "rain", label = "Yağmur" },
		{ id = "storm", label = "Fırtına" },
		{ id = "snow", label = "Kar" },
		{ id = "auto", label = "Otomatik hava" },
	}
	local seasons = {
		{ id = "spring", label = "İlkbahar" },
		{ id = "summer", label = "Yaz" },
		{ id = "autumn", label = "Sonbahar" },
		{ id = "winter", label = "Kış" },
		{ id = "auto", label = "Otomatik mevsim" },
	}
	local function choices(action: string, options: { { id: string, label: string } }, firstOrder: number)
		local currentRow: Frame? = nil
		for index, option in options do
			if index % 2 == 1 then
				currentRow = row(firstOrder + math.floor((index - 1) / 2))
			end
			local button = UiKit.button(
				assert(currentRow, "Yönetici seçenek satırı oluşturulamadı"),
				option.label,
				"secondary"
			)
			button.Size = UDim2.new(
				if index == #options and index % 2 == 1 then 1 else 0.5,
				if index == #options and index % 2 == 1 then 0 else -3,
				1,
				0
			)
			button.LayoutOrder = index
			table.insert(controls, { button = button, action = action, value = option.id })
			button.Activated:Connect(function()
				if button.Active then
					submit(action, option.id)
				end
			end)
		end
	end
	choices("setWeather", weather, 10)
	UiKit.text(created.list, "Sunucu mevsimi", "Heading").LayoutOrder = 13
	local seasonStatus = UiKit.text(created.list, "", "Caption")
	seasonStatus.LayoutOrder = 14
	choices("setSeason", seasons, 15)
	UiKit.text(
		created.list,
		"Otomatik seçeneği ilgili yönetici seçimini kaldırıp normal döngüyü sürdürür.",
		"Caption"
	).LayoutOrder =
		18

	-- Gün-gece, ışık ve test araçları (sonradan eklenen özellikleri denemek için)
	local times = {
		{ id = "dawn", label = "Şafak" },
		{ id = "noon", label = "Öğle" },
		{ id = "dusk", label = "Akşam" },
		{ id = "night", label = "Gece" },
		{ id = "auto", label = "Otomatik saat" },
	}
	local lightModes = {
		{ id = "on", label = "Işıklar hep açık" },
		{ id = "off", label = "Işıklar hep kapalı" },
		{ id = "auto", label = "Otomatik ışık" },
	}
	local lightLevels = {
		{ id = "dim", label = "Çok kısık" },
		{ id = "low", label = "Kısık" },
		{ id = "normal", label = "Normal" },
		{ id = "strong", label = "Güçlü" },
	}
	UiKit.text(created.list, "Gün ve gece", "Heading").LayoutOrder = 19
	local timeStatus = UiKit.text(created.list, "", "Caption")
	timeStatus.LayoutOrder = 20
	choices("setTime", times, 21)
	UiKit.text(created.list, "Gece ışıkları", "Heading").LayoutOrder = 24
	local lightStatus = UiKit.text(created.list, "", "Caption")
	lightStatus.LayoutOrder = 25
	choices("setLights", lightModes, 26)
	UiKit.text(created.list, "Işık parlaklığı", "Heading").LayoutOrder = 28
	local levelStatus = UiKit.text(created.list, "", "Caption")
	levelStatus.LayoutOrder = 29
	choices("setLightLevel", lightLevels, 30)
	UiKit.text(created.list, "Test araçları (yalnızca kendi çiftliğin)", "Heading").LayoutOrder = 33
	UiKit.text(
		created.list,
		"Açma ve doldurma, seçili (bulunduğun) ada içindir. Hayvanları yetişkin yapmak büyüme animasyonunu, açmak tabela ve eklentileri, doldurmak yoğunluğu denemek içindir. Para harcamaz.",
		"Caption"
	).LayoutOrder =
		34
	choices("growAll", { { id = "now", label = "Bütün hayvanları büyüt" } }, 35)
	choices("unlockIslands", { { id = "now", label = "Bu adadaki her şeyi aç (eklentiler dahil)" } }, 36)
	choices("fillSlots", { { id = "now", label = "Bu adadaki bütün slotları hayvanla doldur" } }, 37)
	UiKit.text(created.list, "Rastgele olaylar (test)", "Heading").LayoutOrder = 38
	UiKit.text(
		created.list,
		"Olaylar normalde rastgele gelir; bunlar hemen görmek içindir. Altın hayvan ve tüccar yalnızca senin profilinde çıkar, kaydedilmez.",
		"Caption"
	).LayoutOrder =
		39
	choices("forceMerchant", { { id = "now", label = "Gezgin tüccarı çağır" } }, 40)
	choices("forceGolden", { { id = "now", label = "Altın hayvanı çağır" } }, 41)
	choices("completeSeason", { { id = "now", label = "Mevsim hedefini tamamla" } }, 42)
	choices("resetEvents", { { id = "now", label = "Olayları ve mevsim hedefini sıfırla" } }, 43)
	UiKit.text(created.list, "Envanter (test)", "Heading").LayoutOrder = 44
	choices("grantItems", { { id = "now", label = "Bütün eşyaları ver (takmaz)" } }, 45)
	choices("clearItems", { { id = "now", label = "Envanteri boşalt" } }, 46)

	local function choiceLabel(options: { { id: string, label: string } }, value: string): string
		for _, option in options do
			if option.id == value then
				return option.label
			end
		end
		return "Otomatik"
	end
	local function update()
		local busy = pending ~= nil or os.clock() < nextSendAt or player:GetAttribute("IsAdmin") ~= true
		local weatherOverride = ReplicatedStorage:GetAttribute("AdminWeatherOverride")
		local seasonOverride = ReplicatedStorage:GetAttribute("AdminSeasonOverride")
		local selectedWeather = if typeof(weatherOverride) == "string" and weatherOverride ~= ""
			then weatherOverride
			else "auto"
		local selectedSeason = if typeof(seasonOverride) == "string" and seasonOverride ~= ""
			then seasonOverride
			else "auto"
		local function selectedOf(attribute: string): string
			local value = ReplicatedStorage:GetAttribute(attribute)
			return if typeof(value) == "string" and value ~= "" then value else "auto"
		end
		local selectedTime = selectedOf("AdminClockId")
		local selectedLights = selectedOf("AdminLightsId")
		local selectedLevel = ReplicatedStorage:GetAttribute("AdminLightLevelId")
		selectedLevel = if typeof(selectedLevel) == "string" and selectedLevel ~= "" then selectedLevel else "normal"
		timeStatus.Text = `Seçim: {choiceLabel(times, selectedTime)}`
		-- DayNight'ın bu ekranda izlediği parça/ışık sayısı: 0 ise etiket ya da harita sorunu vardır.
		local function lightingNumber(attribute: string): number
			local value = Lighting:GetAttribute(attribute)
			return if typeof(value) == "number" then value else 0
		end
		local ramp = lightingNumber("NightLightRamp")
		local parts = lightingNumber("NightLightParts")
		local sources = lightingNumber("NightLightSources")
		lightStatus.Text =
			`Seçim: {choiceLabel(lightModes, selectedLights)} · Şu an ışıklar %{ramp} · Yakında {parts} lamba/pencere, {sources} ışık kaynağı`
		levelStatus.Text = `Seçim: {choiceLabel(lightLevels, selectedLevel :: string)}`
		weatherStatus.Text = `Seçim: {choiceLabel(weather, selectedWeather)}`
		seasonStatus.Text = `Seçim: {choiceLabel(seasons, selectedSeason)}`
		persistence.Text = if player:GetAttribute("DataPersistent") == false
			then "Kayıtsız test: para değişiklikleri bu oturum sonunda saklanmaz."
			else "Para değişiklikleri aktif profilin normal kayıt akışında saklanır."
		status.Text = resultText
		status.TextColor3 = if resultSuccess == false
			then UiKit.Color.Red
			elseif resultSuccess == true then UiKit.Color.Green
			else UiKit.Color.TextMuted
		amount.TextEditable = not busy
		amount.Active = not busy
		for _, control in controls do
			local selected = (control.action == "setWeather" and control.value == selectedWeather)
				or (control.action == "setSeason" and control.value == selectedSeason)
				or (control.action == "setTime" and control.value == selectedTime)
				or (control.action == "setLights" and control.value == selectedLights)
				or (control.action == "setLightLevel" and control.value == selectedLevel)
			UiKit.setVariant(
				control.button,
				if busy then "disabled" elseif selected or control.value == nil then "primary" else "secondary"
			)
		end
	end
	render = update
	local connections = {
		ReplicatedStorage:GetAttributeChangedSignal("AdminWeatherOverride"):Connect(update),
		ReplicatedStorage:GetAttributeChangedSignal("AdminSeasonOverride"):Connect(update),
		ReplicatedStorage:GetAttributeChangedSignal("AdminClockId"):Connect(update),
		ReplicatedStorage:GetAttributeChangedSignal("AdminLightsId"):Connect(update),
		ReplicatedStorage:GetAttributeChangedSignal("AdminLightLevelId"):Connect(update),
		Lighting:GetAttributeChangedSignal("NightLightParts"):Connect(update),
		Lighting:GetAttributeChangedSignal("NightLightSources"):Connect(update),
		Lighting:GetAttributeChangedSignal("NightLightRamp"):Connect(update),
		player:GetAttributeChangedSignal("DataPersistent"):Connect(update),
	}
	local stopState = ClientState.onChanged(updateBalance)
	created.frame.Destroying:Connect(function()
		stopState()
		for _, connection in connections do
			connection:Disconnect()
		end
		if render == update then
			render = nil
		end
		if window == created then
			window = nil
		end
	end)
	updateBalance()
	update()
	return created
end

function AdminPanel.open(parent: ScreenGui)
	if player:GetAttribute("IsAdmin") ~= true then
		return
	end
	local current = window
	if current and current.frame.Parent ~= parent then
		current.frame:Destroy()
		current = nil
	end
	if not current then
		current = create(parent)
		window = current
	end
	refresh()
	current.open()
end

return AdminPanel
