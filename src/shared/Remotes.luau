--!strict
-- RemoteEvent / RemoteFunction yönetimi.
-- Sunucu Remotes.init() çağırır, iki taraf da Remotes.get(name) ile erişir.
-- Yeni remote eklemek için aşağıdaki listelere isim ekle.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "Remotes"

export type EventName =
	"RequestMainFarmAction"
	| "MainFarmResult"
	| "Notify"
	| "PlayerState"
	| "EconomyTick"
	| "RequestBuyUpgrade"
	| "RequestBuyAnimal"
	| "RequestReplaceFish"
	| "PurchaseResult"
	| "RequestPlayerState"
	| "RequestGoHome"
	| "RequestTravel"
	| "RequestTravelIsland"
	| "DebugCycleWeather"
	| "RequestClaimOrder"
	| "RequestAdminAction"
	| "AdminResult"
	| "RequestProductionAction"
	| "ProductionResult"
	| "RequestExtensionAction"
	| "RequestSetLanguage"

local EVENTS = {
	"RequestMainFarmAction", -- buy physicalPlotId / select logicalFarmId, requestId
	"MainFarmResult", -- requestId, success, message
	"RequestProductionAction", -- start/sell/keep, recipeId, jobUid?, requestId
	"ProductionResult", -- requestId, success, message
	"RequestExtensionAction", -- assign / unassign, extensionId
	"RequestSetLanguage", -- Client -> Sunucu arayüz dili tercihi (kod); sunucu Config.LANGUAGES ile doğrular
	"RequestAdminAction", -- Sadece sunucudaki AdminPolicy'nin izin verdiği hesap.
	"AdminResult", -- Sunucu -> yetkili client (requestId, success, message).
	"Notify", -- Sunucu -> Client bilgi mesajı (message, kind?)
	"PlayerState", -- Sunucu -> Client kaydın tamamı (yapısal değişikliklerde)
	"EconomyTick", -- Sunucu -> Client sadece (cash, stored); her saniye
	"RequestBuyUpgrade", -- Client -> Sunucu yol haritası satın alma (upgradeId)
	"RequestBuyAnimal", -- Client -> Sunucu hayvan satın alma (animalId)
	"RequestReplaceFish", -- Client -> Sunucu hamsiyi levrekle değiştir (uid, requestId)
	"PurchaseResult", -- Sunucu -> Client (requestId, success, message?)
	"RequestPlayerState", -- Client hazır / tekrar eşitleme
	"RequestClaimOrder", -- Tamamlanan siparişi teslim et (uid, requestId)
	"RequestGoHome", -- Client -> Sunucu kendi adasına ışınlanma
	"RequestTravelIsland", -- Kendi uzman adasına git (islandId, selectOnly?); sunucu kilidi doğrular
	"RequestTravel", -- Client -> Sunucu başka adaya / meydana ışınlanma ("hub" veya plotId)
	"DebugCycleWeather", -- Sadece Studio: F7 ile havayı sırayla değiştir (test için)
}

local FUNCTIONS: { string } = {
	-- "GetPlayerData",
}

local Remotes = {}

function Remotes.init()
	assert(RunService:IsServer(), "Remotes.init() sadece sunucuda çağrılmalı")
	if ReplicatedStorage:FindFirstChild(FOLDER_NAME) then
		return
	end

	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME

	for _, name in EVENTS do
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
	end

	for _, name in FUNCTIONS do
		local remote = Instance.new("RemoteFunction")
		remote.Name = name
		remote.Parent = folder
	end

	folder.Parent = ReplicatedStorage
end

function Remotes.get(name: EventName): RemoteEvent
	local folder = ReplicatedStorage:WaitForChild(FOLDER_NAME)
	local remote = folder:WaitForChild(name)
	assert(remote:IsA("RemoteEvent"), `RemoteEvent bekleniyordu: {name}`)
	return remote
end

return Remotes
