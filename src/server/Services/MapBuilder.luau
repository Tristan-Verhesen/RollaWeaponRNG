--!strict
--[[
	Placeholder world: one floating island per zone, joined by bridges, each zone sealed by a
	shimmering gate until the player's rank opens it.

	Only built when the place contains no parts tagged "Zone". To use your own map:
	  1. Add an invisible, non-colliding, anchored part covering each zone.
	  2. Tag it "Zone" (CollectionService / Tag Editor) and give it a string attribute ZoneId
	     matching an id in Config/Zones ("Hamlet", "Darkwood", ...).
	  3. Optionally tag gate parts "ZoneGate" and spawn parts "ZoneSpawn" (both with ZoneId).
]]

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Types = require(Shared.Types)
local GameConfig = require(Shared.Config.GameConfig)
local Zones = require(Shared.Config.Zones)
local Ranks = require(Shared.Config.Ranks)
local WeaponModels = require(Shared.WeaponModels)

type ZoneDef = Types.ZoneDef

local ISLAND = 150
local SPACING = 220
local BRIDGE_WIDTH = 22
local VOLUME_HEIGHT = 120

local STONE = Color3.fromRGB(120, 116, 110)
local DARK_STONE = Color3.fromRGB(74, 70, 68)
local TIMBER = Color3.fromRGB(96, 66, 40)
local THATCH = Color3.fromRGB(176, 146, 82)

local MapBuilder = {}

type PartProps = {
	name: string?,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?,
	shape: Enum.PartType?,
	transparency: number?,
	collide: boolean?,
	wedge: boolean?,
}

local function part(parent: Instance, props: PartProps): BasePart
	local instance: BasePart = if props.wedge then Instance.new("WedgePart") else Instance.new("Part")
	instance.Name = props.name or "Part"
	instance.Anchored = true
	instance.Size = props.size
	instance.CFrame = props.cframe
	instance.Color = props.color
	instance.Material = props.material or Enum.Material.SmoothPlastic
	instance.Transparency = props.transparency or 0
	instance.CanCollide = if props.collide == nil then true else props.collide
	instance.TopSurface = Enum.SurfaceType.Smooth
	instance.BottomSurface = Enum.SurfaceType.Smooth
	if props.shape and instance:IsA("Part") then
		instance.Shape = props.shape
	end
	instance.Parent = parent
	return instance
end

local function billboard(adornee: BasePart, title: string, subtitle: string, color: Color3, height: number)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(320, 80)
	gui.StudsOffset = Vector3.new(0, height, 0)
	gui.MaxDistance = 220
	gui.LightInfluence = 0

	local titleLabel = Instance.new("TextLabel")
	titleLabel.BackgroundTransparency = 1
	titleLabel.Size = UDim2.fromScale(1, 0.6)
	titleLabel.Font = Enum.Font.GrenzeGotisch
	titleLabel.TextScaled = true
	titleLabel.Text = title
	titleLabel.TextColor3 = color
	titleLabel.TextStrokeTransparency = 0.3
	titleLabel.Parent = gui

	local subLabel = Instance.new("TextLabel")
	subLabel.BackgroundTransparency = 1
	subLabel.Position = UDim2.fromScale(0, 0.6)
	subLabel.Size = UDim2.fromScale(1, 0.4)
	subLabel.Font = Enum.Font.Fondamento
	subLabel.TextScaled = true
	subLabel.Text = subtitle
	subLabel.TextColor3 = Color3.fromRGB(240, 230, 206)
	subLabel.TextStrokeTransparency = 0.3
	subLabel.Parent = gui

	gui.Parent = adornee
end

-- Decorations ---------------------------------------------------------------------------------

local function tree(parent: Instance, base: Vector3, trunk: Color3, leaves: Color3, scale: number)
	local height = 10 * scale
	part(parent, {
		size = Vector3.new(height, 1.6 * scale, 1.6 * scale),
		cframe = CFrame.new(base + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		color = trunk,
		material = Enum.Material.Wood,
		shape = Enum.PartType.Cylinder,
	})
	for i = 0, 2 do
		local size = (7 - i * 1.8) * scale
		part(parent, {
			size = Vector3.new(size, size, size),
			cframe = CFrame.new(base + Vector3.new(0, height + i * 2.6 * scale, 0)),
			color = leaves,
			material = Enum.Material.Grass,
			shape = Enum.PartType.Ball,
		})
	end
end

local function cottage(parent: Instance, cframe: CFrame)
	part(parent, {
		size = Vector3.new(14, 9, 12),
		cframe = cframe * CFrame.new(0, 4.5, 0),
		color = Color3.fromRGB(214, 200, 170),
		material = Enum.Material.Plaster,
	})
	for side = -1, 1, 2 do
		part(parent, {
			wedge = true,
			size = Vector3.new(15, 6, 7),
			cframe = cframe
				* CFrame.new(0, 12, side * 3.5)
				* CFrame.Angles(0, if side > 0 then math.rad(180) else 0, 0),
			color = THATCH,
			material = Enum.Material.Fabric,
		})
	end
	part(parent, {
		size = Vector3.new(3, 6, 0.4),
		cframe = cframe * CFrame.new(0, 3, -6.1),
		color = TIMBER,
		material = Enum.Material.Wood,
	})
end

local function tombstone(parent: Instance, cframe: CFrame, rng: Random)
	part(parent, {
		size = Vector3.new(2.6, 3.4 + rng:NextNumber() * 1.5, 0.7),
		cframe = cframe * CFrame.Angles(math.rad(rng:NextNumber(-8, 8)), 0, math.rad(rng:NextNumber(-8, 8))),
		color = Color3.fromRGB(110, 110, 116),
		material = Enum.Material.Slate,
	})
end

local function spire(parent: Instance, base: Vector3, height: number, color: Color3, rng: Random)
	part(parent, {
		wedge = true,
		size = Vector3.new(6 + rng:NextNumber() * 6, height, 6 + rng:NextNumber() * 6),
		cframe = CFrame.new(base + Vector3.new(0, height / 2, 0))
			* CFrame.Angles(0, math.rad(rng:NextNumber(0, 360)), 0),
		color = color,
		material = Enum.Material.Basalt,
	})
end

local function pillar(parent: Instance, base: Vector3, height: number)
	part(parent, {
		size = Vector3.new(height, 4, 4),
		cframe = CFrame.new(base + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		color = Color3.fromRGB(206, 198, 180),
		material = Enum.Material.Marble,
		shape = Enum.PartType.Cylinder,
	})
end

local function swordInTheStone(parent: Instance, base: Vector3)
	part(parent, {
		name = "Stone",
		size = Vector3.new(7, 4, 6),
		cframe = CFrame.new(base + Vector3.new(0, 2, 0)),
		color = DARK_STONE,
		material = Enum.Material.Rock,
	})
	local sword = WeaponModels.build("citadel_excalibur")
	if sword and sword.PrimaryPart then
		for _, descendant in sword:GetDescendants() do
			if descendant:IsA("BasePart") then
				descendant.Anchored = true
			end
		end
		-- Blade down, buried in the stone.
		sword:PivotTo(CFrame.new(base + Vector3.new(0, 6.6, 0)) * CFrame.Angles(math.rad(180), 0, 0))
		sword.Name = "Excalibur"
		sword.Parent = parent
	end
end

local DECORATORS: { [string]: (Instance, Vector3, ZoneDef, Random) -> () } = {
	Hamlet = function(folder, center, zone, rng)
		for i = 0, 3 do
			local angle = math.rad(i * 90 + 45)
			local position = center + Vector3.new(math.cos(angle) * 42, 0, math.sin(angle) * 42)
			cottage(folder, CFrame.lookAt(position, center))
		end
		for _ = 1, 10 do
			local offset = Vector3.new(rng:NextNumber(-65, 65), 0, rng:NextNumber(-65, 65))
			if offset.Magnitude > 30 then
				tree(folder, center + offset, TIMBER, zone.groundColor:Lerp(Color3.new(0.3, 0.5, 0.2), 0.5), 0.8)
			end
		end
		for _ = 1, 6 do
			part(folder, {
				size = Vector3.new(4, 3, 3),
				cframe = CFrame.new(center + Vector3.new(rng:NextNumber(-25, 25), 1.5, rng:NextNumber(-25, 25))),
				color = THATCH,
				material = Enum.Material.Fabric,
			})
		end
	end,

	Darkwood = function(folder, center, zone, rng)
		for _ = 1, 34 do
			local offset = Vector3.new(rng:NextNumber(-70, 70), 0, rng:NextNumber(-70, 70))
			if math.abs(offset.X) > 12 or math.abs(offset.Z) > 40 then
				tree(
					folder,
					center + offset,
					Color3.fromRGB(60, 44, 30),
					zone.accentColor:Lerp(Color3.new(), 0.45),
					1 + rng:NextNumber() * 0.7
				)
			end
		end
	end,

	Crypts = function(folder, center, zone, rng)
		part(folder, {
			name = "Barrow",
			size = Vector3.new(30, 14, 22),
			cframe = CFrame.new(center + Vector3.new(0, 7, 35)),
			color = DARK_STONE,
			material = Enum.Material.Cobblestone,
		})
		part(folder, {
			size = Vector3.new(8, 10, 1),
			cframe = CFrame.new(center + Vector3.new(0, 5, 23.6)),
			color = Color3.new(0, 0, 0),
			material = Enum.Material.SmoothPlastic,
		})
		for row = -3, 3 do
			for column = -2, 2 do
				local position = center + Vector3.new(column * 12 + rng:NextNumber(-2, 2), 2, row * 10 - 15)
				tombstone(folder, CFrame.new(position), rng)
			end
		end
		for _ = 1, 6 do
			local candle = part(folder, {
				size = Vector3.new(0.6, 1.6, 0.6),
				cframe = CFrame.new(center + Vector3.new(rng:NextNumber(-50, 50), 0.8, rng:NextNumber(-50, 50))),
				color = zone.accentColor,
				material = Enum.Material.Neon,
			})
			local light = Instance.new("PointLight")
			light.Color = zone.accentColor
			light.Range = 16
			light.Parent = candle
		end
	end,

	Dragonspine = function(folder, center, zone, rng)
		for _ = 1, 16 do
			local offset = Vector3.new(rng:NextNumber(-68, 68), 0, rng:NextNumber(-68, 68))
			if offset.Magnitude > 25 then
				spire(
					folder,
					center + offset,
					12 + rng:NextNumber() * 30,
					zone.groundColor:Lerp(Color3.new(), 0.3),
					rng
				)
			end
		end
		for _ = 1, 4 do
			local pool = part(folder, {
				size = Vector3.new(0.6, 14, 14),
				cframe = CFrame.new(center + Vector3.new(rng:NextNumber(-45, 45), 0.1, rng:NextNumber(-45, 45)))
					* CFrame.Angles(0, 0, math.rad(90)),
				color = zone.accentColor,
				material = Enum.Material.Neon,
				shape = Enum.PartType.Cylinder,
				collide = false,
			})
			local light = Instance.new("PointLight")
			light.Color = zone.accentColor
			light.Range = 24
			light.Brightness = 2
			light.Parent = pool
		end
	end,

	Citadel = function(folder, center, _zone, rng)
		for i = 0, 11 do
			local angle = math.rad(i * 30)
			local position = center + Vector3.new(math.cos(angle) * 48, 0, math.sin(angle) * 48)
			pillar(folder, position, if rng:NextNumber() < 0.4 then 6 + rng:NextNumber() * 8 else 26)
		end
		for side = -1, 1, 2 do
			part(folder, {
				size = Vector3.new(4, 18 + rng:NextNumber() * 8, 60),
				cframe = CFrame.new(center + Vector3.new(side * 68, 11, 20)),
				color = STONE,
				material = Enum.Material.Brick,
			})
		end
		swordInTheStone(folder, center)
	end,
}

-- World -----------------------------------------------------------------------------------------

local function buildZone(root: Instance, zone: ZoneDef, index: number, rng: Random)
	local folder = Instance.new("Folder")
	folder.Name = zone.id
	folder.Parent = root

	local center = Vector3.new(0, 0, (index - 1) * SPACING)

	part(folder, {
		name = "Ground",
		size = Vector3.new(ISLAND, 6, ISLAND),
		cframe = CFrame.new(center - Vector3.new(0, 3, 0)),
		color = zone.groundColor,
		material = Enum.Material.Grass,
	})
	part(folder, {
		name = "Cliff",
		size = Vector3.new(ISLAND - 6, 30, ISLAND - 6),
		cframe = CFrame.new(center - Vector3.new(0, 21, 0)),
		color = DARK_STONE,
		material = Enum.Material.Rock,
	})

	local volume = part(folder, {
		name = "ZoneVolume",
		size = Vector3.new(ISLAND + 6, VOLUME_HEIGHT, ISLAND + 6),
		cframe = CFrame.new(center + Vector3.new(0, VOLUME_HEIGHT / 2 - 8, 0)),
		color = zone.accentColor,
		transparency = 1,
		collide = false,
	})
	volume.CanQuery = false
	volume.CanTouch = false
	volume:SetAttribute("ZoneId", zone.id)
	CollectionService:AddTag(volume, "Zone")

	local spawnPad = part(folder, {
		name = "ZoneSpawn",
		size = Vector3.new(8, 1, 8),
		cframe = CFrame.new(center + Vector3.new(0, 0.5, -ISLAND / 2 + 14)),
		color = zone.accentColor,
		material = Enum.Material.Slate,
	})
	spawnPad:SetAttribute("ZoneId", zone.id)
	CollectionService:AddTag(spawnPad, "ZoneSpawn")

	local signpost = part(folder, {
		name = "Signpost",
		size = Vector3.new(1, 8, 1),
		cframe = CFrame.new(center + Vector3.new(14, 4, -ISLAND / 2 + 10)),
		color = TIMBER,
		material = Enum.Material.Wood,
	})
	billboard(signpost, zone.name, zone.subtitle, zone.accentColor, 7)

	local decorate = DECORATORS[zone.id]
	if decorate then
		decorate(folder, center, zone, rng)
	end

	if index > 1 then
		local previousEdge = center.Z - SPACING + ISLAND / 2
		local edge = center.Z - ISLAND / 2
		local length = edge - previousEdge
		part(folder, {
			name = "Bridge",
			size = Vector3.new(BRIDGE_WIDTH, 2, length + 2),
			cframe = CFrame.new(0, -1, (previousEdge + edge) / 2),
			color = TIMBER,
			material = Enum.Material.WoodPlanks,
		})

		local gateZ = (previousEdge + edge) / 2
		local gate = part(folder, {
			name = "Gate",
			size = Vector3.new(BRIDGE_WIDTH + 8, 40, 2),
			cframe = CFrame.new(0, 20, gateZ),
			color = zone.accentColor,
			material = Enum.Material.ForceField,
			transparency = 0.2,
		})
		gate:SetAttribute("ZoneId", zone.id)
		CollectionService:AddTag(gate, "ZoneGate")
		billboard(gate, zone.name, `Requires {Ranks.get(zone.requiredRank).name}`, zone.accentColor, 24)

		for side = -1, 1, 2 do
			part(folder, {
				name = "GatePillar",
				size = Vector3.new(5, 46, 5),
				cframe = CFrame.new(side * (BRIDGE_WIDTH / 2 + 6.5), 23, gateZ),
				color = STONE,
				material = Enum.Material.Cobblestone,
			})
		end
		part(folder, {
			name = "GateLintel",
			size = Vector3.new(BRIDGE_WIDTH + 18, 5, 5),
			cframe = CFrame.new(0, 48, gateZ),
			color = STONE,
			material = Enum.Material.Cobblestone,
		})
	end
end

local function replaceTemplateWorld(root: Instance)
	local baseplate = Workspace:FindFirstChild("Baseplate")
	if baseplate and baseplate:IsA("BasePart") then
		baseplate:Destroy()
	end
	for _, descendant in Workspace:GetDescendants() do
		if descendant:IsA("SpawnLocation") and not descendant:IsDescendantOf(root) then
			descendant.Enabled = false
		end
	end
end

local function setAtmosphere()
	Lighting.ClockTime = 16.2
	Lighting.Brightness = 2
	Lighting.OutdoorAmbient = Color3.fromRGB(128, 118, 104)
	if Lighting:FindFirstChildOfClass("Atmosphere") == nil then
		local atmosphere = Instance.new("Atmosphere")
		atmosphere.Density = 0.32
		atmosphere.Haze = 1.4
		atmosphere.Color = Color3.fromRGB(200, 186, 160)
		atmosphere.Decay = Color3.fromRGB(110, 96, 84)
		atmosphere.Parent = Lighting
	end
end

function MapBuilder.init()
	if not GameConfig.Map.BuildPlaceholder or #CollectionService:GetTagged("Zone") > 0 then
		return
	end

	local root = Instance.new("Model")
	root.Name = "PlaceholderMap"

	local rng = Random.new(1066)
	for index, zone in Zones.List do
		buildZone(root, zone, index, rng)
	end

	local realmSpawn = Instance.new("SpawnLocation")
	realmSpawn.Name = "RealmSpawn"
	realmSpawn.Anchored = true
	realmSpawn.Neutral = true
	realmSpawn.Duration = 0
	realmSpawn.Size = Vector3.new(10, 1, 10)
	realmSpawn.CFrame = CFrame.new(0, 0.5, -30)
	realmSpawn.Color = Zones.List[1].accentColor
	realmSpawn.Material = Enum.Material.Slate
	realmSpawn.TopSurface = Enum.SurfaceType.Smooth
	realmSpawn.Parent = root

	-- Falling off an island ends quickly instead of after a long drop.
	local abyss = Instance.new("Part")
	abyss.Name = "Abyss"
	abyss.Anchored = true
	abyss.CanCollide = false
	abyss.Transparency = 1
	abyss.Size = Vector3.new(2048, 4, 2048)
	abyss.CFrame = CFrame.new(0, -80, (#Zones.List - 1) * SPACING / 2)
	abyss.Touched:Connect(function(hit)
		local model = hit:FindFirstAncestorOfClass("Model")
		local humanoid = model and model:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.Health = 0
		end
	end)
	abyss.Parent = root

	if GameConfig.Map.ReplaceTemplateWorld then
		replaceTemplateWorld(root)
	end
	setAtmosphere()
	root.Parent = Workspace
	print('[MapBuilder] Built placeholder world. Tag your own parts "Zone" to replace it.')
end

return MapBuilder
