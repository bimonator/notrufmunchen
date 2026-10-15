-- LightsPlanner.lua
-- Straßenlaternen entlang der Gehwege, Ampeln (Mast mit Ausleger, zwei Signalköpfe) und Fußgängerampeln als Teileliste.
-- Reine Geometrie. Die Ampeln werden von Ampel.lua über Tags und Attribute gesteuert.
-- Laternen brauchen die Straßenpläne (Gehwegteile), damit kein Mast auf der Fahrbahn, in einer Kreuzung oder über dem Tunnel steht.

local Geo = require(script and script.Parent.Geo or "Geo")

local LightsPlanner = {}

local STEEL, HOUSING, PLATE, WARM = { 128, 132, 136 }, { 28, 28, 30 }, { 235, 230, 200 }, { 255, 226, 150 }
local RED, YELLOW, GREEN = { 235, 40, 40 }, { 255, 190, 30 }, { 60, 220, 90 }
local DIM = { Red = { 90, 20, 20 }, Yellow = { 100, 74, 12 }, Green = { 20, 80, 36 } }
local WALK_TOP = 1.0

local function part(parts, name, kind, x, y, z, sx, sy, sz, yaw, color, material, extra)
	extra = extra or {}
	parts[#parts + 1] = {
		name = name, kind = kind, size = { sx, sy, sz }, pos = { Geo.round3(x), Geo.round3(y), Geo.round3(z) }, yaw = Geo.round3(yaw), pitch = extra.pitch or 0,
		color = color, material = material, collide = extra.collide == true, tag = extra.tag, attrs = extra.attrs,
	}
end

local function onWalk(walks, x, z)
	for _, w in ipairs(walks) do
		if Geo.inPart(x, z, w, 1.2) then return true end
	end
	return false
end

-- Laterne: schlanker Stahlmast, ansteigender Ausleger und flacher Kopf mit Leuchtplatte (Neon, Tag "StreetLamp") über der Fahrbahn
local function lamp(parts, x, z, tx, tz, h)
	local yawZ = Geo.yawOf(tx, tz) + 90 -- lokale z-Achse der Teile läuft zur Straße
	local top = WALK_TOP + h
	part(parts, "LaternenFuss", "lamp", x, WALK_TOP + 1.2, z, 1.3, 2.4, 1.3, 0, STEEL, "Metal", { collide = true })
	part(parts, "LaternenMast", "lamp", x, WALK_TOP + h / 2, z, 0.6, h, 0.6, 0, STEEL, "Metal", { collide = true })
	part(parts, "LaternenArm", "lamp", x + tx * 1.6, top + 0.5, z + tz * 1.6, 0.5, 0.5, 3.6, yawZ, STEEL, "Metal", { pitch = -20 })
	part(parts, "LaternenKopf", "lamp", x + tx * 5.2, top + 1.4, z + tz * 5.2, 1.7, 0.8, 4.6, yawZ, STEEL, "Metal")
	part(parts, "LaternenLicht", "lamp", x + tx * 5.2, top + 0.92, z + tz * 5.2, 1.3, 0.2, 3.8, yawZ, WARM, "Neon", { tag = "StreetLamp", attrs = { Lit = true } })
end

-- Signalkopf mit n Lampen (3: rot/gelb/grün, 2: rot/grün), Mitte (x, y, z), Front zeigt in Richtung (fx, fz); heller Rahmen dahinter
local function head(parts, s, x, y, z, lamps, tag)
	local yaw = Geo.yawOf(s.fx, s.fz)
	local n = #lamps
	local hgt = 1.3 * n + 0.7
	part(parts, "AmpelRahmen", "signal", x - s.fx * 0.5, y, z - s.fz * 0.5, 0.15, hgt + 0.9, 2.1, yaw, PLATE, "SmoothPlastic")
	part(parts, "AmpelKopf", "signal", x, y, z, 0.9, hgt, 1.5, yaw, HOUSING, "Metal")
	for i, l in ipairs(lamps) do
		local lit = i == 1 -- Standard: rot an, bis Ampel.lua schaltet
		part(parts, "AmpelLampe", "signal", x + s.fx * 0.55, y + hgt / 2 - 0.35 - 1.3 * (i - 0.5) + 0.3, z + s.fz * 0.55, 0.3, 0.95, 0.95, yaw,
			lit and l.on or l.dim, lit and "Neon" or "SmoothPlastic", { tag = tag, attrs = { Lamp = l.name, Group = s.name, Axis = (s.fz ~= 0) and "NS" or "EW", Lit = lit } })
	end
end

function LightsPlanner.plan(cfg, roadPlan)
	local parts = {}
	local walks = {}
	for _, p in ipairs(roadPlan.parts) do
		if p.kind == "walk" and p.seg then walks[#walks + 1] = p end
	end
	local stats = { lamps = 0, signals = 0, ped = 0 }
	local L = cfg.lamps
	for _, seg in ipairs(roadPlan.segments) do
		local roadHalf
		for _, st in ipairs(seg.prof.strips) do
			if st[3] == "road" then roadHalf = math.max(roadHalf or 0, math.abs(st[1]), math.abs(st[2])) end
		end
		if roadHalf then -- nur Straßen mit Gehweg (Kreisel und Plätze haben keinen)
			local nx, nz = -seg.uz, seg.ux
			for _, side in ipairs({ -1, 1 }) do
				local off = side * (roadHalf + L.inset)
				local t = L.spacing / 2
				while t < seg.len do
					local x, z = seg.ax + seg.ux * t + nx * off, seg.az + seg.uz * t + nz * off
					if onWalk(walks, x, z) then
						lamp(parts, x, z, -nx * side, -nz * side, L.height)
						stats.lamps = stats.lamps + 1
					end
					t = t + L.spacing
				end
			end
		end
	end

	local lamps3 = { { name = "Red", on = RED, dim = DIM.Red }, { name = "Yellow", on = YELLOW, dim = DIM.Yellow }, { name = "Green", on = GREEN, dim = DIM.Green } }
	local lamps2 = { { name = "Red", on = RED, dim = DIM.Red }, { name = "Green", on = GREEN, dim = DIM.Green } }
	local ARM = 14
	for _, s in ipairs(cfg.signals) do
		part(parts, "AmpelMast", "signal", s.x, WALK_TOP + 12, s.z, 0.9, 24, 0.9, 0, STEEL, "Metal", { collide = true })
		part(parts, "AmpelArm", "signal", s.x + s.ax * ARM / 2, WALK_TOP + 21, s.z + s.az * ARM / 2, ARM, 0.5, 0.5, Geo.yawOf(s.ax, s.az), STEEL, "Metal")
		part(parts, "AmpelHalter", "signal", s.x + s.ax * (ARM - 1.5), WALK_TOP + 20, s.z + s.az * (ARM - 1.5), 0.3, 2, 0.3, 0, STEEL, "Metal")
		head(parts, s, s.x + s.ax * (ARM - 1.5) + s.fx * 0.4, WALK_TOP + 17.4, s.z + s.az * (ARM - 1.5) + s.fz * 0.4, lamps3, "TrafficLight")
		head(parts, s, s.x + s.fx * 1.0, WALK_TOP + 9, s.z + s.fz * 1.0, lamps3, "TrafficLight")
		stats.signals = stats.signals + 1
	end
	for _, s in ipairs(cfg.pedSignals) do
		part(parts, "FussgaengerMast", "signal", s.x, WALK_TOP + 5, s.z, 0.7, 10, 0.7, 0, STEEL, "Metal", { collide = true })
		head(parts, s, s.x + s.fx * 0.9, WALK_TOP + 7.8, s.z + s.fz * 0.9, lamps2, "PedLight")
		stats.ped = stats.ped + 1
	end
	return { parts = parts, stats = stats }
end

return LightsPlanner
