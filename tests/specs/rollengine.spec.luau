local RollEngine = require(Shared.Logic.RollEngine)
local DataTemplate = require(Shared.DataTemplate)
local GameConfig = require(Shared.Config.GameConfig)
local Weapons = require(Shared.Config.Weapons)
local Rarities = require(Shared.Config.Rarities)

local ALWAYS_FAIL = TestKit.constantRng(0.999999)

local function context(overrides)
	local ctx = { zoneId = "Hamlet", luck = 1, goldMultiplier = 1, capacity = 10_000 }
	for key, value in overrides or {} do
		ctx[key] = value
	end
	return ctx
end

local function mostCommon(zoneId)
	local pool = Weapons.ByZone[zoneId]
	return pool[#pool]
end

describe("RollEngine.roll", function()
	it("counts rolls and stores the weapon", function()
		local data = DataTemplate.new()
		local result = RollEngine.roll(data, context(), ALWAYS_FAIL)
		expect(result.weaponId).toBe(mostCommon("Hamlet").id)
		expect(result.isNew).toBe(true)
		expect(data.TotalRolls).toBe(1)
		expect(data.RollsThisOath).toBe(1)
		expect(data.Weapons[result.weaponId]).toBe(1)
		expect(data.Discovered[result.weaponId]).toBe(true)
	end)

	it("blesses every tenth roll with double luck", function()
		local data = DataTemplate.new()
		local blessed = {}
		for roll = 1, 30 do
			local result = RollEngine.roll(data, context({ luck = 1.5 }), ALWAYS_FAIL)
			if result.isBonusRoll then
				table.insert(blessed, roll)
				expect(result.luck).toBeCloseTo(1.5 * GameConfig.BonusRoll.LuckMultiplier)
			else
				expect(result.luck).toBeCloseTo(1.5)
			end
		end
		expect(blessed).toEqual({ 10, 20, 30 })
	end)

	it("reports rolls until the next blessed roll", function()
		local data = DataTemplate.new()
		expect(RollEngine.roll(data, context(), ALWAYS_FAIL).rollsUntilBonus).toBe(9)
		for _ = 1, 8 do
			RollEngine.roll(data, context(), ALWAYS_FAIL)
		end
		local tenth = RollEngine.roll(data, context(), ALWAYS_FAIL)
		expect(tenth.isBonusRoll).toBe(true)
		expect(tenth.rollsUntilBonus).toBe(GameConfig.BonusRoll.Every)
	end)

	it("forces a Rare on the pity roll and resets the counter", function()
		local data = DataTemplate.new()
		local rule = GameConfig.Pity[1]
		expect(rule.rarity).toBe("Rare")
		for roll = 1, rule.rolls - 1 do
			local result = RollEngine.roll(data, context(), ALWAYS_FAIL)
			expect(result.pityRarity).toBeNil()
		end
		expect(data.Pity.Rare).toBe(rule.rolls - 1)
		local pityRoll = RollEngine.roll(data, context(), ALWAYS_FAIL)
		expect(pityRoll.pityRarity).toBe("Rare")
		expect(Rarities.indexOf(pityRoll.rarity) >= Rarities.indexOf("Rare")).toBe(true)
		expect(data.Pity.Rare).toBe(0)
	end)

	it("forces the highest due pity tier", function()
		local data = DataTemplate.new()
		data.Pity.Rare = 10_000
		data.Pity.Epic = GameConfig.Pity[2].rolls - 1
		local result = RollEngine.roll(data, context(), ALWAYS_FAIL)
		expect(result.pityRarity).toBe("Epic")
		expect(data.Pity.Rare).toBe(0)
		expect(data.Pity.Epic).toBe(0)
	end)

	it("never downgrades a natural roll for pity", function()
		local data = DataTemplate.new()
		data.Pity.Rare = 10_000
		-- rng 0 hits the rarest weapon in the pool immediately.
		local result = RollEngine.roll(data, context(), TestKit.constantRng(0))
		expect(result.weaponId).toBe(Weapons.ByZone.Hamlet[1].id)
		expect(result.pityRarity).toBeNil()
	end)

	it("resets lower pity counters on a natural high roll", function()
		local data = DataTemplate.new()
		data.Pity.Rare = 50
		RollEngine.roll(data, context(), TestKit.constantRng(0))
		expect(data.Pity.Rare).toBe(0)
	end)

	it("never auto-sells the first copy", function()
		local data = DataTemplate.new()
		data.Settings.AutoSellMaxRarity = 4
		local result = RollEngine.roll(data, context(), ALWAYS_FAIL)
		expect(result.autoSold).toBe(false)
		expect(data.Weapons[result.weaponId]).toBe(1)
	end)

	it("auto-sells duplicates at or below the player's chosen rarity", function()
		local data = DataTemplate.new()
		data.Settings.AutoSellMaxRarity = 1
		RollEngine.roll(data, context(), ALWAYS_FAIL)
		local result = RollEngine.roll(data, context(), ALWAYS_FAIL)
		expect(result.autoSold).toBe(true)
		expect(result.goldGained).toBeGreaterThan(0)
		expect(data.Weapons[result.weaponId]).toBe(1)
		expect(data.Gold).toBe(result.goldGained)
	end)

	it("auto-sells duplicates when the armory is full, except protected rarities", function()
		local data = DataTemplate.new()
		local common = mostCommon("Hamlet").id
		data.Weapons[common] = 5
		local result = RollEngine.roll(data, context({ capacity = 5 }), ALWAYS_FAIL)
		expect(result.autoSold).toBe(true)
		expect(data.Weapons[common]).toBe(5)

		local legendary = "hamlet_harvest_scythe" -- 1 in 20,000
		expect(Rarities.fromChance(Weapons.ById[legendary].chance).id).toBe("Legendary")
		data.Weapons[legendary] = 1
		data.Pity.Legendary = GameConfig.Pity[3].rolls -- force a Legendary via pity
		local forced = RollEngine.roll(data, context({ capacity = 5 }), ALWAYS_FAIL)
		expect(forced.weaponId).toBe(legendary)
		expect(forced.autoSold).toBe(false)
		expect(data.Weapons[legendary]).toBe(2)
	end)

	it("tracks the best roll", function()
		local data = DataTemplate.new()
		RollEngine.roll(data, context(), ALWAYS_FAIL)
		expect(data.BestRollId).toBe(mostCommon("Hamlet").id)
		RollEngine.roll(data, context(), TestKit.constantRng(0))
		expect(data.BestRollId).toBe(Weapons.ByZone.Hamlet[1].id)
		RollEngine.roll(data, context(), ALWAYS_FAIL)
		expect(data.BestRollId).toBe(Weapons.ByZone.Hamlet[1].id)
	end)

	it("finds relics and melts duplicates into gold", function()
		local data = DataTemplate.new()
		-- rng 0 hits the rarest weapon and then the rarest relic.
		local first = RollEngine.roll(data, context(), TestKit.constantRng(0))
		expect(first.relicId).toBe("hamlet_charter")
		expect(first.relicIsNew).toBe(true)
		expect(data.Relics.hamlet_charter).toBe(1)
		expect(data.Stats.RelicsFound).toBe(1)

		local goldBefore = data.Gold
		local second = RollEngine.roll(data, context(), TestKit.constantRng(0))
		expect(second.relicIsNew).toBe(false)
		expect(second.goldGained).toBeGreaterThan(0)
		expect(data.Gold).toBe(goldBefore + second.goldGained)
		expect(data.Relics.hamlet_charter).toBe(1)
	end)

	it("rolls only from the current zone's pool", function()
		local data = DataTemplate.new()
		local rng = TestKit.seededRng(2024)
		for _ = 1, 300 do
			local result = RollEngine.roll(data, context({ zoneId = "Citadel" }), rng)
			expect(Weapons.ById[result.weaponId].zone).toBe("Citadel")
		end
	end)
end)
