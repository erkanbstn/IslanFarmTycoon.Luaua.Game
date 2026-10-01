--!strict
-- İlk adımların dünya işareti: Onboarding `TutorialMarker` özniteliğine hedefi yazar ("market" ya da "pad:<yükseltme>"),
-- burada hedefin üstüne "Buraya gel" etiketi ve karakterden hedefe altın bir ışın çizilir (CollectorGuide kalıbı).
-- Yalnızca bu oyuncunun ekranında görünür; satın alma yine sunucudaki ProximityPrompt ile yapılır.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UiTheme = require(Shared:WaitForChild("UiTheme"))
local WorldUi = require(Shared:WaitForChild("WorldUi"))

local localPlayer = Players.LocalPlayer
local GOLD = UiTheme.Color.Gold
local HIDE_DISTANCE = 12
local CHECK_INTERVAL = 0.25

local target: BasePart? = nil
local targetKey = ""
local targetAttachment: Attachment? = nil
local tag: BillboardGui? = nil
local beam: Beam? = nil
local fromAttachment: Attachment? = nil

local function ownPlot(): Instance?
	local plots = Workspace:FindFirstChild("Plots")
	if not plots then
		return nil
	end
	for _, plot in plots:GetChildren() do
		if
			plot:GetAttribute("OwnerUserId") == localPlayer.UserId
			and plot:GetAttribute("MainFarmId") == localPlayer:GetAttribute("ActiveMainFarmId")
		then
			return plot
		end
	end
	return nil
end

-- Hedef parça: pazar tezgâhının önü ya da alınabilir yükseltmenin kaidesindeki halka
local function findTarget(key: string): BasePart?
	local plot = ownPlot()
	if not plot then
		return nil
	end
	if key == "market" then
		local anchor = plot:FindFirstChild("MarketPromptAnchor", true)
		return if anchor and anchor:IsA("BasePart") then anchor else nil
	end
	local upgradeId = string.match(key, "^pad:(.+)$")
	if upgradeId then
		for _, ring in CollectionService:GetTagged("BuyPad") do
			if ring:IsA("BasePart") and ring:GetAttribute("UpgradeId") == upgradeId and ring:IsDescendantOf(plot) then
				return ring
			end
		end
	end
	return nil
end

local function clear()
	if beam then
		beam:Destroy()
	end
	if fromAttachment then
		fromAttachment:Destroy()
	end
	if targetAttachment then
		targetAttachment:Destroy()
	end
	if tag then
		tag:Destroy()
	end
	beam, fromAttachment, targetAttachment, tag = nil, nil, nil, nil
	target = nil
	targetKey = ""
end

local function build(part: BasePart, key: string)
	clear()
	target = part
	targetKey = key
	local attachment = Instance.new("Attachment")
	attachment.Name = "TutorialAttachment"
	attachment.Position = Vector3.new(0, 1, 0)
	attachment.Parent = part
	targetAttachment = attachment
	tag = WorldUi.tag(part, "TutorialTag", {
		text = "Buraya gel",
		icon = "👇",
		tint = GOLD,
		widthStuds = 8,
		heightStuds = 1.9,
		offset = Vector3.new(0, 4.5, 0),
		maxDistance = 400,
	})
end

local function ensureBeam(): Beam?
	local character = localPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not targetAttachment then
		return nil
	end
	if
		beam
		and beam.Parent
		and beam.Attachment0
		and beam.Attachment0.Parent == root
		and beam.Attachment1 == targetAttachment
	then
		return beam
	end
	if beam then
		beam:Destroy()
	end
	if fromAttachment then
		fromAttachment:Destroy()
	end
	local from = Instance.new("Attachment")
	from.Name = "TutorialMarkerAttachment"
	from.Position = Vector3.new(0, -2.5, 0)
	from.Parent = root
	fromAttachment = from
	local newBeam = Instance.new("Beam")
	newBeam.Attachment0 = from
	newBeam.Attachment1 = targetAttachment
	newBeam.Color = ColorSequence.new(GOLD)
	newBeam.LightEmission = 1
	newBeam.FaceCamera = true
	newBeam.Width0 = 0.5
	newBeam.Width1 = 0.5
	newBeam.Transparency = NumberSequence.new(0.25)
	newBeam.Enabled = false
	newBeam.Parent = root
	beam = newBeam
	return newBeam
end

local function update()
	local key = localPlayer:GetAttribute("TutorialMarker")
	if typeof(key) ~= "string" or key == "" then
		if target then
			clear()
		end
		return
	end
	if not target or targetKey ~= key or not target:IsDescendantOf(Workspace) then
		local found = findTarget(key)
		if not found then
			if target then
				clear()
			end
			return
		end
		build(found, key)
	end
	local currentBeam = ensureBeam()
	local part = target
	if not currentBeam or not part then
		return
	end
	local character = localPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local near = root ~= nil and (root.Position - part.Position).Magnitude < HIDE_DISTANCE
	currentBeam.Enabled = not near
	if tag then
		tag.Enabled = not near
	end
end

local elapsed = 0
RunService.Heartbeat:Connect(function(dt: number)
	elapsed += dt
	if elapsed < CHECK_INTERVAL then
		return
	end
	elapsed = 0
	update()
end)
