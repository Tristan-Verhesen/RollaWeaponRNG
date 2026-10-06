--!strict
--[[
	Relics: a second, independent drop that can accompany any weapon roll.

	Every roll in a zone gets one extra "relic check" against that zone's relics, using
	luck ^ GameConfig.Relics.LuckExponent so heavy luck stacking does not make relics trivial.
	Equipped relics grant their bonus; finding all four relics of a zone grants the zone's
	set bonus permanently (see Zones).
]]

local Types = require(script.Parent.Parent.Types)

type RelicDef = Types.RelicDef

local List: { RelicDef } = {
	-- Hamlet Outskirts
	{
		id = "hamlet_horseshoe",
		name = "Lucky Horseshoe",
		zone = "Hamlet",
		chance = 40,
		description = "Nailed above the tavern door for a century.",
		bonus = { luck = 0.05 },
	},
	{
		id = "hamlet_corn_doll",
		name = "Harvest Corn Doll",
		zone = "Hamlet",
		chance = 250,
		description = "Woven from the last sheaf of the harvest.",
		bonus = { gold = 0.10 },
	},
	{
		id = "hamlet_chapel_bell",
		name = "Cracked Chapel Bell",
		zone = "Hamlet",
		chance = 1_500,
		description = "It still rings, a little faster each time.",
		bonus = { speed = 0.05 },
	},
	{
		id = "hamlet_charter",
		name = "Village Charter",
		zone = "Hamlet",
		chance = 12_000,
		description = "Signed by a king, granting rights no lord dares revoke.",
		bonus = { luck = 0.15 },
	},

	-- Darkwood Forest
	{
		id = "darkwood_wolf_necklace",
		name = "Wolf-Tooth Necklace",
		zone = "Darkwood",
		chance = 60,
		description = "Each tooth a trophy from a different pack.",
		bonus = { speed = 0.04 },
	},
	{
		id = "darkwood_mistletoe",
		name = "Sprig of Mistletoe",
		zone = "Darkwood",
		chance = 350,
		description = "Cut with a golden sickle on the sixth night of the moon.",
		bonus = { luck = 0.08 },
	},
	{
		id = "darkwood_hunters_horn",
		name = "Hunter's Horn",
		zone = "Darkwood",
		chance = 2_000,
		description = "Its call brings game, and gold, to the hunter.",
		bonus = { gold = 0.15 },
	},
	{
		id = "darkwood_eternal_acorn",
		name = "The Eternal Acorn",
		zone = "Darkwood",
		chance = 15_000,
		description = "The first seed of the first oak.",
		bonus = { luck = 0.20 },
	},

	-- Barrow Crypts
	{
		id = "crypt_grave_candle",
		name = "Grave Candle",
		zone = "Crypts",
		chance = 80,
		description = "Never burns down. Never goes out.",
		bonus = { luck = 0.06 },
	},
	{
		id = "crypt_bone_dice",
		name = "Bone Dice",
		zone = "Crypts",
		chance = 450,
		description = "Carved from a gambler who never lost.",
		bonus = { luck = 0.10 },
	},
	{
		id = "crypt_reliquary",
		name = "Saint's Reliquary",
		zone = "Crypts",
		chance = 3_000,
		description = "Pilgrims paid fortunes just to see it.",
		bonus = { gold = 0.20 },
	},
	{
		id = "crypt_death_mask",
		name = "Barrow-King's Death Mask",
		zone = "Crypts",
		chance = 20_000,
		description = "Gold, and still warm.",
		bonus = { speed = 0.10 },
	},

	-- Dragonspine Peaks
	{
		id = "peaks_dragon_scale",
		name = "Shed Dragon Scale",
		zone = "Dragonspine",
		chance = 100,
		description = "Big as a shield and twice as hard.",
		bonus = { gold = 0.10 },
	},
	{
		id = "peaks_everburning_ember",
		name = "Everburning Ember",
		zone = "Dragonspine",
		chance = 600,
		description = "A coal from a dragon's hearth. It does not cool.",
		bonus = { speed = 0.06 },
	},
	{
		id = "peaks_wyrm_eye",
		name = "Wyrm's Eye Gem",
		zone = "Dragonspine",
		chance = 4_000,
		description = "It sees treasure through stone.",
		bonus = { luck = 0.15 },
	},
	{
		id = "peaks_dragon_egg",
		name = "Petrified Dragon Egg",
		zone = "Dragonspine",
		chance = 30_000,
		description = "Something inside is still waiting.",
		bonus = { luck = 0.25 },
	},

	-- The Fallen Citadel
	{
		id = "citadel_signet",
		name = "Knight's Signet Ring",
		zone = "Citadel",
		chance = 120,
		description = "Pressed into the wax of a hundred oaths.",
		bonus = { luck = 0.08 },
	},
	{
		id = "citadel_banner",
		name = "Tattered Royal Banner",
		zone = "Citadel",
		chance = 800,
		description = "It flew over the last stand. It will fly again.",
		bonus = { gold = 0.25 },
	},
	{
		id = "citadel_round_table",
		name = "Shard of the Round Table",
		zone = "Citadel",
		chance = 6_000,
		description = "Where no knight sat above another.",
		bonus = { speed = 0.10 },
	},
	{
		id = "citadel_holy_grail",
		name = "The Holy Grail",
		zone = "Citadel",
		chance = 50_000,
		description = "Many knights sought it. You found it.",
		bonus = { luck = 0.40 },
	},
}

local ById: { [string]: RelicDef } = {}
local ByZone: { [string]: { RelicDef } } = {}

for _, relic in List do
	assert(ById[relic.id] == nil, `Duplicate relic id {relic.id}`)
	ById[relic.id] = relic
	local pool = ByZone[relic.zone]
	if pool == nil then
		pool = {}
		ByZone[relic.zone] = pool
	end
	table.insert(pool, relic)
end

for _, pool in ByZone do
	table.sort(pool, function(a, b)
		return a.chance > b.chance
	end)
end

local Relics = {
	List = List,
	ById = ById,
	ByZone = ByZone,
}

return table.freeze(Relics)
