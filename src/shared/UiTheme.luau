--!strict
-- Ortak görsel dil: renkler, yazı tipleri, yazı boyutları.
-- Ekran arayüzü (client/UiKit) ve dünyadaki tabelalar (shared/WorldUi) bu tabloları kullanır.

local BUILDER_SANS = "rbxasset://fonts/families/BuilderSans.json"
local FREDOKA = "rbxasset://fonts/families/FredokaOne.json"

local UiTheme = {}

UiTheme.Color = {
	Panel = Color3.fromRGB(24, 26, 32),
	Surface = Color3.fromRGB(40, 43, 52),
	SurfaceRaised = Color3.fromRGB(52, 56, 67),
	Stroke = Color3.fromRGB(255, 255, 255),
	Text = Color3.fromRGB(245, 245, 245),
	TextMuted = Color3.fromRGB(165, 171, 184),
	Cream = Color3.fromRGB(255, 244, 222),
	Gold = Color3.fromRGB(255, 200, 70),
	Green = Color3.fromRGB(62, 180, 96),
	GreenDark = Color3.fromRGB(44, 100, 62),
	Orange = Color3.fromRGB(222, 142, 56),
	Red = Color3.fromRGB(215, 75, 75),
	Blue = Color3.fromRGB(76, 112, 205),
	Disabled = Color3.fromRGB(66, 70, 80),
}

UiTheme.Font = {
	Display = Font.new(FREDOKA),
	Body = Font.new(BUILDER_SANS, Enum.FontWeight.Medium),
	Bold = Font.new(BUILDER_SANS, Enum.FontWeight.Bold),
}

UiTheme.TextSize = {
	Display = 26,
	Title = 20,
	Heading = 16,
	Body = 14,
	Caption = 12,
	LoadingTitle = 40,
	LoadingStatus = 18,
}

return UiTheme
