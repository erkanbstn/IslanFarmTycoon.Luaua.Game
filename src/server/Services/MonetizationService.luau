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
local TelemetryService = require(script.Parent:WaitForChild("TelemetryService"))
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
	local income = FarmMath.computeIncomePerSecond(data)
	return math.floor(math.max(income * 3600 * (product.incomeHours or 1), Config.PRODUCT_MIN_INCOME_PACK))
end

-- Kalıcı etki yield etmez ve Roblox/presentation servisi çağırmaz; makbuzla aynı blokta uygulanır.
local productEffects: { [string]: (data: any, product: Config.ProductConfig) -> boolean } = {
	instantProduction = function(data)
		-- Bozuk iş listesini mutasyondan önce doğrula; yarım uygulanmış etki yeniden ödüllendirilmesin.
		if typeof(data.production) ~= "table" then
			return false
		end
		for _, job in data.production do
			if typeof(job) ~= "table" then
				return false
			end
		end
		for _, job in data.production do
			job.readyAt = 0
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
	-- Makbuz ve etki bellekte yield etmeden birlikte uygulanır; save ikisini aynı görüntüyle yazar.
	-- Ödül verilemezse makbuz günlükten çıkar; Roblox yeniden denediğinde ödül gerçekten verilir.
	local outcome = ReceiptLog.grant(data, id, function(): boolean
		return applyProduct(data, product)
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
		PlayerDataService.markDirty(player)
		presentProduct(player, data, product)
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
