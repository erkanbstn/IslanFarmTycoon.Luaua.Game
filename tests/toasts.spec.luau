--!strict
return function(createToasts: any, createBadge: any)
	local objects, jobs = {}, {}
	local now, tweenCount, cancelledTweens = 0, 0, 0
	local reduced = false
	local function signal(): any
		local listeners = {}
		return {
			Connect = function(_self: any, callback: any): any
				local listener = { callback = callback, live = true }
				table.insert(listeners, listener)
				return {
					Disconnect = function()
						listener.live = false
					end,
				}
			end,
			Fire = function()
				for _, listener in listeners do
					if listener.live then
						listener.callback()
					end
				end
			end,
			Count = function(): number
				local count = 0
				for _, listener in listeners do
					if listener.live then
						count += 1
					end
				end
				return count
			end,
		}
	end
	local instance: any = {}
	instance.new = function(class: string): any
		local properties = {}
		local object: any = {
			ClassName = class,
			Destroying = signal(),
			Activated = signal(),
			Visible = true,
			AbsolutePosition = { X = 0, Y = 0 },
			AbsoluteSize = { X = 400, Y = 50 },
		}
		object.IsA = function(_self: any, kind: string): boolean
			return class == kind
				or (kind == "GuiObject" and (class == "Frame" or class == "CanvasGroup" or class == "TextLabel"))
		end
		object.GetPropertyChangedSignal = function(_self: any, name: string): any
			properties[name] = properties[name] or signal()
			return properties[name]
		end
		object.FindFirstAncestorOfClass = function(self: any, kind: string): any
			local ancestor = self.Parent
			while ancestor do
				if ancestor:IsA(kind) then
					return ancestor
				end
				ancestor = ancestor.Parent
			end
			return nil
		end
		object.Destroy = function(self: any)
			if self.destroyed then
				return
			end
			self.destroyed = true
			self.Destroying.Fire()
			for _, child in objects do
				if child.Parent == self then
					child:Destroy()
				end
			end
			self.Parent = nil
		end
		table.insert(objects, object)
		return object
	end
	local taskMock = {
		delay = function(seconds: number, callback: any): any
			local job = { due = now + seconds, callback = callback, live = true }
			table.insert(jobs, job)
			return job
		end,
		cancel = function(job: any)
			job.live = false
		end,
	}
	local function advance(seconds: number)
		local untilTime = now + seconds
		while true do
			local first: any = nil
			for _, job in jobs do
				if job.live and job.due <= untilTime and (not first or job.due < first.due) then
					first = job
				end
			end
			if not first then
				break
			end
			now = first.due
			first.live = false
			first.callback()
		end
		now = untilTime
	end
	local function liveJobs(): number
		local count = 0
		for _, job in jobs do
			if job.live then
				count += 1
			end
		end
		return count
	end
	local function countClass(class: string): number
		local count = 0
		for _, object in objects do
			if object.ClassName == class and object.Parent and not object.destroyed then
				count += 1
			end
		end
		return count
	end
	local function find(name: string): any
		for _, object in objects do
			if object.Name == name and not object.destroyed then
				return object
			end
		end
		return nil
	end
	local dim = {
		new = function(...: any): any
			return { ... }
		end,
	}
	local size = { new = dim.new, fromOffset = dim.new, fromScale = dim.new }
	local vector = {
		new = function(x: number, y: number): any
			return { X = x, Y = y }
		end,
	}
	local base = {
		corner = function() end,
		stroke = function(): any
			return {}
		end,
		list = function(): any
			return {}
		end,
		text = function(parent: any, text: string): any
			local label = instance.new("TextLabel")
			label.Text = text
			label.Parent = parent
			return label
		end,
	}
	local playerGui = instance.new("PlayerGui")
	local screenGui = instance.new("ScreenGui")
	screenGui.Parent = playerGui
	local root = instance.new("Frame")
	root.Parent = screenGui
	local screen = {
		scale = function(): number
			return 2
		end,
		root = function(gui: any): any
			local frame = instance.new("Frame")
			frame.Parent = gui
			return frame
		end,
	}
	local tweenService = {
		Create = function(): any
			tweenCount += 1
			return {
				Play = function() end,
				Cancel = function()
					cancelledTweens += 1
				end,
			}
		end,
	}
	local tokens =
		{ Color = { Green = 1, Red = 2, Blue = 3, Panel = 4 }, Font = { Bold = 1 }, MenuTileSize = { Y = 60 } }
	local toasts = createToasts(
		{
			GetService = function()
				return tweenService
			end,
		},
		tokens,
		base,
		screen,
		{
			reducedMotion = function(): boolean
				return reduced
			end,
		},
		instance,
		size,
		dim,
		vector,
		{ AutomaticSize = { Y = 1, X = 2 }, HorizontalAlignment = { Center = 1 }, ZIndexBehavior = { Sibling = 1 } },
		taskMock,
		dim
	)
	local banner = instance.new("Frame")
	banner.Parent = root
	banner.AbsolutePosition.Y = 240
	banner.AbsoluteSize.Y = 160
	local show = toasts.toastHost(root, { banner })
	local holder = find("Toasts")
	assert(holder.Position[4] == 208, "toasts start below real tutorial height, accounting for root scale")
	assert(
		find("Notifications").DisplayOrder > 5,
		"notifications must appear above IslandManager's independent ScreenGui"
	)
	local secondRoot = instance.new("Frame")
	secondRoot.Parent = screenGui
	local otherShow = toasts.toastHost(secondRoot)
	assert(otherShow == show and countClass("ScreenGui") == 2, "different UI callers share one visible layer and queue")
	banner.Visible = false
	banner:GetPropertyChangedSignal("Visible").Fire()
	assert(holder.Position[4] == 82, "hidden tutorial releases its vertical reservation")
	banner.Visible = true
	banner.AbsoluteSize.Y = 240
	banner:GetPropertyChangedSignal("AbsoluteSize").Fire()
	assert(holder.Position[4] == 248, "long translated tutorial text repositions notifications")
	local badgeKit = {
		Color = { Panel = 1, Gold = 2 },
		Font = { Bold = 1 },
		TouchTarget = 44,
		corner = base.corner,
		stroke = base.stroke,
		padding = function() end,
		list = base.list,
		iconChip = function() end,
		text = base.text,
		screenScale = screen.scale,
		setText = function(label: any, text: string)
			label.Text = text
		end,
	}
	local badgeModule = createBadge(
		{
			GetService = function(_self: any, name: string): any
				if name == "Players" then
					return { LocalPlayer = { SetAttribute = function() end } }
				end
				if name == "Workspace" then
					return {
						GetServerTimeNow = function()
							return 0
						end,
					}
				end
				return {
					WaitForChild = function(self: any)
						return self
					end,
				}
			end,
		},
		{
			newTracker = function()
				return {}
			end,
		},
		{ play = function() end },
		badgeKit,
		instance,
		vector,
		size,
		{ AutomaticSize = { X = 1 }, VerticalAlignment = { Center = 1 } }
	)
	local badge = badgeModule.create(root, function() end, show, banner)
	assert(badge.frame.Position[4] == 248, "merchant badge also reserves tutorial's actual bottom")
	banner.Visible = false
	banner:GetPropertyChangedSignal("Visible").Fire()
	assert(badge.frame.Position[4] == 112, "hidden tutorial returns merchant badge to its normal position")
	banner.Visible = true
	banner:GetPropertyChangedSignal("Visible").Fire()
	local subscriptions = banner:GetPropertyChangedSignal("Visible").Count()
	badge.frame:Destroy()
	assert(
		banner:GetPropertyChangedSignal("Visible").Count() == subscriptions - 1,
		"merchant cleanup removes tutorial listeners"
	)
	for index = 1, 1000 do
		show(`notice-{index}`)
	end
	assert(countClass("CanvasGroup") == 2 and liveJobs() == 2, "burst creates only two visible cards and two timers")
	otherShow("notice-1000")
	otherShow("notice-1000")
	advance(2.95)
	assert(countClass("CanvasGroup") == 2, "queued entries replace expired cards without overlapping fade generations")
	local firstPending, merged = false, false
	for _, object in objects do
		if object.ClassName == "TextLabel" and object.Parent and not object.destroyed then
			if object.Text == "notice-995" then
				firstPending = true
			end
		end
	end
	assert(firstPending, "overflow keeps only the last six pending notices")
	advance(5.9)
	for _, object in objects do
		if object.ClassName == "TextLabel" and object.Parent and not object.destroyed and object.Text == "×3" then
			merged = true
		end
	end
	assert(merged, "duplicates from different callers coalesce even while pending")
	advance(3)
	assert(countClass("CanvasGroup") == 0 and liveJobs() == 0, "queue fully drains without retained timers/cards")
	show("refresh", "money")
	advance(2.6)
	local before = cancelledTweens
	show("refresh", "money")
	assert(
		cancelledTweens == before + 1 and liveJobs() == 1,
		"repeat during fade cancels old tween/removal and renews lifetime"
	)
	advance(0.35)
	assert(countClass("CanvasGroup") == 1, "old fade callback cannot delete renewed notice")
	advance(3)
	reduced = true
	local previousTweens = tweenCount
	show("quiet")
	advance(2.6)
	assert(tweenCount == previousTweens and countClass("CanvasGroup") == 0, "ReducedMotion avoids fade animation")
	banner:Destroy()
	assert(
		holder.Position[4] == 82 and banner:GetPropertyChangedSignal("Visible").Count() == 0,
		"removed tutorial releases its space and watchers immediately"
	)
	for _index = 1, 1000 do
		show("repeated")
	end
	assert(liveJobs() == 1, "repeats cancel the previous timer instead of scheduling unbounded callbacks")
	root:Destroy()
	assert(
		liveJobs() == 0 and countClass("CanvasGroup") == 0 and not find("Notifications"),
		"owner destruction cleans overlay, pending entries and timers"
	)
	assert(banner:GetPropertyChangedSignal("Visible").Count() == 0, "reservation signal subscriptions are disconnected")
	show("late")
	assert(countClass("CanvasGroup") == 0, "stale caller after owner destruction is harmless")
	local replacement = toasts.toastHost(secondRoot)
	replacement("new")
	assert(countClass("CanvasGroup") == 1, "destroyed shared host can be recreated")
	secondRoot:Destroy()
	print(
		"PASS toast flow: shared overlay, tutorial clearance, bounded burst/duplicates, fade races, ReducedMotion and cleanup"
	)
end
