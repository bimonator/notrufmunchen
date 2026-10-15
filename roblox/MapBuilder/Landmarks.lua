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
	return parts
end

function Landmarks.plan(cfg)
	local parts = {}
	for _, list in ipairs({ Landmarks.siegestor(cfg), Landmarks.friedensengel(cfg) }) do
		for _, p in ipairs(list) do parts[#parts + 1] = p end
	end
	return { parts = parts }
end

return Landmarks
