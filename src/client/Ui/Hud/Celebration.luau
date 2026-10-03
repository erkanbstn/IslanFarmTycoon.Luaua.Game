--!strict
-- Kilometre taşı kutlaması: yeni yapı ya da geliştirme seviyesi alınınca ekranda kısa altın bir pano belirir.
-- Yeni kilometre taşı türü eklersen `detectMilestone` içine ekle (durum farkından türetilir).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local GameTypes = require(Shared:WaitForChild("GameTypes"))
local UiKit = require(script.Parent.Parent:WaitForChild("UiKit"))

type PlayerSave = GameTypes.PlayerSave

local Color = UiKit.Color
local localPlayer = Players.LocalPlayer

local Celebration = {}

-- Döndürdüğü fonksiyon her durum güncellemesinde çağrılır; yeni alınanları kutlar.
function Celebration.create(screenGui: Instance): (PlayerSave) -> ()
	local lastFarmId: string? = nil
	local lastRun: number? = nil
	local lastAnimalCount = 0
	local lastPurchased: { [string]: boolean } = {}
	local lastLevels: { [string]: number } = {}
	local function celebrate(title: string, detail: string)
		local banner = Instance.new("Frame")
		banner.Name = "Celebration"
		banner.AnchorPoint = Vector2.new(0.5, 0)
		banner.Position = UDim2.new(0.5, 0, 0.2, 0)
		banner.Size = UDim2.fromOffset(300, 0)
		banner.AutomaticSize = Enum.AutomaticSize.Y
		banner.BackgroundColor3 = Color.Panel
		banner.BackgroundTransparency = 0.05
		banner.Parent = screenGui
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 12)
		corner.Parent = banner
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color.Gold
		stroke.Thickness = 2
		stroke.Parent = banner
		local pad = Instance.new("UIPadding")
		pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 10), UDim.new(0, 10)
		pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 14), UDim.new(0, 14)
		pad.Parent = banner
		UiKit.list(banner, 2, false)
		local titleLabel = UiKit.text(banner, title, "Title", Color.Gold)
		titleLabel.TextXAlignment = Enum.TextXAlignment.Center
		local detailLabel = UiKit.text(banner, detail, "Caption")
		detailLabel.TextXAlignment = Enum.TextXAlignment.Center
		if localPlayer:GetAttribute("ReducedMotion") ~= true then
			banner.Position = UDim2.new(0.5, 0, 0.2, 24)
			TweenService
				:Create(banner, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Position = UDim2.new(0.5, 0, 0.2, 0) })
				:Play()
		end
		task.delay(2.6, function()
			if localPlayer:GetAttribute("ReducedMotion") ~= true then
				TweenService:Create(banner, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
				TweenService:Create(stroke, TweenInfo.new(0.4), { Transparency = 1 }):Play()
				for _, child in banner:GetChildren() do
					if child:IsA("TextLabel") then
						TweenService:Create(child, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
					end
				end
				task.wait(0.45)
			end
			banner:Destroy()
		end)
	end

	local function detectMilestone(state: PlayerSave)
		local farmId = state.activeMainFarmId
		local run = if state.progression then state.progression.run else 1
		local known = lastFarmId == farmId and lastRun == run
		lastFarmId = farmId
		lastRun = run
		if known and lastAnimalCount == 0 and #state.animals > 0 then
			celebrate("İlk hayvanın geldi", "Çiftliğin artık gelir üretiyor.")
		end
		lastAnimalCount = #state.animals
		local newPurchased: { [string]: boolean } = {}
		local newLevels: { [string]: number } = {}
		for id in state.purchased do
			newPurchased[id] = true
			if known and not lastPurchased[id] then
				local upgrade = Config.getUpgrade(id)
				if upgrade then
					celebrate(
						upgrade.displayName,
						if upgrade.kind == "island" then "Yeni ada açıldı" else "Yeni yapı"
					)
				end
			end
		end
		local expansions: { [string]: number } = state.expansions or {}
		for id, level in expansions do
			newLevels[id] = level
			if known and level > (lastLevels[id] or 0) then
				celebrate(Config.getBuildTargetName(id, farmId), `Geliştirme tamamlandı · Sv.{level}`)
			end
		end
		lastPurchased, lastLevels = newPurchased, newLevels
	end
	return detectMilestone
end

return Celebration
