--!strict
--[[
	Gold values and inventory bookkeeping.
]]

local Shared = script.Parent.Parent
local Types = require(Shared.Types)
local GameConfig = require(Shared.Config.GameConfig)
local Weapons = require(Shared.Config.Weapons)
local Relics = require(Shared.Config.Relics)
local Zones = require(Shared.Config.Zones)

type PlayerData = Types.PlayerData

local Economy = {}

local function baseValue(chance: number, zoneId: string): number
	local zone = Zones.ById[zoneId]
	local zoneMult = if zone then zone.goldMultiplier else 1
	return math.max(1, chance ^ GameConfig.Economy.SellExponent) * zoneMult
end

function Economy.weaponValue(weaponId: string, goldMultiplier: number): number
	local weapon = Weapons.ById[weaponId]
	if weapon == nil then
		return 0
	end
	return math.max(1, math.floor(baseValue(weapon.chance, weapon.zone) * goldMultiplier))
end

function Economy.relicDuplicateValue(relicId: string, goldMultiplier: number): number
	local relic = Relics.ById[relicId]
	if relic == nil then
		return 0
	end
	local value = baseValue(relic.chance, relic.zone) * GameConfig.Relics.DuplicateValueMultiplier * goldMultiplier
	return math.max(1, math.floor(value))
end

-- Total weapon copies held (sum of every stack).
function Economy.totalWeapons(data: PlayerData): number
	local total = 0
	for _, count in data.Weapons do
		total += count
	end
	return total
end

function Economy.addGold(data: PlayerData, amount: number)
	if amount <= 0 then
		return
	end
	data.Gold += amount
	data.Stats.GoldEarned += amount
end

--[[
	Sells up to `amount` copies of a weapon. Never sells the equipped weapon's last copy.
	Returns gold gained and copies actually sold.
]]
function Economy.sellWeapon(
	data: PlayerData,
	weaponId: string,
	amount: number,
	goldMultiplier: number
): (number, number)
	local owned = data.Weapons[weaponId] or 0
	local sellable = owned
	if data.EquippedWeapon == weaponId then
		sellable -= 1
	end
	local count = math.clamp(math.floor(amount), 0, math.max(sellable, 0))
	if count <= 0 then
		return 0, 0
	end

	local gold = Economy.weaponValue(weaponId, goldMultiplier) * count
	local remaining = owned - count
	if remaining > 0 then
		data.Weapons[weaponId] = remaining
	else
		data.Weapons[weaponId] = nil
	end
	Economy.addGold(data, gold)
	return gold, count
end

--[[
	Sells every copy beyond the first for each weapon at or below `maxRarityIndex`.
	Returns gold gained and copies sold.
]]
function Economy.sellDuplicates(
	data: PlayerData,
	maxRarityIndex: number,
	goldMultiplier: number,
	rarityIndexOf: (string) -> number
): (number, number)
	local totalGold, totalSold = 0, 0
	-- Snapshot keys first: sellWeapon mutates data.Weapons.
	local ids = {}
	for weaponId, count in data.Weapons do
		if count > 1 and rarityIndexOf(weaponId) <= maxRarityIndex then
			table.insert(ids, weaponId)
		end
	end
	for _, weaponId in ids do
		local gold, sold = Economy.sellWeapon(data, weaponId, data.Weapons[weaponId] - 1, goldMultiplier)
		totalGold += gold
		totalSold += sold
	end
	return totalGold, totalSold
end

return table.freeze(Economy)
