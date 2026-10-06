--!strict
--[[
	Chivalry: the rank ladder, rising in rank, swearing Oaths, and lifetime deeds.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)
local GameConfig = require(Shared.Config.GameConfig)
local Ranks = require(Shared.Config.Ranks)
local Weapons = require(Shared.Config.Weapons)
local Zones = require(Shared.Config.Zones)
local Relics = require(Shared.Config.Relics)
local Rarities = require(Shared.Config.Rarities)
local Progression = require(Shared.Logic.Progression)
local Stats = require(Shared.Logic.Stats)
local Format = require(Shared.Util.Format)
local Theme = require(script.Parent.Parent.Theme)
local UI = require(script.Parent.Parent.UI)
local Components = require(script.Parent.Parent.Components)
local Actions = require(script.Parent.Parent.Parent.Actions)

type Snapshot = Types.Snapshot

local Chivalry = {}

local function zonesUnlockedAt(rankIndex: number): { string }
	local names = {}
	for _, zone in Zones.List do
		if zone.requiredRank == rankIndex and rankIndex > 1 then
			table.insert(names, zone.name)
		end
	end
	return names
end

function Chivalry.create(parent: Instance): Components.WindowModule
	local window = Components.window(parent, "Chivalry", UDim2.fromOffset(900, 580))
	local content = window.content

	-- Left column: next rank + oath + deeds ----------------------------------------------------
	local left = UI.frame({
		BackgroundTransparency = 1,
		Size = UDim2.new(0, 420, 1, 0),
		Parent = content,
	})

	local current = UI.label({
		Text = "",
		Font = Theme.Fonts.Title,
		TextSize = 44,
		TextColor3 = Theme.Colors.Gold,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, 50),
		Parent = left,
	})

	local nextCard = UI.frame({
		BackgroundColor3 = Theme.Colors.IronRaised,
		Size = UDim2.new(1, 0, 0, 190),
		Position = UDim2.fromOffset(0, 56),
		Parent = left,
	})
	UI.corner(nextCard, 8)
	UI.padding(nextCard, 12)
	local nextTitle = UI.label({
		Text = "",
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, 24),
		Parent = nextCard,
	})
	local nextPerks = UI.label({
		Text = "",
		TextSize = 14,
		TextColor3 = Theme.Colors.ParchmentDim,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, 36),
		Position = UDim2.fromOffset(0, 26),
		Parent = nextCard,
	})
	local rollsBar = Components.progressBar(nextCard, UDim2.new(1, 0, 0, 22), Theme.Colors.Royal)
	rollsBar.frame.Position = UDim2.fromOffset(0, 66)
	local goldBar = Components.progressBar(nextCard, UDim2.new(1, 0, 0, 22), Theme.Colors.Gold)
	goldBar.frame.Position = UDim2.fromOffset(0, 94)
	local riseButton = Components.button({
		text = "Rise",
		size = UDim2.new(1, 0, 0, 40),
		position = UDim2.new(0, 0, 1, -40),
		color = Color3.fromRGB(92, 34, 28),
		font = Theme.Fonts.Title,
		textSize = 28,
		textColor = Theme.Colors.Gold,
		parent = nextCard,
	})

	local oathCard = UI.frame({
		BackgroundColor3 = Theme.Colors.IronRaised,
		Size = UDim2.new(1, 0, 0, 120),
		Position = UDim2.fromOffset(0, 254),
		Parent = left,
	})
	UI.corner(oathCard, 8)
	UI.padding(oathCard, 12)
	local oathText = UI.label({
		Text = "",
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Size = UDim2.new(1, 0, 1, -44),
		Parent = oathCard,
	})
	local oathButton = Components.button({
		text = "Swear an Oath",
		size = UDim2.new(1, 0, 0, 38),
		position = UDim2.new(0, 0, 1, -38),
		color = Theme.Colors.Royal,
		font = Theme.Fonts.Title,
		textSize = 24,
		parent = oathCard,
	})

	local deeds = UI.label({
		Text = "",
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		LineHeight = 1.15,
		Size = UDim2.new(1, 0, 1, -384),
		Position = UDim2.fromOffset(0, 384),
		Parent = left,
	})

	-- Right column: ladder ---------------------------------------------------------------------
	local ladder = UI.scroll({
		Size = UDim2.new(1, -440, 1, 0),
		Position = UDim2.fromOffset(440, 0),
		Parent = content,
	})
	UI.list(ladder, Enum.FillDirection.Vertical, 6)
	UI.new("UIPadding", { PaddingRight = UDim.new(0, 10), Parent = ladder })

	local confirmOath = false

	local function render(snapshot: Snapshot)
		local data = snapshot.data
		local rank = Ranks.get(data.Rank)
		local oathStars = if data.Oaths > 0 then " " .. string.rep("✦", math.min(data.Oaths, 5)) else ""
		current.Text = rank.name .. oathStars

		if data.Rank < Ranks.Max then
			local nextIndex = data.Rank + 1
			local nextRank = Ranks.get(nextIndex)
			local cost = Progression.rankCost(nextIndex, data.Oaths)
			nextTitle.Text = `Next: {UI.colorize(nextRank.name, Theme.Colors.Gold)}`
			local perks = { `{Format.percent(nextRank.luckBonus)} luck`, `{nextRank.relicSlots} relic slots` }
			for _, zoneName in zonesUnlockedAt(nextIndex) do
				table.insert(perks, `opens {zoneName}`)
			end
			nextPerks.Text = table.concat(perks, "  ·  ")
			rollsBar.set(
				data.RollsThisOath / math.max(nextRank.rollsRequired, 1),
				`Rolls {Format.commas(math.min(data.RollsThisOath, nextRank.rollsRequired))} / {Format.commas(
					nextRank.rollsRequired
				)}`
			)
			goldBar.set(
				data.Gold / math.max(cost, 1),
				`Gold {Format.commas(math.min(data.Gold, cost))} / {Format.commas(cost)}`
			)
			rollsBar.frame.Visible = true
			goldBar.frame.Visible = true
			riseButton.Visible = true
			riseButton.Text = `Rise to {nextRank.name}`
			Components.setEnabled(riseButton, (Progression.canRankUp(data)))
		else
			nextTitle.Text = UI.colorize("You stand at the summit of chivalry.", Theme.Colors.Gold)
			nextPerks.Text = "Swear an Oath to begin the climb anew, stronger than before."
			rollsBar.frame.Visible = false
			goldBar.frame.Visible = false
			riseButton.Visible = false
		end

		local nextOathMultiplier = Stats.oathMultiplier(data.Oaths + 1)
		local canOath = (Progression.canTakeOath(data))
		oathText.Text = table.concat({
			`Oaths sworn: {UI.colorize(tostring(data.Oaths), Theme.Colors.Gold)}  ·  current {Format.multiplier(
				Stats.oathMultiplier(data.Oaths)
			)} luck`,
			`An Oath resets your rank and gold for a permanent {UI.colorize(
				Format.multiplier(nextOathMultiplier),
				Theme.Colors.Gold
			)} luck. Your armory, relics and opened zones remain.`,
		}, "\n")
		oathButton.Text = if confirmOath then "Confirm: swear the Oath" else "Swear an Oath"
		Components.setEnabled(oathButton, canOath)
		if not canOath then
			oathButton.Text = `Requires {Ranks.get(Ranks.Max).name}`
		end

		local discovered = 0
		for weaponId in data.Discovered do
			if Weapons.ById[weaponId] then
				discovered += 1
			end
		end
		local best = Weapons.ById[data.BestRollId]
		local bestText = if best
			then `{UI.colorize(best.name, Rarities.fromChance(best.chance).color)} ({Format.chance(best.chance)})`
			else "none yet"
		deeds.Text = table.concat({
			UI.colorize("<b>Deeds</b>", Theme.Colors.Gold),
			`Total rolls: {Format.commas(data.TotalRolls)}`,
			`Finest roll: {bestText}`,
			`Weapons discovered: {discovered} / {#Weapons.List}`,
			`Relics found: {data.Stats.RelicsFound} / {#Relics.List}`,
			`Gold earned: {Format.commas(data.Stats.GoldEarned)}`,
			`Time in the realm: {Format.duration(data.Stats.PlaySeconds)}`,
			`Blessed Roll: {Format.multiplier(GameConfig.BonusRoll.LuckMultiplier)} luck every {GameConfig.BonusRoll.Every} rolls`,
		}, "\n")

		UI.clear(ladder)
		for index, entry in Ranks.List do
			local reached = index <= data.Rank
			local isCurrent = index == data.Rank
			local row = UI.frame({
				BackgroundColor3 = if isCurrent then Theme.Colors.IronHover else Theme.Colors.IronRaised,
				Size = UDim2.new(1, 0, 0, 46),
				LayoutOrder = index,
				Parent = ladder,
			})
			UI.corner(row, 6)
			if isCurrent then
				UI.stroke(row, Theme.Colors.Gold, 2)
			end
			UI.label({
				Text = entry.name,
				Font = Theme.Fonts.Title,
				TextSize = 26,
				TextColor3 = if reached then Theme.Colors.Gold else Theme.Colors.Muted,
				TextXAlignment = Enum.TextXAlignment.Left,
				Size = UDim2.new(0.45, 0, 1, 0),
				Position = UDim2.fromOffset(12, 0),
				Parent = row,
			})
			local perks = { `{Format.percent(entry.luckBonus)} luck`, `{entry.relicSlots} slots` }
			for _, zoneName in zonesUnlockedAt(index) do
				table.insert(perks, zoneName)
			end
			UI.label({
				Text = table.concat(perks, "  ·  "),
				TextSize = 13,
				TextColor3 = if reached then Theme.Colors.Parchment else Theme.Colors.Muted,
				TextXAlignment = Enum.TextXAlignment.Right,
				Size = UDim2.new(0.55, -24, 1, 0),
				Position = UDim2.new(0.45, 12, 0, 0),
				Parent = row,
			})
		end
	end

	riseButton.Activated:Connect(function()
		if riseButton.Active then
			Actions.call("RankUp")
		end
	end)

	oathButton.Activated:Connect(function()
		if not oathButton.Active then
			return
		end
		if not confirmOath then
			confirmOath = true
			oathButton.Text = "Confirm: swear the Oath"
			task.delay(4, function()
				confirmOath = false
			end)
			return
		end
		confirmOath = false
		Actions.call("TakeOath")
	end)

	return { window = window, refresh = render }
end

return Chivalry
