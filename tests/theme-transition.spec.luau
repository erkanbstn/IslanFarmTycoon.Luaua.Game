--!strict
-- Gerçek tema uzlaştırıcısını geçici nesnelerle sınar; kayıtlı harita ve şablonlara dokunmaz.
return function(context: any)
	local RunService = game:GetService("RunService")
	local ServerStorage = game:GetService("ServerStorage")
	local CollectionService = game:GetService("CollectionService")
	assert(RunService:IsStudio(), "Tema geçiş testi yalnız Studio'da çalışır.")
	local patch = context.ThemePatch
	local budget = context.VisualWorkBudget
	assert(patch and budget, "ThemePatch ve VisualWorkBudget test bağlamında verilmelidir.")

	local scratch = Instance.new("Folder")
	scratch.Name = "ThemeTransitionRegression"
	scratch.Parent = ServerStorage
	local scopeDepth = 0
	local function begin(guard: (() -> boolean)?)
		budget.begin(guard)
		scopeDepth += 1
	end
	local function finish()
		budget.finish()
		scopeDepth -= 1
	end
	local function part(parent: Instance, name: string, position: Vector3): Part
		local result = Instance.new("Part")
		result.Name = name
		result.Anchored = true
		result.CanTouch = false
		result.Size = Vector3.new(4, 1, 4)
		result.Position = position
		result.Parent = parent
		return result
	end
	local function signature(instance: Instance): string
		local fields = { instance.ClassName, instance.Name }
		if instance:IsA("BasePart") then
			table.insert(fields, tostring(instance.CFrame))
			table.insert(fields, tostring(instance.Size))
			table.insert(fields, tostring(instance.Color))
			table.insert(fields, tostring(instance.Material))
			table.insert(fields, tostring(instance.CanCollide))
		end
		for name, value in instance:GetAttributes() do
			table.insert(fields, `attribute:{name}:{tostring(value)}`)
		end
		for _, tag in CollectionService:GetTags(instance) do
			table.insert(fields, `tag:{tag}`)
		end
		for _, child in instance:GetChildren() do
			table.insert(fields, signature(child))
		end
		table.sort(fields)
		return table.concat(fields, "|")
	end

	local ok, failure = xpcall(function()
		local source = Instance.new("Model")
		source.Name = "SourceTheme"
		source.Parent = scratch
		local ground = part(source, "HomeGround", Vector3.new(2, 1, 3))
		ground:SetAttribute("RevealZoneId", "new_zone")
		ground:SetAttribute("AreaCFrame", ground.CFrame)
		ground:SetAttribute("PathStart", ground.Position)
		CollectionService:AddTag(ground, "ThemeTransitionSourceTag")
		local island = Instance.new("Model")
		island.Name = "OldAnimalIsland"
		island.Parent = source
		local islandBase = part(island, "IslandBase", Vector3.new(30, 0, 40))
		local fence = part(island, "Fence", Vector3.new(31, 2, 40))
		part(source, "Duplicate", Vector3.new(-5, 1, 0))
		part(source, "Duplicate", Vector3.new(-10, 1, 0))
		local delta = CFrame.new(2000, 100, 3000) * CFrame.Angles(0, math.rad(45), 0)
		local target = Instance.new("Model")
		target.Name = "TargetTheme"
		target.Parent = scratch
		patch.apply(target, source, delta)
		local keptGround = target:FindFirstChild("HomeGround") :: Part
		local keptIsland = target:FindFirstChild("OldAnimalIsland") :: Model
		local keptBase = keptIsland:FindFirstChild("IslandBase") :: Part
		local keptFence = keptIsland:FindFirstChild("Fence") :: Part
		local duplicates: { [Instance]: boolean } = {}
		for _, child in target:GetChildren() do
			if child.Name == "Duplicate" then
				duplicates[child] = true
			end
		end
		local obsolete = part(target, "Obsolete", Vector3.zero)
		keptGround:SetAttribute("ObsoleteAttribute", true)
		CollectionService:AddTag(keptGround, "ThemeTransitionObsoleteTag")
		ground.Color = Color3.fromRGB(95, 150, 70)
		ground.Material = Enum.Material.Grass
		ground.CanCollide = false
		ground.Size = Vector3.new(8, 2, 8)
		island.Name = "NewAnimalIsland"
		part(source, "Added", Vector3.new(7, 1, 8))
		local untouchedSource = signature(source)
		begin(nil)
		local stats = patch.apply(target, source, delta)
		finish()
		assert(target:FindFirstChild("HomeGround") == keptGround, "Ana zemin yeniden yaratıldı.")
		assert(
			target:FindFirstChild("NewAnimalIsland") == keptIsland,
			"Hayvan adı değişince ada yuvası yeniden yaratıldı."
		)
		assert(keptIsland:FindFirstChild("IslandBase") == keptBase, "Ada tabanı yeniden yaratıldı.")
		assert(keptIsland:FindFirstChild("Fence") == keptFence, "Ortak çit yeniden yaratıldı.")
		assert(
			keptBase.CFrame == delta * islandBase.CFrame and keptFence.CFrame == delta * fence.CFrame,
			"Tema özelliği beklenen kaynakla eşleşmedi."
		)
		assert(
			keptGround.Size == ground.Size and keptGround.Color == ground.Color,
			"Tema özelliği beklenen kaynakla eşleşmedi."
		)
		assert(
			keptGround.Material == ground.Material and keptGround.CanCollide == ground.CanCollide,
			"Tema özelliği beklenen kaynakla eşleşmedi."
		)
		assert(
			keptGround:GetAttribute("AreaCFrame") == delta * ground.CFrame,
			"Tema özelliği beklenen kaynakla eşleşmedi."
		)
		assert(
			keptGround:GetAttribute("PathStart") == delta * ground.Position,
			"Tema özelliği beklenen kaynakla eşleşmedi."
		)
		assert(keptGround:GetAttribute("ObsoleteAttribute") == nil, "Tema özelliği beklenen kaynakla eşleşmedi.")
		assert(CollectionService:HasTag(keptGround, "ThemeTransitionSourceTag"))
		assert(not CollectionService:HasTag(keptGround, "ThemeTransitionObsoleteTag"), "Eski etiket silinmedi.")
		assert(
			obsolete.Parent == nil and target:FindFirstChild("Added") ~= nil,
			"Tema özelliği beklenen kaynakla eşleşmedi."
		)
		assert(stats.created == 1 and stats.removed == 1, "Değişmeyen nesneler topluca yeniden kuruldu.")
		for duplicate in duplicates do
			assert(duplicate.Parent == target, "Aynı adlı kardeş nesne kaybedildi.")
		end
		assert(signature(source) == untouchedSource, "Kaynak şablon değiştirildi.")
		local stable = patch.apply(target, source, delta)
		assert(stable.created == 0 and stable.removed == 0 and stable.writes == 0, "Aynı tema tekrar yazılıyor.")

		if RunService:IsRunning() then
			local beforeCancel = signature(target)
			ground.Color = Color3.fromRGB(200, 60, 60)
			begin(function()
				return true
			end)
			begin(function()
				return false
			end)
			local applied = pcall(function()
				patch.apply(target, source, delta)
			end)
			finish()
			finish()
			assert(not applied and signature(target) == beforeCancel, "İptal edilen kapsam dünyayı değiştirdi.")
			local valid = true
			begin(function()
				return valid
			end)
			budget.step(128)
			task.defer(function()
				valid = false
			end)
			local resumed = pcall(function()
				budget.step()
			end)
			finish()
			assert(not resumed, "Kare bekleyişinden sonra iptal kontrol edilmedi.")
		end
	end, debug.traceback)
	while scopeDepth > 0 do
		finish()
	end
	scratch:Destroy()
	assert(ok, tostring(failure))
	return "ThemePatch: identity, property/tag/attribute diff, spatial rename, duplicate names, idempotence, cancellation passed"
end
