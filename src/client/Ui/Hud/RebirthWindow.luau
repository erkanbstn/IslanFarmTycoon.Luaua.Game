--!strict
-- Rebirth yolculuğu her zaman incelenir; sıfırlama yalnız hazırken iki ayrı onayla gönderilir.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local GameTypes = require(Shared:WaitForChild("GameTypes"))
local Progression = require(Shared:WaitForChild("Modules"):WaitForChild("Progression"))
local FarmMath = require(Shared:WaitForChild("Modules"):WaitForChild("FarmMath"))
local UiKit = require(script.Parent.Parent:WaitForChild("UiKit"))
local PurchaseController = require(script.Parent.Parent.Parent:WaitForChild("Core"):WaitForChild("PurchaseController"))
local HudCommon = require(script.Parent:WaitForChild("HudCommon"))
local EffectsSection = require(script.Parent:WaitForChild("EffectsSection"))

type PlayerSave = GameTypes.PlayerSave
local RebirthWindow = {}
local PERK_NAMES: { [string]: string } = {
	income = "Kalıcı Gelir",
	growth = "Hızlı Büyüme",
	starting_cash = "Başlangıç Kasası",
	upgrade_discount = "Açılış İndirimi",
	facility_speed = "Tesis Hızı",
	offline = "Çevrimdışı Kazanç",
	contract = "Sipariş Ödülü",
	ready_start = "Hazır Başlangıç",
	prestige = "Prestij",
}
RebirthWindow.perkNames = PERK_NAMES

local function describe(id: string, nextLevel: number): string
	local effects = Config.PROGRESSION.perks[id].effects
	if id == "income" then
		return `Kalıcı gelir etkisi toplam +%{math.round(nextLevel * (effects.incomeBonus or 0) * 100)}; eşya ile toplam sınıra tabidir.`
	elseif id == "growth" then
		return `Kalıcı büyüme hızı toplam +%{math.round(nextLevel * (effects.growthExcess or 0) * 100)}.`
	elseif id == "starting_cash" then
		return `Yeni turun başlangıç kasasına {nextLevel * (effects.startingAnimals or 0)} ana hayvan bedeli eklenir.`
	elseif id == "upgrade_discount" then
		return `Kalıcı açılış indirimi toplam %{math.round(nextLevel * (effects.upgradeDiscount or 0) * 100)}.`
	elseif id == "facility_speed" then
		return `Kalıcı tesis hızı toplam +%{math.round(nextLevel * (effects.facilitySpeed or 0) * 100)}.`
	elseif id == "offline" then
		return `Çevrimdışı kazanç toplam +%{math.round(nextLevel * (effects.offlineBonus or 0) * 100)}, süre +{nextLevel * (effects.offlineHours or 0)} saat; toplam sınıra tabidir.`
	elseif id == "contract" then
		return `Kalıcı sipariş ödülü toplam +%{math.round(nextLevel * (effects.contractBonus or 0) * 100)}.`
	end
	return if nextLevel == 1
		then "Yeni turlarda otomatik toplama açık başlar."
		elseif nextLevel == 2 then "Yeni turlarda bir yetişkin hayvanla başlarsın."
		elseif nextLevel == 3 then "Yeni turlarda ilk küçük ada açık başlar."
		else "Yeni turlarda bir yetişkin hayvan daha eklenir."
end

-- Rebirth altınıyla (mevcut + ödül) alınabilen, sahip olunmayan kalıcı teklifler; en ucuz önce.
-- Hiçbiri alınamıyorsa `affordable` boş, `nearest` en ucuz sahip olunmayan teklif olur.
function RebirthWindow.affordableOffers(state: PlayerSave, budget: number): { affordable: { any }, nearest: any? }
	local owned = if state.owned then state.owned.items else nil
	local unowned = {}
	for _, offer in Config.PROGRESSION.permanentOffers do
		local itemId = offer.itemId
		local item = if itemId then Config.ITEMS[itemId] else nil
		if itemId and item and offer.goldCost and not (owned and owned[itemId] == true) then
			table.insert(unowned, { itemId = itemId, name = item.displayName, goldCost = offer.goldCost })
		end
	end
	table.sort(unowned, function(a: any, b: any): boolean
		if a.goldCost ~= b.goldCost then
			return a.goldCost < b.goldCost
		end
		return a.itemId < b.itemId
	end)
	local affordable = {}
	for _, entry in unowned do
		if entry.goldCost <= budget and #affordable < 3 then
			table.insert(affordable, entry)
		end
	end
	return { affordable = affordable, nearest = if #affordable == 0 then unowned[1] else nil }
end

function RebirthWindow.create(parent: Instance): { window: UiKit.Window, update: (PlayerSave) -> () }
	local window = UiKit.window(parent, {
		title = "İlerleme",
		icon = "🔄",
		tint = UiKit.Color.Gold,
		width = 600,
		maxHeight = 600,
		anchor = Vector2.new(0.5, 0.5),
		position = UDim2.fromScale(0.5, 0.5),
	})
	local current: PlayerSave? = nil
	local selected: string? = nil
	local viewedRun: number? = nil
	local confirmationRun: number? = nil
	local update: (PlayerSave) -> () = function(_state: PlayerSave) end
	local effectsPage = Instance.new("Frame")
	effectsPage.Name = "CurrentEffects"
	effectsPage.BackgroundTransparency = 1
	effectsPage.Size = UDim2.new(1, 0, 0, 0)
	effectsPage.AutomaticSize = Enum.AutomaticSize.Y
	effectsPage.LayoutOrder = 1
	effectsPage.Parent = window.list
	UiKit.list(effectsPage, 8)
	local effects = EffectsSection.create(effectsPage)
	local rebirthPage = Instance.new("Frame")
	rebirthPage.Name = "RebirthContent"
	rebirthPage.BackgroundTransparency = 1
	rebirthPage.Size = UDim2.new(1, 0, 0, 0)
	rebirthPage.AutomaticSize = Enum.AutomaticSize.Y
	rebirthPage.LayoutOrder = 1
	rebirthPage.Visible = false
	rebirthPage.Parent = window.list
	UiKit.list(rebirthPage, 8)
	UiKit.tabs(window.list, 0, {
		{ id = "effects", label = "Etkiler" },
		{ id = "rebirth", label = "Rebirth" },
	}, function(id: string)
		effectsPage.Visible = id == "effects"
		rebirthPage.Visible = id == "rebirth"
		confirmationRun = nil
		if current then
			update(current)
		end
	end)
	local overview = UiKit.text(rebirthPage, "", "Heading")
	overview.Name = "RebirthOverview"
	overview.LayoutOrder = 0
	local target = UiKit.text(rebirthPage, "", "Body")
	target.Name = "RebirthRequirements"
	target.LayoutOrder = 1
	local milestone = UiKit.text(rebirthPage, "", "Body", UiKit.Color.Green)
	milestone.Name = "NextMilestone"
	milestone.LayoutOrder = 2
	local gains = Instance.new("Frame")
	gains.Name = "RebirthGains"
	gains.BackgroundTransparency = 1
	gains.Size = UDim2.new(1, 0, 0, 0)
	gains.AutomaticSize = Enum.AutomaticSize.Y
	gains.LayoutOrder = 3
	gains.Parent = rebirthPage
	UiKit.list(gains, 4)
	local gainsHeading = UiKit.text(gains, "Bu rebirth'te kazanacakların", "Heading", UiKit.Color.Gold)
	gainsHeading.Name = "RebirthGainsHeading"
	gainsHeading.LayoutOrder = 0
	local goldReward = UiKit.text(gains, "", "Body", UiKit.Color.Gold)
	goldReward.Name = "RebirthGoldReward"
	goldReward.LayoutOrder = 1
	local affordableText = UiKit.text(gains, "", "Body")
	affordableText.Name = "RebirthAffordable"
	affordableText.LayoutOrder = 2
	local nextReward = UiKit.text(gains, "", "Body", UiKit.Color.Green)
	nextReward.Name = "RebirthNextReward"
	nextReward.LayoutOrder = 3
	local perkLine = UiKit.text(gains, "", "Body")
	perkLine.Name = "RebirthPerkLine"
	perkLine.LayoutOrder = 4
	local choicePage = Instance.new("Frame")
	choicePage.Name = "PerkChoices"
	choicePage.BackgroundTransparency = 1
	choicePage.Size = UDim2.new(1, 0, 0, 0)
	choicePage.AutomaticSize = Enum.AutomaticSize.Y
	choicePage.LayoutOrder = 5
	choicePage.Parent = rebirthPage
	UiKit.list(choicePage, 8)
	local journeyPage = Instance.new("Frame")
	journeyPage.Name = "RebirthJourney"
	journeyPage.BackgroundTransparency = 1
	journeyPage.Size = UDim2.new(1, 0, 0, 0)
	journeyPage.AutomaticSize = Enum.AutomaticSize.Y
	journeyPage.LayoutOrder = 5
	journeyPage.Visible = false
	journeyPage.Parent = rebirthPage
	UiKit.list(journeyPage, 8)
	UiKit.tabs(rebirthPage, 4, {
		{ id = "choice", label = "Etki Seç" },
		{ id = "journey", label = "30 Rebirth Yolculuğu" },
	}, function(id: string)
		choicePage.Visible = id == "choice"
		journeyPage.Visible = id == "journey"
	end)
	local journeyRows: { [number]: { title: TextLabel, detail: TextLabel } } = {}
	for level = 1, Config.PROGRESSION.maxRebirth do
		local title = UiKit.text(journeyPage, "", "Heading")
		title.Name = `MilestoneTitleR{level}`
		title.LayoutOrder = level * 2
		local detail = UiKit.text(journeyPage, "", "Caption")
		detail.LayoutOrder = level * 2 + 1
		journeyRows[level] = { title = title, detail = detail }
	end
	local choiceNote = UiKit.text(choicePage, "Kalıcı bir etki seç. Seçmeden yeni tur başlamaz.", "Body")
	choiceNote.LayoutOrder = 1
	local choiceGrid = UiKit.autoGrid(choicePage, 2, 2)
	local choices: { [string]: UiKit.Card } = {}
	for index, id in Config.PROGRESSION.perkOrder do
		local card = UiKit.autoTile(choiceGrid, index, "⭐", { compact = true })
		UiKit.setText(card.title, PERK_NAMES[id])
		choices[id] = card
		card.action.Activated:Connect(function()
			if card.action.Active then
				selected = id
				confirmationRun = nil
				if current then
					update(current)
				end
			end
		end)
	end
	local prestige = UiKit.autoTile(choiceGrid, #Config.PROGRESSION.perkOrder + 1, "🏆", { compact = true })
	UiKit.setText(prestige.title, "Prestij")
	UiKit.setText(prestige.detail, "Tüm etkiler tamamlandı. Rebirth rozeti ilerler; yeni bir gelir etkisi eklenmez.")
	prestige.frame.Visible = false
	prestige.action.Activated:Connect(function()
		if prestige.action.Active and current then
			selected = "prestige"
			confirmationRun = nil
			update(current)
		end
	end)
	local selection = UiKit.text(choicePage, "Önce bir etki seç.", "Body")
	selection.Name = "SelectedPerk"
	selection.LayoutOrder = 3
	local lost = UiKit.text(
		choicePage,
		"Sıfırlanacak: para, çiftlikler, hayvanlar, yükseltmeler, ırk, nakit eşyalar, tur yardımcıları, ürünler, siparişler ve başarımlar.",
		"Body",
		UiKit.Color.Red
	)
	lost.LayoutOrder = 4
	local kept = UiKit.text(
		choicePage,
		"Kalacak: altın, kalıcı ve rebirth ödülü eşyalar, kolaylıklar, kalıcı geçitler, rebirth etkileri, günlük giriş serisi ve ayarlar.",
		"Body",
		UiKit.Color.Green
	)
	kept.LayoutOrder = 5
	local returnNotice = UiKit.text(choicePage, "", "Body")
	returnNotice.LayoutOrder = 6
	local begin = UiKit.button(choicePage, "Etki seç ve sıfırla", "disabled")
	begin.Size = UDim2.new(1, 0, 0, UiKit.TouchTarget)
	begin.LayoutOrder = 7
	local confirmBox = Instance.new("Frame")
	confirmBox.BackgroundTransparency = 1
	confirmBox.Size = UDim2.new(1, 0, 0, 0)
	confirmBox.AutomaticSize = Enum.AutomaticSize.Y
	confirmBox.LayoutOrder = 8
	confirmBox.Visible = false
	confirmBox.Parent = choicePage
	UiKit.list(confirmBox, 8)
	UiKit.text(
		confirmBox,
		"Bu sıfırlama geri alınamaz. Seçtiğin etkiyle yeni tura başlamak istediğine emin misin?",
		"Body",
		UiKit.Color.Red
	).LayoutOrder =
		0
	local confirm = UiKit.button(confirmBox, "Onayla ve yeni tura başla", "danger")
	confirm.Size = UDim2.new(1, 0, 0, UiKit.TouchTarget)
	confirm.LayoutOrder = 1
	local cancel = UiKit.button(confirmBox, "Vazgeç", "secondary")
	cancel.Size = UDim2.new(1, 0, 0, UiKit.TouchTarget)
	cancel.LayoutOrder = 2
	begin.Activated:Connect(function()
		local state = current
		if state and state.progression and selected and begin.Active then
			confirmationRun = state.progression.run
			update(state)
		end
	end)
	cancel.Activated:Connect(function()
		confirmationRun = nil
		if current then
			update(current)
		end
	end)
	confirm.Activated:Connect(function()
		local state = current
		if
			state
			and state.progression
			and selected
			and confirm.Active
			and confirmationRun == state.progression.run
			and Progression.canRebirth(state)
			and Progression.canChoosePerk(state, selected)
		then
			PurchaseController.submitWithRun("RequestRebirth", selected)
			confirmationRun = nil
			update(state)
		end
	end)
	update = function(state: PlayerSave)
		current = state
		local record = state.progression
		if viewedRun ~= (if record then record.run else nil) then
			selected, confirmationRun = nil, nil
			viewedRun = if record then record.run else nil
		end
		local ready = Progression.canRebirth(state)
		if not ready then
			confirmationRun = nil
		end
		if not window.isOpen() then
			return
		end
		if effectsPage.Visible then
			effects.update(state)
		end
		local count = if record then record.count else 0
		local maximumRebirth = Config.PROGRESSION.maxRebirth
		local summary = Progression.progress(state)
		local complete = count >= maximumRebirth
		UiKit.setText(
			overview,
			`Rebirth R{count}/{maximumRebirth} · {summary.farmsComplete}/{summary.farmsTotal} çiftlik hazır`
		)
		local requirements = summary.requirements or Progression.getCompletionRequirements(state)
		UiKit.setText(
			target,
			if complete
				then "R30 yolculuğu tamamlandı. Mevcut çiftliklerini geliştirmeye devam edebilirsin; yeni sıfırlama yok."
				else requirements.description
		)
		local nextMilestone = if not complete then Progression.getMilestone(count + 1) else nil
		local currentMilestone = Progression.getMilestone(count)
		UiKit.setText(
			milestone,
			if currentMilestone
				then `Son kazanım: {currentMilestone.displayName}\n{currentMilestone.description}`
				else ""
		)
		milestone.Visible = currentMilestone ~= nil
		gains.Visible = not complete
		if not complete then
			local reward = Progression.rebirthGoldReward(state)
			UiKit.setText(goldReward, `Altın ödülü: +{reward} altın`)
			local offers = RebirthWindow.affordableOffers(state, (state.gold or 0) + reward)
			local lines = {}
			if #offers.affordable > 0 then
				table.insert(lines, "Bu altınla alabileceğin kalıcı eşyalar:")
				for _, entry in offers.affordable do
					table.insert(lines, `{entry.name} · {entry.goldCost} altın`)
				end
			elseif offers.nearest then
				local missing = offers.nearest.goldCost - ((state.gold or 0) + reward)
				table.insert(
					lines,
					`En yakın kalıcı eşya: {offers.nearest.name} ({offers.nearest.goldCost} altın, {missing} altın eksik)`
				)
			else
				table.insert(lines, "Alınabilecek yeni kalıcı eşya kalmadı.")
			end
			UiKit.setText(affordableText, table.concat(lines, "\n"))
			if nextMilestone then
				local text = `Sonraki ödül R{count + 1}: {nextMilestone.displayName}\n{nextMilestone.description}`
				if nextMilestone.itemId and Config.ITEMS[nextMilestone.itemId] then
					text ..= `\nKalıcı eşya: {Config.ITEMS[nextMilestone.itemId].displayName}`
				end
				UiKit.setText(nextReward, text)
			end
			nextReward.Visible = nextMilestone ~= nil
			perkLine.Visible = selected ~= nil
			if selected then
				local perkName = PERK_NAMES[selected] or "Prestij"
				UiKit.setText(perkLine, `Seçtiğin etki: {perkName}`)
			end
		end
		choiceGrid.Visible = not complete
		-- Son seviyede seçilecek etki kalmaz: sekme boş görünmesin diye tek satır açıklama gösterilir
		UiKit.setText(
			choiceNote,
			if complete
				then "Tüm rebirth seviyelerini tamamladın; seçilecek yeni etki kalmadı."
				else "Kalıcı bir etki seç. Seçmeden yeni tur başlamaz."
		)
		choiceNote.Visible = true
		selection.Visible = not complete
		lost.Visible = not complete and confirmationRun ~= nil
		kept.Visible = not complete and confirmationRun ~= nil
		returnNotice.Visible = not complete and confirmationRun ~= nil
		for level, row in journeyRows do
			local reward = Progression.getMilestone(level)
			if reward then
				local status = if level <= count
					then "Açıldı"
					elseif level == count + 1 then "Sıradaki"
					else "Kilitli"
				UiKit.setText(row.title, `R{level} · {reward.displayName} · {status}`)
				row.title.TextColor3 = if level <= count
					then UiKit.Color.Green
					elseif level == count + 1 then UiKit.Color.Gold
					else UiKit.Color.TextMuted
				UiKit.setText(row.detail, reward.description)
			end
		end
		for id, card in choices do
			local level = Progression.getPerkLevel(state, id)
			local maximum = Config.PROGRESSION.perks[id].maxLevel
			local available = not complete and Progression.canChoosePerk(state, id)
			UiKit.setText(card.detail, `Seviye {level}/{maximum}`)
			HudCommon.setPurchaseButton(
				card.action,
				if selected == id then "Seçili" elseif available then "Seç" else "En üst seviye",
				if selected == id then "accent" elseif available then "primary" else "owned"
			)
		end
		local canPrestige = not complete and Progression.canChoosePerk(state, "prestige")
		prestige.frame.Visible = canPrestige
		HudCommon.setPurchaseButton(
			prestige.action,
			if selected == "prestige" then "Seçili" else "Seç",
			if canPrestige then "primary" else "disabled"
		)
		if selected then
			local description = if selected == "prestige"
				then ""
				else describe(selected, Progression.getPerkLevel(state, selected) + 1)
			if selected == "income" then
				local itemMultiplier = 1 + FarmMath.getEquippedBonus(state, "incomeBonus")
				local before = Progression.getIncomeMultiplier(state, itemMultiplier)
				local after = math.min(
					Config.PROGRESSION.permanentIncomeCap,
					itemMultiplier
						* (
							1
							+ (Progression.getPerkLevel(state, "income") + 1)
								* (Config.PROGRESSION.perks.income.effects.incomeBonus or 0)
						)
				)
				local gain = math.round((after / before - 1) * 1000) / 10
				description =
					`{description}\nŞu an takılı eşyalarla ek gelir: +%{gain}. Kalıcı gelir çarpanı {before}x → {after}x.`
			end
			UiKit.setText(
				selection,
				if selected == "prestige"
					then "Prestij · Rebirth rozeti ilerler; mevcut kalıcı etkilerin korunur."
					else `{PERK_NAMES[selected]} · {description}`
			)
		else
			UiKit.setText(selection, "Önce bir etki seç.")
		end
		UiKit.setText(
			lost,
			if record and record.runDouble
				then "Sıfırlanacak: para, çiftlikler, hayvanlar, yükseltmeler, ırk, nakit eşyalar, tur yardımcıları, ürünler, siparişler ve başarımlar. Bu turun 2x geliri de sona erecek."
				else "Sıfırlanacak: para, çiftlikler, hayvanlar, yükseltmeler, ırk, nakit eşyalar, tur yardımcıları, ürünler, siparişler ve başarımlar."
		)
		UiKit.setText(
			returnNotice,
			`Geri Dönüş bonusu {Config.PROGRESSION.returnSeconds / 3600} saat gerçek zaman sürer; çıkışta durmaz. Yalnız ilk çiftliğin ana hayvanını etkiler ve ikinci çiftlikte sona erer.`
		)
		local canSubmit = ready and not complete and selected ~= nil and Progression.canChoosePerk(state, selected)
		confirmBox.Visible = confirmationRun ~= nil
		begin.Visible = not complete and confirmationRun == nil
		HudCommon.setPurchaseButton(
			begin,
			if ready then "Etki seç ve sıfırla" else "Çiftlik hedeflerini tamamla",
			if canSubmit then "primary" else "disabled"
		)
		HudCommon.setPurchaseButton(confirm, "Onayla ve yeni tura başla", if canSubmit then "danger" else "disabled")
	end
	window.frame:GetPropertyChangedSignal("Visible"):Connect(function()
		if not window.isOpen() then
			confirmationRun = nil
			effects.reset()
		elseif current then
			update(current)
		end
	end)
	return { window = window, update = update }
end

return RebirthWindow
