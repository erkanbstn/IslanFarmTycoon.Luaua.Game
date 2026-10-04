--!strict
return function(VisitTargets: any)
	local function owner(id: number, plot: string?, farm: string?): any
		return {
			UserId = id,
			GetAttribute = function(_self: any, key: string): string?
				return if key == "ActivePlotId" then plot elseif key == "ActiveMainFarmId" then farm else nil
			end,
		}
	end
	local self = owner(1, "6", "1")
	local loading = owner(3, nil, nil)
	local friend = owner(2, "5", "4")
	local targets = VisitTargets.list({ loading, self, friend }, 1)
	assert(#targets == 2, "Every other server player must appear even with no streamed plot or theme owner")
	assert(targets[1].owner == friend and targets[1].plotId == "5", "Visit must target physical plot, not farm theme")
	assert(targets[1].farmId == "4", "Card must show owner's current theme")
	assert(targets[2].owner == loading and targets[2].plotId == nil, "Loading player remains available for money UI")
	assert(#VisitTargets.list({ self }, 1) == 0, "Solo server must not show the local player")
	assert(#VisitTargets.list({ self, loading }, 1) == 1, "Departed players must disappear on refresh")
	assert(
		VisitTargets.list({ owner(7, "2", "6") }, 1)[1].plotId == "2",
		"Farm switch must use current player attributes"
	)
	print("  visit targets use server players and physical plot attributes OK")
end
