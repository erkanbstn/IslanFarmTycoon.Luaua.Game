--!strict
return function(startProgress: any)
	local function signal(): any
		local callbacks = {}
		return {
			Connect = function(_self: any, callback: any): any
				callbacks[callback] = true
				return {
					Disconnect = function()
						callbacks[callback] = nil
					end,
				}
			end,
			fire = function(...: any)
				for callback in callbacks do
					callback(...)
				end
			end,
			count = function(): number
				local count = 0
				for _ in callbacks do
					count += 1
				end
				return count
			end,
		}
	end
	local added, removed, heartbeat = signal(), signal(), signal()
	local scriptNode: any = {
		Destroying = signal(),
		WaitForChild = function(self: any): any
			return self
		end,
	}
	scriptNode.Parent = scriptNode
	local createdGuis = 0
	local destroyedGuis = 0
	local readyButtons = {}
	local instanceFactory = {
		new = function(className: string): any
			if className == "BillboardGui" then
				createdGuis += 1
			end
			local instance = {
				Activated = signal(),
				Destroy = function()
					if className == "BillboardGui" then
						destroyedGuis += 1
					end
				end,
			}
			if className == "TextButton" then
				table.insert(readyButtons, instance)
			end
			return instance
		end,
	}
	local player: any = {
		UserId = 42,
		WaitForChild = function(): any
			return {}
		end,
		GetAttribute = function(): string
			return "1"
		end,
	}
	local engine = {
		GetService = function(_self: any, name: string): any
			if name == "CollectionService" then
				return {
					GetInstanceAddedSignal = function(): any
						return added
					end,
					GetInstanceRemovedSignal = function(): any
						return removed
					end,
					GetTagged = function(): any
						return {}
					end,
				}
			elseif name == "RunService" then
				return { Heartbeat = heartbeat }
			elseif name == "Players" then
				return { LocalPlayer = player }
			elseif name == "Workspace" then
				return {
					GetServerTimeNow = function(): number
						return 100
					end,
				}
			end
			return {}
		end,
	}
	local uiKit = {
		Color = {},
		Radius = { Card = 1 },
		corner = function() end,
		stroke = function() end,
		padding = function() end,
		list = function() end,
		text = function(): any
			return {}
		end,
		setText = function(label: any, value: string)
			label.Text = value
		end,
		progressBar = function(): any
			return {}, function() end
		end,
	}
	local dimensions = { new = function() end, fromScale = function() end, fromOffset = function() end }
	local openedRecipes = {}
	startProgress(
		engine,
		uiKit,
		instanceFactory,
		dimensions,
		dimensions,
		dimensions,
		{
			TextXAlignment = {},
		},
		scriptNode,
		{
			openFocused = function(recipeId: string)
				table.insert(openedRecipes, recipeId)
			end,
		}
	)
	local anchor = {
		Name = "JobAnchor",
		IsA = function(_self: any, name: string): boolean
			return name == "BasePart"
		end,
	}
	local currentAnchor: any = nil
	local attributes: any = {
		JobKind = "production",
		JobStartedAt = 0,
		JobEndsAt = 99,
		JobRecipeId = "milk_goods",
		OwnerUserId = 42,
		MainFarmId = "1",
	}
	local model = {
		Parent = {},
		ChildAdded = signal(),
		Destroying = signal(),
		IsA = function(_self: any, name: string): boolean
			return name == "Model"
		end,
		FindFirstChild = function(): any
			return currentAnchor
		end,
		GetAttribute = function(_self: any, key: string): any
			return attributes[key]
		end,
	}
	added.fire(model)
	added.fire(model)
	assert(model.ChildAdded.count() == 1, "repeated tag arrival has one anchor watcher")
	removed.fire(model)
	assert(model.ChildAdded.count() == 0, "tag removal disconnects pending anchor watcher")
	model.ChildAdded.fire(anchor)
	assert(createdGuis == 0, "late anchor after tag removal cannot create orphan GUI")
	for _ = 1, 100 do
		added.fire(model)
		removed.fire(model)
	end
	assert(model.ChildAdded.count() == 0, "streaming churn leaves no pending callbacks")
	added.fire(model)
	model.ChildAdded.fire(anchor)
	assert(createdGuis == 1 and model.ChildAdded.count() == 0, "active anchor creates one GUI and releases waiter")
	heartbeat.fire(0.25)
	readyButtons[1].Activated.fire()
	assert(openedRecipes[1] == "milk_goods", "clicking ready own production opens its actual recipe")
	attributes.OwnerUserId = 7
	readyButtons[1].Activated.fire()
	attributes.OwnerUserId = 42
	attributes.MainFarmId = "2"
	readyButtons[1].Activated.fire()
	assert(#openedRecipes == 1, "other owners and inactive farms cannot be opened by the ready badge")
	attributes.MainFarmId = "1"
	attributes.JobEndsAt = 101
	heartbeat.fire(0.25)
	readyButtons[1].Activated.fire()
	assert(#openedRecipes == 1, "unfinished production does not expose the ready action")
	removed.fire(model)
	assert(destroyedGuis == 1 and model.Destroying.count() == 0, "untracking releases GUI and model destroy callback")
	assert(readyButtons[1].Activated.count() == 0, "untracking releases the ready click handler")
	currentAnchor = anchor
	added.fire(model)
	assert(createdGuis == 2, "streamed model can be tracked again")
	scriptNode.Destroying.fire()
	assert(destroyedGuis == 2 and model.Destroying.count() == 0, "script destruction releases active GUI")
	assert(
		added.count() == 0 and removed.count() == 0 and heartbeat.count() == 0,
		"script destruction disconnects global signals"
	)
	print("PASS client job progress: removed-tag late anchors, 100 streaming cycles, retracking and complete cleanup")
end
