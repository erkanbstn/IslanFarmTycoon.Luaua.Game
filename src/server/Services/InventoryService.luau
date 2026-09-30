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

local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))
local PlotService = require(script.Parent:WaitForChild("PlotService"))
local EconomyService = require(script.Parent:WaitForChild("EconomyService"))
local SeasonService = require(script.Parent:WaitForChild("SeasonService"))
local RateLimiter = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("RateLimiter"))
local Metrics = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("Metrics"))

local InventoryService = {}

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

local function buildLook(character: Model, slot: string, item: Config.ItemConfig)
	local look = item.look
	if not look then
		return
	end
	local anchor = attachPart(character, look.attach)
	if not anchor then
		return
	end
	local model = Instance.new("Model")
	model.Name = VISUAL_PREFIX .. slot
	for _, spec in look.parts do
		local part = Instance.new("Part")
		part.Name = "Piece"
		part.Shape = if spec.shape == "Ball"
			then Enum.PartType.Ball
			elseif spec.shape == "Cylinder" then Enum.PartType.Cylinder
			else Enum.PartType.Block
		part.Size = Vector3.new(spec.size[1], spec.size[2], spec.size[3])
		part.Color = spec.color
		local ok, material = pcall(function()
			return (Enum.Material :: any)[spec.material or "SmoothPlastic"]
		end)
		part.Material = if ok and material then material else Enum.Material.SmoothPlastic
		part.Massless = true
		part.CanCollide, part.CanTouch, part.CanQuery, part.CastShadow = false, false, false, false
		local angle = spec.angle or { 0, 0, 0 }
		part.CFrame = anchor.CFrame
			* CFrame.new(spec.offset[1], spec.offset[2], spec.offset[3])
			* CFrame.Angles(math.rad(angle[1]), math.rad(angle[2]), math.rad(angle[3]))
		part.Parent = model
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = anchor
		weld.Part1 = part
		weld.Parent = part
	end
	model.Parent = character
end

-- Takılı eşyaları karaktere yeniden giydirir (çıkarılanlar kalkar, takılanlar eklenir)
function InventoryService.applyVisuals(player: Player)
	local character = player.Character
	if not character then
		return
	end
	for _, child in character:GetChildren() do
		if string.sub(child.Name, 1, #VISUAL_PREFIX) == VISUAL_PREFIX then
			child:Destroy()
		end
	end
	local data = PlayerDataService.tryGet(player)
	if not data then
		return
	end
	for _, slot in Config.ITEM_SLOT_ORDER do
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
			local speeds: { [string]: number } = {}
			for _, animal in view.animals do
				speeds[animal.animalId] = FarmMath.getGrowthSpeed(view, animal.animalId)
			end
			table.insert(views, { view = view, speeds = speeds })
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
	if Inventory.owns(data, itemId) then
		return false, "Bu eşyaya zaten sahipsin"
	end
	EconomyService.settlePlayer(player)
	if not PlayerDataService.trySpend(player, item.price) then
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
	if typeof(argument) ~= "string" or not RateLimiter.validId(argument) then
		return false, "Geçersiz seçim"
	end
	local data = ready(player)
	if not data then
		return false, "Veri henüz yüklenmedi"
	end
	local item = Config.ITEMS[itemId]
	local now = nowSeconds()
	local allowed, reason = Inventory.canUse(data, itemId, now)
	if not allowed then
		return false, reason
	end
	local power = item.power :: Config.ItemPower
	local ok: boolean, err: string?
	local message: string
	if power.kind == "season" then
		local season: Config.SeasonConfig? = nil
		for _, candidate in Config.SEASONS do
			if candidate.id == argument then
				season = candidate
			end
		end
		if not season then
			return false, "Bilinmeyen mevsim"
		end
		if Environment.getSeason().id == argument then
			return false, "Zaten bu mevsimdesin"
		end
		ok, err = SeasonService.setPlayerSeason(argument)
		message = `Mevsim değişti: {season.displayName}`
	else
		local weather = Config.WEATHER[argument]
		if not weather then
			return false, "Bilinmeyen hava"
		end
		-- Yalnızca bu mevsimde görülebilen hava türleri seçilebilir (kışın yağmur, yazın kar gibi tuhaflıklar olmasın)
		if not Environment.getSeason().weather[argument] then
			return false, "Bu hava bu mevsimde seçilemez"
		end
		if Environment.getWeather().id == argument then
			return false, "Hava zaten böyle"
		end
		ok, err = SeasonService.setPlayerWeather(argument)
		message = `Hava değişti: {weather.displayName}`
	end
	if not ok then
		return false, err
	end
	Inventory.recordUse(data, itemId, now)
	PlayerDataService.pushState(player)
	PlayerDataService.requestSave(player)
	Metrics.increment("ItemPowersUsed")
	return true, message
end

local function respond(player: Player, requestId: unknown, ok: boolean, message: string?)
	if not ok and message == nil then
		if typeof(requestId) ~= "number" or not RateLimiter.allow(player, "purchaseThrottleReply", 0.5) then
			return
		end
		message = "Çok hızlı işlem yapıyorsun; biraz bekle."
	end
	if message then
		if typeof(requestId) == "number" then
			Remotes.get("PurchaseResult"):FireClient(player, requestId, ok, message)
		else
			Remotes.get("Notify"):FireClient(player, message, if ok then "success" else "error")
		end
	end
end

function InventoryService.init()
	Remotes.get("RequestBuyItem").OnServerEvent:Connect(function(player: Player, itemId: unknown, requestId: unknown)
		if not RateLimiter.acceptRequest(player, requestId) then
			return
		end
		local ok, err = InventoryService.tryBuy(player, itemId)
		respond(
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
		respond(player, requestId, ok, message)
	end)
	Remotes.get("RequestUseItem").OnServerEvent
		:Connect(
			function(player: Player, itemId: unknown, requestId: unknown, _expectedFarmId: unknown, argument: unknown)
				if not RateLimiter.acceptRequest(player, requestId) then
					return
				end
				local ok, message = InventoryService.tryUse(player, itemId, argument)
				respond(player, requestId, ok, message)
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
