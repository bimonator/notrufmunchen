-- MapBuilder_Plugin.lua  (automatisch erzeugt mit make_bundles.py, nicht von Hand ändern)
-- Dauerhaft bauen: in Workspace ein Script anlegen, alles einfügen, Rechtsklick auf das Script >
-- "Als lokales Plugin speichern". Danach das Script löschen. Im Reiter Plugins erscheint der Knopf "Karte bauen".
-- Der Knopf baut im Edit-Modus, die Objekte bleiben im Projekt erhalten (Strg+Z macht es rückgängig).
local ORIGIN = Vector3.new(0, 0, 0) -- Position des Siegestors

local Geo = (function()

local Geo = {}

function Geo.round3(v)
	return math.floor(v * 1000 + 0.5) / 1000
end

function Geo.dir(ax, az, bx, bz)
	local dx, dz = bx - ax, bz - az
	local l = math.sqrt(dx * dx + dz * dz)
	return dx / l, dz / l, l
end

function Geo.yawOf(ux, uz)
	return math.deg(math.atan2(-uz, ux)) % 360
end

function Geo.rect(ax, az, bx, bz, hw, extA, extB)
	local ux, uz, l = Geo.dir(ax, az, bx, bz)
	return { ax = ax, az = az, ux = ux, uz = uz, nx = -uz, nz = ux, s0 = -extA, s1 = l + extB, w = hw }
end

function Geo.within(px, pz, ux, uz, L, r, margin)
	margin = margin or 0
	local lo, hi = 0, L
	local function clip(c0, c1, a, b) -- c0 + c1*t muss in [a, b] liegen
		if math.abs(c1) < 1e-9 then return c0 >= a and c0 <= b end
		local t0, t1 = (a - c0) / c1, (b - c0) / c1
		if t0 > t1 then t0, t1 = t1, t0 end
		if t0 > lo then lo = t0 end
		if t1 < hi then hi = t1 end
		return lo < hi
	end
	local dx, dz = px - r.ax, pz - r.az
	if not clip(dx * r.ux + dz * r.uz, ux * r.ux + uz * r.uz, r.s0 + margin, r.s1 - margin) then return nil end
	if not clip(dx * r.nx + dz * r.nz, ux * r.nx + uz * r.nz, -r.w + margin, r.w - margin) then return nil end
	if hi - lo < 1e-6 then return nil end
	return lo, hi
end

function Geo.polyDist(x, z, pts)
	local best = 1e9
	for i = 1, #pts - 1 do
		local ax, az, bx, bz = pts[i][1], pts[i][2], pts[i + 1][1], pts[i + 1][2]
		local dx, dz = bx - ax, bz - az
		local t = math.max(0, math.min(1, ((x - ax) * dx + (z - az) * dz) / (dx * dx + dz * dz)))
		local px, pz = ax + t * dx - x, az + t * dz - z
		best = math.min(best, math.sqrt(px * px + pz * pz))
	end
	return best
end

function Geo.rectsOverlap(a, b)
	local function corners(r)
		local out = {}
		for _, s in ipairs({ r.s0, r.s1 }) do
			for _, w in ipairs({ -r.w, r.w }) do
				out[#out + 1] = { r.ax + r.ux * s + r.nx * w, r.az + r.uz * s + r.nz * w }
			end
		end
		return out
	end
	local ca, cb = corners(a), corners(b)
	for _, r in ipairs({ a, b }) do
		for _, axis in ipairs({ { r.ux, r.uz }, { r.nx, r.nz } }) do
			local amin, amax, bmin, bmax = 1e18, -1e18, 1e18, -1e18
			for _, c in ipairs(ca) do local d = c[1] * axis[1] + c[2] * axis[2] amin, amax = math.min(amin, d), math.max(amax, d) end
			for _, c in ipairs(cb) do local d = c[1] * axis[1] + c[2] * axis[2] bmin, bmax = math.min(bmin, d), math.max(bmax, d) end
			if amax < bmin + 0.5 or bmax < amin + 0.5 then return false end
		end
	end
	return true
end

function Geo.subtract(spans, cuts)
	local out = {}
	for _, s in ipairs(spans) do
		local pieces = { { s[1], s[2] } }
		for _, c in ipairs(cuts) do
			local nxt = {}
			for _, p in ipairs(pieces) do
				if c[2] <= p[1] or c[1] >= p[2] then
					nxt[#nxt + 1] = p
				else
					if c[1] > p[1] then nxt[#nxt + 1] = { p[1], c[1] } end
					if c[2] < p[2] then nxt[#nxt + 1] = { c[2], p[2] } end
				end
			end
			pieces = nxt
		end
		for _, p in ipairs(pieces) do out[#out + 1] = p end
	end
	return out
end

function Geo.inPart(px, pz, p, margin)
	margin = margin or 0
	local r = math.rad(p.yaw)
	local c, s = math.cos(r), math.sin(r)
	local dx, dz = px - p.pos[1], pz - p.pos[3]
	local lx, lz = dx * c - dz * s, dx * s + dz * c -- Umkehrung der Drehung
	return math.abs(lx) <= p.size[1] / 2 - margin and math.abs(lz) <= p.size[3] / 2 - margin
end

return Geo

end)()

local Config = (function()

local C = {}

C.groundTop = -2

C.map = { xmin = -745, zmin = -556, xmax = 1260, zmax = 494 } -- Osten um 100 Studs erweitert (Isar-Allee)
C.ring = { xmin = -685, zmin = -496, xmax = 1200, zmax = 434 } -- Außenkante der Ringstraße = Innenkante der Mapgrenze

C.profiles = {
	std48 = { half = 24, dashes = { 0 }, strips = { { -24, -14, "walk" }, { -14, 14, "road" }, { 14, 24, "walk" } } },
	raster57 = { half = 28.5, dashes = { -4.5 }, strips = { { -28.5, -18.5, "walk" }, { -18.5, 18.5, "road" }, { 18.5, 28.5, "walk" } } },
	axis110 = {
		half = 55, dashes = { -20, 20 },
		strips = {
			{ -55, -43, "walk" }, { -43, -34, "road" }, { -34, -6, "road" }, { -6, 6, "median" },
			{ 6, 34, "road" }, { 34, 43, "road" }, { 43, 55, "walk" },
		},
	},
	allee = {
		half = 35.5, dashes = { -8.5 }, lamps = { offsets = { 3.5 }, spacing = 48 },
		strips = { { -35.5, -27.5, "walk" }, { -27.5, 1.5, "road" }, { 1.5, 5.5, "green" }, { 5.5, 13.5, "bike" }, { 13.5, 25.5, "green" }, { 25.5, 33.5, "walk" } }, -- Ufergehweg 8 breit, endet 3 Studs vor der Böschungskante
	},
	approach86 = { half = 43, dashes = {}, strips = { { -43, 43, "road" } } }, -- Zulauf der Achse zum Kreisverkehr (ohne Mittelstreifen)
	kreisel24 = { half = 12, dashes = {}, strips = { { -12, 12, "road" } } },
	plaza40 = { half = 20, dashes = {}, strips = { { -20, 20, "plaza" } } },
}

local function circle(cx, cz, r, n)
	local pts = {}
	for i = 0, n - 1 do
		local a = 2 * math.pi * i / n
		pts[#pts + 1] = { cx + r * math.cos(a), cz + r * math.sin(a) }
	end
	return pts
end

C.roads = {
	{ name = "Ring", closed = true, profile = "std48", pts = { { -661, -472 }, { 1176, -472 }, { 1176, 410 }, { -661, 410 } } },
	{ name = "AchseNord", profile = "axis110", pts = { { 0, -472 }, { 0, -84 } } },
	{ name = "ZulaufNord", profile = "approach86", pts = { { 0, -84 }, { 0, -60 } } },
	{ name = "ZulaufSued", profile = "approach86", pts = { { 0, 60 }, { 0, 84 } } },
	{ name = "AchseSued", profile = "axis110", pts = { { 0, 84 }, { 0, 410 } } },
	{ name = "SiegestorKreisel", closed = true, profile = "kreisel24", pts = circle(0, 0, 68, 24) },
	{ name = "V1", profile = "raster57", pts = { { -460, 30 }, { -460, -472 } } },
	{ name = "V2", profile = "raster57", pts = { { -235, 30 }, { -235, -472 } } },
	{ name = "H1", profile = "raster57", pts = { { -661, -285 }, { 0, -285 } } },
	{ name = "H2", profile = "raster57", pts = { { -661, 30 }, { -61, 30 } } },
	{ name = "Diagonale", profile = "std48", pts = { { 61, 30 }, { 290, 36 }, { 455, -77 }, { 605, -212 }, { 770, -347 }, { 790, -472 } } },
	{ name = "Isarspange", profile = "std48", pts = { { 455, -77 }, { 700, -60 }, { 780, -40 }, { 1012, 3 }, { 1030, 70 }, { 1055, 140 }, { 1110, 190 }, { 1176, 210 } } },
	{ name = "V3", profile = "std48", pts = { { 300, -472 }, { 300, 32 } } },
	{ name = "KirchplatzNord", profile = "std48", pts = { { -550, 30 }, { -550, 140 } } }, -- endet am Kirchplatz der Frauenkirche
	{ name = "IsarAllee", profile = "allee", pts = { { 1072.5, -472 }, { 1012, 3 } } },
	{ name = "Maximilianstrasse", profile = "std48", pts = { { 395, 410 }, { 395, 298 }, { 876, 298 } } }, -- vom Ring zur Maximilianbrücke und den Stufen zum Friedensengel
	{ name = "Fussgaengerzone", profile = "plaza40", pts = { { -200, 254 }, { -55, 254 } } },
}

C.bay = { length = 16, width = 9 }
C.tankstelle = { lot = { 57, -336, 180, -150 }, gaps = { { -262, -218 }, { -196, -152 } }, ev = { x0 = 162, x1 = 178, z0 = -290, n = 8, w = 9 } } -- ev: E-Ladepark an der Ostseite (Stellplatzfeld)
C.driveways = {}
for _, g in ipairs(C.tankstelle.gaps) do C.driveways[#C.driveways + 1] = { x0 = 43, x1 = 57, z0 = g[1] - 3, z1 = g[2] + 3 } end

C.bays = {
	{ 38.5, -448, 38.5, -340 }, { 38.5, -334, 38.5, -274 }, { 38.5, -140, 38.5, -98 }, -- Achse Ost: Lücke vor der Tankstelleneinfahrt
	{ -38.5, -448, -38.5, -314 }, { -38.5, -257, -38.5, -98 }, { -38.5, 98, -38.5, 226 }, { 38.5, 98, 38.5, 286 },
	{ -633, -271, -497, -271 }, { -432, -271, -272, -271 }, { -207, -271, -59, -271 },
	{ -633, 44, -578, 44 }, { -522, 44, -497, 44 }, { -432, 44, -272, 44 }, { -207, 44, -59, 44 },
	{ -446, -448, -446, -317 }, { -446, -253, -446, -211 }, { -446, -89, -446, -3 },
	{ -221, -448, -221, -317 }, { -221, -253, -221, -3 },
}

C.allee = { road = "IsarAllee", rowFrom = 28, rowTo = 436, church = { 190, 244 }, bay = { from = 40, to = 430, off = 23 }, trees = { from = 40, to = 440, step = 24, off = 19.5 } }
do
	local r
	for _, rd in ipairs(C.roads) do if rd.name == "IsarAllee" then r = rd end end
	local ax, az, bx, bz = r.pts[1][1], r.pts[1][2], r.pts[2][1], r.pts[2][2]
	local l = math.sqrt((bx - ax) ^ 2 + (bz - az) ^ 2)
	local ux, uz = (bx - ax) / l, (bz - az) / l
	local ex, ez = uz, -ux -- Osten (quer zur Straße, Gegenrichtung der Normalen)
	local b = C.allee.bay
	C.bays[#C.bays + 1] = { ax + ux * b.from + ex * b.off, az + uz * b.from + ez * b.off, ax + ux * b.to + ex * b.off, az + uz * b.to + ez * b.off }
	C.allee.ux, C.allee.uz, C.allee.len, C.allee.ax, C.allee.az = ux, uz, l, ax, az
end

C.plazas = {
	{ name = "Odeonsplatz", x0 = -140, z0 = 296, x1 = 140, z1 = 386 },
	{ name = "Kirchplatz", x0 = -634, z0 = 140, x1 = -200, z1 = 368 }, -- Platz um die Frauenkirche (Kreisel entfällt)
}

C.bridges = {
	{ name = "B0", x = 640, z = -257, len = 56, wid = 48, yaw = 39.3 },
	{ name = "B1", x = 661, z = -62, len = 56, wid = 48, yaw = 356 },
	{ name = "B5", x = 672, z = 120, len = 44, wid = 10, yaw = 0, pedestrian = true },
}

C.isarBridges = {
	{ name = "B2", x = 887, z = -19, len = 214, wid = 28, walk = 14, yaw = 349.4, pier = 36 },
	{ name = "B3", x = 692, z = 410, len = 252, wid = 28, walk = 14, yaw = 0, pier = 36 }, -- Luitpoldbrücke über Bach und Isar
	{ name = "B4", x = 945, z = -472, len = 214, wid = 28, walk = 14, yaw = 0, pier = 36 },
	{ name = "B6", style = "maximilian", x = 751, z = 298, len = 244, wid = 28, walk = 14, yaw = 0, span = 60, rise = 4.5 },
}

C.water = {
	isar = {
		pts = { { 945, -556 }, { 945, -472 }, { 885, 0 }, { 850, 100 }, { 800, 200 }, { 750, 300 }, { 705, 390 }, { 695, 410 }, { 670, 494 } },
		layers = { { 0, -4, 90 }, { -4, -8, 60 }, { -8, -12, 36 }, { -12, -14, 30 } }, waterTop = -8,
		fills = { { -18, -12, 36, "Sand" }, { -12, -8, 60, "Sand" }, { -8, -4, 90, "Grass" } }, -- Sandbett, Kiesbank und Gras-Uferweg (vor dem Ausheben eingefüllt)
	},
	bach = {
		pts = { { 640, -257 }, { 642, -226 }, { 665, -31 }, { 672, 194 }, { 650, 330 }, { 620, 410 }, { 612, 494 } },
		layers = { { 0, -4, 13 }, { -4, -7, 7 } }, waterTop = -4,
		fills = { { -11, -4, 13, "Sand" } }, -- Bachbett und Böschung aus Sand
	},
}

C.parks = { -- Gras-Oberfläche (Terrain)
	{ name = "Hofgarten", x0 = 60, z0 = 100, x1 = 400, z1 = 290 },
	{ name = "EnglischerGarten", x0 = 430, z0 = -45, x1 = 700, z1 = 345 },
	{ name = "Hinterhofpark", x0 = -401.5, z0 = -418, x1 = -293.5, z1 = -343.5 },
}
C.hills = { { name = "Monopteros", x = 575, z = 75, layers = { { 44, 0, 4 }, { 30, 4, 8 } } } } -- { Radius, y0, y1 }, nur 8 hoch
C.terrace = { name = "Friedensengel", x0 = 890, z0 = 250, x1 = 1040, z1 = 346, height = 4 }

C.lamps = { spacing = 64, inset = 2.5, height = 36 }

C.signals = {
	{ name = "Achse_RingNord", x = 45, z = -445, fx = 0, fz = 1, ax = -1, az = 0 }, { name = "Achse_RingNord", x = -58, z = -456, fx = -1, fz = 0, ax = 0, az = -1 },
	{ name = "Achse_RingNord", x = 58, z = -488, fx = 1, fz = 0, ax = 0, az = 1 },
	{ name = "Achse_H1", x = -45, z = -317, fx = 0, fz = -1, ax = 1, az = 0 }, { name = "Achse_H1", x = 45, z = -254, fx = 0, fz = 1, ax = -1, az = 0 },
	{ name = "Achse_H1", x = -58, z = -264, fx = -1, fz = 0, ax = 0, az = -1 },
	{ name = "Achse_Odeonsplatz", x = -45, z = 288, fx = 0, fz = -1, ax = 1, az = 0 }, { name = "Achse_Odeonsplatz", x = -58, z = 427, fx = -1, fz = 0, ax = 0, az = -1 },
	{ name = "Achse_Odeonsplatz", x = 58, z = 393, fx = 1, fz = 0, ax = 0, az = 1 },
	{ name = "Wache_V1", x = -436.5, z = -90, fx = 0, fz = 1, ax = -1, az = 0 }, { name = "Wache_V1", x = -483.5, z = -210, fx = 0, fz = -1, ax = 1, az = 0 },
	{ name = "Wache_V2", x = -211.5, z = -90, fx = 0, fz = 1, ax = -1, az = 0 }, { name = "Wache_V2", x = -258.5, z = -210, fx = 0, fz = -1, ax = 1, az = 0 },
}
C.pedSignals = {} -- die Fußgängerampeln am Siegestor entfallen (Kreisverkehr)

C.landmarks = {
	siegestor = { x = 0, z = 0, baseY = 1.4, islandR = 52, ringR = 68 }, -- steht auf der Mittelinsel des Kreisverkehrs
	friedensengel = { x = 965, z = 298, baseY = 3.7 },
	frauenkirche = { x0 = -610, x1 = -215, z = 254, baseY = 0.7, width = 150, wallH = 72, roofRise = 62, towerH = 210 }, -- auf dem Kirchplatz, Türme im Westen
	turm = { x = 573, z = 224, baseY = 0.2 }, -- Chinesischer Turm im Englischen Garten, Biergarten rundherum
	biergarten = { x0 = 532, z0 = 186, x1 = 614, z1 = 262 },
	eisbach = { z = 366 }, -- Eisbachwelle: Stelle am Bach, wo z so groß ist (südlich vom Park, neben Prinz Eins)
}

C.wall = {
	gates = { N = { { -60, 60 }, { 835, 1055 } }, S = { { -40, 40 }, { 560, 780 } } },
	specials = { { side = "N", name = "Querriegel", x0 = -60, x1 = 60, floors = 10 }, { side = "S", name = "Feldherrnhalle", x0 = -40, x1 = 40, floors = 2 } },
	riverGates = { { side = "N", x0 = 835, x1 = 1055 }, { side = "S", x0 = 560, x1 = 780 } }, -- Brückenhaus: Gebäude über dem Fluss
}

return C

end)()

local Planner = (function()

local Planner = {}

Planner.DEFAULTS = {
	depth = 28, -- Gebäudetiefe
	setback = 2, -- Abstand der Fassade zur Blockkante (der Gehweg liegt schon in der Straße)
	targetWidth = 30, -- Mindest-Durchschnittsbreite eines Hauses (Anzahl = Länge / targetWidth, abgerundet)
	floorY = 1, -- Gehweg-Oberkante = Boden des Erdgeschosses
	groundH = 14, -- Höhe Erdgeschoss
	upperH = 12, -- Höhe jedes Obergeschosses
	floorWeights = { { 3, 0.2 }, { 4, 0.35 }, { 5, 0.3 }, { 6, 0.15 } }, -- Geschosse und ihre Häufigkeit
	seed = 1,
	litChance = 0.35, -- Anteil Fenster, die nachts leuchten
	simple = false, -- true: keine Fensterbänke, Balkone, Schornsteine, Erker, Seitenfenster (Mapgrenze, spart Teile)
	palette = { -- Putzfarben (RGB 0-255)
		{ 236, 226, 200 }, { 232, 208, 150 }, { 214, 200, 178 }, { 228, 186, 150 }, { 196, 204, 200 }, { 214, 168, 150 },
		{ 188, 200, 216 }, { 240, 224, 160 }, { 222, 170, 130 }, { 240, 238, 232 }, { 176, 190, 170 }, { 200, 200, 204 },
		{ 238, 214, 140 }, { 206, 224, 214 }, { 232, 196, 196 }, { 210, 214, 226 }, { 226, 220, 200 }, { 244, 226, 168 },
	},
}
local PALAZZO = { { 226, 216, 196 }, { 214, 200, 170 }, { 232, 222, 200 }, { 206, 190, 164 } }
local JUGEND = { { 238, 214, 140 }, { 244, 226, 168 }, { 226, 196, 150 }, { 232, 206, 196 }, { 204, 214, 200 } }
local MODERN = { { 196, 198, 204 }, { 176, 182, 190 }, { 214, 214, 208 }, { 150, 160, 170 } }

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
	function self.weighted(list) -- { { wert, gewicht }, ... }
		local r, cum = self.next(), 0
		for _, e in ipairs(list) do
			cum = cum + e[2]
			if r <= cum then return e[1] end
		end
		return list[#list][1]
	end
	return self
end

local function tint(c, f) -- Richtung weiß mischen
	return { math.floor(c[1] + (255 - c[1]) * f), math.floor(c[2] + (255 - c[2]) * f), math.floor(c[3] + (255 - c[3]) * f) }
end

local function shade(c, f) -- Richtung schwarz mischen
	return { math.floor(c[1] * (1 - f)), math.floor(c[2] * (1 - f)), math.floor(c[3] * (1 - f)) }
end

local function mergeOpts(opts)
	local o = {}
	for k, v in pairs(Planner.DEFAULTS) do o[k] = v end
	if opts then
		for k, v in pairs(opts) do o[k] = v end
	end
	return o
end

local function add(h, name, kind, lx, ly, lz, sx, sy, sz, color, material, extra)
	extra = extra or {}
	local r = math.rad(h.yaw)
	local c, s = math.cos(r), math.sin(r)
	local part = {
		name = name, kind = kind,
		size = { sx, sy, sz },
		pos = { round3(h.ox + lx * c + lz * s), round3(ly), round3(h.oz - lx * s + lz * c) },
		yaw = (h.yaw + (extra.yaw or 0)) % 360, pitch = extra.pitch or 0,
		color = color, material = material,
		collide = extra.collide == true,
		lit = extra.lit, tag = extra.tag, text = extra.text, shape = extra.shape, roll = extra.roll, transparency = extra.transparency,
		lpos = { lx, ly, lz },
	}
	h.parts[#h.parts + 1] = part
	return part
end

local function onFace(h, face, u, d)
	if face == "front" then return u, -d, 0 end
	if face == "back" then return u, h.depth + d, 180 end
	if face == "+x" then return h.width / 2 + d, u, -90 end
	return -h.width / 2 - d, u, 90
end

local function planChurch(h, o)
	local y0 = o.floorY
	local BRICK, DARK, STONE, ROOF, COPPER, GOLD = { 150, 72, 54 }, { 128, 58, 44 }, { 208, 200, 184 }, { 74, 82, 88 }, { 94, 152, 130 }, { 220, 180, 70 }
	local DOOR, GLASSC, SLIT = { 62, 44, 34 }, { 70, 92, 112 }, { 30, 26, 24 }
	local function box(name, kind, lx, y, lz, sx, sy, sz, color, mat, extra) add(h, name, kind, lx, y, lz, sx, sy, sz, color, mat or "Brick", extra) end
	local function disc(name, lx, y, lz, thick, dia, color, mat, extra) -- Zylinder mit Achse entlang der Tiefe (z): Zifferblatt, Rosette, Bögen an der Front
		extra = extra or {}
		extra.shape, extra.yaw = "Cylinder", 90
		box(name, "trim", lx, y, lz, thick, dia, dia, color, mat or "Concrete", extra)
	end
	local function frontWin(u, yb, w, hgt, zw) -- Rundbogenfenster in der Wandebene lz = zw
		local ph = hgt - w / 2
		box("Glass", "glass", u, yb + ph / 2, zw - 0.2, w, ph, 0.3, GLASSC, "Glass", { tag = "HouseWindow", lit = false })
		disc("GlassBogen", u, yb + ph, zw - 0.2, 0.3, w, GLASSC, "Glass", { tag = "HouseWindow", lit = false })
		box("Sill", "trim", u, yb - 0.3, zw - 0.5, w + 1.6, 0.6, 1.0, STONE, "Concrete")
	end
	local function sideWin(sg, xw, lz, yb, w, hgt) -- Rundbogenfenster in der Wandebene lx = xw (sg = +-1: Blickrichtung)
		local ph = hgt - w / 2
		box("Glass", "glass", xw + sg * 0.2, yb + ph / 2, lz, 0.3, ph, w, GLASSC, "Glass", { tag = "HouseWindow", lit = false })
		box("GlassBogen", "glass", xw + sg * 0.2, yb + ph, lz, 0.3, w, w, GLASSC, "Glass", { shape = "Cylinder", tag = "HouseWindow", lit = false })
		box("Sill", "trim", xw + sg * 0.5, yb - 0.3, lz, 1.0, 0.6, w + 1.6, STONE, "Concrete")
	end
	box("Body", "body", 0, y0 + 31, 9, 18, 62, 18, BRICK, "Brick", { collide = true })
	for _, yy in ipairs({ 14, 44, 62 }) do box("Gurt", "trim", 0, y0 + yy, 9, 18.8, 0.9, 18.8, STONE, "Concrete") end
	for _, sd in ipairs({ -1, 1 }) do for _, dz in ipairs({ 0.2, 17.8 }) do box("Eckquader", "trim", sd * 9, y0 + 31, dz, 1.2, 62, 1.2, DARK, "Brick") end end
	box("Glockenstube", "body", 0, y0 + 71, 9, 16, 18, 16, BRICK, "Brick", { collide = true })
	for _, u in ipairs({ -3.6, 3.6 }) do -- Schallöffnungen in den vier Wänden
		box("Schallloch", "trim", u, y0 + 71.5, 0.9, 3, 9, 0.6, SLIT, "SmoothPlastic")
		box("Schallloch", "trim", u, y0 + 71.5, 17.1, 3, 9, 0.6, SLIT, "SmoothPlastic")
		box("Schallloch", "trim", -8.1, y0 + 71.5, 9 + u, 0.6, 9, 3, SLIT, "SmoothPlastic")
		box("Schallloch", "trim", 8.1, y0 + 71.5, 9 + u, 0.6, 9, 3, SLIT, "SmoothPlastic")
	end
	box("Kranzgesims", "trim", 0, y0 + 80.6, 9, 17.6, 1.2, 17.6, STONE, "Concrete")
	for _, sd in ipairs({ -1, 1 }) do
		for _, dz in ipairs({ 1.2, 16.8 }) do -- Ecktürmchen
			box("Fiale", "trim", sd * 7.4, y0 + 85, dz, 8, 1.8, 1.8, STONE, "Concrete", { shape = "Cylinder", roll = 90 })
			box("FialeKopf", "trim", sd * 7.4, y0 + 89.6, dz, 2.4, 2.4, 2.4, COPPER, "Metal", { shape = "Ball" })
		end
	end
	for i = 0, 17 do -- Turmhelm: 18 überlappende Scheiben, Kegel mit geschwungener Spitze
		local t = i / 17
		local d = 13.8 * (1 - t) ^ 1.15 + 1.1
		box("Turmhelm", "roof", 0, y0 + 81.8 + t * 40, 9, 2.6, d, d, COPPER, "Metal", { shape = "Cylinder", roll = 90 })
	end
	box("Turmkugel", "trim", 0, y0 + 123.4, 9, 2.4, 2.4, 2.4, GOLD, "Metal", { shape = "Ball" })
	box("Turmkreuz", "trim", 0, y0 + 127, 9, 0.8, 6, 0.8, GOLD, "Metal")
	box("Turmkreuz", "trim", 0, y0 + 128, 9, 3.6, 0.8, 0.8, GOLD, "Metal")
	disc("UhrRand", 0, y0 + 52, -0.25, 0.5, 9.2, STONE, "Concrete")
	disc("Uhr", 0, y0 + 52, -0.55, 0.3, 7.8, { 246, 242, 230 }, "SmoothPlastic")
	for _, hd in ipairs({ { 300, 2.2 }, { 60, 3.2 } }) do -- Zeiger (roll dreht um die Tiefenachse, positiv = im Uhrzeigersinn von vorn gesehen)
		local phi = math.rad(hd[1])
		box("Uhrzeiger", "trim", -(hd[2] / 2) * math.sin(phi), y0 + 52 + (hd[2] / 2) * math.cos(phi), -0.85, 0.5, hd[2], 0.3, { 30, 28, 26 }, "Metal", { roll = hd[1] })
	end
	for _, sd in ipairs({ -1, 1 }) do
		box("Uhrstrich", "trim", 0, y0 + 52 + sd * 3.1, -0.85, 0.4, 0.9, 0.3, { 30, 28, 26 }, "Metal")
		box("Uhrstrich", "trim", sd * 3.1, y0 + 52, -0.85, 0.9, 0.4, 0.3, { 30, 28, 26 }, "Metal")
	end
	box("PortalRahmen", "trim", 0, y0 + 5.2, -0.15, 8, 10.4, 0.6, STONE, "Concrete")
	disc("PortalBogen", 0, y0 + 10.4, -0.15, 0.6, 8, STONE, "Concrete")
	box("Portal", "door", 0, y0 + 4.8, -0.5, 5.6, 9.6, 0.5, DOOR, "Wood", { tag = "HouseDoor" })
	disc("PortalTuerBogen", 0, y0 + 9.6, -0.5, 0.5, 5.6, DOOR, "Wood")
	box("Stufe", "trim", 0, y0 + 0.3, -1.0, 10, 0.6, 1.6, STONE, "Concrete")
	disc("RosetteRand", 0, y0 + 24, -0.3, 0.6, 8, STONE, "Concrete")
	disc("Rosette", 0, y0 + 24, -0.55, 0.3, 6.6, GLASSC, "Glass", { tag = "HouseWindow", lit = false })
	for _, r in ipairs({ 0, 45, 90, 135 }) do box("RosetteSteg", "trim", 0, y0 + 24, -0.8, 6.6, 0.45, 0.25, STONE, "Concrete", { roll = r }) end
	for _, u in ipairs({ -3.8, 3.8 }) do frontWin(u, y0 + 33, 2.4, 9, 0) end
	for _, sd in ipairs({ -1, 1 }) do sideWin(sd, sd * 9, 9, y0 + 30, 2.6, 10) end
	for _, sd in ipairs({ -1, 1 }) do
		box("Seitenschiff", "body", sd * 15, y0 + 8, 21, 8, 16, 42, BRICK, "Brick", { collide = true })
		for _, lz in ipairs({ 8, 17, 26, 35 }) do sideWin(sd, sd * 19, lz, y0 + 4, 3.2, 9) end
		frontWin(sd * 14.5, y0 + 4, 3.2, 9, 0)
		for _, lz in ipairs({ 3, 12.5, 21.5, 30.5, 39.5 }) do box("Strebepfeiler", "trim", sd * 19.6, y0 + 6, lz, 1.6, 12, 1.6, DARK, "Brick") end
		box("Seitendach", "roof", sd * 15.4, y0 + 19.4, 21, 44, 0.8, math.sqrt(8.8 ^ 2 + 7.2 ^ 2) + 0.8, ROOF, "Metal", { yaw = 90, pitch = sd * math.deg(math.atan2(7.2, 8.8)) })
		for _, lz in ipairs({ 22, 30, 38 }) do sideWin(sd, sd * 11, lz, y0 + 24.4, 3.2, 5.4) end
		box("Hauptdach", "roof", sd * 5.8, y0 + 37, 30, 34, 0.8, math.sqrt(11.6 ^ 2 + 14 ^ 2) + 0.8, ROOF, "Metal", { yaw = 90, pitch = sd * math.deg(math.atan2(14, 11.6)) })
	end
	box("Mittelschiff", "body", 0, y0 + 15, 30, 22, 30, 32, BRICK, "Brick", { collide = true })
	box("First", "trim", 0, y0 + 44.3, 30, 34, 0.8, 1.4, ROOF, "Metal")
	for i = 0, 4 do box("Giebelstufe", "trim", 0, y0 + 31.4 + 2.8 * i, 46.4, 22 - 4.4 * i, 2.8, 1.2, BRICK, "Brick") end
	box("Apsis", "body", 0, y0 + 11, 46, 22, 19, 19, BRICK, "Brick", { shape = "Cylinder", roll = 90, collide = true })
	box("ApsisDach", "roof", 0, y0 + 22, 46, 19, 19, 19, COPPER, "Metal", { shape = "Ball" })
end


local FRAME = { 70, 62, 56 }
local GLASS = { 70, 92, 112 }
local GLASS_LIT = { 255, 214, 140 }
local SHUTTERS = { { 70, 100, 80 }, { 110, 60, 50 }, { 60, 70, 100 }, { 90, 90, 94 } }
local AWNINGS = { { 190, 60, 50 }, { 60, 100, 150 }, { 70, 130, 90 }, { 220, 170, 60 } }

local function addWindow(h, label, face, u, yc, w, hgt, lit, shift, noSill)
	shift = shift or 0
	local lx, lz, ey = onFace(h, face, u, 0.2 + shift)
	add(h, "Frame" .. label, "frame", lx, yc, lz, w + 1.6, hgt + 1.6, 0.4, FRAME, "SmoothPlastic", { yaw = ey })
	lx, lz = onFace(h, face, u, 0.4 + shift)
	add(h, "Glass" .. label, "glass", lx, yc, lz, w, hgt, 0.2, lit and GLASS_LIT or GLASS, "Glass", { yaw = ey, lit = lit, tag = "HouseWindow" })
	if h.simple or noSill then return end
	lx, lz = onFace(h, face, u, 0.5 + shift)
	add(h, "Sill" .. label, "trim", lx, yc - hgt / 2 - 1.1, lz, w + 3, 0.6, 1.0, { 200, 196, 188 }, "Concrete", { yaw = ey })
end

local function planHouse(h, o, rng, cornerA, cornerB)
	local W, D = h.width, h.depth
	local floors = rng.weighted(o.floorWeights)
	if h.forceFloors then floors = h.forceFloors end
	local H = o.groundH + o.upperH * (floors - 1)
	local y0 = o.floorY
	local facade = rng.pick(o.palette)
	if h.color then facade = h.color end
	local doorSign = (rng.next() < 0.5) and -1 or 1
	local balconyStyle = rng.weighted({ { "none", 0.35 }, { "single", 0.25 }, { "full", 0.15 }, { "juliet", 0.25 } })
	local roofRoll = rng.next()
	local roof = (roofRoll < 0.5) and "flat" or ((roofRoll < 0.8 and floors >= 4) and "mansard" or ((floors <= 4) and "staffel" or "flat"))
	local chimneys = rng.int(0, 2)
	local erker = rng.next() < 0.4 and floors >= 4 and W >= 28 and not h.simple
	local shutters = rng.next() < 0.35 and not h.simple
	local shop = rng.next() < 0.4 and W >= 30
	local plinthColor = rng.pick({ { 140, 140, 140 }, { 112, 104, 98 }, { 160, 150, 138 } })
	local ledgeColor = (rng.next() < 0.5) and tint(facade, 0.35) or shade(facade, 0.12)
	local shutterColor = rng.pick(SHUTTERS)
	local awning = rng.pick(AWNINGS)
	local variant = "plain"
	if not h.simple and not h.color and not h.forceFloors then
		variant = rng.weighted({ { "plain", 0.34 }, { "palazzo", 0.16 }, { "erker", 0.16 }, { "jugend", 0.2 }, { "modern", 0.14 } })
		if variant == "palazzo" and (floors < 4 or W < 28) then variant = "plain" end
		if variant == "erker" and (floors < 4 or W < 30) then variant = "plain" end
		if variant == "palazzo" then facade = rng.pick(PALAZZO) end
		if variant == "jugend" then facade = rng.pick(JUGEND) end
		if variant == "modern" then
			facade = rng.pick(MODERN)
			balconyStyle = "none"
			if floors <= 5 then roof = "staffel" end
		end
	end
	h.variant = variant
	h.floors, h.height, h.facade, h.roof = floors, H, facade, roof

	add(h, "Body", "body", 0, y0 + H / 2, D / 2, W, H, D, facade, "SmoothPlastic", { collide = true })
	add(h, "Plinth", "trim", 0, y0 + 1.2, -0.25, W, 2.4, 0.5, plinthColor, "Concrete")
	for k = 1, floors - 1 do
		local yb = y0 + o.groundH + o.upperH * (k - 1)
		add(h, "Ledge" .. k, "trim", 0, yb, -0.4, W, 0.7, 0.8, ledgeColor, "Concrete")
	end
	add(h, "Cornice", "trim", 0, y0 + H - 0.8, -0.8, W, 1.6, 1.6, tint(facade, 0.45), "Concrete")

	local base = y0 + H
	add(h, "Roof", "roof", 0, base + 0.3, D / 2, W, 0.6, D, { 96, 96, 100 }, "Concrete", { collide = true })
	local roofTop = base + 0.6
	if roof == "flat" or roof == "staffel" then
		add(h, "ParapetF", "trim", 0, base + 1.6, 0.4, W, 2, 0.8, tint(facade, 0.2), "Concrete")
		add(h, "ParapetB", "trim", 0, base + 1.6, D - 0.4, W, 2, 0.8, tint(facade, 0.2), "Concrete")
	end
	if roof == "mansard" then
		local run, rise = 3.5, 6
		local len = math.sqrt(run * run + rise * rise)
		add(h, "MansardFront", "roof", 0, base + rise / 2 + 0.3, run / 2, W, 0.8, len, { 88, 88, 96 }, "Metal", { pitch = -math.deg(math.atan2(rise, run)) })
		add(h, "MansardFill", "body", 0, base + rise / 2 + 0.3, run + (D - run - 1) / 2, W, rise, D - run - 1, shade(facade, 0.08), "SmoothPlastic", { collide = true })
		add(h, "MansardTop", "roof", 0, base + rise + 0.6, run + (D - run) / 2, W, 0.6, D - run, { 88, 88, 96 }, "Metal")
		roofTop = base + rise + 0.9
	elseif roof == "staffel" then
		add(h, "Staffel", "body", 0, roofTop + 5, D / 2, W - 4, 10, D - 12, tint(facade, 0.15), "SmoothPlastic", { collide = true })
		add(h, "StaffelGlass", "glass", 0, roofTop + 5, 5.8, W - 8, 6, 0.3, GLASS, "Glass", { tag = "HouseWindow", lit = false })
		add(h, "StaffelRoof", "roof", 0, roofTop + 10.3, D / 2, W - 3, 0.6, D - 11, { 96, 96, 100 }, "Concrete")
		roofTop = roofTop + 10.6
	end
	for i = 1, h.simple and 0 or chimneys do
		local lim = math.floor(W / 2 - 3)
		add(h, "Chimney" .. i, "chimney", rng.int(-lim, lim), roofTop + 3, D - 6, 2.5, 6, 2.5, { 170, 100, 80 }, "Brick")
	end

	local nw = math.max(2, math.floor((W - 4) / 9))
	local erkerIdx
	if erker then
		erkerIdx = 1
		for i = 1, nw do
			if math.abs(-W / 2 + (i - 0.5) * W / nw) < math.abs(-W / 2 + (erkerIdx - 0.5) * W / nw) then erkerIdx = i end
		end
		local ex = -W / 2 + (erkerIdx - 0.5) * W / nw
		local yb1 = y0 + o.groundH
		add(h, "Erker", "body", ex, yb1 + o.upperH, -1.25, 8, o.upperH * 2, 2.5, tint(facade, 0.1), "SmoothPlastic", { collide = true })
		add(h, "ErkerRoof", "trim", ex, yb1 + o.upperH * 2 + 0.3, -1.45, 8.6, 0.6, 3.1, { 96, 96, 100 }, "Concrete")
	end
	for k = 1, floors - 1 do
		local yb = y0 + o.groundH + o.upperH * (k - 1)
		for i = 1, nw do
			local u = -W / 2 + (i - 0.5) * W / nw
			local lit = rng.next() < o.litChance
			if erker and i == erkerIdx and k <= 2 then
				addWindow(h, "E" .. k, "front", u, yb + 6, 4.4, 6.4, lit, 2.5)
			else
				addWindow(h, "F" .. k .. "_" .. i, "front", u, yb + 6, 4.4, 6.4, lit)
				if shutters then
					for _, sd in ipairs({ -1, 1 }) do
						add(h, "Shutter" .. k .. "_" .. i, "trim", u + sd * 3.8, yb + 6, -0.15, 1.4, 7.8, 0.3, shutterColor, "Wood")
					end
				end
			end
		end
		if k >= 2 and not h.simple and balconyStyle ~= "none" and not (erker and k <= 2) then
			local bw = (balconyStyle == "full") and (W - 10) or math.min(14, W - 10)
			if balconyStyle ~= "juliet" and (balconyStyle == "full" or k % 2 == 0) then
				add(h, "Balcony" .. k, "balcony", 0, yb + 0.3, -1.25, bw, 0.6, 2.5, { 150, 150, 150 }, "Concrete")
				add(h, "Rail" .. k, "balcony", 0, yb + 2.1, -2.35, bw, 3, 0.3, { 60, 60, 66 }, "Metal")
			elseif balconyStyle == "juliet" then
				add(h, "Rail" .. k, "balcony", 0, yb + 2.1, -0.5, math.min(W - 12, 18), 2.4, 0.3, { 60, 60, 66 }, "Metal")
			end
		end
	end

	local a = W / 2 - 6
	local dx = doorSign * a
	add(h, "DoorFrame", "frame", dx, y0 + 5, -0.25, 6.4, 10, 0.5, { 70, 52, 42 }, "Wood")
	add(h, "Door", "door", dx, y0 + 4.5, -0.55, 5, 9, 0.3, { 110, 70, 45 }, "Wood")
	add(h, "DoorCanopy", "trim", dx, y0 + 10.6, -1, 7, 0.5, 2, { 120, 120, 124 }, "Concrete")
	if shop then
		local lo, hi = -W / 2 + 2, W / 2 - 2
		if doorSign > 0 then hi = dx - 4.5 else lo = dx + 4.5 end
		local ws = hi - lo
		addWindow(h, "Shop", "front", (lo + hi) / 2, y0 + 7.5, ws - 1.6, 7, rng.next() < o.litChance)
		add(h, "Awning", "trim", (lo + hi) / 2, y0 + 12, -1.6, ws, 0.5, 3.2, awning, "Concrete")
	elseif W >= 24 then
		local nwg = math.max(1, math.floor((W - 21) / 9) + 1)
		for i = 1, nwg do
			addWindow(h, "G_" .. i, "front", -dx + doorSign * 9 * (i - 1), y0 + 8, 4.4, 5.4, rng.next() < o.litChance)
		end
	end

	if h.rear then
		for k = 1, floors - 1 do
			local yb = y0 + o.groundH + o.upperH * (k - 1)
			for i = 1, nw do
				addWindow(h, "R" .. k .. "_" .. i, "back", -W / 2 + (i - 0.5) * W / nw, yb + 6, 4.4, 6.4, rng.next() < o.litChance, 0, true)
			end
		end
		local bx, bz = onFace(h, "back", dx, 0.25)
		add(h, "BackDoorFrame", "frame", bx, y0 + 5, bz, 6.4, 10, 0.5, { 70, 52, 42 }, "Wood", { yaw = 180 })
		bx, bz = onFace(h, "back", dx, 0.55)
		add(h, "BackDoor", "door", bx, y0 + 4.5, bz, 5, 9, 0.3, { 110, 70, 45 }, "Wood", { yaw = 180 })
		for i = 1, math.max(1, math.floor((W - 21) / 9) + 1) do
			addWindow(h, "RG_" .. i, "back", -dx + doorSign * 9 * (i - 1), y0 + 8, 4.4, 5.4, rng.next() < o.litChance, 0, true)
		end
	end

	if variant == "palazzo" then
		for i = 1, 5 do add(h, "Rustika", "trim", 0, y0 + i * 2.4, -0.12, W, 0.2, 0.3, shade(facade, 0.2), "Concrete") end
		for i = 1, nw do
			local u = -W / 2 + (i - 0.5) * W / nw
			local lx, lz, ey = onFace(h, "front", u, 0.9)
			add(h, "FensterVerdachung", "trim", lx, y0 + o.groundH + 10.6, lz, 6.6, 1.0, 1.4, tint(facade, 0.5), "Concrete", { yaw = ey })
		end
		add(h, "Kranzgesims", "trim", 0, y0 + H - 1.6, -1.2, W + 3, 3.2, 3.6, tint(facade, 0.5), "Concrete")
		add(h, "Fries", "trim", 0, y0 + H - 4.4, -0.3, W, 1.6, 0.6, { 176, 96, 72 }, "Concrete")
		for _, sd in ipairs({ -1, 1 }) do add(h, "Eckquader", "trim", sd * (W / 2 - 1), y0 + H / 2, -0.4, 2, H, 0.8, tint(facade, 0.35), "Concrete") end
	elseif variant == "erker" then
		local ex = rng.pick({ -W / 4, W / 4 })
		local eh = math.min(3, floors - 2) * o.upperH
		local yb1 = y0 + o.groundH
		add(h, "ErkerGlas", "glass", ex, yb1 + eh / 2, -1.9, 7, eh, 3.6, { 110, 140, 160 }, "Glass", { collide = true, tag = "HouseWindow", lit = rng.next() < 0.5 })
		for k = 0, eh / o.upperH do add(h, "ErkerBand", "trim", ex, yb1 + k * o.upperH, -1.9, 7.8, 0.8, 4.0, tint(facade, 0.3), "Concrete") end
		for _, sd in ipairs({ -3.4, 3.4 }) do add(h, "ErkerPfosten", "trim", ex + sd, yb1 + eh / 2, -3.7, 0.5, eh, 0.5, FRAME, "Metal") end
		for _, sd in ipairs({ -1, 1 }) do add(h, "ErkerDach", "roof", ex, yb1 + eh + 1.9, -1.9 + sd * 0.8, 7.8, 0.6, 2.4, { 96, 96, 100 }, "Metal", { pitch = sd * 38 }) end
	elseif variant == "jugend" then
		add(h, "Terrassenzaun", "trim", 0, y0 + 1.0, -3.7, W - 6, 2, 0.3, { 140, 98, 62 }, "Wood")
		for u = -W / 2 + 3, W / 2 - 3, 6 do add(h, "Zaunpfosten", "trim", u, y0 + 1.2, -3.7, 0.5, 2.4, 0.5, { 110, 76, 48 }, "Wood") end
		for _, tu in ipairs({ -W / 4, W / 4 }) do
			add(h, "Terrassentisch", "trim", tu, y0 + 2.0, -1.9, 2.4, 0.2, 2.4, { 236, 232, 222 }, "SmoothPlastic")
			add(h, "Tischfuss", "trim", tu, y0 + 1.0, -1.9, 0.3, 2.0, 0.3, { 70, 70, 74 }, "Metal")
		end
		if roof == "mansard" then
			local nd = math.max(2, math.floor(W / 14))
			for k = 1, nd do
				local u = -W / 2 + (k - 0.5) * W / nd
				add(h, "Gaube", "body", u, y0 + H + 2.6, 1.9, 3.8, 4.4, 2.6, tint(facade, 0.1), "SmoothPlastic", { collide = true })
				add(h, "GaubeFenster", "glass", u, y0 + H + 2.6, 0.55, 2.4, 2.8, 0.2, GLASS, "Glass", { collide = false })
				add(h, "GaubeDach", "roof", u, y0 + H + 5.0, 1.9, 4.6, 0.5, 3.4, { 88, 88, 96 }, "Metal")
			end
		end
	elseif variant == "modern" then
		for k = 2, floors - 1 do
			local yb = y0 + o.groundH + o.upperH * (k - 1)
			for i = 1, nw, 2 do
				local u = -W / 2 + (i - 0.5) * W / nw
				add(h, "BalkonPlatte", "balcony", u, yb + 0.3, -1.2, 5.8, 0.5, 2.4, shade(facade, 0.1), "Concrete")
				add(h, "BalkonGlas", "glass", u, yb + 2.1, -2.3, 5.8, 3, 0.2, { 150, 190, 200 }, "Glass", { collide = false })
			end
		end
		add(h, "Akzentstreifen", "trim", W / 2 - 3, y0 + H / 2, -0.15, 1.6, H, 0.3, { 200, 120, 70 }, "SmoothPlastic")
	end

	for _, face in ipairs({ cornerA and "-x" or false, cornerB and "+x" or false }) do
		if face and not h.simple then
			for _, u in ipairs({ 7, D - 7 }) do
				for k = 1, floors - 1 do
					addWindow(h, "SideF" .. k .. "_" .. face .. u, face, u, y0 + o.groundH + o.upperH * (k - 1) + 6, 4.4, 6.4, rng.next() < o.litChance)
				end
				addWindow(h, "SideG_" .. face .. u, face, u, y0 + 8, 4.4, 5.4, rng.next() < o.litChance)
			end
		end
	end
end

local function splitWidths(len, n, rng)
	local w, sum = {}, 0
	for i = 1, n do
		w[i] = 0.9 + 0.2 * rng.next()
		sum = sum + w[i]
	end
	for i = 1, n do w[i] = len * w[i] / sum end
	return w
end

local function planSides(name, sides, o, rng, plan, depth)
	for _, side in ipairs(sides) do
		local ranges = side.ranges or { { 0, side.len } }
		local idx = 0
		for ri, range in ipairs(ranges) do
			local len = range[2] - range[1]
			if len >= 24 then -- kürzere Lücken bleiben frei (Mindesthausbreite 24)
				local n = math.max(1, math.floor(len / o.targetWidth))
				local widths = splitWidths(len, n, rng)
				local t = range[1]
				for i = 1, n do
					idx = idx + 1
					local width = widths[i]
					local h = {
						side = side.name, index = idx, simple = o.simple, rear = o.rear ~= false,
						ox = side.sx + side.ux * (t + width / 2), oz = side.sz + side.uz * (t + width / 2),
						yaw = side.yaw, width = width, depth = depth, parts = {},
						name = string.format("Haus_%s_%s%d", name, side.name, idx),
					}
					t = t + width
					planHouse(h, o, rng, side.corners and ri == 1 and i == 1, side.corners and ri == #ranges and i == n)
					plan.houses[#plan.houses + 1] = h
				end
			end
		end
	end
end

local function bodyOf(h)
	for _, p in ipairs(h.parts) do
		if p.name == "Body" then return p end
	end
end

function Planner.aabb(p)
	local sx, sy, sz = p.size[1], p.size[2], p.size[3]
	if p.yaw % 180 == 90 then sx, sz = sz, sx end
	return p.pos[1] - sx / 2, p.pos[2] - sy / 2, p.pos[3] - sz / 2, p.pos[1] + sx / 2, p.pos[2] + sy / 2, p.pos[3] + sz / 2
end


local function planInner(plan, block, o, rng)
	plan.inner = {}
	if block.noInner then return end
	local cy = plan.courtyard
	local M, GAP, TARGET, MAXW = 14, 12, 34, 46
	local x0, z0, x1, z1 = cy[1] + M, cy[2] + M, cy[3] - M, cy[4] - M
	local cols, rows = math.floor((x1 - x0 + GAP) / (TARGET + GAP)), math.floor((z1 - z0 + GAP) / (TARGET + GAP))
	if cols < 1 or rows < 1 then return end
	local cw, cd = (x1 - x0 - (cols - 1) * GAP) / cols, (z1 - z0 - (rows - 1) * GAP) / rows
	local w, d = math.min(cw, MAXW), math.min(cd, MAXW)
	local avoid = {}
	for _, r in ipairs(block.reserved or {}) do avoid[#avoid + 1] = r end
	if block.lot then avoid[#avoid + 1] = block.lot end
	for _, r in ipairs(block.avoidInner or {}) do avoid[#avoid + 1] = r end
	for r = 1, rows do
		for c = 1, cols do
			local cx, cz = x0 + (c - 1) * (cw + GAP) + cw / 2, z0 + (r - 1) * (cd + GAP) + cd / 2
			local blocked = false
			for _, a in ipairs(avoid) do
				if cx - w / 2 < a[3] + 10 and cx + w / 2 > a[1] - 10 and cz - d / 2 < a[4] + 10 and cz + d / 2 > a[2] - 10 then blocked = true end
			end
			if not blocked then
				local south = r % 2 == 0 -- Reihen wechseln die Blickrichtung
				local h = {
					side = "I", index = #plan.inner + 1, simple = true, rear = true, forceFloors = rng.int(2, 3),
					ox = cx, oz = south and cz + d / 2 or cz - d / 2, yaw = south and 180 or 0, width = w, depth = d, parts = {},
					name = string.format("Hof_%s_%d", block.name, #plan.inner + 1),
				}
				planHouse(h, o, rng, false, false)
				plan.inner[#plan.inner + 1] = h
			end
		end
	end
end

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
	for _, side in ipairs(sides) do
		local r = math.rad(side.yaw)
		local cs, sn = math.cos(r), math.sin(r)
		local cuts = {}
		for _, rc in ipairs(block.reserved or {}) do
			local lo, hi, zlo, zhi = 1e9, -1e9, 1e9, -1e9
			for _, px in ipairs({ rc[1], rc[3] }) do
				for _, pz in ipairs({ rc[2], rc[4] }) do
					local lx, lz = (px - side.sx) * cs - (pz - side.sz) * sn, (px - side.sx) * sn + (pz - side.sz) * cs
					lo, hi, zlo, zhi = math.min(lo, lx), math.max(hi, lx), math.min(zlo, lz), math.max(zhi, lz)
				end
			end
			if zhi > 0.5 and zlo < D - 0.5 and hi > 0 and lo < side.len then cuts[#cuts + 1] = { math.max(0, lo), math.min(side.len, hi) } end
		end
		if #cuts > 0 then
			table.sort(cuts, function(a, b) return a[1] < b[1] end)
			local ranges, pos = {}, 0
			for _, cu in ipairs(cuts) do
				if cu[1] > pos then ranges[#ranges + 1] = { pos, cu[1] } end
				pos = math.max(pos, cu[2])
			end
			if pos < side.len then ranges[#ranges + 1] = { pos, side.len } end
			side.ranges = ranges
		end
	end
	local plan = { block = block, houses = {}, dropped = 0, courtyard = { xmin + s + D, zmin + s + D, xmax - s - D, zmax - s - D } }
	planSides(block.name, sides, o, rng, plan, D)
	if block.reserved then
		local kept = {}
		for _, h in ipairs(plan.houses) do
			local x0, _, z0, x1, _, z1 = Planner.aabb(bodyOf(h))
			local hit = false
			for _, r in ipairs(block.reserved) do
				if x0 < r[3] - 0.5 and x1 > r[1] + 0.5 and z0 < r[4] - 0.5 and z1 > r[2] + 0.5 then hit = true end
			end
			if hit then plan.dropped = plan.dropped + 1 else kept[#kept + 1] = h end
		end
		plan.houses = kept
	end
	planInner(plan, block, o, rng)
	return plan
end


function Planner.planAllee(cfg, opts)
	local o = mergeOpts(opts)
	local a = cfg.allee
	local rng = newRng(o.seed + hash("IsarAllee"))
	local ex, ez = a.uz, -a.ux
	local off = cfg.profiles.allee.half + o.setback
	local function P(s, d) return a.ax + a.ux * s + ex * d, a.az + a.uz * s + ez * d end
	local yaw = math.deg(math.atan2(ex, ez))
	local sx, sz = P(a.rowTo, off)
	local len = a.rowTo - a.rowFrom
	local t0, t1 = a.rowTo - a.church[2], a.rowTo - a.church[1]
	local side = { name = "A", yaw = yaw, sx = sx, sz = sz, ux = -a.ux, uz = -a.uz, len = len, ranges = { { 0, t0 }, { t1, len } } }
	local plan = { houses = {} }
	planSides("IsarAllee", { side }, o, rng, plan, o.depth)
	local cx, cz = P((a.church[1] + a.church[2]) / 2, off)
	local h = { side = "A", index = 0, simple = o.simple, ox = cx, oz = cz, yaw = yaw, width = a.church[2] - a.church[1], depth = 56, parts = {}, name = "Kirche_IsarAllee" }
	planChurch(h, o)
	plan.houses[#plan.houses + 1] = h
	return plan
end

local DARKG = { 58, 60, 64 }
local GLASS_DARK = { 40, 50, 60 }
local WHITE = { 236, 236, 232 }

local function ribbon(h, o, rng, face, yc, hgt, u0, u1, step, glass, frame, d, litChance, gateTag)
	local n = math.max(1, math.floor((u1 - u0) / step))
	local w = (u1 - u0) / n
	for i = 1, n do
		local u = u0 + (i - 0.5) * w
		local lx, lz, ey = onFace(h, face, u, d)
		local extra = { yaw = ey }
		if litChance then extra.tag, extra.lit = "HouseWindow", rng.next() < litChance end
		if gateTag then extra.tag = gateTag end
		add(h, "Glass", "glass", lx, yc, lz, w - 0.5, hgt, 0.2, glass, "Glass", extra)
		if i < n then
			lx, lz = onFace(h, face, u0 + i * w, d + 0.1)
			add(h, "Pfosten", "trim", lx, yc, lz, 0.5, hgt + 0.6, 0.5, frame, "Metal", { yaw = ey })
		end
	end
	local lx, lz, ey = onFace(h, face, (u0 + u1) / 2, d + 0.1)
	for _, dy in ipairs({ -hgt / 2 - 0.2, hgt / 2 + 0.2 }) do
		add(h, "Riegel", "trim", lx, yc + dy, lz, u1 - u0 + 0.4, 0.5, 0.5, frame, "Metal", { yaw = ey })
	end
end

local function win(h, o, rng, face, u, yc, w, hgt, frame, glass)
	local lx, lz, ey = onFace(h, face, u, 0.2)
	add(h, "Frame", "frame", lx, yc, lz, w + 1.4, hgt + 1.4, 0.4, frame, "SmoothPlastic", { yaw = ey })
	lx, lz = onFace(h, face, u, 0.4)
	add(h, "Glass", "glass", lx, yc, lz, w, hgt, 0.2, glass, "Glass", { yaw = ey, tag = "HouseWindow", lit = rng.next() < o.litChance })
end

local function label(h, face, u, y, d, w, hgt, text, color)
	local lx, lz, ey = onFace(h, face, u, d)
	add(h, "Schrift", "text", lx, y, lz, w, hgt, 0.2, color, "SmoothPlastic", { yaw = ey, text = { s = text, color = color } })
end

local function styleFeuerwache(h, o, rng)
	local W, D, y0 = h.width, h.depth, o.floorY
	local RED, HALL, UP = { 192, 36, 34 }, { 44, 46, 52 }, 36
	h.floors, h.height, h.facade, h.roof = 4, 14 + UP, RED, "flat"
	add(h, "Hallenboden", "body", 0, y0 - 0.5, D / 2, W, 1, D, { 104, 106, 110 }, "Concrete", { collide = true })
	for _, side in ipairs({ -1, 1 }) do -- Seitenwände der Halle, bündig mit den Nachbarhäusern
		add(h, "HalleWand", "body", side * (W / 2 - 1.2), y0 + 7, D / 2, 2.4, 14, D - 6, HALL, "Concrete", { collide = true })
	end
	add(h, "Body", "body", 0, y0 + 14 + UP / 2, D / 2, W, UP, D, RED, "SmoothPlastic", { collide = true })
	local roofTop = y0 + 14 + UP + 0.6
	add(h, "Roof", "roof", 0, roofTop - 0.3, D / 2, W, 0.6, D, { 90, 90, 96 }, "Concrete", { collide = true })
	local bays, pw = 4, 2.4
	local bw = (W - 5 * pw) / bays
	for _, face in ipairs({ "front", "back" }) do
		for b = 0, bays do
			local u = -W / 2 + pw / 2 + b * (bw + pw)
			local lx, lz, ey = onFace(h, face, u, -4.2)
			add(h, "Pfeiler", "trim", lx, y0 + 7, lz, pw, 14, 2.4, DARKG, "Concrete", { yaw = ey, collide = true })
			if b < bays then
				lx, lz = onFace(h, face, u + pw / 2 + bw / 2, -4.2)
				add(h, "Sturz", "trim", lx, y0 + 13, lz, bw, 2, 2.4, DARKG, "Concrete", { yaw = ey, collide = true })
				local u0 = u + pw / 2
				ribbon(h, o, rng, face, y0 + 6, 11.6, u0 + 0.5, u0 + bw - 0.5, 3.6, GLASS_DARK, DARKG, -3.6, nil, "FireGate")
			end
		end
		for k = 1, 3 do
			ribbon(h, o, rng, face, y0 + 14 + 12 * (k - 1) + 6, 5.6, -W / 2 + 4, W / 2 - 4, 7, GLASS, DARKG, 0.2, o.litChance)
		end
	end
	local tbw = W / 3 -- Kopfbau am Ostende, bündig zur Front
	add(h, "TopBlock", "body", W / 2 - tbw / 2, roofTop + 6, D * 0.3, tbw, 12, D * 0.6, RED, "SmoothPlastic", { collide = true })
	add(h, "TopBand", "trim", W / 2 - tbw / 2, roofTop + 9.5, -0.15, tbw, 2.4, 0.3, GLASS_DARK, "SmoothPlastic")
	add(h, "Antenne", "trim", W / 2 - 4, roofTop + 20, D * 0.45, 0.6, 16, 0.6, { 140, 140, 146 }, "Metal")
	label(h, "front", W / 2 - tbw / 2, roofTop + 4.5, 0.2, tbw - 4, 4, "FEUERWACHE SCHWABING", { 250, 250, 250 })
	label(h, "back", 0, y0 + 14 + UP - 1.7, 0.2, 40, 2.6, "RETTUNGSWACHE", { 250, 250, 250 })

	local SEAM, YEL, BLUE = { 150, 28, 28 }, { 240, 200, 40 }, { 40, 110, 255 }
	for _, face in ipairs({ "front", "back" }) do
		for u = -W / 2 + 6, W / 2 - 6, 6 do
			local lx, lz, ey = onFace(h, face, u, 0.1)
			add(h, "Paneelfuge", "trim", lx, y0 + 14 + UP / 2, lz, 0.2, UP, 0.3, SEAM, "Metal", { yaw = ey })
		end
		for k = 1, 2 do
			local lx, lz, ey = onFace(h, face, 0, 0.1)
			add(h, "Paneelfuge", "trim", lx, y0 + 14 + 12 * k, lz, W, 0.2, 0.3, SEAM, "Metal", { yaw = ey })
		end
		for b = 0, bays - 1 do
			local u0 = -W / 2 + pw + b * (bw + pw)
			local uc = u0 + bw / 2
			local lx, lz, ey = onFace(h, face, uc, -1.5) -- Blaulicht unter dem Überstand
			add(h, "Blaulicht", "trim", lx, y0 + 13.2, lz, 1.8, 1.0, 1.4, BLUE, "Neon", { yaw = ey })
			label(h, face, uc, y0 + 13, -2.85, 2.4, 1.6, tostring(b + 1 + (face == "back" and 4 or 0)), { 255, 255, 255 })
			for _, side in ipairs({ -1, 1 }) do -- Markierung des Torvorplatzes (Seitenlinien und Querlinie)
				local lx2, lz2, ey2 = onFace(h, face, uc + side * (bw / 2 - 1), 6)
				add(h, "Torlinie", "trim", lx2, y0 + 0.06, lz2, 0.4, 0.1, 8, YEL, "SmoothPlastic", { yaw = ey2 })
			end
			local lx3, lz3, ey3 = onFace(h, face, uc, 10)
			add(h, "Torlinie", "trim", lx3, y0 + 0.06, lz3, bw - 2, 0.1, 0.4, YEL, "SmoothPlastic", { yaw = ey3 })
		end
	end
	for b = 0, bays - 1 do -- Spurlinien in der Halle
		local uc = -W / 2 + pw + b * (bw + pw) + bw / 2
		for _, side in ipairs({ -1, 1 }) do
			local lx, lz, ey = onFace(h, "front", uc + side * (bw / 2 - 2), -D / 2)
			add(h, "Hallenlinie", "trim", lx, y0 + 0.06, lz, 0.4, 0.1, D - 14, { 236, 236, 232 }, "SmoothPlastic", { yaw = ey })
		end
	end
	for _, sd in ipairs({ -1, 1 }) do -- Hallenlicht
		for k = 0, 6 do
			add(h, "Hallenlicht", "trim", sd * W / 4, y0 + 13.7, 14 + k * (D - 28) / 6, 0.2, 2.4, 2.4, { 255, 250, 235 }, "Neon", { shape = "Cylinder", roll = 90 })
		end
	end
	for r = 0, 2 do -- Solarfeld
		for c = 0, 7 do
			add(h, "Solarmodul", "trim", -W / 2 + 12 + c * 8.4, roofTop + 1.4, D * 0.55 + r * 5.6, 7.4, 0.3, 4.6, { 24, 40, 84 }, "Metal", { pitch = -14, collide = false })
		end
	end
	add(h, "Schlauchturm", "body", -W / 2 + 8, roofTop + 15, D - 10, 10, 30, 10, RED, "SmoothPlastic", { collide = true })
	add(h, "SchlauchturmPlattform", "trim", -W / 2 + 8, roofTop + 30.5, D - 10, 12.4, 1, 12.4, { 90, 90, 96 }, "Concrete")
	add(h, "SchlauchturmFenster", "glass", -W / 2 + 8, roofTop + 22, D - 15.1, 5, 4, 0.2, GLASS_DARK, "Glass", { collide = false })
	for i = 0, 3 do add(h, "Lueftungsaufbau", "trim", -W / 2 + 26 + i * 10, roofTop + 2.5, D * 0.2, 5, 4, 4, { 160, 164, 170 }, "Metal", { collide = true }) end
	for i = 0, 2 do -- Fahnenmasten mit Fahnen vor dem Haus
		local lx, lz, ey = onFace(h, "front", -W / 2 + 12 + i * 12, 2.6)
		add(h, "Fahnenmast", "trim", lx, y0 + 13, lz, 0.6, 26, 0.6, { 200, 202, 206 }, "Metal", { yaw = ey, collide = true })
		add(h, "Fahne", "trim", lx + 3.8 * math.cos(math.rad(h.yaw + ey)) , y0 + 23, lz, 7.6, 4.6, 0.2, (i == 1) and { 255, 255, 255 } or { 0, 100, 190 }, "Fabric", { yaw = ey, collide = false })
	end
	add(h, "NotrufSchild", "trim", W / 2 - tbw - 8, roofTop + 4.5, -0.45, 9, 5.4, 0.5, { 0, 90, 170 }, "SmoothPlastic")
	label(h, "front", W / 2 - tbw - 8, roofTop + 4.5, 0.7, 7.6, 4, "112", { 255, 255, 255 })
end

local function stylePolizei(h, o, rng)
	local W, D, y0 = h.width, h.depth, o.floorY
	local floors = h.forceFloors or 4
	local GREY, RED, UP = { 92, 94, 104 }, { 190, 52, 48 }, o.upperH * (floors - 1)
	h.floors, h.height, h.facade, h.roof = floors, 14 + UP, GREY, "flat"
	add(h, "Body", "body", 0, y0 + 14 + UP / 2, D / 2, W, UP, D, GREY, "SmoothPlastic", { collide = true })
	add(h, "Roof", "roof", 0, y0 + 14 + UP + 0.3, D / 2, W, 0.6, D, { 80, 80, 86 }, "Concrete", { collide = true })
	local a0, a1 = W / 2 - 36, W / 2 - 22 -- Durchfahrt (14 breit, 14 hoch) bleibt offen; lokal +x ist bei Blick nach Süden Westen
	local nwin = math.floor((a0 + W / 2 - 16) / 12)
	add(h, "GroundL", "body", (-W / 2 + a0) / 2, y0 + 7, D / 2, a0 + W / 2, 14, D, RED, "SmoothPlastic", { collide = true })
	add(h, "GroundR", "body", (a1 + W / 2) / 2, y0 + 7, D / 2, W / 2 - a1, 14, D, RED, "SmoothPlastic", { collide = true })
	for _, face in ipairs({ "front", "back" }) do
		local lx, lz, ey = onFace(h, face, a1 + 1.5, 1.5)
		add(h, "Pfeiler", "trim", lx, y0 + 7, lz, 3, 14, 3, WHITE, "Concrete", { yaw = ey, collide = true })
		for i = 1, nwin do win(h, o, rng, face, a0 - 8 - 12 * (i - 1), y0 + 7.5, 4.6, 8, DARKG, { 70, 110, 100 }) end
		local nw = math.floor((W - 8) / 9)
		for k = 1, floors - 1 do
			for i = 1, nw do
				win(h, o, rng, face, -W / 2 + 4 + (i - 0.5) * (W - 8) / nw, y0 + 14 + 12 * (k - 1) + 6, 5.2, 5.8, WHITE, GLASS)
			end
		end
	end
	local ux = W / 2 - 11 -- Eingang mit Vordach und blauem Schild
	add(h, "DoorFrame", "frame", ux, y0 + 5, -0.25, 6.4, 10, 0.5, DARKG, "Metal")
	add(h, "Door", "door", ux, y0 + 4.5, -0.55, 5, 9, 0.3, GLASS_DARK, "Glass")
	add(h, "Vordach", "trim", ux, y0 + 10.8, -2, 9, 0.5, 4, { 110, 112, 118 }, "Concrete")
	add(h, "PolizeiSchild", "trim", ux, y0 + 12.6, -0.4, 11, 2.6, 0.5, { 30, 80, 190 }, "SmoothPlastic")
	label(h, "front", ux, y0 + 12.6, 0.8, 10, 2, "POLIZEI", { 255, 255, 255 })

	local DG, ALU, SEAM = { 74, 76, 86 }, { 150, 154, 160 }, { 150, 40, 38 }
	local nw = math.floor((W - 8) / 9)
	for _, face in ipairs({ "front", "back" }) do
		for k = 1, floors - 1 do
			local yb = y0 + 14 + 12 * (k - 1)
			local lx, lz, ey = onFace(h, face, 0, 0.35)
			add(h, "Bruestungsband", "trim", lx, yb + 1.0, lz, W, 2.0, 0.7, DG, "SmoothPlastic", { yaw = ey })
			for i = 1, nw do
				if (i + k) % 3 == 0 then -- Lamellen vor jedem dritten Fenster
					local u = -W / 2 + 4 + (i - 0.5) * (W - 8) / nw
					local lx2, lz2, ey2 = onFace(h, face, u, 1.2)
					add(h, "Lamellen", "trim", lx2, yb + 6, lz2, 5.8, 6.6, 0.4, ALU, "Metal", { yaw = ey2 })
				end
			end
		end
		for j = 0, nw, 3 do -- weiße Pfeiler zwischen den Fenstergruppen
			local u = -W / 2 + 4 + j * (W - 8) / nw
			local lx, lz, ey = onFace(h, face, u, 0.9)
			add(h, "Fassadenpfeiler", "trim", lx, y0 + 14 + UP / 2, lz, 1.8, UP, 1.2, WHITE, "Concrete", { yaw = ey })
		end
		for u = -W / 2 + 4, a0 - 3, 8 do -- Fugen im roten Sockel (großer Block)
			local lx, lz, ey = onFace(h, face, u, 0.1)
			add(h, "Sockelfuge", "trim", lx, y0 + 7, lz, 0.2, 14, 0.3, SEAM, "Metal", { yaw = ey })
		end
	end
	for i = 1, 2 do -- Treppe zum Eingang mit Handlauf
		local lx, lz, ey = onFace(h, "front", ux, 0.8 + i * 1.6)
		add(h, "EingangsStufe", "trim", lx, y0 + 0.3 * (3 - i), lz, 12, 0.6 * (3 - i), 1.8, { 170, 168, 162 }, "Concrete", { yaw = ey, collide = true })
	end
	for _, sd in ipairs({ -4.4, 4.4 }) do add(h, "Vordachsaeule", "trim", ux + sd, y0 + 5.5, -3.8, 0.8, 11, 0.8, WHITE, "Concrete", { collide = true }) end
	add(h, "Blaulicht", "trim", ux + 6.8, y0 + 9, -1.2, 1.6, 2.2, 1.2, { 40, 110, 255 }, "Neon")
	local sx = -W / 2 + 8
	add(h, "Treppenhaus", "glass", sx, y0 + (14 + UP + 6) / 2, -1.2, 12, 14 + UP + 6, 6, { 80, 110, 130 }, "Glass", { collide = true })
	for i = 0, 3 do add(h, "TreppenhausPfosten", "trim", sx - 6 + i * 4, y0 + (14 + UP + 6) / 2, -4.3, 0.6, 14 + UP + 6.4, 0.6, DARKG, "Metal") end
	for k = 0, floors do add(h, "TreppenhausRiegel", "trim", sx, y0 + 1 + k * 12.4, -4.3, 12.4, 0.5, 0.6, DARKG, "Metal") end
	local rt = y0 + 14 + UP + 0.6
	add(h, "Attika", "trim", 0, rt + 0.9, -0.4, W + 1, 1.8, 0.8, { 190, 192, 198 }, "Concrete")
	add(h, "Attika", "trim", 0, rt + 0.9, D + 0.4, W + 1, 1.8, 0.8, { 190, 192, 198 }, "Concrete")
	add(h, "Technikaufbau", "body", -W / 2 + 34, rt + 4, D / 2, 40, 8, 16, { 120, 124, 132 }, "Metal", { collide = true })
	for i = 0, 1 do add(h, "Antenne", "trim", W / 2 - 14 - i * 6, rt + 12, D / 2 - 6, 0.8, 24, 0.8, { 190, 190, 196 }, "Metal") end
	add(h, "Satellitenschuessel", "trim", W / 2 - 30, rt + 3, D / 2 + 8, 0.6, 6, 6, { 220, 222, 226 }, "Metal", { shape = "Cylinder" })
	for r = 0, 2 do
		for c = 0, 5 do add(h, "Solarmodul", "trim", 0 + c * 8.4, rt + 1.4, D * 0.3 + r * 6, 7.4, 0.3, 4.8, { 24, 40, 84 }, "Metal", { pitch = -12, collide = false }) end
	end
	add(h, "Fahnenmast", "trim", W / 2 - 5, rt + 12, D - 6, 0.6, 24, 0.6, { 200, 202, 206 }, "Metal", { collide = true })
	add(h, "Fahne", "trim", W / 2 - 5, rt + 20, D - 2, 0.2, 5, 8, { 0, 100, 190 }, "Fabric", { collide = false })
	for i = 0, 2 do add(h, "Durchfahrtlicht", "trim", (a0 + a1) / 2, y0 + 13.7, 8 + i * (D - 16) / 2, 0.2, 2.4, 2.4, { 255, 250, 235 }, "Neon", { shape = "Cylinder", roll = 90 }) end
	local sgx, sgz = onFace(h, "front", a1 + 1.5, 1.6)
	add(h, "HinweisSchild", "trim", sgx, y0 + 9, sgz, 4.2, 4.6, 0.3, { 30, 80, 190 }, "SmoothPlastic")
	label(h, "front", a1 + 1.5, y0 + 9, 1.9, 3.8, 3.8, "Einsatz-\nfahrzeuge\nfrei", { 255, 255, 255 })
end

local function styleKlinik(h, o, rng)
	local W, D, y0 = h.width, h.depth, o.floorY
	local floors = h.forceFloors or 5
	local UP = o.upperH * (floors - 1)
	local CONC, SLAB, PARA, MAG = { 150, 146, 140 }, { 176, 172, 164 }, { 124, 120, 114 }, { 200, 30, 100 }
	local GLASSB = { 96, 140, 160 }
	h.floors, h.height, h.facade, h.roof = floors, 14 + UP, CONC, "flat"
	add(h, "Ground", "body", 0, y0 + 7, D / 2, W - 12, 14, D - 12, { 58, 66, 76 }, "Concrete", { collide = true })
	add(h, "Body", "body", 0, y0 + 14 + UP / 2, D / 2, W, UP, D, CONC, "Concrete", { collide = true })
	add(h, "Roof", "roof", 0, y0 + 14 + UP + 0.3, D / 2, W, 0.6, D, { 96, 96, 100 }, "Concrete", { collide = true })
	add(h, "Staffel", "body", 0, y0 + 14 + UP + 6.6, D / 2, W - 40, 12, D - 50, { 170, 166, 158 }, "Concrete", { collide = true })
	for _, face in ipairs({ "front", "back" }) do
		for u = -W / 2 + 10, W / 2 - 9, 20 do
			local lx, lz, ey = onFace(h, face, u, 3 - 0.1)
			add(h, "Stuetze", "trim", lx, y0 + 7, lz, 3, 14, 3, CONC, "Concrete", { yaw = ey, collide = true })
		end
		for k = 1, floors - 1 do
			local yb = y0 + 14 + 12 * (k - 1)
			local lx, lz, ey = onFace(h, face, 0, 1.5)
			add(h, "Geschossplatte", "balcony", lx, yb + 0.5, lz, W, 1, 3, SLAB, "Concrete", { yaw = ey })
			lx, lz = onFace(h, face, 0, 2.75)
			add(h, "Bruestung", "balcony", lx, yb + 2.25, lz, W, 2.5, 0.5, PARA, "Concrete", { yaw = ey })
			ribbon(h, o, rng, face, yb + 6.4, 5, -W / 2 + 3, W / 2 - 3, 8, GLASS, DARKG, 0.2, o.litChance)
		end
	end
	local gx, gw = W / 2 - 17, 34
	local gh = 14 + UP
	add(h, "Glasturm", "glass", gx, y0 + gh / 2, -6, gw, gh, 12, GLASSB, "Glass", { collide = true })
	for i = 0, 6 do
		add(h, "Pfosten", "trim", gx - gw / 2 + i * gw / 6, y0 + gh / 2, -12.2, 0.6, gh, 0.6, DARKG, "Metal")
	end
	for k = 1, 4 do
		add(h, "Riegel", "trim", gx, y0 + k * gh / 4, -12.2, gw, 0.6, 0.6, DARKG, "Metal")
	end
	add(h, "GlasturmDach", "roof", gx, y0 + gh + 0.5, -6, gw + 0.6, 1, 12.6, CONC, "Concrete")
	add(h, "SchildTraeger", "trim", W / 2 - 38, y0 + 14 + 8, -3.4, 3.4, 17.6, 0.6, { 190, 188, 184 }, "SmoothPlastic")
	label(h, "front", W / 2 - 38, y0 + 14 + 8, 3.8, 3, 16, "K\nL\nI\nN\nI\nK\nU\nM", MAG)
	label(h, "front", -W / 2 + 30, y0 + 14 + 24 + 2.25, 3.15, 36, 2.2, "KLINIKUM", MAG)
end


local function styleBuero(h, o, rng)
	local W, D, y0 = h.width, h.depth, o.floorY
	local floors = h.forceFloors or 5
	local H = 14 + 12 * (floors - 1)
	local DARK, BAND, STEEL = { 38, 48, 62 }, { 214, 218, 222 }, { 170, 176, 182 }
	h.floors, h.height, h.facade, h.roof = floors, H, DARK, "flat"
	add(h, "Body", "body", 0, y0 + H / 2, D / 2, W, H, D, DARK, "SmoothPlastic", { collide = true })
	for _, face in ipairs({ "front", "back" }) do
		for k = 0, floors - 1 do
			local yb = y0 + (k == 0 and 0 or 14 + 12 * (k - 1))
			local lx, lz, ey = onFace(h, face, 0, 1.3)
			add(h, "Geschossband", "trim", lx, yb + 0.5, lz, W + 1, 1, 2.6, BAND, "Concrete", { yaw = ey })
			ribbon(h, o, rng, face, yb + (k == 0 and 8 or 6.5), k == 0 and 11 or 8.6, -W / 2 + 2, W / 2 - 2, 7, GLASS, DARKG, 0.3, o.litChance)
		end
		for u = -W / 2 + 7, W / 2 - 6, 14 do -- Stahlpfeiler vor der Fassade, ragen über das Dach
			local lx, lz, ey = onFace(h, face, u, 3)
			add(h, "Stahlpfeiler", "trim", lx, y0 + H / 2 + 3, lz, 1.4, H + 6, 1.4, STEEL, "Metal", { yaw = ey, collide = true })
		end
	end
	add(h, "Dach", "roof", 0, y0 + H + 1.1, D / 2, W + 6, 1.4, D + 9, { 200, 204, 208 }, "Concrete", { collide = true })
	add(h, "Dach", "roof", 0, y0 + H + 3.4, D / 2, W - 14, 1.2, D + 3, { 214, 218, 222 }, "Concrete", { collide = true })
	add(h, "Oberlicht", "glass", 0, y0 + H + 5.6, D / 2, W - 22, 3.2, D - 6, { 96, 124, 146 }, "Glass", { collide = false })
end

local STYLES = { feuerwache = styleFeuerwache, polizei = stylePolizei, klinik = styleKlinik, buero = styleBuero }


local function W3(h, name, kind, x, y, z, sx, sy, sz, color, mat, extra)
	extra = extra or {}
	h.parts[#h.parts + 1] = {
		name = name, kind = kind, size = { round3(sx), round3(sy), round3(sz) }, pos = { round3(x), round3(y), round3(z) }, yaw = extra.yaw or 0, pitch = 0,
		color = color, material = mat, collide = extra.collide == true, lpos = { 0, y, 0 }, tag = extra.tag, attrs = extra.attrs, lit = extra.lit,
		text = extra.text, shape = extra.shape, roll = extra.roll, transparency = extra.transparency,
	}
end

local FACE = { W = { 90, -1, 0 }, E = { 270, 1, 0 }, N = { 0, 0, -1 }, S = { 180, 0, 1 } }
local function logoA(h, x, y, z, size, face)
	local f = FACE[face]
	W3(h, "LogoPlatte", "decor", x + f[2] * 0.05, y, z + f[3] * 0.05, (f[2] ~= 0) and 0.3 or size, size, (f[2] ~= 0) and size or 0.3, { 250, 250, 250 }, "SmoothPlastic")
	W3(h, "Schrift", "text", x + f[2] * 0.25, y, z + f[3] * 0.25, size * 0.85, size * 0.85, 0.2, { 200, 32, 40 }, "SmoothPlastic", { yaw = f[1], text = { s = "A", color = { 200, 32, 40 } } })
end

local function styleTankstelle(h, spec)
	local x0, z0, x1, z1 = spec.x0, spec.z0, spec.x1, spec.z1
	local cx, cz, w, d = (x0 + x1) / 2, (z0 + z1) / 2, x1 - x0, z1 - z0
	local WHITE, RED, GL = { 250, 250, 250 }, { 200, 40, 40 }, { 160, 176, 172 }
	h.floors, h.height, h.facade, h.roof = 1, 14, WHITE, "flat"
	W3(h, "Body", "body", cx, 14.5, cz, w, 1, d, WHITE, "SmoothPlastic", { collide = true }) -- Dach, bündig mit dem Schirm
	W3(h, "ShopHinterwand", "body", x1 - 0.6, 7.5, cz, 1.2, 13, d, WHITE, "SmoothPlastic", { collide = true })
	for _, zz in ipairs({ z0 + 0.6, z1 - 0.6 }) do W3(h, "ShopSeitenwand", "body", cx, 7.5, zz, w, 13, 1.2, WHITE, "SmoothPlastic", { collide = true }) end
	W3(h, "ShopSockel", "body", x0 + 0.6, 2.1, cz, 1.2, 2.2, d - 2.4, WHITE, "SmoothPlastic", { collide = true })
	W3(h, "ShopSturz", "body", x0 + 0.6, 12.9, cz, 1.2, 2.2, d - 2.4, WHITE, "SmoothPlastic", { collide = true })
	W3(h, "ShopBand", "trim", x0 - 0.1, 14.2, cz, 0.4, 2.8, d, RED, "SmoothPlastic")
	W3(h, "ShopBand", "trim", cx, 14.2, z0 - 0.1, w, 2.8, 0.4, RED, "SmoothPlastic") -- Südseite grenzt an den Schirm
	W3(h, "ShopBandHinten", "trim", x1 + 0.1, 14.2, cz, 0.4, 2.8, d, RED, "SmoothPlastic")
	logoA(h, x0 - 0.3, 14.2, cz, 2.7, "W")
	local door = 8
	local function panes(za, zb)
		local n = math.max(1, math.floor((zb - za) / 4))
		local pw = (zb - za) / n
		for i = 1, n do
			W3(h, "ShopGlas", "glass", x0 + 0.6, 7.1, za + (i - 0.5) * pw, 0.3, 8.8, pw - 0.4, GL, "Glass", { collide = true, tag = "HouseWindow", lit = false })
			W3(h, "ShopPfosten", "trim", x0 + 0.6, 7.1, za + i * pw, 0.6, 9, 0.5, { 70, 74, 80 }, "Metal")
		end
	end
	panes(z0 + 1.2, cz - door / 2)
	panes(cz + door / 2, z1 - 1.2)
	W3(h, "ShopTuer", "glass", x0 + 0.6, 6.2, cz, 0.3, 10.4, door, GL, "Glass", { tag = "ShopDoor" }) -- ohne Kollision, man läuft hinein
	for _, zz in ipairs({ cz - door / 2, cz + door / 2 }) do W3(h, "ShopTuerrahmen", "trim", x0 + 0.6, 6.2, zz, 0.7, 10.6, 0.5, RED, "SmoothPlastic") end
	W3(h, "ShopTuerrahmen", "trim", x0 + 0.6, 11.6, cz, 0.7, 0.5, door, RED, "SmoothPlastic")
	W3(h, "Kasse", "trim", x0 + 5, 3, cz - 11, 3, 4, 9, { 190, 190, 194 }, "SmoothPlastic", { collide = true })
	for _, zz in ipairs({ z0 + 7, cz + 4, z1 - 7 }) do W3(h, "Regal", "trim", x1 - 3, 4.5, zz, 2.2, 7, 8, { 220, 220, 224 }, "SmoothPlastic", { collide = true }) end
	W3(h, "Kuehlregal", "trim", cx, 4, z1 - 3.5, 12, 6, 2.4, { 150, 190, 215 }, "SmoothPlastic", { collide = true })
end

local function compoundPolizei(h, spec, o)
	local ASPH, WHITE, RED = { 70, 72, 78 }, { 240, 240, 236 }, { 200, 40, 40 }
	local function slab(name, x0, z0, x1, z1) W3(h, name, "trim", (x0 + x1) / 2, 0.4, (z0 + z1) / 2, x1 - x0, 1.2, z1 - z0, ASPH, "Asphalt", { collide = true }) end
	local ax0 = spec.x0 + 22 -- Durchfahrt (14 breit), siehe stylePolizei
	slab("Hof", spec.x0 + 16, 296, spec.x1 + 2, spec.z0)
	slab("Durchfahrt", ax0, spec.z0, ax0 + 14, spec.z1 + 2)
	slab("Ausfahrt", spec.x1 + 2, 296, spec.x1 + 20, spec.z1 + 2)
	for i = 0, 14 do -- Parkbuchten an der Nordkante
		W3(h, "Parklinie", "dash", spec.x0 + 24 + 8 * i, 1.05, 306, 0.3, 0.1, 16, WHITE, "SmoothPlastic")
	end
	for i = 1, 4 do -- Spawnflächen für Streifenwagen
		W3(h, "FahrzeugSpawn", "spawn", spec.x0 + 20 + 24 * i, 1.12, 330, 12, 0.2, 20, { 36, 60, 120 }, "SmoothPlastic", { tag = "VehicleSpawn", attrs = { Team = "Polizei" } })
	end
	local fx0, fx1 = spec.x0 + 16, spec.x1 + 2
	W3(h, "ZaunRiegel", "trim", (fx0 + fx1) / 2, 4.6, 296.2, fx1 - fx0, 0.4, 0.4, { 50, 54, 58 }, "Metal")
	W3(h, "ZaunRiegel", "trim", (fx0 + fx1) / 2, 1.6, 296.2, fx1 - fx0, 0.4, 0.4, { 50, 54, 58 }, "Metal")
	for x = fx0, fx1, 4 do W3(h, "ZaunStab", "trim", x, 3, 296.2, 0.3, 3.4, 0.3, { 50, 54, 58 }, "Metal") end
	local function barrier(name, px, pz, len)
		W3(h, name .. "Pfosten", "trim", px, 3, pz, 1.4, 4, 1.4, RED, "SmoothPlastic", { collide = true })
		local n = 4
		for i = 1, n do
			W3(h, name .. "Arm", "trim", px + 0.7 + (i - 0.5) * len / n, 4.2, pz, len / n, 0.5, 0.5, (i % 2 == 1) and RED or WHITE, "SmoothPlastic",
				{ collide = true, tag = "Schranke", attrs = { Offen = false, Gruppe = name } })
		end
	end
	barrier("SchrankeEinfahrt", ax0 + 0.2, spec.z1 - 2, 13)
	barrier("SchrankeAusfahrt", spec.x1 + 3, 346, 16)
end

local COMPOUNDS = { polizei = compoundPolizei }

local function canopyAllguth(h, c)
	local x0, z0, x1, z1 = c[1], c[2], c[3], c[4]
	local cx, cz, w, d = (x0 + x1) / 2, (z0 + z1) / 2, x1 - x0, z1 - z0
	local WHITE, RED, TRIM = { 250, 250, 250 }, { 200, 32, 40 }, { 236, 236, 238 }
	local r = 8
	W3(h, "CanopyRoof", "trim", cx, 14.5, (z0 + z1 - r) / 2, w, 1, d - r, WHITE, "SmoothPlastic")
	W3(h, "CanopyRoof", "trim", cx, 14.5, z1 - r / 2, w - 2 * r, 1, r, WHITE, "SmoothPlastic")
	for _, px in ipairs({ x0 + r, x1 - r }) do -- Rundung: Zylinder mit 0,04 Überstand gegen Flackern
		W3(h, "CanopyRoofRund", "trim", px, 14.5, z1 - r, 1.08, 2 * r, 2 * r, WHITE, "SmoothPlastic", { shape = "Cylinder", roll = 90 })
	end
	local zs, ze = z0, z1 - r -- gerade Bänder an den Längsseiten
	W3(h, "CanopyBand", "trim", x0 + 0.4, 14.2, (zs + ze) / 2, 0.8, 2.8, ze - zs, RED, "SmoothPlastic")
	W3(h, "CanopyBand", "trim", x1 - 0.4, 14.2, (zs + ze) / 2, 0.8, 2.8, ze - zs, RED, "SmoothPlastic")
	W3(h, "CanopyBand", "trim", cx, 14.2, z1 - 0.4, w - 2 * r, 2.8, 0.8, RED, "SmoothPlastic")
	for _, e in ipairs({ x0 + 0.5, x1 - 0.5 }) do
		W3(h, "CanopyTrim", "trim", e, 15.85, (zs + ze) / 2, 0.9, 0.5, ze - zs, TRIM, "SmoothPlastic")
	end
	for _, cc in ipairs({ { x0 + r, z1 - r, 90 }, { x1 - r, z1 - r, 0 } }) do -- Bogenstücke der Bänder (Südecken)
		local n, rad = 6, r - 0.4
		for k = 1, n do
			local a = math.rad(cc[3] + (k - 0.5) * 90 / n)
			local tx, tz = -math.sin(a), math.cos(a)
			W3(h, "CanopyBand", "trim", cc[1] + rad * math.cos(a), 14.2, cc[2] + rad * math.sin(a), rad * (math.pi / 2) / n + 0.3, 2.8, 0.8, RED, "SmoothPlastic", { yaw = math.deg(math.atan2(-tz, tx)) % 360 })
		end
	end
	logoA(h, x0 - 0.2, 14.2, (zs + ze) / 2 - 8, 2.7, "W") -- Logo auf dem Band: West (Straße), Ost und Südende
	logoA(h, x1 + 0.2, 14.2, (zs + ze) / 2 - 8, 2.7, "E")
	logoA(h, cx, 14.2, z1 + 0.2, 2.7, "S")
	for _, px in ipairs({ x0 + 10, x1 - 10 }) do
		for k = 0, 3 do W3(h, "CanopyPillar", "trim", px, 7.5, z0 + 14 + k * (d - 28) / 3, 2.6, 14, 2.6, WHITE, "Concrete", { collide = true }) end
	end
	for _, lx in ipairs({ cx - 18, cx, cx + 18 }) do
		for k = 0, 4 do W3(h, "Deckenlicht", "trim", lx, 13.9, z0 + 10 + k * (d - 20) / 4, 0.2, 1.6, 1.6, { 255, 250, 230 }, "Neon", { shape = "Cylinder", roll = 90 }) end
	end
	for _, px in ipairs({ cx - 13, cx + 13 }) do
		W3(h, "Insel", "trim", px, 1.3, cz, 5, 0.6, d - 14, { 190, 188, 182 }, "Concrete", { collide = true })
		for kk = 0, 3 do
			local pz = z0 + 10 + kk * (d - 20) / 3
			W3(h, "Pump", "trim", px, 4.4, pz, 2.2, 5.6, 1.6, { 244, 244, 246 }, "SmoothPlastic", { collide = true })
			W3(h, "PumpKopf", "trim", px, 6.8, pz, 2.3, 1.4, 1.7, RED, "SmoothPlastic")
			for _, sd in ipairs({ -1, 1 }) do W3(h, "PumpDisplay", "trim", px, 5.4, pz + sd * 0.85, 1.6, 0.9, 0.2, { 20, 24, 28 }, "SmoothPlastic") end
		end
	end
end

local function lotDecor(h, spec)
	local l, K = spec.lot, 1.4
	local LAWN, HEDGE, WHITE, RED = { 88, 158, 62 }, { 40, 88, 48 }, { 244, 244, 246 }, { 200, 32, 40 }
	local sections, z = {}, l[2] + K
	for _, g in ipairs(spec.curbGaps) do
		if g[1] - z >= 8 then sections[#sections + 1] = { z, g[1] } end
		z = g[2]
	end
	if l[4] - K - z >= 8 then sections[#sections + 1] = { z, l[4] - K } end
	local lx0, lx1 = l[1] + K + 0.4, l[1] + 13
	for _, sct in ipairs(sections) do
		W3(h, "Rasen", "decor", (lx0 + lx1) / 2, 1.0, (sct[1] + sct[2]) / 2, lx1 - lx0, 0.6, sct[2] - sct[1] - 1, LAWN, "Grass")
		local zz = sct[1] + 4
		while zz + 9 < sct[2] - 3 do
			W3(h, "Hecke", "decor", lx1 - 1.4, 2.5, zz + 4.5, 1.8, 2.4, 9, HEDGE, "Grass", { collide = true })
			zz = zz + 10
		end
		for bz = sct[1] + 8, sct[2] - 6, 15 do W3(h, "Busch", "bush", lx0 + 2.4, 3.3, bz, 4.4, 4.4, 4.4, HEDGE, "Grass", { shape = "Ball" }) end
	end
	local function logoSign(x, zc)
		W3(h, "SchildPfosten", "decor", x, 3.3, zc, 0.4, 4, 0.4, { 80, 82, 86 }, "Metal", { collide = true })
		W3(h, "LogoSchild", "decor", x, 6.5, zc, 4.6, 4.6, 0.3, WHITE, "SmoothPlastic")
		for _, sd in ipairs({ { -1, 0 }, { 1, 180 } }) do
			W3(h, "LogoRot", "decor", x, 6.5, zc + sd[1] * 0.2, 3.2, 3.2, 0.2, RED, "SmoothPlastic")
			W3(h, "Schrift", "text", x, 6.5, zc + sd[1] * 0.4, 3.2, 3.2, 0.2, { 255, 255, 255 }, "SmoothPlastic", { yaw = sd[2], text = { s = "A", color = { 255, 255, 255 } } })
		end
	end
	if sections[1] then logoSign(lx0 + 3, sections[1][1] + 12) end
	local function gateSign(zc, label)
		W3(h, "SchildPfosten", "decor", l[1] + 4.5, 2.8, zc, 0.4, 3, 0.4, { 80, 82, 86 }, "Metal", { collide = true })
		W3(h, "FahrtSchild", "decor", l[1] + 4.5, 5.8, zc, 7, 2.6, 0.3, { 36, 70, 110 }, "SmoothPlastic")
		for _, sd in ipairs({ { -1, 0 }, { 1, 180 } }) do
			W3(h, "Schrift", "text", l[1] + 4.5, 5.8, zc + sd[1] * 0.25, 6.4, 2, 0.2, { 255, 255, 255 }, "SmoothPlastic", { yaw = sd[2], text = { s = label, color = { 255, 255, 255 } } })
		end
	end
	if sections[1] then gateSign(sections[1][2] - 1, "AUSFAHRT") end -- am Südende des Nordabschnitts, direkt vor der Ausfahrt
	if sections[2] then gateSign(sections[2][2] - 1, "EINFAHRT") end -- vor der südlichen Einfahrt
	local tx, tz = l[1] + 6, sections[1] and sections[1][2] - 9 or l[2] + 20
	W3(h, "TotemPylon", "decor", tx, 17.3, tz, 6.2, 32, 1.8, { 70, 74, 80 }, "Metal", { collide = true })
	local fuels = { { "SUPER", "1,81", "Super" }, { "SUPER E10", "1,75", "E10" }, { "SUPER PLUS", "1,95", "SuperPlus" }, { "DIESEL", "1,69", "Diesel" }, { "AUTOGAS", "0,89", "Autogas" } }
	for _, sd in ipairs({ { -1, 0 }, { 1, 180 } }) do
		local zf = tz + sd[1] * 1.0
		W3(h, "TotemKopf", "decor", tx, 28.8, zf, 5.6, 8.6, 0.3, RED, "SmoothPlastic")
		W3(h, "Schrift", "text", tx, 28.8, zf + sd[1] * 0.25, 5, 7, 0.2, { 255, 255, 255 }, "SmoothPlastic", { yaw = sd[2], text = { s = "A", color = { 255, 255, 255 } } })
		W3(h, "TotemTafel", "decor", tx, 14.5, zf, 5.6, 17, 0.3, { 18, 20, 24 }, "SmoothPlastic")
		for i, f in ipairs(fuels) do
			local yy = 22.4 - (i - 0.5) * 3.35
			local off = sd[1] * 0.25
			W3(h, "Schrift", "text", tx - sd[1] * 1.15, yy, zf + off, 3.1, 1.9, 0.2, { 255, 255, 255 }, "SmoothPlastic", { yaw = sd[2], text = { s = f[1], color = { 255, 255, 255 } } })
			W3(h, "Preis", "text", tx + sd[1] * 1.55, yy, zf + off, 1.9, 1.9, 0.2, { 90, 235, 120 }, "SmoothPlastic",
				{ yaw = sd[2], text = { s = f[2], color = { 90, 235, 120 } }, tag = "FuelPrice", attrs = { Fuel = f[3], Price = tonumber((string.gsub(f[2], ",", "."))) } })
		end
	end
end

local function evPark(h, spec)
	local e = spec.ev
	local x0, x1, z0, n, w = e.x0, e.x1, e.z0, e.n, e.w
	local z1, zm, cx = z0 + n * w, z0 + n * w / 2, (x0 + x1) / 2
	local GREEN, WHITE, DARK, CONC = { 40, 168, 110 }, { 244, 244, 246 }, { 24, 28, 34 }, { 190, 188, 182 }
	for i = 0, n - 1 do
		local zc = z0 + (i + 0.5) * w
		W3(h, "EVStellplatz", "decor", cx, 1.03, zc, x1 - x0, 0.06, w - 0.5, { 56, 140, 104 }, "SmoothPlastic")
		W3(h, "EVRadstopper", "decor", x1 - 1.6, 1.4, zc, 0.8, 0.8, 5, CONC, "Concrete", { collide = true })
	end
	for i = 0, n do W3(h, "EVLinie", "dash", cx, 1.08, z0 + i * w, x1 - x0, 0.1, 0.3, WHITE, "SmoothPlastic") end
	for j = 0, n / 2 - 1 do -- Ladesäule zwischen zwei Stellplätzen
		local zc, px = z0 + (2 * j + 1) * w, x1 - 3.6
		W3(h, "EVSockel", "decor", px, 1.3, zc, 3.4, 0.6, 3.4, CONC, "Concrete", { collide = true })
		W3(h, "EVSaeule", "trim", px, 4.2, zc, 1.8, 6, 2.4, WHITE, "SmoothPlastic", { collide = true, tag = "EVCharger", attrs = { Station = j + 1, kW = 50 } })
		W3(h, "EVKopf", "trim", px, 7.6, zc, 2.0, 1.4, 2.6, GREEN, "SmoothPlastic")
		W3(h, "EVDisplay", "text", px - 1.0, 5.8, zc, 2.0, 1.4, 0.2, DARK, "SmoothPlastic", { yaw = 90, text = { s = "EV", color = { 90, 235, 150 } } })
		for _, sd in ipairs({ -1, 1 }) do
			W3(h, "EVHalter", "trim", px - 0.2, 5.0, zc + sd * 1.4, 0.9, 1.2, 0.7, DARK, "SmoothPlastic")
			W3(h, "EVKabel", "trim", px - 1.0, 3.2, zc + sd * 1.4, 3.2, 0.35, 0.35, DARK, "SmoothPlastic", { shape = "Cylinder", roll = 90 })
			W3(h, "EVStecker", "trim", px - 1.0, 1.7, zc + sd * 1.4, 0.6, 0.9, 0.6, GREEN, "SmoothPlastic")
		end
	end
	for i = 0, n, 2 do W3(h, "EVPfosten", "trim", x1 - 0.8, 5.5, z0 + i * w, 1.2, 9, 1.2, WHITE, "SmoothPlastic", { collide = true }) end
	W3(h, "EVDach", "trim", cx - 0.25, 10.2, zm, x1 - x0 + 1.5, 0.8, n * w + 2, { 28, 44, 84 }, "SmoothPlastic")
	W3(h, "EVBlende", "trim", x0 - 1, 10.2, zm, 0.6, 1.6, n * w + 2, WHITE, "SmoothPlastic")
	W3(h, "EVBlende", "trim", cx - 0.25, 10.2, z1 + 1, x1 - x0 + 1.5, 1.6, 0.6, WHITE, "SmoothPlastic")
	W3(h, "EVSchrift", "text", x0 - 1.4, 10.2, zm, 26, 1.2, 0.2, { 40, 168, 110 }, "SmoothPlastic", { yaw = 90, text = { s = "E-LADESTATION", color = { 40, 168, 110 } } })
	W3(h, "EVSchrift", "text", cx - 0.25, 10.2, z1 + 1.4, 12, 1.2, 0.2, { 40, 168, 110 }, "SmoothPlastic", { yaw = 180, text = { s = "E-LADEN", color = { 40, 168, 110 } } })
	for i = 0, n - 1 do W3(h, "EVLicht", "trim", cx, 9.6, z0 + (i + 0.5) * w, 0.2, 1.6, 1.6, { 120, 255, 190 }, "Neon", { shape = "Cylinder", roll = 90 }) end
end

function Planner.planSpecial(spec, opts)
	local o = mergeOpts(opts)
	local rng = newRng(o.seed + hash(spec.name))
	local f = spec.facing
	local h = {
		side = f, index = 0, simple = false, rear = true, forceFloors = spec.floors, color = spec.color, parts = {}, name = "Sonder_" .. spec.name,
	}
	if f == "N" then h.ox, h.oz, h.yaw, h.width, h.depth = (spec.x0 + spec.x1) / 2, spec.z0, 0, spec.x1 - spec.x0, spec.z1 - spec.z0
	elseif f == "S" then h.ox, h.oz, h.yaw, h.width, h.depth = (spec.x0 + spec.x1) / 2, spec.z1, 180, spec.x1 - spec.x0, spec.z1 - spec.z0
	elseif f == "W" then h.ox, h.oz, h.yaw, h.width, h.depth = spec.x0, (spec.z0 + spec.z1) / 2, 90, spec.z1 - spec.z0, spec.x1 - spec.x0
	else h.ox, h.oz, h.yaw, h.width, h.depth = spec.x1, (spec.z0 + spec.z1) / 2, 270, spec.z1 - spec.z0, spec.x1 - spec.x0 end
	if spec.style == "tankstelle" then styleTankstelle(h, spec)
	elseif STYLES[spec.style] then STYLES[spec.style](h, o, rng)
	else planHouse(h, o, rng, false, false) end
	if spec.canopy then canopyAllguth(h, spec.canopy) end
	if spec.lot then -- Tankstellen-Grundstück: Plateau (Asphalt, Oberkante 1) mit Betonkante; zur Straße offen, nur zwischen den Ein-/Ausfahrten (curbGaps) steht eine niedrige Kante
		local l = spec.lot
		local KERB, K = { 190, 188, 182 }, 1.4
		W3(h, "Plateau", "trim", (l[1] + l[3]) / 2, 0.4, (l[2] + l[4]) / 2, l[3] - l[1], 1.2, l[4] - l[2], { 78, 80, 86 }, "Asphalt", { collide = true })
		local function kerb(x0, z0, x1, z1) W3(h, "Kante", "trim", (x0 + x1) / 2, 1.25, (z0 + z1) / 2, x1 - x0, 0.5, z1 - z0, KERB, "Concrete", { collide = true }) end
		kerb(l[1], l[2], l[3], l[2] + K)
		kerb(l[1], l[4] - K, l[3], l[4])
		kerb(l[3] - K, l[2] + K, l[3], l[4] - K)
		local z = l[2] + K
		for _, g in ipairs(spec.curbGaps) do -- Straßenseite: Kante zwischen den Einfahrten
			if g[1] > z then kerb(l[1], z, l[1] + K, g[1]) end
			z = g[2]
		end
		if z < l[4] - K then kerb(l[1], z, l[1] + K, l[4] - K) end
		for _, g in ipairs(spec.curbGaps) do -- Einfahrten über den Gehweg (Bordsteinabsenkung): Asphalt über dem Gehweg bis zum Grundstück
			W3(h, "Auffahrt", "trim", (43.4 + l[1] + 0.4) / 2, 0.91, (g[1] + g[2]) / 2, l[1] + 0.4 - 43.4, 0.3, g[2] - g[1], { 78, 80, 86 }, "Asphalt", { collide = true })
		end
		lotDecor(h, spec)
		if spec.ev then evPark(h, spec) end
	end
	if spec.compound then COMPOUNDS[spec.compound](h, spec, o) end
	return { houses = { h } }
end

function Planner.planWall(wall, opts)
	local o = mergeOpts(opts)
	o.simple, o.setback, o.rear = true, 0, false
	local D = math.abs(wall.outer.xmin - wall.inner.xmin)
	local rng = newRng(o.seed + hash("Mapgrenze"))
	local ix0, iz0, ix1, iz1 = wall.inner.xmin, wall.inner.zmin, wall.inner.xmax, wall.inner.zmax
	local oz0, oz1 = wall.outer.zmin, wall.outer.zmax
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
	for _, sp in ipairs(wall.specials) do -- Sonderbauten in den Lücken (Querriegel, Feldherrnhalle)
		local north = sp.side == "N"
		local h = {
			side = sp.side, index = 0, simple = true, forceFloors = sp.floors,
			ox = (sp.x0 + sp.x1) / 2, oz = north and iz0 or iz1,
			yaw = north and 180 or 0, width = sp.x1 - sp.x0, depth = D, parts = {}, name = "Sonder_" .. sp.name,
		}
		planHouse(h, o, rng, false, false)
		plan.houses[#plan.houses + 1] = h
	end
	return plan
end

function Planner.stats(plan)
	local parts, area = 0, 0
	local n = #plan.houses
	for _, list in ipairs({ plan.houses, plan.inner or {} }) do
		for _, h in ipairs(list) do
			parts = parts + #h.parts
			area = area + h.width * h.depth
		end
	end
	return { houses = n + #(plan.inner or {}), parts = parts, footprint = area }
end

return Planner

end)()

local Blocks = (function()

local Config = Config
local T = Config.tankstelle

return {
	{ name = "A_NordWest", xmin = -637, zmin = -448, xmax = -488.5, zmax = -313.5 },
	{ name = "B_NordMitte", xmin = -431.5, zmin = -448, xmax = -263.5, zmax = -313.5, noInner = true }, -- Innenhof ist der Hinterhofpark
	{ name = "C_LeopoldWestNord", xmin = -206.5, zmin = -448, xmax = -55, zmax = -313.5, reserved = { { -127, -385, -55, -315 } } },
	{ name = "D_West", xmin = -637, zmin = -256.5, xmax = -488.5, zmax = 1.5 },
	{ name = "E_Mitte", xmin = -431.5, zmin = -256.5, xmax = -263.5, zmax = 1.5, reserved = { { -429.5, -200, -265.5, -100 } } },
	{ name = "F_LeopoldWestSued", xmin = -206.5, zmin = -256.5, xmax = -55, zmax = 1.5, reserved = { { -205, -250, -109, -140 }, { -106, -90, -55, 2 } } }, -- zweite Fläche: Kreisverkehr um das Siegestor
	{ name = "G_LeopoldOst", xmin = 55, zmin = -448, xmax = 276, zmax = 4, reserved = { { T.lot[1], T.lot[2], 86, T.lot[4] }, { 55, -90, 106, 6 } }, lot = T.lot, avoidInner = { { 190, -400, 234, -108 } } }, -- Lücke in der Häuserzeile: Tankstelle liegt frei an der Straße, lot = ihr Grundstück
}

end)()

local Specials = (function()

local Config = Config
local T = Config.tankstelle

return {
	{ name = "Isarbank", x0 = -127, z0 = -385, x1 = -55, z1 = -315, facing = "E", floors = 4, color = { 176, 120, 100 } },
	{ name = "Parkhaus", x0 = -205, z0 = -250, x1 = -109, z1 = -140, facing = "N", floors = 4, color = { 170, 170, 176 } },
	{ name = "Tankstellen-Shop", x0 = 78, z0 = -332, x1 = 146, z1 = -298, facing = "W", floors = 1, color = { 250, 250, 250 }, style = "tankstelle", canopy = { 78, -298, 146, -202 }, lot = T.lot, curbGaps = T.gaps, ev = T.ev },
	{ name = "Tankstellen-Buero-Nord", x0 = 190, z0 = -400, x1 = 234, z1 = -318, facing = "W", floors = 5, color = { 38, 48, 62 }, style = "buero" },
	{ name = "Tankstellen-Buero-Mitte", x0 = 190, z0 = -302, x1 = 234, z1 = -210, facing = "W", floors = 6, color = { 38, 48, 62 }, style = "buero" },
	{ name = "Tankstellen-Buero-Sued", x0 = 190, z0 = -194, x1 = 234, z1 = -108, facing = "W", floors = 5, color = { 38, 48, 62 }, style = "buero" },
	{ name = "Feuer-und-Rettungswache", x0 = -429.5, z0 = -200, x1 = -265.5, z1 = -100, facing = "W", floors = 4, color = { 200, 70, 55 }, style = "feuerwache" },
	{ name = "Polizeiwache", x0 = 202, z0 = 340, x1 = 342, z1 = 384, facing = "S", floors = 5, color = { 70, 110, 200 }, style = "polizei", compound = "polizei" },
	{ name = "Polizei-Seitenfluegel", x0 = 202, z0 = 298, x1 = 218, z1 = 340, facing = "E", floors = 3, color = { 92, 94, 104 } },
	{ name = "Krankenhaus", x0 = 340, z0 = -430, x1 = 500, z1 = -310, facing = "W", floors = 5, color = { 90, 170, 150 }, style = "klinik" },
	{ name = "Kiosk", x0 = -350, z0 = 66, x1 = -300, z1 = 106, facing = "N", floors = 1, color = { 200, 70, 55 } },
	{ name = "Cafe-Terrasse", x0 = -130, z0 = 64, x1 = -66, z1 = 116, facing = "E", floors = 2, color = { 226, 190, 120 } },
	{ name = "Uni-Fassade", x0 = -160, z0 = 130, x1 = -60, z1 = 220, facing = "E", floors = 4, color = { 214, 204, 176 } },
	{ name = "Casino-Odeon", x0 = -200, z0 = 316, x1 = -144, z1 = 360, facing = "E", floors = 2, color = { 70, 56, 84 } },
	{ name = "Kaffeehaus", x0 = 144, z0 = 300, x1 = 194, z1 = 340, facing = "W", floors = 2, color = { 100, 150, 100 } },
	{ name = "Prinz-Eins", x0 = 546, z0 = 330, x1 = 602, z1 = 370, facing = "S", floors = 2, color = { 52, 44, 76 } },
}

end)()

local RoadsPlanner = (function()

local Geo = Geo

local RoadsPlanner = {}

local COLOR = {
	road = { 84, 90, 96 }, walk = { 168, 172, 174 }, plaza = { 214, 208, 196 }, median = { 118, 150, 98 }, green = { 104, 148, 84 }, bike = { 176, 66, 58 },
	dash = { 236, 236, 230 }, deck = { 140, 140, 146 }, rail = { 70, 70, 76 }, tunnel = { 110, 110, 116 },
}
local MATERIAL = { road = "Asphalt", walk = "Concrete", plaza = "Concrete", median = "Grass", green = "Grass", bike = "Asphalt" }
local TOP = { road = 0.5, walk = 1.0, plaza = 0.5, median = 0.8, green = 1.0, bike = 0.8 }
local DASH_Y, DASH_H = 0.6, 0.2
local THICK = { road = 1, walk = 2, plaza = 1, median = 1.8, green = 1.8, bike = 1.8 }
local CUT = { walk = true, green = true, bike = true } -- Streifen, die an Kreuzungen unterbrochen werden (Gehwege, Grün- und Radwegstreifen)

local function part(parts, name, kind, x, y, z, sx, sy, sz, yaw, color, material, extra)
	extra = extra or {}
	parts[#parts + 1] = {
		name = name, kind = kind, size = { sx, sy, sz },
		pos = { Geo.round3(x), Geo.round3(y), Geo.round3(z) },
		yaw = Geo.round3(yaw), pitch = extra.pitch or 0, color = color, material = material,
		collide = extra.collide ~= false, seg = extra.seg, shape = extra.shape, roll = extra.roll,
	}
end

local TILE, JOINT, JOINT_COLOR = 6, 0.18, { 150, 144, 136 }
local function tileJoints(parts, cx, cz, ux, uz, len, w, top, yaw, seg)
	local nx, nz = -uz, ux
	local y = top + 0.03
	local k = 1
	while k * TILE < len do -- Fugen quer zur Länge
		local t = -len / 2 + k * TILE
		part(parts, "Fuge", "joint", cx + ux * t, y, cz + uz * t, JOINT, 0.06, w, yaw, JOINT_COLOR, "SmoothPlastic", { collide = false, seg = seg })
		k = k + 1
	end
	k = 1
	while k * TILE < w do -- Fugen in Längsrichtung
		local v = -w / 2 + k * TILE
		part(parts, "Fuge", "joint", cx + nx * v, y, cz + nz * v, len, 0.06, JOINT, yaw, JOINT_COLOR, "SmoothPlastic", { collide = false, seg = seg })
		k = k + 1
	end
end

local function buildSegments(cfg)
	local segs = {}
	for _, road in ipairs(cfg.roads) do
		local prof = cfg.profiles[road.profile]
		local pts, n = road.pts, #road.pts
		local count = road.closed and n or n - 1
		local dirs = {}
		for i = 1, count do
			local a, b = pts[i], pts[(i % n) + 1]
			local ux, uz, l = Geo.dir(a[1], a[2], b[1], b[2])
			dirs[i] = { ux, uz, l }
		end
		local function ext(i, j) -- Verlängerung zwischen Segment i und Segment j
			if not dirs[i] or not dirs[j] then return 0 end
			local c = dirs[i][1] * dirs[j][1] + dirs[i][2] * dirs[j][2]
			c = math.max(-1, math.min(1, c))
			return prof.half * math.tan(math.acos(c) / 2)
		end
		for i = 1, count do
			local prev = (i > 1) and i - 1 or (road.closed and count or nil)
			local nxt = (i < count) and i + 1 or (road.closed and 1 or nil)
			local a, b = pts[i], pts[(i % n) + 1]
			local extA, extB = prev and ext(prev, i) or 0, nxt and ext(i, nxt) or 0
			segs[#segs + 1] = {
				id = #segs + 1, road = road, prof = prof, ax = a[1], az = a[2], ux = dirs[i][1], uz = dirs[i][2], len = dirs[i][3],
				extA = extA, extB = extB, rect = Geo.rect(a[1], a[2], b[1], b[2], prof.half, extA, extB),
			}
		end
	end
	return segs
end

local LEVEL_STEP = 0.04
local PLAZA_LIFT = 0.2 -- Plätze liegen über allen Fahrbahnen
local function roadLevels(segs)
	local level = {}
	for _, s in ipairs(segs) do
		local used = {}
		for _, o in ipairs(segs) do
			if level[o.id] and Geo.rectsOverlap(s.rect, o.rect) then used[level[o.id]] = true end
		end
		local k = 0
		while used[k] do k = k + 1 end
		level[s.id] = k
	end
	return level
end

function RoadsPlanner.segments(cfg)
	return buildSegments(cfg)
end

local function crossCuts(segs, self, px, pz, L, margin)
	local cuts = {}
	for _, o in ipairs(segs) do
		if o.id ~= self.id then
			local lo, hi = Geo.within(px, pz, self.ux, self.uz, L, o.rect, margin)
			if lo then cuts[#cuts + 1] = { lo, hi } end
		end
	end
	return cuts
end

function RoadsPlanner.plan(cfg)
	local parts = {}
	local segs = buildSegments(cfg)
	local stats = { bays = 0, dashes = 0 }
	local level = roadLevels(segs)

	for _, seg in ipairs(segs) do
		local yaw = Geo.yawOf(seg.ux, seg.uz)
		local p0x, p0z = seg.ax - seg.ux * seg.extA, seg.az - seg.uz * seg.extA
		local L = seg.len + seg.extA + seg.extB
		local nx, nz = -seg.uz, seg.ux
		local bridgeCuts = {}
		for _, b in ipairs(cfg.isarBridges) do
			local br = math.rad(b.yaw)
			local bx, bz = math.cos(br), -math.sin(br)
			local dx, dz = b.x - p0x, b.z - p0z
			local along, across = dx * seg.ux + dz * seg.uz, dx * nx + dz * nz
			if math.abs(across) < 2.5 and math.abs(bx * seg.ux + bz * seg.uz) > 0.95 then
				bridgeCuts[#bridgeCuts + 1] = { along - b.len / 2, along + b.len / 2 }
			end
		end
		for si, st in ipairs(seg.prof.strips) do
			local mid, w, kind = (st[1] + st[2]) / 2, st[2] - st[1], st[3]
			local sx, sz = p0x + nx * mid, p0z + nz * mid
			local cuts = {}
			local lift = (kind == "road") and LEVEL_STEP * level[seg.id] or (kind == "plaza" and PLAZA_LIFT or 0)
			if CUT[kind] then cuts = crossCuts(segs, seg, sx, sz, L, 0.05) end
			for _, bc in ipairs(bridgeCuts) do cuts[#cuts + 1] = bc end
			for _, sp in ipairs(Geo.subtract({ { 0, L } }, cuts)) do
				local len = sp[2] - sp[1]
				if len > 0.5 then
					local c = (sp[1] + sp[2]) / 2
					part(parts, string.format("%s_%d_%s", seg.road.name, seg.id, kind), kind, sx + seg.ux * c, TOP[kind] + lift - THICK[kind] / 2, sz + seg.uz * c,
						len, THICK[kind], w, yaw, COLOR[kind], MATERIAL[kind], { seg = seg.id })
					if kind == "plaza" then tileJoints(parts, sx + seg.ux * c, sz + seg.uz * c, seg.ux, seg.uz, len, w, TOP.plaza + lift, yaw, seg.id) end
				end
			end
		end
		for _, d in ipairs(seg.prof.dashes) do
			local sx, sz = p0x + nx * d, p0z + nz * d
			local cuts = crossCuts(segs, seg, sx, sz, L, 0.5)
			for _, bc in ipairs(bridgeCuts) do cuts[#cuts + 1] = bc end
			for _, sp in ipairs(Geo.subtract({ { 0, L } }, cuts)) do
				local t = sp[1] + 1
				while t + 6 <= sp[2] - 1 do
					local c = t + 3
					part(parts, "Dash", "dash", sx + seg.ux * c, DASH_Y, sz + seg.uz * c, 6, DASH_H, 0.4, yaw, COLOR.dash, "SmoothPlastic", { collide = false, seg = seg.id })
					stats.dashes = stats.dashes + 1
					t = t + 12
				end
			end
		end
	end

	for _, b in ipairs(cfg.bays) do
		local x0, z0, x1, z1 = b[1], b[2], b[3], b[4]
		local ux, uz, len = Geo.dir(x0, z0, x1, z1)
		local n = math.floor(len / cfg.bay.length)
		for k = 0, n do
			local x, z = x0 + ux * cfg.bay.length * k, z0 + uz * cfg.bay.length * k
			if math.abs(ux) > 0.999 or math.abs(uz) > 0.999 then
				local sx, sz = (math.abs(ux) > 0.5) and 0.3 or cfg.bay.width, (math.abs(ux) > 0.5) and cfg.bay.width or 0.3
				part(parts, "BayLine", "dash", x, DASH_Y, z, sx, DASH_H, sz, 0, COLOR.dash, "SmoothPlastic", { collide = false })
			else -- schräge Straße (Isar-Allee): Linie quer zur Laufrichtung
				part(parts, "BayLine", "dash", x, DASH_Y, z, 0.3, DASH_H, cfg.bay.width, Geo.yawOf(ux, uz), COLOR.dash, "SmoothPlastic", { collide = false })
			end
		end
		stats.bays = stats.bays + n
	end

	for _, pl in ipairs(cfg.plazas) do
		part(parts, "Plaza_" .. pl.name, "plaza", (pl.x0 + pl.x1) / 2, TOP.plaza + PLAZA_LIFT - THICK.plaza / 2, (pl.z0 + pl.z1) / 2, pl.x1 - pl.x0, 1, pl.z1 - pl.z0, 0, COLOR.plaza, MATERIAL.plaza, {})
		tileJoints(parts, (pl.x0 + pl.x1) / 2, (pl.z0 + pl.z1) / 2, 1, 0, pl.x1 - pl.x0, pl.z1 - pl.z0, TOP.plaza + PLAZA_LIFT, 0)
	end

	for _, b in ipairs(cfg.bridges) do
		local r = math.rad(b.yaw)
		local c, s = math.cos(r), math.sin(r)
		local top = b.pedestrian and 1.0 or -0.5 -- Fußgängerbrücke liegt auf Gehwegshöhe
		part(parts, "Deck_" .. b.name, "deck", b.x, top - 1.5, b.z, b.len, 3, b.wid, b.yaw, COLOR.deck, "Concrete", {})
		for _, side in ipairs({ -1, 1 }) do
			local off = side * (b.wid / 2 - 0.2)
			part(parts, "Rail_" .. b.name, "rail", b.x + off * s, 2.5, b.z + off * c, b.len, 3, 0.4, b.yaw, COLOR.rail, "Metal", {})
		end
	end

	local STONE = { 196, 188, 172 }
	local function floorAt(x, z) -- Oberkante des Geländes im Flussprofil
		local y = 0
		local d = Geo.polyDist(x, z, cfg.water.isar.pts)
		for _, ly in ipairs(cfg.water.isar.layers) do
			if d < ly[3] then y = ly[2] end
		end
		if Geo.polyDist(x, z, cfg.water.bach.pts) < 16 then y = math.min(y, -7) end
		return y
	end
	local function maximilian(b, ux, uz, nx2, nz2)
		local total = b.wid + 2 * b.walk
		local BODY = { 200, 190, 168 }
		local function at(sAlong, lat) return b.x + ux * sAlong + nx2 * lat, b.z + uz * sAlong + nz2 * lat end
		part(parts, "BrueckeFahrbahn", "road", b.x, -0.25, b.z, b.len, 1.5, b.wid, b.yaw, COLOR.road, "Asphalt", {})
		for _, side in ipairs({ -1, 1 }) do
			local x, z = at(0, side * (b.wid / 2 + b.walk / 2))
			part(parts, "BrueckeGehweg", "walk", x, 0.25, z, b.len, 1.5, b.walk, b.yaw, STONE, "Concrete", {})
			x, z = at(0, side * (b.wid / 2 + b.walk - 0.4))
			part(parts, "BrueckeBruestung", "rail", x, 1.7, z, b.len, 1.4, 0.8, b.yaw, STONE, "Concrete", {})
			x, z = at(0, side * (total / 2 - 0.2))
			part(parts, "BrueckeGesims", "deck", x, -0.5, z, b.len, 0.7, 1.2, b.yaw, { 176, 166, 146 }, "Concrete", {})
		end
		local a, f = b.span / 2, b.rise
		local R = (a * a + f * f) / (2 * f)
		local yc = -2.5
		for _, sc in ipairs({ -a, a }) do
			local n = 24
			local w = 2 * a / n
			for k = 1, n do
				local sm = sc - a + (k - 0.5) * w
				local soffit = yc - R + math.sqrt(R * R - (sm - sc) ^ 2)
				local h = -1 - soffit
				local x, z = at(sm, 0)
				part(parts, "BrueckeBogen", "deck", x, (-1 + soffit) / 2, z, w + 0.05, h, total - 4, b.yaw, BODY, "Concrete", {})
			end
		end
		for _, sd in ipairs({ -1, 1 }) do -- Widerlager: massiver Block vom Bogenende bis zum Brückenende
			local s0, s1 = b.span, b.len / 2
			local x, z = at(sd * (s0 + s1) / 2, 0)
			part(parts, "BrueckeWiderlager", "deck", x, -4.5, z, s1 - s0, 7, total - 4, b.yaw, BODY, "Concrete", {})
			x, z = at(sd * b.span, 0) -- Fuß unter dem Bogenansatz bis in die Kiesbank
			part(parts, "BrueckePfeiler", "deck", x, -9.5, z, 6, 6, total - 8, b.yaw, BODY, "Concrete", {})
		end
		local px, pz = at(0, 0) -- Mittelpfeiler vom Flussbett bis zum Bogenansatz, Vorköpfe rund
		part(parts, "BrueckePfeiler", "deck", px, -11, pz, 7, 8, total - 16, b.yaw, BODY, "Concrete", {})
		for _, sd in ipairs({ -1, 1 }) do
			local x, z = at(0, sd * (total - 16) / 2)
			part(parts, "BrueckePfeilerKopf", "deck", x, -11, z, 8, 7, 7, 0, BODY, "Concrete", { shape = "Cylinder", roll = 90 })
		end
		local STATUE = { 176, 172, 162 }
		for _, sd in ipairs({ -1, 1 }) do
			local x, z = at(0, sd * 25.5)
			part(parts, "StatueSockel", "deck", x, 3.5, z, 5, 5, 5, b.yaw, BODY, "Concrete", {})
			part(parts, "StatueGewand", "deck", x, 8.5, z, 3.2, 5, 3.2, b.yaw, STATUE, "Concrete", { collide = false })
			part(parts, "StatueTorso", "deck", x, 12.2, z, 2.6, 2.6, 2, b.yaw, STATUE, "Concrete", { collide = false })
			part(parts, "StatueKopf", "deck", x, 14.3, z, 1.6, 1.8, 1.6, b.yaw, STATUE, "Concrete", { collide = false })
		end
		for _, s in ipairs({ -b.span, 0, b.span }) do
			for _, sd in ipairs({ -1, 1 }) do
				local x, z = at(s, sd * 27)
				part(parts, "BrueckenLaterne", "lamp", x, 5.5, z, 0.5, 9, 0.5, 0, { 40, 56, 48 }, "Metal", {})
				part(parts, "BrueckenLaternenKasten", "lamp", x, 10.8, z, 1.6, 2, 1.6, 0, { 255, 226, 150 }, "Neon", { collide = false })
				parts[#parts].tag, parts[#parts].attrs = "StreetLamp", { Lit = true }
			end
		end
		stats.isarBridges = (stats.isarBridges or 0) + 1
	end

	for _, b in ipairs(cfg.isarBridges) do
		local r = math.rad(b.yaw)
		local ux, uz = math.cos(r), -math.sin(r) -- Richtung der Brücke
		local nx2, nz2 = -uz, ux -- quer
		if b.style == "maximilian" then
			maximilian(b, ux, uz, -uz, ux)
		else
			local total = b.wid + 2 * b.walk
			part(parts, "BrueckeFahrbahn", "road", b.x, -1.5, b.z, b.len, 4, b.wid, b.yaw, COLOR.road, "Asphalt", {})
			for _, side in ipairs({ -1, 1 }) do
				local lat = side * (b.wid / 2 + b.walk / 2)
				part(parts, "BrueckeGehweg", "walk", b.x + nx2 * lat, -1, b.z + nz2 * lat, b.len, 4, b.walk, b.yaw, STONE, "Concrete", {})
				lat = side * (b.wid / 2 + b.walk - 0.4)
				part(parts, "BrueckeBruestung", "rail", b.x + nx2 * lat, 1.7, b.z + nz2 * lat, b.len, 1.4, 0.8, b.yaw, STONE, "Concrete", {})
			end
			local k = 0
			while k * b.pier <= b.len / 2 - 8 do
				for _, sgn in ipairs(k == 0 and { 1 } or { -1, 1 }) do
					local s = sgn * k * b.pier
					local px, pz = b.x + ux * s, b.z + uz * s
					local floor = floorAt(px, pz)
					if floor <= -8 then -- nur im Wasser und auf der Kiesbank
						part(parts, "BrueckePfeilerBalken", "deck", px, -5, pz, 6, 3, total - 6, b.yaw, STONE, "Concrete", {})
						for _, lat in ipairs({ -21, -7, 7, 21 }) do
							local h = -6.5 - (floor - 1)
							part(parts, "BrueckeSaeule", "deck", px + nx2 * lat, (floor - 1 - 6.5) / 2, pz + nz2 * lat, h, 4.5, 4.5, 0, STONE, "Concrete", { shape = "Cylinder", roll = 90 })
						end
						stats.piers = (stats.piers or 0) + 1
					end
				end
				k = k + 1
			end
			stats.isarBridges = (stats.isarBridges or 0) + 1
		end
	end

	stats.stalls = stats.bays
	return { parts = parts, stats = stats, segments = segs }
end

return RoadsPlanner

end)()

local LightsPlanner = (function()

local Geo = Geo

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

end)()

local Landmarks = (function()

local Geo = Geo

local Landmarks = {}

local function new(parts, cx, cz)
	return function(name, x, y, z, sx, sy, sz, color, material, extra)
		extra = extra or {}
		parts[#parts + 1] = {
			name = name, kind = extra.kind or "landmark", size = { sx, sy, sz }, pos = { Geo.round3(cx + x), Geo.round3(y), Geo.round3(cz + z) },
			yaw = extra.yaw or 0, pitch = extra.pitch or 0, roll = extra.roll, color = color, material = material, collide = extra.collide ~= false,
			text = extra.text, transparency = extra.transparency, shape = extra.shape,
		}
	end
end

function Landmarks.siegestor(cfg)
	local parts = {}
	local L = cfg.landmarks.siegestor
	local add = new(parts, L.x, L.z)
	local y0 = L.baseY
	local STONE, LIGHT, DARK, RELIEF = { 214, 200, 170 }, { 226, 214, 186 }, { 176, 162, 134 }, { 192, 178, 150 }
	local BRONZE = { 92, 140, 118 }
	local D, TOP = 12, 42 -- Tiefe, Höhe der Unterkante des Gebälks
	local function pier(x0, x1, name)
		add(name, (x0 + x1) / 2, y0 + TOP / 2, 0, x1 - x0, TOP, D, STONE, "Concrete")
	end
	pier(-32, -23, "PfeilerAussen")
	pier(-13, -8, "PfeilerMitte")
	pier(8, 13, "PfeilerMitte")
	pier(23, 32, "PfeilerAussen")
	local function arch(cx, r, spring, n, name)
		local w = 2 * r / n
		for i = 1, n do
			local xc = -r + (i - 0.5) * w
			local bottom = spring + math.sqrt(math.max(0, r * r - xc * xc))
			add(name, cx + xc, y0 + (bottom + TOP) / 2, 0, w + 0.05, TOP - bottom, D, STONE, "Concrete")
		end
	end
	arch(0, 8, 20, 8, "BogenMitte")
	arch(-18, 5, 14, 6, "BogenSeite")
	arch(18, 5, 14, 6, "BogenSeite")
	for _, z in ipairs({ -D / 2 - 0.8, D / 2 + 0.8 }) do
		for _, x in ipairs({ -27.5, -10.5, 10.5, 27.5 }) do
			add("Saeule", x, y0 + 20, z, 2.4, 36, 2.4, LIGHT, "Concrete")
			add("SaeuleSockel", x, y0 + 1, z, 3.6, 2, 3.6, DARK, "Concrete")
			add("SaeuleKapitell", x, y0 + 39, z, 3.8, 4, 3.8, DARK, "Concrete")
		end
		add("Relief", -18, y0 + 31, z * (D / 2 + 0.15) / (D / 2 + 0.8), 9, 7, 0.4, RELIEF, "Concrete", { collide = false })
		add("Relief", 18, y0 + 31, z * (D / 2 + 0.15) / (D / 2 + 0.8), 9, 7, 0.4, RELIEF, "Concrete", { collide = false })
	end
	add("Gebaelk", 0, y0 + TOP + 1.5, 0, 66, 3, D + 2, STONE, "Concrete")
	add("Attika", 0, y0 + TOP + 8.5, 0, 60, 11, D, LIGHT, "Concrete")
	add("Kranz", 0, y0 + TOP + 15, 0, 66, 2, D + 2, STONE, "Concrete")
	add("Schrift", 0, y0 + TOP + 8.5, -D / 2 - 0.15, 52, 2.4, 0.2, { 60, 56, 50 }, "SmoothPlastic",
		{ collide = false, kind = "text", text = { s = "DEM SIEGE GEWEIHT · VOM KRIEG ZERSTÖRT · ZUM FRIEDEN MAHNEND", color = { 60, 56, 50 } } })
	add("Schrift", 0, y0 + TOP + 8.5, D / 2 + 0.15, 30, 3, 0.2, { 60, 56, 50 }, "SmoothPlastic",
		{ collide = false, kind = "text", yaw = 180, text = { s = "SIEGESTOR", color = { 60, 56, 50 } } })
	local yt = y0 + TOP + 16
	add("StatueSockel", 0, yt + 2, 0, 14, 4, 8, STONE, "Concrete")
	add("StatueRock", 0, yt + 8, 0, 5, 8, 4, BRONZE, "Metal")
	add("StatueTorso", 0, yt + 14, 0, 3.8, 6, 2.8, BRONZE, "Metal")
	add("StatueKopf", 0, yt + 18.2, 0, 2, 2.4, 2, BRONZE, "Metal")
	add("StatueLanze", -3.2, yt + 14, 0, 0.5, 20, 0.5, { 70, 66, 60 }, "Metal", { collide = false })
	add("StatueArm", -1.9, yt + 14.5, 0, 1, 4, 1, BRONZE, "Metal", { collide = false })
	return parts
end

function Landmarks.siegestorInsel(cfg)
	local parts = {}
	local L = cfg.landmarks.siegestor
	local add = new(parts, L.x, L.z)
	local R = L.islandR
	add("InselRasen", 0, 0.35, 0, 1.5, 2 * R, 2 * R, { 96, 156, 72 }, "Grass", { shape = "Cylinder", roll = 90, collide = true })
	local n = 44
	for i = 1, n do -- Randsteine auf dem Kreis (Radius R + 1,2), Oberkante 1,5
		local a = 2 * math.pi * (i - 0.5) / n
		local rr = R + 1.2
		add("InselRandstein", rr * math.cos(a), 0.65, rr * math.sin(a), 2 * math.pi * rr / n + 0.25, 1.7, 2.4, { 190, 186, 176 }, "Concrete",
			{ yaw = math.deg(math.atan2(-math.cos(a), -math.sin(a))) % 360, collide = true })
	end
	add("InselPlatte", 0, L.baseY - 0.2, 0, 80, 0.4, 30, { 206, 200, 186 }, "Concrete", { collide = true })
	return parts
end

function Landmarks.friedensengel(cfg)
	local parts = {}
	local L = cfg.landmarks.friedensengel
	local add = new(parts, L.x, L.z)
	local y0 = L.baseY
	local STONE, VERD, BRONZE, GOLD, WATER = { 206, 200, 186 }, { 150, 176, 166 }, { 52, 62, 58 }, { 236, 184, 44 }, { 120, 170, 210 }
	local function vcyl(name, x, y, z, h, d, color, mat, extra)
		extra = extra or {}
		add(name, x, y, z, h, d, d, color, mat, { shape = "Cylinder", roll = 90, collide = extra.collide ~= false, transparency = extra.transparency })
	end
	vcyl("Rondell", 0, y0 + 0.45, 0, 0.9, 62, STONE, "Concrete")
	local yb = y0 + 0.9
	for i = 0, 23 do
		local a = math.rad(i * 15)
		local tx, tz = -math.sin(a), math.cos(a)
		add("Beckenrand", 18 * math.cos(a), yb + 1, 18 * math.sin(a), 5.2, 2, 2, STONE, "Concrete", { yaw = math.deg(math.atan2(-tz, tx)) % 360 })
	end
	vcyl("Wasser", 0, yb + 0.9, 0, 0.4, 35.6, WATER, "SmoothPlastic", { collide = false, transparency = 0.45 })
	vcyl("SockelStufe", 0, yb + 1.5, 0, 3, 23, STONE, "Concrete")
	vcyl("SockelStufe", 0, yb + 4.5, 0, 3, 17, STONE, "Concrete")
	add("SockelStufe", 0, yb + 9, 0, 11, 6, 11, STONE, "Concrete")
	add("SockelGesims", 0, yb + 12.3, 0, 12.6, 0.8, 12.6, STONE, "Concrete")
	for _, sd in ipairs({ { 0, -1, 0 }, { 0, 1, 180 }, { -1, 0, 90 }, { 1, 0, 270 } }) do -- Bronzereliefs an den vier Seiten des Sockels
		local px, pz = sd[1] * 5.65, sd[2] * 5.65
		local along = (sd[1] ~= 0)
		add("SockelRelief", px, yb + 9, pz, along and 0.3 or 7, 4, along and 7 or 0.3, BRONZE, "Metal", { collide = false })
	end
	for _, cx in ipairs({ -7.4, 7.4 }) do -- Urnen auf den Ecken der mittleren Stufe
		for _, cz in ipairs({ -7.4, 7.4 }) do
			add("Urne", cx, yb + 7.4, cz, 1.8, 2.4, 1.8, STONE, "Concrete", { collide = false })
			add("UrneKopf", cx, yb + 9, cz, 2.2, 2.2, 2.2, STONE, "Concrete", { shape = "Ball", collide = false })
		end
	end
	local ys = yb + 12.7 -- Säulenfuß
	vcyl("SaeuleFuss", 0, ys + 1.5, 0, 3, 9, STONE, "Concrete")
	vcyl("Saeule", 0, ys + 3 + 32, 0, 64, 7, VERD, "Concrete")
	for i = 0, 7 do -- Kanneluren: acht dünne Rillenstäbe rund um den Schaft
		local a = math.rad(i * 45)
		vcyl("SaeuleKannelur", 3.55 * math.cos(a), ys + 3 + 32, 3.55 * math.sin(a), 58, 0.7, { 128, 156, 146 }, "Concrete", { collide = false })
	end
	for _, dy in ipairs({ 4.5, 33, 61.5 }) do vcyl("SaeuleRing", 0, ys + dy, 0, 1.4, 7.8, STONE, "Concrete", { collide = false }) end
	local yk = ys + 3 + 64
	vcyl("Kapitell", 0, yk + 3, 0, 6, 8.4, BRONZE, "Metal")
	for i = 0, 7 do -- Akanthusblätter
		local a = math.rad(i * 45 + 22.5)
		add("KapitellBlatt", 5.2 * math.cos(a), yk + 3.4, 5.2 * math.sin(a), 2, 4.4, 2, BRONZE, "Metal", { shape = "Ball", collide = false })
	end
	add("Abakus", 0, yk + 7, 0, 11, 2, 11, BRONZE, "Metal")
	for _, cx in ipairs({ -5.2, 5.2 }) do for _, cz in ipairs({ -5.2, 5.2 }) do add("Volute", cx, yk + 6, cz, 2.2, 2.2, 2.2, BRONZE, "Metal", { shape = "Ball", collide = false }) end end
	vcyl("Trommel", 0, yk + 11, 0, 6, 6.5, BRONZE, "Metal")
	vcyl("EngelSockel", 0, yk + 14.4, 0, 0.8, 8, BRONZE, "Metal", { collide = false })
	local ya = yk + 14.8
	local k = 1.9
	local function G(name, x, y, z, sx, sy, sz, extra) add(name, x * k, ya + y * k, z * k, sx * k, sy * k, sz * k, GOLD, "Metal", extra) end
	local function ball(name, x, y, z, d) G(name, x, y, z, d, d, d, { shape = "Ball", collide = false }) end
	local function limb(name, a, b, d) -- Zylinder von Punkt a nach Punkt b (Einheiten k)
		local dx, dy, dz = b[1] - a[1], b[2] - a[2], b[3] - a[3]
		local hz = math.sqrt(dx * dx + dz * dz)
		G(name, (a[1] + b[1]) / 2, (a[2] + b[2]) / 2, (a[3] + b[3]) / 2, math.sqrt(hz * hz + dy * dy), d, d,
			{ shape = "Cylinder", roll = math.deg(math.atan2(dy, hz)), yaw = Geo.yawOf(dx, dz), collide = false })
	end
	local function gcyl(name, y, h, d, x) G(name, x or 0, y, 0, h, d, d, { shape = "Cylinder", roll = 90, collide = false }) end
	for i = 0, 11 do -- Gewand: zwölf Scheiben, unten weit ausgestellt, zur Taille hin fließend schmaler
		local u = i / 11
		gcyl("EngelRock", 0.35 + i * 0.5, 0.75, 3.4 + 2.1 * (1 - u) ^ 1.7)
	end
	gcyl("EngelGuertel", 6.15, 0.5, 3.55)
	gcyl("EngelRumpf", 7.4, 2.3, 2.9)
	ball("EngelBrust", -0.15, 8.8, 0, 3.3)
	ball("EngelSchulter", 0, 9.3, -1.55, 1.2)
	ball("EngelSchulter", 0, 9.3, 1.55, 1.2)
	gcyl("EngelHals", 10.15, 0.9, 0.9)
	ball("EngelKopf", -0.05, 11.3, 0, 2.1)
	ball("EngelHaar", 0.4, 11.35, 0, 2.3)
	for i = 0, 7 do -- Lorbeerkranz
		local a = math.rad(i * 45)
		ball("EngelKranz", -0.05 + 1.1 * math.cos(a), 12.1, 1.1 * math.sin(a), 0.55)
	end
	local lens = { 7, 6.6, 5.9, 5, 4 }
	for _, side in ipairs({ -1, 1 }) do
		ball("EngelFluegelAnsatz", 0.9, 9.4, side * 0.9, 1.5)
		for i, l in ipairs(lens) do
			local pd = 8 + (i - 1) * 12
			local p, r = math.rad(pd), math.rad(-12)
			local dx, dy, dz = -math.sin(r), math.cos(r) * math.cos(p), side * math.cos(r) * math.sin(p) -- Richtung der Feder (Rx(p) * Rz(r) auf die y-Achse)
			G("EngelFluegel", 0.9 + dx * l / 2, 9.4 + dy * l / 2, side * 0.9 + dz * l / 2, 0.4, l, 1.25, { pitch = side * pd, roll = -12, collide = false })
		end
	end
	limb("EngelArm", { 0, 9.3, -1.55 }, { -0.9, 10.0, -2.9 }, 0.85)
	limb("EngelArm", { -0.9, 10.0, -2.9 }, { -1.4, 12.0, -3.1 }, 0.75)
	ball("EngelHand", -1.4, 12.2, -3.1, 0.9)
	limb("EngelZweig", { -1.4, 12.3, -3.1 }, { -1.9, 14.9, -3.3 }, 0.22)
	for i = 0, 5 do
		local t = (i + 1) / 7
		ball("EngelBlatt", -1.4 - 0.5 * t, 12.3 + 2.6 * t, -3.1 - 0.2 * t + ((i % 2 == 0) and -0.45 or 0.45), 0.6)
	end
	limb("EngelArm", { 0, 9.3, 1.55 }, { -0.7, 8.4, 2.4 }, 0.85)
	limb("EngelArm", { -0.7, 8.4, 2.4 }, { -2.0, 8.9, 2.5 }, 0.75)
	ball("EngelHand", -2.0, 8.9, 2.5, 0.9)
	gcyl("EngelNike", 9.7, 1.2, 0.5, -2.1) -- kleine Figur: Körper, Kopf, Flügel
	for _, sd in ipairs({ -1, 1 }) do G("EngelNikeFluegel", -1.95, 9.9, 2.5 + sd * 0.3, 0.1, 1.2, 0.5, { pitch = sd * 30, collide = false }) end
	ball("EngelNikeKopf", -2.1, 10.5, 2.5, 0.5)
	for _, a in ipairs({ { 4.5, 0 }, { -4.5, 0 }, { 0, 4.5 }, { 0, -4.5 } }) do
		add("Wasserstrahl", a[1], yb + 4, a[2], 0.9, 8, 0.9, { 240, 248, 255 }, "SmoothPlastic", { collide = false, transparency = 0.5 })
	end
	local t = cfg.terrace
	local sx0 = t.x0 - 14 - L.x
	for i = 1, 4 do
		add("TerrassenStufe", sx0 + (i - 0.5) * 3.5, i / 2 - 0.2, 0, 3.5, i + 0.4, 24, STONE, "Concrete")
	end
	for _, sd in ipairs({ -1, 1 }) do
		add("TerrassenWange", sx0 + 7, 1.8, sd * 12.8, 14, 4.4, 1.6, STONE, "Concrete")
	end
	return parts
end

local function clock(add, x, y, z, R, face)
	local WHITE, DARK, GOLD = { 246, 242, 230 }, { 36, 34, 32 }, { 214, 176, 70 }
	local nx = (face == "W") and -1 or ((face == "E") and 1 or 0)
	local nz = (face == "N") and -1 or ((face == "S") and 1 or 0)
	local onX = nx ~= 0
	local yaw = (face == "W") and 90 or ((face == "E") and 270 or ((face == "N") and 0 or 180))
	local sgn = (face == "W" or face == "S") and 1 or -1 -- Richtung "rechts" aus Sicht des Betrachters entlang z (x-Flächen) bzw. x (z-Flächen)
	if face == "N" then sgn = -1 end
	local function pos(dy, dr) return x + (onX and 0 or dr), y + dy, z + (onX and dr or 0) end
	local function disc(name, dia, thick, off, color, mat)
		local ox, oy, oz = x + nx * off, y, z + nz * off
		if onX then add(name, ox, oy, oz, thick, dia, dia, color, mat, { shape = "Cylinder", collide = false })
		else add(name, ox, oy, oz, thick, dia, dia, color, mat, { shape = "Cylinder", yaw = 90, collide = false }) end
	end
	disc("UhrRand", R * 2 + 3, 0.8, 0.5, DARK, "Metal")
	disc("Uhr", R * 2, 0.8, 0.9, WHITE, "SmoothPlastic")
	local function oriented(name, dy, dr, sx, sy, sz, rot, color, off)
		local px, py, pz = pos(dy, dr)
		px, pz = px + nx * off, pz + nz * off
		if onX then add(name, px, py, pz, sx, sy, sz, color, "Metal", { pitch = rot, collide = false })
		else add(name, px, py, pz, sx, sy, sz, color, "Metal", { roll = rot, collide = false }) end
	end
	local function toRot(phi) return onX and (sgn * phi) or (-sgn * phi) end
	for i = 0, 11 do -- Striche
		local phi = math.rad(i * 30)
		local len = (i % 3 == 0) and 2.6 or 1.5
		local rr = R - 0.9 - len / 2
		if onX then oriented("Uhrstrich", rr * math.cos(phi), sgn * rr * math.sin(phi), 0.3, len, 0.45, math.deg(phi) * sgn, DARK, 1.2)
		else oriented("Uhrstrich", rr * math.cos(phi), sgn * rr * math.sin(phi), 0.45, len, 0.3, -math.deg(phi) * sgn, DARK, 1.2) end
	end
	local function hand(name, phiDeg, len, w)
		local phi = math.rad(phiDeg)
		local rr = len / 2
		if onX then oriented(name, rr * math.cos(phi), sgn * rr * math.sin(phi), 0.3, len, w, phiDeg * sgn, DARK, 1.5)
		else oriented(name, rr * math.cos(phi), sgn * rr * math.sin(phi), w, len, 0.3, -phiDeg * sgn, DARK, 1.5) end
	end
	hand("Uhrzeiger", -60, R * 0.55, 0.9) -- Stundenzeiger auf 10
	hand("Uhrzeiger", 60, R * 0.8, 0.6) -- Minutenzeiger auf 2
	local nums = { { "XII", 0 }, { "III", 90 }, { "VI", 180 }, { "IX", 270 } }
	for _, nm in ipairs(nums) do
		local phi = math.rad(nm[2])
		local rr = R - 4.4
		local px, py, pz = pos(rr * math.cos(phi), sgn * rr * math.sin(phi))
		add("Uhrziffer", px + nx * 1.2, py, pz + nz * 1.2, 3.2, 2, 0.2, DARK, "SmoothPlastic", { yaw = yaw, kind = "text", collide = false, text = { s = nm[1], color = DARK } })
	end
	add("UhrGold", x + nx * 1.7, y, z + nz * 1.7, 1.4, 1.4, 1.4, GOLD, "Metal", { shape = "Ball", collide = false })
end

local function onion(add, x, y, z, color)
	local GOLD = { 214, 176, 70 }
	local H, N = 43, 27
	local function radius(h)
		if h <= 11 then return 19 + 10 * math.sin(math.pi / 2 * h / 11) end
		local u = (h - 11) / (H - 11)
		return 3 + 26 * math.cos(math.pi / 2 * u) ^ 2.2
	end
	for i = 0, N do
		local h = H * i / N
		local d = 2 * radius(h)
		add(i == 7 and "Kuppel" or "KuppelRing", x, y + 1 + h, z, H / N + 0.5, d, d, color, "Metal", { shape = "Cylinder", roll = 90, collide = true })
	end
	add("Laterne", x, y + 49, z, 10, 8, 8, color, "Metal", { shape = "Cylinder", roll = 90, collide = true })
	add("Laternenkappe", x, y + 56, z, 8, 8, 8, color, "Metal", { shape = "Ball", collide = false })
	add("Spitze", x, y + 62, z, 3.4, 3.4, 3.4, GOLD, "Metal", { shape = "Ball", collide = false })
	add("Kreuz", x, y + 70, z, 1.2, 14, 1.2, GOLD, "Metal", { collide = false })
	add("Kreuz", x, y + 72, z, 6, 1.2, 1.2, GOLD, "Metal", { collide = false })
end

function Landmarks.frauenkirche(cfg)
	local parts = {}
	local L = cfg.landmarks.frauenkirche
	local cxn = (L.x0 + L.x1) / 2
	local add = new(parts, cxn, L.z)
	local y0 = L.baseY
	local BRICK, BRICK2, BAND, ROOF, GREEN = { 150, 112, 88 }, { 138, 100, 78 }, { 196, 172, 142 }, { 196, 84, 48 }, { 96, 160, 140 }
	local len, hw, wallH, rise, H = L.x1 - L.x0, L.width / 2, L.wallH, L.roofRise, L.towerH
	add("Sockel", 0, y0 + 1.5, 0, len + 10, 3, 2 * hw + 10, { 150, 148, 142 }, "Concrete")
	local yb = y0 + 3
	add("Schiff", 0, yb + wallH / 2, 0, len, wallH, 2 * hw, BRICK, "Brick", { collide = true })
	add("Gesims", 0, yb + wallH + 1, 0, len + 3, 2, 2 * hw + 3, BAND, "Concrete")
	add("Sockelband", 0, yb + 2, 0, len + 2, 4, 2 * hw + 2, { 128, 120, 112 }, "Concrete")
	local first = -len / 2 + 70
	local n = math.floor((len / 2 - 20 - first) / 22) + 1
	for i = 0, n - 1 do
		local wx = first + i * 22
		for _, sd in ipairs({ -1, 1 }) do
			local zz = sd * (hw + 0.4)
			add("FensterGewaende", wx, yb + 33, sd * (hw + 0.15), 11.4, 50, 0.4, BAND, "Concrete", { collide = false })
			add("Fenster", wx, yb + 31, zz, 8, 44, 0.8, { 50, 62, 78 }, "Glass", { collide = false, kind = "glass", tag = "HouseWindow" })
			add("FensterBogen", wx, yb + 55, zz, 6, 6, 0.8, { 50, 62, 78 }, "Glass", { collide = false, kind = "glass" })
			add("FensterSpitze", wx, yb + 60, zz, 3.4, 5, 0.8, { 50, 62, 78 }, "Glass", { collide = false, kind = "glass" })
			add("Sohlbank", wx, yb + 8.2, sd * (hw + 0.9), 12.4, 1, 1.8, BAND, "Concrete", { collide = false })
			add("Strebepfeiler", wx + 11, yb + wallH / 2, sd * (hw + 2), 4, wallH, 4, BAND, "Concrete", { collide = true })
			add("StrebepfeilerKappe", wx + 11, yb + wallH + 2, sd * (hw + 2), 5, 4, 5, { 176, 150, 124 }, "Concrete")
		end
	end
	local run = hw + 3
	local slope = math.sqrt(run * run + rise * rise)
	local ang = math.deg(math.atan2(rise, run))
	local ca, sa = math.cos(math.rad(ang)), math.sin(math.rad(ang))
	local roofY = yb + wallH + rise / 2 + 2
	for _, sd in ipairs({ -1, 1 }) do
		add("Dach", 0, roofY, sd * run / 2, len + 6, 1.6, slope, ROOF, "Slate", { pitch = sd * ang })
		for xr = -len / 2, len / 2, 9 do -- Ziegelreihen (dunkler, längs der Neigung)
			local off = 1.0
			add("Dachrippe", xr, roofY + off * ca, sd * run / 2 + sd * off * sa, 1, 0.5, slope - 1, { 150, 62, 38 }, "Slate", { pitch = sd * ang, collide = false })
		end
		for k = 1, 10 do -- Gauben auf halber Dachhöhe
			local gx = -len / 2 + 30 + (k - 1) * (len - 60) / 9
			local u = 0.5
			local gy = (yb + wallH + 2) + u * rise
			local gz = sd * run * (1 - u)
			add("Gaube", gx, gy + 2, gz, 6, 6, 5, { 168, 140, 116 }, "Concrete", { collide = true })
			add("GaubeFenster", gx, gy + 2, gz + sd * 2.6, 3.4, 3.8, 0.3, { 50, 62, 78 }, "Glass", { collide = false, kind = "glass" })
			add("GaubeDach", gx, gy + 5.4, gz, 7.4, 0.8, 6.4, { 120, 56, 36 }, "Slate")
		end
	end
	add("First", 0, yb + wallH + rise + 3, 0, len + 6, 1.6, 3, { 170, 70, 40 }, "Slate")
	local steps = 12
	for k = 1, steps do
		add("Giebel", len / 2 - 0.8, yb + wallH + (k - 0.5) * rise / steps + 2, 0, 1.6, rise / steps, 2 * hw * (1 - (k - 1) / steps), BRICK, "Brick", { collide = true })
	end
	add("Chorrosette", len / 2 + 0.2, yb + wallH + 22, 0, 0.6, 18, 18, { 70, 86, 110 }, "Glass", { shape = "Cylinder", collide = false, kind = "glass" })
	local tw, tx = 48, -len / 2 + 24
	local H1 = 110
	for _, sd in ipairs({ -1, 1 }) do
		local tz = sd * (hw - tw / 2)
		add("Turm", tx, yb + H1 / 2, tz, tw, H1, tw, BRICK2, "Brick", { collide = true })
		for _, cxx in ipairs({ -tw / 2 + 1.5, tw / 2 - 1.5 }) do
			for _, czz in ipairs({ -tw / 2 + 1.5, tw / 2 - 1.5 }) do add("TurmEcke", tx + cxx, yb + H / 2, tz + czz, 3, H, 3, BAND, "Concrete") end
		end
		for k = 1, 4 do add("TurmBand", tx, yb + k * 22, tz, tw + 1.6, 2, tw + 1.6, BAND, "Concrete") end
		add("TurmAbsatz", tx, yb + H1 + 1.5, tz, tw + 4, 3, tw + 4, BAND, "Concrete", { collide = true })
		local tw2 = 42
		add("Turm", tx, yb + H1 + 3 + (H - H1 - 3) / 2, tz, tw2, H - H1 - 3, tw2, BRICK, "Brick", { collide = true })
		for k = 1, 3 do add("TurmBand", tx, yb + H1 + 3 + k * 26, tz, tw2 + 1.6, 2, tw2 + 1.6, BAND, "Concrete") end
		for _, yy in ipairs({ 40, 80 }) do -- Fensterschlitze im Untergeschoss
			add("Turmfenster", tx - tw / 2 - 0.3, yb + yy, tz, 0.8, 18, 5, { 40, 44, 52 }, "Glass", { collide = false, kind = "glass" })
			add("Turmfenster", tx, yb + yy, tz + sd * (tw / 2 + 0.3), 5, 18, 0.8, { 40, 44, 52 }, "Glass", { collide = false, kind = "glass" })
		end
		local by = yb + H - 26
		for _, o in ipairs({ -8, 8 }) do
			add("Schallloch", tx - tw2 / 2 - 0.3, by, tz + o, 0.8, 30, 8, { 30, 32, 38 }, "Glass", { collide = false, kind = "glass" })
			add("SchallBogen", tx - tw2 / 2 - 0.3, by + 17, tz + o, 0.8, 6, 5, { 30, 32, 38 }, "Glass", { collide = false, kind = "glass" })
			add("Schallloch", tx + o, by, tz + sd * (tw2 / 2 + 0.3), 8, 30, 0.8, { 30, 32, 38 }, "Glass", { collide = false, kind = "glass" })
			add("SchallBogen", tx + o, by + 17, tz + sd * (tw2 / 2 + 0.3), 5, 6, 0.8, { 30, 32, 38 }, "Glass", { collide = false, kind = "glass" })
		end
		clock(add, tx - tw2 / 2, yb + H - 70, tz, 11, "W")
		clock(add, tx, yb + H - 70, tz + sd * (tw2 / 2), 11, sd < 0 and "N" or "S")
		local oct = 34
		add("Achteck", tx, yb + H + 11, tz, oct, 22, oct, BRICK2, "Brick", { collide = true })
		add("Achteck", tx, yb + H + 11.02, tz, oct, 22, oct, BRICK2, "Brick", { collide = true, yaw = 45 })
		add("AchteckBand", tx, yb + H + 22.5, tz, oct + 6, 1.4, oct + 6, BAND, "Concrete", { collide = true })
		for _, o in ipairs({ 0 }) do
			add("AchteckBogen", tx - oct / 2 - 0.3, yb + H + 11, tz, 0.8, 12, 5, { 30, 32, 38 }, "Glass", { collide = false, kind = "glass" })
			add("AchteckBogen", tx, yb + H + 11, tz + sd * (oct / 2 + 0.3), 5, 12, 0.8, { 30, 32, 38 }, "Glass", { collide = false, kind = "glass" })
		end
		onion(add, tx, yb + H + 23, tz, GREEN)
	end
	add("Portal", -len / 2 - 0.4, yb + 14, 0, 1, 28, 14, { 56, 40, 32 }, "Wood", { collide = false })
	add("PortalRahmen", -len / 2 - 0.8, yb + 15, 0, 0.8, 32, 20, BAND, "Concrete", { collide = false })
	add("PortalSpitze", -len / 2 - 0.8, yb + 33, 0, 0.8, 8, 10, BAND, "Concrete", { collide = false })
	for i = 1, 4 do add("PortalStufe", -len / 2 - 2 - i * 2, yb - 0.4 - i * 0.2, 0, 3, 0.8, 24 + i * 2, { 160, 156, 148 }, "Concrete", { collide = true }) end
	add("Westrosette", -len / 2 - 0.5, yb + 56, 0, 0.8, 20, 20, { 70, 86, 110 }, "Glass", { shape = "Cylinder", collide = false, kind = "glass" })
	add("WestrosetteRand", -len / 2 - 0.3, yb + 56, 0, 0.6, 24, 24, BAND, "Concrete", { shape = "Cylinder", collide = false })
	return parts
end

function Landmarks.chinesischerTurm(cfg)
	local parts = {}
	local L = cfg.landmarks.turm
	local add = new(parts, L.x, L.z)
	local y = L.baseY
	local WOOD, ROOFC, GOLD = { 142, 100, 62 }, { 66, 88, 70 }, { 214, 176, 70 }
	local function disc(name, yy, dia, h, color, mat, collide)
		add(name, 0, yy, 0, h, dia, dia, color, mat, { shape = "Cylinder", roll = 90, collide = collide })
	end
	disc("TurmSockel", y + 0.6, 24, 1.2, { 150, 148, 142 }, "Concrete", true)
	y = y + 1.2
	disc("TurmKern", y + 4, 9, 8, WOOD, "Wood", true)
	for i = 1, 8 do -- Säulenumgang
		local a = 2 * math.pi * (i - 1) / 8
		add("TurmSaeule", 6.4 * math.cos(a), y + 4, 6.4 * math.sin(a), 0.9, 8, 0.9, { 120, 80, 50 }, "Wood", { collide = true })
	end
	y = y + 8
	local tiers = { { 22, 8 }, { 18, 7 }, { 15, 6 }, { 12, 5 }, { 9, 4 } } -- Dachdurchmesser, Kerndurchmesser
	for i, t in ipairs(tiers) do
		disc("TurmDachRand", y + 0.3, t[1], 0.6, ROOFC, "Metal", true)
		disc("TurmDach", y + 1.2, t[1] - 5, 1.2, ROOFC, "Metal", true)
		y = y + 1.8
		if i < #tiers then
			disc("TurmGeschoss", y + 2.5, t[2], 5, WOOD, "Wood", true)
			disc("TurmBruestung", y + 4.6, t[2] + 1.4, 0.8, { 120, 80, 50 }, "Wood")
			y = y + 5
		end
	end
	add("TurmSpitze", 0, y + 3.5, 0, 0.7, 7, 0.7, GOLD, "Metal", { collide = false })
	add("TurmKugel", 0, y + 2, 0, 2.2, 2.2, 2.2, GOLD, "Metal", { shape = "Ball", collide = false })
	return parts
end

function Landmarks.plan(cfg)
	local parts = {}
	for _, list in ipairs({ Landmarks.siegestorInsel(cfg), Landmarks.siegestor(cfg), Landmarks.friedensengel(cfg), Landmarks.frauenkirche(cfg), Landmarks.chinesischerTurm(cfg) }) do
		for _, p in ipairs(list) do parts[#parts + 1] = p end
	end
	return { parts = parts }
end

return Landmarks

end)()

local Ampel = (function()

local Ampel = {}

Ampel.config = {
	green = 30, -- Sekunden grün je Richtung
	yellow = 3,
	clear = 2, -- alle rot, bevor die andere Richtung grün bekommt
	pedGreen = 12,
	pedRed = 28,
}

local ON = { Red = { 235, 40, 40 }, Yellow = { 255, 190, 30 }, Green = { 60, 220, 90 } }
local DIM = { Red = { 90, 20, 20 }, Yellow = { 100, 74, 12 }, Green = { 20, 80, 36 } }

function Ampel.junction(c, t)
	local phases = {
		{ c.green, "Green", "Red" }, { c.yellow, "Yellow", "Red" }, { c.clear, "Red", "Red" },
		{ c.green, "Red", "Green" }, { c.yellow, "Red", "Yellow" }, { c.clear, "Red", "Red" },
	}
	local cycle = 0
	for _, p in ipairs(phases) do cycle = cycle + p[1] end
	t = t % cycle
	for _, p in ipairs(phases) do
		if t < p[1] then return p[2], p[3] end
		t = t - p[1]
	end
	return "Red", "Red"
end

function Ampel.wache(c, state, alarm, t)
	if alarm and state.mode == "Green" then state.mode, state.since = "Yellow", t end
	if state.mode == "Yellow" and t - state.since >= c.yellow then state.mode, state.since = "Red", t end
	if not alarm and state.mode ~= "Green" and t - state.since >= 1 then state.mode, state.since = "Green", t end
	return state.mode
end

function Ampel.ped(c, t)
	return (t % (c.pedGreen + c.pedRed)) < c.pedGreen and "Green" or "Red"
end

local function setLamp(part, on, name)
	if part:GetAttribute("Lit") == on then return end
	part:SetAttribute("Lit", on)
	part.Material = on and Enum.Material.Neon or Enum.Material.SmoothPlastic
	local col = (on and ON or DIM)[name]
	part.Color = Color3.fromRGB(col[1], col[2], col[3])
end

function Ampel.start()
	local CollectionService = game:GetService("CollectionService")
	local Workspace = game:GetService("Workspace")
	local groups = {} -- name -> { lamps = { NS = { Red = {parts} ...}, EW = ... }, wache = state | nil, offset }
	local n = 0
	local function collect(tag)
		for _, part in ipairs(CollectionService:GetTagged(tag)) do
			local name, axis, lamp = part:GetAttribute("Group"), part:GetAttribute("Axis"), part:GetAttribute("Lamp")
			if name and axis and lamp then
				local g = groups[name]
				if not g then
					n = n + 1
					g = { lamps = { NS = {}, EW = {} }, ped = tag == "PedLight", wache = string.sub(name, 1, 6) == "Wache_" and { mode = "Green", since = 0 } or nil, offset = n * 7 }
					groups[name] = g
				end
				local list = g.lamps[axis][lamp] or {}
				g.lamps[axis][lamp] = list
				list[#list + 1] = part
			end
		end
	end
	collect("TrafficLight")
	collect("PedLight")
	local function show(g, axis, color)
		for name, list in pairs(g.lamps[axis]) do
			for _, part in ipairs(list) do setLamp(part, name == color, name) end
		end
	end
	task.spawn(function()
		while true do
			local t = os.clock()
			local alarm = Workspace:GetAttribute("WacheAlarm") == true
			for _, g in pairs(groups) do
				if g.ped then
					local c = Ampel.ped(Ampel.config, t)
					show(g, "EW", c)
				elseif g.wache then
					local c = Ampel.wache(Ampel.config, g.wache, alarm, t)
					show(g, "NS", c)
					show(g, "EW", "Red")
				else
					local ns, ew = Ampel.junction(Ampel.config, t + g.offset)
					show(g, "NS", ns)
					show(g, "EW", ew)
				end
			end
			task.wait(0.25)
		end
	end)
end

return Ampel

end)()

local TerrainPlanner = (function()

local Geo = Geo

local TerrainPlanner = {}

local function block(ops, material, x, y, z, sx, sy, sz, tag)
	ops[#ops + 1] = { op = "block", material = material, pos = { Geo.round3(x), Geo.round3(y), Geo.round3(z) }, size = { Geo.round3(sx), Geo.round3(sy), Geo.round3(sz) }, yaw = 0, tag = tag }
end

local STEP = 8
function TerrainPlanner.riverSamples(pts)
	local out = {}
	for i = 1, #pts - 1 do
		local ux, uz, l = Geo.dir(pts[i][1], pts[i][2], pts[i + 1][1], pts[i + 1][2])
		local n = math.max(1, math.ceil(l / STEP))
		for k = 0, n - 1 do
			local t = (k + 0.5) * l / n
			out[#out + 1] = { x = pts[i][1] + ux * t, z = pts[i][2] + uz * t, ux = ux, uz = uz, len = l / n }
		end
	end
	return out
end

local function river(ops, rv)
	local samples = TerrainPlanner.riverSamples(rv.pts)
	for _, f in ipairs(rv.fills or {}) do
		for _, sm in ipairs(samples) do
			local alongZ = math.abs(sm.uz) >= math.abs(sm.ux)
			local sx, sz
			if alongZ then sx, sz = 2 * f[3] / math.abs(sm.uz), STEP + 2 else sx, sz = STEP + 2, 2 * f[3] / math.abs(sm.ux) end
			block(ops, f[4], sm.x, (f[1] + f[2]) / 2, sm.z, sx, f[2] - f[1], sz, rv.name .. "_fill")
		end
	end
	for pass = 1, 2 do -- 1 = ausheben, 2 = fluten
		for li, ly in ipairs(rv.layers) do
			local top, bot, hw = ly[1], ly[2], ly[3]
			if pass == 1 and li == 1 then top = 6 end -- oberste Schicht nach oben verlängern, damit keine Zellen als Deckel stehen bleiben
			if pass == 1 or ly[1] <= rv.waterTop then
				for _, sm in ipairs(samples) do
					local alongZ = math.abs(sm.uz) >= math.abs(sm.ux)
					local sx, sz
					if alongZ then
						sx, sz = 2 * hw / math.abs(sm.uz), STEP + 2
					else
						sx, sz = STEP + 2, 2 * hw / math.abs(sm.ux)
					end
					block(ops, pass == 1 and "Air" or "Water", sm.x, (top + bot) / 2, sm.z, sx, top - bot, sz, rv.name)
				end
			end
		end
	end
end

function TerrainPlanner.plan(cfg)
	local ops = {}
	local G = cfg.groundTop
	local m, depth, tile = cfg.map, 20, 512
	local x = m.xmin
	while x < m.xmax do
		local w = math.min(tile, m.xmax - x)
		local z = m.zmin
		while z < m.zmax do
			local d = math.min(tile, m.zmax - z)
			block(ops, "Pavement", x + w / 2, G - depth / 2, z + d / 2, w, depth, d)
			z = z + d
		end
		x = x + w
	end
	for _, p in ipairs(cfg.parks) do
		block(ops, "Grass", (p.x0 + p.x1) / 2, G - 2, (p.z0 + p.z1) / 2, p.x1 - p.x0, 4, p.z1 - p.z0)
	end
	for _, h in ipairs(cfg.hills) do
		for _, ly in ipairs(h.layers) do
			ops[#ops + 1] = { op = "cylinder", material = "Grass", pos = { h.x, G + (ly[2] + ly[3]) / 2, h.z }, height = ly[3] - ly[2], radius = ly[1] }
		end
	end
	local t = cfg.terrace
	block(ops, "Grass", (t.x0 + t.x1) / 2, G + t.height / 2, (t.z0 + t.z1) / 2, t.x1 - t.x0, t.height, t.z1 - t.z0)
	cfg.water.isar.name, cfg.water.bach.name = "isar", "bach"
	river(ops, cfg.water.isar)
	river(ops, cfg.water.bach)
	return ops
end

return TerrainPlanner

end)()

local Garden = (function()

local Geo = Geo
local TerrainPlanner = TerrainPlanner

local Garden = {}

local GRAVEL, STONE, SAND = { 206, 196, 172 }, { 206, 200, 186 }, { 214, 200, 168 }
local BARK = { 96, 70, 48 }
local GREENS = { { 70, 120, 60 }, { 88, 140, 70 }, { 56, 100, 56 }, { 104, 150, 76 }, { 64, 112, 80 } }
local HEDGE = { 46, 92, 52 }

local function newRng(seed)
	local s = seed % 2147483647
	if s <= 0 then s = s + 2147483646 end
	return function()
		s = (s * 48271) % 2147483647
		return s / 2147483647
	end
end

local function emitter(parts)
	return function(name, kind, x, y, z, sx, sy, sz, color, material, extra)
		extra = extra or {}
		parts[#parts + 1] = {
			name = name, kind = kind, size = { Geo.round3(sx), Geo.round3(sy), Geo.round3(sz) }, pos = { Geo.round3(x), Geo.round3(y), Geo.round3(z) },
			yaw = Geo.round3(extra.yaw or 0), pitch = extra.pitch or 0, roll = extra.roll, color = color, material = material, collide = extra.collide == true,
			shape = extra.shape, text = extra.text, transparency = extra.transparency, tag = extra.tag, attrs = extra.attrs,
		}
	end
end

local function groundY(cfg, x, z)
	for _, h in ipairs(cfg.hills) do
		local d, y = math.sqrt((x - h.x) ^ 2 + (z - h.z) ^ 2), 0
		for _, ly in ipairs(h.layers) do
			if d < ly[1] then y = ly[3] end
		end
		if y > 0 then return y end
	end
	local t = cfg.terrace
	if x >= t.x0 and x <= t.x1 and z >= t.z0 and z <= t.z1 then return t.height end
	local d, y = Geo.polyDist(x, z, cfg.water.isar.pts), 0
	for _, ly in ipairs(cfg.water.isar.layers) do
		if d < ly[3] then y = ly[2] end
	end
	return y
end

local function inRoad(segs, x, z, m)
	for _, s in ipairs(segs) do
		local r = s.rect
		local dx, dz = x - r.ax, z - r.az
		local a, b = dx * r.ux + dz * r.uz, dx * r.nx + dz * r.nz
		if a > r.s0 - m and a < r.s1 + m and math.abs(b) < r.w + m then return true end
	end
	return false
end

local function tree(add, rng, x, y, z, scale, prefix)
	prefix = prefix or ""
	local h = (6 + 5 * rng()) * scale
	local cw = (9 + 6 * rng()) * scale
	local g = GREENS[math.floor(rng() * #GREENS) + 1]
	add(prefix .. "Stamm", "tree", x, y + h / 2, z, 1.4, h, 1.4, BARK, "Wood", { collide = true })
	add(prefix .. "Krone", "tree", x, y + h + cw * 0.35, z, cw, cw, cw, g, "Grass", { shape = "Ball" })
	if rng() < 0.6 then
		add(prefix .. "Krone", "tree", x + (rng() - 0.5) * 4, y + h + cw * 0.15, z + (rng() - 0.5) * 4, cw * 0.75, cw * 0.75, cw * 0.75, GREENS[math.floor(rng() * #GREENS) + 1], "Grass", { shape = "Ball" })
	end
end

local function bench(add, x, y, z, yaw)
	local r = math.rad(yaw)
	local nx, nz = math.sin(r), math.cos(r) -- lokale z-Richtung
	add("BankSitz", "bench", x, y + 1.3, z, 4.4, 0.4, 1.5, { 130, 90, 60 }, "Wood", { yaw = yaw, collide = true })
	add("BankLehne", "bench", x + nx * 0.7, y + 2.3, z + nz * 0.7, 4.4, 1.2, 0.3, { 130, 90, 60 }, "Wood", { yaw = yaw })
	for _, sd in ipairs({ -1.8, 1.8 }) do
		add("BankBein", "bench", x + math.cos(r) * sd, y + 0.65, z - math.sin(r) * sd, 0.4, 1.3, 1.2, { 60, 62, 66 }, "Metal", { yaw = yaw })
	end
end

local function strip(add, name, x0, z0, x1, z1, w, base, lift, color, material)
	local ux, uz, len = Geo.dir(x0, z0, x1, z1)
	add(name, "path", (x0 + x1) / 2, base + 0.15 + lift - 0.25, (z0 + z1) / 2, len, 0.5, w, color, material or "Pavement", { yaw = Geo.yawOf(ux, uz) })
end

local function disc(add, name, x, y, z, dia, h, color, material, extra)
	extra = extra or {}
	extra.shape, extra.roll = "Cylinder", 90
	add(name, "decor", x, y, z, h, dia, dia, color, material, extra)
end

local function pavilion(add, x, base, z, columns, radius, colHeight, dome)
	disc(add, "TempelSockel", x, base - 1, z, radius * 2 + 9, 3, STONE, "Concrete", { collide = true }) -- Fundament gegen Lücken zum Gelände
	disc(add, "TempelStufe", x, base + 0.5, z, radius * 2 + 9, 1, STONE, "Concrete", { collide = true })
	disc(add, "TempelStufe", x, base + 1.5, z, radius * 2 + 4, 1, STONE, "Concrete", { collide = true })
	disc(add, "TempelBoden", x, base + 2.3, z, radius * 2 + 1, 0.6, { 226, 220, 206 }, "Marble", { collide = true })
	local y0 = base + 2.6
	for i = 1, columns do
		local a = 2 * math.pi * (i - 1) / columns
		local cx, cz = x + radius * math.cos(a), z + radius * math.sin(a)
		add("Saeule", "decor", cx, y0 + colHeight / 2, cz, 1.9, colHeight, 1.9, { 232, 226, 212 }, "Concrete", { collide = true })
		add("SaeuleKapitell", "decor", cx, y0 + colHeight + 0.4, cz, 3, 0.8, 3, { 214, 206, 190 }, "Concrete")
	end
	disc(add, "Gebaelk", x, y0 + colHeight + 1.6, z, radius * 2 + 4, 1.6, STONE, "Concrete", { collide = true })
	disc(add, "TempelDach", x, y0 + colHeight + 2.8, z, radius * 2 + 6, 0.8, { 150, 160, 150 }, "Metal", { collide = true })
	if dome then add("Kuppel", "decor", x, y0 + colHeight + 3.2, z, dome, dome, dome, { 150, 160, 150 }, "Metal", { shape = "Ball", collide = true }) end
end

local function fountain(add, x, z, r)
	disc(add, "Brunnenbecken", x, 0.7, z, r * 2, 1.4, STONE, "Concrete", { collide = true })
	disc(add, "Brunnenwasser", x, 1.15, z, r * 2 - 3, 0.4, { 120, 170, 210 }, "SmoothPlastic", { transparency = 0.45 })
	disc(add, "Brunnenschale", x, 2.4, z, 2.4, 4.8, STONE, "Concrete", { collide = true })
	add("Brunnenstrahl", "decor", x, 6.2, z, 0.9, 7, 0.9, { 240, 248, 255 }, "SmoothPlastic", { transparency = 0.5 })
end

local function hofgarten(cfg, add, rng, free)
	local p
	for _, q in ipairs(cfg.parks) do if q.name == "Hofgarten" then p = q end end
	local cx, cz = (p.x0 + p.x1) / 2, (p.z0 + p.z1) / 2
	strip(add, "WegHof", p.x0 + 6, cz, p.x1 - 6, cz, 8, 0, 0, GRAVEL)
	strip(add, "WegHof", cx, p.z0 + 8, cx, p.z1 - 6, 8, 0, 0.04, GRAVEL)
	strip(add, "WegHof", p.x0 + 8, p.z0 + 16, p.x0 + 8, p.z1 - 16, 5, 0, 0.02, GRAVEL)
	strip(add, "WegHof", p.x1 - 8, p.z0 + 16, p.x1 - 8, p.z1 - 16, 5, 0, 0.02, GRAVEL)
	disc(add, "Hofplatz", cx, 0.1, cz, 44, 0.5, SAND, "Pavement")
	pavilion(add, cx, 0.35, cz, 8, 9, 10, 17)
	local fx = { p.x0 + (cx - p.x0) / 2, cx + (p.x1 - cx) / 2 }
	for _, x in ipairs(fx) do
		disc(add, "Brunnenplatz", x, 0.1, cz, 26, 0.5, SAND, "Pavement")
		fountain(add, x, cz, 10)
	end
	local colors = { { 200, 60, 70 }, { 240, 200, 60 }, { 150, 80, 170 }, { 240, 240, 236 } }
	local k = 0
	for _, qx in ipairs({ -1, 1 }) do
		for _, qz in ipairs({ -1, 1 }) do
			for i = 0, 2 do
				for j = 0, 1 do
					k = k + 1
					add("Beet", "decor", cx + qx * (40 + i * 20), 0.3, cz + qz * (26 + j * 14), 16, 0.6, 10, colors[(k % 4) + 1], "Grass")
				end
			end
		end
	end
	for x = p.x0 + 24, p.x1 - 24, 16 do
		if math.abs(x - cx) > 30 and math.abs(x - fx[1]) > 18 and math.abs(x - fx[2]) > 18 then
			for _, sd in ipairs({ -1, 1 }) do add("Hecke", "decor", x, 1.2, cz + sd * 7.5, 14, 2.4, 1.6, HEDGE, "Grass", { collide = true }) end
		end
	end
	add("ArkadenWand", "decor", cx, 4.5, p.z0 - 0.5, p.x1 - p.x0 - 20, 9, 1, { 214, 196, 160 }, "Concrete", { collide = true })
	for x = p.x0 + 10, p.x1 - 10, 10 do add("ArkadenSaeule", "decor", x, 4.5, p.z0 + 3, 1.8, 9, 1.8, { 226, 214, 184 }, "Concrete", { collide = true }) end
	add("ArkadenDach", "decor", cx, 9.4, p.z0 + 1.5, p.x1 - p.x0 - 20, 0.8, 7, { 170, 90, 70 }, "Concrete", { collide = true })
	for x = p.x0 + 36, p.x1 - 36, 44 do
		if math.abs(x - cx) > 34 and math.abs(x - fx[1]) > 20 and math.abs(x - fx[2]) > 20 then
			bench(add, x, 0, cz - 6, 180)
			bench(add, x, 0, cz + 6, 0)
		end
	end
	local n = 0
	for x = p.x0 + 14, p.x1 - 14, 26 do
		for z = p.z0 + 18, p.z1 - 12, 26 do
			local tx, tz = x + (rng() - 0.5) * 10, z + (rng() - 0.5) * 10
			local nearAxis = math.abs(tz - cz) < 14 or math.abs(tx - cx) < 12
			local nearFountain = math.abs(tz - cz) < 20 and (math.abs(tx - fx[1]) < 18 or math.abs(tx - fx[2]) < 18)
			local nearBed = (math.abs(tx - cx) > 28 and math.abs(tx - cx) < 106 and math.abs(tz - cz) > 14 and math.abs(tz - cz) < 56)
			local nearEdge = tx < p.x0 + 14 or tx > p.x1 - 14
			if not nearAxis and not nearFountain and not nearBed and not nearEdge and rng() < 0.55 and free(tx, tz) then
				tree(add, rng, tx, 0, tz, 1)
				n = n + 1
			end
		end
	end
	for z = p.z0 + 24, p.z1 - 24, 20 do
		for _, x in ipairs({ p.x0 + 16, p.x1 - 16 }) do
			if free(x, z) then tree(add, rng, x, 0, z, 0.9) n = n + 1 end
		end
	end
	return n
end

local function monopteros(cfg, add)
	local h = cfg.hills[1]
	pavilion(add, h.x, 8, h.z, 9, 11, 12, nil)
	strip(add, "WegMonopteros", h.x - 70, h.z, h.x - 44, h.z, 7, 0, 0.06, GRAVEL)
	strip(add, "WegMonopteros", h.x - 44, h.z, h.x - 30, h.z, 7, 4, 0.06, GRAVEL)
	strip(add, "WegMonopteros", h.x - 30, h.z, h.x - 17, h.z, 7, 8, 0.06, GRAVEL)
	for i = 0, 3 do add("AufgangStufe", "decor", h.x - 44 + i * 0.8, 0.5 + i, h.z, 1, 1, 10, STONE, "Concrete", { collide = true }) end -- Treppe zur oberen Terrasse
	for i = 0, 2 do add("AufgangStufe", "decor", h.x - 30 + i * 0.8, 4.5 + i, h.z, 1, 1, 10, STONE, "Concrete", { collide = true }) end
end

local function englischerGarten(cfg, add, rng, free)
	local p
	for _, q in ipairs(cfg.parks) do if q.name == "EnglischerGarten" then p = q end end
	local h = cfg.hills[1]
	strip(add, "WegEG", 520, p.z0 + 10, 520, p.z1 - 10, 8, 0, 0, GRAVEL)
	strip(add, "WegEG", p.x0 + 8, h.z, h.x - 70, h.z, 6, 0, 0.02, GRAVEL)
	strip(add, "WegEG", 520, 270, p.x1 - 60, 270, 6, 0, 0.02, GRAVEL)
	local bs = TerrainPlanner.riverSamples(cfg.water.bach.pts)
	for i = 1, #bs, 2 do
		local s = bs[i]
		if s.z > p.z0 + 8 and s.z < p.z1 - 8 then
			local nx, nz = -s.uz, s.ux
			local x, z = s.x + nx * 20, s.z + nz * 20
			if free(x, z) then add("WegBach", "path", x, 0.1, z, 17, 0.5, 4, SAND, "Pavement", { yaw = Geo.yawOf(s.ux, s.uz) }) end
		end
	end
	for _, z in ipairs({ p.z0 + 60, 140, 200, 240 }) do
		bench(add, 513, 0, z, 270)
		bench(add, 527, 0, z, 90)
	end
	local n = 0
	for x = p.x0 + 8, p.x1 - 8, 17 do
		for z = p.z0 + 8, p.z1 - 8, 17 do
			local tx, tz = x + (rng() - 0.5) * 10, z + (rng() - 0.5) * 10
			local dh = math.sqrt((tx - h.x) ^ 2 + (tz - h.z) ^ 2)
			local dr = Geo.polyDist(tx, tz, cfg.water.isar.pts)
			local pr = 0.55
			if dh < 80 then pr = 0.08 elseif dr < 130 then pr = 0.3 end
			local onPath = math.abs(tx - 520) < 9 or (math.abs(tz - h.z) < 8 and tx < h.x - 40) or (math.abs(tz - 270) < 8 and tx > 520 and tx < p.x1 - 55)
			if not onPath and dr > 100 and Geo.polyDist(tx, tz, cfg.water.bach.pts) > 24 and rng() < pr and free(tx, tz) then
				tree(add, rng, tx, groundY(cfg, tx, tz), tz, 1 + rng() * 0.3)
				n = n + 1
			end
		end
	end
	return n
end

local function isarBank(cfg, add, rng, bridges)
	local rv = cfg.water.isar
	local samples = TerrainPlanner.riverSamples(rv.pts)
	local ledge = rv.layers[1][3] - 15 -- Mitte der Uferstufe
	local shelf = (rv.layers[2][3] + rv.layers[3][3]) / 2
	local n = { slabs = 0, benches = 0, bushes = 0, rocks = 0 }
	local function underBridge(x, z)
		for _, b in ipairs(bridges) do
			local r = math.rad(b.yaw)
			local ux, uz = math.cos(r), -math.sin(r)
			local dx, dz = x - b.x, z - b.z
			if math.abs(dx * ux + dz * uz) < b.len / 2 and math.abs(-dx * uz + dz * ux) < b.wid / 2 + b.walk + 8 then return true end
		end
		return false
	end
	for i, sm in ipairs(samples) do
		if sm.z > -440 and sm.z < 470 then
			for _, side in ipairs({ 1, -1 }) do
				local nx, nz = -sm.uz * side, sm.ux * side
				local lx, lz = sm.x + nx * ledge, sm.z + nz * ledge
				if not underBridge(lx, lz) then
					if i % 2 == 0 then
						add("Uferweg", "path", lx, -3.9, lz, 17.5, 0.4, 6, GRAVEL, "Pavement", { yaw = Geo.yawOf(sm.ux, sm.uz) })
						n.slabs = n.slabs + 1
					end
					if i % 11 == 0 then
						bench(add, lx + nx * 4, -4, lz + nz * 4, math.deg(math.atan2(nx, nz)))
						n.benches = n.benches + 1
					end
					if i % 2 == 1 and rng() < 0.5 then
						local d = 5 + rng() * 2
						add("Busch", "bush", sm.x + nx * (ledge + 12), -4 + d / 2 - 0.4, sm.z + nz * (ledge + 12), d, d, d, GREENS[math.floor(rng() * #GREENS) + 1], "Grass", { shape = "Ball" })
						n.bushes = n.bushes + 1
					end
				end
				if rng() < 0.2 and not underBridge(sm.x + nx * shelf, sm.z + nz * shelf) then
					local sx, sy, sz = 3 + rng() * 4, 1.5 + rng() * 1.5, 3 + rng() * 3
					add("Findling", "rock", sm.x + nx * (shelf + (rng() - 0.5) * 12), -8 + sy / 2 - 0.3, sm.z + nz * (shelf + (rng() - 0.5) * 12), sx, sy, sz, { 120 + rng() * 40, 118 + rng() * 36, 110 + rng() * 30 }, "Rock", { yaw = rng() * 360, collide = true })
					n.rocks = n.rocks + 1
				end
			end
		end
	end
	return n
end

local function club(cfg, add, spec)
	local x0, x1, z1 = spec.x0, spec.x1, spec.z1
	local cx = (x0 + x1) / 2
	local GOLD = { 214, 176, 70 }
	add("Vorplatz", "plaza", cx, 0.4, (z1 + 386) / 2, x1 - x0 + 24, 1.2, 386 - z1, { 196, 190, 182 }, "Concrete", { collide = true })
	add("Teppich", "decor", cx, 1.08, (z1 + 386) / 2, 7, 0.16, 386 - z1, { 150, 20, 40 }, "Fabric")
	for k = 0, 5 do
		for _, sd in ipairs({ -5, 5 }) do
			add("Absperrpfosten", "decor", cx + sd, 2.5, z1 + 2 + k * 2.6, 0.5, 3, 0.5, GOLD, "Metal", { collide = true })
		end
	end
	for _, sd in ipairs({ -5, 5 }) do add("Absperrseil", "decor", cx + sd, 3.1, z1 + 2 + 6.5, 0.2, 0.2, 13, { 120, 20, 40 }, "Fabric") end
	add("Vordach", "decor", cx, 12.6, z1 + 6, 18, 0.6, 12, { 40, 32, 60 }, "Metal")
	for _, sd in ipairs({ -8.4, 8.4 }) do add("VordachStuetze", "decor", cx + sd, 6.5, z1 + 11.4, 0.6, 12, 0.6, GOLD, "Metal", { collide = true }) end
	add("TuerRahmen", "decor", cx, 6, z1 + 0.2, 10, 11, 0.5, GOLD, "Metal")
	add("Tuer", "glass", cx, 5.6, z1 + 0.5, 8.4, 10, 0.3, { 30, 36, 48 }, "Glass")
	add("Leuchtschild", "decor", cx, 18.5, z1 + 0.3, 26, 5.4, 0.6, { 26, 18, 44 }, "SmoothPlastic")
	for _, dy in ipairs({ -2.8, 2.8 }) do add("Neonleiste", "decor", cx, 18.5 + dy, z1 + 0.7, 26, 0.3, 0.3, { 255, 60, 180 }, "Neon") end
	add("Schrift", "text", cx, 18.5, z1 + 0.65, 22, 3.6, 0.2, { 255, 255, 255 }, "SmoothPlastic", { yaw = 180, text = { s = "PRINZ EINS", color = { 255, 255, 255 } } })
	local umb = { { 120, 60, 170 }, { 240, 240, 236 } }
	local t = 0
	for _, gx in ipairs({ x0 - 2, x1 - 18 }) do
		for _, dx in ipairs({ 0, 11 }) do
			for _, dz in ipairs({ 5, 13 }) do
				t = t + 1
				local x, z = gx + dx + 2, z1 + dz
				add("TischFuss", "decor", x, 2.2, z, 0.5, 2.4, 0.5, { 60, 62, 66 }, "Metal")
				disc(add, "Tischplatte", x, 3.5, z, 3.4, 0.3, { 230, 226, 216 }, "SmoothPlastic", { collide = true })
				add("SchirmStange", "decor", x, 5, z, 0.3, 8, 0.3, { 200, 200, 204 }, "Metal")
				disc(add, "Schirm", x, 9, z, 8, 0.3, umb[(t % 2) + 1], "Fabric")
			end
		end
	end
	for _, sd in ipairs({ x0 - 8, x1 + 8 }) do -- Pflanzkübel an den Ecken
		add("Kuebel", "decor", sd, 1.9, z1 + 3, 3, 1.8, 3, { 70, 66, 62 }, "Concrete", { collide = true })
		add("KuebelBusch", "bush", sd, 4.3, z1 + 3, 4.5, 4.5, 4.5, HEDGE, "Grass", { shape = "Ball" })
	end
end

local function eisbach(cfg, add)
	local pts = cfg.water.bach.pts
	local zc = cfg.landmarks.eisbach.z
	local cx, cz, ux, uz
	for i = 1, #pts - 1 do
		local a, b = pts[i], pts[i + 1]
		if zc >= a[2] and zc <= b[2] then
			local t = (zc - a[2]) / (b[2] - a[2])
			cx, cz = a[1] + t * (b[1] - a[1]), zc
			ux, uz = Geo.dir(a[1], a[2], b[1], b[2])
		end
	end
	local nx, nz = -uz, ux -- zeigt vom Bach nach Westen (Zuschauerseite)
	local function at(a, l) return cx + ux * a + nx * l, cz + uz * a + nz * l end
	local yawU, yawN = Geo.yawOf(ux, uz), Geo.yawOf(nx, nz)
	local wx, wz = at(0, 0)
	add("Eisbachwelle", "wave", wx, -3.7, wz, 13, 5.5, 5.5, { 214, 234, 246 }, "SmoothPlastic", { shape = "Cylinder", yaw = yawN, transparency = 0.2, tag = "Eisbachwelle", attrs = { Surf = true } })
	local sx, sz = at(-1.6, 0)
	add("Wellenschaum", "wave", sx, -1.3, sz, 13, 0.6, 2.8, { 248, 252, 255 }, "SmoothPlastic", { yaw = yawN, transparency = 0.1 })
	local tx, tz = at(3.6, 0)
	add("Wellental", "wave", tx, -3.85, tz, 13, 0.3, 6, { 190, 220, 238 }, "SmoothPlastic", { yaw = yawN, transparency = 0.4 })
	add("SurfZone", "zone", wx, -2.5, wz, 14, 6, 14, { 255, 255, 255 }, "SmoothPlastic", { yaw = yawN, transparency = 1, tag = "SurfZone", attrs = { Welle = "Eisbach" } })
	local STONEW = { 170, 164, 150 }
	for _, side in ipairs({ -1, 1 }) do -- Ufermauern an beiden Ufern
		local mx, mz = at(0, side * 13.6)
		add("Ufermauer", "wall", mx, -1.4, mz, 44, 5.2, 1.2, STONEW, "Concrete", { yaw = yawU, collide = true })
	end
	local dx, dz = at(0, 21) -- Zuschauerdeck mit Geländer und drei Bänken
	add("Zuschauerdeck", "deck", dx, 0.25, dz, 26, 0.5, 10, { 140, 104, 70 }, "Wood", { yaw = yawU, collide = true })
	local rx, rz = at(0, 15.8)
	add("DeckGelaender", "deck", rx, 1.2, rz, 26, 1.2, 0.3, { 70, 62, 56 }, "Metal", { yaw = yawU, collide = true })
	for _, a in ipairs({ -8, 0, 8 }) do
		local bx, bz = at(a, 24)
		bench(add, bx, 0.5, bz, math.deg(math.atan2(nx, nz)))
	end
	for _, da in ipairs({ -2.8, 2.8 }) do -- Fußgängerbrücke quer über den Bach
		local bx, bz = at(-24 + da, 0)
		add("BrueckeGelaender", "deck", bx, 1.5, bz, 36, 1.4, 0.4, { 70, 62, 56 }, "Metal", { yaw = yawN, collide = true })
	end
	local bx, bz = at(-24, 0)
	add("BrueckeDeck", "deck", bx, 0, bz, 36, 0.8, 6, { 150, 112, 76 }, "Wood", { yaw = yawN, collide = true })
	local px, pz = at(-12, 16.2)
	local signYaw = yawU + 180
	add("Schild", "decor", px, 3.4, pz, 9, 2.4, 0.3, { 36, 70, 110 }, "SmoothPlastic", { yaw = signYaw })
	add("SchildPfosten", "decor", px, 1.6, pz, 0.5, 3.2, 0.5, { 70, 62, 56 }, "Metal", { yaw = signYaw, collide = true })
	local tx2, tz2 = px + nx * 0.25, pz + nz * 0.25
	add("Schrift", "text", tx2, 3.4, tz2, 8.4, 1.8, 0.2, { 255, 255, 255 }, "SmoothPlastic", { yaw = signYaw, text = { s = "EISBACHWELLE", color = { 255, 255, 255 } } })
end

local function biergarten(cfg, add, rng, free)
	local b, t = cfg.landmarks.biergarten, cfg.landmarks.turm
	local cx, cz = (b.x0 + b.x1) / 2, (b.z0 + b.z1) / 2
	add("BiergartenKies", "plaza", cx, 0, cz, b.x1 - b.x0, 0.5, b.z1 - b.z0, { 214, 204, 176 }, "Pavement")
	local kx, kz = b.x0 + 24, b.z0 + 8
	add("AusschankWand", "decor", kx, 5.2, kz, 40, 10, 12, { 240, 236, 226 }, "SmoothPlastic", { collide = true })
	add("AusschankDach", "decor", kx, 10.9, kz, 43, 0.8, 15, { 196, 84, 48 }, "Slate", { collide = true })
	for i = -1, 1 do add("Ausschankfenster", "glass", kx + i * 12, 5.5, kz + 6.1, 8, 3.6, 0.3, { 50, 62, 78 }, "Glass") end
	add("AusschankTheke", "decor", kx, 2.2, kz + 7, 38, 1.4, 1.6, { 140, 104, 70 }, "Wood", { collide = true })
	add("BiergartenSchild", "decor", kx, 8.2, kz + 6.3, 18, 2.6, 0.3, { 36, 90, 60 }, "SmoothPlastic")
	add("Schrift", "text", kx, 8.2, kz + 6.55, 16.4, 2, 0.2, { 255, 255, 255 }, "SmoothPlastic", { yaw = 180, text = { s = "BIERGARTEN", color = { 255, 255, 255 } } })
	local sets = 0
	for x = b.x0 + 8, b.x1 - 8, 13 do
		for z = b.z0 + 24, b.z1 - 6, 11 do
			if math.sqrt((x - t.x) ^ 2 + (z - t.z) ^ 2) > 21 then
				add("Biertisch", "decor", x, 2.9, z, 6, 0.35, 2.4, { 150, 112, 76 }, "Wood", { collide = true })
				for _, sd in ipairs({ -2.1, 2.1 }) do add("Bierbank", "decor", x, 1.7, z + sd, 6, 0.3, 1.2, { 150, 112, 76 }, "Wood", { collide = true }) end
				sets = sets + 1
			end
		end
	end
	local trees = 0
	for x = b.x0 + 4, b.x1 - 4, 14 do
		for _, z in ipairs({ b.z1 + 3 }) do
			if free(x, z, true) then tree(add, rng, x, 0, z, 1.25) trees = trees + 1 end
		end
	end
	for z = b.z0 + 30, b.z1 - 8, 14 do
		for _, x in ipairs({ b.x0 - 3, b.x1 + 3 }) do
			if free(x, z, true) then tree(add, rng, x, 0, z, 1.25) trees = trees + 1 end
		end
	end
	return { sets = sets, trees = trees }
end

local function alleeTrees(cfg, add, rng)
	local a = cfg.allee
	local nx, nz = -a.uz, a.ux -- Normale nach Westen (zur Isar)
	local n, t = 0, a.trees.from
	while t <= a.trees.to do
		tree(add, rng, a.ax + a.ux * t + nx * a.trees.off, 1.0, a.az + a.uz * t + nz * a.trees.off, 1.1, "Allee")
		n, t = n + 1, t + a.trees.step
	end
	return n
end

function Garden.plan(cfg, roadPlan, specials)
	local parts = {}
	local add = emitter(parts)
	local rng = newRng(7)
	local b = cfg.landmarks.biergarten
	local function free(x, z, ignoreZones) -- nicht auf Straßen, nicht im Bach, nicht in der Isar-Böschung, nicht auf Hügelkuppe/Terrasse
		if inRoad(roadPlan.segments, x, z, 8) then return false end
		if Geo.polyDist(x, z, cfg.water.bach.pts) < 22 then return false end
		if Geo.polyDist(x, z, cfg.water.isar.pts) < cfg.water.isar.layers[1][3] + 6 then return false end
		local h = cfg.hills[1]
		if math.sqrt((x - h.x) ^ 2 + (z - h.z) ^ 2) < 24 then return false end
		local tr = cfg.terrace
		if x > tr.x0 - 6 and x < tr.x1 + 6 and z > tr.z0 - 6 and z < tr.z1 + 6 then return false end
		if not ignoreZones then -- Biergarten, Eisbachwelle-Gelände
			if x > b.x0 - 4 and x < b.x1 + 4 and z > b.z0 - 4 and z < b.z1 + 4 then return false end
			if z > cfg.landmarks.eisbach.z - 50 and Geo.polyDist(x, z, cfg.water.bach.pts) < 46 then return false end
		end
		return true
	end
	local stats = {}
	stats.hofTrees = hofgarten(cfg, add, rng, free)
	monopteros(cfg, add)
	stats.egTrees = englischerGarten(cfg, add, rng, free)
	stats.biergarten = biergarten(cfg, add, rng, free)
	eisbach(cfg, add)
	stats.bank = isarBank(cfg, add, rng, cfg.isarBridges)
	stats.alleeTrees = alleeTrees(cfg, add, rng)
	for _, sp in ipairs(specials or {}) do
		if sp.name == "Prinz-Eins" then club(cfg, add, sp) end
	end
	return { parts = parts, stats = stats }
end

return Garden

end)()

local WallPlanner = (function()

local Planner = Planner
local Geo = Geo

local WallPlanner = {}

function WallPlanner.plan(cfg, opts)
	opts = opts or {}
	local o = {}
	for k, v in pairs(opts) do o[k] = v end
	o.targetWidth, o.depth = o.targetWidth or 40, 60
	o.floorWeights = { { 6, 0.25 }, { 7, 0.3 }, { 8, 0.3 }, { 9, 0.15 } } -- Wandhöhe 74-110
	local gates = { N = {}, S = {} }
	for side, list in pairs(cfg.wall.gates) do
		for _, g in ipairs(list) do gates[side][#gates[side] + 1] = g end
	end
	local plan = Planner.planWall({ inner = cfg.ring, outer = cfg.map, gates = gates, specials = cfg.wall.specials }, o)
	local parts = {}
	for _, g in ipairs(cfg.wall.riverGates) do
		local north = g.side == "N"
		local zc = north and (cfg.ring.zmin + cfg.map.zmin) / 2 or (cfg.ring.zmax + cfg.map.zmax) / 2
		local w = g.x1 - g.x0
		local xc = (g.x0 + g.x1) / 2
		parts[#parts + 1] = { name = "Brueckenhaus_" .. g.side, kind = "body", size = { w, 40, 60 }, pos = { xc, 42, zc }, yaw = 0, pitch = 0, color = { 150, 120, 100 }, material = "Brick", collide = true }
		local zEdge = north and cfg.map.zmin + 0.75 or cfg.map.zmax - 0.75
		parts[#parts + 1] = { name = "Gitter_" .. g.side, kind = "gate", size = { w, 36, 1.5 }, pos = { xc, 4, zEdge }, yaw = 0, pitch = 0, color = { 60, 62, 66 }, material = "Metal", collide = true }
	end
	return { houses = plan.houses, parts = parts }
end

return WallPlanner

end)()

local Builder = (function()

local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local Builder = {}

local MATERIALS = {
	SmoothPlastic = Enum.Material.SmoothPlastic, Concrete = Enum.Material.Concrete, Brick = Enum.Material.Brick,
	Glass = Enum.Material.Glass, Wood = Enum.Material.Wood, Metal = Enum.Material.Metal, Asphalt = Enum.Material.Asphalt,
	Pavement = Enum.Material.Pavement, Grass = Enum.Material.Grass, Water = Enum.Material.Water, Neon = Enum.Material.Neon, Sand = Enum.Material.Sand, Rock = Enum.Material.Rock,
	Marble = Enum.Material.Marble, Fabric = Enum.Material.Fabric, Ground = Enum.Material.Ground, Air = Enum.Material.Air,
}

local function buildPart(spec, origin)
	local p = Instance.new("Part")
	p.Name = spec.name
	p.Anchored = true
	p.Size = Vector3.new(spec.size[1], spec.size[2], spec.size[3])
	p.CFrame = CFrame.new(origin + Vector3.new(spec.pos[1], spec.pos[2], spec.pos[3]))
		* CFrame.Angles(0, math.rad(spec.yaw), 0) * CFrame.Angles(math.rad(spec.pitch or 0), 0, math.rad(spec.roll or 0))
	if spec.shape == "Cylinder" then p.Shape = Enum.PartType.Cylinder elseif spec.shape == "Ball" then p.Shape = Enum.PartType.Ball end -- Achse läuft entlang x, mit roll = 90 steht sie senkrecht
	if spec.transparency then p.Transparency = spec.transparency end
	p.Color = Color3.fromRGB(spec.color[1], spec.color[2], spec.color[3])
	p.Material = MATERIALS[spec.material] or Enum.Material.SmoothPlastic
	p.CanCollide = spec.collide
	p.CanTouch = false
	if spec.kind == "glass" then
		p.Transparency = 0.3
		p.CastShadow = false
	end
	if spec.tag then
		CollectionService:AddTag(p, spec.tag) -- Tag-Skript schaltet nachts Lit-Fenster auf Neon
		p:SetAttribute("Lit", spec.lit == true)
	end
	if spec.text then -- Schrift: Platte unsichtbar, Text als SurfaceGui auf der Vorderseite
		p.Transparency = 1
		p.CastShadow = false
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Front
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 30
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.TextScaled = true
		label.Font = Enum.Font.GothamBold
		label.Text = spec.text.s
		label.TextColor3 = Color3.fromRGB(spec.text.color[1], spec.text.color[2], spec.text.color[3])
		label.Parent = gui
		gui.Parent = p
	end
	if spec.attrs then
		for k, v in pairs(spec.attrs) do p:SetAttribute(k, v) end -- z. B. Lampenfarbe für das Ampel-Skript
	end
	return p
end

local count = 0
local function breathe(every)
	count = count + 1
	if count % every == 0 then task.wait() end
end

function Builder.buildParts(parts, parent, origin)
	for _, spec in ipairs(parts) do
		buildPart(spec, origin).Parent = parent
		breathe(500)
	end
end

function Builder.build(plan, parent, origin)
	for _, list in ipairs({ plan.houses, plan.inner or {} }) do
		for _, h in ipairs(list) do
			local model = Instance.new("Model")
			model.Name = h.name
			model:SetAttribute("Floors", h.floors)
			model:SetAttribute("Side", h.side)
			for _, spec in ipairs(h.parts) do
				local part = buildPart(spec, origin)
				part.Parent = model
				if spec.name == "Body" then model.PrimaryPart = part end
			end
			model.Parent = parent -- erst am Ende, spart Replikation
			breathe(8)
		end
	end
end

function Builder.applyTerrain(ops, origin)
	local terrain = Workspace.Terrain
	pcall(function()
		terrain.Decoration = false
		terrain.WaterTransparency = 0.45
		terrain.WaterColor = Color3.fromRGB(38, 104, 128)
		terrain.WaterReflectance = 0.35
	end)
	for _, op in ipairs(ops) do
		local cf = CFrame.new(origin + Vector3.new(op.pos[1], op.pos[2], op.pos[3])) * CFrame.Angles(0, math.rad(op.yaw or 0), 0)
		if op.op == "cylinder" then
			terrain:FillCylinder(cf, op.height, op.radius, MATERIALS[op.material])
		else
			terrain:FillBlock(cf, Vector3.new(op.size[1], op.size[2], op.size[3]), MATERIALS[op.material])
		end
		breathe(10)
	end
end

function Builder.measureGround(origin)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { Workspace.Terrain }
	local ys = {}
	for _, p in ipairs({ { -560, -200 }, { 0, -100 }, { 200, -350 }, { -300, 150 }, { 300, 200 } }) do
		local hit = Workspace:Raycast(origin + Vector3.new(p[1], 200, p[2]), Vector3.new(0, -400, 0), params)
		if hit then ys[#ys + 1] = hit.Position.Y - origin.Y end
	end
	if #ys == 0 then return 0 end
	table.sort(ys)
	return math.floor(ys[math.ceil(#ys / 2)] * 2 + 0.5) / 2 -- auf 0,5 gerundet
end

function Builder.countWater(center)
	local ok, n = pcall(function()
		local region = Region3.new(center - Vector3.new(16, 20, 16), center + Vector3.new(16, 8, 16)):ExpandToGrid(4)
		local mats = Workspace.Terrain:ReadVoxels(region, 4)
		local c = 0
		for x = 1, #mats do
			for y = 1, #mats[x] do
				for z = 1, #mats[x][y] do
					if mats[x][y][z] == Enum.Material.Water then c = c + 1 end
				end
			end
		end
		return c
	end)
	return ok and n or nil
end

function Builder.waterFallback(pts, halfWidth, y, origin)
	local folder = Builder.container("WasserErsatz")
	for i = 1, #pts - 1 do
		local dx, dz = pts[i + 1][1] - pts[i][1], pts[i + 1][2] - pts[i][2]
		local len = math.sqrt(dx * dx + dz * dz)
		local p = Instance.new("Part")
		p.Name = "Wasser"
		p.Anchored = true
		p.CanCollide = false
		p.Size = Vector3.new(len + 2, 0.4, halfWidth * 2)
		p.CFrame = CFrame.new(origin + Vector3.new((pts[i][1] + pts[i + 1][1]) / 2, y, (pts[i][2] + pts[i + 1][2]) / 2)) * CFrame.Angles(0, math.atan2(-dz, dx), 0)
		p.Color = Color3.fromRGB(63, 155, 220)
		p.Material = Enum.Material.SmoothPlastic
		p.Transparency = 0.35
		p.Parent = folder
	end
end

function Builder.clearTerrain()
	Workspace.Terrain:Clear()
end

function Builder.installController(source)
	local sss = game:GetService("ServerScriptService")
	local old = sss:FindFirstChild("AmpelSteuerung")
	if old then old:Destroy() end
	local script = Instance.new("Script")
	script.Name = "AmpelSteuerung"
	script.Source = source
	script.Parent = sss
end

function Builder.container(...)
	local function folder(parent, name, replace)
		local f = parent:FindFirstChild(name)
		if f and replace then
			f:Destroy()
			f = nil
		end
		if not f then
			f = Instance.new("Folder")
			f.Name = name
			f.Parent = parent
		end
		return f
	end
	local path = { ... }
	local f = folder(Workspace, "Map")
	for i, name in ipairs(path) do
		f = folder(f, name, i == #path)
	end
	return f
end

return Builder

end)()

local BuildAll = (function()

local Config = Config
local Blocks = Blocks
local Planner = Planner
local Specials = Specials
local RoadsPlanner = RoadsPlanner
local LightsPlanner = LightsPlanner
local Landmarks = Landmarks
local Garden = Garden
local TerrainPlanner = TerrainPlanner
local WallPlanner = WallPlanner
local Builder = Builder

local BuildAll = {}

local STEPS = {
	terrain = function(opts, origin)
		if opts.clearTerrain ~= false then Builder.clearTerrain() end
		local ops = TerrainPlanner.plan(Config)
		Builder.applyTerrain(ops, origin)
		return string.format("%d Terrain-Operationen", #ops)
	end,
	roads = function(opts, origin)
		local plan = RoadsPlanner.plan(Config)
		Builder.buildParts(plan.parts, Builder.container("Strassen"), origin)
		return string.format("%d Teile, %d Parkbuchten", #plan.parts, plan.stats.bays)
	end,
	lights = function(opts, origin)
		local plan = LightsPlanner.plan(Config, RoadsPlanner.plan(Config))
		Builder.buildParts(plan.parts, Builder.container("Strassenmobiliar"), origin)
		return string.format("%d Laternen, %d Ampelmasten, %d Fußgängerampeln, %d Teile", plan.stats.lamps, plan.stats.signals, plan.stats.ped, #plan.parts)
	end,
	landmarks = function(opts, origin)
		local plan = Landmarks.plan(Config)
		Builder.buildParts(plan.parts, Builder.container("Wahrzeichen"), origin)
		return string.format("%d Teile (Siegestor, Friedensengel, Frauenkirche, Chinesischer Turm)", #plan.parts)
	end,
	gardens = function(opts, origin)
		local plan = Garden.plan(Config, RoadsPlanner.plan(Config), Specials)
		Builder.buildParts(plan.parts, Builder.container("Gruenanlagen"), origin)
		local st = plan.stats
		return string.format("%d Teile, %d Bäume, %d Uferweg-Platten, %d Findlinge", #plan.parts, st.hofTrees + st.egTrees, st.bank.slabs, st.bank.rocks)
	end,
	houses = function(opts, origin)
		local only, houses, parts = {}, 0, 0
		for _, n in ipairs(opts.only or {}) do only[n] = true end
		for _, block in ipairs(Blocks) do
			if next(only) == nil or only[block.name] then
				local plan = Planner.planBlock(block, { seed = opts.seed or 1 })
				Builder.build(plan, Builder.container("Gebaeude", block.name), origin)
				local st = Planner.stats(plan)
				houses, parts = houses + st.houses, parts + st.parts
			end
		end
		if next(only) == nil or only.IsarAllee then
			local plan = Planner.planAllee(Config, { seed = opts.seed or 1 })
			Builder.build(plan, Builder.container("Gebaeude", "IsarAllee"), origin)
			local st = Planner.stats(plan)
			houses, parts = houses + st.houses, parts + st.parts
		end
		if next(only) == nil then
			local folder = Builder.container("Gebaeude", "Sonderbauten")
			for _, spec in ipairs(Specials) do
				local plan = Planner.planSpecial(spec, { seed = opts.seed or 1 })
				Builder.build(plan, folder, origin)
				local st = Planner.stats(plan)
				houses, parts = houses + st.houses, parts + st.parts
			end
		end
		return string.format("%d Häuser, %d Teile", houses, parts)
	end,
	wall = function(opts, origin)
		local plan = WallPlanner.plan(Config, { seed = opts.seed or 1 })
		local folder = Builder.container("Mapgrenze")
		Builder.build(plan, folder, origin)
		Builder.buildParts(plan.parts, folder, origin)
		local st = Planner.stats(plan)
		return string.format("%d Gebäude, %d Teile", st.houses, st.parts + #plan.parts)
	end,
}

BuildAll.order = { "terrain", "roads", "lights", "landmarks", "gardens", "houses", "wall" }

local function afterTerrain(base)
	local ground = Builder.measureGround(base)
	print(string.format("[boden] Terrain-Oberkante gemessen: %.1f, alle weiteren Teile werden daran ausgerichtet", ground))
	local pts = Config.water.isar.pts
	local mid = pts[math.ceil(#pts / 2)]
	local water = Builder.countWater(base + Vector3.new(mid[1], Config.water.isar.waterTop - 2, mid[2]))
	if water == nil then
		print("[wasser] Auslesen nicht möglich, bitte im Studio nachsehen")
	elseif water == 0 then
		print("[wasser] KEIN Terrain-Wasser gefunden, setze blaue Ersatz-Platten (nicht schwimmbar)")
		Builder.waterFallback(pts, 38, Config.water.isar.waterTop + 0.2, base + Vector3.new(0, ground, 0))
	else
		print(string.format("[wasser] ok (%d Wasser-Zellen am Messpunkt)", water))
	end
	return ground
end

function BuildAll.run(opts)
	opts = opts or {}
	local base = opts.origin or Vector3.new(0, 0, 0)
	local steps = opts.steps or BuildAll.order
	local ground = 0
	local hasTerrain = false
	for _, n in ipairs(steps) do hasTerrain = hasTerrain or n == "terrain" end
	if not hasTerrain then ground = Builder.measureGround(base) end -- vorhandenes Terrain, z. B. beim zweiten Lauf
	for _, name in ipairs(steps) do
		local origin = base + Vector3.new(0, ground, 0)
		local ok, result = pcall(STEPS[name], opts, origin) -- ein fehlerhafter Schritt stoppt die anderen nicht
		print(string.format("[%s] %s", name, ok and result or ("FEHLER: " .. tostring(result))))
		if name == "terrain" and ok then
			local ok2, g = pcall(afterTerrain, base)
			if ok2 then ground = g else print("[boden] FEHLER: " .. tostring(g)) end
		end
	end
	if opts.controllerSource then -- Plugin: Ampel-Skript dauerhaft anlegen
		local ok, err = pcall(Builder.installController, opts.controllerSource)
		print(ok and "[ampel] Script AmpelSteuerung in ServerScriptService angelegt" or ("[ampel] FEHLER: " .. tostring(err)))
	end
	if opts.afterBuild then opts.afterBuild() print("[ampel] läuft (nur bis zum Stoppen)") end -- Test-Script
	pcall(function() game:GetService("ChangeHistoryService"):SetWaypoint("MapBuilder") end) -- Strg+Z
	print("Fertig")
end

return BuildAll

end)()

local AMPEL_SOURCE = [==[
local Ampel = (function()

local Ampel = {}

Ampel.config = {
	green = 30, -- Sekunden grün je Richtung
	yellow = 3,
	clear = 2, -- alle rot, bevor die andere Richtung grün bekommt
	pedGreen = 12,
	pedRed = 28,
}

local ON = { Red = { 235, 40, 40 }, Yellow = { 255, 190, 30 }, Green = { 60, 220, 90 } }
local DIM = { Red = { 90, 20, 20 }, Yellow = { 100, 74, 12 }, Green = { 20, 80, 36 } }

function Ampel.junction(c, t)
	local phases = {
		{ c.green, "Green", "Red" }, { c.yellow, "Yellow", "Red" }, { c.clear, "Red", "Red" },
		{ c.green, "Red", "Green" }, { c.yellow, "Red", "Yellow" }, { c.clear, "Red", "Red" },
	}
	local cycle = 0
	for _, p in ipairs(phases) do cycle = cycle + p[1] end
	t = t % cycle
	for _, p in ipairs(phases) do
		if t < p[1] then return p[2], p[3] end
		t = t - p[1]
	end
	return "Red", "Red"
end

function Ampel.wache(c, state, alarm, t)
	if alarm and state.mode == "Green" then state.mode, state.since = "Yellow", t end
	if state.mode == "Yellow" and t - state.since >= c.yellow then state.mode, state.since = "Red", t end
	if not alarm and state.mode ~= "Green" and t - state.since >= 1 then state.mode, state.since = "Green", t end
	return state.mode
end

function Ampel.ped(c, t)
	return (t % (c.pedGreen + c.pedRed)) < c.pedGreen and "Green" or "Red"
end

local function setLamp(part, on, name)
	if part:GetAttribute("Lit") == on then return end
	part:SetAttribute("Lit", on)
	part.Material = on and Enum.Material.Neon or Enum.Material.SmoothPlastic
	local col = (on and ON or DIM)[name]
	part.Color = Color3.fromRGB(col[1], col[2], col[3])
end

function Ampel.start()
	local CollectionService = game:GetService("CollectionService")
	local Workspace = game:GetService("Workspace")
	local groups = {} -- name -> { lamps = { NS = { Red = {parts} ...}, EW = ... }, wache = state | nil, offset }
	local n = 0
	local function collect(tag)
		for _, part in ipairs(CollectionService:GetTagged(tag)) do
			local name, axis, lamp = part:GetAttribute("Group"), part:GetAttribute("Axis"), part:GetAttribute("Lamp")
			if name and axis and lamp then
				local g = groups[name]
				if not g then
					n = n + 1
					g = { lamps = { NS = {}, EW = {} }, ped = tag == "PedLight", wache = string.sub(name, 1, 6) == "Wache_" and { mode = "Green", since = 0 } or nil, offset = n * 7 }
					groups[name] = g
				end
				local list = g.lamps[axis][lamp] or {}
				g.lamps[axis][lamp] = list
				list[#list + 1] = part
			end
		end
	end
	collect("TrafficLight")
	collect("PedLight")
	local function show(g, axis, color)
		for name, list in pairs(g.lamps[axis]) do
			for _, part in ipairs(list) do setLamp(part, name == color, name) end
		end
	end
	task.spawn(function()
		while true do
			local t = os.clock()
			local alarm = Workspace:GetAttribute("WacheAlarm") == true
			for _, g in pairs(groups) do
				if g.ped then
					local c = Ampel.ped(Ampel.config, t)
					show(g, "EW", c)
				elseif g.wache then
					local c = Ampel.wache(Ampel.config, g.wache, alarm, t)
					show(g, "NS", c)
					show(g, "EW", "Red")
				else
					local ns, ew = Ampel.junction(Ampel.config, t + g.offset)
					show(g, "NS", ns)
					show(g, "EW", ew)
				end
			end
			task.wait(0.25)
		end
	end)
end

return Ampel

end)()
Ampel.start()
]==]

local toolbar = plugin:CreateToolbar("Notruf München")
local button = toolbar:CreateButton("Karte bauen", "Terrain, Straßen, Ampeln, Laternen, Häuser und Mapgrenze bauen", "")
button.Click:Connect(function()
	BuildAll.run({ origin = ORIGIN, controllerSource = AMPEL_SOURCE })
end)
