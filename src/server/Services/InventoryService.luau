--!strict
-- Envanter: eşya satın alma (oyun parasıyla), slotlara takma/çıkarma ve asa gücü (mevsim/hava değiştirme).
-- Takılı eşyaların ekonomik etkileri FarmMath'te hesaplanır (sunucu ve client aynı sonucu görür); burada yalnızca
-- karar, ödeme, kayıt ve karakter görünümü vardır. Fiyat, sahiplik ve günlük haklar yalnızca sunucuda doğrulanır.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local FarmMath = require(Shared:WaitForChild("Modules"):WaitForChild("FarmMath"))
local Environment = require(Shared:WaitForChild("Modules"):WaitForChild("Environment"))
local Inventory = require(Shared:WaitForChild("Modules"):WaitForChild("Inventory"))
local Merchant = require(Shared:WaitForChild("Modules"):WaitForChild("Merchant"))

local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))
local RequestGuard = require(script.Parent:WaitForChild("RequestGuard"))
local PlotService = require(script.Parent:WaitForChild("PlotService"))
local EconomyService = require(script.Parent:WaitForChild("EconomyService"))
local SeasonService = require(script.Parent:WaitForChild("SeasonService"))
local RateLimiter = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("RateLimiter"))
local Metrics = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("Metrics"))
local ModelAssets = require(script.Parent.Parent:WaitForChild("World"):WaitForChild("ModelAssets"))

local WearableFit = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("WearableFit"))

local InventoryService = {}
local merchantProximity: (Player) -> boolean = function(_player: Player): boolean
	return false
end

function InventoryService.configureMerchantProximity(check: (Player) -> boolean)
	merchantProximity = check
end

local VISUAL_PREFIX = "Equip_"

local function nowSeconds(): number
	return os.time()
end

local function ready(player: Player): any?
	local data = PlayerDataService.tryGet(player)
	if not data or player:GetAttribute("WorldReady") ~= true then
		return nil
	end
	return data
end

---------------------------------------------------------------------------
-- Karakter görünümü
---------------------------------------------------------------------------

local function attachPart(character: Model, attach: string): BasePart?
	local found: Instance? = nil
	if attach == "head" then
		found = character:FindFirstChild("Head")
	elseif attach == "hand" then
		found = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	else
		found = character:FindFirstChild("HumanoidRootPart")
	end
	return if found and found:IsA("BasePart") then found else nil
end

local function backOffset(character: Model, anchor: BasePart, attach: string): number
	if attach ~= "back" then
		return 0
	end
	local rear = 0.5
	-- Sadece gövde: eski kozmetiğin hacmi yeni eşyanın ofsetini biriktirmesin.
	for _, name in { "Torso", "UpperTorso", "LowerTorso" } do
		local torso = character:FindFirstChild(name)
		if torso and torso:IsA("BasePart") then
			for _, x in { -0.5, 0.5 } do
				for _, y in { -0.5, 0.5 } do
					for _, z in { -0.5, 0.5 } do
						local corner = torso.CFrame * Vector3.new(torso.Size.X * x, torso.Size.Y * y, torso.Size.Z * z)
						rear = math.max(rear, anchor.CFrame:PointToObjectSpace(corner).Z)
					end
				end
			end
		end
	end
	return WearableFit.backOffset(rear)
end

-- Eşya modeli `assets/Items/<id>`: parçalar çapa parçanın yerel uzayında yazılmıştır (çapa = attachPart); burada klonlanır,
-- fizikten arındırılır (Massless, çarpışma/sorgu kapalı) ve parça başına çapaya kaynaklanır. Model yoksa eşya çizilmez (uyarı verilir).
local missingLooks: { [string]: boolean } = {}

local function buildLook(character: Model, slot: string, item: Config.ItemConfig)
	local look = item.look
	if not look then
		return
	end
	local template = ModelAssets.find("Items", item.id)
	if not template then
		if not missingLooks[item.id] then
			missingLooks[item.id] = true
			warn(`[Inventory] Eşya modeli yok: Items/{item.id}`)
		end
		return
	end
	local attach = template:GetAttribute("Attach")
	local attachName = if typeof(attach) == "string" then attach else look.attach
	local anchor = attachPart(character, attachName)
	if not anchor then
		return
	end
	local offset = backOffset(character, anchor, attachName)
	local model = Instance.new("Model")
	model:SetAttribute("BackOffset", offset)
	model.Name = VISUAL_PREFIX .. slot
	model:SetAttribute("ItemId", item.id)
	local partCount = 0
	for _, source in template:GetChildren() do
		if source:IsA("BasePart") then
			partCount += 1
			local part = source:Clone()
			part.Anchored = false
			part.Massless = true
			part.CanCollide, part.CanTouch, part.CanQuery, part.CastShadow = false, false, false, false
			part.CFrame = anchor.CFrame * CFrame.new(0, 0, offset) * source.CFrame
			part.Parent = model
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = anchor
			weld.Part1 = part
			weld.Parent = part
		end
	end
	model:SetAttribute("PartCount", partCount)
	model.Parent = character
end

local function matchesLook(model: Model, character: Model, item: Config.ItemConfig): boolean
	if model:GetAttribute("ItemId") ~= item.id or not item.look then
		return false
	end
	local template = ModelAssets.find("Items", item.id)
	local attach = template and template:GetAttribute("Attach")
	local attachName = if typeof(attach) == "string" then attach else item.look.attach
	local anchor = attachPart(character, attachName)
	if not anchor then
		return false
	end
	if model:GetAttribute("BackOffset") ~= backOffset(character, anchor, attachName) then
		return false
	end
	local count = 0
	for _, part in model:GetChildren() do
		if part:IsA("BasePart") then
			local weld = part:FindFirstChildWhichIsA("WeldConstraint")
			if not weld or weld.Part0 ~= anchor or weld.Part1 ~= part then
				return false
			end
			count += 1
		end
	end
	return count > 0 and count == model:GetAttribute("PartCount")
end

-- Yalnız değişen slotu giydir; diğer eşyaların parçaları/kaynakları yerinde kalır.
function InventoryService.applyVisuals(player: Player)
	local movementData = PlayerDataService.tryGet(player)
	player:SetAttribute(
		"MovementSpeedMultiplier",
		if movementData then FarmMath.getMovementSpeedMultiplier(movementData) else 1
	)
	local character = player.Character
	if not character then
		return
	end
	local data = PlayerDataService.tryGet(player)
	local kept: { [string]: boolean } = {}
	for _, child in character:GetChildren() do
		if string.sub(child.Name, 1, #VISUAL_PREFIX) ~= VISUAL_PREFIX then
			continue
		end
		local slot = string.sub(child.Name, #VISUAL_PREFIX + 1)
		local itemId = if data then Inventory.equippedId(data, slot) else nil
		local item = if itemId then Config.ITEMS[itemId] else nil
		if item and child:IsA("Model") and not kept[slot] and matchesLook(child, character, item) then
			kept[slot] = true
		else
			child:Destroy()
		end
	end
	if not data then
		return
	end
	for _, slot in Config.ITEM_SLOT_ORDER do
		if kept[slot] then
			continue
		end
		local itemId = Inventory.equippedId(data, slot)
		local item = if itemId then Config.ITEMS[itemId] else nil
		if item then
			buildLook(character, slot, item)
		end
	end
end

-- Karakter geldiğinde (kayıt yüklenince) giydir; parçalar ve veri gecikebilir
local function applyWhenReady(player: Player)
	for _ = 1, 30 do
		local character = player.Character
		if
			character
			and character:FindFirstChild("HumanoidRootPart")
			and character:FindFirstChild("Head")
			and PlayerDataService.tryGet(player)
		then
			InventoryService.applyVisuals(player)
			return
		end
		task.wait(0.5)
	end
end

---------------------------------------------------------------------------
-- Eylemler
---------------------------------------------------------------------------

-- Ekonomik etkisi olan bir takma/çıkarma değişikliği: geçen süre eski etkilerle kapanır, büyüme ilerlemesi korunur,
-- dünya (fiyat etiketleri, düğmeler) ve karakter yenilenir.
local function changeEquipment(player: Player, mutate: () -> ())
	EconomyService.settlePlayer(player)
	local views: { { view: any, speeds: { [string]: number } } } = {}
	for _, farmId in PlayerDataService.getFarmIds(player) do
		local view = PlayerDataService.getFarmView(player, farmId)
		if view then
			table.insert(views, { view = view, speeds = FarmMath.snapshotGrowthSpeeds(view) })
		end
	end
	mutate()
	local now = DateTime.now().UnixTimestampMillis / 1000
	for _, entry in views do
		FarmMath.preserveGrowthProgress(entry.view, entry.speeds, now)
	end
	PlayerDataService.pushState(player)
	PlayerDataService.requestSave(player)
	PlotService.refreshPlayerWorld(player)
	InventoryService.applyVisuals(player)
end

function InventoryService.tryBuy(player: Player, itemId: unknown): (boolean, string?)
	if not RateLimiter.allow(player, "purchase", 0.2) then
		return false, nil
	end
	if typeof(itemId) ~= "string" or not RateLimiter.validId(itemId) or not Config.ITEMS[itemId] then
		return false, "Bilinmeyen eşya"
	end
	local data = ready(player)
	if not data then
		return false, "Veri henüz yüklenmedi"
	end
	local item = Config.ITEMS[itemId]
	if item.rewardOnly then
		return false, "Bu eşya yalnızca rebirth ilerlemesiyle kazanılır."
	end
	if Inventory.owns(data, itemId) then
		return false, "Bu eşyaya zaten sahipsin"
	end
	EconomyService.settlePlayer(player)
	if not PlayerDataService.trySpend(player, item.price, "item") then
		return false, `Yeterli para yok ({FarmMath.formatMoney(item.price)})`
	end
	-- Satın alınca slot boşsa otomatik takılır (etkisi hemen başlasın)
	local autoEquip = Inventory.equippedId(data, item.slot) == nil
	changeEquipment(player, function()
		Inventory.grant(data, itemId)
		if autoEquip then
			Inventory.equip(data, itemId)
		end
	end)
	Metrics.increment("ItemsPurchased")
	return true, nil
end

function InventoryService.tryBuyMerchantOffer(player: Player, itemId: unknown, quote: unknown): (boolean, string?)
	if not RateLimiter.allow(player, "purchase", 0.2) then
		return false, nil
	end
	if not RateLimiter.validId(itemId) or typeof(quote) ~= "table" then
		return false, "Geçersiz istek"
	end
	local data = ready(player)
	if not data then
		return false, "Veri henüz yüklenmedi"
	end
	local offer = Merchant.findOffer(data, player.UserId, nowSeconds(), itemId :: string)
	if not offer then
		return false, "Gezgin tüccar şu an bu eşyayı sunmuyor."
	end
	local expected = quote :: any
	if expected.cycle ~= offer.cycle or expected.expectedPrice ~= offer.price then
		return false, "Tüccarın teklifi değişti. Güncel teklifi tekrar incele."
	end
	if not merchantProximity(player) then
		return false, "Satın almak için meydandaki gezgin tüccara yaklaş."
	end
	EconomyService.settlePlayer(player)
	if not PlayerDataService.trySpend(player, offer.price, "item") then
		return false, `Yeterli para yok ({FarmMath.formatMoney(offer.price)})`
	end
	local item = Config.ITEMS[offer.itemId]
	local autoEquip = Inventory.equippedId(data, item.slot) == nil
	changeEquipment(player, function()
		data.merchant = { key = offer.cycle, bought = true }
		Inventory.grant(data, offer.itemId)
		if autoEquip then
			Inventory.equip(data, offer.itemId)
		end
	end)
	Metrics.increment("MerchantOffersBought")
	return true, nil
end

function InventoryService.tryToggleEquip(player: Player, itemId: unknown): (boolean, string?, boolean?)
	if not RateLimiter.allow(player, "equipItem", 0.3) then
		return false, nil, nil
	end
	if typeof(itemId) ~= "string" or not RateLimiter.validId(itemId) or not Config.ITEMS[itemId] then
		return false, "Bilinmeyen eşya", nil
	end
	local data = ready(player)
	if not data then
		return false, "Veri henüz yüklenmedi", nil
	end
	local item = Config.ITEMS[itemId]
	if not Inventory.owns(data, itemId) then
		return false, "Bu eşyaya sahip değilsin", nil
	end
	local wasEquipped = Inventory.isEquipped(data, itemId)
	changeEquipment(player, function()
		if wasEquipped then
			Inventory.unequip(data, item.slot)
		else
			Inventory.equip(data, itemId)
		end
	end)
	Metrics.increment("ItemsEquipped")
	return true, nil, not wasEquipped
end

function InventoryService.tryUse(player: Player, itemId: unknown, argument: unknown): (boolean, string?)
	if not RateLimiter.allow(player, "useItem", 0.5) then
		return false, nil
	end
	if typeof(itemId) ~= "string" or not RateLimiter.validId(itemId) or not Config.ITEMS[itemId] then
		return false, "Bilinmeyen eşya"
	end
	local data = ready(player)
	if not data then
		return false, "Veri henüz yüklenmedi"
	end
	local item = Config.ITEMS[itemId]
	local queueDetail = if typeof(argument) == "table" then argument :: any else nil
	if queueDetail and item.power and item.power.kind == "weather" and queueDetail.queueAction == "cancel" then
		return SeasonService.cancelQueuedWeather(player)
	end
	local selection = if queueDetail then queueDetail.weatherId else argument
	if typeof(selection) ~= "string" or not RateLimiter.validId(selection) then
		return false, "Geçersiz seçim"
	end
	local choice = selection :: string
	local now = nowSeconds()
	local allowed, reason = Inventory.canUse(data, itemId, now)
	if not allowed then
		return false, reason
	end
	local power = item.power :: Config.ItemPower
	-- Mevsim kişisel kalır; hava asası bütün sunucunun doğal hava zamanlayıcısını yeniler.
	local current = data.envOverride
	local currentSeason = Environment.getSeason(current)
	local message: string
	if power.kind == "season" then
		local season: Config.SeasonConfig? = nil
		for _, candidate in Config.SEASONS do
			if candidate.id == choice then
				season = candidate
			end
		end
		if not season then
			return false, "Bilinmeyen mevsim"
		end
		if currentSeason.id == choice then
			return false, "Zaten bu mevsimdesin"
		end
		EconomyService.settlePlayer(player) -- geçen süre eski mevsimin çarpanıyla kapanır
		-- Yeni mevsimin havası mevsim havuzundan kendiliğinden seçilir; eski hava geçersiz kılması silinir
		data.envOverride = { seasonId = choice, seasonEndsAt = now + Config.SEASON_SECONDS }
		message = `Mevsim değişti: {season.displayName}`
	else
		local weather = Config.WEATHER[choice]
		if not weather then
			return false, "Bilinmeyen hava"
		end
		if SeasonService.hasQueuedWeather(player) then
			return false, "Zaten hava sırasında bekliyorsun."
		end
		if queueDetail then
			if typeof(queueDetail.queueToken) ~= "string" or not RateLimiter.validId(queueDetail.queueToken) then
				return false, "Geçersiz seçim"
			end
			local expectedRun = if data.progression then data.progression.run else 0
			return SeasonService.confirmWeatherQueue(
				player,
				itemId,
				choice,
				queueDetail.queueToken,
				function(): (boolean, string?)
					local currentData = ready(player)
					if
						not currentData
						or (if currentData.progression then currentData.progression.run else 0) ~= expectedRun
					then
						return false, "Veri henüz yüklenmedi"
					end
					return Inventory.canUse(currentData, itemId, nowSeconds())
				end,
				function()
					local currentData = assert(ready(player))
					Inventory.recordUse(currentData, itemId, nowSeconds())
					PlayerDataService.pushState(player)
					PlayerDataService.requestSave(player)
					Metrics.increment("ItemPowersUsed")
				end
			)
		end
		if SeasonService.isWandWeatherBusy() then
			return SeasonService.offerWeatherQueue(player, itemId, choice)
		end
		local changed, errorMessage = SeasonService.setPlayerWeather(choice, player)
		if not changed then
			return false, errorMessage
		end
		message = `Hava değişti: {weather.displayName}`
	end
	Inventory.recordUse(data, itemId, now)
	PlayerDataService.pushState(player)
	PlayerDataService.requestSave(player)
	Metrics.increment("ItemPowersUsed")
	return true, message
end

function InventoryService.init()
	Remotes.get("RequestBuyMerchantOffer").OnServerEvent
		:Connect(function(player: Player, itemId: unknown, requestId: unknown, expectedFarmId: unknown, quote: unknown)
			if not RateLimiter.acceptRequest(player, requestId) then
				return
			end
			if not RequestGuard.activeFarm(player, requestId, expectedFarmId) then
				return
			end
			local ok, message = InventoryService.tryBuyMerchantOffer(player, itemId, quote)
			RequestGuard.reply(
				player,
				requestId,
				ok,
				if ok then "Tüccardan indirimli tur eşyası alındı." else message
			)
		end)
	Remotes.get("RequestBuyItem").OnServerEvent:Connect(function(player: Player, itemId: unknown, requestId: unknown)
		if not RateLimiter.acceptRequest(player, requestId) then
			return
		end
		local ok, err = InventoryService.tryBuy(player, itemId)
		RequestGuard.reply(
			player,
			requestId,
			ok,
			if ok then `{Config.ITEMS[itemId :: string].displayName} satın alındı!` else err
		)
	end)
	Remotes.get("RequestEquipItem").OnServerEvent:Connect(function(player: Player, itemId: unknown, requestId: unknown)
		if not RateLimiter.acceptRequest(player, requestId) then
			return
		end
		local ok, err, equipped = InventoryService.tryToggleEquip(player, itemId)
		local message = err
		if ok then
			local name = Config.ITEMS[itemId :: string].displayName
			message = if equipped then `{name} takıldı` else `{name} çıkarıldı`
		end
		RequestGuard.reply(player, requestId, ok, message)
	end)
	Remotes.get("RequestUseItem").OnServerEvent
		:Connect(
			function(player: Player, itemId: unknown, requestId: unknown, expectedFarmId: unknown, argument: unknown)
				if not RateLimiter.acceptRequest(player, requestId) then
					return
				end
				if not RequestGuard.activeFarm(player, requestId, expectedFarmId) then
					return
				end
				local ok, message = InventoryService.tryUse(player, itemId, argument)
				-- Teklif kendi penceresini açar; bildirimsiz cevap pending kilidini kaldırır.
				if ok and message == nil then
					Remotes.get("PurchaseResult"):FireClient(player, requestId, true)
				else
					RequestGuard.reply(player, requestId, ok, message)
				end
			end
		)

	local function watch(player: Player)
		player.CharacterAdded:Connect(function()
			task.spawn(applyWhenReady, player)
		end)
		if player.Character then
			task.spawn(applyWhenReady, player)
		end
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
end

return InventoryService
