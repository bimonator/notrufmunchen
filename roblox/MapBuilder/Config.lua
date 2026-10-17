-- Config.lua
-- Alle Karten-Maße aus docs/MAP_PLAN.md und docs/phase1_bauplan.html als Daten.
-- Koordinaten: x = Ost, z = Süd, Ursprung = Siegestor. Einheiten: Studs. Terrain-Oberkante = Y 0.

local C = {}

-- Oberkante des Terrains im Plan. Etwas unter 0 gewählt, damit die flachen Straßen (Oberkante 0,5) nie im Terrain versinken,
-- egal wie Roblox die 4-Studs-Zellen ausrichtet. BuildAll misst die echte Höhe nach dem Bau und richtet alles daran aus.
C.groundTop = -2

C.map = { xmin = -745, zmin = -556, xmax = 1260, zmax = 494 } -- Osten um 100 Studs erweitert (Isar-Allee)
C.ring = { xmin = -685, zmin = -496, xmax = 1200, zmax = 434 } -- Außenkante der Ringstraße = Innenkante der Mapgrenze

-- Querschnitte: strips = { von, bis, Art } quer zur Straße (positiv = links der Fahrtrichtung, Normale n = (-uz, ux)).
-- dashes = Versatz der gestrichelten Linien. underground = Streifen entfällt im Tunnelbereich.
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
	-- Isar-Allee, von der Isar (+) zu den Häusern (-): Gehweg am Ufer, Bäume, roter Radweg, Laternenstreifen, Straße mit Parkstreifen, Gehweg vor den Häusern
	allee = {
		half = 35.5, dashes = { -8.5 }, lamps = { offsets = { 3.5 }, spacing = 48 },
		strips = { { -35.5, -27.5, "walk" }, { -27.5, 1.5, "road" }, { 1.5, 5.5, "green" }, { 5.5, 13.5, "bike" }, { 13.5, 25.5, "green" }, { 25.5, 33.5, "walk" } }, -- Ufergehweg 8 breit, endet 3 Studs vor der Böschungskante
	},
	approach86 = { half = 58, dashes = {}, strips = { { -43, 43, "road" } } }, -- Zulauf der Achse zum Kreisverkehr (ohne Mittelstreifen); half 58 hält den Gehweg des Kreisels bis zur Einmündungskurve frei
	kreisel24 = { half = 22, core = 12, dashes = {}, strips = { { -22, -12, "walk" }, { -12, 12, "road" } } }, -- Fahrbahn 24 breit, außen ein Gehweg (10) rund um den Kreisverkehr
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

-- Superellipse |x/a|^p + |z/b|^p = 1 (p = 2 Ellipse, größer = abgerundetes Rechteck); n Punkte, Start im Osten
local function superellipse(cx, cz, a, b, p, n)
	local pts = {}
	for i = 0, n - 1 do
		local t = 2 * math.pi * i / n
		local c, s = math.cos(t), math.sin(t)
		pts[#pts + 1] = { cx + a * (c < 0 and -1 or 1) * math.abs(c) ^ (2 / p), cz + b * (s < 0 and -1 or 1) * math.abs(s) ^ (2 / p) }
	end
	return pts
end

-- Fahrtrichtung der Raster-Straßen: V nach Norden, H nach Osten, damit die Parkseite (positiv) östlich bzw. südlich liegt.
C.roads = {
	{ name = "Ring", closed = true, profile = "std48", pts = { { -661, -472 }, { 1176, -472 }, { 1176, 410 }, { -661, 410 } } },
	-- Leopoldstraße / Ludwigstraße: läuft oben in den Kreisverkehr um das Siegestor (Mittelradius 68, Insel Radius 52)
	{ name = "AchseNord", profile = "axis110", pts = { { 0, -472 }, { 0, -84 } } },
	{ name = "ZulaufNord", profile = "approach86", pts = { { 0, -84 }, { 0, -60 } } },
	{ name = "ZulaufSued", profile = "approach86", pts = { { 0, 60 }, { 0, 84 } } },
	{ name = "AchseSued", profile = "axis110", pts = { { 0, 84 }, { 0, 410 } } },
	{ name = "SiegestorKreisel", closed = true, profile = "kreisel24", pts = circle(0, 0, 68, 96) },
	{ name = "V1", profile = "raster57", pts = { { -460, 30 }, { -460, -472 } } },
	{ name = "V2", profile = "raster57", pts = { { -235, 30 }, { -235, -472 } } },
	{ name = "H1", profile = "raster57", pts = { { -661, -285 }, { 0, -285 } } },
	{ name = "H2", profile = "raster57", pts = { { -661, 30 }, { -61, 30 } } },
	{ name = "Diagonale", profile = "std48", pts = { { 61, 30 }, { 290, 36 }, { 455, -77 }, { 605, -212 }, { 770, -347 }, { 790, -472 } }, lampSpacing = 128 },
	{ name = "Isarspange", profile = "std48", pts = { { 455, -77 }, { 700, -60 }, { 780, -40 }, { 1012, 3 }, { 1030, 70 }, { 1055, 140 }, { 1110, 190 }, { 1176, 210 } }, lampSpacing = 128 },
	{ name = "V3", profile = "std48", pts = { { 300, -472 }, { 300, 32 } } },
	-- Isar-Allee: gerade, parallel zur (geraden) Isar am Ostufer; Mittellinie 127,5 Studs östlich der Isar-Mitte, endet am Knick der Isarspange
	{ name = "IsarAllee", profile = "allee", pts = { { 1072.5, -472 }, { 1012, 3 } } },
	{ name = "Maximilianstrasse", profile = "std48", pts = { { 395, 410 }, { 395, 298 }, { 906, 298 } } }, -- vom Ring über die Maximilianbrücke zum Friedensengel-Oval
	-- Friedensengel-Oval: die Maximilianstraße teilt sich am Westende in zwei Bögen um die Terrasse (wie in München), im Osten wieder zusammen, Ausfahrt zum Ring
	{ name = "FriedensengelRing", closed = true, profile = "std48", pts = superellipse(1013, 298, 107, 62, 2.6, 64) },
	{ name = "FriedensengelAusfahrt", profile = "std48", pts = { { 1120, 298 }, { 1176, 298 } } },
}

-- Skyline (Hochhaeuser.lua): glas = Glasturm mit abgerundeten Ecken (w x d, Eckradius r, Etagen), bmo = Vierzylinder-Turm, schuessel = rundes Schalen-Gebäude.
-- Die Standorte sind in Blocks.lua als reserved eingetragen (dort entfallen die Häuser).
C.hochhaeuser = {
	{ name = "Hochhaus-Klinikum", art = "glas", x = 462, z = -268, w = 64, d = 64, r = 12, floors = 12, label = "ISARTOR" }, -- hinter Volksbank und Krankenhaus
	{ name = "Hochhaus-West", art = "glas", x = -563, z = -127, w = 66, d = 66, r = 14, floors = 15, label = "NOVA" }, -- Block D_West, Richtung Mapende
	{ name = "BMO-Turm", art = "bmo", x = 100, z = -418, floors = 12, radius = 14, versatz = 12.5 },
	{ name = "BMO-Welt", art = "schuessel", x = 164, z = -420, r = 24, bruecke = { x = 126.5, z = -418 } },
	{ name = "Hochhaus-Allguth-Sued", art = "glas", x = 160, z = -22, w = 58, d = 44, r = 11, floors = 10, label = "OPTIMA", pm = 3 },
	{ name = "Hochhaus-Allguth-Nordost", art = "glas", x = 252, z = -424, w = 40, d = 40, r = 9, floors = 9, label = "HELIOS", pm = 3 },
}

-- Eckhäuser, die höher gebaut werden (Faktor auf die Geschosszahl, gerundet; 1,5 = um 50 % erhöht). Schlüssel = Hausname aus dem Planer.
C.eckhaeuser = { Haus_F_LeopoldWestSued_N1 = 1.5, Haus_C_LeopoldWestNord_S2 = 1.5 }

-- Bushaltestellen (Mitte auf dem Gehweg, zurStrasse = Seite, auf der die Fahrbahn liegt). Raster-Straßen: Gehweg 23,5 neben der Mittellinie, std48: 19.
C.busstops = {
	{ x = -436.5, z = -360, zurStrasse = "W" }, { x = -483.5, z = -60, zurStrasse = "E" }, { x = -211.5, z = -130, zurStrasse = "W" },
	{ x = -258.5, z = -380, zurStrasse = "E" }, { x = -560, z = -261.5, zurStrasse = "N" }, { x = -150, z = -308.5, zurStrasse = "S" },
	{ x = -330, z = 53.5, zurStrasse = "N" }, { x = -560, z = 6.5, zurStrasse = "S" }, { x = 281, z = -120, zurStrasse = "E" },
	{ x = 319, z = -380, zurStrasse = "W" }, { x = 49, z = -380, zurStrasse = "W" }, { x = -49, z = -200, zurStrasse = "E" },
	{ x = 49, z = 200, zurStrasse = "W" }, { x = -49, z = 250, zurStrasse = "E" }, { x = 600, z = 317, zurStrasse = "N" },
	{ x = 700, z = 279, zurStrasse = "S" }, { x = -642, z = -100, zurStrasse = "W" }, { x = 40, z = -453, zurStrasse = "N" },
}

-- Parkbuchten: Mittellinie des Parkstreifens, Buchtlänge 16, Breite 9. { x0, z0, x1, z1 }
C.bay = { length = 16, width = 9 }
-- Allguth-Tankstelle (southOpen = x-Bereich, in dem die Südkante offen ist: Durchfahrt zum Werkstatt-Hof): Grundstück und Ein-/Ausfahrten (z-Bereiche an der Straße, Einfahrt südlich, Ausfahrt nördlich davon).
-- Vor den Einfahrten gibt es keine Parkbuchten und die Laternen stehen nicht im Weg (siehe driveways).
C.tankstelle = { lot = { 57, -336, 180, -150 }, gaps = { { -262, -218 }, { -196, -152 } }, southOpen = { 88, 180 }, parking = { x0 = 80, zBack = -152, depth = 16, w = 8, kinds = { "H", "E", "E", "E", "N", "N", "N", "N", "N", "N" } } } -- parking: Stellplatzreihe im Südteil (H Behinderte, E Ladeplatz, N normal)
-- Autohaus (Autohaus.lua): Grundstück östlich der V3, nördlich der Diagonale; Westwand bei frontX, Showroom und Werkstatt als z-Bereiche (Nord nach Süd)
C.autohaus = { x0 = 332, z0 = -196, x1 = 442, z1 = -116, frontX = 394, showroom = { -170, -122 }, werkstatt = { -196, -170 },
	-- Vorfeld im Dreieck südlich (bis zum Gehweg der Diagonale): Stellplatzreihen als z-Bereiche, margin = Rasenstreifen zum Gehweg, trees/lamps = x-Lagen
	vorfeld = { road = "Diagonale", margin = 5, rows = { { -114, -98 }, { -80, -64 } }, zMax = -20, trees = { 352, 372, 396, 420, 438 }, lamps = { 372, 404 } } }
-- Werkstatt (Werkstatt.lua): Hof (gleicher Asphalt wie die Tankstelle, schließt an deren offene Südkante an), Halle mit Front nach Süden; gate = z-Bereich der offenen Zaunlücke an der Ostseite
C.werkstatt = { x0 = 88, z0 = -150, x1 = 186, z1 = -90, hall = { 104, 160 }, hallOffset = 14, depth = 22, gate = { -110, -98 } }

-- Tram (blau, Pendel): Linie vom Biederstein (Westen) über Josephsplatz, Karolinenplatz, die Mittelinsel der Achse und den Nordring, die Diagonale und die Isarspange
-- zum Isartor an der V3. route = Eckpunkte { x, z, Rundungsradius } auf den Straßenmitten; stops liegen auf der Strecke, aufsteigend vom Biederstein zum Isartor.
-- Wagen: 2 x carLen mit Gelenk gap; bed = Breite des Gleisbetts, gauge = Schienenabstand; Fahrdaten in Studs/s, Studs/s^2 und Sekunden; platform = Bahnsteig { Länge, Abstand der Kante zur Gleismitte, Breite }.
C.tram = {
	route = { { -460, -382, 0 }, { -460, 30, 40 }, { -235, 30, 40 }, { -235, -285, 40 }, { 0, -285, 40 }, { 0, -472, 40 }, { 790, -472, 30 }, { 770, -347, 70 },
		{ 605, -212, 100 }, { 455, -77, 100 }, { 300, 29.15, 22 }, { 300, -229, 0 } },
	stops = {
		{ name = "Biederstein", x = -460, z = -346 }, { name = "Hohenzollernplatz", x = -460, z = -45 }, { name = "Josephsplatz", x = -235, z = -45 },
		{ name = "Karolinenplatz", x = -140, z = -285 }, { name = "Nordring", x = 436, z = -472 }, { name = "Klinikum", x = 514, z = -130 }, { name = "Isartor", x = 300, z = -193 },
	},
	carLen = 16, gap = 2.6, width = 7.4, bed = 7, gauge = 3.6,
	speed = 34, accel = 7, dwell = 12, dwellEnd = 20,
	platform = { len = 40, off = 5.2, w = 6.4 },
}
C.driveways = {}
for _, g in ipairs(C.tankstelle.gaps) do C.driveways[#C.driveways + 1] = { x0 = 43, x1 = 57, z0 = g[1] - 3, z1 = g[2] + 3 } end

-- Einfahrten über den Gehweg (RoadsPlanner): Rechteck von der Fahrbahnkante bis zur Grundstücksgrenze, dir = Richtung von der Straße ins Grundstück.
-- Der Gehweg bekommt dort eine Kerbe: abgesenkter Bordstein (Rampe), Asphalt auf Gehwegebene, Rampe zum Grundstück.
C.einfahrten = {
	{ name = "Autohaus-Werkstatt", x0 = 314, z0 = -190, x1 = 332, z1 = -176, dir = "E" }, -- V3, Ostseite
	{ name = "Autohaus-Kunden", x0 = 314, z0 = -146, x1 = 332, z1 = -130, dir = "E" },
	{ name = "Autohaus-Vorfeld", x0 = 314, z0 = -97, x1 = 332, z1 = -81, dir = "E" },
	{ name = "Krankenhaus-Notaufnahme", x0 = 314, z0 = -356, x1 = 340, z1 = -340, dir = "E" },
	{ name = "Prinz-Eins-Parkplatz", x0 = 409, z0 = 358, x1 = 436, z1 = 374, dir = "E" }, -- Maximilianstraße, Ostseite
	{ name = "Kaffeehaus-Parkplatz", x0 = 150, z0 = 384, x1 = 166, z1 = 396, dir = "N" }, -- Ring Süd
	{ name = "Polizei-Einfahrt", x0 = 224, z0 = 384, x1 = 238, z1 = 396, dir = "N" },
	{ name = "Polizei-Ausfahrt", x0 = 344, z0 = 384, x1 = 362, z1 = 396, dir = "N" },
	{ name = "Klinik-Parkhaus-Einfahrt", x0 = 564, z0 = -458, x1 = 576, z1 = -430, dir = "S" }, -- Ring Nord
	{ name = "Klinik-Parkhaus-Ausfahrt", x0 = 584, z0 = -458, x1 = 596, z1 = -430, dir = "S" },
}
for _, bz in ipairs({ -186.6, -162.2, -137.8, -113.4 }) do -- Feuerwache: vier Tore zur V1
	C.einfahrten[#C.einfahrten + 1] = { name = "Feuerwache-Tor", x0 = -441.5, z0 = bz - 10, x1 = -429.5, z1 = bz + 10, dir = "E" }
end
for _, e in ipairs(C.einfahrten) do C.driveways[#C.driveways + 1] = { x0 = e.x0, x1 = e.x1, z0 = e.z0, z1 = e.z1 } end

C.bays = {
	{ 38.5, -448, 38.5, -340 }, { 38.5, -334, 38.5, -274 }, { 38.5, -140, 38.5, -98 }, -- Achse Ost: Lücke vor der Tankstelleneinfahrt
	{ -38.5, -448, -38.5, -314 }, { -38.5, -257, -38.5, -98 }, { -38.5, 98, -38.5, 226 }, { 38.5, 98, 38.5, 286 },
	{ -633, -271, -497, -271 }, { -432, -271, -272, -271 }, { -207, -271, -59, -271 },
	{ -633, 44, -578, 44 }, { -522, 44, -497, 44 }, { -432, 44, -272, 44 }, { -207, 44, -59, 44 },
	{ -446, -448, -446, -317 }, { -446, -253, -446, -211 }, { -446, -89, -446, -3 },
	{ -221, -448, -221, -317 }, { -221, -253, -221, -3 },
}

-- Isar-Allee (Ostufer): Straße IsarAllee von Norden (Ring) nach Süden (Isarspange); Parameter s = Abstand vom Nordende entlang der Mittellinie.
-- Fassadenlinie der Häuserzeile = Gehwegkante der Häuser (35,5 östlich der Mittellinie) + Abstand 2; Zeile von s = 28 bis 436, die Kirche steht bei s = 190 bis 244.
-- Parkbuchten liegen 23 Studs östlich der Mittellinie.
-- Westufer gegenüber der Allee: Häuserzeile (Fassade 116 Studs westlich der Isar-Mitte, Blick zum Fluss), davor Ufergehweg (Abstand 93 bis 101 von der Isar-Mitte)
-- und Baumstreifen (101 bis 113), dahinter ein Park (C.parks). rowFrom/rowTo = s-Bereich entlang der Allee-Mittellinie (wie allee.church).
C.westbank = { rowFrom = 183, rowTo = 370, front = -(127.5 * 0.9921 + 116), walk = { 93, 101 }, green = { 101, 113 }, treeStep = 24 }
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

-- Gestaltete Anlagen (Anlagen.lua): Polygon, Wege { pts, w, benchStep, lampStep }, Teiche { x, z, r }, Beete { x, z, Spalten, Reihen } (5x5-Felder), Baumreihen, freie Bäume
-- { step, density, scale, edge }, Büsche, Findlinge. Alle Flächen liegen in Lücken zwischen Straßen und Häusern (aus dem Kartenbild abgelesen).
local function ringPath(cx, cz, r, n)
	local pts = circle(cx, cz, r, n)
	pts[#pts + 1] = pts[1]
	return pts
end
C.anlagen = {
	{ name = "AlleeSchlossgarten", seed = 3, poly = { { 68, 62 }, { 392, 62 }, { 392, 97 }, { 68, 97 } },
		paths = { { pts = { { 68, 80 }, { 214, 80 } }, w = 10, benchStep = 52, lampStep = 64 }, { pts = { { 246, 80 }, { 392, 80 } }, w = 10, benchStep = 52, lampStep = 64 },
			{ pts = ringPath(230, 80, 16, 16), w = 5 } },
		ponds = { { 230, 80, 8 } },
		rows = { { z = 71, x0 = 80, x1 = 208, step = 14 }, { z = 71, x0 = 256, x1 = 384, step = 14 }, { z = 89, x0 = 80, x1 = 208, step = 14 }, { z = 89, x0 = 256, x1 = 384, step = 14 } },
		bushes = 10 },
	{ name = "Klinikpark", seed = 5, poly = { { 506, -306 }, { 675, -306 }, { 586, -233 }, { 452, -112 }, { 446, -232 }, { 506, -232 } },
		paths = { { pts = { { 470, -150 }, { 506, -176 }, { 546, -214 }, { 586, -250 }, { 628, -286 }, { 646, -298 } }, w = 8, benchStep = 44, lampStep = 48 },
			{ pts = ringPath(545, -262, 26, 20), w = 6, benchStep = 40 },
			{ pts = { { 546, -214 }, { 545, -236 } }, w = 5 }, { pts = { { 571, -262 }, { 593, -256 } }, w = 5 },
			{ pts = { { 470, -150 }, { 466, -190 }, { 484, -222 }, { 512, -228 }, { 522, -244 }, { 519, -262 } }, w = 5, benchStep = 40 } },
		ponds = { { 545, -262, 16 } }, beds = { { 478, -190, 4, 2 } },
		trees = { step = 12, density = 0.8, scale = 1.05, edge = 8 }, bushes = 24 },
	{ name = "KlinikparkSued", seed = 6, poly = { { 540, -108 }, { 622, -108 }, { 622, -180 } },
		paths = { { pts = { { 556, -114 }, { 600, -118 }, { 616, -150 } }, w = 5, benchStep = 36, lampStep = 56 } },
		trees = { step = 12, density = 0.85, scale = 1.0, edge = 6 }, bushes = 6 },
	{ name = "UferWestNord", seed = 7, poly = { { 672, -436 }, { 757, -436 }, { 745, -366 }, { 705, -330 }, { 672, -330 } },
		paths = { { pts = { { 686, -428 }, { 700, -380 }, { 692, -342 } }, w = 5, benchStep = 36 } },
		trees = { step = 13, density = 0.8, scale = 1.0, edge = 8 }, bushes = 14 },
	{ name = "UferWestPromenade", seed = 9, willow = true, poly = { { 820, -440 }, { 846, -440 }, { 846, -328 }, { 820, -328 } },
		paths = { { pts = { { 833, -436 }, { 833, -332 } }, w = 5, benchStep = 40, lampStep = 56 } },
		trees = { step = 11, density = 0.85, scale = 0.95, edge = 5 }, bushes = 6, rocks = 4 },
	{ name = "UferWestMitte", seed = 13, willow = true, poly = { { 708, 4 }, { 772, 4 }, { 758, 62 }, { 740, 120 }, { 724, 170 }, { 708, 170 } },
		paths = { { pts = { { 722, 10 }, { 734, 60 }, { 720, 120 }, { 716, 164 } }, w = 5, benchStep = 36, lampStep = 60 } },
		trees = { step = 12, density = 0.8, scale = 1.0, edge = 7 }, bushes = 12, rocks = 6 },
	{ name = "UferOst", seed = 17, willow = true, poly = { { 1066, -14 }, { 1150, -14 }, { 1150, 160 }, { 1132, 160 }, { 1100, 128 }, { 1086, 92 }, { 1068, 36 } },
		paths = { { pts = { { 1112, -8 }, { 1118, 60 }, { 1130, 120 }, { 1140, 154 } }, w = 5, benchStep = 40, lampStep = 60 } },
		trees = { step = 12, density = 0.8, scale = 1.0, edge = 7 }, bushes = 12, rocks = 5 },
	{ name = "UferFriedensengel", seed = 19, poly = { { 970, 46 }, { 984, 46 }, { 1000, 100 }, { 1016, 142 }, { 1036, 172 }, { 1066, 198 }, { 900, 198 }, { 930, 142 }, { 946, 100 } },
		paths = { { pts = { { 976, 54 }, { 972, 100 }, { 958, 140 }, { 940, 188 } }, w = 5, benchStep = 36, lampStep = 56 } },
		beds = { { 988, 150, 3, 2 } },
		trees = { step = 12, density = 0.8, scale = 1.0, edge = 7 }, bushes = 10, rocks = 3 },
}

-- Gepflasterte Plätze (Odeonsplatz, Kirchplatz, Fußgängerzone) sind vorerst entfernt: die Leopoldstraße bleibt Asphalt, um die Frauenkirche liegt kein Pflaster.
C.plazas = {}

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
	-- Maximilianbrücke: zwei flache Segmentbögen über einen Mittelpfeiler mit Statuen, führt von der Maximilianstraße zur Friedensengel-Terrasse
	{ name = "B6", style = "maximilian", x = 751, z = 298, len = 244, wid = 28, walk = 14, yaw = 0, span = 60, rise = 4.5, culvert = { s = -95.8, w = 38 } }, -- culvert: Durchlass für den Eisbach im westlichen Widerlager (s = Abstand von der Brückenmitte, w = Breite)
}

C.water = {
	isar = {
		pts = { { 945, -556 }, { 945, -472 }, { 885, 0 }, { 850, 100 }, { 800, 200 }, { 750, 300 }, { 705, 390 }, { 695, 410 }, { 670, 494 } },
		-- Böschung in drei Stufen: Uferweg (Oberkante -4, Breite 30), Kiesbank auf Wasserhöhe (-8, Breite 24), dann Wasser bis -14.
		layers = { { 0, -4, 90 }, { -4, -8, 60 }, { -8, -12, 36 }, { -12, -14, 30 } }, waterTop = -8,
		fills = { { -18, -12, 36, "Sand" }, { -12, -8, 60, "Sand" }, { -8, -4, 90, "Grass" } }, -- Sandbett, Kiesbank und Gras-Uferweg (vor dem Ausheben eingefüllt)
	},
	bach = {
		pts = { { 640, -257 }, { 642, -226 }, { 665, -31 }, { 672, 194 }, { 650, 330 }, { 620, 410 }, { 612, 494 } },
		layers = { { 0, -4, 13 }, { -4, -7, 7 } }, waterTop = -4,
		fills = { { -11, -4, 13, "Sand" } }, -- Bachbett und Böschung aus Sand
	},
	-- Eisbach-Kanal: gemauertes Stück unter der Maximilianbrücke bis vor die Luitpoldbrücke, gleiche Mittellinie wie der Bach (Teilstück von bach.pts),
	-- aber senkrechte Wände (26 breit, Wasser bis -4, Sohle -8) statt Sandböschung. Mauern und Welle: Garden.lua. bank = Erdstreifen neben dem Kanal.
	kanal = {
		pts = { { 661, 262 }, { 650, 330 }, { 632, 378 } },
		layers = { { 0, -4, 13 }, { -4, -8, 13 } }, waterTop = -4,
		fills = { { -12, -8, 13, "Slate" } },
		bank = { from = 14, width = 16, zmin = 326, material = "Ground" },
	},
}

-- Eckhäuser am Siegestor: gebogene Gebäude (Fassadenplatten auf dem Kreis um die Mitte, Radius r0 = Außenkante des Gehwegs + Abstand), Winkelbereiche in Grad (z nach Süden)
-- Einmündungen am Kreisverkehr: Gehweg der Zufahrt geht in einer S-Kurve in den Gehweg des Kreisels über. r0/r1 = Innen-/Außenkante des Kreisel-Gehwegs (gemittelt über
-- die 24-Eck-Facetten), rho = Radius der Bordsteinrundung, arms: p0 = Punkt auf der Straßenachse, u = Richtung vom Kreisel weg, d0/d1 = Gehweg (Abstand von der Achse),
-- cut = Gehweg der Straße endet vor der Kurve (sonst endet er schon an p0).
C.kreiselEcken = {
	r0 = 80, r1 = 90, rho = 14,
	arms = {
		{ road = "AchseNord", p0 = { 0, -84 }, u = { 0, -1 }, d0 = 43, d1 = 55 },
		{ road = "AchseSued", p0 = { 0, 84 }, u = { 0, 1 }, d0 = 43, d1 = 55 },
		{ road = "H2", p0 = { -61, 30 }, u = { -1, 0 }, d0 = 18.5, d1 = 28.5, cut = true },
		{ road = "Diagonale", p0 = { 61, 30 }, u = { 229, 6 }, d0 = 14, d1 = 24, cut = true },
	},
}
C.siegestorCorners = { r0 = 92, depth = 28, ranges = { { name = "Nordwest", th = { 186, 223 } }, { name = "Nordost", th = { 317, 354 } } } }

C.parks = { -- Gras-Oberfläche (Terrain)
	{ name = "WestuferParkNord", x0 = 700, z0 = -292, x1 = 748, z1 = -200 }, -- Hintergarten der Westufer-Häuser
	{ name = "WestuferParkSued", x0 = 640, z0 = -200, x1 = 748, z1 = -104 },
	{ name = "EckgartenNordwest", x0 = -125, z0 = -90, x1 = -57, z1 = 0 }, -- Hintergärten hinter den Eckhäusern am Siegestor
	{ name = "EckgartenNordost", x0 = 57, z0 = -90, x1 = 125, z1 = 4 },
	{ name = "Hofgarten", x0 = 60, z0 = 100, x1 = 400, z1 = 290 },
	{ name = "EnglischerGarten", x0 = 430, z0 = -45, x1 = 700, z1 = 345 },
	{ name = "Hinterhofpark", x0 = -401.5, z0 = -418, x1 = -293.5, z1 = -343.5 },
}
C.hills = { { name = "Monopteros", x = 575, z = 75, layers = { { 44, 0, 4 }, { 30, 4, 8 } } } } -- { Radius, y0, y1 }, nur 8 hoch
-- Terrasse des Friedensengels: Rasen-Insel in Form der Superellipse (Mitte cx, cz, Halbachsen a, b, Exponent p) innerhalb des Straßenovals, 26 Studs
-- Abstand zur Mittellinie; x0..z1 = Umgebungsrechteck
C.terrace = { name = "Friedensengel", cx = 1013, cz = 298, a = 81, b = 36, p = 2.6, x0 = 932, z0 = 262, x1 = 1094, z1 = 334, height = 4, round = true }

-- Straßenlaternen nach Foto: hoher, schlanker grauer Mast mit geschwungenem Ausleger und Kopf über der Fahrbahn.
C.lamps = { spacing = 64, inset = 2.5, height = 36 }
-- Laternen am Friedensengel-Oval (die Segmente der Ellipse sind zu kurz für den Abstand von 64): außen und innen alle ca. 50 Studs, nicht an den Einmündungen
C.extraLamps = {}
do
	local a, b, cx, cz, p, n = 107, 62, 1013, 298, 2.6, 11
	for i = 0, n - 1 do
		local t = 2 * math.pi * (i + 0.5) / n
		local c, s = math.cos(t), math.sin(t)
		local qx, qz = (c < 0 and -1 or 1) * math.abs(c) ^ (2 / p), (s < 0 and -1 or 1) * math.abs(s) ^ (2 / p)
		local nx, nz = (qx < 0 and -1 or 1) * math.abs(qx) ^ (p - 1) / a, (qz < 0 and -1 or 1) * math.abs(qz) ^ (p - 1) / b -- Gradient der Superellipse
		local l = math.sqrt(nx * nx + nz * nz)
		nx, nz = nx / l, nz / l
		local px, pz = cx + a * qx, cz + b * qz
		if math.abs(px - (cx - a)) > 30 and math.abs(px - (cx + a)) > 30 then
			for _, sd in ipairs({ -1, 1 }) do
				local off = sd * (14 + C.lamps.inset)
				C.extraLamps[#C.extraLamps + 1] = { px + nx * off, pz + nz * off, -nx * sd, -nz * sd }
			end
		end
	end
end

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
C.pedSignals = {} -- die Fußgängerampeln am Siegestor entfallen (Kreisverkehr)

-- Wahrzeichen: Siegestor steht auf dem Tunneldeckel (Mitte = Ursprung), Friedensengel in der Mitte der Terrasse
-- Fußgängerüberwege (Zebrastreifen): Mitte (x, z), Fahrtrichtung (ux, uz), Querbereich a0..a1 (Abstand von der Mitte in Richtung der Normalen (-uz, ux));
-- Streifen 2 breit, 2 Lücke, 10 lang. Am Friedensengel-Oval (6, radial über die Fahrbahn zwischen äußerem und innerem Gehweg) und am Siegestor (6).
C.crossings = {
	{ x = 0, z = -91, ux = 0, uz = 1, a0 = 6, a1 = 43 }, { x = 0, z = -91, ux = 0, uz = 1, a0 = -43, a1 = -6 }, -- Achse Nord, beide Fahrbahnen
	{ x = 0, z = 91, ux = 0, uz = 1, a0 = 6, a1 = 43 }, { x = 0, z = 91, ux = 0, uz = 1, a0 = -43, a1 = -6 }, -- Achse Süd
	{ x = -96, z = 30, ux = 1, uz = 0, a0 = -18.5, a1 = 18.5 }, -- H2 vor dem Kreisverkehr
	{ x = 110, z = 31.3, ux = 0.9997, uz = 0.0262, a0 = -14, a1 = 14 }, -- Diagonale
}
do
	local p = 2.6
	local function pt(t)
		local c, s = math.cos(t), math.sin(t)
		return 1013 + 107 * (c < 0 and -1 or 1) * math.abs(c) ^ (2 / p), 298 + 62 * (s < 0 and -1 or 1) * math.abs(s) ^ (2 / p)
	end
	for _, deg in ipairs({ 22, 90, 158, 202, 270, 338 }) do
		local t = math.rad(deg)
		local x0, z0 = pt(t - 0.01)
		local x1, z1 = pt(t + 0.01)
		local l = math.sqrt((x1 - x0) ^ 2 + (z1 - z0) ^ 2)
		local x, z = pt(t)
		C.crossings[#C.crossings + 1] = { x = x, z = z, ux = (x1 - x0) / l, uz = (z1 - z0) / l, a0 = -14, a1 = 14 }
	end
end

-- Stachus (Karlsplatz) statt Odeonsplatz-Bebauung: Platz x0..x1, z0..z1, Mitte (cx, cz) = Brunnen. Halbellipse der Geschäftshäuser (Mittellinie ac x bc, Tiefe depth,
-- n = segments Abschnitte), nach Osten gerade Schenkel (legs Abschnitte), Karlstor in der Westmitte (gate = halbe Lücke). taxi = Parkbuchten der Leopoldstraße.
C.stachus = { x0 = -215, z0 = 60, x1 = -55, z1 = 386, cx = -116, cz = 225, depth = 39, floors = 5, basin = 40, gate = 30, seg = 8.4,
	rowN = 86.5, eastEnd = -83, -- Nordzeile Mittellinie z (bündig mit dem Neuen Rathaus), Ostende aller Zeilen
	taxi = { x = -38.5, z0 = 98, len = 16, n = 8 },
	ubahn = { { x0 = -112, x1 = -80, z0 = 306, z1 = 322, gang = 14, depth = 10.5 }, { x0 = -112, x1 = -80, z0 = 128, z1 = 144, gang = 14, depth = 10.5 } } } -- Gruben spiegelbildlich zur Brunnenmitte; Zugang im Westen, Treppe fällt nach Osten (Richtung Taxistand) ab

-- Marienplatz (Südwest-Viertel): gepflasterter Platz, Neues Rathaus am Nordrand (Front nach Süden bei z1), Mariensäule, U-Bahn-Abgang vor dem Rathaus
-- (Treppe fällt nach Norden auf depth ab, dahinter ein kurzer Gang), Frauenkirche im Nordwesten (landmarks.frauenkirche).
C.marienplatz = {
	plaza = { x0 = -632, z0 = 60, x1 = -215, z1 = 326 }, -- bis zur Häuserzeile Süd (Block M_MarienplatzSued)
	rathaus = { x0 = -355, z0 = 66, x1 = -215, z1 = 106 },
	saeule = { x = -285, z = 205 },
	ubahn = { x0 = -302, x1 = -268, z0 = 128, z1 = 160, depth = 10.5, gang = 18 },
}

C.landmarks = {
	siegestor = { x = 0, z = 0, baseY = 1.4, islandR = 52, ringR = 68 }, -- steht auf der Mittelinsel des Kreisverkehrs
	friedensengel = { x = 1040, z = 298, baseY = 3.7 }, -- im östlichen Teil der Insel, der Blick geht nach Westen die Maximilianstraße hinunter
	frauenkirche = { x0 = -687.5, x1 = -292.5, z = 118, baseY = 1.0, width = 150, wallH = 72, roofRise = 62, towerH = 210, scale = 0.65 }, -- Maße vor der Skalierung (scale um die Mitte), Türme im Westen, am Nordrand des Marienplatzes
	turm = { x = 573, z = 224, baseY = 0.2 }, -- Chinesischer Turm im Englischen Garten, Biergarten rundherum
	biergarten = { x0 = 532, z0 = 186, x1 = 614, z1 = 262 },
	eisbach = { z = 338 }, -- Eisbachwelle: Stelle am Bach, wo z so groß ist: unmittelbar flussabwärts (südlich) der Maximilianbrücke, neben Prinz Eins
}

C.wall = {
	gates = { N = { { -60, 60 }, { 835, 1055 } }, S = { { -40, 40 }, { 560, 780 } } },
	specials = { { side = "N", name = "Querriegel", x0 = -60, x1 = 60, floors = 10 }, { side = "S", name = "Feldherrnhalle", x0 = -40, x1 = 40, floors = 2 } },
	riverGates = { { side = "N", x0 = 835, x1 = 1055 }, { side = "S", x0 = 560, x1 = 780 } }, -- Brückenhaus: Gebäude über dem Fluss
}

return C
