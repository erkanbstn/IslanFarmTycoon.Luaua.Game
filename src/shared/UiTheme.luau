--!strict
-- Ortak görsel dil: renkler, yazı tipleri, yazı boyutları.
-- Ekran arayüzü (client/UiKit) ve dünyadaki tabelalar (shared/WorldUi) bu tabloları kullanır.

local BUILDER_SANS = "rbxasset://fonts/families/BuilderSans.json"
local FREDOKA = "rbxasset://fonts/families/FredokaOne.json"

local UiTheme = {}

UiTheme.Color = {
	Panel = Color3.fromRGB(26, 34, 66),
	Surface = Color3.fromRGB(40, 56, 104),
	SurfaceRaised = Color3.fromRGB(58, 80, 142),
	Stroke = Color3.fromRGB(190, 215, 255),
	Text = Color3.fromRGB(250, 250, 255),
	TextMuted = Color3.fromRGB(184, 202, 236),
	Cream = Color3.fromRGB(255, 244, 222),
	Gold = Color3.fromRGB(255, 205, 60),
	Green = Color3.fromRGB(48, 196, 104),
	GreenDark = Color3.fromRGB(34, 120, 76),
	Orange = Color3.fromRGB(255, 150, 52),
	Red = Color3.fromRGB(238, 78, 92),
	Blue = Color3.fromRGB(72, 132, 245),
	Disabled = Color3.fromRGB(72, 84, 118),
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
