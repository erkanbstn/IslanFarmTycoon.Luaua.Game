--!strict
return function(create: any)
	local function node(class: string, name: string): any
		local children = {}
		local value: any = { Name = name, children = children, destroyed = false }
		function value:IsA(expected: string): boolean
			return class == expected
				or (expected == "BasePart" and (class == "Part" or class == "WedgePart"))
				or (expected == "LuaSourceContainer" and class == "Script")
		end
		function value:FindFirstChild(childName: string): any
			for _, child in children do
				if child.Name == childName then
					return child
				end
			end
			return nil
		end
		function value:GetDescendants(): any
			local descendants = {}
			for _, child in children do
				if not child.destroyed then
					table.insert(descendants, child)
					for _, nested in child:GetDescendants() do
						table.insert(descendants, nested)
					end
				end
			end
			return descendants
		end
		function value:Destroy()
			self.destroyed = true
			for _, child in children do
				if child.Parent == self then
					child:Destroy()
				end
			end
		end
		function value:Clone(): any
			local clone = node(class, name)
			clone.Size, clone.Color, clone.Material, clone.Transparency =
				self.Size, self.Color, self.Material, self.Transparency
			for _, child in children do
				local copy = child:Clone()
				copy.Parent = clone
				table.insert(clone.children, copy)
			end
			return clone
		end
		return value
	end
	local function add(parent: any, class: string, name: string): any
		local child = node(class, name)
		child.Parent = parent
		table.insert(parent.children, child)
		return child
	end
	local root = node("Folder", "ReplicatedStorage")
	local effects = add(add(root, "Folder", "ClientAssets"), "Folder", "Effects")
	local warnings = {}
	local assets = create({
		GetService = function()
			return root
		end,
	}, function(message)
		table.insert(warnings, message)
	end)
	for _ = 1, 60 do
		assert(assets.clonePart("Effects", "Missing") == nil, "Missing model must not create fallback geometry")
	end
	assert(#warnings == 1, "A missing pool template should warn once")
	local template = add(effects, "Model", "SeasonFragment")
	local original = add(template, "Part", "SeasonFragment")
	original.Size, original.Color, original.Material, original.Transparency = "size", "color", "material", 1
	add(original, "SpecialMesh", "Mesh")
	add(original, "Script", "ImportedPartScript")
	add(template, "Script", "ImportedScript")
	local part = assets.clonePart("Effects", "SeasonFragment")
	assert(part and part ~= original and part.Name == original.Name, "Loader must return a cloned Part")
	assert(
		not part:FindFirstChild("ImportedPartScript") or part:FindFirstChild("ImportedPartScript").destroyed,
		"Imported scripts must be removed before the clone can enter the world"
	)
	assert(part.Parent == nil and not part.destroyed, "Removing the wrapper must preserve the detached part")
	assert(
		part:FindFirstChild("Mesh") and not part:FindFirstChild("Mesh").destroyed,
		"Template mesh must survive extraction"
	)
	assert(
		part.Size == original.Size
			and part.Color == original.Color
			and part.Material == original.Material
			and part.Transparency == 1,
		"Template geometry and style must be preserved"
	)
	assert(
		part.Anchored and not part.CanCollide and not part.CanQuery and not part.CanTouch and not part.CastShadow,
		"Effect parts must remain outside physics and shadows"
	)
	assert(not original.Anchored and not template.destroyed, "Shared template must remain unchanged")
	add(template, "Part", "UnexpectedSecondPart")
	assert(assets.clonePart("Effects", "SeasonFragment") == nil, "Multi-part models must not silently lose geometry")
	local wedge = add(effects, "Model", "Wedge")
	add(wedge, "WedgePart", "Wedge")
	assert(assets.clonePart("Effects", "Wedge") == nil, "Part-only pool contract must reject other geometry")
	assert(
		assets.clonePart("Effects", "Wedge") == nil and #warnings == 3,
		"Invalid templates should also warn only once"
	)
	print(
		"client-model-assets: single-part extraction preserves geometry/mesh, sanitizes physics, rejects missing/invalid templates"
	)
end
