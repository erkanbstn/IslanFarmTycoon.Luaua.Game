--!strict
-- Rebirth yalnız hazırken açılır; kalıcı etki seçimi ve ayrı onay olmadan sıfırlama gönderilmez.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local GameTypes = require(Shared:WaitForChild("GameTypes"))
local Progression = require(Shared:WaitForChild("Modules"):WaitForChild("Progression"))
local FarmMath = require(Shared:WaitForChild("Modules"):WaitForChild("FarmMath"))
local UiKit = require(script.Parent.Parent:WaitForChild("UiKit"))
local PurchaseController = require(script.Parent.Parent.Parent:WaitForChild("Core"):WaitForChild("PurchaseController"))
local HudCommon = require(script.Parent:WaitForChild("HudCommon"))

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

function RebirthWindow.create(parent: Instance): { window: UiKit.Window, update: (PlayerSave) -> () }
	local window = UiKit.window(parent, {
		title = "Rebirth",
		icon = "🔄",
		tint = UiKit.Color.Gold,
		width = 460,
		maxHeight = 600,
		anchor = Vector2.new(0.5, 0.5),
		position = UDim2.fromScale(0.5, 0.5),
	})
	local overview = UiKit.text(window.list, "", "Heading")
	overview.LayoutOrder = 0
	UiKit.text(window.list, "Kalıcı bir etki seç. Seçmeden yeni tur başlamaz.", "Body").LayoutOrder = 1
	local choiceGrid = UiKit.autoGrid(window.list, 2, 2)
	local choices: { [string]: UiKit.Card } = {}
	local current: PlayerSave? = nil
	local selected: string? = nil
	local viewedRun: number? = nil
	local confirmationRun: number? = nil
	local update: (PlayerSave) -> ()
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
	local selection = UiKit.text(window.list, "Önce bir etki seç.", "Body")
	selection.LayoutOrder = 3
	local lost = UiKit.text(
		window.list,
		"Sıfırlanacak: para, çiftlikler, hayvanlar, yükseltmeler, ırk, nakit eşyalar, tur yardımcıları, ürünler, siparişler ve başarımlar.",
		"Body",
		UiKit.Color.Red
	)
	lost.LayoutOrder = 4
	UiKit.text(
		window.list,
		"Kalacak: altın, altın/Robux ile alınmış kalıcı eşyalar ve kolaylıklar, kalıcı geçitler, rebirth etkileri, günlük giriş serisi ve ayarlar.",
		"Body",
		UiKit.Color.Green
	).LayoutOrder =
		5
	local returnNotice = UiKit.text(window.list, "", "Body")
	returnNotice.LayoutOrder = 6
	local begin = UiKit.button(window.list, "Etki seç ve sıfırla", "disabled")
	begin.Size = UDim2.new(1, 0, 0, UiKit.TouchTarget)
	begin.LayoutOrder = 7
	local confirmBox = Instance.new("Frame")
	confirmBox.BackgroundTransparency = 1
	confirmBox.Size = UDim2.new(1, 0, 0, 0)
	confirmBox.AutomaticSize = Enum.AutomaticSize.Y
	confirmBox.LayoutOrder = 8
	confirmBox.Visible = false
	confirmBox.Parent = window.list
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
		if not Progression.canRebirth(state) then
			confirmationRun = nil
			if window.isOpen() then
				window.close()
			end
			return
		end
		if not window.isOpen() then
			return
		end
		local count = if record then record.count else 0
		UiKit.setText(overview, `Rebirth R{count} · Altı çiftlik tamamlandı`)
		for id, card in choices do
			local level = Progression.getPerkLevel(state, id)
			local maximum = Config.PROGRESSION.perks[id].maxLevel
			local available = Progression.canChoosePerk(state, id)
			UiKit.setText(card.detail, `Seviye {level}/{maximum}`)
			HudCommon.setPurchaseButton(
				card.action,
				if selected == id then "Seçili" elseif available then "Seç" else "En üst seviye",
				if selected == id then "accent" elseif available then "primary" else "owned"
			)
		end
		local canPrestige = Progression.canChoosePerk(state, "prestige")
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
		local canSubmit = selected ~= nil and Progression.canChoosePerk(state, selected)
		confirmBox.Visible = confirmationRun ~= nil
		begin.Visible = confirmationRun == nil
		HudCommon.setPurchaseButton(begin, "Etki seç ve sıfırla", if canSubmit then "primary" else "disabled")
		HudCommon.setPurchaseButton(confirm, "Onayla ve yeni tura başla", if canSubmit then "danger" else "disabled")
	end
	window.frame:GetPropertyChangedSignal("Visible"):Connect(function()
		if not window.isOpen() then
			confirmationRun = nil
		elseif current then
			update(current)
		end
	end)
	return { window = window, update = update }
end

return RebirthWindow
