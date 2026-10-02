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
local playerConnections: { RBXScriptConnection } = {}

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

local function submit(action: string, value: string | number, targetUserId: number?)
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
	if targetUserId then
		Remotes.get("RequestAdminPlayerAction"):FireServer(targetUserId, action, value, id)
	else
		Remotes.get("RequestAdminAction"):FireServer(action, value, id)
	end
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

local function create(parent: Instance): UiKit.Window
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

	-- Sekmeler: her sekme kendi bölümlerini ayrı bir çerçevede tutar (liste uzayıp gitmesin); sonuç satırı sekmelerin üstünde kalır.
	local pages: { [string]: Frame } = {}
	for _, id in { "cash", "players", "world", "test" } do
		local frame = Instance.new("Frame")
		frame.Name = `Page_{id}`
		frame.BackgroundTransparency = 1
		frame.Size = UDim2.new(1, 0, 0, 0)
		frame.AutomaticSize = Enum.AutomaticSize.Y
		frame.LayoutOrder = 5
		frame.Visible = id == "cash"
		frame.Parent = created.list
		UiKit.list(frame, 8)
		pages[id] = frame
	end
	UiKit.tabs(created.list, 4, {
		{ id = "cash", label = "Kasa" },
		{ id = "players", label = "Oyuncular" },
		{ id = "world", label = "Dünya" },
		{ id = "test", label = "Test" },
	}, function(id: string)
		for pageId, frame in pages do
			frame.Visible = pageId == id
		end
	end)
	local page: Instance = pages.cash

	local cashHeading = UiKit.text(page, "Kendi kasam", "Heading")
	cashHeading.LayoutOrder = 4
	local function updateBalance()
		local state = ClientState.get()
		cashHeading.Text = if state
			then `Kendi kasam: {FarmMath.formatMoney(state.cash)}`
			else "Kendi kasam: yükleniyor"
	end
	local amount = UiKit.textInput(page, "Tutar (örnek: 1000)")
	amount.Name = "CashAmount"
	amount.LayoutOrder = 5

	-- Uzun düğme yazıları satıra sarılır, gerekirse küçülür; düğmeden taşmaz.
	local function fit(button: TextButton)
		button.TextWrapped = true
		button.TextScaled = true
		local limit = Instance.new("UITextSizeConstraint")
		limit.MaxTextSize = button.TextSize
		limit.MinTextSize = 10
		limit.Parent = button
		local padding = Instance.new("UIPadding")
		padding.PaddingLeft = UDim.new(0, 6)
		padding.PaddingRight = UDim.new(0, 6)
		padding.PaddingTop = UDim.new(0, 3)
		padding.PaddingBottom = UDim.new(0, 3)
		padding.Parent = button
	end

	local function row(order: number): Frame
		local frame = Instance.new("Frame")
		frame.BackgroundTransparency = 1
		frame.Size = UDim2.new(1, 0, 0, 44)
		frame.LayoutOrder = order
		frame.Parent = page
		UiKit.list(frame, 6, true)
		return frame
	end
	local cashRow = row(6)
	for index, option in { { id = "addCash", label = "Kasaya ekle" }, { id = "setCash", label = "Bakiyeyi ayarla" } } do
		local button = UiKit.button(cashRow, option.label, "primary")
		fit(button)
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
	UiKit.text(page, "Bakiyeyi ayarla, mevcut tutarın üzerine yazdığı için parayı azaltabilir.", "Caption").LayoutOrder =
		7

	page = pages.world
	UiKit.text(page, "Sunucu havası", "Heading").LayoutOrder = 8
	local weatherStatus = UiKit.text(page, "", "Caption")
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
			fit(button)
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
	UiKit.text(page, "Sunucu mevsimi", "Heading").LayoutOrder = 13
	local seasonStatus = UiKit.text(page, "", "Caption")
	seasonStatus.LayoutOrder = 14
	choices("setSeason", seasons, 15)
	UiKit.text(
		page,
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
	UiKit.text(page, "Gün ve gece", "Heading").LayoutOrder = 19
	local timeStatus = UiKit.text(page, "", "Caption")
	timeStatus.LayoutOrder = 20
	choices("setTime", times, 21)
	UiKit.text(page, "Gece ışıkları", "Heading").LayoutOrder = 24
	local lightStatus = UiKit.text(page, "", "Caption")
	lightStatus.LayoutOrder = 25
	choices("setLights", lightModes, 26)
	UiKit.text(page, "Işık parlaklığı", "Heading").LayoutOrder = 28
	local levelStatus = UiKit.text(page, "", "Caption")
	levelStatus.LayoutOrder = 29
	choices("setLightLevel", lightLevels, 30)
	page = pages.test
	UiKit.text(page, "Test araçları (yalnızca kendi çiftliğin)", "Heading").LayoutOrder = 33
	UiKit.text(
		page,
		'Açma ve doldurma, seçili (bulunduğun) ada ya da bütün adalar içindir (kilitli ada seçilemediği için "Bütün adalar" onları da açar). Hayvanları yetişkin yapmak büyüme animasyonunu, açmak tabela ve eklentileri, doldurmak yoğunluğu denemek içindir. Para harcamaz.',
		"Caption"
	).LayoutOrder =
		34
	choices("maxAll", { { id = "now", label = "Hepsini aç, büyüt ve doldur (bütün adalar)" } }, 35)
	choices("growAll", { { id = "now", label = "Bütün hayvanları büyüt" } }, 36)
	choices("unlockIslands", {
		{ id = "now", label = "Bu adadaki her şeyi aç (eklentiler dahil)" },
		{ id = "all", label = "Bütün adalardaki her şeyi aç" },
	}, 37)
	choices("fillSlots", {
		{ id = "now", label = "Bu adadaki bütün slotları hayvanla doldur" },
		{ id = "all", label = "Bütün adaları hayvanla doldur" },
	}, 38)
	UiKit.text(page, "Rastgele olaylar (test)", "Heading").LayoutOrder = 39
	UiKit.text(
		page,
		"Olaylar normalde rastgele gelir; bunlar hemen görmek içindir. Altın hayvan ve tüccar yalnızca senin profilinde çıkar, kaydedilmez.",
		"Caption"
	).LayoutOrder =
		40
	choices("forceMerchant", { { id = "now", label = "Gezgin tüccarı çağır" } }, 41)
	choices("forceGolden", { { id = "now", label = "Altın hayvanı çağır" } }, 42)
	choices("completeSeason", { { id = "now", label = "Mevsim hedefini tamamla" } }, 43)
	choices("resetEvents", { { id = "now", label = "Olayları ve mevsim hedefini sıfırla" } }, 44)
	UiKit.text(page, "Envanter (test)", "Heading").LayoutOrder = 45
	choices("fillBarn", { { id = "now", label = "Ahır deposunu doldur" } }, 48)
	choices("grantItems", { { id = "now", label = "Bütün eşyaları ver (takmaz)" } }, 46)
	choices("clearItems", { { id = "now", label = "Envanteri boşalt" } }, 47)

	-- Oyuncu işlemleri: seçilen oyuncuya para ver/al/ayarla, kayıt özeti, sunucudan at. Hedef ve tutar sunucuda yeniden doğrulanır.
	page = pages.players
	UiKit.text(page, "Oyuncu işlemleri", "Heading").LayoutOrder = 48
	local targetStatus = UiKit.text(page, "Önce bir oyuncu seç.", "Caption")
	targetStatus.LayoutOrder = 49
	local playerList = Instance.new("Frame")
	playerList.BackgroundTransparency = 1
	playerList.Size = UDim2.new(1, 0, 0, 0)
	playerList.AutomaticSize = Enum.AutomaticSize.Y
	playerList.LayoutOrder = 50
	playerList.Parent = page
	UiKit.list(playerList, 4)
	local selectedTarget: Player? = nil
	local function rebuildPlayers()
		for _, child in playerList:GetChildren() do
			if child:IsA("TextButton") then
				child:Destroy()
			end
		end
		if selectedTarget and selectedTarget.Parent == nil then
			selectedTarget = nil
		end
		for index, other in Players:GetPlayers() do
			local label = if other == player then `{other.DisplayName} (ben)` else other.DisplayName
			local button = UiKit.button(playerList, label, if other == selectedTarget then "primary" else "secondary")
			fit(button)
			button.Size = UDim2.new(1, 0, 0, 34)
			button.LayoutOrder = index
			button.Activated:Connect(function()
				selectedTarget = other
				targetStatus.Text = `Seçili: {other.DisplayName}`
				rebuildPlayers()
			end)
		end
		if not selectedTarget then
			targetStatus.Text = "Önce bir oyuncu seç."
		end
	end
	table.insert(playerConnections, Players.PlayerAdded:Connect(rebuildPlayers))
	table.insert(
		playerConnections,
		Players.PlayerRemoving:Connect(function()
			task.defer(rebuildPlayers)
		end)
	)
	rebuildPlayers()
	local targetAmount = UiKit.textInput(page, "Tutar (para işlemleri için)")
	targetAmount.Name = "TargetAmount"
	targetAmount.LayoutOrder = 51
	local function targetRow(order: number, options: { { id: string, label: string, needsAmount: boolean } })
		local frame = row(order)
		for index, option in options do
			local button = UiKit.button(frame, option.label, "primary")
			fit(button)
			button.Size = UDim2.new(1 / #options, -4, 1, 0)
			button.LayoutOrder = index
			table.insert(controls, { button = button, action = `target:{option.id}`, value = nil })
			button.Activated:Connect(function()
				if not button.Active then
					return
				end
				local target = selectedTarget
				if not target then
					resultText = "Önce bir oyuncu seç."
					resultSuccess = false
					refresh()
					return
				end
				local number = 0
				if option.needsAmount then
					local parsed = tonumber(targetAmount.Text)
					local least = if option.id == "setTargetCash" then 0 else 1
					if
						not parsed
						or parsed ~= parsed
						or parsed < least
						or parsed % 1 ~= 0
						or parsed > MAX_COMMAND_CASH
					then
						resultText = "Geçerli bir tam sayı tutar yaz."
						resultSuccess = false
						refresh()
						return
					end
					number = parsed
					targetAmount:ReleaseFocus()
				end
				submit(option.id, number, target.UserId)
			end)
		end
	end
	targetRow(52, {
		{ id = "giveCash", label = "Para ver", needsAmount = true },
		{ id = "takeCash", label = "Para al", needsAmount = true },
		{ id = "setTargetCash", label = "Bakiyeyi ayarla", needsAmount = true },
	})
	targetRow(53, {
		{ id = "inspect", label = "Kasayı göster", needsAmount = false },
		{ id = "kickPlayer", label = "Sunucudan at", needsAmount = false },
	})

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
		for _, connection in playerConnections do
			connection:Disconnect()
		end
		table.clear(playerConnections)
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

function AdminPanel.toggle(parent: Instance)
	local current = window
	if current and current.isOpen() then
		current.close()
		return
	end
	AdminPanel.open(parent)
end

function AdminPanel.open(parent: Instance)
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
