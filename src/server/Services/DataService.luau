--!strict
--[[
	Player persistence via ProfileStore (session-locked, auto-saving, dupe-safe).

	Other services read and mutate `DataService.getData(player)` directly. The table *is* the
	profile data, so mutations are saved automatically. Remember to call
	StateService.markDirty(player) afterwards so the client sees the change.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage.Shared
local Types = require(Shared.Types)
local GameConfig = require(Shared.Config.GameConfig)
local Ranks = require(Shared.Config.Ranks)
local Weapons = require(Shared.Config.Weapons)
local DataTemplate = require(Shared.DataTemplate)
local Progression = require(Shared.Logic.Progression)
local Signal = require(Shared.Util.Signal)

assert(
	ServerScriptService:FindFirstChild("ServerPackages"),
	"ServerPackages is missing. Run `wally install`, then restart `rojo serve`."
)
-- Cast through `any`: Wally's link file does not re-export ProfileStore's types.
local ProfileStore = require(ServerScriptService.ServerPackages.ProfileStore) :: any

type PlayerData = Types.PlayerData

-- The subset of ProfileStore's Profile we use.
export type Profile = {
	Data: PlayerData,
	LastSavedData: PlayerData,
	Key: string,
	IsActive: (self: Profile) -> boolean,
	Reconcile: (self: Profile) -> (),
	EndSession: (self: Profile) -> (),
	AddUserId: (self: Profile, userId: number) -> (),
	Save: (self: Profile) -> (),
	OnSessionEnd: { Connect: (self: any, listener: () -> ()) -> any },
}

local DataService = {
	-- Fired once a player's profile is loaded and sanitized.
	PlayerLoaded = Signal.new() :: Signal.Signal<Player, PlayerData>,
	-- Fired right before a player's profile session ends.
	PlayerUnloading = Signal.new() :: Signal.Signal<Player>,
}

local profiles: { [Player]: Profile } = {}
local store: any = nil

-- Repairs data that may be stale after content or rule changes.
local function sanitize(data: PlayerData)
	data.Rank = math.clamp(math.floor(data.Rank), 1, Ranks.Max)
	data.BonusRollCounter = math.clamp(math.floor(data.BonusRollCounter), 0, GameConfig.BonusRoll.Every - 1)
	data.Settings.AutoSellMaxRarity =
		math.clamp(math.floor(data.Settings.AutoSellMaxRarity), 0, GameConfig.Inventory.MaxAutoSellRarity)

	if data.EquippedWeapon ~= "" and (data.Weapons[data.EquippedWeapon] or 0) <= 0 then
		data.EquippedWeapon = ""
	end
	for weaponId, count in data.Weapons do
		if count <= 0 then
			data.Weapons[weaponId] = nil
		elseif Weapons.ById[weaponId] then
			data.Discovered[weaponId] = true
		end
	end
	Progression.unlockZones(data)
end

local function onPlayerAdded(player: Player)
	local profile: Profile? = store:StartSessionAsync(`Player_{player.UserId}`, {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})

	if profile == nil then
		-- Another server holds the session or DataStores are unavailable.
		player:Kick("Your save could not be loaded. Please rejoin in a moment.")
		return
	end

	profile:AddUserId(player.UserId) -- GDPR compliance
	profile:Reconcile() -- Fill in fields added to the template since this profile was saved

	profile.OnSessionEnd:Connect(function()
		profiles[player] = nil
		player:Kick("Your save was opened on another server. Please rejoin.")
	end)

	if player.Parent ~= Players then
		profile:EndSession()
		return
	end

	sanitize(profile.Data)
	profiles[player] = profile
	DataService.PlayerLoaded:Fire(player, profile.Data)
end

local function onPlayerRemoving(player: Player)
	local profile = profiles[player]
	if profile then
		DataService.PlayerUnloading:Fire(player)
		profiles[player] = nil
		profile:EndSession()
	end
end

function DataService.getProfile(player: Player): Profile?
	return profiles[player]
end

function DataService.getData(player: Player): PlayerData?
	local profile = profiles[player]
	return if profile then profile.Data else nil
end

-- Yields until the player's data is loaded or they leave. Returns nil if they left.
function DataService.waitForData(player: Player, timeout: number?): PlayerData?
	local deadline = os.clock() + (timeout or 30)
	while player.Parent == Players and os.clock() < deadline do
		local data = DataService.getData(player)
		if data then
			return data
		end
		task.wait(0.1)
	end
	return DataService.getData(player)
end

function DataService.loadedPlayers(): { [Player]: PlayerData }
	local result = {}
	for player, profile in profiles do
		result[player] = profile.Data
	end
	return result
end

function DataService.init()
	local playerStore = ProfileStore.New(GameConfig.DataStore.Name, DataTemplate.Template)
	store = if RunService:IsStudio() and GameConfig.Debug.UseMockDataInStudio then playerStore.Mock else playerStore
end

function DataService.start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
end

return DataService
