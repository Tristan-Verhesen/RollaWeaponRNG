--!strict
--[[
	Core RNG math. Pure: no Roblox services, randomness is injected.

	The cascade walks a pool from rarest to most common. Each item gets an independent check
	at min(1, luck / N); the first success wins. Luck therefore divides every item's N, and once
	luck exceeds an item's N, everything more common than it can no longer drop.
]]

local Types = require(script.Parent.Parent.Types)

type Rng = Types.Rng

local RollMath = {}

-- Chance a single check succeeds for an item with odds "1 in chance".
function RollMath.checkChance(chance: number, luck: number): number
	if chance <= 1 then
		return 1
	end
	return math.min(1, math.max(luck, 0) / chance)
end

-- The "1 in N" a player effectively sees for an item at a given luck.
function RollMath.effectiveChance(chance: number, luck: number): number
	if luck <= 0 then
		return chance
	end
	return math.max(1, chance / luck)
end

--[[
	Runs the cascade over `sorted` (rarest first).
	With `fallback`, the most common item is returned when nothing hits; otherwise returns nil.
]]
function RollMath.cascade<T>(sorted: { T }, chanceOf: (T) -> number, luck: number, rng: Rng, fallback: boolean): T?
	for _, item in sorted do
		if rng() < RollMath.checkChance(chanceOf(item), luck) then
			return item
		end
	end
	if fallback then
		return sorted[#sorted]
	end
	return nil
end

--[[
	Picks one item whose chance is at least `minChance`, weighted by 1 / chance so rarer items
	stay proportionally rarer. Used by pity. Returns nil when nothing qualifies.
]]
function RollMath.weightedAtLeast<T>(pool: { T }, chanceOf: (T) -> number, minChance: number, rng: Rng): T?
	local total = 0
	for _, item in pool do
		local chance = chanceOf(item)
		if chance >= minChance then
			total += 1 / chance
		end
	end
	if total <= 0 then
		return nil
	end

	local target = rng() * total
	local last: T? = nil
	for _, item in pool do
		local chance = chanceOf(item)
		if chance >= minChance then
			target -= 1 / chance
			last = item
			if target < 0 then
				return item
			end
		end
	end
	-- Floating point leftovers land on the last eligible item.
	return last
end

--[[
	Exact probability of each item in a cascade (rarest first), useful for tests and UI.
	Returns probabilities in the same order as `sorted`.
]]
function RollMath.cascadeProbabilities<T>(sorted: { T }, chanceOf: (T) -> number, luck: number): { number }
	local result = table.create(#sorted, 0)
	local remaining = 1
	for index, item in sorted do
		local p = RollMath.checkChance(chanceOf(item), luck)
		if index == #sorted then
			p = 1
		end
		result[index] = remaining * p
		remaining *= (1 - p)
	end
	return result
end

return table.freeze(RollMath)
