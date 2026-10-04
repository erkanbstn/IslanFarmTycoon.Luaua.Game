--!strict
-- Sol orta "Stats" paneli: para + gelir, ahır, depo çubuğu ve ipucu satırı; sola kayarak kapanır (sağ kenarındaki sekme).
-- Mevsim kartı (SeasonBar) ile hedef/ada kartları (GoalCard) aynı panele eklenir.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local GameTypes = require(Shared:WaitForChild("GameTypes"))
local FarmMath = require(Shared:WaitForChild("Modules"):WaitForChild("FarmMath"))
local IslandContext = require(script.Parent.Parent.Parent:WaitForChild("Core"):WaitForChild("IslandContext"))
local UiKit = require(script.Parent.Parent:WaitForChild("UiKit"))

type PlayerSave = GameTypes.PlayerSave

local Color = UiKit.Color
local localPlayer = Players.LocalPlayer
local TAB_WIDTH = UiKit.TouchTarget -- açma sekmesi dokunma alt sınırında

local StatsPanel = {}

export type Hud = {
	frame: Frame,
	update: (state: PlayerSave, income: number) -> (),
	setCompact: (compact: boolean) -> (),
	bounceCash: () -> (),
	progressionButton: TextButton,
}

function StatsPanel.create(screenGui: Instance): Hud
	local stats = UiKit.panel(screenGui)
	stats.Name = "Stats"
	stats.AnchorPoint = Vector2.new(0, 0.5)
	stats.Position = UDim2.new(0, 12, 0.5, 0)
	stats.Size = UDim2.fromOffset(240, 0)
	stats.AutomaticSize = Enum.AutomaticSize.Y
	UiKit.padding(stats, 12)
	UiKit.list(stats, 8)
	local farmContextLabel = UiKit.text(stats, IslandContext.name(), "Caption", Color.Gold)
	farmContextLabel.LayoutOrder = -1
	local dataHealth = UiKit.text(stats, "", "Caption", Color.Red)
	dataHealth.LayoutOrder = 0
	dataHealth.Visible = false

	-- İkon kutusu + yanında alt alta yazılar (dönen çerçeveye yazılar eklenir)
	local function statRow(parent: Instance, order: number, icon: string, tint: Color3): Frame
		local row = Instance.new("Frame")
		row.BackgroundTransparency = 1
		row.Size = UDim2.new(1, 0, 0, 40)
		row.AutomaticSize = Enum.AutomaticSize.Y
		row.LayoutOrder = order
		row.Parent = parent

		UiKit.iconChip(row, icon, 40, tint)

		local texts = Instance.new("Frame")
		texts.BackgroundTransparency = 1
		texts.Position = UDim2.fromOffset(50, 0)
		texts.Size = UDim2.new(1, -50, 0, 0)
		texts.AutomaticSize = Enum.AutomaticSize.Y
		texts.Parent = row
		UiKit.list(texts, 0)
		return texts
	end

	local cashBlock = Instance.new("Frame")
	cashBlock.Name = "Wallet"
	cashBlock.BackgroundTransparency = 1
	cashBlock.Size = UDim2.new(1, 0, 0, 0)
	cashBlock.AutomaticSize = Enum.AutomaticSize.Y
	cashBlock.LayoutOrder = 1
	cashBlock.Parent = stats
	UiKit.list(cashBlock, 4)
	local cashTexts = statRow(cashBlock, 1, "💰", Color.Green)
	local cashLabel = UiKit.text(cashTexts, "$0", "Display", Color.Green)
	cashLabel.LayoutOrder = 1
	-- Para toplayınca kasadaki sayı hafifçe zıplar
	local cashScale = Instance.new("UIScale")
	cashScale.Parent = cashLabel
	local function bounceCash()
		if localPlayer:GetAttribute("ReducedMotion") == true then
			return
		end
		cashScale.Scale = 1.25
		TweenService:Create(cashScale, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Scale = 1,
		}):Play()
	end
	local incomeLabel = UiKit.text(cashTexts, "+$0/sn", "Caption")
	incomeLabel.LayoutOrder = 2
	local progressionButton = UiKit.button(cashBlock, "", "secondary")
	progressionButton.Name = "GoldWallet"
	progressionButton.Size = UDim2.new(1, 0, 0, UiKit.TouchTarget + 16)
	progressionButton.LayoutOrder = 2
	local goldIcon = UiKit.iconChip(progressionButton, "🪙", 30, Color.Gold)
	goldIcon.Name = "GoldIcon"
	goldIcon.AnchorPoint = Vector2.new(0, 0.5)
	goldIcon.Position = UDim2.new(0, 6, 0.5, 0)
	local goldAmount = UiKit.text(progressionButton, "Altın", "Body", Color.Green)
	goldAmount.Name = "GoldAmount"
	goldAmount.FontFace = UiKit.Font.Bold
	goldAmount.AutomaticSize = Enum.AutomaticSize.None
	goldAmount.Position = UDim2.fromOffset(44, 6)
	goldAmount.Size = UDim2.new(1, -50, 0, 24)
	goldAmount.TextWrapped = false
	goldAmount.TextTruncate = Enum.TextTruncate.AtEnd
	goldAmount.TextYAlignment = Enum.TextYAlignment.Center
	local rebirthLevel = UiKit.text(progressionButton, "Rebirth", "Caption", Color.TextMuted)
	rebirthLevel.Name = "RebirthLevel"
	rebirthLevel.AutomaticSize = Enum.AutomaticSize.None
	rebirthLevel.Position = UDim2.fromOffset(44, 30)
	rebirthLevel.Size = UDim2.new(1, -50, 0, 24)
	rebirthLevel.TextWrapped = false
	rebirthLevel.TextXAlignment = Enum.TextXAlignment.Left
	rebirthLevel.TextYAlignment = Enum.TextYAlignment.Center

	local barnTexts = statRow(stats, 2, "🏚️", Color.Red)
	local barnLabel = UiKit.text(barnTexts, "", "Heading")
	barnLabel.LayoutOrder = 1
	local barnDetail = UiKit.text(barnTexts, "", "Caption")
	barnDetail.LayoutOrder = 2

	-- Depo: başlık + değer, çubuk, ipucu
	local storageBlock = Instance.new("Frame")
	storageBlock.BackgroundTransparency = 1
	storageBlock.Size = UDim2.new(1, 0, 0, 0)
	storageBlock.AutomaticSize = Enum.AutomaticSize.Y
	storageBlock.LayoutOrder = 3
	storageBlock.Parent = stats
	UiKit.list(storageBlock, 6)

	local storageHeader = Instance.new("Frame")
	storageHeader.BackgroundTransparency = 1
	storageHeader.Size = UDim2.new(1, 0, 0, UiKit.TextSize.Heading + 6)
	storageHeader.LayoutOrder = 1
	storageHeader.Parent = storageBlock
	local storageTitle = UiKit.text(storageHeader, "Depo", "Heading")
	storageTitle.AutomaticSize = Enum.AutomaticSize.None
	storageTitle.Size = UDim2.fromScale(0.4, 1)
	local storageValue = UiKit.text(storageHeader, "", "Body", Color.TextMuted)
	storageValue.AutomaticSize = Enum.AutomaticSize.None
	storageValue.AnchorPoint = Vector2.new(1, 0)
	storageValue.Position = UDim2.fromScale(1, 0)
	storageValue.Size = UDim2.fromScale(0.6, 1)
	storageValue.TextXAlignment = Enum.TextXAlignment.Right
	storageValue.TextWrapped = false
	storageValue.TextTruncate = Enum.TextTruncate.AtEnd

	local storageBar, setStorageBar = UiKit.progressBar(storageBlock, 10)
	storageBar.LayoutOrder = 2
	local hintLabel = UiKit.text(storageBlock, "", "Caption")
	hintLabel.LayoutOrder = 3
	local hintWanted = false -- yalnızca sorun varken görünür

	local cashValue = Instance.new("NumberValue")
	local cashTween: Tween? = nil
	local cashTarget: number? = nil
	cashValue.Changed:Connect(function(value: number)
		UiKit.setText(cashLabel, FarmMath.formatMoney(value))
	end)
	local function animateCash(target: number)
		if cashTarget == target then
			return
		end
		local first = cashTarget == nil
		cashTarget = target
		if cashTween then
			cashTween:Cancel()
		end
		if first or localPlayer:GetAttribute("ReducedMotion") == true then
			cashValue.Value = target
			return
		end
		local tween = TweenService:Create(cashValue, TweenInfo.new(0.4, Enum.EasingStyle.Quad), { Value = target })
		cashTween = tween
		tween:Play()
	end

	local compact = false
	local function update(state: PlayerSave, income: number)
		UiKit.setText(farmContextLabel, IslandContext.name())
		local status = localPlayer:GetAttribute("DataStatus")
		local dataError = localPlayer:GetAttribute("DataError")
		dataHealth.Visible = status ~= "Active" or (typeof(dataError) == "string" and dataError ~= "")
		UiKit.setText(
			dataHealth,
			if status ~= "Active"
				then "Kayıt bağlantısı kesildi. Ekonomi durduruldu; lütfen yeniden katıl."
				else "Son kayıt tamamlanamadı; tekrar deneniyor."
		)
		local cap = FarmMath.getStorageCap(state)
		local barnConfig = FarmMath.getBarnConfig(state)
		animateCash(state.cash)
		UiKit.setText(goldAmount, `Altın: {state.gold or 0}`)
		UiKit.setText(rebirthLevel, `Rebirth: {if state.progression then state.progression.count else 0}`)
		UiKit.setText(incomeLabel, `+${FarmMath.formatRate(income)}/sn gelir`)
		UiKit.setText(barnLabel, barnConfig.displayName)
		local ownedIslands, totalIslands = FarmMath.countIslands(state)
		local islandAnimals, islandCapacity = 0, 0
		for zoneId, zone in Config.ZONES do
			if zone.island == IslandContext.get() and state.unlockedZones[zoneId] then
				islandAnimals += FarmMath.countInZone(state, zoneId)
				islandCapacity += FarmMath.getZoneCapacity(state, zoneId)
			end
		end
		UiKit.setText(
			barnDetail,
			`Seviye {state.barnLevel} · Ada {ownedIslands}/{totalIslands}\nBu ada: {islandAnimals}/{islandCapacity} hayvan`
		)
		local auto = FarmMath.hasAutoCollect(state)
		if auto then
			UiKit.setText(storageValue, "Otomatik")
			setStorageBar(1, Color.Green)
		else
			local ratio = if cap > 0 then state.stored / cap else 0
			UiKit.setText(storageValue, `{FarmMath.formatMoney(state.stored)} / {FarmMath.formatMoney(cap)}`)
			setStorageBar(ratio, if ratio >= 1 then Color.Red elseif ratio > 0.8 then Color.Orange else Color.Green)
		end
		UiKit.setText(
			hintLabel,
			if localPlayer:GetAttribute("DataPersistent") == false
				then "Kayıtsız Studio testi: bu ilerleme saklanmaz."
				elseif auto then "Otomatik toplama açık. Çevrimdışı kazanç da kasana eklenir."
				elseif state.stored >= cap then "Depo dolu, üretim durdu! Yeşil platforma bas."
				else "Parayı almak için yeşil platforma bas. Çevrimdışı kazanç kasana eklenir."
		)
		-- İpucu satırı yalnızca bir şey ters giderken görünür (depo dolu ya da kayıtsız test); sürekli aynı cümle HUD'u kalabalıklaştırır
		hintWanted = state.stored >= cap or localPlayer:GetAttribute("DataPersistent") == false
		hintLabel.Visible = hintWanted and not compact
	end

	-- Açılır/kapanır panel: sola kayar, sağ kenarındaki küçük sekme ile açılıp kapanır.
	-- Varsayılan: geniş ekranda açık, dar ekranda kapalı; oyuncu sekmeye basınca seçimi korunur.
	local collapsed = false
	local userChoice = false
	local positionTween: Tween? = nil

	local tab = Instance.new("TextButton")
	tab.Name = "StatsToggle"
	tab.Text = ""
	tab.AnchorPoint = Vector2.new(0, 0.5)
	tab.Size = UDim2.fromOffset(TAB_WIDTH, 60)
	tab.BackgroundColor3 = Color.Panel
	tab.BackgroundTransparency = 0.05
	tab.AutoButtonColor = true
	tab.Parent = screenGui
	UiKit.corner(tab, UiKit.Radius.Card)
	UiKit.stroke(tab, 0.6)
	-- Ok işareti font karakteri değil, çizilmiş iki çubuk (kapatırken "<", açarken ">")
	local arms: { Frame } = {}
	for index = 1, 2 do
		local arm = Instance.new("Frame")
		arm.AnchorPoint = Vector2.new(0.5, 0.5)
		arm.Position = UDim2.new(0, TAB_WIDTH / 2, 0.5, if index == 1 then -4 else 4)
		arm.Size = UDim2.fromOffset(12, 2)
		arm.BackgroundColor3 = Color.Text
		arm.BorderSizePixel = 0
		arm.Parent = tab
		UiKit.corner(arm, 1)
		arms[index] = arm
	end

	-- Panel kapalıyken sekmenin yanında kasa görünür (panel açılınca gizlenir)
	local tabCash = UiKit.text(tab, "$0", "Heading", Color.Green) -- kapalıyken de rahat okunsun: para yeşil, büyük
	tabCash.AutomaticSize = Enum.AutomaticSize.None
	tabCash.AnchorPoint = Vector2.new(0, 0.5)
	tabCash.Position = UDim2.new(0, TAB_WIDTH + 2, 0.5, 0)
	tabCash.Size = UDim2.new(1, -(TAB_WIDTH + 6), 1, 0)
	tabCash.TextXAlignment = Enum.TextXAlignment.Left
	tabCash.Visible = false
	-- Kapalı sekme paraya göre büyür: sayı uzadıkça genişler (sabit kutu değil)
	local collapsedTab = false
	local function fitTab()
		if collapsedTab then
			tab.Size = UDim2.fromOffset(TAB_WIDTH + 14 + math.max(tabCash.TextBounds.X, 40), 60)
		end
	end
	cashLabel:GetPropertyChangedSignal("Text"):Connect(function()
		tabCash.Text = cashLabel.Text
		fitTab()
	end)
	tabCash:GetPropertyChangedSignal("TextBounds"):Connect(fitTab)
	tabCash.Text = cashLabel.Text

	local function expandedPosition(): UDim2
		return if compact then UDim2.fromOffset(8, 8) else UDim2.new(0, 12, 0.5, 0)
	end
	local function panelWidth(): number
		return if compact then 200 else 240
	end
	local function followTab()
		-- Mutlak değerler ekran pikselidir; sekme ölçekli kökün altında olduğu için kök konumu çıkarılıp ölçeğe bölünür.
		local origin = if screenGui:IsA("GuiBase2d") then screenGui.AbsolutePosition else Vector2.zero
		local scale = UiKit.screenScale()
		tab.Position = UDim2.fromOffset(
			(stats.AbsolutePosition.X - origin.X) / scale + stats.AbsoluteSize.X / scale + 6,
			(stats.AbsolutePosition.Y - origin.Y) / scale + stats.AbsoluteSize.Y / scale / 2
		)
	end
	stats:GetPropertyChangedSignal("AbsolutePosition"):Connect(followTab)
	stats:GetPropertyChangedSignal("AbsoluteSize"):Connect(followTab)

	local function applyPosition(animate: boolean)
		local base = expandedPosition()
		local target = if collapsed then base + UDim2.fromOffset(-(panelWidth() + 24), 0) else base
		-- Kapalıyken "<" yerine ">" (joint sağda), açıkken "<" (joint solda)
		arms[1].Rotation = if collapsed then 45 else -45
		arms[2].Rotation = if collapsed then -45 else 45
		collapsedTab = collapsed
		tab.Size = UDim2.fromOffset(TAB_WIDTH, 60)
		fitTab()
		tabCash.Visible = collapsed
		if positionTween then
			positionTween:Cancel()
			positionTween = nil
		end
		if animate and localPlayer:GetAttribute("ReducedMotion") ~= true then
			local tween = TweenService:Create(
				stats,
				TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
				{ Position = target }
			)
			positionTween = tween
			tween:Play()
		else
			stats.Position = target
		end
	end

	tab.Activated:Connect(function()
		userChoice = true
		collapsed = not collapsed
		applyPosition(true)
	end)

	local function setCompact(value: boolean)
		compact = value
		if not userChoice then
			collapsed = value
		end
		stats.AnchorPoint = if compact then Vector2.zero else Vector2.new(0, 0.5)
		stats.Size = UDim2.fromOffset(panelWidth(), 0)
		farmContextLabel.Visible = not compact
		hintLabel.Visible = hintWanted and not compact
		applyPosition(false)
	end

	return {
		frame = stats,
		update = update,
		setCompact = setCompact,
		bounceCash = bounceCash,
		progressionButton = progressionButton,
	}
end

return StatsPanel
