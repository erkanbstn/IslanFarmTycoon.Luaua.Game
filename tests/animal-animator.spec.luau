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
		return setmetatable(
			{ Position = vector(x or 0, y or 0, z or 0), LookVector = vector(0, 0, -1), kind = "CFrame" },
			cfMt
		)
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
		local p = a.Position + b.Position
		return cf(p.X, p.Y, p.Z)
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
	local gameMock = {
		GetService = function(_self: any, name: string)
			return ({ CollectionService = collection, RunService = { PreRender = render }, Workspace = workspace })[name]
		end,
	}
	createAnimator(gameMock, {
		reducedMotion = function(): boolean
			return reduced
		end,
		quality = function(): string
			return "high"
		end,
	}, { new = vector }, {
		new = cf,
		Angles = function()
			return cf()
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
	local function animal(uid: string, area: any, size: any, x: number, movement: string?): any
		local position = area * cf(x, 1, 0)
		local attributes = { Uid = uid, AreaCFrame = area, AreaSize = size, HeightOffset = 1, MovementStyle = movement }
		local body = {
			IsA = function(_self: any, name: string): boolean
				return name == "BasePart"
			end,
			move = function(value: any)
				position = value
			end,
		}
		local model: any = {
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
				return { body }
			end,
			IsDescendantOf = function()
				return true
			end,
			FindFirstChildWhichIsA = function()
				return {}
			end,
			PivotTo = function(_self: any, value: any)
				position = value
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
	local horse = animal("track", origin, vector(20, 0, 32), 0, "track")
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
	print("PASS animal animator: garden transfer, growth continuation and resized-area spawn")
end
