--!strict
-- Üst ortadaki bildirimler (toast): çizilmiş işaretler ve yığın yönetimi.
-- UiKit cephesi bunları birleştirir; bileşenleri `UiKit.<ad>` ile kullan.

local TweenService = game:GetService("TweenService")
local Tokens = require(script.Parent:WaitForChild("Tokens"))
local Base = require(script.Parent:WaitForChild("Base"))
local Screen = require(script.Parent:WaitForChild("Screen"))
local EffectSettings = require(script.Parent.Parent.Parent:WaitForChild("Core"):WaitForChild("EffectSettings"))

local Toasts = {}

---------------------------------------------------------------------------
-- Bildirimler
---------------------------------------------------------------------------

export type ToastKind = "success" | "error" | "money" | "info"

local TOAST_COLORS: { [string]: Color3 } = {
	success = Tokens.Color.Green,
	error = Tokens.Color.Red,
	money = Tokens.Color.Green,
	info = Tokens.Color.Blue,
}

-- Bildirim türüne göre çizilmiş işaret: tik, ünlem, para (daire), bilgi (nokta + çizgi)
local function drawToastMark(parent: Frame, kind: string)
	local color = Tokens.Color.Panel
	local function bar(size: Vector2, position: UDim2, rotation: number)
		local f = Instance.new("Frame")
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Size = UDim2.fromOffset(size.X, size.Y)
		f.Position = position
		f.Rotation = rotation
		f.BackgroundColor3 = color
		f.BorderSizePixel = 0
		f.Parent = parent
		Base.corner(f, 1)
	end
	if kind == "success" then
		bar(Vector2.new(6, 2), UDim2.new(0.5, -3, 0.5, 2), 45)
		bar(Vector2.new(10, 2), UDim2.new(0.5, 2, 0.5, 0), -50)
	elseif kind == "error" then
		bar(Vector2.new(2, 8), UDim2.new(0.5, 0, 0.5, -2), 0)
		bar(Vector2.new(2, 2), UDim2.new(0.5, 0, 0.5, 5), 0)
	elseif kind == "money" then
		-- Madeni para: içte halka
		local ring = Instance.new("Frame")
		ring.AnchorPoint = Vector2.new(0.5, 0.5)
		ring.Position = UDim2.fromScale(0.5, 0.5)
		ring.Size = UDim2.fromOffset(12, 12)
		ring.BackgroundTransparency = 1
		ring.Parent = parent
		Base.corner(ring, 6)
		local line = Instance.new("UIStroke")
		line.Color = color
		line.Thickness = 2
		line.Parent = ring
	else
		bar(Vector2.new(2, 2), UDim2.new(0.5, 0, 0.5, -4), 0)
		bar(Vector2.new(2, 7), UDim2.new(0.5, 0, 0.5, 2), 0)
	end
end

-- Tüm ekranlar tek kuyruğu paylaşır; bekleyen bildirimler zamanlayıcı/GUI oluşturmaz.
local MAX_VISIBLE = 2
local MAX_PENDING = 6
local GAP = 8

type Entry = {
	key: string,
	message: string,
	kind: string,
	count: number,
	toast: CanvasGroup?,
	label: TextLabel?,
	badge: TextLabel?,
	timer: thread?,
	fade: thread?,
	tween: Tween?,
}
type Host = {
	holder: Frame,
	entries: { [string]: Entry },
	visible: { Entry },
	pending: { Entry },
	connections: { RBXScriptConnection },
	blockers: { [GuiObject]: { RBXScriptConnection } },
	show: (message: string, kind: string?) -> (),
	alive: boolean,
	addBlockers: (blockers: { GuiObject }) -> (),
}
local sharedHost: Host? = nil

function Toasts.toastHost(parent: Instance, blockers: { GuiObject }?): (message: string, kind: string?) -> ()
	if sharedHost and sharedHost.alive then
		sharedHost.addBlockers(blockers or {})
		return sharedHost.show
	end
	local screen = if parent:IsA("ScreenGui") then parent else parent:FindFirstAncestorOfClass("ScreenGui")
	local layer: ScreenGui? = nil
	local container = parent
	if screen and screen.Parent then
		local created = Instance.new("ScreenGui")
		created.Name = "Notifications"
		created.ResetOnSpawn = false
		created.DisplayOrder = 20
		created.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		created.Parent = screen.Parent
		layer = created
		container = Screen.root(created)
	end
	local holder = Instance.new("Frame")
	holder.Name = "Toasts"
	holder.AnchorPoint = Vector2.new(0.5, 0)
	holder.Position = UDim2.new(0.5, 0, 0, 14 + Tokens.MenuTileSize.Y + GAP)
	holder.Size = UDim2.new(0.9, 0, 0, 0)
	holder.AutomaticSize = Enum.AutomaticSize.Y
	holder.ZIndex = 30
	holder.BackgroundTransparency = 1
	holder.Parent = container
	local widthLimit = Instance.new("UISizeConstraint")
	widthLimit.MaxSize = Vector2.new(460, 10000)
	widthLimit.Parent = holder
	Base.list(holder, GAP).HorizontalAlignment = Enum.HorizontalAlignment.Center
	local host: Host = {
		holder = holder,
		entries = {},
		visible = {},
		pending = {},
		connections = {},
		blockers = {},
		show = function() end,
		addBlockers = function() end,
		alive = true,
	}
	sharedHost = host
	local function reposition()
		if not host.alive then
			return
		end
		local origin = if container:IsA("GuiObject") then (container :: GuiObject).AbsolutePosition.Y else 0
		local scale = Screen.scale()
		local top = 14 + Tokens.MenuTileSize.Y + GAP
		for blocker in host.blockers do
			if blocker.Parent and blocker.Visible then
				top = math.max(top, (blocker.AbsolutePosition.Y + blocker.AbsoluteSize.Y - origin) / scale + GAP)
			end
		end
		holder.Position = UDim2.new(0.5, 0, 0, top)
	end
	host.addBlockers = function(list: { GuiObject })
		for _, blocker in list do
			if host.blockers[blocker] then
				continue
			end
			local watched: { RBXScriptConnection } = {}
			host.blockers[blocker] = watched
			for _, property in { "Visible", "AbsolutePosition", "AbsoluteSize" } do
				table.insert(watched, blocker:GetPropertyChangedSignal(property):Connect(reposition))
			end
			table.insert(
				watched,
				blocker.Destroying:Connect(function()
					host.blockers[blocker] = nil
					for _, connection in watched do
						connection:Disconnect()
					end
					table.clear(watched)
					reposition()
				end)
			)
		end
		reposition()
	end
	host.addBlockers(blockers or {})
	if layer then
		local ownerLayer = layer
		table.insert(
			host.connections,
			parent.Destroying:Connect(function()
				ownerLayer:Destroy()
			end)
		)
	end
	local function cancel(entry: Entry)
		if entry.timer then
			task.cancel(entry.timer)
			entry.timer = nil
		end
		if entry.fade then
			task.cancel(entry.fade)
			entry.fade = nil
		end
		if entry.tween then
			entry.tween:Cancel()
			entry.tween = nil
		end
	end
	local drain: () -> ()
	local function remove(entry: Entry)
		cancel(entry)
		host.entries[entry.key] = nil
		local index = table.find(host.visible, entry)
		if index then
			table.remove(host.visible, index)
		end
		if entry.toast then
			entry.toast:Destroy()
			entry.toast = nil
		end
		if host.alive then
			drain()
		end
	end
	local function schedule(entry: Entry)
		cancel(entry)
		if entry.toast then
			entry.toast.GroupTransparency = 0
		end
		entry.timer = task.delay(2.6, function()
			entry.timer = nil
			if not host.alive then
				return
			end
			if EffectSettings.reducedMotion() then
				remove(entry)
				return
			end
			local toast = entry.toast
			if not toast then
				return
			end
			local tween = TweenService:Create(toast, TweenInfo.new(0.35), { GroupTransparency = 1 })
			entry.tween = tween
			tween:Play()
			entry.fade = task.delay(0.35, function()
				entry.fade = nil
				remove(entry)
			end)
		end)
	end
	local function updateBadge(entry: Entry)
		local toast, label = entry.toast, entry.label
		if not toast or not label or entry.count <= 1 then
			return
		end
		local badge: TextLabel = entry.badge or Base.text(toast, "", "Body")
		if not entry.badge then
			badge.FontFace = Tokens.Font.Bold
			badge.TextColor3 = TOAST_COLORS[entry.kind]
			badge.AutomaticSize = Enum.AutomaticSize.X
			badge.Size = UDim2.new(0, 0, 0, 24)
			badge.LayoutOrder = 3
			entry.badge = badge
			label.Size = UDim2.new(1, -86, 0, 24)
		end
		badge.Text = `×{entry.count}`
	end
	local function display(entry: Entry)
		local toast = Instance.new("CanvasGroup")
		toast.Size = UDim2.new(1, 0, 0, 40)
		toast.AutomaticSize = Enum.AutomaticSize.Y
		toast.BackgroundColor3 = Tokens.Color.Panel
		toast.BackgroundTransparency = 0.05
		toast.Parent = holder
		Base.corner(toast, 19)
		Base.stroke(toast, 0.4).Color = TOAST_COLORS[entry.kind]
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0, 8)
		pad.PaddingRight = UDim.new(0, 16)
		pad.PaddingTop = UDim.new(0, 8)
		pad.PaddingBottom = UDim.new(0, 8)
		pad.Parent = toast
		Base.list(toast, 10, true)
		local mark = Instance.new("Frame")
		mark.Size = UDim2.fromOffset(24, 24)
		mark.BackgroundColor3 = TOAST_COLORS[entry.kind]
		mark.LayoutOrder = 1
		mark.Parent = toast
		Base.corner(mark, 12)
		drawToastMark(mark, entry.kind)
		local label = Base.text(toast, entry.message, "Body")
		label.AutomaticSize = Enum.AutomaticSize.Y
		label.Size = UDim2.new(1, -34, 0, 24)
		label.TextWrapped = true
		label.FontFace = Tokens.Font.Bold
		label.LayoutOrder = 2
		entry.toast, entry.label = toast, label
		table.insert(host.visible, entry)
		updateBadge(entry)
		for index, visible in host.visible do
			if visible.toast then
				visible.toast.LayoutOrder = index
			end
		end
		schedule(entry)
	end
	drain = function()
		while host.alive and #host.visible < MAX_VISIBLE and #host.pending > 0 do
			local nextEntry = table.remove(host.pending, 1)
			if nextEntry then
				display(nextEntry)
			end
		end
	end
	host.show = function(message: string, kind: string?)
		if not host.alive or message == "" then
			return
		end
		local resolvedKind = if kind and TOAST_COLORS[kind] then kind else "info"
		local key = `{resolvedKind}|{message}`
		local existing = host.entries[key]
		if existing then
			existing.count = math.min(existing.count + 1, 999)
			updateBadge(existing)
			if existing.toast then
				schedule(existing)
			end
			return
		end
		if #host.pending >= MAX_PENDING then
			local dropped = table.remove(host.pending, 1)
			if dropped then
				host.entries[dropped.key] = nil
			end
		end
		local entry: Entry = { key = key, message = message, kind = resolvedKind, count = 1 }
		host.entries[key] = entry
		table.insert(host.pending, entry)
		drain()
	end
	table.insert(
		host.connections,
		holder.Destroying:Connect(function()
			host.alive = false
			for _, entry in host.entries do
				cancel(entry)
			end
			table.clear(host.entries)
			table.clear(host.visible)
			table.clear(host.pending)
			for _, watched in host.blockers do
				for _, connection in watched do
					connection:Disconnect()
				end
			end
			table.clear(host.blockers)
			for _, connection in host.connections do
				connection:Disconnect()
			end
			table.clear(host.connections)
			if sharedHost == host then
				sharedHost = nil
			end
		end)
	)
	return host.show
end

return Toasts
