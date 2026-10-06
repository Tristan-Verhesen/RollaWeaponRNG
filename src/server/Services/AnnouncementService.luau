--!strict
--[[
	Rare roll announcements.

	>= GameConfig.Announcements.ServerMinChance: banner + chat line for everyone in this server.
	>= GameConfig.Announcements.GlobalMinChance: also broadcast to every server via
	   MessagingService, where it shows as a realm-wide proclamation.
]]

local MessagingService = game:GetService("MessagingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Types = require(Shared.Types)
local GameConfig = require(Shared.Config.GameConfig)
local Weapons = require(Shared.Config.Weapons)
local Net = require(Shared.Net)

type Announcement = Types.Announcement
type RollResult = Types.RollResult

local AnnouncementService = {}

local function broadcastLocal(announcement: Announcement)
	Net.event("Announce"):FireAllClients(announcement)
end

function AnnouncementService.onRoll(player: Player, result: RollResult)
	local config = GameConfig.Announcements
	if result.chance < config.ServerMinChance then
		return
	end

	broadcastLocal({
		playerName = player.DisplayName,
		weaponId = result.weaponId,
		chance = result.chance,
		global = false,
	})

	if result.chance >= config.GlobalMinChance then
		task.spawn(function()
			local ok, err = pcall(MessagingService.PublishAsync, MessagingService, config.Topic, {
				playerName = player.DisplayName,
				weaponId = result.weaponId,
				jobId = game.JobId,
			})
			if not ok then
				warn(`[AnnouncementService] Publish failed: {err}`)
			end
		end)
	end
end

function AnnouncementService.start()
	task.spawn(function()
		local ok, err = pcall(
			MessagingService.SubscribeAsync,
			MessagingService,
			GameConfig.Announcements.Topic,
			function(message)
				local payload = message.Data
				if type(payload) ~= "table" or payload.jobId == game.JobId then
					return
				end
				local weapon = Weapons.ById[payload.weaponId]
				if weapon == nil or type(payload.playerName) ~= "string" then
					return
				end
				broadcastLocal({
					playerName = string.sub(payload.playerName, 1, 40),
					weaponId = weapon.id,
					chance = weapon.chance,
					global = true,
				})
			end
		)
		if not ok then
			-- Expected in unpublished places / some Studio sessions.
			warn(`[AnnouncementService] Cross-server announcements disabled: {err}`)
		end
	end)
end

return AnnouncementService
