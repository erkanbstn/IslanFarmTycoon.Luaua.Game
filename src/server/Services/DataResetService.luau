--!strict
-- Yönetici "herkesin verisini sıfırla": DataStore kayıtlarını silmez; genel veri çağını (SaveStore.bumpEpoch) artırır.
-- Çağı farklı olan her kayıt girişte temiz yeni oyunla değişir (SaveCodec.decode) ve eski kayıt `_archive_<çağ>` anahtarına
-- kopyalanır (PlayerDataService.load); sayıyı geri azaltmak mümkün değildir ama arşivden elle kurtarılabilir.
-- Çevrimiçi oyuncular (bu ve diğer sunucular: MessagingService) atılır; yeniden girince temiz başlarlar.
local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")

local SaveStore = require(script.Parent:WaitForChild("SaveStore"))

local DataResetService = {}
local TOPIC = "DataResetAll"
local KICK_MESSAGE =
	"Tüm oyuncu verileri sıfırlandı. Lütfen yeniden bağlan. / All player data was reset. Please rejoin."
local initialized = false

local function kickEveryone()
	for _, player in Players:GetPlayers() do
		player:Kick(KICK_MESSAGE)
	end
end

-- Dönüş: (başarılı mı, mesaj)
function DataResetService.resetAll(): (boolean, string)
	local epoch = SaveStore.bumpEpoch()
	if not epoch then
		return false, "Veri çağı artırılamadı; hiçbir şey sıfırlanmadı"
	end
	pcall(function()
		MessagingService:PublishAsync(TOPIC, { epoch = epoch })
	end)
	task.defer(kickEveryone)
	return true, `Tüm veriler sıfırlandı (çağ {epoch}); oyuncular atılıyor`
end

function DataResetService.init()
	if initialized then
		return
	end
	initialized = true
	-- Diğer sunuculardaki oyuncuları da at (Studio'da MessagingService kullanılamayabilir)
	pcall(function()
		MessagingService:SubscribeAsync(TOPIC, function()
			kickEveryone()
		end)
	end)
end

return DataResetService
