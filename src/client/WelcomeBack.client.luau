--!strict
-- Dönüş özeti: oyuna girince "Sen yokken" penceresi. Sunucu para ve büyüyen hayvan sayısını gönderir
-- (OfflineSummary); hazır üretim partileri client'ta kayıttan sayılır. Bildirim yerine tek pencere.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local FarmMath = require(Shared:WaitForChild("Modules"):WaitForChild("FarmMath"))
local ClientState = require(script.Parent:WaitForChild("ClientState"))
local UiKit = require(script.Parent:WaitForChild("UiKit"))

local player = Players.LocalPlayer

-- Çiftlik durumu gelene kadar en fazla bu kadar bekle; gelmezse özet üretim satırı olmadan gösterilir.
local STATE_WAIT_SECONDS = 6

local function readyRecipes(): { string }
	local state = ClientState.get()
	local result: { string } = {}
	if state and state.production then
		local now = Workspace:GetServerTimeNow()
		for recipeId, job in state.production do
			local recipe = Config.PRODUCTION_RECIPES[recipeId]
			if recipe and job.readyAt <= now then
				table.insert(result, recipe.displayName)
			end
		end
	end
	table.sort(result)
	return result
end

local function show(earned: number, grown: number)
	local gui = Instance.new("ScreenGui")
	gui.Name = "WelcomeBack"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 6
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = player:WaitForChild("PlayerGui")
	local window = UiKit.window(gui, {
		title = "Tekrar hoş geldin",
		icon = "🌅",
		tint = UiKit.Color.Gold,
		width = 340,
		maxHeight = 360,
		anchor = Vector2.new(0.5, 0.5),
		position = UDim2.fromScale(0.5, 0.5),
	})
	UiKit.text(window.list, "Sen yokken çiftliğinde olanlar", "Caption").LayoutOrder = 1

	local order = 2
	local function line(icon: string, text: string, detail: string?)
		local card = UiKit.card(window.list, order, icon)
		card.title.Text = text
		card.detail.Text = detail or ""
		card.detail.Visible = detail ~= nil
		card.action.Visible = false
		order += 1
	end
	if earned > 0 then
		line("💰", `+{FarmMath.formatMoney(earned)} kazandın`, "Kasana eklendi")
	end
	if grown > 0 then
		line("🐄", `{grown} hayvan büyüdü`, "Yetişkin hayvanlar daha çok kazandırır")
	end
	local recipes = readyRecipes()
	if #recipes > 0 then
		line("🏭", `{table.concat(recipes, ", ")} hazır`, "Üretim menüsünden topla")
	end

	local close = UiKit.button(window.list, "Devam et", "primary")
	close.Size = UDim2.new(1, 0, 0, 40)
	close.LayoutOrder = order
	close.Activated:Connect(function()
		window.close()
		task.delay(0.5, function()
			gui:Destroy()
		end)
	end)
	window.open()
end

Remotes.get("OfflineSummary").OnClientEvent:Connect(function(earned: unknown, grown: unknown)
	if typeof(earned) ~= "number" or typeof(grown) ~= "number" then
		return
	end
	-- Üretim satırı için çiftlik durumunun gelmesini kısa süre bekle
	local waited = 0
	while not ClientState.get() and waited < STATE_WAIT_SECONDS do
		task.wait(0.25)
		waited += 0.25
	end
	show(earned, grown)
end)
