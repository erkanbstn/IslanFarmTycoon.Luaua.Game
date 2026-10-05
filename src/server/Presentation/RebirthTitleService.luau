--!strict
-- Rebirth ünvanı: her oyuncunun karakterinde başın üstünde küçük bir etiket ("R3 · Usta Çiftçi").
-- Sayı yalnızca sunucu kaydından okunur (init.server `getCount` enjekte eder; istemciden hiçbir şey alınmaz).
-- Rebirth sayısı 0 iken etiket yoktur. Yeni karakterde (doğma/yeniden doğma) yeniden kurulur, rebirth sonrası
-- `refresh` ile yerinde güncellenir. Animasyon yok (hareket azaltma/düşük kalite ile çakışmaz); MaxDistance
-- sınırlı ve AlwaysOnTop kapalı. Karakter/oyuncu kalkınca etiket ve bağlantılar temizlenir. Para/kayıt yazmaz.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RebirthTitles = require(Shared:WaitForChild("Modules"):WaitForChild("RebirthTitles"))
local WorldUi = require(Shared:WaitForChild("WorldUi"))

local RebirthTitleService = {}

local TAG_NAME = "RebirthTitle"
local MAX_DISTANCE = 60
local HEIGHT_STUDS = 0.8
local HEAD_OFFSET = 3.4 -- Roblox'un varsayılan ad etiketinin üstünde kalır
local HEAD_WAIT_SECONDS = 5

type State = {
	character: Model?,
	tag: any,
	text: string?,
	connections: { RBXScriptConnection },
}

local states: { [Player]: State } = {}
local getCount: ((Player) -> number?)? = nil
local initialized = false

local function destroyTag(state: State)
	local tag = state.tag
	state.tag = nil
	state.text = nil
	if tag then
		tag:Destroy()
	end
end

local function widthFor(text: string): number
	local length = utf8.len(text) or #text
	return math.max(length * 0.3 + 1.2, 3)
end

local function currentLabel(player: Player): string?
	local read = getCount
	if not read then
		return nil
	end
	local ok, count = pcall(read, player)
	if not ok then
		return nil
	end
	return RebirthTitles.label(count)
end

-- Etiketi kayıttaki sayıya göre kurar/günceller/kaldırır.
local function apply(player: Player, state: State)
	local character = state.character
	local label = currentLabel(player)
	if not character or not character.Parent or label == nil then
		destroyTag(state)
		return
	end
	local head = character:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		destroyTag(state)
		return
	end
	if state.tag and state.tag.Parent == head then
		if state.text ~= label then
			WorldUi.setTag(state.tag, label)
			state.text = label
		end
		return
	end
	destroyTag(state)
	local tag = WorldUi.tag(head, TAG_NAME, {
		text = label,
		widthStuds = widthFor(label),
		heightStuds = HEIGHT_STUDS,
		worldOffset = Vector3.new(0, HEAD_OFFSET, 0),
		maxDistance = MAX_DISTANCE,
	})
	tag.AlwaysOnTop = false
	tag.Active = false
	state.tag = tag
	state.text = label
end

local function bindCharacter(player: Player, state: State, character: Model)
	destroyTag(state)
	state.character = character
	task.spawn(function()
		-- R6/R15 ikisinde de "Head" vardır; gelmezse etiket kurulmaz.
		if not character:WaitForChild("Head", HEAD_WAIT_SECONDS) then
			return
		end
		if states[player] == state and state.character == character then
			apply(player, state)
		end
	end)
end

local function releasePlayer(player: Player)
	local state = states[player]
	if not state then
		return
	end
	states[player] = nil
	for _, connection in state.connections do
		connection:Disconnect()
	end
	table.clear(state.connections)
	state.character = nil
	destroyTag(state)
end

local function trackPlayer(player: Player)
	if states[player] then
		return
	end
	local state: State = { character = nil, tag = nil, text = nil, connections = {} }
	states[player] = state
	table.insert(
		state.connections,
		player.CharacterAdded:Connect(function(character: Model)
			bindCharacter(player, state, character)
		end)
	)
	table.insert(
		state.connections,
		player.CharacterRemoving:Connect(function(character: Model)
			if state.character == character then
				state.character = nil
				destroyTag(state)
			end
		end)
	)
	-- Kayıt yüklenip dünya hazır olunca (karakter veriden önce doğmuş olabilir) etiketi kur.
	table.insert(
		state.connections,
		player:GetAttributeChangedSignal("WorldReady"):Connect(function()
			apply(player, state)
		end)
	)
	local existing = player.Character
	if existing then
		bindCharacter(player, state, existing)
	end
end

-- Rebirth sonrası ya da sayı değişince çağrılır; etiket anında güncellenir.
function RebirthTitleService.refresh(player: Player)
	local state = states[player]
	if state then
		apply(player, state)
	end
end

function RebirthTitleService.init(readCount: (Player) -> number?)
	if initialized then
		return
	end
	initialized = true
	getCount = readCount
	Players.PlayerAdded:Connect(trackPlayer)
	Players.PlayerRemoving:Connect(releasePlayer)
	for _, player in Players:GetPlayers() do
		trackPlayer(player)
	end
end

return RebirthTitleService
