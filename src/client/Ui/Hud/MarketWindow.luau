--!strict
-- Altın cüzdanı, kalıcı sahiplik ve tek hedefli hızlandırma; önizleme sunucuyla aynı saf hesapları kullanır.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local GameTypes = require(Shared:WaitForChild("GameTypes"))
local FarmMath = require(Shared:WaitForChild("Modules"):WaitForChild("FarmMath"))
local Progression = require(Shared:WaitForChild("Modules"):WaitForChild("Progression"))
local UiKit = require(script.Parent.Parent:WaitForChild("UiKit"))
local PurchaseController = require(script.Parent.Parent.Parent:WaitForChild("Core"):WaitForChild("PurchaseController"))
local HudCommon = require(script.Parent:WaitForChild("HudCommon"))
local StoreSection = require(script.Parent:WaitForChild("StoreSection"))
local RebirthWindow = require(script.Parent:WaitForChild("RebirthWindow"))

type PlayerSave = GameTypes.PlayerSave
type Target = { kind: string, id: string, uid: string, name: string, endsAt: number? }
local MarketWindow = {}

local QUOTE_ERRORS = {
	invalid_amount = "Tam sayı olarak altın miktarı gir.",
	insufficient_gold = "Altın yetmiyor.",
	daily_limit = "Günlük çevirme sınırına ulaştın.",
	run_limit = "Bu turun çevirme sınırına ulaştın.",
	no_income = "Önce gelir üreten bir hayvan al.",
}

function MarketWindow.create(
	parent: Instance
): { window: UiKit.Window, update: (PlayerSave) -> (), open: (string?) -> () }
	local window = UiKit.window(parent, {
		title = "Market",
		icon = "🪙",
		tint = UiKit.Color.Gold,
		width = 600,
		maxHeight = 560,
		anchor = Vector2.new(0.5, 0.5),
		position = UDim2.fromScale(0.5, 0.5),
	})
	local walletRow = Instance.new("Frame")
	walletRow.Name = "GoldWallet"
	walletRow.BackgroundTransparency = 1
	walletRow.Size = UDim2.new(1, 0, 0, UiKit.TouchTarget)
	walletRow.AutomaticSize = Enum.AutomaticSize.Y
	walletRow.LayoutOrder = 0
	walletRow.Parent = window.list
	local walletIcon = UiKit.iconChip(walletRow, "🪙", 36, UiKit.Color.Gold)
	walletIcon.Name = "GoldIcon"
	walletIcon.AnchorPoint = Vector2.new(0, 0.5)
	walletIcon.Position = UDim2.fromScale(0, 0.5)
	local wallet = UiKit.text(walletRow, "", "Heading", UiKit.Color.Green)
	wallet.Position = UDim2.new(0, UiKit.TouchTarget, 0, 0)
	wallet.Size = UDim2.new(1, -UiKit.TouchTarget, 0, UiKit.TouchTarget)
	local pages: { [string]: Frame } = {}
	for _, id in { "featured", "gold", "cash", "permanent", "run", "convert", "finish" } do
		local page = Instance.new("Frame")
		page.BackgroundTransparency = 1
		page.Size = UDim2.new(1, 0, 0, 0)
		page.AutomaticSize = Enum.AutomaticSize.Y
		page.LayoutOrder = 2
		page.Parent = window.list
		UiKit.list(page, 8)
		pages[id] = page
	end
	local selectedPage = "featured"
	local current: PlayerSave? = nil
	local update: (PlayerSave) -> ()
	local _, selectTab = UiKit.tabs(window.list, 1, {
		{ id = "featured", label = "Öne Çıkanlar" },
		{ id = "gold", label = "Altın" },
		{ id = "cash", label = "Para" },
		{ id = "permanent", label = "Kalıcı" },
		{ id = "run", label = "Bu Tur" },
		{ id = "convert", label = "Altın Çevir" },
		{ id = "finish", label = "Hızlı Bitir" },
	}, function(id: string)
		selectedPage = id
		for pageId, page in pages do
			page.Visible = pageId == id
		end
		if current then
			update(current)
		end
	end)
	for id, page in pages do
		page.Visible = id == selectedPage
	end
	UiKit.text(pages.convert, "Altın miktarını seç ve alacağın parayı kontrol et.", "Body").LayoutOrder = 0
	local conversionGuide = UiKit.disclosure(pages.convert, 9, "Altın nasıl çalışır?")
	UiKit.text(
		conversionGuide.body,
		`İlk ücretsiz altın: bir adanın tüm yükseltmelerini tamamla. Ada başına {Config.PROGRESSION.gold.island} altın, tamamlanan çiftlik için ayrıca {Config.PROGRESSION.gold.farm} altın kazanırsın.`,
		"Body"
	).LayoutOrder =
		0
	UiKit.text(
		conversionGuide.body,
		"Altın Hayvan olayı oyun parası verir; altın cüzdanından ayrıdır.",
		"Caption"
	).LayoutOrder =
		1
	UiKit.text(
		conversionGuide.body,
		"Altın rebirth'te kalır. Paraya çevirmek yerine kalıcı eşya için biriktirebilirsin.",
		"Body"
	).LayoutOrder =
		2
	UiKit.text(
		conversionGuide.body,
		"Tutar, en yüksek kalıcı çiftlik gelirinden hesaplanır; geçici 2x ve Geri Dönüş bonusu dahil değildir.",
		"Caption"
	).LayoutOrder =
		3
	local amountInput = UiKit.textInput(pages.convert, "Çevrilecek altın miktarı")
	amountInput.Text = "1"
	amountInput.Size = UDim2.new(1, 0, 0, UiKit.TouchTarget)
	amountInput.LayoutOrder = 3
	local quota = UiKit.text(pages.convert, "", "Caption")
	quota.LayoutOrder = 4
	local convert = UiKit.button(pages.convert, "Paraya çevir", "disabled")
	convert.Size = UDim2.new(1, 0, 0, UiKit.TouchTarget)
	convert.LayoutOrder = 5
	local quoteNote = UiKit.text(pages.convert, "", "Caption")
	quoteNote.LayoutOrder = 6
	local perkSummary = UiKit.text(conversionGuide.body, "", "Caption")
	perkSummary.LayoutOrder = 7
	local returnSummary = UiKit.text(conversionGuide.body, "", "Caption")
	returnSummary.LayoutOrder = 8
	local quotedAmount: number? = nil
	local quotedCash: number? = nil
	convert.Activated:Connect(function()
		if convert.Active and quotedAmount and quotedCash then
			PurchaseController.submitWithRun("RequestGoldAction", "convert", {
				amount = quotedAmount,
				expectedCash = quotedCash,
			})
		end
	end)

	local storeUpdates: { [string]: (PlayerSave) -> () } = {}
	local storeResets: { () -> () } = {}
	for _, category in { "featured", "gold", "cash", "permanent", "run" } do
		local updateStore, resetStore = StoreSection.create(pages[category], category)
		storeUpdates[category] = updateStore
		table.insert(storeResets, resetStore)
	end

	UiKit.text(
		pages.finish,
		"Hayvan büyümesini veya eklenti görevini altınla tamamla. Üretim tesislerinde kullanılamaz.",
		"Body"
	).LayoutOrder =
		0
	local finishCard = UiKit.card(pages.finish, 1, "⚡")
	local selector = Instance.new("Frame")
	selector.BackgroundTransparency = 1
	selector.Size = UDim2.new(1, 0, 0, UiKit.TouchTarget)
	selector.LayoutOrder = 2
	selector.Parent = pages.finish
	local previous = UiKit.button(selector, "Önceki", "secondary")
	previous.Size = UDim2.new(0.48, 0, 1, 0)
	local nextButton = UiKit.button(selector, "Sonraki", "secondary")
	nextButton.Position = UDim2.fromScale(0.52, 0)
	nextButton.Size = UDim2.new(0.48, 0, 1, 0)
	local targets: { Target } = {}
	local targetIndex = 1
	local selectedKey: string? = nil
	local quotedFinishCost: number? = nil
	local function selectTarget(offset: number)
		if #targets > 0 then
			targetIndex = (targetIndex - 1 + offset) % #targets + 1
			local target = targets[targetIndex]
			selectedKey = `{target.kind}:{target.id}`
		end
		if current then
			update(current)
		end
	end
	previous.Activated:Connect(function()
		selectTarget(-1)
	end)
	nextButton.Activated:Connect(function()
		selectTarget(1)
	end)
	finishCard.action.Activated:Connect(function()
		local target = targets[targetIndex]
		if finishCard.action.Active and target and quotedFinishCost then
			PurchaseController.submitWithRun("RequestGoldAction", "finish", {
				targetKind = target.kind,
				targetId = target.id,
				uid = target.uid,
				expectedCost = quotedFinishCost,
				expectedEndsAt = target.endsAt or 0,
			})
		end
	end)

	update = function(state: PlayerSave)
		current = state
		if not window.isOpen() then
			return
		end
		local now = Workspace:GetServerTimeNow()
		UiKit.setText(wallet, `Altın: {state.gold or 0} · Rebirth'te kalır`)
		if selectedPage == "convert" then
			local record = state.progression
			local perks = {}
			for _, id in Config.PROGRESSION.perkOrder do
				local level = Progression.getPerkLevel(state, id)
				if level > 0 then
					table.insert(perks, `{RebirthWindow.perkNames[id]} Sv.{level}`)
				end
			end
			UiKit.setText(
				perkSummary,
				if #perks > 0
					then `Kalıcı etkiler: {table.concat(perks, ", ")}`
					else "Henüz rebirth etkisi yok. Altı çiftliği tamamlayınca kalıcı bir etki seçebilirsin."
			)
			returnSummary.Visible = record ~= nil and record.count > 0
			UiKit.setText(
				returnSummary,
				if record and Progression.isReturnActive(state, now)
					then `Geri Dönüş: {math.ceil(math.max(0, record.returnEndsAt - now) / 60)} dk kaldı. Gerçek zaman; çıkışta durmaz.`
					else "Geri Dönüş bonusu sona erdi. Bir sonraki rebirth'te yenilenir."
			)
			local usedToday = if record and record.convertedDay == math.floor(now / 86400)
				then record.convertedDayGold
				else 0
			local usedRun = if record then record.convertedRunGold else 0
			UiKit.setText(
				quota,
				`Kalan çevirme hakkı: bugün {math.max(0, Config.PROGRESSION.gold.dailyLimit - usedToday)}, bu tur {math.max(
					0,
					Config.PROGRESSION.gold.runLimit - usedRun
				)} altın`
			)
			local amount = tonumber(amountInput.Text)
			local cash, code = Progression.goldCashQuote(state, amount or 0, now)
			quotedAmount, quotedCash = amount, cash
			HudCommon.setPurchaseButton(
				convert,
				if cash and amount then `{amount} altın → {FarmMath.formatMoney(cash)}` else "Paraya çevir",
				if cash then "primary" else "disabled"
			)
			UiKit.setText(quoteNote, if cash then "" else QUOTE_ERRORS[code or ""] or "Altın miktarını kontrol et.")
		else
			quotedAmount, quotedCash = nil, nil
		end
		local updateStore = storeUpdates[selectedPage]
		if updateStore then
			updateStore(state)
		end

		if selectedPage ~= "finish" then
			return
		end
		targets = {}
		for _, animal in state.animals do
			local name = Config.getAnimalLook(animal.animalId, state.activeMainFarmId).displayName
			if Progression.finishGoldQuote(state, "growth", animal.uid, now) then
				table.insert(targets, { kind = "growth", id = animal.uid, uid = animal.uid, name = `Büyüme: {name}` })
			end
			if Progression.finishGoldQuote(state, "extension", animal.uid, now) then
				table.insert(targets, {
					kind = "extension",
					id = animal.uid,
					uid = animal.uid,
					name = `Eklenti: {name}`,
					endsAt = if animal.task then animal.task.endsAt else nil,
				})
			end
		end
		table.sort(targets, function(a: Target, b: Target): boolean
			return `{a.kind}:{a.id}` < `{b.kind}:{b.id}`
		end)
		targetIndex = 1
		for index, target in targets do
			if `{target.kind}:{target.id}` == selectedKey then
				targetIndex = index
				break
			end
		end
		local target = targets[targetIndex]
		selector.Visible = #targets > 1
		if target then
			selectedKey = `{target.kind}:{target.id}`
			local cost = Progression.finishGoldQuote(state, target.kind, target.id, now)
			quotedFinishCost = cost
			UiKit.setText(finishCard.title, target.name)
			UiKit.setText(
				finishCard.detail,
				`{targetIndex}/{#targets} bekleyiş · Seçilen hayvanın bekleyişi tamamlanır.`
			)
			HudCommon.setPurchaseButton(
				finishCard.action,
				`Hemen bitir · {cost or 0} altın`,
				if cost and (state.gold or 0) >= cost then "primary" else "warning"
			)
		else
			selectedKey = nil
			quotedFinishCost = nil
			UiKit.setText(finishCard.title, "Bitirilecek bekleyiş yok")
			UiKit.setText(
				finishCard.detail,
				"Hayvan büyümesi veya eklenti görevi başladığında burada görünür."
			)
			HudCommon.setPurchaseButton(finishCard.action, "Bekleyiş yok", "disabled")
		end
	end
	amountInput:GetPropertyChangedSignal("Text"):Connect(function()
		if current then
			update(current)
		end
	end)
	window.frame:GetPropertyChangedSignal("Visible"):Connect(function()
		if not window.isOpen() then
			conversionGuide.setExpanded(false)
			for _, resetStore in storeResets do
				resetStore()
			end
		end
	end)
	return {
		window = window,
		update = update,
		open = function(pageId: string?)
			local id = pageId or "featured"
			if pages[id] then
				selectedPage = id
				selectTab(id)
				for key, page in pages do
					page.Visible = key == id
				end
			end
			UiKit.showWindow(window)
			if current then
				update(current)
			end
		end,
	}
end

return MarketWindow
