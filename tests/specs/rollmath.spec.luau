local RollMath = require(Shared.Logic.RollMath)
local Weapons = require(Shared.Config.Weapons)

local function chanceOf(item)
	return item.chance
end

local pool = {
	{ id = "legend", chance = 10_000 },
	{ id = "rare", chance = 100 },
	{ id = "uncommon", chance = 10 },
	{ id = "common", chance = 2 },
}

describe("RollMath.checkChance", function()
	it("is luck / N, capped at 1", function()
		expect(RollMath.checkChance(100, 1)).toBeCloseTo(0.01)
		expect(RollMath.checkChance(100, 2)).toBeCloseTo(0.02)
		expect(RollMath.checkChance(100, 500)).toBe(1)
		expect(RollMath.checkChance(1, 1)).toBe(1)
	end)

	it("halves effective N when luck doubles", function()
		expect(RollMath.effectiveChance(1_000_000, 2)).toBe(500_000)
		expect(RollMath.effectiveChance(10, 100)).toBe(1)
	end)
end)

describe("RollMath.cascade", function()
	it("falls back to the most common item when every check fails", function()
		local item = RollMath.cascade(pool, chanceOf, 1, TestKit.constantRng(0.999), true)
		expect(item.id).toBe("common")
	end)

	it("returns nil without fallback when every check fails", function()
		expect(RollMath.cascade(pool, chanceOf, 1, TestKit.constantRng(0.999), false)).toBeNil()
	end)

	it("checks the rarest item first", function()
		local item = RollMath.cascade(pool, chanceOf, 1, TestKit.constantRng(0), true)
		expect(item.id).toBe("legend")
	end)

	it("skips commons once luck exceeds their N", function()
		-- Luck 200: rare (N=100) always succeeds once legend fails.
		local item = RollMath.cascade(pool, chanceOf, 200, TestKit.sequenceRng({ 0.5, 0.99 }), true)
		expect(item.id).toBe("rare")
	end)

	it("matches the analytic distribution over many rolls", function()
		local zonePool = Weapons.ByZone.Hamlet
		local expected = RollMath.cascadeProbabilities(zonePool, chanceOf, 1)
		local counts = {}
		local rng = TestKit.seededRng(1337)
		local trials = 200_000
		for _ = 1, trials do
			local item = RollMath.cascade(zonePool, chanceOf, 1, rng, true)
			counts[item.id] = (counts[item.id] or 0) + 1
		end
		for index, weapon in zonePool do
			local p = expected[index]
			if p > 0.01 then
				local observed = (counts[weapon.id] or 0) / trials
				-- Five standard deviations keeps this deterministic test meaningful but stable.
				local sigma = math.sqrt(p * (1 - p) / trials)
				expect(math.abs(observed - p) < 5 * sigma).toBe(true)
			end
		end
	end)
end)

describe("RollMath.cascadeProbabilities", function()
	it("sums to one", function()
		for _, luck in { 1, 3.5, 50, 10_000 } do
			local total = 0
			for _, p in RollMath.cascadeProbabilities(pool, chanceOf, luck) do
				total += p
			end
			expect(total).toBeCloseTo(1, 1e-9)
		end
	end)

	it("puts rare items close to their nominal 1 in N", function()
		local probabilities = RollMath.cascadeProbabilities(pool, chanceOf, 1)
		expect(probabilities[1]).toBeCloseTo(1 / 10_000, 1e-12)
		expect(probabilities[2]).toBeCloseTo((1 - 1 / 10_000) / 100, 1e-12)
	end)
end)

describe("RollMath.weightedAtLeast", function()
	it("only returns items at or above the minimum", function()
		local rng = TestKit.seededRng(7)
		for _ = 1, 500 do
			local item = RollMath.weightedAtLeast(pool, chanceOf, 100, rng)
			expect(item.chance >= 100).toBe(true)
		end
	end)

	it("weights by 1/N so rarer items stay rarer", function()
		local rng = TestKit.seededRng(99)
		local legend = 0
		for _ = 1, 20_000 do
			if RollMath.weightedAtLeast(pool, chanceOf, 100, rng).id == "legend" then
				legend += 1
			end
		end
		-- Expected share: (1/10000) / (1/10000 + 1/100) ~= 0.0099
		expect(legend / 20_000).toBeLessThan(0.02)
	end)

	it("returns nil when nothing qualifies", function()
		expect(RollMath.weightedAtLeast(pool, chanceOf, 1e9, TestKit.constantRng(0.5))).toBeNil()
	end)
end)
