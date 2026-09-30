--!strict
-- Hayvanların bölge zemininde yerleşimi: alan, yuva konumu, yüzeye oturtma ve bölge zemini bulma.

-- Hayvanların durabileceği alan: zemin eksi kenar payı ve arkadaki yapılar (Ground.BackReserve)
local SIDE_MARGIN = 2

local function getAnimalArea(ground: BasePart): (CFrame, Vector3)
	local size = ground.Size
	local reserve = ground:GetAttribute("BackReserve")
	local back = if typeof(reserve) == "number" then reserve else 0
	local width = math.max(size.X - SIDE_MARGIN * 2, 1)
	local depth = math.max(size.Z - SIDE_MARGIN - math.max(back, SIDE_MARGIN), 1)
	-- Alan önden (-Z) başlar, arka şeridi dışarıda bırakır
	local centerZ = -size.Z / 2 + SIDE_MARGIN + depth / 2
	return ground.CFrame * CFrame.new(0, size.Y / 2, centerZ), Vector3.new(width, 0, depth)
end

-- Alanı hücrelere bölüp index. hücrenin merkezini döner
local function slotCFrame(area: CFrame, size: Vector3, index: number, capacity: number): CFrame
	local cols = math.max(1, math.ceil(math.sqrt(capacity * size.X / size.Z)))
	local rows = math.max(1, math.ceil(capacity / cols))
	local col = (index - 1) % cols
	local row = math.floor((index - 1) / cols) % rows
	local x = -size.X / 2 + size.X / cols * (col + 0.5)
	local z = -size.Z / 2 + size.Z / rows * (row + 0.5)
	-- Hepsi aynı yöne bakmasın diye hafif rastgele görünen açı
	local yaw = math.rad(((index * 47) % 90) - 45)
	return area * CFrame.new(x, 0, z) * CFrame.Angles(0, yaw, 0)
end

-- Modeli, alt noktası yüzeye oturacak şekilde yerleştirir
local function placeOnSurface(model: Model, target: CFrame)
	model:PivotTo(target)
	local boxCf, boxSize = model:GetBoundingBox()
	local bottom = boxCf.Position.Y - boxSize.Y / 2
	model:PivotTo(model:GetPivot() + Vector3.new(0, target.Position.Y - bottom, 0))
end

local function findZoneGround(plot: Model, zoneId: string): BasePart?
	local zones = plot:FindFirstChild("Zones")
	if not zones then
		return nil
	end
	for _, zone in zones:GetChildren() do
		if zone:GetAttribute("ZoneId") == zoneId then
			local ground = zone:FindFirstChild("Ground")
			if ground and ground:IsA("BasePart") then
				return ground
			end
		end
	end
	return nil
end

return {
	getAnimalArea = getAnimalArea,
	slotCFrame = slotCFrame,
	placeOnSurface = placeOnSurface,
	findZoneGround = findZoneGround,
}
