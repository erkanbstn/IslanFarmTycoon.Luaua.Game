--!strict
-- Çiftliğim penceresi: günlük ödül ve başarımlar.

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local GameTypes = require(Shared:WaitForChild("GameTypes"))
local FarmMath = require(Shared:WaitForChild("Modules"):WaitForChild("FarmMath"))
local Rewards = require(Shared:WaitForChild("Modules"):WaitForChild("Rewards"))
local UiKit = require(script.Parent.Parent:WaitForChild("UiKit"))
local PurchaseController = require(script.Parent.Parent:WaitForChild("PurchaseController"))

type PlayerSave = GameTypes.PlayerSave

local RewardsSection = {}

-- setGoalsBadge: Çiftliğim düğmesindeki "alınabilir ödül" rozeti
function RewardsSection.create(list: Instance, setGoalsBadge: (number) -> ()): (PlayerSave) -> ()
	local dailyCard = UiKit.card(list, 20, "🎁")
	dailyCard.title.Text = "Günlük ödül"
	dailyCard.action.Activated:Connect(function()
		if dailyCard.action.Active then
			PurchaseController.submit("RequestClaimDaily", "daily")
		end
	end)
	local _, achievementsMeta = UiKit.sectionHeader(list, "Başarımlar", 21)
	local achievementCards: { [string]: UiKit.Card } = {}
	for index, achievement in Config.ACHIEVEMENTS do
		local card = UiKit.card(list, 21 + index, achievement.icon)
		card.title.Text = achievement.displayName
		achievementCards[achievement.id] = card
		card.action.Activated:Connect(function()
			if card.action.Active then
				PurchaseController.submit("RequestClaimAchievement", achievement.id)
			end
		end)
	end

	local rewardSignature = ""
	local function updateRewards(state: PlayerSave)
		local status = Rewards.dailyStatus(state.daily, Workspace:GetServerTimeNow())
		local claimable = Rewards.claimableCount(state)
		local parts: { string } = { tostring(status.canClaim), tostring(status.streak), tostring(claimable) }
		local claimed = 0
		for _, achievement in Config.ACHIEVEMENTS do
			local owned = state.achievements ~= nil and state.achievements[achievement.id] == true
			if owned then
				claimed += 1
			end
			table.insert(parts, `{if owned then "c" else Rewards.progress(state, achievement)}`)
		end
		local pending = PurchaseController.isPending()
		table.insert(parts, tostring(pending))
		table.insert(parts, tostring(if status.canClaim then Rewards.dailyAmount(state, status.nextStreak) else 0))
		local signature = table.concat(parts, "|")
		setGoalsBadge(claimable + (if status.canClaim then 1 else 0))
		if signature == rewardSignature then
			return
		end
		rewardSignature = signature

		local length = #Config.DAILY_REWARD_MULTIPLIERS
		if status.canClaim then
			dailyCard.detail.Text = `{status.nextStreak}. gün · Ödül: {FarmMath.formatMoney(
				Rewards.dailyAmount(state, status.nextStreak)
			)}`
			dailyCard.action.Text = "Ödülü al"
			UiKit.setVariant(dailyCard.action, if pending then "disabled" else "primary")
		else
			dailyCard.detail.Text = `Seri {status.streak}/{length} · Yarın yeni ödül`
			dailyCard.action.Text = "Alındı"
			UiKit.setVariant(dailyCard.action, "owned")
		end
		achievementsMeta.Text = `{claimed}/{#Config.ACHIEVEMENTS}`
		for _, achievement in Config.ACHIEVEMENTS do
			local card = achievementCards[achievement.id]
			local owned = state.achievements ~= nil and state.achievements[achievement.id] == true
			local progress = Rewards.progress(state, achievement)
			local shown = math.min(progress, achievement.target)
			local text = if achievement.metric == "earned"
				then `{FarmMath.formatMoney(shown)}/{FarmMath.formatMoney(achievement.target)}`
				else `{math.floor(shown)}/{achievement.target}`
			card.detail.Text = `{achievement.description} · {text}`
			if owned then
				card.action.Text = "Alındı"
				UiKit.setVariant(card.action, "owned")
			elseif progress >= achievement.target then
				card.action.Text = `Ödülü al · {FarmMath.formatMoney(achievement.reward)}`
				UiKit.setVariant(card.action, if pending then "disabled" else "primary")
			else
				card.action.Text = text
				UiKit.setVariant(card.action, "disabled")
			end
		end
	end
	return updateRewards
end

return RewardsSection
