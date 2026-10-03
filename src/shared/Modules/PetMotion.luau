--!strict
-- Yardımcı (pet) hareketinin saf hesabı: ne zaman ışınlanır, güncelleme aralığı, bir adım ilerleme.
-- Kalite yalnızca pahalı işi (bacak/zıplama, bekleme sallanması) keser; konum akıcı ilerler. Işınlanma yalnızca çok uzakta olur.
-- `ReducedMotion` ayrı bir konudur (zıplamayı keser), buradaki kalite kararlarına karışmaz.

local PetMotion = {}

PetMotion.SKIP_DISTANCE = 350 -- bu uzaklıktan ötede yürütülmez, ışınlanır
PetMotion.FAR_DISTANCE = 150 -- bu uzaklıktan ötede güncelleme seyrelir (ışınlanma yok)
PetMotion.NEAR_INTERVAL = 0 -- orta/yüksek kalite: her kare
PetMotion.LOW_INTERVAL = 1 / 30 -- düşük kalite: en az 30 Hz
PetMotion.FAR_INTERVAL = 1 / 15 -- uzakta en az 15 Hz
PetMotion.MAX_DT = 0.25 -- tek adımda en çok bu kadar süre ilerler (takılma sonrası sıçrama sınırı)
PetMotion.ARRIVE_DISTANCE = 0.4

-- Kameraya uzaklık (distance) için yürüyüş ışınlanır mı? Kamera yoksa asla.
function PetMotion.teleports(distance: number?): boolean
	return distance ~= nil and distance > PetMotion.SKIP_DISTANCE
end

-- İki konum güncellemesi arasındaki en kısa süre (kare başı beklemek 0).
function PetMotion.walkInterval(quality: string, distance: number?): number
	local far = distance ~= nil and distance > PetMotion.FAR_DISTANCE
	local interval = if quality == "low" then PetMotion.LOW_INTERVAL else PetMotion.NEAR_INTERVAL
	if far then
		interval = math.max(interval, PetMotion.FAR_INTERVAL)
	end
	return interval
end

-- Yürüyüş zıplaması / bekleme sallanması yalnızca düşük olmayan kalitede ve hareket azaltma kapalıyken.
function PetMotion.animates(quality: string, reducedMotion: boolean): boolean
	return quality ~= "low" and not reducedMotion
end

-- (x, z) konumundan hedefe `speed * dt` kadar ilerler, hedefi aşmaz. Dönüş: yeni x, z, vardı mı.
function PetMotion.advance(
	x: number,
	z: number,
	targetX: number,
	targetZ: number,
	speed: number,
	dt: number
): (number, number, boolean)
	local dx, dz = targetX - x, targetZ - z
	local distance = math.sqrt(dx * dx + dz * dz)
	if distance < PetMotion.ARRIVE_DISTANCE then
		return x, z, true
	end
	local step = math.min(distance, speed * math.min(dt, PetMotion.MAX_DT))
	return x + dx / distance * step, z + dz / distance * step, false
end

export type Point = { x: number, z: number }
type RouteNode = { x: number, z: number, cost: number, score: number, parent: string? }

-- Engel denetimini çağırana bırakır; sınırlı arama duvar/çit etrafından dolaşır.
-- Yol bulunamadığında zorla düz yürümek yerine nil döner.
function PetMotion.detour(
	x: number,
	z: number,
	targetX: number,
	targetZ: number,
	canTravel: (number, number, number, number) -> boolean,
	spacing: number?,
	budget: number?
): { Point }?
	if canTravel(x, z, targetX, targetZ) then
		return { { x = targetX, z = targetZ } }
	end
	local step = spacing or 3
	local limit = budget or 256
	local function distance(px: number, pz: number): number
		return math.sqrt((px - targetX) ^ 2 + (pz - targetZ) ^ 2)
	end
	local nodes: { [string]: RouteNode } = {
		["0:0"] = { x = x, z = z, cost = 0, score = distance(x, z), parent = nil },
	}
	local open: { string } = { "0:0" }
	local closed: { [string]: boolean } = {}
	local offsets = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 }, { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } }
	for _ = 1, limit do
		if #open == 0 then
			return nil
		end
		local best = 1
		for index = 2, #open do
			if nodes[open[index]].score < nodes[open[best]].score then
				best = index
			end
		end
		local key = table.remove(open, best) :: string
		local current = nodes[key]
		closed[key] = true
		-- Yakın hücre hedefe son güvenli bağlantıyı kurar; duvardan kestirme yapılmaz.
		if distance(current.x, current.z) <= step * 1.5 and canTravel(current.x, current.z, targetX, targetZ) then
			local reverse: { Point } = { { x = targetX, z = targetZ } }
			local trace: string? = key
			while trace and trace ~= "0:0" do
				local node = nodes[trace]
				table.insert(reverse, { x = node.x, z = node.z })
				trace = node.parent
			end
			local route: { Point } = {}
			for index = #reverse, 1, -1 do
				table.insert(route, reverse[index])
			end
			return route
		end
		local gridX = math.round((current.x - x) / step)
		local gridZ = math.round((current.z - z) / step)
		for _, offset in offsets do
			local ix, iz = gridX + offset[1], gridZ + offset[2]
			local nextKey = `{ix}:{iz}`
			if closed[nextKey] then
				continue
			end
			local nx, nz = x + ix * step, z + iz * step
			local cost = current.cost + math.sqrt(offset[1] ^ 2 + offset[2] ^ 2) * step
			local previous = nodes[nextKey]
			if (not previous or cost < previous.cost) and canTravel(current.x, current.z, nx, nz) then
				nodes[nextKey] = { x = nx, z = nz, cost = cost, score = cost + distance(nx, nz), parent = key }
				if not previous then
					table.insert(open, nextKey)
				end
			end
		end
	end
	return nil
end

return PetMotion
