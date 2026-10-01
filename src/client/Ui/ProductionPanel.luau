--!strict
-- Sayaçlar gösterim içindir; ödeme, üretim ve teslim sunucuda doğrulanır.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local Workspace = game:GetService("Workspace")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local FarmMath = require(Shared:WaitForChild("Modules"):WaitForChild("FarmMath"))
local ClientState = require(script.Parent.Parent:WaitForChild("Core"):WaitForChild("ClientState"))
local PurchaseController = require(script.Parent.Parent:WaitForChild("Core"):WaitForChild("PurchaseController"))
local UiKit = require(script.Parent:WaitForChild("UiKit"))
local IslandContext = require(script.Parent.Parent:WaitForChild("Core"):WaitForChild("IslandContext"))
local IslandManager = require(script.Parent:WaitForChild("IslandManager"))
local IslandTabs = require(script.Parent:WaitForChild("Hud"):WaitForChild("IslandTabs"))
local player = Players.LocalPlayer
local ProductionPanel = {}
local window: UiKit.Window? = nil
local screen: Instance? = nil
local render: (() -> ())? = nil
local sequence = 0
local pending: number? = nil
local nextSendAt = 0
local message = ""
local success = true
local focused: string? = nil
-- Bir binanın "Üretim" promptundan açıldıysa yalnızca o binanın tarifleri gösterilir (menüden açılınca hepsi)
local focusedUpgrade: string? = nil

local function refresh()
	if render then
		render()
	end
end

-- detail: "start" için para tesisinin parti kimliği, "sell"/"keep" için işin uid'i
local function submit(action: string, recipeId: string, detail: string?)
	if pending or os.clock() < nextSendAt or PurchaseController.isPending() then
		return
	end
	sequence += 1
	local requestId = sequence
	pending = requestId
	nextSendAt = os.clock() + 0.6
	message = "İşlem doğrulanıyor."
	success = true
	refresh()
	local state = ClientState.get()
	Remotes.get("RequestProductionAction")
		:FireServer(action, recipeId, detail, requestId, if state then state.activeMainFarmId else nil)
	task.delay(0.6, refresh)
	task.delay(10, function()
		if pending == requestId then
			pending = nil
			message = "Yanıt gecikti. İşlem tekrarlanmadı; üretim durumu yenileniyor."
			success = false
			ClientState.requestSnapshot()
			refresh()
		end
	end)
end

Remotes.get("ProductionResult").OnClientEvent:Connect(function(id: number, ok: boolean, result: string?)
	if id ~= pending then
		return
	end
	pending = nil
	message = result or (if ok then "İşlem tamamlandı." else "İşlem uygulanamadı.")
	success = ok
	refresh()
end)

local function create(parent: Instance): UiKit.Window
	local created = UiKit.window(parent, {
		title = "Üretim",
		icon = "🏭",
		tint = UiKit.Color.Green,
		width = 350,
		maxHeight = 450,
		anchor = Vector2.new(0.5, 0.5),
		position = UDim2.fromScale(0.5, 0.5),
	})
	UiKit.text(
		created.list,
		"Tesise yetişkin hayvanlarını ver: iş boyunca gelir getirmezler, bitince ödülle birlikte geri dönerler. Süre çıkışta da ilerler; teslim etmeden yeni parti başlamaz.",
		"Caption"
	).LayoutOrder =
		0
	local selectedLabel = UiKit.text(created.list, "", "Heading")
	selectedLabel.LayoutOrder = 1
	local showAll = UiKit.button(created.list, "Adadaki tüm tesisleri göster", "secondary")
	showAll.Size = UDim2.new(1, 0, 0, 34)
	showAll.LayoutOrder = 19
	showAll.Visible = false
	showAll.Activated:Connect(function()
		focusedUpgrade = nil
		focused = nil
		refresh()
	end)
	local changeIsland = UiKit.button(created.list, "Adalarımı yönet", "primary")
	changeIsland.Size = UDim2.new(1, 0, 0, 36)
	changeIsland.LayoutOrder = 20
	changeIsland.Activated:Connect(IslandManager.open)
	local feedback = UiKit.text(created.list, "", "Caption")
	feedback.LayoutOrder = 1
	-- Ada sekmeleri (diğer pencerelerle aynı): adaya gitmeden her adanın tesislerine geçilir
	IslandTabs.add(created)
	type Entry = {
		card: UiKit.Card,
		keep: TextButton,
		progress: Frame,
		fill: (number, Color3) -> (),
		options: { TextButton },
		repeatToggle: TextButton,
	}
	local entries: { [string]: Entry } = {}
	for index, id in Config.PRODUCTION_ORDER do
		local recipe = Config.PRODUCTION_RECIPES[id]
		local card = UiKit.card(created.list, index + 2, recipe.icon)
		card.title.Text = recipe.displayName
		local progress, fill = UiKit.progressBar(card.frame, 5)
		progress.LayoutOrder = 3
		local keep = UiKit.button(card.frame, "Civcivi kümese ekle", "primary")
		keep.Size = UDim2.new(1, 0, 0, 36)
		keep.LayoutOrder = 4
		keep.Visible = false
		-- Para tesisi: her parti seçeneği için bir başlatma butonu (ücretsiz; ne kadar hayvan isterse o kadar kazandırır)
		local optionButtons: { TextButton } = {}
		local recipeOptions: { Config.ProductionOptionConfig } = recipe.options or {}
		for optionIndex, option in recipeOptions do
			local button = UiKit.button(card.frame, option.displayName, "primary")
			button.Size = UDim2.new(1, 0, 0, 36)
			button.LayoutOrder = 5 + optionIndex
			button.Visible = false
			table.insert(optionButtons, button)
			button.Activated:Connect(function()
				local state = ClientState.get()
				if state and button.Active and state.purchased[recipe.upgradeId] and not state.production[id] then
					submit("start", id, option.id)
				end
			end)
		end
		-- Yardımcı (pet) varsa "otomatik tekrar": hazır partiyi yardımcı teslim alır ve aynı seçenekle yenisini başlatır
		local repeatToggle = UiKit.button(card.frame, "Otomatik tekrar", "secondary")
		repeatToggle.Size = UDim2.new(1, 0, 0, 32)
		repeatToggle.LayoutOrder = 5
		repeatToggle.Visible = false
		repeatToggle.Activated:Connect(function()
			local state = ClientState.get()
			if not state or not repeatToggle.Active then
				return
			end
			local on = state.autoRepeat ~= nil and state.autoRepeat[id] ~= nil
			local job = state.production and state.production[id]
			local choice: string? = nil
			if recipe.options then
				choice = if job and job.optionId then job.optionId else recipe.options[1].id
			end
			submit("auto", id, if on then "off" else choice)
		end)
		entries[id] = {
			card = card,
			keep = keep,
			progress = progress,
			fill = fill,
			options = optionButtons,
			repeatToggle = repeatToggle,
		}
		card.action.Activated:Connect(function()
			local state = ClientState.get()
			if not state or not card.action.Active then
				return
			end
			if not state.purchased[recipe.upgradeId] then
				PurchaseController.submit("RequestBuyUpgrade", recipe.upgradeId)
				return
			end
			local job = state.production and state.production[id]
			submit(if job then "sell" else "start", id, if job then job.uid else nil)
		end)
		keep.Activated:Connect(function()
			local state = ClientState.get()
			local job = state and state.production and state.production[id]
			if job and keep.Active then
				submit("keep", id, job.uid)
			end
		end)
	end
	-- Tarifin hayvan türünden, şu an başka bir görevde (eklenti ya da başka üretim) olan yetişkin sayısı: "boşta" sayımına girmez
	local function busyAnimals(state: any, recipe: Config.ProductionRecipeConfig, now: number): number
		local count = 0
		for _, animal in state.animals do
			local task = FarmMath.getActiveTask(animal, now)
			if
				task
				and table.find(recipe.animalIds, animal.animalId)
				and not (task.kind == "production" and task.id == recipe.id)
			then
				count += 1
			end
		end
		return count
	end
	render = function()
		if not created.isOpen() then
			return
		end
		local state = ClientState.get()
		if not state then
			return
		end
		feedback.Text = message
		local focusedBuilding = if focusedUpgrade then Config.getUpgrade(focusedUpgrade) else nil
		selectedLabel.Text = if focusedBuilding
			then `{focusedBuilding.displayName} · {IslandContext.name()}`
			else IslandContext.name()
		showAll.Visible = focusedBuilding ~= nil
		feedback.Visible = message ~= ""
		feedback.TextColor3 = if success then UiKit.Color.Green else UiKit.Color.Red
		local now = Workspace:GetServerTimeNow()
		local blocked = pending ~= nil
			or PurchaseController.isPending()
			or os.clock() < nextSendAt
			or player:GetAttribute("DataStatus") ~= "Active"
		for index, id in Config.PRODUCTION_ORDER do
			local recipe = Config.PRODUCTION_RECIPES[id]
			local entry = entries[id]
			local card = entry.card
			card.frame.Visible = recipe.island == IslandContext.get()
				and (focusedUpgrade == nil or recipe.upgradeId == focusedUpgrade)
			card.frame.LayoutOrder = if focused == id then 2 else index + 3
			entry.keep.Visible = false
			entry.progress.Visible = false
			card.action.Visible = true
			for _, button in entry.options do
				button.Visible = false
			end
			-- Otomatik tekrar düğmesi: yalnızca kurulu para fabrikası/ürün merkezinde; yardımcı yoksa kapalı
			local petKind = FarmMath.petKindFor(recipe)
			local built = petKind ~= nil and state.purchased[recipe.upgradeId] == true
			entry.repeatToggle.Visible = built
			if built and petKind then
				local hasPet = FarmMath.hasPet(state, petKind)
				local repeating = state.autoRepeat ~= nil and state.autoRepeat[id] ~= nil
				entry.repeatToggle.Text = if not hasPet
					then "Otomatik tekrar (yardımcı gerekli)"
					elseif repeating then "Otomatik tekrar: Açık"
					else "Otomatik tekrar: Kapalı"
				UiKit.setVariant(
					entry.repeatToggle,
					if not hasPet or blocked then "disabled" elseif repeating then "primary" else "secondary"
				)
			end
			local variant: UiKit.Variant = "primary"
			local job = state.production and state.production[id]
			local reward, bonus = FarmMath.getProductionReward(state, recipe, now, job)
			local isGoods = recipe.output == "goods" and recipe.goodsId ~= nil
			local good = if isGoods then Config.GOODS[recipe.goodsId :: string] else nil
			if isGoods then
				-- Ürün merkezi: teslimde para değil, ahır deposuna ürün gelir
				reward, bonus = FarmMath.getGoodsYield(state, recipe, now, job)
			end
			if job then
				local remaining = math.max(0, math.ceil(job.readyAt - now))
				entry.progress.Visible = true
				entry.fill(1 - remaining / FarmMath.getFacilityDuration(state, recipe, job.optionId), UiKit.Color.Green)
				local working = 0
				for _, animal in state.animals do
					local task = animal.task
					if task and task.kind == "production" and task.id == id then
						working += 1
					end
				end
				card.detail.Text = if remaining > 0
					then `{recipe.description}\nKalan: {math.floor(remaining / 60)}:{string.format(
						"%02d",
						remaining % 60
					)}\nTesisteki hayvanlar: {working}`
					else "Parti hazır. Teslim ederek yeni üretime yer aç."
				card.action.Text = if remaining > 0
					then "Üretiliyor"
					elseif isGoods then `Depoya al · +{reward}`
					else `Sat · {FarmMath.formatMoney(reward)}`
				variant = if remaining > 0 then "disabled" else "primary"
				if recipe.output == "chicken" and remaining == 0 then
					entry.keep.Visible = true
					local room = FarmMath.findZoneForAnimal(state, "chicken") ~= nil
					entry.keep.Text = if room then "Civcivi kümese ekle" else "Kümes dolu; satabilirsin"
					UiKit.setVariant(entry.keep, if room and not blocked then "primary" else "disabled")
				end
			elseif not state.purchased[recipe.upgradeId] then
				local upgrade = Config.getUpgrade(recipe.upgradeId)
				local status, missing = FarmMath.getUpgradeStatus(state, recipe.upgradeId)
				card.detail.Text = `{recipe.description}\n`
					.. (
						if status == "locked"
							then `Önce: {table.concat(missing, ", ")}`
							else "Önce üretim tesisini kur."
					)
				card.action.Text = if upgrade
					then `Tesisi kur · {FarmMath.formatMoney(FarmMath.getUpgradeCost(state, upgrade))}`
					else "Kilitli"
				variant = if not upgrade or status == "locked"
					then "disabled"
					elseif state.cash >= FarmMath.getUpgradeCost(state, upgrade) then "primary"
					else "warning"
			elseif recipe.options then
				-- Para tesisi: başlatma ücretsiz; her parti seçeneği kendi hayvan sayısını ister ve farklı kazandırır
				local adults = FarmMath.countProductionAdults(state, recipe, now)
				local busy = busyAnimals(state, recipe, now)
				local busyLine = if busy > 0 then `\nBaşka görevde: {busy}` else ""
				card.detail.Text =
					`{recipe.description}\nBoştaki yetişkin hayvan: {adults}{busyLine}\nBaşlatma ücretsiz; hayvanlar iş boyunca gelirsiz çalışır, bitince döner.`
				card.action.Visible = false
				for optionIndex, option in recipe.options do
					local button = entry.options[optionIndex]
					local duration = FarmMath.getFacilityDuration(state, recipe, option.id)
					local picked = FarmMath.pickProductionAnimals(state, recipe, now, option.id)
					local forgone = if picked then FarmMath.estimateForgoneIncome(state, picked, duration) else 0
					local shownReward = FarmMath.getProductionReward(
						state,
						recipe,
						now,
						{ uid = "preview", readyAt = now, forgone = forgone, optionId = option.id }
					)
					button.Visible = true
					button.Text =
						`{option.displayName} · {option.requiredAdults} hayvan · {duration} sn · +{FarmMath.formatMoney(
							shownReward
						)}`
					UiKit.setVariant(
						button,
						if blocked or adults < option.requiredAdults then "disabled" else "primary"
					)
				end
			else
				local adults = FarmMath.countProductionAdults(state, recipe, now)
				local busy = busyAnimals(state, recipe, now)
				local busyLine = if busy > 0 then `\nBaşka görevde: {busy}` else ""
				local bonusLine = if bonus > 0 then `\nYetişkin bonusu: +%{math.round(bonus * 100)}` else ""
				local startCost = FarmMath.getFacilityCost(state, recipe)
				-- Gösterilen satış, hayvanların kaçıracağı gelirin üstündeki garantili tabanı da içerir.
				local duration = FarmMath.getFacilityDuration(state, recipe)
				local picked = FarmMath.pickProductionAnimals(state, recipe, now)
				local forgone = if picked then FarmMath.estimateForgoneIncome(state, picked, duration) else 0
				local preview = { uid = "preview", readyAt = now, forgone = forgone }
				local hasSpace = true
				if isGoods and good then
					-- Ürün miktarı: kaçırılan gelirin üstündeki garantili taban dahil; depoda yer de gerekir
					local amount = FarmMath.getGoodsYield(state, recipe, now, preview)
					local space = FarmMath.getGoodsSpace(state, good.id)
					hasSpace = space >= math.min(math.max(recipe.goodsAmount or 0, amount), FarmMath.getGoodsCap(state))
					card.detail.Text =
						`{recipe.description}\n{duration} sn · {good.displayName} · +{amount}\nAhır deposu: {FarmMath.getGoodsAmount(
							state,
							good.id
						)}/{FarmMath.getGoodsCap(state)}\nYetişkin hayvan: {adults}/{recipe.requiredAdults}{bonusLine}{busyLine}\nHayvanlar iş boyunca gelirsiz çalışır, bitince döner.`
				else
					local shownReward = FarmMath.getProductionReward(state, recipe, now, preview)
					card.detail.Text = `{recipe.description}\n{duration} sn · Satış {FarmMath.formatMoney(
						shownReward
					)}\nYetişkin hayvan: {adults}/{recipe.requiredAdults}{bonusLine}{busyLine}\nHayvanlar iş boyunca gelirsiz çalışır, bitince döner.`
				end
				card.action.Text = if hasSpace then `Başlat · {FarmMath.formatMoney(startCost)}` else "Depo dolu"
				variant = if adults < recipe.requiredAdults or not hasSpace
					then "disabled"
					elseif state.cash >= startCost then "primary"
					else "warning"
			end
			UiKit.setVariant(card.action, if blocked then "disabled" else variant)
		end
	end
	created.frame:GetPropertyChangedSignal("Visible"):Connect(refresh)
	return created
end

function ProductionPanel.open(parent: Instance, recipeId: string?)
	screen = parent
	focused = recipeId
	local recipe = recipeId and Config.PRODUCTION_RECIPES[recipeId]
	focusedUpgrade = if recipe then recipe.upgradeId else nil
	if recipe and recipe.island ~= IslandContext.get() then
		-- Tesise yürüyerek gelindiğinde yönetim bağlamını değiştir; oyuncuyu geri ışınlama.
		Remotes.get("RequestTravelIsland"):FireServer(recipe.island, true)
	end
	if not window then
		window = create(parent)
	end
	local current = window :: UiKit.Window
	current.open()
	current.list.CanvasPosition = Vector2.zero
	refresh()
end

-- Menü düğmesi/kısayol: açıksa kapatır
function ProductionPanel.toggle(parent: Instance)
	local current = window
	if current and current.isOpen() then
		current.close()
		return
	end
	ProductionPanel.open(parent)
end

function ProductionPanel.bind(parent: Instance)
	screen = parent
end

ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt, who: Player?)
	if prompt.Name ~= "ProductionPrompt" or (who and who ~= player) or not screen then
		return
	end
	local owner: Instance? = prompt.Parent
	while owner and owner:GetAttribute("OwnerUserId") == nil do
		owner = owner.Parent
	end
	local recipeId = prompt:GetAttribute("ProductionRecipe")
	if
		owner
		and owner:GetAttribute("OwnerUserId") == player.UserId
		and owner:GetAttribute("MainFarmId") == player:GetAttribute("ActiveMainFarmId")
		and typeof(recipeId) == "string"
		and Config.PRODUCTION_RECIPES[recipeId]
	then
		ProductionPanel.open(screen, recipeId)
	end
end)
ClientState.onChanged(refresh)
IslandContext.Changed:Connect(refresh)
PurchaseController.Changed:Connect(refresh)
player:GetAttributeChangedSignal("DataStatus"):Connect(refresh)
local elapsed = 0
RunService.Heartbeat:Connect(function(dt: number)
	elapsed += dt
	if elapsed >= 0.25 then
		elapsed = 0
		refresh()
	end
end)
return ProductionPanel
