--!strict
-- Roblox PolicyService.IsPaidItemTradingAllowed kararı (oyuncu başına, oturum boyunca bellekte).
-- Para aktarımını bu politikanın kapsamında saymak temkinli bir ürün kararıdır: resmî belge bayrağı "Robux veya oyun içi
-- parayla alınan sanal eşyaların oyuncular arası takası" için tanımlar; nakit paketleri Robux'la satıldığından aktarım da kapsanır.
-- Değer kalıcı kayda yazılmaz, istemciden alınmaz; yalnızca açıkça `true` ise izin verilir (yükleniyor/hata/geçersiz = izin yok).
local Players = game:GetService("Players")
local PolicyService = game:GetService("PolicyService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local RateLimiter = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("RateLimiter"))

export type Status = "loading" | "allowed" | "restricted" | "unavailable"

type Entry = { status: Status, attempts: number, lastAttemptAt: number, loading: boolean }

local TradePolicyService = {}
local initialized = false
local entries: { [Player]: Entry } = {}

-- Geçici API hatasında 3 deneme (arada 2 sn, 5 sn); sonra "unavailable". Sonraki sorgularda en erken 30 sn arayla yeniden denenir.
local RETRY_DELAYS = { 2, 5 }
local MAX_ATTEMPTS = #RETRY_DELAYS + 1
local LAZY_RETRY_SECONDS = 30
local REQUEST_INTERVAL = 1

local function push(player: Player, entry: Entry)
	if player.Parent then
		pcall(function()
			Remotes.get("TradePolicyState"):FireClient(player, entry.status)
		end)
	end
end

-- true/false yalnızca gerçek boolean ise; eksik, null ya da başka tür yanıt geçersizdir (nil).
local function parse(info: unknown): boolean?
	if typeof(info) ~= "table" then
		return nil
	end
	local value = (info :: any).IsPaidItemTradingAllowed
	if typeof(value) ~= "boolean" then
		return nil
	end
	return value
end

local function load(player: Player, entry: Entry)
	if entry.loading then
		return
	end
	entry.loading = true
	entry.status = "loading"
	task.spawn(function()
		for attempt = 1, MAX_ATTEMPTS do
			entry.attempts += 1
			entry.lastAttemptAt = os.clock()
			local ok, info = pcall(function(): unknown
				return PolicyService:GetPolicyInfoForPlayerAsync(player)
			end)
			if entries[player] ~= entry then
				return -- oyuncu ayrıldı: gecikmiş yanıt hiçbir yere yazılmaz
			end
			local allowed = if ok then parse(info) else nil
			if allowed ~= nil then
				entry.loading = false
				entry.status = if allowed then "allowed" else "restricted"
				push(player, entry)
				return
			end
			if attempt < MAX_ATTEMPTS then
				task.wait(RETRY_DELAYS[attempt])
				if entries[player] ~= entry then
					return
				end
			end
		end
		entry.loading = false
		entry.status = "unavailable"
		warn(`[TradePolicy] Politika alınamadı user={player.UserId}; aktarım kapalı kalır`)
		push(player, entry)
	end)
end

function TradePolicyService.track(player: Player)
	if entries[player] or not player.Parent then
		return
	end
	local entry: Entry = { status = "loading", attempts = 0, lastAttemptAt = -math.huge, loading = false }
	entries[player] = entry
	load(player, entry)
end

function TradePolicyService.forget(player: Player)
	entries[player] = nil
end

-- "allowed" dışındaki her durum yeni para gönderimini reddeder.
function TradePolicyService.status(player: Player): Status
	local entry = entries[player]
	if not entry then
		if not player.Parent then
			return "unavailable" -- ayrılmış oyuncu yeniden izlenmez, asla izin almaz
		end
		TradePolicyService.track(player)
		entry = entries[player]
	end
	local current = entry :: Entry
	if current.status == "unavailable" and os.clock() - current.lastAttemptAt >= LAZY_RETRY_SECONDS then
		load(player, current)
	end
	return current.status
end

function TradePolicyService.canTrade(player: Player): boolean
	return TradePolicyService.status(player) == "allowed"
end

function TradePolicyService.init()
	if initialized then
		return
	end
	initialized = true
	Players.PlayerAdded:Connect(TradePolicyService.track)
	Players.PlayerRemoving:Connect(TradePolicyService.forget)
	for _, player in Players:GetPlayers() do
		TradePolicyService.track(player)
	end
	-- İstemci yalnızca KENDİ durumunu ister; yanıt hiçbir istemci değerine dayanmaz (argümanlar yok sayılır).
	Remotes.get("RequestTradePolicy").OnServerEvent:Connect(function(player: Player)
		if not RateLimiter.allow(player, "tradePolicy", REQUEST_INTERVAL) then
			return
		end
		TradePolicyService.status(player)
		push(player, entries[player] :: Entry)
	end)
end

return TradePolicyService
