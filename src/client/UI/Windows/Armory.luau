--!strict
--[[
	Armory: the weapon collection and index. Undiscovered weapons show as "???" with their odds
	so players always know what is left to chase.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)
local GameConfig = require(Shared.Config.GameConfig)
local Rarities = require(Shared.Config.Rarities)
local Weapons = require(Shared.Config.Weapons)
local Zones = require(Shared.Config.Zones)
local Economy = require(Shared.Logic.Economy)
local Stats = require(Shared.Logic.Stats)
local Format = require(Shared.Util.Format)
local WeaponModels = require(Shared.WeaponModels)
local Theme = require(script.Parent.Parent.Theme)
local UI = require(script.Parent.Parent.UI)
local Components = require(script.Parent.Parent.Components)
local Actions = require(script.Parent.Parent.Parent.Actions)

type Snapshot = Types.Snapshot
type WeaponDef = Types.WeaponDef

local SELL_DUPLICATES_UP_TO = Rarities.indexOf("Epic")

local Armory = {}

local function bonusText(weaponId: string): string
	local bonus = Stats.weaponBonus(weaponId)
	if bonus == nil then
		return "No bonus"
	end
	local parts = {}
	if bonus.luck then
		table.insert(parts, `{Format.percent(bonus.luck)} luck`)
	end
	if bonus.gold then
		table.insert(parts, `{Format.percent(bonus.gold)} gold`)
	end
	if bonus.speed then
		table.insert(parts, `{Format.percent(bonus.speed)} roll speed`)
	end
	return table.concat(parts, ", ")
end

local function autoSellText(index: number): string
	if index <= 0 then
		return "Auto-sell: Off"
	end
	return `Auto-sell: {Rarities.List[index].name} and below`
end

function Armory.create(parent: Instance): Components.WindowModule
	local window = Components.window(parent, "The Armory", UDim2.fromOffset(940, 580))
	local content = window.content

	local selectedTab = "All"
	local selectedWeapon: string? = nil
	local confirmLastSale: string? = nil
	local latest: Snapshot? = nil
	local render: (Snapshot) -> ()

	-- Left: tabs + list ----------------------------------------------------------------------
	local tabs = UI.frame({
		BackgroundTransparency = 1,
		Size = UDim2.new(0, 540, 0, 32),
		Parent = content,
	})
	UI.list(tabs, Enum.FillDirection.Horizontal, 6)

	local list = UI.scroll({
		Size = UDim2.new(0, 540, 1, -90),
		Position = UDim2.fromOffset(0, 40),
		Parent = content,
	})
	UI.list(list, Enum.FillDirection.Vertical, 4)
	UI.new("UIPadding", { PaddingRight = UDim.new(0, 10), Parent = list })

	-- Right: details ---------------------------------------------------------------------------
	local details = UI.frame({
		Size = UDim2.new(1, -556, 1, -50),
		Position = UDim2.fromOffset(556, 0),
		BackgroundColor3 = Theme.Colors.IronRaised,
		Parent = content,
	})
	UI.corner(details, 8)
	UI.padding(details, 12)

	local viewport = UI.new("ViewportFrame", {
		Size = UDim2.new(1, 0, 0, 170),
		BackgroundColor3 = Theme.Colors.Iron,
		Ambient = Color3.fromRGB(150, 140, 130),
		LightColor = Color3.fromRGB(255, 240, 220),
		LightDirection = Vector3.new(-1, -1, -1),
		Parent = details,
	}) :: ViewportFrame
	UI.corner(viewport, 6)
	local camera = UI.new("Camera", { FieldOfView = 30, Parent = viewport }) :: Camera
	viewport.CurrentCamera = camera

	local detailName = UI.label({
		Text = "Select a weapon",
		Font = Theme.Fonts.Title,
		TextSize = 30,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, 34),
		Position = UDim2.fromOffset(0, 176),
		Parent = details,
	})
	local detailInfo = UI.label({
		Text = "",
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		LineHeight = 1.15,
		Size = UDim2.new(1, 0, 0, 150),
		Position = UDim2.fromOffset(0, 212),
		Parent = details,
	})

	local equipButton = Components.button({
		text = "Equip",
		size = UDim2.new(1, 0, 0, 36),
		position = UDim2.new(0, 0, 1, -82),
		color = Theme.Colors.Royal,
		parent = details,
	})
	local sellOneButton = Components.button({
		text = "Sell 1",
		size = UDim2.new(0.5, -4, 0, 36),
		position = UDim2.new(0, 0, 1, -38),
		parent = details,
	})
	local sellExtrasButton = Components.button({
		text = "Sell extras",
		size = UDim2.new(0.5, -4, 0, 36),
		position = UDim2.new(0.5, 4, 1, -38),
		parent = details,
	})

	-- Footer -----------------------------------------------------------------------------------
	local capacityLabel = UI.label({
		Text = "",
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.fromOffset(200, 40),
		Position = UDim2.new(0, 0, 1, -40),
		Parent = content,
	})
	local autoSellButton = Components.button({
		text = autoSellText(0),
		size = UDim2.fromOffset(250, 40),
		position = UDim2.new(0, 200, 1, -40),
		textSize = 14,
		parent = content,
	})
	local sellAllButton = Components.button({
		text = `Sell all duplicates ({Rarities.List[SELL_DUPLICATES_UP_TO].name} and below)`,
		size = UDim2.fromOffset(330, 40),
		position = UDim2.new(1, 0, 1, -40),
		anchor = Vector2.new(1, 0),
		textSize = 14,
		color = Color3.fromRGB(92, 34, 28),
		parent = content,
	})

	-- 3D preview -------------------------------------------------------------------------------
	local previewModel: Model? = nil
	local previewId: string? = nil
	local spin = 0
	local function showPreview(weaponId: string?)
		if previewId == weaponId then
			return
		end
		if previewModel then
			previewModel:Destroy()
			previewModel = nil
		end
		previewId = weaponId
		if weaponId == nil then
			return
		end
		local model = WeaponModels.build(weaponId)
		if model == nil then
			return
		end
		model:PivotTo(CFrame.new())
		model.Parent = viewport
		previewModel = model
		local extents = model:GetExtentsSize()
		local center = model:GetBoundingBox().Position
		local distance = math.max(extents.X, extents.Y, extents.Z) * 2.4
		camera.CFrame = CFrame.lookAt(center + Vector3.new(0, 0, distance), center)
	end

	local spinConnection: RBXScriptConnection? = nil

	-- Rendering --------------------------------------------------------------------------------
	local function renderDetails(snapshot: Snapshot)
		local data = snapshot.data
		local weaponId = selectedWeapon
		local weapon = if weaponId then Weapons.ById[weaponId] else nil
		if weaponId == nil or weapon == nil then
			detailName.Text = "Select a weapon"
			detailName.TextColor3 = Theme.Colors.Parchment
			detailInfo.Text = UI.colorize("Choose a weapon from the list to inspect it.", Theme.Colors.ParchmentDim)
			equipButton.Visible = false
			sellOneButton.Visible = false
			sellExtrasButton.Visible = false
			showPreview(nil)
			return
		end

		local rarity = Rarities.fromChance(weapon.chance)
		local zone = Zones.ById[weapon.zone]
		local owned = data.Weapons[weapon.id] or 0
		local discovered = data.Discovered[weapon.id] == true

		if not discovered then
			detailName.Text = "???"
			detailName.TextColor3 = rarity.color
			detailInfo.Text = table.concat({
				`{UI.colorize(rarity.name, rarity.color)}  ·  {Format.chance(weapon.chance)}`,
				`Found in {if zone then zone.name else weapon.zone}`,
				"",
				UI.colorize("Not yet discovered. Keep rolling.", Theme.Colors.ParchmentDim),
			}, "\n")
			equipButton.Visible = false
			sellOneButton.Visible = false
			sellExtrasButton.Visible = false
			showPreview(nil)
			return
		end

		local value = Economy.weaponValue(weapon.id, snapshot.stats.goldMultiplier)
		detailName.Text = weapon.name
		detailName.TextColor3 = rarity.color
		detailInfo.Text = table.concat({
			`{UI.colorize(rarity.name, rarity.color)}  ·  {Format.chance(weapon.chance)}  ·  {weapon.kind}`,
			`From {if zone then zone.name else weapon.zone}`,
			UI.colorize(`<i>{weapon.description}</i>`, Theme.Colors.ParchmentDim),
			"",
			`Equipped bonus: {UI.colorize(bonusText(weapon.id), Theme.Colors.Gold)}`,
			`Owned: {Format.commas(owned)}   ·   Sells for {UI.colorize(Format.commas(value), Theme.Colors.Gold)} gold`,
		}, "\n")

		local equipped = data.EquippedWeapon == weapon.id
		equipButton.Visible = owned > 0
		equipButton.Text = if equipped then "Unequip" else "Equip"
		sellOneButton.Visible = owned > 0
		local lastCopy = owned == 1
		sellOneButton.Text = if confirmLastSale == weapon.id then "Confirm: sell last copy" else "Sell 1"
		Components.setEnabled(sellOneButton, not (equipped and lastCopy))
		sellExtrasButton.Visible = owned > 1
		sellExtrasButton.Text = `Sell {owned - 1} extra{if owned - 1 == 1 then "" else "s"}`

		showPreview(weapon.id)
	end

	local function makeRow(weapon: WeaponDef, snapshot: Snapshot, order: number)
		local data = snapshot.data
		local rarity = Rarities.fromChance(weapon.chance)
		local owned = data.Weapons[weapon.id] or 0
		local discovered = data.Discovered[weapon.id] == true
		local selected = selectedWeapon == weapon.id

		local row = UI.textButton({
			Text = "",
			Size = UDim2.new(1, 0, 0, 36),
			BackgroundColor3 = if selected then Theme.Colors.IronHover else Theme.Colors.IronRaised,
			LayoutOrder = order,
			Parent = list,
		})
		UI.corner(row, 4)
		local bar = UI.frame({
			Size = UDim2.new(0, 5, 1, -8),
			Position = UDim2.fromOffset(4, 4),
			BackgroundColor3 = rarity.color,
			BackgroundTransparency = if discovered then 0 else 0.6,
			Parent = row,
		})
		UI.corner(bar, 2)

		local nameText = if discovered then weapon.name else "???"
		if data.EquippedWeapon == weapon.id then
			nameText ..= "  " .. UI.colorize("[equipped]", Theme.Colors.Gold)
		end
		UI.label({
			Text = nameText,
			TextColor3 = if discovered then rarity.color else Theme.Colors.Muted,
			TextSize = 16,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextWrapped = false,
			Size = UDim2.new(1, -230, 1, 0),
			Position = UDim2.fromOffset(16, 0),
			Parent = row,
		})
		UI.label({
			Text = if owned > 0 then `x{Format.commas(owned)}` else "",
			TextSize = 15,
			TextXAlignment = Enum.TextXAlignment.Right,
			Size = UDim2.fromOffset(60, 36),
			Position = UDim2.new(1, -210, 0, 0),
			Parent = row,
		})
		UI.label({
			Text = Format.chance(weapon.chance),
			TextColor3 = Theme.Colors.ParchmentDim,
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Right,
			Size = UDim2.fromOffset(140, 36),
			Position = UDim2.new(1, -144, 0, 0),
			Parent = row,
		})

		row.Activated:Connect(function()
			selectedWeapon = weapon.id
			confirmLastSale = nil
			if latest then
				render(latest)
			end
		end)
	end

	local tabButtons: { [string]: TextButton } = {}
	function render(snapshot: Snapshot)
		latest = snapshot
		local data = snapshot.data

		for key, button in tabButtons do
			Components.setButtonColor(
				button,
				if key == selectedTab then Theme.Colors.IronHover else Theme.Colors.IronRaised
			)
		end

		local pool: { WeaponDef } = if selectedTab == "All"
			then table.clone(Weapons.List)
			else table.clone(Weapons.ByZone[selectedTab] or {})
		table.sort(pool, function(a, b)
			return a.chance > b.chance
		end)

		UI.clear(list)
		for index, weapon in pool do
			makeRow(weapon, snapshot, index)
		end

		renderDetails(snapshot)
		capacityLabel.Text =
			`Armory: {Format.commas(Economy.totalWeapons(data))} / {Format.commas(snapshot.stats.capacity)}`
		autoSellButton.Text = autoSellText(data.Settings.AutoSellMaxRarity)
	end

	local function addTab(key: string, label: string)
		local button = Components.button({
			text = label,
			size = UDim2.fromOffset(0, 30),
			textSize = 14,
			parent = tabs,
		})
		button.AutomaticSize = Enum.AutomaticSize.X
		UI.new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), Parent = button })
		tabButtons[key] = button
		button.Activated:Connect(function()
			selectedTab = key
			if latest then
				render(latest)
			end
		end)
	end
	addTab("All", "All")
	for _, zone in Zones.List do
		addTab(zone.id, zone.name)
	end

	-- Actions ----------------------------------------------------------------------------------
	equipButton.Activated:Connect(function()
		local snapshot = latest
		local weaponId = selectedWeapon
		if snapshot == nil or weaponId == nil then
			return
		end
		local target = if snapshot.data.EquippedWeapon == weaponId then "" else weaponId
		Actions.call("EquipWeapon", target)
	end)

	sellOneButton.Activated:Connect(function()
		local snapshot = latest
		local weaponId = selectedWeapon
		if snapshot == nil or weaponId == nil or not sellOneButton.Active then
			return
		end
		if (snapshot.data.Weapons[weaponId] or 0) == 1 and confirmLastSale ~= weaponId then
			confirmLastSale = weaponId
			renderDetails(snapshot)
			return
		end
		confirmLastSale = nil
		Actions.call("SellWeapon", weaponId, 1)
	end)

	sellExtrasButton.Activated:Connect(function()
		local snapshot = latest
		local weaponId = selectedWeapon
		if snapshot == nil or weaponId == nil then
			return
		end
		local owned = snapshot.data.Weapons[weaponId] or 0
		if owned > 1 then
			Actions.call("SellWeapon", weaponId, owned - 1)
		end
	end)

	sellAllButton.Activated:Connect(function()
		Actions.call("SellDuplicates", SELL_DUPLICATES_UP_TO)
	end)

	autoSellButton.Activated:Connect(function()
		local snapshot = latest
		if snapshot == nil then
			return
		end
		local nextValue = (snapshot.data.Settings.AutoSellMaxRarity + 1) % (GameConfig.Inventory.MaxAutoSellRarity + 1)
		Actions.call("SetAutoSell", nextValue)
	end)

	return {
		window = window,
		refresh = render,
		onOpen = function()
			if spinConnection == nil then
				spinConnection = RunService.RenderStepped:Connect(function(dt: number)
					spin += dt * 0.8
					if previewModel then
						previewModel:PivotTo(CFrame.Angles(0, spin, 0))
					end
				end)
			end
		end,
		onClose = function()
			if spinConnection then
				spinConnection:Disconnect()
				spinConnection = nil
			end
		end,
	}
end

return Armory
