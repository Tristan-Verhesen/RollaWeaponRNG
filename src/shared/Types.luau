--!strict
--[[
	Shared type definitions.

	Everything that crosses a boundary (config -> logic, server -> client, profile -> DataStore)
	is typed here so the whole codebase agrees on one shape.
]]

-- Additive bonuses. 0.10 means +10%.
export type Bonus = {
	luck: number?,
	gold: number?,
	speed: number?,
}

export type CutsceneKind = "None" | "Minor" | "Major" | "Epic"

export type RarityDef = {
	id: string,
	name: string,
	-- Smallest "1 in N" value that belongs to this tier.
	minChance: number,
	color: Color3,
	-- Default luck bonus a weapon of this tier grants while equipped.
	equipLuck: number,
	cutscene: CutsceneKind,
}

export type WeaponKind =
	"Sword"
	| "Greatsword"
	| "Dagger"
	| "Axe"
	| "Mace"
	| "Hammer"
	| "Flail"
	| "Club"
	| "Spear"
	| "Halberd"
	| "Pitchfork"
	| "Scythe"
	| "Sickle"
	| "Staff"
	| "Bow"
	| "Crossbow"

export type WeaponDef = {
	id: string,
	name: string,
	zone: string,
	-- Rolled as "1 in chance".
	chance: number,
	kind: WeaponKind,
	description: string,
	-- Overrides the rarity's default equip bonus.
	bonus: Bonus?,
	-- Head/blade color for the procedural model. Defaults to steel.
	tint: Color3?,
}

export type RelicDef = {
	id: string,
	name: string,
	zone: string,
	chance: number,
	description: string,
	bonus: Bonus,
}

export type ZoneDef = {
	id: string,
	name: string,
	subtitle: string,
	order: number,
	-- Rank index required to pass the zone gate.
	requiredRank: number,
	-- Additive luck while rolling in this zone.
	luckBonus: number,
	-- Multiplies the sell value of weapons that come from this zone.
	goldMultiplier: number,
	-- Granted permanently once every relic of the zone has been found.
	setBonus: Bonus,
	groundColor: Color3,
	accentColor: Color3,
}

export type RankDef = {
	id: string,
	name: string,
	rollsRequired: number,
	goldCost: number,
	-- Absolute (not cumulative) additive luck bonus while at this rank.
	luckBonus: number,
	relicSlots: number,
}

export type GamePassKey = "LuckyBlessing" | "AutoRoll" | "QuickRoll" | "RoyalArmory"

export type GamePassDef = {
	key: GamePassKey,
	id: number,
	name: string,
	description: string,
}

export type PotionDef = {
	id: string,
	name: string,
	description: string,
	-- Seconds of effect per potion drunk. Drinking more extends the timer.
	duration: number,
	luckMultiplier: number?,
	speedBonus: number?,
	productId: number,
	color: Color3,
}

export type PlayerSettings = {
	-- Duplicates of this rarity index or lower are sold automatically (0 = off).
	AutoSellMaxRarity: number,
}

export type PlayerLifetimeStats = {
	GoldEarned: number,
	RelicsFound: number,
	PlaySeconds: number,
}

-- Persisted profile data. Keep it JSON-safe: no Instances, no Color3, no mixed tables.
export type PlayerData = {
	Gold: number,
	TotalRolls: number,
	RollsThisOath: number,
	Rank: number,
	Oaths: number,
	Weapons: { [string]: number },
	Discovered: { [string]: boolean },
	Relics: { [string]: number },
	EquippedWeapon: string,
	EquippedRelics: { string },
	Potions: { [string]: number },
	-- Remaining seconds per potion id. Only ticks down while the player is online.
	ActiveBoosts: { [string]: number },
	-- Rolls since the last result at or above each pity rarity.
	Pity: { [string]: number },
	BonusRollCounter: number,
	UnlockedZones: { [string]: boolean },
	BestRollId: string,
	BestRollChance: number,
	Settings: PlayerSettings,
	Stats: PlayerLifetimeStats,
	PurchaseIdCache: { string },
}

export type LuckPart = {
	label: string,
	kind: "add" | "mult",
	value: number,
}

export type ComputedStats = {
	luck: number,
	luckParts: { LuckPart },
	cooldown: number,
	speed: number,
	goldMultiplier: number,
	capacity: number,
	relicSlots: number,
}

export type PassOwnership = { [string]: boolean }

-- What the client is allowed to see about its own player.
export type Snapshot = {
	data: PlayerData,
	stats: ComputedStats,
	zone: string,
	passes: PassOwnership,
}

export type RollResult = {
	weaponId: string,
	chance: number,
	rarity: string,
	isNew: boolean,
	isBonusRoll: boolean,
	-- Rarity id that pity forced, if any.
	pityRarity: string?,
	luck: number,
	autoSold: boolean,
	goldGained: number,
	relicId: string?,
	relicIsNew: boolean,
	rollsUntilBonus: number,
}

export type RollResponse = {
	ok: boolean,
	result: RollResult?,
	reason: string?,
	-- Seconds until the next roll is accepted.
	cooldown: number,
}

export type ActionResponse = {
	ok: boolean,
	message: string?,
}

export type Announcement = {
	playerName: string,
	weaponId: string,
	chance: number,
	global: boolean,
}

export type NotifyKind = "info" | "success" | "warning" | "error"

-- Random source returning a float in [0, 1). Injected so logic is deterministic in tests.
export type Rng = () -> number

return nil
