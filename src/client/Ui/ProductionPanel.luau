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
local player = Players.LocalPlayer
local ProductionPanel = {}
local window: UiKit.Window? = nil
local screen: ScreenGui? = nil
local render: (() -> ())? = nil
local sequence = 0
local pending: number? = nil
local nextSendAt = 0
local message = ""
local success = true
local focused: string? = nil

local function refresh()
	if render then
		render()
	end
end

local function submit(action: string, recipeId: string, uid: string?)
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
		:FireServer(action, recipeId, uid, requestId, if state then state.activeMainFarmId else nil)
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

local function create(parent: ScreenGui): UiKit.Window
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
	local changeIsland = UiKit.button(created.list, "Adalarımı yönet", "primary")
	changeIsland.Size = UDim2.new(1, 0, 0, 36)
	changeIsland.LayoutOrder = 20
	changeIsland.Activated:Connect(IslandManager.open)
	local feedback = UiKit.text(created.list, "", "Caption")
	feedback.LayoutOrder = 1
	type Entry = { card: UiKit.Card, keep: TextButton, progress: Frame, fill: (number, Color3) -> () }
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
		entries[id] = { card = card, keep = keep, progress = progress, fill = fill }
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
	render = function()
		if not created.isOpen() then
			return
		end
		local state = ClientState.get()
		if not state then
			return
		end
		feedback.Text = message
		selectedLabel.Text = IslandContext.name()
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
			card.frame.LayoutOrder = if focused == id then 2 else index + 3
			entry.keep.Visible = false
			entry.progress.Visible = false
			local variant: UiKit.Variant = "primary"
			local job = state.production and state.production[id]
			local reward, bonus = FarmMath.getProductionReward(state, recipe, now, job)
			if job then
				local remaining = math.max(0, math.ceil(job.readyAt - now))
				entry.progress.Visible = true
				entry.fill(1 - remaining / FarmMath.getFacilityDuration(state, recipe), UiKit.Color.Green)
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
				card.action.Text = if remaining > 0 then "Üretiliyor" else `Sat · {FarmMath.formatMoney(reward)}`
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
			else
				local adults = FarmMath.countProductionAdults(state, recipe, now)
				local bonusLine = if bonus > 0 then `\nYetişkin bonusu: +%{math.round(bonus * 100)}` else ""
				local startCost = FarmMath.getFacilityCost(state, recipe)
				-- Gösterilen satış, hayvanların kaçıracağı gelirin üstündeki garantili tabanı da içerir.
				local duration = FarmMath.getFacilityDuration(state, recipe)
				local picked = FarmMath.pickProductionAnimals(state, recipe, now)
				local forgone = if picked then FarmMath.estimateForgoneIncome(state, picked, duration) else 0
				local shownReward = FarmMath.getProductionReward(
					state,
					recipe,
					now,
					{ uid = "preview", readyAt = now, forgone = forgone }
				)
				card.detail.Text =
					`{recipe.description}\n{duration} sn · Satış {FarmMath.formatMoney(shownReward)}\nYetişkin hayvan: {adults}/{recipe.requiredAdults}{bonusLine}\nHayvanlar iş boyunca gelirsiz çalışır, bitince döner.`
				card.action.Text = `Başlat · {FarmMath.formatMoney(startCost)}`
				variant = if adults < recipe.requiredAdults
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

function ProductionPanel.open(parent: ScreenGui, recipeId: string?)
	screen = parent
	focused = recipeId
	local recipe = recipeId and Config.PRODUCTION_RECIPES[recipeId]
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

function ProductionPanel.bind(parent: ScreenGui)
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
