--!strict
--[[
	Notifications (bottom right) and rare-roll proclamations (top banner + chat line).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)
local Rarities = require(Shared.Config.Rarities)
local Weapons = require(Shared.Config.Weapons)
local Format = require(Shared.Util.Format)
local Theme = require(script.Parent.Theme)
local UI = require(script.Parent.UI)
local Screen = require(script.Parent.Screen)

type NotifyKind = Types.NotifyKind
type Announcement = Types.Announcement

local KIND_COLORS: { [NotifyKind]: Color3 } = {
	info = Theme.Colors.Royal,
	success = Theme.Colors.Verdant,
	warning = Theme.Colors.Gold,
	error = Theme.Colors.Crimson,
}

local TOAST_SECONDS = 3.5
local BANNER_SECONDS = 6

local Toasts = {}

local stack: Frame? = nil
local bannerQueue: { Announcement } = {}
local bannerBusy = false

local function getStack(): Frame
	if stack then
		return stack
	end
	local layer = Screen.layer("Toasts", 40)
	local frame = UI.frame({
		Name = "Toasts",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(360, 400),
		Position = UDim2.new(1, -16, 1, -130),
		AnchorPoint = Vector2.new(1, 1),
		Parent = layer,
	})
	local layout = UI.list(frame, Enum.FillDirection.Vertical, 6, Enum.HorizontalAlignment.Right)
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	stack = frame
	return frame
end

function Toasts.notify(message: string, kind: NotifyKind?)
	local resolved: NotifyKind = kind or "info"
	local color = KIND_COLORS[resolved]
	local toast = UI.frame({
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.fromOffset(340, 0),
		BackgroundColor3 = Theme.Colors.Iron,
		BackgroundTransparency = 0.08,
		LayoutOrder = math.floor(os.clock() * 100),
		Parent = getStack(),
	})
	UI.corner(toast)
	UI.stroke(toast, color, 1.5)
	UI.padding(toast, 10)
	local accent = UI.frame({
		Size = UDim2.new(0, 4, 1, 0),
		Position = UDim2.fromOffset(-6, 0),
		BackgroundColor3 = color,
		Parent = toast,
	})
	UI.corner(accent, 2)
	local label = UI.label({
		Text = message,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.fromScale(1, 0),
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = toast,
	})

	task.delay(TOAST_SECONDS, function()
		local fade = TweenInfo.new(0.35)
		TweenService:Create(toast, fade, { BackgroundTransparency = 1 }):Play()
		TweenService:Create(label, fade, { TextTransparency = 1 }):Play()
		task.wait(0.35)
		toast:Destroy()
	end)
end

local function chatLine(text: string)
	pcall(function()
		local channels = TextChatService:FindFirstChild("TextChannels")
		local general = channels and channels:FindFirstChild("RBXGeneral")
		if general and general:IsA("TextChannel") then
			general:DisplaySystemMessage(text)
		end
	end)
end

local function showNextBanner()
	if bannerBusy or #bannerQueue == 0 then
		return
	end
	bannerBusy = true
	local announcement = table.remove(bannerQueue, 1) :: Announcement
	local weapon = Weapons.ById[announcement.weaponId]
	if weapon == nil then
		bannerBusy = false
		showNextBanner()
		return
	end
	local rarity = Rarities.fromChance(weapon.chance)

	local prefix = if announcement.global then "Across the realm, " else ""
	local text = `{prefix}{announcement.playerName} has drawn {UI.colorize(weapon.name, rarity.color)} `
		.. `<font size="18">({Format.chance(weapon.chance)})</font>`

	local layer = Screen.layer("Banner", 45)
	local banner = UI.frame({
		Size = UDim2.fromOffset(760, 64),
		Position = UDim2.new(0.5, 0, 0, -80),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Theme.Colors.Iron,
		BackgroundTransparency = 0.05,
		Parent = layer,
	})
	UI.corner(banner, 8)
	UI.stroke(banner, rarity.color, 2.5)
	UI.label({
		Text = text,
		Size = UDim2.fromScale(1, 1),
		Font = Theme.Fonts.Flavor,
		TextSize = 24,
		Parent = banner,
	})

	chatLine(`[Herald] {text}`)

	local slide = TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	TweenService:Create(banner, slide, { Position = UDim2.new(0.5, 0, 0, 72) }):Play()
	task.delay(BANNER_SECONDS, function()
		local out = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		TweenService:Create(banner, out, { Position = UDim2.new(0.5, 0, 0, -80) }):Play()
		task.wait(0.4)
		banner:Destroy()
		bannerBusy = false
		showNextBanner()
	end)
end

function Toasts.announce(announcement: Announcement)
	table.insert(bannerQueue, announcement)
	showNextBanner()
end

return Toasts
