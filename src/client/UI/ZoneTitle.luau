--!strict
--[[
	Large fading title card when entering a zone.
]]

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)
local Theme = require(script.Parent.Theme)
local UI = require(script.Parent.UI)
local Screen = require(script.Parent.Screen)

local ZoneTitle = {}

local current: Frame? = nil

function ZoneTitle.show(zone: Types.ZoneDef)
	if current then
		current:Destroy()
	end
	local layer = Screen.layer("ZoneTitle", 30)
	local card = UI.frame({
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(900, 140),
		Position = UDim2.fromScale(0.5, 0.24),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Parent = layer,
	})
	current = card

	local title = UI.label({
		Text = zone.name,
		Font = Theme.Fonts.Title,
		TextSize = 72,
		TextColor3 = zone.accentColor:Lerp(Theme.Colors.Parchment, 0.45),
		TextStrokeTransparency = 0.4,
		TextTransparency = 1,
		TextStrokeColor3 = Theme.Colors.Black,
		Size = UDim2.new(1, 0, 0, 80),
		Parent = card,
	})
	local rule = UI.frame({
		Size = UDim2.new(0, 0, 0, 2),
		Position = UDim2.new(0.5, 0, 0, 86),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Theme.Colors.Trim,
		Parent = card,
	})
	local subtitle = UI.label({
		Text = zone.subtitle,
		Font = Theme.Fonts.Flavor,
		TextSize = 26,
		TextColor3 = Theme.Colors.Parchment,
		TextTransparency = 1,
		TextStrokeTransparency = 1,
		Size = UDim2.new(1, 0, 0, 40),
		Position = UDim2.fromOffset(0, 94),
		Parent = card,
	})

	local fadeIn = TweenInfo.new(0.9, Enum.EasingStyle.Sine)
	TweenService:Create(title, fadeIn, { TextTransparency = 0 }):Play()
	TweenService:Create(subtitle, fadeIn, { TextTransparency = 0, TextStrokeTransparency = 0.6 }):Play()
	TweenService:Create(rule, TweenInfo.new(1.2, Enum.EasingStyle.Quart), { Size = UDim2.new(0, 520, 0, 2) }):Play()

	task.delay(3.2, function()
		if current ~= card then
			return
		end
		local fadeOut = TweenInfo.new(1.1, Enum.EasingStyle.Sine)
		TweenService:Create(title, fadeOut, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		TweenService:Create(subtitle, fadeOut, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		TweenService:Create(rule, fadeOut, { BackgroundTransparency = 1 }):Play()
		task.wait(1.2)
		card:Destroy()
		if current == card then
			current = nil
		end
	end)
end

return ZoneTitle
