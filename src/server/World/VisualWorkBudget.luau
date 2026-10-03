--!strict
-- Birden fazla çiftlik geçişi aynı sunucu kare bütçesini paylaşır; normal güncellemeler bekletilmez.
local RunService = game:GetService("RunService")

local VisualWorkBudget = {}

local MAX_INSTANCES = 128
local MAX_SECONDS = 0.003
type ScopeFrame = { guard: (() -> boolean)? }
local scopes: { [thread]: { ScopeFrame } } = {}
local activeScopes = 0
local used = 0
local windowStarted = 0
local heartbeatConnection: RBXScriptConnection? = nil

function VisualWorkBudget.begin(guard: (() -> boolean)?)
	if not RunService:IsRunning() then
		return
	end
	local current = coroutine.running()
	local stack = scopes[current]
	if stack then
		table.insert(stack, { guard = guard })
		return
	end
	scopes[current] = { { guard = guard } }
	activeScopes += 1
	if not heartbeatConnection then
		heartbeatConnection = RunService.Heartbeat:Connect(function()
			used = 0
			windowStarted = 0
		end)
	end
end

function VisualWorkBudget.finish()
	local current = coroutine.running()
	local stack = scopes[current]
	if not stack then
		return
	end
	if #stack > 1 then
		table.remove(stack)
		return
	end
	scopes[current] = nil
	activeScopes -= 1
	if activeScopes == 0 and heartbeatConnection then
		heartbeatConnection:Disconnect()
		heartbeatConnection = nil
		used = 0
		windowStarted = 0
	end
end

local function checkGuards(stack: { ScopeFrame })
	for _, frame in stack do
		if frame.guard and not frame.guard() then
			error("Visual transition cancelled", 0)
		end
	end
end

function VisualWorkBudget.step(weight: number?)
	local stack = scopes[coroutine.running()]
	if not stack or not RunService:IsRunning() then
		return
	end
	checkGuards(stack)
	while used >= MAX_INSTANCES or (windowStarted > 0 and os.clock() - windowStarted >= MAX_SECONDS) do
		RunService.Heartbeat:Wait()
		checkGuards(stack)
	end
	if windowStarted == 0 then
		windowStarted = os.clock()
	end
	used += if weight and weight == weight then math.max(1, weight) else 1
end

return VisualWorkBudget
