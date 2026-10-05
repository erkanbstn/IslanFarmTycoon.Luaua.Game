--!strict
-- İlk bakışta sonuçlar; kaynaklar ve takılı olmayan eşyalar isteğe bağlı açılır.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local GameTypes = require(Shared:WaitForChild("GameTypes"))
local EffectSummary = require(Shared:WaitForChild("Modules"):WaitForChild("EffectSummary"))
local FarmMath = require(Shared:WaitForChild("Modules"):WaitForChild("FarmMath"))
local Environment = require(Shared:WaitForChild("Modules"):WaitForChild("Environment"))
local UiKit = require(script.Parent.Parent:WaitForChild("UiKit"))
local ItemText = require(script.Parent:WaitForChild("ItemText"))

type PlayerSave = GameTypes.PlayerSave
local EffectsSection = {}
local PERK_NAMES: { [string]: string } = {
	income = "Kalıcı Gelir",
	growth = "Hızlı Büyüme",
	starting_cash = "Başlangıç Kasası",
	upgrade_discount = "Açılış İndirimi",
	facility_speed = "Tesis Hızı",
	offline = "Çevrimdışı Kazanç",
	contract = "Sipariş Ödülü",
	ready_start = "Hazır Başlangıç",
}

local function rounded(value: number): number
	return math.round(value * 100) / 100
end

function EffectsSection.create(parent: Frame): { update: (PlayerSave) -> (), reset: () -> () }
	local grid = UiKit.autoGrid(parent, 0, 2)
	local cards: { UiKit.Card } = {}
	for index, entry in
		{
			{ "📈", "Şu anki gelir" },
			{ "⭐", "Eşya ve rebirth" },
			{ "🌱", "Ana hayvan büyümesi" },
			{ "🌙", "Çevrimdışı kazanç" },
		}
	do
		local card = UiKit.autoTile(grid, index, entry[1], { compact = true })
		UiKit.setText(card.title, entry[2])
		card.action.Visible = false
		card.detail.TextSize = UiKit.TextSize.Heading
		card.detail.FontFace = UiKit.Font.Bold
		if index == 1 then
			card.detail.TextColor3 = UiKit.Color.Green
		end
		cards[index] = card
	end
	local temporary = UiKit.text(parent, "", "Body")
	temporary.Name = "ActiveTemporaryEffects"
	temporary.LayoutOrder = 1
	local level = UiKit.text(parent, "", "Body", UiKit.Color.Gold)
	level.LayoutOrder = 2
	local details = UiKit.disclosure(parent, 3, "Etki kaynaklarını göster")
	local limits = UiKit.text(details.body, "", "Body")
	limits.LayoutOrder = 0
	UiKit.text(
		details.body,
		"Kaynak farkları, o kaynak çıkarıldığında gelirdeki değişimdir; birbirine eklenmez.",
		"Caption"
	).LayoutOrder =
		1
	local sourceText = UiKit.text(details.body, "", "Body")
	sourceText.LayoutOrder = 2
	local equipmentDetails = UiKit.disclosure(parent, 4, "Takılı ve sahip olunan eşyalar")
	local equipmentText = UiKit.text(equipmentDetails.body, "", "Body")
	equipmentText.LayoutOrder = 0
	local perkDetails = UiKit.disclosure(parent, 5, "Açılmış kalıcı kazanımlar")
	local perkText = UiKit.text(perkDetails.body, "", "Body")
	perkText.LayoutOrder = 0
	local current: PlayerSave? = nil
	local function update(save: PlayerSave)
		current = save
		local summary = EffectSummary.snapshot(save, Workspace:GetServerTimeNow(), details.isExpanded())
		UiKit.setText(cards[1].detail, `{FarmMath.formatMoney(summary.income)}/sn`)
		UiKit.setText(cards[2].detail, `{rounded(summary.incomeFactor)}x`)
		UiKit.setText(cards[3].detail, `{rounded(summary.growthSpeed)}x`)
		UiKit.setText(cards[4].detail, `%{rounded(summary.offlineRate * 100)} · {summary.offlineHours} saat`)
		local season = Environment.getSeason(save.envOverride)
		local weather = Environment.getWeather(save.envOverride)
		local active = {
			`{season.displayName} · {weather.displayName}`,
			`Yürüme ve koşma: +%{rounded((summary.movementMultiplier - 1) * 100)} · Eşya sınırı +%{math.round(
				Config.MOVEMENT_SPEED_BONUS_CAP * 100
			)}`,
		}
		if summary.passFactor > 1 then
			table.insert(
				active,
				if summary.runDouble
					then "2x gelir açık; tur sonunda biter. Kalıcı 2x varsa birlikte çarpılmaz."
					else "Kalıcı 2x gelir açık."
			)
		end
		if summary.returnActive then
			table.insert(
				active,
				`Dönüş etkisi: inek geliri {Config.PROGRESSION.returnIncomeMultiplier}x · {math.ceil(
					summary.returnSeconds / 60
				)} dk kaldı`
			)
		end
		UiKit.setText(temporary, table.concat(active, "\n"))
		UiKit.setText(
			level,
			`R{summary.count}/{Config.PROGRESSION.maxRebirth} · Ödüller ve sıradaki hedef Rebirth sekmesinde`
		)
		if details.isExpanded() then
			UiKit.setText(
				limits,
				`Nakit deposu: {FarmMath.formatMoney(summary.storageCap)}\nEşya ve rebirth gelir sınırı: {Config.PROGRESSION.permanentIncomeCap}x · {if summary.incomeCapped
					then "Sınır etkin"
					else "Sınıra ulaşılmadı"}`
			)
			local lines = {}
			for _, entry in summary.sources do
				table.insert(lines, `{entry.label} · {FarmMath.formatMoney(entry.incomeDelta)}/sn fark`)
			end
			table.insert(lines, `Ekipman ve kalıcı sipariş artısı: +%{rounded(summary.contractBonus * 100)}`)
			for _, entry in summary.facilities do
				local recipe = Config.PRODUCTION_RECIPES[entry.id]
				table.insert(
					lines,
					`{recipe.displayName} · Parti süresi {entry.duration} sn{if entry.goods
						then ` · Ürün önizlemesi {entry.goods}`
						else ""}`
				)
			end
			for _, entry in summary.zones do
				local zone = Config.ZONES[entry.id]
				table.insert(
					lines,
					`{Config.getZoneName(zone, save.farmId or save.activeMainFarmId)} · Kapasite {entry.capacity} · Büyüme {rounded(
						entry.growthSpeed
					)}x · Soy Sv.{entry.lineage}`
				)
			end
			for _, id in summary.islands do
				local island = Config.FARM_ISLANDS[id]
				table.insert(lines, `{island.displayName} · {island.trait}`)
			end
			if summary.upgradeQuote then
				local quote = summary.upgradeQuote
				local upgrade = Config.getUpgrade(quote.id)
				if upgrade then
					table.insert(
						lines,
						`{upgrade.displayName} · Şu an {FarmMath.formatMoney(quote.price)} · Ekipman ve etki olmadan {FarmMath.formatMoney(
							quote.withoutEquipmentAndPerk
						)}`
					)
				end
			end
			UiKit.setText(
				sourceText,
				if #lines > 0 then table.concat(lines, "\n") else "Gelir değiştiren takılı kaynak yok."
			)
		end
		if equipmentDetails.isExpanded() then
			local lines = {}
			for _, entry in summary.equipment do
				local item = Config.ITEMS[entry.id]
				table.insert(
					lines,
					`{item.displayName} · {if entry.equipped
						then "Takılı; etkisi açık"
						else "Takılı değil; etkisi kapalı"}\n{ItemText.describe(item)}`
				)
			end
			UiKit.setText(equipmentText, if #lines > 0 then table.concat(lines, "\n\n") else "Henüz eşyan yok.")
		end
		if perkDetails.isExpanded() then
			local lines = {}
			for _, id in Config.PROGRESSION.perkOrder do
				local perkLevel = FarmMath.getPerkLevel(save, id)
				if perkLevel > 0 then
					local effect = Config.PROGRESSION.perks[id].effects
					local description = if id == "ready_start"
						then `Hazır Başlangıç Sv.{perkLevel} · Gelir +%{rounded(
							perkLevel * (effect.incomeBonus or 0) * 100
						)}`
						elseif id == "offline" then `Çevrimdışı oran +{rounded(
							perkLevel * (effect.offlineBonus or 0) * 100
						)} puan · Süre +{perkLevel * (effect.offlineHours or 0)} saat`
						elseif
							id == "starting_cash"
						then `Başlangıç kasası +{perkLevel * (effect.startingAnimals or 0)} ana hayvan bedeli`
						elseif id == "growth" then `Büyüme hızı artısı +%{rounded(
							perkLevel * (effect.growthExcess or 0) * 100
						)}`
						else ItemText.describe({
							effects = {
								incomeBonus = if effect.incomeBonus then perkLevel * effect.incomeBonus else nil,
								upgradeDiscount = if effect.upgradeDiscount
									then perkLevel * effect.upgradeDiscount
									else nil,
								facilitySpeed = if effect.facilitySpeed then perkLevel * effect.facilitySpeed else nil,
								contractBonus = if effect.contractBonus then perkLevel * effect.contractBonus else nil,
							},
						} :: any)
					table.insert(lines, `{PERK_NAMES[id]} · {description}`)
				end
			end
			for index = 1, math.min(summary.count, Config.PROGRESSION.maxRebirth) do
				local milestone = Config.PROGRESSION.milestones[index]
				table.insert(lines, `R{index} · {milestone.displayName}\n{milestone.description}`)
			end
			UiKit.setText(
				perkText,
				if #lines > 0 then table.concat(lines, "\n\n") else "Kalıcı kazanımlar ilk rebirth ile açılır."
			)
		end
	end
	for _, disclosure in { details, equipmentDetails, perkDetails } do
		disclosure.button.Activated:Connect(function()
			if current then
				update(current)
			end
		end)
	end
	local function reset()
		for _, disclosure in { details, equipmentDetails, perkDetails } do
			disclosure.setExpanded(false)
		end
	end
	parent:GetPropertyChangedSignal("Visible"):Connect(function()
		if not parent.Visible then
			reset()
		end
	end)
	return { update = update, reset = reset }
end

return EffectsSection
