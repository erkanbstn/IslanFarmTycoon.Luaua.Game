--!strict
-- Ahır binası: hazır model (assets/Barns/Barn_Lv<1-4>); seviye yükseldikçe malzeme ve ek parçalar modelde değişir.
-- Konum: plot içindeki "BarnSpot" parçası (LookVector = kapı yönü).
-- BarnSpot yoksa başlangıç bölgesinin zemini kullanılır.

-- Studio plugin'i modülleri kopyalayıp taze Config ile çalıştırır; Shared araması SharedRef'te (kopyadaki Shared'ı bulur).
local Shared = require(script.Parent:WaitForChild("SharedRef")) :: typeof(game.ReplicatedStorage.Shared)
local Config = require(Shared:WaitForChild("Config"))
local WorldUi = require(Shared:WaitForChild("WorldUi"))
local UiTheme = require(Shared:WaitForChild("UiTheme"))
local ModelAssets = require(script.Parent:WaitForChild("ModelAssets"))

local BarnVisualService = {}

local function getBarnFrame(plot: Model): CFrame?
	local spot = plot:FindFirstChild("BarnSpot")
	if spot and spot:IsA("BasePart") then
		return spot.CFrame
	end
	local zones = plot:FindFirstChild("Zones")
	if not zones then
		return nil
	end
	for _, zone in zones:GetChildren() do
		if zone:GetAttribute("ZoneId") == "starter" then
			local ground = zone:FindFirstChild("Ground")
			if ground and ground:IsA("BasePart") then
				return ground.CFrame * CFrame.new(0, ground.Size.Y / 2, 0)
			end
		end
	end
	return nil
end

-- Sandığın etkileşimi (model de kod da aynı): prompt yalnızca sahibine görünür; üstünde ad etiketi
local function attachChestInteraction(body: BasePart)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "BarnChestPrompt"
	prompt.ActionText = "Aç"
	prompt.ObjectText = "Ahır Deposu"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("Locked", true)
	WorldUi.configureProximityPrompt(prompt)
	prompt.Parent = body
	WorldUi.tag(body, "ChestTag", {
		text = "Ahır Deposu",
		icon = "📦",
		tint = UiTheme.Color.Gold,
		widthStuds = 7,
		heightStuds = 1.7,
		offset = Vector3.new(0, 3.6, 0),
		maxDistance = 55,
	})
end

-- frame: zemin yüzeyinde, LookVector (-Z) kapı yönü
local function buildBarn(parent: Instance, frame: CFrame, barnLevel: number)
	local levelConfig = Config.getBarnLevelConfig(barnLevel)
	local tier = math.clamp(barnLevel, 1, 4)

	-- Hazır model (assets/Barns/Barn_Lv<1-4>): geometri modelden; fener/pencere ışığı, sandık etkileşimi ve seviye yazısı burada eklenir.
	local modelBarn = ModelAssets.clone("Barns", `Barn_Lv{tier}`)
	if modelBarn then
		modelBarn.Name = "Barn"
		modelBarn:PivotTo(frame)
		ModelAssets.eachNamed(modelBarn, { "Lantern" }, ModelAssets.markLantern)
		ModelAssets.eachNamed(modelBarn, { "HayloftWindow", "SideWindow" }, ModelAssets.markGlowWindow)
		local chest = modelBarn:FindFirstChild("StorageChest")
		if chest and chest:IsA("BasePart") then
			attachChestInteraction(chest)
		end
		-- Seviye tabelası modelde "LevelSign" parçasıdır (SurfaceGui modelde saklanmaz): yazı burada eklenir
		local sign = modelBarn:FindFirstChild("LevelSign")
		if sign and sign:IsA("BasePart") then
			WorldUi.sign(sign, Enum.NormalId.Front, {
				title = `Seviye {barnLevel}`,
				text = if levelConfig then levelConfig.displayName else "Ahır",
			})
		end
		modelBarn:SetAttribute("VisualCreatedAt", game:GetService("Workspace"):GetServerTimeNow())
		modelBarn:SetAttribute("PartCount", ModelAssets.partCount(modelBarn))
		local floor = modelBarn:FindFirstChild("Floor")
		if floor and floor:IsA("BasePart") then
			modelBarn.PrimaryPart = floor
		end
		modelBarn.Parent = parent
		return
	end

	warn(`[Barn] assets/Barns/Barn_Lv{tier}.rbxmx bulunamadı`)
end

function BarnVisualService.buildAt(plot: Model, barnLevel: number)
	local existing = plot:FindFirstChild("Barn")
	if existing then
		existing:Destroy()
	end
	local frame = getBarnFrame(plot)
	if not frame then
		warn(`[Barn] {plot.Name}: BarnSpot bulunamadı`)
		return
	end
	buildBarn(plot, frame, barnLevel)
end

-- Aynı seviye zaten kuruluysa yeniden inşa etme
function BarnVisualService.applyForPlayer(plot: Model, barnLevel: number)
	if plot:GetAttribute("BarnLevel") == barnLevel and plot:FindFirstChild("Barn") then
		return
	end
	plot:SetAttribute("BarnLevel", barnLevel)
	BarnVisualService.buildAt(plot, barnLevel)
end

return BarnVisualService
