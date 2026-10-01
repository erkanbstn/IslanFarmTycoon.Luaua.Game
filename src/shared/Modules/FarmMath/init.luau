--!strict
-- Sunucu ve client'ın aynı sonucu hesaplaması için ortak oyun hesapları.
-- Sunucu bunları KARAR için, client sadece GÖSTERİM için kullanır.
-- Parçalar (Modules/FarmMath/): Format, Core, Contracts, Recipes, Counts, Islands, Lineage, Expansion, Production, Income, Animals.

local Format = require(script:WaitForChild("Format"))
local Core = require(script:WaitForChild("Core"))
local Goods = require(script:WaitForChild("Goods"))
local Contracts = require(script:WaitForChild("Contracts"))
local Recipes = require(script:WaitForChild("Recipes"))
local Counts = require(script:WaitForChild("Counts"))
local Islands = require(script:WaitForChild("Islands"))
local Lineage = require(script:WaitForChild("Lineage"))
local Expansion = require(script:WaitForChild("Expansion"))
local Production = require(script:WaitForChild("Production"))
local Income = require(script:WaitForChild("Income"))
local Animals = require(script:WaitForChild("Animals"))

export type UpgradeStatus = Islands.UpgradeStatus
export type LineageStatus = Lineage.LineageStatus
export type ExpansionStatus = Expansion.ExpansionStatus
export type ZoneBlock = Animals.ZoneBlock
export type ContractOffer = Contracts.Offer

local FarmMath = {}

-- Format
FarmMath.formatMoney = Format.formatMoney
FarmMath.formatRate = Format.formatRate
-- Core
FarmMath.applyDerived = Core.applyDerived
FarmMath.getEquippedBonus = Core.getEquippedBonus
FarmMath.getBonus = Core.getBonus
FarmMath.hasPet = Core.hasPet
FarmMath.hasOfflineIncome = Core.hasOfflineIncome
FarmMath.getUpgradeBonus = Core.getUpgradeBonus
FarmMath.getEquippedMultiplier = Core.getEquippedMultiplier
FarmMath.getUpgradeCost = Core.getUpgradeCost
FarmMath.getFarmCostMultiplier = Core.getFarmCostMultiplier
FarmMath.settleFarmIncome = Core.settleFarmIncome
FarmMath.hasAutoCollect = Core.hasAutoCollect
FarmMath.getStage = Core.getStage
FarmMath.getBarnConfig = Core.getBarnConfig
FarmMath.getStorageCap = Core.getStorageCap
FarmMath.getStorageLevel = Core.getStorageLevel
-- Goods
FarmMath.getGoodsCap = Goods.getGoodsCap
FarmMath.getGoodsAmount = Goods.getGoodsAmount
FarmMath.getGoodsSpace = Goods.getGoodsSpace
FarmMath.addGoods = Goods.addGoods
FarmMath.removeGoods = Goods.removeGoods
FarmMath.getGoodsWorth = Goods.getGoodsWorth
FarmMath.getFullGoods = Goods.getFullGoods
FarmMath.getGoodsSellAmount = Goods.getSellAmount
FarmMath.getGoodsSellValue = Goods.getSellValue
FarmMath.sellGoods = Goods.sellGoods
FarmMath.getGoodsBarterWorth = Goods.getBarterWorth
FarmMath.planGoodsBarter = Goods.planBarter
FarmMath.applyGoodsBarter = Goods.applyBarter
-- Counts
FarmMath.countInZone = Counts.countInZone
FarmMath.countInExtension = Counts.countInExtension
FarmMath.getActiveTask = Counts.getActiveTask
FarmMath.isInProduction = Counts.isInProduction
FarmMath.getExtensionCapacity = Counts.getExtensionCapacity
FarmMath.countAnimals = Counts.countAnimals
FarmMath.zoneAllows = Counts.zoneAllows
-- Islands
FarmMath.isUpgradeInTheme = Islands.isUpgradeInTheme
FarmMath.getUpgradeStatus = Islands.getUpgradeStatus
FarmMath.getExtensionStatus = Islands.getExtensionStatus
FarmMath.themeIslands = Islands.themeIslands
FarmMath.getNextIsland = Islands.getNextIsland
FarmMath.countIslands = Islands.countIslands
-- Lineage
FarmMath.getLineageLevel = Lineage.getLineageLevel
FarmMath.getLineageCost = Lineage.getLineageCost
FarmMath.getLineageStatus = Lineage.getLineageStatus
-- Expansion
FarmMath.getExpansionLevel = Expansion.getExpansionLevel
FarmMath.getBuildBonus = Expansion.getBuildBonus
FarmMath.getBuildMultiplier = Expansion.getBuildMultiplier
FarmMath.getNextBuildLevel = Expansion.getNextBuildLevel
FarmMath.getBuildLevelKind = Expansion.getBuildLevelKind
FarmMath.getExpansionStep = Expansion.getExpansionStep
FarmMath.getZoneCapacity = Expansion.getZoneCapacity
FarmMath.getMaxZoneCapacity = Expansion.getMaxZoneCapacity
FarmMath.getExpansionCost = Expansion.getExpansionCost
FarmMath.getExpansionStatus = Expansion.getExpansionStatus
FarmMath.getFacilityDuration = Expansion.getFacilityDuration
FarmMath.getFacilityCost = Expansion.getFacilityCost
-- Production
FarmMath.getGrowthSpeed = Production.getGrowthSpeed
FarmMath.countProductionAdults = Production.countProductionAdults
FarmMath.pickProductionAnimals = Production.pickProductionAnimals
FarmMath.getGoodsYield = Production.getGoodsYield
FarmMath.forEachFarm = Goods.forEachFarm
FarmMath.resolveRecipe = Recipes.resolve
-- Ahır siparişleri
FarmMath.getContractWindow = Contracts.window
FarmMath.getContractSecondsLeft = Contracts.secondsLeft
FarmMath.getContractOffers = Contracts.offers
FarmMath.isContractDone = Contracts.isDone
FarmMath.canFulfillContract = Contracts.canFulfill
FarmMath.fulfillContract = Contracts.fulfill
FarmMath.getReadyContractCount = Contracts.readyCount
FarmMath.getContractGoods = Contracts.availableGoods
FarmMath.getContractBaseUnits = Contracts.baseUnits
FarmMath.getContractIncomeFloor = Contracts.incomeFloor
FarmMath.findProductionOption = Recipes.findOption
FarmMath.petKindFor = Recipes.petKindFor
FarmMath.getProductionReward = Production.getProductionReward
FarmMath.combineGrowthExcess = Production.combineGrowthExcess
FarmMath.getGrowthSeconds = Production.getGrowthSeconds
FarmMath.snapshotGrowthSpeeds = Production.snapshotGrowthSpeeds
FarmMath.preserveGrowthProgress = Production.preserveGrowthProgress
-- Income
FarmMath.getAnimalMultiplier = Income.getAnimalMultiplier
FarmMath.getSeasonEffect = Income.getSeasonEffect
FarmMath.getAnimalIncome = Income.getAnimalIncome
FarmMath.estimateForgoneIncome = Income.estimateForgoneIncome
FarmMath.previewGoodsYield = Income.previewGoodsYield
FarmMath.computeIncomePerSecond = Income.computeIncomePerSecond
FarmMath.computeIncomeOverInterval = Income.computeIncomeOverInterval
FarmMath.computeOfflineEarnings = Income.computeOfflineEarnings
FarmMath.getOfflineTerms = Income.getOfflineTerms
-- Animals
FarmMath.getAnimalPrice = Animals.getAnimalPrice
FarmMath.getSellPrice = Animals.getSellPrice
FarmMath.getNewAnimalBornAt = Animals.getNewAnimalBornAt
FarmMath.findSellableAnimal = Animals.findSellableAnimal
FarmMath.getFreeSlots = Animals.getFreeSlots
FarmMath.getBulkPrice = Animals.getBulkPrice
FarmMath.findReplaceableFish = Animals.findReplaceableFish
FarmMath.getFishReplacementPrice = Animals.getFishReplacementPrice
FarmMath.hasUnlockedAnimalZone = Animals.hasUnlockedAnimalZone
FarmMath.findZoneForAnimal = Animals.findZoneForAnimal

return FarmMath
