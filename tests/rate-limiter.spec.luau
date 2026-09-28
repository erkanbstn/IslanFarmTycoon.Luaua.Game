--!strict
-- Gerçek RateLimiter; zaman ve oyuncu-ayrılma sinyali deterministik olarak enjekte edilir.
return function(createLimiter: any)
	local now = 0
	local onRemoving: any = nil
	local engine = {
		GetService = function(): any
			return {
				PlayerRemoving = {
					Connect = function(_self: any, callback: any)
						onRemoving = callback
					end,
				},
			}
		end,
	}
	local limiter = createLimiter(engine, {
		clock = function(): number
			return now
		end,
	})
	local player: any = {}
	local other: any = {}
	assert(limiter.allow(player, "purchase", 0.2), "first purchase must be accepted at time zero")
	assert(not limiter.allow(player, "purchase", 0.2), "same action is throttled")
	assert(limiter.allow(other, "purchase", 0.2), "players have independent limits")
	assert(limiter.allow(player, "purchaseThrottleReply", 0.5), "reply bucket is separate from purchase")
	now = 0.2
	assert(limiter.allow(player, "purchase", 0.2), "purchase cooldown expires at boundary")
	assert(not limiter.allow(player, "purchaseThrottleReply", 0.5), "reply traffic stays independently bounded")
	now = 0.5
	assert(limiter.allow(player, "purchaseThrottleReply", 0.5), "reply cooldown expires at boundary")

	assert(limiter.validId("cow"), "short string IDs are valid")
	assert(
		not limiter.validId(4) and not limiter.validId("") and not limiter.validId(string.rep("x", 65)),
		"IDs require bounded strings"
	)
	assert(limiter.acceptRequest(player, nil), "legacy prompt requests omit request ID")
	for _, invalid in { -1, 0.5, 0 / 0, math.huge, 2147483648, "1", {} } do
		assert(not limiter.acceptRequest(player, invalid), "invalid request ID must not be registered")
	end
	assert(limiter.acceptRequest(player, 0), "zero is a valid integral request ID")
	assert(not limiter.acceptRequest(player, 0), "same request cannot purchase twice")
	assert(limiter.acceptRequest(other, 0), "request IDs are scoped to the player")
	for id = 1, 128 do
		assert(limiter.acceptRequest(player, id), "unique request must be accepted")
	end
	assert(not limiter.acceptRequest(player, 128), "newest request remains deduplicated")
	assert(limiter.acceptRequest(player, 0), "dedup history is intentionally bounded to 128 recent requests")
	onRemoving(player)
	assert(limiter.allow(player, "purchaseThrottleReply", 0.5), "departure clears cooldown state")
	assert(limiter.acceptRequest(player, 128), "departure clears request history")
	print(
		"PASS rate limiter: cooldown boundaries, independent reply budget, invalid IDs, dedup, bounded history, cleanup"
	)
end
