--!strict
--[[
	Argument validation for remote handlers. Never trust a client argument's type, range or
	identity; every check here rejects NaN, infinities, absurd lengths and wrong types.
]]

local Validate = {}

function Validate.string(value: unknown, maxLength: number?): boolean
	return type(value) == "string" and #value <= (maxLength or 64)
end

function Validate.integer(value: unknown, min: number, max: number): boolean
	if type(value) ~= "number" then
		return false
	end
	-- NaN fails both comparisons; infinities fail the range check.
	return value == value and value == math.floor(value) and value >= min and value <= max
end

function Validate.boolean(value: unknown): boolean
	return type(value) == "boolean"
end

return Validate
