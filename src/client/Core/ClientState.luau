--!strict
-- Tek client snapshot'ı; geç açılan arayüz güncel durumu tekrar isteyebilir.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local GameTypes = require(Shared:WaitForChild("GameTypes"))
type PlayerSave = GameTypes.PlayerSave
type Listener = (PlayerSave, boolean) -> ()

local ClientState = {}
local current: PlayerSave? = nil
local revision = -1
local snapshotRevision = -1
local latestEconomy: { cash: number, stored: number, revision: number, farmId: string, orderProgress: number?, orderUid: string? }? =
	nil
local listeners: { [Listener]: boolean } = {}
local lastRequest = -math.huge

local function emit(structural: boolean)
	local state = current
	if not state then
		return
	end
	for listener in listeners do
		local ok, err = pcall(listener, state, structural)
		if not ok then
			warn(`[ClientState] {err}`)
		end
	end
end

function ClientState.get(): PlayerSave?
	return current
end

function ClientState.requestSnapshot()
	if os.clock() - lastRequest < 2 then
		return
	end
	lastRequest = os.clock()
	Remotes.get("RequestPlayerState"):FireServer()
end

function ClientState.onChanged(listener: Listener): () -> ()
	listeners[listener] = true
	if current then
		listener(current, true)
	end
	return function()
		listeners[listener] = nil
	end
end

Remotes.get("PlayerState").OnClientEvent:Connect(function(state: PlayerSave, nextRevision: number)
	if typeof(state) ~= "table" or typeof(nextRevision) ~= "number" or nextRevision < snapshotRevision then
		return
	end
	-- Farklı event kanallarında daha yeni para paketi önce geldiyse yapısal veriyi
	-- yine uygula, ancak para/sipariş ilerlemesini eski snapshot'a geri döndürme.
	local packet = latestEconomy
	if packet and nextRevision < packet.revision then
		state.cash = packet.cash
		if state.activeMainFarmId == packet.farmId then
			state.stored = packet.stored
			if state.order and state.order.uid == packet.orderUid and packet.orderProgress then
				state.order.progress = packet.orderProgress
			end
		end
	end
	snapshotRevision = nextRevision
	revision = math.max(revision, nextRevision)
	current = state
	Players.LocalPlayer:SetAttribute("ClientStateReady", true)
	emit(true)
end)

Remotes.get("EconomyTick").OnClientEvent
	:Connect(
		function(cash: number, stored: number, nextRevision: number, orderProgress: number?, activeMainFarmId: string?)
			if not current then
				ClientState.requestSnapshot()
				return
			end
			if typeof(nextRevision) ~= "number" or nextRevision <= revision then
				return
			end
			if nextRevision > revision + 1 then
				ClientState.requestSnapshot()
			end
			if typeof(cash) ~= "number" or typeof(stored) ~= "number" then
				return
			end
			local farmId = activeMainFarmId or "1"
			latestEconomy = {
				cash = cash,
				stored = stored,
				revision = nextRevision,
				farmId = farmId,
				orderProgress = orderProgress,
				orderUid = if current.activeMainFarmId == farmId and current.order then current.order.uid else nil,
			}
			revision = nextRevision
			current.cash = cash
			if current.activeMainFarmId == farmId then
				current.stored = stored
				if current.order and typeof(orderProgress) == "number" then
					current.order.progress = orderProgress
				end
			else
				ClientState.requestSnapshot()
			end
			emit(false)
		end
	)

task.spawn(function()
	while not current do
		ClientState.requestSnapshot()
		task.wait(1)
	end
end)
return ClientState
