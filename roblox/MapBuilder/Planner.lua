-- Planner.lua
-- Reine Geometrie für Reihenhaus-Blockränder. Keine Roblox-Funktionen, läuft in Luau und in Lua 5.1 (Tests).
-- Koordinaten wie im Kartenplan: x = Ost, z = Süd, y = oben. Einheiten: Studs.
-- Lokales Haus-System: x läuft entlang der Fassade, z zeigt von der Fassade in den Block hinein, y nach oben.
-- Alles, was vor der Wand liegt (Fenster, Gesimse, Balkone), hat lokal z < 0.

local Planner = {}

Planner.DEFAULTS = {
	depth = 28, -- Gebäudetiefe
	setback = 2, -- Abstand der Fassade zur Blockkante (der Gehweg liegt schon in der Straße)
	targetWidth = 26, -- Wunschbreite eines Reihenhauses
	floorY = 1, -- Gehweg-Oberkante = Boden des Erdgeschosses
	groundH = 14, -- Höhe Erdgeschoss
	upperH = 12, -- Höhe jedes Obergeschosses
	minFloors = 4,
	maxFloors = 5,
	seed = 1,
	litChance = 0.35, -- Anteil Fenster, die nachts leuchten
	simple = false, -- true: keine Fensterbänke, Balkone, Schornsteine, Seitenfenster (für die Mapgrenze, spart Teile)
	palette = { -- Putzfarben (RGB 0-255)
		{ 236, 226, 200 }, { 232, 208, 150 }, { 214, 200, 178 }, { 228, 186, 150 },
		{ 196, 204, 200 }, { 214, 168, 150 }, { 188, 200, 216 },
	},
}

local function round3(v)
	return math.floor(v * 1000 + 0.5) / 1000
end

local function hash(s)
	local h = 0
	for i = 1, #s do
		h = (h * 31 + string.byte(s, i)) % 2147483647
	end
	return h
end

-- Park-Miller: Zwischenwerte bleiben unter 2^53, daher in Luau und Lua 5.1 identisch.
local function newRng(seed)
	local state = (seed % 2147483646) + 1
	local self = {}
	function self.next()
		state = (state * 16807) % 2147483647
		return state / 2147483647
	end
	function self.int(a, b) -- beide Grenzen eingeschlossen
		return a + math.floor(self.next() * (b - a + 1))
	end
	function self.pick(t)
		return t[self.int(1, #t)]
	end
	return self
end

local function tint(c, f) -- Richtung weiß mischen
	return {
		math.floor(c[1] + (255 - c[1]) * f), math.floor(c[2] + (255 - c[2]) * f), math.floor(c[3] + (255 - c[3]) * f),
	}
end

local function mergeOpts(opts)
	local o = {}
	for k, v in pairs(Planner.DEFAULTS) do o[k] = v end
	if opts then
		for k, v in pairs(opts) do o[k] = v end
	end
	return o
end

-- Teil im lokalen Haus-System anlegen; Position wird in Weltkoordinaten umgerechnet.
local function add(h, name, kind, lx, ly, lz, sx, sy, sz, color, material, extra)
	extra = extra or {}
	local r = math.rad(h.yaw)
	local c, s = math.cos(r), math.sin(r)
	local part = {
		name = name, kind = kind,
		size = { sx, sy, sz },
		pos = { round3(h.ox + lx * c + lz * s), round3(ly), round3(h.oz - lx * s + lz * c) },
		yaw = (h.yaw + (extra.yaw or 0)) % 360,
		color = color, material = material,
		collide = extra.collide == true,
		lit = extra.lit, tag = extra.tag,
		lpos = { lx, ly, lz },
	}
	h.parts[#h.parts + 1] = part
	return part
end

-- Fläche (face) "front", "+x" oder "-x"; u = Position entlang der Fläche, d = Abstand vor der Wand
local function onFace(h, face, u, d)
	if face == "front" then return u, -d, 0 end
	if face == "+x" then return h.width / 2 + d, u, -90 end
	return -h.width / 2 - d, u, 90
end

local FRAME = { 70, 62, 56 }
local GLASS = { 70, 92, 112 }
local GLASS_LIT = { 255, 214, 140 }

-- Fenster: Rahmen und Scheibe sitzen vor der Wand (kein Ausschnitt), Fensterbank darunter.
local function addWindow(h, label, face, u, yc, w, hgt, lit)
	local lx, lz, ey = onFace(h, face, u, 0.2)
	add(h, "Frame" .. label, "frame", lx, yc, lz, w + 1.6, hgt + 1.6, 0.4, FRAME, "SmoothPlastic", { yaw = ey })
	lx, lz = onFace(h, face, u, 0.4)
	add(h, "Glass" .. label, "glass", lx, yc, lz, w, hgt, 0.2, lit and GLASS_LIT or GLASS, "Glass",
		{ yaw = ey, lit = lit, tag = "HouseWindow" })
	if h.simple then return end
	lx, lz = onFace(h, face, u, 0.5)
	add(h, "Sill" .. label, "trim", lx, yc - hgt / 2 - 1.1, lz, w + 3, 0.6, 1.0, { 200, 196, 188 }, "Concrete", { yaw = ey })
end

local function planHouse(h, o, rng, cornerA, cornerB)
	local W, D = h.width, h.depth
	local floors = rng.int(o.minFloors, o.maxFloors)
	if h.forceFloors then floors = h.forceFloors end
	local H = o.groundH + o.upperH * (floors - 1)
	local y0 = o.floorY
	local facade = rng.pick(o.palette)
	local doorSign = (rng.next() < 0.5) and -1 or 1
	local balcony = rng.next() < 0.5
	local staffel = floors == o.minFloors and rng.next() < 0.35
	local chimneys = rng.int(0, 2)
	h.floors, h.height, h.facade = floors, H, facade

	-- Hauptkörper, Sockel, Gesimse, Dachabschluss
	add(h, "Body", "body", 0, y0 + H / 2, D / 2, W, H, D, facade, "SmoothPlastic", { collide = true })
	add(h, "Plinth", "trim", 0, y0 + 1.2, -0.25, W, 2.4, 0.5, { 140, 140, 140 }, "Concrete")
	for k = 1, floors - 1 do
		local yb = y0 + o.groundH + o.upperH * (k - 1)
		add(h, "Ledge" .. k, "trim", 0, yb, -0.4, W, 0.7, 0.8, tint(facade, 0.35), "Concrete")
	end
	add(h, "Cornice", "trim", 0, y0 + H - 0.8, -0.8, W, 1.6, 1.6, tint(facade, 0.45), "Concrete")
	add(h, "Roof", "roof", 0, y0 + H + 0.3, D / 2, W, 0.6, D, { 96, 96, 100 }, "Concrete", { collide = true })
	add(h, "ParapetF", "trim", 0, y0 + H + 1.6, 0.4, W, 2, 0.8, tint(facade, 0.2), "Concrete")
	add(h, "ParapetB", "trim", 0, y0 + H + 1.6, D - 0.4, W, 2, 0.8, tint(facade, 0.2), "Concrete")
	local roofTop = y0 + H + 0.6
	if staffel then
		add(h, "Staffel", "body", 0, roofTop + 5, D / 2, W - 4, 10, D - 12, tint(facade, 0.15), "SmoothPlastic", { collide = true })
		add(h, "StaffelGlass", "glass", 0, roofTop + 5, 5.8, W - 8, 6, 0.3, GLASS, "Glass", { tag = "HouseWindow", lit = false })
		add(h, "StaffelRoof", "roof", 0, roofTop + 10.3, D / 2, W - 3, 0.6, D - 11, { 96, 96, 100 }, "Concrete")
		roofTop = roofTop + 10.6
	end
	for i = 1, h.simple and 0 or chimneys do
		local lim = math.floor(W / 2 - 3)
		add(h, "Chimney" .. i, "chimney", rng.int(-lim, lim), roofTop + 3, D - 6, 2.5, 6, 2.5, { 170, 100, 80 }, "Brick")
	end

	-- Obergeschoss-Fenster (vorne) und optionale Balkone
	local nw = math.max(2, math.floor((W - 4) / 9))
	for k = 1, floors - 1 do
		local yb = y0 + o.groundH + o.upperH * (k - 1)
		for i = 1, nw do
			addWindow(h, "F" .. k .. "_" .. i, "front", -W / 2 + (i - 0.5) * W / nw, yb + 6, 4.4, 6.4, rng.next() < o.litChance)
		end
		if balcony and k >= 2 and not h.simple then
			local bw = math.min(14, W - 10)
			add(h, "Balcony" .. k, "balcony", 0, yb + 0.3, -1.25, bw, 0.6, 2.5, { 150, 150, 150 }, "Concrete")
			add(h, "Rail" .. k, "balcony", 0, yb + 2.1, -2.35, bw, 3, 0.3, { 60, 60, 66 }, "Metal")
		end
	end

	-- Erdgeschoss: Tür auf einer Seite, Schaufenster auf der anderen
	local a = W / 2 - 6
	local dx = doorSign * a
	add(h, "DoorFrame", "frame", dx, y0 + 5, -0.25, 6.4, 10, 0.5, { 70, 52, 42 }, "Wood")
	add(h, "Door", "door", dx, y0 + 4.5, -0.55, 5, 9, 0.3, { 110, 70, 45 }, "Wood")
	add(h, "DoorCanopy", "trim", dx, y0 + 10.6, -1, 7, 0.5, 2, { 120, 120, 124 }, "Concrete")
	local nwg = math.max(1, math.floor((W - 21) / 9) + 1)
	for i = 1, nwg do
		addWindow(h, "G_" .. i, "front", -dx + doorSign * 9 * (i - 1), y0 + 8, 4.4, 5.4, rng.next() < o.litChance)
	end

	-- Eckhaus: Fenster auch an der Seitenfläche zur Querstraße
	for _, face in ipairs({ cornerA and "-x" or false, cornerB and "+x" or false }) do
		if face then
			for _, u in ipairs({ 7, D - 7 }) do
				for k = 1, floors - 1 do
					addWindow(h, "SideF" .. k .. "_" .. face .. u, face, u, y0 + o.groundH + o.upperH * (k - 1) + 6, 4.4, 6.4, rng.next() < o.litChance)
				end
				addWindow(h, "SideG_" .. face .. u, face, u, y0 + 8, 4.4, 5.4, rng.next() < o.litChance)
			end
		end
	end
end

-- Häuser entlang mehrerer Fassadenlinien. side = { name, yaw, sx, sz, ux, uz, len, corners, ranges }
-- ranges = { { t0, t1 }, ... } begrenzt die bebaubaren Abschnitte (Lücken z. B. für Tore); Standard: ganze Länge.
local function planSides(name, sides, o, rng, plan, depth)
	for _, side in ipairs(sides) do
		local ranges = side.ranges or { { 0, side.len } }
		local idx = 0
		for ri, range in ipairs(ranges) do
			local len = range[2] - range[1]
			if len >= 12 then
				local n = math.max(1, math.floor(len / o.targetWidth + 0.5))
				local width = len / n
				for i = 0, n - 1 do
					idx = idx + 1
					local t = range[1] + (i + 0.5) * width
					local h = {
						side = side.name, index = idx, simple = o.simple,
						ox = side.sx + side.ux * t, oz = side.sz + side.uz * t,
						yaw = side.yaw, width = width, depth = depth, parts = {},
						name = string.format("Haus_%s_%s%d", name, side.name, idx),
					}
					planHouse(h, o, rng, side.corners and ri == 1 and i == 0, side.corners and ri == #ranges and i == n - 1)
					plan.houses[#plan.houses + 1] = h
				end
			end
		end
	end
end

-- block = { name, xmin, zmin, xmax, zmax } (Außenkante = Straßenrand). Gibt den Bauplan zurück.
function Planner.planBlock(block, opts)
	local o = mergeOpts(opts)
	local rng = newRng(o.seed + hash(block.name))
	local s, D = o.setback, o.depth
	local xmin, zmin, xmax, zmax = block.xmin, block.zmin, block.xmax, block.zmax
	local sides = {
		{ name = "N", yaw = 0, sx = xmin + s, sz = zmin + s, ux = 1, uz = 0, len = (xmax - xmin) - 2 * s, corners = true },
		{ name = "S", yaw = 180, sx = xmax - s, sz = zmax - s, ux = -1, uz = 0, len = (xmax - xmin) - 2 * s, corners = true },
		{ name = "W", yaw = 90, sx = xmin + s, sz = zmax - s - D, ux = 0, uz = -1, len = (zmax - zmin) - 2 * s - 2 * D, corners = false },
		{ name = "E", yaw = 270, sx = xmax - s, sz = zmin + s + D, ux = 0, uz = 1, len = (zmax - zmin) - 2 * s - 2 * D, corners = false },
	}
	local plan = {
		block = block, houses = {},
		courtyard = { xmin + s + D, zmin + s + D, xmax - s - D, zmax - s - D },
	}
	planSides(block.name, sides, o, rng, plan, D)
	return plan
end

-- Mapgrenze: Häuserband rund um die Karte, Fassade zeigt nach innen zur Ringstraße.
-- wall = { inner = {xmin,zmin,xmax,zmax} (Ringaußenkante), outer = {...} (Kartenrand), gates = { N = {{x0,x1},...}, S = ... },
--          specials = { { side, name, x0, x1, floors } } }
function Planner.planWall(wall, opts)
	local o = mergeOpts(opts)
	o.simple, o.setback = true, 0
	local D = wall.outer.xmin - wall.inner.xmin
	D = math.abs(D)
	local rng = newRng(o.seed + hash("Mapgrenze"))
	local ix0, iz0, ix1, iz1 = wall.inner.xmin, wall.inner.zmin, wall.inner.xmax, wall.inner.zmax
	local ox0, oz0, oz1 = wall.outer.xmin, wall.outer.zmin, wall.outer.zmax
	local function ranges(len, startCoord, dirSign, gaps) -- Lücken (Weltkoordinate) in Abschnitte entlang der Laufrichtung umrechnen
		local cuts = {}
		for _, g in ipairs(gaps or {}) do
			local a, b = (g[1] - startCoord) * dirSign, (g[2] - startCoord) * dirSign
			if a > b then a, b = b, a end
			cuts[#cuts + 1] = { a, b }
		end
		table.sort(cuts, function(p, q) return p[1] < q[1] end)
		local out, pos = {}, 0
		for _, c in ipairs(cuts) do
			if c[1] > pos then out[#out + 1] = { pos, c[1] } end
			pos = math.max(pos, c[2])
		end
		if pos < len then out[#out + 1] = { pos, len } end
		return out
	end
	local innerW = ix1 - ix0
	local sides = {
		{ name = "N", yaw = 180, sx = ix1, sz = iz0, ux = -1, uz = 0, len = innerW, ranges = ranges(innerW, ix1, -1, wall.gates.N) },
		{ name = "S", yaw = 0, sx = ix0, sz = iz1, ux = 1, uz = 0, len = innerW, ranges = ranges(innerW, ix0, 1, wall.gates.S) },
		{ name = "W", yaw = 270, sx = ix0, sz = oz0, ux = 0, uz = 1, len = oz1 - oz0 },
		{ name = "E", yaw = 90, sx = ix1, sz = oz1, ux = 0, uz = -1, len = oz1 - oz0 },
	}
	local plan = { houses = {}, wall = wall }
	planSides("Wand", sides, o, rng, plan, D)
	-- Sonderbauten in den Lücken (Querriegel, Feldherrnhalle)
	for _, sp in ipairs(wall.specials) do
		local w = sp.x1 - sp.x0
		local north = sp.side == "N"
		local h = {
			side = sp.side, index = 0, simple = true, forceFloors = sp.floors,
			ox = (sp.x0 + sp.x1) / 2, oz = north and iz0 or iz1,
			yaw = north and 180 or 0, width = w, depth = D, parts = {}, name = "Sonder_" .. sp.name,
		}
		planHouse(h, o, rng, false, false)
		plan.houses[#plan.houses + 1] = h
	end
	return plan
end

-- Achsparallele Außenmaße eines Teils (Drehung nur in 90-Grad-Schritten).
function Planner.aabb(p)
	local sx, sy, sz = p.size[1], p.size[2], p.size[3]
	if p.yaw % 180 == 90 then sx, sz = sz, sx end
	return p.pos[1] - sx / 2, p.pos[2] - sy / 2, p.pos[3] - sz / 2, p.pos[1] + sx / 2, p.pos[2] + sy / 2, p.pos[3] + sz / 2
end

function Planner.stats(plan)
	local parts, area = 0, 0
	for _, h in ipairs(plan.houses) do
		parts = parts + #h.parts
		area = area + h.width * h.depth
	end
	return { houses = #plan.houses, parts = parts, footprint = area }
end

return Planner
