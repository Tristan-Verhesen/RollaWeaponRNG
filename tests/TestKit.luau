--[[
	A tiny describe/it/expect test kit for Lune.
]]

local TestKit = {}

local stack: { string } = {}
local results = {
	passed = 0,
	failed = 0,
	failures = {} :: { { name: string, message: string } },
}

local function describeValue(value: any): string
	if type(value) == "string" then
		return string.format("%q", value)
	elseif type(value) == "table" then
		local parts = {}
		for key, inner in value do
			table.insert(parts, `{tostring(key)}={describeValue(inner)}`)
			if #parts > 8 then
				table.insert(parts, "...")
				break
			end
		end
		return "{" .. table.concat(parts, ", ") .. "}"
	end
	return tostring(value)
end

local function deepEqual(a: any, b: any): boolean
	if type(a) ~= type(b) then
		return false
	end
	if type(a) ~= "table" then
		return a == b
	end
	for key, value in a do
		if not deepEqual(value, b[key]) then
			return false
		end
	end
	for key in b do
		if a[key] == nil then
			return false
		end
	end
	return true
end

function TestKit.describe(name: string, body: () -> ())
	table.insert(stack, name)
	body()
	table.remove(stack)
end

function TestKit.it(name: string, body: () -> ())
	local fullName = table.concat(stack, " > ") .. " > " .. name
	local ok, err = pcall(body)
	if ok then
		results.passed += 1
	else
		results.failed += 1
		table.insert(results.failures, { name = fullName, message = tostring(err) })
	end
end

function TestKit.expect(actual: any)
	local function fail(message: string)
		error(message, 3)
	end

	local matchers = {}

	function matchers.toBe(expected: any)
		if actual ~= expected then
			fail(`expected {describeValue(actual)} to be {describeValue(expected)}`)
		end
	end

	function matchers.toEqual(expected: any)
		if not deepEqual(actual, expected) then
			fail(`expected {describeValue(actual)} to deep-equal {describeValue(expected)}`)
		end
	end

	function matchers.toBeCloseTo(expected: number, tolerance: number?)
		local tol = tolerance or 1e-9
		if math.abs(actual - expected) > tol then
			fail(`expected {actual} to be within {tol} of {expected}`)
		end
	end

	function matchers.toBeGreaterThan(expected: number)
		if not (actual > expected) then
			fail(`expected {actual} > {expected}`)
		end
	end

	function matchers.toBeGreaterThanOrEqual(expected: number)
		if not (actual >= expected) then
			fail(`expected {actual} >= {expected}`)
		end
	end

	function matchers.toBeLessThan(expected: number)
		if not (actual < expected) then
			fail(`expected {actual} < {expected}`)
		end
	end

	function matchers.toBeNil()
		if actual ~= nil then
			fail(`expected nil, got {describeValue(actual)}`)
		end
	end

	function matchers.toBeTruthy()
		if not actual then
			fail(`expected a truthy value, got {describeValue(actual)}`)
		end
	end

	function matchers.toBeFalsy()
		if actual then
			fail(`expected a falsy value, got {describeValue(actual)}`)
		end
	end

	function matchers.toThrow()
		local ok = pcall(actual)
		if ok then
			fail("expected function to throw")
		end
	end

	return matchers
end

-- Returns an rng that replays `values` in order, then repeats the last one.
function TestKit.sequenceRng(values: { number }): () -> number
	local index = 0
	return function()
		index = math.min(index + 1, #values)
		return values[index]
	end
end

-- Returns an rng that always yields `value`.
function TestKit.constantRng(value: number): () -> number
	return function()
		return value
	end
end

-- Deterministic seeded rng (Park-Miller minimal standard generator).
function TestKit.seededRng(seed: number): () -> number
	local state = seed % 2147483647
	if state <= 0 then
		state += 2147483646
	end
	return function()
		state = (state * 16807) % 2147483647
		return (state - 1) / 2147483646
	end
end

TestKit.results = results

return TestKit
