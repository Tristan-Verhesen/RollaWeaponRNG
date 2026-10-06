--!strict
--[[
	Per-player token bucket. Each request spends a token; tokens refill at `rate` per second
	up to `burst`.
]]

local Players = game:GetService("Players")

export type RateLimiter = {
	allow: (self: RateLimiter, player: Player) -> boolean,
}

type Bucket = { tokens: number, updated: number }

local RateLimiter = {}

function RateLimiter.new(rate: number, burst: number): RateLimiter
	local buckets: { [Player]: Bucket } = {}

	Players.PlayerRemoving:Connect(function(player)
		buckets[player] = nil
	end)

	local limiter: RateLimiter = {
		allow = function(_self: RateLimiter, player: Player): boolean
			local now = os.clock()
			local bucket = buckets[player]
			if bucket == nil then
				bucket = { tokens = burst, updated = now }
				buckets[player] = bucket
			end
			bucket.tokens = math.min(burst, bucket.tokens + (now - bucket.updated) * rate)
			bucket.updated = now
			if bucket.tokens < 1 then
				return false
			end
			bucket.tokens -= 1
			return true
		end,
	}
	return limiter
end

return RateLimiter
