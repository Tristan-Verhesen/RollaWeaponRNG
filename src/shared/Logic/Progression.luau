--!strict
--[[
	Rank-ups and Oaths (prestige).
]]

local Shared = script.Parent.Parent
local Types = require(Shared.Types)
local GameConfig = require(Shared.Config.GameConfig)
local Ranks = require(Shared.Config.Ranks)
local Zones = require(Shared.Config.Zones)

type PlayerData = Types.PlayerData

local Progression = {}

function Progression.rankCost(rankIndex: number, oaths: number): number
	local rank = Ranks.get(rankIndex)
	return math.floor(rank.goldCost * (1 + GameConfig.Oath.GoldCostScalePerOath * oaths))
end

-- Returns whether the player can rise to the next rank and, if not, why.
function Progression.canRankUp(data: PlayerData): (boolean, string?)
	if data.Rank >= Ranks.Max then
		return false, "You already hold the highest rank. Swear an Oath to begin anew."
	end
	local nextIndex = data.Rank + 1
	local nextRank = Ranks.get(nextIndex)
	if data.RollsThisOath < nextRank.rollsRequired then
		return false, `Requires {nextRank.rollsRequired} rolls ({data.RollsThisOath} so far).`
	end
	local cost = Progression.rankCost(nextIndex, data.Oaths)
	if data.Gold < cost then
		return false, `Requires {cost} gold.`
	end
	return true, nil
end

-- Unlocks every zone whose required rank has been reached. Returns newly unlocked zone ids.
function Progression.unlockZones(data: PlayerData): { string }
	local unlocked = {}
	for _, zone in Zones.List do
		if zone.requiredRank <= data.Rank and not data.UnlockedZones[zone.id] then
			data.UnlockedZones[zone.id] = true
			table.insert(unlocked, zone.id)
		end
	end
	return unlocked
end

-- Applies a rank-up. Callers must check canRankUp first. Returns newly unlocked zone ids.
function Progression.rankUp(data: PlayerData): { string }
	local nextIndex = data.Rank + 1
	data.Gold -= Progression.rankCost(nextIndex, data.Oaths)
	data.Rank = nextIndex
	return Progression.unlockZones(data)
end

function Progression.canTakeOath(data: PlayerData): (boolean, string?)
	if data.Rank < Ranks.Max then
		return false, `Only a {Ranks.get(Ranks.Max).name} may swear an Oath.`
	end
	return true, nil
end

-- Resets rank, gold and rolls-this-oath; grants one more Oath. Collection and zones are kept.
function Progression.takeOath(data: PlayerData)
	data.Oaths += 1
	data.Rank = 1
	data.Gold = 0
	data.RollsThisOath = 0
	local slots = Ranks.get(1).relicSlots
	while #data.EquippedRelics > slots do
		table.remove(data.EquippedRelics)
	end
end

return table.freeze(Progression)
