--!strict
--[[
	Calls a server action and surfaces its message as a toast.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)
local Net = require(Shared.Net)
local Toasts = require(script.Parent.UI.Toasts)

type ActionResponse = Types.ActionResponse

local Actions = {}

function Actions.call(name: Net.FunctionName, ...: any): ActionResponse
	local remote = Net.fn(name)
	local ok, response = pcall(remote.InvokeServer, remote, ...)
	if not ok or type(response) ~= "table" then
		Toasts.notify("The realm did not answer. Try again.", "error")
		return { ok = false }
	end
	local result = response :: ActionResponse
	if result.message then
		Toasts.notify(result.message, if result.ok then "success" else "warning")
	end
	return result
end

return Actions
