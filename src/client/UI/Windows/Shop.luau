--!strict
--[[
	Market: gamepasses ("Royal Charters") and potions ("Apothecary").
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)
local Products = require(Shared.Config.Products)
local Format = require(Shared.Util.Format)
local Theme = require(script.Parent.Parent.Theme)
local UI = require(script.Parent.Parent.UI)
local Components = require(script.Parent.Parent.Components)
local Actions = require(script.Parent.Parent.Parent.Actions)
local StateController = require(script.Parent.Parent.Parent.Controllers.StateController)

type Snapshot = Types.Snapshot

local Shop = {}

local function sectionTitle(parent: Instance, text: string, order: number)
	UI.label({
		Text = text,
		Font = Theme.Fonts.Title,
		TextSize = 30,
		TextColor3 = Theme.Colors.Gold,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, 34),
		LayoutOrder = order,
		Parent = parent,
	})
end

local function cardGrid(parent: Instance, order: number, columns: number, height: number): Frame
	local grid = UI.frame({
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = order,
		Parent = parent,
	})
	UI.new("UIGridLayout", {
		CellSize = UDim2.new(1 / columns, -8, 0, height),
		CellPadding = UDim2.fromOffset(8, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = grid,
	})
	return grid
end

local function card(parent: Instance, order: number, title: string, color: Color3, body: string): Frame
	local frame = UI.frame({
		BackgroundColor3 = Theme.Colors.IronRaised,
		LayoutOrder = order,
		Parent = parent,
	})
	UI.corner(frame, 8)
	UI.padding(frame, 10)
	UI.stroke(frame, color, 1.5, 0.3)
	UI.label({
		Text = title,
		Font = Theme.Fonts.Flavor,
		TextSize = 20,
		TextColor3 = color,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, 26),
		Parent = frame,
	})
	UI.label({
		Text = body,
		TextSize = 14,
		TextColor3 = Theme.Colors.ParchmentDim,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Size = UDim2.new(1, 0, 1, -70),
		Position = UDim2.fromOffset(0, 28),
		Parent = frame,
	})
	return frame
end

function Shop.create(parent: Instance): Components.WindowModule
	local window = Components.window(parent, "The Market", UDim2.fromOffset(900, 580))

	local scroll = UI.scroll({
		Size = UDim2.fromScale(1, 1),
		Parent = window.content,
	})
	UI.list(scroll, Enum.FillDirection.Vertical, 10)
	UI.new("UIPadding", { PaddingRight = UDim.new(0, 10), Parent = scroll })

	local function render(snapshot: Snapshot)
		UI.clear(scroll)

		sectionTitle(scroll, "Royal Charters", 1)
		local passGrid = cardGrid(scroll, 2, 2, 130)
		for index, pass in Products.GamePasses do
			local frame = card(passGrid, index, pass.name, Theme.Colors.Gold, pass.description)
			local owned = snapshot.passes[pass.key] == true
			local available = pass.id ~= 0
			local button = Components.button({
				text = if owned then "Owned" elseif available then "Purchase" else "Coming soon",
				size = UDim2.new(1, 0, 0, 34),
				position = UDim2.new(0, 0, 1, -34),
				color = if owned
					then Theme.Colors.Verdant
					elseif available then Theme.Colors.Royal
					else Theme.Colors.IronHover,
				parent = frame,
			})
			Components.setEnabled(button, available and not owned)
			button.Activated:Connect(function()
				if button.Active then
					MarketplaceService:PromptGamePassPurchase(Players.LocalPlayer, pass.id)
				end
			end)
		end

		sectionTitle(scroll, "The Apothecary", 3)
		local potionGrid = cardGrid(scroll, 4, 3, 150)
		for index, potion in Products.Potions do
			local stock = snapshot.data.Potions[potion.id] or 0
			local remaining = StateController.boostRemaining(potion.id)
			local body = potion.description .. `\nIn your satchel: {UI.colorize(tostring(stock), Theme.Colors.Gold)}`
			if remaining > 0 then
				body ..= `  ·  active {Format.duration(remaining)}`
			end
			local frame = card(potionGrid, index, potion.name, potion.color, body)

			local drink = Components.button({
				text = "Drink",
				size = UDim2.new(0.5, -4, 0, 34),
				position = UDim2.new(0, 0, 1, -34),
				color = Theme.Colors.Verdant,
				parent = frame,
			})
			Components.setEnabled(drink, stock > 0)
			drink.Activated:Connect(function()
				if drink.Active then
					Actions.call("UsePotion", potion.id)
				end
			end)

			local available = potion.productId ~= 0
			local buy = Components.button({
				text = if available then "Buy" else "Soon",
				size = UDim2.new(0.5, -4, 0, 34),
				position = UDim2.new(0.5, 4, 1, -34),
				color = if available then Theme.Colors.Royal else Theme.Colors.IronHover,
				parent = frame,
			})
			Components.setEnabled(buy, available)
			buy.Activated:Connect(function()
				if buy.Active then
					MarketplaceService:PromptProductPurchase(Players.LocalPlayer, potion.productId)
				end
			end)
		end
	end

	return { window = window, refresh = render }
end

return Shop
