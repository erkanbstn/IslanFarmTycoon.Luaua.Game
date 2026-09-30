--!strict
-- İlk adımlar yönlendirmesi: durumdan türetilir (kayıt alanı yok), eski oyuncular otomatik atlar.
--   1) İlk hayvanı al (Pazar düğmesi vurgulanır)
--   2) Parayı topla (yeşil platforma ışın çizgisi)
--   3) İlk yükseltmeyi al (Yükseltmeler düğmesi vurgulanır)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local GameTypes = require(Shared:WaitForChild("GameTypes"))
local UiKit = require(script.Parent.Parent:WaitForChild("UiKit"))

type PlayerSave = GameTypes.PlayerSave

local localPlayer = Players.LocalPlayer

-- Bu kadar kazanmış bir hesap artık yeni sayılmaz
local SKIP_AFTER_EARNED = 1500

local Onboarding = {}

export type Hud = {
	step: (state: PlayerSave) -> number,
	apply: (state: PlayerSave, canAffordUpgrade: boolean) -> number,
}

-- 0 = bitti; 1..3 = sıradaki adım
function Onboarding.stepFor(state: PlayerSave): number
	-- Hesap düzeyi ilerleme (lifetimeEarned) yeterliyse bu oyuncu yönlendirme istemez (yeni çiftlik satın alanlar dahil)
	if next(state.purchased) ~= nil or (state.lifetimeEarned or 0) >= SKIP_AFTER_EARNED then
		return 0
	end
	if #state.animals <= Config.STARTING_COW_COUNT then
		return 1
	end
	if (state.lifetimeEarned or 0) <= 0 then
		return 2
	end
	return 3
end

-- Vurguları uygular; hangi adımda olduğunu döner
function Onboarding.create(shopButton: GuiObject, upgradesButton: GuiObject): Hud
	local pulseShop = UiKit.pulse(shopButton)
	local pulseUpgrades = UiKit.pulse(upgradesButton)
	local function apply(state: PlayerSave, canAffordUpgrade: boolean): number
		local step = Onboarding.stepFor(state)
		pulseShop(step == 1 and state.cash >= 1)
		pulseUpgrades(step == 3 and canAffordUpgrade)
		-- CollectorGuide: yeşil platforma giden ışın
		local wantBeam = step == 2
		if localPlayer:GetAttribute("TutorialGuide") ~= wantBeam then
			localPlayer:SetAttribute("TutorialGuide", wantBeam)
		end
		return step
	end
	return {
		step = Onboarding.stepFor,
		apply = apply,
	}
end

return Onboarding
