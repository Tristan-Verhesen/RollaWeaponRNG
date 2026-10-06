--!strict
--[[
	Server entry point. Services are plain modules with optional init() (synchronous setup,
	run in order) and start() (connections and loops, run after every init has finished).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)

Net.setup()

local Services = script.Services
-- Typed as `any`: services are free to define only init, only start, or both.
local order: { any } = {
	require(Services.MapBuilder),
	require(Services.DataService),
	require(Services.PassService),
	require(Services.ZoneService),
	require(Services.StateService),
	require(Services.CharacterService),
	require(Services.AnnouncementService),
	require(Services.RollService),
	require(Services.InventoryService),
	require(Services.RankService),
	require(Services.BoostService),
}

for _, service in order do
	if service.init then
		service.init()
	end
end

for _, service in order do
	if service.start then
		service.start()
	end
end

print("[RollaWeaponRNG] Server ready.")
