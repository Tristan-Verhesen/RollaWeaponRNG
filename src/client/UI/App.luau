--!strict
--[[
	Mounts the whole interface and manages which window is open (one at a time).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)
local Net = require(Shared.Net)
local Screen = require(script.Parent.Screen)
local UI = require(script.Parent.UI)
local Components = require(script.Parent.Components)
local HUD = require(script.Parent.HUD)
local RollReveal = require(script.Parent.RollReveal)
local Toasts = require(script.Parent.Toasts)
local Armory = require(script.Parent.Windows.Armory)
local Relics = require(script.Parent.Windows.Relics)
local Chivalry = require(script.Parent.Windows.Chivalry)
local Shop = require(script.Parent.Windows.Shop)
local StateController = require(script.Parent.Parent.Controllers.StateController)

type Snapshot = Types.Snapshot

local App = {}

local windows: { [string]: Components.WindowModule } = {}
local openName: string? = nil

local function close()
	local name = openName
	if name == nil then
		return
	end
	local module = windows[name]
	module.window.root.Visible = false
	openName = nil
	if module.onClose then
		module.onClose()
	end
end

local function open(name: string)
	local module = windows[name]
	if module == nil then
		return
	end
	close()
	openName = name

	local snapshot = StateController.get()
	if snapshot then
		module.refresh(snapshot)
	end
	if module.onOpen then
		module.onOpen()
	end

	local root = module.window.root
	local scale = root:FindFirstChildOfClass("UIScale") or UI.new("UIScale", { Parent = root }) :: UIScale
	scale.Scale = 0.92
	root.Visible = true
	TweenService:Create(scale, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		:Play()
end

function App.toggle(name: string)
	if openName == name then
		close()
	else
		open(name)
	end
end

function App.mount()
	local layer = Screen.layer("Windows", 15)
	windows.Armory = Armory.create(layer)
	windows.Relics = Relics.create(layer)
	windows.Chivalry = Chivalry.create(layer)
	windows.Shop = Shop.create(layer)

	for _, module in windows do
		module.window.closeButton.Activated:Connect(close)
	end

	StateController.Changed:Connect(function(snapshot: Snapshot)
		local name = openName
		if name then
			windows[name].refresh(snapshot)
		end
	end)

	HUD.mount({ onMenu = App.toggle })
	RollReveal.mount()

	Net.event("Notify").OnClientEvent:Connect(function(message: string, kind: Types.NotifyKind?)
		Toasts.notify(message, kind)
	end)
	Net.event("Announce").OnClientEvent:Connect(function(announcement: Types.Announcement)
		Toasts.announce(announcement)
	end)
end

return App
