-- LightsPlanner.lua
-- Ampeln und Fußgängerampeln als Teileliste (reine Geometrie, keine Roblox-Funktionen). Gesteuert werden sie von Ampel.lua über Tags und Attribute.

local Geo = require(script and script.Parent.Geo or "Geo")

local LightsPlanner = {}

local DARK = { 58, 60, 64 }
local RED, YELLOW, GREEN = { 235, 40, 40 }, { 255, 190, 30 }, { 60, 220, 90 }
local DIM = { RED = { 90, 20, 20 }, YELLOW = { 100, 74, 12 }, GREEN = { 20, 80, 36 } }
local WALK_TOP = 1.0

local function part(parts, name, kind, x, y, z, sx, sy, sz, yaw, color, material, extra)
	extra = extra or {}
	parts[#parts + 1] = {
		name = name, kind = kind, size = { sx, sy, sz }, pos = { Geo.round3(x), Geo.round3(y), Geo.round3(z) }, yaw = Geo.round3(yaw), pitch = 0,
		color = color, material = material, collide = extra.collide == true, tag = extra.tag, attrs = extra.attrs,
	}
end

-- Signalkopf mit n Lampen (3: rot/gelb/grün, 2: rot/grün) vor dem Mast, Front zeigt in Richtung (fx, fz)
local function head(parts, s, y0, lamps, tag)
	local yaw = Geo.yawOf(s.fx, s.fz)
	local n = #lamps
	local hgt = 1.2 * n + 0.6
	part(parts, "AmpelKopf", "signal", s.x + s.fx * 0.9, y0, s.z + s.fz * 0.9, 0.8, hgt, 1.3, yaw, DARK, "Metal")
	for i, l in ipairs(lamps) do
		local lit = i == 1 -- Standard: rot an, bis das Ampel-Skript schaltet
		part(parts, "AmpelLampe", "signal", s.x + s.fx * 1.35, y0 + hgt / 2 - 0.3 - 1.2 * (i - 0.5) + 0.0, s.z + s.fz * 1.35, 0.3, 0.9, 0.9, yaw,
			lit and l.on or l.dim, lit and "Neon" or "SmoothPlastic", { tag = tag, attrs = { Lamp = l.name, Group = s.name, Axis = (s.fz ~= 0) and "NS" or "EW", Lit = lit } })
	end
end

function LightsPlanner.plan(cfg)
	local parts = {}
	local stats = { signals = 0, ped = 0 }

	local lamps3 = { { name = "Red", on = RED, dim = DIM.RED }, { name = "Yellow", on = YELLOW, dim = DIM.YELLOW }, { name = "Green", on = GREEN, dim = DIM.GREEN } }
	local lamps2 = { { name = "Red", on = RED, dim = DIM.RED }, { name = "Green", on = GREEN, dim = DIM.GREEN } }
	for _, s in ipairs(cfg.signals) do
		part(parts, "AmpelMast", "signal", s.x, WALK_TOP + 7, s.z, 0.8, 14, 0.8, 0, DARK, "Metal", { collide = true })
		head(parts, s, WALK_TOP + 11.6, lamps3, "TrafficLight")
		stats.signals = stats.signals + 1
	end
	for _, s in ipairs(cfg.pedSignals) do
		part(parts, "FussgaengerMast", "signal", s.x, WALK_TOP + 4.5, s.z, 0.6, 9, 0.6, 0, DARK, "Metal", { collide = true })
		head(parts, s, WALK_TOP + 7.4, lamps2, "PedLight")
		stats.ped = stats.ped + 1
	end
	return { parts = parts, stats = stats }
end

return LightsPlanner
