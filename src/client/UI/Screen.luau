--!strict
--[[
	ScreenGui layers, created on demand. Every layer carries a UIScale tied to the viewport so the
	interface is designed once at 1280x760 and scales cleanly from phones to ultrawide monitors.
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local UI = require(script.Parent.UI)

local DESIGN_SIZE = Vector2.new(1280, 760)

local Screen = {}

local layers: { [string]: ScreenGui } = {}
local scales: { UIScale } = {}

local function currentScale(): number
	local camera = Workspace.CurrentCamera
	local viewport = if camera then camera.ViewportSize else DESIGN_SIZE
	return math.clamp(math.min(viewport.X / DESIGN_SIZE.X, viewport.Y / DESIGN_SIZE.Y), 0.5, 1.35)
end

local function rescale()
	local value = currentScale()
	for _, scale in scales do
		scale.Scale = value
	end
end

local watching = false
local function watchViewport()
	if watching then
		return
	end
	watching = true
	local function bindCamera()
		local camera = Workspace.CurrentCamera
		if camera then
			camera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
		end
		rescale()
	end
	Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindCamera)
	bindCamera()
end

-- Returns (creating if needed) a full-screen layer. Higher displayOrder draws on top.
function Screen.layer(name: string, displayOrder: number): ScreenGui
	local existing = layers[name]
	if existing then
		return existing
	end

	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local gui = UI.new("ScreenGui", {
		Name = `RollaWeapon_{name}`,
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = displayOrder,
		Parent = playerGui,
	}) :: ScreenGui
	local scale = UI.new("UIScale", { Scale = currentScale(), Parent = gui }) :: UIScale
	table.insert(scales, scale)
	layers[name] = gui
	watchViewport()
	return gui
end

return Screen
