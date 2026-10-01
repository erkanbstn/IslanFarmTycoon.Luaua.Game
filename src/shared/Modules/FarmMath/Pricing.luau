--!strict
-- Fiyat: yükseltme, hayvan, yapı geliştirme ve ana çiftlik fiyatlarının TEK hesabı (`FarmMath.getPrice`).
-- Gösterim (arayüz, tabela) ve tahsilat (sunucu) bu işlevleri çağırır; elle fiyat çarpma. Kurallar ve gerekçe: Config/Difficulty.luau.
-- FarmMath cephesi (init.luau) bunları birleştirir; her zaman `FarmMath.<ad>` ile kullan.

local Config = require(script.Parent.Parent.Parent:WaitForChild("Config"))
local GameTypes = require(script.Parent.Parent.Parent:WaitForChild("GameTypes"))
local Format = require(script.Parent:WaitForChild("Format"))
local Core = require(script.Parent:WaitForChild("Core"))
local Counts = require(script.Parent:WaitForChild("Counts"))
local Goods = require(script.Parent:WaitForChild("Goods"))

type PlayerSave = GameTypes.PlayerSave

local Pricing = {}

export type PriceKind = "upgrade" | "animal" | "expansion" | "farm"

-- Çiftliğin zorluk kademesi = TEMA numarası (çiftlik numarası; Config.THEMES sırası). Alım sırası serbesttir, fiyat ve zorluk temaya bağlıdır;
-- eksik/bozuk kimlik 1. kademedir. Tek yer burasıdır.
function Pricing.getTier(save: PlayerSave?): number
	local farmId = if save then save.farmId or save.activeMainFarmId else nil
	local tier = if typeof(farmId) == "string" then tonumber(farmId) else nil
	if tier == nil or tier ~= tier then
		return 1
	end
	return math.clamp(math.floor(tier), 1, #Config.DIFFICULTY.tiers)
end

-- Çiftlik çarpanı (ada sırası hariç): 1. çiftlik ve bilinmeyen kayıt x1.
function Pricing.getFarmCostMultiplier(save: PlayerSave?): number
	return Config.DIFFICULTY.tiers[Pricing.getTier(save)].costMultiplier
end

-- Adanın çiftlikteki sırası: ana ada ve temanın erken adası 1, orta 2, geç 3 (THEMES.satellites sırası).
function Pricing.getIslandSlot(save: PlayerSave?, islandId: string?): number
	if not save or not islandId then
		return 1
	end
	local index = table.find(Config.getTheme(save.farmId or save.activeMainFarmId).satellites, islandId)
	return index or 1
end

-- Ada sırası çarpanı: çiftlik ilerledikçe orta ve geç adalar göreli olarak pahalanır; 1. çiftlikte ve ilk adada x1.
function Pricing.getSlotFactor(save: PlayerSave?, islandId: string?): number
	local slot = Pricing.getIslandSlot(save, islandId)
	return 1 + Config.DIFFICULTY.slotSpread * (Pricing.getTier(save) - 1) * (slot - 1)
end

-- Ada açılış primi (DIFFICULTY.islandPremium): çiftlik ilerledikçe orta ve geç adalar geç açılsın, ilk ada alınır alınmaz açılmasın; tier 1'de x1.
function Pricing.getIslandPremium(save: PlayerSave?, islandId: string?): number
	local tier = Pricing.getTier(save)
	if tier <= 1 then
		return 1
	end
	local premium = Config.DIFFICULTY.islandPremium[math.clamp(
		Pricing.getIslandSlot(save, islandId),
		1,
		#Config.DIFFICULTY.islandPremium
	)]
	return 1 + premium.perTier * (tier - 1) ^ premium.power
end

-- Hayvanın bu çiftlikte yaşadığı ada (ilk uygun bölgenin adası; bulunamazsa ana ada)
function Pricing.getAnimalIsland(save: PlayerSave?, animalId: string): string
	local farmId = if save then save.farmId or save.activeMainFarmId else nil
	for _, zoneId in Config.ZONE_ORDER do
		local zone = Config.ZONES[zoneId]
		if zone and Config.zoneAllows(zone, animalId, farmId) then
			return zone.island
		end
	end
	return "home"
end

-- Çiftlik çarpanı x ada sırası çarpanı (tek adanın fiyat katsayısı)
function Pricing.getScale(save: PlayerSave?, islandId: string?): number
	return Pricing.getFarmCostMultiplier(save) * Pricing.getSlotFactor(save, islandId)
end

-- Hayvanın n. alım eğrisi: sahip olunan her aynı tür bu kadar çarpanla pahalılaşır.
function Pricing.getAnimalGrowth(save: PlayerSave?): number
	return Config.ANIMAL_PRICE_GROWTH + Config.DIFFICULTY.animalGrowthPerTier * (Pricing.getTier(save) - 1)
end

local function roundTwoDigits(raw: number): number
	if raw < 10 then
		return math.max(1, math.floor(raw + 0.5))
	end
	local step = 10 ^ (math.floor(math.log10(raw)) - 1)
	return math.floor(raw / step + 0.5) * step
end

local function upgradePrice(save: PlayerSave?, id: string): number
	local upgrade = Config.getUpgrade(id)
	if not upgrade then
		return math.huge
	end
	if not save then
		return upgrade.cost
	end
	local scale = Pricing.getScale(save, Config.getUpgradeIsland(upgrade))
	if upgrade.kind == "island" then
		scale *= Pricing.getIslandPremium(save, upgrade.islandId)
	end
	local base = math.floor(upgrade.cost * scale + 0.5)
	local discount = math.clamp(Core.getEquippedBonus(save, "upgradeDiscount"), 0, 0.9)
	if discount <= 0 then
		return base
	end
	return math.max(1, math.floor(base * (1 - discount)))
end

local function animalPrice(save: PlayerSave?, animalId: string, owned: number): number
	local animalConfig = Config.ANIMALS[animalId]
	if not animalConfig then
		return math.huge
	end
	local scale = Pricing.getScale(save, Pricing.getAnimalIsland(save, animalId))
	return math.floor(animalConfig.price * scale * Pricing.getAnimalGrowth(save) ^ owned)
end

local function expansionPrice(save: PlayerSave, targetId: string, level: number): number
	local config = Config.BUILD_UPGRADES
	if level >= config.maxLevel then
		return math.huge
	end
	local raw: number
	local zone = Config.ZONES[targetId]
	local recipe = Config.PRODUCTION_RECIPES[targetId]
	if zone then
		local animalConfig = Config.ANIMALS[Config.getZoneAnimals(zone, save.farmId or save.activeMainFarmId)[1]]
		if not animalConfig then
			return math.huge
		end
		raw = animalConfig.price
			* config.costMultiplier
			* config.costGrowth ^ level
			* Pricing.getScale(save, zone.island)
	elseif recipe then
		raw = recipe.reward
			* config.facilityCostMultiplier
			* config.facilityCostGrowth ^ level
			* Pricing.getScale(save, recipe.island)
	else
		return math.huge
	end
	raw *= 1 - math.clamp(Core.getBonus(save, "expansionDiscount"), 0, 0.5)
	return roundTwoDigits(raw)
end

local function farmPrice(index: number): number
	local price = Config.MAIN_FARM_PRICES[index]
	return if typeof(price) == "number" then price else math.huge
end

-- Tek fiyat işlevi. kind:
--   "upgrade":   id = yükseltme kimliği (ada, bölge, bina, ahır, eklenti, seviye zincirleri); level kullanılmaz.
--   "animal":    id = hayvan kimliği; level = zaten sahip olunan sayı (varsayılan: çiftlikteki gerçek sayı) -> sıradaki hayvanın fiyatı.
--   "expansion": id = bölge ya da tesis kimliği; level = ulaşılmış seviye (varsayılan: gerçek seviye) -> sonraki seviyenin fiyatı.
--   "farm":      level = alınacak çiftliğin TEMA numarası (MAIN_FARM_PRICES[tema]); çiftlik çarpanı uygulanmaz.
-- Bilinmeyen kimlik ve en üst seviye math.huge döner.
function Pricing.getPrice(save: PlayerSave?, kind: PriceKind, id: string?, level: number?): number
	if kind == "upgrade" then
		return if id then upgradePrice(save, id) else math.huge
	elseif kind == "animal" then
		if not id then
			return math.huge
		end
		local owned = level or (if save then Counts.countAnimals(save, id) else 0)
		return animalPrice(save, id, owned)
	elseif kind == "expansion" then
		if not id or not save then
			return math.huge
		end
		local current = level
		if current == nil then
			local expansions = save.expansions
			local stored = if expansions then expansions[id] else nil
			current = if typeof(stored) == "number" and Core.isFinite(stored)
				then math.clamp(math.floor(stored), 0, Config.BUILD_UPGRADES.maxLevel)
				else 0
		end
		return expansionPrice(save, id, current :: number)
	end
	return farmPrice(level or 1)
end

-- Yükseltmenin bu oyuncu için maliyeti (çiftlik çarpanı, ada sırası ve takılı alet indirimi uygulanır; en az 1).
function Pricing.getUpgradeCost(save: PlayerSave?, upgrade: Config.UpgradeConfig): number
	return Pricing.getPrice(save, "upgrade", upgrade.id)
end

export type GoodsCost = { [string]: number }
export type GoodsShortfall = { goodsId: string, have: number, need: number }

-- Açılışın ürün gereksinimi ({ [ürün] = adet }; yoksa boş tablo). Miktar = temel para fiyatı x pay x adım x kademe çarpanı / ürün birim değeri
-- (yukarı yuvarlanır, en az 1), ahır kapasitesine sığar (gereken ahır seviyesinin ürün kapasitesinin `goods.capShare` payı). Çiftlik 1'in erken adımı ürün istemez.
-- Kaynak ürün temaya göre çözülür (Config.resolveGoodsSource); çözülemeyen kaynak atlanır. Gösterim ve tahsilat bu işlevi kullanır.
function Pricing.getGoodsCost(save: PlayerSave?, upgrade: Config.UpgradeConfig): GoodsCost
	local result: GoodsCost = {}
	local spec = upgrade.goodsCost
	if not spec or not save then
		return result
	end
	local tier = Pricing.getTier(save)
	local settings = Config.DIFFICULTY.goods
	if tier == 1 and spec.step <= settings.tutorialSteps then
		return result
	end
	local stepBase = settings.stepBase[math.clamp(spec.step, 1, #settings.stepBase)]
	local factor = stepBase * (1 + settings.tierGrowth * (tier - 1))
	local farmId = save.farmId or save.activeMainFarmId
	local island = Config.getUpgradeIsland(upgrade)
	local barn = Config.getBarnLevelConfig(Config.getMinBarnLevel(upgrade.id)) or Config.BARN_LEVELS[1]
	local cap = math.max(1, math.floor(barn.goodsCap * settings.capShare))
	for source, share in spec.shares do
		local goodsId = Config.resolveGoodsSource(farmId, source, island)
		local good = if goodsId then Config.GOODS[goodsId] else nil
		if goodsId and good then
			local units = math.max(1, math.ceil(share * upgrade.cost * factor / good.value - 0.000001))
			result[goodsId] = (result[goodsId] or 0) + units
		end
	end
	for goodsId, amount in result do
		result[goodsId] = math.min(amount, cap)
	end
	return result
end

-- Ürün gereksiniminin GOODS_ORDER sırasındaki listesi (gösterim)
function Pricing.listGoodsCost(cost: GoodsCost): { { goodsId: string, amount: number } }
	local list: { { goodsId: string, amount: number } } = {}
	for _, goodsId in Config.GOODS_ORDER do
		local amount = cost[goodsId]
		if amount and amount > 0 then
			table.insert(list, { goodsId = goodsId, amount = amount })
		end
	end
	return list
end

-- Depoda yetmeyen kalemler (boşsa ürün gereksinimi karşılanıyor); save: ahır deposu kök kayıttadır
function Pricing.getGoodsShortfall(save: PlayerSave, cost: GoodsCost): { GoodsShortfall }
	local missing: { GoodsShortfall } = {}
	for _, entry in Pricing.listGoodsCost(cost) do
		local have = Goods.getGoodsAmount(save, entry.goodsId)
		if have < entry.amount then
			table.insert(missing, { goodsId = entry.goodsId, have = have, need = entry.amount })
		end
	end
	return missing
end

-- "Süt ×2 · Yumurta ×1" (çeviri parçaları " · " ile ayrılır; emoji yok)
function Pricing.formatGoodsCost(cost: GoodsCost): string
	local parts: { string } = {}
	for _, entry in Pricing.listGoodsCost(cost) do
		table.insert(parts, `{Config.GOODS[entry.goodsId].displayName} ×{entry.amount}`)
	end
	return table.concat(parts, " · ")
end

-- "Süt 2/4 · Yumurta 0/3" (yetmeyen kalemler: eldeki/gereken)
function Pricing.formatGoodsShortfall(missing: { GoodsShortfall }): string
	local parts: { string } = {}
	for _, entry in missing do
		table.insert(parts, `{Config.GOODS[entry.goodsId].displayName} {entry.have}/{entry.need}`)
	end
	return table.concat(parts, " · ")
end

-- Yükseltmenin gösterilen fiyatı: "$12.4K" ya da ürün de gerekiyorsa "$12.4K · Süt ×2 · Yumurta ×1" (tabela ve buton metni)
function Pricing.formatUpgradePrice(save: PlayerSave?, upgrade: Config.UpgradeConfig): string
	local money = Format.formatMoney(Pricing.getUpgradeCost(save, upgrade))
	local goods = Pricing.formatGoodsCost(Pricing.getGoodsCost(save, upgrade))
	return if goods == "" then money else `{money} · {goods}`
end

return Pricing
