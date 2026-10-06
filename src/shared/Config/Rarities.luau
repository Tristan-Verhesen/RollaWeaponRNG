--!strict
--[[
	Rarity tiers. A weapon's tier is derived from its "1 in N" chance, so retuning a weapon's
	odds automatically moves it to the right tier, color and cutscene.

	List is ordered from most common to rarest; a rarity's index is its "rank" for comparisons
	(auto-sell thresholds, pity rules, cutscene selection).
]]

local Types = require(script.Parent.Parent.Types)

type RarityDef = Types.RarityDef

local List: { RarityDef } = {
	{
		id = "Common",
		name = "Common",
		minChance = 1,
		color = Color3.fromRGB(168, 160, 150),
		equipLuck = 0,
		cutscene = "None",
	},
	{
		id = "Uncommon",
		name = "Uncommon",
		minChance = 10,
		color = Color3.fromRGB(112, 178, 92),
		equipLuck = 0.02,
		cutscene = "None",
	},
	{
		id = "Rare",
		name = "Rare",
		minChance = 100,
		color = Color3.fromRGB(78, 140, 220),
		equipLuck = 0.05,
		cutscene = "None",
	},
	{
		id = "Epic",
		name = "Epic",
		minChance = 1_000,
		color = Color3.fromRGB(164, 96, 220),
		equipLuck = 0.10,
		cutscene = "Minor",
	},
	{
		id = "Legendary",
		name = "Legendary",
		minChance = 10_000,
		color = Color3.fromRGB(240, 176, 40),
		equipLuck = 0.20,
		cutscene = "Major",
	},
	{
		id = "Mythic",
		name = "Mythic",
		minChance = 100_000,
		color = Color3.fromRGB(226, 52, 64),
		equipLuck = 0.35,
		cutscene = "Major",
	},
	{
		id = "Exalted",
		name = "Exalted",
		minChance = 1_000_000,
		color = Color3.fromRGB(255, 244, 196),
		equipLuck = 0.60,
		cutscene = "Epic",
	},
}

local ById: { [string]: RarityDef } = {}
local IndexById: { [string]: number } = {}
for index, rarity in List do
	ById[rarity.id] = rarity
	IndexById[rarity.id] = index
end

local Rarities = {
	List = List,
	ById = ById,
}

-- Returns the tier a "1 in N" chance falls into.
function Rarities.fromChance(chance: number): RarityDef
	local found = List[1]
	for _, rarity in List do
		if chance >= rarity.minChance then
			found = rarity
		else
			break
		end
	end
	return found
end

function Rarities.indexOf(id: string): number
	return IndexById[id] or 0
end

function Rarities.indexFromChance(chance: number): number
	return IndexById[Rarities.fromChance(chance).id]
end

return table.freeze(Rarities)
