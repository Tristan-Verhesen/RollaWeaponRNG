--!strict
--[[
	Every rollable weapon, grouped by zone.

	chance   "1 in N". Rarity tier, color and cutscene are derived from it (see Rarities).
	kind     Picks the procedural model used when no custom model exists in
	         ReplicatedStorage.Assets.WeaponModels[<id>].
	bonus    Optional. Overrides the rarity's default equip bonus ({ luck = tier.equipLuck }).
	tint     Optional head/blade color for the procedural model.

	Balancing tip: run `lune run scripts/simulate` after changing odds to see progression pacing.
]]

local Types = require(script.Parent.Parent.Types)

type WeaponDef = Types.WeaponDef

local IRON = Color3.fromRGB(92, 92, 98)
local RUST = Color3.fromRGB(142, 84, 52)
local BRONZE = Color3.fromRGB(176, 124, 64)
local BONE = Color3.fromRGB(222, 212, 184)
local WOOD = Color3.fromRGB(120, 84, 52)
local GOLD = Color3.fromRGB(232, 188, 72)
local SILVER = Color3.fromRGB(214, 220, 228)
local GRAVE = Color3.fromRGB(110, 170, 140)
local EMBER = Color3.fromRGB(236, 96, 36)
local OBSIDIAN = Color3.fromRGB(40, 36, 44)
local VERDANT = Color3.fromRGB(90, 160, 80)
local HOLY = Color3.fromRGB(255, 240, 190)

local List: { WeaponDef } = {
	-- Hamlet Outskirts -------------------------------------------------------------------------
	{
		id = "hamlet_rusty_dagger",
		name = "Rusty Dagger",
		zone = "Hamlet",
		chance = 2,
		kind = "Dagger",
		tint = RUST,
		description = "More tetanus than threat.",
	},
	{
		id = "hamlet_splintered_club",
		name = "Splintered Club",
		zone = "Hamlet",
		chance = 3,
		kind = "Club",
		tint = WOOD,
		description = "A fence post with ambition.",
	},
	{
		id = "hamlet_pitchfork",
		name = "Farmer's Pitchfork",
		zone = "Hamlet",
		chance = 5,
		kind = "Pitchfork",
		tint = IRON,
		description = "The original weapon of every peasant revolt.",
	},
	{
		id = "hamlet_hatchet",
		name = "Woodcutter's Hatchet",
		zone = "Hamlet",
		chance = 9,
		kind = "Axe",
		tint = IRON,
		description = "Splits logs. Occasionally bandits.",
	},
	{
		id = "hamlet_sickle",
		name = "Reaping Sickle",
		zone = "Hamlet",
		chance = 14,
		kind = "Sickle",
		description = "Curved for wheat, sharp enough for worse.",
	},
	{
		id = "hamlet_iron_longsword",
		name = "Iron Longsword",
		zone = "Hamlet",
		chance = 25,
		kind = "Sword",
		description = "Plain, heavy and honest. A squire's first true blade.",
	},
	{
		id = "hamlet_militia_spear",
		name = "Militia Spear",
		zone = "Hamlet",
		chance = 60,
		kind = "Spear",
		description = "Issued to every able villager when the beacons are lit.",
	},
	{
		id = "hamlet_smith_hammer",
		name = "Blacksmith's Hammer",
		zone = "Hamlet",
		chance = 180,
		kind = "Hammer",
		tint = IRON,
		description = "Forged a thousand swords. Broke a few skulls.",
		bonus = { gold = 0.10 },
	},
	{
		id = "hamlet_watch_crossbow",
		name = "Watchman's Crossbow",
		zone = "Hamlet",
		chance = 750,
		kind = "Crossbow",
		description = "The night watch never sleeps, and never misses.",
	},
	{
		id = "hamlet_reeve_mace",
		name = "Reeve's Flanged Mace",
		zone = "Hamlet",
		chance = 3_000,
		kind = "Mace",
		tint = BRONZE,
		description = "Taxes are collected, one way or another.",
	},
	{
		id = "hamlet_harvest_scythe",
		name = "Harvest Moon Scythe",
		zone = "Hamlet",
		chance = 20_000,
		kind = "Scythe",
		tint = SILVER,
		description = "Only rises from the fields under a blood-orange moon.",
	},
	{
		id = "hamlet_kings_peace",
		name = "The King's Peace",
		zone = "Hamlet",
		chance = 150_000,
		kind = "Sword",
		tint = GOLD,
		description = "Lost by a king in a haystack. He never came back for it.",
	},

	-- Darkwood Forest --------------------------------------------------------------------------
	{
		id = "darkwood_thorn_shiv",
		name = "Thorn Shiv",
		zone = "Darkwood",
		chance = 2,
		kind = "Dagger",
		tint = WOOD,
		description = "Snapped from a bramble that bit back.",
	},
	{
		id = "darkwood_hunting_bow",
		name = "Hunter's Shortbow",
		zone = "Darkwood",
		chance = 4,
		kind = "Bow",
		description = "Quiet enough for deer, quick enough for wolves.",
	},
	{
		id = "darkwood_woodsman_axe",
		name = "Woodsman's Axe",
		zone = "Darkwood",
		chance = 7,
		kind = "Axe",
		description = "The forest fears exactly one tool.",
	},
	{
		id = "darkwood_oak_cudgel",
		name = "Oaken Cudgel",
		zone = "Darkwood",
		chance = 12,
		kind = "Club",
		tint = WOOD,
		description = "Carved from a tree that fell on its own.",
	},
	{
		id = "darkwood_boar_spear",
		name = "Boar Spear",
		zone = "Darkwood",
		chance = 30,
		kind = "Spear",
		description = "The crossbar keeps the boar from reaching you. Mostly.",
	},
	{
		id = "darkwood_yew_longbow",
		name = "Yew Longbow",
		zone = "Darkwood",
		chance = 85,
		kind = "Bow",
		description = "Taller than its archer and twice as stubborn.",
	},
	{
		id = "darkwood_outlaw_falchion",
		name = "Outlaw's Falchion",
		zone = "Darkwood",
		chance = 240,
		kind = "Sword",
		description = "Robbed from the rich. Kept by the poor.",
		bonus = { gold = 0.15 },
	},
	{
		id = "darkwood_warden_glaive",
		name = "Warden's Glaive",
		zone = "Darkwood",
		chance = 700,
		kind = "Halberd",
		tint = VERDANT,
		description = "Carried by the rangers who keep the old roads open.",
	},
	{
		id = "darkwood_wolfsbane",
		name = "Wolfsbane Dagger",
		zone = "Darkwood",
		chance = 2_200,
		kind = "Dagger",
		tint = SILVER,
		description = "Silver edge, poisoned groove. Werewolves need not apply.",
	},
	{
		id = "darkwood_grove_staff",
		name = "Staff of the Old Grove",
		zone = "Darkwood",
		chance = 9_000,
		kind = "Staff",
		tint = VERDANT,
		description = "Still growing leaves, centuries after it was cut.",
		bonus = { speed = 0.10 },
	},
	{
		id = "darkwood_green_knight",
		name = "Green Knight's Axe",
		zone = "Darkwood",
		chance = 45_000,
		kind = "Axe",
		tint = VERDANT,
		description = "Strike once, and in a year and a day it strikes back.",
	},
	{
		id = "darkwood_heartwood_bow",
		name = "Heartwood Warbow",
		zone = "Darkwood",
		chance = 350_000,
		kind = "Bow",
		tint = GOLD,
		description = "Strung with a dryad's hair. Its arrows never fall.",
	},

	-- Barrow Crypts ----------------------------------------------------------------------------
	{
		id = "crypt_femur_club",
		name = "Femur Club",
		zone = "Crypts",
		chance = 2,
		kind = "Club",
		tint = BONE,
		description = "Its previous owner is not using it anymore.",
	},
	{
		id = "crypt_robber_dirk",
		name = "Tomb Robber's Dirk",
		zone = "Crypts",
		chance = 4,
		kind = "Dagger",
		tint = IRON,
		description = "Pries open coffins. And ribcages.",
	},
	{
		id = "crypt_chain_flail",
		name = "Rusted Chain Flail",
		zone = "Crypts",
		chance = 7,
		kind = "Flail",
		tint = RUST,
		description = "Rattles like the dead in their sleep.",
	},
	{
		id = "crypt_barrow_blade",
		name = "Barrow Blade",
		zone = "Crypts",
		chance = 18,
		kind = "Sword",
		tint = BRONZE,
		description = "Pulled from a cairn. The cairn was not happy.",
	},
	{
		id = "crypt_bone_flail",
		name = "Bone Flail",
		zone = "Crypts",
		chance = 50,
		kind = "Flail",
		tint = BONE,
		description = "Three skulls on a chain. They still chatter.",
	},
	{
		id = "crypt_cursed_seax",
		name = "Cursed Seax",
		zone = "Crypts",
		chance = 150,
		kind = "Dagger",
		tint = GRAVE,
		description = "Whispers the names of everyone it has cut.",
	},
	{
		id = "crypt_deathwatch_halberd",
		name = "Deathwatch Halberd",
		zone = "Crypts",
		chance = 500,
		kind = "Halberd",
		tint = OBSIDIAN,
		description = "Its guardians stood watch for four hundred years.",
	},
	{
		id = "crypt_lich_staff",
		name = "Lich-King's Staff",
		zone = "Crypts",
		chance = 1_800,
		kind = "Staff",
		tint = GRAVE,
		description = "Cold to the touch. Colder to the soul.",
		bonus = { luck = 0.08, speed = 0.05 },
	},
	{
		id = "crypt_soulreaper",
		name = "Soulreaper Scythe",
		zone = "Crypts",
		chance = 7_500,
		kind = "Scythe",
		tint = GRAVE,
		description = "Harvests something finer than wheat.",
	},
	{
		id = "crypt_wight_greatsword",
		name = "Barrow-Wight Greatsword",
		zone = "Crypts",
		chance = 30_000,
		kind = "Greatsword",
		tint = OBSIDIAN,
		description = "Too heavy for the living. The wight never minded.",
	},
	{
		id = "crypt_mourneblade",
		name = "Mourneblade",
		zone = "Crypts",
		chance = 200_000,
		kind = "Sword",
		tint = GRAVE,
		description = "Forged at a funeral. Every swing is a eulogy.",
	},
	{
		id = "crypt_ossuary_maul",
		name = "Ossuary Maul of the Bone Tyrant",
		zone = "Crypts",
		chance = 600_000,
		kind = "Hammer",
		tint = BONE,
		description = "Built from the bones of an entire dynasty.",
	},

	-- Dragonspine Peaks ------------------------------------------------------------------------
	{
		id = "peaks_flint_axe",
		name = "Flint Hand-Axe",
		zone = "Dragonspine",
		chance = 2,
		kind = "Axe",
		tint = OBSIDIAN,
		description = "Knapped on the mountainside. Older than kingdoms.",
	},
	{
		id = "peaks_mountain_pick",
		name = "Mountaineer's Pick",
		zone = "Dragonspine",
		chance = 4,
		kind = "Hammer",
		description = "For climbing ice, and for anything that climbs after you.",
	},
	{
		id = "peaks_goatherd_crook",
		name = "Goatherd's Crook",
		zone = "Dragonspine",
		chance = 7,
		kind = "Staff",
		tint = WOOD,
		description = "The goats up here are terrifying.",
	},
	{
		id = "peaks_scaled_mace",
		name = "Scale-Studded Mace",
		zone = "Dragonspine",
		chance = 20,
		kind = "Mace",
		tint = EMBER,
		description = "Studded with shed dragon scales. Still warm.",
	},
	{
		id = "peaks_drakebane_spear",
		name = "Drakebane Spear",
		zone = "Dragonspine",
		chance = 60,
		kind = "Spear",
		description = "Long enough to reach a drake's heart. Barely.",
	},
	{
		id = "peaks_ember_falchion",
		name = "Emberforged Falchion",
		zone = "Dragonspine",
		chance = 180,
		kind = "Sword",
		tint = EMBER,
		description = "Quenched in dragonfire instead of water.",
	},
	{
		id = "peaks_wyvern_arbalest",
		name = "Wyvern-Hunter's Arbalest",
		zone = "Dragonspine",
		chance = 650,
		kind = "Crossbow",
		tint = OBSIDIAN,
		description = "Winds with a crank. Fires through wyvern hide.",
	},
	{
		id = "peaks_cinderheart",
		name = "Cinderheart Greatsword",
		zone = "Dragonspine",
		chance = 2_800,
		kind = "Greatsword",
		tint = EMBER,
		description = "The blade glows brighter when dragons are near.",
	},
	{
		id = "peaks_dragon_tooth",
		name = "Dragon-Tooth Dagger",
		zone = "Dragonspine",
		chance = 11_000,
		kind = "Dagger",
		tint = BONE,
		description = "A single tooth. The dragon has others.",
		bonus = { luck = 0.15, gold = 0.15 },
	},
	{
		id = "peaks_wyrmslayer",
		name = "Wyrmslayer Halberd",
		zone = "Dragonspine",
		chance = 60_000,
		kind = "Halberd",
		tint = SILVER,
		description = "Carried by the last of the dragon-knights.",
	},
	{
		id = "peaks_elder_fang",
		name = "Fang of the Elder Wyrm",
		zone = "Dragonspine",
		chance = 250_000,
		kind = "Sword",
		tint = EMBER,
		description = "Torn from the jaw of the oldest dragon alive.",
	},
	{
		id = "peaks_skyfire",
		name = "Skyfire, the Wyrm's Bane",
		zone = "Dragonspine",
		chance = 750_000,
		kind = "Spear",
		tint = GOLD,
		description = "Thrown once from the highest peak. It never landed.",
	},

	-- The Fallen Citadel -----------------------------------------------------------------------
	{
		id = "citadel_broken_sword",
		name = "Broken Guardsman's Sword",
		zone = "Citadel",
		chance = 2,
		kind = "Sword",
		tint = IRON,
		description = "The guardsman held the gate. The sword did not.",
	},
	{
		id = "citadel_pike",
		name = "Citadel Pike",
		zone = "Citadel",
		chance = 3,
		kind = "Spear",
		description = "Once one of ten thousand. Now one of few.",
	},
	{
		id = "citadel_morningstar",
		name = "Morningstar",
		zone = "Citadel",
		chance = 6,
		kind = "Flail",
		description = "Rises early. Hits hard.",
	},
	{
		id = "citadel_lucerne",
		name = "Lucerne Hammer",
		zone = "Citadel",
		chance = 15,
		kind = "Halberd",
		description = "A can-opener for knights in plate.",
	},
	{
		id = "citadel_crusader_sword",
		name = "Crusader's Sword",
		zone = "Citadel",
		chance = 45,
		kind = "Sword",
		description = "Cross-hilted and battle-notched.",
	},
	{
		id = "citadel_arming_sword",
		name = "Knight's Arming Sword",
		zone = "Citadel",
		chance = 400,
		kind = "Sword",
		tint = SILVER,
		description = "Given at the knighting. Carried until death.",
	},
	{
		id = "citadel_paladin_maul",
		name = "Paladin's Maul",
		zone = "Citadel",
		chance = 1_500,
		kind = "Hammer",
		tint = GOLD,
		description = "Blessed by seven bishops. Feared by seven armies.",
	},
	{
		id = "citadel_oathkeeper",
		name = "Oathkeeper",
		zone = "Citadel",
		chance = 12_000,
		kind = "Sword",
		tint = SILVER,
		description = "Breaks in the hand of anyone who breaks their word.",
		bonus = { luck = 0.25 },
	},
	{
		id = "citadel_durendal",
		name = "Durendal",
		zone = "Citadel",
		chance = 80_000,
		kind = "Sword",
		tint = SILVER,
		description = "Roland could not break it against the mountain. Nor could the mountain.",
	},
	{
		id = "citadel_ascalon",
		name = "Ascalon, the Dragon's Doom",
		zone = "Citadel",
		chance = 250_000,
		kind = "Spear",
		tint = HOLY,
		description = "The lance that ended the last great wyrm.",
	},
	{
		id = "citadel_curtana",
		name = "Curtana, the Sword of Mercy",
		zone = "Citadel",
		chance = 500_000,
		kind = "Sword",
		tint = HOLY,
		description = "Its tip was broken off so that it could never kill. It rules instead.",
	},
	{
		id = "citadel_excalibur",
		name = "Excalibur",
		zone = "Citadel",
		chance = 1_000_000,
		kind = "Sword",
		tint = HOLY,
		description = "Drawn from the stone by the one true king. Today, that may be you.",
	},
}

local ById: { [string]: WeaponDef } = {}
local ByZone: { [string]: { WeaponDef } } = {}

for _, weapon in List do
	assert(ById[weapon.id] == nil, `Duplicate weapon id {weapon.id}`)
	ById[weapon.id] = weapon
	local pool = ByZone[weapon.zone]
	if pool == nil then
		pool = {}
		ByZone[weapon.zone] = pool
	end
	table.insert(pool, weapon)
end

-- Rarest first: this is the order the roll cascade walks.
for _, pool in ByZone do
	table.sort(pool, function(a, b)
		return a.chance > b.chance
	end)
end

local Weapons = {
	List = List,
	ById = ById,
	ByZone = ByZone,
}

return table.freeze(Weapons)
