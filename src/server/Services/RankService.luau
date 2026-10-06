--!strict
--[[
	Rising through the ranks and swearing Oaths.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Types = require(Shared.Types)
local Ranks = require(Shared.Config.Ranks)
local Zones = require(Shared.Config.Zones)
local Progression = require(Shared.Logic.Progression)
local Stats = require(Shared.Logic.Stats)
local Format = require(Shared.Util.Format)
local Net = require(Shared.Net)
local DataService = require(script.Parent.DataService)
local StateService = require(script.Parent.StateService)
local CharacterService = require(script.Parent.CharacterService)
local Remote = require(script.Parent.Parent.Util.Remote)

type ActionResponse = Types.ActionResponse

local RankService = {}

local NOT_LOADED: ActionResponse = { ok = false, message = "Your save is still loading." }

local function rankUp(player: Player): ActionResponse
	local data = DataService.getData(player)
	if data == nil then
		return NOT_LOADED
	end
	local ok, reason = Progression.canRankUp(data)
	if not ok then
		return { ok = false, message = reason }
	end

	local unlocked = Progression.rankUp(data)
	StateService.markDirty(player)
	CharacterService.refreshTitle(player)

	local notify = Net.event("Notify")
	for _, zoneId in unlocked do
		notify:FireClient(player, `The gates of {Zones.ById[zoneId].name} open before you.`, "success")
	end
	return { ok = true, message = `Arise, {Ranks.get(data.Rank).name} {player.DisplayName}!` }
end

local function takeOath(player: Player): ActionResponse
	local data = DataService.getData(player)
	if data == nil then
		return NOT_LOADED
	end
	local ok, reason = Progression.canTakeOath(data)
	if not ok then
		return { ok = false, message = reason }
	end

	Progression.takeOath(data)
	StateService.markDirty(player)
	CharacterService.refreshTitle(player)
	return {
		ok = true,
		message = `Oath sworn. Your luck is forever {Format.multiplier(Stats.oathMultiplier(data.Oaths))}.`,
	}
end

function RankService.start()
	Remote.bind("RankUp", { rate = 2, burst = 4 }, rankUp)
	Remote.bind("TakeOath", { rate = 0.5, burst = 1 }, takeOath)
end

return RankService
