-- Config.lua
-- Alle Karten-Maße aus docs/MAP_PLAN.md und docs/phase1_bauplan.html als Daten.
-- Koordinaten: x = Ost, z = Süd, Ursprung = Siegestor. Einheiten: Studs. Terrain-Oberkante = Y 0.

local C = {}

-- Oberkante des Terrains im Plan. Etwas unter 0 gewählt, damit die flachen Straßen (Oberkante 0,5) nie im Terrain versinken,
-- egal wie Roblox die 4-Studs-Zellen ausrichtet. BuildAll misst die echte Höhe nach dem Bau und richtet alles daran aus.
C.groundTop = -2

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
	{ name = "Isarspange", profile = "std48", pts = { { 455, -77 }, { 700, -60 }, { 780, -40 }, { 1012, 3 }, { 1030, 70 }, { 1076, 210 } } },
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

-- Isar-Brücken: flache Brücken auf Straßenhöhe (Oberkante 0,5), bleiben oben und tragen auf Säulen im Flussbett und auf den Uferstufen.
-- len = Gesamtlänge entlang der Straße (länger als die Uferböschung, 2 x 90), wid = Fahrbahn, walk = Gehweg je Seite, pier = Abstand der Pfeilerreihen
C.isarBridges = {
	{ name = "B2", x = 887, z = -19, len = 214, wid = 28, walk = 14, yaw = 349.4, pier = 36 },
	{ name = "B3", x = 692, z = 410, len = 252, wid = 28, walk = 14, yaw = 0, pier = 36 }, -- Luitpoldbrücke über Bach und Isar
	{ name = "B4", x = 945, z = -472, len = 214, wid = 28, walk = 14, yaw = 0, pier = 36 },
}

-- Siegestor-Unterführung: die vier Fahrspuren der Achse tauchen unter der Querstraße H2/D ab
C.tunnel = { road = "Achse", half = 34, z0 = -144, rampN = { -144, -8 }, box = { -8, 64 }, rampS = { 64, 200 }, z1 = 200, floorTop = -16.5, surfaceTop = 0.5 }

C.water = {
	isar = {
		pts = { { 945, -556 }, { 945, -472 }, { 930, -330 }, { 915, -200 }, { 895, -90 }, { 885, 0 }, { 850, 100 }, { 800, 200 }, { 750, 300 }, { 705, 390 }, { 695, 410 }, { 670, 494 } },
		-- Böschung in drei Stufen: Uferweg (Oberkante -4, Breite 30), Kiesbank auf Wasserhöhe (-8, Breite 24), dann Wasser bis -14.
		layers = { { 0, -4, 90 }, { -4, -8, 60 }, { -8, -12, 36 }, { -12, -14, 30 } }, waterTop = -8,
		fills = { { -12, -8, 60, "Sand" }, { -8, -4, 90, "Grass" } }, -- Material der beiden Uferstufen (vor dem Ausheben eingefüllt)
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

-- Straßenlaternen nach Foto: hoher, schlanker grauer Mast mit geschwungenem Ausleger und Kopf über der Fahrbahn.
C.lamps = { spacing = 64, inset = 2.5, height = 36 }

-- Ampeln nach Foto: grauer Mast mit Ausleger über die Fahrbahn (arm = Richtung zur Straße), je ein Signalkopf am Ausleger und am Mast.
-- Standort Mast, Blickrichtung des Kopfes (f) zum ankommenden Verkehr. Rechtsverkehr: Achse Süd-Richtung fährt auf der Westseite.
-- Maste stehen auf Gehwegen, nie auf der Fahrbahn.
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
C.pedSignals = { { name = "Siegestor_West", x = -62, z = 8, fx = 1, fz = 0 }, { name = "Siegestor_Ost", x = 62, z = 14, fx = -1, fz = 0 } }

-- Wahrzeichen: Siegestor steht auf dem Tunneldeckel (Mitte = Ursprung), Friedensengel in der Mitte der Terrasse
C.landmarks = {
	siegestor = { x = 0, z = 0, baseY = 0.4 },
	friedensengel = { x = 945, z = 298, baseY = 3.7 },
	frauenkirche = { x = -550, z = 254, baseY = 0.7 }, -- auf der Marienplatz-Insel im Kreisel
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
