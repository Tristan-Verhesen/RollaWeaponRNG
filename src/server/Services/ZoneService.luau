--!strict
--[[
	Physical zones.

	A zone is any BasePart tagged "Zone" with a string attribute ZoneId (see Config/Zones). The
	part is an invisible volume; a player standing inside it rolls from that zone's pool. A
	player keeps their last zone while between volumes (bridges, paths), so there are no dead
	spots.

	Gates are parts tagged "ZoneGate" with a ZoneId attribute. They are solid on the server and
	clients make them passable locally once the zone is unlocked. As a backstop, anyone who
	ends up inside a locked zone is returned to their current zone's spawn.

	Optional spawn points are parts tagged "ZoneSpawn" with a ZoneId attribute.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Zones = require(Shared.Config.Zones)
local Ranks = require(Shared.Config.Ranks)
local Signal = require(Shared.Util.Signal)
local Net = require(Shared.Net)
local DataService = require(script.Parent.DataService)

local ZONE_TAG = "Zone"
local SPAWN_TAG = "ZoneSpawn"

local ZoneService = {
	ZoneChanged = Signal.new() :: Signal.Signal<Player, string>,
}

local currentZone: { [Player]: string } = {}
local lockedSince: { [Player]: number } = {}

local function zoneIdOf(instance: Instance): string?
	local zoneId = instance:GetAttribute("ZoneId")
	if type(zoneId) == "string" and Zones.ById[zoneId] then
		return zoneId
	end
	return nil
end

local function isInside(part: BasePart, position: Vector3): boolean
	local relative = part.CFrame:PointToObjectSpace(position)
	local half = part.Size / 2
	return math.abs(relative.X) <= half.X and math.abs(relative.Y) <= half.Y and math.abs(relative.Z) <= half.Z
end

-- The zone volume containing `position`, if any.
function ZoneService.zoneAt(position: Vector3): string?
	for _, instance in CollectionService:GetTagged(ZONE_TAG) do
		if instance:IsA("BasePart") and isInside(instance, position) then
			local zoneId = zoneIdOf(instance)
			if zoneId then
				return zoneId
			end
		end
	end
	return nil
end

function ZoneService.getZone(player: Player): string
	return currentZone[player] or Zones.Default
end

function ZoneService.isUnlocked(player: Player, zoneId: string): boolean
	local data = DataService.getData(player)
	return data ~= nil and data.UnlockedZones[zoneId] == true
end

function ZoneService.spawnCFrame(zoneId: string): CFrame?
	for _, instance in CollectionService:GetTagged(SPAWN_TAG) do
		if instance:IsA("BasePart") and zoneIdOf(instance) == zoneId then
			return instance.CFrame + Vector3.new(0, 4, 0)
		end
	end
	for _, instance in CollectionService:GetTagged(ZONE_TAG) do
		if instance:IsA("BasePart") and zoneIdOf(instance) == zoneId then
			return CFrame.new(instance.Position + Vector3.new(0, 6, 0))
		end
	end
	return nil
end

local function setZone(player: Player, zoneId: string)
	if currentZone[player] == zoneId then
		return
	end
	currentZone[player] = zoneId
	ZoneService.ZoneChanged:Fire(player, zoneId)
	Net.event("ZoneEntered"):FireClient(player, zoneId)
end

local function sendBack(player: Player, root: BasePart, lockedZoneId: string)
	local zone = Zones.ById[lockedZoneId]
	local target = ZoneService.spawnCFrame(ZoneService.getZone(player))
	if target then
		root.AssemblyLinearVelocity = Vector3.zero
		root.CFrame = target
	end
	Net.event("Notify"):FireClient(
		player,
		`{zone.name} is sealed until you reach the rank of {Ranks.get(zone.requiredRank).name}.`,
		"warning"
	)
end

local function update(player: Player)
	-- Until the save loads every zone would look locked; don't bounce anyone in the meantime.
	if DataService.getData(player) == nil then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		return
	end

	local zoneId = ZoneService.zoneAt(root.Position)
	if zoneId == nil then
		lockedSince[player] = nil
		return
	end

	if ZoneService.isUnlocked(player, zoneId) then
		lockedSince[player] = nil
		setZone(player, zoneId)
		return
	end

	local since = lockedSince[player]
	if since == nil then
		lockedSince[player] = os.clock()
	elseif os.clock() - since >= GameConfig.Zones.LockedGraceSeconds then
		lockedSince[player] = nil
		sendBack(player, root, zoneId)
	end
end

function ZoneService.start()
	Players.PlayerRemoving:Connect(function(player)
		currentZone[player] = nil
		lockedSince[player] = nil
	end)

	task.spawn(function()
		while true do
			for _, player in Players:GetPlayers() do
				update(player)
			end
			task.wait(GameConfig.Zones.DetectInterval)
		end
	end)
end

return ZoneService
