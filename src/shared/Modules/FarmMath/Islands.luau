--!strict
-- Ada teması, yol haritası yükseltme durumu ve sıradaki ada.
-- FarmMath cephesi (init.luau) bunları birleştirir; her zaman `FarmMath.<ad>` ile kullan.

local Config = require(script.Parent.Parent.Parent:WaitForChild("Config"))
local GameTypes = require(script.Parent.Parent.Parent:WaitForChild("GameTypes"))

type PlayerSave = GameTypes.PlayerSave

local Islands = {}

export type UpgradeStatus = "owned" | "available" | "locked"

function Islands.getExtensionStatus(save: PlayerSave, extensionId: string): (UpgradeStatus, { string })
	local upgrade = Config.getExtensionUpgrade(extensionId)
	if not upgrade then
		return "locked", {}
	end
	return Islands.getUpgradeStatus(save, upgrade.id)
end

-- Yol haritası öğesinin durumu; kilitliyse eksik ön koşulların adları
-- Yükseltme bu çiftliğin temasında var mı? (Temada olmayan adaların yükseltmeleri hiçbir zaman alınamaz.)
function Islands.isUpgradeInTheme(save: PlayerSave, upgrade: Config.UpgradeConfig): boolean
	return Config.themeHasIsland(save.farmId or save.activeMainFarmId, Config.getUpgradeIsland(upgrade))
end

function Islands.getUpgradeStatus(save: PlayerSave, upgradeId: string): (UpgradeStatus, { string })
	if save.purchased[upgradeId] then
		return "owned", {}
	end
	local upgrade = Config.getUpgrade(upgradeId)
	if not upgrade then
		return "locked", {}
	end
	if not Islands.isUpgradeInTheme(save, upgrade) then
		return "locked", { "Bu çiftlikte yok" }
	end
	local missing: { string } = {}
	for _, requiredId in upgrade.requires do
		if not save.purchased[requiredId] then
			local required = Config.getUpgrade(requiredId)
			table.insert(missing, if required then required.displayName else requiredId)
		end
	end
	if #missing > 0 then
		return "locked", missing
	end
	return "available", {}
end

-- Henüz açılmamış, ön koşulları tamam olan en ucuz ada (sıradaki ada hedefi)
-- Bu çiftliğin (temasının) adaları: ana ada + 3 küçük ada. Etkin olmayan çiftlik görünümleri farmId taşır.
function Islands.themeIslands(save: PlayerSave): { string }
	return Config.getThemeIslands(save.farmId or save.activeMainFarmId)
end

-- Henüz açılmamış, en ucuz sıradaki ada (yalnızca bu çiftliğin temasındakiler)
function Islands.getNextIsland(save: PlayerSave): (Config.FarmIslandConfig?, Config.UpgradeConfig?)
	local best: Config.FarmIslandConfig? = nil
	local bestUpgrade: Config.UpgradeConfig? = nil
	for _, islandId in Islands.themeIslands(save) do
		local island = Config.FARM_ISLANDS[islandId]
		if island and island.upgradeId and not save.unlockedIslands[islandId] then
			local upgrade = Config.getUpgrade(island.upgradeId)
			if upgrade and (not bestUpgrade or upgrade.cost < bestUpgrade.cost) then
				best, bestUpgrade = island, upgrade
			end
		end
	end
	return best, bestUpgrade
end

function Islands.countIslands(save: PlayerSave): (number, number)
	local owned = 0
	local islands = Islands.themeIslands(save)
	for _, islandId in islands do
		if save.unlockedIslands[islandId] then
			owned += 1
		end
	end
	return owned, #islands
end

return Islands
