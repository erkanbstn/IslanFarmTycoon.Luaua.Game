--!strict
-- Renk, yazı tipi, boyut ve yarıçap sabitleri (Color/Font/TextSize dünyadaki tabelalarla ortak: shared/UiTheme).
-- UiKit cephesi bunları birleştirir; bileşenleri `UiKit.<ad>` ile kullan.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UiTheme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UiTheme"))

local Tokens = {}

-- Renk, yazı tipi ve boyutlar dünyadaki tabelalarla ortak: shared/UiTheme
Tokens.Color = UiTheme.Color

Tokens.Font = UiTheme.Font

-- Arayüz (HUD, pencereler, yönetici paneli) yazıları dünyadaki tabelalardan (UiTheme.TextSize) biraz büyüktür: okunabilirlik.
-- Tabela boyutları değişmez; ekran arayüzü yalnızca buradaki değerleri kullanır (Body/Caption +2, diğerleri +1 px).
Tokens.TextSize = {
	Display = UiTheme.TextSize.Display + 1,
	Title = UiTheme.TextSize.Title + 1,
	Heading = UiTheme.TextSize.Heading + 1,
	Body = UiTheme.TextSize.Body + 2,
	Caption = UiTheme.TextSize.Caption + 2,
	Button = UiTheme.TextSize.Body + 1, -- düğme ve sekme yazısı (Body'den bir küçük)
	LoadingTitle = UiTheme.TextSize.LoadingTitle,
	LoadingStatus = UiTheme.TextSize.LoadingStatus,
}

Tokens.Radius = {
	Panel = 14,
	Card = 10,
	Button = 8,
}

-- Okunabilirlik ve dokunma alt sınırları (telefon): kendi küçük değerini yazma
Tokens.MinTextSize = 12
Tokens.TouchTarget = 44

-- Menü karosu boyutu (HUD üst menü çubuğu ve sağ menü sütunu aynı ölçüyü kullanır)
Tokens.MenuTileSize = Vector2.new(76, 60)

return Tokens
