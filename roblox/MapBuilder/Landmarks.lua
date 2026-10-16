-- Landmarks.lua
-- Wahrzeichen als Teileliste (reine Geometrie): Siegestor (nach Foto: drei Bögen, Säulen, Attika mit Inschrift, Statue) und
-- Friedensengel (Säule mit goldenem Engel in einem Springbrunnenbecken). Teilefelder wie in RoadsPlanner (name, kind, size, pos, yaw, pitch, color, material, collide).

local Geo = require(script and script.Parent.Geo or "Geo")

local Landmarks = {}

local function new(parts, cx, cz)
	-- add(name, x, y, z, sx, sy, sz, color, material, extra): x, z relativ zur Mitte (cx, cz), y absolut; extra = { pitch, collide, text, transparency, shape, roll, yaw }
	return function(name, x, y, z, sx, sy, sz, color, material, extra)
		extra = extra or {}
		parts[#parts + 1] = {
			name = name, kind = extra.kind or "landmark", size = { sx, sy, sz }, pos = { Geo.round3(cx + x), Geo.round3(y), Geo.round3(cz + z) },
			yaw = extra.yaw or 0, pitch = extra.pitch or 0, roll = extra.roll, color = color, material = material, collide = extra.collide ~= false,
			text = extra.text, transparency = extra.transparency, shape = extra.shape,
		}
	end
end

-- Siegestor: Breite 64 (quer zur Achse), Tiefe 12, Höhe bis Attika 58, Statue darüber. Mitte = Ursprung, steht auf dem Tunneldeckel.
-- Öffnungen: Mittelbogen 16 breit (Kämpfer 20, Scheitel 28), Seitenbögen 10 breit (Kämpfer 14, Scheitel 19).
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
	-- Bögen: senkrechte Scheiben, deren Unterkante der Halbkreis bildet
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
	-- Säulen vor den Pfeilern (an Vorder- und Rückseite), mit Sockel und Kapitell
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
	-- Statue (Bavaria mit Lanze) auf Sockel
	local yt = y0 + TOP + 16
	add("StatueSockel", 0, yt + 2, 0, 14, 4, 8, STONE, "Concrete")
	add("StatueRock", 0, yt + 8, 0, 5, 8, 4, BRONZE, "Metal")
	add("StatueTorso", 0, yt + 14, 0, 3.8, 6, 2.8, BRONZE, "Metal")
	add("StatueKopf", 0, yt + 18.2, 0, 2, 2.4, 2, BRONZE, "Metal")
	add("StatueLanze", -3.2, yt + 14, 0, 0.5, 20, 0.5, { 70, 66, 60 }, "Metal", { collide = false })
	add("StatueArm", -1.9, yt + 14.5, 0, 1, 4, 1, BRONZE, "Metal", { collide = false })
	return parts
end

-- Friedensengel: Becken mit Wasser, gestufter Sockel, Säule, Kapitell, goldener Engel mit Flügeln und Palmzweig.
function Landmarks.friedensengel(cfg)
	local parts = {}
	local L = cfg.landmarks.friedensengel
	local add = new(parts, L.x, L.z)
	local y0 = L.baseY
	local STONE, VERD, BRONZE, GOLD, WATER = { 206, 200, 186 }, { 150, 176, 166 }, { 52, 62, 58 }, { 236, 184, 44 }, { 120, 170, 210 }
	add("Rondell", 0, y0 + 0.45, 0, 60, 0.9, 60, STONE, "Concrete") -- Platte, Oberkante y0 + 0,9 (4,6)
	local yb = y0 + 0.9
	for _, e in ipairs({ { 0, -19, 38, 2 }, { 0, 19, 38, 2 } }) do -- Beckenrand (Nord/Süd)
		add("Beckenrand", e[1], yb + 1, e[2], e[3], e[4], 2, STONE, "Concrete")
	end
	for _, e in ipairs({ { -19, 0 }, { 19, 0 } }) do -- Beckenrand (West/Ost)
		add("Beckenrand", e[1], yb + 1, e[2], 2, 2, 36, STONE, "Concrete")
	end
	add("Wasser", 0, yb + 0.9, 0, 36, 0.4, 36, WATER, "SmoothPlastic", { collide = false, transparency = 0.45 })
	add("SockelStufe", 0, yb + 1.5, 0, 22, 3, 22, STONE, "Concrete")
	add("SockelStufe", 0, yb + 4.5, 0, 16, 3, 16, STONE, "Concrete")
	add("SockelStufe", 0, yb + 9, 0, 11, 6, 11, STONE, "Concrete")
	local ys = yb + 12 -- Säulenfuß
	add("SaeuleFuss", 0, ys + 1.5, 0, 3, 9, 9, STONE, "Concrete", { shape = "Cylinder", roll = 90 })
	add("Saeule", 0, ys + 3 + 32, 0, 64, 7, 7, VERD, "Concrete", { shape = "Cylinder", roll = 90 })
	local yk = ys + 3 + 64
	add("Kapitell", 0, yk + 3, 0, 6, 11, 11, BRONZE, "Metal", { shape = "Cylinder", roll = 90 })
	add("Abakus", 0, yk + 7, 0, 11, 2, 11, BRONZE, "Metal")
	add("Trommel", 0, yk + 11, 0, 6, 6.5, 6.5, BRONZE, "Metal", { shape = "Cylinder", roll = 90 })
	local ya = yk + 14
	local k = 1.9 -- Engel größer als maßstäblich, damit er aus der Ferne als goldener Punkt auf der Säule zu erkennen ist
	add("EngelRock", 0, ya + 3 * k, 0, 4.2 * k, 6 * k, 4.2 * k, GOLD, "Metal")
	add("EngelRumpf", 0, ya + 8 * k, 0, 3 * k, 5 * k, 3 * k, GOLD, "Metal")
	add("EngelKopf", 0, ya + 11.4 * k, 0, 2 * k, 2 * k, 2 * k, GOLD, "Metal")
	for _, side in ipairs({ -1, 1 }) do -- Flügel in V-Form quer zur Blickrichtung (nach Westen)
		add("EngelFluegel", 0, ya + 11 * k, side * 3.4 * k, 0.6, 8 * k, 3.6 * k, GOLD, "Metal", { pitch = side * 35, collide = false })
	end
	add("EngelZweig", -2.6 * k, ya + 11 * k, 1.2 * k, 0.5, 7 * k, 0.5, GOLD, "Metal", { collide = false })
	for _, a in ipairs({ { 4.5, 0 }, { -4.5, 0 }, { 0, 4.5 }, { 0, -4.5 } }) do -- Wasserstrahlen am Sockel
		add("Wasserstrahl", a[1], yb + 4, a[2], 0.9, 8, 0.9, { 240, 248, 255 }, "SmoothPlastic", { collide = false, transparency = 0.5 })
	end
	-- Treppe vom Ende der Maximilianstraße (x = Terrasse - 14) zur Terrasse: vier Stufen, Wangenmauern
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

-- Frauenkirche (nach Fotos, nahe am Originalmaßstab von etwa 4 Studs je Meter): langes Backsteinschiff mit hohen Spitzbogenfenstern,
-- riesiges steiles Ziegeldach, zwei sehr hohe Türme mit Uhren und grünen Zwiebelhauben am Westende. Steht auf dem Kirchplatz.
function Landmarks.frauenkirche(cfg)
	local parts = {}
	local L = cfg.landmarks.frauenkirche
	local cxn = (L.x0 + L.x1) / 2
	local add = new(parts, cxn, L.z)
	local y0 = L.baseY
	local BRICK, BRICK2, BAND, ROOF, GREEN, GOLD = { 150, 112, 88 }, { 138, 100, 78 }, { 196, 172, 142 }, { 196, 84, 48 }, { 96, 160, 140 }, { 214, 176, 70 }
	local len, hw, wallH, rise, H = L.x1 - L.x0, L.width / 2, L.wallH, L.roofRise, L.towerH
	add("Sockel", 0, y0 + 1.5, 0, len + 10, 3, 2 * hw + 10, { 150, 148, 142 }, "Concrete")
	local yb = y0 + 3
	add("Schiff", 0, yb + wallH / 2, 0, len, wallH, 2 * hw, BRICK, "Brick", { collide = true })
	add("Gesims", 0, yb + wallH + 1, 0, len + 3, 2, 2 * hw + 3, BAND, "Concrete")
	-- hohe Spitzbogenfenster mit Pfeilern dazwischen, beide Längswände
	local first = -len / 2 + 70 -- hinter den Türmen
	local n = math.floor((len / 2 - 20 - first) / 22) + 1
	for i = 0, n - 1 do
		local wx = first + i * 22
		for _, sd in ipairs({ -1, 1 }) do
			add("Fenster", wx, yb + 31, sd * (hw + 0.4), 8, 44, 0.8, { 50, 62, 78 }, "Glass", { collide = false, kind = "glass", tag = "HouseWindow" })
			add("FensterBogen", wx, yb + 55, sd * (hw + 0.4), 4.4, 6, 0.8, { 50, 62, 78 }, "Glass", { collide = false, kind = "glass" })
			add("FensterPfeiler", wx + 11, yb + wallH / 2, sd * (hw + 1), 3, wallH, 2.4, BAND, "Concrete")
		end
	end
	-- Satteldach mit Überstand, First, Giebelstufen am Ostende
	local run = hw + 3
	local slope = math.sqrt(run * run + rise * rise)
	local ang = math.deg(math.atan2(rise, run))
	for _, sd in ipairs({ -1, 1 }) do
		add("Dach", 0, yb + wallH + rise / 2 + 2, sd * run / 2, len + 6, 1.6, slope, ROOF, "Slate", { pitch = sd * ang })
	end
	add("First", 0, yb + wallH + rise + 3, 0, len + 6, 1.6, 3, { 170, 70, 40 }, "Slate")
	local steps = 12
	for k = 1, steps do
		add("Giebel", len / 2 - 0.8, yb + wallH + (k - 0.5) * rise / steps + 2, 0, 1.6, rise / steps, 2 * hw * (1 - (k - 1) / steps), BRICK, "Brick", { collide = true })
	end
	-- Türme: je 48 breit, am Nord- und Südrand der Westfassade
	local tw, tx = 48, -len / 2 + 24
	for _, sd in ipairs({ -1, 1 }) do
		local tz = sd * (hw - tw / 2)
		add("Turm", tx, yb + H / 2, tz, tw, H, tw, BRICK2, "Brick", { collide = true })
		for _, cxx in ipairs({ -tw / 2 + 1.5, tw / 2 - 1.5 }) do
			for _, czz in ipairs({ -tw / 2 + 1.5, tw / 2 - 1.5 }) do add("TurmEcke", tx + cxx, yb + H / 2, tz + czz, 3, H, 3, BAND, "Concrete") end
		end
		for k = 1, 6 do add("TurmBand", tx, yb + k * 30, tz, tw + 1.6, 2, tw + 1.6, BAND, "Concrete") end
		for _, yy in ipairs({ 45, 90, 135, 180 }) do -- Fensterschlitze an den drei Außenseiten
			add("Turmfenster", tx - tw / 2 - 0.3, yb + yy, tz, 0.8, 18, 5, { 40, 44, 52 }, "Glass", { collide = false, kind = "glass" })
			add("Turmfenster", tx, yb + yy, tz + sd * (tw / 2 + 0.3), 5, 18, 0.8, { 40, 44, 52 }, "Glass", { collide = false, kind = "glass" })
		end
		local clockY = yb + H - 28
		add("Uhr", tx - tw / 2 - 0.5, clockY, tz, 0.8, 18, 18, { 244, 240, 228 }, "SmoothPlastic", { collide = false, shape = "Cylinder" })
		add("Uhr", tx, clockY, tz + sd * (tw / 2 + 0.5), 0.8, 18, 18, { 244, 240, 228 }, "SmoothPlastic", { collide = false, shape = "Cylinder", yaw = 90 })
		add("Trommel", tx, yb + H + 7, tz, 14, tw - 2, tw - 2, BRICK2, "Brick", { shape = "Cylinder", roll = 90, collide = true })
		add("Kuppel", tx, yb + H + 14 + 22, tz, 56, 56, 56, GREEN, "Metal", { shape = "Ball", collide = true })
		add("Laterne", tx, yb + H + 14 + 50 + 6, tz, 14, 12, 12, GREEN, "Metal", { shape = "Cylinder", roll = 90, collide = true })
		add("Spitze", tx, yb + H + 14 + 50 + 16, tz, 8, 8, 8, GOLD, "Metal", { shape = "Ball", collide = false })
		add("Kreuz", tx, yb + H + 14 + 50 + 28, tz, 1.4, 16, 1.4, GOLD, "Metal", { collide = false })
	end
	add("Portal", -len / 2 - 0.4, yb + 14, 0, 1, 28, 14, { 56, 40, 32 }, "Wood", { collide = false })
	add("PortalRahmen", -len / 2 - 0.8, yb + 15, 0, 0.8, 32, 20, BAND, "Concrete", { collide = false })
	return parts
end

-- Chinesischer Turm: fünf Stockwerke aus Holz mit weit ausladenden Dächern, Säulenumgang unten, vergoldete Spitze
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
	for _, list in ipairs({ Landmarks.siegestor(cfg), Landmarks.friedensengel(cfg), Landmarks.frauenkirche(cfg), Landmarks.chinesischerTurm(cfg) }) do
		for _, p in ipairs(list) do parts[#parts + 1] = p end
	end
	return { parts = parts }
end

return Landmarks
