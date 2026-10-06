--!strict
--[[
	Remote definitions. The server creates every remote at startup (Net.setup); clients wait
	for them by name. All requests go client -> server through RemoteFunctions and the server
	validates every argument. The server never invokes the client.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

export type FunctionName =
	"GetSnapshot"
	| "Roll"
	| "SellWeapon"
	| "SellDuplicates"
	| "EquipWeapon"
	| "SetRelicEquipped"
	| "RankUp"
	| "TakeOath"
	| "UsePotion"
	| "SetAutoSell"

export type EventName = "StateChanged" | "Announce" | "Notify" | "ZoneEntered"

local FUNCTIONS: { FunctionName } = {
	"GetSnapshot",
	"Roll",
	"SellWeapon",
	"SellDuplicates",
	"EquipWeapon",
	"SetRelicEquipped",
	"RankUp",
	"TakeOath",
	"UsePotion",
	"SetAutoSell",
}

local EVENTS: { EventName } = { "StateChanged", "Announce", "Notify", "ZoneEntered" }

local FOLDER_NAME = "Remotes"

local Net = {}

local function folder(): Instance
	if RunService:IsServer() then
		local existing = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
		if existing then
			return existing
		end
		local created = Instance.new("Folder")
		created.Name = FOLDER_NAME
		created.Parent = ReplicatedStorage
		return created
	end
	return ReplicatedStorage:WaitForChild(FOLDER_NAME)
end

-- Server only: creates every remote. Safe to call more than once.
function Net.setup()
	assert(RunService:IsServer(), "Net.setup is server-only")
	local parent = folder()
	for _, name in FUNCTIONS do
		if not parent:FindFirstChild(name) then
			local remote = Instance.new("RemoteFunction")
			remote.Name = name
			remote.Parent = parent
		end
	end
	for _, name in EVENTS do
		if not parent:FindFirstChild(name) then
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = parent
		end
	end
end

function Net.fn(name: FunctionName): RemoteFunction
	local remote = if RunService:IsServer() then folder():FindFirstChild(name) else folder():WaitForChild(name)
	assert(remote and remote:IsA("RemoteFunction"), `Missing RemoteFunction {name}; did the server call Net.setup?`)
	return remote
end

function Net.event(name: EventName): RemoteEvent
	local remote = if RunService:IsServer() then folder():FindFirstChild(name) else folder():WaitForChild(name)
	assert(remote and remote:IsA("RemoteEvent"), `Missing RemoteEvent {name}; did the server call Net.setup?`)
	return remote
end

return Net
