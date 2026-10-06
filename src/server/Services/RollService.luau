--!strict
--[[
	Server-authoritative rolling. The client only asks; the server checks the cooldown, rolls
	with its own RNG, applies the result and replies with what happened.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Types = require(Shared.Types)
local GameConfig = require(Shared.Config.GameConfig)
local RollEngine = require(Shared.Logic.RollEngine)
local DataService = require(script.Parent.DataService)
local StateService = require(script.Parent.StateService)
local ZoneService = require(script.Parent.ZoneService)
local AnnouncementService = require(script.Parent.AnnouncementService)
local Remote = require(script.Parent.Parent.Util.Remote)

type RollResponse = Types.RollResponse

local RollService = {}

local random = Random.new()
local function rng(): number
	return random:NextNumber()
end

local lastRoll: { [Player]: number } = {}

local function roll(player: Player): RollResponse
	local data = DataService.getData(player)
	local stats = StateService.getStats(player)
	if data == nil or stats == nil then
		return { ok = false, reason = "Your save is still loading.", cooldown = 1 }
	end

	local now = os.clock()
	local elapsed = now - (lastRoll[player] or 0)
	if elapsed < stats.cooldown - GameConfig.Roll.CooldownTolerance then
		return { ok = false, reason = "cooldown", cooldown = stats.cooldown - elapsed }
	end
	lastRoll[player] = now

	local result = RollEngine.roll(data, {
		zoneId = ZoneService.getZone(player),
		luck = stats.luck,
		goldMultiplier = stats.goldMultiplier,
		capacity = stats.capacity,
	}, rng)

	StateService.markDirty(player)
	AnnouncementService.onRoll(player, result)

	return { ok = true, result = result, cooldown = stats.cooldown }
end

function RollService.start()
	-- The cooldown is the real limiter; this only stops request floods.
	Remote.bind("Roll", { rate = 6, burst = 10 }, roll)

	Players.PlayerRemoving:Connect(function(player)
		lastRoll[player] = nil
	end)
end

return RollService
