--!strict
-- Studio düzenleme modunda çalıştırılır (world.spec ile aynı düzen). Kayıtlı/kurulmuş haritanın yapısını denetler:
-- tema bölgeleri, tabela yüksekliği (yolu kapatmaz), meydan satıcıları ve etkileşim noktaları.
return function()
	local RunService = game:GetService("RunService")
	assert(
		RunService:IsStudio() and not RunService:IsRunning(),
		"Harita yapı testi Studio düzenleme modunda çalıştırılmalıdır."
	)
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local ServerScriptService = game:GetService("ServerScriptService")
	local Workspace = game:GetService("Workspace")
	local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
	local mapBuilder =
		require(ServerScriptService:WaitForChild("Server"):WaitForChild("Services"):WaitForChild("MapBuilder"))

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
	end
	for action in actions do
		assert(found[action], `Meydanda '{action}' satıcısı yok.`)
	end
	assert(hub:FindFirstChild("TravelBoard"), "Meydanda Adalar tabelası eksik.")
	print("PASS map structure: themes, signs, vendors and prompts")
end
