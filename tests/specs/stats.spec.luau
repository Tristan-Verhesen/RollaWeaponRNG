local Stats = require(Shared.Logic.Stats)
local DataTemplate = require(Shared.DataTemplate)
local GameConfig = require(Shared.Config.GameConfig)
local Products = require(Shared.Config.Products)
local Relics = require(Shared.Config.Relics)

local NO_PASSES = {}

describe("Stats.compute", function()
	it("starts a fresh peasant at exactly x1 luck", function()
		local stats = Stats.compute(DataTemplate.new(), "Hamlet", NO_PASSES)
		expect(stats.luck).toBeCloseTo(1)
		expect(stats.cooldown).toBeCloseTo(GameConfig.Roll.BaseCooldown)
		expect(stats.goldMultiplier).toBeCloseTo(1)
		expect(stats.capacity).toBe(GameConfig.Inventory.BaseCapacity)
		expect(stats.relicSlots).toBe(1)
		expect(#stats.luckParts).toBe(0)
	end)

	it("adds rank and zone bonuses", function()
		local data = DataTemplate.new()
		data.Rank = 5 -- Knight, +25%
		local stats = Stats.compute(data, "Crypts", NO_PASSES) -- +20%
		expect(stats.luck).toBeCloseTo(1.45)
	end)

	it("multiplies oaths, the luck pass and luck potions", function()
		local data = DataTemplate.new()
		data.Oaths = 2 -- x2
		data.ActiveBoosts.Fortune = 120 -- x2
		local stats = Stats.compute(data, "Hamlet", { LuckyBlessing = true }) -- x2
		expect(stats.luck).toBeCloseTo(8)
	end)

	it("ignores expired boosts", function()
		local data = DataTemplate.new()
		data.ActiveBoosts.Fortune = 0
		expect(Stats.compute(data, "Hamlet", NO_PASSES).luck).toBeCloseTo(1)
	end)

	it("uses the rarity's default bonus for an equipped weapon", function()
		local data = DataTemplate.new()
		data.Weapons.hamlet_iron_longsword = 1 -- 1 in 25, Uncommon: +2%
		data.EquippedWeapon = "hamlet_iron_longsword"
		expect(Stats.compute(data, "Hamlet", NO_PASSES).luck).toBeCloseTo(1.02)
	end)

	it("uses a weapon's own bonus when it has one", function()
		local data = DataTemplate.new()
		data.Weapons.citadel_oathkeeper = 1 -- explicit +25% luck
		data.EquippedWeapon = "citadel_oathkeeper"
		expect(Stats.compute(data, "Hamlet", NO_PASSES).luck).toBeCloseTo(1.25)
	end)

	it("ignores an equipped weapon the player no longer owns", function()
		local data = DataTemplate.new()
		data.EquippedWeapon = "citadel_oathkeeper"
		expect(Stats.compute(data, "Hamlet", NO_PASSES).luck).toBeCloseTo(1)
	end)

	it("limits equipped relics to owned ones within the rank's slot count", function()
		local data = DataTemplate.new()
		data.Relics.hamlet_horseshoe = 1
		data.Relics.hamlet_charter = 1
		data.EquippedRelics = { "hamlet_charter", "hamlet_horseshoe", "citadel_holy_grail" }
		-- Peasant has one slot: only the Village Charter (+15%) counts.
		expect(Stats.compute(data, "Hamlet", NO_PASSES).luck).toBeCloseTo(1.15)
		data.Rank = 3 -- Squire, two slots, +10%
		expect(Stats.compute(data, "Hamlet", NO_PASSES).luck).toBeCloseTo(1 + 0.10 + 0.15 + 0.05)
	end)

	it("grants a zone's set bonus once all its relics are found", function()
		local data = DataTemplate.new()
		for _, relic in Relics.ByZone.Hamlet do
			data.Relics[relic.id] = 1
		end
		expect(Stats.isSetComplete("Hamlet", data.Relics)).toBe(true)
		expect(Stats.isSetComplete("Darkwood", data.Relics)).toBe(false)
		expect(Stats.compute(data, "Hamlet", NO_PASSES).luck).toBeCloseTo(1.05)
	end)

	it("speeds up rolls with speed bonuses and the Quick Roll pass, down to the floor", function()
		local data = DataTemplate.new()
		data.ActiveBoosts.Haste = 60 -- +35% speed
		local base = GameConfig.Roll.BaseCooldown
		expect(Stats.compute(data, "Hamlet", NO_PASSES).cooldown).toBeCloseTo(base / 1.35)
		local quick = Stats.compute(data, "Hamlet", { QuickRoll = true }).cooldown
		expect(quick).toBeCloseTo(
			math.max(GameConfig.Roll.MinCooldown, base / 1.35 * Products.QuickRollCooldownMultiplier)
		)
		expect(quick).toBeGreaterThanOrEqual(GameConfig.Roll.MinCooldown)
	end)

	it("adds armory capacity for the Royal Armory pass", function()
		local stats = Stats.compute(DataTemplate.new(), "Hamlet", { RoyalArmory = true })
		expect(stats.capacity).toBe(GameConfig.Inventory.BaseCapacity + Products.RoyalArmoryCapacity)
	end)
end)
