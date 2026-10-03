--!strict
-- Real service functions are injected by check-visual-identity.py; only Roblox and dependencies are doubles.
local methods = {}
local mt = {
	__index = function(self, key)
		if key == "Parent" then
			return rawget(self, "_parent")
		end
		if key == "Position" then
			return self.CFrame.Position
		end
		return methods[key]
	end,
	__newindex = function(self, key, value)
		if key ~= "Parent" then
			rawset(self, key, value)
			return
		end
		local old = rawget(self, "_parent")
		if old then
			local index = table.find(old._children, self)
			if index then
				table.remove(old._children, index)
			end
		end
		rawset(self, "_parent", value)
		if value then
			table.insert(value._children, self)
		end
	end,
}
local Vector3 = {
	new = function(x, y, z)
		return { X = x, Y = y, Z = z }
	end,
	one = { X = 1, Y = 1, Z = 1 },
}
local Vector2 = {
	new = function(x, y)
		return { X = x, Y = y }
	end,
}
local cfmt = {
	__mul = function(a, b)
		return setmetatable({
			Position = Vector3.new(
				a.Position.X + b.Position.X,
				a.Position.Y + b.Position.Y,
				a.Position.Z + b.Position.Z
			),
		}, getmetatable(a))
	end,
}
local CFrame = {
	new = function(x, y, z)
		return setmetatable({ Position = Vector3.new(x or 0, y or 0, z or 0) }, cfmt)
	end,
}
CFrame.Angles = function()
	return CFrame.new()
end
local Color3 = {
	fromRGB = function(r, g, b)
		return { R = r, G = g, B = b }
	end,
}
local Enum = {
	KeyCode = { F = "F", ButtonX = "X", E = "E" },
	Material = { Glass = "Glass", Grass = "Grass" },
	ModelStreamingMode = { Atomic = "Atomic" },
}
local Instance = {
	new = function(class)
		return setmetatable({
			_class = class,
			_children = {},
			_attrs = {},
			Name = class,
			CFrame = CFrame.new(),
			Size = Vector3.new(24, 1, 24),
			Color = {},
			Triggered = { Connect = function() end },
		}, mt)
	end,
}
function methods:IsA(class)
	return self._class == class or (class == "BasePart" and self._class == "Part")
end
function methods:GetChildren()
	return table.clone(self._children)
end
function methods:GetDescendants()
	local all = {}
	for _, child in self._children do
		table.insert(all, child)
		for _, nested in child:GetDescendants() do
			table.insert(all, nested)
		end
	end
	return all
end
function methods:FindFirstChild(name, recursive)
	for _, child in self._children do
		if child.Name == name then
			return child
		end
	end
	if recursive then
		for _, child in self._children do
			local found = child:FindFirstChild(name, true)
			if found then
				return found
			end
		end
	end
	return nil
end
function methods:FindFirstChildWhichIsA(class, recursive)
	for _, child in (if recursive then self:GetDescendants() else self:GetChildren()) do
		if child:IsA(class) then
			return child
		end
	end
	return nil
end
function methods:WaitForChild(name)
	return self:FindFirstChild(name) or self
end
function methods:SetAttribute(name, value)
	self._attrs[name] = value
end
function methods:GetAttribute(name)
	return self._attrs[name]
end
function methods:ClearAllChildren()
	for _, child in self:GetChildren() do
		child:Destroy()
	end
end
function methods:Destroy()
	self:ClearAllChildren()
	self.Parent = nil
	self.destroyed = true
end
function methods:PivotTo(cf)
	self.CFrame = cf
end
function methods:GetPivot()
	return self.CFrame
end
local function child(parent, class, name)
	local object = Instance.new(class)
	object.Name = name
	object.Parent = parent
	return object
end
local service = Instance.new("Folder")
function service:GetServerTimeNow()
	return 100
end
function service:AddTag() end
local game = {
	GetService = function()
		return service
	end,
}
local DateTime = {
	now = function()
		return { UnixTimestampMillis = 100000 }
	end,
}
local factories = {}
-- SOURCE_FACTORIES
local deps = { GameTypes = {}, Remotes = {}, UiTheme = { Color = { Gold = {} } }, Shared = service }
deps.InstanceUtil = {
	getOrCreateFolder = function(parent, name)
		return parent:FindFirstChild(name) or child(parent, "Folder", name)
	end,
}
deps.WorldUi = {
	configureProximityPrompt = function() end,
	setSignText = function(board, text)
		board.text = text
	end,
}
deps.WorldDecor = { markNightWindow = function() end, grassTufts = function() end, optimize = function() end }
deps.IslandSiteParts = { markObstacles = function() end }
deps.ModelAssets = {
	clone = function(_, name)
		local model = Instance.new("Model")
		model.Name = name
		child(model, "Part", "Floor")
		return model
	end,
	eachNamed = function() end,
	partCount = function()
		return 1
	end,
}
deps.Config = {
	MAIN_FARM_LIMIT = 6,
	ZONES = { starter = {} },
	STAGE_DISPLAY = { young = "Young" },
	getExtensionUpgrade = function(id)
		return { id = id }
	end,
	getExtension = function(id)
		return { id = id }
	end,
	getBarnLevelConfig = function()
		return {}
	end,
	getAnimalLook = function(id)
		return { modelId = id, displayName = id }
	end,
}
deps.FarmMath = {
	formatUpgradePrice = function(save)
		return tostring(save.price)
	end,
	getExtensionCapacity = function(save, id)
		return save.capacities[id]
	end,
	countInExtension = function(save, id)
		return save.counts[id] or 0
	end,
	getLineageLevel = function(save)
		return save.lineage or 1
	end,
	getZoneCapacity = function()
		return 4
	end,
	isInProduction = function(animal)
		return animal.working == true
	end,
}
deps.JobMarks = {
	extensionSummary = function(save, id)
		return save.counts[id] or 0, 20, 200
	end,
	ensureAnchor = function() end,
	setExtension = function(model, count, capacity)
		model:SetAttribute("JobCount", count)
		model:SetAttribute("JobCapacity", capacity)
	end,
}
deps.IslandSpecialization = {
	EXTENSIONS = {
		a = { id = "a", island = "home", title = "A" },
		b = { id = "b", island = "home", title = "B" },
		c = { id = "c", island = "home", title = "C" },
	},
	markObstacles = function() end,
	buildExtensionVisual = function(parent, _, id)
		local model = child(parent, "Model", id)
		child(model, "Part", "SpecialtySign")
		return model
	end,
	buildForSaleSign = function(parent, _, id, price)
		local model = child(parent, "Model", `ForSale_{id}`)
		local board = child(model, "Part", "ForSaleSign")
		board.text = `Satılık · {price}`
		return model
	end,
}
deps.ExtensionAreas = {
	find = function()
		return CFrame.new(), Vector3.new(20, 1, 20), "walk"
	end,
}
deps.AnimalModels = {
	createAnimalVisual = function()
		local model = Instance.new("Model")
		child(model, "Part", "Body")
		return model
	end,
}
deps.AnimalLabels = {
	addNameTag = function() end,
	tierOf = function()
		return 1
	end,
	applyLineage = function(model, level)
		model:SetAttribute("Lineage", level)
	end,
}
deps.AnimalPlacement = {
	getAnimalArea = function(ground)
		return ground.CFrame, ground.Size
	end,
	slotCFrame = function(cf)
		return cf
	end,
	placeOnSurface = function(model, cf)
		model:PivotTo(cf)
	end,
	findZoneGround = function(plot, id)
		return plot:FindFirstChild("Zones"):FindFirstChild(id):FindFirstChild("Ground")
	end,
}
local extension = factories.ExtensionVisualService(deps)
local animal = factories.AnimalVisualService(deps)
local zone = factories.ZoneVisualService(deps)
local barn = factories.BarnVisualService(deps)
local plot = Instance.new("Model")
local island = child(child(plot, "Folder", "Islands"), "Model", "home")
island:SetAttribute("FarmIslandId", "home")
child(plot, "Part", "BarnSpot")
local starter = child(child(plot, "Folder", "Zones"), "Model", "starter")
starter:SetAttribute("ZoneId", "starter")
child(starter, "Part", "Ground")
local secondZone = child(starter.Parent, "Model", "second")
child(secondZone, "Part", "Ground")
local save = {
	unlockedIslands = { home = true },
	purchased = { a = true, b = true },
	capacities = { a = 3, b = 3, c = 2 },
	counts = {},
	price = 100,
	unlockedZones = { starter = true },
	animals = {
		{ animalId = "goat", uid = "1", stage = "adult", zoneId = "starter" },
		{ animalId = "cow", uid = "2", stage = "adult", zoneId = "starter" },
	},
}
local function refresh()
	extension.apply(plot, save)
	animal.refresh(plot, save)
	barn.applyForPlayer(plot, 1)
	zone.apply(starter, "starter", true)
	zone.apply(secondZone, "second", true)
	zone.applyLevelFlags(starter, { "basic" })
	zone.applyLevelFlags(secondZone, { "basic" })
end
refresh()
local root = island:FindFirstChild("ExtensionVisuals")
local a, b, c = root:FindFirstChild("a"), root:FindFirstChild("b"), root:FindFirstChild("c")
local modelA, modelB, sale = a:FindFirstChild("a"), b:FindFirstChild("b"), c:FindFirstChild("ForSale_c")
local propsA, propsB = a:FindFirstChild("CapacityProps"), b:FindFirstChild("CapacityProps")
local promptA = modelA:FindFirstChild("ExtensionAssignPrompt", true)
local salePrompt = sale:FindFirstChild("BuyExtensionPrompt", true)
local animals = plot:FindFirstChild("Animals")
local animal1, animal2 = animals:FindFirstChild("goat_1"), animals:FindFirstChild("cow_2")
local initialBarn = plot:FindFirstChild("Barn")
local decor, flags = starter:FindFirstChild("Decor"), starter:FindFirstChild("LevelFlags")
local decor2, flags2 = secondZone:FindFirstChild("Decor"), secondZone:FindFirstChild("LevelFlags")
save.money = 999
save.price = 80
save.counts.a = 1
refresh()
assert(a:FindFirstChild("a") == modelA and b:FindFirstChild("b") == modelB, "global discount retains owned extensions")
assert(
	a:FindFirstChild("CapacityProps") == propsA and b:FindFirstChild("CapacityProps") == propsB,
	"discount retains capacity decor"
)
assert(
	c:FindFirstChild("ForSale_c") == sale and sale:FindFirstChild("BuyExtensionPrompt", true) == salePrompt,
	"sale sign and buy callback retained"
)
assert(sale:FindFirstChild("ForSaleSign").text == "Satılık · 80", "discount refreshes sale text in place")
assert(
	modelA:FindFirstChild("ExtensionAssignPrompt", true) == promptA and promptA.ObjectText == "A (1/3)",
	"job change retains prompt and updates count"
)
assert(
	animals:FindFirstChild("goat_1") == animal1 and animals:FindFirstChild("cow_2") == animal2,
	"unrelated state retains animals"
)
assert(plot:FindFirstChild("Barn") == initialBarn, "unrelated state retains barn")
assert(
	starter:FindFirstChild("Decor") == decor and starter:FindFirstChild("LevelFlags") == flags,
	"unrelated state retains zone"
)
save.capacities.a = 4
refresh()
assert(
	a:FindFirstChild("a") == modelA and modelA:FindFirstChild("ExtensionAssignPrompt", true) == promptA,
	"capacity retains structure and prompt"
)
assert(propsA.destroyed and a:FindFirstChild("CapacityProps") ~= propsA, "capacity replaces only its decor")
assert(b:FindFirstChild("CapacityProps") == propsB, "other extension capacity decor retained")
save.capacities.a = 5
local cap4 = a:FindFirstChild("CapacityProps")
refresh()
assert(
	a:FindFirstChild("CapacityProps") == cap4 and promptA.ObjectText == "A (1/5)",
	"clamped same visual capacity keeps decor but updates logical capacity"
)
save.purchased.c = true
refresh()
assert(sale.destroyed and c:FindFirstChild("c"), "purchase replaces only its sale model")
assert(a:FindFirstChild("a") == modelA and b:FindFirstChild("b") == modelB, "purchase retains other structures")
save.animals[1].stage = "young"
refresh()
assert(animal1.destroyed and animals:FindFirstChild("goat_1") ~= animal1, "growth replaces only affected animal")
assert(animals:FindFirstChild("cow_2") == animal2, "growth retains other animal")
zone.applyLevelFlags(starter, { "basic", "basic" })
assert(flags.destroyed and starter:FindFirstChild("Decor") == decor, "zone level changes only level props")
zone.apply(starter, "starter", false)
assert(
	decor.destroyed
		and secondZone:FindFirstChild("Decor") == decor2
		and secondZone:FindFirstChild("LevelFlags") == flags2,
	"zone lock retains other zone"
)
barn.applyForPlayer(plot, 2)
assert(initialBarn.destroyed and plot:FindFirstChild("Barn") ~= initialBarn, "barn level replaces barn")
assert(
	a:FindFirstChild("a") == modelA and animals:FindFirstChild("cow_2") == animal2,
	"barn upgrade retains extension and animal"
)
print("PASS visual identity: discounts, jobs, capacities, purchase, animal growth, zone level/lock, barn level")
