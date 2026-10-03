--!strict
-- Yol Haritası penceresi: aşamalar, yükseltme kartları ve uzantı (Hayvan ekle/çıkar) düğmeleri.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local GameTypes = require(Shared:WaitForChild("GameTypes"))
local FarmMath = require(Shared:WaitForChild("Modules"):WaitForChild("FarmMath"))
local Progression = require(Shared:WaitForChild("Modules"):WaitForChild("Progression"))
local UiKit = require(script.Parent.Parent:WaitForChild("UiKit"))
local PurchaseController = require(script.Parent.Parent.Parent:WaitForChild("Core"):WaitForChild("PurchaseController"))
local IslandContext = require(script.Parent.Parent.Parent:WaitForChild("Core"):WaitForChild("IslandContext"))
local HudCommon = require(script.Parent:WaitForChild("HudCommon"))
local IslandTabs = require(script.Parent:WaitForChild("IslandTabs"))

type PlayerSave = GameTypes.PlayerSave

local Color = UiKit.Color
local setPurchaseButton = HudCommon.setPurchaseButton

local RoadmapWindow = {}

export type Roadmap = {
	window: UiKit.Window,
	update: (state: PlayerSave, content: boolean) -> (),
}

function RoadmapWindow.create(screenGui: Instance, WINDOW_POSITION: UDim2): Roadmap
	local roadmapWindow = UiKit.window(screenGui, {
		title = "Yol Haritası",
		icon = "🗺️",
		tint = Color.Blue,
		width = 330,
		maxHeight = 430,
		anchor = Vector2.new(1, 0.5),
		position = WINDOW_POSITION,
	})
	local roadmapInfo =
		UiKit.text(roadmapWindow.list, "Tüm aşamalar ve ilerlemen. Alışveriş için Yükseltmeler (U)", "Caption")
	roadmapInfo.LayoutOrder = 0
	local rebirthGoal = UiKit.text(roadmapWindow.list, "", "Caption", Color.Gold)
	rebirthGoal.LayoutOrder = 1

	IslandTabs.add(roadmapWindow)

	local upgradeCards: { [string]: UiKit.Card } = {}
	local disclosures: { UiKit.Disclosure } = {}
	local lastContext = ""
	local function resetDetails()
		for _, detail in disclosures do
			detail.setExpanded(false)
		end
	end
	roadmapWindow.frame:GetPropertyChangedSignal("Visible"):Connect(function()
		if not roadmapWindow.isOpen() then
			resetDetails()
		end
	end)
	type ExtensionHudRow = { row: Frame, add: TextButton, remove: TextButton }
	local extensionHudRows: { [string]: ExtensionHudRow } = {}
	local stageMeta: { [number]: TextLabel } = {}
	local stageGroups: { [number]: { GuiObject } } = {}
	do
		local order = 1
		for stageIndex, stage in Config.ROADMAP_STAGES do
			local stageName = stage.name
			local header, meta = UiKit.sectionHeader(roadmapWindow.list, `Aşama {stageIndex} · {stageName}`, order)
			stageMeta[stageIndex] = meta
			stageGroups[stageIndex] = { header.Parent :: GuiObject }
			order += 1

			-- Aşama bir uzman adaya aitse adanın özelliği, değilse aşamanın açıklaması başlığın altında yazsın
			local islandConfig = if stage.island then Config.FARM_ISLANDS[stage.island] else nil
			local caption = if islandConfig and islandConfig.upgradeId
				then `Ada özelliği: {islandConfig.trait}`
				else stage.description
			if caption then
				local information = UiKit.disclosure(roadmapWindow.list, order, "Ayrıntılar")
				UiKit.text(information.body, caption, "Caption")
				table.insert(disclosures, information)
				table.insert(stageGroups[stageIndex], information.frame)
				order += 1
			end

			-- Aşamanın kartları 2 sütunlu esnek ızgaradır
			local stageGrid = UiKit.autoGrid(roadmapWindow.list, order)
			table.insert(stageGroups[stageIndex], stageGrid)
			order += 1
			local tileOrder = 0

			if stageIndex == 1 then
				local free = UiKit.autoTile(stageGrid, tileOrder, "🎁")
				tileOrder += 1
				free.title.Text = "Başlangıç hediyesi"
				free.detail.Text = `{Config.BARN_LEVELS[1].displayName}, ana ağıl, ilk hayvanın parası`
				free.action.Text = "Alındı"
				UiKit.setVariant(free.action, "owned")
			end

			for _, upgrade in Config.UPGRADES do
				if upgrade.stage ~= stageIndex then
					continue
				end
				local card = UiKit.autoTile(stageGrid, tileOrder, upgrade.icon)
				card.title.Text = upgrade.displayName
				tileOrder += 1
				upgradeCards[upgrade.id] = card
				table.insert(disclosures, UiKit.cardDetails(card, "Ayrıntılar"))
				card.action.Activated:Connect(function()
					if card.action.Active then
						PurchaseController.submit("RequestBuyUpgrade", upgrade.id)
					end
				end)
				if upgrade.kind == "extension" and upgrade.extensionId then
					local row = Instance.new("Frame")
					row.Name = "ExtensionActions"
					row.BackgroundTransparency = 1
					row.Size = UDim2.new(1, 0, 0, 68)
					row.LayoutOrder = 3
					row.Visible = false
					row.Parent = card.frame
					UiKit.list(row, 4)
					local add = UiKit.button(row, "Hayvan gönder", "primary")
					add.Size = UDim2.new(1, 0, 0, 32)
					add.LayoutOrder = 1
					local remove = UiKit.button(row, "Geri çağır", "warning")
					remove.Size = UDim2.new(1, 0, 0, 32)
					remove.LayoutOrder = 2
					local extensionId = upgrade.extensionId :: string
					add.Activated:Connect(function()
						Remotes.get("RequestExtensionAction"):FireServer(extensionId, "assign")
					end)
					remove.Activated:Connect(function()
						Remotes.get("RequestExtensionAction"):FireServer(extensionId, "unassign")
					end)
					extensionHudRows[upgrade.id] = { row = row, add = add, remove = remove }
				end
			end
		end
	end

	local function updateRoadmap(state: PlayerSave, content: boolean)
		local context =
			`{state.activeMainFarmId}:{IslandContext.get()}:{if state.progression then state.progression.run else 0}`
		if context ~= lastContext then
			lastContext = context
			resetDetails()
		end
		local progress = Progression.progress(state)
		UiKit.setText(rebirthGoal, `Rebirth: {progress.farmsComplete}/{progress.farmsTotal} çiftlik`)
		local selectedIsland = IslandContext.get()
		IslandTabs.update(state)
		if content then
			UiKit.setText(roadmapInfo, IslandContext.name())
		end
		local ownedPerStage: { [number]: number } = {}
		local totalPerStage: { [number]: number } = {}
		for _, upgrade in Config.UPGRADES do
			local card = upgradeCards[upgrade.id]
			local relevant = IslandContext.upgradeIsland(upgrade) == selectedIsland
				and FarmMath.isUpgradeInTheme(state, upgrade)
			card.frame.Visible = relevant
			if not relevant then
				continue
			end
			local status, missing = FarmMath.getUpgradeStatus(state, upgrade.id)
			local extensionRow = extensionHudRows[upgrade.id]
			if content then
				totalPerStage[upgrade.stage] = (totalPerStage[upgrade.stage] or 0) + 1
				if status == "owned" then
					ownedPerStage[upgrade.stage] = (ownedPerStage[upgrade.stage] or 0) + 1
				end
				if status == "owned" and upgrade.kind == "extension" and upgrade.extensionId then
					local extension = Config.getExtension(upgrade.extensionId)
					local inExt = if extension then FarmMath.countInExtension(state, upgrade.extensionId) else 0
					local cap = if extension then FarmMath.getExtensionCapacity(state, upgrade.extensionId) else 0
					card.detail.Text = `{upgrade.description} · Dolu: {inExt}/{cap}`
				else
					local needs = if status == "available" then HudCommon.goodsNeedText(state, upgrade) else nil
					card.detail.Text = if status == "locked"
						then `Önce: {table.concat(missing, ", ")}`
						elseif needs then `{upgrade.description}\n{needs}`
						else upgrade.description
				end
				card.frame.BackgroundTransparency = if status == "owned" then 0.5 else 0
			end
			if extensionRow then
				local ownedExtension = status == "owned"
				extensionRow.row.Visible = ownedExtension
				card.action.Visible = not ownedExtension
			end
			local variant: UiKit.Variant = if status == "owned"
				then "owned"
				elseif status == "locked" then "disabled"
				else HudCommon.upgradeVariant(state, upgrade)
			setPurchaseButton(
				card.action,
				if status == "owned" then "Alındı" else FarmMath.formatMoney(FarmMath.getUpgradeCost(state, upgrade)),
				variant
			)
			-- Kilitli: düğme yerine kartın sağ üstünde kırmızı yazı
			UiKit.setCardStatus(card, if status == "locked" then "Kilitli" else nil)
			if extensionRow and status == "owned" then
				card.action.Visible = false
			end
		end
		if content then
			for stageIndex in Config.ROADMAP_STAGES do
				local stageVisible = (ownedPerStage[stageIndex] or 0) > 0 or (totalPerStage[stageIndex] or 0) > 0
				stageMeta[stageIndex].Text = `{ownedPerStage[stageIndex] or 0}/{totalPerStage[stageIndex] or 0}`
				for _, item in stageGroups[stageIndex] do
					item.Visible = stageVisible
				end
			end
		end
	end

	return { window = roadmapWindow, update = updateRoadmap }
end

return RoadmapWindow
