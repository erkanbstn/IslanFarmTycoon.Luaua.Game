--!strict
-- Başlangıç öğreticisinin kalıcı ilerlemesi (sunucu yazar): `tutorialStage` yalnız artar, `tutorialDone` atla/bitti işaretidir.
-- Adımların kendisi durumdan türer (Shared/Modules/OnboardingSteps); burası tamamlanan adımı kalıcı yapar ki rebirth, satış ya da
-- tüketilen eşya gibi sonraki durum değişiklikleri tamamlanmış adımı geri getirmesin. Roblox'a dokunmaz: `OnboardingSteps` çağıran
-- tarafından verilir (saf modüller birbirini require etmez), `player` yoksa öznitelik yazılmaz.
local Preferences = require(script.Parent.Preferences)

local TutorialProgress = {}

local function publishPreferences(data: any, player: any?)
	if player == nil then
		return
	end
	for name, attribute in Preferences.attributes(data) do
		player:SetAttribute(name, attribute)
	end
end

-- Öğreticiyi bitmiş işaretler (yönetici test eylemleri ve son adım). Değiştiyse true; öznitelikler yayımlanır.
function TutorialProgress.markDone(data: any, player: any?): boolean
	if not Preferences.apply(data, "tutorialDone", true) then
		return false
	end
	publishPreferences(data, player)
	return true
end

-- Durumu gözlemler: aşama yalnız artar (azalmaz). Son aşamaya (rebirth) ya da kazanç eşiğine ulaşınca öğretici bitmiş işaretlenir.
-- Aşama değiştiyse true döner (çağıran kaydı zaten kirli sayar: durum itme/kayıt döngüsü).
function TutorialProgress.observe(data: any, steps: any, player: any?): boolean
	local before = steps.clampStage(data.tutorialStage)
	local after = steps.reachedStage(data)
	if after <= before and (data.tutorialStage == nil or data.tutorialStage == before) then
		return false
	end
	-- Bozuk/eksik kayıtlı değer (ör. kesirli) normalleşir; azalma asla yazılmaz
	data.tutorialStage = math.max(before, after)
	if after >= steps.TOTAL and before < steps.TOTAL then
		TutorialProgress.markDone(data, player)
	end
	return after > before
end

return TutorialProgress
