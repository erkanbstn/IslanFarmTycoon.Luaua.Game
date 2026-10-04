--!strict
-- Yükseltmeler penceresi: seçili adanın açık yükseltmeleri (alınanlar listeden çıkar).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local GameTypes = require(Shared:WaitForChild("GameTypes"))
local FarmMath = require(Shared:WaitForChild("Modules"):WaitForChild("FarmMath"))
local Progression = require(Shared:WaitForChild("Modules"):WaitForChild("Progression"))
local UiKit = require(script.Parent.Parent:WaitForChild("UiKit"))
local ClientState = require(script.Parent.Parent.Parent:WaitForChild("Core"):WaitForChild("ClientState"))
local PurchaseController = require(script.Parent.Parent.Parent:WaitForChild("Core"):WaitForChild("PurchaseController"))
local IslandContext = require(script.Parent.Parent.Parent:WaitForChild("Core"):WaitForChild("IslandContext"))
local IslandManager = require(script.Parent.Parent:WaitForChild("IslandManager"))
local HudCommon = require(script.Parent:WaitForChild("HudCommon"))
local IslandTabs = require(script.Parent:WaitForChild("IslandTabs"))
local ActionBadges = require(script.Parent:WaitForChild("ActionBadges"))

type PlayerSave = GameTypes.PlayerSave

local Color = UiKit.Color
local setPurchaseButton = HudCommon.setPurchaseButton

local UpgradesWindow = {}

export type Upgrades = {
	window: UiKit.Window,
	update: (state: PlayerSave, content: boolean) -> (),
	focus: (category: string) -> (),
}

function UpgradesWindow.create(screenGui: Instance, WINDOW_POSITION: UDim2): Upgrades
	local upgradesWindow = UiKit.window(screenGui, {
		title = "Yükseltmeler",
		icon = "🛠️",
		tint = Color.Gold,
		width = 600,
		maxHeight = 560,
		anchor = Vector2.new(0.5, 0.5),
		position = WINDOW_POSITION,
	})
	local upgradesInfo =
		UiKit.text(upgradesWindow.list, "Ada değiştirmek için sekmeleri kullan · Kısayol: U", "Caption")
	upgradesInfo.LayoutOrder = -2
	local refreshTab: (() -> ())? = nil
	local islandTabs = IslandTabs.add(upgradesWindow, function()
		if refreshTab then
			refreshTab()
		end
	end)
	-- Kategori sekmeleri: Yapılar (satın alınacak yükseltmeler) | Geliştirmeler (bölge ve tesis seviyeleri)
	local currentTab = "upgrades"
	local _, chooseTab, setTabBadge = UiKit.tabs(upgradesWindow.list, 0, {
		{ id = "upgrades", label = "Yapılar" },
		{ id = "levels", label = "Seviyeler" },
		{ id = "expansions", label = "Geliştirmeler" },
	}, function(id: string)
		currentTab = id
		if refreshTab then
			refreshTab()
		end
	end)
	local completed = UiKit.emptyState(
		upgradesWindow.list,
		"✅",
		"Yapılar tamamlandı",
		"Bu adanın yapılarını tamamladın. Diğer sekmelerden seviyeleri ve geliştirmeleri inceleyebilirsin."
	)
	local upgradesEmpty = completed.description
	completed.frame.LayoutOrder = 1
	completed.frame.Visible = false
	local nextIslandButton = UiKit.button(upgradesWindow.list, "Adalar'da sıradaki yatırımı seç", "primary")
	nextIslandButton.Size = UDim2.new(1, 0, 0, 42)
	nextIslandButton.LayoutOrder = 2
	nextIslandButton.Visible = false
	nextIslandButton.Activated:Connect(IslandManager.open)
	local directUpgradeCards: { [string]: UiKit.Card } = {}
	local directDetails: { [string]: UiKit.Disclosure } = {}
	local requirements: { [string]: TextLabel } = {}
	-- Kartlar 2 sütunlu esnek ızgaradır (alt alta uzun liste yerine)
	local upgradeGrid = UiKit.autoGrid(upgradesWindow.list, 3)
	for index, upgrade in Config.UPGRADES do
		local card = UiKit.autoTile(upgradeGrid, index + 1, upgrade.icon)
		card.title.Text = upgrade.displayName
		directUpgradeCards[upgrade.id] = card
		directDetails[upgrade.id] = UiKit.cardDetails(card, "Ayrıntılar")
		local needed = UiKit.text(card.frame, "", "Caption", Color.Orange)
		needed.LayoutOrder = 3
		needed.Visible = false
		requirements[upgrade.id] = needed
		card.action.Activated:Connect(function()
			if card.action.Active then
				PurchaseController.submit("RequestBuyUpgrade", upgrade.id)
			end
		end)
	end

	-- Yapı geliştirme: seçili adanın açık bölgeleri ve kurulu tesisleri; her seviye yapının işlevine uygun bir fayda demeti verir
	local EXPANSION_ORDER = 1000
	local expansionHeader = UiKit.sectionHeader(upgradesWindow.list, "Geliştirmeler", EXPANSION_ORDER)
	local expansionCards: { [string]: UiKit.Card } = {}
	local expansionDetails: { [string]: UiKit.Disclosure } = {}
	local expansionSummary: { [string]: TextLabel } = {}
	local expansionGrid = UiKit.autoGrid(upgradesWindow.list, EXPANSION_ORDER + 1)
	for index, targetId in Config.BUILD_ORDER do
		local card = UiKit.autoTile(expansionGrid, EXPANSION_ORDER + index, Config.BUILD_TARGETS[targetId].icon)
		card.frame.Visible = false
		expansionCards[targetId] = card
		expansionDetails[targetId] = UiKit.cardDetails(card, "Ayrıntılar")
		local summary = UiKit.text(card.frame, "", "Caption")
		summary.LayoutOrder = 3
		expansionSummary[targetId] = summary
		card.action.Activated:Connect(function()
			if card.action.Active then
				PurchaseController.submit("RequestExpandZone", targetId)
			end
		end)
	end

	-- Her fayda ayrı satırda; dar karolarda fiyat düğmesine taşmaz.
	local function effectText(zone: Config.ZoneConfig?, bundle: Config.BuildLevelEffects): string
		local parts: { string } = {}
		if bundle.capacity then
			local step = if zone then FarmMath.getExpansionStep(zone) else 0
			table.insert(parts, `+{bundle.capacity * step} kapasite`)
		end
		if bundle.growthSpeed then
			table.insert(parts, `Büyüme +%{math.round((bundle.growthSpeed - 1) * 100)}`)
		end
		if bundle.incomeBonus then
			table.insert(parts, `Verim +%{math.round(bundle.incomeBonus * 100)}`)
		end
		if bundle.seasonAffinity then
			table.insert(parts, `Mevsim uyumu +%{math.round(bundle.seasonAffinity * 100)}`)
		end
		if bundle.speed then
			table.insert(parts, `Süre -%{math.round((1 - bundle.speed) * 100)}`)
		end
		if bundle.yield then
			table.insert(parts, `Satış +%{math.round(bundle.yield * 100)}`)
		end
		if bundle.thrift then
			table.insert(parts, `Başlatma -%{math.round(bundle.thrift * 100)}`)
		end
		return table.concat(parts, "\n")
	end

	local function updateExpansions(state: PlayerSave, content: boolean)
		local selectedIsland = islandTabs.get()
		local any = false
		for _, targetId in Config.BUILD_ORDER do
			local target = Config.BUILD_TARGETS[targetId]
			local card = expansionCards[targetId]
			local zone = Config.ZONES[targetId]
			local status, reason, cost = FarmMath.getExpansionStatus(state, targetId)
			-- Tamamlananlar listeden çıkar (alınan yükseltmeler gibi)
			local shown = target.island == selectedIsland
				and status ~= "max"
				and (if target.isZone then state.unlockedZones[targetId] == true else status ~= "locked")
			card.frame.Visible = shown and currentTab == "expansions"
			if not shown then
				continue
			end
			any = true
			-- Alınabilir olanlar üstte, parası yetmeyenler sonra, kilitliler en altta (yükseltmelerle aynı düzen)
			local group = if status == "locked" then 2 elseif state.cash >= cost then 0 else 1
			card.frame.LayoutOrder = EXPANSION_ORDER + group * 100 + table.find(Config.BUILD_ORDER, targetId) :: number
			if content then
				-- Ana ada ağılının simgesi çiftliğin hayvanına göre (inek/tavuk/ördek)
				card.icon.Text = Config.getBuildTargetIcon(targetId, state.activeMainFarmId)
				local level = FarmMath.getExpansionLevel(state, targetId)
				local nextLevel = FarmMath.getNextBuildLevel(state, targetId)
				card.title.Text =
					`{Config.getBuildTargetName(targetId, state.activeMainFarmId)} · Sv.{level}/{Config.BUILD_UPGRADES.maxLevel}`
				local text = if nextLevel then effectText(zone, nextLevel) else "Tüm seviyeler tamamlandı"
				UiKit.setText(card.detail, text)
				UiKit.setText(expansionSummary[targetId], string.match(text, "[^\n]+") or "")
			end
			if status == "max" then
				UiKit.setCardStatus(card, nil)
				setPurchaseButton(card.action, "En üst seviye", "owned")
			elseif status == "locked" then
				-- Kilitli: düğme yerine kartın sağ üstünde kırmızı yazı
				UiKit.setCardStatus(
					card,
					if reason == "Önce bölgeyi hayvanla doldur" then "Dolunca açılır" else "Kilitli"
				)
			else
				UiKit.setCardStatus(card, nil)
				setPurchaseButton(
					card.action,
					FarmMath.formatMoney(cost),
					if state.cash >= cost then "primary" else "warning"
				)
			end
		end
		(expansionHeader.Parent :: GuiObject).Visible = any and currentTab == "expansions"
	end

	local lastContext = ""
	local function updateUpgrades(state: PlayerSave, content: boolean)
		islandTabs.update(state)
		local context =
			`{state.activeMainFarmId}:{islandTabs.get()}:{if state.progression then state.progression.run else 0}`
		if context ~= lastContext then
			lastContext = context
			for _, details in directDetails do
				details.setExpanded(false)
			end
			for _, details in expansionDetails do
				details.setExpanded(false)
			end
		end
		updateExpansions(state, content)
		local remaining = 0
		local selectedIsland = islandTabs.get()
		local _, counts = ActionBadges.upgrades(state)
		local islandCounts: { [string]: number } = {}
		for islandId, value in counts do
			islandCounts[islandId] = value.total
		end
		islandTabs.setBadges(islandCounts)
		local selectedCounts = counts[selectedIsland]
		for _, category in { "upgrades", "levels", "expansions" } do
			setTabBadge(category, if selectedCounts then selectedCounts[category] else 0)
		end
		if content then
			UiKit.setText(upgradesInfo, islandTabs.name())
			UiKit.setText(
				upgradesEmpty,
				"Bu adanın yapılarını tamamladın. Diğer sekmelerden seviyeleri ve geliştirmeleri inceleyebilirsin."
			)
			UiKit.setText(completed.title, "Yapılar tamamlandı")
		end
		for index, upgrade in Config.UPGRADES do
			local card = directUpgradeCards[upgrade.id]
			local relevant = IslandContext.upgradeIsland(upgrade) == selectedIsland
				and FarmMath.isUpgradeInTheme(state, upgrade)
			if not relevant then
				card.frame.Visible = false
				continue
			end
			local status, missing = FarmMath.getUpgradeStatus(state, upgrade.id)
			-- Seviyeli zincirler (yem kalitesi, depo, büyüme, yardımcılar, eklenti kapasitesi) kendi sekmesinde
			local tabId = if upgrade.leveled then "levels" else "upgrades"
			local group = if status == "locked" then 2 elseif HudCommon.upgradeAffordable(state, upgrade) then 0 else 1
			card.frame.LayoutOrder = index + 1 + group * #Config.UPGRADES
			if content then
				card.frame.Visible = status ~= "owned" and currentTab == tabId
				local needs = if status == "locked" then nil else HudCommon.goodsNeedText(state, upgrade)
				UiKit.setText(requirements[upgrade.id], needs or "")
				requirements[upgrade.id].Visible = needs ~= nil
				card.detail.Text = if status == "locked"
					then `Önce: {table.concat(missing, ", ")}`
					elseif needs then `{upgrade.description}\n{needs}`
					else upgrade.description
			end
			if status ~= "owned" then
				if tabId == "upgrades" then
					remaining += 1
				end
				UiKit.setCardStatus(card, if status == "locked" then "Kilitli" else nil)
				if status ~= "locked" then
					setPurchaseButton(
						card.action,
						FarmMath.formatMoney(FarmMath.getUpgradeCost(state, upgrade)),
						HudCommon.upgradeVariant(state, upgrade)
					)
				end
			end
		end
		if content then
			completed.frame.Visible = remaining == 0 and currentTab == "upgrades"
			nextIslandButton.Visible = false
			if remaining == 0 then
				local pendingUpgrade: Config.UpgradeConfig? = nil
				local pendingIsland: string? = nil
				for _, upgrade in Config.UPGRADES do
					local islandId = IslandContext.upgradeIsland(upgrade)
					if islandId == selectedIsland then
						continue
					end
					if FarmMath.getUpgradeStatus(state, upgrade.id) == "available" then
						pendingUpgrade = upgrade
						pendingIsland = islandId
						break
					end
				end
				if pendingUpgrade and pendingIsland then
					local pendingIslandName = Config.FARM_ISLANDS[pendingIsland].displayName
					UiKit.setText(upgradesEmpty, `Sırada: {pendingUpgrade.displayName} · {pendingIslandName}`)
					nextIslandButton.Visible = currentTab == "upgrades"
				end
				if Progression.canRebirth(state) then
					UiKit.setText(completed.title, "REBIRTH HAZIR")
					UiKit.setText(
						upgradesEmpty,
						"Rebirth menüsünden kalıcı ödülünü seçerek yeni tura başlayabilirsin."
					)
					nextIslandButton.Visible = false
				end
			end
			upgradesInfo.Visible = true
		end
	end
	upgradesWindow.frame:GetPropertyChangedSignal("Visible"):Connect(function()
		if not upgradesWindow.isOpen() then
			for _, details in directDetails do
				details.setExpanded(false)
			end
			for _, details in expansionDetails do
				details.setExpanded(false)
			end
		end
	end)

	refreshTab = function()
		local state = ClientState.get()
		if state then
			updateUpgrades(state, true)
		end
	end
	return {
		window = upgradesWindow,
		update = updateUpgrades,
		focus = function(category: string)
			if category ~= "upgrades" and category ~= "levels" and category ~= "expansions" then
				return
			end
			currentTab = category
			chooseTab(category)
			upgradesWindow.list.CanvasPosition = Vector2.zero
			if refreshTab then
				refreshTab()
			end
		end,
	}
end

return UpgradesWindow
