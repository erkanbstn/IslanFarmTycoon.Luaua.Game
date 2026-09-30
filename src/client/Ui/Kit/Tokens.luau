--!strict
-- Renk, yazı tipi, boyut ve yarıçap sabitleri (Color/Font/TextSize dünyadaki tabelalarla ortak: shared/UiTheme).
-- UiKit cephesi bunları birleştirir; bileşenleri `UiKit.<ad>` ile kullan.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UiTheme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UiTheme"))

local Tokens = {}

-- Renk, yazı tipi ve boyutlar dünyadaki tabelalarla ortak: shared/UiTheme
Tokens.Color = UiTheme.Color

Tokens.Font = UiTheme.Font

Tokens.TextSize = UiTheme.TextSize

Tokens.Radius = {
	Panel = 14,
	Card = 10,
	Button = 8,
}

-- Menü karosu boyutu (HUD üst menü çubuğu ve sağ menü sütunu aynı ölçüyü kullanır)
Tokens.MenuTileSize = Vector2.new(76, 60)

return Tokens
