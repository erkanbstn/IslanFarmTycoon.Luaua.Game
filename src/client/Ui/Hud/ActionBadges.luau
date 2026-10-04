--!strict
-- Menü ve alt sekmeler aynı işlem sayısını gösterir; sekmeye bakmak sayacı silmez.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local FarmMath = require(Shared:WaitForChild("Modules"):WaitForChild("FarmMath"))
local Rewards = require(Shared:WaitForChild("Modules"):WaitForChild("Rewards"))
local HudCommon = require(script.Parent:WaitForChild("HudCommon"))
local ActionBadges = {}

function ActionBadges.production(state: any, now: number): (number, { [string]: number })
	local total = 0
	local islands: { [string]: number } = {}
	for recipeId, job in state.production or {} do
		local recipe = Config.PRODUCTION_RECIPES[recipeId]
		if recipe and job.readyAt <= now and Config.themeHasIsland(state.activeMainFarmId, recipe.island) then
			islands[recipe.island] = (islands[recipe.island] or 0) + 1
			total += 1
		end
	end
	return total, islands
end

export type Upgrades = { total: number, upgrades: number, levels: number, expansions: number }
function ActionBadges.upgrades(state: any): (number, { [string]: Upgrades })
	local total = 0
	local islands: { [string]: Upgrades } = {}
	local function add(islandId: string, category: string)
		local counts = islands[islandId]
		if not counts then
			counts = { total = 0, upgrades = 0, levels = 0, expansions = 0 }
			islands[islandId] = counts
		end
		counts[category] += 1
		counts.total += 1
		total += 1
	end
	for _, upgrade in Config.UPGRADES do
		if
			upgrade.kind ~= "island"
			and FarmMath.isUpgradeInTheme(state, upgrade)
			and FarmMath.getUpgradeStatus(state, upgrade.id) == "available"
			and HudCommon.upgradeAffordable(state, upgrade)
		then
			add(Config.getUpgradeIsland(upgrade), if upgrade.leveled then "levels" else "upgrades")
		end
	end
	for targetId, target in Config.BUILD_TARGETS do
		if Config.themeHasIsland(state.activeMainFarmId, target.island) then
			local status, _, cost = FarmMath.getExpansionStatus(state, targetId)
			if status == "available" and state.cash >= cost then
				add(target.island, "expansions")
			end
		end
	end
	return total, islands
end

function ActionBadges.rewards(state: any, now: number): (number, number, number)
	local daily = (if Rewards.dailyStatus(state.daily, now).canClaim then 1 else 0)
		+ (if Rewards.seasonalClaimable(state, now) then 1 else 0)
	local achievements = Rewards.claimableCount(state)
	return daily + achievements, daily, achievements
end

return ActionBadges
