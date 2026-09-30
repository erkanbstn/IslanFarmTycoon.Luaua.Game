--!strict
-- Yardımcılar (pet): her oyuncunun bütün çiftliklerinde (etkin ya da park edilmiş) hazır partileri teslim alır ve
-- "otomatik tekrar" açıksa yenisini başlatır. Çekirdek kural ProductionLogic.runPets'te (saf, testli); burası yalnızca
-- sunucu döngüsü, bildirim ve kayıt isteğidir. Yalnızca çevrimiçi oyuncu için çalışır.
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local FarmMath = require(Shared:WaitForChild("Modules"):WaitForChild("FarmMath"))
local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))
local EconomyService = require(script.Parent:WaitForChild("EconomyService"))
local PlotService = require(script.Parent:WaitForChild("PlotService"))
local ProductionLogic = require(script.Parent.Parent.Modules.ProductionLogic)

local PetService = {}

local TICK_SECONDS = 2
local initialized = false

-- Yardımcıların görünür hareketi istemcide (PetAnimator); burada yalnızca plot özniteliklerine iş ve tur sayısı yazılır.
--   PetCashJob / PetGoodsJob : çalışan partinin tesis kimliği ("" = iş yok)
--   PetCashCycle / PetGoodsCycle : yardımcının teslim ettiği toplam parti (her artışta teslim turu oynar)
local JOB_ATTRIBUTE = { cash = "PetCashJob", goods = "PetGoodsJob" }
local CYCLE_ATTRIBUTE = { cash = "PetCashCycle", goods = "PetGoodsCycle" }

local function publish(player: Player, data: any, claims: { cash: number, goods: number }?)
	local plot = PlotService.getPlot(player)
	if not plot then
		return
	end
	for _, kind in { "cash", "goods" } do
		local job = ""
		if FarmMath.hasPet(data, kind) then
			for _, recipeId in Config.PRODUCTION_ORDER do
				local recipe = Config.PRODUCTION_RECIPES[recipeId]
				local recipeKind = if recipe.output == "goods"
					then "goods"
					elseif recipe.output == "cash" then "cash"
					else nil
				if recipeKind == kind and data.purchased[recipe.upgradeId] and data.production[recipeId] then
					job = recipe.upgradeId
					break
				end
			end
		end
		plot:SetAttribute(JOB_ATTRIBUTE[kind], job)
		if claims and claims[kind] > 0 then
			local attribute = CYCLE_ATTRIBUTE[kind]
			plot:SetAttribute(attribute, (plot:GetAttribute(attribute) or 0) + claims[kind])
		end
	end
end

local function tick(player: Player)
	local data = PlayerDataService.tryGet(player)
	if not data or player:GetAttribute("WorldReady") ~= true then
		return
	end
	local hooks: ProductionLogic.Hooks = {
		settle = function()
			EconomyService.settlePlayer(player)
		end,
		trySpend = function(amount: number): boolean
			return PlayerDataService.trySpend(player, amount)
		end,
		addCash = function(amount: number)
			PlayerDataService.addCash(player, amount)
		end,
		newUid = function(): string
			return HttpService:GenerateGUID(false)
		end,
	}
	local now = DateTime.now().UnixTimestampMillis / 1000
	local summary = ProductionLogic.runPets(data, PlayerDataService.getFarmIds(player), function(farmId: string): any
		return PlayerDataService.getFarmView(player, farmId)
	end, Config.PRODUCTION_ORDER, now, FarmMath, Config, hooks)
	publish(player, data, summary.claims[data.activeMainFarmId])
	if next(summary.changedFarms) == nil then
		return
	end
	PlayerDataService.pushState(player)
	PlayerDataService.requestSave(player)
	if summary.changedFarms[data.activeMainFarmId] then
		-- Etkin çiftlikte hayvanlar tesise girdi/döndü ve bina üstündeki çubuk değişti
		local ok, err = pcall(function()
			PlotService.refreshPlayerWorld(player)
		end)
		if not ok then
			warn(`[Pet] Görünüm yenilenemedi: {err}`)
		end
	end
	local parts: { string } = {}
	if summary.cash > 0 then
		table.insert(parts, `Yardımcı · +{FarmMath.formatMoney(summary.cash)}`)
	end
	for _, message in summary.goodsMessages do
		table.insert(parts, message)
	end
	if #parts > 0 then
		Remotes.get("Notify"):FireClient(player, table.concat(parts, " · "), "info")
	end
end

function PetService.init()
	if initialized then
		return
	end
	initialized = true
	task.spawn(function()
		while true do
			task.wait(TICK_SECONDS)
			for _, player in Players:GetPlayers() do
				local ok, err = pcall(tick, player)
				if not ok then
					warn(`[Pet] {err}`)
				end
			end
		end
	end)
end

return PetService
