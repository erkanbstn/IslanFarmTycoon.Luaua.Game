--!strict
-- Önce ayrı ana çiftlikler; küçük uzman adalar yalnızca etkin ana çiftliğe bağlıdır.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local FarmMath = require(Shared:WaitForChild("Modules"):WaitForChild("FarmMath"))
local UiKit = require(script.Parent:WaitForChild("UiKit"))
local SendMoney = require(script.Parent:WaitForChild("SendMoney"))
local HudCommon = require(script.Parent:WaitForChild("Hud"):WaitForChild("HudCommon"))
local ClientState = require(script.Parent.Parent:WaitForChild("Core"):WaitForChild("ClientState"))
local Sfx = require(script.Parent.Parent:WaitForChild("Core"):WaitForChild("Sfx"))
local PurchaseController = require(script.Parent.Parent:WaitForChild("Core"):WaitForChild("PurchaseController"))
local IslandContext = require(script.Parent.Parent:WaitForChild("Core"):WaitForChild("IslandContext"))
local player = Players.LocalPlayer
local IslandManager = {}
local window: UiKit.Window? = nil
local refresh: (() -> ())? = nil
local travelling = false
local sequence = 0
local pending: number? = nil
local resultMessage = ""
local resultOk = false
local LIMIT = Config.MAIN_FARM_LIMIT or 6
local notifyHook: ((message: string, kind: string?) -> ())? = nil

type Offer = { id: string, name: string, icon: string, ownerUserId: number? }

-- Sunucunun tam ada envanteri. Streaming açıkken uzak adaların modeli cihazda olmayabilir;
-- satın alma/ziyaret listesi bu yüzden Workspace'e değil bu listeye dayanır.
local function offersById(state: any): { [string]: Offer }
	local result: { [string]: Offer } = {}
	local offers = state and state.mainFarmOffers
	if typeof(offers) == "table" then
		for _, offer in offers do
			if typeof(offer) == "table" and typeof(offer.id) == "string" then
				result[offer.id] = offer
			end
		end
	end
	return result
end

type MainFarm = {
	id: string,
	plotId: string?,
	active: boolean,
	animalCount: number,
	purchasedCount: number,
	stored: number,
}

local function update()
	if refresh then
		refresh()
	end
end

local function blocked(): boolean
	return pending ~= nil
		or travelling
		or PurchaseController.isPending()
		or player:GetAttribute("DataStatus") ~= "Active"
end

local function summaries(state: any): { MainFarm }
	if typeof(state.mainFarmSummaries) == "table" and #state.mainFarmSummaries > 0 then
		return state.mainFarmSummaries
	end
	-- Eski/ilk snapshot: yalnızca başlangıç çiftliğini göster; sahte ek çiftlik üretme.
	local purchased = 0
	for _, owned in state.purchased do
		if owned then
			purchased += 1
		end
	end
	return {
		{
			id = "1",
			plotId = nil,
			active = true,
			animalCount = #state.animals,
			purchasedCount = purchased,
			stored = state.stored,
		},
	}
end

local function submit(action: string, target: string)
	if blocked() then
		return
	end
	sequence += 1
	local id = sequence
	pending = id
	resultMessage = "Ana çiftlik işlemi bekleniyor..."
	resultOk = false
	update()
	Remotes.get("RequestMainFarmAction"):FireServer(action, target, id)
	task.delay(8, function()
		if pending ~= id then
			return
		end
		pending = nil
		resultMessage = "Yanıt gecikti. İstek tekrarlanmadı; çiftlik bilgileri yenileniyor."
		resultOk = false
		ClientState.requestSnapshot()
		update()
	end)
end

Remotes.get("MainFarmResult").OnClientEvent:Connect(function(id: unknown, ok: unknown, message: unknown)
	if typeof(id) ~= "number" or id ~= pending or typeof(ok) ~= "boolean" then
		return
	end
	pending = nil
	Sfx.play(if ok then "success" else "error")
	resultOk = ok
	resultMessage = if typeof(message) == "string"
		then message
		else if ok then "Ana çiftlik hazır." else "İşlem uygulanamadı."
	if notifyHook then
		notifyHook(resultMessage, if ok then "success" else "error")
	end
	update()
end)

local function create(): UiKit.Window
	local screen = Instance.new("ScreenGui")
	screen.Name = "IslandManager"
	screen.ResetOnSpawn = false
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screen.DisplayOrder = 5
	screen.Parent = player:WaitForChild("PlayerGui")
	local root = UiKit.screenRoot(screen)
	local created = UiKit.window(root, {
		title = "Ana Çiftlikler ve Adalar",
		icon = "🧭",
		tint = UiKit.Color.Blue,
		width = 360,
		maxHeight = 470,
		anchor = Vector2.new(0.5, 0.5),
		position = UDim2.fromScale(0.5, 0.5),
	})
	created.frame.BackgroundColor3 = UiKit.Color.Surface
	created.frame.BackgroundTransparency = 0
	-- Bu pencerenin önünde görünen bildirim alanı: yetersiz bakiye, satın alma sonucu vb.
	local notify = UiKit.toastHost(root)
	notifyHook = notify
	local info = UiKit.text(created.list, "", "Caption")
	info.LayoutOrder = 0
	local feedback = UiKit.text(created.list, "", "Caption")
	feedback.LayoutOrder = 1
	local function section(order: number): Frame
		local frame = Instance.new("Frame")
		frame.BackgroundTransparency = 1
		frame.Size = UDim2.new(1, 0, 0, 0)
		frame.AutomaticSize = Enum.AutomaticSize.Y
		frame.LayoutOrder = order
		frame.Parent = created.list
		UiKit.list(frame, 8)
		return frame
	end
	local ownedList = section(3)
	local ownedCards: { [string]: UiKit.Card } = {}
	-- Etkin çiftlik kartındaki ok: bu çiftliğe bağlı küçük adalar kartın altında açılır/kapanır.
	local specialtyOpen = false
	local applySpecialtyOpen: () -> () = function() end
	local arrows: { [string]: TextButton } = {}
	for index = 1, LIMIT do
		local id = tostring(index)
		local card = UiKit.card(ownedList, index, "🏝️")
		card.frame.BackgroundColor3 = UiKit.Color.SurfaceRaised
		card.frame.Visible = false
		ownedCards[id] = card
		local row = card.icon.Parent :: Frame
		local texts = card.title.Parent :: Frame
		texts.Size = UDim2.new(1, -96, 0, 0)
		local arrow = Instance.new("TextButton")
		arrow.Name = "SpecialtyArrow"
		arrow.AnchorPoint = Vector2.new(1, 0)
		arrow.Position = UDim2.new(1, 0, 0, 5)
		arrow.Size = UDim2.fromOffset(32, 32)
		arrow.BackgroundColor3 = UiKit.Color.Surface
		arrow.Text = ""
		arrow.AutoButtonColor = true
		arrow.Visible = false
		arrow.Parent = row
		UiKit.corner(arrow, 8)
		-- Aşağı bakan ok (çizilmiş iki çubuk); kapalıyken sağa döner
		for _, side in { -1, 1 } do
			local bar = Instance.new("Frame")
			bar.AnchorPoint = Vector2.new(0.5, 0.5)
			bar.Size = UDim2.fromOffset(12, 3)
			bar.Position = UDim2.new(0.5, side * 3.5, 0.5, -1)
			bar.Rotation = -side * 45
			bar.BackgroundColor3 = UiKit.Color.Gold
			bar.BorderSizePixel = 0
			bar.Parent = arrow
			UiKit.corner(bar, 2)
		end
		arrow.Activated:Connect(function()
			specialtyOpen = not specialtyOpen
			applySpecialtyOpen()
		end)
		arrows[id] = arrow
		card.action.Activated:Connect(function()
			if card.action.Active then
				submit("select", id)
			end
		end)
	end
	local buyInfo = UiKit.text(created.list, "", "Caption")
	buyInfo.LayoutOrder = 5
	local freeList = section(6)
	local freeGrid = UiKit.autoGrid(freeList, 1)
	local freeCards: { [string]: UiKit.Card } = {}
	local plotsById: { [string]: Instance } = {}
	local offerById: { [string]: Offer } = {}

	local function nameOf(id: string): string?
		local offer = offerById[id]
		return if offer then offer.name else nil
	end
	local function isKnown(id: string): boolean
		return offerById[id] ~= nil
	end
	local function isOwned(id: string): boolean
		local state = ClientState.get()
		if not state then
			return false
		end
		for _, farm in summaries(state) do
			if farm.id == id then
				return true
			end
		end
		return false
	end

	for index = 1, Config.MAP_PLOT_COUNT do
		local id = tostring(index)
		local card = UiKit.autoTile(freeGrid, index, "🌴")
		card.frame.BackgroundColor3 = UiKit.Color.SurfaceRaised
		freeCards[id] = card
		card.action.Activated:Connect(function()
			if card.action.Active and isKnown(id) and not isOwned(id) then
				local state = ClientState.get()
				local price = if state then FarmMath.getPrice(state, "farm", nil, index) else nil
				if state and typeof(price) == "number" and state.cash < price then
					-- Sunucuya gitmeden hemen bildir
					if notifyHook then
						notifyHook(
							`Yeterli para yok: yeni ana çiftlik {FarmMath.formatMoney(price)} (kasanda {FarmMath.formatMoney(
								state.cash
							)})`,
							"error"
						)
					end
					return
				end
				submit("buy", id)
			end
		end)
	end
	local specialtyBox = Instance.new("Frame")
	specialtyBox.Name = "SpecialtyBox"
	specialtyBox.BackgroundTransparency = 1
	specialtyBox.Size = UDim2.new(1, 0, 0, 0)
	specialtyBox.AutomaticSize = Enum.AutomaticSize.Y
	specialtyBox.LayoutOrder = 3
	specialtyBox.Visible = false
	UiKit.list(specialtyBox, 8)
	local specialtyInfo = UiKit.text(specialtyBox, "", "Caption")
	specialtyInfo.LayoutOrder = 1
	local specialtyList = Instance.new("Frame")
	specialtyList.BackgroundTransparency = 1
	specialtyList.Size = UDim2.new(1, 0, 0, 0)
	specialtyList.AutomaticSize = Enum.AutomaticSize.Y
	specialtyList.LayoutOrder = 2
	specialtyList.Parent = specialtyBox
	UiKit.list(specialtyList, 8)
	local specialtyGrid = UiKit.autoGrid(specialtyList, 1)
	-- Küçük adalar artık kendi sekmesinde (ok ile açılan kutu kalktı); görünürlüğü sekme belirler
	specialtyBox.LayoutOrder = 7
	specialtyBox.Parent = created.list
	applySpecialtyOpen = function() end
	local specialtyCards: { [string]: UiKit.Card } = {}
	for index, id in Config.FARM_ISLAND_ORDER do
		if id == "home" then
			continue
		end
		local island = Config.FARM_ISLANDS[id]
		local card = UiKit.autoTile(specialtyGrid, index, island.icon)
		card.frame.BackgroundColor3 = UiKit.Color.SurfaceRaised
		specialtyCards[id] = card
		card.action.Activated:Connect(function()
			local state = ClientState.get()
			if not state or not card.action.Active or blocked() then
				return
			end
			if state.unlockedIslands[id] then
				travelling = true
				update()
				Remotes.get("RequestTravelIsland"):FireServer(id)
				task.delay(1.6, function()
					travelling = false
					update()
				end)
			elseif island.upgradeId then
				local upgrade = Config.getUpgrade(island.upgradeId)
				if upgrade and state.cash < FarmMath.getUpgradeCost(state, upgrade) then
					if notifyHook then
						notifyHook(
							`Yeterli para yok: {island.displayName} {FarmMath.formatMoney(
								FarmMath.getUpgradeCost(state, upgrade)
							)} (kasanda {FarmMath.formatMoney(state.cash)})`,
							"error"
						)
					end
					return
				end
				if upgrade then
					local shortfall = FarmMath.getGoodsShortfall(state, FarmMath.getGoodsCost(state, upgrade))
					if #shortfall > 0 then
						if notifyHook then
							notifyHook(`Yeterli ürün yok ({FarmMath.formatGoodsShortfall(shortfall)})`, "error")
						end
						return
					end
				end
				PurchaseController.submit("RequestBuyUpgrade", island.upgradeId)
			end
		end)
	end
	local hub = UiKit.button(created.list, "Meydana git", "primary")
	hub.Size = UDim2.new(1, 0, 0, 36)
	hub.LayoutOrder = 10
	hub.Activated:Connect(function()
		if blocked() then
			return
		end
		Remotes.get("RequestTravel"):FireServer("hub")
		created.close()
	end)
	local visits = section(12)
	-- Sekmeler: Çiftliklerim | Satın Al | Küçük Adalar | Ziyaret (her sekme kendi bölümlerini gösterir)
	local tabContent: { [string]: { GuiObject } } = {
		farms = { ownedList, hub },
		buy = { buyInfo, freeList },
		islands = { specialtyBox },
		visit = { visits },
	}
	local function showTab(id: string)
		for tabId, objects in tabContent do
			for _, object in objects do
				object.Visible = tabId == id
			end
		end
	end
	UiKit.tabs(created.list, -1, {
		{ id = "farms", label = "Çiftliklerim" },
		{ id = "buy", label = "Satın Al" },
		{ id = "islands", label = "Küçük Adalar" },
		{ id = "visit", label = "Ziyaret" },
	}, showTab)
	showTab("farms")
	local visitsSignature: string? = nil
	local visitButtons: { TextButton } = {}
	local function rebuildVisits()
		local plots = Workspace:FindFirstChild("Plots")
		local signatureParts: { string } = {}
		local nextPlots: { [string]: Instance } = {}
		if plots then
			for _, plot in plots:GetChildren() do
				local id = plot:GetAttribute("PlotId")
				if typeof(id) ~= "string" then
					continue
				end
				nextPlots[id] = plot
				table.insert(
					signatureParts,
					`{id}:{tostring(plot:GetAttribute("OwnerUserId"))}:{tostring(plot:GetAttribute("MainFarmId"))}:{tostring(
						plot:GetAttribute("IslandName")
					)}`
				)
			end
		end
		plotsById = nextPlots
		offerById = offersById(ClientState.get())
		for id, offer in offerById do
			table.insert(signatureParts, `offer:{id}:{tostring(offer.ownerUserId)}:{offer.name}`)
		end
		table.sort(signatureParts)
		local signature = table.concat(signatureParts, "|")
		if signature == visitsSignature then
			return
		end
		visitsSignature = signature
		table.clear(visitButtons)
		for _, child in visits:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		UiKit.text(visits, "Diğer oyuncuların adalarını ziyaret edebilirsin; onlara dokunamazsın.", "Caption").LayoutOrder =
			0
		local visitGrid = UiKit.autoGrid(visits, 1)
		for index = 1, Config.MAP_PLOT_COUNT do
			local id = tostring(index)
			local plot = plotsById[id]
			local ownerId = plot and plot:GetAttribute("OwnerUserId")
			if not plot or typeof(ownerId) ~= "number" or ownerId == player.UserId then
				continue
			end
			local owner = Players:GetPlayerByUserId(ownerId)
			local card = UiKit.autoTile(visitGrid, index, tostring(plot:GetAttribute("IslandIcon") or "🏝️"))
			card.frame.BackgroundColor3 = UiKit.Color.SurfaceRaised
			card.title.Text = tostring(plot:GetAttribute("IslandName") or plot.Name)
			card.detail.Text = `{if owner then owner.DisplayName else "Oyuncu"} · Çiftlik {tostring(
				plot:GetAttribute("MainFarmId")
			)}`
			card.action.Text = "Ziyaret et"
			table.insert(visitButtons, card.action)
			card.action.Activated:Connect(function()
				if blocked() then
					return
				end
				Remotes.get("RequestTravel"):FireServer(id)
				created.close()
			end)
			if owner then
				local give = UiKit.button(card.frame, "Para gönder", "secondary")
				give.Size = UDim2.new(1, 0, 0, 30)
				give.TextSize = UiKit.TextSize.Button
				give.LayoutOrder = 5
				give.Activated:Connect(function()
					if blocked() then
						return
					end
					SendMoney.open(owner.UserId, owner.DisplayName)
				end)
			end
		end
	end
	refresh = function()
		if not created.isOpen() then
			return
		end
		local state = ClientState.get()
		if not state then
			return
		end
		offerById = offersById(state)
		local farms = summaries(state)
		local activeId = (state :: any).activeMainFarmId or "1"
		local activeName = `Ana Çiftlik {activeId}`
		info.Text =
			`Etkin: {activeName} · Bölüm: {IslandContext.name()} · Çiftlik {#farms}/{LIMIT}\nKasa {FarmMath.formatMoney(
				state.cash
			)} bütün ana çiftliklerinde ortaktır.`
		feedback.Text = resultMessage
		feedback.Visible = resultMessage ~= ""
		feedback.TextColor3 = if pending
			then UiKit.Color.TextMuted
			elseif resultOk then UiKit.Color.Green
			else UiKit.Color.Red
		local unavailable = blocked()
		for _, card in ownedCards do
			card.frame.Visible = false
		end
		for _, farm in farms do
			local card = ownedCards[farm.id]
			if not card then
				continue
			end
			card.frame.Visible = true
			local isActive = farm.id == activeId
			local physicalName = nameOf(farm.id)
			card.title.Text = `Ana Çiftlik {farm.id}` .. (if isActive then " · Etkin" else "")
			local stored = if isActive then state.stored else farm.stored
			card.detail.Text = `{farm.animalCount} hayvan · {farm.purchasedCount} yatırım · Depo {FarmMath.formatMoney(
				stored
			)}\n` .. (if physicalName then `Konum: {physicalName}` else "Park halinde; seçince adanda açılır.")
			card.action.Text = if pending
				then "İşleniyor"
				elseif isActive then "Etkin çiftliğe dön"
				else "Bu ana çiftliği yönet"
			UiKit.setVariant(card.action, if unavailable then "disabled" else "primary")
		end
		local atLimit = #farms >= LIMIT
		buyInfo.Text = if atLimit
			then `En fazla {LIMIT} ana çiftliğin olabilir.`
			else "Bir çiftlik teması seç; her temanın kendi fiyatı vardır (ilerledikçe pahalı ve zor). Satın alınca adan o çiftliğe dönüşür; önceki çiftliğin park edilir ve çalışmaya devam eder."
		-- Sahip olunan en yüksek tema: ondan iki ya da daha fazla ileri tema "çok zor" etiketi alır (fiyat ve süre kademesi tema numarasından gelir)
		local highestOwned = 0
		for _, farm in farms do
			highestOwned = math.max(highestOwned, tonumber(farm.id) or 0)
		end
		for id, card in freeCards do
			local known = isKnown(id)
			local cardPrice = FarmMath.getPrice(state, "farm", nil, tonumber(id) or 1)
			card.frame.Visible = not isOwned(id)
			card.title.Text = nameOf(id) or `Ana alan {id}`
			local offer = offerById[id]
			if offer then
				card.icon.Text = offer.icon
			end
			local variant: UiKit.Variant = "disabled"
			if not known then
				card.detail.Text, card.action.Text = "Alan bilgisi henüz yüklenmedi.", "Yükleniyor"
			elseif atLimit then
				card.detail.Text, card.action.Text = "Bu çiftlik teması henüz senin değil.", "Çiftlik sınırı"
			elseif typeof(cardPrice) == "number" then
				local veryHard = (tonumber(id) or 1) >= highestOwned + 2
				card.detail.Text = if veryHard
					then "Çok zor: önce daha kolay çiftlikleri al. Hayvanları ve yatırımları ayrı gelişir; kasa ve depo ortaktır."
					else "Hayvanları ve yatırımları ayrı gelişir; kasa ve depo ortaktır."
				card.action.Text = if pending then "İşleniyor" else `Satın al · {FarmMath.formatMoney(cardPrice)}`
				variant = if state.cash >= cardPrice then "primary" else "warning"
			else
				card.detail.Text, card.action.Text = "Fiyat bilgisi bekleniyor.", "Bekleniyor"
			end
			UiKit.setVariant(card.action, if unavailable then "disabled" else variant)
		end
		specialtyInfo.Text =
			`Bu üç küçük ada yalnızca {activeName}'i geliştirir ({Config.getTheme(activeId).displayName}). Seçili bölüm: {IslandContext.name()}.`
		local themeIslands = FarmMath.themeIslands(state)
		for id, card in specialtyCards do
			local island = Config.FARM_ISLANDS[id]
			-- Yalnızca bu çiftliğin temasındaki küçük adalar listelenir
			card.frame.Visible = table.find(themeIslands, id) ~= nil
			card.title.Text = island.displayName .. (if id == IslandContext.get() then " · Seçili" else "")
			local variant: UiKit.Variant = "primary"
			if state.unlockedIslands[id] then
				card.detail.Text = island.trait
				card.action.Text = if travelling then "Geçiş bekleniyor" else "Küçük adaya git"
			else
				local upgrade = island.upgradeId and Config.getUpgrade(island.upgradeId)
				local status, missing = FarmMath.getUpgradeStatus(state, island.upgradeId or "")
				local needs = if upgrade and status ~= "locked" then HudCommon.goodsNeedText(state, upgrade) else nil
				card.detail.Text = island.trait
					.. (if status == "locked" then `\nÖnce: {table.concat(missing, ", ")}` else "")
					.. (if needs then `\n{needs}` else "")
				card.action.Text = if upgrade
					then `Küçük adayı aç · {FarmMath.formatMoney(FarmMath.getUpgradeCost(state, upgrade))}`
					else "Kilitli"
				variant = if not upgrade or status == "locked"
					then "disabled"
					else HudCommon.upgradeVariant(state, upgrade)
			end
			UiKit.setVariant(card.action, if unavailable then "disabled" else variant)
		end
		UiKit.setVariant(hub, if unavailable then "disabled" else "primary")
		for _, button in visitButtons do
			UiKit.setVariant(button, if unavailable then "disabled" else "primary")
		end
	end
	created.frame:GetPropertyChangedSignal("Visible"):Connect(function()
		if created.isOpen() then
			rebuildVisits()
			update()
		end
	end)
	local elapsed = 0
	local snapshotElapsed = 0
	local polling = RunService.Heartbeat:Connect(function(dt: number)
		if not created.isOpen() then
			snapshotElapsed = 0
			return
		end
		elapsed += dt
		snapshotElapsed += dt
		if snapshotElapsed >= 3 then
			snapshotElapsed = 0
			ClientState.requestSnapshot()
		end
		if elapsed >= 1 then
			elapsed = 0
			rebuildVisits()
			update()
		end
	end)
	screen.Destroying:Connect(function()
		polling:Disconnect()
	end)
	return created
end

function IslandManager.isOpen(): boolean
	return window ~= nil and (window :: UiKit.Window).isOpen()
end

function IslandManager.toggle()
	if IslandManager.isOpen() then
		(window :: UiKit.Window).close()
	else
		IslandManager.open()
	end
end

function IslandManager.open()
	if not window then
		window = create()
	end
	(window :: UiKit.Window).open()
	update()
end
ClientState.onChanged(update)
PurchaseController.Changed:Connect(update)
IslandContext.Changed:Connect(function()
	travelling = false
	update()
end)
-- Satın alma sonuçları (küçük ada açma vb.) pencere açıkken pencerenin bildirim alanında gösterilir.
PurchaseController.Completed:Connect(function(success: boolean, message: string?)
	if message and notifyHook and IslandManager.isOpen() then
		notifyHook(message, if success then "success" else "error")
	end
end)
player:GetAttributeChangedSignal("DataStatus"):Connect(update)
player.CharacterAdded:Connect(function()
	if window then
		window.close()
	end
end)
return IslandManager
