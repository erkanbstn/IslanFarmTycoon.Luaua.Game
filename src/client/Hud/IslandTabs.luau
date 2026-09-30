--!strict
-- Yol Haritası ve Yükseltmeler pencerelerindeki ada sekmeleri: gitmeden her adanın listesini görmek için.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local GameTypes = require(Shared:WaitForChild("GameTypes"))
local FarmMath = require(Shared:WaitForChild("Modules"):WaitForChild("FarmMath"))
local ClientState = require(script.Parent.Parent:WaitForChild("ClientState"))
local UiKit = require(script.Parent.Parent:WaitForChild("UiKit"))
local IslandContext = require(script.Parent.Parent:WaitForChild("IslandContext"))

type PlayerSave = GameTypes.PlayerSave

local IslandTabs = {}

local updaters: { (state: PlayerSave) -> () } = {}

function IslandTabs.add(window: UiKit.Window)
	local row = Instance.new("Frame")
	row.Name = "IslandTabs"
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, 34)
	row.LayoutOrder = -1
	row.Parent = window.list
	UiKit.list(row, 4, true)
	local buttons: { [string]: TextButton } = {}
	for index, islandId in Config.FARM_ISLAND_ORDER do
		local island = Config.FARM_ISLANDS[islandId]
		local button = UiKit.button(row, (string.gsub(island.displayName, " Adası$", "")), "secondary")
		button.LayoutOrder = index
		-- Her çiftlikte en çok 4 sekme görünür (ana ada + temanın 3 küçük adası)
		button.Size = UDim2.new(1 / 4, -3, 1, 0)
		-- Her sekmede aynı yazı boyutu; uzun ad kesilir, boyut oynamaz.
		button.TextScaled = false
		button.TextSize = 14
		button.TextTruncate = Enum.TextTruncate.AtEnd
		buttons[islandId] = button
		button.Activated:Connect(function()
			local state = ClientState.get()
			if not state then
				return
			end
			if state.unlockedIslands[islandId] then
				IslandContext.setPreview(nil)
				Remotes.get("RequestTravelIsland"):FireServer(islandId, true)
			else
				-- Kilitli ada: yalnızca bakmak için (yükseltmeleri ve ada kartı görünür); sunucu seçimi değişmez
				IslandContext.setPreview(islandId)
			end
		end)
	end
	table.insert(updaters, function(state: PlayerSave)
		local selected = IslandContext.get()
		local themeIslands = FarmMath.themeIslands(state)
		for islandId, button in buttons do
			button.Visible = table.find(themeIslands, islandId) ~= nil
			UiKit.setVariant(button, if islandId == selected then "primary" else "secondary")
		end
	end)
end

function IslandTabs.update(state: PlayerSave)
	for _, updateTabs in updaters do
		updateTabs(state)
	end
end

-- Ada sekmeleri pencere açık olmasa da güncel kalsın (yeni açılan ada hemen tıklanabilir olsun).
-- Ayrı ve korumalı: buradaki bir hata ana arayüzün güncellenmesini asla engellemez.
function IslandTabs.refreshSafe()
	local state = ClientState.get()
	if not state then
		return
	end
	for _, updateTabs in updaters do
		local ok, err = pcall(updateTabs, state)
		if not ok then
			warn(`[FarmHud] Ada sekmeleri güncellenemedi: {err}`)
		end
	end
end

return IslandTabs
