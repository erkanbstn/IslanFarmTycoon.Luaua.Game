--!strict
-- Yetki sadece değişmez Roblox UserId ile belirlenir; ad/attribute/Studio yetki vermez.
local AdminPolicy = {}
local OWNER_USER_ID = 11641916529
local MAX_REQUEST_ID = 2147483647
local MAX_COMMAND_CASH = 1e12

function AdminPolicy.isAllowed(userId: unknown): boolean
	return typeof(userId) == "number" and userId == OWNER_USER_ID
end

function AdminPolicy.validRequestId(value: unknown): boolean
	return typeof(value) == "number" and value == value and value >= 1 and value <= MAX_REQUEST_ID and value % 1 == 0
end

function AdminPolicy.validCash(value: unknown, positiveOnly: boolean?): boolean
	return typeof(value) == "number"
		and value == value
		and value >= (if positiveOnly then 1 else 0)
		and value <= MAX_COMMAND_CASH
		and value % 1 == 0
end

function AdminPolicy.validAction(value: unknown): boolean
	return value == "setCash"
		or value == "addCash"
		or value == "setWeather"
		or value == "setSeason"
		or value == "setTime"
		or value == "setLights"
		or value == "setLightLevel"
		or value == "growAll"
		or value == "unlockIslands"
		or value == "fillSlots"
		or value == "forceMerchant"
		or value == "forceGolden"
		or value == "completeSeason"
		or value == "resetEvents"
end

return AdminPolicy
