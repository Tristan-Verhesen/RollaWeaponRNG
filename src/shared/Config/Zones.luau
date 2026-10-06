--!strict
--[[
	Zones. Each zone has its own weapon + relic pool. Players roll from the pool of the zone they
	are standing in (or the last zone they stood in).

	requiredRank is an index into Ranks.List. Once a player reaches it the zone is unlocked
	permanently, including after taking an Oath.
]]

local Types = require(script.Parent.Parent.Types)

type ZoneDef = Types.ZoneDef

local List: { ZoneDef } = {
	{
		id = "Hamlet",
		name = "Hamlet Outskirts",
		subtitle = "Where every legend begins",
		order = 1,
		requiredRank = 1,
		luckBonus = 0,
		goldMultiplier = 1,
		setBonus = { luck = 0.05 },
		groundColor = Color3.fromRGB(96, 128, 64),
		accentColor = Color3.fromRGB(196, 164, 92),
	},
	{
		id = "Darkwood",
		name = "Darkwood Forest",
		subtitle = "The trees remember",
		order = 2,
		requiredRank = 3,
		luckBonus = 0.10,
		goldMultiplier = 1.5,
		setBonus = { speed = 0.05 },
		groundColor = Color3.fromRGB(44, 72, 40),
		accentColor = Color3.fromRGB(92, 140, 76),
	},
	{
		id = "Crypts",
		name = "Barrow Crypts",
		subtitle = "The dead do not rest here",
		order = 3,
		requiredRank = 5,
		luckBonus = 0.20,
		goldMultiplier = 2.5,
		setBonus = { luck = 0.10 },
		groundColor = Color3.fromRGB(58, 56, 62),
		accentColor = Color3.fromRGB(120, 168, 150),
	},
	{
		id = "Dragonspine",
		name = "Dragonspine Peaks",
		subtitle = "Where the sky burns",
		order = 4,
		requiredRank = 7,
		luckBonus = 0.35,
		goldMultiplier = 4,
		setBonus = { gold = 0.25 },
		groundColor = Color3.fromRGB(92, 74, 66),
		accentColor = Color3.fromRGB(232, 104, 44),
	},
	{
		id = "Citadel",
		name = "The Fallen Citadel",
		subtitle = "Glory lies in ruins",
		order = 5,
		requiredRank = 9,
		luckBonus = 0.50,
		goldMultiplier = 6,
		setBonus = { luck = 0.25 },
		groundColor = Color3.fromRGB(150, 142, 128),
		accentColor = Color3.fromRGB(226, 196, 110),
	},
}

table.sort(List, function(a, b)
	return a.order < b.order
end)

local ById: { [string]: ZoneDef } = {}
for _, zone in List do
	ById[zone.id] = zone
end

local Zones = {
	List = List,
	ById = ById,
	Default = List[1].id,
}

return table.freeze(Zones)
