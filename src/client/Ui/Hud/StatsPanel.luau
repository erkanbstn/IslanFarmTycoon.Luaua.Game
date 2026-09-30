--!strict
-- Sol orta "Stats" paneli: para + gelir, depo çubuğu, ipucu satırı ve ahır satırı (Çiftliğim penceresinde).
-- Mevsim kartı (SeasonBar) ve hedef kartı (GoalCard) aynı panele eklenir.

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

local StatsPanel = {}

export type Hud = {
	frame: Frame,
	update: (state: PlayerSave, income: number) -> (),
	setCompact: (compact: boolean) -> (),
	bounceCash: () -> (),
}

function StatsPanel.create(screenGui: ScreenGui, goalsList: Instance): Hud
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
		row.LayoutOrder = order
		row.Parent = parent

		UiKit.iconChip(row, icon, 40, tint)

		local texts = Instance.new("Frame")
		texts.BackgroundTransparency = 1
		texts.AnchorPoint = Vector2.new(0, 0.5)
		texts.Position = UDim2.new(0, 50, 0.5, 0)
		texts.Size = UDim2.new(1, -50, 0, 0)
		texts.AutomaticSize = Enum.AutomaticSize.Y
		texts.Parent = row
		UiKit.list(texts, 0)
		return texts
	end

	local cashTexts = statRow(stats, 1, "💰", Color.Gold)
	local cashLabel = UiKit.text(cashTexts, "$0", "Display", Color.Gold)
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

	local barnTexts = statRow(goalsList, 1, "🏚️", Color.Red)
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
	storageHeader.Size = UDim2.new(1, 0, 0, 20)
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

	local storageBar, setStorageBar = UiKit.progressBar(storageBlock, 10)
	storageBar.LayoutOrder = 2
	local hintLabel = UiKit.text(storageBlock, "", "Caption")
	hintLabel.LayoutOrder = 3
	local hintWanted = false -- yalnızca sorun varken görünür

	local cashValue = Instance.new("NumberValue")
	local cashTween: Tween? = nil
	local cashTarget: number? = nil
	cashValue.Changed:Connect(function(value: number)
		cashLabel.Text = FarmMath.formatMoney(value)
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
		farmContextLabel.Text = IslandContext.name()
		local status = localPlayer:GetAttribute("DataStatus")
		local dataError = localPlayer:GetAttribute("DataError")
		dataHealth.Visible = status ~= "Active" or (typeof(dataError) == "string" and dataError ~= "")
		dataHealth.Text = if status ~= "Active"
			then "Kayıt bağlantısı kesildi. Ekonomi durduruldu; lütfen yeniden katıl."
			else "Son kayıt tamamlanamadı; tekrar deneniyor."
		local cap = FarmMath.getStorageCap(state)
		local barnConfig = FarmMath.getBarnConfig(state)
		animateCash(state.cash)
		incomeLabel.Text = `+${FarmMath.formatRate(income)}/sn gelir`
		barnLabel.Text = barnConfig.displayName
		local ownedIslands, totalIslands = FarmMath.countIslands(state)
		local islandAnimals, islandCapacity = 0, 0
		for zoneId, zone in Config.ZONES do
			if zone.island == IslandContext.get() and state.unlockedZones[zoneId] then
				islandAnimals += FarmMath.countInZone(state, zoneId)
				islandCapacity += FarmMath.getZoneCapacity(state, zoneId)
			end
		end
		barnDetail.Text =
			`Seviye {state.barnLevel} · Ada {ownedIslands}/{totalIslands}\nBu ada: {islandAnimals}/{islandCapacity} hayvan`
		local auto = FarmMath.hasAutoCollect(state)
		if auto then
			storageValue.Text = "Otomatik"
			setStorageBar(1, Color.Green)
		else
			local ratio = if cap > 0 then state.stored / cap else 0
			storageValue.Text = `{FarmMath.formatMoney(state.stored)} / {FarmMath.formatMoney(cap)}`
			setStorageBar(ratio, if ratio >= 1 then Color.Red elseif ratio > 0.8 then Color.Orange else Color.Green)
		end
		hintLabel.Text = if localPlayer:GetAttribute("DataPersistent") == false
			then "Kayıtsız Studio testi: bu ilerleme saklanmaz."
			elseif auto then "Otomatik toplama açık. Çevrimdışı kazanç da kasana eklenir."
			elseif state.stored >= cap then "Depo dolu, üretim durdu! Yeşil platforma bas."
			else "Parayı almak için yeşil platforma bas. Çevrimdışı kazanç kasana eklenir."
		-- İpucu satırı yalnızca bir şey ters giderken görünür (depo dolu ya da kayıtsız test); sürekli aynı cümle HUD'u kalabalıklaştırır
		hintWanted = state.stored >= cap or localPlayer:GetAttribute("DataPersistent") == false
		hintLabel.Visible = hintWanted and not compact
	end

	local function setCompact(value: boolean)
		compact = value
		stats.AnchorPoint = if compact then Vector2.zero else Vector2.new(0, 0.5)
		stats.Position = if compact then UDim2.fromOffset(8, 8) else UDim2.new(0, 12, 0.5, 0)
		stats.Size = if compact then UDim2.fromOffset(200, 0) else UDim2.fromOffset(240, 0)
		farmContextLabel.Visible = not compact
		hintLabel.Visible = hintWanted and not compact
	end

	return {
		frame = stats,
		update = update,
		setCompact = setCompact,
		bounceCash = bounceCash,
	}
end

return StatsPanel
