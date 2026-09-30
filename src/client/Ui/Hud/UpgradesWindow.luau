--!strict
-- Yükseltmeler penceresi: seçili adanın açık yükseltmeleri (alınanlar listeden çıkar).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local GameTypes = require(Shared:WaitForChild("GameTypes"))
local FarmMath = require(Shared:WaitForChild("Modules"):WaitForChild("FarmMath"))
local UiKit = require(script.Parent.Parent:WaitForChild("UiKit"))
local PurchaseController = require(script.Parent.Parent.Parent:WaitForChild("Core"):WaitForChild("PurchaseController"))
local IslandContext = require(script.Parent.Parent.Parent:WaitForChild("Core"):WaitForChild("IslandContext"))
local IslandManager = require(script.Parent.Parent:WaitForChild("IslandManager"))
local HudCommon = require(script.Parent:WaitForChild("HudCommon"))
local IslandTabs = require(script.Parent:WaitForChild("IslandTabs"))

type PlayerSave = GameTypes.PlayerSave

local Color = UiKit.Color
local setPurchaseButton = HudCommon.setPurchaseButton

local UpgradesWindow = {}

export type Upgrades = {
	window: UiKit.Window,
	update: (state: PlayerSave, content: boolean) -> (),
}

function UpgradesWindow.create(screenGui: ScreenGui, WINDOW_POSITION: UDim2): Upgrades
	local upgradesWindow = UiKit.window(screenGui, {
		title = "Yükseltmeler",
		icon = "🛠️",
		tint = Color.Gold,
		width = 330,
		maxHeight = 430,
		anchor = Vector2.new(1, 0.5),
		position = WINDOW_POSITION,
	})
	local upgradesInfo =
		UiKit.text(upgradesWindow.list, "Ada değiştirmek için sekmeleri kullan · Kısayol: U", "Caption")
	upgradesInfo.LayoutOrder = 0
	IslandTabs.add(upgradesWindow)
	local upgradesEmpty = UiKit.text(
		upgradesWindow.list,
		"Tüm yükseltmeleri aldın. Çiftliğini hayvanlarla büyütmeye devam edebilirsin.",
		"Body"
	)
	upgradesEmpty.LayoutOrder = 1
	upgradesEmpty.Visible = false
	local nextIslandButton = UiKit.button(upgradesWindow.list, "Adalar'da sıradaki yatırımı seç", "primary")
	nextIslandButton.Size = UDim2.new(1, 0, 0, 42)
	nextIslandButton.LayoutOrder = 2
	nextIslandButton.Visible = false
	nextIslandButton.Activated:Connect(IslandManager.open)
	local directUpgradeCards: { [string]: UiKit.Card } = {}
	for index, upgrade in Config.UPGRADES do
		local card = UiKit.card(upgradesWindow.list, index + 1, upgrade.icon)
		card.title.Text = upgrade.displayName
		directUpgradeCards[upgrade.id] = card
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
	for index, targetId in Config.BUILD_ORDER do
		local card = UiKit.card(upgradesWindow.list, EXPANSION_ORDER + index, Config.BUILD_TARGETS[targetId].icon)
		card.frame.Visible = false
		expansionCards[targetId] = card
		card.action.Activated:Connect(function()
			if card.action.Active then
				PurchaseController.submit("RequestExpandZone", targetId)
			end
		end)
	end

	-- Bir seviyenin faydaları: " · " ile ayrılmış kısa parçalar (her parça ayrı çevrilir)
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
		return table.concat(parts, " · ")
	end

	local function updateExpansions(state: PlayerSave, content: boolean)
		local selectedIsland = IslandContext.get()
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
			card.frame.Visible = shown
			if not shown then
				continue
			end
			any = true
			-- Alınabilir olanlar üstte, parası yetmeyenler sonra, kilitliler en altta (yükseltmelerle aynı düzen)
			local group = if status == "locked" then 2 elseif state.cash >= cost then 0 else 1
			card.frame.LayoutOrder = EXPANSION_ORDER + group * 100 + table.find(Config.BUILD_ORDER, targetId) :: number
			if content then
				local level = FarmMath.getExpansionLevel(state, targetId)
				local nextLevel = FarmMath.getNextBuildLevel(state, targetId)
				card.title.Text =
					`{Config.getBuildTargetName(targetId, state.activeMainFarmId)} · Sv.{level}/{Config.BUILD_UPGRADES.maxLevel}`
				card.detail.Text = if nextLevel then effectText(zone, nextLevel) else "Tüm seviyeler tamamlandı"
			end
			if status == "max" then
				setPurchaseButton(card.action, "En üst seviye", "owned")
			elseif status == "locked" then
				setPurchaseButton(
					card.action,
					if reason == "Önce bölgeyi hayvanla doldur" then "Dolunca açılır" else "Kilitli",
					"disabled"
				)
			else
				setPurchaseButton(
					card.action,
					FarmMath.formatMoney(cost),
					if state.cash >= cost then "primary" else "warning"
				)
			end
		end
		(expansionHeader.Parent :: GuiObject).Visible = any
	end

	local function updateUpgrades(state: PlayerSave, content: boolean)
		updateExpansions(state, content)
		local remaining = 0
		local selectedIsland = IslandContext.get()
		if content then
			upgradesInfo.Text = `{IslandContext.name()} · Ada değiştirmek için sekmeleri kullan`
			upgradesEmpty.Text =
				`{IslandContext.name()} yükseltmeleri tamamlandı. Sıradaki yatırımını seçmek için Adalar'ı aç.`
		end
		for index, upgrade in Config.UPGRADES do
			local card = directUpgradeCards[upgrade.id]
			local relevant = IslandContext.upgradeIsland(upgrade) == selectedIsland
			if not relevant then
				card.frame.Visible = false
				continue
			end
			local status, missing = FarmMath.getUpgradeStatus(state, upgrade.id)
			local group = if status == "locked"
				then 2
				elseif state.cash >= FarmMath.getUpgradeCost(state, upgrade) then 0
				else 1
			card.frame.LayoutOrder = index + 1 + group * #Config.UPGRADES
			if content then
				card.frame.Visible = status ~= "owned"
				card.detail.Text = if status == "locked"
					then `Önce: {table.concat(missing, ", ")}`
					else upgrade.description
			end
			if status ~= "owned" then
				remaining += 1
				setPurchaseButton(
					card.action,
					if status == "locked"
						then "Kilitli"
						else FarmMath.formatMoney(FarmMath.getUpgradeCost(state, upgrade)),
					if status == "locked"
						then "disabled"
						elseif state.cash >= FarmMath.getUpgradeCost(state, upgrade) then "primary"
						else "warning"
				)
			end
		end
		if content then
			upgradesEmpty.Visible = remaining == 0
			nextIslandButton.Visible = remaining == 0
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
					upgradesEmpty.Text =
						`Bu adada açık yükseltme kalmadı. Sırada: {pendingUpgrade.displayName} ({pendingIslandName} — Adalar menüsünden o adayı seç, Yol Haritası'na bak).`
				end
			end
			upgradesInfo.Visible = true
		end
	end

	return { window = upgradesWindow, update = updateUpgrades }
end

return UpgradesWindow
