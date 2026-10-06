--!strict
--[[
	Binds RemoteFunction handlers with rate limiting and error isolation.

	A handler that errors returns a generic failure to the client instead of propagating the
	error (which would otherwise surface server internals in the client's output).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local RateLimiter = require(script.Parent.RateLimiter)

local Remote = {}

export type Options = {
	-- Requests per second refilled.
	rate: number?,
	-- Max requests in a burst.
	burst: number?,
}

local RATE_LIMITED = { ok = false, message = "Slow down, good sir." }
local FAILED = { ok = false, message = "Something went wrong. Please try again." }

function Remote.bind(name: Net.FunctionName, options: Options, handler: (Player, ...any) -> any)
	local limiter = RateLimiter.new(options.rate or 8, options.burst or 12)
	Net.fn(name).OnServerInvoke = function(player: Player, ...: any): any
		if not limiter:allow(player) then
			return RATE_LIMITED
		end
		local results = table.pack(pcall(handler, player, ...))
		if not results[1] then
			warn(`[Remote:{name}] {player.Name}: {results[2]}`)
			return FAILED
		end
		return results[2]
	end
end

return Remote
