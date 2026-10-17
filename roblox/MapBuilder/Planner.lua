-- Planner.lua
-- Reine Geometrie für Häuser (Blockränder, Sonderbauten, Mapgrenze). Keine Roblox-Funktionen, läuft in Luau und in Lua 5.1 (Tests).
-- Koordinaten wie im Kartenplan: x = Ost, z = Süd, y = oben. Einheiten: Studs.
-- Lokales Haus-System: x läuft entlang der Fassade, z zeigt von der Fassade in den Block hinein, y nach oben.
-- Alles, was vor der Wand liegt (Fenster, Gesimse, Balkone), hat lokal z < 0.

local Geo = require(script and script.Parent.Geo or "Geo")

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
-- Fassadenfarben je Stilvariante (Palazzo = Naturstein, Jugendstil = warme Putzfarben, modern = kühles Grau)
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
		lit = extra.lit, tag = extra.tag, text = extra.text, shape = extra.shape, roll = extra.roll, transparency = extra.transparency,
		lpos = { lx, ly, lz },
	}
	h.parts[#h.parts + 1] = part
	return part
end

-- Fläche (face) "front", "+x" oder "-x"; u = Position entlang der Fläche, d = Abstand vor der Wand
local function onFace(h, face, u, d)
	if face == "front" then return u, -d, 0 end
	if face == "back" then return u, h.depth + d, 180 end
	if face == "+x" then return h.width / 2 + d, u, -90 end
	return -h.width / 2 - d, u, 90
end

-- Backsteinkirche der Isar-Allee (neuromanisch): Turm vorn mit Zifferblatt, Glockenstube und Kupferhelm, Mittelschiff mit Satteldach, zwei Seitenschiffe,
-- runde Apsis, Rundbogenfenster, Rosette und Portal. Lokal wie die Häuser: x entlang der Fassade, z in die Tiefe (Fassade zeigt zur Allee), y absolut.
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
	-- Turm und Glockenstube
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
	for _, s in ipairs(Geo.lathe(40, function(h) return 13.8 * (1 - h / 40) ^ 1.15 + 1.1 end, 0.3, 0.5)) do -- Turmhelm: feine Scheiben, Kegel mit geschwungener Spitze ohne sichtbare Stufen
		box("Turmhelm", "roof", 0, y0 + 81.8 + s.y, 9, s.dick, s.d, s.d, COPPER, "Metal", { shape = "Cylinder", roll = 90 })
	end
	box("Turmkugel", "trim", 0, y0 + 123.4, 9, 2.4, 2.4, 2.4, GOLD, "Metal", { shape = "Ball" })
	box("Turmkreuz", "trim", 0, y0 + 127, 9, 0.8, 6, 0.8, GOLD, "Metal")
	box("Turmkreuz", "trim", 0, y0 + 128, 9, 3.6, 0.8, 0.8, GOLD, "Metal")
	-- Zifferblatt (10:10), Portal mit Rundbogen und Stufe, Rosette, Fenster
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
	-- Seitenschiffe (vorn bündig mit dem Turm), Mittelschiff mit Satteldach (Platten um die Tiefenachse geneigt)
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

-- Fenster: Rahmen und Scheibe sitzen vor der Wand (kein Ausschnitt), Fensterbank darunter. shift = zusätzlicher Abstand (Erker).
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

-- Schaufenster der Einkaufsmeile (Leopoldstraße): Vitrine vor der Fassade (nicht begehbar) mit Kulisse je Art: Mode (Schaufensterpuppen, Kleiderstange),
-- Bar (Tresen, Flaschenregal, Neonschild, Hocker), Café (Tische, Stühle, Kuchentheke, Pendelleuchten, Markise), Schuhe (Regale mit Kartons).
local SHOPNAMES = {
	mode = { "MODA LEO", "URBAN STYLE", "SCHICK & CO", "TEXTIL 77", "FASHION HAUS" },
	bar = { "BAR NOIR", "SKYLINE BAR", "LEOS PUB", "CLUB 54" },
	cafe = { "CAFÉ LEOPOLD", "KAFFEEHAUS ROSA", "ESPRESSO BAR", "EISDIELE" },
	schuhe = { "SCHUHHAUS", "SNEAKER BOX", "BOUTIQUE" },
}
local SHOPKINDS = { "mode", "bar", "cafe", "schuhe", "mode", "cafe" }
local BACKDROP = { mode = { 236, 232, 226 }, bar = { 58, 28, 34 }, cafe = { 240, 224, 190 }, schuhe = { 206, 218, 230 } }
local SIGNCOL = { mode = { 30, 30, 34 }, bar = { 24, 20, 30 }, cafe = { 96, 56, 40 }, schuhe = { 34, 60, 96 } }
local CLOTHES = { { 200, 60, 70 }, { 60, 90, 170 }, { 240, 200, 70 }, { 70, 150, 100 }, { 230, 230, 230 }, { 150, 70, 160 } }

local function storefront(h, rng, kind, name, u, w, y0)
	local yb, wh = y0 + 1.8, 9.4 -- Fensterunterkante, Fensterhöhe
	local fl = yb + 0.1 -- Warenboden
	local function put(n, k, lx, y, lz, sx, sy, sz, col, mat, extra) add(h, n, k, u + lx, y, lz, sx, sy, sz, col, mat, extra) end
	local back = BACKDROP[kind]
	put("SchauKulisse", "body", 0, yb + wh / 2, -0.4, w, wh, 0.2, back, "SmoothPlastic")
	put("SchauBoden", "trim", 0, fl, -1.4, w, 0.3, 2.2, kind == "bar" and { 40, 30, 28 } or { 150, 118, 86 }, "Wood")
	for _, sd in ipairs({ -1, 1 }) do put("SchauSeite", "body", sd * (w / 2 - 0.1), yb + wh / 2, -1.3, 0.2, wh, 2.0, back, "SmoothPlastic") end
	put("SchauLicht", "trim", 0, yb + wh - 0.4, -1.2, w - 2, 0.2, 0.5, kind == "bar" and { 255, 90, 150 } or { 255, 236, 190 }, "Neon")
	put("SchauGlas", "glass", 0, yb + wh / 2, -2.3, w, wh, 0.15, { 170, 205, 225 }, "Glass", { tag = "HouseWindow", lit = true })
	put("SchauRahmenOben", "frame", 0, yb + wh + 0.25, -2.3, w + 0.8, 0.5, 0.6, { 40, 40, 44 }, "Metal")
	put("SchauRahmenUnten", "frame", 0, yb - 0.25, -2.3, w + 0.8, 0.5, 0.6, { 40, 40, 44 }, "Metal")
	for _, sd in ipairs({ -1, 1 }) do put("SchauRahmenSeite", "frame", sd * (w / 2 + 0.2), yb + wh / 2, -2.3, 0.5, wh, 0.6, { 40, 40, 44 }, "Metal") end
	if w > 17 then put("SchauSprosse", "frame", 0, yb + wh / 2, -2.3, 0.4, wh, 0.5, { 40, 40, 44 }, "Metal") end
	-- Schild mit Namen über dem Fenster
	put("LadenSchild", "trim", 0, y0 + 12.7, -0.6, w + 1, 2.3, 0.4, SIGNCOL[kind], "SmoothPlastic")
	put("LadenSchrift", "sign", 0, y0 + 12.7, -0.85, w - 1, 1.7, 0.1, { 0, 0, 0 }, "SmoothPlastic", { text = { s = name, color = kind == "bar" and { 255, 120, 190 } or { 244, 238, 220 } } })

	if kind == "mode" then
		local n = math.max(2, math.floor(w / 5))
		for i = 1, n do
			local x = -w / 2 + (i - 0.5) * (w * 0.6 / n) + 1
			local top, pant = rng.pick(CLOTHES), rng.pick({ { 40, 50, 80 }, { 30, 30, 34 }, { 120, 100, 80 } })
			put("PuppePfosten", "trim", x, fl + 1.2, -1.4, 0.2, 2.4, 0.2, { 60, 60, 64 }, "Metal")
			put("PuppeBeine", "trim", x, fl + 3.0, -1.4, 0.9, 3.2, 0.6, pant, "Fabric")
			put("PuppeTorso", "trim", x, fl + 5.8, -1.4, 1.5, 2.6, 0.8, top, "Fabric")
			put("PuppeKopf", "trim", x, fl + 7.5, -1.4, 0.9, 0.9, 0.9, { 226, 214, 200 }, "SmoothPlastic", { shape = "Ball" })
		end
		local rx = w / 2 - w * 0.2 - 1 -- Kleiderstange rechts
		put("Kleiderstange", "trim", rx, fl + 6.4, -0.9, w * 0.34, 0.15, 0.15, { 190, 190, 196 }, "Metal")
		for i = 1, math.max(3, math.floor(w * 0.34 / 1.3)) do
			put("Kleidung", "trim", rx - w * 0.17 + i * 1.3, fl + 5.1, -0.9, 0.9, 2.6, 0.35, rng.pick(CLOTHES), "Fabric")
		end
		put("SaleSchild", "trim", -w / 2 + 2.6, yb + wh - 1.8, -2.0, 3.2, 1.4, 0.1, { 220, 40, 50 }, "SmoothPlastic")
		put("SaleSchrift", "sign", -w / 2 + 2.6, yb + wh - 1.8, -2.08, 3.0, 1.2, 0.1, { 0, 0, 0 }, "SmoothPlastic", { text = { s = "SALE", color = { 255, 255, 255 } } })
	elseif kind == "bar" then
		put("Tresen", "trim", 0, fl + 1.8, -1.0, w * 0.8, 3.6, 1.0, { 92, 56, 36 }, "Wood")
		put("TresenPlatte", "trim", 0, fl + 3.7, -1.15, w * 0.8 + 0.4, 0.3, 1.5, { 30, 24, 22 }, "Wood")
		for _, yy in ipairs({ 5.8, 7.6 }) do
			put("Regalbrett", "trim", 0, fl + yy, -0.6, w * 0.8, 0.2, 0.5, { 120, 84, 56 }, "Wood")
			for i = 1, math.floor(w * 0.8 / 1.4) do
				local col = rng.pick({ { 40, 120, 70 }, { 200, 130, 40 }, { 40, 90, 170 }, { 170, 40, 50 } })
				put("Flasche", "trim", -w * 0.4 + i * 1.4 - 0.7, fl + yy + 0.9, -0.6, 0.5, 1.6, 0.5, col, "Glass", { shape = "Cylinder", roll = 90 })
			end
		end
		for i = 1, math.max(2, math.floor(w / 5)) do
			local x = -w * 0.4 + (i - 0.5) * (w * 0.8 / math.max(2, math.floor(w / 5)))
			put("Hockerbein", "trim", x, fl + 1.1, -2.0, 0.2, 2.2, 0.2, { 80, 80, 86 }, "Metal")
			put("Hockersitz", "trim", x, fl + 2.3, -2.0, 1.1, 0.3, 1.1, { 170, 40, 60 }, "Fabric", { shape = "Cylinder", roll = 90 })
		end
		for _, e in ipairs({ { 0, 8.4, w * 0.5, 0.2 }, { 0, 6.6, w * 0.5, 0.2 } }) do -- Neonröhren im Fenster
			put("Neon", "trim", e[1], fl + e[2] + 0.3, -2.0, e[3], e[4], 0.2, rng.pick({ { 255, 70, 160 }, { 70, 220, 255 } }), "Neon")
		end
	elseif kind == "cafe" then
		for i = 1, 2 do
			local x = -w / 2 + (i - 0.5) * w * 0.28 + 1.5
			put("Tischbein", "trim", x, fl + 1.3, -1.5, 0.2, 2.6, 0.2, { 60, 60, 64 }, "Metal")
			put("Tischplatte", "trim", x, fl + 2.7, -1.5, 0.2, 2.2, 2.2, { 244, 240, 230 }, "SmoothPlastic", { shape = "Cylinder", roll = 90 })
			for _, sd in ipairs({ -1.8, 1.8 }) do
				put("Stuhl", "trim", x + sd, fl + 1.4, -1.5, 1.0, 0.3, 1.0, { 150, 90, 60 }, "Wood")
				put("StuhlLehne", "trim", x + sd * 1.3, fl + 2.6, -1.5, 0.2, 2.2, 1.0, { 150, 90, 60 }, "Wood")
			end
			put("Pendelleuchte", "trim", x, fl + 7.4, -1.5, 1.2, 1.2, 1.2, { 255, 214, 140 }, "Neon", { shape = "Ball" })
		end
		local kx = w / 2 - w * 0.2 -- Kuchentheke rechts
		put("Kuchentheke", "trim", kx, fl + 1.8, -1.0, w * 0.34, 3.6, 1.2, { 236, 226, 210 }, "SmoothPlastic")
		put("KuchenGlas", "glass", kx, fl + 4.1, -1.0, w * 0.34, 1.0, 1.2, { 190, 220, 235 }, "Glass", { tag = "HouseWindow", lit = true })
		for i = 1, math.max(2, math.floor(w * 0.34 / 1.6)) do
			put("Kuchen", "trim", kx - w * 0.17 + i * 1.6 - 0.8, fl + 3.9, -1.0, 1.0, 0.7, 0.9, rng.pick({ { 240, 150, 170 }, { 120, 70, 40 }, { 250, 220, 120 }, { 230, 230, 220 } }), "SmoothPlastic")
		end
		-- gestreifte Markise und Kreidetafel
		local stripes = math.max(4, math.floor(w / 2))
		for i = 1, stripes do
			put("Markise", "trim", -w / 2 + (i - 0.5) * w / stripes, y0 + 11.9, -2.8, w / stripes, 0.3, 2.2, i % 2 == 0 and { 240, 240, 236 } or { 190, 50, 50 }, "Fabric", { pitch = 14 })
		end
		put("Kreidetafel", "trim", -w / 2 + 3, y0 + 2.4, -3.6, 2.2, 3.6, 0.3, { 30, 40, 36 }, "SmoothPlastic", { pitch = 8 })
	else -- schuhe
		for _, yy in ipairs({ 2.4, 4.8, 7.2 }) do
			put("Schuhregal", "trim", 0, fl + yy, -0.9, w - 2, 0.2, 1.0, { 230, 230, 232 }, "SmoothPlastic")
			for i = 1, math.floor((w - 3) / 2.2) do
				put("Schuhkarton", "trim", -w / 2 + 1.5 + i * 2.2 - 1.1, fl + yy + 0.7, -0.9, 1.8, 1.2, 0.8, rng.pick(CLOTHES), "SmoothPlastic")
			end
		end
		put("Podest", "trim", 0, fl + 0.6, -1.6, w * 0.4, 1.0, 1.0, { 40, 40, 44 }, "SmoothPlastic")
		put("PodestSchuh", "trim", 0, fl + 1.5, -1.6, 1.8, 0.8, 0.7, { 220, 50, 50 }, "Fabric")
	end
end

-- Schaufenster auf der Strecke lo..hi (Fassadenmitte u); je 16 bis 20 Studs ein Laden, keine zwei gleichen nebeneinander
local function storefronts(h, lo, hi, y0)
	local rng = newRng(hash(h.name .. "Laden"))
	local ws = hi - lo
	local n = math.max(1, math.min(3, math.floor(ws / 16)))
	local last
	for i = 1, n do
		local kind = rng.pick(SHOPKINDS)
		if kind == last then kind = SHOPKINDS[(rng.int(1, #SHOPKINDS) % 4) + 1] end
		if kind == last then kind = (kind == "bar") and "cafe" or "bar" end
		last = kind
		local w = ws / n
		storefront(h, rng, kind, rng.pick(SHOPNAMES[kind]), lo + (i - 0.5) * w, w - 1.2, y0)
	end
end

local function planHouse(h, o, rng, cornerA, cornerB)
	local W, D = h.width, h.depth
	local floors = rng.weighted(o.floorWeights)
	if h.forceFloors then floors = h.forceFloors end
	if h.floorMul then floors = math.floor(floors * h.floorMul + 0.5) end -- Eckhäuser, die höher gebaut werden
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
	-- Stilvariante für mehr Abwechslung: Palazzo (Rustika, Kranzgesims), Erkerturm, Jugendstil (Terrassenzaun, Gauben), modern (Glasbalkone)
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
	if h.shopStreet and W >= 24 then
		local lo, hi = -W / 2 + 2, W / 2 - 2
		if doorSign > 0 then hi = dx - 4.5 else lo = dx + 4.5 end
		storefronts(h, lo, hi, y0)
	elseif shop then
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

	-- Rückseite zum Innenhof: Fenster in jedem Geschoss, zwei Erdgeschossfenster und eine Hintertür
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

	-- Stildetails je Variante (nur Vorderseite, nicht weiter als 2 Studs über den Blockrand hinaus)
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
					h.floorMul = o.raise and o.raise[h.name]
					h.shopStreet = side.shop
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


-- Hinterhäuser: der Innenhof wird mit niedrigen Häusern (2 bis 3 Geschosse) in einem Raster gefüllt, dazwischen 12 Studs breite Gassen,
-- 14 Studs Abstand zu den Rückseiten der Randhäuser. Sonderflächen (reserved) und das Tankstellen-Grundstück (lot) bleiben mit 10 Studs Rand frei.
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
	for _, side in ipairs(sides) do side.shop = block.shopSide == side.name end
	-- Reservierte Flächen (Sonderbauten) sparen Abschnitte der Randbebauung aus; die Nachbarhäuser werden auf die Restlänge verteilt und
	-- schließen so bündig an die Sonderbauten an (eine durchgehende Häuserlinie).
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


-- Häuserzeile der Isar-Allee (Ostseite): gerade, wie die Allee gegen Nord geneigt, Fassaden zur Allee; dazwischen die Backsteinkirche (allee.church = s-Bereich).
-- Zeilenlaufrichtung nach Norden; Haus-z (in den Block hinein) zeigt nach Osten.
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
	-- Hintergärten: Rasen hinter jedem Haus bis zur Ringstraße (höchstens 40 tief), bei genug Platz zwei Bäume
	local ringInner = cfg.ring.xmax - 48
	for _, hh in ipairs(plan.houses) do
		if hh ~= h then
			local avail = (ringInner - 3 - (hh.ox + hh.depth * math.sin(math.rad(hh.yaw)))) / math.sin(math.rad(hh.yaw))
			local g = math.min(avail, 40)
			if g >= 10 then
				add(hh, "Hintergarten", "garden", 0, 0, hh.depth + 0.5 + g / 2, hh.width - 1, 1, g, { 96, 150, 72 }, "Grass")
				if g >= 24 then
					for _, sd in ipairs({ -1, 1 }) do
						local lx, lz = sd * hh.width / 4, hh.depth + g / 2 + 2 * sd
						add(hh, "HintergartenStamm", "tree", lx, 4, lz, 1.4, 7, 1.4, { 96, 70, 48 }, "Wood", { collide = true })
						add(hh, "HintergartenKrone", "tree", lx, 11, lz, 9, 9, 9, { 74, 128, 62 }, "Grass", { shape = "Ball" })
					end
				end
			end
		end
	end
	return plan
end

-- Häuserzeile am Westufer der Isar gegenüber der Allee (cfg.westbank): Fassade zum Fluss, davor Ufergehweg und Baumstreifen mit Bäumen alle treeStep Studs.
-- Liefert Häuser und freie Teile (plan.parts, Weltkoordinaten). Der Park dahinter liegt in cfg.parks, seine Bäume setzt Garden.
function Planner.planWestbank(cfg, opts)
	local o = mergeOpts(opts)
	local a, w = cfg.allee, cfg.westbank
	local rng = newRng(o.seed + hash("IsarWestufer"))
	local ex, ez = a.uz, -a.ux -- Osten
	local function P(s, d) return a.ax + a.ux * s + ex * d, a.az + a.uz * s + ez * d end
	local yaw = math.deg(math.atan2(-ex, -ez)) % 360
	local sx, sz = P(w.rowFrom, w.front)
	local len = w.rowTo - w.rowFrom
	local plan = { houses = {}, parts = {} }
	planSides("IsarWest", { { name = "W", yaw = yaw, sx = sx, sz = sz, ux = a.ux, uz = a.uz, len = len } }, o, rng, plan, o.depth)
	local perp = 127.5 * a.uz -- Querabstand Allee-Mittellinie zur Isar-Mitte
	local ya = math.deg(math.atan2(-a.uz, a.ux)) % 360 -- Teile längs der Zeile
	local function strip(name, kind, lo, hi, top, thick, color, mat)
		local mx, mz = P((w.rowFrom + w.rowTo) / 2, -(perp + (lo + hi) / 2))
		plan.parts[#plan.parts + 1] = { name = name, kind = kind, size = { len, thick, hi - lo }, pos = { mx, top - thick / 2, mz }, yaw = ya, pitch = 0, color = color, material = mat, collide = true }
	end
	strip("WestuferGehweg", "walk", w.walk[1], w.walk[2], 1.0, 2, { 168, 172, 174 }, "Concrete")
	strip("WestuferGruen", "green", w.green[1], w.green[2], 1.0, 1.8, { 104, 148, 84 }, "Grass")
	local t = w.rowFrom + w.treeStep / 2
	while t < w.rowTo do
		local tx, tz = P(t, -(perp + (w.green[1] + w.green[2]) / 2))
		plan.parts[#plan.parts + 1] = { name = "WestuferStamm", kind = "tree", size = { 1.4, 8, 1.4 }, pos = { tx, 5, tz }, yaw = 0, pitch = 0, color = { 96, 70, 48 }, material = "Wood", collide = true }
		plan.parts[#plan.parts + 1] = { name = "WestuferKrone", kind = "tree", size = { 10, 10, 10 }, pos = { tx, 13, tz }, yaw = 0, pitch = 0, color = { 78, 132, 66 }, material = "Grass", collide = false, shape = "Ball" }
		t = t + w.treeStep
	end
	return plan
end

-- ===== Sonderbauten nach Fotovorlagen (Feuerwache 4 Schwabing, Polizeiinspektion, Klinikum) =====
local DARKG = { 58, 60, 64 }
local GLASS_DARK = { 40, 50, 60 }
local WHITE = { 236, 236, 232 }

-- Fensterband: Glasfelder mit Pfosten und Riegeln zwischen u0 und u1; d = Abstand vor der Wand (negativ = zurückgesetzt).
-- litChance nil = nachts nicht beleuchtet (Tore), sonst Anteil leuchtender Felder.
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

-- Einzelfenster mit hellem Rahmen
local function win(h, o, rng, face, u, yc, w, hgt, frame, glass)
	local lx, lz, ey = onFace(h, face, u, 0.2)
	add(h, "Frame", "frame", lx, yc, lz, w + 1.4, hgt + 1.4, 0.4, frame, "SmoothPlastic", { yaw = ey })
	lx, lz = onFace(h, face, u, 0.4)
	add(h, "Glass", "glass", lx, yc, lz, w, hgt, 0.2, glass, "Glass", { yaw = ey, tag = "HouseWindow", lit = rng.next() < o.litChance })
end

-- Schrift: unsichtbare Platte mit SurfaceGui (Builder), Vorderseite zeigt in Blickrichtung des Teils
local function label(h, face, u, y, d, w, hgt, text, color)
	local lx, lz, ey = onFace(h, face, u, d)
	add(h, "Schrift", "text", lx, y, lz, w, hgt, 0.2, color, "SmoothPlastic", { yaw = ey, text = { s = text, color = color } })
end

-- Feuerwache: durchgehende Fahrzeughalle (hohl) mit 4 Toren vorn (Feuerwehr) und 4 hinten (Rettung), roter Obergeschoss-Block
-- mit Fensterbändern, höherer Kopfbau, Schrift, Mast. Die Tore sind Geisterteile (nicht kollidierend, Tag "FireGate"), damit man
-- schon durchfahren kann; ein späteres Skript kann sie öffnen und schließen.
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

	-- Details: Paneelfugen, Torvorplätze mit gelber Markierung, Blaulichter und Torziffern, Hallenbeleuchtung und Spurlinien,
	-- Solarfeld, Schlauchturm und Lüfter auf dem Dach, Fahnenmasten, Notruf-Emblem
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

-- Polizeiinspektion: roter Sockel, graue Obergeschosse mit hellen Fensterrahmen, Durchfahrt zum Innenhof, blaues Schild
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

	-- Details: dunkle Brüstungsbänder und weiße Fassadenpfeiler, Lamellen-Sonnenschutz, Fugen im roten Sockel, Treppe, Blaulicht,
	-- Treppenhaus-Glasturm am anderen Ende, Dachaufbauten (Technik, Antennen, Solar, Fahne), Brandmauer-Attika
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
	-- Glas-Treppenhausturm am Ostende der Front
	local sx = -W / 2 + 8
	add(h, "Treppenhaus", "glass", sx, y0 + (14 + UP + 6) / 2, -1.2, 12, 14 + UP + 6, 6, { 80, 110, 130 }, "Glass", { collide = true })
	for i = 0, 3 do add(h, "TreppenhausPfosten", "trim", sx - 6 + i * 4, y0 + (14 + UP + 6) / 2, -4.3, 0.6, 14 + UP + 6.4, 0.6, DARKG, "Metal") end
	for k = 0, floors do add(h, "TreppenhausRiegel", "trim", sx, y0 + 1 + k * 12.4, -4.3, 12.4, 0.5, 0.6, DARKG, "Metal") end
	-- Dach: Attika, Technikaufbau, Antennen, Solar, Fahnenmast
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
	-- Durchfahrt: Deckenleuchten und Hinweisschild "Einsatzfahrzeuge frei"
	for i = 0, 2 do add(h, "Durchfahrtlicht", "trim", (a0 + a1) / 2, y0 + 13.7, 8 + i * (D - 16) / 2, 0.2, 2.4, 2.4, { 255, 250, 235 }, "Neon", { shape = "Cylinder", roll = 90 }) end
	local sgx, sgz = onFace(h, "front", a1 + 1.5, 1.6)
	add(h, "HinweisSchild", "trim", sgx, y0 + 9, sgz, 4.2, 4.6, 0.3, { 30, 80, 190 }, "SmoothPlastic")
	label(h, "front", a1 + 1.5, y0 + 9, 1.9, 3.8, 3.8, "Einsatz-\nfahrzeuge\nfrei", { 255, 255, 255 })
end

-- Klinikum: Betonfassade mit auskragenden Geschossplatten und Brüstungsbändern, Fensterbänder, Stützen im Sockel,
-- Glasturm an der Ecke, Schriftzug und senkrechtes Schild
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
	-- Glasturm an der Nordecke (in z-Richtung der Fassade am Ende), springt 12 Studs vor
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


-- Bürogebäude hinter der Tankstelle (nach Foto): dunkle Glasfassade mit weißen Geschossbändern, hohe Stahlpfeiler bis über das Dach,
-- weit auskragendes Dach mit aufgesetztem Oberlichtband. Fassade (vorn) zur Tankstelle, Rückseite ebenfalls verglast.
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

-- Gemeinsame Vorplatz-Bausteine (lokal): Platte in Gehwegoptik (Oberkante 1), Bank, Baum
local function forecourt(h, lx, lz, w, d)
	add(h, "Vorplatz", "trim", lx, 0.5, lz, w, 1, d, { 168, 172, 174 }, "Concrete", { collide = true })
end
local function benchAt(h, lx, lz, yaw)
	add(h, "VorplatzBank", "decor", lx, 2.1, lz, 5, 0.5, 1.6, { 120, 84, 56 }, "Wood", { yaw = yaw, collide = true })
	add(h, "VorplatzBank", "decor", lx, 3.0, lz + ((yaw == 0) and 0.7 or 0), 5, 1.6, 0.3, { 120, 84, 56 }, "Wood", { yaw = yaw })
	for _, sd in ipairs({ -1, 1 }) do add(h, "VorplatzBank", "decor", lx + sd * 2, 1.5, lz, 0.4, 1, 1.2, { 60, 62, 66 }, "Metal", { yaw = yaw }) end
end
local function treeAt(h, lx, lz)
	add(h, "VorplatzStamm", "tree", lx, 4.5, lz, 1.4, 7, 1.4, { 96, 70, 48 }, "Wood", { collide = true })
	add(h, "VorplatzKrone", "tree", lx, 12, lz, 10, 10, 10, { 70, 124, 62 }, "Grass", { shape = "Ball" })
end

-- Kaffeehaus Odeon (grün-weißes Café nach Plan, bewusst ohne echtes Markenlogo): helle Fassade mit grünen Bändern, großes Glasfenster, grünes Vordach
-- mit Schriftzug, rundes Schild mit Kaffeebohne, Terrasse mit Zaun, Tischen, Stühlen und Sonnenschirmen, Menütafel.
local function styleKaffee(h, o, rng)
	local W, D, y0 = h.width, h.depth, o.floorY
	local H = 33
	local CREAM, GREEN, DGREEN, WHITE2 = { 244, 242, 232 }, { 30, 120, 80 }, { 18, 84, 56 }, { 250, 250, 246 }
	h.floors, h.height, h.facade, h.roof = 2, H, CREAM, "flat"
	add(h, "Body", "body", 0, y0 + H / 2, D / 2, W, H, D, CREAM, "SmoothPlastic", { collide = true })
	add(h, "Sockel", "trim", 0, y0 + 1.2, -0.3, W, 2.4, 0.6, DGREEN, "Concrete")
	add(h, "Band", "trim", 0, y0 + 13.2, -0.4, W + 0.6, 1.2, 0.8, GREEN, "SmoothPlastic")
	add(h, "Kranzgesims", "trim", 0, y0 + H - 0.8, -0.8, W + 1, 1.6, 1.6, GREEN, "SmoothPlastic")
	add(h, "Dach", "roof", 0, y0 + H + 0.3, D / 2, W, 0.6, D, { 96, 96, 100 }, "Concrete", { collide = true })
	add(h, "Attika", "trim", 0, y0 + H + 1.6, 0.4, W, 2, 0.8, CREAM, "Concrete")
	for _, lx in ipairs({ -W / 4, W / 4 }) do add(h, "Lueftung", "trim", lx, y0 + H + 2.4, D * 0.6, 5, 3.6, 4, { 170, 176, 180 }, "Metal") end
	-- Glasfront im Erdgeschoss, Tür in der Mitte; Fenster im Obergeschoss
	ribbon(h, o, rng, "front", y0 + 7, 9.4, -W / 2 + 2, -3.6, 4.4, GLASS, DGREEN, 0.3, nil)
	ribbon(h, o, rng, "front", y0 + 7, 9.4, 3.6, W / 2 - 2, 4.4, GLASS, DGREEN, 0.3, nil)
	for _, yy in ipairs({ 18, 25.5 }) do ribbon(h, o, rng, "front", y0 + yy, 4.4, -W / 2 + 2, W / 2 - 2, 6, GLASS, DGREEN, 0.3, o.litChance) end
	for _, sd in ipairs({ -1, 1 }) do
		add(h, "Kaffeetuer", "glass", sd * 1.7, y0 + 4.8, -0.5, 3.2, 9.6, 0.3, { 160, 180, 176 }, "Glass", { tag = "ShopDoor" })
		add(h, "Tuerrahmen", "trim", sd * 3.5, y0 + 5, -0.6, 0.5, 10, 0.5, DGREEN, "Metal")
	end
	add(h, "Tuerrahmen", "trim", 0, y0 + 10.1, -0.6, 7.4, 0.5, 0.5, DGREEN, "Metal")
	for _, face in ipairs({ "+x", "-x" }) do
		ribbon(h, o, rng, face, y0 + 7, 9, 6, D - 6, 8, GLASS, DGREEN, 0.3, o.litChance)
		for _, yy in ipairs({ 18, 25.5 }) do ribbon(h, o, rng, face, y0 + yy, 4.4, 6, D - 6, 8, GLASS, DGREEN, 0.3, o.litChance) end
	end
	-- grünes Vordach mit Schriftzug
	add(h, "Markise", "trim", 0, y0 + 12.2, -3, W - 8, 0.6, 6, GREEN, "Fabric")
	add(h, "MarkiseSaum", "trim", 0, y0 + 11.3, -6, W - 8, 1.8, 0.4, GREEN, "Fabric")
	label(h, "front", 0, y0 + 11.3, 6.3, W - 12, 1.2, "KAFFEEHAUS ODEON", WHITE2)
	-- rundes Schild mit Kaffeebohne (eigenes Zeichen, kein Markenlogo)
	add(h, "SchildRand", "decor", 0, y0 + 18.4, -0.4, 0.6, 9, 9, DGREEN, "Metal", { shape = "Cylinder", yaw = 90 })
	add(h, "SchildGruen", "decor", 0, y0 + 18.4, -0.7, 0.4, 8, 8, GREEN, "SmoothPlastic", { shape = "Cylinder", yaw = 90 })
	add(h, "SchildRing", "decor", 0, y0 + 18.4, -0.9, 0.3, 6.6, 6.6, WHITE2, "SmoothPlastic", { shape = "Cylinder", yaw = 90 })
	add(h, "SchildBohne", "decor", 0, y0 + 18.4, -1.1, 0.3, 4.6, 3, { 92, 56, 36 }, "SmoothPlastic", { shape = "Cylinder", yaw = 90, roll = 25 })
	add(h, "SchildBohneNaht", "decor", 0, y0 + 18.4, -1.3, 0.2, 0.3, 4.4, WHITE2, "SmoothPlastic", { roll = 25 })
	-- Terrasse
	forecourt(h, 0, -13, W + 8, 26)
	for _, sd in ipairs({ -1, 1 }) do
		for _, lz in ipairs({ -8, -14, -20, -25 }) do add(h, "Zaunpfosten", "decor", sd * (W / 2 + 2), 2.4, lz, 0.4, 2.8, 0.4, DGREEN, "Metal", { collide = true }) end
		add(h, "Zaunriegel", "decor", sd * (W / 2 + 2), 3.4, -16.5, 0.3, 0.3, 17.5, DGREEN, "Metal")
	end
	add(h, "Zaunriegel", "decor", 0, 3.4, -25.2, W + 4, 0.3, 0.3, DGREEN, "Metal")
	for _, lx in ipairs({ -W / 2 + 2, W / 2 - 2 }) do for _, lz in ipairs({ -25.2 }) do add(h, "Zaunpfosten", "decor", lx, 2.4, lz, 0.4, 2.8, 0.4, DGREEN, "Metal", { collide = true }) end end
	local ti = 0
	for _, lx in ipairs({ -W / 3, -W / 9, W / 9, W / 3 }) do
		for _, lz in ipairs({ -12, -20 }) do
			ti = ti + 1
			add(h, "Tisch", "decor", lx, 3.4, lz, 0.4, 3.4, 3.4, { 240, 238, 230 }, "SmoothPlastic", { shape = "Cylinder", roll = 90, collide = true })
			add(h, "Tischfuss", "decor", lx, 2.2, lz, 2.2, 0.5, 0.5, { 50, 54, 58 }, "Metal", { shape = "Cylinder", roll = 90 })
			for _, sd in ipairs({ -1, 1 }) do add(h, "Stuhl", "decor", lx + sd * 2.6, 2.5, lz, 1.5, 0.4, 1.5, DGREEN, "Metal", { collide = true }) end
			if ti % 2 == 1 then
				add(h, "SchirmStange", "decor", lx, 5.2, lz, 0.3, 8.4, 0.3, { 200, 200, 196 }, "Metal")
				add(h, "Schirm", "decor", lx, 9.5, lz, 0.3, 9, 9, (ti % 4 == 1) and GREEN or WHITE2, "Fabric", { shape = "Cylinder", roll = 90 })
			end
		end
	end
	for _, sd in ipairs({ -1, 1 }) do -- Pflanzkübel am Eingang, Menütafel
		add(h, "Kuebel", "decor", sd * 7, 1.9, -2.6, 2.8, 1.8, 2.8, { 70, 66, 62 }, "Concrete", { collide = true })
		add(h, "KuebelBusch", "bush", sd * 7, 4.2, -2.6, 4, 4, 4, { 46, 92, 52 }, "Grass", { shape = "Ball" })
	end
	add(h, "MenuTafel", "decor", 8.4, 3.3, -4.2, 3, 4.6, 0.4, { 28, 32, 30 }, "SmoothPlastic", { collide = true })
	label(h, "front", 8.4, y0 + 3.4, 4.5, 2.6, 1.4, "MENUE", WHITE2)
end

-- Parkhaus am Klinikum: Erdgeschoss plus 1. und 2. Stock (je 11 hoch) als offene Decks mit Stützen, Brüstungen, Lamellen an der Front, Stellplatzlinien,
-- Schriftzug, Einfahrt mit Schranke und Kassenhäuschen, Treppenhäusern und einer Auffahrt ins 1. Obergeschoss an der Ostseite (außerhalb des Grundrisses).
local function styleParkhaus(h, o, rng)
	local W, D, y0 = h.width, h.depth, o.floorY
	local CONC, DARK, BLUE, WHITE = { 176, 176, 172 }, { 120, 122, 124 }, { 36, 84, 170 }, { 244, 244, 246 }
	local LV, TOP = 11, 33
	h.floors, h.height, h.facade, h.roof = 3, TOP, CONC, "flat"
	add(h, "Body", "body", 0, y0 + TOP + 0.6, D / 2, W, 1.2, D, CONC, "Concrete", { collide = true }) -- Dach
	for k = 0, 2 do
		local yt = y0 + k * LV
		add(h, "Parkdeck", "trim", 0, yt - 0.6, D / 2, W, 1.2, D, DARK, "Concrete", { collide = true })
		for i = 0, 6 do
			for j = 0, 4 do
				add(h, "Stuetze", "trim", -W / 2 + 1 + i * (W - 2) / 6, yt + LV / 2 - 0.6, 1 + j * (D - 2) / 4, 2, LV - 1.2, 2, CONC, "Concrete", { collide = true })
			end
		end
		add(h, "Bruestung", "trim", 0, yt + 1.7, 0.4, W, 3.4, 0.8, CONC, "Concrete", { collide = true })
		add(h, "Bruestung", "trim", 0, yt + 1.7, D - 0.4, W, 3.4, 0.8, CONC, "Concrete", { collide = true })
		for _, sd in ipairs({ -1, 1 }) do add(h, "Bruestung", "trim", sd * (W / 2 - 0.4), yt + 1.7, D / 2, 0.8, 3.4, D, CONC, "Concrete", { collide = true }) end
		add(h, "Gurt", "trim", 0, yt + LV - 1.8, -0.4, W, 1.2, 0.8, { 150, 150, 146 }, "Concrete")
		for i = 0, math.floor(W / 4) do add(h, "Lamelle", "trim", -W / 2 + 1 + i * (W - 2) / math.floor(W / 4), yt + 6.4, -0.3, 0.7, 5.6, 1, { 190, 190, 186 }, "Concrete") end
		-- Stellplätze: zwei Reihen (vorn und hinten), Fahrgasse in der Mitte, Linien alle 5,4 Studs
		for _, band in ipairs({ { 4, 16 }, { D - 20, 16 } }) do
			for i = 0, 27 do add(h, "StellplatzLinie", "dash", -W / 2 + 6 + i * (W - 12) / 27, yt + 0.06, band[1] + band[2] / 2, 0.3, 0.1, band[2], WHITE, "SmoothPlastic") end
		end
		for i = 0, 8 do add(h, "Deckenlicht", "trim", -W / 2 + 10 + i * (W - 20) / 8, yt + LV - 1.5, D / 2, 4, 0.3, 0.6, { 255, 250, 232 }, "Neon") end
		add(h, "Geschossschild", "decor", -W / 2 + 14, yt + 7.2, 1.2, 8, 2.4, 0.3, BLUE, "SmoothPlastic")
		add(h, "Schrift", "text", -W / 2 + 14, yt + 7.2, 1.0, 7, 1.8, 0.2, WHITE, "SmoothPlastic", { kind = "text", yaw = 180, text = { s = ({ "EG", "1. OG", "2. OG" })[k + 1], color = WHITE } })
	end
	-- Schriftzug und P-Schild
	add(h, "Schildband", "trim", 0, y0 + TOP - 2.4, -1.2, 60, 4.4, 1, BLUE, "SmoothPlastic")
	label(h, "front", 0, y0 + TOP - 2.4, 1.8, 56, 3.2, "PARKHAUS KLINIKUM", WHITE)
	add(h, "Pylon", "decor", W / 2 - 14, y0 + 8, -4, 1, 16, 1, { 80, 82, 86 }, "Metal", { collide = true })
	add(h, "PylonSchild", "decor", W / 2 - 14, y0 + 17, -4, 6, 6, 0.4, BLUE, "SmoothPlastic")
	label(h, "front", W / 2 - 14, y0 + 17, 4.3, 5, 5, "P", WHITE)
	-- Einfahrt (Mitte): Kassenhäuschen und rot-weiße Schranke, Ausfahrt daneben
	for k, u in ipairs({ -10, 10 }) do
		add(h, "Kassenhaeuschen", "trim", u + (k == 1 and -4.5 or 4.5), y0 + 3, -5, 3, 6, 4, WHITE, "SmoothPlastic", { collide = true })
		add(h, "Kassendach", "trim", u + (k == 1 and -4.5 or 4.5), y0 + 6.3, -5, 4.4, 0.6, 5.4, BLUE, "SmoothPlastic")
		for i = 1, 4 do add(h, "Schranke", "trim", u - 3 + (i - 0.5) * 1.5 + (k == 1 and 0 or 0), y0 + 4.2, -5, 1.5, 0.5, 0.5, (i % 2 == 1) and { 200, 40, 40 } or WHITE, "SmoothPlastic", { collide = true, tag = "Schranke", attrs = { Offen = false, Gruppe = k == 1 and "ParkhausEin" or "ParkhausAus" } }) end
	end
	label(h, "front", -10, y0 + 8.4, 6.4, 10, 1.2, "EINFAHRT", { 120, 240, 160 })
	label(h, "front", 10, y0 + 8.4, 6.4, 10, 1.2, "AUSFAHRT", { 255, 150, 120 })
	-- Treppenhäuser an den hinteren Ecken (Glasfront), Fahrstuhlkern
	for _, sd in ipairs({ -1, 1 }) do
		add(h, "Treppenhaus", "trim", sd * (W / 2 - 8), y0 + TOP / 2, D - 7, 10, TOP, 12, { 150, 150, 146 }, "Concrete", { collide = true })
		add(h, "TreppenhausGlas", "glass", sd * (W / 2 - 8), y0 + 8, D - 13.2, 6, 14, 0.3, { 130, 160, 180 }, "Glass", { kind = "glass" })
	end
	-- Auffahrt ins 1. Obergeschoss an der Ostseite (außerhalb des Grundrisses), Neigung 13 Grad
	local rl = 46
	add(h, "Auffahrt", "trim", W / 2 + rl / 2, y0 + LV / 2, 14, math.sqrt(rl * rl + LV * LV), 1, 18, DARK, "Asphalt", { collide = true, roll = -math.deg(math.atan2(LV, rl)) })
	for _, sd in ipairs({ 6, 22 }) do add(h, "AuffahrtMauer", "trim", W / 2 + rl / 2, y0 + LV / 2 + 1.2, sd, math.sqrt(rl * rl + LV * LV), 2.4, 0.6, CONC, "Concrete", { collide = true, roll = -math.deg(math.atan2(LV, rl)) }) end
end

-- Bank (Volksbank, erster grober Entwurf): dreigeschossiger heller Bau mit blauem Sockelband und orangem Akzent, Glasfront mit Schalterhalle, Eingangsvordach mit Drehtür,
-- zwei Geldautomaten, großer Schriftzug "Volksbank" (nur Wortmarke, kein Logo), Vorplatz mit Fahnenmasten.
local function styleBank(h, o, rng)
	local W, D, y0 = h.width, h.depth, o.floorY
	local H = 38
	local BLUE, ORANGE, WHITE, GLASS2 = { 0, 76, 150 }, { 240, 112, 24 }, { 236, 238, 240 }, { 130, 166, 190 }
	h.floors, h.height, h.facade, h.roof = 3, H, WHITE, "flat"
	add(h, "Body", "body", 0, y0 + H / 2, D / 2, W, H, D, WHITE, "SmoothPlastic", { collide = true })
	add(h, "Sockel", "trim", 0, y0 + 1.2, -0.3, W, 2.4, 0.6, { 110, 112, 116 }, "Concrete")
	add(h, "Dach", "roof", 0, y0 + H + 0.3, D / 2, W + 1, 0.6, D + 1, { 96, 96, 100 }, "Concrete", { collide = true })
	add(h, "Attika", "trim", 0, y0 + H + 1.6, 0.4, W + 1, 2, 0.8, WHITE, "Concrete")
	add(h, "BlauBand", "trim", 0, y0 + 14.8, -0.5, W + 0.6, 2.2, 1, BLUE, "SmoothPlastic")
	add(h, "OrangeBand", "trim", 0, y0 + 16.2, -0.6, W + 0.6, 0.6, 1.2, ORANGE, "SmoothPlastic")
	add(h, "BlauBand", "trim", 0, y0 + H - 1, -0.5, W + 0.6, 2, 1, BLUE, "SmoothPlastic")
	ribbon(h, o, rng, "front", y0 + 7.4, 10.4, -W / 2 + 2, -8, 5, GLASS, BLUE, 0.3, nil)
	ribbon(h, o, rng, "front", y0 + 7.4, 10.4, 8, W / 2 - 2, 5, GLASS, BLUE, 0.3, nil)
	for _, row in ipairs({ { 22.5, 6 }, { 31, 5 } }) do
		ribbon(h, o, rng, "front", y0 + row[1], row[2], -W / 2 + 2, W / 2 - 2, 7, GLASS2, { 90, 96, 104 }, 0.3, o.litChance)
		for _, face in ipairs({ "+x", "-x" }) do ribbon(h, o, rng, face, y0 + row[1], row[2], 6, D - 6, 8, GLASS2, { 90, 96, 104 }, 0.3, o.litChance) end
	end
	-- Eingang: Drehtür in Glas, Vordach, Schriftzug
	add(h, "Eingangsrahmen", "trim", 0, y0 + 5.4, -0.4, 9, 10.8, 0.5, BLUE, "Metal")
	add(h, "Drehtuer", "glass", 0, y0 + 5, -0.6, 7, 10, 0.3, { 150, 180, 196 }, "Glass", { tag = "ShopDoor" })
	add(h, "Vordach", "trim", 0, y0 + 12.4, -4, 22, 0.8, 8, BLUE, "SmoothPlastic", { collide = true })
	for _, sd in ipairs({ -1, 1 }) do add(h, "VordachStuetze", "trim", sd * 10, y0 + 6, -7.4, 0.8, 12, 0.8, { 150, 154, 158 }, "Metal", { collide = true }) end
	add(h, "VordachRand", "trim", 0, y0 + 12.4, -8.1, 22.4, 1.2, 0.5, ORANGE, "SmoothPlastic")
	add(h, "Schriftband", "trim", 0, y0 + H - 6.8, -0.7, 54, 7, 0.8, BLUE, "SmoothPlastic")
	label(h, "front", 0, y0 + H - 6.8, 1.2, 50, 5, "Volksbank", WHITE)
	add(h, "SchriftOrange", "trim", 0, y0 + H - 10.7, -0.7, 54, 0.8, 0.8, ORANGE, "SmoothPlastic")
	-- Geldautomaten links neben dem Eingang (Nische mit zwei Geräten) und Öffnungszeiten
	for k, u in ipairs({ -15, -21 }) do
		add(h, "Geldautomat", "trim", u, y0 + 4.2, -1.2, 4.4, 7.4, 2.4, BLUE, "SmoothPlastic", { collide = true })
		add(h, "GeldautomatBildschirm", "decor", u, y0 + 5.6, -2.5, 3, 2.2, 0.2, { 255, 170, 60 }, "Neon")
		add(h, "GeldautomatFach", "decor", u, y0 + 3, -2.5, 3, 0.8, 0.3, { 24, 24, 28 }, "SmoothPlastic")
	end
	label(h, "front", -18, y0 + 9.6, 3, 8, 1.4, "GELD 24 H", ORANGE)
	label(h, "front", 17, y0 + 6.6, 0.7, 9, 3.2, "Mo-Fr 9-17", { 40, 50, 70 })
	-- Vorplatz, Fahnenmaste, Pflanzkübel, Bänke
	add(h, "Vorplatz", "trim", 0, 0.5, -10, W + 6, 1, 20, { 168, 172, 174 }, "Concrete", { collide = true })
	for _, sd in ipairs({ -1, 1 }) do
		add(h, "Fahnenmast", "decor", sd * (W / 2 - 4), y0 + 9, -5, 0.5, 18, 0.5, { 200, 200, 204 }, "Metal", { collide = true })
		add(h, "Fahne", "decor", sd * (W / 2 - 4) + 1.9, y0 + 15, -5, 3.4, 4, 0.2, (sd < 0) and BLUE or ORANGE, "Fabric")
		add(h, "Kuebel", "decor", sd * 14, 1.9, -2.6, 2.8, 1.8, 2.8, { 70, 66, 62 }, "Concrete", { collide = true })
		add(h, "KuebelBusch", "bush", sd * 14, 4.2, -2.6, 4, 4, 4, { 46, 92, 52 }, "Grass", { shape = "Ball" })
	end
	benchAt(h, -W / 2 + 12, -14, 0)
	benchAt(h, W / 2 - 12, -14, 0)
end

local STYLES = { feuerwache = styleFeuerwache, polizei = stylePolizei, klinik = styleKlinik, buero = styleBuero, kaffee = styleKaffee, parkhaus = styleParkhaus, bank = styleBank }


-- Teil in Weltkoordinaten (für Anlagen, die nicht zum Haus-Koordinatensystem passen: Tankstelle, Polizeihof)
local function W3(h, name, kind, x, y, z, sx, sy, sz, color, mat, extra)
	extra = extra or {}
	h.parts[#h.parts + 1] = {
		name = name, kind = kind, size = { round3(sx), round3(sy), round3(sz) }, pos = { round3(x), round3(y), round3(z) }, yaw = extra.yaw or 0, pitch = 0,
		color = color, material = mat, collide = extra.collide == true, lpos = { 0, y, 0 }, tag = extra.tag, attrs = extra.attrs, lit = extra.lit,
		text = extra.text, shape = extra.shape, roll = extra.roll, transparency = extra.transparency,
	}
end

-- Logo: weiße Platte mit rotem "A" (nur der Buchstabe, kein Firmenname). face = "W", "E", "N" oder "S" (Blickrichtung der Vorderseite)
local FACE = { W = { 90, -1, 0 }, E = { 270, 1, 0 }, N = { 0, 0, -1 }, S = { 180, 0, 1 } }
local function logoA(h, x, y, z, size, face)
	local f = FACE[face]
	W3(h, "LogoPlatte", "decor", x + f[2] * 0.05, y, z + f[3] * 0.05, (f[2] ~= 0) and 0.3 or size, size, (f[2] ~= 0) and size or 0.3, { 250, 250, 250 }, "SmoothPlastic")
	W3(h, "Schrift", "text", x + f[2] * 0.25, y, z + f[3] * 0.25, size * 0.85, size * 0.85, 0.2, { 200, 32, 40 }, "SmoothPlastic", { yaw = f[1], text = { s = "A", color = { 200, 32, 40 } } })
end

-- Tankstellen-Shop (nach Beschreibung): weiß mit rotem Band, schließt an die schmale Seite des Schirms an, hohl mit Glasfront zur Straße (West)
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
	-- Glasfassade zur Straße: Scheiben links und rechts der Schiebetür (8 breit), Pfosten, rote Türrahmen
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
	-- Eingang: automatische Schiebetür (zwei Flügel, Antrieb, Sensor) und daneben eine Glastür mit Griff; ohne Kollision, man läuft hinein
	local DK, tx = { 70, 74, 80 }, x0 + 0.6
	for _, zz in ipairs({ cz - 2.65, cz - 0.05 }) do
		W3(h, "Schiebetuer", "glass", tx, 6.2, zz, 0.3, 10.2, 2.6, GL, "Glass", { tag = "ShopDoor" })
		W3(h, "Schiebetuerrahmen", "trim", tx, 1.2, zz, 0.4, 0.4, 2.6, DK, "Metal")
		W3(h, "Schiebetuerrahmen", "trim", tx, 11.2, zz, 0.4, 0.4, 2.6, DK, "Metal")
	end
	W3(h, "Schiebetuerantrieb", "trim", x0 + 0.2, 11.7, cz - 1.35, 0.9, 0.7, 5.6, DK, "Metal")
	W3(h, "Tuersensor", "trim", x0 - 0.1, 11.4, cz - 1.35, 0.3, 0.4, 1.2, { 30, 32, 36 }, "SmoothPlastic")
	W3(h, "Glastuer", "glass", tx, 6.2, cz + 2.75, 0.3, 10.2, 2.5, GL, "Glass", { tag = "ShopDoor" })
	for _, zz in ipairs({ cz + 1.45, cz + 4.05 }) do W3(h, "GlastuerRahmen", "trim", tx, 6.2, zz, 0.5, 10.4, 0.3, DK, "Metal") end
	W3(h, "GlastuerGriff", "trim", x0 - 0.15, 6, cz + 1.9, 0.25, 3, 0.25, { 190, 192, 196 }, "Metal")
	W3(h, "Tuermatte", "decor", x0 - 1.8, 1.2, cz, 3, 0.3, door - 0.4, { 52, 54, 60 }, "Fabric")
	for _, zz in ipairs({ cz - door / 2, cz + door / 2 }) do W3(h, "ShopTuerrahmen", "trim", x0 + 0.6, 6.2, zz, 0.7, 10.6, 0.5, RED, "SmoothPlastic") end
	W3(h, "ShopTuerrahmen", "trim", x0 + 0.6, 11.6, cz, 0.7, 0.5, door, RED, "SmoothPlastic")
	-- Einrichtung: Kasse am Eingang, Regale an der Rückwand
	W3(h, "Kasse", "trim", x0 + 5, 3, cz - 11, 3, 4, 9, { 190, 190, 194 }, "SmoothPlastic", { collide = true })
	for _, zz in ipairs({ z0 + 7, cz + 4, z1 - 7 }) do W3(h, "Regal", "trim", x1 - 3, 4.5, zz, 2.2, 7, 8, { 220, 220, 224 }, "SmoothPlastic", { collide = true }) end
	W3(h, "Kuehlregal", "trim", cx, 4, z1 - 3.5, 12, 6, 2.4, { 150, 190, 215 }, "SmoothPlastic", { collide = true })
end

-- Polizeihof hinter der Durchfahrt: Hof mit Parkbuchten, vier Fahrzeug-Spawnflächen, Zaun zum Hofgarten, Ausfahrt an der Ostseite mit Schranke,
-- Einfahrt durch die Durchfahrt mit Schranke. Alles in Weltkoordinaten; Schranken tragen den Tag "Schranke" (Attribut Offen).
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
	-- Zaun an der Nordkante (lockere Einfriedung, Gitterstäbe alle 4 Studs)
	local fx0, fx1 = spec.x0 + 16, spec.x1 + 2
	W3(h, "ZaunRiegel", "trim", (fx0 + fx1) / 2, 4.6, 296.2, fx1 - fx0, 0.4, 0.4, { 50, 54, 58 }, "Metal")
	W3(h, "ZaunRiegel", "trim", (fx0 + fx1) / 2, 1.6, 296.2, fx1 - fx0, 0.4, 0.4, { 50, 54, 58 }, "Metal")
	for x = fx0, fx1, 4 do W3(h, "ZaunStab", "trim", x, 3, 296.2, 0.3, 3.4, 0.3, { 50, 54, 58 }, "Metal") end
	-- Schranken: Pfosten (rot-weiß) und Arm quer über die Fahrspur, geschlossen
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

-- Allguth-Schirm nach Fotos: flaches weißes Dach, am freien Südende abgerundete Ecken (im Norden schließt der Shop an), rotes Band mit
-- Logo "A", kräftige weiße Stützen in zwei Reihen, Deckenleuchten, zwei Zapfsäulen-Inseln mit weiß-roten Säulen.
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
	-- Stützen: zwei Reihen à vier, kräftig weiß
	for _, px in ipairs({ x0 + 10, x1 - 10 }) do
		for k = 0, 3 do W3(h, "CanopyPillar", "trim", px, 7.5, z0 + 14 + k * (d - 28) / 3, 2.6, 14, 2.6, WHITE, "Concrete", { collide = true }) end
	end
	-- Deckenleuchten (Neon) in drei Reihen
	for _, lx in ipairs({ cx - 18, cx, cx + 18 }) do
		for k = 0, 4 do W3(h, "Deckenlicht", "trim", lx, 13.9, z0 + 10 + k * (d - 20) / 4, 0.2, 1.6, 1.6, { 255, 250, 230 }, "Neon", { shape = "Cylinder", roll = 90 }) end
	end
	-- Zapfsäulen-Inseln: Betonsockel, je vier weiß-rote Säulen mit Display
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

-- Grundstücksausstattung nach Fotos: Rasenstreifen zwischen Gehweg und Tankstelle (nicht an den Einfahrten), Hecke, Büsche,
-- quadratische Logoschilder, Ein-/Ausfahrt-Schilder und das Preis-Totem (Tag "FuelPrice" je Preiszeile für ein späteres Skript).
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
	-- quadratische Logoschilder (weiß mit rotem A), beidseitig lesbar
	local function logoSign(x, zc)
		W3(h, "SchildPfosten", "decor", x, 3.3, zc, 0.4, 4, 0.4, { 80, 82, 86 }, "Metal", { collide = true })
		W3(h, "LogoSchild", "decor", x, 6.5, zc, 4.6, 4.6, 0.3, WHITE, "SmoothPlastic")
		for _, sd in ipairs({ { -1, 0 }, { 1, 180 } }) do
			W3(h, "LogoRot", "decor", x, 6.5, zc + sd[1] * 0.2, 3.2, 3.2, 0.2, RED, "SmoothPlastic")
			W3(h, "Schrift", "text", x, 6.5, zc + sd[1] * 0.4, 3.2, 3.2, 0.2, { 255, 255, 255 }, "SmoothPlastic", { yaw = sd[2], text = { s = "A", color = { 255, 255, 255 } } })
		end
	end
	if sections[1] then logoSign(lx0 + 3, sections[1][1] + 12) end
	-- Ein- und Ausfahrt-Schilder an den Rasenenden
	local function gateSign(zc, label)
		W3(h, "SchildPfosten", "decor", l[1] + 4.5, 2.8, zc, 0.4, 3, 0.4, { 80, 82, 86 }, "Metal", { collide = true })
		W3(h, "FahrtSchild", "decor", l[1] + 4.5, 5.8, zc, 7, 2.6, 0.3, { 36, 70, 110 }, "SmoothPlastic")
		for _, sd in ipairs({ { -1, 0 }, { 1, 180 } }) do
			W3(h, "Schrift", "text", l[1] + 4.5, 5.8, zc + sd[1] * 0.25, 6.4, 2, 0.2, { 255, 255, 255 }, "SmoothPlastic", { yaw = sd[2], text = { s = label, color = { 255, 255, 255 } } })
		end
	end
	if sections[1] then gateSign(sections[1][2] - 1, "AUSFAHRT") end -- am Südende des Nordabschnitts, direkt vor der Ausfahrt
	if sections[2] then gateSign(sections[2][2] - 1, "EINFAHRT") end -- vor der südlichen Einfahrt
	-- Preis-Totem: Stahlpylon mit rotem Kopf (weißes A, ALLGUTH) und schwarzer Preistafel, an beiden Flachseiten
	local tx, tz = l[1] + 6, sections[1] and sections[1][2] - 9 or l[2] + 20
	W3(h, "TotemPylon", "decor", tx, 17.3, tz, 6.2, 32, 1.8, { 70, 74, 80 }, "Metal", { collide = true })
	local fuels = { { "SUPER", "2,29", "Super" }, { "SUPER E10", "2,23", "E10" }, { "SUPER PLUS", "2,39", "SuperPlus" }, { "DIESEL", "2,33", "Diesel" }, { "AUTOGAS", "1,09", "Autogas" } }
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

-- Kundenparkplätze im freien Südteil des Tankstellen-Grundstücks, gegenüber der schmalen Südseite des Schirms (die Fahrzeuge stehen mit der Front zum Schirm):
-- eine Reihe Stellplätze quer zur Fahrgasse mit weißen Linien; kinds = "H" Behindertenparkplatz (blau, Rollstuhlsymbol, Schild), "E" E-Ladeplatz (grüne Fläche,
-- Ladesäule am hinteren Rand, Tag "EVCharger" mit Attributen Station und kW; ohne Überdachung), "N" normaler Platz.
local function parkingLot(h, spec)
	local pk = spec.parking
	local WHITE, BLUE, GREEN, DARK, STEEL = { 244, 244, 246 }, { 36, 84, 170 }, { 40, 168, 110 }, { 24, 28, 34 }, { 80, 82, 86 }
	local n, w, d, x0, zb = #pk.kinds, pk.w, pk.depth, pk.x0, pk.zBack
	local zf = zb - d -- Vorderkante der Stellplätze (Nordseite)
	local zc = (zb + zf) / 2
	for i = 0, n do W3(h, "StellplatzLinie", "dash", x0 + i * w, 1.07, zc, 0.3, 0.1, d, WHITE, "SmoothPlastic") end
	local station = 0
	for i, k in ipairs(pk.kinds) do
		local cx = x0 + (i - 0.5) * w
		if k == "E" then
			station = station + 1
			W3(h, "EVStellplatz", "decor", cx, 1.03, zc, w - 0.5, 0.06, d - 0.4, { 56, 140, 104 }, "SmoothPlastic")
			W3(h, "EVSockel", "decor", cx, 1.3, zb - 1.6, 2.6, 0.6, 2.6, { 190, 188, 182 }, "Concrete", { collide = true })
			W3(h, "EVSaeule", "trim", cx, 4.2, zb - 1.6, 1.8, 6, 1.4, WHITE, "SmoothPlastic", { collide = true, tag = "EVCharger", attrs = { Station = station, kW = 50 } })
			W3(h, "EVKopf", "trim", cx, 7.6, zb - 1.6, 2.2, 1.4, 1.6, GREEN, "SmoothPlastic")
			W3(h, "EVDisplay", "text", cx, 5.8, zb - 2.4, 1.6, 1.4, 0.2, DARK, "SmoothPlastic", { text = { s = "EV", color = { 90, 235, 150 } } })
			W3(h, "EVKabel", "trim", cx + 1.2, 3.2, zb - 2.4, 3.2, 0.35, 0.35, DARK, "SmoothPlastic", { shape = "Cylinder", roll = 90 })
			W3(h, "EVStecker", "trim", cx + 1.2, 1.7, zb - 2.4, 0.6, 0.9, 0.6, GREEN, "SmoothPlastic")
		elseif k == "H" then
			W3(h, "BehindertenStellplatz", "decor", cx, 1.03, zc, w - 0.5, 0.06, d - 0.4, BLUE, "SmoothPlastic")
			-- Rollstuhlsymbol (ISA, weiß auf blau, flach auf dem Boden): Rad als Ring, Kopf, Rumpf, Arm, Oberschenkel, Unterschenkel mit Fußstütze und Gelenkkappen.
			-- Koordinaten (a nach rechts, b nach oben = zum Stellplatzende), aus Sicht des anfahrenden Fahrers (Blick nach Süden, rechts = Westen).
			local sc = 0.75
			local function wx(a) return cx - (a - 4) * sc end
			local function wz(b) return zc + (b - 5) * sc end
			local function disc(a, b, dia, y, color) W3(h, "RollstuhlSymbol", "decor", wx(a), y, wz(b), 0.06, dia * sc, dia * sc, color, "SmoothPlastic", { shape = "Cylinder", roll = 90 }) end
			local function limb(a0, b0, a1, b1, wd)
				local x0, z0, x1, z1 = wx(a0), wz(b0), wx(a1), wz(b1)
				local len = math.sqrt((x1 - x0) ^ 2 + (z1 - z0) ^ 2)
				W3(h, "RollstuhlSymbol", "decor", (x0 + x1) / 2, 1.15, (z0 + z1) / 2, len, 0.06, wd * sc, WHITE, "SmoothPlastic", { yaw = math.deg(math.atan2(-(z1 - z0), x1 - x0)) % 360 })
				disc(a0, b0, wd, 1.15, WHITE)
				disc(a1, b1, wd, 1.15, WHITE)
			end
			disc(3.4, 3.2, 6.4, 1.08, WHITE) -- Rad: weißer Ring um blaue Mitte
			disc(3.4, 3.2, 4.6, 1.10, BLUE)
			disc(3.4, 3.2, 1.0, 1.15, WHITE) -- Nabe
			disc(3.4, 9.0, 2.1, 1.15, WHITE) -- Kopf
			limb(3.4, 7.8, 3.4, 5.0, 1.2) -- Rumpf
			limb(3.4, 7.2, 5.8, 6.1, 0.8) -- Arm zur Greifreifen-Seite
			limb(3.4, 4.8, 6.2, 4.8, 1.1) -- Oberschenkel
			limb(6.2, 4.8, 7.2, 1.4, 1.0) -- Unterschenkel
			limb(7.2, 1.4, 8.4, 1.4, 0.8) -- Fußstütze
			W3(h, "RollstuhlSchildPfosten", "decor", cx - w / 2 + 0.6, 3.3, zb - 0.8, 0.4, 4.6, 0.4, STEEL, "Metal", { collide = true })
			W3(h, "RollstuhlSchild", "decor", cx - w / 2 + 0.6, 6.2, zb - 0.8, 3.2, 3.2, 0.3, BLUE, "SmoothPlastic")
			W3(h, "Schrift", "text", cx - w / 2 + 0.6, 6.2, zb - 1.05, 2.6, 2.6, 0.2, WHITE, "SmoothPlastic", { text = { s = "P", color = WHITE } })
		end
	end
end

-- Öffentlicher Parkplatz (Weltkoordinaten): Asphaltplatte mit Randstein, Stellplätze (8 breit, 16 tief) in einer oder zwei Reihen an den Längsseiten,
-- dazwischen die Fahrgasse, Pfosten mit blauem P-Schild. Querformat (breiter als tief): Reihen im Norden/Süden, Hochformat: Reihen im Westen/Osten.
local function parkingArea(h, r)
	local x0, z0, x1, z1 = r[1], r[2], r[3], r[4]
	local WHITE, KERB = { 244, 244, 246 }, { 190, 188, 182 }
	local w, d, S = x1 - x0, z1 - z0, 8
	W3(h, "Parkplatz", "trim", (x0 + x1) / 2, 0.4, (z0 + z1) / 2, w, 1.2, d, { 78, 80, 86 }, "Asphalt", { collide = true })
	W3(h, "Parkplatzkante", "trim", (x0 + x1) / 2, 1.25, z0 + 0.4, w, 0.5, 0.8, KERB, "Concrete", { collide = true })
	W3(h, "Parkplatzkante", "trim", (x0 + x1) / 2, 1.25, z1 - 0.4, w, 0.5, 0.8, KERB, "Concrete", { collide = true })
	local wide = w >= d
	local len = wide and w or d
	local rows = (math.min(w, d) >= 40) and 2 or 1
	local n = math.floor((len - 2) / S)
	local off = (len - n * S) / 2
	for row = 1, rows do
		for i = 0, n do
			local t = off + i * S
			local back = (row == 1) and 0 or 1 -- Reihe 1 an der Nordkante/Westkante, Reihe 2 an der Gegenkante
			if wide then
				local zc = back == 0 and z0 + 1.2 + 8 or z1 - 1.2 - 8
				W3(h, "StellplatzLinie", "dash", x0 + t, 1.07, zc, 0.3, 0.1, 16, WHITE, "SmoothPlastic")
			else
				local xc = back == 0 and x0 + 1.2 + 8 or x1 - 1.2 - 8
				W3(h, "StellplatzLinie", "dash", xc, 1.07, z0 + t, 16, 0.1, 0.3, WHITE, "SmoothPlastic")
			end
		end
	end
	local px, pz = x0 + 3, z0 + 3
	W3(h, "ParkplatzPfosten", "decor", px, 4, pz, 0.4, 6.6, 0.4, { 80, 82, 86 }, "Metal", { collide = true })
	W3(h, "ParkplatzSchild", "decor", px, 7.6, pz, 3.2, 3.2, 0.3, { 36, 84, 170 }, "SmoothPlastic")
	W3(h, "Schrift", "text", px, 7.6, pz - 0.25, 2.6, 2.6, 0.2, { 255, 255, 255 }, "SmoothPlastic", { text = { s = "P", color = { 255, 255, 255 } } })
end

-- Sonderbau (Bank, Wache, Krankenhaus ...) als Platzhalter-Gebäude auf einer Rechteckfläche.
-- spec = { name, x0, z0, x1, z1, facing = "N"|"S"|"E"|"W" (Seite zur Straße), floors, color, canopy = { x0, z0, x1, z1 } }
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
		if spec.parking then parkingLot(h, spec) end
	end
	for _, r in ipairs(spec.lots or {}) do parkingArea(h, r) end
	if spec.compound then COMPOUNDS[spec.compound](h, spec, o) end
	return { houses = { h } }
end

-- Eckhäuser am Siegestor: je Winkelbereich eine Reihe Fassadenplatten (Häuser gleicher Farbe und Höhe) auf einem Kreis um die Mitte, Front zum Kreisverkehr,
-- die zusammen ein gebogenes Gebäude ergeben (die Platten stoßen an der Front, hinten überlappen sie sich leicht).
function Planner.planCorners(cfg, opts)
	local o = mergeOpts(opts)
	local C = cfg.siegestorCorners
	local cx, cz = cfg.landmarks.siegestor.x, cfg.landmarks.siegestor.z
	local rng = newRng(o.seed + hash("Siegestor-Ecken"))
	local plan = { houses = {} }
	for _, rg in ipairs(C.ranges) do
		local th0, th1 = math.rad(rg.th[1]), math.rad(rg.th[2])
		local n = math.max(1, math.floor((th1 - th0) * C.r0 / o.targetWidth * 2 + 0.5))
		local dth = (th1 - th0) / n
		local color = rng.pick(o.palette)
		for i = 1, n do
			local th = th0 + (i - 0.5) * dth
			local ex, ez = math.cos(th), math.sin(th) -- radial nach außen = Haus-z (in den Block hinein)
			local h = {
				side = "Ecke", index = i, simple = o.simple, rear = true, forceFloors = 5, color = color,
				ox = cx + C.r0 * ex, oz = cz + C.r0 * ez, yaw = math.deg(math.atan2(ex, ez)), width = 2 * C.r0 * math.sin(dth / 2), depth = C.depth, parts = {},
				name = string.format("Eckhaus_%s_%d", rg.name, i),
			}
			planHouse(h, o, rng, false, false)
			plan.houses[#plan.houses + 1] = h
		end
	end
	return plan
end

-- Mapgrenze: Häuserband rund um die Karte, Fassade zeigt nach innen zur Ringstraße.
-- wall = { inner = {xmin,zmin,xmax,zmax} (Ringaußenkante), outer = {...} (Kartenrand), gates = { N = {{x0,x1},...}, S = ... },
--          specials = { { side, name, x0, x1, floors } } }
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
