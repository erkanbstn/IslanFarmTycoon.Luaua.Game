--!strict
-- Üst ortadaki bildirimler (toast): çizilmiş işaretler ve yığın yönetimi.
-- UiKit cephesi bunları birleştirir; bileşenleri `UiKit.<ad>` ile kullan.

local TweenService = game:GetService("TweenService")
local Tokens = require(script.Parent:WaitForChild("Tokens"))
local Base = require(script.Parent:WaitForChild("Base"))

local Toasts = {}

---------------------------------------------------------------------------
-- Bildirimler
---------------------------------------------------------------------------

export type ToastKind = "success" | "error" | "money" | "info"

local TOAST_COLORS: { [string]: Color3 } = {
	success = Tokens.Color.Green,
	error = Tokens.Color.Red,
	money = Tokens.Color.Gold,
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

-- Ekranın üst ortasında bildirim yığını. Dönen fonksiyonla bildirim gösterilir.
function Toasts.toastHost(parent: Instance): (message: string, kind: string?) -> ()
	local holder = Instance.new("Frame")
	holder.Name = "Toasts"
	holder.AnchorPoint = Vector2.new(0.5, 0)
	holder.Position = UDim2.new(0.5, 0, 0, 12)
	holder.Size = UDim2.new(1, -24, 0, 0)
	holder.AutomaticSize = Enum.AutomaticSize.Y
	holder.ZIndex = 30
	local widthLimit = Instance.new("UISizeConstraint")
	widthLimit.MaxSize = Vector2.new(460, 10000)
	widthLimit.Parent = holder
	holder.BackgroundTransparency = 1
	holder.Parent = parent
	local layout = Base.list(holder, 6)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center

	local counter = 0
	-- Aynı metin ve türdeki bildirim ekranda duruyorsa yenisi eklenmez: "×N" rozeti artar ve süre tazelenir
	type Entry = { toast: CanvasGroup, label: TextLabel, badge: TextLabel?, count: number, token: number }
	local active: { [string]: Entry } = {}
	local function scheduleFade(key: string, entry: Entry)
		entry.token += 1
		local mine = entry.token
		task.delay(2.6, function()
			if entry.token ~= mine then
				return
			end
			if active[key] == entry then
				active[key] = nil
			end
			if not entry.toast.Parent then
				return -- taşan kuyrukta silinmişti
			end
			TweenService:Create(entry.toast, TweenInfo.new(0.35), { GroupTransparency = 1 }):Play()
			task.wait(0.35)
			entry.toast:Destroy()
		end)
	end
	local function makeBadge(entry: Entry, resolvedKind: string): TextLabel
		local created = Base.text(entry.toast, "", "Body")
		created.FontFace = Tokens.Font.Bold
		created.TextColor3 = TOAST_COLORS[resolvedKind]
		created.AutomaticSize = Enum.AutomaticSize.X
		created.Size = UDim2.new(0, 0, 0, 24)
		created.LayoutOrder = 3
		entry.badge = created
		entry.label.Size = UDim2.new(1, -74, 0, 24)
		return created
	end
	return function(message: string, kind: string?)
		local resolvedKind = if kind and TOAST_COLORS[kind] then kind else "info"
		local key = `{resolvedKind}|{message}`
		local existing = active[key]
		if existing and existing.toast.Parent then
			existing.count += 1
			local badge: TextLabel = existing.badge or makeBadge(existing, resolvedKind)
			badge.Text = `×{existing.count}`
			existing.toast.GroupTransparency = 0
			scheduleFade(key, existing)
			return
		end
		counter += 1

		-- CanvasGroup: tüm bildirim (işaret dahil) tek parça halinde solar
		local toast = Instance.new("CanvasGroup")
		toast.Size = UDim2.new(1, 0, 0, 40)
		toast.AutomaticSize = Enum.AutomaticSize.Y
		toast.BackgroundColor3 = Tokens.Color.Panel
		toast.BackgroundTransparency = 0.05
		toast.LayoutOrder = counter
		toast.Parent = holder
		Base.corner(toast, 19)
		local accent = Base.stroke(toast, 0.4)
		accent.Color = TOAST_COLORS[resolvedKind]
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0, 8)
		pad.PaddingRight = UDim.new(0, 16)
		pad.PaddingTop = UDim.new(0, 8)
		pad.PaddingBottom = UDim.new(0, 8)
		pad.Parent = toast
		Base.list(toast, 10, true)

		local mark = Instance.new("Frame")
		mark.Size = UDim2.fromOffset(24, 24)
		mark.BackgroundColor3 = TOAST_COLORS[resolvedKind]
		mark.LayoutOrder = 1
		mark.Parent = toast
		Base.corner(mark, 12)
		drawToastMark(mark, resolvedKind)

		local label = Base.text(toast, message, "Body")
		label.AutomaticSize = Enum.AutomaticSize.Y
		label.Size = UDim2.new(1, -34, 0, 24)
		label.TextWrapped = true
		label.FontFace = Tokens.Font.Bold
		label.LayoutOrder = 2

		-- En fazla 4 bildirim
		local toasts = {}
		for _, child in holder:GetChildren() do
			if child:IsA("CanvasGroup") then
				table.insert(toasts, child)
			end
		end
		if #toasts > 4 then
			table.sort(toasts, function(a, b)
				return a.LayoutOrder < b.LayoutOrder
			end)
			toasts[1]:Destroy()
		end

		local entry: Entry = { toast = toast, label = label, badge = nil, count = 1, token = 0 }
		active[key] = entry
		scheduleFade(key, entry)
	end
end

return Toasts
