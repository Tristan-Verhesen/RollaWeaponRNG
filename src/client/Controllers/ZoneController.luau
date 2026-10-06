--!strict
--[[
	Zone gates and zone title cards.

	Gates (parts tagged "ZoneGate") are solid on the server. Here, on this client only, gates of
	unlocked zones stop colliding so the local character can walk through; everyone else still
	sees and bumps into them.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Zones = require(Shared.Config.Zones)
local Net = require(Shared.Net)
local StateController = require(script.Parent.StateController)
local ZoneTitle = require(script.Parent.Parent.UI.ZoneTitle)

local GATE_TAG = "ZoneGate"
local OPEN_TRANSPARENCY = 0.85

local ZoneController = {}

local originalTransparency: { [BasePart]: number } = {}

local function updateGate(gate: Instance)
	if not gate:IsA("BasePart") then
		return
	end
	local zoneId = gate:GetAttribute("ZoneId")
	local snapshot = StateController.get()
	local unlocked = snapshot ~= nil and type(zoneId) == "string" and snapshot.data.UnlockedZones[zoneId] == true

	if originalTransparency[gate] == nil then
		originalTransparency[gate] = gate.Transparency
	end
	gate.CanCollide = not unlocked
	gate.Transparency = if unlocked then OPEN_TRANSPARENCY else originalTransparency[gate]
end

local function updateAllGates()
	for _, gate in CollectionService:GetTagged(GATE_TAG) do
		updateGate(gate)
	end
end

function ZoneController.start()
	CollectionService:GetInstanceAddedSignal(GATE_TAG):Connect(updateGate)
	CollectionService:GetInstanceRemovedSignal(GATE_TAG):Connect(function(gate)
		if gate:IsA("BasePart") then
			originalTransparency[gate] = nil
		end
	end)
	StateController.Changed:Connect(updateAllGates)
	updateAllGates()

	Net.event("ZoneEntered").OnClientEvent:Connect(function(zoneId: string)
		local zone = Zones.ById[zoneId]
		if zone then
			ZoneTitle.show(zone)
		end
	end)
end

return ZoneController
