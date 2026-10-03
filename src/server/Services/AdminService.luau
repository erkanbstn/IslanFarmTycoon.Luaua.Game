--!strict
-- Kendi bakiyesi ve sunucunun hava/mevsimi. Hedef oyuncu veya client miktar hesabı kabul edilmez.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local GameTypes = require(Shared:WaitForChild("GameTypes"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local FarmMath = require(Shared:WaitForChild("Modules"):WaitForChild("FarmMath"))
local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))
local EconomyService = require(script.Parent:WaitForChild("EconomyService"))
local PlotService = require(script.Parent:WaitForChild("PlotService"))
local HttpService = game:GetService("HttpService")
local SeasonService = require(script.Parent:WaitForChild("SeasonService"))
local SaveCodec = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("SaveCodec"))
local FarmProfiles = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("FarmProfiles"))
local AdminPolicy = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("AdminPolicy"))
local RateLimiter = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("RateLimiter"))

local AdminService = {}
local highWater: { [Player]: number } = {}
local initialized = false

local function validValue(action: string, value: unknown): boolean
	if action == "setCash" or action == "addCash" then
		return AdminPolicy.validCash(value, action == "addCash")
	end
	return typeof(value) == "string" and #value > 0 and #value <= 32 and string.match(value, "^[a-z_]+$") ~= nil
end

local function validSeason(id: string): boolean
	for _, season in Config.SEASONS do
		if season.id == id then
			return true
		end
	end
	return false
end

-- Bir çiftlik görünümünde (etkin kayıt ya da park edilmiş çiftlik) seçilen adaları açar/doldurur/büyütür; para harcamaz.
-- Gerçek satın almayla aynı yol: büyüme hızı anlığı alınır, türetilmiş durum (açık adalar/bölgeler) yeniden hesaplanır.
local function maxFarmView(
	view: any,
	farmId: string,
	islandIds: { string },
	grow: boolean,
	unlockAll: boolean,
	fill: boolean
): (number, number)
	if grow then
		for _, animal in view.animals do
			animal.bornAt = 0
			animal.stage = "adult"
		end
	end
	if unlockAll then
		local previousSpeeds = FarmMath.snapshotGrowthSpeeds(view)
		local function unlock(upgradeId: string)
			local upgrade = Config.getUpgrade(upgradeId)
			if not upgrade or view.purchased[upgradeId] then
				return
			end
			for _, requiredId in upgrade.requires do
				unlock(requiredId)
			end
			view.purchased[upgradeId] = true
		end
		for _, islandId in islandIds do
			for _, upgrade in Config.UPGRADES do
				if Config.getUpgradeIsland(upgrade) == islandId and Config.upgradeInTheme(upgrade, farmId) then
					unlock(upgrade.id)
				end
			end
		end
		FarmMath.applyDerived(view) -- açık bölgeler satın alınanlardan türer
		-- Açılan bölgelerin yapı geliştirme seviyesi de tam olur (otlaktaki çiftlik evi gibi seviyeyle beliren yapılar görünsün)
		local scope: { [string]: boolean } = {}
		for _, islandId in islandIds do
			scope[islandId] = true
		end
		local expansions = view.expansions or {}
		view.expansions = expansions
		for zoneId, zone in Config.ZONES do
			if scope[zone.island] and view.unlockedZones[zoneId] then
				expansions[zoneId] = Config.BUILD_UPGRADES.maxLevel
			end
		end
		FarmMath.applyDerived(view)
		FarmMath.preserveGrowthProgress(view, previousSpeeds, os.time())
	end
	local added, sent = 0, 0
	if fill then
		-- Seçilen adalardaki bütün bölgeleri ve satın alınmış eklentileri yetişkin hayvanla doldur.
		local serial = 0
		local inScope: { [string]: boolean } = {}
		for _, islandId in islandIds do
			inScope[islandId] = true
		end
		for zoneId, zone in Config.ZONES do
			if inScope[zone.island] and view.unlockedZones[zoneId] then
				for _ = FarmMath.countInZone(view, zoneId) + 1, FarmMath.getZoneCapacity(view, zoneId) do
					serial += 1
					table.insert(view.animals, {
						uid = string.format("adm%d_%d_%d_%s", os.time(), math.floor(os.clock() * 1000), serial, farmId),
						animalId = Config.getZoneAnimals(zone, farmId)[1],
						zoneId = zoneId,
						stage = "adult",
						bornAt = 0,
					})
					added += 1
				end
			end
		end
		-- Satın alınmış eklentiler: ana bölgedeki boşta yetişkinleri eklentiye gönder (süreli görev; bölgeden yeni
		-- hayvan eklenmez çünkü eklentideki hayvanın ana bölgedeki yeri ayrılı kalır).
		local sentNow = os.time()
		for extensionId, extension in Config.EXTENSIONS do
			local upgrade = Config.getExtensionUpgrade(extensionId)
			if inScope[extension.island] and upgrade and view.purchased[upgrade.id] then
				local room = FarmMath.getExtensionCapacity(view, extensionId)
					- FarmMath.countInExtension(view, extensionId, sentNow)
				for _, animal in view.animals do
					if room <= 0 then
						break
					end
					if
						animal.animalId == extension.animalId
						and animal.zoneId == extension.sourceZoneId
						and FarmMath.getActiveTask(animal, sentNow) == nil
					then
						animal.extensionId = extensionId
						animal.task = {
							kind = "extension",
							id = extensionId,
							startedAt = sentNow,
							endsAt = sentNow + extension.stayDuration,
						}
						room -= 1
						sent += 1
					end
				end
			end
		end
	end
	return added, sent
end

local function execute(player: Player, action: string, value: unknown): (boolean, string)
	if action == "setCash" or action == "addCash" then
		if player:GetAttribute("WorldReady") ~= true or not PlayerDataService.tryGet(player) then
			return false, "Çiftliğin henüz hazır değil"
		end
		EconomyService.settlePlayer(player)
		local data = PlayerDataService.tryGet(player)
		if not data then
			return false, "Kayıt oturumu artık etkin değil"
		end
		local amount = value :: number
		if action == "addCash" and data.cash + amount > 1e15 then
			return false, "Bakiye sınırı aşılıyor"
		end
		data.cash = if action == "setCash" then amount else data.cash + amount
		PlayerDataService.pushState(player)
		PlayerDataService.requestSave(player)
		return true, "Para güncellendi"
	end
	if action == "grantItems" or action == "clearItems" then
		-- Test aracı: bütün eşyaları ver (takmaz) ya da envanteri boşalt; para harcamaz, yalnızca yöneticinin kendi profili.
		if player:GetAttribute("WorldReady") ~= true then
			return false, "Çiftliğin henüz hazır değil"
		end
		local data = PlayerDataService.tryGet(player)
		if not data then
			return false, "Kayıt oturumu artık etkin değil"
		end
		EconomyService.settlePlayer(player) -- takılı eşyaların etkisi değişebilir: geçen süre eski etkiyle kapanır
		local inventory: GameTypes.InventoryData = (if action == "clearItems" then nil else data.inventory)
			or { items = {}, equipped = {}, uses = {} }
		data.inventory = inventory
		if action == "grantItems" then
			for itemId in Config.ITEMS do
				inventory.items[itemId] = true
			end
		end
		PlayerDataService.pushState(player)
		PlayerDataService.requestSave(player)
		PlotService.refreshPlayerWorld(player)
		return true,
			if action == "grantItems" then "Bütün eşyalar verildi (Envanter'den tak)" else "Envanter boşaltıldı"
	end
	if action == "fillBarn" then
		-- Test aracı: ahır deposunu bütün ürünlerden kapasiteye kadar doldurur (yalnızca yöneticinin kendi profili).
		if player:GetAttribute("WorldReady") ~= true then
			return false, "Çiftliğin henüz hazır değil"
		end
		local data = PlayerDataService.tryGet(player)
		if not data then
			return false, "Kayıt oturumu artık etkin değil"
		end
		for goodsId in Config.GOODS do
			FarmMath.addGoods(data, goodsId, FarmMath.getGoodsSpace(data, goodsId))
		end
		PlayerDataService.pushState(player)
		PlayerDataService.requestSave(player)
		return true, "Ahır deposu doldu"
	end
	if
		action == "forceMerchant"
		or action == "forceGolden"
		or action == "completeSeason"
		or action == "resetEvents"
	then
		-- Test aracı: rastgele olayları hemen görmek için; yalnızca yöneticinin kendi profili, para vermez.
		-- Çalışma anı işaretleri (`adminForce`) kaydedilmez; mevsim hedefini EngagementService tamamlar.
		if player:GetAttribute("WorldReady") ~= true then
			return false, "Çiftliğin henüz hazır değil"
		end
		local data = PlayerDataService.tryGet(player)
		if not data then
			return false, "Kayıt oturumu artık etkin değil"
		end
		local force: { [string]: any } = data.adminForce or {}
		data.adminForce = force
		local message = ""
		if action == "forceMerchant" then
			force.merchantUntil = os.time() + Config.MERCHANT.visitSeconds
			data.merchant = nil
			message = "Gezgin tüccar geldi (Pazar penceresine bak)"
		elseif action == "forceGolden" then
			force.goldenUntil = os.time() + Config.GOLDEN.windowSeconds
			data.golden = nil
			message = "Altın hayvan belirdi"
		elseif action == "completeSeason" then
			force.completeSeason = true
			message = "Mevsim hedefi birkaç saniye içinde tamamlanır"
		else
			data.adminForce = nil
			data.seasonal = nil
			data.merchant = nil
			data.golden = nil
			message = "Olaylar sıfırlandı (mevsim hedefi yeniden oluşur)"
		end
		PlayerDataService.pushState(player)
		PlayerDataService.requestSave(player)
		return true, message
	end
	if action == "growAll" or action == "unlockIslands" or action == "fillSlots" or action == "maxAll" then
		-- Test aracı: yalnızca yöneticinin kendi profili; para harcamaz, sonuç normal kayıt akışına girer.
		if player:GetAttribute("WorldReady") ~= true then
			return false, "Çiftliğin henüz hazır değil"
		end
		local data = PlayerDataService.tryGet(player)
		if not data then
			return false, "Kayıt oturumu artık etkin değil"
		end
		-- Değer: "now" = seçili ada, "all" = bütün adalar, ya da bir ada kimliği (kilitli adayı seçmek mümkün olmadığı için)
		local selected = player:GetAttribute("SelectedFarmIsland")
		local islandIds: { string } = {}
		if value == "all" or action == "maxAll" then
			islandIds = table.clone(Config.FARM_ISLAND_ORDER)
		elseif typeof(value) == "string" and Config.FARM_ISLANDS[value] then
			islandIds = { value }
		else
			islandIds = { if typeof(selected) == "string" and Config.FARM_ISLANDS[selected] then selected else "home" }
		end
		local scopeName = if #islandIds > 1 then "Bütün adalar" else Config.FARM_ISLANDS[islandIds[1]].displayName
		local doAll = action == "maxAll"
		local grow = action == "growAll" or doAll
		local unlockAll = action == "unlockIslands" or doAll
		local fill = action == "fillSlots" or doAll
		local message = ""
		if doAll then
			-- Eksik ana çiftlikleri ücretsiz ekle (Çiftliklerim listesinde görünsün); etkin çiftlik değişmez.
			FarmProfiles.ensure(data)
			for plotNumber = 1, Config.MAIN_FARM_LIMIT do
				local farmId = tostring(plotNumber)
				if not data.mainFarms[farmId] then
					data.mainFarms[farmId] = SaveCodec.newFarm(Config, FarmMath, os.time(), function(): string
						return HttpService:GenerateGUID(false)
					end, farmId)
				end
			end
			local added, sent = 0, 0
			for _, farmId in FarmProfiles.ids(data) do
				local view = FarmProfiles.view(data, farmId)
				local a, s = maxFarmView(view, farmId, islandIds, grow, unlockAll, fill)
				added += a
				sent += s
			end
			FarmProfiles.capture(data)
			message =
				`Bütün çiftlikler ve adalar açıldı, büyütüldü ve dolduruldu ({added} hayvan eklendi, {sent} eklentiye gitti)`
		else
			local added, sent = maxFarmView(data, data.activeMainFarmId, islandIds, grow, unlockAll, fill)
			if unlockAll then
				message = `{scopeName}: her şey açıldı`
			end
			if fill then
				message = `{scopeName}: {added} hayvan eklendi`
				if sent > 0 then
					message ..= `, {sent} hayvan eklentiye gönderildi`
				end
			end
			if grow and not unlockAll and not fill then
				message = "Bütün hayvanlar yetişkin oldu"
			end
		end
		PlayerDataService.pushState(player)
		PlayerDataService.requestSave(player)
		PlotService.refreshPlayerWorld(player)
		return true, message
	end
	local id = value :: string
	if action == "setTime" then
		local ok = SeasonService.setAdminClock(if id == "auto" then nil else id)
		return ok, if ok then "Saat güncellendi" else "Bilinmeyen saat"
	elseif action == "setLights" then
		local ok = SeasonService.setAdminLights(if id == "auto" then nil else id)
		return ok, if ok then "Işık modu güncellendi" else "Bilinmeyen ışık modu"
	elseif action == "setLightLevel" then
		local ok = SeasonService.setAdminLightLevel(if id == "auto" then nil else id)
		return ok, if ok then "Işık parlaklığı güncellendi" else "Bilinmeyen parlaklık"
	end
	if action == "setWeather" and id ~= "auto" and not Config.WEATHER[id] then
		return false, "Bilinmeyen hava"
	end
	if action == "setSeason" and id ~= "auto" and not validSeason(id) then
		return false, "Bilinmeyen mevsim"
	end
	-- SeasonService ortak geçiş callback'iyle tüm oyuncuların eski hava gelirini önce kapatır.
	-- Bu çağrıdan önce ID doğrulanır; geçersiz komut hiçbir ekonomik yan etki üretmez.
	local override = if id == "auto" then nil else id
	if action == "setWeather" then
		local ok = SeasonService.setAdminWeather(override)
		return ok, if ok then "Hava güncellendi" else "Hava değiştirilemedi"
	end
	local ok = SeasonService.setAdminSeason(override)
	return ok, if ok then "Mevsim güncellendi" else "Mevsim değiştirilemedi"
end

local function onRequest(player: Player, action: unknown, value: unknown, requestId: unknown)
	-- IsAdmin yalnızca arayüz ipucudur; güvenlik kontrolünde hiçbir zaman okunmaz.
	if not AdminPolicy.isAllowed(player.UserId) then
		return
	end
	if not AdminPolicy.validRequestId(requestId) or not AdminPolicy.validAction(action) then
		return
	end
	local id = requestId :: number
	if id <= (highWater[player] or 0) then
		return
	end
	highWater[player] = id
	local actionName = action :: string
	if not validValue(actionName, value) then
		return
	end
	if not RateLimiter.allow(player, "admin", 0.3) then
		if RateLimiter.allow(player, "adminThrottle", 0.5) then
			Remotes.get("AdminResult"):FireClient(player, id, false, "Lütfen kısa bir süre bekle")
		end
		return
	end
	local ok, message = execute(player, actionName, value)
	Remotes.get("AdminResult"):FireClient(player, id, ok, message)
end

local function markPlayer(player: Player)
	player:SetAttribute("IsAdmin", AdminPolicy.isAllowed(player.UserId))
end

function AdminService.init()
	if initialized then
		return
	end
	initialized = true
	Players.PlayerAdded:Connect(markPlayer)
	Players.PlayerRemoving:Connect(function(player: Player)
		highWater[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		markPlayer(player)
	end
	Remotes.get("RequestAdminAction").OnServerEvent:Connect(onRequest)
end

return AdminService
