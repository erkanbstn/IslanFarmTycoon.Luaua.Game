--!strict
-- Hayvan etiketleri: ad etiketi ve ırk seviyesi (renk ve yıldız).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local WorldUi = require(Shared:WaitForChild("WorldUi"))

local function addNameTag(model: Model, text: string, extraHeight: number)
	local anchor = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	if not anchor then
		return
	end
	local _, boxSize = model:GetBoundingBox()
	local length = utf8.len(text) or #text
	WorldUi.tag(anchor, "NameTag", {
		text = text,
		widthStuds = math.max(length * 0.32 + 0.6, 2.2),
		heightStuds = 0.8,
		worldOffset = Vector3.new(0, boxSize.Y / 2 + 1 + extraHeight, 0),
		maxDistance = 45,
	})
end

-- Irk geliştirme rozeti: seviye 1+ olan hayvanın üstünde, ad etiketinin üzerinde küçük bir yıldız + "Sv.N" etiketi.
-- Renk kademeyi gösterir (bronz 1-3, gümüş 4-6, altın 7-9, elmas 10). Görsel yeniden kurulmadan yerinde güncellenir.
local LINEAGE_TIER_COLORS = {
	Color3.fromRGB(205, 127, 50),
	Color3.fromRGB(190, 198, 210),
	Color3.fromRGB(255, 200, 70),
	Color3.fromRGB(110, 220, 255),
}

local function lineageTier(level: number): number
	return if level >= Config.LINEAGE.maxLevel then 4 elseif level >= 7 then 3 elseif level >= 4 then 2 else 1
end

local function applyLineage(model: Model, level: number, extraHeight: number)
	model:SetAttribute("Lineage", level)
	local anchor = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	if not anchor then
		return
	end
	local old = anchor:FindFirstChild("LineageTag")
	if old then
		old:Destroy()
	end
	if level <= 0 then
		return
	end
	local _, boxSize = model:GetBoundingBox()
	WorldUi.tag(anchor, "LineageTag", {
		text = `Sv.{level}`,
		icon = "⭐",
		tint = LINEAGE_TIER_COLORS[lineageTier(level)],
		widthStuds = 2.6,
		heightStuds = 0.7,
		worldOffset = Vector3.new(0, boxSize.Y / 2 + 1.9 + extraHeight, 0),
		maxDistance = 32,
	})
end

return {
	addNameTag = addNameTag,
	applyLineage = applyLineage,
}
