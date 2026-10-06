--!strict
--[[
	Small helpers for building UI in code without a framework.

	UI.new("Frame", { Size = ..., Parent = ... }) applies properties in order, setting Parent
	last so the instance is fully configured before it enters the tree.
]]

local Theme = require(script.Parent.Theme)

local UI = {}

function UI.new(className: string, props: { [string]: any }?): Instance
	local instance = Instance.new(className)
	local parent: Instance? = nil
	if props then
		for key, value in props do
			if key == "Parent" then
				parent = value
			else
				(instance :: any)[key] = value
			end
		end
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

function UI.frame(props: { [string]: any }): Frame
	local defaults = { BackgroundColor3 = Theme.Colors.Iron, BorderSizePixel = 0 }
	for key, value in props do
		defaults[key] = value
	end
	return UI.new("Frame", defaults) :: Frame
end

function UI.label(props: { [string]: any }): TextLabel
	local defaults: { [string]: any } = {
		BackgroundTransparency = 1,
		Font = Theme.Fonts.Body,
		TextColor3 = Theme.Colors.Parchment,
		TextSize = 16,
		TextWrapped = true,
		RichText = true,
	}
	for key, value in props do
		defaults[key] = value
	end
	return UI.new("TextLabel", defaults) :: TextLabel
end

function UI.textButton(props: { [string]: any }): TextButton
	local defaults: { [string]: any } = {
		AutoButtonColor = false,
		BackgroundColor3 = Theme.Colors.IronRaised,
		BorderSizePixel = 0,
		Font = Theme.Fonts.Body,
		TextColor3 = Theme.Colors.Parchment,
		TextSize = 16,
		RichText = true,
	}
	for key, value in props do
		defaults[key] = value
	end
	return UI.new("TextButton", defaults) :: TextButton
end

function UI.scroll(props: { [string]: any }): ScrollingFrame
	local defaults: { [string]: any } = {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Theme.Colors.Trim,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollingDirection = Enum.ScrollingDirection.Y,
	}
	for key, value in props do
		defaults[key] = value
	end
	return UI.new("ScrollingFrame", defaults) :: ScrollingFrame
end

function UI.corner(parent: Instance, radius: number?): UICorner
	return UI.new("UICorner", { CornerRadius = UDim.new(0, radius or Theme.Radius), Parent = parent }) :: UICorner
end

function UI.stroke(parent: Instance, color: Color3?, thickness: number?, transparency: number?): UIStroke
	return UI.new("UIStroke", {
		Color = color or Theme.Colors.Trim,
		Thickness = thickness or 1.5,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = parent,
	}) :: UIStroke
end

function UI.padding(parent: Instance, pixels: number): UIPadding
	local amount = UDim.new(0, pixels)
	return UI.new("UIPadding", {
		PaddingTop = amount,
		PaddingBottom = amount,
		PaddingLeft = amount,
		PaddingRight = amount,
		Parent = parent,
	}) :: UIPadding
end

function UI.list(
	parent: Instance,
	direction: Enum.FillDirection,
	spacing: number,
	align: Enum.HorizontalAlignment?
): UIListLayout
	return UI.new("UIListLayout", {
		FillDirection = direction,
		Padding = UDim.new(0, spacing),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = align or Enum.HorizontalAlignment.Left,
		Parent = parent,
	}) :: UIListLayout
end

function UI.gradient(parent: Instance, top: Color3, bottom: Color3): UIGradient
	return UI.new("UIGradient", {
		Color = ColorSequence.new(top, bottom),
		Rotation = 90,
		Parent = parent,
	}) :: UIGradient
end

-- Removes every child except layout/decoration objects.
function UI.clear(container: Instance)
	for _, child in container:GetChildren() do
		if not child:IsA("UIBase") then
			child:Destroy()
		end
	end
end

-- "#RRGGBB" for RichText font color tags.
function UI.hex(color: Color3): string
	return "#" .. color:ToHex()
end

function UI.colorize(text: string, color: Color3): string
	return `<font color="{UI.hex(color)}">{text}</font>`
end

return UI
