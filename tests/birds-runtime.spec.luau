--!strict
-- Gerçek efekt betiği: katı yüzey, koşan oyuncu, streaming kaybı ve kapanış.
return function(createBirds: any, BirdBehavior: any)
	local mt: any = {}
	local function vector(x: number, y: number, z: number): any
		return setmetatable({ X = x, Y = y, Z = z }, mt)
	end
	mt.__add = function(a: any, b: any): any
		return vector(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
	end
	mt.__sub = function(a: any, b: any): any
		return vector(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
	end
	mt.__mul = function(a: any, b: number): any
		return vector(a.X * b, a.Y * b, a.Z * b)
	end
	mt.__div = function(a: any, b: number): any
		return vector(a.X / b, a.Y / b, a.Z / b)
	end
	mt.__index = function(a: any, key: string): any
		local length = math.sqrt(a.X ^ 2 + a.Y ^ 2 + a.Z ^ 2)
		return if key == "Magnitude" then length elseif key == "Unit" then a / length else nil
	end
	local cfMethods: any = {}
	local cfMt: any = { __index = cfMethods }
	local function frame(x: number?, y: number?, z: number?): any
		return setmetatable({
			Position = vector(x or 0, y or 0, z or 0),
			LookVector = vector(0, 0, -1),
			RightVector = vector(1, 0, 0),
			UpVector = vector(0, 1, 0),
		}, cfMt)
	end
	cfMt.__mul = function(a: any, b: any): any
		local p = a.Position + b.Position
		return frame(p.X, p.Y, p.Z)
	end
	cfMethods.ToObjectSpace = function(a: any, b: any): any
		local p = b.Position - a.Position
		return frame(p.X, p.Y, p.Z)
	end
	cfMethods.Lerp = function(a: any, b: any, alpha: number): any
		local p = a.Position + (b.Position - a.Position) * alpha
		return frame(p.X, p.Y, p.Z)
	end
	local function signal(): any
		local callbacks = {}
		return {
			Connect = function(_self: any, callback: any): any
				local connection = { active = true }
				connection.Disconnect = function()
					connection.active = false
				end
				table.insert(callbacks, { connection, callback })
				return connection
			end,
			fire = function(...: any)
				for _, pair in callbacks do
					if pair[1].active then
						pair[2](...)
					end
				end
			end,
		}
	end
	local heartbeat, destroying = signal(), signal()
	local now, rays, playerReads = 0, 0, 0
	local reduced, night, surfaceLoaded = false, false, true
	local root: any = nil
	local models: { any } = {}
	local folder: any = nil
	local workspaceMock: any = { CurrentCamera = { CFrame = frame(0, 20, -150) } }
	local surface = { CanCollide = true, Transparency = 0, CFrame = frame(), Parent = workspaceMock }
	surface.IsA = function(_self: any, class: string): boolean
		return class == "BasePart"
	end
	surface.IsDescendantOf = function(): boolean
		return surfaceLoaded
	end
	workspaceMock.Raycast = function(_self: any, origin: any): any
		rays += 1
		return if surfaceLoaded
			then {
				Instance = surface,
				Normal = vector(0, 1, 0),
				Material = "Grass",
				Position = vector(origin.X, 0, origin.Z),
			}
			else nil
	end
	local services: any = {
		Workspace = workspaceMock,
		RunService = { Heartbeat = heartbeat },
		ReplicatedStorage = {
			WaitForChild = function(): any
				return {}
			end,
		},
		CollectionService = {
			HasTag = function(): boolean
				return false
			end,
		},
		Players = {
			GetPlayers = function(): any
				playerReads += 1
				return if root
					then {
						{
							Character = {
								FindFirstChild = function(): any
									return root
								end,
							},
						},
					}
					else {}
			end,
		},
	}
	local assets = {
		clone = function(): any
			local parts = {}
			for _, name in { "Body", "LeftWing", "RightWing", "Tail" } do
				table.insert(parts, {
					Name = name,
					Size = vector(1, 0.5, 1),
					CFrame = frame(),
					Transparency = 1,
					IsA = function(): boolean
						return true
					end,
				})
			end
			local model = { frame = frame(), parts = parts }
			model.ScaleTo = function() end
			model.GetPivot = function(): any
				return model.frame
			end
			model.GetDescendants = function(): any
				return parts
			end
			model.FindFirstChild = function(_self: any, name: string): any
				for _, part in parts do
					if part.Name == name then
						return part
					end
				end
				return nil
			end
			model.PivotTo = function(_self: any, cf: any)
				model.frame = cf
			end
			table.insert(models, model)
			return model
		end,
	}
	local cframe = {
		identity = frame(),
		new = function(x: any, y: number?, z: number?): any
			return if type(x) == "table" then frame(x.X, x.Y, x.Z) else frame(x, y, z)
		end,
		Angles = function(): any
			return frame()
		end,
		lookAt = function(p: any, _target: any): any
			return frame(p.X, p.Y, p.Z)
		end,
	}
	createBirds(
		{
			GetService = function(_self: any, name: string): any
				return services[name]
			end,
		},
		{ Destroying = destroying },
		{
			quality = function(): string
				return "high"
			end,
			reducedMotion = function(): boolean
				return reduced
			end,
		},
		assets,
		BirdBehavior,
		{
			getWeather = function(): any
				return { id = "sunny" }
			end,
			getClockTime = function(): number
				return 12
			end,
			getNightFactor = function(): number
				return if night then 1 else 0
			end,
		},
		{ wait = function() end },
		{
			new = function(): any
				return {
					NextNumber = function(_self: any, a: number?, b: number?): number
						return if a and b then (a + b) / 2 else 0.5
					end,
					NextInteger = function(_self: any, a: number): number
						return a
					end,
				}
			end,
		},
		{
			new = function(): any
				folder = {
					Destroy = function(self: any)
						self.destroyed = true
					end,
				}
				return folder
			end,
		},
		{
			new = function(): any
				return {}
			end,
		},
		{ RaycastFilterType = { Exclude = "exclude" }, Material = { Water = "Water" } },
		cframe,
		{ new = vector, xAxis = vector(1, 0, 0) },
		{
			clock = function(): number
				return now
			end,
		},
		function() end
	)
	local function advance(seconds: number)
		for _ = 1, math.ceil(seconds / 0.05) do
			now += 0.05
			heartbeat.fire(0.05)
		end
	end
	advance(18)
	local perched: any = nil
	for _, model in models do
		if model.frame.Position.Y < 1 and model.parts[1].Transparency == 0 then
			perched = model
			break
		end
	end
	assert(perched, "actual bird script descends onto solid ground")
	assert(perched.frame.Position.Y >= 0.25, "model bottom stays above the surface")
	assert(rays <= 45 and playerReads < 80, "raycast and player sampling remain bounded")
	local landed = perched.frame.Position
	root = {
		Position = landed + vector(0, 0, 8),
		AssemblyLinearVelocity = vector(0, 0, 10),
		Parent = true,
		IsA = function(): boolean
			return true
		end,
	}
	advance(1)
	assert(perched.frame.Position.Y > landed.Y + 2, "nearby runner triggers real takeoff")
	root = nil
	advance(25)
	local resting: any = nil
	for _, model in models do
		if model.frame.Position.Y < 1 and model.parts[1].Transparency == 0 then
			resting = model
			break
		end
	end
	assert(resting, "birds can land again after returning to flight")
	surfaceLoaded = false
	advance(1)
	assert(resting.frame.Position.Y > 2, "streamed-out support triggers takeoff rather than hovering")
	night = true
	advance(0.1)
	for _, model in models do
		assert(model.parts[1].Transparency == 1, "night hides daytime birds")
	end
	night, reduced = false, true
	advance(0.1)
	for _, model in models do
		assert(model.parts[1].Transparency == 1, "reduced motion disables moving birds")
	end
	destroying.fire()
	assert(folder.destroyed, "shutdown removes the pool")
	local reads = playerReads
	advance(1)
	assert(playerReads == reads, "shutdown disconnects heartbeat")
end
