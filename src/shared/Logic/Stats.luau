--!strict
--[[
	Derives a player's effective luck, roll speed, gold multiplier, capacity and relic slots.

	Luck = (1 + sum of additive bonuses) * product of multipliers
	  additive:    rank, zone, equipped weapon, equipped relics, completed relic sets
	  multipliers: oaths, luck gamepass, active luck potions
	The Blessed Roll (every Nth roll) multiplies on top of this at roll time.
]]

local Shared = script.Parent.Parent
local Types = require(Shared.Types)
local GameConfig = require(Shared.Config.GameConfig)
local Rarities = require(Shared.Config.Rarities)
local Weapons = require(Shared.Config.Weapons)
local Relics = require(Shared.Config.Relics)
local Zones = require(Shared.Config.Zones)
local Ranks = require(Shared.Config.Ranks)
local Products = require(Shared.Config.Products)

type Bonus = Types.Bonus
type PlayerData = Types.PlayerData
type ComputedStats = Types.ComputedStats
type LuckPart = Types.LuckPart
type PassOwnership = Types.PassOwnership

local Stats = {}

-- The bonus a weapon grants while equipped.
function Stats.weaponBonus(weaponId: string): Bonus?
	local weapon = Weapons.ById[weaponId]
	if weapon == nil then
		return nil
	end
	if weapon.bonus then
		return weapon.bonus
	end
	local rarity = Rarities.fromChance(weapon.chance)
	if rarity.equipLuck > 0 then
		return { luck = rarity.equipLuck }
	end
	return nil
end

function Stats.isSetComplete(zoneId: string, relicsOwned: { [string]: number }): boolean
	local pool = Relics.ByZone[zoneId]
	if pool == nil or #pool == 0 then
		return false
	end
	for _, relic in pool do
		if (relicsOwned[relic.id] or 0) <= 0 then
			return false
		end
	end
	return true
end

function Stats.oathMultiplier(oaths: number): number
	return 1 + GameConfig.Oath.LuckPerOath * oaths
end

function Stats.relicSlots(rank: number): number
	return Ranks.get(rank).relicSlots
end

function Stats.capacity(passes: PassOwnership): number
	local capacity = GameConfig.Inventory.BaseCapacity
	if passes.RoyalArmory then
		capacity += Products.RoyalArmoryCapacity
	end
	return capacity
end

-- Equipped relics that are actually owned and fit in the current slot count.
function Stats.validEquippedRelics(data: PlayerData): { string }
	local slots = Stats.relicSlots(data.Rank)
	local valid = {}
	for _, relicId in data.EquippedRelics do
		if #valid >= slots then
			break
		end
		if Relics.ById[relicId] and (data.Relics[relicId] or 0) > 0 and not table.find(valid, relicId) then
			table.insert(valid, relicId)
		end
	end
	return valid
end

function Stats.compute(data: PlayerData, zoneId: string, passes: PassOwnership): ComputedStats
	local luckParts: { LuckPart } = {}
	local addLuck = 0
	local luckMult = 1
	local gold = 0
	local speed = 0

	local function addPart(label: string, kind: "add" | "mult", value: number)
		if kind == "add" and value == 0 then
			return
		end
		if kind == "mult" and value == 1 then
			return
		end
		table.insert(luckParts, { label = label, kind = kind, value = value })
	end

	local function applyBonus(label: string, bonus: Bonus?)
		if bonus == nil then
			return
		end
		local luck = bonus.luck or 0
		addLuck += luck
		gold += bonus.gold or 0
		speed += bonus.speed or 0
		addPart(label, "add", luck)
	end

	local rank = Ranks.get(data.Rank)
	addLuck += rank.luckBonus
	addPart(`Rank: {rank.name}`, "add", rank.luckBonus)

	local zone = Zones.ById[zoneId]
	if zone then
		addLuck += zone.luckBonus
		addPart(`Zone: {zone.name}`, "add", zone.luckBonus)
	end

	local equipped = data.EquippedWeapon
	if equipped ~= "" and (data.Weapons[equipped] or 0) > 0 then
		local weapon = Weapons.ById[equipped]
		if weapon then
			applyBonus(`Weapon: {weapon.name}`, Stats.weaponBonus(equipped))
		end
	end

	for _, relicId in Stats.validEquippedRelics(data) do
		local relic = Relics.ById[relicId]
		applyBonus(`Relic: {relic.name}`, relic.bonus)
	end

	for _, setZone in Zones.List do
		if Stats.isSetComplete(setZone.id, data.Relics) then
			applyBonus(`Set: {setZone.name}`, setZone.setBonus)
		end
	end

	local oathMult = Stats.oathMultiplier(data.Oaths)
	luckMult *= oathMult
	addPart(`Oaths sworn: {data.Oaths}`, "mult", oathMult)

	if passes.LuckyBlessing then
		luckMult *= Products.LuckyBlessingMultiplier
		addPart("Blessing of Fortune", "mult", Products.LuckyBlessingMultiplier)
	end

	for potionId, remaining in data.ActiveBoosts do
		local potion = Products.PotionById[potionId]
		if potion and remaining > 0 then
			if potion.luckMultiplier then
				luckMult *= potion.luckMultiplier
				addPart(potion.name, "mult", potion.luckMultiplier)
			end
			speed += potion.speedBonus or 0
		end
	end

	local speedTotal = 1 + speed
	local cooldown = GameConfig.Roll.BaseCooldown / speedTotal
	if passes.QuickRoll then
		cooldown *= Products.QuickRollCooldownMultiplier
	end
	cooldown = math.max(GameConfig.Roll.MinCooldown, cooldown)

	return {
		luck = (1 + addLuck) * luckMult,
		luckParts = luckParts,
		cooldown = cooldown,
		speed = speedTotal,
		goldMultiplier = 1 + gold,
		capacity = Stats.capacity(passes),
		relicSlots = Stats.relicSlots(data.Rank),
	}
end

return table.freeze(Stats)
