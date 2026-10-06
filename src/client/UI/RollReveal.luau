--!strict
--[[
	The roll reveal in the middle of the screen.

	Every roll cycles through weapon names from the zone pool before landing on the result.
	Rarer results add a cutscene: the screen darkens, a prelude line appears and the text
	trembles before the weapon is named.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)
local Rarities = require(Shared.Config.Rarities)
local Weapons = require(Shared.Config.Weapons)
local Relics = require(Shared.Config.Relics)
local Format = require(Shared.Util.Format)
local Theme = require(script.Parent.Theme)
local UI = require(script.Parent.UI)
local Screen = require(script.Parent.Screen)
local Components = require(script.Parent.Components)
local RollController = require(script.Parent.Parent.Controllers.RollController)

type RollResult = Types.RollResult
type CutsceneKind = Types.CutsceneKind

-- Keyed by CutsceneKind.
local PRELUDES: { [string]: { string } } = {
	None = { "" },
	Minor = { "Steel sings...", "A fine edge glints..." },
	Major = { "The heavens stir...", "A legend awakens...", "Bards will sing of this..." },
	Epic = { "THE STONE TREMBLES...", "THE ONCE AND FUTURE KING..." },
}

local OVERLAY_DARKNESS: { [string]: number } = {
	None = 1,
	Minor = 0.6,
	Major = 0.35,
	Epic = 0.12,
}

local HOLD_SECONDS = 2.4

local RollReveal = {}

function RollReveal.mount()
	local layer = Screen.layer("Reveal", 20)

	local overlay = UI.frame({
		Name = "Overlay",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Colors.Black,
		BackgroundTransparency = 1,
		Parent = layer,
	})

	local container = UI.frame({
		Name = "Reveal",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(760, 260),
		Position = UDim2.fromScale(0.5, 0.4),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Visible = false,
		Parent = layer,
	})
	local scale = UI.new("UIScale", { Parent = container }) :: UIScale

	local glow = UI.frame({
		Size = UDim2.new(1, 0, 0, 110),
		Position = UDim2.fromOffset(0, 20),
		BackgroundColor3 = Theme.Colors.Gold,
		BackgroundTransparency = 0.2,
		Parent = container,
	})
	local glowGradient = UI.new("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 0.55),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Parent = glow,
	}) :: UIGradient

	local prelude = UI.label({
		Text = "",
		Font = Theme.Fonts.Flavor,
		TextSize = 34,
		TextColor3 = Theme.Colors.Parchment,
		Size = UDim2.new(1, 0, 0, 40),
		Position = UDim2.fromOffset(0, -24),
		TextStrokeTransparency = 0.5,
		Parent = container,
	})

	local nameLabel = UI.label({
		Text = "",
		Font = Theme.Fonts.Title,
		TextSize = 72,
		TextStrokeTransparency = 0.2,
		TextStrokeColor3 = Theme.Colors.Black,
		Size = UDim2.new(1, 0, 0, 90),
		Position = UDim2.fromOffset(0, 30),
		Parent = container,
	})

	local rarityLabel = UI.label({
		Text = "",
		Font = Enum.Font.GothamBlack,
		TextSize = 22,
		TextStrokeTransparency = 0.4,
		Size = UDim2.new(1, 0, 0, 26),
		Position = UDim2.fromOffset(0, 120),
		Parent = container,
	})

	local chanceLabel = UI.label({
		Text = "",
		TextSize = 18,
		TextColor3 = Theme.Colors.Parchment,
		TextStrokeTransparency = 0.4,
		Size = UDim2.new(1, 0, 0, 22),
		Position = UDim2.fromOffset(0, 148),
		Parent = container,
	})

	local tags = UI.frame({
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 22),
		Position = UDim2.fromOffset(0, 178),
		Parent = container,
	})
	local tagLayout = UI.list(tags, Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Center)
	tagLayout.VerticalAlignment = Enum.VerticalAlignment.Center

	local extraLabel = UI.label({
		Text = "",
		TextSize = 17,
		TextColor3 = Theme.Colors.Parchment,
		TextStrokeTransparency = 0.4,
		Size = UDim2.new(1, 0, 0, 44),
		Position = UDim2.fromOffset(0, 206),
		Parent = container,
	})

	local rollId = 0
	local cycling = false

	local function setDetailsVisible(visible: boolean)
		rarityLabel.Visible = visible
		chanceLabel.Visible = visible
		tags.Visible = visible
		extraLabel.Visible = visible
	end

	RollController.RollStarted:Connect(function(result: RollResult, duration: number)
		rollId += 1
		local myId = rollId
		local weapon = Weapons.ById[result.weaponId]
		local rarity = Rarities.ById[result.rarity]
		if weapon == nil or rarity == nil then
			return
		end

		local pool = Weapons.ByZone[weapon.zone]
		local cutscene: CutsceneKind = rarity.cutscene
		-- Plain rolls cycle for most of the reveal; cutscenes cycle briefly, then build up.
		local cycleSeconds = if cutscene == "None" then duration * 0.85 else math.min(0.7, duration * 0.3)

		container.Visible = true
		container.Position = UDim2.fromScale(0.5, 0.4)
		scale.Scale = 1
		prelude.Text = ""
		glow.BackgroundTransparency = 1
		setDetailsVisible(false)
		nameLabel.TextTransparency = 0

		-- Phase 1: cycle names.
		cycling = true
		task.spawn(function()
			local started = os.clock()
			local interval = 0.035
			while cycling and rollId == myId and os.clock() - started < cycleSeconds do
				local pick = pool[math.random(1, #pool)]
				nameLabel.Text = pick.name
				nameLabel.TextColor3 = Rarities.fromChance(pick.chance).color
				task.wait(interval)
				interval = math.min(interval * 1.12, 0.14)
			end
			if rollId ~= myId or cutscene == "None" then
				return
			end

			-- Phase 2: cutscene build-up.
			cycling = false
			nameLabel.Text = ""
			local lines = PRELUDES[cutscene]
			prelude.Text = lines[math.random(1, #lines)]
			prelude.TextColor3 = rarity.color
			TweenService:Create(overlay, TweenInfo.new(0.5), { BackgroundTransparency = OVERLAY_DARKNESS[cutscene] })
				:Play()
			local shakeUntil = os.clock() + math.max(0, duration - cycleSeconds - 0.1)
			while rollId == myId and os.clock() < shakeUntil do
				local intensity = if cutscene == "Epic" then 6 elseif cutscene == "Major" then 3 else 1
				container.Position =
					UDim2.new(0.5, math.random(-intensity, intensity), 0.4, math.random(-intensity, intensity))
				task.wait(0.03)
			end
			container.Position = UDim2.fromScale(0.5, 0.4)
		end)
	end)

	RollController.RevealFinished:Connect(function(result: RollResult)
		cycling = false
		local myId = rollId
		local weapon = Weapons.ById[result.weaponId]
		local rarity = Rarities.ById[result.rarity]
		if weapon == nil or rarity == nil then
			return
		end

		prelude.Text = ""
		nameLabel.Text = weapon.name
		nameLabel.TextColor3 = rarity.color
		rarityLabel.Text = string.upper(rarity.name)
		rarityLabel.TextColor3 = rarity.color
		local effective = math.max(1, result.chance / math.max(result.luck, 1))
		chanceLabel.Text = if result.luck > 1.001
			then `{Format.chance(result.chance)}   <font color="{UI.hex(Theme.Colors.ParchmentDim)}">({Format.chance(
				effective
			)} at {Format.multiplier(math.floor(result.luck * 100) / 100)} luck)</font>`
			else Format.chance(result.chance)

		UI.clear(tags)
		if result.isNew then
			Components.tag(tags, "NEW", Theme.Colors.Gold)
		end
		if result.isBonusRoll then
			Components.tag(tags, "BLESSED ROLL", Theme.Colors.Parchment)
		end
		if result.pityRarity then
			Components.tag(tags, `{string.upper(result.pityRarity)} GUARANTEED`, Theme.Colors.Royal)
		end
		if result.autoSold then
			Components.tag(tags, "AUTO-SOLD", Theme.Colors.Muted)
		end

		local extras = {}
		if result.relicId then
			local relic = Relics.ById[result.relicId]
			if relic then
				local relicColor = Rarities.fromChance(relic.chance).color
				if result.relicIsNew then
					table.insert(
						extras,
						`Relic found: {UI.colorize(relic.name, relicColor)} ({Format.chance(relic.chance)})`
					)
				else
					table.insert(extras, `Duplicate {UI.colorize(relic.name, relicColor)} melted down`)
				end
			end
		end
		if result.goldGained > 0 then
			table.insert(extras, UI.colorize(`+{Format.commas(result.goldGained)} gold`, Theme.Colors.Gold))
		end
		extraLabel.Text = table.concat(extras, "   ·   ")
		setDetailsVisible(true)

		glow.BackgroundColor3 = rarity.color
		glow.BackgroundTransparency = if rarity.cutscene == "None" then 0.75 else 0.2
		glowGradient.Offset = Vector2.new(-1, 0)
		TweenService:Create(glowGradient, TweenInfo.new(0.6, Enum.EasingStyle.Quad), { Offset = Vector2.zero }):Play()

		scale.Scale = if rarity.cutscene == "None" then 1.12 else 1.45
		TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
			:Play()
		TweenService:Create(overlay, TweenInfo.new(0.9), { BackgroundTransparency = 1 }):Play()

		task.delay(HOLD_SECONDS, function()
			if rollId == myId and not RollController.isBusy() then
				container.Visible = false
			end
		end)
	end)
end

return RollReveal
