--[[
	Balance simulator: plays a scripted player through the real game logic.

	  lune run scripts/simulate                  -- defaults
	  lune run scripts/simulate -- 7 2 LuckyBlessing QuickRoll
	                               ^ ^ ^ gamepasses to own
	                               | +-- oaths to play through (default 1)
	                               +---- rng seed (default 1)

	Strategy each roll: roll in the best unlocked zone. Every 25 rolls: sell duplicates up to
	Epic, equip the luckiest weapon and relics, and rank up when possible. Time assumes
	auto-roll running at the player's exact cooldown.
]]

local process = require("@lune/process")

local Loader = require("../tests/Loader")
local TestKit = require("../tests/TestKit")

local Shared = Loader.root("src/shared")
local DataTemplate = Loader.require(Shared.DataTemplate)
local RollEngine = Loader.require(Shared.Logic.RollEngine)
local Stats = Loader.require(Shared.Logic.Stats)
local Economy = Loader.require(Shared.Logic.Economy)
local Progression = Loader.require(Shared.Logic.Progression)
local Format = Loader.require(Shared.Util.Format)
local Rarities = Loader.require(Shared.Config.Rarities)
local Weapons = Loader.require(Shared.Config.Weapons)
local Relics = Loader.require(Shared.Config.Relics)
local Zones = Loader.require(Shared.Config.Zones)
local Ranks = Loader.require(Shared.Config.Ranks)

local args = {}
for _, arg in process.args do
	if arg ~= "--" then
		table.insert(args, arg)
	end
end

local seed = tonumber(args[1]) or 1
local targetOaths = tonumber(args[2]) or 1
local passes = {}
for index = 3, #args do
	passes[args[index]] = true
end

local MAX_ROLLS = 2_000_000
local rng = TestKit.seededRng(seed)
local data = DataTemplate.new()
local seconds = 0

local function rarityIndexOf(weaponId: string): number
	return Rarities.indexFromChance(Weapons.ById[weaponId].chance)
end

local function bestZone(): string
	local best = Zones.Default
	for _, zone in Zones.List do
		if data.UnlockedZones[zone.id] then
			best = zone.id
		end
	end
	return best
end

local function equipBest()
	local bestWeapon, bestLuck = "", -1
	for weaponId in data.Weapons do
		local bonus = Stats.weaponBonus(weaponId)
		local luck = if bonus then bonus.luck or 0 else 0
		if luck > bestLuck then
			bestWeapon, bestLuck = weaponId, luck
		end
	end
	data.EquippedWeapon = bestWeapon

	local owned = {}
	for relicId in data.Relics do
		table.insert(owned, Relics.ById[relicId])
	end
	table.sort(owned, function(a, b)
		return (a.bonus.luck or 0) > (b.bonus.luck or 0)
	end)
	table.clear(data.EquippedRelics)
	for index = 1, math.min(#owned, Stats.relicSlots(data.Rank)) do
		table.insert(data.EquippedRelics, owned[index].id)
	end
end

local function row(...: string)
	local cells = { ... }
	local widths = { 16, 10, 10, 9, 10, 12 }
	local parts = {}
	for index, cell in cells do
		table.insert(parts, cell .. string.rep(" ", math.max(0, widths[index] - #cell)))
	end
	print(table.concat(parts, " "))
end

local passList = {}
for key in passes do
	table.insert(passList, key)
end
print(`Seed {seed}, oaths {targetOaths}, passes: {if #passList > 0 then table.concat(passList, ", ") else "none"}\n`)
row("Rank", "Rolls", "Played", "Luck", "Zone", "Gold banked")
row("----", "-----", "------", "----", "----", "-----------")

local firstOfRarity: { [string]: number } = {}

while data.TotalRolls < MAX_ROLLS do
	local zoneId = bestZone()
	local stats = Stats.compute(data, zoneId, passes)
	local result = RollEngine.roll(data, {
		zoneId = zoneId,
		luck = stats.luck,
		goldMultiplier = stats.goldMultiplier,
		capacity = stats.capacity,
	}, rng)
	seconds += stats.cooldown
	if firstOfRarity[result.rarity] == nil then
		firstOfRarity[result.rarity] = data.TotalRolls
	end

	if data.TotalRolls % 25 == 0 then
		Economy.sellDuplicates(data, 4, stats.goldMultiplier, rarityIndexOf)
		equipBest()
		while Progression.canRankUp(data) do
			Progression.rankUp(data)
			local rank = Ranks.get(data.Rank)
			local after = Stats.compute(data, bestZone(), passes)
			row(
				(if data.Oaths > 0 then `[O{data.Oaths}] ` else "") .. rank.name,
				Format.short(data.TotalRolls),
				Format.duration(seconds),
				Format.multiplier(math.floor(after.luck * 100) / 100),
				bestZone(),
				Format.short(data.Gold)
			)
		end
		if data.Rank == Ranks.Max and Progression.canTakeOath(data) then
			if data.Oaths >= targetOaths then
				break
			end
			Progression.takeOath(data)
			equipBest()
			print(
				`--- Oath {data.Oaths} sworn after {Format.commas(data.TotalRolls)} rolls ({Format.duration(seconds)}) ---`
			)
		end
	end
end

print("\nFirst roll of each rarity:")
for _, rarity in Rarities.List do
	local at = firstOfRarity[rarity.id]
	print(`  {rarity.name}: {if at then "roll " .. Format.commas(at) else "never"}`)
end

local discovered = 0
for _ in data.Discovered do
	discovered += 1
end
print(
	`\nDiscovered {discovered}/{#Weapons.List} weapons, best roll: {data.BestRollId} ({Format.chance(
		data.BestRollChance
	)})`
)
print(`Relics found: {data.Stats.RelicsFound}/{#Relics.List}, lifetime gold: {Format.commas(data.Stats.GoldEarned)}`)
