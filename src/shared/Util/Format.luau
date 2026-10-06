--!strict
--[[
	Number and time formatting for UI and announcements.
]]

local Format = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi" }

-- 1234567 -> "1,234,567"
function Format.commas(value: number): string
	local negative = value < 0
	local digits = string.format("%.0f", math.floor(math.abs(value)))
	local formatted = digits:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if formatted:sub(1, 1) == "," then
		formatted = formatted:sub(2)
	end
	return if negative then "-" .. formatted else formatted
end

-- 1500 -> "1.5K", 2000000 -> "2M"
function Format.short(value: number): string
	local abs = math.abs(value)
	if abs < 1000 then
		return tostring(math.floor(value))
	end
	local tier = math.min(math.floor(math.log10(abs) / 3), #SUFFIXES - 1)
	local scaled = value / 10 ^ (tier * 3)
	local text = if math.abs(scaled) >= 100 then tostring(math.floor(scaled)) else string.format("%.1f", scaled)
	text = text:gsub("%.0$", "")
	return text .. SUFFIXES[tier + 1]
end

-- 12000 -> "1 in 12,000"
function Format.chance(chance: number): string
	return "1 in " .. Format.commas(math.max(1, math.floor(chance + 0.5)))
end

-- 0.25 -> "+25%"
function Format.percent(value: number): string
	local pct = value * 100
	local text = if pct == math.floor(pct) then tostring(math.floor(pct)) else string.format("%.1f", pct)
	return (if value >= 0 then "+" else "") .. text .. "%"
end

-- 2.5 -> "x2.5"
function Format.multiplier(value: number): string
	local text = string.format("%.2f", value):gsub("0+$", ""):gsub("%.$", "")
	return "x" .. text
end

-- 75 -> "1:15", 3725 -> "1:02:05"
function Format.duration(seconds: number): string
	local total = math.max(0, math.floor(seconds))
	local hours = total // 3600
	local minutes = (total % 3600) // 60
	local secs = total % 60
	if hours > 0 then
		return string.format("%d:%02d:%02d", hours, minutes, secs)
	end
	return string.format("%d:%02d", minutes, secs)
end

return table.freeze(Format)
