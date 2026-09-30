--!strict
-- Karakter kendi çiftliklerinden birinin adasına (yürüyerek ya da ışınlanarak) girince:
--  * O ana çiftlik etkin değilse etkin yapılır (panelden seçmekle aynı, ışınlama olmadan).
--  * O ada seçilir: Yükseltmeler, Yol Haritası, Pazar ve diğer ada bağımlı arayüzler o adaya göre güncellenir.
--    Kilitli bir adaya girilince seçim sunucuda yapılamaz; paneller client'ta önizleme olarak o adayı gösterir.
-- Ada sekmelerinden elle seçilen ada, karakter başka bir adaya geçene kadar korunur.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local ClientState = require(script.Parent.Parent:WaitForChild("Core"):WaitForChild("ClientState"))
local IslandContext = require(script.Parent.Parent:WaitForChild("Core"):WaitForChild("IslandContext"))
local IslandManager = require(script.Parent.Parent:WaitForChild("Ui"):WaitForChild("IslandManager"))

local player = Players.LocalPlayer
local CHECK_INTERVAL = 0.4
local lastDetected: string? = nil -- "farmId|islandId"
-- Sunucu seçimi hız sınırı yüzünden düşürebilir: seçim tutana kadar (en fazla birkaç kez) yeniden istenir.
local pendingIsland: string? = nil
local retriesLeft = 0
local nextRetryAt = 0
local RETRY_SECONDS = 0.8
local MAX_RETRIES = 6

-- Silindir tabanın üstünde mi? (MapBuilder silindirleri X ekseni çevrilmiş disklerdir; yatay çap Size.Y'dedir.)
local function inside(base: Instance?, position: Vector3): boolean
	if not base or not base:IsA("BasePart") then
		return false
	end
	local flat = Vector3.new(position.X - base.Position.X, 0, position.Z - base.Position.Z)
	return flat.Magnitude <= base.Size.Y / 2 - 2
end

-- Karakterin üstünde durduğu (çiftlik kimliği, ada); kendi çiftliklerinden hiçbirinde değilse nil
local function locate(position: Vector3): (string?, string?)
	local plots = Workspace:FindFirstChild("Plots")
	if not plots then
		return nil, nil
	end
	for _, plot in plots:GetChildren() do
		if not plot:IsA("Model") or plot:GetAttribute("OwnerUserId") ~= player.UserId then
			continue
		end
		local farmId = plot:GetAttribute("MainFarmId")
		if typeof(farmId) ~= "string" then
			continue
		end
		local islands = plot:FindFirstChild("Islands")
		if islands then
			for _, island in islands:GetChildren() do
				local islandId = island:GetAttribute("FarmIslandId")
				if typeof(islandId) == "string" and inside(island:FindFirstChild("IslandBase"), position) then
					return farmId, islandId
				end
			end
		end
		if inside(plot:FindFirstChild("PlotBase"), position) then
			return farmId, "home"
		end
	end
	return nil, nil
end

local function check()
	local state = ClientState.get()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not state or not root or not root:IsA("BasePart") then
		return
	end
	local farmId, islandId = locate(root.Position)
	if not farmId or not islandId then
		return
	end
	local signature = `{farmId}|{islandId}`
	if signature == lastDetected then
		if pendingIsland then
			if IslandContext.selected() == pendingIsland or retriesLeft <= 0 then
				pendingIsland = nil
			elseif os.clock() >= nextRetryAt then
				retriesLeft -= 1
				nextRetryAt = os.clock() + RETRY_SECONDS
				Remotes.get("RequestTravelIsland"):FireServer(pendingIsland, true)
			end
		end
		return
	end

	-- Başka bir ana çiftliğin adasına geçildi: önce çiftliği etkin yap. Etkinleşince ActiveMainFarmId
	-- değişir, tespit sıfırlanır ve ada seçimi bir sonraki turda yapılır.
	local activeFarm = player:GetAttribute("ActiveMainFarmId")
	if farmId ~= activeFarm then
		IslandManager.activateFarm(farmId)
		return
	end

	lastDetected = signature
	if state.unlockedIslands[islandId] then
		-- Açık ada: gerçek seçim (sunucu); varsa önizleme silinir
		IslandContext.setPreview(nil)
		if islandId ~= IslandContext.selected() then
			pendingIsland, retriesLeft, nextRetryAt = islandId, MAX_RETRIES, os.clock() + RETRY_SECONDS
			Remotes.get("RequestTravelIsland"):FireServer(islandId, true)
		else
			pendingIsland = nil
		end
	else
		pendingIsland = nil
		-- Kilitli ada: paneller yalnızca bakmak için o adayı gösterir (satın alma kartı dahil)
		IslandContext.setPreview(islandId)
	end
end

task.spawn(function()
	while true do
		task.wait(CHECK_INTERVAL)
		-- Tek bir hata döngüyü öldürmesin; sonraki turda yeniden denenir.
		local ok, err = pcall(check)
		if not ok then
			warn(`[IslandAutoSelect] {err}`)
		end
	end
end)
-- Çiftlik değişince ada tespiti yeniden yapılsın
player:GetAttributeChangedSignal("ActiveMainFarmId"):Connect(function()
	lastDetected = nil
end)
