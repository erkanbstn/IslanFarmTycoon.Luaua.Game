--!strict
-- Üretim tesislerinin ve eklentilerin üstünde iş ilerlemesi: çubuk + kalan süre.
--  * Üretim: çubuk iş boyunca dolar; bitince yeşil tik ve "Hazır" görünür (teslim alınana kadar).
--  * Eklenti: "duran/kapasite" ve ilk dönecek hayvana kalan süre.
-- Sunucu yalnızca "JobSite" etiketli Model'e öznitelik yazar (Presentation/JobMarks); süre burada yerelde ilerler.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local UiKit = require(script.Parent.Parent:WaitForChild("Ui"):WaitForChild("UiKit"))
local ProductionPanel = require(script.Parent.Parent:WaitForChild("Ui"):WaitForChild("ProductionPanel"))

local TAG = "JobSite"
local UPDATE_SECONDS = 0.25
local MAX_DISTANCE = 90

local Color = UiKit.Color
local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

type Entry = {
	gui: BillboardGui,
	running: Frame,
	done: TextButton,
	label: TextLabel,
	setFill: (number, Color3) -> (),
	destroying: RBXScriptConnection?,
	activated: RBXScriptConnection?,
}

local entries: { [Model]: Entry } = {}
local waiting: { [Model]: RBXScriptConnection } = {}

local function formatTime(seconds: number): string
	local whole = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", whole // 60, whole % 60)
end

-- Yeşil tik: yuvarlak zemin üstünde iki çubuktan çizilir (font karakteri değil)
local function drawCheck(parent: Instance)
	local circle = Instance.new("Frame")
	circle.Name = "Check"
	circle.Size = UDim2.fromOffset(26, 26)
	circle.BackgroundColor3 = Color.Green
	circle.Parent = parent
	UiKit.corner(circle, 13)
	local function arm(width: number, rotation: number, x: number, y: number)
		local bar = Instance.new("Frame")
		bar.AnchorPoint = Vector2.new(0.5, 0.5)
		bar.Position = UDim2.fromScale(x, y)
		bar.Size = UDim2.fromOffset(width, 3)
		bar.Rotation = rotation
		bar.BackgroundColor3 = Color3.new(1, 1, 1)
		bar.BorderSizePixel = 0
		bar.Parent = circle
		UiKit.corner(bar, 1)
	end
	arm(8, 45, 0.38, 0.6)
	arm(14, -50, 0.58, 0.5)
	return circle
end

local function createEntry(model: Model, anchor: BasePart): Entry
	local gui = Instance.new("BillboardGui")
	gui.Name = "JobProgress"
	gui.Adornee = anchor
	gui.Size = UDim2.fromOffset(150, 46)
	gui.MaxDistance = MAX_DISTANCE
	gui.AlwaysOnTop = false
	gui.LightInfluence = 0
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.Active = true
	gui.Parent = playerGui

	local panel = Instance.new("Frame")
	panel.Size = UDim2.fromScale(1, 1)
	panel.BackgroundColor3 = Color.Panel
	panel.BackgroundTransparency = 0.08
	panel.Parent = gui
	UiKit.corner(panel, UiKit.Radius.Card)
	UiKit.stroke(panel, 0.6)

	-- Sürerken: üstte yazı, altta çubuk
	local running = Instance.new("Frame")
	running.Size = UDim2.fromScale(1, 1)
	running.BackgroundTransparency = 1
	running.Parent = panel
	UiKit.padding(running, 8, 6)
	UiKit.list(running, 4)
	local label = UiKit.text(running, "", "Caption", Color.Text)
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.LayoutOrder = 1
	local track, setFill = UiKit.progressBar(running, 9)
	track.LayoutOrder = 2

	-- Bitince: yeşil tik + "Hazır"
	local done = Instance.new("TextButton")
	done.Name = "ReadyProduction"
	done.Text = ""
	done.AutoButtonColor = false
	done.Size = UDim2.fromScale(1, 1)
	done.BackgroundTransparency = 1
	done.Visible = false
	done.Parent = panel
	UiKit.padding(done, 10, 8)
	UiKit.list(done, 8, true)
	local check = drawCheck(done)
	check.LayoutOrder = 1
	local doneLabel = UiKit.text(done, "Hazır", "Heading", Color.Green)
	doneLabel.LayoutOrder = 2

	local entry: Entry = { gui = gui, running = running, done = done, label = label, setFill = setFill }
	entry.activated = done.Activated:Connect(function()
		local recipeId = model:GetAttribute("JobRecipeId")
		local owner: Instance? = model
		while owner and owner:GetAttribute("OwnerUserId") == nil do
			owner = owner.Parent
		end
		if
			entry.gui.Enabled
			and done.Visible
			and owner
			and owner:GetAttribute("OwnerUserId") == localPlayer.UserId
			and owner:GetAttribute("MainFarmId") == localPlayer:GetAttribute("ActiveMainFarmId")
			and typeof(recipeId) == "string"
		then
			ProductionPanel.openFocused(recipeId)
		end
	end)
	entry.destroying = model.Destroying:Connect(function()
		gui:Destroy()
	end)
	return entry
end

local function update(model: Model, entry: Entry)
	local kind = model:GetAttribute("JobKind")
	local startedAt = model:GetAttribute("JobStartedAt")
	local endsAt = model:GetAttribute("JobEndsAt")
	if typeof(kind) ~= "string" or typeof(startedAt) ~= "number" or typeof(endsAt) ~= "number" then
		entry.gui.Enabled = false
		return
	end
	local now = Workspace:GetServerTimeNow()
	if now >= endsAt then
		if kind == "production" then
			-- Teslim bekleyen üretim: yeşil tik
			entry.gui.Size = UDim2.fromOffset(120, 46)
			entry.running.Visible = false
			entry.done.Visible = true
			entry.gui.Enabled = true
		else
			entry.gui.Enabled = false -- eklentideki hayvan döndü; sunucu işareti birazdan kaldırır
		end
		return
	end
	entry.gui.Size = UDim2.fromOffset(150, 46)
	entry.running.Visible = true
	entry.done.Visible = false
	local total = math.max(1, endsAt - startedAt)
	local ratio = (now - startedAt) / total
	entry.setFill(ratio, if kind == "production" then Color.Gold else Color.Blue)
	local remaining = formatTime(endsAt - now)
	if kind == "extension" then
		local count = model:GetAttribute("JobCount")
		local capacity = model:GetAttribute("JobCapacity")
		UiKit.setText(
			entry.label,
			if typeof(count) == "number" and typeof(capacity) == "number"
				then `{count}/{capacity} · {remaining}`
				else remaining
		)
	else
		local title = model:GetAttribute("JobLabel")
		UiKit.setText(
			entry.label,
			if typeof(title) == "string" then `{title} · {remaining}` else `Üretimde · {remaining}`
		)
	end
	entry.gui.Enabled = true
end

local function track(instance: Instance)
	if not instance:IsA("Model") or entries[instance] or waiting[instance] then
		return
	end
	local anchor = instance:FindFirstChild("JobAnchor")
	if anchor and anchor:IsA("BasePart") then
		entries[instance] = createEntry(instance, anchor)
		return
	end
	-- Parçalar sonradan yüklenebilir (streaming): anchor gelince kurulur.
	waiting[instance] = instance.ChildAdded:Connect(function(child: Instance)
		if child.Name == "JobAnchor" and child:IsA("BasePart") and not entries[instance] then
			local connection = waiting[instance]
			if connection then
				connection:Disconnect()
				waiting[instance] = nil
			end
			entries[instance] = createEntry(instance, child)
		end
	end)
end

local function untrack(instance: Instance)
	if not instance:IsA("Model") then
		return
	end
	local connection = waiting[instance]
	if connection then
		connection:Disconnect()
		waiting[instance] = nil
	end
	local entry = entries[instance]
	if entry then
		if entry.activated then
			entry.activated:Disconnect()
		end
		if entry.destroying then
			entry.destroying:Disconnect()
		end
		entry.gui:Destroy()
		entries[instance] = nil
	end
end

local added = CollectionService:GetInstanceAddedSignal(TAG):Connect(track)
local removed = CollectionService:GetInstanceRemovedSignal(TAG):Connect(untrack)
for _, instance in CollectionService:GetTagged(TAG) do
	track(instance)
end

local elapsed = 0
local heartbeat = RunService.Heartbeat:Connect(function(dt: number)
	elapsed += dt
	if elapsed < UPDATE_SECONDS then
		return
	end
	elapsed = 0
	for model, entry in entries do
		if model.Parent then
			update(model, entry)
		else
			untrack(model)
		end
	end
end)

script.Destroying:Connect(function()
	added:Disconnect()
	removed:Disconnect()
	heartbeat:Disconnect()
	for model in waiting do
		untrack(model)
	end
	for model in entries do
		untrack(model)
	end
end)
