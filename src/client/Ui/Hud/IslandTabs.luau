--!strict
-- Yol Haritası ve Yükseltmeler pencerelerindeki ada sekmeleri: gitmeden her adanın listesini görmek için.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local GameTypes = require(Shared:WaitForChild("GameTypes"))
local FarmMath = require(Shared:WaitForChild("Modules"):WaitForChild("FarmMath"))
local ClientState = require(script.Parent.Parent.Parent:WaitForChild("Core"):WaitForChild("ClientState"))
local UiKit = require(script.Parent.Parent:WaitForChild("UiKit"))
local IslandContext = require(script.Parent.Parent.Parent:WaitForChild("Core"):WaitForChild("IslandContext"))

type PlayerSave = GameTypes.PlayerSave

local IslandTabs = {}

local updaters: { (state: PlayerSave) -> () } = {}

export type Context = {
	get: () -> string,
	name: () -> string,
	set: (islandId: string) -> (),
	update: (state: PlayerSave) -> (),
	setBadges: (counts: { [string]: number }) -> (),
}

function IslandTabs.add(window: UiKit.Window, onChanged: (() -> ())?): Context
	local preview: string? = nil
	local latest: PlayerSave? = nil
	local farmContext: string? = nil
	local function sync(state: PlayerSave)
		local context = `{state.activeMainFarmId}:{if state.progression then state.progression.run else 0}`
		if context ~= farmContext then
			preview = nil
			farmContext = context
		end
		latest = state
		if preview and not table.find(FarmMath.themeIslands(state), preview) then
			preview = nil
		end
	end
	local function get(): string
		local state = latest or ClientState.get()
		local islandId = preview or IslandContext.get()
		return if state and not table.find(FarmMath.themeIslands(state), islandId) then "home" else islandId
	end
	local row = Instance.new("Frame")
	row.Name = "IslandTabs"
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, 40)
	row.LayoutOrder = -1
	row.Parent = window.list
	UiKit.list(row, 4, true)
	local buttons: { [string]: TextButton } = {}
	local badges: { [string]: (number) -> () } = {}
	for index, islandId in Config.FARM_ISLAND_ORDER do
		local island = Config.FARM_ISLANDS[islandId]
		local button = UiKit.button(row, (string.gsub(island.displayName, " Adası$", "")), "secondary")
		button.LayoutOrder = index
		-- Her çiftlikte en çok 4 sekme görünür (ana ada + temanın 3 küçük adası)
		button.Size = UDim2.new(1 / 4, -3, 1, 0)
		-- Her sekmede aynı yazı boyutu; uzun ad kesilir, boyut oynamaz.
		button.TextScaled = false
		button.TextSize = UiKit.TextSize.Tab
		button.TextTruncate = Enum.TextTruncate.AtEnd
		buttons[islandId] = button
		badges[islandId] = UiKit.badge(button, true)
		button.Activated:Connect(function()
			local state = ClientState.get()
			if not state then
				return
			end
			sync(state)
			local changed = get() ~= islandId
			preview = islandId
			if changed and onChanged then
				onChanged()
			end
		end)
	end
	local function updateTabs(state: PlayerSave)
		sync(state)
		local selected = get()
		local themeIslands = FarmMath.themeIslands(state)
		for islandId, button in buttons do
			button.Visible = table.find(themeIslands, islandId) ~= nil
			UiKit.setVariant(button, if islandId == selected then "primary" else "secondary")
		end
	end
	table.insert(updaters, updateTabs)
	window.frame.Destroying:Connect(function()
		local index = table.find(updaters, updateTabs)
		if index then
			table.remove(updaters, index)
		end
	end)
	return {
		get = get,
		name = function(): string
			local state = latest or ClientState.get()
			return `Çiftlik {if state then state.activeMainFarmId else "1"} · {Config.FARM_ISLANDS[get()].displayName}`
		end,
		update = updateTabs,
		setBadges = function(counts: { [string]: number })
			for islandId, setBadge in badges do
				local count = counts[islandId] or 0
				setBadge(count)
				local padding = buttons[islandId]:FindFirstChildOfClass("UIPadding")
				if padding then
					(padding :: UIPadding).PaddingRight = UDim.new(0, if count > 0 then 30 else 8)
				end
			end
		end,
		set = function(islandId: string)
			local state = ClientState.get()
			if not state or not table.find(FarmMath.themeIslands(state), islandId) then
				return
			end
			sync(state)
			preview = islandId
			updateTabs(state)
			if onChanged then
				onChanged()
			end
		end,
	}
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
		local ok, err = pcall(function(): boolean
			updateTabs(state)
			return true
		end)
		if not ok then
			warn(`[FarmHud] Ada sekmeleri güncellenemedi: {err}`)
		end
	end
end

return IslandTabs
