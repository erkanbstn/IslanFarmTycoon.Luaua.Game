--!strict
-- İlk adımlar yönlendirmesi: adım durumdan türetilir (kayıt alanı yok; mantık Modules/OnboardingSteps).
--   1) İlk hayvanı al        Pazar düğmesi + dünyada pazar tezgâhı işareti (para şartı yok: oyuncu hayvanı kendi alır)
--   2) Parayı topla          yeşil platforma ışın çizgisi (CollectorGuide)
--   3) İlk yükseltmeyi al    Yükseltmeler düğmesi + dünyada ilgili yapım alanı işareti
--   4) Yol Haritası'nı aç    Yol Haritası düğmesi
--   5) İlk genişletmeyi al   Yükseltmeler düğmesi (Geliştirmeler sekmesi)
--   6) Üretimde ilk parti    Üretim düğmesi
-- Her vurgulu düğmede ayrıca zıplayan "Buraya dokun" oku vardır (UiKit.pointer); üst ortadaki görev şeridi OnboardingBanner.
-- Dünya işareti `TutorialMarker` özniteliğiyle bildirilir ("market" ya da "pad:<yükseltme>"); çizimi Interaction/TutorialMarker.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameTypes = require(Shared:WaitForChild("GameTypes"))
local OnboardingSteps = require(Shared:WaitForChild("Modules"):WaitForChild("OnboardingSteps"))
local UiKit = require(script.Parent.Parent:WaitForChild("UiKit"))

type PlayerSave = GameTypes.PlayerSave

local localPlayer = Players.LocalPlayer

local Onboarding = {}

export type Buttons = {
	shop: GuiObject,
	upgrades: GuiObject,
	roadmap: GuiObject,
	production: GuiObject,
}

export type Hud = {
	step: (state: PlayerSave) -> number,
	apply: (state: PlayerSave, canAffordUpgrade: boolean, upgradeId: string?) -> number,
}

-- Oturuma özgü ilerleme (Yol Haritası bu oturumda açıldı mı); kayda yazılmaz
local progress: OnboardingSteps.Progress = { roadmapOpened = false }

Onboarding.TOTAL = OnboardingSteps.TOTAL

function Onboarding.markRoadmapOpened()
	progress.roadmapOpened = true
end

-- 0 = bitti; 1..6 = sıradaki adım
function Onboarding.stepFor(state: PlayerSave): number
	return OnboardingSteps.stepFor(state, progress)
end

-- Temel adımlar (1-3) tamamlandı mı: Adalar gibi sonraki menü karoları buna bakar
function Onboarding.basicsDone(state: PlayerSave): boolean
	return OnboardingSteps.basicsDone(Onboarding.stepFor(state))
end

local function setAttributeIfChanged(name: string, value: any)
	if localPlayer:GetAttribute(name) ~= value then
		localPlayer:SetAttribute(name, value)
	end
end

-- Vurguları uygular; hangi adımda olduğunu döner
function Onboarding.create(buttons: Buttons): Hud
	local pulseShop = UiKit.pulse(buttons.shop)
	local pulseUpgrades = UiKit.pulse(buttons.upgrades)
	local pulseRoadmap = UiKit.pulse(buttons.roadmap)
	local pulseProduction = UiKit.pulse(buttons.production)
	-- Parlayan düğmenin yanında "Buraya dokun" oku (yalnızca ilk adımlarda)
	local pointShop = UiKit.pointer(buttons.shop, "Buraya dokun")
	local pointUpgrades = UiKit.pointer(buttons.upgrades, "Buraya dokun")
	local pointRoadmap = UiKit.pointer(buttons.roadmap, "Buraya dokun")
	local pointProduction = UiKit.pointer(buttons.production, "Buraya dokun")
	local function apply(state: PlayerSave, canAffordUpgrade: boolean, upgradeId: string?): number
		local step = Onboarding.stepFor(state)
		local expansionAffordable = false
		if step == 5 then
			local targetId, cost = OnboardingSteps.cheapestExpansion(state)
			expansionAffordable = targetId ~= nil and state.cash >= cost
		end
		local marker = ""
		if step == 1 then
			marker = "market"
		elseif step == 3 and canAffordUpgrade and upgradeId then
			marker = `pad:{upgradeId}`
		end
		-- İlk hayvan oyuncunun kendi seçimidir: Pazar, parası olsun olmasın (başlangıç parası hayvana yeter) işaretlenir
		local upgradesTarget = (step == 3 and canAffordUpgrade) or (step == 5 and expansionAffordable)
		pulseShop(step == 1)
		pulseUpgrades(upgradesTarget)
		pulseRoadmap(step == 4)
		pulseProduction(step == 6)
		pointShop(step == 1)
		pointUpgrades(upgradesTarget)
		pointRoadmap(step == 4)
		pointProduction(step == 6)
		setAttributeIfChanged("TutorialMarker", marker)
		-- CollectorGuide: yeşil platforma giden ışın
		setAttributeIfChanged("TutorialGuide", step == 2)
		return step
	end
	return {
		step = Onboarding.stepFor,
		apply = apply,
	}
end

return Onboarding
