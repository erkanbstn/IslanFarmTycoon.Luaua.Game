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
	-- Mevsim hedefi: her mevsimde yeni bir hedef; ilerleme ve kalan süre canlı gösterilir
	local seasonalCard = UiKit.card(list, 19, "🌸")
	seasonalCard.action.Activated:Connect(function()
		if seasonalCard.action.Active then
			PurchaseController.submit("RequestClaimSeasonal", "seasonal")
		end
	end)
	local function updateSeasonal(state: PlayerSave, now: number)
		local goal, stored = Rewards.seasonalGoal(state, now)
		local def, season = Rewards.seasonalDef(goal.key)
		local progress = Rewards.seasonalProgress(state, goal)
		local left = math.max(0, (goal.key + 1) * Config.SEASON_SECONDS - now)
		local progressText = if def.metric == "earned"
			then `Kazan: {FarmMath.formatMoney(progress)}/{FarmMath.formatMoney(goal.target)}`
			else `Yatırım yap: {math.floor(progress)}/{goal.target}`
		seasonalCard.icon.Text = season.icon
		seasonalCard.title.Text = `Mevsim hedefi · {season.eventName}`
		seasonalCard.detail.Text =
			`{progressText} · Ödül: {FarmMath.formatMoney(Rewards.seasonalReward(state))} · {string.format(
				"%02d:%02d",
				math.ceil(left) // 60,
				math.ceil(left) % 60
			)} kaldı`
		local pending = PurchaseController.isPending()
		if not stored then
			seasonalCard.action.Text = "Hazırlanıyor"
			UiKit.setVariant(seasonalCard.action, "disabled")
		elseif goal.claimed then
			seasonalCard.action.Text = "Alındı"
			UiKit.setVariant(seasonalCard.action, "owned")
		elseif progress >= goal.target then
			seasonalCard.action.Text = "Ödülü al"
			UiKit.setVariant(seasonalCard.action, if pending then "disabled" else "primary")
		else
			seasonalCard.action.Text = `{math.floor(progress)}/{goal.target}`
			UiKit.setVariant(seasonalCard.action, "disabled")
		end
	end

	-- Başarımlar uzun bir liste: varsayılan kapalıdır; düğmeyle açılır (ödül alınabiliyorsa düğme vurgulanır)
	local achievementsToggle = UiKit.button(list, "Başarımlar", "secondary")
	achievementsToggle.Size = UDim2.new(1, 0, 0, 38)
	achievementsToggle.LayoutOrder = 21
	local achievementsOpen = false
	local achievementCards: { [string]: UiKit.Card } = {}
	local achievementsSummary = ""
	local achievementsClaimable = 0
	local function refreshAchievementsToggle()
		achievementsToggle.Text = if achievementsOpen then "Başarımları gizle" else achievementsSummary
		UiKit.setVariant(
			achievementsToggle,
			if achievementsClaimable > 0 and not achievementsOpen then "primary" else "secondary"
		)
		for _, card in achievementCards do
			card.frame.Visible = achievementsOpen
		end
	end
	achievementsToggle.Activated:Connect(function()
		achievementsOpen = not achievementsOpen
		refreshAchievementsToggle()
	end)
	for index, achievement in Config.ACHIEVEMENTS do
		local card = UiKit.card(list, 21 + index, achievement.icon)
		card.frame.Visible = false
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
		local now = Workspace:GetServerTimeNow()
		updateSeasonal(state, now)
		local status = Rewards.dailyStatus(state.daily, now)
		local claimable = Rewards.claimableCount(state, now)
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
		achievementsClaimable = claimable
		achievementsSummary = if claimable > 0
			then `Başarımlar · {claimed}/{#Config.ACHIEVEMENTS} · Ödül var`
			else `Başarımlar · {claimed}/{#Config.ACHIEVEMENTS}`
		refreshAchievementsToggle()
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
