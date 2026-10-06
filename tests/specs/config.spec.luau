-- Sanity checks on game content so a typo in config fails CI instead of a live server.

local Rarities = require(Shared.Config.Rarities)
local Weapons = require(Shared.Config.Weapons)
local Relics = require(Shared.Config.Relics)
local Zones = require(Shared.Config.Zones)
local Ranks = require(Shared.Config.Ranks)
local Products = require(Shared.Config.Products)
local GameConfig = require(Shared.Config.GameConfig)

describe("Rarities", function()
	it("are ordered by ascending minChance", function()
		for index = 2, #Rarities.List do
			expect(Rarities.List[index].minChance).toBeGreaterThan(Rarities.List[index - 1].minChance)
		end
	end)

	it("maps chances onto the right tier at the boundaries", function()
		expect(Rarities.fromChance(1).id).toBe("Common")
		expect(Rarities.fromChance(9).id).toBe("Common")
		expect(Rarities.fromChance(10).id).toBe("Uncommon")
		expect(Rarities.fromChance(999).id).toBe("Rare")
		expect(Rarities.fromChance(1_000).id).toBe("Epic")
		expect(Rarities.fromChance(1_000_000).id).toBe("Exalted")
		expect(Rarities.fromChance(1e12).id).toBe("Exalted")
	end)

	it("indexes rarities by id", function()
		expect(Rarities.indexOf("Common")).toBe(1)
		expect(Rarities.indexOf("Exalted")).toBe(#Rarities.List)
		expect(Rarities.indexOf("Nope")).toBe(0)
	end)
end)

describe("Weapons", function()
	it("has about sixty weapons across five zones", function()
		expect(#Weapons.List).toBe(60)
		expect(#Zones.List).toBe(5)
	end)

	it("every weapon belongs to a real zone and has valid odds", function()
		for _, weapon in Weapons.List do
			expect(Zones.ById[weapon.zone] ~= nil).toBe(true)
			expect(weapon.chance).toBeGreaterThanOrEqual(1)
			expect(#weapon.name).toBeGreaterThan(0)
			expect(#weapon.description).toBeGreaterThan(0)
		end
	end)

	it("every zone pool is sorted rarest first and starts with a common", function()
		for _, zone in Zones.List do
			local pool = Weapons.ByZone[zone.id]
			expect(pool ~= nil).toBe(true)
			expect(#pool).toBeGreaterThanOrEqual(8)
			for index = 2, #pool do
				expect(pool[index].chance).toBeLessThan(pool[index - 1].chance)
			end
			expect(Rarities.fromChance(pool[#pool].chance).id).toBe("Common")
		end
	end)

	it("every zone can satisfy the Rare and Epic pity rules", function()
		for _, zone in Zones.List do
			local hasRare, hasEpic = false, false
			for _, weapon in Weapons.ByZone[zone.id] do
				hasRare = hasRare or weapon.chance >= Rarities.ById.Rare.minChance
				hasEpic = hasEpic or weapon.chance >= Rarities.ById.Epic.minChance
			end
			expect(hasRare).toBe(true)
			expect(hasEpic).toBe(true)
		end
	end)

	it("Excalibur is the rarest weapon in the realm", function()
		local rarest = Weapons.List[1]
		for _, weapon in Weapons.List do
			if weapon.chance > rarest.chance then
				rarest = weapon
			end
		end
		expect(rarest.id).toBe("citadel_excalibur")
	end)
end)

describe("Relics", function()
	it("every zone has four relics", function()
		for _, zone in Zones.List do
			expect(#Relics.ByZone[zone.id]).toBe(4)
		end
	end)

	it("every relic grants some bonus", function()
		for _, relic in Relics.List do
			local bonus = relic.bonus
			expect((bonus.luck or 0) + (bonus.gold or 0) + (bonus.speed or 0)).toBeGreaterThan(0)
		end
	end)
end)

describe("Ranks", function()
	it("has the ten-step chivalric ladder", function()
		expect(Ranks.Max).toBe(10)
		expect(Ranks.List[1].name).toBe("Peasant")
		expect(Ranks.List[10].name).toBe("King")
	end)

	it("requirements and rewards never decrease", function()
		for index = 2, #Ranks.List do
			local previous, current = Ranks.List[index - 1], Ranks.List[index]
			expect(current.rollsRequired).toBeGreaterThan(previous.rollsRequired)
			expect(current.goldCost).toBeGreaterThan(previous.goldCost)
			expect(current.luckBonus).toBeGreaterThan(previous.luckBonus)
			expect(current.relicSlots).toBeGreaterThanOrEqual(previous.relicSlots)
		end
	end)

	it("every zone is reachable", function()
		for _, zone in Zones.List do
			expect(zone.requiredRank).toBeGreaterThanOrEqual(1)
			expect(zone.requiredRank <= Ranks.Max).toBe(true)
		end
		expect(Zones.ById[Zones.Default].requiredRank).toBe(1)
	end)
end)

describe("GameConfig", function()
	it("pity rules reference real rarities in ascending order", function()
		local lastIndex = 0
		for _, rule in GameConfig.Pity do
			local index = Rarities.indexOf(rule.rarity)
			expect(index).toBeGreaterThan(lastIndex)
			lastIndex = index
		end
	end)

	it("protected rarity exists", function()
		expect(Rarities.indexOf(GameConfig.Inventory.ProtectedRarity)).toBeGreaterThan(0)
	end)

	it("reveal animations fit inside the cooldowns they pair with", function()
		expect(GameConfig.Roll.RevealDuration <= GameConfig.Roll.BaseCooldown).toBe(true)
		expect(
			GameConfig.Roll.QuickRevealDuration <= GameConfig.Roll.BaseCooldown * Products.QuickRollCooldownMultiplier
		).toBe(true)
	end)
end)

describe("Products", function()
	it("has unique pass keys and potion ids", function()
		local seen = {}
		for _, pass in Products.GamePasses do
			expect(seen[pass.key]).toBeNil()
			seen[pass.key] = true
		end
		for _, potion in Products.Potions do
			expect(seen[potion.id]).toBeNil()
			seen[potion.id] = true
			expect(potion.duration).toBeGreaterThan(0)
		end
	end)
end)
