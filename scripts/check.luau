--[[
	Runs every check CI runs, on any OS: `lune run scripts/check`

	  1. StyLua formatting       (pass --fix to format instead of checking)
	  2. Selene lint
	  3. Lune unit tests
	  4. luau-lsp strict type check (downloads Roblox type definitions on first run)
	  5. Rojo build
]]

local fs = require("@lune/fs")
local net = require("@lune/net")
local process = require("@lune/process")

local fix = table.find(process.args, "--fix") ~= nil
local DEFS_PATH = "globalTypes.d.luau"
local DEFS_URL = "https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/main/scripts/globalTypes.d.luau"

local failures = {}

local function step(name: string, program: string, args: { string })
	print(`\n== {name} ==`)
	local ok, result = pcall(process.exec, program, args, { stdio = "inherit" })
	if not ok then
		print(`could not run {program}: {result}. Did you run \`rokit install\`?`)
		table.insert(failures, name)
	elseif not result.ok then
		table.insert(failures, name)
	end
end

if fix then
	step("Format", "stylua", { "src", "tests", "scripts" })
else
	step("Format", "stylua", { "--check", "src", "tests", "scripts" })
end
step("Lint", "selene", { "src" })
step("Tests", "lune", { "run", "tests/run" })

if not fs.isFile(DEFS_PATH) then
	print("\nDownloading Roblox type definitions...")
	local ok, response = pcall(net.request, DEFS_URL)
	if ok and response.ok then
		fs.writeFile(DEFS_PATH, response.body)
	else
		print(`download failed ({if ok then response.statusCode else response}); save {DEFS_URL} as {DEFS_PATH}`)
	end
end
step(
	"Sourcemap",
	"rojo",
	{ "sourcemap", "default.project.json", "--output", "sourcemap.json", "--include-non-scripts" }
)
step("Type check", "luau-lsp", {
	"analyze",
	"--platform=roblox",
	"--sourcemap=sourcemap.json",
	`--definitions=@roblox={DEFS_PATH}`,
	"--ignore=ServerPackages/**",
	"--ignore=Packages/**",
	"src",
})
step("Build", "rojo", { "build", "default.project.json", "--output", "RollaWeaponRNG.rbxl" })

print("")
if #failures > 0 then
	print(`FAILED: {table.concat(failures, ", ")}`)
	process.exit(1)
end
print("All checks passed.")
