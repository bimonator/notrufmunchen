-- MapBuilder_Plugin.lua  (automatisch erzeugt mit make_bundles.py, nicht von Hand ändern)
-- Dauerhaft bauen: in Workspace ein Script anlegen, alles einfügen, Rechtsklick auf das Script >
-- "Als lokales Plugin speichern". Danach das Script löschen. Im Reiter Plugins erscheint der Knopf "Karte bauen".
-- Der Knopf baut im Edit-Modus, die Objekte bleiben im Projekt erhalten (Strg+Z macht es rückgängig).
local ORIGIN = Vector3.new(0, 0, 0) -- Position des Siegestors

local Geo = (function()
-- Geo.lua
-- Kleine 2D-Geometrie in der Draufsicht (x = Ost, z = Süd). Reine Mathematik, keine Roblox-Funktionen.

local Geo = {}

function Geo.round3(v)
	return math.floor(v * 1000 + 0.5) / 1000
end

-- Einheitsvektor und Länge von a nach b
function Geo.dir(ax, az, bx, bz)
	local dx, dz = bx - ax, bz - az
	local l = math.sqrt(dx * dx + dz * dz)
	return dx / l, dz / l, l
end

-- Drehwinkel (Grad) um die Y-Achse, bei dem die lokale x-Achse eines Teils in Richtung (ux, uz) zeigt
function Geo.yawOf(ux, uz)
	return math.deg(math.atan2(-uz, ux)) % 360
end

-- Rechteck um eine Strecke a-b mit Halbbreite hw; extA/extB verlängern an den Enden
function Geo.rect(ax, az, bx, bz, hw, extA, extB)
	local ux, uz, l = Geo.dir(ax, az, bx, bz)
	return { ax = ax, az = az, ux = ux, uz = uz, nx = -uz, nz = ux, s0 = -extA, s1 = l + extB, w = hw }
end

-- Abschnitt [t0, t1] der Linie P + u*t (t = 0..L), der im Rechteck r liegt (margin verkleinert das Rechteck). nil, wenn keiner.
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

-- Aus den Abschnitten spans (Liste {a, b}) die Abschnitte cuts herausschneiden
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

-- Liegt der Punkt (px, pz) in der Draufsicht innerhalb des Teils? (margin verkleinert)
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
-- Config.lua
-- Alle Karten-Maße aus docs/MAP_PLAN.md und docs/phase1_bauplan.html als Daten.
-- Koordinaten: x = Ost, z = Süd, Ursprung = Siegestor. Einheiten: Studs. Terrain-Oberkante = Y 0.

local C = {}

C.map = { xmin = -745, zmin = -556, xmax = 1160, zmax = 494 }
C.ring = { xmin = -685, zmin = -496, xmax = 1100, zmax = 434 } -- Außenkante der Ringstraße = Innenkante der Mapgrenze

-- Querschnitte: strips = { von, bis, Art } quer zur Straße (positiv = links der Fahrtrichtung, Normale n = (-uz, ux)).
-- dashes = Versatz der gestrichelten Linien. underground = Streifen entfällt im Tunnelbereich.
C.profiles = {
	std48 = { half = 24, dashes = { 0 }, strips = { { -24, -14, "walk" }, { -14, 14, "road" }, { 14, 24, "walk" } } },
	raster57 = { half = 28.5, dashes = { -4.5 }, strips = { { -28.5, -18.5, "walk" }, { -18.5, 18.5, "road" }, { 18.5, 28.5, "walk" } } },
	axis110 = {
		half = 55, dashes = { -20, 20 }, dashesUnderground = true,
		strips = {
			{ -55, -43, "walk" }, { -43, -34, "road" }, { -34, -6, "road", true }, { -6, 6, "median", true },
			{ 6, 34, "road", true }, { 34, 43, "road" }, { 43, 55, "walk" },
		},
	},
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

-- Fahrtrichtung der Raster-Straßen: V nach Norden, H nach Osten, damit die Parkseite (positiv) östlich bzw. südlich liegt.
C.roads = {
	{ name = "Ring", closed = true, profile = "std48", pts = { { -661, -472 }, { 1076, -472 }, { 1076, 410 }, { -661, 410 } } },
	{ name = "Achse", profile = "axis110", pts = { { 0, -472 }, { 0, 410 } } },
	{ name = "V1", profile = "raster57", pts = { { -460, 30 }, { -460, -472 } } },
	{ name = "V2", profile = "raster57", pts = { { -235, 30 }, { -235, -472 } } },
	{ name = "H1", profile = "raster57", pts = { { -661, -285 }, { 0, -285 } } },
	{ name = "H2", profile = "raster57", pts = { { -661, 30 }, { 0, 30 } } },
	{ name = "Diagonale", profile = "std48", pts = { { 0, 30 }, { 290, 36 }, { 455, -77 }, { 605, -212 }, { 770, -347 }, { 790, -472 } } },
	{ name = "Isarspange", profile = "std48", pts = { { 455, -77 }, { 700, -60 }, { 780, -40 }, { 990, 0 }, { 1030, 70 }, { 1076, 210 } } },
	{ name = "V3", profile = "std48", pts = { { 300, -472 }, { 300, 32 } } },
	{ name = "KreiselNord", profile = "std48", pts = { { -550, 30 }, { -550, 196 } } },
	{ name = "KreiselWest", profile = "std48", pts = { { -661, 254 }, { -612, 254 } } },
	{ name = "Kreisel", closed = true, profile = "kreisel24", pts = circle(-550, 254, 58, 24) },
	{ name = "Fussgaengerzone", profile = "plaza40", pts = { { -480, 254 }, { -55, 254 } } },
}

-- Parkbuchten: Mittellinie des Parkstreifens, Buchtlänge 16, Breite 9. { x0, z0, x1, z1 }
C.bay = { length = 16, width = 9 }
C.bays = {
	{ 38.5, -448, 38.5, -40 }, { -38.5, -448, -38.5, -314 }, { -38.5, -257, -38.5, -40 }, { -38.5, 64, -38.5, 226 }, { 38.5, 64, 38.5, 286 },
	{ -633, -271, -497, -271 }, { -432, -271, -272, -271 }, { -207, -271, -59, -271 },
	{ -633, 44, -578, 44 }, { -522, 44, -497, 44 }, { -432, 44, -272, 44 }, { -207, 44, -59, 44 },
	{ -446, -448, -446, -317 }, { -446, -253, -446, -211 }, { -446, -89, -446, -3 },
	{ -221, -448, -221, -317 }, { -221, -253, -221, -3 },
}

C.plazas = {
	{ name = "Odeonsplatz", x0 = -140, z0 = 296, x1 = 140, z1 = 386 },
	{ name = "MarienplatzInsel", x0 = -580, z0 = 224, x1 = -520, z1 = 284 },
}

-- Kleine Brücken (flaches Deck unter der Straße, Länge entlang der Straße, Breite quer, yaw in Grad)
C.bridges = {
	{ name = "B0", x = 640, z = -257, len = 56, wid = 48, yaw = 39.3 },
	{ name = "B1", x = 661, z = -62, len = 56, wid = 48, yaw = 356 },
	{ name = "B5", x = 672, z = 120, len = 44, wid = 10, yaw = 0, pedestrian = true },
}

-- Isar-Brücken: gewölbte Steinbrücken (Fahrbahn steigt zur Mitte um peak), breiter als die Straße, mit Pfeilern im Fluss.
-- len = Gesamtlänge entlang der Straße, wid = Breite der Fahrbahn, walk = Breite jedes Gehwegs, yaw = Richtung der Straße
C.archBridges = {
	{ name = "B2", x = 890, z = -19, len = 170, wid = 28, walk = 14, yaw = 349.4, peak = 10 },
	{ name = "B3", x = 687.5, z = 410, len = 220, wid = 28, walk = 14, yaw = 0, peak = 12 }, -- Luitpoldbrücke über Bach und Isar
	{ name = "B4", x = 985, z = -472, len = 170, wid = 28, walk = 14, yaw = 0, peak = 8 },
}

-- Siegestor-Unterführung: die vier Fahrspuren der Achse tauchen unter der Querstraße H2/D ab
C.tunnel = { road = "Achse", half = 34, z0 = -144, rampN = { -144, -8 }, box = { -8, 64 }, rampS = { 64, 200 }, z1 = 200, floorTop = -16.5, surfaceTop = 0.5 }

C.water = {
	isar = {
		pts = { { 985, -556 }, { 985, -472 }, { 960, -330 }, { 930, -200 }, { 895, -90 }, { 885, 0 }, { 850, 100 }, { 800, 200 }, { 750, 300 }, { 705, 390 }, { 695, 410 }, { 670, 494 } },
		layers = { { 0, -4, 62.5 }, { -4, -8, 47.5 }, { -8, -12, 36 }, { -12, -14, 30 } }, waterTop = -8,
	},
	bach = {
		pts = { { 640, -257 }, { 642, -226 }, { 665, -31 }, { 672, 194 }, { 650, 330 }, { 620, 410 }, { 612, 494 } },
		layers = { { 0, -4, 13 }, { -4, -7, 7 } }, waterTop = -4,
	},
}

C.parks = { -- Gras-Oberfläche (Terrain)
	{ name = "Hofgarten", x0 = 60, z0 = 100, x1 = 400, z1 = 290 },
	{ name = "EnglischerGarten", x0 = 430, z0 = -45, x1 = 700, z1 = 345 },
	{ name = "Hinterhofpark", x0 = -401.5, z0 = -418, x1 = -293.5, z1 = -343.5 },
}
C.hills = { { name = "Monopteros", x = 575, z = 75, layers = { { 44, 0, 4 }, { 30, 4, 8 } } } } -- { Radius, y0, y1 }, nur 8 hoch
C.terrace = { name = "Friedensengel", x0 = 870, z0 = 250, x1 = 1020, z1 = 346, height = 4 }

C.wall = {
	gates = { N = { { -60, 60 }, { 915, 1055 } }, S = { { -40, 40 }, { 590, 745 } } },
	specials = { { side = "N", name = "Querriegel", x0 = -60, x1 = 60, floors = 10 }, { side = "S", name = "Feldherrnhalle", x0 = -40, x1 = 40, floors = 2 } },
	riverGates = { { side = "N", x0 = 915, x1 = 1055 }, { side = "S", x0 = 590, x1 = 745 } }, -- Brückenhaus: Gebäude über dem Fluss
}

return C

end)()

local Planner = (function()
-- Planner.lua
-- Reine Geometrie für Häuser (Blockränder, Sonderbauten, Mapgrenze). Keine Roblox-Funktionen, läuft in Luau und in Lua 5.1 (Tests).
-- Koordinaten wie im Kartenplan: x = Ost, z = Süd, y = oben. Einheiten: Studs.
-- Lokales Haus-System: x läuft entlang der Fassade, z zeigt von der Fassade in den Block hinein, y nach oben.
-- Alles, was vor der Wand liegt (Fenster, Gesimse, Balkone), hat lokal z < 0.

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

-- Teil im lokalen Haus-System anlegen; Position wird in Weltkoordinaten umgerechnet.
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
local SHUTTERS = { { 70, 100, 80 }, { 110, 60, 50 }, { 60, 70, 100 }, { 90, 90, 94 } }
local AWNINGS = { { 190, 60, 50 }, { 60, 100, 150 }, { 70, 130, 90 }, { 220, 170, 60 } }

-- Fenster: Rahmen und Scheibe sitzen vor der Wand (kein Ausschnitt), Fensterbank darunter. shift = zusätzlicher Abstand (Erker).
local function addWindow(h, label, face, u, yc, w, hgt, lit, shift)
	shift = shift or 0
	local lx, lz, ey = onFace(h, face, u, 0.2 + shift)
	add(h, "Frame" .. label, "frame", lx, yc, lz, w + 1.6, hgt + 1.6, 0.4, FRAME, "SmoothPlastic", { yaw = ey })
	lx, lz = onFace(h, face, u, 0.4 + shift)
	add(h, "Glass" .. label, "glass", lx, yc, lz, w, hgt, 0.2, lit and GLASS_LIT or GLASS, "Glass", { yaw = ey, lit = lit, tag = "HouseWindow" })
	if h.simple then return end
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
	h.floors, h.height, h.facade, h.roof = floors, H, facade, roof

	-- Hauptkörper, Sockel, Gesimse
	add(h, "Body", "body", 0, y0 + H / 2, D / 2, W, H, D, facade, "SmoothPlastic", { collide = true })
	add(h, "Plinth", "trim", 0, y0 + 1.2, -0.25, W, 2.4, 0.5, plinthColor, "Concrete")
	for k = 1, floors - 1 do
		local yb = y0 + o.groundH + o.upperH * (k - 1)
		add(h, "Ledge" .. k, "trim", 0, yb, -0.4, W, 0.7, 0.8, ledgeColor, "Concrete")
	end
	add(h, "Cornice", "trim", 0, y0 + H - 0.8, -0.8, W, 1.6, 1.6, tint(facade, 0.45), "Concrete")

	-- Dach: flach mit Attika, Mansarddach (steile Front, flaches Dach dahinter) oder zurückgesetztes Staffelgeschoss
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

	-- Obergeschoss: Fenster, Erker, Fensterläden, Balkone
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

	-- Erdgeschoss: Tür auf einer Seite; Schaufenster mit Markise oder zwei kleinere Fenster
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

	-- Eckhaus: Fenster auch an der Seitenfläche zur Querstraße
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

-- Zufällige Hausbreiten, die genau die Länge füllen (Abweichung höchstens etwa +-10 % vom Durchschnitt)
local function splitWidths(len, n, rng)
	local w, sum = {}, 0
	for i = 1, n do
		w[i] = 0.9 + 0.2 * rng.next()
		sum = sum + w[i]
	end
	for i = 1, n do w[i] = len * w[i] / sum end
	return w
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
				local n = math.max(1, math.floor(len / o.targetWidth))
				local widths = splitWidths(len, n, rng)
				local t = range[1]
				for i = 1, n do
					idx = idx + 1
					local width = widths[i]
					local h = {
						side = side.name, index = idx, simple = o.simple,
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

-- Achsparallele Außenmaße eines Teils (Drehung nur in 90-Grad-Schritten).
function Planner.aabb(p)
	local sx, sy, sz = p.size[1], p.size[2], p.size[3]
	if p.yaw % 180 == 90 then sx, sz = sz, sx end
	return p.pos[1] - sx / 2, p.pos[2] - sy / 2, p.pos[3] - sz / 2, p.pos[1] + sx / 2, p.pos[2] + sy / 2, p.pos[3] + sz / 2
end

-- block = { name, xmin, zmin, xmax, zmax, reserved = { {x0,z0,x1,z1}, ... } } (Außenkante = Straßenrand).
-- Häuser, die in reserved-Flächen (Sonderbauten) stehen würden, entfallen.
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
	return plan
end

-- Sonderbau (Bank, Wache, Krankenhaus ...) als Platzhalter-Gebäude auf einer Rechteckfläche.
-- spec = { name, x0, z0, x1, z1, facing = "N"|"S"|"E"|"W" (Seite zur Straße), floors, color, canopy = { x0, z0, x1, z1 } }
function Planner.planSpecial(spec, opts)
	local o = mergeOpts(opts)
	local rng = newRng(o.seed + hash(spec.name))
	local f = spec.facing
	local h = {
		side = f, index = 0, simple = false, forceFloors = spec.floors, color = spec.color, parts = {}, name = "Sonder_" .. spec.name,
	}
	if f == "N" then h.ox, h.oz, h.yaw, h.width, h.depth = (spec.x0 + spec.x1) / 2, spec.z0, 0, spec.x1 - spec.x0, spec.z1 - spec.z0
	elseif f == "S" then h.ox, h.oz, h.yaw, h.width, h.depth = (spec.x0 + spec.x1) / 2, spec.z1, 180, spec.x1 - spec.x0, spec.z1 - spec.z0
	elseif f == "W" then h.ox, h.oz, h.yaw, h.width, h.depth = spec.x0, (spec.z0 + spec.z1) / 2, 90, spec.z1 - spec.z0, spec.x1 - spec.x0
	else h.ox, h.oz, h.yaw, h.width, h.depth = spec.x1, (spec.z0 + spec.z1) / 2, 270, spec.z1 - spec.z0, spec.x1 - spec.x0 end
	planHouse(h, o, rng, false, false)
	if spec.canopy then -- Tankstellen-Schirm: Dach auf vier Pfeilern, 8 Zapfsäulen
		local c = spec.canopy
		local cx, cz, w, d = (c[1] + c[3]) / 2, (c[2] + c[4]) / 2, c[3] - c[1], c[4] - c[2]
		local function w3(name, x, y, z, sx, sy, sz, color, mat)
			h.parts[#h.parts + 1] = { name = name, kind = "trim", size = { sx, sy, sz }, pos = { round3(x), round3(y), round3(z) }, yaw = 0, pitch = 0, color = color, material = mat, collide = false, lpos = { 0, y, 0 } }
		end
		w3("CanopyRoof", cx, 14.5, cz, w, 1, d, { 232, 200, 60 }, "SmoothPlastic")
		for _, px in ipairs({ c[1] + 3, c[3] - 3 }) do
			for _, pz in ipairs({ c[2] + 3, c[4] - 3 }) do w3("CanopyPillar", px, 7.5, pz, 1.5, 14, 1.5, { 200, 200, 204 }, "Metal") end
		end
		for _, px in ipairs({ cx - 6, cx + 6 }) do
			for k = 0, 3 do w3("Pump", px, 3.5, c[2] + 10 + k * (d - 20) / 3, 1.5, 5, 1.5, { 200, 60, 50 }, "SmoothPlastic") end
		end
	end
	return { houses = { h } }
end

-- Mapgrenze: Häuserband rund um die Karte, Fassade zeigt nach innen zur Ringstraße.
-- wall = { inner = {xmin,zmin,xmax,zmax} (Ringaußenkante), outer = {...} (Kartenrand), gates = { N = {{x0,x1},...}, S = ... },
--          specials = { { side, name, x0, x1, floors } } }
function Planner.planWall(wall, opts)
	local o = mergeOpts(opts)
	o.simple, o.setback = true, 0
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
	for _, h in ipairs(plan.houses) do
		parts = parts + #h.parts
		area = area + h.width * h.depth
	end
	return { houses = #plan.houses, parts = parts, footprint = area }
end

return Planner

end)()

local Blocks = (function()
-- Blocks.lua
-- Häuserblöcke (Kartenkoordinaten in Studs, Ursprung = Siegestor, x = Ost, z = Süd).
-- Außenkante = Straßenrand (Raster-Straßen 57 breit: V1 x=-460, V2 x=-235, H1 z=-285, H2 z=30; Ring 48 breit; Achse 110 breit).
-- reserved = Flächen der Sonderbauten (Specials.lua): dort entfallen Blockrand-Häuser.

return {
	{ name = "A_NordWest", xmin = -637, zmin = -448, xmax = -488.5, zmax = -313.5 },
	{ name = "B_NordMitte", xmin = -431.5, zmin = -448, xmax = -263.5, zmax = -313.5 },
	{ name = "C_LeopoldWestNord", xmin = -206.5, zmin = -448, xmax = -55, zmax = -313.5, reserved = { { -127, -385, -55, -315 } } },
	{ name = "D_West", xmin = -637, zmin = -256.5, xmax = -488.5, zmax = 1.5 },
	{ name = "E_Mitte", xmin = -431.5, zmin = -256.5, xmax = -263.5, zmax = 1.5, reserved = { { -425, -200, -275, -100 } } },
	{ name = "F_LeopoldWestSued", xmin = -206.5, zmin = -256.5, xmax = -55, zmax = 1.5, reserved = { { -205, -250, -109, -140 } } },
	{ name = "G_LeopoldOst", xmin = 55, zmin = -448, xmax = 276, zmax = 4, reserved = { { 58, -300, 168, -190 } } },
}

end)()

local Specials = (function()
-- Specials.lua
-- Sonderbauten als Platzhalter-Gebäude (richtige Grundfläche, Farbe nach Art). Details und Innenräume kommen später.
-- facing = Seite zur Straße. Koordinaten wie in docs/phase1_bauplan.html.

return {
	{ name = "Isarbank", x0 = -127, z0 = -385, x1 = -55, z1 = -315, facing = "E", floors = 4, color = { 176, 120, 100 } },
	{ name = "Parkhaus", x0 = -205, z0 = -250, x1 = -109, z1 = -140, facing = "N", floors = 4, color = { 170, 170, 176 } },
	{ name = "Tankstellen-Shop", x0 = 112, z0 = -280, x1 = 164, z1 = -210, facing = "W", floors = 1, color = { 232, 200, 60 }, canopy = { 68, -292, 102, -196 } },
	{ name = "Feuer-und-Rettungswache", x0 = -425, z0 = -200, x1 = -275, z1 = -100, facing = "W", floors = 3, color = { 200, 70, 55 } },
	{ name = "Polizeiwache", x0 = 215, z0 = 310, x1 = 295, z1 = 380, facing = "S", floors = 3, color = { 70, 110, 200 } },
	{ name = "Krankenhaus", x0 = 340, z0 = -430, x1 = 500, z1 = -310, facing = "W", floors = 5, color = { 90, 170, 150 } },
	{ name = "Kiosk", x0 = -350, z0 = 66, x1 = -300, z1 = 106, facing = "N", floors = 1, color = { 200, 70, 55 } },
	{ name = "Cafe-Terrasse", x0 = -130, z0 = 64, x1 = -66, z1 = 116, facing = "E", floors = 2, color = { 226, 190, 120 } },
	{ name = "Uni-Fassade", x0 = -160, z0 = 130, x1 = -60, z1 = 220, facing = "E", floors = 4, color = { 214, 204, 176 } },
	{ name = "Casino-Odeon", x0 = -200, z0 = 316, x1 = -144, z1 = 360, facing = "E", floors = 2, color = { 70, 56, 84 } },
	{ name = "Kaffeehaus", x0 = 144, z0 = 300, x1 = 194, z1 = 340, facing = "W", floors = 2, color = { 100, 150, 100 } },
	{ name = "Prinz-Eins", x0 = 560, z0 = 330, x1 = 616, z1 = 370, facing = "S", floors = 2, color = { 52, 44, 76 } },
}

end)()

local RoadsPlanner = (function()
-- RoadsPlanner.lua
-- Straßen, Gehwege, Markierungen, Parkbuchten, Plätze, Brücken und die Siegestor-Unterführung als Teileliste.
-- Reine Geometrie (keine Roblox-Funktionen). Teile haben dieselben Felder wie die Häuser aus Planner.lua, dazu optional pitch.

local Geo = Geo

local RoadsPlanner = {}

local COLOR = {
	road = { 84, 90, 96 }, walk = { 168, 172, 174 }, plaza = { 214, 208, 196 }, median = { 118, 150, 98 },
	dash = { 236, 236, 230 }, deck = { 140, 140, 146 }, rail = { 70, 70, 76 }, tunnel = { 110, 110, 116 },
}
local MATERIAL = { road = "Asphalt", walk = "Concrete", plaza = "Pavement", median = "Grass" }
local TOP = { road = 0.5, walk = 1.0, plaza = 0.5, median = 0.8 }
local THICK = { road = 1, walk = 2, plaza = 1, median = 1.8 }

local function part(parts, name, kind, x, y, z, sx, sy, sz, yaw, color, material, extra)
	extra = extra or {}
	parts[#parts + 1] = {
		name = name, kind = kind, size = { sx, sy, sz },
		pos = { Geo.round3(x), Geo.round3(y), Geo.round3(z) },
		yaw = Geo.round3(yaw), pitch = extra.pitch or 0, color = color, material = material,
		collide = extra.collide ~= false, seg = extra.seg,
	}
end

-- Segmente aller Straßen mit Verlängerung an Knicken (hw * tan(Knickwinkel / 2)), damit außen keine Lücke bleibt
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

function RoadsPlanner.segments(cfg)
	return buildSegments(cfg)
end

-- Abschnitte (t-Werte) entlang der Linie P + u*t, die in anderen Straßen liegen
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
	local tun = cfg.tunnel
	local stats = { bays = 0, dashes = 0 }

	for _, seg in ipairs(segs) do
		local yaw = Geo.yawOf(seg.ux, seg.uz)
		local p0x, p0z = seg.ax - seg.ux * seg.extA, seg.az - seg.uz * seg.extA
		local L = seg.len + seg.extA + seg.extB
		local nx, nz = -seg.uz, seg.ux
		-- Tunnelbereich als Abschnitt entlang dieser Straße (nur die Achse läuft in z-Richtung)
		local tunnelCut
		if seg.road.name == tun.road then
			local t0, t1 = (tun.z0 - p0z) * seg.uz, (tun.z1 - p0z) * seg.uz
			if t0 > t1 then t0, t1 = t1, t0 end
			tunnelCut = { t0, t1 }
		end
		local bridgeCuts = {}
		for _, b in ipairs(cfg.archBridges) do
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
			if kind == "walk" then cuts = crossCuts(segs, seg, sx, sz, L, 0.05) end
			if st[4] and tunnelCut then cuts[#cuts + 1] = tunnelCut end
			for _, bc in ipairs(bridgeCuts) do cuts[#cuts + 1] = bc end
			for _, sp in ipairs(Geo.subtract({ { 0, L } }, cuts)) do
				local len = sp[2] - sp[1]
				if len > 0.5 then
					local c = (sp[1] + sp[2]) / 2
					part(parts, string.format("%s_%d_%s", seg.road.name, seg.id, kind), kind, sx + seg.ux * c, TOP[kind] - THICK[kind] / 2, sz + seg.uz * c,
						len, THICK[kind], w, yaw, COLOR[kind], MATERIAL[kind], { seg = seg.id })
				end
			end
		end
		-- gestrichelte Mittel-/Spurlinien
		for _, d in ipairs(seg.prof.dashes) do
			local sx, sz = p0x + nx * d, p0z + nz * d
			local cuts = crossCuts(segs, seg, sx, sz, L, 0.5)
			if seg.prof.dashesUnderground and tunnelCut then cuts[#cuts + 1] = tunnelCut end
			for _, bc in ipairs(bridgeCuts) do cuts[#cuts + 1] = bc end
			for _, sp in ipairs(Geo.subtract({ { 0, L } }, cuts)) do
				local t = sp[1] + 1
				while t + 6 <= sp[2] - 1 do
					local c = t + 3
					part(parts, "Dash", "dash", sx + seg.ux * c, 0.53, sz + seg.uz * c, 6, 0.06, 0.4, yaw, COLOR.dash, "SmoothPlastic", { collide = false, seg = seg.id })
					stats.dashes = stats.dashes + 1
					t = t + 12
				end
			end
		end
	end

	-- Parkbuchten: Trennlinien quer zum Parkstreifen
	for _, b in ipairs(cfg.bays) do
		local x0, z0, x1, z1 = b[1], b[2], b[3], b[4]
		local ux, uz, len = Geo.dir(x0, z0, x1, z1)
		local n = math.floor(len / cfg.bay.length)
		for k = 0, n do
			local x, z = x0 + ux * cfg.bay.length * k, z0 + uz * cfg.bay.length * k
			local sx, sz = (math.abs(ux) > 0.5) and 0.3 or cfg.bay.width, (math.abs(ux) > 0.5) and cfg.bay.width or 0.3
			part(parts, "BayLine", "dash", x, 0.53, z, sx, 0.06, sz, 0, COLOR.dash, "SmoothPlastic", { collide = false })
		end
		stats.bays = stats.bays + n
	end

	for _, pl in ipairs(cfg.plazas) do
		part(parts, "Plaza_" .. pl.name, "plaza", (pl.x0 + pl.x1) / 2, -0.05, (pl.z0 + pl.z1) / 2, pl.x1 - pl.x0, 1, pl.z1 - pl.z0, 0, COLOR.plaza, MATERIAL.plaza, {})
	end

	-- Brücken: Deck unter dem Asphalt (Oberkante -0.5), Geländer an beiden Kanten
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

	-- Gewölbte Isar-Brücken: Fahrbahn und Gehwege als geneigte Platten entlang einer Parabel, Brüstungen, Pfeiler im Fluss
	local STONE = { 196, 188, 172 }
	for _, b in ipairs(cfg.archBridges) do
		local r = math.rad(b.yaw)
		local ux, uz = math.cos(r), -math.sin(r) -- Richtung der Brücke
		local nx2, nz2 = -uz, ux -- quer
		local yawZ = b.yaw + 90 -- lokale z-Achse der Platten läuft entlang der Brücke
		local N = 16
		local function top(s) -- Oberkante der Fahrbahn bei s (Mitte = 0)
			local q = 2 * s / b.len
			return 0.5 + b.peak * (1 - q * q)
		end
		for i = 0, N - 1 do
			local s0, s1 = -b.len / 2 + b.len * i / N, -b.len / 2 + b.len * (i + 1) / N
			local sm = (s0 + s1) / 2
			local y0, y1 = top(s0), top(s1)
			local ym = (y0 + y1) / 2
			local L = math.sqrt((s1 - s0) ^ 2 + (y1 - y0) ^ 2) + 0.2
			local pitch = -math.deg(math.atan2(y1 - y0, s1 - s0)) -- steigt mit s: negativer Pitch
			local cx, cz = b.x + ux * sm, b.z + uz * sm
			local function slab(name, kind, lat, w, thick, up, color, mat)
				part(parts, name, kind, cx + nx2 * lat, ym + up - thick / 2, cz + nz2 * lat, w, thick, L, yawZ, color, mat, { pitch = pitch })
			end
			slab("BrueckeFahrbahn", "road", 0, b.wid, 4, 0, COLOR.road, "Asphalt")
			for _, side in ipairs({ -1, 1 }) do
				slab("BrueckeGehweg", "walk", side * (b.wid / 2 + b.walk / 2), b.walk, 4, 0.5, STONE, "Concrete")
				slab("BrueckeBruestung", "rail", side * (b.wid / 2 + b.walk + 0.6), 1.2, 4.5, 4, STONE, "Concrete")
			end
		end
		for _, side in ipairs({ -1, 1 }) do -- zwei Pfeiler im Fluss, vom Flussbett (-14) bis unter die Fahrbahn
			local s = side * b.len * 0.2
			local deckBottom = top(s) - 4
			part(parts, "BrueckePfeiler", "deck", b.x + ux * s, (deckBottom - 14) / 2, b.z + uz * s, 6, deckBottom + 14, b.wid + 2 * b.walk - 4, b.yaw, STONE, "Concrete", {})
		end
		stats.archBridges = (stats.archBridges or 0) + 1
	end

	-- Unterführung: Rampen (geneigt), Boden, Decke unter der Querstraße, Seitenwände des Tunnelkastens
	local w = tun.half * 2
	local drop = tun.surfaceTop - tun.floorTop
	for _, ramp in ipairs({ { tun.rampN, 1 }, { tun.rampS, -1 } }) do
		local z0, z1 = ramp[1][1], ramp[1][2]
		local dz = z1 - z0
		local L = math.sqrt(dz * dz + drop * drop)
		local ang = math.deg(math.atan2(drop, dz)) -- positiv = fällt nach Süden
		part(parts, "Rampe", "tunnel", 0, (tun.surfaceTop + tun.floorTop) / 2 - 0.5, (z0 + z1) / 2, w, 1, L, 0, COLOR.road, "Asphalt", { pitch = ramp[2] * ang })
	end
	local bz0, bz1 = tun.box[1], tun.box[2]
	part(parts, "TunnelBoden", "tunnel", 0, tun.floorTop - 0.5, (bz0 + bz1) / 2, w, 1, bz1 - bz0, 0, COLOR.road, "Asphalt", {})
	part(parts, "TunnelDecke", "tunnel", 0, -1.1, (bz0 + bz1) / 2, w, 3, bz1 - bz0, 0, COLOR.tunnel, "Concrete", {})
	for _, side in ipairs({ -1, 1 }) do
		part(parts, "TunnelWand", "tunnel", side * (tun.half + 1), tun.floorTop - 1 + 8.75, (bz0 + bz1) / 2, 2, 17.5, bz1 - bz0, 0, COLOR.tunnel, "Concrete", {})
	end
	stats.stalls = stats.bays
	return { parts = parts, stats = stats, segments = segs }
end

return RoadsPlanner

end)()

local TerrainPlanner = (function()
-- TerrainPlanner.lua
-- Liste von Terrain-Operationen (Grundfläche, Parks, Hügel, Terrasse, Isar, Bach, Tunnelgraben).
-- Reine Daten, die Builder.lua mit Terrain:FillBlock / FillCylinder ausführt. Reihenfolge ist wichtig.
-- Op: { op = "block" | "cylinder", material, pos = {x,y,z}, size = {x,y,z} | height, radius, yaw }

local Geo = Geo

local TerrainPlanner = {}

local function block(ops, material, x, y, z, sx, sy, sz, yaw)
	ops[#ops + 1] = { op = "block", material = material, pos = { Geo.round3(x), Geo.round3(y), Geo.round3(z) }, size = { sx, sy, sz }, yaw = Geo.round3(yaw or 0) }
end

-- Wasserlauf als Stapel von Schichten: Luft ausheben (Böschung), danach Wasser bis zur Wasserlinie einfüllen.
local function river(ops, rv)
	local pts, n = rv.pts, #rv.pts
	local dirs = {}
	for i = 1, n - 1 do
		local ux, uz, l = Geo.dir(pts[i][1], pts[i][2], pts[i + 1][1], pts[i + 1][2])
		dirs[i] = { ux, uz, l }
	end
	for pass = 1, 2 do -- 1 = ausheben, 2 = fluten
		for _, ly in ipairs(rv.layers) do
			local top, bot, hw = ly[1], ly[2], ly[3]
			if pass == 1 or top <= rv.waterTop then
				for i = 1, n - 1 do
					local function ext(j)
						if not dirs[j] then return 0 end
						local c = math.max(-1, math.min(1, dirs[i][1] * dirs[j][1] + dirs[i][2] * dirs[j][2]))
						return hw * math.tan(math.acos(c) / 2)
					end
					local eA, eB = (i > 1) and ext(i - 1) or 0, (i < n - 1) and ext(i + 1) or 0
					local L = dirs[i][3] + eA + eB
					local c = (dirs[i][3] + eB - eA) / 2 -- Mitte relativ zum Segmentanfang
					local x, z = pts[i][1] + dirs[i][1] * c, pts[i][2] + dirs[i][2] * c
					block(ops, pass == 1 and "Air" or "Water", x, (top + bot) / 2, z, L, top - bot, hw * 2, Geo.yawOf(dirs[i][1], dirs[i][2]))
				end
			end
		end
	end
end

function TerrainPlanner.plan(cfg)
	local ops = {}
	local m, depth, tile = cfg.map, 20, 512
	-- 1. Boden in Kacheln (ein riesiger Block wäre unhandlich)
	local x = m.xmin
	while x < m.xmax do
		local w = math.min(tile, m.xmax - x)
		local z = m.zmin
		while z < m.zmax do
			local d = math.min(tile, m.zmax - z)
			block(ops, "Pavement", x + w / 2, -depth / 2, z + d / 2, w, depth, d)
			z = z + d
		end
		x = x + w
	end
	-- 2. Grasflächen (oberste 4 Studs)
	for _, p in ipairs(cfg.parks) do
		block(ops, "Grass", (p.x0 + p.x1) / 2, -2, (p.z0 + p.z1) / 2, p.x1 - p.x0, 4, p.z1 - p.z0)
	end
	-- 3. Hügel (gestapelte Zylinder) und Terrasse
	for _, h in ipairs(cfg.hills) do
		for _, ly in ipairs(h.layers) do
			ops[#ops + 1] = { op = "cylinder", material = "Grass", pos = { h.x, (ly[2] + ly[3]) / 2, h.z }, height = ly[3] - ly[2], radius = ly[1] }
		end
	end
	local t = cfg.terrace
	block(ops, "Grass", (t.x0 + t.x1) / 2, t.height / 2, (t.z0 + t.z1) / 2, t.x1 - t.x0, t.height, t.z1 - t.z0)
	-- 4. Tunnelgraben der Siegestor-Unterführung
	local tn = cfg.tunnel
	block(ops, "Air", 0, -8.5, (tn.z0 + tn.z1) / 2, tn.half * 2, 17, tn.z1 - tn.z0)
	-- 5. Isar und Bach
	river(ops, cfg.water.isar)
	river(ops, cfg.water.bach)
	return ops
end

return TerrainPlanner

end)()

local WallPlanner = (function()
-- WallPlanner.lua
-- Mapgrenze: durchgehendes Häuserband (60 tief, ca. 74-110 hoch) rund um die Ringstraße, Fassade zur Straße.
-- Lücken für Querriegel (Nord), Feldherrnhalle (Süd) und die zwei Flusstore (Brückenhäuser mit Gitter).

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
	-- Flusstore: Gebäude über dem Wasser (ab Höhe 22) und ein Gitter an der Kartenkante
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
-- Builder.lua
-- Wandelt die Pläne (Teilelisten, Terrain-Operationen) in Roblox-Instanzen um. Läuft im Studio.
-- Die Roblox-Aufrufe hier sind in der Cloud-Session nur gegen eine Attrappe getestet, nicht gegen echtes Roblox.

local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local Builder = {}

local MATERIALS = {
	SmoothPlastic = Enum.Material.SmoothPlastic, Concrete = Enum.Material.Concrete, Brick = Enum.Material.Brick,
	Glass = Enum.Material.Glass, Wood = Enum.Material.Wood, Metal = Enum.Material.Metal, Asphalt = Enum.Material.Asphalt,
	Pavement = Enum.Material.Pavement, Grass = Enum.Material.Grass, Water = Enum.Material.Water, Air = Enum.Material.Air,
}

local function buildPart(spec, origin)
	local p = Instance.new("Part")
	p.Name = spec.name
	p.Anchored = true
	p.Size = Vector3.new(spec.size[1], spec.size[2], spec.size[3])
	p.CFrame = CFrame.new(origin + Vector3.new(spec.pos[1], spec.pos[2], spec.pos[3]))
		* CFrame.Angles(0, math.rad(spec.yaw), 0) * CFrame.Angles(math.rad(spec.pitch or 0), 0, 0)
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
	return p
end

-- Gibt dem Studio zwischendurch Luft, sonst friert es bei vielen tausend Teilen ein.
local count = 0
local function breathe(every)
	count = count + 1
	if count % every == 0 then task.wait() end
end

-- Liste von Teilen unter parent anlegen
function Builder.buildParts(parts, parent, origin)
	for _, spec in ipairs(parts) do
		buildPart(spec, origin).Parent = parent
		breathe(500)
	end
end

-- Häuser: je Haus ein Model (PrimaryPart = Body)
function Builder.build(plan, parent, origin)
	for _, h in ipairs(plan.houses) do
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

function Builder.applyTerrain(ops, origin)
	local terrain = Workspace.Terrain
	for _, op in ipairs(ops) do
		local cf = CFrame.new(origin + Vector3.new(op.pos[1], op.pos[2], op.pos[3])) * CFrame.Angles(0, math.rad(op.yaw or 0), 0)
		if op.op == "cylinder" then
			terrain:FillCylinder(cf, op.height, op.radius, MATERIALS[op.material])
		else
			terrain:FillBlock(cf, Vector3.new(op.size[1], op.size[2], op.size[3]), MATERIALS[op.material])
		end
		task.wait()
	end
end

function Builder.clearTerrain()
	Workspace.Terrain:Clear()
end

-- Ordner Workspace.Map.<path...>; ein vorhandener letzter Ordner wird ersetzt (Neu-Bauen möglich).
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
-- BuildAll.lua
-- Baut die Karte in einem Rutsch oder schrittweise. Aufruf (Command Bar, Edit-Modus):
--   require(game.ServerStorage.MapBuilder.BuildAll).run()
--   require(game.ServerStorage.MapBuilder.BuildAll).run({ steps = { "roads" } })
-- Optionen: steps (Standard alle), origin (Vector3, Position des Siegestors), seed, only (Blocknamen für "houses"), clearTerrain (true/false)

local Config = Config
local Blocks = Blocks
local Planner = Planner
local Specials = Specials
local RoadsPlanner = RoadsPlanner
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

BuildAll.order = { "terrain", "roads", "houses", "wall" }

function BuildAll.run(opts)
	opts = opts or {}
	local origin = opts.origin or Vector3.new(0, 0, 0)
	for _, name in ipairs(opts.steps or BuildAll.order) do
		local ok, result = pcall(STEPS[name], opts, origin) -- ein fehlerhafter Schritt stoppt die anderen nicht
		print(string.format("[%s] %s", name, ok and result or ("FEHLER: " .. tostring(result))))
	end
	pcall(function() game:GetService("ChangeHistoryService"):SetWaypoint("MapBuilder") end) -- Strg+Z
	print("Fertig")
end

return BuildAll

end)()

local toolbar = plugin:CreateToolbar("Notruf München")
local button = toolbar:CreateButton("Karte bauen", "Terrain, Straßen, Häuser und Mapgrenze bauen", "")
button.Click:Connect(function()
	BuildAll.run({ origin = ORIGIN })
end)
