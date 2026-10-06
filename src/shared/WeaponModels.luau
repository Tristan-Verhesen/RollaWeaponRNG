--!strict
--[[
	Builds the 3D model for a weapon.

	If ReplicatedStorage.Assets.WeaponModels has a child named after the weapon id (a Model or
	BasePart), a clone of it is used; a Model's PrimaryPart (or a part named "Handle") becomes
	the grip. Otherwise a procedural model is assembled from parts based on the weapon's kind,
	so every weapon has a look from day one and you can replace them one at a time.

	Procedural models are built with the grip ("Handle") at the origin and the business end
	pointing up +Y, which reads well with Roblox's default tool-hold pose.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(script.Parent.Types)
local Rarities = require(script.Parent.Config.Rarities)
local Weapons = require(script.Parent.Config.Weapons)

type WeaponDef = Types.WeaponDef

local STEEL = Color3.fromRGB(196, 200, 208)
local WOOD = Color3.fromRGB(110, 76, 46)
local LEATHER = Color3.fromRGB(70, 46, 30)
local GOLD_TRIM = Color3.fromRGB(212, 170, 70)

local WeaponModels = {}

type Builder = {
	add: (size: Vector3, offset: CFrame, color: Color3, material: Enum.Material, shape: Enum.PartType?) -> BasePart,
	handle: BasePart,
	model: Model,
}

local function newPart(name: string, size: Vector3, color: Color3, material: Enum.Material): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = material
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	return part
end

local function builder(name: string, gripLength: number, gripColor: Color3): Builder
	local model = Instance.new("Model")
	model.Name = name

	local handle = newPart("Handle", Vector3.new(0.3, gripLength, 0.3), gripColor, Enum.Material.Wood)
	handle.Parent = model
	model.PrimaryPart = handle

	local self = {} :: Builder
	self.model = model
	self.handle = handle
	self.add = function(size, offset, color, material, shape)
		local part = newPart("Part", size, color, material)
		if shape then
			part.Shape = shape
		end
		part.CFrame = handle.CFrame * offset
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = handle
		weld.Part1 = part
		weld.Parent = part
		part.Parent = model
		return part
	end
	return self
end

local function at(x: number, y: number, z: number, rx: number?, ry: number?, rz: number?): CFrame
	return CFrame.new(x, y, z) * CFrame.Angles(math.rad(rx or 0), math.rad(ry or 0), math.rad(rz or 0))
end

local METAL = Enum.Material.Metal
local WOODMAT = Enum.Material.Wood
local BALL = Enum.PartType.Ball

-- Each builder adds parts above the grip. `head` is the weapon's tint (blade/head color).
local KINDS: { [string]: (b: Builder, head: Color3) -> BasePart } = {
	Sword = function(b, head)
		b.add(Vector3.new(1.4, 0.2, 0.3), at(0, 0.7, 0), GOLD_TRIM, METAL)
		b.add(Vector3.new(0.35, 0.35, 0.35), at(0, -0.75, 0), GOLD_TRIM, METAL, BALL)
		return b.add(Vector3.new(0.32, 3.2, 0.08), at(0, 2.4, 0), head, METAL)
	end,
	Greatsword = function(b, head)
		b.add(Vector3.new(2, 0.25, 0.35), at(0, 0.8, 0), GOLD_TRIM, METAL)
		b.add(Vector3.new(0.4, 0.4, 0.4), at(0, -0.85, 0), GOLD_TRIM, METAL, BALL)
		return b.add(Vector3.new(0.5, 4.6, 0.12), at(0, 3.2, 0), head, METAL)
	end,
	Dagger = function(b, head)
		b.add(Vector3.new(0.8, 0.15, 0.25), at(0, 0.65, 0), GOLD_TRIM, METAL)
		return b.add(Vector3.new(0.25, 1.3, 0.06), at(0, 1.35, 0), head, METAL)
	end,
	Axe = function(b, head)
		b.add(Vector3.new(0.25, 2.4, 0.25), at(0, 1.6, 0), WOOD, WOODMAT)
		return b.add(Vector3.new(1.1, 0.9, 0.12), at(0.5, 2.5, 0), head, METAL)
	end,
	Mace = function(b, head)
		b.add(Vector3.new(0.25, 1.8, 0.25), at(0, 1.3, 0), LEATHER, METAL)
		local ball = b.add(Vector3.new(0.9, 0.9, 0.9), at(0, 2.5, 0), head, METAL, BALL)
		for i = 0, 3 do
			b.add(Vector3.new(0.12, 0.7, 0.5), at(0, 2.5, 0, 0, i * 45, 0) * CFrame.new(0.45, 0, 0), head, METAL)
		end
		return ball
	end,
	Hammer = function(b, head)
		b.add(Vector3.new(0.25, 2.4, 0.25), at(0, 1.6, 0), WOOD, WOODMAT)
		return b.add(Vector3.new(1.4, 0.65, 0.65), at(0, 2.9, 0), head, METAL)
	end,
	Flail = function(b, head)
		for i = 1, 3 do
			b.add(Vector3.new(0.12, 0.25, 0.12), at(0.12 * i, 0.6 + 0.25 * i, 0, 0, 0, -20), STEEL, METAL)
		end
		local ball = b.add(Vector3.new(0.8, 0.8, 0.8), at(0.55, 1.6, 0), head, METAL, BALL)
		for i = 0, 2 do
			b.add(Vector3.new(0.12, 1.1, 0.12), at(0.55, 1.6, 0, i * 60, 0, 90), head, METAL)
		end
		return ball
	end,
	Club = function(b, head)
		return b.add(Vector3.new(0.55, 2.4, 0.55), at(0, 1.7, 0, 0, 0, 3), head, WOODMAT)
	end,
	Spear = function(b, head)
		b.add(Vector3.new(0.2, 5, 0.2), at(0, 2.2, 0), WOOD, WOODMAT)
		return b.add(Vector3.new(0.35, 1.1, 0.1), at(0, 5.2, 0), head, METAL)
	end,
	Halberd = function(b, head)
		b.add(Vector3.new(0.22, 5.2, 0.22), at(0, 2.3, 0), WOOD, WOODMAT)
		b.add(Vector3.new(0.2, 0.9, 0.08), at(0, 5.3, 0), head, METAL)
		return b.add(Vector3.new(1.1, 1.2, 0.1), at(0.55, 4.5, 0), head, METAL)
	end,
	Pitchfork = function(b, head)
		b.add(Vector3.new(0.2, 4.6, 0.2), at(0, 2, 0), WOOD, WOODMAT)
		b.add(Vector3.new(0.9, 0.12, 0.12), at(0, 4.35, 0), head, METAL)
		b.add(Vector3.new(0.08, 0.9, 0.08), at(-0.4, 4.85, 0), head, METAL)
		b.add(Vector3.new(0.08, 0.9, 0.08), at(0.4, 4.85, 0), head, METAL)
		return b.add(Vector3.new(0.08, 1, 0.08), at(0, 4.9, 0), head, METAL)
	end,
	Scythe = function(b, head)
		b.add(Vector3.new(0.2, 4.8, 0.2), at(0, 2.1, 0), WOOD, WOODMAT)
		b.add(Vector3.new(1.4, 0.3, 0.06), at(0.7, 4.4, 0, 0, 0, -8), head, METAL)
		return b.add(Vector3.new(1.2, 0.25, 0.06), at(1.85, 4.05, 0, 0, 0, -30), head, METAL)
	end,
	Sickle = function(b, head)
		b.add(Vector3.new(0.6, 0.18, 0.05), at(0.25, 0.9, 0, 0, 0, 25), head, METAL)
		b.add(Vector3.new(0.6, 0.18, 0.05), at(0.6, 1.35, 0, 0, 0, 75), head, METAL)
		return b.add(Vector3.new(0.5, 0.15, 0.05), at(0.45, 1.8, 0, 0, 0, 135), head, METAL)
	end,
	Staff = function(b, head)
		b.add(Vector3.new(0.22, 4.6, 0.22), at(0, 2, 0), WOOD, WOODMAT)
		local orb = b.add(Vector3.new(0.7, 0.7, 0.7), at(0, 4.6, 0), head, Enum.Material.Neon, BALL)
		local light = Instance.new("PointLight")
		light.Color = head
		light.Range = 8
		light.Brightness = 1.5
		light.Parent = orb
		return orb
	end,
	Bow = function(b, head)
		b.add(Vector3.new(0.18, 1.8, 0.18), at(0, 1.4, 0.15, 0, 0, 0) * at(0, 0, 0, -18, 0, 0), head, WOODMAT)
		b.add(Vector3.new(0.18, 1.8, 0.18), at(0, -1.4, 0.15, 0, 0, 0) * at(0, 0, 0, 18, 0, 0), head, WOODMAT)
		return b.add(Vector3.new(0.04, 4.6, 0.04), at(0, 0, 0.62), Color3.fromRGB(230, 225, 210), Enum.Material.Fabric)
	end,
	Crossbow = function(b, head)
		b.add(Vector3.new(0.3, 2.2, 0.3), at(0, 1.4, 0), WOOD, WOODMAT)
		b.add(Vector3.new(2.2, 0.18, 0.18), at(0, 2.3, 0), head, METAL)
		return b.add(Vector3.new(0.08, 1.4, 0.08), at(0, 1.7, -0.2), STEEL, METAL)
	end,
}

local function decorate(focus: BasePart, rarityIndex: number, color: Color3)
	if rarityIndex >= Rarities.indexOf("Epic") then
		local light = Instance.new("PointLight")
		light.Color = color
		light.Range = 6 + rarityIndex
		light.Brightness = 0.5 + 0.25 * rarityIndex
		light.Parent = focus
	end
	if rarityIndex >= Rarities.indexOf("Legendary") then
		local particles = Instance.new("ParticleEmitter")
		particles.Color = ColorSequence.new(color)
		particles.LightEmission = 1
		particles.Rate = 4 * rarityIndex
		particles.Lifetime = NumberRange.new(0.6, 1.2)
		particles.Speed = NumberRange.new(0.5, 1.5)
		particles.SpreadAngle = Vector2.new(180, 180)
		particles.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.18),
			NumberSequenceKeypoint.new(1, 0),
		})
		particles.Parent = focus
	end
	if rarityIndex >= Rarities.indexOf("Exalted") then
		focus.Material = Enum.Material.Neon
	end
end

local function customModel(weaponId: string): Model?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local folder = assets and assets:FindFirstChild("WeaponModels")
	local template = folder and folder:FindFirstChild(weaponId)
	if template == nil then
		return nil
	end

	if template:IsA("BasePart") then
		local model = Instance.new("Model")
		model.Name = weaponId
		local part = template:Clone()
		part.Name = "Handle"
		part.Parent = model
		model.PrimaryPart = part
		return model
	elseif template:IsA("Model") then
		local model = template:Clone()
		local handle = model.PrimaryPart or model:FindFirstChild("Handle", true)
		if handle and handle:IsA("BasePart") then
			model.PrimaryPart = handle
			return model
		end
		warn(`[WeaponModels] Custom model {weaponId} needs a PrimaryPart or a part named Handle`)
	end
	return nil
end

-- Returns a model whose PrimaryPart is the grip. Parts are unanchored and welded together.
function WeaponModels.build(weaponId: string): Model?
	local weapon: WeaponDef? = Weapons.ById[weaponId]
	if weapon == nil then
		return nil
	end

	local custom = customModel(weaponId)
	if custom then
		return custom
	end

	local rarityIndex = Rarities.indexFromChance(weapon.chance)
	local rarityColor = Rarities.List[rarityIndex].color
	local gripColor = if weapon.kind == "Club" then WOOD else LEATHER
	local b = builder(weapon.name, if weapon.kind == "Dagger" then 1 else 1.2, gripColor)
	local kindBuilder = KINDS[weapon.kind] or KINDS.Sword
	local focus = kindBuilder(b, weapon.tint or STEEL)
	decorate(focus, rarityIndex, rarityColor)
	return b.model
end

return WeaponModels
