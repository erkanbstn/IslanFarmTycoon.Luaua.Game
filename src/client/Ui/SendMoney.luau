--!strict
-- "Para gönder" penceresi: alıcı ve tutar seçilir; doğrulama, bakiye düşümü ve alıcıya ekleme sunucudadır (Services/TransferService).
-- Bu arayüz yalnızca ön kontroldür (boş/yetmeyen tutarı sunucuya yollamamak için).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local FarmMath = require(Shared:WaitForChild("Modules"):WaitForChild("FarmMath"))
local UiKit = require(script.Parent:WaitForChild("UiKit"))
local Core = script.Parent.Parent:WaitForChild("Core")
local ClientState = require(Core:WaitForChild("ClientState"))
local PurchaseController = require(Core:WaitForChild("PurchaseController"))

local player = Players.LocalPlayer
local SendMoney = {}

local MAX_AMOUNT = 1e12 -- Asıl sınır sunucudaki TransferRules'tadır.

local window: UiKit.Window? = nil
local targetUserId = 0
local targetName = ""
local heading: TextLabel? = nil
local balance: TextLabel? = nil
local message: TextLabel? = nil
local amountBox: TextBox? = nil
local sendButton: TextButton? = nil

local function setMessage(text: string, ok: boolean?)
	local label = message
	if label then
		label.Text = text
		label.TextColor3 = if ok == true
			then UiKit.Color.Green
			elseif ok == false then UiKit.Color.Red
			else UiKit.Color.TextMuted
	end
end

local function refresh()
	local state = ClientState.get()
	local label = balance
	if label then
		label.Text = if state then `Kasan: {FarmMath.formatMoney(state.cash)}` else "Kasan: yükleniyor"
	end
	local button = sendButton
	if button then
		UiKit.setVariant(button, if PurchaseController.isPending() then "disabled" else "primary")
	end
end

local function create(): UiKit.Window
	local screen = Instance.new("ScreenGui")
	screen.Name = "SendMoney"
	screen.ResetOnSpawn = false
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screen.DisplayOrder = 7
	screen.Parent = player:WaitForChild("PlayerGui")
	local root = UiKit.screenRoot(screen)
	local created = UiKit.window(root, {
		title = "Para gönder",
		icon = "💸",
		tint = UiKit.Color.Green,
		width = 340,
		maxHeight = 360,
		anchor = Vector2.new(0.5, 0.5),
		position = UDim2.fromScale(0.5, 0.5),
	})
	created.frame.BackgroundColor3 = UiKit.Color.Surface
	created.frame.BackgroundTransparency = 0
	heading = UiKit.text(created.list, "", "Heading");
	(heading :: TextLabel).LayoutOrder = 1
	balance = UiKit.text(created.list, "", "Caption");
	(balance :: TextLabel).LayoutOrder = 2
	local box = UiKit.textInput(created.list, "Tutar (örnek: 1000)")
	box.Name = "TransferAmount"
	box.LayoutOrder = 3
	amountBox = box
	local quick = Instance.new("Frame")
	quick.BackgroundTransparency = 1
	quick.Size = UDim2.new(1, 0, 0, 38)
	quick.LayoutOrder = 4
	quick.Parent = created.list
	UiKit.list(quick, 6, true)
	for index, option in
		{ { label = "%10", share = 0.1 }, { label = "%50", share = 0.5 }, { label = "Tümü", share = 1 } }
	do
		local button = UiKit.button(quick, option.label, "secondary")
		button.Size = UDim2.new(1 / 3, -4, 1, 0)
		button.LayoutOrder = index
		button.Activated:Connect(function()
			local state = ClientState.get()
			if state then
				box.Text = tostring(math.max(1, math.floor(state.cash * option.share)))
			end
		end)
	end
	message = UiKit.text(created.list, "", "Caption");
	(message :: TextLabel).LayoutOrder = 5
	local send = UiKit.button(created.list, "Gönder", "primary")
	send.Size = UDim2.new(1, 0, 0, 44)
	send.LayoutOrder = 6
	sendButton = send
	send.Activated:Connect(function()
		if PurchaseController.isPending() then
			return
		end
		local state = ClientState.get()
		local number = tonumber(box.Text)
		if not number or number ~= number or number < 1 or number % 1 ~= 0 then
			setMessage("1 veya daha büyük bir tam sayı yaz.", false)
			return
		end
		if number > MAX_AMOUNT then
			setMessage("Tek seferde en fazla 1 trilyon gönderilebilir.", false)
			return
		end
		if state and number > state.cash then
			setMessage("Bakiyen yetmiyor.", false)
			return
		end
		box:ReleaseFocus()
		setMessage("Sunucu yanıtı bekleniyor.", nil)
		PurchaseController.submitTargeted("RequestSendMoney", targetUserId, number)
	end)
	created.frame.Destroying:Connect(function()
		window = nil
	end)
	return created
end

PurchaseController.Completed:Connect(function(success: boolean, text: string)
	local current = window
	if not current or not current.isOpen() then
		return
	end
	setMessage(text, success)
	if success then
		local box = amountBox
		if box then
			box.Text = ""
		end
	end
end)
PurchaseController.Changed:Connect(refresh)
ClientState.onChanged(refresh)

function SendMoney.open(userId: number, displayName: string)
	if not window then
		window = create()
	end
	targetUserId = userId
	targetName = displayName
	local label = heading
	if label then
		label.Text = `Alıcı: {targetName}`
	end
	setMessage("Gönderilen para sende azalır, alıcıda aynen artar. Geri alınamaz.", nil)
	refresh();
	(window :: UiKit.Window).open()
end

return SendMoney
