--!strict
--[[
	Armory and relic management: selling, equipping, auto-sell settings.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Types = require(Shared.Types)
local GameConfig = require(Shared.Config.GameConfig)
local Rarities = require(Shared.Config.Rarities)
local Weapons = require(Shared.Config.Weapons)
local Relics = require(Shared.Config.Relics)
local Economy = require(Shared.Logic.Economy)
local Stats = require(Shared.Logic.Stats)
local Format = require(Shared.Util.Format)
local DataService = require(script.Parent.DataService)
local StateService = require(script.Parent.StateService)
local CharacterService = require(script.Parent.CharacterService)
local Remote = require(script.Parent.Parent.Util.Remote)
local Validate = require(script.Parent.Parent.Util.Validate)

type ActionResponse = Types.ActionResponse

local InventoryService = {}

local NOT_LOADED: ActionResponse = { ok = false, message = "Your save is still loading." }
local BAD_REQUEST: ActionResponse = { ok = false, message = "That request made no sense, good sir." }

local function rarityIndexOf(weaponId: string): number
	local weapon = Weapons.ById[weaponId]
	return if weapon then Rarities.indexFromChance(weapon.chance) else 0
end

local function goldMultiplier(player: Player): number
	local stats = StateService.getStats(player)
	return if stats then stats.goldMultiplier else 1
end

local function sellWeapon(player: Player, weaponId: unknown, amount: unknown): ActionResponse
	local data = DataService.getData(player)
	if data == nil then
		return NOT_LOADED
	end
	if not Validate.string(weaponId) or not Validate.integer(amount, 1, 1_000_000) then
		return BAD_REQUEST
	end
	local id = weaponId :: string
	local weapon = Weapons.ById[id]
	if weapon == nil or (data.Weapons[id] or 0) <= 0 then
		return { ok = false, message = "You do not own that weapon." }
	end

	local gold, sold = Economy.sellWeapon(data, id, amount :: number, goldMultiplier(player))
	if sold == 0 then
		return { ok = false, message = "You cannot sell the weapon in your hand. Unequip it first." }
	end
	StateService.markDirty(player)
	return { ok = true, message = `Sold {sold}x {weapon.name} for {Format.commas(gold)} gold.` }
end

local function sellDuplicates(player: Player, maxRarity: unknown): ActionResponse
	local data = DataService.getData(player)
	if data == nil then
		return NOT_LOADED
	end
	if not Validate.integer(maxRarity, 1, #Rarities.List) then
		return BAD_REQUEST
	end

	local gold, sold = Economy.sellDuplicates(data, maxRarity :: number, goldMultiplier(player), rarityIndexOf)
	if sold == 0 then
		return { ok = false, message = "No duplicates to sell." }
	end
	StateService.markDirty(player)
	return { ok = true, message = `Sold {Format.commas(sold)} duplicates for {Format.commas(gold)} gold.` }
end

local function equipWeapon(player: Player, weaponId: unknown): ActionResponse
	local data = DataService.getData(player)
	if data == nil then
		return NOT_LOADED
	end
	if not Validate.string(weaponId) then
		return BAD_REQUEST
	end
	local id = weaponId :: string
	if id ~= "" and (Weapons.ById[id] == nil or (data.Weapons[id] or 0) <= 0) then
		return { ok = false, message = "You do not own that weapon." }
	end

	data.EquippedWeapon = id
	StateService.markDirty(player)
	CharacterService.refreshWeapon(player)
	if id == "" then
		return { ok = true, message = "Weapon sheathed." }
	end
	return { ok = true, message = `You now wield {Weapons.ById[id].name}.` }
end

local function setRelicEquipped(player: Player, relicId: unknown, equipped: unknown): ActionResponse
	local data = DataService.getData(player)
	if data == nil then
		return NOT_LOADED
	end
	if not Validate.string(relicId) or not Validate.boolean(equipped) then
		return BAD_REQUEST
	end
	local id = relicId :: string
	local relic = Relics.ById[id]
	if relic == nil or (data.Relics[id] or 0) <= 0 then
		return { ok = false, message = "You have not found that relic." }
	end

	-- Drop stale entries (relics no longer owned, or beyond the slot count after an Oath).
	data.EquippedRelics = Stats.validEquippedRelics(data)
	local index = table.find(data.EquippedRelics, id)

	if equipped then
		if index then
			return { ok = true }
		end
		if #data.EquippedRelics >= Stats.relicSlots(data.Rank) then
			return { ok = false, message = "All relic slots are filled. Rise in rank to carry more." }
		end
		table.insert(data.EquippedRelics, id)
	elseif index then
		table.remove(data.EquippedRelics, index)
	end

	StateService.markDirty(player)
	return { ok = true }
end

local function setAutoSell(player: Player, maxRarity: unknown): ActionResponse
	local data = DataService.getData(player)
	if data == nil then
		return NOT_LOADED
	end
	if not Validate.integer(maxRarity, 0, GameConfig.Inventory.MaxAutoSellRarity) then
		return BAD_REQUEST
	end
	data.Settings.AutoSellMaxRarity = maxRarity :: number
	StateService.markDirty(player)
	return { ok = true }
end

function InventoryService.start()
	Remote.bind("SellWeapon", {}, sellWeapon)
	Remote.bind("SellDuplicates", { rate = 1, burst = 3 }, sellDuplicates)
	Remote.bind("EquipWeapon", { rate = 2, burst = 4 }, equipWeapon)
	Remote.bind("SetRelicEquipped", {}, setRelicEquipped)
	Remote.bind("SetAutoSell", { rate = 2, burst = 4 }, setAutoSell)
end

return InventoryService
