--!strict
--[[
	Reusable themed widgets.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Types = require(ReplicatedStorage:WaitForChild("Shared").Types)
local Theme = require(script.Parent.Theme)
local UI = require(script.Parent.UI)

local Components = {}

local FAST = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

export type ButtonProps = {
	text: string,
	size: UDim2,
	position: UDim2?,
	anchor: Vector2?,
	color: Color3?,
	textColor: Color3?,
	textSize: number?,
	font: Enum.Font?,
	parent: Instance?,
	layoutOrder: number?,
}

function Components.button(props: ButtonProps): TextButton
	local base = props.color or Theme.Colors.IronRaised
	local hover = base:Lerp(Color3.new(1, 1, 1), 0.08)
	local button = UI.textButton({
		Text = props.text,
		Size = props.size,
		Position = props.position or UDim2.new(),
		AnchorPoint = props.anchor or Vector2.zero,
		BackgroundColor3 = base,
		TextColor3 = props.textColor or Theme.Colors.Parchment,
		TextSize = props.textSize or 16,
		Font = props.font or Theme.Fonts.Body,
		LayoutOrder = props.layoutOrder or 0,
		Parent = props.parent,
	})
	UI.corner(button)
	UI.stroke(button, Theme.Colors.Trim, 1.5, 0.25)
	local scale = UI.new("UIScale", { Parent = button }) :: UIScale

	button.MouseEnter:Connect(function()
		if button.Active then
			TweenService:Create(button, FAST, { BackgroundColor3 = hover }):Play()
		end
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(button, FAST, { BackgroundColor3 = button:GetAttribute("BaseColor") or base }):Play()
		TweenService:Create(scale, FAST, { Scale = 1 }):Play()
	end)
	button.MouseButton1Down:Connect(function()
		TweenService:Create(scale, FAST, { Scale = 0.96 }):Play()
	end)
	button.MouseButton1Up:Connect(function()
		TweenService:Create(scale, FAST, { Scale = 1 }):Play()
	end)
	return button
end

-- Recolors a button created by Components.button and remembers it as the resting color.
function Components.setButtonColor(button: TextButton, color: Color3)
	button:SetAttribute("BaseColor", color)
	button.BackgroundColor3 = color
end

function Components.setEnabled(button: TextButton, enabled: boolean)
	button.Active = enabled
	button.AutoButtonColor = false
	button.TextTransparency = if enabled then 0 else 0.5
end

export type Window = {
	root: Frame,
	content: Frame,
	title: TextLabel,
	closeButton: TextButton,
}

function Components.window(parent: Instance, titleText: string, size: UDim2): Window
	local root = UI.frame({
		Name = titleText,
		Size = size,
		Position = UDim2.fromScale(0.5, 0.52),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Theme.Colors.Iron,
		Visible = false,
		Parent = parent,
	})
	UI.corner(root, 10)
	UI.stroke(root, Theme.Colors.Trim, 2)
	UI.gradient(root, Color3.fromRGB(255, 255, 255), Color3.fromRGB(190, 190, 190))

	local header = UI.frame({
		Name = "Header",
		Size = UDim2.new(1, 0, 0, 54),
		BackgroundColor3 = Theme.Colors.IronRaised,
		Parent = root,
	})
	UI.corner(header, 10)

	local title = UI.label({
		Name = "Title",
		Text = titleText,
		Font = Theme.Fonts.Title,
		TextSize = 34,
		TextColor3 = Theme.Colors.Gold,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, -80, 1, 0),
		Position = UDim2.fromOffset(20, 0),
		Parent = header,
	})

	local closeButton = Components.button({
		text = "✕",
		size = UDim2.fromOffset(38, 38),
		position = UDim2.new(1, -10, 0.5, 0),
		anchor = Vector2.new(1, 0.5),
		color = Theme.Colors.Crimson,
		textSize = 20,
		parent = header,
	})

	local content = UI.frame({
		Name = "Content",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -28, 1, -70),
		Position = UDim2.fromOffset(14, 62),
		Parent = root,
	})

	return { root = root, content = content, title = title, closeButton = closeButton }
end

-- A window plus the function that redraws it from a snapshot.
export type WindowModule = {
	window: Window,
	refresh: (snapshot: Types.Snapshot) -> (),
	onOpen: (() -> ())?,
	onClose: (() -> ())?,
}

export type ProgressBar = {
	frame: Frame,
	fill: Frame,
	set: (fraction: number, text: string?) -> (),
}

function Components.progressBar(parent: Instance, size: UDim2, fillColor: Color3): ProgressBar
	local frame = UI.frame({
		Size = size,
		BackgroundColor3 = Theme.Colors.Black,
		BackgroundTransparency = 0.35,
		Parent = parent,
	})
	UI.corner(frame, 4)
	UI.stroke(frame, Theme.Colors.Trim, 1, 0.5)
	local fill = UI.frame({
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = fillColor,
		Parent = frame,
	})
	UI.corner(fill, 4)
	local label = UI.label({
		Size = UDim2.fromScale(1, 1),
		TextSize = 14,
		ZIndex = 2,
		TextStrokeTransparency = 0.5,
		Parent = frame,
	})
	return {
		frame = frame,
		fill = fill,
		set = function(fraction: number, text: string?)
			fill.Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1)
			label.Text = text or ""
		end,
	}
end

-- A small rounded tag such as "NEW" or "EQUIPPED".
function Components.tag(parent: Instance, text: string, color: Color3): TextLabel
	local tag = UI.label({
		Text = text,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 20),
		BackgroundTransparency = 0,
		BackgroundColor3 = color,
		TextColor3 = Theme.Colors.Iron,
		TextSize = 12,
		Font = Enum.Font.GothamBold,
		TextWrapped = false,
		Parent = parent,
	})
	UI.corner(tag, 4)
	UI.padding(tag, 4)
	return tag
end

return Components
