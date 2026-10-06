--!strict
--[[
	Requests rolls, paces auto-roll and times the reveal.

	Flow: InvokeServer("Roll") -> RollStarted(result, revealSeconds) -> wait -> RevealFinished.
	Snapshots are held during the reveal so nothing on screen spoils the result.
]]

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)
local GameConfig = require(Shared.Config.GameConfig)
local Products = require(Shared.Config.Products)
local Rarities = require(Shared.Config.Rarities)
local Net = require(Shared.Net)
local Signal = require(Shared.Util.Signal)
local StateController = require(script.Parent.StateController)
local Toasts = require(script.Parent.Parent.UI.Toasts)

type RollResult = Types.RollResult
type RollResponse = Types.RollResponse

-- Extra seconds of cutscene by rarity cutscene kind.
local CUTSCENE_SECONDS: { [Types.CutsceneKind]: number } = {
	None = 0,
	Minor = 0.6,
	Major = 1.8,
	Epic = 3.2,
}

local RollController = {
	RollStarted = Signal.new() :: Signal.Signal<RollResult, number>,
	RevealFinished = Signal.new() :: Signal.Signal<RollResult>,
	AutoChanged = Signal.new() :: Signal.Signal<boolean>,
	-- Fired with (startedAt, cooldownSeconds) so the HUD can draw a cooldown bar.
	CooldownStarted = Signal.new() :: Signal.Signal<number, number>,
}

local busy = false
local auto = false
local readyAt = 0

function RollController.revealDuration(result: RollResult, quick: boolean): number
	local base = if quick then GameConfig.Roll.QuickRevealDuration else GameConfig.Roll.RevealDuration
	local rarity = Rarities.ById[result.rarity]
	return base + (if rarity then CUTSCENE_SECONDS[rarity.cutscene] else 0)
end

function RollController.isBusy(): boolean
	return busy
end

function RollController.isAuto(): boolean
	return auto
end

function RollController.roll()
	if busy or os.clock() < readyAt then
		return
	end
	busy = true
	StateController.hold()

	local remote = Net.fn("Roll")
	local ok, response = pcall(remote.InvokeServer, remote)
	local rollResponse: RollResponse? = if ok and type(response) == "table" then response else nil

	if rollResponse == nil or not rollResponse.ok or rollResponse.result == nil then
		StateController.release()
		busy = false
		if rollResponse and rollResponse.reason == "cooldown" then
			readyAt = os.clock() + math.max(rollResponse.cooldown, 0.05)
		elseif rollResponse and rollResponse.reason then
			Toasts.notify(rollResponse.reason, "warning")
			readyAt = os.clock() + 1
		else
			readyAt = os.clock() + 1
		end
		return
	end

	local result = rollResponse.result :: RollResult
	local startedAt = os.clock()
	readyAt = startedAt + rollResponse.cooldown
	RollController.CooldownStarted:Fire(startedAt, rollResponse.cooldown)

	local snapshot = StateController.get()
	local quick = snapshot ~= nil and snapshot.passes.QuickRoll == true
	local reveal = RollController.revealDuration(result, quick)
	RollController.RollStarted:Fire(result, reveal)
	task.wait(reveal)

	StateController.release()
	RollController.RevealFinished:Fire(result)
	busy = false
end

function RollController.setAuto(enabled: boolean)
	if enabled then
		local snapshot = StateController.get()
		if snapshot == nil or not snapshot.passes.AutoRoll then
			local pass = Products.PassByKey.AutoRoll
			if pass.id ~= 0 then
				MarketplaceService:PromptGamePassPurchase(Players.LocalPlayer, pass.id)
			else
				Toasts.notify("Auto-Roll needs the Squire's Diligence pass (not yet on sale).", "info")
			end
			return
		end
	end
	if auto == enabled then
		return
	end
	auto = enabled
	RollController.AutoChanged:Fire(auto)
	if auto then
		task.spawn(function()
			while auto do
				if not busy and os.clock() >= readyAt then
					RollController.roll()
				else
					task.wait(0.03)
				end
			end
		end)
	end
end

function RollController.start()
	-- Losing the pass (or rejoining without it) turns auto-roll off.
	StateController.Changed:Connect(function(snapshot)
		if auto and not snapshot.passes.AutoRoll then
			RollController.setAuto(false)
		end
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.R then
			RollController.roll()
		elseif input.KeyCode == Enum.KeyCode.T then
			RollController.setAuto(not auto)
		end
	end)
end

return RollController
