--!strict
--[[
	Relics: four per zone. Equip found relics into your slots; find a zone's full set for its
	permanent set bonus.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)
local Rarities = require(Shared.Config.Rarities)
local Relics = require(Shared.Config.Relics)
local Zones = require(Shared.Config.Zones)
local Stats = require(Shared.Logic.Stats)
local Format = require(Shared.Util.Format)
local Theme = require(script.Parent.Parent.Theme)
local UI = require(script.Parent.Parent.UI)
local Components = require(script.Parent.Parent.Components)
local Actions = require(script.Parent.Parent.Parent.Actions)

type Snapshot = Types.Snapshot
type Bonus = Types.Bonus

local RelicsWindow = {}

local function bonusText(bonus: Bonus): string
	local parts = {}
	if bonus.luck then
		table.insert(parts, `{Format.percent(bonus.luck)} luck`)
	end
	if bonus.gold then
		table.insert(parts, `{Format.percent(bonus.gold)} gold`)
	end
	if bonus.speed then
		table.insert(parts, `{Format.percent(bonus.speed)} speed`)
	end
	return table.concat(parts, ", ")
end

function RelicsWindow.create(parent: Instance): Components.WindowModule
	local window = Components.window(parent, "Relics", UDim2.fromOffset(900, 580))
	local content = window.content

	local slotsLabel = UI.label({
		Text = "",
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, 24),
		Parent = content,
	})

	local list = UI.scroll({
		Size = UDim2.new(1, 0, 1, -32),
		Position = UDim2.fromOffset(0, 32),
		Parent = content,
	})
	UI.list(list, Enum.FillDirection.Vertical, 10)
	UI.new("UIPadding", { PaddingRight = UDim.new(0, 10), Parent = list })

	local function render(snapshot: Snapshot)
		local data = snapshot.data
		local equipped = Stats.validEquippedRelics(data)
		slotsLabel.Text = `Relic slots: {UI.colorize(`{#equipped} / {snapshot.stats.relicSlots}`, Theme.Colors.Gold)}`
			.. UI.colorize("   ·   Rise in rank to carry more relics.", Theme.Colors.ParchmentDim)

		UI.clear(list)
		for zoneIndex, zone in Zones.List do
			local pool: { Types.RelicDef } = Relics.ByZone[zone.id] or {}
			local found = 0
			for _, relic in pool do
				if (data.Relics[relic.id] or 0) > 0 then
					found += 1
				end
			end
			local complete = Stats.isSetComplete(zone.id, data.Relics)

			local section = UI.frame({
				BackgroundColor3 = Theme.Colors.IronRaised,
				Size = UDim2.new(1, 0, 0, 176),
				LayoutOrder = zoneIndex,
				Parent = list,
			})
			UI.corner(section, 8)
			UI.padding(section, 10)
			if complete then
				UI.stroke(section, Theme.Colors.Gold, 2)
			end

			local setText = `Set bonus: {bonusText(zone.setBonus)}`
			UI.label({
				Text = `{UI.colorize(zone.name, zone.accentColor:Lerp(Theme.Colors.Parchment, 0.4))}   `
					.. UI.colorize(
						`{found}/{#pool} found  ·  {setText}{if complete then "  (active)" else ""}`,
						if complete then Theme.Colors.Gold else Theme.Colors.ParchmentDim
					),
				Font = Theme.Fonts.Body,
				TextSize = 17,
				TextXAlignment = Enum.TextXAlignment.Left,
				Size = UDim2.new(1, 0, 0, 24),
				Parent = section,
			})

			local grid = UI.frame({
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 1, -30),
				Position = UDim2.fromOffset(0, 30),
				Parent = section,
			})
			UI.new("UIGridLayout", {
				CellSize = UDim2.new(0.25, -8, 1, 0),
				CellPadding = UDim2.fromOffset(8, 0),
				SortOrder = Enum.SortOrder.LayoutOrder,
				Parent = grid,
			})

			for relicIndex, relic in pool do
				local owned = (data.Relics[relic.id] or 0) > 0
				local isEquipped = table.find(equipped, relic.id) ~= nil
				local rarity = Rarities.fromChance(relic.chance)

				local card = UI.frame({
					BackgroundColor3 = Theme.Colors.Iron,
					LayoutOrder = -relicIndex,
					Parent = grid,
				})
				UI.corner(card, 6)
				UI.padding(card, 8)
				UI.stroke(
					card,
					if isEquipped then Theme.Colors.Gold else rarity.color,
					if isEquipped then 2 else 1,
					0.3
				)

				UI.label({
					Text = if owned then relic.name else "???",
					TextColor3 = if owned then rarity.color else Theme.Colors.Muted,
					Font = Theme.Fonts.Flavor,
					TextSize = 17,
					Size = UDim2.new(1, 0, 0, 40),
					Parent = card,
				})
				UI.label({
					Text = `{Format.chance(relic.chance)}\n{UI.colorize(bonusText(relic.bonus), Theme.Colors.Gold)}`,
					TextSize = 13,
					Size = UDim2.new(1, 0, 0, 36),
					Position = UDim2.fromOffset(0, 40),
					Parent = card,
				})

				if owned then
					local button = Components.button({
						text = if isEquipped then "Unequip" else "Equip",
						size = UDim2.new(1, 0, 0, 28),
						position = UDim2.new(0, 0, 1, -28),
						color = if isEquipped then Theme.Colors.IronHover else Theme.Colors.Royal,
						textSize = 14,
						parent = card,
					})
					button.Activated:Connect(function()
						Actions.call("SetRelicEquipped", relic.id, not isEquipped)
					end)
				end
			end
		end
	end

	return { window = window, refresh = render }
end

return RelicsWindow
