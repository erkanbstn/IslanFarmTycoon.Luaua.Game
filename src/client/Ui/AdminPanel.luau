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

-- Sekme başına vurgu rengi (başlıklar) ve işlem başına düğme tonu; yeni renk yazma, UiKit.Color'dan türet.
local PAGE_ACCENT: { [string]: Color3 } = {
	Page_cash = UiKit.Color.Green,
	Page_players = UiKit.Color.Blue,
	Page_world = UiKit.Color.Gold,
	Page_test = UiKit.Color.Orange,
}
local ACTION_ACCENT: { [string]: Color3 } = {
	addCash = UiKit.Color.Green,
	setCash = UiKit.Color.Blue,
	["target:giveCash"] = UiKit.Color.Green,
	["target:takeCash"] = UiKit.Color.Orange,
	["target:setTargetCash"] = UiKit.Color.Blue,
	["target:inspect"] = UiKit.Color.Blue,
	["target:kickPlayer"] = UiKit.Color.Red,
	setWeather = UiKit.Color.Blue,
	setSeason = UiKit.Color.Green,
	setTime = UiKit.Color.Gold,
	setLights = UiKit.Color.Gold,
	setLightLevel = UiKit.Color.Gold,
	maxAll = UiKit.Color.Green,
	growAll = UiKit.Color.Green,
	unlockIslands = UiKit.Color.Blue,
	fillSlots = UiKit.Color.Blue,
	forceMerchant = UiKit.Color.Orange,
	forceGolden = UiKit.Color.Gold,
	completeSeason = UiKit.Color.Green,
	resetEvents = UiKit.Color.Red,
	grantItems = UiKit.Color.Blue,
	clearItems = UiKit.Color.Red,
	fillBarn = UiKit.Color.Orange,
}

local function create(parent: Instance): UiKit.Window
	local created = UiKit.window(parent, {
		title = "Yönetici",
		icon = "🛠️",
		tint = UiKit.Color.Orange,
		width = 540,
		maxHeight = 620,
		anchor = Vector2.new(0.5, 0.5),
		position = UDim2.fromScale(0.5, 0.5),
	})
	local panelDetails = UiKit.disclosure(created.list, 9, "Ayrıntılar")
	UiKit.text(
		panelDetails.body,
		"Para işlemleri yalnızca kendi kasanı değiştirir. Hava, mevsim, saat ve ışıklar bu sunucudaki herkesi etkiler.",
		"Caption"
	).LayoutOrder =
		1
	local persistence = UiKit.text(panelDetails.body, "", "Caption")
	persistence.LayoutOrder = 2
	local persistenceWarning = UiKit.text(
		created.list,
		"Kayıtsız test: para değişiklikleri bu oturum sonunda saklanmaz.",
		"Caption",
		UiKit.Color.Orange
	)
	persistenceWarning.LayoutOrder = 2
	persistenceWarning.Visible = false
	local status = UiKit.text(created.list, "", "Body")
	status.RichText = false
	status.LayoutOrder = 3
	local controls: { Control } = {}

	-- Bölüm başlığı: sayfanın vurgu renginde (sekme başına bir renk); düğme tonlarıyla aynı aileden.
	local function heading(holder: Instance, text: string, color: Color3?): TextLabel
		return UiKit.text(holder, text, "Heading", color or PAGE_ACCENT[holder.Name] or UiKit.Color.Gold)
	end

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

	local cashHeading = heading(page, "Kendi kasam")
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

	-- Düğme yazısı sabit boyutta (UiKit.TextSize.Button) ve satıra sarılır; açıklama yazısıyla aynı ölçek ailesinde kalır.
	local function fit(button: TextButton)
		button.TextWrapped = true
		button.TextScaled = false
		button.TextSize = UiKit.TextSize.Button
		local padding = Instance.new("UIPadding")
		padding.PaddingLeft = UDim.new(0, 8)
		padding.PaddingRight = UDim.new(0, 8)
		padding.PaddingTop = UDim.new(0, 3)
		padding.PaddingBottom = UDim.new(0, 3)
		padding.Parent = button
	end

	local function row(order: number): Frame
		local frame = Instance.new("Frame")
		frame.BackgroundTransparency = 1
		frame.Size = UDim2.new(1, 0, 0, math.max(UiKit.TouchTarget, 56))
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
	heading(page, "Sunucu havası").LayoutOrder = 8
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
	local function choices(
		action: string,
		options: { { id: string, label: string, action: string? } },
		firstOrder: number
	)
		local short = action == "setWeather" or action == "setSeason" or action == "setTime"
		local currentRow = UiKit.actionRow(page, firstOrder, if short then 4 else 2, if short then 86 else 144)
		for index, option in options do
			local button = UiKit.actionButton(currentRow, index, option.label, "secondary")
			fit(button)
			local command = option.action or action
			table.insert(controls, { button = button, action = command, value = option.id })
			button.Activated:Connect(function()
				if button.Active then
					submit(command, option.id)
				end
			end)
		end
	end
	choices("setWeather", weather, 10)
	heading(page, "Sunucu mevsimi").LayoutOrder = 13
	local seasonStatus = UiKit.text(page, "", "Caption")
	seasonStatus.LayoutOrder = 14
	choices("setSeason", seasons, 15)
	local worldDetails = UiKit.disclosure(page, 33, "Ayrıntılar")
	UiKit.text(
		worldDetails.body,
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
	heading(page, "Gün ve gece").LayoutOrder = 19
	local timeStatus = UiKit.text(page, "", "Caption")
	timeStatus.LayoutOrder = 20
	choices("setTime", times, 21)
	heading(page, "Gece ışıkları").LayoutOrder = 24
	local lightStatus = UiKit.text(page, "", "Caption")
	lightStatus.LayoutOrder = 25
	local lightDiagnostics = UiKit.text(worldDetails.body, "", "Caption")
	lightDiagnostics.LayoutOrder = 19
	choices("setLights", lightModes, 26)
	heading(page, "Işık parlaklığı").LayoutOrder = 28
	local levelStatus = UiKit.text(page, "", "Caption")
	levelStatus.LayoutOrder = 29
	choices("setLightLevel", lightLevels, 30)
	page = pages.test
	heading(page, "Kendi çiftliğin").LayoutOrder = 33
	local testDetails = UiKit.disclosure(page, 49, "Ayrıntılar")
	UiKit.text(
		testDetails.body,
		'Açma ve doldurma, seçili (bulunduğun) ada ya da bütün adalar içindir (kilitli ada seçilemediği için "Bütün adalar" onları da açar). Hayvanları yetişkin yapmak büyüme animasyonunu, açmak tabela ve eklentileri, doldurmak yoğunluğu denemek içindir. Para harcamaz.',
		"Caption"
	).LayoutOrder =
		34
	choices("maxAll", { { id = "now", label = "Bütün adaları tamamla" } }, 35)
	choices("growAll", { { id = "now", label = "Bütün hayvanları büyüt" } }, 36)
	choices("unlockIslands", {
		{ id = "now", label = "Bu adayı aç" },
		{ id = "all", label = "Bütün adaları aç" },
	}, 37)
	choices("fillSlots", {
		{ id = "now", label = "Bu adayı doldur" },
		{ id = "all", label = "Bütün adaları doldur" },
	}, 38)
	heading(page, "Rastgele olaylar (test)").LayoutOrder = 39
	UiKit.text(
		testDetails.body,
		"Olaylar normalde rastgele gelir; bunlar hemen görmek içindir. Altın hayvan ve tüccar yalnızca senin profilinde çıkar, kaydedilmez.",
		"Caption"
	).LayoutOrder =
		40
	choices("forceMerchant", {
		{ id = "now", label = "Gezgin tüccarı çağır" },
		{ id = "now", label = "Altın hayvanı çağır", action = "forceGolden" },
		{ id = "now", label = "Mevsim hedefini tamamla", action = "completeSeason" },
		{ id = "now", label = "Olayları sıfırla", action = "resetEvents" },
	}, 41)
	heading(page, "Envanter (test)").LayoutOrder = 45
	choices("grantItems", {
		{ id = "now", label = "Bütün eşyaları ver" },
		{ id = "now", label = "Envanteri boşalt", action = "clearItems" },
		{ id = "now", label = "Ahır deposunu doldur", action = "fillBarn" },
	}, 46)

	-- Tehlikeli bölge: bütün oyuncuların verisini sıfırlar (kayıtlar silinmez: veri çağı artar, eski kayıt arşivlenir; ayrıntı DataResetService)
	heading(page, "Tehlikeli bölge", UiKit.Color.Red).LayoutOrder = 60
	UiKit.text(
		page,
		"Bütün oyuncuların (sen dahil, bütün sunucular) verisini sıfırlar: herkes atılır, yeniden girince temiz oyunla başlar. Eski kayıtlar arşivlenir. Geri alınamaz; onay için kutuya SIFIRLA yaz.",
		"Caption"
	).LayoutOrder =
		61
	local resetConfirm = UiKit.textInput(page, "Onay için SIFIRLA yaz")
	resetConfirm.LayoutOrder = 62
	local resetRow = row(63)
	local resetButton = UiKit.button(resetRow, "Herkesin verisini sıfırla", "danger")
	fit(resetButton)
	resetButton.Size = UDim2.new(1, 0, 1, 0)
	resetButton.Activated:Connect(function()
		if not resetButton.Active then
			return
		end
		if resetConfirm.Text ~= "SIFIRLA" then
			resultText = "Onay için kutuya tam olarak SIFIRLA yaz."
			resultSuccess = false
			refresh()
			return
		end
		resetConfirm.Text = ""
		submit("resetAllPlayers", "confirm")
	end)

	-- Oyuncu işlemleri: seçilen oyuncuya para ver/al/ayarla, kayıt özeti, sunucudan at. Hedef ve tutar sunucuda yeniden doğrulanır.
	page = pages.players
	heading(page, "Oyuncu işlemleri").LayoutOrder = 48
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
			button.Size = UDim2.new(1, 0, 0, UiKit.TouchTarget)
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
		lightStatus.Text = `Seçim: {choiceLabel(lightModes, selectedLights)}`
		lightDiagnostics.Text =
			`Seçim: {choiceLabel(lightModes, selectedLights)} · Şu an ışıklar %{ramp} · Yakında {parts} lamba/pencere, {sources} ışık kaynağı`
		levelStatus.Text = `Seçim: {choiceLabel(lightLevels, selectedLevel :: string)}`
		weatherStatus.Text = `Seçim: {choiceLabel(weather, selectedWeather)}`
		seasonStatus.Text = `Seçim: {choiceLabel(seasons, selectedSeason)}`
		persistence.Text = if player:GetAttribute("DataPersistent") == false
			then "Kayıtsız test: para değişiklikleri bu oturum sonunda saklanmaz."
			else "Para değişiklikleri aktif profilin normal kayıt akışında saklanır."
		persistenceWarning.Visible = player:GetAttribute("DataPersistent") == false
		status.Visible = pending ~= nil or resultSuccess ~= nil
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
			UiKit.setVariant(control.button, if busy then "disabled" elseif selected then "primary" else "secondary")
			if not busy and not selected then
				-- Seçilmemiş düğme yüzeyden vurgu rengine doğru tonlanır (işlem düğmeleri daha canlı)
				local accent = ACTION_ACCENT[control.action] or UiKit.Color.Blue
				control.button.BackgroundColor3 = accent
				control.button.TextColor3 = UiKit.Color.OnAccent
			end
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
	if current then
		UiKit.toggleWindow(current)
		return
	end
	AdminPanel.open(parent)
end

function AdminPanel.open(parent: Instance)
	if player:GetAttribute("IsAdmin") ~= true then
		return
	end
	local current = window
	if current and (current.ownerParent or current.frame.Parent) ~= parent then
		current.frame:Destroy()
		current = nil
	end
	local active: UiKit.Window = current or create(parent)
	window = active
	refresh()
	active.open()
end

return AdminPanel
