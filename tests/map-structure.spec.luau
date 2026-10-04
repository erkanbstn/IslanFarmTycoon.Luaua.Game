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

	-- Önceki bir (başarısız) çalıştırmadan kalan şablonlar eski model/kodla kurulmuş olabilir; temiz başla
	mapBuilder.clearTemplates()
	mapBuilder.validate()
	local plots = Workspace:FindFirstChild("Plots") :: Folder
	assert(plots and #plots:GetChildren() == Config.MAP_PLOT_COUNT, "Her fiziksel ada için bir plot olmalı.")

	-- Karakter boyu (yaklaşık 5,5 stud) + kamera payı: tabela tahtasının alt kenarı yerden bu kadar yüksekte olmalı
	local MIN_SIGN_CLEARANCE = 10

	for _, plot in plots:GetChildren() do
		local plotId = tostring(plot:GetAttribute("ThemeIndex"))
		assert(plotId == "1", `{plot.Name}: kayıtlı haritada her ada 1. temayla kurulu olmalı.`)
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

	-- Karşılaştırma gerçek adaları değiştirir; hata olsa da sonraki testlere tema bırakma.
	local originalThemes: { [Model]: number } = {}
	for _, plot in plots:GetChildren() do
		if plot:IsA("Model") then
			originalThemes[plot] = plot:GetAttribute("ThemeIndex") :: number
		end
	end
	local themesOk, themesError = pcall(function()
		-- Ana ada düzeni temaya göre değişir: 1. adayı sırayla her temaya giydirip işaret yapısını ve yerleşimi denetle
		local signatures: { [string]: boolean } = {}
		local distinct = 0
		local probe = plots:GetChildren()[1] :: Model
		for themeIndex = 1, Config.MAIN_FARM_LIMIT do
			mapBuilder.applyTheme(probe, themeIndex)
			assert(probe:GetAttribute("ThemeIndex") == themeIndex, "applyTheme ThemeIndex özniteliğini yazmalı.")
			local decorFolder = probe:FindFirstChild("Decor") :: Folder
			-- İşaret yapısı RevealGate sarmalayıcısının içindedir (aynı adlı iki model): Kind özniteliği iç modeldedir
			local landmarkKind: any = nil
			for _, descendant in decorFolder:GetDescendants() do
				if descendant.Name == "Landmark" and descendant:GetAttribute("Kind") ~= nil then
					landmarkKind = descendant:GetAttribute("Kind")
				end
			end
			assert(
				landmarkKind == Config.getTheme(tostring(themeIndex)).landmark,
				`Tema {themeIndex}: işaret yapısı eksik ya da yanlış.`
			)
			local islands = probe:FindFirstChild("Islands") :: Folder
			assert(#islands:GetChildren() == 3, `Tema {themeIndex}: tam üç küçük ada olmalı.`)
			local plotBase = probe:FindFirstChild("PlotBase") :: BasePart
			local parts: { string } = {}
			for _, name in { "Farmhouse", "Windmill", "VegetableGarden", "Granary", "Well", "Orchard", "Beehives" } do
				local item = decorFolder:FindFirstChild(name) :: Model
				assert(item, `Tema {themeIndex}: {name} eksik.`)
				local localPos = plotBase.CFrame:PointToObjectSpace(item:GetPivot().Position)
				table.insert(parts, `{name}:{math.floor(localPos.X / 6 + 0.5)}:{math.floor(localPos.Z / 6 + 0.5)}`)
			end
			local signature = table.concat(parts, "|")
			if not signatures[signature] then
				signatures[signature] = true
				distinct += 1
			end
		end
		mapBuilder.applyTheme(probe, 1)
		mapBuilder.validate()
		assert(distinct >= 5, "Ana ada yerleşimleri çok benzer; temaya göre en az 5 farklı düzen olmalı.")

		-- Tema şablonu kopyası (Clone + PivotTo) eski yordamsal kurulumla aynı olmalı: aynı adada her tema için ikisini kur, karşılaştır.
		-- Plot1 şablonla aynı çerçevede olduğundan birebir (konumlar dahil); diğer ada döndürülmüş çerçeveyi (PivotTo + öznitelik taşıma) sınar.
		assert(mapBuilder.applyThemeProcedural ~= nil, "MapBuilder.applyThemeProcedural referans kurulumu eksik.")
		local POSITION_TOLERANCE = 0.05
		local function isThemeZone(zone: Instance): boolean
			local zoneConfig = Config.ZONES[zone:GetAttribute("ZoneId") :: string]
			return zoneConfig ~= nil and zoneConfig.island ~= "home"
		end
		-- Tema içeriğinin özeti: sınıf:ad sayıları, parça sayısı ve yolu tekil olan örneklerin sınıf/öznitelik/konumu (adaya göre yerel)
		local function snapshot(plot: Model)
			local frame = plot:GetAttribute("HomeFrame") :: CFrame
			local roots: { Instance } = {}
			for _, name in { "BuildSpots", "Decor", "Islands" } do
				table.insert(roots, plot:FindFirstChild(name) :: Instance)
			end
			for _, zone in (plot:FindFirstChild("Zones") :: Folder):GetChildren() do
				if isThemeZone(zone) then
					table.insert(roots, zone)
				end
			end
			local counts: { [string]: number } = {}
			local byPath: { [string]: any } = {}
			local paths: { [string]: number } = {}
			local parts = 0
			local function visit(instance: Instance)
				-- Serpiştirilen süsler (kaya, saz, kütük, mantar, kardan adam...) konuma bağlı tohumdan gelir; şablonda başka konumda
				-- kurulduğu için tür dağılımı oynar. Klasörün kendisi sayılır, içi sayılmaz.
				-- Çim tutamları da konuma bağlı tohumdan gelir (sayıları ve çiçekli oranları oynar); kar başlığı ağaçla birlikte
				-- gelir (ağaç sayısı oynar). Bunlar da sayılmaz.
				if
					instance.Name == "SnowCap"
					or instance:FindFirstAncestor("ScatterProps")
					or instance:FindFirstAncestor("GrassTufts")
					or instance:FindFirstAncestor("SnowCap")
				then
					return
				end
				local path = string.sub(instance:GetFullName(), #plot:GetFullName() + 2)
				local key = `{instance.ClassName}:{instance.Name}`
				counts[key] = (counts[key] or 0) + 1
				paths[path] = (paths[path] or 0) + 1
				local entry: any = { class = instance.ClassName, attributes = instance:GetAttributes() }
				if instance:IsA("BasePart") then
					parts += 1
					entry.position = frame:PointToObjectSpace(instance.Position)
					entry.size = instance.Size
					entry.canQuery = instance.CanQuery
					entry.castShadow = instance.CastShadow
				end
				byPath[path] = entry
			end
			for _, root in roots do
				visit(root)
				for _, descendant in root:GetDescendants() do
					visit(descendant)
				end
			end
			return { counts = counts, byPath = byPath, paths = paths, parts = parts, frame = frame }
		end
		local function sameAttribute(name: string, a: any, b: any, snapA: any, snapB: any): boolean
			if typeof(a) == "CFrame" and typeof(b) == "CFrame" then
				local localA, localB = snapA.frame:ToObjectSpace(a), snapB.frame:ToObjectSpace(b)
				return (localA.Position - localB.Position).Magnitude <= POSITION_TOLERANCE
			elseif typeof(a) == "Vector3" and typeof(b) == "Vector3" then
				if name == "PathStart" or name == "PathEnd" then
					return (snapA.frame:PointToObjectSpace(a) - snapB.frame:PointToObjectSpace(b)).Magnitude
						<= POSITION_TOLERANCE
				end
				return (a - b).Magnitude <= POSITION_TOLERANCE
			end
			return a == b
		end
		local function compareThemes(plot: Model, themeIndex: number, exact: boolean)
			local label = `{plot.Name} tema {themeIndex}`
			local stamped = snapshot(plot) -- şablon kopyası (çağıran applyTheme'i çalıştırdı)
			mapBuilder.applyThemeProcedural(plot, themeIndex)
			local reference = snapshot(plot)
			assert(
				math.abs(stamped.parts - reference.parts) <= (if exact then 0 else math.ceil(reference.parts * 0.03)),
				`{label}: parça sayısı farklı ({stamped.parts} / {reference.parts}).`
			)
			-- Ağaç/çalı türü ve sayısı konuma bağlı tohumdan gelir (MapParts.seedFrom: çam mı meşe mi); şablon başka konumda kurulduğu için bu parçalar
			-- birkaç ağaç kadar oynar. Diğer her şey sıkı tolerans kullanır.
			-- Anahtar "Sınıf:Ad"dır; ağaç parçaları Part/WedgePart olabilir (yeni modellerde yaprak/iğne katmanları kama), bu yüzden ad sınıftan bağımsız eşlenir.
			local TREE_NAMES = {
				Needles = true,
				Trunk = true,
				Leaves = true,
				Branch = true,
				Berry = true,
				PineTree = true,
				OakTree = true,
				Bush = true,
				SnowCap = true,
				Snow = true,
				SpecialMesh = true, -- çam iğneleri, kar başlıkları ve elips parçalar ağaç sayısıyla birlikte oynar
			}
			local function treeKey(key: string): boolean
				local name = string.match(key, "^[^:]+:(.+)$")
				return name ~= nil and TREE_NAMES[name] == true
			end
			for key, count in reference.counts do
				local other = stamped.counts[key] or 0
				local allowed = if treeKey(key)
					then math.max(20, math.ceil(count * 0.5))
					else math.max(2, math.ceil(count * 0.1))
				assert(
					if exact then other == count else math.abs(other - count) <= allowed,
					`{label}: {key} sayısı farklı ({other} / {count}).`
				)
			end
			for key in stamped.counts do
				assert(reference.counts[key] ~= nil, `{label}: şablonda fazladan {key}.`)
			end
			-- Ağaç/çalı çeşidi konuma bağlı tohumdan gelir (yukarıdaki tohum notu): tek bir çam ya da meşe yolunun şablonda aynı
			-- türden çıkması beklenmez; yalnızca bu adlı model yolları atlanır.
			local SEED_MODELS = { PineTree = true, OakTree = true, Bush = true, Flowers = true }
			local function seedDependent(path: string): boolean
				for component in string.gmatch(path, "[^%.]+") do
					if SEED_MODELS[component] then
						return true
					end
				end
				return false
			end
			for path, count in reference.paths do
				if count ~= 1 or seedDependent(path) then
					continue
				end
				local entryA, entryB = stamped.byPath[path], reference.byPath[path]
				assert(stamped.paths[path] == 1 and entryA, `{label}: {path} şablon kopyasında yok ya da tekrarlı.`)
				assert(entryA.class == entryB.class, `{label}: {path} sınıfı farklı.`)
				for name, value in entryB.attributes do
					assert(
						sameAttribute(name, entryA.attributes[name], value, stamped, reference),
						`{label}: {path} özniteliği '{name}' farklı.`
					)
				end
				for name in entryA.attributes do
					assert(entryB.attributes[name] ~= nil, `{label}: {path} fazladan öznitelik '{name}'.`)
				end
				if entryB.position then
					assert(
						(entryA.position - entryB.position).Magnitude <= POSITION_TOLERANCE,
						`{label}: {path} konumu farklı.`
					)
					assert(
						(entryA.size - entryB.size).Magnitude <= 0.001 -- döndürülmüş çerçevede uzunluk son hanede oynayabilir
							and entryA.canQuery == entryB.canQuery
							and entryA.castShadow == entryB.castShadow,
						`{label}: {path} boyut/optimize özellikleri farklı.`
					)
				end
			end
			for _, name in { "ThemeIndex", "IslandName", "IslandIcon" } do
				assert(plot:GetAttribute(name) ~= nil, `{label}: plot özniteliği {name} eksik.`)
			end
		end
		for _, plotIndex in { 1, 3 } do
			local plot = plots:FindFirstChild(`Plot{plotIndex}`) :: Model
			assert(plot, `Plot{plotIndex} bulunamadı.`)
			-- 2..N sonra 1: her adım bir öncekinden farklı tema, böylece applyTheme gerçekten şablon basar
			local order: { number } = {}
			for themeIndex = 2, Config.MAIN_FARM_LIMIT do
				table.insert(order, themeIndex)
			end
			table.insert(order, 1)
			for _, themeIndex in order do
				assert(
					mapBuilder.applyTheme(plot, themeIndex),
					`Plot{plotIndex} tema {themeIndex}: applyTheme değişiklik bildirmeli.`
				)
				compareThemes(plot, themeIndex, plotIndex == 1)
				assert(mapBuilder.applyTheme(plot, themeIndex) == false, "Aynı temaya geçiş bir şey kurmamalı.")
			end
			mapBuilder.validate()
		end
		-- Şablonlar yalnızca bellekteki test içindi; place'e kaydedilmesin
		if mapBuilder.clearTemplates then
			mapBuilder.clearTemplates()
		end
	end)
	local restoreErrors: { string } = {}
	for plot, themeIndex in originalThemes do
		if plot:GetAttribute("ThemeIndex") ~= themeIndex then
			local restored, restoreError = pcall(mapBuilder.applyThemeProcedural, plot, themeIndex)
			if not restored then
				table.insert(restoreErrors, `{plot.Name}: {tostring(restoreError)}`)
			end
		end
	end
	mapBuilder.clearTemplates()
	assert(#restoreErrors == 0, `Tema testi temizliği başarısız: {table.concat(restoreErrors, "; ")}`)
	assert(themesOk, tostring(themesError))

	-- Harita çevresi: görünmez halka duvar (haritadan ötesine yüzülemez); dağlar Terrain'dedir
	local rim = (Workspace:FindFirstChild("World") :: Folder):FindFirstChild("MapRim")
	assert(rim and #rim:GetChildren() >= 48, "MapRim (halka duvar) eksik; Haritayı Kur'u yeniden çalıştır.")
	for _, wall in rim:GetChildren() do
		assert(
			(wall :: BasePart).CanCollide and (wall :: BasePart).Transparency == 1,
			"Halka duvar katı ve görünmez olmalı."
		)
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

	-- Model çerçevesi tek başına yeterli değil: iki yönden gelen oyuncu yazıyı görmeli.
	local function assertSign(modelName: string, partName: string, expectedText: string)
		local model = hub:FindFirstChild(modelName)
		local part = model and model:FindFirstChild(partName)
		assert(part and part:IsA("BasePart"), `{modelName}/{partName}: tabela yüzeyi eksik.`)
		local faces: { [Enum.NormalId]: boolean } = {}
		for _, child in (part :: BasePart):GetChildren() do
			if not child:IsA("SurfaceGui") then
				continue
			end
			local text = child:FindFirstChild("Text", true)
			assert(
				text and text:IsA("TextLabel") and text.Text == expectedText,
				`{modelName}: tabela yazısı eksik/yanlış.`
			)
			faces[child.Face] = true
		end
		assert(faces[Enum.NormalId.Front] and faces[Enum.NormalId.Back], `{modelName}: iki yüz de okunabilir olmalı.`)
	end
	assertSign("HubTitleBoard", "Title", Config.GAME_NAME)
	assertSign("Hub_Banner", "Banner", "Hoş geldin")
	local bannerModel = hub:FindFirstChild("Hub_Banner") :: Model
	for _, name in { "Banner", "Header" } do
		local surface = bannerModel:FindFirstChild(name) :: BasePart
		assert(surface and surface.Transparency == 0, `Hub_Banner/{name}: model yüzeyi görünür olmalı.`)
	end

	print("PASS map structure: themes, signs, vendors and prompts")
end
