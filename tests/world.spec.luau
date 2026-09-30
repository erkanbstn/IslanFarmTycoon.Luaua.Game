--!strict
-- Studio düzenleme modunda çalıştırılır; geçici harita değişiklikleri her kontrolden sonra geri alınır.
-- context (isteğe bağlı): eklenti taze kodu verir { mapBuilder = ... }; verilmezse oyun kodundan yüklenir.
return function(context: any?)
	local RunService = game:GetService("RunService")
	assert(
		RunService:IsStudio() and not RunService:IsRunning(),
		"World testleri Studio düzenleme modunda çalıştırılmalıdır."
	)
	local ServerScriptService = game:GetService("ServerScriptService")
	local Workspace = game:GetService("Workspace")
	local server = ServerScriptService:WaitForChild("Server")
	local sanitizer = require(server:WaitForChild("Modules"):WaitForChild("AssetSanitizer"))
	local mapBuilder = if context and context.mapBuilder
		then context.mapBuilder
		else require(server:WaitForChild("Services"):WaitForChild("MapBuilder"))

	local template = Instance.new("Model")
	local nested = Instance.new("Folder")
	nested.Parent = template
	for _, className in { "Script", "LocalScript", "ModuleScript" } do
		Instance.new(className).Parent = nested
	end
	local part = Instance.new("Part")
	part.Anchored = false
	part.CanCollide = true
	part.CanTouch = true
	part.Parent = template
	local animal = sanitizer.clone(template, false)
	local building = sanitizer.clone(template, true)
	local sanitizedOk, sanitizedError = pcall(function()
		for _, clone in { animal, building } do
			assert(clone.Parent == nil, "Sanitizer klonu dünyaya kendisi eklememeli.")
			for _, descendant in clone:GetDescendants() do
				assert(not descendant:IsA("LuaSourceContainer"), "Çalışabilir kod klonda kaldı.")
				if descendant:IsA("BasePart") then
					assert(descendant.Anchored and not descendant.CanTouch, "Görsel fizik ayarları eksik.")
					assert(descendant.CanCollide == (clone == building), "Çarpışma politikası uygulanmadı.")
				end
			end
		end
		assert(#nested:GetChildren() == 3 and not part.Anchored, "Kaynak şablon değiştirilmemeli.")
	end)
	animal:Destroy()
	building:Destroy()
	template:Destroy()
	assert(sanitizedOk, tostring(sanitizedError))

	-- Harita testi gerçek sözleşmeyi kullanır; fixture elle kopyalanıp eskimez.
	mapBuilder.validate()
	local plots = Workspace:FindFirstChild("Plots") :: Folder
	local first = plots:GetChildren()[1]
	local second = plots:GetChildren()[2]
	assert(first and second, "Harita testi en az iki plot gerektirir.")
	-- Tam sürüm eşleşmesini validate() yapar; burada yalnızca tabana bağlı iskele düzeninin (v13+) varlığı.
	local mapVersion = plots:GetAttribute("MapVersion")
	assert(typeof(mapVersion) == "number" and mapVersion >= 13, "Tabana bağlı iskele düzeni v13+ olmalı.")
	local spots = first:FindFirstChild("BuildSpots") :: Folder
	for _, id in { "milk_factory", "hatchery", "horse_training", "cheese_dairy", "fishing_boat" } do
		local spot = spots:FindFirstChild(id)
		assert(spot and spot:IsA("BasePart"), `Üretim noktası eksik: {id}`)
	end
	local productionSpot = spots:FindFirstChild("milk_factory") :: BasePart
	productionSpot.Parent = nil
	local missingProductionAccepted = pcall(mapBuilder.validate)
	productionSpot.Parent = spots
	assert(not missingProductionAccepted, "Üretim yapı noktası eksikken harita kabul edildi.")
	local boatSpot = spots:FindFirstChild("fishing_boat") :: BasePart
	assert(
		boatSpot:GetAttribute("BoatPatrolX") == 6 and boatSpot:GetAttribute("BoatPatrolZ") == 3,
		"Tekne gezi sınırları eksik."
	)

	-- Yeni yükseltiler/engeller mevcut hayvan dolaşım dikdörtgenlerini kapatmamalı.
	-- Döndürülmüş adalarda parçaların sekiz köşesinin izdüşümüyle muhafazakâr sınır kullanılır.
	local zones = first:FindFirstChild("Zones") :: Folder
	local fishZone: Instance? = nil
	for _, zone in zones:GetChildren() do
		if zone:GetAttribute("ZoneId") == "fishpen" then
			fishZone = zone
		end
	end
	assert(fishZone, "Balık kafesi eksik.")
	local walkway = (fishZone :: Instance):FindFirstChild("Walkway") :: Model
	local decor = first:FindFirstChild("Decor") :: Folder
	local dock = decor:FindFirstChild("Dock") :: Model
	local dockDeck = dock:FindFirstChild("Deck") :: BasePart
	local spawnPad = first:FindFirstChild("Spawn") :: BasePart
	local landY = spawnPad.Position.Y - spawnPad.Size.Y / 2
	local dockTop = dockDeck.Position.Y + dockDeck.Size.Y / 2
	assert(math.abs(dockTop - landY) < 0.1, "İskele ile kara arasında yürünemez yükseklik farkı var.")
	local entrance = dockDeck.CFrame:PointToWorldSpace(Vector3.new(0, 0, dockDeck.Size.Z / 2))
	local plotBase = first:FindFirstChild("PlotBase") :: BasePart
	local distanceFromIsland =
		Vector3.new(entrance.X - plotBase.Position.X, 0, entrance.Z - plotBase.Position.Z).Magnitude
	assert(distanceFromIsland < plotBase.Size.Y / 2 - 1, "İskele girişi ada yüzeyine oturmuyor.")
	local tip = dockDeck.CFrame:PointToWorldSpace(Vector3.new(0, 0, -dockDeck.Size.Z / 2))
	local joined = false
	for _, deck in walkway:GetChildren() do
		if deck:IsA("BasePart") and deck.Name == "Deck" then
			local point = deck.CFrame:PointToObjectSpace(tip)
			if math.abs(point.X) < deck.Size.X / 2 and math.abs(point.Z) < deck.Size.Z / 2 then
				joined = math.abs(deck.Position.Y + deck.Size.Y / 2 - dockTop) < 0.1
			end
		end
	end
	assert(joined, "İskele ucu balık kafesinin yürüyüş yoluna bağlanmıyor.")
	for _, pier in { dock, walkway } do
		local piles = 0
		for _, support in pier:GetChildren() do
			if support:IsA("BasePart") and support.Name == "Pile" then
				piles += 1
				local half = support.Size / 2
				local extentY = math.abs(support.CFrame.RightVector.Y) * half.X
					+ math.abs(support.CFrame.UpVector.Y) * half.Y
					+ math.abs(support.CFrame.LookVector.Y) * half.Z
				assert(support.Position.Y - extentY <= -20.49, "İskele kazığı deniz tabanına ulaşmıyor.")
				assert(
					support.Position.Y + extentY <= landY and support.Position.Y + extentY >= landY - 0.6,
					"Kazık üstü tahtaya oturmuyor."
				)
				assert(
					support.Anchored and support.CanCollide and not support.CanTouch,
					"Kazık fizik ayarları yanlış."
				)
			end
		end
		assert(piles >= 8, "İskele destekleri eksik.")
	end
	local function overlapsZone(partToCheck: BasePart, ground: BasePart): boolean
		local relative = ground.CFrame:ToObjectSpace(partToCheck.CFrame)
		local half = partToCheck.Size / 2
		local x = math.abs(relative.RightVector.X) * half.X
			+ math.abs(relative.UpVector.X) * half.Y
			+ math.abs(relative.LookVector.X) * half.Z
		local z = math.abs(relative.RightVector.Z) * half.X
			+ math.abs(relative.UpVector.Z) * half.Y
			+ math.abs(relative.LookVector.Z) * half.Z
		return math.abs(relative.Position.X) < ground.Size.X / 2 + x
			and math.abs(relative.Position.Z) < ground.Size.Z / 2 + z
	end
	local specializationCount = 0
	for _, instance in first:GetDescendants() do
		if instance:IsA("Model") and instance.Name == "Specialization" then
			specializationCount += 1
			for _, descendant in instance:GetDescendants() do
				if descendant:IsA("BasePart") and descendant.CanCollide then
					for _, zone in zones:GetChildren() do
						local ground = zone:FindFirstChild("Ground") :: BasePart
						assert(
							not overlapsZone(descendant, ground),
							`Uzmanlık dekoru hayvan alanına taşıyor: {descendant:GetFullName()}`
						)
					end
				end
			end
		end
	end
	assert(specializationCount == 4, "Her oyuncunun mevcut dört adası uzmanlaşmalı; yeni ada eklenmemeli.")
	local collector = first:FindFirstChild("Collector") :: BasePart
	collector.Parent = nil
	local missingCollectorAccepted = pcall(mapBuilder.validate)
	collector.Parent = first
	assert(not missingCollectorAccepted, "Collector eksikken harita kabul edildi.")

	local originalId = second:GetAttribute("PlotId")
	second:SetAttribute("PlotId", first:GetAttribute("PlotId"))
	local duplicateAccepted = pcall(mapBuilder.validate)
	second:SetAttribute("PlotId", originalId)
	assert(not duplicateAccepted, "Tekrarlı PlotId kabul edildi.")

	local originalVersion = plots:GetAttribute("MapVersion")
	plots:SetAttribute("MapVersion", -1)
	local staleAccepted = pcall(mapBuilder.validate)
	plots:SetAttribute("MapVersion", originalVersion)
	assert(not staleAccepted, "Eski harita sürümü kabul edildi.")
	mapBuilder.validate()
end
