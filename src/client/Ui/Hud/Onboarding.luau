--!strict
-- İlk adımlar yönlendirmesi: adım kayıt durumundan türetilir (mantık Modules/OnboardingSteps); kapatma işareti hesaba kayıtlıdır.
--   1) İlk hayvanı al        Pazar düğmesi + dünyada pazar tezgâhı işareti (para şartı yok: oyuncu hayvanı kendi alır)
--   2) Parayı topla          yeşil platforma ışın çizgisi (CollectorGuide)
--   3) İlk yükseltmeyi al    Yükseltmeler düğmesi + dünyada ilgili yapım alanı işareti
--   4) Üretimde ilk parti    Üretim düğmesi
-- Her vurgulu düğmede ayrıca zıplayan "Buraya dokun" oku vardır (UiKit.pointer); üst ortadaki görev şeridi OnboardingBanner.
-- Atla ve "tekrar göster" sunucuya RequestSetPreference("tutorialDone") ile gider; kayıtlı değer SavedTutorialDone özniteliğidir.
-- Dünya işareti `TutorialMarker` özniteliğiyle bildirilir ("market" ya da "pad:<yükseltme>"); çizimi Interaction/TutorialMarker.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local GameTypes = require(Shared:WaitForChild("GameTypes"))
local OnboardingSteps = require(Shared:WaitForChild("Modules"):WaitForChild("OnboardingSteps"))
local UiKit = require(script.Parent.Parent:WaitForChild("UiKit"))

type PlayerSave = GameTypes.PlayerSave

local localPlayer = Players.LocalPlayer

local Onboarding = {}

export type Buttons = {
	shop: GuiObject,
	upgrades: GuiObject,
	production: GuiObject,
}

export type Hud = {
	step: (state: PlayerSave) -> number,
	apply: (state: PlayerSave, canAffordUpgrade: boolean, upgradeId: string?) -> number,
}

-- Atla/tekrar göster sunucu onayına kadar anında yansır (kayıtlı değer SavedTutorialDone gelince bu iptal olur)
local pendingSkip: boolean? = nil
local cancelGuidance: (() -> ())? = nil
local changed = Instance.new("BindableEvent")
Onboarding.Changed = changed.Event

local function isSkipped(): boolean
	if pendingSkip ~= nil then
		return pendingSkip
	end
	return localPlayer:GetAttribute("SavedTutorialDone") == true
end

local function send(done: boolean)
	pendingSkip = done
	Remotes.get("RequestSetPreference"):FireServer("tutorialDone", done)
	changed:Fire()
end

function Onboarding.skip()
	send(true)
	if cancelGuidance then
		cancelGuidance()
	end
end

-- "Başlangıç rehberini göster": işaret kaldırılır, sıradaki adım durumdan yeniden türer
function Onboarding.replay()
	send(false)
end

-- Rehber açık mı (Ayarlar anahtarı): kapalıysa hiçbir adım gösterilmez
function Onboarding.isActive(): boolean
	return not isSkipped()
end

Onboarding.TOTAL = OnboardingSteps.TOTAL

localPlayer:GetAttributeChangedSignal("SavedTutorialDone"):Connect(function()
	-- Sunucu değeri kesinleşti (kendi isteğimizin yanıtı ya da ilk üretim partisi)
	pendingSkip = nil
	changed:Fire()
end)

-- 0 = bitti; 1..4 = sıradaki adım
function Onboarding.stepFor(state: PlayerSave): number
	return OnboardingSteps.stepFor(state, { skipped = isSkipped() })
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
	local pulseProduction = UiKit.pulse(buttons.production)
	-- Parlayan düğmenin yanında "Buraya dokun" oku (yalnızca ilk adımlarda)
	local pointShop = UiKit.pointer(buttons.shop, "Buraya dokun")
	local pointUpgrades = UiKit.pointer(buttons.upgrades, "Buraya dokun")
	local pointProduction = UiKit.pointer(buttons.production, "Buraya dokun")
	cancelGuidance = function()
		pulseShop(false)
		pulseUpgrades(false)
		pulseProduction(false)
		pointShop(false)
		pointUpgrades(false)
		pointProduction(false)
		setAttributeIfChanged("TutorialMarker", "")
		setAttributeIfChanged("TutorialGuide", false)
	end
	local function apply(state: PlayerSave, canAffordUpgrade: boolean, upgradeId: string?): number
		local step = Onboarding.stepFor(state)
		local marker = ""
		if step == 1 then
			marker = "market"
		elseif step == 3 and canAffordUpgrade and upgradeId then
			marker = `pad:{upgradeId}`
		end
		-- İlk hayvan oyuncunun kendi seçimidir: Pazar, parası olsun olmasın (başlangıç parası hayvana yeter) işaretlenir
		local upgradesTarget = step == 3 and canAffordUpgrade
		pulseShop(step == 1)
		pulseUpgrades(upgradesTarget)
		pulseProduction(step == 4)
		pointShop(step == 1)
		pointUpgrades(upgradesTarget)
		pointProduction(step == 4)
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
