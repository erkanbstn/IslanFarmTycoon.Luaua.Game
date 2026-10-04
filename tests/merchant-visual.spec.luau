--!strict
-- Gerçek NPC kaynağı: ziyaret yaşam döngüsü, mevcut modeli sahiplenme ve prompt mesafesi.
return function(createVisual: any, config: any, merchant: any)
	local vector = {}
	local mt: any = {}
	function vector.new(x: number, y: number, z: number): any
		return setmetatable({ X = x, Y = y, Z = z, Magnitude = math.sqrt(x * x + y * y + z * z) }, mt)
	end
	mt.__add = function(a: any, b: any): any
		return vector.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
	end
	mt.__sub = function(a: any, b: any): any
		return vector.new(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
	end
	mt.__mul = function(a: any, b: number): any
		return vector.new(a.X * b, a.Y * b, a.Z * b)
	end
	local models = {}
	local hub: any = {}
	local hubAvailable = true
	hub.FindFirstChild = function(_self: any, name: string): any
		for _, model in models do
			if model.Parent == hub and model.Name == name then
				return model
			end
		end
		return nil
	end
	local world = {
		FindFirstChild = function(): any
			return if hubAvailable then hub else nil
		end,
	}
	local workspaceMock = {
		FindFirstChild = function(): any
			return world
		end,
	}
	local part = {
		CanCollide = true,
		IsA = function(_self: any, name: string): boolean
			return name == "BasePart"
		end,
	}
	local function makeModel(position: any): any
		local anchor = { Position = position, IsA = part.IsA }
		local model: any = {
			Name = "TravelingMerchant",
			Parent = hub,
			anchor = anchor,
			IsA = function(_self: any, name: string): boolean
				return name == "Model"
			end,
			FindFirstChild = function(self: any): any
				return self.anchor
			end,
			GetDescendants = function(): any
				return { part }
			end,
			GetPivot = function()
				error("purchase distance must use the prompt, not the visual pivot")
			end,
			Destroy = function(self: any)
				self.Parent = nil
				self.destroyed = true
			end,
		}
		table.insert(models, model)
		return model
	end
	local builds = 0
	local npc = {
		vendor = function(parent: any, frame: any, spec: any): any
			assert(spec.action == "merchant" and spec.modelName == "Vendor_store", "real NPC asset is reused")
			builds += 1
			local model = makeModel(frame.Position)
			model.Parent = parent
			return model
		end,
	}
	local root = { Position = vector.new(0, 3, 0), IsA = part.IsA }
	local humanoid = { Health = 100 }
	local player = {
		Character = {
			FindFirstChild = function(): any
				return root
			end,
			FindFirstChildOfClass = function(): any
				return humanoid
			end,
		},
	}
	local loops = {}
	local visual = createVisual(
		{
			GetService = function(_self: any, name: string): any
				return if name == "Workspace"
					then workspaceMock
					else {
						WaitForChild = function(self: any): any
							return self
						end,
					}
			end,
		},
		config,
		npc,
		{ SURFACE_Y = 4 },
		vector,
		{
			lookAt = function(position: any): any
				return { Position = position }
			end,
		},
		{
			new = function(): any
				return { Destroy = function() end }
			end,
		},
		{ ModelStreamingMode = { Atomic = "Atomic" } },
		{
			spawn = function(callback: any)
				table.insert(loops, callback)
			end,
		},
		function(message: string)
			error(message)
		end
	)
	-- Önceden var olan model init sırasında atlanmamalı: eski kod burada mesafeyi hep false döndürüyordu.
	local old = makeModel(root.Position)
	visual.init(function(): boolean
		return true
	end)
	assert(
		builds == 0 and visual.isNear(player),
		"existing NPC is adopted without duplicate and allows nearby purchases"
	)
	visual.init(function(): boolean
		return true
	end)
	assert(#loops == 1, "initialization creates a single refresh loop")
	root.Position = old.anchor.Position + vector.new(config.MERCHANT.buyRadius, 0, 0)
	assert(visual.isNear(player), "configured distance boundary is accepted at the prompt")
	root.Position = old.anchor.Position + vector.new(config.MERCHANT.buyRadius + 0.01, 0, 0)
	assert(not visual.isNear(player), "outside purchase range remains rejected")
	root.Position = old.anchor.Position
	humanoid.Health = 0
	assert(not visual.isNear(player), "dead character cannot buy")
	humanoid.Health = 100
	visual.update(false)
	assert(old.destroyed and not visual.isNear(player), "departure destroys the NPC and purchase anchor")
	visual.update(true)
	assert(builds == 1 and models[#models].Parent == hub, "next visit spawns a fresh NPC")
	visual.update(true)
	assert(builds == 1, "unchanged active visit does not rebuild")
	local incomplete = models[#models]
	incomplete.anchor = nil
	visual.update(true)
	assert(incomplete.destroyed and builds == 2, "legacy NPC without a prompt anchor is repaired")
	for _ = 1, 100 do
		visual.update(false)
		visual.update(true)
	end
	local count = 0
	for _, model in models do
		if model.Parent == hub then
			count += 1
		end
	end
	assert(count == 1, "100 visits retain exactly one current NPC")
	hubAvailable = false
	visual.update(true)
	assert(not visual.isNear(player), "removed hub cannot leave a stale purchase anchor")
	hubAvailable = true
	visual.update(true)
	assert(models[#models].Parent == hub, "hub streaming/replacement can be retried")
	local data = { adminForce = { merchantUntil = 900001 } }
	local at = 900000
	assert(merchant.currentVisit(data, 1, at) ~= nil, "admin arrival uses the same server visit source")
	-- Doğal ziyaret olabilecek kimliği seçmek yerine zorlamadan sonraki beklenti gerçek kaynaktan gelir.
	local natural = merchant.visit(1, 900001)
	local expired = merchant.currentVisit(data, 1, 900001)
	assert((expired ~= nil) == (natural ~= nil and natural.active), "forced visit expires exactly at its end")
	print("PASS merchant visual: existing NPC adoption, prompt distance, spawn/departure, retry and 100 visits")
end
