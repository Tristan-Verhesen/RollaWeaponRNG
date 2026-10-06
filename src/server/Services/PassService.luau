--!strict
--[[
	Gamepass ownership and developer product (potion) purchases.

	Gamepasses: ownership is checked on join and cached; buying one mid-session updates the
	cache immediately. Products: receipts are granted at most once per PurchaseId, and Roblox
	is only told "granted" after the grant has been saved (ProfileStore's recommended pattern).
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Types = require(Shared.Types)
local GameConfig = require(Shared.Config.GameConfig)
local Products = require(Shared.Config.Products)
local Signal = require(Shared.Util.Signal)
local Net = require(Shared.Net)
local DataService = require(script.Parent.DataService)

type PassOwnership = Types.PassOwnership
type Profile = DataService.Profile

local PassService = {
	-- Fired when a player's pass ownership or potion stock changes.
	Changed = Signal.new() :: Signal.Signal<Player>,
}

local owned: { [Player]: PassOwnership } = {}

local function grantAllInStudio(): boolean
	return RunService:IsStudio() and GameConfig.Debug.GrantAllPassesInStudio
end

local function refreshOwnership(player: Player)
	local passes: PassOwnership = {}
	for _, pass in Products.GamePasses do
		if grantAllInStudio() then
			passes[pass.key] = true
		elseif pass.id ~= 0 then
			local ok, result =
				pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, pass.id)
			passes[pass.key] = ok and result == true
		end
	end
	if player.Parent == Players then
		owned[player] = passes
		PassService.Changed:Fire(player)
	end
end

function PassService.getPasses(player: Player): PassOwnership
	return owned[player] or {}
end

function PassService.owns(player: Player, key: Types.GamePassKey): boolean
	local passes = owned[player]
	return passes ~= nil and passes[key] == true
end

-- Yields until the profile has durably saved `purchaseId`, granting the product once.
local function purchaseIdCheckAsync(profile: Profile, purchaseId: string, grant: () -> ()): Enum.ProductPurchaseDecision
	if not profile:IsActive() then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local cache = profile.Data.PurchaseIdCache
	if not table.find(cache, purchaseId) then
		local granted = xpcall(grant, function(err)
			warn(`[PassService] Failed to grant purchase {purchaseId} for {profile.Key}: {err}`)
		end)
		if not granted then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		while #cache >= GameConfig.DataStore.PurchaseIdCacheSize do
			table.remove(cache, 1)
		end
		table.insert(cache, purchaseId)
	end

	local function isSaved(): boolean
		local saved = profile.LastSavedData.PurchaseIdCache
		return saved ~= nil and table.find(saved, purchaseId) ~= nil
	end

	-- Ask for a save, then poll until it lands or the session ends.
	profile:Save()
	local nextSaveRequest = os.clock() + 10
	while profile:IsActive() do
		if isSaved() then
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
		if os.clock() >= nextSaveRequest then
			profile:Save()
			nextSaveRequest = os.clock() + 10
		end
		task.wait(0.25)
	end
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

local function processReceipt(receipt: { [string]: any }): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if player == nil then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local potion = Products.PotionByProductId[receipt.ProductId]
	if potion == nil then
		warn(`[PassService] No handler for product {receipt.ProductId}`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	-- The receipt can arrive before the profile finishes loading.
	DataService.waitForData(player)
	local profile = DataService.getProfile(player)
	if profile == nil then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local decision = purchaseIdCheckAsync(profile, tostring(receipt.PurchaseId), function()
		local potions = profile.Data.Potions
		potions[potion.id] = (potions[potion.id] or 0) + 1
	end)

	if decision == Enum.ProductPurchaseDecision.PurchaseGranted and player.Parent == Players then
		PassService.Changed:Fire(player)
		Net.event("Notify"):FireClient(player, `{potion.name} added to your satchel!`, "success")
	end
	return decision
end

function PassService.start()
	MarketplaceService.ProcessReceipt = processReceipt

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gamePassId, purchased)
		if not purchased then
			return
		end
		for _, pass in Products.GamePasses do
			if pass.id == gamePassId then
				local passes = owned[player] or {}
				passes[pass.key] = true
				owned[player] = passes
				PassService.Changed:Fire(player)
				Net.event("Notify"):FireClient(player, `{pass.name} unlocked. Long may you reign!`, "success")
			end
		end
	end)

	Players.PlayerAdded:Connect(refreshOwnership)
	Players.PlayerRemoving:Connect(function(player)
		owned[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(refreshOwnership, player)
	end
end

return PassService
