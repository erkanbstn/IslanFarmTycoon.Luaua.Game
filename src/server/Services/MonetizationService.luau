--!strict
-- Gelir modeli: oyun geçitleri (kalıcı çarpan/avantaj) ve tek seferlik ürünler.
-- Kimlikler Config.PRODUCTS içindedir; id = 0 ürün henüz oluşturulmadığı için kapalıdır.
--
-- Güvenlik:
--  * Geçit sahipliği MarketplaceService'ten doğrulanır ve yalnızca sunucuda `data.passes`'a yazılır.
--  * ProcessReceipt çift ödemeye karşı korunur: makbuz kimliği kayda yazılır, ödül yalnızca ilk kez verilir
--    ve `PurchaseGranted` ancak kayıt başarıyla yazıldıktan sonra döner (aksi halde `NotProcessedYet`).
--  * Client yalnızca "şu ürünü satın almak istiyorum" der; fiyat ve ödül sunucuda belirlenir.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local FarmMath = require(Shared:WaitForChild("Modules"):WaitForChild("FarmMath"))
local Progression = require(Shared:WaitForChild("Modules"):WaitForChild("Progression"))

local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))
local TelemetryService = require(script.Parent:WaitForChild("TelemetryService"))
local EconomyService = require(script.Parent:WaitForChild("EconomyService"))
local PlotService = require(script.Parent:WaitForChild("PlotService"))
local RateLimiter = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("RateLimiter"))
local ReceiptLog = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("ReceiptLog"))
local Metrics = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("Metrics"))

local MonetizationService = {}

local initialized = false

local function findProduct(productId: number): (string?, Config.ProductConfig?)
	for key, product in Config.PRODUCTS.products do
		if product.id ~= 0 and product.id == productId then
			return key, product
		end
	end
	return nil, nil
end

local function findPassKey(passId: number): string?
	for key, pass in Config.PRODUCTS.passes do
		if pass.id ~= 0 and pass.id == passId then
			return key
		end
	end
	return nil
end

-- Sahip olunan geçitleri MarketplaceService'ten okuyup kayda (kaydedilmeyen `passes`) yazar.
-- Sorgu hata verirse o geçidin önceki değeri korunur (geçici bir Roblox hatası sahip olunan geçidi düşürmesin) ve
-- PASS_RETRY_SECONDS sonra en çok PASS_RETRY_LIMIT kez yeniden denenir.
local PASS_RETRY_SECONDS = 30
local PASS_RETRY_LIMIT = 3

function MonetizationService.refreshPasses(player: Player, attempt: number?)
	local data = PlayerDataService.tryGet(player)
	if not data then
		return
	end
	-- Sorgular yield eder; satın alma olayı aynı tabloyu bu sırada değiştirebilir.
	local previous = table.clone(data.passes or {})
	local failed = false
	local passes: { [string]: boolean } = {}
	for key, pass in Config.PRODUCTS.passes do
		if pass.id == 0 then
			continue
		end
		local ok, owned = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, pass.id)
		if ok and owned == true then
			passes[key] = true
		elseif not ok then
			failed = true
			if previous[key] then
				passes[key] = true
			end
			warn(`[Monetization] Geçit sahipliği okunamadı user={player.UserId} pass={key}: {owned}`)
		end
	end
	-- Oyuncu ayrılmış ya da kayıt oturumu kapanmış olabilir (yield sonrası yeniden doğrula).
	local current = PlayerDataService.tryGet(player)
	if not current or current ~= data then
		return
	end
	-- Sorgu başladıktan sonra doğrulanan yeni sahipliği eski false yanıtıyla silme.
	local currentPasses: { [string]: boolean } = current.passes or {}
	for key, owned in currentPasses do
		if owned and not previous[key] then
			passes[key] = true
		end
	end
	current.passes = passes
	PlayerDataService.pushState(player)
	local tries = attempt or 0
	if failed and tries < PASS_RETRY_LIMIT then
		task.delay(PASS_RETRY_SECONDS, MonetizationService.refreshPasses, player, tries + 1)
	end
end

-- Desteklenen ürün etkileri tek kaynaktır: processReceipt yalnızca burada olanları işler.
local function incomePackAmount(data: any, product: Config.ProductConfig): number
	local income = FarmMath.getPermanentReferenceIncome(data)
	return math.floor(math.max(income * 3600 * (product.incomeHours or 1), Config.PRODUCT_MIN_INCOME_PACK))
end

-- Kalıcı etki yield etmez ve Roblox/presentation servisi çağırmaz; makbuzla aynı blokta uygulanır.
local productEffects: { [string]: (data: any, product: Config.ProductConfig) -> boolean } = {
	instantGrowth = function(data, product)
		if typeof(data.animals) ~= "table" then
			return false
		end
		local young = false
		for _, animal in data.animals do
			if
				typeof(animal) ~= "table"
				or (animal.stage ~= "adult" and animal.stage ~= "young" and animal.stage ~= "calf")
			then
				return false
			end
			young = young or animal.stage ~= "adult"
		end
		if not young then
			local compensation = product.goldAmount
			if
				not compensation
				or compensation <= 0
				or (data.gold or 0) + compensation > Config.PROGRESSION.gold.maxBalance
			then
				return false
			end
			data.gold = (data.gold or 0) + compensation
			return true
		end
		for _, animal in data.animals do
			if animal.stage ~= "adult" then
				animal.bornAt, animal.stage = 0, "adult"
			end
		end
		return true
	end,
	goldPack = function(data, product)
		local amount = product.goldAmount
		if
			not amount
			or amount <= 0
			or amount % 1 ~= 0
			or (data.gold or 0) + amount > Config.PROGRESSION.gold.maxBalance
		then
			return false
		end
		data.gold = (data.gold or 0) + amount
		return true
	end,
	runDouble = function(data)
		local state = data.progression
		if not state then
			return false
		end
		-- Geciken/ikinci ücretli hak kaybolmaz; aynı turda 4x yaratmadan sonraki tura taşınır.
		if
			state.count >= Config.PROGRESSION.maxRebirth
			and (state.runDouble or (data.passes and data.passes.double_income))
		then
			local compensation = Config.PROGRESSION.terminalDoubleGold
			if (data.gold or 0) + compensation > Config.PROGRESSION.gold.maxBalance then
				return false
			end
			data.gold = (data.gold or 0) + compensation
		elseif state.runDouble or (data.passes and data.passes.double_income) or Progression.canRebirth(data) then
			if (state.doubleCredits or 0) >= 1000000 then
				return false
			end
			state.doubleCredits = (state.doubleCredits or 0) + 1
		else
			state.runDouble = true
		end
		return true
	end,
	permanentOffer = function(data, product)
		local offer = if product.offerId then Config.PROGRESSION.permanentOffers[product.offerId] else nil
		if not offer then
			return false
		end
		data.owned = data.owned or { items = {}, conveniences = {} }
		local rights = if offer.kind == "item" then data.owned.items else data.owned.conveniences
		if rights[offer.id] then
			-- Mağaza tekrar almayı engeller; geç makbuzla çakışan satın alma bedelsiz silinmez.
			if (data.gold or 0) + offer.goldCost > Config.PROGRESSION.gold.maxBalance then
				return false
			end
			data.gold = (data.gold or 0) + offer.goldCost
		else
			rights[offer.id] = true
			if offer.kind == "item" then
				data.inventory = data.inventory or { items = {}, equipped = {}, uses = {} }
				data.inventory.items[offer.id] = true
			end
		end
		return true
	end,
	incomePack = function(data, product)
		local amount = incomePackAmount(data, product)
		local cash = math.min(1e15, data.cash + amount)
		local lifetimeEarned = math.min(1e18, (data.lifetimeEarned or 0) + amount)
		data.cash, data.lifetimeEarned = cash, lifetimeEarned
		return true
	end,
}

local function isSupported(effect: any): boolean
	return typeof(effect) == "string" and productEffects[effect] ~= nil
end

local function applyProduct(data: any, product: Config.ProductConfig): boolean
	local effect = product.effect
	local handler = if effect ~= nil then productEffects[effect] else nil
	return handler ~= nil and handler(data, product)
end

-- Bildirim/telemetri hatası kalıcı ödülü ve tekrar korumasını geri almamalı.
local function presentProduct(player: Player, data: any, product: Config.ProductConfig)
	local ok, message = pcall(function()
		if product.effect == "incomePack" then
			PlayerDataService.pushEconomy(player)
			TelemetryService.economy(player, "iap", incomePackAmount(data, product), data.cash)
		end
		PlayerDataService.pushState(player)
		PlotService.refreshPlayerWorld(player)
		Metrics.increment("ProductsGranted")
		Remotes.get("Notify"):FireClient(player, `{product.displayName} etkinleştirildi!`, "success")
	end)
	if not ok then
		warn(`[Monetization] Ödül uygulandı, sunum başarısız user={player.UserId}: {message}`)
	end
end

-- Roblox aynı makbuzu tekrar gönderebilir; ödül yalnızca ilk kez verilir.
function MonetizationService.processReceipt(receiptInfo: any): Enum.ProductPurchaseDecision
	if typeof(receiptInfo) ~= "table" or typeof(receiptInfo.PurchaseId) ~= "string" then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet -- Oyuncu döndüğünde Roblox yeniden dener
	end
	local data = PlayerDataService.tryGet(player)
	if not data or player:GetAttribute("WorldReady") ~= true then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	-- Eski yedekteki makbuz geçmişi eksik olabilir; elle uzlaştırılmadan yeni/tekrar ödül verme.
	if data.transfers and data.transfers.quarantined then
		warn(`[Monetization] Finansal kayıt uzlaştırma bekliyor user={player.UserId}; makbuz bekletildi`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local _, product = findProduct(receiptInfo.ProductId)
	if not product then
		warn(`[Monetization] Bilinmeyen ürün {tostring(receiptInfo.ProductId)}; makbuz işlenmedi`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if not isSupported(product.effect) then
		warn(`[Monetization] Ürün etkisi geçersiz {tostring(product.effect)}; makbuz işlenmedi`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local id = receiptInfo.PurchaseId
	if ReceiptLog.has(data, id) then
		return if PlayerDataService.save(player)
			then Enum.ProductPurchaseDecision.PurchaseGranted
			else Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if ReceiptLog.isFull(data) then
		Metrics.increment("ReceiptCapacityBlocked")
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	-- Makbuz ve etki bellekte yield etmeden birlikte uygulanır; save ikisini aynı görüntüyle yazar.
	-- Ödül verilemezse makbuz günlükten çıkar; Roblox yeniden denediğinde ödül gerçekten verilir.
	EconomyService.settlePlayer(player)
	local outcome = "failed"
	local acquiredSlot: string? = nil
	local persisted = PlayerDataService.transactAccount(player, function(current: any): (boolean, string?)
		acquiredSlot = nil
		if current.transfers and current.transfers.quarantined then
			return false, nil
		end
		-- Kalıcı teklif ilk kez veriliyorsa edinim sayılır (zaten sahipse iade yolu: edinim yok).
		local fresh: string? = nil
		if product.effect == "permanentOffer" and product.offerId then
			local offer = Config.PROGRESSION.permanentOffers[product.offerId]
			if offer then
				local owned = current.owned
				local rights = if owned then (if offer.kind == "item" then owned.items else owned.conveniences) else nil
				if not (rights and rights[offer.id]) then
					local item = if offer.kind == "item" then Config.ITEMS[offer.itemId or offer.id] else nil
					fresh = if item then item.slot else "convenience"
				end
			end
		end
		outcome = ReceiptLog.grant(current, id, function(): boolean
			return applyProduct(current, product)
		end)
		if outcome == "granted" then
			acquiredSlot = fresh
		end
		return outcome == "granted" or outcome == "duplicate", nil
	end, function()
		EconomyService.startPlayer(player)
	end)
	if outcome == "full" then
		Metrics.increment("ReceiptCapacityBlocked")
		warn(
			`[Monetization] Makbuz kapasitesi dolu user={player.UserId}; yeni ödül kalıcı günlük genişletilene kadar bekliyor`
		)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	elseif outcome == "failed" then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	elseif outcome == "granted" then
		if persisted then
			presentProduct(player, data, product)
			-- Yalnızca ilk işlenen makbuz buraya gelir; tekrar gelen makbuz yukarıdaki "duplicate" yolunda döner.
			if acquiredSlot then
				pcall(TelemetryService.acquired, player, "robux", acquiredSlot)
			end
		end
	end
	-- PurchaseGranted yalnızca kayıt diske yazıldıysa; yazılamazsa Roblox makbuzu yeniden gönderir
	-- ve yukarıdaki kontrol ödülü tekrar vermeden yeniden kaydetmeyi dener.
	if persisted then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

function MonetizationService.init()
	if initialized then
		return
	end
	initialized = true

	MarketplaceService.ProcessReceipt = MonetizationService.processReceipt

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(
		function(player: Player, passId: number, purchased: boolean)
			if not purchased then
				return
			end
			local key = findPassKey(passId)
			local data = PlayerDataService.tryGet(player)
			if not key or not data then
				return
			end
			local passes: { [string]: boolean } = data.passes or {}
			data.passes = passes
			passes[key] = true
			Metrics.increment("PassesPurchased")
			PlayerDataService.pushState(player)
			Remotes.get("Notify")
				:FireClient(player, `{Config.PRODUCTS.passes[key].displayName} etkinleştirildi!`, "success")
		end
	)

	-- Client yalnızca anahtar gönderir; kimlik ve fiyat sunucuda çözülür.
	Remotes.get("RequestPromptProduct").OnServerEvent:Connect(function(player: Player, kind: unknown, key: unknown)
		if not RateLimiter.allow(player, "promptProduct", 1) then
			return
		end
		if (kind ~= "pass" and kind ~= "product") or not RateLimiter.validId(key) then
			return
		end
		if player:GetAttribute("WorldReady") ~= true then
			return
		end
		local product = if kind == "pass"
			then Config.PRODUCTS.passes[key :: string]
			else Config.PRODUCTS.products[key :: string]
		if not product or product.id == 0 then
			Remotes.get("Notify"):FireClient(player, "Bu ürün henüz satışta değil", "error")
			return
		end
		local data = PlayerDataService.tryGet(player)
		if not data or (data.transfers and data.transfers.quarantined) then
			return
		end
		if
			kind == "pass"
			and (
				(data.passes and data.passes[key :: string])
				or (key == "auto_collector" and data.owned and data.owned.conveniences.auto_collect)
			)
		then
			Remotes.get("Notify"):FireClient(player, "Bu ürüne zaten sahipsin", "info")
			return
		end
		if kind == "product" and product.effect == "permanentOffer" and product.offerId then
			local offer = Config.PROGRESSION.permanentOffers[product.offerId]
			local rights = data.owned
				and (if offer and offer.kind == "item" then data.owned.items else data.owned.conveniences)
			if
				not offer
				or (rights and rights[product.offerId])
				or (product.offerId == "auto_collect" and data.passes and data.passes.auto_collector)
			then
				Remotes.get("Notify"):FireClient(player, "Bu ürüne zaten sahipsin", "info")
				return
			end
		elseif kind == "product" and product.effect == "instantGrowth" then
			local young = false
			for _, animal in data.animals do
				young = young or animal.stage ~= "adult"
			end
			if not young then
				Remotes.get("Notify"):FireClient(player, "Bu çiftlikte büyütülecek genç hayvan yok", "info")
				return
			end
		elseif kind == "product" and product.effect == "runDouble" then
			if
				(data.progression and data.progression.runDouble)
				or (data.passes and data.passes.double_income)
				or Progression.canRebirth(data)
			then
				Remotes.get("Notify"):FireClient(player, "Bu tur için ek gelir ürünü alınamaz", "info")
				return
			end
		end
		if kind == "pass" then
			MarketplaceService:PromptGamePassPurchase(player, product.id)
		else
			MarketplaceService:PromptProductPurchase(player, product.id)
		end
	end)
end

return MonetizationService
