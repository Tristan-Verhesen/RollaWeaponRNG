--!strict
--[[
	Client mirror of the player's server state.

	The server pushes a full Snapshot whenever something changes. While a roll is being
	revealed the controller can be "held" so the HUD does not spoil the result early; the
	newest snapshot is applied when the hold is released.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)
local Net = require(Shared.Net)
local Signal = require(Shared.Util.Signal)

type Snapshot = Types.Snapshot

local StateController = {
	Changed = Signal.new() :: Signal.Signal<Snapshot>,
}

local current: Snapshot? = nil
local receivedAt = os.clock()
local holds = 0
local pending: Snapshot? = nil

local function apply(snapshot: Snapshot)
	current = snapshot
	receivedAt = os.clock()
	StateController.Changed:Fire(snapshot)
end

function StateController.get(): Snapshot?
	return current
end

-- Yields until the first snapshot has arrived.
function StateController.await(): Snapshot
	while current == nil do
		task.wait()
	end
	return current :: Snapshot
end

function StateController.hold()
	holds += 1
end

function StateController.release()
	holds = math.max(0, holds - 1)
	if holds == 0 and pending then
		local snapshot = pending
		pending = nil
		apply(snapshot)
	end
end

-- Seconds left on a potion, counted down locally between snapshots.
function StateController.boostRemaining(potionId: string): number
	if current == nil then
		return 0
	end
	local remaining = current.data.ActiveBoosts[potionId]
	if remaining == nil then
		return 0
	end
	return math.max(0, remaining - (os.clock() - receivedAt))
end

function StateController.start()
	Net.event("StateChanged").OnClientEvent:Connect(function(snapshot: Snapshot)
		if holds > 0 then
			pending = snapshot
		else
			apply(snapshot)
		end
	end)

	task.spawn(function()
		local getSnapshot = Net.fn("GetSnapshot")
		while current == nil do
			local ok, snapshot = pcall(getSnapshot.InvokeServer, getSnapshot)
			if ok and type(snapshot) == "table" and current == nil then
				apply(snapshot)
			else
				task.wait(2)
			end
		end
	end)
end

return StateController
