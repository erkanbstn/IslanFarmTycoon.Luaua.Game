--!strict
-- Ahır deposundan ürünü KALICI silme onayı: miktar seçici (-/+, yazı kutusu, 1 / 10 / Yarısı / Hepsi), kırmızı uyarı ve ayrı onay düğmesi.
-- Tek tıkla silme yoktur: karttaki "Sil" yalnız bu paneli açar, silme onay düğmesindedir. Satış düğmelerine dokunmaz; para verilmez.
-- Yalnız ürün adedi silinir. Ekipman ve kalıcı haklar için silme eylemi bilerek yoktur (altın/Robux ile alınmış olabilirler).
-- Miktar sunucuda yeniden doğrulanır (GoodsDiscard.validAmount); buradaki sıkıştırma yalnızca kullanım kolaylığıdır.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local FarmMath = require(Shared:WaitForChild("Modules"):WaitForChild("FarmMath"))
local GoodsDiscard = require(Shared:WaitForChild("Modules"):WaitForChild("GoodsDiscard"))
local UiKit = require(script.Parent.Parent:WaitForChild("UiKit"))
local PurchaseController = require(script.Parent.Parent.Parent:WaitForChild("Core"):WaitForChild("PurchaseController"))
local HudCommon = require(script.Parent:WaitForChild("HudCommon"))

local GoodsDiscardPrompt = {}

GoodsDiscardPrompt.WARNING =
	"Bu işlem geri alınamaz: seçilen ürün kalıcı olarak silinir ve karşılığında para verilmez."

export type Panel = {
	window: UiKit.Window,
	open: (goodId: string, state: any) -> (),
	update: (state: any) -> (),
}

function GoodsDiscardPrompt.create(screenGui: Instance): Panel
	local window = UiKit.window(screenGui, {
		title = "Ürünü sil",
		icon = "🗑️",
		tint = UiKit.Color.Red,
		width = 460,
		maxHeight = 520,
		anchor = Vector2.new(0.5, 0.5),
		position = UDim2.fromScale(0.5, 0.5),
	})
	local card = UiKit.card(window.list, 1, "📦")
	card.action.Visible = false
	local amountTitle = UiKit.text(window.list, "Silinecek miktar", "Caption", UiKit.Color.TextMuted)
	amountTitle.LayoutOrder = 2

	-- Miktar seçici: - | yazı kutusu | +
	local stepper = Instance.new("Frame")
	stepper.Name = "AmountStepper"
	stepper.BackgroundTransparency = 1
	stepper.Size = UDim2.new(1, 0, 0, UiKit.TouchTarget)
	stepper.LayoutOrder = 3
	stepper.Parent = window.list
	UiKit.list(stepper, 6, true)
	local minus = UiKit.button(stepper, "-", "secondary")
	minus.Size = UDim2.fromOffset(UiKit.TouchTarget, UiKit.TouchTarget)
	minus.LayoutOrder = 1
	local input = UiKit.textInput(stepper, "Adet")
	input.Size = UDim2.new(1, -(UiKit.TouchTarget * 2 + 12), 0, UiKit.TouchTarget)
	input.LayoutOrder = 2
	input.TextXAlignment = Enum.TextXAlignment.Center
	local plus = UiKit.button(stepper, "+", "secondary")
	plus.Size = UDim2.fromOffset(UiKit.TouchTarget, UiKit.TouchTarget)
	plus.LayoutOrder = 3

	local quickRow = UiKit.actionRow(window.list, 4, 4, 86)
	local quickButtons: { [string]: TextButton } = {
		one = UiKit.actionButton(quickRow, 1, "1", "secondary"),
		ten = UiKit.actionButton(quickRow, 2, "10", "secondary"),
		half = UiKit.actionButton(quickRow, 3, "Yarısı", "secondary"),
		all = UiKit.actionButton(quickRow, 4, "Hepsi", "secondary"),
	}

	local summary = UiKit.text(window.list, "", "Body")
	summary.LayoutOrder = 5
	local warning = UiKit.text(window.list, GoodsDiscardPrompt.WARNING, "Body", UiKit.Color.Red)
	warning.LayoutOrder = 6
	local confirm = UiKit.button(window.list, "Kalıcı olarak sil", "danger")
	confirm.Size = UDim2.new(1, 0, 0, UiKit.TouchTarget)
	confirm.LayoutOrder = 7
	local cancel = UiKit.button(window.list, "Vazgeç", "secondary")
	cancel.Size = UDim2.new(1, 0, 0, UiKit.TouchTarget)
	cancel.LayoutOrder = 8

	local goodId: string? = nil
	local amount = 1
	local lastState: any = nil
	local lastInputText = ""

	local function available(): number
		if not goodId or not lastState then
			return 0
		end
		return FarmMath.getGoodsAmount(lastState, goodId)
	end

	local function render()
		local id = goodId
		if not id then
			return
		end
		local have = available()
		if have < 1 then
			-- Ürün satıldı/harcandı/silindi: onaylanacak bir şey kalmadı
			goodId = nil
			window.close()
			return
		end
		amount = GoodsDiscard.clamp(amount, have)
		local good = Config.GOODS[id]
		card.icon.Text = good.icon
		UiKit.setText(card.title, good.displayName)
		UiKit.setText(card.detail, `Depoda: {have} adet`)
		local text = tostring(amount)
		if text ~= lastInputText then
			lastInputText = text
			input.Text = text
		end
		UiKit.setText(summary, `{amount} adet silinecek · Kalan: {have - amount} adet`)
		local valid = GoodsDiscard.validAmount(amount, have) ~= nil
		UiKit.setVariant(minus, if amount > 1 then "secondary" else "disabled")
		UiKit.setVariant(plus, if amount < have then "secondary" else "disabled")
		HudCommon.setPurchaseButton(
			confirm,
			if valid then "Kalıcı olarak sil" else "Miktar seç",
			if valid then "danger" else "disabled"
		)
	end

	local function setAmount(value: number)
		amount = GoodsDiscard.clamp(value, available())
		render()
	end
	-- Yazılan değer kutudan okunur (odak kaybı beklenmeden); okunamazsa seçili miktar korunur.
	local function commitInput()
		local parsed = GoodsDiscard.parseText(input.Text, available())
		if parsed then
			amount = parsed
		end
		lastInputText = "" -- okunamayan/sıkıştırılan yazı kutuda geçerli miktarla değiştirilir
		render()
	end

	minus.Activated:Connect(function()
		if minus.Active then
			commitInput()
			setAmount(amount - 1)
		end
	end)
	plus.Activated:Connect(function()
		if plus.Active then
			commitInput()
			setAmount(amount + 1)
		end
	end)
	for kind, button in quickButtons do
		button.Activated:Connect(function()
			setAmount(GoodsDiscard.quick(kind, available()))
		end)
	end
	input.FocusLost:Connect(commitInput)
	cancel.Activated:Connect(function()
		goodId = nil
		window.close()
	end)
	confirm.Activated:Connect(function()
		local id = goodId
		if not id or not confirm.Active then
			return
		end
		commitInput()
		local have = available()
		local count = GoodsDiscard.validAmount(amount, have)
		if not count then
			return
		end
		if PurchaseController.submit("RequestDiscardGoods", id, count) then
			goodId = nil
			window.close()
		end
	end)

	local pendingConnection = PurchaseController.Changed:Connect(function()
		if window.isOpen() then
			render()
		end
	end)
	local visibleConnection = window.frame:GetPropertyChangedSignal("Visible"):Connect(function()
		if window.isOpen() then
			render()
		else
			goodId = nil -- ESC/X ile kapanınca seçim unutulur; bir sonraki açılış her zaman 1 adetle başlar
		end
	end)
	window.frame.Destroying:Connect(function()
		pendingConnection:Disconnect()
		visibleConnection:Disconnect()
		goodId = nil
	end)

	return {
		window = window,
		open = function(id: string, state: any)
			if not Config.GOODS[id] or not state or FarmMath.getGoodsAmount(state, id) < 1 then
				return
			end
			goodId = id
			lastState = state
			amount = 1
			lastInputText = ""
			UiKit.showWindow(window)
			render()
		end,
		update = function(state: any)
			lastState = state
			if goodId and window.isOpen() then
				render()
			end
		end,
	}
end

return GoodsDiscardPrompt
