local Progression = require(Shared.Logic.Progression)
local Economy = require(Shared.Logic.Economy)
local Stats = require(Shared.Logic.Stats)
local DataTemplate = require(Shared.DataTemplate)
local GameConfig = require(Shared.Config.GameConfig)
local Ranks = require(Shared.Config.Ranks)
local Rarities = require(Shared.Config.Rarities)
local Weapons = require(Shared.Config.Weapons)

local function rarityIndexOf(weaponId)
	return Rarities.indexFromChance(Weapons.ById[weaponId].chance)
end

describe("Economy", function()
	it("values weapons by N ^ exponent and zone multiplier", function()
		local hamlet = Weapons.ById.hamlet_iron_longsword -- 1 in 25, Hamlet x1
		local expected = math.floor(25 ^ GameConfig.Economy.SellExponent)
		expect(Economy.weaponValue(hamlet.id, 1)).toBe(expected)
		expect(Economy.weaponValue(hamlet.id, 2)).toBe(math.floor(25 ^ GameConfig.Economy.SellExponent * 2))
		-- The same odds are worth more in a richer zone.
		expect(Economy.weaponValue("citadel_pike", 1)).toBeGreaterThan(Economy.weaponValue("hamlet_splintered_club", 1))
	end)

	it("never sells the equipped weapon's last copy", function()
		local data = DataTemplate.new()
		data.Weapons.hamlet_iron_longsword = 3
		data.EquippedWeapon = "hamlet_iron_longsword"
		local gold, sold = Economy.sellWeapon(data, "hamlet_iron_longsword", 99, 1)
		expect(sold).toBe(2)
		expect(gold).toBeGreaterThan(0)
		expect(data.Weapons.hamlet_iron_longsword).toBe(1)
		expect(data.Gold).toBe(gold)
		expect(data.Stats.GoldEarned).toBe(gold)
	end)

	it("removes a stack entirely when every copy is sold", function()
		local data = DataTemplate.new()
		data.Weapons.hamlet_rusty_dagger = 2
		Economy.sellWeapon(data, "hamlet_rusty_dagger", 2, 1)
		expect(data.Weapons.hamlet_rusty_dagger).toBeNil()
	end)

	it("sells duplicates down to one copy, respecting the rarity cap", function()
		local data = DataTemplate.new()
		data.Weapons.hamlet_rusty_dagger = 10 -- Common
		data.Weapons.hamlet_smith_hammer = 4 -- Rare
		local _, sold = Economy.sellDuplicates(data, Rarities.indexOf("Uncommon"), 1, rarityIndexOf)
		expect(sold).toBe(9)
		expect(data.Weapons.hamlet_rusty_dagger).toBe(1)
		expect(data.Weapons.hamlet_smith_hammer).toBe(4)
	end)

	it("counts total copies", function()
		local data = DataTemplate.new()
		data.Weapons.a = 3
		data.Weapons.b = 4
		expect(Economy.totalWeapons(data)).toBe(7)
	end)
end)

describe("Progression", function()
	it("requires rolls and gold to rank up", function()
		local data = DataTemplate.new()
		local serf = Ranks.List[2]
		local ok, reason = Progression.canRankUp(data)
		expect(ok).toBe(false)
		expect(reason ~= nil).toBe(true)

		data.RollsThisOath = serf.rollsRequired
		expect((Progression.canRankUp(data))).toBe(false)

		data.Gold = serf.goldCost + 5
		expect((Progression.canRankUp(data))).toBe(true)
		Progression.rankUp(data)
		expect(data.Rank).toBe(2)
		expect(data.Gold).toBe(5)
	end)

	it("unlocks zones when their rank is reached, permanently", function()
		local data = DataTemplate.new()
		data.Rank = 2
		data.RollsThisOath = 1e9
		data.Gold = 1e12
		local unlocked = Progression.rankUp(data) -- Squire
		expect(unlocked).toEqual({ "Darkwood" })
		expect(data.UnlockedZones.Darkwood).toBe(true)

		data.Rank = Ranks.Max
		Progression.takeOath(data)
		expect(data.Rank).toBe(1)
		expect(data.UnlockedZones.Darkwood).toBe(true)
	end)

	it("only lets a King swear an Oath, which resets the climb", function()
		local data = DataTemplate.new()
		expect((Progression.canTakeOath(data))).toBe(false)
		data.Rank = Ranks.Max
		data.Gold = 1234
		data.RollsThisOath = 99_999
		data.TotalRolls = 99_999
		data.Weapons.citadel_excalibur = 1
		data.EquippedRelics = { "a", "b", "c", "d", "e" }
		expect((Progression.canTakeOath(data))).toBe(true)
		Progression.takeOath(data)
		expect(data.Oaths).toBe(1)
		expect(data.Rank).toBe(1)
		expect(data.Gold).toBe(0)
		expect(data.RollsThisOath).toBe(0)
		expect(data.TotalRolls).toBe(99_999)
		expect(data.Weapons.citadel_excalibur).toBe(1)
		expect(#data.EquippedRelics).toBe(Ranks.List[1].relicSlots)
		expect(Stats.oathMultiplier(data.Oaths)).toBeCloseTo(1 + GameConfig.Oath.LuckPerOath)
	end)

	it("scales rank costs with oaths", function()
		local base = Progression.rankCost(5, 0)
		expect(Progression.rankCost(5, 2)).toBe(math.floor(base * (1 + 2 * GameConfig.Oath.GoldCostScalePerOath)))
	end)
end)
