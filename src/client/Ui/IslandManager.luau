--!strict
-- Önce ayrı ana çiftlikler; küçük uzman adalar yalnızca etkin ana çiftliğe bağlıdır.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local FarmMath = require(Shared:WaitForChild("Modules"):WaitForChild("FarmMath"))
local UiKit = require(script.Parent:WaitForChild("UiKit"))
local SendMoney = require(script.Parent:WaitForChild("SendMoney"))
local VisitTargets = require(script.Parent:WaitForChild("Hud"):WaitForChild("VisitTargets"))
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

local avatarCache: { [number]: string } = {}
local avatarRequests: { [number]: { (string) -> () } } = {}

local function setAvatar(chip: TextLabel, userId: number)
	chip.Name = "OwnerAvatar"
	chip.Size = UDim2.fromOffset(48, 48)
	chip.BackgroundColor3 = UiKit.Color.Panel
	chip.ClipsDescendants = true
	local portrait = Instance.new("ImageLabel")
	portrait.Name = "Portrait"
	portrait.BackgroundTransparency = 1
	portrait.Size = UDim2.fromScale(1, 1)
	portrait.ScaleType = Enum.ScaleType.Crop
	portrait.Parent = chip
	UiKit.corner(portrait, UiKit.Radius.Card)
	local function apply(image: string)
		if not chip:IsDescendantOf(player.PlayerGui) then
			return
		end
		portrait.Image = image
		UiKit.setText(chip, "")
	end
	local cached = avatarCache[userId]
	if cached then
		apply(cached)
		return
	end
	local pendingAvatars = avatarRequests[userId]
	if pendingAvatars then
		table.insert(pendingAvatars, apply)
		return
	end
	avatarRequests[userId] = { apply }
	task.spawn(function()
		local image: string? = nil
		for attempt = 1, 3 do
			local ok, content, ready = pcall(function()
				return Players:GetUserThumbnailAsync(
					userId,
					Enum.ThumbnailType.HeadShot,
					Enum.ThumbnailSize.Size150x150
				)
			end)
			if ok and ready and content ~= "" then
				image = content
				break
			end
			if attempt < 3 then
				task.wait(1)
			end
		end
		local waiting: { (string) -> () } = avatarRequests[userId] or {}
		avatarRequests[userId] = nil
		if image then
			avatarCache[userId] = image
			for _, callback in waiting do
				callback(image)
			end
		end
	end)
end

Players.PlayerRemoving:Connect(function(leaving: Player)
	avatarCache[leaving.UserId] = nil
end)

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
	-- Altı oyuncunun geçişi ortak kuyrukta sırayla işlenebilir.
	task.delay(60, function()
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
		title = "Adalar",
		icon = "🧭",
		tint = UiKit.Color.Blue,
		width = 540,
		maxHeight = 560,
		anchor = Vector2.new(0.5, 0.5),
		position = UDim2.fromScale(0.5, 0.5),
	})
	created.frame.BackgroundColor3 = UiKit.Color.Surface
	created.frame.BackgroundTransparency = 0
	-- Bu pencerenin önünde görünen bildirim alanı: yetersiz bakiye, satın alma sonucu vb.
	local notify = UiKit.toastHost(root)
	notifyHook = notify
	local details = UiKit.disclosure(created.list, 15, "Ayrıntılar")
	UiKit.text(details.body, "Kasa ve altın ortaktır; hayvanlar, yükseltmeler ve depolar çiftliğe aittir.", "Body").LayoutOrder =
		1
	UiKit.text(
		details.body,
		"Çiftlik değiştirince önceki çiftliğin çalışmaya devam eder. Küçük adalar yalnızca etkin çiftliği geliştirir.",
		"Body"
	).LayoutOrder =
		2
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
	for index = 1, LIMIT do
		local id = tostring(index)
		local card = UiKit.card(ownedList, index, "🏝️")
		card.frame.Visible = false
		ownedCards[id] = card
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
	local specialtyCards: { [string]: UiKit.Card } = {}
	for index, id in Config.FARM_ISLAND_ORDER do
		if id == "home" then
			continue
		end
		local island = Config.FARM_ISLANDS[id]
		local card = UiKit.autoTile(specialtyGrid, index, island.icon)
		specialtyCards[id] = card
		local islandDetails = UiKit.disclosure(card.frame, 6, "Ayrıntılar")
		UiKit.text(islandDetails.body, island.trait, "Caption")
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
	hub.Size = UDim2.new(1, 0, 0, UiKit.TouchTarget)
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
	local giveButtons: { TextButton } = {}
	local function rebuildVisits()
		local signatureParts: { string } = {}
		for _, owner in Players:GetPlayers() do
			table.insert(
				signatureParts,
				`owner:{owner.UserId}:{owner.DisplayName}:{tostring(owner:GetAttribute("ActiveMainFarmId"))}:{tostring(
					owner:GetAttribute("ActivePlotId")
				)}`
			)
		end
		table.sort(signatureParts)
		local signature = table.concat(signatureParts, "|")
		if signature == visitsSignature then
			return
		end
		visitsSignature = signature
		table.clear(visitButtons)
		table.clear(giveButtons)
		for _, child in visits:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		local visitDetails = UiKit.disclosure(visits, 2, "Ayrıntılar")
		UiKit.text(
			visitDetails.body,
			"Diğer oyuncuların adalarını ziyaret edebilirsin; onlara dokunamazsın.",
			"Caption"
		).LayoutOrder =
			0
		local visitGrid = UiKit.autoGrid(visits, 1)
		local targets = VisitTargets.list(Players:GetPlayers(), player.UserId)
		if #targets == 0 then
			UiKit.text(visits, "Sunucuda ziyaret edebileceğin başka oyuncu yok.", "Body").LayoutOrder = 0
		end
		for index, target in targets do
			local owner = target.owner
			local ownerId = owner.UserId
			local ownerName = owner.DisplayName
			local id = target.plotId
			local farmId = target.farmId
			local card = UiKit.autoTile(visitGrid, index, "👤", { compact = true })
			card.frame.Name = `Visit_{ownerId}`
			setAvatar(card.icon, ownerId)
			card.title.TextWrapped = false
			card.title.TextTruncate = Enum.TextTruncate.AtEnd
			card.title.AutomaticSize = Enum.AutomaticSize.None
			card.title.Size = UDim2.new(1, 0, 0, UiKit.TextSize.Caption + 6)
			UiKit.setText(card.title, ownerName)
			UiKit.setText(card.detail, if farmId ~= nil then `Çiftlik {tostring(farmId)}` else "Yükleniyor")
			UiKit.setText(card.action, if id then "Ziyaret et" else "Yükleniyor")
			if id then
				table.insert(visitButtons, card.action)
			else
				UiKit.setVariant(card.action, "disabled")
			end
			card.action.Activated:Connect(function()
				if blocked() or not id then
					return
				end
				Remotes.get("RequestTravel"):FireServer(id)
				created.close()
			end)
			if owner then
				local give = UiKit.button(card.frame, "Para gönder", "accent")
				give.Size = UDim2.new(1, 0, 0, UiKit.TouchTarget)
				give.TextSize = UiKit.TextSize.Button
				give.LayoutOrder = 5
				table.insert(giveButtons, give)
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
		UiKit.setText(info, `Çiftlik {activeId} · {IslandContext.name()} · {#farms}/{LIMIT}`)
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
			card.title.Text = `Ana Çiftlik {farm.id}` .. (if isActive then " · Etkin" else "")
			local stored = if isActive then state.stored else farm.stored
			UiKit.setText(
				card.detail,
				`{farm.animalCount} hayvan · {farm.purchasedCount} yatırım · Depo {FarmMath.formatMoney(stored)}`
			)
			card.action.Text = if pending
				then "İşleniyor"
				elseif isActive then "Etkin çiftliğe dön"
				else "Bu ana çiftliği yönet"
			UiKit.setVariant(card.action, if unavailable then "disabled" else "primary")
		end
		local atLimit = #farms >= LIMIT
		UiKit.setText(
			buyInfo,
			if atLimit then `En fazla {LIMIT} ana çiftliğin olabilir.` else "Sıradaki çiftliğini seç."
		)
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
				UiKit.setText(
					card.detail,
					if veryHard then "Çok zor: önceki çiftliklerden sonra önerilir." else "Yeni çiftlik"
				)
				card.action.Text = if pending then "İşleniyor" else `Satın al · {FarmMath.formatMoney(cardPrice)}`
				variant = if state.cash >= cardPrice then "primary" else "warning"
			else
				card.detail.Text, card.action.Text = "Fiyat bilgisi bekleniyor.", "Bekleniyor"
			end
			UiKit.setVariant(card.action, if unavailable then "disabled" else variant)
		end
		UiKit.setText(specialtyInfo, Config.getTheme(activeId).displayName)
		local themeIslands = FarmMath.themeIslands(state)
		for id, card in specialtyCards do
			local island = Config.FARM_ISLANDS[id]
			-- Yalnızca bu çiftliğin temasındaki küçük adalar listelenir
			card.frame.Visible = table.find(themeIslands, id) ~= nil
			card.title.Text = island.displayName .. (if id == IslandContext.get() then " · Seçili" else "")
			local variant: UiKit.Variant = "primary"
			if state.unlockedIslands[id] then
				card.detail.Visible = false
				card.action.Text = if travelling then "Geçiş bekleniyor" else "Küçük adaya git"
			else
				local upgrade = island.upgradeId and Config.getUpgrade(island.upgradeId)
				local status, missing = FarmMath.getUpgradeStatus(state, island.upgradeId or "")
				local needs = if upgrade and status ~= "locked" then HudCommon.goodsNeedText(state, upgrade) else nil
				card.detail.Visible = status == "locked" or needs ~= nil
				UiKit.setText(
					card.detail,
					(if status == "locked" then `Önce: {table.concat(missing, ", ")}` else "")
						.. (if needs then `\n{needs}` else "")
				)
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
		for _, button in giveButtons do
			UiKit.setVariant(button, if unavailable then "disabled" else "accent")
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
	if window then
		UiKit.toggleWindow(window :: UiKit.Window)
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
