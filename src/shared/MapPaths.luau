--!strict
-- Ana adanın taş yol ağı (tek kaynak): IslandBuilder yolları bu listeden çizer, yardımcılar (PetAnimator) aynı listeyle
-- rota bulur. Koordinatlar ana adanın yerel (x, z) düzlemindedir. Saf hesap: Roblox nesnesi kullanmaz.

local MapPaths = {}

export type Segment = { ax: number, az: number, bx: number, bz: number, width: number }
export type Graph = { x: { number }, z: { number }, adj: { { number } } }
export type Point = { x: number, z: number }

local JOIN_DISTANCE = 16 -- uç, başka bir yola bu kadar yakınsa ona bağlanır (yollar ahır/meydan önünde kısa aralıklarla kesilir)
local MERGE_DISTANCE = 0.6

-- Ana ada yolları (genişlik dahil). radius = ana ada yarıçapı.
function MapPaths.homeSegments(radius: number): { Segment }
	return {
		{ ax = 0, az = -(radius - 2), bx = 0, bz = -49, width = 6 },
		{ ax = 0, az = -41, bx = 0, bz = 28, width = 6 },
		{ ax = 3, az = -42, bx = 12, bz = -40, width = 4 },
		{ ax = -20, az = -16, bx = 20, bz = -16, width = 5 },
		{ ax = -14, az = 27, bx = -43, bz = 53, width = 5 },
		{ ax = 14, az = 27, bx = 43, bz = 53, width = 5 },
		{ ax = -15, az = 28, bx = -16, bz = 54, width = 5 },
		{ ax = -16, az = 54, bx = 0, bz = radius - 2, width = 5 },
	}
end

function MapPaths.newGraph(): Graph
	return { x = {}, z = {}, adj = {} }
end

function MapPaths.addNode(graph: Graph, x: number, z: number): number
	for index = 1, #graph.x do
		local dx, dz = graph.x[index] - x, graph.z[index] - z
		if dx * dx + dz * dz <= MERGE_DISTANCE * MERGE_DISTANCE then
			return index
		end
	end
	table.insert(graph.x, x)
	table.insert(graph.z, z)
	table.insert(graph.adj, {})
	return #graph.x
end

function MapPaths.connect(graph: Graph, a: number, b: number)
	if a == b or table.find(graph.adj[a], b) then
		return
	end
	table.insert(graph.adj[a], b)
	table.insert(graph.adj[b], a)
end

-- Yolları grafa ekler. transform yerel (x, z)'yi grafın uzayına çevirir (ör. dünya koordinatı); uçlar başka bir yolun
-- üstündeyse (T kavşağı) o noktaya bölünüp bağlanır.
function MapPaths.addSegments(graph: Graph, segments: { Segment }, transform: (number, number) -> (number, number))
	local stops: { { { u: number, x: number, z: number } } } = {}
	local links: { { ax: number, az: number, bx: number, bz: number } } = {}
	for index, segment in segments do
		stops[index] = {
			{ u = 0, x = segment.ax, z = segment.az },
			{ u = 1, x = segment.bx, z = segment.bz },
		}
	end
	-- Yolların kesiştiği yerler ortak bir düğüm olur (ör. ana yol ile enine yol)
	for index, first in segments do
		for other = index + 1, #segments do
			local second = segments[other]
			local rx, rz = first.bx - first.ax, first.bz - first.az
			local sx, sz = second.bx - second.ax, second.bz - second.az
			local denominator = rx * sz - rz * sx
			if math.abs(denominator) > 1e-6 then
				local qx, qz = second.ax - first.ax, second.az - first.az
				local t = (qx * sz - qz * sx) / denominator
				local u = (qx * rz - qz * rx) / denominator
				if t > 0.001 and t < 0.999 and u > 0.001 and u < 0.999 then
					local x, z = first.ax + rx * t, first.az + rz * t
					table.insert(stops[index], { u = t, x = x, z = z })
					table.insert(stops[other], { u = u, x = x, z = z })
				end
			end
		end
	end
	for index, segment in segments do
		for _, endpoint in { { segment.ax, segment.az }, { segment.bx, segment.bz } } do
			for other, target in segments do
				if other == index then
					continue
				end
				local dx, dz = target.bx - target.ax, target.bz - target.az
				local lengthSquared = dx * dx + dz * dz
				local u =
					math.clamp(((endpoint[1] - target.ax) * dx + (endpoint[2] - target.az) * dz) / lengthSquared, 0, 1)
				local qx, qz = target.ax + dx * u, target.az + dz * u
				local distance = math.sqrt((endpoint[1] - qx) ^ 2 + (endpoint[2] - qz) ^ 2)
				if distance <= JOIN_DISTANCE and distance > 0.01 then
					table.insert(stops[other], { u = u, x = qx, z = qz })
					table.insert(links, { ax = endpoint[1], az = endpoint[2], bx = qx, bz = qz })
				end
			end
		end
	end
	for _, list in stops do
		table.sort(list, function(a, b)
			return a.u < b.u
		end)
		local previous: number? = nil
		for _, stop in list do
			local wx, wz = transform(stop.x, stop.z)
			local node = MapPaths.addNode(graph, wx, wz)
			if previous then
				MapPaths.connect(graph, previous, node)
			end
			previous = node
		end
	end
	for _, link in links do
		local ax, az = transform(link.ax, link.az)
		local bx, bz = transform(link.bx, link.bz)
		MapPaths.connect(graph, MapPaths.addNode(graph, ax, az), MapPaths.addNode(graph, bx, bz))
	end
end

function MapPaths.nearest(graph: Graph, x: number, z: number): number?
	local best: number? = nil
	local bestDistance = math.huge
	for index = 1, #graph.x do
		local dx, dz = graph.x[index] - x, graph.z[index] - z
		local distance = dx * dx + dz * dz
		if distance < bestDistance then
			best, bestDistance = index, distance
		end
	end
	return best
end

-- from -> to arası en kısa yol boyunca sıralı durak noktaları (başlangıç hariç, hedef dahil). Yol ağı yoksa doğrudan hedef.
function MapPaths.route(graph: Graph, fromX: number, fromZ: number, toX: number, toZ: number): { Point }
	local start, finish = MapPaths.nearest(graph, fromX, fromZ), MapPaths.nearest(graph, toX, toZ)
	local result: { Point } = {}
	if start and finish and start ~= finish then
		local count = #graph.x
		local distance: { number } = {}
		local previous: { number } = {}
		local done: { boolean } = {}
		for index = 1, count do
			distance[index] = math.huge
		end
		distance[start] = 0
		for _ = 1, count do
			local current: number? = nil
			local best = math.huge
			for index = 1, count do
				if not done[index] and distance[index] < best then
					current, best = index, distance[index]
				end
			end
			if not current then
				break
			end
			done[current] = true
			for _, neighbor in graph.adj[current] do
				local dx, dz = graph.x[neighbor] - graph.x[current], graph.z[neighbor] - graph.z[current]
				local candidate = distance[current] + math.sqrt(dx * dx + dz * dz)
				if candidate < distance[neighbor] then
					distance[neighbor], previous[neighbor] = candidate, current
				end
			end
		end
		if distance[finish] < math.huge then
			local chain: { number } = {}
			local node: number? = finish
			while node and node ~= start do
				table.insert(chain, 1, node)
				node = previous[node]
			end
			table.insert(result, { x = graph.x[start], z = graph.z[start] })
			for _, index in chain do
				table.insert(result, { x = graph.x[index], z = graph.z[index] })
			end
		end
	end
	table.insert(result, { x = toX, z = toZ })
	return result
end

return MapPaths
