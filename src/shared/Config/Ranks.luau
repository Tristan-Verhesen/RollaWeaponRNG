--!strict
--[[
	The chivalric ladder. Rising a rank requires rolls made since your last Oath and costs gold.

	luckBonus   Absolute additive luck at this rank (King = +100%), not cumulative.
	relicSlots  How many relics can be equipped at this rank.

	At the final rank a player may swear an Oath: rank, gold and rolls-this-oath reset, and they
	gain a permanent luck multiplier (GameConfig.Oath). Zones and the collection are kept.
]]

local Types = require(script.Parent.Parent.Types)

type RankDef = Types.RankDef

local List: { RankDef } = {
	{ id = "Peasant", name = "Peasant", rollsRequired = 0, goldCost = 0, luckBonus = 0, relicSlots = 1 },
	{ id = "Serf", name = "Serf", rollsRequired = 25, goldCost = 40, luckBonus = 0.05, relicSlots = 1 },
	{ id = "Squire", name = "Squire", rollsRequired = 120, goldCost = 250, luckBonus = 0.10, relicSlots = 2 },
	{ id = "ManAtArms", name = "Man-at-Arms", rollsRequired = 400, goldCost = 1_200, luckBonus = 0.15, relicSlots = 2 },
	{ id = "Knight", name = "Knight", rollsRequired = 1_000, goldCost = 4_000, luckBonus = 0.25, relicSlots = 3 },
	{
		id = "KnightBanneret",
		name = "Knight-Banneret",
		rollsRequired = 2_200,
		goldCost = 12_000,
		luckBonus = 0.35,
		relicSlots = 3,
	},
	{ id = "Baron", name = "Baron", rollsRequired = 4_000, goldCost = 30_000, luckBonus = 0.50, relicSlots = 4 },
	{ id = "Earl", name = "Earl", rollsRequired = 7_000, goldCost = 75_000, luckBonus = 0.65, relicSlots = 4 },
	{ id = "Duke", name = "Duke", rollsRequired = 11_000, goldCost = 160_000, luckBonus = 0.80, relicSlots = 5 },
	{ id = "King", name = "King", rollsRequired = 16_000, goldCost = 350_000, luckBonus = 1.00, relicSlots = 5 },
}

local Ranks = {
	List = List,
	Max = #List,
}

function Ranks.get(index: number): RankDef
	return List[math.clamp(index, 1, #List)]
end

return table.freeze(Ranks)
