--!strict
-- Gezgin tüccar: ziyaret sürerken üst ortada geri sayımlı kalıcı rozet (tıklayınca Pazar açılır) ve
-- geliş / "kaçırdın" bildirimleri. Ziyaret ve teklif hesabı yalnızca `Merchant.status` + `Merchant.advance`'tadır.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameTypes = require(Shared:WaitForChild("GameTypes"))
local Merchant = require(Shared:WaitForChild("Modules"):WaitForChild("Merchant"))
local Sfx = require(script.Parent.Parent.Parent:WaitForChild("Core"):WaitForChild("Sfx"))
local UiKit = require(script.Parent.Parent:WaitForChild("UiKit"))

type PlayerSave = GameTypes.PlayerSave

local Color = UiKit.Color

local MerchantBadge = {}

export type Badge = {
	frame: TextButton,
	update: (state: PlayerSave?) -> (),
}

-- Üst menü çubuğunun hemen altı; bildirimler (FarmHud toastHolder) bunun da altında durur.
MerchantBadge.TOP = 112
MerchantBadge.HEIGHT = UiKit.TouchTarget

function MerchantBadge.create(
	screenGui: Instance,
	onOpen: () -> (),
	notify: (message: string, kind: string?) -> (),
	banner: GuiObject?
): Badge
	local button = Instance.new("TextButton")
	button.Name = "MerchantBadge"
	button.AnchorPoint = Vector2.new(0.5, 0)
	button.Position = UDim2.new(0.5, 0, 0, MerchantBadge.TOP)
	button.Size = UDim2.fromOffset(0, MerchantBadge.HEIGHT)
	button.AutomaticSize = Enum.AutomaticSize.X
	button.BackgroundColor3 = Color.Panel
	button.BackgroundTransparency = 0.05
	button.AutoButtonColor = true
	button.Text = ""
	button.Selectable = true
	button.Visible = false
	button.ZIndex = 5
	button.Parent = screenGui
	local connections: { RBXScriptConnection } = {}
	local tutorial = banner
	local function position()
		local top = MerchantBadge.TOP
		local current = tutorial
		if current and current.Parent and current.Visible then
			local origin = if screenGui:IsA("GuiObject") then (screenGui :: GuiObject).AbsolutePosition.Y else 0
			top =
				math.max(top, (current.AbsolutePosition.Y + current.AbsoluteSize.Y - origin) / UiKit.screenScale() + 8)
		end
		button.Position = UDim2.new(0.5, 0, 0, top)
	end
	if banner then
		for _, property in { "Visible", "AbsolutePosition", "AbsoluteSize" } do
			table.insert(connections, banner:GetPropertyChangedSignal(property):Connect(position))
		end
		table.insert(
			connections,
			banner.Destroying:Connect(function()
				tutorial = nil
				for _, connection in connections do
					connection:Disconnect()
				end
				table.clear(connections)
				position()
			end)
		)
	end
	button.Destroying:Connect(function()
		for _, connection in connections do
			connection:Disconnect()
		end
		table.clear(connections)
	end)
	position()
	UiKit.corner(button, 15)
	local stroke = UiKit.stroke(button, 0.2)
	stroke.Color = Color.Gold
	UiKit.padding(button, 8, 0)
	local row = UiKit.list(button, 6, true)
	row.VerticalAlignment = Enum.VerticalAlignment.Center
	UiKit.iconChip(button, "🧳", 22, Color.Gold)
	local label = UiKit.text(button, "", "Caption", Color.Gold)
	label.AutomaticSize = Enum.AutomaticSize.X
	label.Size = UDim2.fromOffset(0, 22)
	label.TextWrapped = false
	label.RichText = false
	label.LayoutOrder = 2
	button.Activated:Connect(onOpen)

	local tracker = Merchant.newTracker()
	local function update(state: PlayerSave?)
		if not state then
			button.Visible = false
			Players.LocalPlayer:SetAttribute("MerchantVisitActive", false)
			return
		end
		local now = Workspace:GetServerTimeNow()
		local status = Merchant.status(state, Players.LocalPlayer.UserId, now)
		Players.LocalPlayer:SetAttribute("MerchantVisitActive", status.visit ~= nil)
		local event = Merchant.advance(tracker, status)
		if event == "arrived" then
			Sfx.play("merchant_arrive")
			notify("Gezgin tüccar geldi: indirimli tur eşyalarına göz at!", "info")
		elseif event == "missed" then
			notify("Gezgin tüccar yola çıktı. Bir sonrakini kaçırma!", "info")
		end
		button.Visible = status.visit ~= nil
		if status.visit then
			local left = math.max(0, math.ceil(status.visit.endsAt - now))
			UiKit.setText(label, `Gezgin tüccar · {string.format("%d:%02d", left // 60, left % 60)}`)
		end
	end
	return { frame = button, update = update }
end

return MerchantBadge
