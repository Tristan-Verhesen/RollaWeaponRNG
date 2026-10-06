--!strict
--[[
	Always-on HUD: status card, luck breakdown, menu, roll controls, Blessed Roll counter and
	active potion timers.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)
local GameConfig = require(Shared.Config.GameConfig)
local Ranks = require(Shared.Config.Ranks)
local Zones = require(Shared.Config.Zones)
local Products = require(Shared.Config.Products)
local Economy = require(Shared.Logic.Economy)
local Format = require(Shared.Util.Format)
local Theme = require(script.Parent.Theme)
local UI = require(script.Parent.UI)
local Screen = require(script.Parent.Screen)
local Components = require(script.Parent.Components)
local StateController = require(script.Parent.Parent.Controllers.StateController)
local RollController = require(script.Parent.Parent.Controllers.RollController)

type Snapshot = Types.Snapshot

export type Callbacks = {
	onMenu: (name: string) -> (),
}

local MENU = {
	{ name = "Armory", label = "Armory" },
	{ name = "Relics", label = "Relics" },
	{ name = "Chivalry", label = "Chivalry" },
	{ name = "Shop", label = "Market" },
}

local HUD = {}

local function statLine(parent: Instance, order: number, caption: string): TextLabel
	local row = UI.frame({
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 22),
		LayoutOrder = order,
		Parent = parent,
	})
	UI.label({
		Text = caption,
		TextColor3 = Theme.Colors.ParchmentDim,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.fromOffset(70, 22),
		Parent = row,
	})
	return UI.label({
		Text = "-",
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, -70, 1, 0),
		Position = UDim2.fromOffset(70, 0),
		Parent = row,
	})
end

function HUD.mount(callbacks: Callbacks)
	local layer = Screen.layer("HUD", 10)

	-- Status card ------------------------------------------------------------------------------
	local card = UI.frame({
		Name = "Status",
		Size = UDim2.fromOffset(300, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Position = UDim2.fromOffset(16, 16),
		BackgroundTransparency = 0.12,
		Parent = layer,
	})
	UI.corner(card, 8)
	UI.stroke(card, Theme.Colors.Trim, 1.5)
	UI.padding(card, 12)
	UI.list(card, Enum.FillDirection.Vertical, 2)

	local rankLabel = UI.label({
		Text = "Peasant",
		Font = Theme.Fonts.Title,
		TextSize = 34,
		TextColor3 = Theme.Colors.Gold,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, 36),
		LayoutOrder = 1,
		Parent = card,
	})
	local goldLabel = statLine(card, 2, "Gold")
	local luckLabel = statLine(card, 3, "Luck")
	local zoneLabel = statLine(card, 4, "Zone")
	local armoryLabel = statLine(card, 5, "Armory")

	local breakdownButton = UI.textButton({
		Text = "Luck breakdown ▸",
		BackgroundTransparency = 1,
		TextColor3 = Theme.Colors.Trim,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, 20),
		LayoutOrder = 6,
		Parent = card,
	})

	-- Luck breakdown ---------------------------------------------------------------------------
	local breakdown = UI.frame({
		Name = "LuckBreakdown",
		Size = UDim2.fromOffset(300, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Position = UDim2.fromOffset(326, 16),
		BackgroundTransparency = 0.08,
		Visible = false,
		Parent = layer,
	})
	UI.corner(breakdown, 8)
	UI.stroke(breakdown, Theme.Colors.Trim, 1.5)
	UI.padding(breakdown, 12)
	local breakdownText = UI.label({
		Text = "",
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.fromScale(1, 0),
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		LineHeight = 1.15,
		Parent = breakdown,
	})
	breakdownButton.Activated:Connect(function()
		breakdown.Visible = not breakdown.Visible
		breakdownButton.Text = if breakdown.Visible then "Luck breakdown ◂" else "Luck breakdown ▸"
	end)

	-- Menu -------------------------------------------------------------------------------------
	local menu = UI.frame({
		Name = "Menu",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(150, 220),
		Position = UDim2.new(0, 16, 0.5, 20),
		AnchorPoint = Vector2.new(0, 0.5),
		Parent = layer,
	})
	UI.list(menu, Enum.FillDirection.Vertical, 8)
	for index, entry in MENU do
		local button = Components.button({
			text = entry.label,
			size = UDim2.fromOffset(150, 46),
			font = Theme.Fonts.Title,
			textSize = 26,
			textColor = Theme.Colors.Gold,
			layoutOrder = index,
			parent = menu,
		})
		button.Activated:Connect(function()
			callbacks.onMenu(entry.name)
		end)
	end

	-- Roll cluster -----------------------------------------------------------------------------
	local cluster = UI.frame({
		Name = "RollCluster",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(560, 100),
		Position = UDim2.new(0.5, 0, 1, -24),
		AnchorPoint = Vector2.new(0.5, 1),
		Parent = layer,
	})

	local rollButton = Components.button({
		text = "",
		size = UDim2.fromOffset(280, 78),
		position = UDim2.fromScale(0.5, 0),
		anchor = Vector2.new(0.5, 0),
		color = Color3.fromRGB(92, 34, 28),
		parent = cluster,
	})
	local rollTitle = UI.label({
		Text = "ROLL",
		Font = Theme.Fonts.Title,
		TextSize = 46,
		TextColor3 = Theme.Colors.Gold,
		Size = UDim2.new(1, 0, 0, 50),
		Position = UDim2.fromOffset(0, 4),
		Parent = rollButton,
	})
	local rollSub = UI.label({
		Text = "",
		TextSize = 13,
		TextColor3 = Theme.Colors.ParchmentDim,
		Size = UDim2.new(1, 0, 0, 18),
		Position = UDim2.fromOffset(0, 54),
		Parent = rollButton,
	})
	rollButton.Activated:Connect(function()
		task.spawn(RollController.roll)
	end)

	local cooldown = Components.progressBar(cluster, UDim2.fromOffset(280, 8), Theme.Colors.Gold)
	cooldown.frame.Position = UDim2.new(0.5, 0, 0, 86)
	cooldown.frame.AnchorPoint = Vector2.new(0.5, 0)
	cooldown.set(1)

	local autoButton = Components.button({
		text = "Auto",
		size = UDim2.fromOffset(120, 56),
		position = UDim2.new(0.5, -150, 0, 11),
		anchor = Vector2.new(1, 0),
		textSize = 18,
		parent = cluster,
	})
	autoButton.Activated:Connect(function()
		RollController.setAuto(not RollController.isAuto())
	end)

	local blessed = UI.frame({
		Size = UDim2.fromOffset(120, 56),
		Position = UDim2.new(0.5, 150, 0, 11),
		BackgroundColor3 = Theme.Colors.IronRaised,
		Parent = cluster,
	})
	UI.corner(blessed)
	local blessedStroke = UI.stroke(blessed, Theme.Colors.Trim, 1.5, 0.25)
	local blessedLabel = UI.label({
		Text = "",
		TextSize = 15,
		Size = UDim2.fromScale(1, 1),
		Parent = blessed,
	})

	-- Boost timers -----------------------------------------------------------------------------
	local boosts = UI.frame({
		Name = "Boosts",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(260, 200),
		Position = UDim2.new(1, -16, 0, 16),
		AnchorPoint = Vector2.new(1, 0),
		Parent = layer,
	})
	UI.list(boosts, Enum.FillDirection.Vertical, 6, Enum.HorizontalAlignment.Right)
	local boostLabels: { [string]: TextLabel } = {}
	for index, potion in Products.Potions do
		local label = UI.label({
			Text = "",
			Size = UDim2.fromOffset(260, 30),
			BackgroundTransparency = 0.15,
			BackgroundColor3 = Theme.Colors.Iron,
			TextSize = 15,
			Visible = false,
			LayoutOrder = index,
			Parent = boosts,
		})
		UI.corner(label)
		UI.stroke(label, potion.color, 1.5)
		boostLabels[potion.id] = label
	end

	-- Updates ----------------------------------------------------------------------------------
	local function render(snapshot: Snapshot)
		local data = snapshot.data
		local stats = snapshot.stats
		local oaths = if data.Oaths > 0 then " " .. string.rep("✦", math.min(data.Oaths, 5)) else ""
		rankLabel.Text = Ranks.get(data.Rank).name .. oaths
		goldLabel.Text = UI.colorize(Format.commas(data.Gold), Theme.Colors.Gold)
		luckLabel.Text = Format.multiplier(math.floor(stats.luck * 100 + 0.5) / 100)
		local zone = Zones.ById[snapshot.zone]
		zoneLabel.Text = if zone then zone.name else snapshot.zone
		armoryLabel.Text = `{Format.commas(Economy.totalWeapons(data))} / {Format.commas(stats.capacity)}`

		local lines = { UI.colorize("<b>Luck sources</b>", Theme.Colors.Gold) }
		for _, part in stats.luckParts do
			local value = if part.kind == "add" then Format.percent(part.value) else Format.multiplier(part.value)
			table.insert(lines, `{UI.colorize(value, Theme.Colors.Gold)}  {part.label}`)
		end
		if #stats.luckParts == 0 then
			table.insert(
				lines,
				UI.colorize("None yet. Rise in rank, equip weapons and relics.", Theme.Colors.ParchmentDim)
			)
		end
		table.insert(lines, "")
		table.insert(
			lines,
			`{UI.colorize(Format.multiplier(GameConfig.BonusRoll.LuckMultiplier), Theme.Colors.Gold)}  Blessed Roll (every {GameConfig.BonusRoll.Every}th roll)`
		)
		table.insert(lines, "")
		table.insert(lines, UI.colorize("<b>Bad-luck protection</b>", Theme.Colors.Gold))
		for _, rule in GameConfig.Pity do
			local count = data.Pity[rule.rarity] or 0
			table.insert(lines, `{rule.rarity} guaranteed: {Format.commas(count)} / {Format.commas(rule.rolls)}`)
		end
		breakdownText.Text = table.concat(lines, "\n")

		rollSub.Text = `{Format.multiplier(math.floor(stats.luck * 100 + 0.5) / 100)} luck  ·  R to roll`

		if snapshot.passes.AutoRoll then
			autoButton.Text = if RollController.isAuto() then "Auto: <b>On</b>" else "Auto: Off"
		else
			autoButton.Text = "Auto 🔒"
		end

		local untilBonus = GameConfig.BonusRoll.Every - data.BonusRollCounter
		if untilBonus <= 1 then
			blessedLabel.Text = UI.colorize("<b>Next roll\nBLESSED</b>", Theme.Colors.Gold)
			blessedStroke.Color = Theme.Colors.Gold
			blessedStroke.Thickness = 3
		else
			blessedLabel.Text = `Blessed in\n<b>{untilBonus}</b>`
			blessedStroke.Color = Theme.Colors.Trim
			blessedStroke.Thickness = 1.5
		end
	end

	StateController.Changed:Connect(render)
	local initial = StateController.get()
	if initial then
		render(initial)
	end

	RollController.AutoChanged:Connect(function()
		local snapshot = StateController.get()
		if snapshot then
			render(snapshot)
		end
	end)

	RollController.CooldownStarted:Connect(function(_startedAt: number, duration: number)
		cooldown.set(0)
		TweenService
			:Create(cooldown.fill, TweenInfo.new(duration, Enum.EasingStyle.Linear), { Size = UDim2.fromScale(1, 1) })
			:Play()
	end)

	RollController.RollStarted:Connect(function()
		rollTitle.TextTransparency = 0.45
	end)
	RollController.RevealFinished:Connect(function()
		rollTitle.TextTransparency = 0
	end)

	task.spawn(function()
		while true do
			for _, potion in Products.Potions do
				local label = boostLabels[potion.id]
				local remaining = StateController.boostRemaining(potion.id)
				label.Visible = remaining > 0
				if remaining > 0 then
					local effect = if potion.luckMultiplier
						then Format.multiplier(potion.luckMultiplier) .. " luck"
						else Format.percent(potion.speedBonus or 0) .. " speed"
					label.Text = `{UI.colorize(potion.name, potion.color)}  {effect}  {Format.duration(remaining)}`
				end
			end
			task.wait(0.25)
		end
	end)
end

return HUD
