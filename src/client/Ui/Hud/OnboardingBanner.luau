--!strict
-- İlk adımlar görev şeridi: üst ortada, menü çubuğunun altında "İLK ADIMLAR n/6" + tek cümlelik görev.
-- Metni GoalCard verir (tek kaynak: adım metinleri orada); adımlar bitince (ya da oyuncu "Atla" deyince) şerit kaybolur.
-- Atlama yalnızca bu oturumdadır, kayda yazılmaz.

local UiKit = require(script.Parent.Parent:WaitForChild("UiKit"))

local Color = UiKit.Color

local OnboardingBanner = {}

export type Banner = {
	frame: Frame,
	show: (title: string, label: string) -> (),
	hide: () -> (),
}

local MAX_WIDTH = 460
local TOP_GAP = 14 -- menü çubuğunun üst boşluğu (MenuBar.topBar ile aynı)
local POINTER_ROOM = 46 -- menü düğmesinin altına inen "Buraya dokun" okuna yer

function OnboardingBanner.create(hudRoot: Instance, onSkip: (() -> ())?): Banner
	local skipped = false

	local frame = Instance.new("Frame")
	frame.Name = "OnboardingBanner"
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.Position = UDim2.new(0.5, 0, 0, TOP_GAP + UiKit.MenuTileSize.Y + POINTER_ROOM)
	frame.Size = UDim2.fromScale(0.9, 0)
	frame.AutomaticSize = Enum.AutomaticSize.Y
	frame.BackgroundColor3 = Color.Panel
	frame.BackgroundTransparency = 0.05
	frame.Visible = false
	frame.Parent = hudRoot
	UiKit.corner(frame, UiKit.Radius.Card)
	UiKit.stroke(frame, 0.2).Color = Color.Gold
	UiKit.padding(frame, 14, 8)
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(MAX_WIDTH, math.huge)
	limit.Parent = frame
	UiKit.list(frame, 2).HorizontalAlignment = Enum.HorizontalAlignment.Center

	local title = UiKit.text(frame, "", "Caption", Color.Gold)
	title.FontFace = UiKit.Font.Bold
	title.TextXAlignment = Enum.TextXAlignment.Center
	title.LayoutOrder = 1
	local label = UiKit.text(frame, "", "Body")
	label.FontFace = UiKit.Font.Bold
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.LayoutOrder = 2

	local skip = UiKit.button(frame, "Atla", "secondary")
	skip.Size = UDim2.fromOffset(96, UiKit.TouchTarget)
	skip.TextSize = UiKit.TextSize.Caption
	skip.LayoutOrder = 3
	skip.Activated:Connect(function()
		skipped = true
		frame.Visible = false
		if onSkip then
			onSkip()
		end
	end)

	return {
		frame = frame,
		show = function(titleText: string, labelText: string)
			if skipped then
				return
			end
			UiKit.setText(title, titleText)
			UiKit.setText(label, labelText)
			frame.Visible = true
		end,
		hide = function()
			frame.Visible = false
		end,
	}
end

return OnboardingBanner
