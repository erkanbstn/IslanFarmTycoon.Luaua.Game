--!strict
-- Taş yol ağı: yollar tek bağlı ağ olur, rotalar yol düğümlerinden geçer, kesişim ve T kavşakları bağlanır.
return function(MapPaths: any)
	local RADIUS = 70
	local graph = MapPaths.newGraph()
	local function identity(x: number, z: number): (number, number)
		return x, z
	end
	MapPaths.addSegments(graph, MapPaths.homeSegments(RADIUS), identity)
	assert(#graph.x >= 10, "home path network has junction nodes")

	-- Her düğüm ilkinden erişilebilir (tek bağlı ağ)
	local seen: { [number]: boolean } = { [1] = true }
	local queue = { 1 }
	while #queue > 0 do
		local current = table.remove(queue) :: number
		for _, neighbor in graph.adj[current] do
			if not seen[neighbor] then
				seen[neighbor] = true
				table.insert(queue, neighbor)
			end
		end
	end
	for index = 1, #graph.x do
		assert(seen[index], `path node {index} is unreachable from the network`)
	end

	-- Toplama yolu (12,-40) -> güney köprü ucu (0, R-2): ana yolun her iki kavşağından geçer
	local route = MapPaths.route(graph, 12, -40, 0, RADIUS - 2)
	assert(#route >= 4, "a long route follows several path nodes")
	local crossesCross, crossesSouth = false, false
	for _, point in route do
		if math.abs(point.x) < 1 and math.abs(point.z + 16) < 1 then
			crossesCross = true
		end
		if math.abs(point.x) < 1 and math.abs(point.z - 28) < 2 then
			crossesSouth = true
		end
	end
	assert(crossesCross and crossesSouth, "the route uses the main road junctions instead of cutting across the grass")
	local last = route[#route]
	assert(last.x == 0 and last.z == RADIUS - 2, "the route ends at the requested target")

	-- Aynı düğüme yakın hedef: tek durak
	local short = MapPaths.route(graph, 0, -15, 0, -14)
	assert(#short == 1, "a target next to the start needs no detour")

	-- Dönüşüm: dünya uzayına kaydırılmış ağ aynı yapıyı verir
	local shifted = MapPaths.newGraph()
	MapPaths.addSegments(shifted, MapPaths.homeSegments(RADIUS), function(x: number, z: number): (number, number)
		return x + 1000, z - 500
	end)
	assert(#shifted.x == #graph.x, "transform keeps the node structure")
	local moved = MapPaths.route(shifted, 1012, -540, 1000, -500 + RADIUS - 2)
	assert(#moved == #route, "the same route exists in world space")
	print("PASS map paths: connected home network, junction splitting, stone-road routes and transforms")
end
