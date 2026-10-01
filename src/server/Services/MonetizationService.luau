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

local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))
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
	local previous = data.passes or {}
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
	if not current then
		return
	end
	current.passes = passes
	PlayerDataService.pushState(player)
	local tries = attempt or 0
	if failed and tries < PASS_RETRY_LIMIT then
		task.delay(PASS_RETRY_SECONDS, MonetizationService.refreshPasses, player, tries + 1)
	end
end

-- Desteklenen ürün etkileri tek kaynaktır: processReceipt yalnızca burada olanları işler.
local productEffects: { [string]: (player: Player, data: any, product: Config.ProductConfig) -> boolean } = {
	instantProduction = function(player, data)
		for _, job in data.production do
			job.readyAt = 0
		end
		PlayerDataService.pushState(player)
		return true
	end,
	incomePack = function(player, data, product)
		local income = FarmMath.computeIncomePerSecond(data)
		local amount = math.max(income * 3600 * (product.incomeHours or 1), Config.PRODUCT_MIN_INCOME_PACK)
		PlayerDataService.addCash(player, math.floor(amount), "iap")
		PlayerDataService.pushState(player)
		return true
	end,
}

local function isSupported(effect: any): boolean
	return typeof(effect) == "string" and productEffects[effect] ~= nil
end

local function applyProduct(player: Player, data: any, product: Config.ProductConfig): boolean
	local effect = product.effect
	local handler = if effect ~= nil then productEffects[effect] else nil
	return handler ~= nil and handler(player, data, product)
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
	-- Makbuz önce yazılır, sonra ödül verilir: çökme ya da tekrar aynı ödülü ikinci kez üretmez.
	-- Ödül verilemezse makbuz günlükten çıkar; Roblox yeniden denediğinde ödül gerçekten verilir.
	local outcome = ReceiptLog.grant(data, id, function(): boolean
		return applyProduct(player, data, product)
	end)
	if outcome == "failed" then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	elseif outcome == "granted" then
		Metrics.increment("ProductsGranted")
		Remotes.get("Notify"):FireClient(player, `{product.displayName} etkinleştirildi!`, "success")
	end
	-- PurchaseGranted yalnızca kayıt diske yazıldıysa; yazılamazsa Roblox makbuzu yeniden gönderir
	-- ve yukarıdaki kontrol ödülü tekrar vermeden yeniden kaydetmeyi dener.
	if PlayerDataService.save(player) then
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
			local passes = data.passes
			if not passes then
				passes = {}
				data.passes = passes
			end
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
		if kind == "pass" and data and data.passes and data.passes[key :: string] then
			Remotes.get("Notify"):FireClient(player, "Bu ürüne zaten sahipsin", "info")
			return
		end
		if kind == "pass" then
			MarketplaceService:PromptGamePassPurchase(player, product.id)
		else
			MarketplaceService:PromptProductPurchase(player, product.id)
		end
	end)
end

return MonetizationService
