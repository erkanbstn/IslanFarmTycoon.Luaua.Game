--!strict
-- Sol panelde küçük mevsim/hava kartı (depo ile hedef arasında).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Environment = require(Shared:WaitForChild("Modules"):WaitForChild("Environment"))
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
	end
	return { update = updateSeasonBar, setCompact = setCompact }
end

return SeasonBar
