--!strict
return function(create: any)
	local copies: { any } = {}
	local function node(class: string, name: string): any
		local value: any = { Name = name, children = {}, attributes = {}, destroyed = false }
		function value:IsA(expected: string): boolean
			return class == expected
				or (expected == "BasePart" and (class == "Part" or class == "WedgePart"))
				or (expected == "LuaSourceContainer" and class == "Script")
		end
		function value:GetChildren(): any
			local children = {}
			for _, child in self.children do
				if child.Parent == self and not child.destroyed then
					table.insert(children, child)
				end
			end
			return children
		end
		function value:FindFirstChild(childName: string): any
			for _, child in self:GetChildren() do
				if child.Name == childName then
					return child
				end
			end
			return nil
		end
		function value:GetDescendants(): any
			local descendants = {}
			for _, child in self:GetChildren() do
				table.insert(descendants, child)
				for _, nested in child:GetDescendants() do
					table.insert(descendants, nested)
				end
			end
			return descendants
		end
		function value:SetAttribute(key: string, attribute: any)
			self.attributes[key] = attribute
		end
		function value:GetAttribute(key: string): any
			return self.attributes[key]
		end
		function value:Destroy()
			self.destroyed = true
			for _, child in self:GetChildren() do
				child:Destroy()
			end
			self.Parent = nil
		end
		function value:Clone(): any
			local copy = node(class, name)
			for _, key in
				{
					"Size",
					"Color",
					"Material",
					"Transparency",
					"Anchored",
					"CanCollide",
					"CanQuery",
					"CanTouch",
					"CastShadow",
					"MeshType",
					"Scale",
				}
			do
				copy[key] = self[key]
			end
			copy.attributes = table.clone(self.attributes)
			for _, child in self:GetChildren() do
				local nested = child:Clone()
				nested.Parent = copy
				table.insert(copy.children, nested)
			end
			if class == "Model" then
				table.insert(copies, copy)
			end
			return copy
		end
		return value
	end
	local function add(parent: any, class: string, name: string): any
		local child = node(class, name)
		child.Parent = parent
		table.insert(parent.children, child)
		return child
	end
	local serverStorage = node("Folder", "ServerStorage")
	local replicatedStorage = node("Folder", "ReplicatedStorage")
	local surfaces = add(add(serverStorage, "Folder", "Assets"), "Folder", "SurfaceModels")
	local budgetCalls = 0
	local assets = create({
		GetService = function(_self: any, service: string): any
			return if service == "ServerStorage" then serverStorage else replicatedStorage
		end,
	}, {
		step = function(units: number)
			assert(units >= 2, "cloning budget includes the wrapper and its descendants")
			budgetCalls += 1
		end,
	})
	local ok, err = pcall(assets.part, "SurfaceModels", "Missing")
	assert(not ok and string.find(tostring(err), "zorunlu", 1, true), "missing physical core must stop setup")
	assert(#copies == 0 and budgetCalls == 0, "missing model cannot create fallback geometry")
	local template = add(surfaces, "Model", "Ground")
	local original = add(template, "Part", "Ground")
	original.Size, original.Color, original.Material, original.Transparency = "size", "color", "material", 0
	original.Anchored, original.CanCollide, original.CanQuery, original.CanTouch, original.CastShadow =
		false, true, true, true, false
	original:SetAttribute("SurfaceRole", "ground")
	local mesh = add(original, "SpecialMesh", "Mesh")
	mesh.MeshType, mesh.Scale = "Cylinder", "mesh-scale"
	local scriptNode = add(original, "Script", "ImportedScript")
	for _ = 1, 60 do
		local part = assets.part("SurfaceModels", "Ground")
		assert(part ~= original and part.Parent == nil and not part.destroyed, "extraction detaches a live cloned Part")
		assert(
			part.Size == original.Size
				and part.Color == original.Color
				and part.Material == original.Material
				and part.Transparency == 0,
			"model geometry and style survive extraction"
		)
		assert(
			part.Anchored and not part.CanTouch and part.CanCollide and part.CanQuery and not part.CastShadow,
			"loader sanitizes anchoring/touch and preserves model physics flags"
		)
		assert(
			part:GetAttribute("ModelAsset") == "SurfaceModels/Ground" and part:GetAttribute("SurfaceRole") == "ground",
			"detached part retains model identity and source attributes"
		)
		local copiedMesh = part:FindFirstChild("Mesh")
		assert(
			copiedMesh
				and copiedMesh ~= mesh
				and copiedMesh.MeshType == mesh.MeshType
				and copiedMesh.Scale == mesh.Scale
				and not copiedMesh.destroyed,
			"primitive mesh survives wrapper cleanup"
		)
		assert(not part:FindFirstChild("ImportedScript"), "imported executable content is stripped")
		assert(
			copies[#copies].destroyed and #copies[#copies]:GetChildren() == 0,
			"every successful extraction destroys its empty wrapper"
		)
		part:Destroy()
	end
	assert(
		not template.destroyed
			and original.Parent == template
			and not original.Anchored
			and original.CanTouch
			and not scriptNode.destroyed,
		"source template stays reusable and unmodified"
	)
	assert(
		original:GetAttribute("ModelAsset") == nil and template:GetAttribute("ModelAsset") == nil,
		"clone identity never mutates the source template"
	)
	local extra = add(template, "Part", "Extra")
	ok, err = pcall(assets.part, "SurfaceModels", "Ground")
	assert(
		not ok and string.find(tostring(err), "tek bir Part", 1, true),
		"multiple parts must not silently discard geometry"
	)
	local rejected = copies[#copies]
	assert(
		rejected.destroyed and rejected.children[1].destroyed and rejected.children[2].destroyed,
		"invalid wrapper destroys all cloned parts"
	)
	assert(not extra.destroyed and not original.destroyed, "rejection leaves original geometry intact")
	local invalid = add(surfaces, "Model", "Wedge")
	add(invalid, "WedgePart", "Wedge")
	ok = pcall(assets.part, "SurfaceModels", "Wedge")
	assert(
		not ok and copies[#copies].destroyed,
		"Part-only contract rejects unsupported geometry and cleans its wrapper"
	)
	for _, copy in copies do
		assert(copy.destroyed, "repeated successful and rejected extractions cannot leak model wrappers")
	end
	assert(budgetCalls == 62, "each existing template clone is budgeted exactly once")
	print(
		"model-assets: required single-Part extraction, preserved mesh/physics, unchanged templates and wrapper cleanup passed"
	)
end
