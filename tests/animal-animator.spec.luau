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
	}
	cfMt.__mul = function(a: any, b: any)
		local p = a.Position + b.Position
		return cf(p.X, p.Y, p.Z)
	end
	cfMt.__eq = function(a: any, b: any)
		return a.Position == b.Position
	end
	local added, removed, render = signal(), signal(), signal()
	local collection = {
		GetInstanceAddedSignal = function()
			return added
		end,
		GetInstanceRemovedSignal = function()
			return removed
		end,
		GetTagged = function()
			return {}
		end,
	}
	local workspace = {
		Raycast = function()
			return nil
		end,
	}
	local gameMock = {
		GetService = function(_self: any, name: string)
			return ({ CollectionService = collection, RunService = { PreRender = render }, Workspace = workspace })[name]
		end,
	}
	createAnimator(gameMock, {}, { new = vector }, {
		new = cf,
		Angles = function()
			return cf()
		end,
	}, {
		new = function()
			return {
				NextNumber = function(_self: any, low: number, high: number)
					return (low + high) / 2
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
	}, { RaycastFilterType = { Exclude = 0 } }, function(value: any)
		return if type(value) == "table" then value.kind or "table" else type(value)
	end)
	local function animal(uid: string, area: any, size: any, x: number): any
		local position = area * cf(x, 1, 0)
		local attributes = { Uid = uid, AreaCFrame = area, AreaSize = size, HeightOffset = 1 }
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
	print("PASS animal animator: garden transfer, growth continuation and resized-area spawn")
end
