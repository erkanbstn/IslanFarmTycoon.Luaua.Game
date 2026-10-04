--!strict
-- Tema şablonunu mevcut ağaca uygular; ortak zemin/çit/dekor parçalarının kimliği korunur.
local CollectionService = game:GetService("CollectionService")
local VisualWorkBudget = require(script.Parent:WaitForChild("VisualWorkBudget"))

local ThemePatch = {}
export type Stats = { kept: number, created: number, removed: number, writes: number }

local PART_PROPERTIES = {
	"Size",
	"Color",
	"Material",
	"MaterialVariant",
	"Transparency",
	"Reflectance",
	"Anchored",
	"CanCollide",
	"CanTouch",
	"CanQuery",
	"CastShadow",
	"CollisionGroup",
	"Massless",
	"RootPriority",
	"CustomPhysicalProperties",
	"PivotOffset",
	"TopSurface",
	"BottomSurface",
	"FrontSurface",
	"BackSurface",
	"LeftSurface",
	"RightSurface",
}
local POSITION_CFRAMES = { AreaCFrame = true, IslandFrame = true, WetFrame = true }
local POSITION_VECTORS = { PathStart = true, PathEnd = true }
local FOLIAGE_NAMES: { [string]: boolean } = {
	Leaves = true,
	Needles = true,
	Berry = true,
	Fruit = true,
	Bloom = true,
	Stem = true,
	Blossom = true,
	Petals = true,
}
-- Her iki kurulum yolu aynı mevsim başlangıç değerlerini taşır.
function ThemePatch.captureFoliage(part: BasePart)
	if FOLIAGE_NAMES[part.Name] then
		if part:GetAttribute("ThemeBaseColor") == nil then
			part:SetAttribute("ThemeBaseColor", part.Color)
		end
		if part:GetAttribute("ThemeBaseSize") == nil then
			part:SetAttribute("ThemeBaseSize", part.Size)
		end
	end
end

local LEAF_PROPERTIES: { [string]: { string } } = {
	PointLight = { "Brightness", "Color", "Enabled", "Range", "Shadows" },
	SpotLight = { "Brightness", "Color", "Enabled", "Range", "Shadows", "Angle", "Face" },
	SurfaceLight = { "Brightness", "Color", "Enabled", "Range", "Shadows", "Angle", "Face" },
	SpecialMesh = { "MeshType", "MeshId", "TextureId", "Scale", "Offset", "VertexColor" },
	Attachment = { "CFrame", "Visible" },
}

local function setProperty(target: Instance, property: string, value: any, stats: Stats)
	local object: any = target
	local previous = object[property]
	if typeof(previous) == "CFrame" and typeof(value) == "CFrame" then
		local difference = previous:ToObjectSpace(value)
		local _, angle = difference:ToAxisAngle()
		if difference.Position.Magnitude < 0.0001 and math.abs(angle) < 0.00001 then
			return
		end
	end
	if object[property] ~= value then
		object[property] = value
		stats.writes += 1
	end
end

local function syncMetadata(target: Instance, source: Instance, delta: CFrame, stats: Stats)
	setProperty(target, "Name", source.Name, stats)
	local attributes = source:GetAttributes()
	for name in target:GetAttributes() do
		if attributes[name] == nil and name ~= "ThemeBaseColor" and name ~= "ThemeBaseSize" then
			target:SetAttribute(name, nil)
			stats.writes += 1
		end
	end
	for name, original in attributes do
		local value = original
		if
			(typeof(original) == "CFrame" and (POSITION_CFRAMES :: any)[name])
			or (typeof(original) == "Vector3" and (POSITION_VECTORS :: any)[name])
		then
			value = delta * original
		end
		if target:GetAttribute(name) ~= value then
			target:SetAttribute(name, value)
			stats.writes += 1
		end
	end
	local tags: { [string]: boolean } = {}
	for _, tag in CollectionService:GetTags(source) do
		tags[tag] = true
		if not CollectionService:HasTag(target, tag) then
			CollectionService:AddTag(target, tag)
		end
	end
	for _, tag in CollectionService:GetTags(target) do
		if not tags[tag] then
			CollectionService:RemoveTag(target, tag)
		end
	end
end

local function key(instance: Instance, delta: CFrame): string
	-- Ada/bölge adı ve hayvanı değişebilir, fiziksel yuva aynı kalır.
	if instance:IsA("Model") then
		local base = instance:FindFirstChild("IslandBase") or instance:FindFirstChild("Ground")
		if base and base:IsA("BasePart") then
			local position = delta * base.Position
			return `{base.Name}:{math.round(position.X * 100)},{math.round(position.Z * 100)}`
		end
	end
	return `{instance.ClassName}:{instance.Name}`
end

local function reusable(instance: Instance): boolean
	return instance:IsA("Model")
		or instance:IsA("Folder")
		or instance:IsA("BasePart")
		or LEAF_PROPERTIES[instance.ClassName] ~= nil
end

local function syncNode(
	target: Instance,
	source: Instance,
	delta: CFrame,
	stats: Stats,
	preserveChild: ((Instance) -> boolean)?
)
	VisualWorkBudget.step()
	stats.kept += 1
	syncMetadata(target, source, delta, stats)
	if target:IsA("BasePart") and source:IsA("BasePart") then
		if FOLIAGE_NAMES[source.Name] then
			if target:GetAttribute("ThemeBaseColor") ~= source.Color then
				target:SetAttribute("ThemeBaseColor", source.Color)
			end
			if target:GetAttribute("ThemeBaseSize") ~= source.Size then
				target:SetAttribute("ThemeBaseSize", source.Size)
			end
		end
		setProperty(target, "CFrame", delta * source.CFrame, stats)
		for _, property in PART_PROPERTIES do
			setProperty(target, property, (source :: any)[property], stats)
		end
		if target:IsA("Part") and source:IsA("Part") then
			setProperty(target, "Shape", source.Shape, stats)
		end
	elseif target:IsA("Model") and source:IsA("Model") then
		setProperty(target, "ModelStreamingMode", source.ModelStreamingMode, stats)
	end
	local leafProperties = LEAF_PROPERTIES[source.ClassName]
	if leafProperties then
		for _, property in leafProperties do
			setProperty(target, property, (source :: any)[property], stats)
		end
	end
	local buckets: { [string]: { Instance } } = {}
	for _, child in target:GetChildren() do
		if preserveChild and preserveChild(child) then
			continue
		end
		local childKey = key(child, CFrame.identity)
		local bucket = buckets[childKey] or {}
		table.insert(bucket, child)
		buckets[childKey] = bucket
	end
	local mapped: { [Instance]: Instance } = {}
	for _, child in source:GetChildren() do
		VisualWorkBudget.step()
		local bucket = buckets[key(child, delta)]
		local old = if bucket then table.remove(bucket, 1) else nil
		if old and old.ClassName == child.ClassName and reusable(child) then
			syncNode(old, child, delta, stats)
			mapped[child] = old
		else
			if old then
				local weight = #old:GetDescendants() + 1
				VisualWorkBudget.step(weight)
				old:Destroy()
				stats.removed += weight
			end
			local copy: Instance
			if reusable(child) then
				-- Clone() yalnız yapraklarda: büyük ada ağacı bir karede çoğaltılmaz.
				copy = Instance.new(child.ClassName)
				copy.Name = child.Name
				if copy:IsA("BasePart") then
					copy.Anchored = true
					copy.CanCollide = false
					copy.Transparency = 1
				end
				copy.Parent = target
				syncNode(copy, child, delta, stats)
				stats.kept -= 1
				stats.created += 1
			else
				local weight = #child:GetDescendants() + 1
				VisualWorkBudget.step(weight)
				copy = child:Clone()
				copy.Parent = target
				stats.created += weight
			end
			mapped[child] = copy
		end
	end
	for _, bucket in buckets do
		for _, old in bucket do
			local weight = #old:GetDescendants() + 1
			VisualWorkBudget.step(weight)
			old:Destroy()
			stats.removed += weight
		end
	end
	if target:IsA("Model") and source:IsA("Model") then
		local primary = if source.PrimaryPart then mapped[source.PrimaryPart] else nil
		if primary and primary:IsA("BasePart") then
			if target.PrimaryPart ~= primary then
				target.PrimaryPart = primary
			end
		else
			target.PrimaryPart = nil
			target.WorldPivot = delta * source:GetPivot()
		end
	end
end

function ThemePatch.apply(
	target: Instance,
	source: Instance,
	delta: CFrame,
	preserveChild: ((Instance) -> boolean)?
): Stats
	local stats: Stats = { kept = 0, created = 0, removed = 0, writes = 0 }
	syncNode(target, source, delta, stats, preserveChild)
	return stats
end

return ThemePatch
