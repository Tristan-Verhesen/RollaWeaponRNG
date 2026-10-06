--!strict
--[[
	Default player data. ProfileStore reconciles saved profiles against Template, so adding a
	field here is a safe, backwards-compatible migration.
]]

local Types = require(script.Parent.Types)
local Zones = require(script.Parent.Config.Zones)

type PlayerData = Types.PlayerData

local DataTemplate = {}

function DataTemplate.new(): PlayerData
	return {
		Gold = 0,
		TotalRolls = 0,
		RollsThisOath = 0,
		Rank = 1,
		Oaths = 0,
		Weapons = {},
		Discovered = {},
		Relics = {},
		EquippedWeapon = "",
		EquippedRelics = {},
		Potions = {},
		ActiveBoosts = {},
		Pity = {},
		BonusRollCounter = 0,
		UnlockedZones = { [Zones.Default] = true },
		BestRollId = "",
		BestRollChance = 0,
		Settings = {
			AutoSellMaxRarity = 0,
		},
		Stats = {
			GoldEarned = 0,
			RelicsFound = 0,
			PlaySeconds = 0,
		},
		PurchaseIdCache = {},
	}
end

DataTemplate.Template = DataTemplate.new()

return DataTemplate
