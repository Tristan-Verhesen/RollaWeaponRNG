--!strict
--[[
	Character dressing: the equipped weapon (as an undroppable Tool held in hand) and the
	overhead chivalric title ("Knight / PlayerName").
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Ranks = require(Shared.Config.Ranks)
local Rarities = require(Shared.Config.Rarities)
local Weapons = require(Shared.Config.Weapons)
local WeaponModels = require(Shared.WeaponModels)
local DataService = require(script.Parent.DataService)

local WEAPON_ATTRIBUTE = "RollaWeaponId"
local TITLE_NAME = "ChivalricTitle"

local TITLE_GOLD = Color3.fromRGB(232, 196, 104)
local PARCHMENT = Color3.fromRGB(240, 230, 206)

local CharacterService = {}

local function removeWeaponTools(player: Player)
	local containers: { Instance? } = { player.Character, player:FindFirstChildOfClass("Backpack") }
	for _, container in containers do
		if container then
			for _, child in container:GetChildren() do
				if child:IsA("Tool") and child:GetAttribute(WEAPON_ATTRIBUTE) ~= nil then
					child:Destroy()
				end
			end
		end
	end
end

local function buildTool(weaponId: string): Tool?
	local weapon = Weapons.ById[weaponId]
	local model = WeaponModels.build(weaponId)
	if weapon == nil or model == nil then
		return nil
	end

	local tool = Instance.new("Tool")
	tool.Name = weapon.name
	tool.ToolTip = Rarities.fromChance(weapon.chance).name
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool:SetAttribute(WEAPON_ATTRIBUTE, weaponId)

	local handle = model.PrimaryPart
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.CanCollide = false
			descendant.Massless = true
		end
	end
	for _, child in model:GetChildren() do
		child.Parent = tool
	end
	if handle then
		handle.Name = "Handle"
		handle.Parent = tool
	end
	model:Destroy()
	return tool
end

function CharacterService.refreshWeapon(player: Player)
	removeWeaponTools(player)

	local data = DataService.getData(player)
	local character = player.Character
	if data == nil or character == nil or data.EquippedWeapon == "" then
		return
	end

	local tool = buildTool(data.EquippedWeapon)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if tool == nil or humanoid == nil then
		return
	end
	tool.Parent = player:FindFirstChildOfClass("Backpack") or character
	humanoid:EquipTool(tool)
end

local function label(parent: Instance, name: string, position: UDim2, size: UDim2, font: Enum.Font): TextLabel
	local text = Instance.new("TextLabel")
	text.Name = name
	text.BackgroundTransparency = 1
	text.Position = position
	text.Size = size
	text.Font = font
	text.TextScaled = true
	text.TextStrokeTransparency = 0.4
	text.TextStrokeColor3 = Color3.new(0, 0, 0)
	text.Parent = parent
	return text
end

function CharacterService.refreshTitle(player: Player)
	local data = DataService.getData(player)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if data == nil or head == nil then
		return
	end

	local gui = head:FindFirstChild(TITLE_NAME)
	if gui == nil then
		local billboard = Instance.new("BillboardGui")
		billboard.Name = TITLE_NAME
		billboard.Size = UDim2.fromOffset(220, 54)
		billboard.StudsOffset = Vector3.new(0, 2.6, 0)
		billboard.MaxDistance = 90
		billboard.LightInfluence = 0
		label(billboard, "Rank", UDim2.fromScale(0, 0), UDim2.fromScale(1, 0.52), Enum.Font.GrenzeGotisch)
		label(billboard, "PlayerName", UDim2.fromScale(0, 0.52), UDim2.fromScale(1, 0.48), Enum.Font.Fondamento)
		billboard.Parent = head
		gui = billboard
	end
	assert(gui, "title billboard was just created")

	local rankLabel = gui:FindFirstChild("Rank") :: TextLabel?
	local nameLabel = gui:FindFirstChild("PlayerName") :: TextLabel?
	if rankLabel then
		local oaths = if data.Oaths > 0 then " " .. string.rep("✦", math.min(data.Oaths, 5)) else ""
		rankLabel.Text = Ranks.get(data.Rank).name .. oaths
		rankLabel.TextColor3 = TITLE_GOLD
	end
	if nameLabel then
		nameLabel.Text = player.DisplayName
		nameLabel.TextColor3 = PARCHMENT
	end

	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
end

local function onCharacterAdded(player: Player, character: Model)
	character:WaitForChild("Head", 10)
	character:WaitForChild("Humanoid", 10)
	if player.Character ~= character then
		return
	end
	CharacterService.refreshTitle(player)
	CharacterService.refreshWeapon(player)
end

function CharacterService.start()
	local function watch(player: Player)
		player.CharacterAdded:Connect(function(character)
			onCharacterAdded(player, character)
		end)
		if player.Character then
			task.spawn(onCharacterAdded, player, player.Character)
		end
	end

	-- Characters can spawn before data loads; dress them once it arrives.
	DataService.PlayerLoaded:Connect(function(player: Player)
		CharacterService.refreshTitle(player)
		CharacterService.refreshWeapon(player)
	end)

	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
end

return CharacterService
