--!strict
-- Sol paneldeki "sıradaki hedef" ve "sıradaki ada" kartları.
-- Hedef metinleri durumdan türetilir (yalnızca gösterim; satın almayı sunucu doğrular). Yeni oyuncuda
-- Onboarding adımları, deneyimli oyuncuda bekleyen işler ve "hızlı kazanç" önerisi gösterilir.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local GameTypes = require(Shared:WaitForChild("GameTypes"))
local FarmMath = require(Shared:WaitForChild("Modules"):WaitForChild("FarmMath"))
local Progression = require(Shared:WaitForChild("Modules"):WaitForChild("Progression"))
local IslandContext = require(script.Parent.Parent.Parent:WaitForChild("Core"):WaitForChild("IslandContext"))
local UiKit = require(script.Parent.Parent:WaitForChild("UiKit"))
local HudCommon = require(script.Parent:WaitForChild("HudCommon"))
local Onboarding = require(script.Parent:WaitForChild("Onboarding"))
local OnboardingBanner = require(script.Parent:WaitForChild("OnboardingBanner"))
local OnboardingSteps = require(Shared:WaitForChild("Modules"):WaitForChild("OnboardingSteps"))

type PlayerSave = GameTypes.PlayerSave

local Color = UiKit.Color
local purchaseHint = HudCommon.purchaseHint

local GoalCard = {}

export type Hud = {
	card: Frame, -- hedef kartı (sol panelde)
	updateGoal: (state: PlayerSave, income: number) -> (),
	updateIsland: (state: PlayerSave, income: number) -> (),
}

function GoalCard.create(stats: Frame, onboarding: Onboarding.Hud, banner: OnboardingBanner.Banner): Hud
	-- Sıradaki ada kartı: oyuncunun uzun vadeli amacı
	local islandCard = Instance.new("Frame")
	islandCard.BackgroundColor3 = Color.Surface
	islandCard.Size = UDim2.new(1, 0, 0, 0)
	islandCard.AutomaticSize = Enum.AutomaticSize.Y
	islandCard.LayoutOrder = 6
	islandCard.Parent = stats
	UiKit.corner(islandCard, UiKit.Radius.Card)
	UiKit.stroke(islandCard, 0.6).Color = Color.Gold
	UiKit.padding(islandCard, 10)
	UiKit.list(islandCard, 6)

	local islandRow = Instance.new("Frame")
	islandRow.Name = "IslandOverview"
	islandRow.BackgroundTransparency = 1
	islandRow.Size = UDim2.new(1, 0, 0, 40)
	islandRow.AutomaticSize = Enum.AutomaticSize.Y
	islandRow.LayoutOrder = 1
	islandRow.Parent = islandCard
	local islandChip = UiKit.iconChip(islandRow, "🏝️", 40, Color.Gold)
	local islandTexts = Instance.new("Frame")
	islandTexts.BackgroundTransparency = 1
	islandTexts.Position = UDim2.fromOffset(50, 0)
	islandTexts.Size = UDim2.new(1, -50, 0, 0)
	islandTexts.AutomaticSize = Enum.AutomaticSize.Y
	islandTexts.Parent = islandRow
	UiKit.list(islandTexts, 1)
	local islandHeader = UiKit.text(islandTexts, "SIRADAKİ ADA", "Caption", Color.Gold)
	islandHeader.FontFace = UiKit.Font.Bold
	islandHeader.LayoutOrder = 1
	local islandName = UiKit.text(islandTexts, "", "Heading")
	islandName.LayoutOrder = 2
	local islandTrait = UiKit.text(islandTexts, "", "Caption")
	islandTrait.LayoutOrder = 3
	local islandDetails = UiKit.disclosure(islandCard, 2, "Ayrıntılar")
	islandTrait.Parent = islandDetails.body
	local islandEta = UiKit.text(islandTexts, "", "Caption", Color.Text)
	islandEta.LayoutOrder = 4

	-- Sıradaki hedef kartı
	local goalCard = Instance.new("Frame")
	goalCard.BackgroundColor3 = Color.Surface
	goalCard.Size = UDim2.new(1, 0, 0, 0)
	goalCard.AutomaticSize = Enum.AutomaticSize.Y
	goalCard.LayoutOrder = 5
	goalCard.Parent = stats
	UiKit.corner(goalCard, UiKit.Radius.Card)
	UiKit.padding(goalCard, 10)
	UiKit.list(goalCard, 2)
	local goalTitle = UiKit.text(goalCard, "SIRADAKİ HEDEF", "Caption", Color.Gold)
	goalTitle.FontFace = UiKit.Font.Bold
	goalTitle.LayoutOrder = 1
	local goalLabel = UiKit.text(goalCard, "", "Body")
	goalLabel.LayoutOrder = 2
	local goalDetail = UiKit.text(goalCard, "", "Caption")
	goalDetail.LayoutOrder = 3
	local goalDetails = UiKit.disclosure(goalCard, 4, "Ayrıntılar")
	goalDetail.Parent = goalDetails.body

	local function updateGoalMain(state: PlayerSave, income: number)
		goalTitle.Text = "SIRADAKİ HEDEF"
		local progress = Progression.progress(state)
		if progress.canRebirth then
			goalTitle.Text = "REBIRTH HAZIR"
			goalLabel.Text = "Altı çiftliği tamamladın"
			goalDetail.Text = "Rebirth menüsünden kalıcı ödülünü seçerek yeni tura başlayabilirsin."
			return
		elseif
			state.progression
			and state.progression.count >= Config.PROGRESSION.maxRebirth
			and progress.farmsComplete == progress.farmsTotal
		then
			goalTitle.Text = "YOLCULUK TAMAMLANDI"
			goalLabel.Text = "Tüm rebirth seviyelerini ve çiftliklerini tamamladın"
			goalDetail.Text = "Siparişlere, üretime ve çiftliğini kişiselleştirmeye devam edebilirsin."
			return
		end
		-- İlk adımlar: hayvan al → parayı topla → ilk yükseltme (durumdan türetilir, vurgular Onboarding'de)
		local cheapest: Config.UpgradeConfig? = nil
		for _, upgrade in Config.UPGRADES do
			if
				FarmMath.getUpgradeStatus(state, upgrade.id) == "available"
				and (not cheapest or FarmMath.getUpgradeCost(state, upgrade) < FarmMath.getUpgradeCost(state, cheapest))
			then
				cheapest = upgrade
			end
		end
		local step = onboarding.apply(
			state,
			cheapest ~= nil and HudCommon.upgradeAffordable(state, cheapest),
			if cheapest then cheapest.id else nil
		)
		if step == 2 then
			goalTitle.Text = "İLK ADIMLAR 2/6"
			goalLabel.Text = "Yeşil platforma basıp parayı topla"
			goalDetail.Text = "Hayvanların depoya para üretir; platforma basınca kasana geçer."
			return
		elseif step == 3 and cheapest then
			goalTitle.Text = "İLK ADIMLAR 3/6"
			goalLabel.Text = `İlk yükseltme: {cheapest.displayName} · {FarmMath.formatMoney(
				FarmMath.getUpgradeCost(state, cheapest)
			)}`
			goalDetail.Text = purchaseHint(state, FarmMath.getUpgradeCost(state, cheapest), income, cheapest)
			return
		elseif step == 4 then
			goalTitle.Text = "İLK ADIMLAR 4/6"
			goalLabel.Text = "Yol Haritası'nı aç"
			goalDetail.Text =
				"Neden: Bütün yükseltmeler ve sıradaki adalar orada; en kârlı yatırımı oradan seçersin."
			return
		elseif step == 5 then
			local targetId, cost = OnboardingSteps.cheapestExpansion(state)
			if targetId then
				goalTitle.Text = "İLK ADIMLAR 5/6"
				goalLabel.Text =
					`İlk genişletme: {Config.getBuildTargetName(targetId, state.activeMainFarmId)} · {FarmMath.formatMoney(
						cost
					)}`
				goalDetail.Text = "Neden: Genişletme kapasite ve gelir ekler. Yükseltmeler penceresinde alınır."
				return
			end
		elseif step == 6 then
			goalTitle.Text = "İLK ADIMLAR 6/6"
			goalLabel.Text = "İlk üretim partini başlat"
			goalDetail.Text =
				"Neden: Tesis hayvanlarının ürününü paraya çevirir. Üretim penceresinden bir parti seç."
			return
		end
		if step == 1 then
			goalTitle.Text = "İLK ADIMLAR 1/6"
			local homeAnimal = Config.getHomeAnimal(state.activeMainFarmId)
			-- Hayvansız başlanır: ilk hayvan başlangıç parasıyla alınır
			local homeName = Config.ANIMALS[homeAnimal].displayName
			goalLabel.Text = if #state.animals == 0
				then `Pazar'ı aç ve ilk hayvanını satın al ({homeName})`
				else `İlk hedef: yeni bir hayvan ({homeName})`
			goalDetail.Text = purchaseHint(state, FarmMath.getAnimalPrice(state, homeAnimal), income)
			return
		end
		local best: Config.UpgradeConfig? = nil
		for _, upgrade in Config.UPGRADES do
			local status = FarmMath.getUpgradeStatus(state, upgrade.id)
			local useful = upgrade.id ~= "zone_pasture"
				or FarmMath.countInZone(state, "starter") >= FarmMath.getZoneCapacity(state, "starter")
			if
				useful
				and status == "available"
				and (not best or FarmMath.getUpgradeCost(state, upgrade) < FarmMath.getUpgradeCost(state, best))
			then
				best = upgrade
			end
		end
		-- Otlak diğer tüm tercihlerden sonra hâlâ eksik olabilir.
		if not best then
			for _, upgrade in Config.UPGRADES do
				if FarmMath.getUpgradeStatus(state, upgrade.id) == "available" then
					best = upgrade
					break
				end
			end
		end
		if best then
			goalLabel.Text = `{best.displayName} · {FarmMath.formatMoney(FarmMath.getUpgradeCost(state, best))}`
			local bestCost = FarmMath.getUpgradeCost(state, best)
			goalDetail.Text = purchaseHint(state, bestCost, income, best)
			-- Büyük hedef için biriktirirken parası yetenin küçük bir geliştirme (hedefin yarısından ucuz) varsa önerilir
			if state.cash < bestCost then
				local quickLabel: string? = nil
				local quickCost = math.huge
				for targetId, target in Config.BUILD_TARGETS do
					if target.island == IslandContext.get() then
						local status, _, cost = FarmMath.getExpansionStatus(state, targetId)
						if
							status == "available"
							and cost <= state.cash
							and cost * 2 <= bestCost
							and cost < quickCost
						then
							quickCost = cost
							quickLabel =
								`Hızlı kazanç: {Config.getBuildTargetName(targetId, state.activeMainFarmId)} Sv.{FarmMath.getExpansionLevel(
									state,
									targetId
								) + 1} · {FarmMath.formatMoney(cost)}`
						end
					end
				end
				if quickLabel then
					goalDetail.Text ..= "\n" .. quickLabel
				end
			end
			return
		end
		-- Yükseltme kalmadı: oyun sonu yatırımları (en ucuz ırk seviyesi ya da alan genişletmesi) hedef olur
		local lateLabel: string? = nil
		local lateCost = math.huge
		for _, animalId in Config.ANIMAL_ORDER do
			local status, _, cost = FarmMath.getLineageStatus(state, animalId)
			if status == "available" and cost < lateCost then
				lateCost = cost
				lateLabel =
					`{Config.getAnimalLook(animalId, state.activeMainFarmId).displayName} · Irk Sv.{FarmMath.getLineageLevel(
						state,
						animalId
					) + 1} · {FarmMath.formatMoney(cost)}`
			end
		end
		local lateIslands = FarmMath.themeIslands(state)
		for targetId, target in Config.BUILD_TARGETS do
			if table.find(lateIslands, target.island) then
				local status, _, cost = FarmMath.getExpansionStatus(state, targetId)
				if status == "available" and cost < lateCost then
					lateCost = cost
					lateLabel =
						`{Config.getBuildTargetName(targetId, state.activeMainFarmId)} · Geliştir Sv.{FarmMath.getExpansionLevel(
							state,
							targetId
						) + 1} · {FarmMath.formatMoney(cost)}`
				end
			end
		end
		if lateLabel then
			goalLabel.Text = lateLabel
			goalDetail.Text = purchaseHint(state, lateCost, income)
			return
		end
		goalTitle.Text = "ÇİFTLİK USTALIĞI VE SİPARİŞ"
		local capacity = 0
		local themeIslands = FarmMath.themeIslands(state)
		for zoneId, zone in Config.ZONES do
			if table.find(themeIslands, zone.island) then
				capacity += FarmMath.getZoneCapacity(state, zoneId)
			end
		end
		local adults = 0
		for _, animal in state.animals do
			if animal.stage == "adult" then
				adults += 1
			end
		end
		goalLabel.Text =
			`Ustalık: {adults}/{capacity} yetişkin · {FarmMath.countAnimals(state, "seabass")}/{FarmMath.getZoneCapacity(
				state,
				"fishpen"
			)} büyük balık`
		local delivered = if state.contracts then state.contracts.completed else 0
		goalDetail.Text = `Ahır siparişi: ürün merkezlerinde üret, depodan teslim et · Teslim edilen: {delivered}`
	end

	local function updateIslandGoal(state: PlayerSave, income: number)
		local island, upgrade = FarmMath.getNextIsland(state)
		islandCard.Visible = island ~= nil
		if not island or not upgrade then
			return
		end
		islandChip.Text = island.icon
		islandName.Text = `{island.displayName} · {FarmMath.formatMoney(FarmMath.getUpgradeCost(state, upgrade))}`
		islandTrait.Text = island.trait
		local status, missing = FarmMath.getUpgradeStatus(state, upgrade.id)
		islandEta.Text = if status == "locked"
			then `Önce: {table.concat(missing, ", ")}`
			else purchaseHint(state, FarmMath.getUpgradeCost(state, upgrade), income, upgrade)
	end

	-- Bekleyen işler: hedef kartının altında, o an yapılabilecek kısa işler (durumdan türetilir; iş bitince satır kaybolur)
	local function pendingChores(state: PlayerSave): { string }
		local chores: { string } = {}
		local now = Workspace:GetServerTimeNow()
		for recipeId, job in state.production do
			local recipe = Config.PRODUCTION_RECIPES[recipeId]
			if recipe and job.readyAt <= now then
				table.insert(chores, `Üretim hazır: {recipe.displayName}`)
			end
		end
		if #chores < 2 then
			for _, recipeId in Config.PRODUCTION_ORDER do
				local recipe = Config.PRODUCTION_RECIPES[recipeId]
				if
					not state.production[recipeId]
					and state.purchased[recipe.upgradeId]
					and state.unlockedIslands[recipe.island]
					and FarmMath.countProductionAdults(state, recipe, now) >= recipe.requiredAdults
					and state.cash >= FarmMath.getFacilityCost(state, recipe)
					and (
						recipe.output ~= "goods"
						or (
							recipe.goodsId ~= nil
							and FarmMath.getGoodsSpace(state, recipe.goodsId)
								>= math.min(
									math.max(recipe.goodsAmount or 0, FarmMath.previewGoodsYield(state, recipe, now)),
									FarmMath.getGoodsCap(state)
								)
						)
					)
				then
					table.insert(chores, `Üretimi başlat: {recipe.displayName}`)
					break
				end
			end
		end
		if #chores < 2 and FarmMath.getReadyContractCount(state, now, 0) > 0 then
			table.insert(chores, "Ahır siparişi teslime hazır")
		end
		local fullGoods = FarmMath.getFullGoods(state)
		if #chores < 2 and #fullGoods > 0 then
			table.insert(chores, `Ahır deposu dolmak üzere: {Config.GOODS[fullGoods[1]].displayName}`)
		end
		return chores
	end

	local function updateGoal(state: PlayerSave, income: number)
		updateGoalMain(state, income)
		-- Üst ortadaki görev şeridi ilk adımlarda aynı metni gösterir (metin kaynağı yukarıdaki kart)
		if Onboarding.stepFor(state) ~= 0 then
			goalCard.Visible = false
			banner.show(goalTitle.Text, goalLabel.Text)
		else
			goalCard.Visible = true
			banner.hide()
		end
		-- Yeni oyuncuda hedef kartı tek başına yönlendirir; bekleyen işler deneyimli oyuncuda eklenir
		if Onboarding.stepFor(state) ~= 0 then
			return
		end
		local progress = Progression.progress(state)
		if
			progress.canRebirth
			or (
				state.progression
				and state.progression.count >= Config.PROGRESSION.maxRebirth
				and progress.farmsComplete == progress.farmsTotal
			)
		then
			return
		end
		local chores = pendingChores(state)
		if #chores > 0 then
			goalDetail.Text ..= "\n" .. chores[1]
		end
	end

	return {
		card = goalCard,
		updateGoal = updateGoal,
		updateIsland = updateIslandGoal,
	}
end

return GoalCard
