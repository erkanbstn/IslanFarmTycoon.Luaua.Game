--!strict
-- Fiyat: yükseltme, hayvan, yapı geliştirme ve ana çiftlik fiyatlarının TEK hesabı (`FarmMath.getPrice`).
-- Gösterim (arayüz, tabela) ve tahsilat (sunucu) bu işlevleri çağırır; elle fiyat çarpma. Kurallar ve gerekçe: Config/Difficulty.luau.
-- FarmMath cephesi (init.luau) bunları birleştirir; her zaman `FarmMath.<ad>` ile kullan.

local Config = require(script.Parent.Parent.Parent:WaitForChild("Config"))
local GameTypes = require(script.Parent.Parent.Parent:WaitForChild("GameTypes"))
local Core = require(script.Parent:WaitForChild("Core"))
local Counts = require(script.Parent:WaitForChild("Counts"))

type PlayerSave = GameTypes.PlayerSave

local Pricing = {}

export type PriceKind = "upgrade" | "animal" | "expansion" | "farm"

-- Çiftliğin zorluk kademesi: alım sırası (save.tier); eksik/bozuk kayıt 1. kademedir.
function Pricing.getTier(save: PlayerSave?): number
	local tier = if save then save.tier else nil
	if typeof(tier) ~= "number" or tier ~= tier then
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
	local base = math.floor(upgrade.cost * Pricing.getScale(save, Config.getUpgradeIsland(upgrade)) + 0.5)
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
--   "farm":      level = alınacak çiftliğin sırası (sahip olunan sayı + 1); çiftlik çarpanı uygulanmaz.
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

return Pricing
