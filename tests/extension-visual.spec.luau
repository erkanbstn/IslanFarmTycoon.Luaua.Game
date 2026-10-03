--!strict
return function(create: any)
	local instances = {}
	local function node(class: string, name: string): any
		local attributes, children, callbacks = {}, {}, {}
		local result = {
			Name = name,
			Position = { X = 0, Y = 10, Z = 0 },
			children = children,
			SetAttribute = function(_, key, value)
				attributes[key] = value
			end,
			GetAttribute = function(_, key)
				return attributes[key]
			end,
			IsA = function(_, expected)
				return class == expected or (class == "Part" and expected == "BasePart")
			end,
			FindFirstChild = function(_, key)
				return children[key]
			end,
			FindFirstChildWhichIsA = function()
				return nil
			end,
			GetChildren = function()
				local list = {}
				for _, child in children do
					table.insert(list, child)
				end
				return list
			end,
			GetPivot = function()
				return {}
			end,
			ClearAllChildren = function()
				table.clear(children)
			end,
			Triggered = {
				Connect = function(_, callback)
					table.insert(callbacks, callback)
				end,
			},
			fire = function(_, player)
				for _, callback in callbacks do
					callback(player)
				end
			end,
		}
		table.insert(instances, result)
		return result
	end
	local function build(parent: any, name: string, boardName: string): any
		local model = node("Model", name)
		model.Parent = parent
		model.children[boardName] = node("Part", boardName)
		parent.children[name] = model
		return model
	end
	local notifications = {}
	local remotes = {
		get = function()
			return {
				FireClient = function(_, player, message, kind)
					table.insert(notifications, { player = player, message = message, kind = kind })
				end,
			}
		end,
	}
	local upgrade = { id = "upgrade", displayName = "Test yükseltmesi" }
	local config = {
		getExtensionUpgrade = function()
			return upgrade
		end,
		getUpgrade = function()
			return upgrade
		end,
		getExtension = function()
			return {}
		end,
	}
	local farmMath = {
		formatUpgradePrice = function()
			return "100"
		end,
		getExtensionCapacity = function()
			return 2
		end,
		countInExtension = function()
			return 1
		end,
	}
	local instanceUtil = {
		getOrCreateFolder = function(parent, name)
			if not parent.children[name] then
				parent.children[name] = node("Folder", name)
			end
			return parent.children[name]
		end,
	}
	local specialization = {
		EXTENSIONS = { ext = { island = "home", title = "Test", id = "ext" } },
		buildForSaleSign = function(parent)
			return build(parent, "ForSale_ext", "ForSaleSign")
		end,
		buildExtensionVisual = function(parent)
			return build(parent, "ext", "SpecialtySign")
		end,
		markObstacles = function() end,
	}
	local shared = {
		WaitForChild = function(self)
			return self
		end,
	}
	local game = {
		GetService = function(_, service)
			return if service == "Workspace"
				then {
					GetServerTimeNow = function()
						return 0
					end,
				}
				else shared
		end,
	}
	local script = { Parent = { Parent = shared } }
	local service = create(
		game,
		script,
		{
			new = function(class)
				return node(class, "")
			end,
		},
		{ one = {} },
		{
			new = function()
				return {}
			end,
		},
		{
			new = function()
				return {}
			end,
		},
		{ KeyCode = { F = "F", ButtonX = "ButtonX" } },
		{
			now = function()
				return { UnixTimestampMillis = 0 }
			end,
		},
		config,
		remotes,
		{},
		farmMath,
		instanceUtil,
		{
			extensionSummary = function()
				return 1, nil, nil
			end,
			ensureAnchor = function() end,
			setExtension = function() end,
		},
		{ configureProximityPrompt = function() end },
		specialization,
		{},
		{}
	)
	local owner, visitor = {}, {}
	local function apply(owned: boolean): any
		local plot, island = node("Model", "Plot"), node("Model", "Home")
		island:SetAttribute("FarmIslandId", "home")
		local islands = node("Folder", "Islands")
		islands.children.home = island
		plot.children.Islands = islands
		service.apply(plot, { unlockedIslands = { home = true }, purchased = { upgrade = owned } })
		return plot
	end
	local function prompt(name: string): any
		for index = #instances, 1, -1 do
			if instances[index].Name == name then
				return instances[index]
			end
		end
		error(`Missing actual prompt {name}`)
	end
	apply(false)
	local buy = prompt("BuyExtensionPrompt")
	buy:fire(owner)
	assert(#notifications == 0, "Unconfigured actions must fail closed")
	local calls = {}
	local success, message = true, nil
	local actualOwner = owner
	local function action(name: string): any
		return function(player, id)
			table.insert(calls, { name = name, player = player, id = id })
			return success, message
		end
	end
	service.configure({
		getOwner = function()
			return actualOwner
		end,
		tryBuy = action("buy"),
		tryAssign = action("assign"),
		tryUnassign = action("unassign"),
	})
	buy:fire(visitor)
	assert(#calls == 0 and #notifications == 0, "Visitors must not reach actions")
	buy:fire(owner)
	assert(calls[1].name == "buy" and calls[1].id == "upgrade", "Buy must pass the exact upgrade id")
	assert(
		notifications[1].player == owner
			and notifications[1].message == "Test yükseltmesi açıldı!"
			and notifications[1].kind == "success",
		"Successful purchase notification must be preserved"
	)
	success, message = false, "Test hatası"
	buy:fire(owner)
	assert(notifications[2].message == message and notifications[2].kind == "error", "Purchase error must be forwarded")
	message = nil
	buy:fire(owner)
	assert(#notifications == 2, "Silent rate limit failures must stay silent")
	apply(true)
	local assign, unassign = prompt("ExtensionAssignPrompt"), prompt("ExtensionUnassignPrompt")
	assign:fire(visitor)
	unassign:fire(visitor)
	assert(#calls == 3, "Visitor assignment and recall must be rejected")
	success = true
	assign:fire(owner)
	unassign:fire(owner)
	assert(
		calls[4].name == "assign" and calls[4].id == "ext" and calls[5].name == "unassign" and calls[5].id == "ext",
		"Assignment/recall must pass the extension id"
	)
	assert(#notifications == 2, "Successful assignment/recall should not emit extra notifications")
	success, message = false, "Eklenti hatası"
	assign:fire(owner)
	unassign:fire(owner)
	assert(
		#notifications == 4 and notifications[3].kind == "error" and notifications[4].message == message,
		"Assignment/recall errors must be forwarded"
	)
	message = nil
	assign:fire(owner)
	unassign:fire(owner)
	assert(#notifications == 4, "Silent extension failures must remain silent")
	actualOwner = visitor
	local previousCalls = #calls
	buy:fire(owner)
	assign:fire(owner)
	unassign:fire(owner)
	assert(#calls == previousCalls, "Ownership must be checked at trigger time")
	print("extension-visual: actual buy/assign/recall callbacks preserve ownership, result and notification behavior")
end
