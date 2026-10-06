--!strict
--[[
	Monetization. Every id is 0 until you create the product on the Creator Dashboard.

	A gamepass or product with id 0 is treated as "not configured": ownership checks return false
	and the shop shows it as unavailable. Paste real ids here, no other code changes needed.
	(GameConfig.Debug.GrantAllPassesInStudio lets you test pass perks in Studio.)
]]

local Types = require(script.Parent.Parent.Types)

type GamePassDef = Types.GamePassDef
type PotionDef = Types.PotionDef

local GamePasses: { GamePassDef } = {
	{
		key = "LuckyBlessing",
		id = 0,
		name = "Blessing of Fortune",
		description = "Permanently doubles your luck.",
	},
	{
		key = "AutoRoll",
		id = 0,
		name = "Squire's Diligence",
		description = "Unlocks Auto-Roll. Your squire rolls while you watch.",
	},
	{
		key = "QuickRoll",
		id = 0,
		name = "Swift Hands",
		description = "Rolls 40% faster with a shorter reveal.",
	},
	{
		key = "RoyalArmory",
		id = 0,
		name = "Royal Armory",
		description = "+1,200 armory storage for your collection.",
	},
}

local Potions: { PotionDef } = {
	{
		id = "Fortune",
		name = "Potion of Fortune",
		description = "x2 luck for 10 minutes.",
		duration = 600,
		luckMultiplier = 2,
		productId = 0,
		color = Color3.fromRGB(96, 200, 120),
	},
	{
		id = "KingsElixir",
		name = "Elixir of Kings",
		description = "x3 luck for 5 minutes.",
		duration = 300,
		luckMultiplier = 3,
		productId = 0,
		color = Color3.fromRGB(240, 196, 64),
	},
	{
		id = "Haste",
		name = "Draught of Haste",
		description = "Rolls 35% faster for 10 minutes.",
		duration = 600,
		speedBonus = 0.35,
		productId = 0,
		color = Color3.fromRGB(80, 160, 230),
	},
}

local PassByKey: { [string]: GamePassDef } = {}
for _, pass in GamePasses do
	PassByKey[pass.key] = pass
end

local PotionById: { [string]: PotionDef } = {}
local PotionByProductId: { [number]: PotionDef } = {}
for _, potion in Potions do
	PotionById[potion.id] = potion
	if potion.productId ~= 0 then
		PotionByProductId[potion.productId] = potion
	end
end

local Products = {
	GamePasses = GamePasses,
	PassByKey = PassByKey,
	Potions = Potions,
	PotionById = PotionById,
	PotionByProductId = PotionByProductId,
	-- Luck multiplier granted by owning LuckyBlessing.
	LuckyBlessingMultiplier = 2,
	-- Cooldown multiplier granted by owning QuickRoll.
	QuickRollCooldownMultiplier = 0.6,
	-- Extra armory capacity granted by owning RoyalArmory.
	RoyalArmoryCapacity = 1_200,
}

return table.freeze(Products)
