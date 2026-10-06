--!strict
--[[
	Visual language: blackened iron panels, gold trim, parchment text, blackletter titles.
]]

local Theme = {
	Colors = {
		Iron = Color3.fromRGB(22, 19, 17),
		IronRaised = Color3.fromRGB(36, 31, 27),
		IronHover = Color3.fromRGB(52, 45, 38),
		Trim = Color3.fromRGB(168, 132, 58),
		Gold = Color3.fromRGB(234, 198, 106),
		Parchment = Color3.fromRGB(240, 230, 206),
		ParchmentDim = Color3.fromRGB(178, 166, 140),
		Muted = Color3.fromRGB(110, 102, 90),
		Crimson = Color3.fromRGB(176, 52, 44),
		Verdant = Color3.fromRGB(94, 156, 76),
		Royal = Color3.fromRGB(70, 92, 168),
		Black = Color3.new(0, 0, 0),
	},
	Fonts = {
		Title = Enum.Font.GrenzeGotisch,
		Body = Enum.Font.Merriweather,
		Flavor = Enum.Font.Fondamento,
	},
	Radius = 6,
}

return table.freeze(Theme)
