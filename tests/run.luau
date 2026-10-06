--[[
	Test entry point: `lune run tests/run` from the repository root.

	Every tests/specs/*.spec.luau file runs with these globals:
	  describe, it, expect        TestKit matchers
	  Shared                      node standing in for ReplicatedStorage.Shared
	  require(node)               Roblox-style require for nodes under Shared
	  TestKit                     helpers such as TestKit.seededRng
]]

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")

local Loader = require("./Loader")
local TestKit = require("./TestKit")

local SPEC_DIR = "tests/specs"
local filter = process.args[1]

local Shared = Loader.root("src/shared")

local specFiles = {}
for _, entry in fs.readDir(SPEC_DIR) do
	if string.match(entry, "%.spec%.luau$") and (filter == nil or string.find(entry, filter, 1, true)) then
		table.insert(specFiles, entry)
	end
end
table.sort(specFiles)

for _, file in specFiles do
	local path = `{SPEC_DIR}/{file}`
	local env = Loader.environment(Shared)
	env.describe = TestKit.describe
	env.it = TestKit.it
	env.expect = TestKit.expect
	env.TestKit = TestKit
	env.Shared = Shared

	local ok, err = pcall(function()
		local chunk = luau.load(fs.readFile(path), { debugName = path, environment = env })
		chunk()
	end)
	if not ok then
		TestKit.results.failed += 1
		table.insert(TestKit.results.failures, { name = `{file} (load)`, message = tostring(err) })
	end
end

local results = TestKit.results
for _, failure in results.failures do
	print(`\27[31mFAIL\27[0m {failure.name}\n     {failure.message}`)
end
print(`\n{#specFiles} spec files, {results.passed} passed, {results.failed} failed`)

if results.failed > 0 then
	process.exit(1)
end
