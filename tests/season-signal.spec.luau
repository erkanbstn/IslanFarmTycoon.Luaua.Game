--!strict
return function(create: any)
	local function signal(): any
		local handlers = {}
		return {
			Connect = function(_, callback)
				local connection = { Connected = true }
				function connection:Disconnect()
					self.Connected = false
				end
				table.insert(handlers, { connection = connection, callback = callback })
				return connection
			end,
			fire = function(_, value)
				for _, item in handlers do
					if item.connection.Connected then
						item.callback(value)
					end
				end
			end,
			count = function()
				local count = 0
				for _, item in handlers do
					if item.connection.Connected then
						count += 1
					end
				end
				return count
			end,
		}
	end
	local added, removed, descendants = signal(), signal(), signal()
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
	local replicated = {
		WaitForChild = function(self)
			return self
		end,
	}
	local game = {
		GetService = function(_, name)
			if name == "CollectionService" then
				return collection
			end
			if name == "ReplicatedStorage" then
				return replicated
			end
			return { Heartbeat = signal() }
		end,
	}
	local script = { Parent = { Parent = replicated } }
	create(
		game,
		{
			spawn = function(callback)
				callback()
			end,
		},
		script,
		{},
		{ onChanged = function() end },
		{ Color = {} },
		{ onChanged = function() end },
		{ wait = function() end },
		{
			find = function()
				return nil
			end,
		},
		{},
		{}
	)
	local model = {
		IsA = function(_, class)
			return class == "Model"
		end,
		FindFirstChild = function()
			return nil
		end,
		DescendantAdded = descendants,
	}
	for _ = 1, 100 do
		added:fire(model)
		added:fire(model)
		assert(descendants.count() == 1, "Repeated tag notification must not duplicate descendant subscriptions")
		removed:fire(model)
		assert(descendants.count() == 0, "Tag removal must disconnect the streaming subscription")
	end
	print("season-signal: repeated tag add/remove leaves no duplicate or retained subscriptions")
end
