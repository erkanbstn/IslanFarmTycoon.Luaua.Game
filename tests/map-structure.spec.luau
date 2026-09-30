--!strict
-- Studio düzenleme modunda çalıştırılır (world.spec ile aynı düzen). Kayıtlı/kurulmuş haritanın yapısını denetler:
-- tema bölgeleri, tabela yüksekliği (yolu kapatmaz), meydan satıcıları ve etkileşim noktaları.
-- context (isteğe bağlı): eklenti taze kodu verir { mapBuilder = ..., Config = ... }; verilmezse oyun kodundan yüklenir.
return function(context: any?)
	local RunService = game:GetService("RunService")
	assert(
		RunService:IsStudio() and not RunService:IsRunning(),
		"Harita yapı testi Studio düzenleme modunda çalıştırılmalıdır."
	)
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local ServerScriptService = game:GetService("ServerScriptService")
	local Workspace = game:GetService("Workspace")
	local Config = if context and context.Config
		then context.Config
		else require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
	local mapBuilder = if context and context.mapBuilder
		then context.mapBuilder
		else require(ServerScriptService:WaitForChild("Server"):WaitForChild("World"):WaitForChild("MapBuilder"))

	mapBuilder.validate()
	local plots = Workspace:FindFirstChild("Plots") :: Folder
	assert(plots and #plots:GetChildren() == Config.MAP_PLOT_COUNT, "Her fiziksel ada için bir plot olmalı.")

	-- Karakter boyu (yaklaşık 5,5 stud) + kamera payı: tabela tahtasının alt kenarı yerden bu kadar yüksekte olmalı
	local MIN_SIGN_CLEARANCE = 10

	for _, plot in plots:GetChildren() do
		local plotId = plot:GetAttribute("PlotId") :: string
		local spawnPad = plot:FindFirstChild("Spawn") :: BasePart
		local landY = spawnPad.Position.Y - spawnPad.Size.Y / 2
		local theme = Config.getTheme(plotId)

		-- Ana ada hayvanı: ağıl ve otlak temanın hayvanını kabul eder, adı ona göre yazılır
		local zones = plot:FindFirstChild("Zones") :: Folder
		local seen: { [string]: Instance } = {}
		for _, zone in zones:GetChildren() do
			seen[zone:GetAttribute("ZoneId") :: string] = zone
		end
		for _, zoneId in { "starter", "pasture" } do
			local zone = seen[zoneId]
			assert(zone, `{plot.Name}: {zoneId} bölgesi eksik.`)
			assert(
				Config.zoneAllows(Config.ZONES[zoneId], theme.homeAnimal, plotId),
				`{plot.Name}: {zoneId} ana ada hayvanını kabul etmiyor.`
			)
		end
		assert(
			(seen.starter :: Instance).Name == Config.getZoneName(Config.ZONES.starter, plotId),
			`{plot.Name}: ağıl adı temayla eşleşmiyor.`
		)

		-- Ana ada giriş tabelası: yüksekte, çarpışmaz, direkler uzun
		local plotSign = plot:FindFirstChild("PlotSign") :: BasePart
		assert(plotSign, `{plot.Name}: giriş tabelası eksik.`)
		assert(not plotSign.CanCollide, `{plot.Name}: giriş tabelası çarpışmamalı.`)
		assert(
			plotSign.Position.Y - plotSign.Size.Y / 2 - landY >= MIN_SIGN_CLEARANCE,
			`{plot.Name}: giriş tabelası yolu kapatıyor (yeterince yüksek değil).`
		)
		local posts = 0
		for _, child in plot:GetChildren() do
			if child.Name == "SignPost" and child:IsA("BasePart") then
				posts += 1
				assert(child.Size.Y >= 15, `{plot.Name}: giriş tabelası direği kısa.`)
			end
		end
		assert(posts == 2, `{plot.Name}: giriş tabelasının iki direği olmalı.`)

		-- Küçük ada tabelaları da yüksekte ve çarpışmaz
		local islands = plot:FindFirstChild("Islands") :: Folder
		assert(#islands:GetChildren() == 3, `{plot.Name}: tam üç küçük ada olmalı.`)
		for _, island in islands:GetChildren() do
			local sign = island:FindFirstChild("IslandSign") :: BasePart
			assert(sign and not sign.CanCollide, `{plot.Name}/{island.Name}: ada tabelası eksik ya da çarpışıyor.`)
			assert(
				sign.Position.Y - sign.Size.Y / 2 - landY >= MIN_SIGN_CLEARANCE,
				`{plot.Name}/{island.Name}: ada tabelası yolu kapatıyor.`
			)
		end

		-- Pazar tezgâhı: yalnızca sahibine görünen etkileşim (IslandPrompts "Locked" özniteliğine bakar)
		local market: Instance? = nil
		for _, descendant in plot:GetDescendants() do
			if descendant:IsA("ProximityPrompt") and descendant.Name == "MarketPrompt" then
				market = descendant
			end
		end
		assert(market and market:GetAttribute("Locked") == true, `{plot.Name}: pazar tezgâhı etkileşimi eksik.`)
	end

	-- Ana ada düzeni temaya göre değişir: işaret yapısı temaya uygun ve yerleşimler birbirinden farklı
	local signatures: { [string]: boolean } = {}
	local distinct = 0
	for _, plot in plots:GetChildren() do
		local plotId = plot:GetAttribute("PlotId") :: string
		local decorFolder = plot:FindFirstChild("Decor") :: Folder
		local landmark = decorFolder:FindFirstChild("Landmark")
		assert(
			landmark and landmark:GetAttribute("Kind") == Config.getTheme(plotId).landmark,
			`{plot.Name}: tema işaret yapısı eksik ya da yanlış.`
		)
		local plotBase = plot:FindFirstChild("PlotBase") :: BasePart
		local parts: { string } = {}
		for _, name in { "Farmhouse", "Windmill", "VegetableGarden", "Granary", "Well", "Orchard", "Beehives" } do
			local item = decorFolder:FindFirstChild(name) :: Model
			assert(item, `{plot.Name}: {name} eksik.`)
			local localPos = plotBase.CFrame:PointToObjectSpace(item:GetPivot().Position)
			table.insert(parts, `{name}:{math.floor(localPos.X / 6 + 0.5)}:{math.floor(localPos.Z / 6 + 0.5)}`)
		end
		local signature = table.concat(parts, "|")
		if not signatures[signature] then
			signatures[signature] = true
			distinct += 1
		end
	end
	assert(distinct >= 5, "Ana ada yerleşimleri çok benzer; temaya göre en az 5 farklı düzen olmalı.")

	-- Meydan: dört satıcı, her birinin bilinen bir eylemi var, spawn alanını kapatmaz
	local hub = (Workspace:FindFirstChild("World") :: Folder):FindFirstChild("Hub") :: Model
	assert(hub, "Meydan (Hub) eksik.")
	local actions: { [string]: boolean } = { orders = true, store = true, roadmap = true, travel = true }
	local found: { [string]: boolean } = {}
	for _, child in hub:GetChildren() do
		if string.sub(child.Name, 1, 7) ~= "Vendor_" then
			continue
		end
		local prompt = child:FindFirstChild("VendorPrompt", true) :: ProximityPrompt?
		assert(prompt, `{child.Name}: etkileşim noktası eksik.`)
		local action = (prompt :: ProximityPrompt):GetAttribute("Action")
		assert(typeof(action) == "string" and actions[action], `{child.Name}: bilinmeyen eylem.`)
		found[action] = true
		local counter = child:FindFirstChild("Counter") :: BasePart
		local hubSpawn = hub:FindFirstChild("HubSpawn") :: BasePart
		local flat = Vector3.new(counter.Position.X - hubSpawn.Position.X, 0, counter.Position.Z - hubSpawn.Position.Z)
		assert(flat.Magnitude >= 15, `{child.Name}: doğma noktasına çok yakın.`)
		local sign = child:FindFirstChild("Sign") :: BasePart
		assert(sign and not sign.CanCollide, `{child.Name}: tabela çarpışmamalı.`)
		-- Tezgâh katıdır ve yanları kapalıdır: içine girilip satıcının içinden geçilemez
		assert(counter.CanCollide, `{child.Name}: tezgâh çarpışmalı.`)
		local panels = 0
		for _, descendant in child:GetChildren() do
			if descendant.Name == "SidePanel" then
				assert((descendant :: BasePart).CanCollide, `{child.Name}: yan panel çarpışmalı.`)
				panels += 1
			end
		end
		assert(panels == 2, `{child.Name}: iki yan panel bekleniyor.`)
	end
	for action in actions do
		assert(found[action], `Meydanda '{action}' satıcısı yok.`)
	end
	-- Canlı meydan: satıcılar client'ın canlandırması için etiketli, dekor yerinde
	local CollectionService = game:GetService("CollectionService")
	for _, child in hub:GetChildren() do
		if string.sub(child.Name, 1, 7) == "Vendor_" then
			assert(CollectionService:HasTag(child, "HubNpc"), `{child.Name}: HubNpc etiketi eksik.`)
			assert(
				child:FindFirstChild("Head") and child:FindFirstChild("Torso"),
				`{child.Name}: canlandırılacak parçalar eksik.`
			)
		end
	end
	assert(hub:FindFirstChild("Fountain"), "Meydanda çeşme eksik.")
	local benches, planters = 0, 0
	for _, child in hub:GetChildren() do
		if child.Name == "Bench" then
			benches += 1
		elseif child.Name == "Planter" then
			planters += 1
		end
	end
	assert(benches == 3 and planters == 8, "Meydan dekoru eksik (3 bank, 8 çiçeklik).")
	assert(hub:FindFirstChild("TravelBoard"), "Meydanda Adalar tabelası eksik.")
	print("PASS map structure: themes, signs, vendors and prompts")
end
