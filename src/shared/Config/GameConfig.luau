--!strict
--[[
	Global tuning knobs. Content (weapons, relics, zones, ranks, products) lives in its own
	config modules; this file holds the rules that tie them together.
]]

local GameConfig = {
	Roll = {
		-- Seconds between rolls before speed bonuses.
		BaseCooldown = 1.0,
		-- Hard floor no matter how much speed is stacked.
		MinCooldown = 0.3,
		-- Latency forgiveness when the server checks the cooldown.
		CooldownTolerance = 0.12,
		-- Client reveal animation lengths (seconds). Kept below the cooldown they pair with.
		RevealDuration = 0.85,
		QuickRevealDuration = 0.45,
	},

	-- Every Nth roll is a "Blessed Roll" with multiplied luck.
	BonusRoll = {
		Every = 10,
		LuckMultiplier = 2,
	},

	-- Bad-luck protection. If a player goes `rolls` rolls without a result at or above
	-- `rarity`, the next roll is upgraded to a random item of that rarity or better from the
	-- current zone (weighted by 1/N, so rarer items stay rarer).
	Pity = {
		{ rarity = "Rare", rolls = 150 },
		{ rarity = "Epic", rolls = 1_500 },
		{ rarity = "Legendary", rolls = 20_000 },
	},

	Relics = {
		-- Relic checks use luck ^ LuckExponent.
		LuckExponent = 0.5,
		-- Duplicate relics are melted down for this multiple of a same-odds weapon's value.
		DuplicateValueMultiplier = 2,
	},

	Inventory = {
		-- Total weapon copies (sum of stacks) before duplicates are auto-sold.
		BaseCapacity = 300,
		-- Duplicates at or above this rarity are never auto-sold for lack of space.
		ProtectedRarity = "Legendary",
		-- Highest rarity index a player may pick for auto-sell (4 = Epic).
		MaxAutoSellRarity = 4,
	},

	Economy = {
		-- Sell value = floor(N ^ SellExponent * zone gold multiplier * player gold multiplier).
		SellExponent = 0.75,
	},

	Oath = {
		-- Each Oath multiplies luck by (1 + LuckPerOath * oaths).
		LuckPerOath = 0.5,
		-- Rank-up gold costs scale by (1 + GoldCostScalePerOath * oaths).
		GoldCostScalePerOath = 0.5,
	},

	Announcements = {
		-- Rolls at or above this "1 in N" are announced to the whole server.
		ServerMinChance = 10_000,
		-- Rolls at or above this are broadcast to every server via MessagingService.
		GlobalMinChance = 250_000,
		Topic = "RollaWeapon_RareRolls",
	},

	Zones = {
		-- Seconds between server position checks.
		DetectInterval = 0.25,
		-- Seconds a player may stand inside a locked zone before being sent back.
		LockedGraceSeconds = 1.5,
	},

	Map = {
		-- Build a placeholder world when the place has no parts tagged "Zone". Tag your own zone
		-- volumes (with a ZoneId attribute) and the placeholder is skipped automatically.
		BuildPlaceholder = true,
		-- While building the placeholder, remove the default "Baseplate" and disable other
		-- SpawnLocations so players start on the zone islands.
		ReplaceTemplateWorld = true,
	},

	DataStore = {
		Name = "PlayerData_v1",
		PurchaseIdCacheSize = 100,
	},

	Debug = {
		-- In Studio only: pretend the player owns every gamepass.
		GrantAllPassesInStudio = false,
		-- In Studio only: use ProfileStore.Mock so play-tests never write real saves.
		-- (ProfileStore already uses mock data when Studio API access is disabled.)
		UseMockDataInStudio = false,
	},
}

return table.freeze(GameConfig)
