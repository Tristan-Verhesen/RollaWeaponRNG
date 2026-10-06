--!strict
--[[
	Replicates each player's state to their client.

	Services mutate profile data and call markDirty(player); dirty players get one snapshot per
	flush interval. The snapshot carries the derived stats too, so the client never recomputes
	luck on its own and always shows exactly what the server will use.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Types = require(Shared.Types)
local Ranks = require(Shared.Config.Ranks)
local Stats = require(Shared.Logic.Stats)
local Net = require(Shared.Net)
local DataService = require(script.Parent.DataService)
local PassService = require(script.Parent.PassService)
local ZoneService = require(script.Parent.ZoneService)
local Remote = require(script.Parent.Parent.Util.Remote)

type Snapshot = Types.Snapshot
type ComputedStats = Types.ComputedStats

local FLUSH_INTERVAL = 0.1

local StateService = {}

local dirty: { [Player]: boolean } = {}

function StateService.markDirty(player: Player)
	dirty[player] = true
end

function StateService.getStats(player: Player): ComputedStats?
	local data = DataService.getData(player)
	if data == nil then
		return nil
	end
	return Stats.compute(data, ZoneService.getZone(player), PassService.getPasses(player))
end

function StateService.buildSnapshot(player: Player): Snapshot?
	local data = DataService.getData(player)
	if data == nil then
		return nil
	end
	-- The purchase cache is server bookkeeping; keep it off the wire.
	local publicData = table.clone(data)
	publicData.PurchaseIdCache = {}

	local zone = ZoneService.getZone(player)
	local passes = PassService.getPasses(player)
	return {
		data = publicData,
		stats = Stats.compute(data, zone, passes),
		zone = zone,
		passes = passes,
	}
end

local function ensureLeaderstats(player: Player): Folder
	local existing = player:FindFirstChild("leaderstats")
	if existing and existing:IsA("Folder") then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = "leaderstats"

	local rank = Instance.new("StringValue")
	rank.Name = "Rank"
	rank.Parent = folder

	local rolls = Instance.new("IntValue")
	rolls.Name = "Rolls"
	rolls.Parent = folder

	folder.Parent = player
	return folder
end

local function updateLeaderstats(player: Player)
	local data = DataService.getData(player)
	if data == nil then
		return
	end
	local folder = ensureLeaderstats(player)
	local rank = folder:FindFirstChild("Rank")
	local rolls = folder:FindFirstChild("Rolls")
	if rank and rank:IsA("StringValue") then
		local oaths = if data.Oaths > 0 then ` ({string.rep("+", math.min(data.Oaths, 5))})` else ""
		rank.Value = Ranks.get(data.Rank).name .. oaths
	end
	if rolls and rolls:IsA("IntValue") then
		rolls.Value = data.TotalRolls
	end
end

local function flush()
	if next(dirty) == nil then
		return
	end
	local players = dirty
	dirty = {}
	local stateChanged = Net.event("StateChanged")
	for player in players do
		if player.Parent == Players then
			local snapshot = StateService.buildSnapshot(player)
			if snapshot then
				stateChanged:FireClient(player, snapshot)
				updateLeaderstats(player)
			end
		end
	end
end

function StateService.start()
	Remote.bind("GetSnapshot", { rate = 1, burst = 3 }, function(player: Player): Snapshot?
		DataService.waitForData(player)
		return StateService.buildSnapshot(player)
	end)

	DataService.PlayerLoaded:Connect(StateService.markDirty)
	PassService.Changed:Connect(StateService.markDirty)
	ZoneService.ZoneChanged:Connect(function(player: Player)
		StateService.markDirty(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		dirty[player] = nil
	end)

	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed >= FLUSH_INTERVAL then
			elapsed = 0
			flush()
		end
	end)
end

return StateService
