--!strict
-- Sol panelde küçük mevsim/hava kartı (depo ile hedef arasında).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Environment = require(Shared:WaitForChild("Modules"):WaitForChild("Environment"))
local FarmMath = require(Shared:WaitForChild("Modules"):WaitForChild("FarmMath"))
local ClientState = require(script.Parent.Parent.Parent:WaitForChild("Core"):WaitForChild("ClientState"))
local UiKit = require(script.Parent.Parent:WaitForChild("UiKit"))

local Color = UiKit.Color

local SeasonBar = {}

export type Bar = {
	update: () -> (),
	setCompact: (compact: boolean) -> (),
}

function SeasonBar.create(stats: Instance): Bar
	local seasonBar = Instance.new("Frame")
	seasonBar.Name = "SeasonBar"
	seasonBar.BackgroundColor3 = Color.Surface
	seasonBar.LayoutOrder = 4
	seasonBar.Size = UDim2.new(1, 0, 0, 0)
	seasonBar.AutomaticSize = Enum.AutomaticSize.Y
	seasonBar.Parent = stats
	UiKit.corner(seasonBar, UiKit.Radius.Card)
	UiKit.padding(seasonBar, 8)
	UiKit.list(seasonBar, 4)

	local seasonHeader = Instance.new("Frame")
	seasonHeader.BackgroundTransparency = 1
	seasonHeader.Size = UDim2.new(1, 0, 0, 20)
	seasonHeader.LayoutOrder = 1
	seasonHeader.Parent = seasonBar
	local seasonChip = UiKit.iconChip(seasonHeader, "", 20, Color.Green)
	local seasonTitle = UiKit.text(seasonHeader, "", "Caption")
	seasonTitle.AutomaticSize = Enum.AutomaticSize.None
	seasonTitle.Position = UDim2.fromOffset(26, 0)
	seasonTitle.Size = UDim2.new(1, -26, 1, 0)
	seasonTitle.TextWrapped = false
	seasonTitle.TextTruncate = Enum.TextTruncate.AtEnd
	local seasonClock = UiKit.text(seasonBar, "", "Caption", Color.Gold)
	seasonClock.LayoutOrder = 2
	seasonClock.TextWrapped = false

	local seasonProgress, setSeasonProgress = UiKit.progressBar(seasonBar, 6)
	seasonProgress.Name = "SeasonProgress"
	seasonProgress.LayoutOrder = 3

	local seasonFooter = Instance.new("Frame")
	seasonFooter.BackgroundTransparency = 1
	seasonFooter.Size = UDim2.new(1, 0, 0, 20)
	seasonFooter.LayoutOrder = 4
	seasonFooter.Parent = seasonBar
	local weatherChip = UiKit.iconChip(seasonFooter, "", 20, Color.Blue)
	local weatherTitle = UiKit.text(seasonFooter, "", "Caption", Color.Text)
	weatherTitle.AutomaticSize = Enum.AutomaticSize.None
	weatherTitle.Position = UDim2.fromOffset(26, 0)
	weatherTitle.Size = UDim2.new(1, -26, 1, 0)
	weatherTitle.TextWrapped = false
	weatherTitle.TextTruncate = Enum.TextTruncate.AtEnd
	local nextSeasonLabel = UiKit.text(seasonBar, "", "Caption")
	nextSeasonLabel.LayoutOrder = 5

	-- Açılır/kapanır "Etkiler" bölümü: mevsimin, havanın ve ikisinin toplam gelir etkisi (hayvan başına)
	local toggle = UiKit.button(seasonBar, "Etkileri göster", "secondary")
	toggle.Name = "EffectsToggle"
	toggle.Size = UDim2.new(1, 0, 0, 26)
	toggle.TextSize = 12
	toggle.LayoutOrder = 6
	-- Uzun listeler küçük ekranlarda paneli taşırmasın: sabit yükseklikte kaydırılır
	local details = Instance.new("ScrollingFrame")
	details.Name = "EffectDetails"
	details.BackgroundTransparency = 1
	details.BorderSizePixel = 0
	details.Size = UDim2.new(1, 0, 0, 180)
	details.CanvasSize = UDim2.new()
	details.AutomaticCanvasSize = Enum.AutomaticSize.Y
	details.ScrollBarThickness = 4
	details.LayoutOrder = 7
	details.Visible = false
	details.Parent = seasonBar
	UiKit.list(details, 3)
	local detailsOpen = false
	local compactMode = false
	local detailsSignature = ""

	local function percent(value: number): string
		return string.format("%+d%%", math.floor(value * 100 + 0.5))
	end
	local function addTitle(text: string, order: number)
		local label = UiKit.text(details, text, "Caption", Color.Gold)
		label.LayoutOrder = order
	end
	-- Satır: solda ikon + ad, sağda renkli yüzde (yeşil = artı, kırmızı = eksi)
	local function addRow(icon: string, name: string, value: number, order: number)
		local row = Instance.new("Frame")
		row.BackgroundTransparency = 1
		row.Size = UDim2.new(1, 0, 0, 18)
		row.LayoutOrder = order
		row.Parent = details
		UiKit.iconChip(row, icon, 18, Color.SurfaceRaised)
		local label = UiKit.text(row, name, "Caption")
		label.AutomaticSize = Enum.AutomaticSize.None
		label.Position = UDim2.fromOffset(24, 0)
		label.Size = UDim2.new(1, -78, 1, 0)
		label.TextWrapped = false
		label.TextTruncate = Enum.TextTruncate.AtEnd
		local amount = UiKit.text(row, percent(value), "Caption", if value >= 0 then Color.Green else Color.Red)
		amount.AutomaticSize = Enum.AutomaticSize.None
		amount.AnchorPoint = Vector2.new(1, 0)
		amount.Position = UDim2.new(1, 0, 0, 0)
		amount.Size = UDim2.fromOffset(52, 18)
		amount.TextXAlignment = Enum.TextXAlignment.Right
	end
	local function addModifierRows(modifiers: { [string]: number }, order: number): number
		local count = 0
		for _, animalId in Config.ANIMAL_ORDER do
			local value = modifiers[animalId]
			local animal = Config.ANIMALS[animalId]
			if value and value ~= 0 and animal then
				count += 1
				local current = ClientState.get()
				local look = Config.getAnimalLook(animalId, if current then current.activeMainFarmId else nil)
				addRow(look.icon, look.displayName, value, order + count)
			end
		end
		return count
	end

	-- Toplam etki: mevsim + hava; hayvanların durduğu bölgelerin "mevsim uyumu" (olumlu etkiyi büyütür, olumsuzu küçültür) dahil.
	-- Aynı türden hayvanlar farklı bölgelerdeyse ortalaması alınır; hayvan yoksa uyumsuz (0) gösterilir.
	local function effectiveTotals(): ({ [string]: number }, string)
		local state = ClientState.get()
		local totals: { [string]: number } = {}
		local parts: { string } = {}
		for _, animalId in Config.ANIMAL_ORDER do
			local sum, count = 0, 0
			if state then
				for _, animal in state.animals do
					if animal.animalId == animalId then
						sum += FarmMath.getSeasonEffect(state, animalId, animal.zoneId).percent
						count += 1
					end
				end
			end
			totals[animalId] = if count > 0
				then sum / count
				else (if state
					then FarmMath.getSeasonEffect(state, animalId, nil).percent
					else Environment.getIncomeMultiplier(animalId) - 1)
			table.insert(parts, string.format("%.3f", totals[animalId]))
		end
		return totals, table.concat(parts, ",")
	end

	local function renderDetails(season: Config.SeasonConfig, weather: Config.WeatherConfig)
		local total, totalKey = effectiveTotals()
		local signature = `{season.id}|{weather.id}|{totalKey}`
		if signature == detailsSignature then
			return
		end
		detailsSignature = signature
		for _, child in details:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		local order = 0
		addTitle("Mevsim etkisi", order)
		order += 1
		local seasonRows = addModifierRows(season.incomeModifiers, order)
		order += seasonRows + 1
		if (season.orderBonus or 0) ~= 0 then
			addRow("📋", "Sipariş ödülü", season.orderBonus or 0, order)
			order += 1
		end
		addTitle("Hava etkisi", order)
		order += 1
		local weatherRows = addModifierRows(weather.incomeModifiers, order)
		order += weatherRows + 1
		if weatherRows == 0 then
			local none = UiKit.text(details, "Etki yok", "Caption")
			none.LayoutOrder = order
			order += 1
		end
		addTitle("Toplam etki (bölge uyumu dahil)", order)
		order += 1
		local totalRows = addModifierRows(total, order)
		if totalRows == 0 then
			local none = UiKit.text(details, "Etki yok", "Caption")
			none.LayoutOrder = order + 1
		else
			local hint =
				UiKit.text(details, "Hayvanın yanında yeşil ok: gelir artıyor, kırmızı ok: azalıyor", "Caption")
			hint.LayoutOrder = order + totalRows + 2
		end
	end

	local function applyDetailsVisibility()
		toggle.Visible = not compactMode
		details.Visible = detailsOpen and not compactMode
		toggle.Text = if detailsOpen then "Etkileri gizle" else "Etkileri göster"
	end
	toggle.Activated:Connect(function()
		detailsOpen = not detailsOpen
		applyDetailsVisibility()
	end)

	local seasonTints: { [string]: Color3 } = {
		spring = Color.Green,
		summer = Color.Gold,
		autumn = Color.Orange,
		winter = Color.Blue,
	}

	local function formatClock(seconds: number): string
		local s = math.max(0, math.ceil(seconds))
		return string.format("%02d:%02d", s // 60, s % 60)
	end

	local function updateSeasonBar()
		local season = Environment.getSeason()
		local weather = Environment.getWeather()
		local now = Workspace:GetServerTimeNow()
		local progress = Environment.getSeasonProgress(now)
		local left = math.max(0, Config.SEASON_SECONDS * (1 - progress))
		local tint = seasonTints[season.id] or Color.Green
		seasonChip.Text = season.icon
		seasonChip.BackgroundColor3 = tint
		seasonTitle.Text = season.displayName
		seasonClock.Text = `{formatClock(left)} kaldı`
		setSeasonProgress(progress, tint)
		nextSeasonLabel.Text = if ReplicatedStorage:GetAttribute("AdminSeasonOverride")
			then "Mevsim sabit"
			else `Sonra: {Environment.getNextSeason().displayName}`
		renderDetails(season, weather)
		local clockHour = Environment.getClockTime(now)
		local isNight = Environment.getNightFactor(clockHour) >= 0.5
		local dayPart = if isNight then "Gece" else "Gündüz"
		-- Gece "Güneşli" yazmak kafa karıştırır: açık hava geceleri "Açık" ve ay simgesiyle gösterilir
		local nightClear = isNight and weather.id == "sunny"
		weatherChip.Text = if nightClear then "🌙" else weather.icon
		weatherTitle.Text = string.format(
			"%s · %02d:%02d %s",
			if nightClear then "Açık" else weather.displayName,
			clockHour // 1,
			(clockHour % 1) * 60 // 1,
			dayPart
		)
	end

	local function setCompact(compact: boolean)
		nextSeasonLabel.Visible = not compact
		seasonClock.Visible = not compact
		seasonProgress.Visible = not compact
		compactMode = compact
		applyDetailsVisibility()
	end
	return { update = updateSeasonBar, setCompact = setCompact }
end

return SeasonBar
