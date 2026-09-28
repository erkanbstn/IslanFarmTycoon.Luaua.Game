--!strict
-- Ucuz, oyuncu/eylem bazlı kontrol. Remote ve prompt aynı servis girişini kullanır.
local Players = game:GetService("Players")

local RateLimiter = {}
local nextAllowed: { [Player]: { [string]: number } } = {}
local recentRequests: { [Player]: { number } } = {}

function RateLimiter.allow(player: Player, action: string, interval: number): boolean
	local now = os.clock()
	local actions = nextAllowed[player]
	if not actions then
		actions = {}
		nextAllowed[player] = actions
	end
	if now < (actions[action] or 0) then
		return false
	end
	actions[action] = now + interval
	return true
end

function RateLimiter.validId(value: unknown): boolean
	return typeof(value) == "string" and #value > 0 and #value <= 64
end

-- Eski client/prompt kimlik göndermeyebilir. Yeni client tüm satın almalarda
-- ortak artan kimlik kullanır; son istekler tekrar gönderilirse işlem yapılmaz.
function RateLimiter.acceptRequest(player: Player, requestId: unknown): boolean
	if requestId == nil then
		return true
	end
	if
		typeof(requestId) ~= "number"
		or requestId ~= requestId
		or requestId < 0
		or requestId > 2147483647
		or requestId % 1 ~= 0
	then
		return false
	end
	local recent = recentRequests[player]
	if not recent then
		recent = {}
		recentRequests[player] = recent
	end
	if table.find(recent, requestId) then
		return false
	end
	table.insert(recent, requestId)
	if #recent > 128 then
		table.remove(recent, 1)
	end
	return true
end

function RateLimiter.reset(player: Player)
	nextAllowed[player] = nil
	recentRequests[player] = nil
end

Players.PlayerRemoving:Connect(RateLimiter.reset)

return RateLimiter
