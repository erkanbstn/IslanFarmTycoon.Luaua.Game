--!strict
-- Actual animator initialization: same-UID models may stream in before their predecessor disappears.
return function(createAnimator: any)
	local function signal()
		local callbacks = {}
		return {
			Connect = function(_self: any, callback: any)
				table.insert(callbacks, callback)
				return { Disconnect = function() end }
			end,
			fire = function(...: any)
				for _, callback in callbacks do
					callback(...)
				end
			end,
		}
	end
	local vectorMt: any = {}
	local function vector(x: number, y: number, z: number): any
		return setmetatable({ X = x, Y = y, Z = z, kind = "Vector3" }, vectorMt)
	end
	vectorMt.__add = function(a: any, b: any)
		return vector(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
	end
	vectorMt.__sub = function(a: any, b: any)
		return vector(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
	end
	vectorMt.__div = function(a: any, b: number)
		return vector(a.X / b, a.Y / b, a.Z / b)
	end
	vectorMt.__eq = function(a: any, b: any)
		return a.X == b.X and a.Y == b.Y and a.Z == b.Z
	end
	vectorMt.__mul = function(a: any, b: number): any
		return vector(a.X * b, a.Y * b, a.Z * b)
	end
	vectorMt.__index = function(a: any, key: string): any
		local magnitude = math.sqrt(a.X * a.X + a.Y * a.Y + a.Z * a.Z)
		if key == "Magnitude" then
			return magnitude
		end
		if key == "Unit" then
			return a / magnitude
		end
		if key == "Lerp" then
			return function(self: any, other: any, alpha: number): any
				return self + (other - self) * alpha
			end
		end
		return nil
	end
	local cfMt: any = {}
	local function cf(x: number?, y: number?, z: number?): any
		return setmetatable({
			Position = vector(x or 0, y or 0, z or 0),
			LookVector = vector(0, 0, -1),
			kind = "CFrame",
			Pitch = 0,
			Yaw = 0,
			Roll = 0,
		}, cfMt)
	end
	cfMt.__index = {
		ToObjectSpace = function(a: any, b: any)
			local p = b.Position - a.Position
			return cf(p.X, p.Y, p.Z)
		end,
		PointToWorldSpace = function(a: any, point: any)
			return a.Position + point
		end,
		PointToObjectSpace = function(a: any, point: any): any
			return point - a.Position
		end,
		VectorToWorldSpace = function(_a: any, point: any): any
			return point
		end,
	}
	cfMt.__mul = function(a: any, b: any)
		local c, s = math.cos(a.Pitch), math.sin(a.Pitch)
		local rotated = vector(b.Position.X, c * b.Position.Y - s * b.Position.Z, s * b.Position.Y + c * b.Position.Z)
		local p = a.Position + rotated
		local result = cf(p.X, p.Y, p.Z)
		result.Pitch, result.Yaw, result.Roll = a.Pitch + b.Pitch, a.Yaw + b.Yaw, a.Roll + b.Roll
		return result
	end
	cfMt.__eq = function(a: any, b: any)
		return a.Position == b.Position
	end
	local added, removed, render = signal(), signal(), signal()
	local obstacles: { any } = {}
	local now, randomFraction = 0, 0.5
	local supported, blockRim, reduced = false, false, false
	local collection = {
		GetInstanceAddedSignal = function()
			return added
		end,
		GetInstanceRemovedSignal = function()
			return removed
		end,
		GetTagged = function(_self: any, tag: string)
			return if tag == "AnimalObstacle" then obstacles else {}
		end,
		HasTag = function(): boolean
			return false
		end,
	}
	local ground = {
		FindFirstAncestorOfClass = function(): any
			return nil
		end,
	}
	local workspace = {
		CurrentCamera = { CFrame = cf() },
		Raycast = function(_self: any, origin: any): any
			if not supported or (blockRim and origin.X < -4) then
				return nil
			end
			return { Instance = ground, Position = vector(origin.X, 0, origin.Z), Normal = vector(0, 1, 0) }
		end,
		BulkMoveTo = function(_self: any, parts: any, frames: any)
			for i, part in parts do
				part.move(frames[i])
			end
		end,
	}
	local lighting = { ClockTime = 12 }
	local gameMock = {
		GetService = function(_self: any, name: string)
			return ({
				CollectionService = collection,
				RunService = { PreRender = render },
				Workspace = workspace,
				Lighting = lighting,
			})[name]
		end,
	}
	createAnimator(gameMock, {
		reducedMotion = function(): boolean
			return reduced
		end,
		quality = function(): string
			return "high"
		end,
	}, { new = vector, zero = vector(0, 0, 0) }, {
		new = cf,
		Angles = function(x: number, y: number, z: number)
			local result = cf()
			result.Pitch, result.Yaw, result.Roll = x, y, z
			return result
		end,
	}, {
		new = function()
			return {
				NextNumber = function(_self: any, low: number, high: number)
					return low + (high - low) * randomFraction
				end,
				NextInteger = function()
					return 0
				end,
			}
		end,
	}, {
		new = function()
			return {}
		end,
	}, { RaycastFilterType = { Exclude = 0 }, BulkMoveMode = { FireCFrameChanged = 1 } }, function(value: any)
		return if type(value) == "table" then value.kind or "table" else type(value)
	end, {
		clock = function(): number
			return now
		end,
	})
	local function animal(
		uid: string,
		area: any,
		size: any,
		x: number,
		movement: string?,
		species: string?,
		swims: boolean?
	): any
		local position = area * cf(x, 1, 0)
		local attributes = {
			Uid = uid,
			AreaCFrame = area,
			AreaSize = size,
			HeightOffset = 1,
			MovementStyle = movement,
			AnimalSpecies = species,
			SwimDepthOffset = if swims then 1 else nil,
		}
		local body = {
			Name = "Body",
			Size = vector(2, 1, 3),
			IsA = function(_self: any, name: string): boolean
				return name == "BasePart"
			end,
			move = function(value: any)
				position = value
			end,
		}
		local function limb(name: string, offset: any, partSize: any): any
			local part: any = { Name = name, Size = partSize, CFrame = position * offset }
			part.IsA = body.IsA
			part.move = function(value: any)
				part.CFrame = value
			end
			return part
		end
		local head = limb("Head", cf(0, 0.5, -1.2), vector(1, 1, 1))
		local leg = limb("Leg", cf(-0.7, -0.5, -0.7), vector(0.3, 1, 0.3))
		local rightLeg = limb("Leg", cf(0.7, -0.5, -0.7), vector(0.3, 1, 0.3))
		local rearLeft = limb("Leg", cf(-0.7, -0.5, 0.7), vector(0.3, 1, 0.3))
		local rearRight = limb("Leg", cf(0.7, -0.5, 0.7), vector(0.3, 1, 0.3))
		local foot = limb("Foot", cf(-0.7, -1, -0.8), vector(0.4, 0.2, 0.5))
		local rightFoot = limb("Foot", cf(0.7, -1, -0.8), vector(0.4, 0.2, 0.5))
		local hoof = limb("Hoof", cf(-0.7, -1, 0.7), vector(0.4, 0.2, 0.4))
		local rightHoof = limb("Hoof", cf(0.7, -1, 0.7), vector(0.4, 0.2, 0.4))
		local articulated = { head, leg, rightLeg, rearLeft, rearRight, foot, rightFoot, hoof, rightHoof }
		local twoLegged = {
			chicken = true,
			duck = true,
			falcon = true,
			parrot = true,
			peacock = true,
			pigeon = true,
			quail = true,
			turkey = true,
		}
		if species and twoLegged[species] then
			articulated = { head, leg, rightLeg, foot, rightFoot }
		end
		local original: { any } = {}
		for index, part in articulated do
			original[index] = position:ToObjectSpace(part.CFrame)
		end
		local model: any = {
			Name = (species or "cow") .. "_" .. uid,
			head = head,
			leg = leg,
			rightLeg = rightLeg,
			rearLeft = rearLeft,
			rearRight = rearRight,
			foot = foot,
			rightFoot = rightFoot,
			hoof = hoof,
			rightHoof = rightHoof,
			Parent = workspace,
			AttributeChanged = signal(),
			DescendantAdded = signal(),
			DescendantRemoving = signal(),
			IsA = function(_self: any, name: string)
				return name == "Model"
			end,
			GetAttribute = function(_self: any, name: string)
				return attributes[name]
			end,
			GetPivot = function()
				return position
			end,
			GetExtentsSize = function()
				return vector(3, 3, 4)
			end,
			GetDescendants = function(): any
				body.CFrame = position
				local parts = { body }
				for _, part in articulated do
					table.insert(parts, part)
				end
				return parts
			end,
			IsDescendantOf = function()
				return true
			end,
			FindFirstChildWhichIsA = function()
				return {}
			end,
			PivotTo = function(_self: any, value: any)
				position = value
				for index, part in articulated do
					part.CFrame = value * original[index]
				end
			end,
		}
		added.fire(model)
		return model
	end
	local origin, oldSize = cf(), vector(30, 0, 24)
	local old = animal("transfer", origin, oldSize, 12)
	local garden = animal("transfer", cf(100, 0, 0), vector(18, 0, 28), -4.5)
	assert(
		garden:GetPivot().Position.X == 95.5,
		"assigning to a garden must use its safe spawn cell, not the old zone position"
	)
	local oldGrow = animal("growth", origin, oldSize, 7)
	local adult = animal("growth", cf(), vector(30, 0, 24), -5)
	assert(adult:GetPivot().Position.X == 7, "growth in the same area retains visual position")
	local smallerArea = animal("resize", origin, oldSize, 12)
	local resized = animal("resize", origin, vector(18, 0, 24), -4.5)
	assert(resized:GetPivot().Position.X == -4.5, "a resized area must not inherit coordinates beyond its edge")
	for _, model in { old, garden, oldGrow, adult, smallerArea, resized } do
		removed.fire(model)
	end
	supported = true
	table.insert(obstacles, {
		Parent = workspace,
		CanCollide = false,
		Position = vector(0, 0, 0),
		Size = vector(40, 3, 40),
		CFrame = cf(),
		IsA = function(_self: any, name: string): boolean
			return name == "BasePart"
		end,
	})
	local horse = animal("track", origin, vector(20, 0, 32), 0, "track", "horse")
	local function frames(count: number)
		for _ = 1, count do
			now += 0.1
			render.fire(0.1)
		end
	end
	frames(1)
	local start = horse:GetPivot().Position
	frames(20)
	assert(
		(horse:GetPivot().Position - start).Magnitude > 1,
		"Non-colliding training rails must not freeze the horse's track"
	)
	removed.fire(horse)
	table.clear(obstacles)
	blockRim = true
	local trapped = animal("recovery", origin, vector(20, 0, 32), 0, "track")
	frames(1)
	local stalled = trapped:GetPivot().Position
	randomFraction = 0.6
	frames(90)
	assert(
		(trapped:GetPivot().Position - stalled).Magnitude > 0.5,
		"Blocked oval must recover with safe wandering instead of retrying the same invalid step forever"
	)
	local before = trapped:GetPivot().Position
	reduced = true
	frames(10)
	assert(trapped:GetPivot().Position == before, "Motion reduction still stops animation")
	removed.fire(trapped)
	reduced = false
	blockRim = false
	local sleeper = animal("sleep", origin, vector(20, 0, 32), 0, "track", "cow")
	frames(20)
	local awakeY = sleeper:GetPivot().Position.Y
	lighting.ClockTime = 22
	frames(80)
	local sleeping = sleeper:GetPivot().Position
	assert(sleeping.Y < awakeY - 0.2, "Land animals settle down to sleep at night")
	frames(20)
	assert(math.abs(sleeper:GetPivot().Position.X - sleeping.X) < 0.001, "Sleeping animals stop walking their track")
	assert(math.abs(sleeper.leg.CFrame.Pitch) > 0.5, "Sleeping legs fold beneath the body")
	assert(
		math.abs(sleeper.leg.CFrame.Pitch - sleeper.rightLeg.CFrame.Pitch) < 0.001,
		"Front legs fold identically on both sides, not in opposite walking phases"
	)
	assert(
		math.abs(sleeper.rearLeft.CFrame.Pitch - sleeper.rearRight.CFrame.Pitch) < 0.001,
		"Rear legs fold symmetrically"
	)
	assert(
		sleeper.leg.CFrame.Pitch < 0 and sleeper.rearLeft.CFrame.Pitch > 0,
		"Front and rear legs tuck toward the body center"
	)
	assert(
		sleeper.foot.CFrame.Pitch == sleeper.leg.CFrame.Pitch
			and sleeper.rightFoot.CFrame.Pitch == sleeper.rightLeg.CFrame.Pitch,
		"Both bird feet follow their own leg joint"
	)
	assert(
		sleeper.hoof.CFrame.Pitch == sleeper.rearLeft.CFrame.Pitch
			and sleeper.rightHoof.CFrame.Pitch == sleeper.rearRight.CFrame.Pitch,
		"Both hooves follow their own leg joint"
	)
	assert(
		math.abs(sleeper.foot.CFrame.Position.Y - sleeper.rightFoot.CFrame.Position.Y) < 0.001
			and math.abs(sleeper.foot.CFrame.Position.Z - sleeper.rightFoot.CFrame.Position.Z) < 0.001,
		"Mirrored feet stay at equal height and depth when lying down"
	)
	assert(
		sleeper.foot.CFrame.Position.Y - sleeper.foot.Size.Y / 2 >= 0
			and sleeper.rightFoot.CFrame.Position.Y - sleeper.rightFoot.Size.Y / 2 >= 0,
		"Neither side's foot disappears below the ground"
	)
	local headPitch = sleeper.head.CFrame.Pitch
	sleeper.DescendantAdded.fire({})
	frames(10)
	assert(
		math.abs(sleeper.head.CFrame.Pitch - headPitch) < 0.02,
		"Cache rebuild must not accumulate the current head pose"
	)
	lighting.ClockTime = 12
	frames(80)
	assert(sleeper:GetPivot().Position.Y > sleeping.Y + 0.2, "Dawn returns animals to their standing height")
	assert((sleeper:GetPivot().Position - sleeping).Magnitude > 1, "Dawn resumes extension movement")
	removed.fire(sleeper)
	local fish = animal("fish", origin, vector(20, 0, 32), 0, "track", "salmon", true)
	lighting.ClockTime = 22
	frames(10)
	local fishStart = fish:GetPivot().Position
	frames(30)
	assert((fish:GetPivot().Position - fishStart).Magnitude > 0.1, "Fish keep swimming gently at night")
	assert(math.abs(fish:GetPivot().Position.Y - 1) < 0.1, "Fish never adopt a land sleeping pose")
	removed.fire(fish)
	lighting.ClockTime = 12
	local feeder = animal("feed", origin, vector(20, 0, 32), 0, "track", "chicken")
	frames(140)
	assert(feeder.head.CFrame.Pitch < -0.4, "Daytime pauses visibly dip the head to feed")
	local feedPosition = feeder:GetPivot().Position
	frames(5)
	assert(
		math.abs(feeder:GetPivot().Position.X - feedPosition.X) < 0.001,
		"Feeding pauses travel rather than sliding across the ground"
	)
	removed.fire(feeder)
	lighting.ClockTime = 22
	for _, species in
		{
			"bee",
			"buffalo",
			"camel",
			"chicken",
			"cow",
			"deer",
			"duck",
			"falcon",
			"goat",
			"horse",
			"llama",
			"parrot",
			"peacock",
			"pig",
			"pigeon",
			"quail",
			"rabbit",
			"sheep",
			"squirrel",
			"tortoise",
			"turkey",
			"yak",
		}
	do
		local resting = animal("symmetry_" .. species, origin, vector(20, 0, 32), 0, "track", species)
		frames(80)
		assert(
			math.abs(resting.leg.CFrame.Pitch - resting.rightLeg.CFrame.Pitch) < 0.001,
			species .. ": both sides use the same resting fold"
		)
		assert(
			math.abs(resting.foot.CFrame.Position.Y - resting.rightFoot.CFrame.Position.Y) < 0.001
				and math.abs(resting.foot.CFrame.Position.Z - resting.rightFoot.CFrame.Position.Z) < 0.001,
			species .. ": feet stay symmetric, including two-legged birds"
		)
		removed.fire(resting)
	end
	print("PASS animal animator: transfers, extension movement, day feeding, night rest, dawn and pose cache")
end
