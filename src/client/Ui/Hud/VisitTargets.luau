--!strict
-- Tema teklifleri sahiplik değildir; oyuncu öznitelikleri streaming dışında da görünür.
local VisitTargets = {}

export type Target = { owner: Player, plotId: string?, farmId: string? }

function VisitTargets.list(players: { Player }, localUserId: number): { Target }
	local result: { Target } = {}
	for _, owner in players do
		if owner.UserId == localUserId then
			continue
		end
		local plotId = owner:GetAttribute("ActivePlotId")
		local farmId = owner:GetAttribute("ActiveMainFarmId")
		table.insert(result, {
			owner = owner,
			plotId = if typeof(plotId) == "string" and plotId ~= "" then plotId else nil,
			farmId = if typeof(farmId) == "string" and farmId ~= "" then farmId else nil,
		})
	end
	table.sort(result, function(a: Target, b: Target): boolean
		return a.owner.UserId < b.owner.UserId
	end)
	return result
end

return VisitTargets
