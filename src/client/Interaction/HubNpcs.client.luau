--!strict
-- Meydandaki satıcı NPC'lere hayat verir (yalnızca bu oyuncunun ekranında):
--  * boşta hafif nefes/baş sallanması, yaklaşan oyuncuya doğru bakma
--  * yakınlaşınca el sallama ve kısa bir selam balonu (satıcının işine göre)
-- Satıcılar sunucuda "HubNpc" etiketi ve `Action` özniteliğiyle kurulur (HubNpcs.luau); parçalar sabittir,
-- hareket yalnızca burada CFrame yazarak yapılır (AnimalAnimator/Windmill ile aynı yöntem).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local EffectSettings = require(script.Parent.Parent:WaitForChild("Core"):WaitForChild("EffectSettings"))
local UiTheme = require(Shared:WaitForChild("UiTheme"))
local WorldUi = require(Shared:WaitForChild("WorldUi"))

local localPlayer = Players.LocalPlayer

local ANIMATE_DISTANCE = 70 -- Daha uzaktaki satıcı oynatılmaz
local LOOK_DISTANCE = 26
local GREET_DISTANCE = 15
local LEAVE_DISTANCE = 22
local GREET_SECONDS = 6
local MAX_LOOK_YAW = 0.9

-- Her satıcı işine göre iki selam arasında dönüşümlü konuşur (çeviri Localizer'da)
local GREETINGS: { [string]: { string } } = {
	orders = { "Merhaba! Günün siparişlerine göz at.", "Siparişleri zamanında teslim et, ödülü büyük!" },
	store = { "Çekiç, asa, muska... hepsi burada!", "Bir kez al, ömür boyu faydasını gör." },
	roadmap = {
		"Sıradaki hedefini mi arıyorsun? Yol haritası bende.",
		"Her yatırım çiftliğini büyütür, sırayı sen seç.",
	},
	travel = { "Hangi adaya yelken açıyoruz?", "Adalarını gezmek için tabelaya yaklaş." },
}

type Attached = { part: BasePart, rel: CFrame }
type Arm = { part: BasePart, base: CFrame, side: number }
type Npc = {
	model: Model,
	torso: BasePart,
	head: BasePart,
	headBase: CFrame,
	attached: { Attached },
	arms: { Arm },
	wave: Arm?,
	phase: number,
	yaw: number,
	bubble: BillboardGui?,
	greetUntil: number,
	greeted: boolean,
	lines: { string },
	lineIndex: number,
}

local npcs: { [Model]: Npc } = {}

local function setup(model: Instance)
	if not model:IsA("Model") or npcs[model] then
		return
	end
	local head = model:FindFirstChild("Head")
	local torso = model:FindFirstChild("Torso")
	if not head or not head:IsA("BasePart") or not torso or not torso:IsA("BasePart") then
		return -- Parçalar henüz gelmedi (streaming); ChildAdded ile tekrar denenir
	end
	local headBase = head.CFrame
	local attached: { Attached } = {}
	local arms: { Arm } = {}
	for _, child in model:GetChildren() do
		if not child:IsA("BasePart") then
			continue
		end
		if child.Name == "Eye" or child.Name == "HatBrim" or child.Name == "HatTop" then
			table.insert(attached, { part = child, rel = headBase:ToObjectSpace(child.CFrame) })
		elseif child.Name == "Arm" then
			local side = if torso.CFrame:PointToObjectSpace(child.Position).X >= 0 then 1 else -1
			table.insert(arms, { part = child, base = child.CFrame, side = side })
		end
	end
	local wave: Arm? = nil
	for _, arm in arms do
		if arm.side > 0 then
			wave = arm
		end
	end
	local action = model:GetAttribute("Action")
	npcs[model] = {
		model = model,
		torso = torso,
		head = head,
		headBase = headBase,
		attached = attached,
		arms = arms,
		wave = wave,
		phase = math.random() * math.pi * 2,
		yaw = 0,
		bubble = nil,
		greetUntil = 0,
		greeted = false,
		lines = if typeof(action) == "string" then GREETINGS[action] or {} else {},
		lineIndex = 0,
	}
end

local function hideBubble(npc: Npc)
	if npc.bubble then
		npc.bubble:Destroy()
		npc.bubble = nil
	end
end

local function showBubble(npc: Npc, now: number)
	if #npc.lines == 0 then
		return
	end
	npc.lineIndex = npc.lineIndex % #npc.lines + 1
	local text = npc.lines[npc.lineIndex]
	hideBubble(npc)
	npc.bubble = WorldUi.tag(npc.head, "Greeting", {
		text = text,
		widthStuds = math.max(#text * 0.26, 8),
		heightStuds = 1.4,
		worldOffset = Vector3.new(0, 3.2, 0),
		maxDistance = 40,
		tint = UiTheme.Color.Gold,
	})
	npc.greetUntil = now + GREET_SECONDS
end

-- Parçalar model çoğalırken geç gelebilir (streaming): kurulana kadar kısa aralıklarla dene
local function track(instance: Instance)
	task.spawn(function()
		for _ = 1, 20 do
			setup(instance)
			if npcs[instance :: Model] then
				return
			end
			task.wait(0.5)
		end
	end)
end

CollectionService:GetInstanceAddedSignal("HubNpc"):Connect(track)
CollectionService:GetInstanceRemovedSignal("HubNpc"):Connect(function(instance: Instance)
	local npc = npcs[instance :: Model]
	if npc then
		hideBubble(npc)
		npcs[instance :: Model] = nil
	end
end)
for _, instance in CollectionService:GetTagged("HubNpc") do
	track(instance)
end

RunService.Heartbeat:Connect(function(dt: number)
	if next(npcs) == nil then
		return
	end
	local reduced = EffectSettings.reducedMotion()
	local character = localPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local playerPosition: Vector3? = if root and root:IsA("BasePart") then root.Position else nil
	local now = os.clock()

	for model, npc in npcs do
		if not model.Parent or not npc.head.Parent then
			hideBubble(npc)
			npcs[model] = nil
			continue
		end
		local distance = if playerPosition then (playerPosition - npc.torso.Position).Magnitude else math.huge
		-- Selam balonu: yaklaşınca bir kez, uzaklaşınca sıfırlanır
		if distance <= GREET_DISTANCE and not npc.greeted then
			npc.greeted = true
			showBubble(npc, now)
		elseif distance > LEAVE_DISTANCE then
			npc.greeted = false
			hideBubble(npc)
		end
		if npc.bubble and now >= npc.greetUntil then
			hideBubble(npc)
		end
		if distance > ANIMATE_DISTANCE or reduced then
			continue
		end

		npc.phase += dt
		-- Oyuncuya doğru bakış (gövde yönüne göre sınırlı), yumuşak geçiş
		local targetYaw = 0
		if playerPosition and distance <= LOOK_DISTANCE then
			local rel = npc.torso.CFrame:PointToObjectSpace(playerPosition)
			targetYaw = math.clamp(-math.atan2(rel.X, -rel.Z), -MAX_LOOK_YAW, MAX_LOOK_YAW)
		end
		npc.yaw += (targetYaw - npc.yaw) * math.min(1, dt * 6)
		local bob = math.sin(npc.phase * 1.6) * 0.07
		local headCf = npc.headBase * CFrame.new(0, bob, 0) * CFrame.Angles(0, npc.yaw, 0)
		npc.head.CFrame = headCf
		for _, item in npc.attached do
			item.part.CFrame = headCf * item.rel
		end

		-- Kollar: boşta hafif sallanır; yakındayken bir kol el sallar
		for _, arm in npc.arms do
			local half = arm.part.Size.Y / 2
			local angle = math.sin(npc.phase * 1.3 + arm.side) * 0.05
			if distance <= GREET_DISTANCE and npc.wave == arm then
				angle = 1.3 + math.sin(npc.phase * 9) * 0.3
			end
			arm.part.CFrame = arm.base * CFrame.new(0, half, 0) * CFrame.Angles(angle, 0, 0) * CFrame.new(0, -half, 0)
		end
	end
end)
