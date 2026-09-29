--!strict
-- Island Farm Tycoon Studio eklentisi: haritayı DÜZENLEME modunda kurar, böylece place'e kaydedilir
-- ve Play'e basmadan görülebilir. Harita kodu tek kaynaktır: src/server/Services/MapBuilder.luau
--
-- Kurulum (bir kez):  rojo build plugin.project.json --plugin IslandFarmTycoonHarita.rbxm

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

-- Play sırasında buton görünmesin
if RunService:IsRunning() then
	return
end

local toolbar = plugin:CreateToolbar("Island Farm Tycoon")
local buildButton = toolbar:CreateButton(
	"Haritayı Kur",
	"Denizi, meydanı ve adaları koddan sıfırdan kurar. Plots/World ve merkezdeki 1104×64×1104 Terrain alanı yenilenir (Ctrl+Z ile geri alınabilir).",
	""
)
buildButton.ClickableWhenViewportHidden = true

-- Studio require sonuçlarını önbelleğe alır; Rojo kodu güncellese bile eski hali çalışırdı.
-- Bu yüzden modüllerin kopyasını alıp kopyayı çalıştırıyoruz (her tıklamada en güncel kod).
local function loadFreshMapBuilder(): (any, Instance)
	local shared = ReplicatedStorage:FindFirstChild("Shared")
	local server = ServerScriptService:FindFirstChild("Server")
	local services = server and server:FindFirstChild("Services")
	if not shared or not services then
		error("Oyun kodu bulunamadı. Önce 'rojo serve' çalıştırıp Rojo eklentisinden Connect'e bas.")
	end

	local sandbox = Instance.new("Folder")
	sandbox.Name = "AhirTycoonMapSandbox"
	shared:Clone().Parent = sandbox
	local servicesCopy = services:Clone()
	servicesCopy.Parent = sandbox

	local module = servicesCopy:FindFirstChild("MapBuilder")
	if not module or not module:IsA("ModuleScript") then
		sandbox:Destroy()
		error("MapBuilder modülü bulunamadı.")
	end
	local ok, result = pcall(require :: any, module)
	if not ok then
		sandbox:Destroy()
		error(result)
	end
	return result, sandbox
end

local building = false

buildButton.Click:Connect(function()
	if building then
		return
	end
	building = true
	buildButton:SetActive(false)

	local recording = ChangeHistoryService:TryBeginRecording("Island Farm Tycoon haritasını kur")
	if not recording then
		building = false
		warn("[Island Farm Tycoon] Geri alma kaydı açılamadı; harita değiştirilmedi.")
		return
	end
	local sandbox: Instance? = nil
	local ok, err = pcall(function()
		local mapBuilder, box = loadFreshMapBuilder()
		sandbox = box
		mapBuilder.build(true)
	end)
	if recording then
		ChangeHistoryService:FinishRecording(
			recording,
			if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel
		)
	end
	if sandbox then
		sandbox:Destroy()
	end

	building = false
	if ok then
		print("[Island Farm Tycoon] Harita kuruldu. Kaydetmek için Ctrl+S (ya da File → Publish).")
	else
		warn(`[Island Farm Tycoon] Harita kurulamadı: {err}`)
	end
end)
