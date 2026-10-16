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
		color = color, material = material, collide = extra.collide == true, tag = extra.tag, attrs = extra.attrs, shape = extra.shape, roll = extra.roll,
	}
end

local function inDriveway(cfg, x, z)
	for _, d in ipairs(cfg.driveways or {}) do
		if x > d.x0 - 1 and x < d.x1 + 1 and z > d.z0 - 3 and z < d.z1 + 3 then return true end
	end
	return false
end

local function onWalk(walks, x, z)
	for _, w in ipairs(walks) do
		if Geo.inPart(x, z, w, 1.2) then return true end
	end
	return false
end

-- Laterne (abgerundet): runder Fuß, zweistufiger konischer Zylindermast, Bogenarm aus vier Zylinderstücken (Viertelkreis, Radius 5),
-- walzenförmiger Kopf mit Leuchtlinse unten (Neon, Tag "StreetLamp") über der Fahrbahn
local function lamp(parts, x, z, tx, tz, h)
	local yawT = Geo.yawOf(tx, tz)
	local top = WALK_TOP + h
	local CYL = { shape = "Cylinder", roll = 90 }
	local function cyl(name, px, py, pz, len, dia, collide) part(parts, name, "lamp", px, py, pz, len, dia, dia, 0, STEEL, "Metal", { collide = collide, shape = "Cylinder", roll = 90 }) end
	cyl("LaternenFuss", x, WALK_TOP + 1.2, z, 2.4, 2.0, true)
	local lowH = h * 0.55
	cyl("LaternenMast", x, WALK_TOP + lowH / 2, z, lowH, 1.0, true)
	cyl("LaternenMastOben", x, WALK_TOP + lowH + (h - lowH) / 2, z, h - lowH, 0.65, true)
	local r, n = 5, 4
	for k = 1, n do
		local a0, a1 = (k - 1) / n * math.pi / 2, k / n * math.pi / 2
		local px0, py0, px1, py1 = r * (1 - math.cos(a0)), r * math.sin(a0), r * (1 - math.cos(a1)), r * math.sin(a1)
		local len = math.sqrt((px1 - px0) ^ 2 + (py1 - py0) ^ 2) + 0.25
		part(parts, "LaternenArm", "lamp", x + tx * (px0 + px1) / 2, top + (py0 + py1) / 2, z + tz * (px0 + px1) / 2, len, 0.5, 0.5, yawT, STEEL, "Metal",
			{ shape = "Cylinder", roll = math.deg(math.atan2(py1 - py0, px1 - px0)) })
	end
	part(parts, "LaternenArm", "lamp", x + tx * (r + 1.2), top + r, z + tz * (r + 1.2), 2.6, 0.5, 0.5, yawT, STEEL, "Metal", { shape = "Cylinder" })
	part(parts, "LaternenKopf", "lamp", x + tx * (r + 4.8), top + r, z + tz * (r + 4.8), 5.2, 1.7, 1.7, yawT, STEEL, "Metal", { shape = "Cylinder" })
	part(parts, "LaternenLicht", "lamp", x + tx * (r + 4.8), top + r - 0.8, z + tz * (r + 4.8), 0.25, 1.9, 1.9, 0, WARM, "Neon", { shape = "Cylinder", roll = 90, tag = "StreetLamp", attrs = { Lit = true } })
end

-- Signalkopf mit n Lampen (3: rot/gelb/grün, 2: rot/grün), Mitte (x, y, z), Front zeigt in Richtung (fx, fz): heller Rahmen, schlankes Gehäuse,
-- je Lampe ein rundes Blendenrohr (Zylinder) mit runder Linse davor
local function head(parts, s, x, y, z, lamps, tag)
	local yaw = Geo.yawOf(s.fx, s.fz)
	local n = #lamps
	local sp = 1.7
	local hgt = sp * n + 0.6
	part(parts, "AmpelRahmen", "signal", x - s.fx * 0.55, y, z - s.fz * 0.55, 0.15, hgt + 0.9, 2.3, yaw, PLATE, "SmoothPlastic")
	part(parts, "AmpelKopf", "signal", x - s.fx * 0.1, y, z - s.fz * 0.1, 0.7, hgt, 1.2, yaw, HOUSING, "Metal")
	for i, l in ipairs(lamps) do
		local yy = y + hgt / 2 - 0.3 - sp * (i - 0.5)
		part(parts, "AmpelBlende", "signal", x + s.fx * 0.45, yy, z + s.fz * 0.45, 0.9, 1.5, 1.5, yaw, HOUSING, "Metal", { shape = "Cylinder" })
		local lit = i == 1 -- Standard: rot an, bis Ampel.lua schaltet
		part(parts, "AmpelLampe", "signal", x + s.fx * 0.95, yy, z + s.fz * 0.95, 0.3, 1.25, 1.25, yaw,
			lit and l.on or l.dim, lit and "Neon" or "SmoothPlastic", { shape = "Cylinder", tag = tag, attrs = { Lamp = l.name, Group = s.name, Axis = (s.fz ~= 0) and "NS" or "EW", Lit = lit } })
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
		local custom = seg.prof.lamps -- eigene Laternenstreifen (Isar-Allee: zwischen Fahrbahn und Radweg), Arm zeigt zur Fahrbahn
		if custom then
			local nx, nz = -seg.uz, seg.ux
			for _, off in ipairs(custom.offsets) do
				local t = custom.spacing / 2 + 12
				while t < seg.len - 30 do
					local sg = (off > 0) and 1 or -1
					lamp(parts, seg.ax + seg.ux * t + nx * off, seg.az + seg.uz * t + nz * off, -nx * sg, -nz * sg, L.height)
					stats.lamps = stats.lamps + 1
					t = t + custom.spacing
				end
			end
		end
		if roadHalf and not custom then -- nur Straßen mit Gehweg (Kreisel und Plätze haben keinen)
			local nx, nz = -seg.uz, seg.ux
			for _, side in ipairs({ -1, 1 }) do
				local off = side * (roadHalf + L.inset)
				local t = L.spacing / 2
				while t < seg.len do
					local x, z = seg.ax + seg.ux * t + nx * off, seg.az + seg.uz * t + nz * off
					if onWalk(walks, x, z) and not inDriveway(cfg, x, z) then
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
		part(parts, "AmpelMast", "signal", s.x, WALK_TOP + 7.5, s.z, 15, 1.1, 1.1, 0, STEEL, "Metal", { collide = true, shape = "Cylinder", roll = 90 })
		part(parts, "AmpelMastOben", "signal", s.x, WALK_TOP + 19.5, s.z, 9, 0.8, 0.8, 0, STEEL, "Metal", { collide = true, shape = "Cylinder", roll = 90 })
		part(parts, "AmpelKappe", "signal", s.x, WALK_TOP + 24.2, s.z, 1.2, 1.2, 1.2, 0, STEEL, "Metal", { shape = "Ball" })
		part(parts, "AmpelGelenk", "signal", s.x, WALK_TOP + 21, s.z, 1.6, 1.6, 1.6, 0, STEEL, "Metal", { shape = "Ball" })
		part(parts, "AmpelArm", "signal", s.x + s.ax * ARM / 2, WALK_TOP + 21, s.z + s.az * ARM / 2, ARM, 0.6, 0.6, Geo.yawOf(s.ax, s.az), STEEL, "Metal", { shape = "Cylinder" })
		part(parts, "AmpelHalter", "signal", s.x + s.ax * (ARM - 1.5), WALK_TOP + 20, s.z + s.az * (ARM - 1.5), 2, 0.35, 0.35, 0, STEEL, "Metal", { shape = "Cylinder", roll = 90 })
		head(parts, s, s.x + s.ax * (ARM - 1.5) + s.fx * 0.4, WALK_TOP + 17.4, s.z + s.az * (ARM - 1.5) + s.fz * 0.4, lamps3, "TrafficLight")
		head(parts, s, s.x + s.fx * 1.0, WALK_TOP + 9, s.z + s.fz * 1.0, lamps3, "TrafficLight")
		stats.signals = stats.signals + 1
	end
	for _, s in ipairs(cfg.pedSignals) do
		part(parts, "FussgaengerMast", "signal", s.x, WALK_TOP + 5, s.z, 10, 0.8, 0.8, 0, STEEL, "Metal", { collide = true, shape = "Cylinder", roll = 90 })
		head(parts, s, s.x + s.fx * 0.9, WALK_TOP + 7.8, s.z + s.fz * 0.9, lamps2, "PedLight")
		stats.ped = stats.ped + 1
	end
	return { parts = parts, stats = stats }
end

return LightsPlanner
