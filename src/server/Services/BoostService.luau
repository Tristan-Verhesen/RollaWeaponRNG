--!strict
--[[
	Potions: drinking one from the satchel starts (or extends) its timer. Timers only tick while
	the player is online.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Types = require(Shared.Types)
local Products = require(Shared.Config.Products)
local DataService = require(script.Parent.DataService)
local StateService = require(script.Parent.StateService)
local Remote = require(script.Parent.Parent.Util.Remote)
local Validate = require(script.Parent.Parent.Util.Validate)

type ActionResponse = Types.ActionResponse

local TICK = 1

local BoostService = {}

local function usePotion(player: Player, potionId: unknown): ActionResponse
	local data = DataService.getData(player)
	if data == nil then
		return { ok = false, message = "Your save is still loading." }
	end
	if not Validate.string(potionId) then
		return { ok = false, message = "Unknown potion." }
	end
	local potion = Products.PotionById[potionId :: string]
	if potion == nil then
		return { ok = false, message = "Unknown potion." }
	end
	local stock = data.Potions[potion.id] or 0
	if stock <= 0 then
		return { ok = false, message = `You have no {potion.name} left.` }
	end

	if stock > 1 then
		data.Potions[potion.id] = stock - 1
	else
		data.Potions[potion.id] = nil
	end
	data.ActiveBoosts[potion.id] = (data.ActiveBoosts[potion.id] or 0) + potion.duration
	StateService.markDirty(player)
	return { ok = true, message = `You drink the {potion.name}.` }
end

local function tick()
	for player, data in DataService.loadedPlayers() do
		data.Stats.PlaySeconds += TICK
		local expired = false
		for potionId, remaining in data.ActiveBoosts do
			local left = remaining - TICK
			if left <= 0 then
				data.ActiveBoosts[potionId] = nil
				expired = true
			else
				data.ActiveBoosts[potionId] = left
			end
		end
		-- Clients count timers down locally; only resync when an effect actually ends.
		if expired then
			StateService.markDirty(player)
		end
	end
end

function BoostService.start()
	Remote.bind("UsePotion", { rate = 2, burst = 4 }, usePotion)
	task.spawn(function()
		while true do
			task.wait(TICK)
			tick()
		end
	end)
end

return BoostService
