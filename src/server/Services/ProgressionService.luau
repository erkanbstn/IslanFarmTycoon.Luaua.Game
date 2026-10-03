--!strict
-- Altın, kalıcı haklar ve rebirth aynı hesap mutex'i ve kalıcı checkpoint üzerinden uygulanır.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local FarmMath = require(Shared:WaitForChild("Modules"):WaitForChild("FarmMath"))
local Progression = require(Shared:WaitForChild("Modules"):WaitForChild("Progression"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))
local PlotService = require(script.Parent:WaitForChild("PlotService"))
local EconomyService = require(script.Parent:WaitForChild("EconomyService"))
local RequestGuard = require(script.Parent:WaitForChild("RequestGuard"))
local RateLimiter = require(script.Parent.Parent.Modules.RateLimiter)
local SaveCodec = require(script.Parent.Parent.Modules.SaveCodec)
local Rebirth = require(script.Parent.Parent.Modules.Rebirth)

local ProgressionService = {}
local initialized = false
-- Ayrılan oyuncu kalıcı tabloda tutulmaz; çalışan işin kilidi pcall sonrasında temizlenir.
local inFlight: { [Player]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local function nowSeconds(): number
	return DateTime.now().UnixTimestampMillis / 1000
end
local function uid(): string
	return HttpService:GenerateGUID(false)
end

local function context(player: Player, expectedFarmId: unknown, detail: unknown): any?
	local data = PlayerDataService.tryGet(player)
	if not data or player:GetAttribute("WorldReady") ~= true or typeof(detail) ~= "table" then
		return nil
	end
	local state = data.progression
	if not state then
		return nil
	end
	if
		expectedFarmId ~= data.activeMainFarmId
		or typeof((detail :: any).expectedRun) ~= "number"
		or (detail :: any).expectedRun ~= state.run
	then
		return nil
	end
	if data.transfers and data.transfers.quarantined then
		return nil
	end
	return data
end

local function refresh(player: Player)
	PlotService.refreshPlayerWorld(player)
	PlayerDataService.pushState(player)
end

function ProgressionService.tryGoldAction(
	player: Player,
	action: unknown,
	expectedFarmId: unknown,
	detail: unknown
): (boolean, string?)
	if not RateLimiter.allow(player, "goldAction", 0.5) then
		return false, nil
	end
	if not context(player, expectedFarmId, detail) then
		return false, "İşlem bağlamı değişti; yeniden seç."
	end
	local request = detail :: any
	EconomyService.settlePlayer(player)
	return PlayerDataService.transactAccount(player, function(data: any): (boolean, string?)
		if data.activeMainFarmId ~= expectedFarmId or data.progression.run ~= request.expectedRun then
			return false, "İşlem bağlamı değişti; yeniden seç."
		end
		local now = nowSeconds()
		if action == "convert" then
			local cash = Progression.goldCashQuote(data, request.amount, now)
			if not cash then
				return false, "Altın çevrilemiyor; bakiyeni ve günlük sınırını kontrol et."
			end
			if typeof(request.expectedCash) ~= "number" or request.expectedCash ~= cash then
				return false, "Önizleme değişti; tutarı yeniden kontrol et."
			end
			if data.cash + cash > 1e15 then
				return false, "Kasan bu tutarı alamaz."
			end
			local state = data.progression
			local day = math.floor(now / 86400)
			if state.convertedDay ~= day then
				state.convertedDay, state.convertedDayGold = day, 0
			end
			state.convertedDayGold += request.amount
			state.convertedRunGold += request.amount
			data.gold -= request.amount
			data.cash += cash
			return true, "Altın paraya çevrildi."
		elseif action == "buy" then
			if typeof(request.offerId) ~= "string" then
				return false, "Geçersiz kalıcı ürün."
			end
			local offer = Config.PROGRESSION.permanentOffers[request.offerId]
			if not offer then
				return false, "Geçersiz kalıcı ürün."
			end
			local owned = if offer.kind == "item" then data.owned.items else data.owned.conveniences
			if owned[offer.id] then
				return false, "Bu kalıcı ürüne zaten sahipsin."
			end
			if data.gold < offer.goldCost then
				return false, "Yeterli altının yok."
			end
			data.gold -= offer.goldCost
			owned[offer.id] = true
			if offer.kind == "item" then
				data.inventory.items[offer.itemId] = true
			end
			return true, "Kalıcı ürün satın alındı."
		elseif action == "finish" then
			local target = if request.targetKind == "production"
				then request.targetId
				else request.uid or request.targetId
			if typeof(target) ~= "string" then
				return false, "Geçersiz hızlı bitirme hedefi."
			end
			local cost = Progression.finishGoldQuote(data, request.targetKind, target, now)
			if not cost or cost <= 0 or data.gold < cost then
				return false, "Bu işlem bitirilemiyor veya altının yetmiyor."
			end
			if
				typeof(request.expectedCost) ~= "number"
				or request.expectedCost ~= request.expectedCost
				or request.expectedCost % 1 ~= 0
				or request.expectedCost < cost
				or request.expectedCost > Config.PROGRESSION.gold.maxBalance
			then
				return false, "Önizleme değişti; tutarı yeniden kontrol et."
			end
			if request.targetKind == "production" then
				local job = data.production[target]
				if not job or request.uid ~= job.uid then
					return false, "Üretim partisi değişti; yeniden seç."
				end
				job.readyAt = now
				for _, animal in data.animals do
					if animal.task and animal.task.kind == "production" and animal.task.id == target then
						animal.task.endsAt = now
					end
				end
			else
				local animal = nil
				for _, record in data.animals do
					if record.uid == target then
						animal = record
						break
					end
				end
				if not animal then
					return false, "Geçersiz hızlı bitirme hedefi."
				end
				if request.targetKind == "growth" then
					animal.bornAt, animal.stage = 0, "adult"
				elseif request.targetKind == "extension" and animal.task and animal.task.kind == "extension" then
					if
						request.expectedEndsAt ~= animal.task.endsAt
						or request.expectedStartedAt ~= animal.task.startedAt
					then
						return false, "Hayvanın görevi değişti; yeniden seç."
					end
					animal.task, animal.extensionId = nil, nil
				else
					return false, "Geçersiz hızlı bitirme hedefi."
				end
			end
			data.gold -= cost
			return true, "Bekleme tamamlandı."
		end
		return false, "Geçersiz altın işlemi."
	end, function(owner: Player)
		EconomyService.startPlayer(owner)
		refresh(owner)
	end)
end

function ProgressionService.tryRebirth(
	player: Player,
	perkId: unknown,
	expectedFarmId: unknown,
	detail: unknown
): (boolean, string?)
	if not RateLimiter.allow(player, "rebirth", 1) then
		return false, nil
	end
	if not context(player, expectedFarmId, detail) or typeof(perkId) ~= "string" then
		return false, "İşlem bağlamı değişti; yeniden seç."
	end
	EconomyService.settlePlayer(player)
	return PlayerDataService.transactAccount(player, function(data: any): (boolean, string?)
		if data.progression.run ~= (detail :: any).expectedRun then
			return false, "İşlem bağlamı değişti; yeniden seç."
		end
		if data.transfers and next(data.transfers.outbox) ~= nil then
			return false, "Bekleyen aktarım tamamlanmadan rebirth yapılamaz."
		end
		if not Rebirth.apply(data, Config, FarmMath, Progression, SaveCodec, nowSeconds(), uid, perkId :: string) then
			return false, "Rebirth hazır değil veya bu etki seçilemiyor."
		end
		return true, "Rebirth tamamlandı. Yeni turun hazır!"
	end, function(owner: Player)
		EconomyService.startPlayer(owner)
		owner:SetAttribute("WorldReady", false)
		local ready = PlotService.restoreMainFarms(owner, { "1" }, "1")
		owner:SetAttribute("WorldReady", ready)
		if ready then
			PlotService.teleportHome(owner)
		end
		PlayerDataService.pushState(owner)
	end)
end

function ProgressionService.collect(player: Player): boolean
	local data = PlayerDataService.tryGet(player)
	local state = if data then data.progression else nil
	if not data or not state or player:GetAttribute("WorldReady") ~= true then
		return false
	end
	local now = nowSeconds()
	-- Önce saf bir görünümde kontrol: değişiklik yokken DataStore'a yazma.
	local candidate: any = table.clone(data)
	candidate.progression = table.clone(state)
	candidate.progression.claims = table.clone(state.claims)
	if Progression.collectGold(candidate, now) <= 0 then
		return false
	end
	EconomyService.settlePlayer(player)
	local gained = 0
	local accepted = PlayerDataService.transactAccount(player, function(current: any): (boolean, string?)
		gained = Progression.collectGold(current, now)
		return gained > 0, nil
	end, function(owner: Player)
		Remotes.get("Notify"):FireClient(owner, `{gained} altın kazanıldı`, "money")
	end)
	return accepted
end

function ProgressionService.expireReturn(player: Player)
	local data = PlayerDataService.tryGet(player)
	local state = if data then data.progression else nil
	local now = nowSeconds()
	if not data or not state or state.returnEnded or now < state.returnEndsAt then
		return
	end
	EconomyService.settlePlayer(player)
	local speeds = FarmMath.snapshotGrowthSpeeds(data, state.returnEndsAt - 0.001)
	state.returnEnded = true
	FarmMath.preserveGrowthProgress(data, speeds, state.returnEndsAt)
	PlayerDataService.markDirty(player)
	PlayerDataService.requestSave(player)
	refresh(player)
end

function ProgressionService.init()
	if initialized then
		return
	end
	initialized = true
	local handlers: { [string]: (Player, unknown, unknown, unknown) -> (boolean, string?) } =
		{ RequestGoldAction = ProgressionService.tryGoldAction, RequestRebirth = ProgressionService.tryRebirth }
	for name, handler in handlers do
		Remotes.get(name :: any).OnServerEvent
			:Connect(
				function(player: Player, value: unknown, requestId: unknown, expectedFarmId: unknown, detail: unknown)
					if not RateLimiter.acceptRequest(player, requestId) then
						return
					end
					if not RequestGuard.activeFarm(player, requestId, expectedFarmId) then
						return
					end
					local ok, message = handler(player, value, expectedFarmId, detail)
					RequestGuard.reply(player, requestId, ok, message)
				end
			)
	end
	task.spawn(function()
		while true do
			task.wait(2)
			for _, player in Players:GetPlayers() do
				if not inFlight[player] then
					inFlight[player] = true
					task.spawn(function()
						local ok, message = pcall(function()
							ProgressionService.expireReturn(player)
							ProgressionService.collect(player)
						end)
						inFlight[player] = nil
						if not ok then
							warn(`[Progression] Oyuncu ilerlemesi yeniden denenecek: {message}`)
						end
					end)
				end
			end
		end
	end)
end

return ProgressionService
