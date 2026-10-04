--!strict
return function(start: any, BridgeSurface: any)
	local function signal(): any
		local callbacks = {}
		return {
			Connect = function(_self: any, callback: any): any
				local connection = { connected = true }
				function connection:Disconnect()
					self.connected = false
				end
				table.insert(callbacks, { callback = callback, connection = connection })
				return connection
			end,
			fire = function(_self: any, ...: any)
				for _, entry in callbacks do
					if entry.connection.connected then
						entry.callback(...)
					end
				end
			end,
			count = function(): number
				local count = 0
				for _, entry in callbacks do
					if entry.connection.connected then
						count += 1
					end
				end
				return count
			end,
		}
	end
	local now = 0
	local attributes = {}
	local objects = {}
	local function instance(class: string): any
		local object = { ClassName = class, destroyed = false }
		function object:IsA(expected: string): boolean
			return self.ClassName == expected or (self.ClassName == "Part" and expected == "BasePart")
		end
		function object:Destroy()
			self.destroyed = true
			self.Parent = nil
		end
		table.insert(objects, object)
		return object
	end
	local vectorMeta: any = {}
	vectorMeta.__add = function(a: any, b: any): any
		return setmetatable({ X = a.X + b.X, Y = a.Y + b.Y, Z = a.Z + b.Z }, vectorMeta)
	end
	local vectors = {
		new = function(x: number, y: number, z: number): any
			return setmetatable({ X = x, Y = y, Z = z }, vectorMeta)
		end,
	}
	local root = instance("Part")
	root.Position = vectors.new(0, 0, 0)
	root.AssemblyLinearVelocity = { Magnitude = 10 }
	root.Parent = {}
	local humanoid = { Health = 100 }
	local character = {
		FindFirstChild = function(): any
			return root
		end,
		FindFirstChildOfClass = function(): any
			return humanoid
		end,
	}
	local player = {
		Character = character,
		CharacterAdded = signal(),
		CharacterRemoving = signal(),
		GetAttribute = function(_self: any, key: string): any
			return attributes[key]
		end,
		SetAttribute = function(_self: any, key: string, value: any)
			attributes[key] = value
		end,
	}
	local model = instance("Model")
	model.Name = "BridgeModule_8"
	local deck = instance("Part")
	deck.Name, deck.Parent = "DeckPlank", model
	local hit: any = { Instance = deck }
	local heartbeat = signal()
	local services = {
		Players = { LocalPlayer = player },
		RunService = { Heartbeat = heartbeat },
		Workspace = {
			Raycast = function(): any
				return hit
			end,
		},
	}
	local scriptMock = {
		Parent = { Parent = {
			WaitForChild = function(self: any): any
				return self
			end,
		} },
		Destroying = signal(),
	}
	start(
		{
			GetService = function(_self: any, name: string): any
				return services[name]
			end,
		},
		BridgeSurface,
		scriptMock,
		{
			new = function()
				return {}
			end,
		},
		{ RaycastFilterType = { Exclude = "Exclude" } },
		vectors,
		{ new = instance },
		{
			clock = function()
				return now
			end,
		},
		{
			new = function(...)
				return { ... }
			end,
		},
		{
			fromRGB = function(...)
				return { ... }
			end,
		},
		{
			new = function(...)
				return { ... }
			end,
		},
		{
			new = function(...)
				return { ... }
			end,
		},
		function(message: string)
			error(message)
		end
	)
	local function tick(seconds: number)
		now += seconds
		heartbeat:fire(seconds)
	end
	local function trails(enabled: boolean?): number
		local count = 0
		for _, object in objects do
			if
				object.ClassName == "Trail"
				and not object.destroyed
				and (enabled == nil or object.Enabled == enabled)
			then
				count += 1
			end
		end
		return count
	end
	tick(0.1)
	assert(attributes.OnBridge == true and trails(true) == 3, "bridge movement activates three wind trails")
	for _ = 1, 100 do
		tick(0.1)
	end
	assert(trails() == 3, "long bridge travel reuses bounded trail objects")
	attributes.ReducedMotion = true
	tick(0.1)
	assert(attributes.OnBridge == true and trails(true) == 0, "reduced motion disables wind without losing speed")
	attributes.ReducedMotion, attributes.EffectsQuality = false, "low"
	tick(0.1)
	assert(trails(true) == 0, "low quality disables wind")
	attributes.EffectsQuality = "high"
	root.AssemblyLinearVelocity.Magnitude = 0
	tick(0.1)
	assert(trails(true) == 0, "stationary characters do not show speed streaks")
	root.AssemblyLinearVelocity.Magnitude = 10
	hit = nil
	tick(0.1)
	assert(attributes.OnBridge == true, "short bridge seams retain speed")
	tick(0.4)
	assert(attributes.OnBridge == false and trails(true) == 0, "leaving bridge restores normal movement")
	hit = { Instance = deck }
	tick(0.1)
	player.CharacterRemoving:fire()
	assert(trails() == 0 and attributes.OnBridge == false, "character removal destroys wind resources")
	player.CharacterAdded:fire()
	tick(0.1)
	assert(trails() == 3, "respawn rebuilds one wind set")
	humanoid.Health = 0
	tick(0.1)
	assert(trails() == 0 and attributes.OnBridge == false, "death clears bridge state and resources")
	scriptMock.Destroying:fire()
	assert(
		heartbeat.count() == 0 and player.CharacterAdded.count() == 0 and player.CharacterRemoving.count() == 0,
		"script teardown disconnects lifecycle listeners"
	)
	for _, object in objects do
		if object.ClassName == "Attachment" then
			assert(object.destroyed, "owned attachments are destroyed")
		end
	end
	print("PASS bridge boost: wind bounds, quality, grace, death, respawn and cleanup")
end
