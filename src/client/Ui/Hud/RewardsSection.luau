--!strict
-- Ödüller penceresi: Günlük (günlük ödül + mevsim hedefi) ve Başarımlar sekmeleri.

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local GameTypes = require(Shared:WaitForChild("GameTypes"))
local FarmMath = require(Shared:WaitForChild("Modules"):WaitForChild("FarmMath"))
local Rewards = require(Shared:WaitForChild("Modules"):WaitForChild("Rewards"))
local UiKit = require(script.Parent.Parent:WaitForChild("UiKit"))
local PurchaseController = require(script.Parent.Parent.Parent:WaitForChild("Core"):WaitForChild("PurchaseController"))

type PlayerSave = GameTypes.PlayerSave

local RewardsSection = {}

-- setRewardsBadge: Ödüller düğmesindeki "alınabilir ödül" rozeti
-- Döner: (tam güncelleme, yalnızca rozet). Pencere kapalıyken yalnızca ikincisi çağrılır.
function RewardsSection.create(
	list: Instance,
	setRewardsBadge: (number) -> ()
): ((PlayerSave) -> (), (PlayerSave) -> ())
	local dailyCard = UiKit.card(list, 20, "🎁")
	UiKit.setText(dailyCard.title, "Günlük ödül")
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
		UiKit.setText(seasonalCard.icon, season.icon)
		UiKit.setText(seasonalCard.title, `Mevsim hedefi · {season.eventName}`)
		UiKit.setText(
			seasonalCard.detail,
			`{progressText} · Ödül: {FarmMath.formatMoney(Rewards.seasonalReward(state))} · {string.format(
				"%02d:%02d",
				math.ceil(left) // 60,
				math.ceil(left) % 60
			)} kaldı`
		)
		local pending = PurchaseController.isPending()
		if not stored then
			UiKit.setText(seasonalCard.action, "Hazırlanıyor")
			UiKit.setVariant(seasonalCard.action, "disabled")
		elseif goal.claimed then
			UiKit.setText(seasonalCard.action, "Alındı")
			UiKit.setVariant(seasonalCard.action, "owned")
		elseif progress >= goal.target then
			UiKit.setText(seasonalCard.action, "Ödülü al")
			UiKit.setVariant(seasonalCard.action, if pending then "disabled" else "primary")
		else
			UiKit.setText(seasonalCard.action, `{math.floor(progress)}/{goal.target}`)
			UiKit.setVariant(seasonalCard.action, "disabled")
		end
	end

	-- Sekmeler: Günlük (günlük ödül + mevsim hedefi) | Başarımlar (uzun liste; alınabilirler üstte)
	local currentTab = "daily"
	local achievementCards: { [string]: UiKit.Card } = {}
	local achievementProgress: { [string]: (number, Color3) -> () } = {}
	local claimableHeader = UiKit.sectionHeader(list, "Alınabilir başarımlar", 0)
	local claimableHeaderRow = claimableHeader.Parent :: GuiObject
	local hasClaimable = false
	claimableHeaderRow.Visible = false
	local achievementsSummary = "Başarımlar"
	local tabsRow: Frame
	local function refreshTabs()
		local daily = currentTab == "daily"
		dailyCard.frame.Visible = daily
		seasonalCard.frame.Visible = daily
		claimableHeaderRow.Visible = not daily and hasClaimable
		for _, card in achievementCards do
			card.frame.Visible = not daily
		end
		for _, child in tabsRow:GetChildren() do
			if child:IsA("TextButton") and child.LayoutOrder == 2 then
				UiKit.setText(child, achievementsSummary)
			end
		end
	end
	tabsRow = UiKit.tabs(list, -1, {
		{ id = "daily", label = "Günlük" },
		{ id = "achievements", label = "Başarımlar" },
	}, function(id: string)
		currentTab = id
		refreshTabs()
	end)
	local achievementGrid = UiKit.autoGrid(list, 21)
	for index, achievement in Config.ACHIEVEMENTS do
		local card = UiKit.autoTile(achievementGrid, index, achievement.icon)
		card.frame.Visible = false
		UiKit.setText(card.title, achievement.displayName)
		achievementCards[achievement.id] = card
		UiKit.cardDetails(card, "Ayrıntılar")
		local bar, setProgress = UiKit.progressBar(card.frame, 6)
		bar.LayoutOrder = 3
		achievementProgress[achievement.id] = setProgress
		card.action.Activated:Connect(function()
			if card.action.Active then
				PurchaseController.submit("RequestClaimAchievement", achievement.id)
			end
		end)
	end

	local rewardSignature = ""
	local function updateBadge(state: PlayerSave)
		local now = Workspace:GetServerTimeNow()
		local status = Rewards.dailyStatus(state.daily, now)
		setRewardsBadge(Rewards.claimableCount(state, now) + (if status.canClaim then 1 else 0))
	end
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
		setRewardsBadge(claimable + (if status.canClaim then 1 else 0))
		if signature == rewardSignature then
			return
		end
		rewardSignature = signature

		local length = #Config.DAILY_REWARD_MULTIPLIERS
		if status.canClaim then
			UiKit.setText(
				dailyCard.detail,
				`{status.nextStreak}. gün · Ödül: {FarmMath.formatMoney(
					Rewards.dailyAmount(state, status.nextStreak)
				)}`
			)
			UiKit.setText(dailyCard.action, "Ödülü al")
			UiKit.setVariant(dailyCard.action, if pending then "disabled" else "primary")
		else
			UiKit.setText(dailyCard.detail, `Seri {status.streak}/{length} · Yarın yeni ödül`)
			UiKit.setText(dailyCard.action, "Alındı")
			UiKit.setVariant(dailyCard.action, "owned")
		end
		achievementsSummary = if claimable > 0
			then `Başarımlar · {claimed}/{#Config.ACHIEVEMENTS} · Ödül var`
			else `Başarımlar · {claimed}/{#Config.ACHIEVEMENTS}`
		-- Sıralama: alınabilirler en üstte, sonra tamamlanmaya en yakın olanlar, alınmışlar en altta
		local claimableIndex = 0
		for index, achievement in Config.ACHIEVEMENTS do
			local card = achievementCards[achievement.id]
			local owned = state.achievements ~= nil and state.achievements[achievement.id] == true
			local progress = Rewards.progress(state, achievement)
			if owned then
				card.frame.LayoutOrder = 3000 + index
			elseif progress >= achievement.target then
				claimableIndex += 1
				card.frame.LayoutOrder = claimableIndex
			else
				card.frame.LayoutOrder = 100 + math.floor((1 - progress / achievement.target) * 1000)
			end
		end
		hasClaimable = claimableIndex > 0
		refreshTabs()
		for _, achievement in Config.ACHIEVEMENTS do
			local card = achievementCards[achievement.id]
			local owned = state.achievements ~= nil and state.achievements[achievement.id] == true
			local progress = Rewards.progress(state, achievement)
			local shown = math.min(progress, achievement.target)
			local text = if achievement.metric == "earned"
				then `{FarmMath.formatMoney(shown)}/{FarmMath.formatMoney(achievement.target)}`
				else `{math.floor(shown)}/{achievement.target}`
			UiKit.setText(card.detail, achievement.description)
			achievementProgress[achievement.id](shown / math.max(1, achievement.target), UiKit.Color.Green)
			if owned then
				UiKit.setText(card.action, "Alındı")
				UiKit.setVariant(card.action, "owned")
			elseif progress >= achievement.target then
				UiKit.setText(card.action, `Ödülü al · {FarmMath.formatMoney(achievement.reward)}`)
				UiKit.setVariant(card.action, if pending then "disabled" else "primary")
			else
				UiKit.setText(card.action, text)
				UiKit.setVariant(card.action, "disabled")
			end
		end
	end
	return updateRewards, updateBadge
end

return RewardsSection
