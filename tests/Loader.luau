--[[
	Lets Roblox-style modules run under Lune.

	Game code requires siblings the Roblox way (`require(script.Parent.Config.Weapons)`). This
	loader builds lightweight "instance" nodes over the filesystem that mirror how Rojo maps
	folders and files, then loads each module with `script` and `require` pointing at them.

	Only pure modules (no game services) are meant to be loaded this way.
]]

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local task = require("@lune/task")

export type Node = any

local Loader = {}

local cache: { [string]: any } = {}
local loading: { [string]: boolean } = {}

local nodeMeta = {}

local function makeNode(path: string, name: string, isDir: boolean, parent: Node?): Node
	return setmetatable({
		__path = path,
		__name = name,
		__isDir = isDir,
		__parent = parent,
		__children = {},
	}, nodeMeta)
end

-- Builds the whole tree up front: Lune's fs calls yield, which is not allowed inside the
-- __index metamethod that resolves `script.Parent.Child`.
local function scan(node: Node)
	local path = rawget(node, "__path")
	local children = rawget(node, "__children")
	for _, entry in fs.readDir(path) do
		local fullPath = `{path}/{entry}`
		if fs.isDir(fullPath) then
			local child = makeNode(fullPath, entry, true, node)
			children[entry] = child
			scan(child)
		else
			local moduleName = string.match(entry, "^(.+)%.luau$") or string.match(entry, "^(.+)%.lua$")
			if moduleName and moduleName ~= "init" and not string.find(moduleName, "%.") then
				children[moduleName] = makeNode(fullPath, moduleName, false, node)
			end
		end
	end
end

local function findChild(node: Node, name: string): Node?
	return rawget(node, "__children")[name]
end

nodeMeta.__index = function(node: Node, key: string): any
	if key == "Name" then
		return rawget(node, "__name")
	elseif key == "Parent" then
		return rawget(node, "__parent")
	elseif key == "FindFirstChild" then
		return function(self: Node, name: string)
			return findChild(self, name)
		end
	elseif key == "WaitForChild" then
		return function(self: Node, name: string)
			return findChild(self, name) or error(`{rawget(self, "__path")} has no child {name}`)
		end
	end
	local child = findChild(node, key)
	if child == nil then
		error(`{key} is not a valid member of {rawget(node, "__path")}`, 2)
	end
	return child
end

nodeMeta.__tostring = function(node: Node): string
	return rawget(node, "__path")
end

local function sourcePath(node: Node): string
	local path = rawget(node, "__path")
	if rawget(node, "__isDir") then
		return `{path}/init.luau`
	end
	return path
end

function Loader.require(node: Node): any
	local path = sourcePath(node)
	local cached = cache[path]
	if cached ~= nil then
		return if cached == false then nil else cached
	end
	assert(not loading[path], `Cyclic require detected at {path}`)

	loading[path] = true
	local chunk = luau.load(fs.readFile(path), {
		debugName = path,
		environment = Loader.environment(node),
	})
	local result = chunk()
	loading[path] = nil

	cache[path] = if result == nil then false else result
	return result
end

-- Globals available to loaded modules: Roblox datatypes plus a `script` / `require` pair.
function Loader.environment(node: Node): { [string]: any }
	return {
		script = node,
		require = function(target: any): any
			if type(target) == "string" then
				return require(target)
			end
			return Loader.require(target)
		end,
		Color3 = roblox.Color3,
		Vector3 = roblox.Vector3,
		CFrame = roblox.CFrame,
		task = task,
	}
end

-- A node standing in for a folder on disk, e.g. Loader.root("src/shared") ~= ReplicatedStorage.Shared.
function Loader.root(path: string): Node
	assert(fs.isDir(path), `{path} is not a directory`)
	local name = string.match(path, "([^/]+)$") or path
	local root = makeNode(path, name, true, nil)
	scan(root)
	return root
end

return Loader
