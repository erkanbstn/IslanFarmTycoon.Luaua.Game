--!strict
-- Yükseltmeler penceresi: seçili adanın açık yükseltmeleri (alınanlar listeden çıkar).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local GameTypes = require(Shared:WaitForChild("GameTypes"))
local FarmMath = require(Shared:WaitForChild("Modules"):WaitForChild("FarmMath"))
local UiKit = require(script.Parent.Parent:WaitForChild("UiKit"))
local PurchaseController = require(script.Parent.Parent:WaitForChild("PurchaseController"))
local IslandContext = require(script.Parent.Parent:WaitForChild("IslandContext"))
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
	local upgradesInfo = UiKit.text(
		upgradesWindow.list,
		"Açık yükseltmeler üstte; alınanlar bu listeden çıkar. Kısayol: U.",
		"Caption"
	)
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

	local function updateUpgrades(state: PlayerSave, content: boolean)
		local remaining = 0
		local selectedIsland = IslandContext.get()
		if content then
			upgradesInfo.Text =
				`Seçili: {IslandContext.name()}\nAçık yükseltmeler üstte; alınanlar listeden çıkar. Üstteki sekmelerden ada seçebilirsin.`
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
			local group = if status == "locked" then 2 elseif state.cash >= upgrade.cost then 0 else 1
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
					if status == "locked" then "Kilitli" else FarmMath.formatMoney(upgrade.cost),
					if status == "locked" then "disabled" elseif state.cash >= upgrade.cost then "primary" else "warning"
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
