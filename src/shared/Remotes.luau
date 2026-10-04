--!strict
-- RemoteEvent / RemoteFunction yönetimi.
-- Sunucu Remotes.init() çağırır, iki taraf da Remotes.get(name) ile erişir.
-- Yeni remote eklemek için aşağıdaki listelere isim ekle.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "Remotes"

export type EventName =
	"RequestMainFarmAction"
	| "RequestGoldAction"
	| "RequestRebirth"
	| "MainFarmResult"
	| "Notify"
	| "PlayerState"
	| "EconomyTick"
	| "RequestBuyUpgrade"
	| "RequestUpgradeLineage"
	| "RequestExpandZone"
	| "RequestClaimSeasonal"
	| "RequestBuyMerchantOffer"
	| "RequestClaimGolden"
	| "RequestBuyItem"
	| "RequestEquipItem"
	| "RequestUseItem"
	| "WeatherQueueOffer"
	| "RequestBuyAnimal"
	| "RequestReplaceFish"
	| "RequestSellAnimal"
	| "PurchaseResult"
	| "RequestPlayerState"
	| "RequestGoHome"
	| "RequestTravel"
	| "RequestTravelIsland"
	| "DebugCycleWeather"
	| "RequestClaimDaily"
	| "RequestPromptProduct"
	| "RequestFulfillContract"
	| "RequestSellGoods"
	| "RequestBarterAnimal"
	| "RequestClaimAchievement"
	| "OfflineSummary"
	| "RequestAdminAction"
	| "RequestAdminPlayerAction"
	| "RequestSendMoney"
	| "RequestTradePolicy"
	| "TradePolicyState"
	| "AdminResult"
	| "RequestProductionAction"
	| "ProductionResult"
	| "RequestExtensionAction"
	| "RequestSetLanguage"
	| "RequestSetGraphics"
	| "RequestSetPreference"

local EVENTS = {
	"RequestGoldAction", -- action, requestId, expectedFarmId, detail (expectedRun zorunlu)
	"RequestRebirth", -- perkId, requestId, expectedFarmId, detail (expectedRun zorunlu)
	"RequestMainFarmAction", -- buy physicalPlotId / select logicalFarmId, requestId
	"MainFarmResult", -- requestId, success, message
	"RequestProductionAction", -- start/sell/keep/cancel/auto, recipeId, jobUid?, requestId, expectedFarmId, detail?
	"ProductionResult", -- requestId, success, message
	"RequestExtensionAction", -- assign / unassign, extensionId
	"RequestSetGraphics", -- Client -> Sunucu grafik tercihi (auto/low/medium/high); sunucu Config.GRAPHICS_MODES ile doğrular
	"RequestSetPreference", -- Client -> Sunucu ses düzeyi/hareket azaltma tercihi (tür, değer); sunucu Modules/Preferences ile doğrular
	"RequestSetLanguage", -- Client -> Sunucu arayüz dili tercihi (kod); sunucu Config.LANGUAGES ile doğrular
	"RequestAdminAction", -- Sadece sunucudaki AdminPolicy'nin izin verdiği hesap.
	"RequestTradePolicy", -- Client -> Sunucu kendi para gönderme iznini sor (argüman yok); sonuç TradePolicyState
	"TradePolicyState", -- Sunucu -> Client yalnız o oyuncunun durumu ("loading"|"allowed"|"restricted"|"unavailable"); başkasının durumu gönderilmez
	"AdminResult", -- Sunucu -> yetkili client (requestId, success, message).
	"RequestAdminPlayerAction", -- Yetkili -> Sunucu başka oyuncuya işlem (targetUserId, action, value, requestId); sonuç AdminResult
	"RequestSendMoney", -- Client -> Sunucu başka oyuncuya para gönder (targetUserId, amount, requestId); sonuç PurchaseResult
	"Notify", -- Sunucu -> Client bilgi mesajı (message, kind?)
	"PlayerState", -- Sunucu -> Client kaydın tamamı (yapısal değişikliklerde)
	"EconomyTick", -- Sunucu -> Client sadece (cash, stored, revision, farmId); her saniye
	"RequestBuyUpgrade", -- Client -> Sunucu yol haritası satın alma (upgradeId)
	"RequestUpgradeLineage", -- Client -> Sunucu ırk geliştirme (animalId, requestId, expectedFarmId)
	"RequestExpandZone", -- Client -> Sunucu alan genişletme (zoneId, requestId, expectedFarmId)
	"RequestClaimSeasonal", -- Client -> Sunucu mevsim hedefi ödülünü al (_, requestId)
	"RequestBuyMerchantOffer", -- Client -> Sunucu tüccardan tur eşyası al (itemId, requestId, expectedFarmId, {cycle, expectedPrice})
	"RequestClaimGolden", -- Client -> Sunucu altın hayvan ödülünü al (_, requestId, expectedFarmId)
	"RequestBuyItem", -- Client -> Sunucu eşya satın al (itemId, requestId)
	"RequestEquipItem", -- Client -> Sunucu eşyayı tak / çıkar (itemId, requestId)
	"RequestUseItem", -- itemId, requestId, expectedFarmId, seçim kimliği veya {weatherId, queueToken} / {queueAction="cancel"}
	"WeatherQueueOffer", -- Sunucu -> Client hava sırası önizlemesi/durumu (offer|queued|closed); kullanım hakkı başlamadan harcanmaz
	"RequestBuyAnimal", -- Client -> Sunucu hayvan satın alma (animalId)
	"RequestSellAnimal", -- Client -> Sunucu hayvan sat (animalId, requestId, expectedFarmId); fiyat ve hayvan sunucuda seçilir
	"RequestReplaceFish", -- Client -> Sunucu hamsiyi levrekle değiştir (uid, requestId)
	"PurchaseResult", -- Sunucu -> Client (requestId, success, message?)
	"RequestPlayerState", -- Client hazır / tekrar eşitleme
	"RequestFulfillContract", -- Ahır siparişini depodaki ürünlerle teslim et (offerKey, requestId, expectedFarmId); sonuç PurchaseResult
	"RequestSellGoods", -- Depodaki ürünü paraya çevir (goodsId, requestId, expectedFarmId, "all"|"half"); oran Config.GOODS_SELL, sonuç PurchaseResult
	"RequestBarterAnimal", -- Depodaki ürünlerle hayvan satın al (animalId, requestId, expectedFarmId); oran Config.GOODS_BARTER, sonuç PurchaseResult
	"RequestPromptProduct", -- Oyun geçidi/ürün satın alma penceresini aç ("pass"|"product", anahtar); fiyatı sunucu belirler
	"RequestClaimDaily", -- Günlük giriş ödülünü al (_, requestId); sonuç PurchaseResult
	"RequestClaimAchievement", -- Başarım ödülünü al (achievementId, requestId); sonuç PurchaseResult
	"OfflineSummary", -- Sunucu -> Client giriş özeti (kazanılan para, yetişkin olan hayvan sayısı)
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
