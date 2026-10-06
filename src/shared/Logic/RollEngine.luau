--!strict
--[[
	One complete roll: Blessed Roll counter, weapon cascade, pity upgrade, inventory and
	auto-sell, best-roll tracking and the relic check. Mutates `data` in place and returns
	what happened. Pure apart from that mutation; randomness is injected.
]]

local Shared = script.Parent.Parent
local Types = require(Shared.Types)
local GameConfig = require(Shared.Config.GameConfig)
local Rarities = require(Shared.Config.Rarities)
local Weapons = require(Shared.Config.Weapons)
local Relics = require(Shared.Config.Relics)
local RollMath = require(script.Parent.RollMath)
local Economy = require(script.Parent.Economy)

type PlayerData = Types.PlayerData
type RollResult = Types.RollResult
type WeaponDef = Types.WeaponDef
type RelicDef = Types.RelicDef
type Rng = Types.Rng

export type RollContext = {
	zoneId: string,
	-- Luck from Stats.compute (before the Blessed Roll multiplier).
	luck: number,
	goldMultiplier: number,
	capacity: number,
}

local RollEngine = {}

local function weaponChance(weapon: WeaponDef): number
	return weapon.chance
end

local function relicChance(relic: RelicDef): number
	return relic.chance
end

local function poolHasRarity(pool: { WeaponDef }, minChance: number): boolean
	for _, weapon in pool do
		if weapon.chance >= minChance then
			return true
		end
	end
	return false
end

-- The highest pity rarity that is due on this roll for this pool, if any.
function RollEngine.duePity(data: PlayerData, pool: { WeaponDef }): string?
	local best: string? = nil
	local bestIndex = 0
	for _, rule in GameConfig.Pity do
		local counter = data.Pity[rule.rarity] or 0
		local index = Rarities.indexOf(rule.rarity)
		local rarity = Rarities.ById[rule.rarity]
		if rarity and counter + 1 >= rule.rolls and index > bestIndex and poolHasRarity(pool, rarity.minChance) then
			best = rule.rarity
			bestIndex = index
		end
	end
	return best
end

function RollEngine.updatePity(data: PlayerData, rarityIndex: number)
	for _, rule in GameConfig.Pity do
		if rarityIndex >= Rarities.indexOf(rule.rarity) then
			data.Pity[rule.rarity] = 0
		else
			data.Pity[rule.rarity] = (data.Pity[rule.rarity] or 0) + 1
		end
	end
end

function RollEngine.rollsUntilBonus(data: PlayerData): number
	return GameConfig.BonusRoll.Every - data.BonusRollCounter
end

function RollEngine.roll(data: PlayerData, ctx: RollContext, rng: Rng): RollResult
	local pool = Weapons.ByZone[ctx.zoneId]
	assert(pool and #pool > 0, `Zone {ctx.zoneId} has no weapons`)

	data.TotalRolls += 1
	data.RollsThisOath += 1

	-- Blessed Roll: every Nth roll gets multiplied luck.
	data.BonusRollCounter += 1
	local isBonusRoll = data.BonusRollCounter >= GameConfig.BonusRoll.Every
	if isBonusRoll then
		data.BonusRollCounter = 0
	end
	local luck = ctx.luck * (if isBonusRoll then GameConfig.BonusRoll.LuckMultiplier else 1)

	local weapon = RollMath.cascade(pool, weaponChance, luck, rng, true) :: WeaponDef
	local rarityIndex = Rarities.indexFromChance(weapon.chance)

	-- Pity only ever upgrades a roll, never downgrades it.
	local pityRarity: string? = nil
	local due = RollEngine.duePity(data, pool)
	if due and rarityIndex < Rarities.indexOf(due) then
		local forced = RollMath.weightedAtLeast(pool, weaponChance, Rarities.ById[due].minChance, rng)
		if forced then
			weapon = forced
			rarityIndex = Rarities.indexFromChance(forced.chance)
			pityRarity = due
		end
	end
	RollEngine.updatePity(data, rarityIndex)

	-- Inventory: first copies are always kept; duplicates may be auto-sold.
	local owned = data.Weapons[weapon.id] or 0
	local isNew = not data.Discovered[weapon.id]
	data.Discovered[weapon.id] = true

	local autoSold = false
	local goldGained = 0
	if owned >= 1 then
		local byPlayerRule = rarityIndex <= data.Settings.AutoSellMaxRarity
		local protected = rarityIndex >= Rarities.indexOf(GameConfig.Inventory.ProtectedRarity)
		local full = Economy.totalWeapons(data) >= ctx.capacity
		if byPlayerRule or (full and not protected) then
			autoSold = true
			goldGained += Economy.weaponValue(weapon.id, ctx.goldMultiplier)
		end
	end
	if not autoSold then
		data.Weapons[weapon.id] = owned + 1
	end

	if weapon.chance > data.BestRollChance then
		data.BestRollChance = weapon.chance
		data.BestRollId = weapon.id
	end

	-- Relic check, with dampened luck.
	local relicId: string? = nil
	local relicIsNew = false
	local relicPool = Relics.ByZone[ctx.zoneId]
	if relicPool then
		local relicLuck = luck ^ GameConfig.Relics.LuckExponent
		local relic = RollMath.cascade(relicPool, relicChance, relicLuck, rng, false)
		if relic then
			relicId = relic.id
			if (data.Relics[relic.id] or 0) > 0 then
				goldGained += Economy.relicDuplicateValue(relic.id, ctx.goldMultiplier)
			else
				data.Relics[relic.id] = 1
				data.Stats.RelicsFound += 1
				relicIsNew = true
			end
		end
	end

	Economy.addGold(data, goldGained)

	return {
		weaponId = weapon.id,
		chance = weapon.chance,
		rarity = Rarities.List[rarityIndex].id,
		isNew = isNew,
		isBonusRoll = isBonusRoll,
		pityRarity = pityRarity,
		luck = luck,
		autoSold = autoSold,
		goldGained = goldGained,
		relicId = relicId,
		relicIsNew = relicIsNew,
		rollsUntilBonus = RollEngine.rollsUntilBonus(data),
	}
end

return table.freeze(RollEngine)
