-- MapBuilder_Script.lua  (automatisch erzeugt mit make_bundles.py, nicht von Hand ändern)
--
-- NOTRUF MÜNCHEN: KOMPLETTE KARTE IN EINEM SCRIPT
-- So geht's: 1) In Studio ein leeres Baseplate-Projekt öffnen (Baseplate gern löschen).
--            2) In ServerScriptService ein Script "MapBuilder" anlegen, diesen ganzen Text einfügen.
--            3) Unter diesem Script zwei ModuleScripts anlegen (bei dieser Datei NICHT nötig) (Rechtsklick auf das Script > Insert Object > ModuleScript),
--               umbenennen in "Teil1" und "Teil2" und die Texte aus MapBuilder_Teil1.lua bzw. MapBuilder_Teil2.lua einfügen.
--               (Roblox erlaubt pro Script nur ca. 200 000 Zeichen, darum drei Teile.)
--            4) Oben auf RUN klicken (nicht Play). Das Bauen dauert 1-3 Minuten, Fortschritt steht im Output.
--            5) Mit der Kamera (F im Viewport, WASD + Rechtsklick) zum Siegestor fliegen: Ursprung = (0, 0, 0).
--            Die Karte ist nach dem Stoppen weg. Dauerhaft bauen: MapBuilder_Plugin.lua als lokales Plugin.
--
-- WAS GEBAUT WIRD (Schritte, in dieser Reihenfolge; Output zeigt je Schritt eine Zeile):
--   terrain    Boden, Parks, Hügel (Monopteros), Terrasse (Friedensengel), Isar mit 3-stufiger Böschung, Bach
--   roads      Ring, Leopoldstraße/Ludwigstraße (Achse, rund um das Siegestor ein Kreisverkehr), Schwabinger Raster, Diagonale, Isarspange,
--              Maximilianstraße, Isar-Allee (Ostufer: Straße mit Parkstreifen, Laternen, roter Radweg, Baumreihe, Ufergehweg), Friedensengel-Oval, Kreisverkehr, gerundete Gehwegecken, 12 Zebrastreifen, Parkbuchten, 4 Brücken über die Isar (flach, auf Säulen),
--              Maximilianbrücke (zwei Bögen, Statuen)
--   lights     270 Laternen (runder Mast, Bogenarm, Leuchtkopf), 13 Ampelmasten (Rundmast, Ausleger, Linsenköpfe mit Blenden)
--   marienplatz Neues Rathaus, Mariensäule, U-Bahn-Abgang, Pflaster, Kugelleuchten, Platanen, Cafés (Frauenkirche verkleinert im Nordwesten)
--   autohaus   Autohaus an der V3 mit Showroom (Glas um die Ecke), Parkdeck, Werkstatt, Pylon (ohne Fahrzeuge)
--   einfahrten Einfahrten (Kerben im Gehweg) an Autohaus, Klinik, Polizei, Feuerwache, Parkhaus, Café, Prinz-Eins (nur diese Teile)
--   kreiselwege Gehwege am Siegestor-Kreisel nahtlos an die Zufahrten angeschlossen (nur diese Gehwege)
--   tankshop   Schiebetür und Glastür am Allguth-Shop (nur die Türteile)
--   kaffeehaus Café mit Terrasse zur Leopoldstraße, Parkplatz im Süden (Modell neu)
--   stachus    Stachus: Halbkreis-Geschäftshäuser, Karlstor, Brunnen mit Strahlen, Taxistand (statt Casino/Kaffeehaus-Gelände am Odeonsplatz)
--   landmarks  Siegestor auf Mittelinsel, Friedensengel (Engel mit Flügeln, Ölzweig, Nike; rundes Becken), Frauenkirche (runde Zwiebelhauben),
--              Chinesischer Turm
--   gardens    Hofgarten, Englischer Garten, Monopteros-Tempel, Biergarten, Eisbachwelle, Isar-Uferwege, Prinz-Eins-Vorplatz
--   houses     7 Häuserblöcke mit Rück- und Hinterhäusern, Isar-Allee-Zeile mit Backsteinkirche, Westufer-Zeile, gebogene Eckhäuser am Siegestor, Kino Casino Odeon und Kaffeehaus Odeon am Odeonsplatz, 13 Sonderbauten (Feuerwache, Polizeiwache mit Hof, Klinikum,
--              Tankstelle mit Schirm, Shop und Parkplätzen (3 Ladeplätze, 1 Behindertenparkplatz), Bank, Parkhaus, ...)
--   skyline    5 Hochhäuser (Glas mit abgerundeten Ecken; Vierzylinder-Turm "BMO" mit Logo und blauem Band; Schüssel-Gebäude "BMO Welt" mit Brücke)
--   bus        18 Bushaltestellen (Wartehäuschen, Bank, Schild "H") auf Gehwegen in der Innenstadt
--   wall       Häuserband um die Karte (Mapgrenze) mit Toren und Flusstoren
--
-- WAS FUNKTIONIERT WIE:
--   Ampeln      Starten automatisch nach dem Bauen. Kreuzungen: 30 s grün je Richtung (Einstellung Ampel.config.green weiter unten).
--               Feuerwache: im Run-Modus in der Command Bar  workspace:SetAttribute("WacheAlarm", true)  -> V1/V2 gelb, dann rot;
--               mit false wieder grün. Tag der Lampen: TrafficLight (Gruppen Wache_V1, Wache_V2, Achse_*).
--   Tore/Schranken  Feuerwache-Tore (Tag FireGate) und Polizei-Schranken (Tag Schranke) sind Modelle, noch ohne Skript.
--   Spawns      Polizeihof: 4 Flächen mit Tag VehicleSpawn (Attribut Team = Polizei).
--   Fenster     Tag HouseWindow, Attribut Lit = leuchtet nachts (Tag-Nacht-Skript folgt). Laternen: Tag StreetLamp.
--   Eisbachwelle  an der Maximilianbrücke (Welle flussabwärts, Deck am Westufer). Tags Eisbachwelle, SurfZone (Surf-Skript folgt).
--   Isar-Allee  Ostufer der Isar zwischen Ring Nord und Isarspange (Karte nach Osten um 100 Studs erweitert), 11 Häuser + Backsteinkirche.
--   Alle Maße   in Config (weiter unten im Text, Block "local Config = (function()"): Straßen, Isar, Brücken, Tankstelle, Gärten.
--
-- OUTPUT-ZEILEN, auf die du achten kannst: [boden] (Bodenhöhe), [wasser] ok, [roads], [lights], [landmarks], [gardens], [houses], [wall].
-- Steht irgendwo "FEHLER:", schick mir die Zeile.
--
local STEPS = { "terrain", "roads", "lights", "landmarks", "marienplatz", "stachus", "gardens", "houses", "skyline", "bus", "wall" } -- Teilmenge möglich, z. B. { "roads" }
local ONLY = nil -- nur bestimmte Häuserblöcke, z. B. { "B_NordMitte" }; nil = alle
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
function Geo.lathe(H, diam, dd, dhMax)
local out, h = {}, 0
while h < H - 1e-6 do
local step = math.min(dhMax, H - h)
while step > 0.02 and math.abs(diam(h + step) - diam(h)) > dd do step = step * 0.8 end
out[#out + 1] = { y = h + step / 2, dick = step + 0.3, d = diam(h + step / 2), h0 = h, h1 = h + step }
h = h + step
end
return out
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
function Geo.wedges(p1, p2, p3, thick, hint)
local P = { p1, p2, p3 }
local best, bi = -1, 1
for i = 1, 3 do
local a, b = P[i], P[i % 3 + 1]
local l = (a[1] - b[1]) ^ 2 + (a[2] - b[2]) ^ 2 + (a[3] - b[3]) ^ 2
if l > best then best, bi = l, i end
end
local a, b, c = P[bi], P[bi % 3 + 1], P[(bi + 1) % 3 + 1]
local bx, by, bz = b[1] - a[1], b[2] - a[2], b[3] - a[3]
local bl = math.sqrt(bx * bx + by * by + bz * bz)
if bl < 0.05 then return {} end
bx, by, bz = bx / bl, by / bl, bz / bl
local t = (c[1] - a[1]) * bx + (c[2] - a[2]) * by + (c[3] - a[3]) * bz
local f = { a[1] + bx * t, a[2] + by * t, a[3] + bz * t }
local hx, hy, hz = c[1] - f[1], c[2] - f[2], c[3] - f[3]
local hl = math.sqrt(hx * hx + hy * hy + hz * hz)
if hl < 0.03 then return {} end
hx, hy, hz = hx / hl, hy / hl, hz / hl
local out = {}
for _, leg in ipairs({ { -1, t }, { 1, bl - t } }) do
local l1 = leg[2]
if l1 > 0.03 then
local d = { leg[1] * bx, leg[1] * by, leg[1] * bz } -- vom Fußpunkt zur Ecke der Grundseite
local ey, ez = d, { -hx, -hy, -hz }
local n = { ey[2] * ez[3] - ey[3] * ez[2], ey[3] * ez[1] - ey[1] * ez[3], ey[1] * ez[2] - ey[2] * ez[1] } -- Normale = ey x ez
local sh = 0
if hint then sh = ((n[1] * hint[1] + n[2] * hint[2] + n[3] * hint[3]) > 0) and -thick / 2 or thick / 2 end
out[#out + 1] = {
pos = { f[1] + d[1] * l1 / 2 + hx * hl / 2 + n[1] * sh, f[2] + d[2] * l1 / 2 + hy * hl / 2 + n[2] * sh, f[3] + d[3] * l1 / 2 + hz * hl / 2 + n[3] * sh },
size = { thick, l1, hl }, wedge = { ey, ez },
}
end
end
return out
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
local function superellipse(cx, cz, a, b, p, n)
local pts = {}
for i = 0, n - 1 do
local t = 2 * math.pi * i / n
local c, s = math.cos(t), math.sin(t)
pts[#pts + 1] = { cx + a * (c < 0 and -1 or 1) * math.abs(c) ^ (2 / p), cz + b * (s < 0 and -1 or 1) * math.abs(s) ^ (2 / p) }
end
return pts
end
C.roads = {
{ name = "Ring", closed = true, profile = "std48", pts = { { -661, -472 }, { 1176, -472 }, { 1176, 410 }, { -661, 410 } } },
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
{ name = "IsarAllee", profile = "allee", pts = { { 1072.5, -472 }, { 1012, 3 } } },
{ name = "Maximilianstrasse", profile = "std48", pts = { { 395, 410 }, { 395, 298 }, { 906, 298 } } }, -- vom Ring über die Maximilianbrücke zum Friedensengel-Oval
{ name = "FriedensengelRing", closed = true, profile = "std48", pts = superellipse(1013, 298, 107, 62, 2.6, 64) },
{ name = "FriedensengelAusfahrt", profile = "std48", pts = { { 1120, 298 }, { 1176, 298 } } },
}
C.hochhaeuser = {
{ name = "Hochhaus-Klinikum", art = "glas", x = 462, z = -268, w = 64, d = 64, r = 12, floors = 12, label = "ISARTOR" }, -- hinter Volksbank und Krankenhaus
{ name = "Hochhaus-West", art = "glas", x = -563, z = -127, w = 66, d = 66, r = 14, floors = 15, label = "NOVA" }, -- Block D_West, Richtung Mapende
{ name = "BMO-Turm", art = "bmo", x = 100, z = -418, floors = 12, radius = 14, versatz = 12.5 },
{ name = "BMO-Welt", art = "schuessel", x = 164, z = -420, r = 24, bruecke = { x = 126.5, z = -418 } },
{ name = "Hochhaus-Allguth-Sued", art = "glas", x = 160, z = -22, w = 58, d = 44, r = 11, floors = 10, label = "OPTIMA", pm = 3 },
{ name = "Hochhaus-Allguth-Nordost", art = "glas", x = 252, z = -424, w = 40, d = 40, r = 9, floors = 9, label = "HELIOS", pm = 3 },
}
C.eckhaeuser = { Haus_F_LeopoldWestSued_N1 = 1.5, Haus_C_LeopoldWestNord_S2 = 1.5 }
C.busstops = {
{ x = -436.5, z = -360, zurStrasse = "W" }, { x = -483.5, z = -60, zurStrasse = "E" }, { x = -211.5, z = -130, zurStrasse = "W" },
{ x = -258.5, z = -380, zurStrasse = "E" }, { x = -560, z = -261.5, zurStrasse = "N" }, { x = -150, z = -308.5, zurStrasse = "S" },
{ x = -330, z = 53.5, zurStrasse = "N" }, { x = -560, z = 6.5, zurStrasse = "S" }, { x = 281, z = -120, zurStrasse = "E" },
{ x = 319, z = -380, zurStrasse = "W" }, { x = 49, z = -380, zurStrasse = "W" }, { x = -49, z = -200, zurStrasse = "E" },
{ x = 49, z = 200, zurStrasse = "W" }, { x = -49, z = 250, zurStrasse = "E" }, { x = 600, z = 317, zurStrasse = "N" },
{ x = 700, z = 279, zurStrasse = "S" }, { x = -642, z = -100, zurStrasse = "W" }, { x = 40, z = -453, zurStrasse = "N" },
}
C.bay = { length = 16, width = 9 }
C.tankstelle = { lot = { 57, -336, 180, -150 }, gaps = { { -262, -218 }, { -196, -152 } }, southOpen = { 88, 180 }, parking = { x0 = 80, zBack = -152, depth = 16, w = 8, kinds = { "H", "E", "E", "E", "N", "N", "N", "N", "N", "N" } } } -- parking: Stellplatzreihe im Südteil (H Behinderte, E Ladeplatz, N normal)
C.autohaus = { x0 = 332, z0 = -196, x1 = 442, z1 = -116, frontX = 394, showroom = { -170, -122 }, werkstatt = { -196, -170 },
vorfeld = { road = "Diagonale", margin = 5, rows = { { -114, -98 }, { -80, -64 } }, zMax = -20, trees = { 352, 372, 396, 420, 438 }, lamps = { 372, 404 } } }
C.werkstatt = { x0 = 88, z0 = -150, x1 = 186, z1 = -90, hall = { 104, 160 }, hallOffset = 14, depth = 22, gate = { -110, -98 } }
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
C.plazas = {}
C.bridges = {
{ name = "B0", x = 640, z = -257, len = 56, wid = 48, yaw = 39.3 },
{ name = "B1", x = 661, z = -62, len = 56, wid = 48, yaw = 356 },
{ name = "B5", x = 672, z = 120, len = 44, wid = 10, yaw = 0, pedestrian = true },
}
C.isarBridges = {
{ name = "B2", x = 887, z = -19, len = 214, wid = 28, walk = 14, yaw = 349.4, pier = 36 },
{ name = "B3", x = 692, z = 410, len = 252, wid = 28, walk = 14, yaw = 0, pier = 36 }, -- Luitpoldbrücke über Bach und Isar
{ name = "B4", x = 945, z = -472, len = 214, wid = 28, walk = 14, yaw = 0, pier = 36 },
{ name = "B6", style = "maximilian", x = 751, z = 298, len = 244, wid = 28, walk = 14, yaw = 0, span = 60, rise = 4.5, culvert = { s = -95.8, w = 38 } }, -- culvert: Durchlass für den Eisbach im westlichen Widerlager (s = Abstand von der Brückenmitte, w = Breite)
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
kanal = {
pts = { { 661, 262 }, { 650, 330 }, { 632, 378 } },
layers = { { 0, -4, 13 }, { -4, -8, 13 } }, waterTop = -4,
fills = { { -12, -8, 13, "Slate" } },
bank = { from = 14, width = 16, zmin = 326, material = "Ground" },
},
}
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
C.terrace = { name = "Friedensengel", cx = 1013, cz = 298, a = 81, b = 36, p = 2.6, x0 = 932, z0 = 262, x1 = 1094, z1 = 334, height = 4, round = true }
C.lamps = { spacing = 64, inset = 2.5, height = 36 }
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
C.stachus = { x0 = -215, z0 = 60, x1 = -55, z1 = 386, cx = -116, cz = 225, depth = 39, floors = 5, basin = 40, gate = 30, seg = 8.4,
rowN = 86.5, eastEnd = -83, -- Nordzeile Mittellinie z (bündig mit dem Neuen Rathaus), Ostende aller Zeilen
taxi = { x = -38.5, z0 = 98, len = 16, n = 8 },
ubahn = { { x0 = -112, x1 = -80, z0 = 306, z1 = 322, gang = 14, depth = 10.5 }, { x0 = -112, x1 = -80, z0 = 128, z1 = 144, gang = 14, depth = 10.5 } } } -- Gruben spiegelbildlich zur Brunnenmitte; Zugang im Westen, Treppe fällt nach Osten (Richtung Taxistand) ab
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

end)()
local Planner = (function()
local Geo = Geo
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
for _, s in ipairs(Geo.lathe(40, function(h) return 13.8 * (1 - h / 40) ^ 1.15 + 1.1 end, 0.3, 0.5)) do -- Turmhelm: feine Scheiben, Kegel mit geschwungener Spitze ohne sichtbare Stufen
box("Turmhelm", "roof", 0, y0 + 81.8 + s.y, 9, s.dick, s.d, s.d, COPPER, "Metal", { shape = "Cylinder", roll = 90 })
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
for _, side in ipairs(sides) do side.shop = block.shopSide == side.name end
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
add(h, "Markise", "trim", 0, y0 + 12.2, -3, W - 8, 0.6, 6, GREEN, "Fabric")
add(h, "MarkiseSaum", "trim", 0, y0 + 11.3, -6, W - 8, 1.8, 0.4, GREEN, "Fabric")
label(h, "front", 0, y0 + 11.3, 6.3, W - 12, 1.2, "KAFFEEHAUS ODEON", WHITE2)
add(h, "SchildRand", "decor", 0, y0 + 18.4, -0.4, 0.6, 9, 9, DGREEN, "Metal", { shape = "Cylinder", yaw = 90 })
add(h, "SchildGruen", "decor", 0, y0 + 18.4, -0.7, 0.4, 8, 8, GREEN, "SmoothPlastic", { shape = "Cylinder", yaw = 90 })
add(h, "SchildRing", "decor", 0, y0 + 18.4, -0.9, 0.3, 6.6, 6.6, WHITE2, "SmoothPlastic", { shape = "Cylinder", yaw = 90 })
add(h, "SchildBohne", "decor", 0, y0 + 18.4, -1.1, 0.3, 4.6, 3, { 92, 56, 36 }, "SmoothPlastic", { shape = "Cylinder", yaw = 90, roll = 25 })
add(h, "SchildBohneNaht", "decor", 0, y0 + 18.4, -1.3, 0.2, 0.3, 4.4, WHITE2, "SmoothPlastic", { roll = 25 })
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
for _, band in ipairs({ { 4, 16 }, { D - 20, 16 } }) do
for i = 0, 27 do add(h, "StellplatzLinie", "dash", -W / 2 + 6 + i * (W - 12) / 27, yt + 0.06, band[1] + band[2] / 2, 0.3, 0.1, band[2], WHITE, "SmoothPlastic") end
end
for i = 0, 8 do add(h, "Deckenlicht", "trim", -W / 2 + 10 + i * (W - 20) / 8, yt + LV - 1.5, D / 2, 4, 0.3, 0.6, { 255, 250, 232 }, "Neon") end
add(h, "Geschossschild", "decor", -W / 2 + 14, yt + 7.2, 1.2, 8, 2.4, 0.3, BLUE, "SmoothPlastic")
add(h, "Schrift", "text", -W / 2 + 14, yt + 7.2, 1.0, 7, 1.8, 0.2, WHITE, "SmoothPlastic", { kind = "text", yaw = 180, text = { s = ({ "EG", "1. OG", "2. OG" })[k + 1], color = WHITE } })
end
add(h, "Schildband", "trim", 0, y0 + TOP - 2.4, -1.2, 60, 4.4, 1, BLUE, "SmoothPlastic")
label(h, "front", 0, y0 + TOP - 2.4, 1.8, 56, 3.2, "PARKHAUS KLINIKUM", WHITE)
add(h, "Pylon", "decor", W / 2 - 14, y0 + 8, -4, 1, 16, 1, { 80, 82, 86 }, "Metal", { collide = true })
add(h, "PylonSchild", "decor", W / 2 - 14, y0 + 17, -4, 6, 6, 0.4, BLUE, "SmoothPlastic")
label(h, "front", W / 2 - 14, y0 + 17, 4.3, 5, 5, "P", WHITE)
for k, u in ipairs({ -10, 10 }) do
add(h, "Kassenhaeuschen", "trim", u + (k == 1 and -4.5 or 4.5), y0 + 3, -5, 3, 6, 4, WHITE, "SmoothPlastic", { collide = true })
add(h, "Kassendach", "trim", u + (k == 1 and -4.5 or 4.5), y0 + 6.3, -5, 4.4, 0.6, 5.4, BLUE, "SmoothPlastic")
for i = 1, 4 do add(h, "Schranke", "trim", u - 3 + (i - 0.5) * 1.5 + (k == 1 and 0 or 0), y0 + 4.2, -5, 1.5, 0.5, 0.5, (i % 2 == 1) and { 200, 40, 40 } or WHITE, "SmoothPlastic", { collide = true, tag = "Schranke", attrs = { Offen = false, Gruppe = k == 1 and "ParkhausEin" or "ParkhausAus" } }) end
end
label(h, "front", -10, y0 + 8.4, 6.4, 10, 1.2, "EINFAHRT", { 120, 240, 160 })
label(h, "front", 10, y0 + 8.4, 6.4, 10, 1.2, "AUSFAHRT", { 255, 150, 120 })
for _, sd in ipairs({ -1, 1 }) do
add(h, "Treppenhaus", "trim", sd * (W / 2 - 8), y0 + TOP / 2, D - 7, 10, TOP, 12, { 150, 150, 146 }, "Concrete", { collide = true })
add(h, "TreppenhausGlas", "glass", sd * (W / 2 - 8), y0 + 8, D - 13.2, 6, 14, 0.3, { 130, 160, 180 }, "Glass", { kind = "glass" })
end
local rl = 46
add(h, "Auffahrt", "trim", W / 2 + rl / 2, y0 + LV / 2, 14, math.sqrt(rl * rl + LV * LV), 1, 18, DARK, "Asphalt", { collide = true, roll = -math.deg(math.atan2(LV, rl)) })
for _, sd in ipairs({ 6, 22 }) do add(h, "AuffahrtMauer", "trim", W / 2 + rl / 2, y0 + LV / 2 + 1.2, sd, math.sqrt(rl * rl + LV * LV), 2.4, 0.6, CONC, "Concrete", { collide = true, roll = -math.deg(math.atan2(LV, rl)) }) end
end
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
add(h, "Eingangsrahmen", "trim", 0, y0 + 5.4, -0.4, 9, 10.8, 0.5, BLUE, "Metal")
add(h, "Drehtuer", "glass", 0, y0 + 5, -0.6, 7, 10, 0.3, { 150, 180, 196 }, "Glass", { tag = "ShopDoor" })
add(h, "Vordach", "trim", 0, y0 + 12.4, -4, 22, 0.8, 8, BLUE, "SmoothPlastic", { collide = true })
for _, sd in ipairs({ -1, 1 }) do add(h, "VordachStuetze", "trim", sd * 10, y0 + 6, -7.4, 0.8, 12, 0.8, { 150, 154, 158 }, "Metal", { collide = true }) end
add(h, "VordachRand", "trim", 0, y0 + 12.4, -8.1, 22.4, 1.2, 0.5, ORANGE, "SmoothPlastic")
add(h, "Schriftband", "trim", 0, y0 + H - 6.8, -0.7, 54, 7, 0.8, BLUE, "SmoothPlastic")
label(h, "front", 0, y0 + H - 6.8, 1.2, 50, 5, "Volksbank", WHITE)
add(h, "SchriftOrange", "trim", 0, y0 + H - 10.7, -0.7, 54, 0.8, 0.8, ORANGE, "SmoothPlastic")
for k, u in ipairs({ -15, -21 }) do
add(h, "Geldautomat", "trim", u, y0 + 4.2, -1.2, 4.4, 7.4, 2.4, BLUE, "SmoothPlastic", { collide = true })
add(h, "GeldautomatBildschirm", "decor", u, y0 + 5.6, -2.5, 3, 2.2, 0.2, { 255, 170, 60 }, "Neon")
add(h, "GeldautomatFach", "decor", u, y0 + 3, -2.5, 3, 0.8, 0.3, { 24, 24, 28 }, "SmoothPlastic")
end
label(h, "front", -18, y0 + 9.6, 3, 8, 1.4, "GELD 24 H", ORANGE)
label(h, "front", 17, y0 + 6.6, 0.7, 9, 3.2, "Mo-Fr 9-17", { 40, 50, 70 })
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
if spec.southOpen then -- Südkante offen (Durchfahrt zum Werkstatt-Hof)
kerb(l[1], l[4] - K, spec.southOpen[1], l[4])
if spec.southOpen[2] < l[3] then kerb(spec.southOpen[2], l[4] - K, l[3], l[4]) end
else
kerb(l[1], l[4] - K, l[3], l[4])
end
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
{ name = "C_LeopoldWestNord", xmin = -206.5, zmin = -448, xmax = -55, zmax = -313.5, reserved = { { -127, -385, -55, -315 } }, shopSide = "E" },
{ name = "D_West", xmin = -637, zmin = -256.5, xmax = -488.5, zmax = 1.5, reserved = { { -599, -163, -527, -91 } } }, -- Hochhaus-West
{ name = "E_Mitte", xmin = -431.5, zmin = -256.5, xmax = -263.5, zmax = 1.5, reserved = { { -429.5, -200, -265.5, -100 } } },
{ name = "F_LeopoldWestSued", xmin = -206.5, zmin = -256.5, xmax = -55, zmax = 1.5, reserved = { { -205, -250, -109, -140 }, { -125, -90, -55, 2 } }, shopSide = "E" }, -- zweite Fläche: Kreisverkehr um das Siegestor
{ name = "M_MarienplatzSued", xmin = -632, zmin = 326, xmax = -215, zmax = 386, noInner = true }, -- Häuserzeile am Südrand des Marienplatzes (vorn zum Platz, hinten zum Ring)
{ name = "G_LeopoldOst", xmin = 55, zmin = -448, xmax = 276, zmax = 4, reserved = { { T.lot[1], T.lot[2], 86, T.lot[4] }, { 55, -90, 125, 6 }, { 70, -448, 130, -388 }, { 138, -448, 190, -394 }, { 229, -448, 276, -400 }, { 128, -48, 192, 6 } }, shopSide = "W", lot = T.lot, avoidInner = { { 190, -400, 234, -108 } } }, -- Lücke in der Häuserzeile: Tankstelle liegt frei an der Straße, lot = ihr Grundstück
}

end)()
local Specials = (function()
local Config = Config
local T = Config.tankstelle
return {
{ name = "Isarbank", x0 = -127, z0 = -385, x1 = -55, z1 = -315, facing = "E", floors = 4, color = { 176, 120, 100 } },
{ name = "Parkhaus", x0 = -205, z0 = -250, x1 = -109, z1 = -140, facing = "N", floors = 4, color = { 170, 170, 176 } },
{ name = "Tankstellen-Shop", x0 = 78, z0 = -332, x1 = 146, z1 = -298, facing = "W", floors = 1, color = { 250, 250, 250 }, style = "tankstelle", canopy = { 78, -298, 146, -202 }, lot = T.lot, curbGaps = T.gaps, southOpen = T.southOpen, parking = T.parking },
{ name = "Tankstellen-Buero-Nord", x0 = 190, z0 = -400, x1 = 234, z1 = -318, facing = "W", floors = 5, color = { 38, 48, 62 }, style = "buero" },
{ name = "Tankstellen-Buero-Mitte", x0 = 190, z0 = -302, x1 = 234, z1 = -210, facing = "W", floors = 6, color = { 38, 48, 62 }, style = "buero" },
{ name = "Tankstellen-Buero-Sued", x0 = 190, z0 = -194, x1 = 234, z1 = -108, facing = "W", floors = 5, color = { 38, 48, 62 }, style = "buero" },
{ name = "Feuer-und-Rettungswache", x0 = -429.5, z0 = -200, x1 = -265.5, z1 = -100, facing = "W", floors = 4, color = { 200, 70, 55 }, style = "feuerwache" },
{ name = "Polizeiwache", x0 = 202, z0 = 340, x1 = 342, z1 = 384, facing = "S", floors = 5, color = { 70, 110, 200 }, style = "polizei", compound = "polizei" },
{ name = "Polizei-Seitenfluegel", x0 = 202, z0 = 298, x1 = 218, z1 = 340, facing = "E", floors = 3, color = { 92, 94, 104 } },
{ name = "Krankenhaus", x0 = 340, z0 = -430, x1 = 500, z1 = -310, facing = "W", floors = 5, color = { 90, 170, 150 }, style = "klinik" },
{ name = "Kiosk", x0 = -420, z0 = 280, x1 = -370, z1 = 320, facing = "N", floors = 1, color = { 200, 70, 55 } }, -- auf dem Marienplatz
{ name = "Kaffeehaus", x0 = 112, z0 = 300, x1 = 202, z1 = 360, facing = "W", floors = 3, color = { 244, 242, 232 }, style = "kaffee", lots = { { 112, 366, 202, 384 } } }, -- Terrasse zur Leopoldstraße (West), Parkplatz südlich, Rückseite zum Hofgarten,
{ name = "Prinz-Eins", x0 = 526, z0 = 326, x1 = 610, z1 = 366, facing = "S", floors = 3, color = { 52, 44, 76 }, lots = { { 436, 350, 522, 384 } } },
{ name = "Klinikum-Parkhaus", x0 = 500, z0 = -430, x1 = 660, z1 = -310, facing = "N", floors = 3, color = { 176, 176, 172 }, style = "parkhaus" }, -- grenzt an das Klinikum (x = 500)
{ name = "Volksbank", x0 = 330, z0 = -280, x1 = 404, z1 = -210, facing = "W", floors = 3, color = { 236, 238, 240 }, style = "bank" }, -- Lücke an der V3, südlich des Klinikums (erster grober Entwurf)
}

end)()
local Werkstatt = (function()
local Werkstatt = {}
local WHITE, GREY, DARK, YELLOW = { 240, 240, 236 }, { 132, 136, 142 }, { 58, 62, 70 }, { 255, 200, 0 }
local GLASS, ASPH = { 120, 156, 178 }, { 78, 80, 86 } -- ASPH wie das Plateau der Tankstelle
function Werkstatt.plan(cfg)
local W = cfg.werkstatt
local parts, stats = {}, { gates = 0, texts = 0, stalls = 0, lamps = 0 }
local function r3(v) return math.floor(v * 1000 + 0.5) / 1000 end
local function add(name, kind, x, y, z, sx, sy, sz, color, mat, e)
e = e or {}
parts[#parts + 1] = {
name = name, kind = kind, size = { r3(sx), r3(sy), r3(sz) }, pos = { r3(x), r3(y), r3(z) }, yaw = e.yaw or 0, pitch = 0, roll = e.roll,
color = color, material = mat, collide = e.collide == true, shape = e.shape, text = e.text, tag = e.tag, lit = e.lit, attrs = e.attrs, transparency = e.transparency,
}
end
local function text(name, x, y, z, sx, sy, s, color, bg, fz) -- Schrift auf einer Fläche; fz = +1 nach Süden, -1 nach Norden
add(name, "sign", x, y, z, sx, sy, 0.1, bg or { 0, 0, 0 }, "SmoothPlastic", { yaw = fz == 1 and 180 or 0, text = { s = s, color = color } })
stats.texts = stats.texts + 1
end
local Y = 1.0 -- Oberkante Boden (wie das Tankstellen-Plateau, damit man ohne Stufe hinüberfährt)
local H = 10 -- Traufhöhe der Halle
local OH = 7 -- lichte Höhe der Tordurchfahrten
local bx0, bx1 = W.hall[1], W.hall[2] -- Halle von West nach Ost
local bz0, bz1 = W.z0 + W.hallOffset, W.z0 + W.hallOffset + W.depth -- Halle von Nord nach Süd
local zc = (bz0 + bz1) / 2
local xc = (bx0 + bx1) / 2
local wallH = H - 0.8 -- Wandhöhe bis unter das Dach
add("Hof", "plaza", (W.x0 + W.x1) / 2, Y - 0.6, (W.z0 + W.z1) / 2, W.x1 - W.x0, 1.2, W.z1 - W.z0, ASPH, "Asphalt", { collide = true })
add("WerkstattBoden", "floor", xc, Y + 0.1, zc, bx1 - bx0, 0.2, bz1 - bz0, { 188, 188, 184 }, "Concrete", { collide = true })
add("Halle", "roof", xc, Y + H - 0.4, zc, bx1 - bx0, 0.8, bz1 - bz0, WHITE, "SmoothPlastic", { collide = true })
for _, z in ipairs({ bz0 + 0.2, bz1 - 0.2 }) do add("Dachrand", "trim", xc, Y + H + 0.5, z, bx1 - bx0 + 0.8, 1.0, 0.6, WHITE, "Concrete") end
for _, x in ipairs({ bx0, bx1 }) do add("Dachrand", "trim", x, Y + H + 0.5, zc, 0.6, 1.0, bz1 - bz0 + 0.8, WHITE, "Concrete") end
local gz0, gz1 = zc - 4, zc + 4 -- Durchgang in der Westwand, 4 hoch
add("HalleWandWest", "body", bx0 + 0.5, Y + wallH / 2, (bz0 + gz0) / 2, 1, wallH, gz0 - bz0, WHITE, "SmoothPlastic", { collide = true })
add("HalleWandWest", "body", bx0 + 0.5, Y + wallH / 2, (gz1 + bz1) / 2, 1, wallH, bz1 - gz1, WHITE, "SmoothPlastic", { collide = true })
add("HalleWandWest", "body", bx0 + 0.5, Y + 4 + (wallH - 4) / 2, zc, 1, wallH - 4, gz1 - gz0, WHITE, "SmoothPlastic", { collide = true }) -- Sturz über dem Durchgang
add("HalleWandOst", "body", bx1 - 0.5, Y + wallH / 2, zc, 1, wallH, bz1 - bz0, WHITE, "SmoothPlastic", { collide = true })
for _, wz in ipairs({ zc - 6, zc + 6 }) do -- Fenster in der Ostwand (zur Zufahrtsgasse)
add("SeitenFensterRahmen", "trim", bx1 + 0.15, Y + 5.2, wz, 0.4, 4.6, 7.6, DARK, "Metal")
add("SeitenFenster", "glass", bx1 + 0.35, Y + 5.2, wz, 0.2, 3.8, 6.8, GLASS, "Glass", { tag = "HouseWindow", lit = true })
end
add("Sockel", "trim", bx1 + 0.1, Y + 0.5, zc, 0.4, 1.0, bz1 - bz0, { 150, 154, 158 }, "Concrete")
local gateW, pilW = 12, 6
local function gateX(g) return bx0 + 4 + gateW / 2 + (g - 1) * (gateW + pilW) end
for _, fz in ipairs({ 1, -1 }) do
local zo = fz == 1 and bz1 or bz0 -- Außenkante der Fassade
local zw = zo - fz * 0.5 -- Mitte der Fassadenwand (1 dick)
add("HallePfeiler", "body", bx0 + 2, Y + wallH / 2, zw, 4, wallH, 1, WHITE, "SmoothPlastic", { collide = true })
add("HallePfeiler", "body", bx1 - 2, Y + wallH / 2, zw, 4, wallH, 1, WHITE, "SmoothPlastic", { collide = true })
for g = 1, 2 do add("HallePfeiler", "body", gateX(g) + (gateW + pilW) / 2, Y + wallH / 2, zw, pilW, wallH, 1, WHITE, "SmoothPlastic", { collide = true }) end
add("HalleSturz", "body", xc, Y + OH + (wallH - OH) / 2, zw, bx1 - bx0, wallH - OH, 1, WHITE, "SmoothPlastic", { collide = true })
add("Blende", "trim", xc, Y + H - 1.3, zo + fz * 0.25, bx1 - bx0 + 0.2, 2.6, 0.5, GREY, "Concrete")
add("Sockel", "trim", xc, Y + 0.5, zo + fz * 0.15, bx1 - bx0 + 0.2, 1.0, 0.5, { 150, 154, 158 }, "Concrete")
for g = 1, 3 do
local gx = gateX(g)
add("TorRahmen", "trim", gx, Y + OH - 0.1, zo + fz * 0.2, gateW + 0.8, 0.6, 0.5, GREY, "Metal")
for _, sd in ipairs({ -1, 1 }) do add("TorRahmen", "trim", gx + sd * (gateW / 2 + 0.2), Y + OH / 2, zo + fz * 0.2, 0.5, OH, 0.5, GREY, "Metal") end
add("TorGlas", "glass", gx, Y + OH + 1.5, zo + fz * 0.05, gateW - 0.8, 2.2, 0.2, GLASS, "Glass", { tag = "HouseWindow", lit = false })
for k = 1, 3 do add("TorSprosse", "trim", gx - (gateW - 0.8) / 2 + k * (gateW - 0.8) / 4, Y + OH + 1.5, zo + fz * 0.2, 0.3, 2.2, 0.2, DARK, "Metal") end
add("TorSprosse", "trim", gx, Y + OH + 1.5, zo + fz * 0.2, gateW - 0.8, 0.3, 0.2, DARK, "Metal")
add("TorSchildPlatte", "sign", gx + gateW / 2 + 2.9, Y + 5, zo + fz * 0.2, 2.6, 2.4, 0.2, { 120, 124, 128 }, "SmoothPlastic")
text("TorSchildText", gx + gateW / 2 + 2.9, Y + 5, zo + fz * 0.35, 2.2, 1.2, "Tor " .. (g + (fz == 1 and 0 or 3)), { 255, 255, 255 }, { 120, 124, 128 }, fz)
stats.gates = stats.gates + 1
end
for _, g in ipairs({ 1, 3 }) do
local gx = gateX(g)
add("WerkstattSchild", "sign", gx, Y + H - 1.3, zo + fz * 0.6, gateW + 0.2, 3.2, 0.4, YELLOW, "SmoothPlastic")
text("WerkstattSchrift", gx, Y + H - 0.6, zo + fz * 0.85, 9, 1.4, "ADAN", { 255, 255, 255 }, YELLOW, fz)
text("WerkstattSchrift", gx, Y + H - 2.1, zo + fz * 0.85, 9, 1, "Werkstatt", { 255, 255, 255 }, YELLOW, fz)
end
text("BlendeText", gateX(2), Y + H - 1.3, zo + fz * 0.6, 10, 1.6, "Huber", { 255, 255, 255 }, GREY, fz)
add("Vordach", "roof", xc, Y + H - 2.9, zo + fz * 1.6, bx1 - bx0 - 2, 0.3, 2.4, GREY, "Concrete") -- schmale Auskragung über der Durchfahrt
end
local sx0, sx1 = bx0 + 2, bx0 + 2 + 36
for _, px in ipairs({ sx0 + 3, sx1 - 3 }) do add("DachschildPfosten", "trim", px, Y + H + 2, zc, 0.5, 4, 0.5, DARK, "Metal") end
add("DachschildTafel", "sign", (sx0 + sx1) / 2, Y + H + 4.4, zc, sx1 - sx0, 3.2, 0.4, GREY, "Concrete")
for _, fz in ipairs({ 1, -1 }) do
add("DachschildGelb", "sign", sx0 + 4.4, Y + H + 4.4, zc + fz * 0.25, 8.4, 3.2, 0.2, YELLOW, "SmoothPlastic")
text("DachschildGelbText", sx0 + 4.4, Y + H + 4.4, zc + fz * 0.4, 7.6, 1.8, "ADAN", { 0, 0, 0 }, YELLOW, fz)
text("DachschildText", (sx0 + sx1) / 2 + 4.4, Y + H + 4.4, zc + fz * 0.4, 24, 1.8, "Service-Center", { 255, 255, 255 }, GREY, fz)
end
for _, g in ipairs({ 1, 3 }) do
local gx = gateX(g)
for _, sd in ipairs({ -1, 1 }) do
add("HebebuehnePfosten", "decor", gx + sd * 4, Y + 3.2, zc, 0.9, 6.4, 1.2, { 236, 190, 40 }, "Metal", { collide = true })
add("HebebuehneArm", "decor", gx + sd * 2.4, Y + 2, zc - 4, 0.8, 0.5, 3.4, { 70, 74, 80 }, "Metal")
add("HebebuehneArm", "decor", gx + sd * 2.4, Y + 2, zc + 4, 0.8, 0.5, 3.4, { 70, 74, 80 }, "Metal")
end
add("HebebuehneQuerbalken", "decor", gx, Y + 6.2, zc, 8.8, 0.6, 1.2, { 236, 190, 40 }, "Metal")
end
add("Werkbank", "decor", bx0 + 3, Y + 1.7, zc + 6.5, 2.4, 0.4, 5, { 150, 112, 76 }, "Wood", { collide = true })
add("WerkbankKorpus", "decor", bx0 + 3, Y + 0.8, zc + 6.5, 2.2, 1.6, 4.6, { 80, 84, 92 }, "Metal", { collide = true })
add("Werkzeugkasten", "decor", bx0 + 3, Y + 2.5, zc + 7.5, 1.6, 1.2, 2.2, { 200, 50, 44 }, "Metal")
for k = 0, 3 do add("Reifen", "decor", bx1 - 3, Y + 0.7 + k * 1.3, zc - 7, 1.3, 3, 3, { 28, 28, 30 }, "SmoothPlastic", { shape = "Cylinder" }) end
for k = 0, 2 do add("Reifen", "decor", bx1 - 3, Y + 0.7 + k * 1.3, zc - 3.6, 1.3, 3, 3, { 28, 28, 30 }, "SmoothPlastic", { shape = "Cylinder" }) end
for _, dz in ipairs({ 4, 6.4 }) do add("Oelfass", "decor", bx1 - 3, Y + 1.7, zc + dz, 2, 3.2, 2, { 40, 70, 150 }, "Metal", { shape = "Cylinder", roll = 90 }) end
for g = 1, 3 do
for _, dz in ipairs({ -5, 5 }) do
add("Deckenleuchte", "lamp", gateX(g), Y + H - 1.0, zc + dz, 6, 0.3, 0.8, { 255, 252, 236 }, "Neon", { tag = "StreetLamp", attrs = { Lit = true } })
stats.lamps = stats.lamps + 1
end
end
local lx0, lx1, lz0, lz1 = W.x0 + 2, bx0, bz1 - 14, bz1 + 4
add("AnnahmeBoden", "floor", (lx0 + lx1) / 2, Y + 0.3, (lz0 + lz1) / 2, lx1 - lx0, 0.6, lz1 - lz0, { 200, 200, 196 }, "Concrete", { collide = true })
add("AnnahmeGlas", "glass", (lx0 + lx1) / 2, Y + 3.6, lz1, lx1 - lx0, 6, 0.3, GLASS, "Glass", { tag = "HouseWindow", lit = true })
add("AnnahmeGlas", "glass", lx0, Y + 3.6, (lz0 + lz1) / 2, 0.3, 6, lz1 - lz0, GLASS, "Glass", { tag = "HouseWindow", lit = true })
add("AnnahmeGlas", "glass", (lx0 + lx1) / 2, Y + 3.6, lz0, lx1 - lx0, 6, 0.3, GLASS, "Glass", { tag = "HouseWindow", lit = true })
for k = 0, 3 do add("AnnahmePfosten", "trim", lx0 + k * (lx1 - lx0) / 3, Y + 3.6, lz1, 0.5, 6.4, 0.5, DARK, "Metal") end
add("AnnahmeDach", "roof", (lx0 + lx1) / 2, Y + 7.1, (lz0 + lz1) / 2, lx1 - lx0 + 1, 0.6, lz1 - lz0 + 1, GREY, "Concrete")
add("AnnahmeTuer", "trim", lx0 + (lx1 - lx0) / 2, Y + 3.2, lz1 + 0.2, 3.6, 5.6, 0.2, DARK, "Metal")
add("AnnahmePflanze", "bush", lx0 + 3, Y + 1.6, lz0 + 4, 2.6, 2.6, 2.6, { 56, 110, 60 }, "Grass", { shape = "Ball" })
add("AnnahmeTresen", "decor", lx0 + 4, Y + 1.5, lz1 - 5, 7, 2.4, 1.6, { 150, 112, 76 }, "Wood", { collide = true })
add("AnnahmeSchild", "sign", lx0 + (lx1 - lx0) / 2, Y + 8.1, lz1 + 0.3, 10, 1.6, 0.3, YELLOW, "SmoothPlastic")
text("AnnahmeSchrift", lx0 + (lx1 - lx0) / 2, Y + 8.1, lz1 + 0.55, 9.2, 1.1, "Kundenannahme", { 0, 0, 0 }, YELLOW, 1)
local zs0, zs1 = W.z1 - 16, W.z1 - 0.5
for x = W.x0 + 8, W.x1 - 8, 8 do add("StellplatzLinie", "dash", x, Y + 0.1, (zs0 + zs1) / 2, 0.3, 0.2, zs1 - zs0, { 240, 240, 236 }, "SmoothPlastic") end
stats.stalls = math.floor((W.x1 - W.x0 - 16) / 8)
add("StellplatzLinie", "dash", (W.x0 + W.x1) / 2, Y + 0.1, zs0, W.x1 - W.x0 - 16, 0.2, 0.3, { 240, 240, 236 }, "SmoothPlastic")
local fx = W.x1 - 0.5
for z = W.z0 + 2, W.z1 - 8, 6 do
if z < W.gate[1] or z > W.gate[2] then
add("ZaunPfosten", "fence", fx, Y + 2, z, 0.4, 4, 0.4, GREY, "Metal", { collide = true })
add("ZaunFeld", "fence", fx, Y + 2, z + 3, 0.2, 3.4, 5.6, { 170, 174, 180 }, "Metal", { collide = true, transparency = 0.2 })
end
end
local px, pz = W.x1 - 6, W.z1 - 1
add("PylonMast", "trim", px, Y + 5, pz, 1.0, 10, 1.0, DARK, "Metal", { collide = true })
add("PylonSchild", "sign", px, Y + 13, pz, 7, 5.6, 0.6, YELLOW, "SmoothPlastic")
for _, fz in ipairs({ 1, -1 }) do
text("PylonSchrift", px, Y + 14, pz + fz * 0.35, 6, 2.2, "ADAN", { 0, 0, 0 }, YELLOW, fz)
text("PylonSchrift", px, Y + 11.4, pz + fz * 0.35, 6, 1.4, "Werkstatt", { 0, 0, 0 }, YELLOW, fz)
end
for _, lx in ipairs({ W.x0 + 22, W.x1 - 24 }) do
local lz = bz1 + 9
add("LampenMast", "lamp", lx, Y + 5, lz, 0.5, 10, 0.5, { 40, 56, 48 }, "Metal", { collide = true })
add("LampenKopf", "lamp", lx, Y + 10.3, lz, 2.6, 0.6, 1.2, { 255, 226, 150 }, "Neon", { tag = "StreetLamp", attrs = { Lit = true } })
stats.lamps = stats.lamps + 1
end
return { parts = parts, stats = stats }
end
return Werkstatt

end)()
local Anlagen = (function()
local Geo = Geo
local Anlagen = {}
local GREENS = { { 70, 120, 60 }, { 88, 140, 70 }, { 56, 100, 56 }, { 104, 150, 76 }, { 64, 112, 80 } }
local WILLOW = { { 128, 156, 84 }, { 112, 148, 88 }, { 142, 164, 96 } }
local BARK, KIES, STONE, HEDGE = { 96, 70, 48 }, { 206, 196, 172 }, { 150, 146, 134 }, { 46, 92, 52 }
local function newRng(seed)
local s = seed % 2147483647
if s <= 0 then s = s + 2147483646 end
return function()
s = (s * 48271) % 2147483647
return s / 2147483647
end
end
local function inside(poly, x, z) -- Punkt im Polygon (Strahlverfahren)
local c, n = false, #poly
local j = n
for i = 1, n do
local a, b = poly[i], poly[j]
if (a[2] > z) ~= (b[2] > z) and x < (b[1] - a[1]) * (z - a[2]) / (b[2] - a[2]) + a[1] then c = not c end
j = i
end
return c
end
local function distPoly(poly, x, z) -- kleinster Abstand zum Rand
local best = 1e9
for i = 1, #poly do
local a, b = poly[i], poly[i % #poly + 1]
local dx, dz = b[1] - a[1], b[2] - a[2]
local l2 = dx * dx + dz * dz
local t = l2 > 0 and math.max(0, math.min(1, ((x - a[1]) * dx + (z - a[2]) * dz) / l2)) or 0
best = math.min(best, math.sqrt((x - a[1] - t * dx) ^ 2 + (z - a[2] - t * dz) ^ 2))
end
return best
end
function Anlagen.terrain(cfg)
local ops = {}
local G = cfg.groundTop
for _, s in ipairs(cfg.anlagen) do
if s.lawn ~= false then
local minX, maxX = 1e9, -1e9
for _, p in ipairs(s.poly) do minX, maxX = math.min(minX, p[1]), math.max(maxX, p[1]) end
for x = minX + 2, maxX, 4 do
local zs = {}
for i = 1, #s.poly do
local a, b = s.poly[i], s.poly[i % #s.poly + 1]
if (a[1] > x) ~= (b[1] > x) then zs[#zs + 1] = a[2] + (x - a[1]) / (b[1] - a[1]) * (b[2] - a[2]) end
end
table.sort(zs)
for k = 1, #zs - 1, 2 do
local z0, z1 = zs[k], zs[k + 1]
if z1 - z0 > 1 then
ops[#ops + 1] = { op = "block", material = "Grass", pos = { Geo.round3(x), G - 2, Geo.round3((z0 + z1) / 2) }, size = { 4, 4, Geo.round3(z1 - z0) }, yaw = 0, tag = "anlage" }
end
end
end
end
end
return ops
end
function Anlagen.plan(cfg)
local parts, stats = {}, { areas = 0, trees = 0, benches = 0, lamps = 0, rocks = 0, bushes = 0, beds = 0, pathSegs = 0 }
local function add(name, kind, x, y, z, sx, sy, sz, color, mat, e)
e = e or {}
parts[#parts + 1] = {
name = name, kind = kind, size = { Geo.round3(sx), Geo.round3(sy), Geo.round3(sz) }, pos = { Geo.round3(x), Geo.round3(y), Geo.round3(z) }, yaw = Geo.round3(e.yaw or 0),
pitch = 0, roll = e.roll, color = color, material = mat, collide = e.collide == true, shape = e.shape, tag = e.tag, lit = e.lit, attrs = e.attrs, transparency = e.transparency,
}
end
local function disc(name, x, y, z, dia, h, color, mat, e)
e = e or {}
e.shape, e.roll = "Cylinder", 90
add(name, "decor", x, y, z, h, dia, dia, color, mat, e)
end
local function tree(rng, x, z, scale, palette)
local h = (6 + 5 * rng()) * scale
local cw = (9 + 6 * rng()) * scale
local g = palette[math.floor(rng() * #palette) + 1]
add("AnlageStamm", "tree", x, h / 2, z, 1.4, h, 1.4, BARK, "Wood", { collide = true })
add("AnlageKrone", "tree", x, h + cw * 0.35, z, cw, cw, cw, g, "Grass", { shape = "Ball" })
if rng() < 0.55 then
add("AnlageKrone", "tree", x + (rng() - 0.5) * 4, h + cw * 0.15, z + (rng() - 0.5) * 4, cw * 0.75, cw * 0.75, cw * 0.75, palette[math.floor(rng() * #palette) + 1], "Grass", { shape = "Ball" })
end
stats.trees = stats.trees + 1
end
local function bench(x, z, nx, nz) -- Lehne zeigt in Richtung (nx, nz), Blick zum Weg
local yaw = math.deg(math.atan2(nx, nz))
local r = math.rad(yaw)
local sx, sz = math.sin(r), math.cos(r)
add("BankSitz", "bench", x, 1.3, z, 4.4, 0.4, 1.5, { 130, 90, 60 }, "Wood", { yaw = yaw, collide = true })
add("BankLehne", "bench", x + sx * 0.7, 2.3, z + sz * 0.7, 4.4, 1.2, 0.3, { 130, 90, 60 }, "Wood", { yaw = yaw })
for _, sd in ipairs({ -1.8, 1.8 }) do add("BankBein", "bench", x + math.cos(r) * sd, 0.65, z - math.sin(r) * sd, 0.4, 1.3, 1.2, { 60, 62, 66 }, "Metal", { yaw = yaw }) end
stats.benches = stats.benches + 1
end
local function lamp(x, z)
add("AnlagenMast", "lamp", x, 5, z, 0.5, 10, 0.5, { 40, 56, 48 }, "Metal", { collide = true })
add("AnlagenKopf", "lamp", x, 10.4, z, 2.4, 0.8, 2.4, { 255, 226, 150 }, "Neon", { tag = "StreetLamp", attrs = { Lit = true } })
stats.lamps = stats.lamps + 1
end
for _, s in ipairs(cfg.anlagen) do
stats.areas = stats.areas + 1
local rng = newRng(s.seed or 11)
local poly = s.poly
local minX, maxX, minZ, maxZ = 1e9, -1e9, 1e9, -1e9
for _, p in ipairs(poly) do minX, maxX, minZ, maxZ = math.min(minX, p[1]), math.max(maxX, p[1]), math.min(minZ, p[2]), math.max(maxZ, p[2]) end
local function clear(x, z, extra) -- frei von Wegen, Teichen, Beeten
for _, p in ipairs(s.paths or {}) do
if Geo.polyDist(x, z, p.pts) < p.w / 2 + extra then return false end
end
for _, q in ipairs(s.ponds or {}) do
if (x - q[1]) ^ 2 + (z - q[2]) ^ 2 < (q[3] + 2 + extra) ^ 2 then return false end
end
for _, b in ipairs(s.beds or {}) do
if x > b[1] - 2 - extra and x < b[1] + b[3] * 5 + extra and z > b[2] - 2 - extra and z < b[2] + b[4] * 5 + extra then return false end
end
return true
end
for _, p in ipairs(s.paths or {}) do
for i = 1, #p.pts - 1 do
local a, b = p.pts[i], p.pts[i + 1]
local ux, uz, len = Geo.dir(a[1], a[2], b[1], b[2])
add("AnlagenWeg", "path", (a[1] + b[1]) / 2, 0.15, (a[2] + b[2]) / 2, len, 0.4, p.w, KIES, "Pavement", { yaw = Geo.yawOf(ux, uz) })
stats.pathSegs = stats.pathSegs + 1
if i < #p.pts - 1 then disc("AnlagenWegGelenk", b[1], 0.15, b[2], p.w, 0.4, KIES, "Pavement") end
end
end
for _, q in ipairs(s.ponds or {}) do
disc("Teich", q[1], 0.1, q[2], q[3] * 2, 0.5, { 52, 112, 132 }, "SmoothPlastic", { transparency = 0.2 })
local n = math.max(12, math.floor(q[3] * 1.4))
for k = 0, n - 1 do
local th = 2 * math.pi * k / n
add("TeichRand", "decor", q[1] + (q[3] + 0.6) * math.cos(th), 0.55, q[2] + (q[3] + 0.6) * math.sin(th), 2 * math.pi * (q[3] + 0.6) / n + 0.3, 1.1, 1.8, STONE, "Cobblestone", { yaw = math.deg(-th) + 90, collide = true })
end
end
for _, b in ipairs(s.beds or {}) do
local cols = { { 214, 80, 96 }, { 236, 200, 70 }, { 150, 100, 190 }, { 240, 240, 236 } }
for i = 0, b[3] - 1 do
for j = 0, b[4] - 1 do
add("Beet", "decor", b[1] + i * 5 + 2.5, 0.25, b[2] + j * 5 + 2.5, 4.2, 0.5, 4.2, cols[(i + 2 * j) % #cols + 1], "Grass")
end
end
for _, e in ipairs({ { b[1] + b[3] * 2.5, b[2] - 0.5, b[3] * 5 + 1, 1 }, { b[1] + b[3] * 2.5, b[2] + b[4] * 5 + 0.5, b[3] * 5 + 1, 1 }, { b[1] - 0.5, b[2] + b[4] * 2.5, 1, b[4] * 5 }, { b[1] + b[3] * 5 + 0.5, b[2] + b[4] * 2.5, 1, b[4] * 5 } }) do
add("BeetHecke", "decor", e[1], 0.7, e[2], e[3], 1.4, e[4], HEDGE, "Grass", { collide = true })
end
stats.beds = stats.beds + 1
end
for _, r in ipairs(s.rows or {}) do
for x = r.x0, r.x1, r.step do tree(rng, x, r.z, 0.95, GREENS) end
end
if s.trees then
local st = s.trees.step
for x = minX + st / 2, maxX, st do
for z = minZ + st / 2, maxZ, st do
local tx, tz = x + (rng() - 0.5) * st * 0.7, z + (rng() - 0.5) * st * 0.7
if rng() < (s.trees.density or 0.7) and inside(poly, tx, tz) and distPoly(poly, tx, tz) > (s.trees.edge or 7) and clear(tx, tz, 6) then
tree(rng, tx, tz, s.trees.scale or 1, s.willow and WILLOW or GREENS)
end
end
end
end
for _ = 1, s.bushes or 0 do
for _ = 1, 8 do -- bis zu 8 Versuche pro Busch
local x, z = minX + rng() * (maxX - minX), minZ + rng() * (maxZ - minZ)
if inside(poly, x, z) and distPoly(poly, x, z) > 3 and clear(x, z, 2) then
local d = 4 + rng() * 2.5
add("AnlagenBusch", "bush", x, d / 2 - 0.4, z, d, d, d, GREENS[math.floor(rng() * #GREENS) + 1], "Grass", { shape = "Ball" })
stats.bushes = stats.bushes + 1
break
end
end
end
for _ = 1, s.rocks or 0 do
for _ = 1, 8 do
local x, z = minX + rng() * (maxX - minX), minZ + rng() * (maxZ - minZ)
if inside(poly, x, z) and distPoly(poly, x, z) > 3 and clear(x, z, 2) then
local sx, sy, sz = 3 + rng() * 4, 1.5 + rng() * 1.5, 3 + rng() * 3
add("Findling", "rock", x, sy / 2 - 0.3, z, sx, sy, sz, { 120 + rng() * 40, 118 + rng() * 36, 110 + rng() * 30 }, "Rock", { yaw = rng() * 360, collide = true })
stats.rocks = stats.rocks + 1
break
end
end
end
for _, p in ipairs(s.paths or {}) do
local total, acc = 0, {}
for i = 1, #p.pts - 1 do
local _, _, len = Geo.dir(p.pts[i][1], p.pts[i][2], p.pts[i + 1][1], p.pts[i + 1][2])
acc[i] = total
total = total + len
end
local function at(d)
for i = #p.pts - 1, 1, -1 do
if d >= acc[i] then
local a, b = p.pts[i], p.pts[i + 1]
local ux, uz = Geo.dir(a[1], a[2], b[1], b[2])
return a[1] + ux * (d - acc[i]), a[2] + uz * (d - acc[i]), -uz, ux
end
end
end
local side = 1
if p.benchStep then
for d = p.benchStep / 2, total - 6, p.benchStep do
local x, z, nx, nz = at(d)
local bx, bz = x + nx * side * (p.w / 2 + 2.4), z + nz * side * (p.w / 2 + 2.4)
if inside(poly, bx, bz) and distPoly(poly, bx, bz) > 3 and clear(bx, bz, 0) then bench(bx, bz, nx * side, nz * side) end
side = -side
end
end
if p.lampStep then
for d = p.lampStep / 2, total - 6, p.lampStep do
local x, z, nx, nz = at(d)
local lx, lz = x + nx * side * (p.w / 2 + 1.6), z + nz * side * (p.w / 2 + 1.6)
if inside(poly, lx, lz) and distPoly(poly, lx, lz) > 2 then lamp(lx, lz) end
side = -side
end
end
end
end
return { parts = parts, stats = stats }
end
return Anlagen

end)()
local Tram = (function()
local Geo = Geo
local Tram = {}
local BLUE, WHITE, GREY, DARK, YELLOW = { 0, 98, 175 }, { 240, 244, 248 }, { 176, 178, 180 }, { 38, 42, 50 }, { 250, 210, 40 }
local GLASS = { 170, 210, 235 }
local BED_Y, RAIL_Y, FLOOR = 0.83, 1.01, 2.5
function Tram.path(cfg)
local v = cfg.tram.route
local pts = { { x = v[1][1], z = v[1][2] } }
local prevT = 0 -- Tangentenlänge der vorigen Rundung
for i = 2, #v - 1 do
local P, A, B = v[i], v[i - 1], v[i + 1]
local ax, az, al = Geo.dir(P[1], P[2], A[1], A[2])
local bx, bz, bl = Geo.dir(P[1], P[2], B[1], B[2])
local phi = math.acos(math.max(-1, math.min(1, ax * bx + az * bz))) -- Innenwinkel zwischen den Schenkeln
local R = P[3] or 0
if R <= 0 or phi > math.pi - 1e-4 then
assert(prevT <= al + 1e-6, "Tram: Rundungen überlappen bei Eckpunkt " .. i)
pts[#pts + 1] = { x = P[1], z = P[2] }
prevT = 0
else
local t = R / math.tan(phi / 2)
assert(t + prevT <= al + 1e-6, "Tram: Rundung R" .. R .. " passt nicht auf den Schenkel vor Eckpunkt " .. i)
local mx, mz = ax + bx, az + bz
local ml = math.sqrt(mx * mx + mz * mz)
local c = R / math.sin(phi / 2)
local cx, cz = P[1] + mx / ml * c, P[2] + mz / ml * c
local a0 = math.atan2(P[2] + az * t - cz, P[1] + ax * t - cx)
local turn = math.pi - phi
local sweep = ((-ax) * bz - (-az) * bx > 0 and 1 or -1) * turn -- Drehsinn der Fahrt
local n = math.max(2, math.ceil(R * turn / 3.5))
for k = 0, n do
local a = a0 + sweep * k / n
pts[#pts + 1] = { x = cx + R * math.cos(a), z = cz + R * math.sin(a) }
end
local e = pts[#pts]
assert(math.abs(e.x - (P[1] + bx * t)) < 0.05 and math.abs(e.z - (P[2] + bz * t)) < 0.05, "Tram: Rundung dreht falsch herum bei Eckpunkt " .. i)
prevT = t
end
end
local last = v[#v]
local _, _, ll = Geo.dir(v[#v - 1][1], v[#v - 1][2], last[1], last[2])
assert(prevT <= ll + 1e-6, "Tram: letzte Rundung passt nicht auf den Endschenkel")
pts[#pts + 1] = { x = last[1], z = last[2] }
local s = 0
pts[1].s = 0
for i = 2, #pts do
s = s + math.sqrt((pts[i].x - pts[i - 1].x) ^ 2 + (pts[i].z - pts[i - 1].z) ^ 2)
pts[i].s = s
end
return { pts = pts, len = s }
end
function Tram.at(path, s)
local pts = path.pts
local lo, hi = 1, #pts
while hi - lo > 1 do
local mid = math.floor((lo + hi) / 2)
if pts[mid].s <= s then lo = mid else hi = mid end
end
local a, b = pts[lo], pts[hi]
local ux, uz, l = Geo.dir(a.x, a.z, b.x, b.z)
local t = math.max(0, math.min(l, s - a.s))
return a.x + ux * t, a.z + uz * t, ux, uz
end
function Tram.stops(cfg, path)
local out = {}
for i, st in ipairs(cfg.tram.stops) do
local best = { d = 1e9 }
for k = 1, #path.pts - 1 do
local a, b = path.pts[k], path.pts[k + 1]
local dx, dz = b.x - a.x, b.z - a.z
local l2 = dx * dx + dz * dz
local t = math.max(0, math.min(1, ((st.x - a.x) * dx + (st.z - a.z) * dz) / l2))
local d = math.sqrt((st.x - a.x - t * dx) ^ 2 + (st.z - a.z - t * dz) ^ 2)
if d < best.d then best = { d = d, s = a.s + t * math.sqrt(l2) } end
end
local x, z, ux, uz = Tram.at(path, best.s)
out[i] = { name = st.name, s = best.s, x = x, z = z, ux = ux, uz = uz, off = best.d, side = st.side or 1 }
assert(i == 1 or out[i].s > out[i - 1].s, "Tram: Halte müssen entlang der Strecke aufsteigen: " .. st.name)
end
return out
end
local function frame(cx, cz, fx, fz, parts, attrs)
local yaw = Geo.yawOf(fx, fz)
return function(name, kind, lx, y, lz, sx, sy, sz, color, mat, o)
o = o or {}
local p = {
name = name, kind = kind, size = { sx, sy, sz }, pos = { Geo.round3(cx + lx * fx - lz * fz), Geo.round3(y), Geo.round3(cz + lx * fz + lz * fx) },
yaw = (yaw + (o.yaw or 0)) % 360, pitch = 0, color = color, material = mat, collide = o.collide == true, shape = o.shape, roll = o.roll,
tag = o.tag, text = o.text, transparency = o.transparency, attrs = o.attrs or attrs,
}
parts[#parts + 1] = p
return p
end
end
local function track(path, T, parts)
for i = 1, #path.pts - 1 do
local a, b = path.pts[i], path.pts[i + 1]
local ux, uz, l = Geo.dir(a.x, a.z, b.x, b.z)
local add = frame((a.x + b.x) / 2, (a.z + b.z) / 2, ux, uz, parts)
add("Gleisbett", "rail", 0, BED_Y, 0, l + 0.3, 0.14, T.bed, { 96, 98, 100 }, "Concrete")
for _, o in ipairs({ -1, 1 }) do add("Schiene", "rail", 0, RAIL_Y, o * T.gauge / 2, l + 0.3, 0.22, 0.4, { 150, 154, 160 }, "Metal") end
end
for _, e in ipairs({ { path.pts[1], path.pts[2] }, { path.pts[#path.pts], path.pts[#path.pts - 1] } }) do
local ux, uz = Geo.dir(e[2].x, e[2].z, e[1].x, e[1].z) -- vom Streckenende weg
local add = frame(e[1].x + ux * 1.2, e[1].z + uz * 1.2, ux, uz, parts)
add("Prellbock", "rail", 0, 1.5, 0, 1.6, 1.4, 5.2, { 200, 60, 50 }, "Metal")
add("PrellbockStreifen", "rail", 0, 1.5, 0, 1.7, 0.5, 5.3, YELLOW, "Metal")
end
end
local function stop(parts, st, i, T)
local P = T.platform
local add = frame(st.x, st.z, st.side * st.ux, st.side * st.uz, parts, { Haltestelle = st.name })
local zc = P.off + P.w / 2
add("Bahnsteig", "trim", 0, 0.75, zc, P.len, 0.5, P.w, GREY, "Concrete", { collide = true })
add("Bahnsteigkante", "trim", 0, 1.03, P.off + 0.4, P.len, 0.06, 0.7, YELLOW, "SmoothPlastic")
local zr, zb = P.off + 1.8, P.off + P.w - 0.6 -- Vorderkante und Rückwand
local zm = (zr + zb) / 2
add("Dach", "trim", 0, 9.2, zm, 12, 0.4, zb - zr + 0.8, BLUE, "Metal")
for _, lx in ipairs({ -5.6, 5.6 }) do
for _, lz in ipairs({ zr + 0.4, zb - 0.4 }) do add("Pfosten", "trim", lx, 5.1, lz, 0.4, 8.2, 0.4, BLUE, "Metal") end
end
add("Rueckwand", "glass", 0, 4.4, zb, 11.6, 6.4, 0.2, GLASS, "Glass")
add("Seitenwand", "glass", -5.8, 4.4, zm, 0.2, 6.4, zb - zr, GLASS, "Glass")
add("Bank", "trim", 0, 2.0, zb - 1.0, 7, 0.4, 1.4, { 140, 100, 64 }, "Wood")
for _, lx in ipairs({ -2.8, 2.8 }) do add("Bankstuetze", "trim", lx, 1.5, zb - 1.0, 0.4, 1.0, 1.2, DARK, "Metal") end
add("Fahrplan", "sign", 3.8, 4.8, zb - 0.2, 1.8, 2.6, 0.2, YELLOW, "SmoothPlastic")
add("Leuchte", "lamp", 0, 8.95, zm, 6, 0.2, 0.6, { 255, 248, 225 }, "Neon", { tag = "StreetLamp", attrs = { Lit = true, Haltestelle = st.name } })
add("Namensband", "sign", 0, 8.4, zr - 0.1, 12.4, 1.5, 0.25, BLUE, "SmoothPlastic")
add("Haltestellenname", "sign", 0, 8.4, zr - 0.3, 11.8, 1.1, 0.1, BLUE, "SmoothPlastic", { text = { s = st.name, color = WHITE } })
for _, lx in ipairs({ -17.5, 17.5 }) do
local lz = P.off + 0.9
add("SchildMast", "trim", lx, 6.5, lz, 0.4, 11, 0.4, { 120, 124, 130 }, "Metal")
add("SchildScheibe", "sign", lx, 10.6, lz - 0.1, 0.3, 3.6, 3.6, BLUE, "SmoothPlastic", { shape = "Cylinder", yaw = 90 })
add("SchildH", "sign", lx, 10.6, lz - 0.32, 2.4, 2.4, 0.2, BLUE, "SmoothPlastic", { text = { s = "H", color = WHITE } })
end
end
local function car(T, cx, cz, ux, uz, outer, parts)
local add = frame(cx, cz, ux, uz, parts)
local L, W = T.carLen, T.width
local hw = W / 2
add("Body", "trim", 0, 2.1, 0, L, 0.8, W - 0.4, BLUE, "SmoothPlastic")
add("Innenboden", "trim", 0, FLOOR + 0.06, 0, L - 0.8, 0.1, W - 0.8, { 110, 118, 128 }, "SmoothPlastic")
add("Dach", "trim", 0, 8.75, 0, L, 0.5, W - 0.2, { 214, 220, 226 }, "SmoothPlastic")
add("Dachaufbau", "trim", -outer * 2, 9.35, 0, 6.5, 0.7, 3.4, { 150, 156, 164 }, "Metal")
add("Innenlicht", "lamp", 0, 8.4, 0, 8, 0.12, 0.7, { 255, 248, 225 }, "Neon", { tag = "StreetLamp", attrs = { Lit = true } })
for _, bx in ipairs({ -4.6, 4.6 }) do add("Drehgestell", "trim", bx, 1.5, 0, 4, 0.8, 4.6, DARK, "Metal") end
for _, lx in ipairs({ -2.9, 2.9 }) do
for _, lz in ipairs({ -1.6, 1.6 }) do add("Haltestange", "trim", lx, FLOOR + 3, lz, 0.25, 5.9, 0.25, YELLOW, "Metal") end
end
for _, e in ipairs({ -1, 1 }) do
add("Stirn", "trim", e * (L / 2 - 0.25), 5.7, 0, 0.5, 6.4, W - 0.4, BLUE, "SmoothPlastic")
if e == outer then
local ex = e * (L / 2)
add("Frontscheibe", "glass", ex + e * 0.02, 6.6, 0, 0.2, 2.6, W - 1.6, { 30, 44, 60 }, "Glass")
for _, lz in ipairs({ -2.5, 2.5 }) do add("Scheinwerfer", "lamp", ex + e * 0.05, 3.4, lz, 0.2, 0.8, 0.9, { 255, 244, 200 }, "Neon") end
add("Stossfaenger", "trim", ex + e * 0.1, 2.8, 0, 0.5, 0.5, W - 0.6, GREY, "Metal")
add("Zielanzeige", "sign", ex + e * 0.06, 8.1, 0, 0.12, 0.9, 4.2, { 20, 22, 26 }, "SmoothPlastic")
add("Ziel", "sign", ex + e * 0.14, 8.1, 0, 4, 0.7, 0.1, { 20, 22, 26 }, "SmoothPlastic", { yaw = e == 1 and 270 or 90, text = { s = "Linie 1", color = { 255, 176, 40 } } })
end
end
if outer == 1 then -- Gelenk zum Hinterwagen, am hinteren Ende des Vorderwagens
add("Faltenbalg", "trim", -(L / 2 + T.gap / 2), 5.6, 0, T.gap + 0.6, 5.8, W - 1.2, { 30, 32, 36 }, "Fabric")
end
for _, s in ipairs({ -1, 1 }) do
local wz = s * (hw - 0.15)
local flip = s == 1 and 0 or 180 -- Sitzmarken schauen zum Gang
add("Schuerze", "trim", 0, FLOOR + 0.95, wz, L - 0.6, 1.9, 0.3, BLUE, "SmoothPlastic")
add("Zierstreifen", "trim", 0, FLOOR + 1.75, wz + s * 0.02, L - 0.6, 0.3, 0.3, WHITE, "SmoothPlastic")
add("Oberteil", "trim", 0, 7.85, wz, L - 0.6, 1.3, 0.3, BLUE, "SmoothPlastic")
for _, lx in ipairs({ -7.75, -2.35, 2.35, 7.75 }) do add("Pfosten", "trim", lx, 5.8, wz, 0.5, 2.8, 0.34, BLUE, "SmoothPlastic") end
for _, lx in ipairs({ -5.05, 5.05 }) do add("Fenster", "glass", lx, 5.8, wz, 5.1, 2.8, 0.2, GLASS, "Glass") end
add("Tuer", "glass", 0, FLOOR + 2.35, wz, 4.2, 4.7, 0.2, { 150, 196, 230 }, "Glass")
add("Tuertaster", "trim", 2.6, FLOOR + 1.9, wz + s * 0.2, 0.4, 0.5, 0.15, YELLOW, "SmoothPlastic")
add("Einstieg", "trim", 0, 4.3, s * (hw + 0.3), 1, 1, 1, BLUE, "SmoothPlastic", { transparency = 1 })
for _, bx in ipairs({ -5.05, 5.05 }) do
add("Bankstuetze", "trim", bx, FLOOR + 0.25, s * (hw - 1.15), 4.6, 0.5, 1.2, DARK, "Metal")
add("Bank", "trim", bx, FLOOR + 0.7, s * (hw - 1.15), 4.8, 0.4, 1.4, { 70, 100, 150 }, "Fabric")
add("Lehne", "trim", bx, FLOOR + 1.6, s * (hw - 0.6), 4.8, 1.3, 0.2, { 70, 100, 150 }, "Fabric")
for _, dx in ipairs({ -1.2, 1.2 }) do add("Sitzmarke", "trim", bx + dx, FLOOR + 1.0, s * (hw - 1.15), 1.9, 0.2, 1.6, WHITE, "SmoothPlastic", { yaw = flip, transparency = 1 }) end
end
end
end
function Tram.plan(cfg)
local T = cfg.tram
local path = Tram.path(cfg)
local stops = Tram.stops(cfg, path)
local parts = {}
track(path, T, parts)
for i, st in ipairs(stops) do stop(parts, st, i, T) end
local d = T.carLen + T.gap -- Abstand der Wagenmitten
local s0 = stops[1].s
local houses, seats = {}, 0
for _, outer in ipairs({ 1, -1 }) do
local x, z, ux, uz = Tram.at(path, s0 + outer * d / 2)
local cp = {}
car(T, x, z, ux, uz, outer, cp)
for _, p in ipairs(cp) do if p.name == "Sitzmarke" then seats = seats + 1 end end
if outer == 1 then -- Strecke und Fahrdaten für TramSteuerung
local rt, sp = {}, {}
for _, p in ipairs(path.pts) do rt[#rt + 1] = string.format("%.1f,%.1f,%.1f;", p.x, p.z, p.s) end
for _, q in ipairs(stops) do sp[#sp + 1] = string.format("%.1f|%d|%s;", q.s, q.side, q.name) end
cp[1].attrs = { Route = table.concat(rt), Stops = table.concat(sp), Abstand = d, Start = s0, Tempo = T.speed, Beschl = T.accel, Halt = T.dwell, HaltEnde = T.dwellEnd, Bahnsteig = T.platform.off + T.platform.w / 2 }
end
houses[#houses + 1] = { name = outer == 1 and "TramVorn" or "TramHinten", floors = 1, side = "Q", parts = cp }
end
return { parts = parts, houses = houses, path = path, stops = stops, stats = { stops = #stops, seats = seats, len = path.len, pathPts = #path.pts } }
end
return Tram

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
collide = extra.collide ~= false, seg = extra.seg, shape = extra.shape, roll = extra.roll, wedge = extra.wedge,
}
end
local function tri(parts, name, p1, p2, p3, top, thick, color, material)
local P = { p1, p2, p3 }
local best, bi = -1, 1
for i = 1, 3 do
local a, b = P[i], P[i % 3 + 1]
local l = (a[1] - b[1]) ^ 2 + (a[2] - b[2]) ^ 2
if l > best then best, bi = l, i end
end
local a, b, c = P[bi], P[bi % 3 + 1], P[(bi + 1) % 3 + 1]
local bx, bz = b[1] - a[1], b[2] - a[2]
local bl = math.sqrt(bx * bx + bz * bz)
if bl < 0.05 then return end
bx, bz = bx / bl, bz / bl
local t = (c[1] - a[1]) * bx + (c[2] - a[2]) * bz
local fx, fz = a[1] + bx * t, a[2] + bz * t
local hx, hz = c[1] - fx, c[2] - fz
local hl = math.sqrt(hx * hx + hz * hz)
if hl < 0.03 then return end
hx, hz = hx / hl, hz / hl
for _, leg in ipairs({ { a, -1 }, { b, 1 } }) do -- zwei Dreiecke: Fußpunkt, Ecke der Grundseite und Spitze
local l1 = (leg[2] < 0) and t or (bl - t)
if l1 > 0.03 then
local dx, dz = leg[2] * bx, leg[2] * bz -- Richtung vom Fußpunkt zur Ecke
part(parts, name, "corner", fx + dx * l1 / 2 + hx * hl / 2, top - thick / 2, fz + dz * l1 / 2 + hz * hl / 2, thick, l1, hl, 0, color, material,
{ wedge = { { dx, 0, dz }, { -hx, 0, -hz } } })
end
end
end
local function strip(parts, name, P, Q, top, thick, color, material)
for i = 1, #P - 1 do
tri(parts, name, P[i], P[i + 1], Q[i], top, thick, color, material)
tri(parts, name, P[i + 1], Q[i + 1], Q[i], top, thick, color, material)
end
end
local TILE, JOINT, JOINT_COLOR = 6, 0.18, { 150, 144, 136 }
local function tileJoints(parts, cx, cz, ux, uz, len, w, top, yaw, seg)
local nx, nz = -uz, ux
local y = top + 0.1 -- Fugen 0,2 hoch: dünnere flackern gegen den Boden
local k = 1
while k * TILE < len do -- Fugen quer zur Länge
local t = -len / 2 + k * TILE
part(parts, "Fuge", "joint", cx + ux * t, y, cz + uz * t, JOINT, 0.2, w, yaw, JOINT_COLOR, "SmoothPlastic", { collide = false, seg = seg })
k = k + 1
end
k = 1
while k * TILE < w do -- Fugen in Längsrichtung
local v = -w / 2 + k * TILE
part(parts, "Fuge", "joint", cx + nx * v, y, cz + nz * v, len, 0.2, JOINT, yaw, JOINT_COLOR, "SmoothPlastic", { collide = false, seg = seg })
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
local function outerSide(d1, d2) -- Außenseite der Kurve von d1 nach d2 (+1 = links der Fahrtrichtung); nil bei fast gerader Fortsetzung
local s = d2[1] * (-d1[2]) + d2[2] * d1[1]
if math.abs(s) < 0.14 then return nil end
return s > 0 and -1 or 1
end
for i = 1, count do
local prev = (i > 1) and i - 1 or (road.closed and count or nil)
local nxt = (i < count) and i + 1 or (road.closed and 1 or nil)
local a, b = pts[i], pts[(i % n) + 1]
local extA, extB = prev and ext(prev, i) or 0, nxt and ext(i, nxt) or 0
segs[#segs + 1] = {
outerA = prev and outerSide(dirs[prev], dirs[i]) or nil, outerB = nxt and outerSide(dirs[i], dirs[nxt]) or nil, nextDir = nxt and dirs[nxt] or nil,
id = #segs + 1, road = road, prof = prof, ax = a[1], az = a[2], ux = dirs[i][1], uz = dirs[i][2], len = dirs[i][3],
extA = extA, extB = extB, rect = Geo.rect(a[1], a[2], b[1], b[2], prof.half, extA, extB),
cutRect = prof.core and Geo.rect(a[1], a[2], b[1], b[2], prof.core, extA, extB) or nil,
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
local function kreiselEcken(cfg)
local K = cfg.kreiselEcken
local out = {}
if not K then return out end
for _, arm in ipairs(K.arms) do
local ul = math.sqrt(arm.u[1] ^ 2 + arm.u[2] ^ 2)
local ux, uz = arm.u[1] / ul, arm.u[2] / ul
for _, side in ipairs({ -1, 1 }) do
local sx, sz = -uz * side, ux * side
local ca, cb = -arm.p0[1] * ux - arm.p0[2] * uz, -arm.p0[1] * sx - arm.p0[2] * sz
local function world(a, b) return arm.p0[1] + ux * a + sx * b, arm.p0[2] + uz * a + sz * b end
local function circleA(d, R, rho) -- a des Mittelpunkts einer Rundung (Radius rho) an Gerade b = d und Kreis R um den Kreiselmittelpunkt
local dd = (R + rho) ^ 2 - (d + rho - cb) ^ 2
return dd > 0 and ca + math.sqrt(dd) or nil
end
local rho0 = K.rho
local oa = circleA(arm.d0, K.r0, rho0)
local D = oa - ca
local rho1 = (D * D + (arm.d1 - cb) ^ 2 - K.r1 ^ 2) / (2 * (K.r1 - (arm.d1 - cb)))
rho1 = math.max(1.5, math.min(20, rho1))
local oa1 = circleA(arm.d1, K.r1, rho1) or oa
local function path(d, R, rho, o) -- Stützpunkte: Gerade, Bogen, Kreisbogen
local ob = d + rho
local phi0, phi1 = -math.pi / 2, math.atan2(cb - ob, ca - o)
local dphi = (phi1 - phi0 + math.pi) % (2 * math.pi) - math.pi
local psi0 = math.atan2(ob - cb, o - ca)
return { o = o, ob = ob, rho = rho, R = R, phi0 = phi0, dphi = dphi, psi0 = psi0, d = d }
end
local A, B = path(arm.d0, K.r0, rho0, oa), path(arm.d1, K.r1, rho1, oa1)
local bEnd = math.max(cb + A.R * math.sin(A.psi0), cb + B.R * math.sin(B.psi0)) + 4.5
local function pts(P, aStart) -- Linienzug in Weltkoordinaten: Start auf der Geraden, Rundung, Kreisbogen des Kreisel-Gehwegs
local line, arc = { { world(aStart, P.d) } }, {}
for i = 0, 9 do
local f = P.phi0 + P.dphi * i / 9
local x, z = world(P.o + P.rho * math.cos(f), P.ob + P.rho * math.sin(f))
line[#line + 1] = { x, z }
arc[#arc + 1] = { x, z }
end
local psiE = math.asin(math.min(0.999, (bEnd - cb) / P.R))
for i = 1, 9 do
local f = P.psi0 + (psiE - P.psi0) * i / 9
local x, z = world(ca + P.R * math.cos(f), cb + P.R * math.sin(f))
line[#line + 1] = { x, z }
end
return line, arc
end
local aStart = arm.cut and (math.max(oa, oa1) + 2) or 1
local lineA, arcA = pts(A, aStart)
local lineB = pts(B, aStart)
local aP = ca + math.sqrt(K.r0 ^ 2 - (arm.d0 - cb) ^ 2) -- Scheitel der Straßenecke (Gerade trifft Kreis)
local ax, az = world(aP, arm.d0)
out[#out + 1] = { arm = arm, side = side, ux = ux, uz = uz, sx = sx, sz = sz, aStart = aStart, world = world, P = lineA, Q = lineB, apex = { ax, az }, apexArc = arcA }
end
end
return out
end
function RoadsPlanner.segments(cfg)
return buildSegments(cfg)
end
local function crossCuts(segs, self, px, pz, L, margin)
local cuts = {}
for _, o in ipairs(segs) do
if o.id ~= self.id and not (o.road == self.road and o.ux * self.ux + o.uz * self.uz > 0.95) then
local lo, hi = Geo.within(px, pz, self.ux, self.uz, L, o.cutRect or o.rect, margin)
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
local curves = kreiselEcken(cfg)
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
if kind == "walk" then
local so = mid > 0 and 1 or -1
if seg.outerA == so then cuts[#cuts + 1] = { -1, 0 } end -- Außenseite von Knicken: Gehweg endet am Knickpunkt, eine Rundung schließt an
if seg.outerB == so then cuts[#cuts + 1] = { L, L + 1 } end
for _, k in ipairs(curves) do
if k.arm.cut and k.arm.road == seg.road.name and (nx * k.sx + nz * k.sz) * mid > 0 and math.abs(math.abs(mid) - (k.arm.d0 + k.arm.d1) / 2) < 0.5 then
local qx, qz = k.world(k.aStart, 0)
local t = (qx - p0x) * seg.ux + (qz - p0z) * seg.uz
cuts[#cuts + 1] = (seg.ux * k.ux + seg.uz * k.uz < 0) and { t, L + 1 } or { -1, t }
end
end
end
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
stats.curves = #curves
for _, k in ipairs(curves) do
strip(parts, "GehwegKurve", k.P, k.Q, TOP.walk, THICK.walk, COLOR.walk, MATERIAL.walk)
for i = 1, #k.apexArc - 1 do -- Asphalt: Fächer vom Scheitel der Straßenecke zur Bordsteinrundung
tri(parts, "EckAsphalt", k.apex, k.apexArc[i], k.apexArc[i + 1], 0.52, 1, COLOR.road, MATERIAL.road)
end
end
local RAMP = 2.5
for _, e in ipairs(cfg.einfahrten or {}) do
local alongX = (e.dir == "E" or e.dir == "W")
local a0, a1 = alongX and e.x0 or e.z0, alongX and e.x1 or e.z1
local b0, b1 = alongX and e.z0 or e.x0, alongX and e.z1 or e.x1
local function piece(name, p0, p1, top)
local ca, cb = (p0 + p1) / 2, (b0 + b1) / 2
local x, z, sx, sz = ca, cb, p1 - p0, b1 - b0
if not alongX then x, z, sx, sz = cb, ca, b1 - b0, p1 - p0 end
part(parts, name, "road", x, top - 0.3, z, sx, 0.6, sz, 0, COLOR.road, MATERIAL.road, {})
end
piece("EinfahrtRampe", a0, a0 + RAMP, 0.78)
piece("Einfahrt", a0 + RAMP, a1 - RAMP, 1.04)
piece("EinfahrtRampe", a1 - RAMP, a1, 0.78)
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
stats.bends = 0
for _, seg in ipairs(segs) do
local so = seg.outerB
if so and seg.nextDir then
local vx, vz = seg.ax + seg.ux * seg.len, seg.az + seg.uz * seg.len
local a0 = math.atan2(so * seg.ux, -so * seg.uz)
local a1 = math.atan2(so * seg.nextDir[1], -so * seg.nextDir[2])
local d = (a1 - a0 + math.pi) % (2 * math.pi) - math.pi
local n = math.max(1, math.ceil(math.abs(d) / (math.pi / 12)))
for _, st in ipairs(seg.prof.strips) do
if st[3] == "walk" and st[1] * so > 0 and st[2] * so > 0 then
local r0, r1 = math.min(math.abs(st[1]), math.abs(st[2])), math.max(math.abs(st[1]), math.abs(st[2]))
local P, Q = {}, {}
for i = 0, n do
local f = a0 + d * i / n
P[#P + 1] = { vx + r0 * math.cos(f), vz + r0 * math.sin(f) }
Q[#Q + 1] = { vx + r1 * math.cos(f), vz + r1 * math.sin(f) }
end
strip(parts, "GehwegKurve", P, Q, TOP.walk, THICK.walk, COLOR.walk, MATERIAL.walk)
stats.bends = stats.bends + 1
end
end
end
end
local CURB = 10
local function walkSide(seg, dirx, dirz) -- Gehwegstreifen von seg auf der Seite der Richtung (dirx, dirz): Abstände (innen, außen) zur Mittellinie; nur direkt an der Fahrbahn
local sideSign = ((-seg.uz) * dirx + seg.ux * dirz) > 0 and 1 or -1
local edge = 0
for _, st in ipairs(seg.prof.strips) do
if st[3] == "road" and (st[1] * sideSign >= -0.01 or st[2] * sideSign >= -0.01) then edge = math.max(edge, st[1] * sideSign, st[2] * sideSign) end
end
for _, st in ipairs(seg.prof.strips) do
if st[3] == "walk" and st[1] * sideSign > 0 and st[2] * sideSign > 0 then
local d0, d1 = math.min(math.abs(st[1]), math.abs(st[2])), math.max(math.abs(st[1]), math.abs(st[2]))
if math.abs(d0 - edge) < 0.01 then return d0, d1 end
end
end
end
local function inRect(r, x, z)
local dx, dz = x - r.ax, z - r.az
local u, v = dx * r.ux + dz * r.uz, dx * r.nx + dz * r.nz
return u > r.s0 and u < r.s1 and math.abs(v) < r.w
end
local function isect(px, pz, dx, dz, qx, qz, ex, ez) -- p + t d = q + s e: liefert t
local det = -dx * ez + ex * dz
if math.abs(det) < 1e-6 then return nil end
return ((qx - px) * (-ez) + ex * (qz - pz)) / det
end
local function cornerPaths(px, pz, ea, eb, da0, da1, db0, db1)
local sinT = math.abs(ea[1] * eb[2] - ea[2] * eb[1])
if sinT < 0.35 then return nil end
local nA = { -ea[2], ea[1] }
if nA[1] * eb[1] + nA[2] * eb[2] < 0 then nA = { ea[2], -ea[1] } end
local nB = { -eb[2], eb[1] }
if nB[1] * ea[1] + nB[2] * ea[2] < 0 then nB = { eb[2], -eb[1] } end
local function off(da, db) -- Schnitt der Linien im Abstand da von A und db von B
local t = isect(px + nA[1] * da, pz + nA[2] * da, ea[1], ea[2], px + nB[1] * db, pz + nB[2] * db, eb[1], eb[2])
return px + nA[1] * da + ea[1] * t, pz + nA[2] * da + ea[2] * t
end
local rho0 = CURB
local rho1 = rho0 * 0.6
local c0x, c0z = off(da0 + rho0, db0 + rho0)
local c1x, c1z = off(da1 + rho1, db1 + rho1)
local apx, apz = off(da0, db0)
local function along(x, z, e) return (x - px) * e[1] + (z - pz) * e[2] end
local cosT = ea[1] * eb[1] + ea[2] * eb[2]
local tanDev = math.min(3, math.abs(cosT) / sinT)
local dmA, dmB = (da0 + da1) / 2, (db0 + db1) / 2
local nn = nA[1] * nB[1] + nA[2] * nB[2]
local t0A = (db1 - dmA * nn) / (ea[1] * nB[1] + ea[2] * nB[2]) -- hier endet der Gehweg von A (Straßenrechteck von B)
local t0B = (da1 - dmB * nn) / (eb[1] * nA[1] + eb[2] * nA[2])
local tsA = math.max(t0A + 1 + (da1 - da0) / 2 * tanDev, along(c0x, c0z, ea) + 1, along(c1x, c1z, ea) + 1)
local tsB = math.max(t0B + 1 + (db1 - db0) / 2 * tanDev, along(c0x, c0z, eb) + 1, along(c1x, c1z, eb) + 1)
local a0, a1 = math.atan2(-nA[2], -nA[1]), math.atan2(-nB[2], -nB[1])
local d = (a1 - a0 + math.pi) % (2 * math.pi) - math.pi
local n = math.max(4, math.ceil(math.abs(d) / (math.pi / 12)))
local P = { { px + nA[1] * da0 + ea[1] * tsA, pz + nA[2] * da0 + ea[2] * tsA } }
local Q = { { px + nA[1] * da1 + ea[1] * tsA, pz + nA[2] * da1 + ea[2] * tsA } }
local arc = {}
for i = 0, n do
local f = a0 + d * i / n
arc[#arc + 1] = { c0x + rho0 * math.cos(f), c0z + rho0 * math.sin(f) }
P[#P + 1] = arc[#arc]
Q[#Q + 1] = { c1x + rho1 * math.cos(f), c1z + rho1 * math.sin(f) }
end
P[#P + 1] = { px + nB[1] * db0 + eb[1] * tsB, pz + nB[2] * db0 + eb[2] * tsB }
Q[#Q + 1] = { px + nB[1] * db1 + eb[1] * tsB, pz + nB[2] * db1 + eb[2] * tsB }
return P, Q, { apx, apz }, arc, c0x, c0z
end
stats.corners = 0
stats.skips = {}
for i = 1, #segs do
for j = i + 1, #segs do
local A, B = segs[i], segs[j]
local bend = A.road == B.road and A.nextDir ~= nil and math.abs(A.ax + A.ux * A.len - B.ax) < 0.01 and math.abs(A.az + A.uz * A.len - B.az) < 0.01
and math.abs(A.ux * B.uz - A.uz * B.ux) >= 0.5
if (A.road ~= B.road or bend) and not A.prof.core and not B.prof.core then
local ta = isect(A.ax, A.az, A.ux, A.uz, B.ax, B.az, B.ux, B.uz)
local tb = isect(B.ax, B.az, B.ux, B.uz, A.ax, A.az, A.ux, A.uz)
if ta and tb and ta > -0.5 and ta < A.len + 0.5 and tb > -0.5 and tb < B.len + 0.5 then
local px, pz = A.ax + A.ux * ta, A.az + A.uz * ta
for _, sa in ipairs({ -1, 1 }) do
for _, sb in ipairs({ -1, 1 }) do
local ea, eb = { sa * A.ux, sa * A.uz }, { sb * B.ux, sb * B.uz }
local da0, da1 = walkSide(A, eb[1], eb[2]) -- Gehweg von A auf der Seite von B
local db0, db1 = walkSide(B, ea[1], ea[2])
if da0 and db0 then
local extA = (sa > 0) and (A.len - ta) or ta
local extB = (sb > 0) and (B.len - tb) or tb
local P, Q, apex, arc, cx, cz
if extA >= db1 - 0.5 and extB >= da1 - 0.5 then P, Q, apex, arc, cx, cz = cornerPaths(px, pz, ea, eb, da0, da1, db0, db1) end
local free = P ~= nil
local why = P == nil and (extA >= db1 - 0.5 and extB >= da1 - 0.5 and "Winkel" or "kurz") or nil
for _, C in ipairs(segs) do
if free and C.road ~= A.road and C.road ~= B.road and inRect(C.rect, cx, cz) then free = false why = "belegt " .. C.road.name end
end
if why then stats.skips[#stats.skips + 1] = { A.road.name, B.road.name, px, pz, why } end
if free then
strip(parts, "GehwegKurve", P, Q, TOP.walk, THICK.walk, COLOR.walk, MATERIAL.walk)
for k = 1, #arc - 1 do tri(parts, "EckAsphalt", apex, arc[k], arc[k + 1], 0.52, 1, COLOR.road, MATERIAL.road) end
stats.corners = stats.corners + 1
end
end
end
end
end
end
end
end
stats.zebras = 0
for _, cr in ipairs(cfg.crossings or {}) do
local yaw = Geo.yawOf(cr.ux, cr.uz)
local nx, nz = -cr.uz, cr.ux
local a = cr.a0 + 1
while a + 1 <= cr.a1 do
part(parts, "Zebra", "dash", cr.x + nx * a, DASH_Y, cr.z + nz * a, 10, DASH_H, 2, yaw, COLOR.dash, "SmoothPlastic", { collide = false })
a = a + 4
end
stats.zebras = stats.zebras + 1
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
local blocks, cv = { { s0, s1 } }, b.culvert -- bei einem Durchlass (Eisbach) in zwei Blöcke mit Öffnung dazwischen geteilt
if cv and sd * cv.s > 0 then blocks = { { s0, math.abs(cv.s) - cv.w / 2 }, { math.abs(cv.s) + cv.w / 2, s1 } } end
for _, bl in ipairs(blocks) do
local bx, bz = at(sd * (bl[1] + bl[2]) / 2, 0)
part(parts, "BrueckeWiderlager", "deck", bx, -4.5, bz, bl[2] - bl[1], 7, total - 4, b.yaw, BODY, "Concrete", {})
end
local x, z = at(sd * b.span, 0) -- Fuß unter dem Bogenansatz bis in die Kiesbank
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
if b.culvert then
local xc, L = b.culvert.s, total - 4
local PIER = 4
local ah = (b.culvert.w - PIER) / 4 -- halbe Spannweite je Bogen
local ys, f, crown = -5.0, 4.0, -1.0 -- Kämpfer, Pfeilhöhe, Scheitel der Untersicht (Unterkante Fahrbahn)
local R = (ah * ah + f * f) / (2 * f)
local GREY, LIGHT = { 150, 146, 134 }, { 214, 208, 194 }
local px, pz = at(xc, 0)
part(parts, "EisbachPfeiler", "deck", px, -5, pz, PIER, 8, L, b.yaw, GREY, "Cobblestone", {})
for _, sc in ipairs({ xc - PIER / 2 - ah, xc + PIER / 2 + ah }) do
local n = 16
local w = 2 * ah / n
for k = 1, n do
local sm = sc - ah + (k - 0.5) * w
local soffit = ys + math.sqrt(R * R - (sm - sc) ^ 2) - (R - f)
if soffit < crown - 0.05 then
local x, z = at(sm, 0)
part(parts, "EisbachBogen", "deck", x, (soffit + crown) / 2, z, w + 0.05, crown - soffit, L, b.yaw, GREY, "Cobblestone", {})
end
end
end
for _, sd in ipairs({ -1, 1 }) do
local lat = sd * (b.wid / 2 + b.walk - 0.4)
local x, z = at(xc, lat)
part(parts, "EisbachBruestung", "rail", x, 2.2, z, b.culvert.w + 4, 2.8, 1.0, b.yaw, { 172, 166, 152 }, "Concrete", {})
for _, s in ipairs({ xc - PIER / 2 - ah, xc, xc + PIER / 2 + ah }) do -- Rosetten über den Bögen und dem Pfeiler
local rx, rz = at(s, lat + sd * 0.55)
part(parts, "EisbachRosette", "decor", rx, 2.3, rz, 0.3, 2.0, 2.0, b.yaw + 90, LIGHT, "Concrete", { shape = "Cylinder", collide = false })
rx, rz = at(s, lat + sd * 0.5)
part(parts, "EisbachRosettenring", "decor", rx, 2.3, rz, 0.2, 2.7, 2.7, b.yaw + 90, { 120, 116, 106 }, "Concrete", { shape = "Cylinder", collide = false })
end
for _, sp in ipairs({ -1, 1 }) do -- Eckpfosten mit Kugel
local ex, ez = at(xc + sp * (b.culvert.w / 2 + 2.4), lat)
part(parts, "EisbachPfosten", "decor", ex, 3.0, ez, 1.6, 5.0, 1.6, b.yaw, { 160, 154, 140 }, "Concrete", {})
part(parts, "EisbachPfostenKugel", "decor", ex, 5.9, ez, 1.4, 1.4, 1.4, b.yaw, { 160, 154, 140 }, "Concrete", { shape = "Ball", collide = false })
end
end
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
local sp = seg.road.lampSpacing or L.spacing -- Straßen mit lampSpacing: weniger Laternen, abwechselnd links und rechts
local t = seg.road.lampSpacing and (side > 0 and sp / 2 or sp) or sp / 2
while t < seg.len do
local x, z = seg.ax + seg.ux * t + nx * off, seg.az + seg.uz * t + nz * off
if onWalk(walks, x, z) and not inDriveway(cfg, x, z) then
lamp(parts, x, z, -nx * side, -nz * side, L.height)
stats.lamps = stats.lamps + 1
end
t = t + sp
end
end
end
end
for _, l in ipairs(cfg.extraLamps or {}) do
lamp(parts, l[1], l[2], l[3], l[4], L.height)
stats.lamps = stats.lamps + 1
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
local BRONZE, GOLD = { 92, 140, 118 }, { 226, 184, 72 }
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
local function deco(name, x, y, z, sx, sy, sz, color, mat, extra)
extra = extra or {}
extra.collide = false
add(name, x, y, z, sx, sy, sz, color, mat, extra)
end
local function vcyl(name, x, y, z, h, d, color, mat)
add(name, x, y, z, h, d, d, color, mat, { shape = "Cylinder", roll = 90, collide = false })
end
for _, sz in ipairs({ -1, 1 }) do
local z = sz * (D / 2 + 0.8)
for _, x in ipairs({ -27.5, -10.5, 10.5, 27.5 }) do
add("Saeule", x, y0 + 20, z, 36, 2.4, 2.4, LIGHT, "Concrete", { shape = "Cylinder", roll = 90 })
add("SaeuleSockel", x, y0 + 1, z, 3.8, 2, 3.8, DARK, "Concrete")
vcyl("SaeuleFuss", x, y0 + 2.5, z, 1, 3.2, STONE, "Concrete")
for i = 0, 5 do -- Kanneluren
local an = math.rad(i * 60)
deco("Kannelur", x + 1.2 * math.cos(an), y0 + 20, z + 1.2 * math.sin(an), 0.25, 33, 0.25, DARK, "Concrete")
end
vcyl("SaeuleHals", x, y0 + 37.6, z, 0.8, 2.8, STONE, "Concrete")
vcyl("SaeuleKelch", x, y0 + 39, z, 2.4, 2.9, LIGHT, "Concrete")
for i = 0, 7 do -- Akanthusblätter in zwei Kränzen
local an = math.rad(i * 45 + (i % 2) * 22)
deco("Akanthus", x + 1.45 * math.cos(an), y0 + 38.4 + (i % 2) * 0.8, z + 1.45 * math.sin(an), 0.8, 1.7, 0.8, DARK, "Concrete")
end
for _, cx in ipairs({ -1, 1 }) do
for _, cz in ipairs({ -1, 1 }) do deco("Volute", x + cx * 1.55, y0 + 40.6, z + cz * 1.55, 0.7, 0.7, 0.7, STONE, "Concrete", { shape = "Ball" }) end
end
add("Abakus", x, y0 + 41.3, z, 3.8, 0.8, 3.8, STONE, "Concrete", { collide = false })
deco("GebaelkKroepfung", x, y0 + TOP + 1.7, sz * 7.2, 5.4, 3.4, 2.4, STONE, "Concrete")
end
deco("Stylobat", 0, y0 + 0.4, sz * 7.4, 68, 0.8, 2.6, DARK, "Concrete")
deco("Stylobat", 0, y0 + 1.1, sz * 6.9, 64, 0.6, 1.6, STONE, "Concrete")
for _, seg in ipairs({ { -32, -23 }, { -13, -8 }, { 8, 13 }, { 23, 32 } }) do
for _, yy in ipairs({ 5, 9, 13 }) do deco("Rustika", (seg[1] + seg[2]) / 2, y0 + yy, sz * (D / 2 + 0.1), seg[2] - seg[1] + 0.4, 0.3, 0.3, DARK, "Concrete") end
end
for _, x in ipairs({ -10.5, 10.5 }) do deco("Kaempfer", x, y0 + 20, sz * (D / 2 + 0.1), 6.2, 0.9, 0.9, STONE, "Concrete") end
end
local function archivolt(cx, r, spring, name)
local R2, m = r + 1.7, 14
local w = 2 * R2 / m
for _, sz in ipairs({ -1, 1 }) do
for i = 1, m do
local xc = -R2 + (i - 0.5) * w
local inner = (math.abs(xc) < r) and (spring + math.sqrt(r * r - xc * xc)) or spring
local outer = spring + math.sqrt(math.max(0, R2 * R2 - xc * xc))
if outer - inner > 0.3 then deco(name, cx + xc, y0 + (inner + outer) / 2, sz * (D / 2 + 0.25), w + 0.05, outer - inner, 0.5, LIGHT, "Concrete") end
end
deco("Schlussstein", cx, y0 + spring + r + 0.7, sz * (D / 2 + 0.5), 1.8, 3.4, 1, STONE, "Concrete")
end
end
archivolt(0, 8, 20, "ArchivolteMitte")
archivolt(-18, 5, 14, "ArchivolteSeite")
archivolt(18, 5, 14, "ArchivolteSeite")
add("Gebaelk", 0, y0 + TOP + 1.5, 0, 66, 3, D + 2, STONE, "Concrete")
deco("Fries", 0, y0 + TOP + 2.2, -D / 2 - 1.05, 64, 1.2, 0.2, DARK, "Concrete")
deco("Fries", 0, y0 + TOP + 2.2, D / 2 + 1.05, 64, 1.2, 0.2, DARK, "Concrete")
add("Attika", 0, y0 + TOP + 8.5, 0, 60, 11, D, LIGHT, "Concrete")
add("Kranz", 0, y0 + TOP + 15, 0, 66, 2, D + 2, STONE, "Concrete")
for _, sz in ipairs({ -1, 1 }) do
for i = 0, 35 do deco("Zahnschnitt", -31.5 + i * 1.8, y0 + TOP + 13.6, sz * (D / 2 + 1.35), 0.9, 0.9, 0.9, DARK, "Concrete") end
deco("AttikaRahmen", 0, y0 + TOP + 5.9, sz * (D / 2 + 0.1), 56, 0.5, 0.3, DARK, "Concrete")
deco("AttikaRahmen", 0, y0 + TOP + 11.1, sz * (D / 2 + 0.1), 56, 0.5, 0.3, DARK, "Concrete")
for _, ex in ipairs({ -28, 28 }) do
deco("AttikaRahmen", ex, y0 + TOP + 8.5, sz * (D / 2 + 0.1), 0.5, 5.7, 0.3, DARK, "Concrete")
deco("AttikaEcke", ex + (ex < 0 and -1 or 1) * 1.2, y0 + TOP + 8.5, sz * (D / 2 + 0.6), 3.6, 11, 1.2, STONE, "Concrete")
end
end
add("Schrift", 0, y0 + TOP + 8.5, -D / 2 - 0.15, 52, 2.4, 0.2, { 60, 56, 50 }, "SmoothPlastic",
{ collide = false, kind = "text", text = { s = "DEM SIEGE GEWEIHT · VOM KRIEG ZERSTÖRT · ZUM FRIEDEN MAHNEND", color = { 60, 56, 50 } } })
add("Schrift", 0, y0 + TOP + 8.5, D / 2 + 0.15, 30, 3, 0.2, { 60, 56, 50 }, "SmoothPlastic",
{ collide = false, kind = "text", yaw = 180, text = { s = "SIEGESTOR", color = { 60, 56, 50 } } })
for _, sz in ipairs({ -1, 1 }) do
local zr = sz * (D / 2 + 0.15)
for _, cx in ipairs({ -18, 18 }) do
deco("Relief", cx, y0 + 31, zr, 9, 7, 0.4, RELIEF, "Concrete")
deco("ReliefRahmen", cx, y0 + 34.7, zr + sz * 0.1, 10, 0.6, 0.5, STONE, "Concrete")
deco("ReliefRahmen", cx, y0 + 27.3, zr + sz * 0.1, 10, 0.6, 0.5, STONE, "Concrete")
deco("ReliefRahmen", cx - 4.7, y0 + 31, zr + sz * 0.1, 0.6, 7, 0.5, STONE, "Concrete")
deco("ReliefRahmen", cx + 4.7, y0 + 31, zr + sz * 0.1, 0.6, 7, 0.5, STONE, "Concrete")
for i = 1, 4 do -- stehende Figuren
local fx = cx - 3.4 + (i - 1) * 2.3
deco("ReliefFigur", fx, y0 + 30.2 + (i % 2) * 0.4, zr + sz * 0.3, 0.9, 3.6 + (i % 2), 0.4, DARK, "Concrete")
deco("ReliefKopf", fx, y0 + 32.4 + (i % 2) * 0.9, zr + sz * 0.3, 0.8, 0.8, 0.4, DARK, "Concrete", { shape = "Ball" })
end
deco("ReliefPferd", cx, y0 + 28.8, zr + sz * 0.3, 3, 1.3, 0.4, DARK, "Concrete")
end
end
for _, sx in ipairs({ -1, 1 }) do -- Seitenflächen: Relieffeld und Pilaster
deco("SeitenRelief", sx * 32.2, y0 + 31, 0, 0.4, 7, 8, RELIEF, "Concrete")
deco("SeitenRahmen", sx * 32.3, y0 + 34.7, 0, 0.5, 0.6, 9, STONE, "Concrete")
deco("SeitenRahmen", sx * 32.3, y0 + 27.3, 0, 0.5, 0.6, 9, STONE, "Concrete")
for _, sz in ipairs({ -4, 4 }) do deco("SeitenPilaster", sx * 32.2, y0 + 20, sz, 0.5, 38, 1.4, LIGHT, "Concrete") end
end
for _, sx in ipairs({ -1, 1 }) do
deco("EckSockel", sx * 29.5, y0 + TOP + 17.6, 0, 5, 3.2, 5, STONE, "Concrete")
deco("EckFigurRock", sx * 29.5, y0 + TOP + 21, 0, 2.4, 3.8, 2.4, BRONZE, "Metal")
deco("EckFigurTorso", sx * 29.5, y0 + TOP + 24, 0, 2.2, 2.6, 1.6, BRONZE, "Metal")
deco("EckFigurKopf", sx * 29.5, y0 + TOP + 26, 0, 1.4, 1.4, 1.4, BRONZE, "Metal", { shape = "Ball" })
deco("EckFigurSpeer", sx * 29.5 + sx * 1.6, y0 + TOP + 24, 0, 0.3, 9, 0.3, { 70, 66, 60 }, "Metal")
end
local yt = y0 + TOP + 16
add("StatueSockel", 0, yt + 2, 0, 24, 4, 8, STONE, "Concrete")
deco("StatueSockelGesims", 0, yt + 4.3, 0, 25.4, 0.6, 8.8, DARK, "Concrete")
local yp = yt + 4.6 -- Plattform
deco("Wagen", 0, yp + 1.4, 2.4, 11, 2.8, 3.6, BRONZE, "Metal")
deco("WagenBug", 0, yp + 2.9, 0.5, 11.4, 0.5, 0.5, GOLD, "Metal")
deco("Deichsel", 0, yp + 1.2, -1.5, 0.5, 0.5, 4.6, { 70, 66, 60 }, "Metal")
for _, sx in ipairs({ -6, 6 }) do deco("Wagenrad", sx, yp + 1.7, 2.6, 0.6, 3.4, 3.4, { 70, 100, 86 }, "Metal", { shape = "Cylinder" }) end
for i = 1, 4 do
local lx = -7.5 + (i - 1) * 5
deco("LoeweKoerper", lx, yp + 1.6, -1.2, 2.2, 2.4, 4.4, BRONZE, "Metal")
deco("LoeweBrust", lx, yp + 2.0, -3.2, 2.2, 2.8, 1.2, BRONZE, "Metal")
deco("LoeweMaehne", lx, yp + 2.9, -3.7, 3, 3, 1.4, { 62, 102, 86 }, "Metal")
deco("LoeweKopf", lx, yp + 2.6, -4.7, 1.7, 1.7, 1.6, BRONZE, "Metal")
deco("LoeweTatze", lx - 0.6, yp + 0.5, -3.6, 0.7, 1.2, 0.7, BRONZE, "Metal")
deco("LoeweTatze", lx + 0.6, yp + 0.5, -3.6, 0.7, 1.2, 0.7, BRONZE, "Metal")
deco("LoeweSchwanz", lx, yp + 2.4, 1.4, 0.35, 0.35, 2.2, BRONZE, "Metal", { pitch = -20 })
end
local ys = yp + 2.8 -- Wagenboden der Figur
add("StatueRock", 0, ys + 4, 2.4, 4.6, 8, 3.2, BRONZE, "Metal", { collide = false })
deco("StatueGuertel", 0, ys + 6, 2.4, 4.9, 0.6, 3.5, GOLD, "Metal")
add("StatueTorso", 0, ys + 10.6, 2.4, 3.8, 5.6, 2.6, BRONZE, "Metal", { collide = false })
deco("StatueKopf", 0, ys + 14.4, 2.4, 2.1, 2.4, 2.1, BRONZE, "Metal", { shape = "Ball" })
deco("StatueHelm", 0, ys + 15.6, 2.4, 2.4, 1.4, 2.4, GOLD, "Metal")
deco("StatueHelmbusch", 0, ys + 17, 2.4, 0.6, 1.6, 2.2, GOLD, "Metal")
deco("StatueLanze", -3.4, ys + 12, 2.4, 0.5, 22, 0.5, { 70, 66, 60 }, "Metal")
deco("StatueLanzenspitze", -3.4, ys + 23.4, 2.4, 0.9, 2.2, 0.3, GOLD, "Metal", { roll = 12 })
deco("StatueArm", -2.4, ys + 11.4, 2.4, 1.1, 4.2, 1.1, BRONZE, "Metal")
deco("StatueSchild", 2.8, ys + 9.5, 1.0, 3.6, 3.6, 0.5, GOLD, "Metal", { shape = "Cylinder" })
deco("StatueUmhang", 0, ys + 9.6, 3.9, 4.6, 8.4, 0.4, { 62, 102, 86 }, "Metal")
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
vcyl("Rondell", 0, y0 + 0.45, 0, 0.9, 56, STONE, "Concrete")
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
local sx0 = t.x0 - 12 - L.x
for i = 1, 4 do
local top = 1 + 0.75 * i
add("TerrassenStufe", sx0 + (i - 1) * 3 + (12 - (i - 1) * 3 + 0.5) / 2, top / 2, 0, 12 - (i - 1) * 3 + 0.5, top, 24, STONE, "Concrete")
end
for _, sd in ipairs({ -1, 1 }) do
add("TerrassenWange", sx0 + 6, 2.2, sd * 12.8, 12, 4.4, 1.6, STONE, "Concrete")
end
local pw0, pw1 = t.x0 + 0.5 - L.x, -28
add("Plattenweg", (pw0 + pw1) / 2, 4.05, 0, pw1 - pw0, 0.2, 10, { 214, 208, 196 }, "Concrete", { collide = false })
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
local H = 43
local function radius(h)
if h <= 11 then return 19 + 10 * math.sin(math.pi / 2 * h / 11) end
local u = (h - 11) / (H - 11)
return 3 + 26 * math.cos(math.pi / 2 * u) ^ 2.2
end
for _, s in ipairs(Geo.lathe(H, function(h) return 2 * radius(h) end, 0.3, 0.5)) do
add(s.h0 <= 11 and 11 < s.h1 and "Kuppel" or "KuppelRing", x, y + 1 + s.y, z, s.dick, s.d, s.d, color, "Metal", { shape = "Cylinder", roll = 90, collide = true })
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
for k = 1, steps do -- Giebelstufen an beiden Enden (im Westen steht davor die Turmfront mit Portal und Westfenster)
for _, ex in ipairs({ -1, 1 }) do
add("Giebel", ex * (len / 2 - 0.8), yb + wallH + (k - 0.5) * rise / steps + 2, 0, 1.6, rise / steps, 2 * hw * (1 - (k - 1) / steps), BRICK, "Brick", { collide = true })
end
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
local LIGHT, DEEP = { 222, 210, 190 }, { 150, 128, 108 }
local function pointed(name, face, x, y, z, w, hgt, color, mat)
local hh, sq = hgt - w / 2, w / math.sqrt(2)
if face == "W" then
add(name, x, y + hh / 2, z, 0.8, hh, w, color, mat, { collide = false })
add(name, x, y + hh, z, 0.8, sq, sq, color, mat, { collide = false, pitch = 45 })
else
add(name, x, y + hh / 2, z, w, hh, 0.8, color, mat, { collide = false })
add(name, x, y + hh, z, sq, sq, 0.8, color, mat, { collide = false, roll = 45 })
end
end
for _, sd in ipairs({ -1, 1 }) do
local tz = sd * (hw - tw / 2)
for _, st in ipairs({ { w = tw, y0 = 0, y1 = H1, friezes = { 30, 64, 98 }, wins = { 14, 44, 74 } }, { w = 42, y0 = H1 + 3, y1 = H, friezes = { H1 + 34 }, wins = { H1 + 12 } } }) do
local wx, wz = tx - st.w / 2 - 0.4, tz + sd * (st.w / 2 + 0.4) -- Westfläche (x) und Außenfläche (z)
for _, o in ipairs({ -st.w / 4, st.w / 4 }) do
add("Lisene", wx, yb + (st.y0 + st.y1) / 2, tz + o, 1.2, st.y1 - st.y0, 1.8, BAND, "Concrete", { collide = false })
add("Lisene", tx + o, yb + (st.y0 + st.y1) / 2, wz, 1.8, st.y1 - st.y0, 1.2, BAND, "Concrete", { collide = false })
end
for _, fy in ipairs(st.friezes) do
add("Masswerkfries", wx - 0.2, yb + fy, tz, 0.6, 6, st.w - 2, LIGHT, "Concrete", { collide = false })
add("Masswerkfries", tx, yb + fy, wz + sd * 0.2, st.w - 2, 6, 0.6, LIGHT, "Concrete", { collide = false })
for k = 0, 3 do
local o = -st.w / 2 + 1 + (k + 0.5) * (st.w - 2) / 4
pointed("Masswerkbogen", "W", wx - 0.6, yb + fy - 2.4, tz + o, 4, 4.6, DEEP, "Concrete")
pointed("Masswerkbogen", "Z", tx + o, yb + fy - 2.4, wz + sd * 0.6, 4, 4.6, DEEP, "Concrete")
end
end
for _, wy in ipairs(st.wins) do
for _, o in ipairs({ -st.w / 4 + 4, st.w / 4 - 4 }) do
pointed("Turmspitzfenster", "W", wx - 0.2, yb + wy, tz + o, 3, 12, { 40, 44, 52 }, "Glass")
pointed("Turmspitzfenster", "Z", tx + o, yb + wy, wz + sd * 0.2, 3, 12, { 40, 44, 52 }, "Glass")
end
end
end
end
for _, sd in ipairs({ -1, 1 }) do add("Wandband", 0, yb + 24, sd * (hw + 0.3), len, 1.4, 0.6, BAND, "Concrete", { collide = false }) end
local px = -len / 2 - 8
add("Vorhalle", px + 4, yb + 22, 0, 8, 44, 30, LIGHT, "Concrete", { collide = true })
pointed("PortalGewaende", "W", px - 0.3, yb, 0, 22, 34, { 232, 222, 204 }, "Concrete")
pointed("PortalGewaende", "W", px - 0.6, yb, 0, 18, 30, { 206, 192, 170 }, "Concrete")
pointed("PortalNische", "W", px - 0.9, yb, 0, 14, 26, { 120, 104, 88 }, "Concrete")
pointed("Portal", "W", px - 1.2, yb, 0, 10, 20, { 56, 40, 32 }, "Wood")
for _, o in ipairs({ -6, 6 }) do add("Portalfigur", px - 1.4, yb + 14, o, 1.4, 5, 1.6, { 236, 228, 210 }, "Concrete", { collide = false }) end
add("Wimperg", px - 0.4, yb + 44.6, 0, 0.8, 15, 15, LIGHT, "Concrete", { pitch = 45, collide = false })
add("Kreuzblume", px - 0.6, yb + 56.4, 0, 2.4, 2.4, 2.4, LIGHT, "Concrete", { shape = "Ball", collide = false })
for _, o in ipairs({ -13.5, 13.5 }) do
add("Fiale", px - 0.4, yb + 28, o, 2, 56, 2, LIGHT, "Concrete", { collide = false })
add("FialeSpitze", px - 0.4, yb + 57.5, o, 1.6, 1.6, 1.6, LIGHT, "Concrete", { shape = "Ball", collide = false })
end
for i = 1, 4 do add("PortalStufe", px - 2 - i * 2, yb - 0.4 - i * 0.2, 0, 3, 0.8, 26 + i * 2, { 160, 156, 148 }, "Concrete", { collide = true }) end
pointed("WestfensterGewaende", "W", -len / 2 - 0.3, yb + 61, 0, 15, 54, LIGHT, "Concrete")
pointed("Westfenster", "W", -len / 2 - 0.6, yb + 63, 0, 11, 50, { 50, 62, 78 }, "Glass")
for k = 1, 3 do add("Westfensterpfosten", -len / 2 - 0.8, yb + 83, -5.5 + k * 2.75, 0.4, 40, 0.5, LIGHT, "Concrete", { collide = false }) end
local sc = L.scale or 1
if sc ~= 1 then
for _, p in ipairs(parts) do
p.pos = { Geo.round3(cxn + (p.pos[1] - cxn) * sc), Geo.round3(y0 + (p.pos[2] - y0) * sc), Geo.round3(L.z + (p.pos[3] - L.z) * sc) }
p.size = { Geo.round3(p.size[1] * sc), Geo.round3(p.size[2] * sc), Geo.round3(p.size[3] * sc) }
end
end
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
local Rathaus = (function()
local Geo = Geo
local Rathaus = {}
function Rathaus.plan(cfg)
local R = cfg.marienplatz.rathaus
local parts = {}
local W, D = R.x1 - R.x0, R.z1 - R.z0
local cx, zf, y0 = (R.x0 + R.x1) / 2, R.z1, 1
local STONE, LIGHT, DARK, ROOF, GLASS = { 150, 146, 136 }, { 198, 192, 178 }, { 40, 38, 40 }, { 58, 62, 68 }, { 50, 62, 78 }
local PINK, LEAF, GOLD = { 222, 86, 140 }, { 60, 110, 56 }, { 226, 184, 72 }
local function add(name, u, y, v, sx, sy, sz, color, mat, extra)
extra = extra or {}
parts[#parts + 1] = {
name = name, kind = extra.kind or "landmark", size = { Geo.round3(sx), Geo.round3(sy), Geo.round3(sz) },
pos = { Geo.round3(cx + u), Geo.round3(y), Geo.round3(zf + v) }, yaw = extra.yaw or 0, pitch = extra.pitch or 0, roll = extra.roll,
color = color, material = mat, collide = extra.collide == true, shape = extra.shape, tag = extra.tag, attrs = extra.attrs, lit = extra.lit,
}
end
local function pointed(name, u, y, v, w, hgt, color, mat, side, extra)
local hh, sq = hgt - w / 2, w / math.sqrt(2)
extra = extra or {}
if side then
add(name, u, y + hh / 2, v, 0.3, hh, w, color, mat, extra)
add(name, u, y + hh, v, 0.3, sq, sq, color, mat, { pitch = 45, kind = extra.kind })
else
add(name, u, y + hh / 2, v, w, hh, 0.3, color, mat, extra)
add(name, u, y + hh, v, sq, sq, 0.3, color, mat, { roll = 45, kind = extra.kind })
end
end
local function vcyl(name, u, y, v, h, d, color, mat, extra)
extra = extra or {}
extra.shape, extra.roll = "Cylinder", 90
add(name, u, y, v, h, d, d, color, mat, extra)
end
local H = 50
add("Body", 0, y0 + H / 2, -D / 2, W, H, D, STONE, "Concrete", { collide = true })
add("Sockel", 0, y0 + 1, 0.3, W, 2, 0.6, { 110, 106, 100 }, "Concrete")
for _, yy in ipairs({ 14, 26, 38, 49.5 }) do add("Gesims", 0, y0 + yy, 0.5, W + 1, 1, 1, LIGHT, "Concrete") end
local n = 9
local b = W / n
for j = 0, n do add("Pfeiler", -W / 2 + j * b, y0 + H / 2, 0.6, 1.4, H, 1.2, LIGHT, "Concrete") end
for i = 1, n do
local u = -W / 2 + (i - 0.5) * b
if i ~= 5 then
pointed("ArkadeGewaende", u, y0, 0.15, 12, 13.5, LIGHT, "Concrete")
pointed("Arkade", u, y0, 0.35, 10, 12, DARK, "SmoothPlastic")
add("Balkon", u, y0 + 14.6, 1.6, b - 1.4, 0.8, 3.2, LIGHT, "Concrete", { collide = true })
add("Bruestung", u, y0 + 16.2, 3, b - 1.4, 2.4, 0.5, LIGHT, "Concrete")
add("Blumenkasten", u, y0 + 17.2, 2.4, b - 2.6, 0.9, 1.3, LEAF, "Grass")
add("Blumen", u, y0 + 18.1, 2.4, b - 3, 1.2, 1.1, PINK, "Fabric")
for _, fl in ipairs({ { 16.5, 8.5 }, { 28.5, 8 }, { 40.5, 7 } }) do
for _, o in ipairs({ -b / 4, b / 4 }) do
pointed("FensterGewaende", u + o, y0 + fl[1] - 0.6, 0.15, 4.4, fl[2] + 1.2, LIGHT, "Concrete")
pointed("Fenster", u + o, y0 + fl[1], 0.35, 3.2, fl[2], GLASS, "Glass", nil, { kind = "glass", tag = "HouseWindow" })
end
end
end
end
for _, i in ipairs({ 2, 8 }) do
local u = -W / 2 + (i - 0.5) * b
add("Erker", u, y0 + 27, 2, 9, 22, 4, LIGHT, "Concrete", { collide = true })
add("ErkerFenster", u, y0 + 22, 4.1, 6, 6, 0.3, GLASS, "Glass", { kind = "glass" })
add("ErkerFenster", u, y0 + 33, 4.1, 6, 6, 0.3, GLASS, "Glass", { kind = "glass" })
add("ErkerDach", u, y0 + 39, 2, 10, 1, 5, ROOF, "Slate")
end
for _, sd in ipairs({ -1, 1 }) do
local u = sd * (W / 2 - 3)
vcyl("Ecktuermchen", u, y0 + 38.5, 1, 47, 8, STONE, "Concrete", { collide = true })
for _, yy in ipairs({ 27, 50 }) do vcyl("EcktuermchenBand", u, y0 + yy, 1, 1, 9, LIGHT, "Concrete") end
for _, s in ipairs(Geo.lathe(13.5, function(h) return 8.4 * (1 - h / 15) + 0.6 end, 0.3, 0.5)) do vcyl("EcktuermchenHelm", u, y0 + 62.5 + s.y, 1, s.dick, s.d, ROOF, "Slate") end
add("EcktuermchenKugel", u, y0 + 77.5, 1, 1.4, 1.4, 1.4, GOLD, "Metal", { shape = "Ball" })
for k = 0, 2 do pointed("EcktuermchenFenster", u + sd * 0, y0 + 30 + k * 10, 5.1, 2, 5, GLASS, "Glass", nil, { kind = "glass" }) end
end
local run, rise = D / 2, 22
local ang = math.deg(math.atan2(rise, run))
local slope = math.sqrt(run * run + rise * rise)
add("Dach", 0, y0 + H + rise / 2, -run / 2, W + 2, 1.2, slope + 1, ROOF, "Slate", { pitch = ang })
add("Dach", 0, y0 + H + rise / 2, -D + run / 2, W + 2, 1.2, slope + 1, ROOF, "Slate", { pitch = -ang })
add("First", 0, y0 + H + rise + 0.6, -run, W + 2, 1.2, 1.6, ROOF, "Slate")
for k = 0, 19 do add("Firstzier", -W / 2 + 3.5 + k * (W - 7) / 19, y0 + H + rise + 1.8, -run, 1.6, 1.6, 0.5, { 90, 96, 100 }, "Metal", { roll = 45 }) end
for _, sd in ipairs({ -1, 1 }) do
for k = 1, 8 do add("Giebel", sd * (W / 2 - 0.6), y0 + H + (k - 0.5) * rise / 8, -run, 1.2, rise / 8, D * (1 - (k - 1) / 8), STONE, "Concrete", { collide = true }) end
end
for i = 1, n do
if i ~= 5 then
local u = -W / 2 + (i - 0.5) * b
add("Gaube", u, y0 + H + 9, -7.5, 4, 5, 4, STONE, "Concrete")
add("GaubeFenster", u, y0 + H + 9, -5.4, 2.4, 3, 0.3, GLASS, "Glass", { kind = "glass" })
add("GaubeDach", u, y0 + H + 12, -7.5, 4.8, 0.6, 4.8, ROOF, "Slate", { roll = 0 })
end
end
for j = 0, n do
if j ~= 4 and j ~= 5 then
vcyl("Fiale", -W / 2 + j * b, y0 + H + 3.5, 0.8, 7, 1.4, LIGHT, "Concrete")
add("FialeKugel", -W / 2 + j * b, y0 + H + 7.4, 0.8, 1.2, 1.2, 1.2, LIGHT, "Concrete", { shape = "Ball" })
end
end
for _, sd in ipairs({ -1, 1 }) do
for _, fy in ipairs({ 16.5, 28.5, 40.5 }) do
for k = 1, 3 do pointed("Seitenfenster", sd * (W / 2 + 0.2), y0 + fy, -D * k / 4, 3.2, 7.5, GLASS, "Glass", true, { kind = "glass", tag = "HouseWindow" }) end
end
end
local TW, TV = 26, -3 -- Breite, Mitte (Tiefe 14, ragt 4 vor die Fassade)
add("Turm", 0, y0 + 35, TV, TW, 70, 14, STONE, "Concrete", { collide = true })
for _, sd in ipairs({ -1, 1 }) do add("TurmLisene", sd * (TW / 2 - 0.8), y0 + 35, 4.3, 1.6, 70, 0.8, LIGHT, "Concrete") end
for _, yy in ipairs({ 17, 28, 56 }) do add("TurmBand", 0, y0 + yy, 4.4, TW + 0.6, 1, 0.8, LIGHT, "Concrete") end
pointed("TorGewaende", 0, y0, 4.15, 16, 19, LIGHT, "Concrete")
pointed("Tor", 0, y0, 4.35, 12, 16, DARK, "Wood", nil, { tag = "HouseDoor" })
for _, o in ipairs({ -4, 4 }) do pointed("TurmFenster", o, y0 + 19.5, 4.35, 3, 7, GLASS, "Glass", nil, { kind = "glass" }) end
pointed("GlockenspielNische", 0, y0 + 29, 4.15, 16, 26, GOLD, "Metal")
pointed("Glockenspiel", 0, y0 + 30, 4.35, 14, 24, { 30, 44, 70 }, "SmoothPlastic", nil, { tag = "Glockenspiel" })
local FIG = { { 200, 40, 40 }, { 40, 90, 170 }, { 230, 200, 60 }, { 60, 140, 70 }, { 240, 240, 236 }, { 150, 70, 160 } }
for t, yy in ipairs({ 32.5, 42 }) do
add("GlockenspielBuehne", 0, y0 + yy - 0.6, 4.9, 12, 0.6, 1.6, GOLD, "Metal")
for k = 1, 6 do
local fu = -6 + (k - 0.5) * 2
add("GlockenspielFigur", fu, y0 + yy + 1.3, 4.9, 1.2, 2.6, 0.9, FIG[(k + t) % #FIG + 1], "SmoothPlastic", { tag = "GlockenspielFigur" })
add("GlockenspielKopf", fu, y0 + yy + 3, 4.9, 0.9, 0.9, 0.9, { 232, 196, 160 }, "SmoothPlastic", { shape = "Ball" })
end
end
add("UhrRand", 0, y0 + 63, 4.4, 0.5, 11.4, 11.4, DARK, "Metal", { shape = "Cylinder", yaw = 90 })
add("Uhr", 0, y0 + 63, 4.65, 0.3, 10, 10, { 246, 242, 230 }, "SmoothPlastic", { shape = "Cylinder", yaw = 90 })
for _, hd in ipairs({ { 300, 2.8 }, { 60, 4 } }) do -- Zeiger: von Süden gesehen dreht roll gegen den Uhrzeigersinn, daher negativ
local phi = math.rad(hd[1])
add("Uhrzeiger", (hd[2] / 2) * math.sin(phi), y0 + 63 + (hd[2] / 2) * math.cos(phi), 4.9, 0.5, hd[2], 0.3, DARK, "Metal", { roll = -hd[1] })
end
for k = 0, 3 do
local phi = math.rad(k * 90)
add("Uhrstrich", 4 * math.sin(phi), y0 + 63 + 4 * math.cos(phi), 4.9, (k % 2 == 0) and 0.4 or 1, (k % 2 == 0) and 1 or 0.4, 0.3, DARK, "Metal")
end
add("Umgang", 0, y0 + 70.5, TV, TW + 4, 1, 18, LIGHT, "Concrete", { collide = true })
for _, sd in ipairs({ -1, 1 }) do
add("Gelaender", 0, y0 + 72, TV + sd * 8.8, TW + 4, 1.6, 0.4, LIGHT, "Concrete")
add("Gelaender", sd * (TW / 2 + 1.8), y0 + 72, TV, 0.4, 1.6, 18, LIGHT, "Concrete")
for _, sv in ipairs({ -1, 1 }) do
vcyl("TurmFiale", sd * (TW / 2 - 1), y0 + 77, TV + sv * 6, 12, 2.2, LIGHT, "Concrete")
add("TurmFialeKugel", sd * (TW / 2 - 1), y0 + 83.6, TV + sv * 6, 1.6, 1.6, 1.6, GOLD, "Metal", { shape = "Ball" })
end
end
add("Glockenstube", 0, y0 + 82, TV, 18, 22, 12, STONE, "Concrete", { collide = true })
for _, o in ipairs({ -4, 4 }) do
pointed("Schallloch", o, y0 + 76, TV + 6.15, 3.4, 12, DARK, "SmoothPlastic")
pointed("Schallloch", o, y0 + 76, TV - 6.15, 3.4, 12, DARK, "SmoothPlastic")
end
for _, sd in ipairs({ -1, 1 }) do pointed("Schallloch", sd * 9.15, y0 + 76, TV, 3.4, 12, DARK, "SmoothPlastic", true) end
add("Kranz", 0, y0 + 93.4, TV, 20, 1, 14, LIGHT, "Concrete")
for _, s in ipairs(Geo.lathe(28.5, function(h) return 15 * (1 - h / 30.4) ^ 1.2 + 1 end, 0.3, 0.5)) do vcyl("Turmhelm", 0, y0 + 95 + s.y, TV, s.dick, s.d, ROOF, "Slate") end
vcyl("Kindl", 0, y0 + 127, TV, 2.4, 1.2, GOLD, "Metal")
add("KindlKopf", 0, y0 + 128.8, TV, 1, 1, 1, GOLD, "Metal", { shape = "Ball" })
return parts
end
return Rathaus

end)()
local Marienplatz = (function()
local Geo = Geo
local Marienplatz = {}
local GRANITE, JOINT, BAND = { 204, 198, 188 }, { 172, 166, 156 }, { 150, 96, 84 }
function Marienplatz.plan(cfg)
local M = cfg.marienplatz
local P, U, S = M.plaza, M.ubahn, M.saeule
local parts = {}
local stats = { lamps = 0, trees = 0, steps = 0, bikes = 0 }
local function add(name, x, y, z, sx, sy, sz, color, mat, extra)
extra = extra or {}
parts[#parts + 1] = {
name = name, kind = extra.kind or "plaza", size = { Geo.round3(sx), Geo.round3(sy), Geo.round3(sz) }, pos = { Geo.round3(x), Geo.round3(y), Geo.round3(z) },
yaw = extra.yaw or 0, pitch = extra.pitch or 0, roll = extra.roll, color = color, material = mat, collide = extra.collide == true,
shape = extra.shape, text = extra.text, tag = extra.tag, attrs = extra.attrs, transparency = extra.transparency,
}
end
local function vcyl(name, x, y, z, h, d, color, mat, extra)
extra = extra or {}
extra.shape, extra.roll = "Cylinder", 90
add(name, x, y, z, h, d, d, color, mat, extra)
end
local function rect(name, x0, z0, x1, z1, top, thick, color, mat, extra)
if x1 - x0 > 0.01 and z1 - z0 > 0.01 then add(name, (x0 + x1) / 2, top - thick / 2, (z0 + z1) / 2, x1 - x0, thick, z1 - z0, color, mat, extra) end
end
local function inPit(x, z, m) return x > U.x0 - m and x < U.x1 + m and z > U.z0 - m and z < U.z1 + m end
local pave = { collide = true }
rect("Pflaster", P.x0, P.z0, P.x1, U.z0, 1, 2, GRANITE, "Granite", pave)
rect("Pflaster", P.x0, U.z1, P.x1, P.z1, 1, 2, GRANITE, "Granite", pave)
rect("Pflaster", P.x0, U.z0, U.x0, U.z1, 1, 2, GRANITE, "Granite", pave)
rect("Pflaster", U.x1, U.z0, P.x1, U.z1, 1, 2, GRANITE, "Granite", pave)
local function line(name, x0, z0, x1, z1, w, color, y, h) -- Linie (Höhe h, nicht zu dünn: dünnere Linien flackern gegen den Boden) längs x (z0 == z1) oder längs z, am U-Bahn-Abgang unterbrochen
local spans = { { 0, 1 } }
if z0 == z1 and z0 > U.z0 and z0 < U.z1 then spans = { { 0, (U.x0 - x0) / (x1 - x0) }, { (U.x1 - x0) / (x1 - x0), 1 } } end
if x0 == x1 and x0 > U.x0 and x0 < U.x1 then spans = { { 0, (U.z0 - z0) / (z1 - z0) }, { (U.z1 - z0) / (z1 - z0), 1 } } end
for _, sp in ipairs(spans) do
local ax, az, bx, bz = x0 + (x1 - x0) * sp[1], z0 + (z1 - z0) * sp[1], x0 + (x1 - x0) * sp[2], z0 + (z1 - z0) * sp[2]
if z0 == z1 and bx - ax > 0.5 then add(name, (ax + bx) / 2, y, z0, bx - ax, h, w, color, "SmoothPlastic") end
if x0 == x1 and bz - az > 0.5 then add(name, x0, y, (az + bz) / 2, w, h, bz - az, color, "SmoothPlastic") end
end
end
for x = P.x0 + 8, P.x1 - 4, 8 do line("Fuge", x, P.z0, x, P.z1, 0.3, JOINT, 1.1, 0.2) end
for z = P.z0 + 8, P.z1 - 4, 8 do line("Fuge", P.x0, z, P.x1, z, 0.3, JOINT, 1.1, 0.2) end
for _, z in ipairs({ 120, 200, 280 }) do line("Band", P.x0, z, P.x1, z, 2.4, BAND, 1.15, 0.3) end
for _, x in ipairs({ -560, -450, -380 }) do line("Band", x, P.z0, x, P.z1, 2.4, BAND, 1.15, 0.3) end
line("Band", P.x0 + 1.2, P.z0, P.x0 + 1.2, P.z1, 2.4, BAND, 1.15, 0.3)
line("Band", P.x1 - 1.2, P.z0, P.x1 - 1.2, P.z1, 2.4, BAND, 1.15, 0.3)
line("Band", P.x0, P.z1 - 1.2, P.x1, P.z1 - 1.2, 2.4, BAND, 1.15, 0.3)
local MARBLE, RED, BRONZE, GOLD, PINK = { 214, 206, 194 }, { 150, 58, 58 }, { 64, 68, 60 }, { 230, 188, 70 }, { 222, 86, 140 }
vcyl("SaeulenKreis", S.x, 1.15, S.z, 0.3, 46, BAND, "Granite")
vcyl("SaeulenKreis", S.x, 1.3, S.z, 0.3, 40, GRANITE, "Granite")
for k = 1, 3 do
local d = 34 - 5 * k
for _, yw in ipairs({ 0, 45 }) do add("SaeulenStufe", S.x, 1 + 0.8 * k - 0.4, S.z, d, 0.8, d, MARBLE, "Marble", { yaw = yw, collide = true }) end
end
local top = 3.4
for _, sd in ipairs({ -1, 1 }) do
add("Balustrade", S.x + sd * 9.5, top + 1.2, S.z, 0.8, 2.4, 19.8, MARBLE, "Marble", { collide = true })
add("Balustrade", S.x, top + 1.2, S.z + sd * 9.5, 19.8, 2.4, 0.8, MARBLE, "Marble", { collide = true })
add("Blumenbeet", S.x + sd * 7.6, top + 0.7, S.z, 2.6, 1.4, 16, PINK, "Fabric")
add("Blumenbeet", S.x, top + 0.7, S.z + sd * 7.6, 16, 1.4, 2.6, PINK, "Fabric")
for _, sv in ipairs({ -1, 1 }) do
add("BalustradePfosten", S.x + sd * 9.5, top + 1.6, S.z + sv * 9.5, 1.6, 3.2, 1.6, MARBLE, "Marble", { collide = true })
add("PuttoSockel", S.x + sd * 5.6, top + 0.8, S.z + sv * 5.6, 2, 1.6, 2, MARBLE, "Marble", { collide = true })
vcyl("Putto", S.x + sd * 5.6, top + 2.8, S.z + sv * 5.6, 2.4, 1.4, BRONZE, "Metal")
add("PuttoKopf", S.x + sd * 5.6, top + 4.6, S.z + sv * 5.6, 1.2, 1.2, 1.2, BRONZE, "Metal", { shape = "Ball" })
add("PuttoLanze", S.x + sd * 5.2, top + 4.2, S.z + sv * 5.2, 0.25, 6, 0.25, BRONZE, "Metal", { yaw = sd * sv * 45, pitch = 25 })
end
end
add("Saeulensockel", S.x, top + 5, S.z, 8, 10, 8, MARBLE, "Marble", { collide = true })
add("Saeulensockel", S.x, top + 10.4, S.z, 9.4, 0.8, 9.4, MARBLE, "Marble")
vcyl("Saeulenfuss", S.x, top + 11.4, S.z, 1.2, 4.2, MARBLE, "Marble")
vcyl("Mariensaeule", S.x, top + 26, S.z, 28, 3, RED, "Marble", { collide = true })
vcyl("Kapitell", S.x, top + 40.8, S.z, 1.6, 4.4, GOLD, "Metal")
add("Kapitell", S.x, top + 42, S.z, 5, 0.8, 5, GOLD, "Metal")
add("Mondsichel", S.x, top + 42.8, S.z, 3.4, 0.5, 1.2, GOLD, "Metal")
for k, d in ipairs({ 3, 2.6, 2.2, 1.8 }) do vcyl("Madonna", S.x, top + 42.8 + k * 1.1, S.z, 1.2, d, GOLD, "Metal") end
vcyl("Madonna", S.x, top + 48.6, S.z, 1.6, 1.6, GOLD, "Metal")
add("MadonnaKopf", S.x, top + 50, S.z, 1.3, 1.3, 1.3, GOLD, "Metal", { shape = "Ball" })
vcyl("MadonnaKrone", S.x, top + 50.9, S.z, 0.6, 1, GOLD, "Metal")
add("Strahlenkranz", S.x, top + 50.2, S.z - 0.7, 0.2, 3.6, 3.6, { 250, 220, 120 }, "Neon", { shape = "Cylinder", yaw = 90 })
add("Christuskind", S.x - 1.1, top + 48.4, S.z + 0.5, 0.9, 0.9, 0.9, GOLD, "Metal", { shape = "Ball" })
add("Zepter", S.x + 1.1, top + 48.8, S.z + 0.3, 0.2, 3, 0.2, GOLD, "Metal")
local function bench(x, z, yaw)
add("Bank", x, 2.1, z, 5, 0.5, 1.6, { 120, 84, 56 }, "Wood", { yaw = yaw, collide = true })
add("BankLehne", x, 3, z, 5, 1.4, 0.3, { 120, 84, 56 }, "Wood", { yaw = yaw })
add("BankFuss", x, 1.5, z, 4.4, 1, 1.2, { 60, 62, 66 }, "Metal", { yaw = yaw })
end
for _, b in ipairs({ { S.x - 22, S.z, 90 }, { S.x + 22, S.z, 90 }, { S.x, S.z + 22, 0 } }) do bench(b[1], b[2], b[3]) end
local CONC, STEEL, UBLUE, SGREEN, WHITE = { 176, 174, 168 }, { 70, 74, 80 }, { 0, 94, 184 }, { 0, 150, 70 }, { 255, 255, 255 }
local nSteps, landing = 14, 6
local rise, run = U.depth / nSteps, (U.z1 - U.z0 - landing) / nSteps
local bottom, ux = 1 - U.depth, (U.x0 + U.x1) / 2
local inner = U.x1 - U.x0 - 2.4
for k = 1, nSteps do
local t = 1 - k * rise
add("UBahnStufe", ux, (t - 12) / 2, U.z1 - (k - 0.5) * run, inner, t + 12, run, { 150, 148, 144 }, "Granite", { collide = true })
stats.steps = stats.steps + 1
end
add("UBahnPodest", ux, (bottom - 12) / 2, U.z0 + landing / 2, inner, bottom + 12, landing, { 150, 148, 144 }, "Granite", { collide = true })
for _, sd in ipairs({ -1, 1 }) do
local wx = (sd < 0) and (U.x0 + 0.6) or (U.x1 - 0.6)
add("UBahnWand", wx, -5.2, (U.z0 + U.z1) / 2, 1.2, 13.6, U.z1 - U.z0, CONC, "Concrete", { collide = true })
add("UBahnHandlauf", wx - sd * 0.9, 1 - U.depth / 2 + 3, (U.z0 + landing + U.z1) / 2, 0.3, 0.3, math.sqrt((U.z1 - U.z0 - landing) ^ 2 + U.depth ^ 2), STEEL, "Metal",
{ pitch = -math.deg(math.atan2(U.depth, U.z1 - U.z0 - landing)) })
end
local pw, ph = 12, 8
add("UBahnWand", U.x0 + (inner + 2.4 - pw) / 4, -5.2, U.z0 + 0.6, (U.x1 - U.x0 - pw) / 2, 13.6, 1.2, CONC, "Concrete", { collide = true })
add("UBahnWand", U.x1 - (inner + 2.4 - pw) / 4, -5.2, U.z0 + 0.6, (U.x1 - U.x0 - pw) / 2, 13.6, 1.2, CONC, "Concrete", { collide = true })
add("UBahnWand", ux, (bottom + ph + 1.6) / 2, U.z0 + 0.6, pw, 1.6 - bottom - ph, 1.2, CONC, "Concrete", { collide = true })
add("UBahnSchild", ux, bottom + ph + 2.2, U.z0 + 1.3, 16, 2.4, 0.3, UBLUE, "SmoothPlastic")
add("Schrift", ux, bottom + ph + 2.2, U.z0 + 1.5, 15, 1.8, 0.2, WHITE, "SmoothPlastic", { kind = "text", yaw = 180, text = { s = "U  S  MARIENPLATZ", color = WHITE } })
for _, e in ipairs({ { U.x0 + 0.6, U.z0, U.x0 + 0.6, U.z1 }, { U.x1 - 0.6, U.z0, U.x1 - 0.6, U.z1 }, { U.x0, U.z0 + 0.6, U.x1, U.z0 + 0.6 } }) do
local len = math.max(e[3] - e[1], e[4] - e[2])
local alongX = e[3] - e[1] > 0.1
add("Gelaender", (e[1] + e[3]) / 2, 4.2, (e[2] + e[4]) / 2, alongX and len or 0.3, 0.3, alongX and 0.3 or len, STEEL, "Metal", { collide = true })
for k = 0, math.floor(len / 4) do
local px, pz = alongX and (e[1] + k * len / math.floor(len / 4)) or e[1], alongX and e[2] or (e[2] + k * len / math.floor(len / 4))
add("GelaenderPfosten", px, 2.6, pz, 0.3, 3.2, 0.3, STEEL, "Metal", { collide = true })
end
end
local sx, sz = U.x0 - 3, U.z1 + 2
add("UBahnPylon", sx, 6, sz, 0.8, 10, 0.8, STEEL, "Metal", { collide = true })
add("UBahnU", sx, 10.4, sz, 4, 4, 0.4, UBLUE, "SmoothPlastic")
add("Schrift", sx, 10.4, sz + 0.3, 3.4, 3.4, 0.2, WHITE, "SmoothPlastic", { kind = "text", yaw = 180, text = { s = "U", color = WHITE } })
add("UBahnS", sx, 5.6, sz, 0.4, 4, 4, SGREEN, "SmoothPlastic", { shape = "Cylinder", yaw = 90 })
add("Schrift", sx, 5.6, sz + 0.3, 2.8, 2.8, 0.2, WHITE, "SmoothPlastic", { kind = "text", yaw = 180, text = { s = "S", color = WHITE } })
local g0, g1 = U.z0 - U.gang, U.z0
rect("UBahnGangBoden", ux - pw / 2 - 1, g0, ux + pw / 2 + 1, g1, bottom, 1, { 150, 148, 144 }, "Granite", { collide = true })
rect("UBahnGangDecke", ux - pw / 2 - 1, g0, ux + pw / 2 + 1, g1, bottom + ph + 1, 1, { 200, 200, 196 }, "Concrete", { collide = true })
for _, sd in ipairs({ -1, 1 }) do add("UBahnGangWand", ux + sd * (pw / 2 + 0.5), bottom + ph / 2, (g0 + g1) / 2, 1, ph, U.gang, { 226, 222, 210 }, "Concrete", { collide = true }) end
add("UBahnGangWand", ux, bottom + ph / 2, g0 - 0.5, pw + 2, ph, 1, { 226, 222, 210 }, "Concrete", { collide = true })
add("Fahrplan", ux, bottom + 4.5, g0 + 0.1, 6, 3, 0.2, { 30, 34, 40 }, "SmoothPlastic")
add("Schrift", ux, bottom + 4.5, g0 + 0.3, 5.6, 1.4, 0.2, { 255, 200, 60 }, "SmoothPlastic", { kind = "text", yaw = 180, text = { s = "U3 U6  S1-S8", color = { 255, 200, 60 } } })
for k = 1, 3 do add("UBahnLicht", ux, bottom + ph + 0.4, g0 + k * U.gang / 4, 1.2, 0.2, 3, { 255, 250, 236 }, "Neon") end
local lamps = {}
for x = -620, -380, 48 do lamps[#lamps + 1] = { x, 182 } end
for _, x in ipairs({ -340, -230 }) do lamps[#lamps + 1] = { x, 116 } end
for x = -620, -230, 65 do lamps[#lamps + 1] = { x, 262 } end
for _, l in ipairs(lamps) do
vcyl("KugelleuchteMast", l[1], 12, l[2], 22, 0.8, { 150, 152, 156 }, "Metal", { collide = true })
for _, yy in ipairs({ 18.6, 22.6 }) do add("Kugelleuchte", l[1], yy, l[2], 4.4, 4.4, 4.4, { 255, 250, 238 }, "Neon", { shape = "Ball", tag = "StreetLamp", attrs = { Lit = true } }) end
vcyl("KugelleuchteKappe", l[1], 25, l[2], 0.6, 1.2, { 150, 152, 156 }, "Metal")
stats.lamps = stats.lamps + 1
end
local trees = { { -606, 214 }, { -572, 238 }, { -538, 214 }, { -504, 240 }, { -470, 214 }, { -560, 300 }, { -330, 300 }, { -236, 222 } }
local GREENS = { { 70, 120, 60 }, { 88, 140, 70 }, { 60, 108, 58 } }
for i, t in ipairs(trees) do
vcyl("Baumscheibe", t[1], 1.15, t[2], 0.3, 6, { 70, 66, 60 }, "Metal")
vcyl("PlataneStamm", t[1], 7, t[2], 12, 2.2, { 150, 138, 116 }, "Wood", { collide = true })
add("PlataneKrone", t[1], 18, t[2], 17, 15, 17, GREENS[i % 3 + 1], "Grass", { shape = "Ball" })
add("PlataneKrone", t[1] + 4, 15.5, t[2] - 3, 12, 11, 12, GREENS[(i + 1) % 3 + 1], "Grass", { shape = "Ball" })
add("PlataneKrone", t[1] - 4, 15, t[2] + 3, 12, 10, 12, GREENS[(i + 2) % 3 + 1], "Grass", { shape = "Ball" })
stats.trees = stats.trees + 1
end
for k = 1, 3 do add("Sitzstufe", -555, (0.9 * k + 1) / 2, 254 - (k - 0.5) * 4, 90, 0.9 * k + 1, 4, { 128, 124, 116 }, "Granite", { collide = true }) end
for _, c in ipairs({ { -612, 300 }, { -245, 290 } }) do
for i = 0, 2 do
for j = 0, 1 do
local tx, tz = c[1] + j * 12, c[2] - 10 + i * 10
vcyl("CafeTisch", tx, 3.4, tz, 0.3, 3, { 240, 238, 230 }, "SmoothPlastic", { collide = true })
vcyl("CafeTischFuss", tx, 2.2, tz, 2.2, 0.4, { 50, 54, 58 }, "Metal")
for _, sd in ipairs({ -1, 1 }) do add("CafeStuhl", tx + sd * 2.4, 2.5, tz, 1.4, 0.4, 1.4, { 40, 44, 52 }, "Metal", { collide = true }) end
end
vcyl("CafeSchirmStange", c[1] + 6, 5.6, c[2] - 10 + i * 10, 9.2, 0.3, { 200, 200, 196 }, "Metal")
vcyl("CafeSchirm", c[1] + 6, 10.2, c[2] - 10 + i * 10, 0.4, 11, { 34, 70, 150 }, "Fabric")
end
end
for _, l in ipairs({ lamps[2], lamps[4], lamps[#lamps - 1] }) do
for k = 0, 3 do
local bx, bz = l[1] + 3 + k * 1.6, l[2] + 2
for _, o in ipairs({ -1.4, 1.4 }) do add("Fahrradrad", bx, 2.4, bz + o, 0.15, 2.6, 2.6, { 30, 30, 32 }, "SmoothPlastic", { shape = "Cylinder", yaw = 90 }) end
add("Fahrradrahmen", bx, 3, bz, 0.2, 0.2, 2.8, ({ { 40, 40, 44 }, { 160, 40, 40 }, { 50, 90, 150 }, { 230, 230, 226 } })[k + 1], "Metal")
add("Fahrradsattel", bx, 3.9, bz - 0.8, 0.5, 0.2, 1, { 60, 44, 36 }, "SmoothPlastic")
add("Fahrradlenker", bx, 4, bz + 1.3, 1.6, 0.2, 0.2, { 60, 62, 66 }, "Metal")
stats.bikes = stats.bikes + 1
end
end
return { parts = parts, stats = stats }
end
return Marienplatz

end)()
local Stachus = (function()
local Geo = Geo
local Stachus = {}
local SAND, SAND2, SLATE, STONE, DARK = { 236, 222, 190 }, { 222, 204, 166 }, { 66, 72, 84 }, { 206, 200, 186 }, { 70, 66, 62 }
local GLASS, GLASS_LIT = { 74, 98, 118 }, { 255, 224, 150 }
local SHOPS = { "LEDERWAREN", "APOTHEKE", "BÄCKEREI", "UHREN SCHMID", "SPORTHAUS", "CAFÉ ROSA", "MODE & CO", "BUCHHANDLUNG", "OPTIK", "SCHMUCK", "EISDIELE", "SCHUHE", "BLUMEN", "BANK" }
local SIGNS = { { 40, 40, 44 }, { 30, 90, 56 }, { 120, 70, 40 }, { 30, 50, 96 }, { 110, 30, 40 }, { 60, 60, 66 } }
local AWN = { { 190, 60, 50 }, { 60, 100, 150 }, { 70, 130, 90 }, { 220, 170, 60 } }
local function newRng(seed)
local s = seed
return function()
s = (s * 1103515245 + 12345) % 2147483648
return s / 2147483648
end
end
function Stachus.plan(cfg)
local S = cfg.stachus
local parts = {}
local stats = { segs = 0, shops = 0, jets = 0, merlons = 0, taxis = 0, lamps = 0, trees = 0, towers = 0, pits = #cfg.stachus.ubahn }
local rng = newRng(11)
local function add(name, kind, x, y, z, sx, sy, sz, color, mat, e)
e = e or {}
parts[#parts + 1] = {
name = name, kind = kind, size = { Geo.round3(sx), Geo.round3(sy), Geo.round3(sz) }, pos = { Geo.round3(x), Geo.round3(y), Geo.round3(z) },
yaw = e.yaw or 0, pitch = e.pitch or 0, roll = e.roll, color = color, material = mat, collide = e.collide == true, shape = e.shape,
text = e.text, tag = e.tag, lit = e.lit, attrs = e.attrs, transparency = e.transparency, emitter = e.emitter, wedge = e.wedge,
}
end
local function vcyl(name, kind, x, y, z, h, d, color, mat, e)
e = e or {}
e.shape, e.roll = "Cylinder", 90
add(name, kind, x, y, z, h, d, d, color, mat, e)
end
local function frame(cx, cz, psi)
local r = math.rad(psi)
local c, s = math.cos(r), math.sin(r)
local function W(lx, y, lz) return cx + lx * c + lz * s, y, cz - lx * s + lz * c end
return function(name, kind, lx, y, lz, sx, sy, sz, color, mat, e)
e = e or {}
local ee = {}
for k, v in pairs(e) do ee[k] = v end
ee.yaw = (psi + (e.yaw or 0)) % 360
add(name, kind, cx + lx * c + lz * s, y, cz - lx * s + lz * c, sx, sy, sz, color, mat, ee)
end, W
end
local function wtri(W, name, kind, a, b, c, thick, color, mat, hint, e)
local function pt(v) local x, y, z = W(v[1], v[2], v[3]) return { x, y, z } end
local h
if hint then
local hx, hy, hz = W(hint[1], hint[2], hint[3])
local ox, oy, oz = W(0, 0, 0)
h = { hx - ox, hy - oy, hz - oz }
end
for _, w in ipairs(Geo.wedges(pt(a), pt(b), pt(c), thick, h)) do
local ee = {}
for k, v in pairs(e or {}) do ee[k] = v end
ee.wedge = w.wedge
add(name, kind, w.pos[1], w.pos[2], w.pos[3], w.size[1], w.size[2], w.size[3], color, mat, ee)
end
end
local function facebox(put, face, half, name, kind, u, y, n, su, sy, sn, color, mat, e)
if face == "F" then put(name, kind, u, y, -(half + n), su, sy, sn, color, mat, e)
elseif face == "B" then put(name, kind, u, y, half + n, su, sy, sn, color, mat, e)
elseif face == "L" then put(name, kind, -(half + n), y, u, sn, sy, su, color, mat, e)
else put(name, kind, half + n, y, u, sn, sy, su, color, mat, e) end
end
local TRIM = { 226, 212, 184 }
local function bay(put, face, half, u, yc, ww, wh, lit)
facebox(put, face, half, "FensterRahmen", "trim", u, yc, 0.3, ww + 1.4, wh + 1.4, 0.6, TRIM, "Concrete")
facebox(put, face, half, "Fenster", "glass", u, yc, 0.62, ww, wh, 0.2, lit and GLASS_LIT or GLASS, "Glass", { tag = "HouseWindow", lit = false })
facebox(put, face, half, "Fenstersprosse", "trim", u, yc, 0.8, 0.25, wh, 0.25, TRIM, "Concrete")
facebox(put, face, half, "Fensterbank", "trim", u, yc - wh / 2 - 0.7, 0.7, ww + 2.2, 0.5, 1.4, TRIM, "Concrete")
facebox(put, face, half, "Sturz", "trim", u, yc + wh / 2 + 0.9, 0.5, ww + 2, 0.7, 1.0, TRIM, "Concrete")
end
local cx, cz, ac, bc, D = S.cx, S.cz, S.ac, S.bc, S.depth
local H, Y0 = 14 + 12 * (S.floors - 1), 1
local TOP = Y0 + H
local pits = S.ubahn
local px0, px1 = pits[1].x0, pits[1].x1 -- beide Gruben liegen in demselben x-Streifen
local function slab(x0, z0, x1, z1)
if x1 - x0 > 0.01 and z1 - z0 > 0.01 then add("Pflaster", "plaza", (x0 + x1) / 2, 0, (z0 + z1) / 2, x1 - x0, 2, z1 - z0, { 204, 198, 188 }, "Granite", { collide = true }) end
end
slab(S.x0, S.z0, px0, S.z1)
slab(px1, S.z0, S.x1, S.z1)
local zs = { S.z0 }
for _, pt in ipairs(pits) do zs[#zs + 1] = pt.z0 zs[#zs + 1] = pt.z1 end
zs[#zs + 1] = S.z1
table.sort(zs)
for i = 1, #zs - 1, 2 do slab(px0, zs[i], px1, zs[i + 1]) end
local function inPit(x, z)
for _, pt in ipairs(pits) do if x > pt.x0 - 0.1 and x < pt.x1 + 0.1 and z > pt.z0 - 0.1 and z < pt.z1 + 0.1 then return true end end
return false
end
for x = S.x0 + 8, S.x1 - 4, 8 do
if x > px0 and x < px1 then -- Fuge längs z, an den Gruben unterbrochen
for i = 1, #zs - 1, 2 do add("Fuge", "plaza", x, 1.1, (zs[i] + zs[i + 1]) / 2, 0.3, 0.2, zs[i + 1] - zs[i], { 172, 166, 156 }, "SmoothPlastic") end
else
add("Fuge", "plaza", x, 1.1, (S.z0 + S.z1) / 2, 0.3, 0.2, S.z1 - S.z0, { 172, 166, 156 }, "SmoothPlastic")
end
end
for z = S.z0 + 8, S.z1 - 4, 8 do
if inPit(px0 + 1, z) then
add("Fuge", "plaza", (S.x0 + px0) / 2, 1.1, z, px0 - S.x0, 0.2, 0.3, { 172, 166, 156 }, "SmoothPlastic")
add("Fuge", "plaza", (px1 + S.x1) / 2, 1.1, z, S.x1 - px1, 0.2, 0.3, { 172, 166, 156 }, "SmoothPlastic")
else
add("Fuge", "plaza", (S.x0 + S.x1) / 2, 1.1, z, S.x1 - S.x0, 0.2, 0.3, { 172, 166, 156 }, "SmoothPlastic")
end
end
for i, rr in ipairs({ 52, 49, 46 }) do vcyl("Pflasterring", "plaza", cx, 1.0 + i * 0.15, cz, 0.3, 2 * rr, i == 2 and { 150, 96, 84 } or { 186, 180, 170 }, "Granite") end
local R = S.basin
for i = 0, 35 do
local a = math.rad(i * 10)
add("Beckenrand", "plaza", cx + R * math.cos(a), 2.1, cz + R * math.sin(a), 8, 2.2, 2.6, STONE, "Granite", { yaw = math.deg(math.atan2(-math.cos(a), -math.sin(a))) % 360, collide = true })
end
vcyl("Beckenboden", "plaza", cx, 1.2, cz, 0.3, 2 * R, { 120, 140, 156 }, "Concrete")
vcyl("Wasser", "plaza", cx, 2.3, cz, 0.4, 2 * R - 2, { 130, 180, 214 }, "SmoothPlastic", { transparency = 0.45 })
for _, ring in ipairs({ { 20, 24, 10, 6, 30, 26 }, { 32, 30, 8, 5, 35, 22 } }) do -- Radius, Düsen, Reichweite, Höhe, Neigung nach außen (Grad), Strahlgeschwindigkeit
for k = 0, ring[2] - 1 do
local a = math.rad(k * 360 / ring[2] + (ring[1] > 25 and 6 or 0))
add("Duese", "plaza", cx + ring[1] * math.cos(a), 2.6, cz + ring[1] * math.sin(a), 0.5, 0.5, 0.5, { 240, 248, 255 }, "SmoothPlastic",
{ yaw = (90 - math.deg(a)) % 360, pitch = ring[5], emitter = { rate = 16, speed = ring[6], spread = 3, gravity = 60, life = 1.1, size = 0.5, color = { 225, 240, 255 } } })
stats.jets = stats.jets + 1
end
end
vcyl("Mittelstrahl", "plaza", cx, 9, cz, 14, 1.4, { 240, 248, 255 }, "SmoothPlastic", { transparency = 0.3 })
vcyl("Mittelsockel", "plaza", cx, 2.2, cz, 1.6, 8, STONE, "Granite", { collide = true })
for i = 0, 35 do -- Poller (niedrige Steinstümpfe) rund um das Becken
local a = math.rad(i * 10 + 5)
vcyl("Poller", "plaza", cx + (R + 7) * math.cos(a), 2.3, cz + (R + 7) * math.sin(a), 2.6, 2.4, { 150, 146, 140 }, "Granite", { collide = true })
end
for i = 0, 9 do -- Sitzsteine auf der Ostseite
local a = math.rad(-72 + i * 16)
add("Sitzstein", "plaza", cx + (R + 11) * math.cos(a), 2.3, cz + (R + 11) * math.sin(a), 3.4, 2.6, 2.6, { 160, 156, 148 }, "Granite", { yaw = i * 23, collide = true })
end
local shopNo, roofSigns = 0, {}
local function segment(x, z, psi, len, idx, opts)
opts = opts or {}
local put = frame(x, z, psi)
local W = len + 1.4
stats.segs = stats.segs + 1
put("Gebaeude", "body", 0, Y0 + H / 2, 0, W, H, D, SAND, "SmoothPlastic", { collide = true })
for _, face in ipairs({ "F", "B" }) do
facebox(put, face, D / 2, "Sockel", "trim", 0, Y0 + 1.2, 0.25, W, 2.4, 0.5, { 140, 136, 130 }, "Concrete")
for k = 1, S.floors - 1 do facebox(put, face, D / 2, "Gesims", "trim", 0, Y0 + 14 + 12 * (k - 1), 0.4, W, 0.7, 0.8, { 214, 200, 170 }, "Concrete") end
facebox(put, face, D / 2, "Lisene", "trim", -len / 2, Y0 + 2.4 + (H - 3.6) / 2, 0.3, 1.0, H - 3.6, 0.6, TRIM, "Concrete")
end
put("Kranzgesims", "trim", 0, Y0 + H - 0.8, 0, W + 0.4, 1.6, D + 0.8, { 244, 236, 214 }, "Concrete")
local rise, run = 7, 4
local ln = math.sqrt(run * run + rise * rise)
local ang = math.deg(math.atan2(rise, run))
local base = Y0 + H
put("Mansard", "roof", 0, base + rise / 2 + 0.3, -D / 2 + run / 2, W, 0.8, ln, SLATE, "Metal", { pitch = -ang })
put("Mansard", "roof", 0, base + rise / 2 + 0.3, D / 2 - run / 2, W, 0.8, ln, SLATE, "Metal", { pitch = ang })
put("MansardFuellung", "body", 0, base + rise / 2 + 0.3, 0, W, rise, D - 2 * run, { 56, 60, 70 }, "SmoothPlastic", { collide = true })
put("Dach", "roof", 0, base + rise + 0.6, 0, W, 0.6, D - 2 * run, SLATE, "Metal")
if idx % 2 == 0 then
put("Gaube", "body", 0, base + 2.6, -D / 2 + 2.2, 3.8, 4.4, 2.6, SAND, "SmoothPlastic")
put("GaubeFenster", "glass", 0, base + 2.6, -D / 2 + 0.85, 2.4, 2.8, 0.2, GLASS, "Glass", { tag = "HouseWindow", lit = rng() < 0.3 })
put("GaubeDach", "roof", 0, base + 5.0, -D / 2 + 2.2, 4.6, 0.5, 3.4, SLATE, "Metal")
end
for k = 1, S.floors - 1 do
local yb = Y0 + 14 + 12 * (k - 1)
for _, u in ipairs({ -len * 0.25, len * 0.25 }) do
bay(put, "F", D / 2, u, yb + 6, 2.8, 6.2, rng() < 0.3)
bay(put, "B", D / 2, u, yb + 6, 2.8, 6.2, rng() < 0.3)
end
if k == 1 or k == 3 then
put("BalkonPlatte", "balcony", 0, yb + 0.3, -D / 2 - 1.2, W - 1.2, 0.5, 2.4, { 170, 166, 158 }, "Concrete")
for _, yy in ipairs({ yb + 0.9, yb + 3.0 }) do put("BalkonHolm", "balcony", 0, yy, -D / 2 - 2.3, W - 1.2, 0.25, 0.25, { 60, 60, 66 }, "Metal") end
local nb = 7
for q = 0, nb do put("BalkonStab", "balcony", -(W - 1.2) / 2 + q * (W - 1.2) / nb, yb + 1.95, -D / 2 - 2.3, 0.18, 2.1, 0.18, { 60, 60, 66 }, "Metal") end
end
end
put("Pilaster", "trim", -len / 2, Y0 + 7, -D / 2 - 0.6, 1.2, 14, 1.2, { 214, 200, 170 }, "Concrete")
if not opts.noShop then
shopNo = shopNo + 1
stats.shops = stats.shops + 1
local burger = opts.burger
local name = burger and "McDonnell's" or SHOPS[(shopNo * 5) % #SHOPS + 1]
local sc = burger and { 190, 30, 36 } or SIGNS[shopNo % #SIGNS + 1]
put("LadenGlas", "glass", 0, Y0 + 5.2, -D / 2 - 0.2, len - 1.4, 8.4, 0.3, { 150, 190, 206 }, "Glass", { tag = "HouseWindow", lit = true })
put("LadenSchild", "trim", 0, Y0 + 11.3, -D / 2 - 0.5, len - 0.2, 2.2, 0.5, sc, "SmoothPlastic")
put("LadenSchrift", "sign", 0, Y0 + 11.3, -D / 2 - 0.8, len - 0.8, 1.7, 0.1, { 0, 0, 0 }, "SmoothPlastic", { text = { s = name, color = burger and { 255, 208, 40 } or { 244, 238, 220 } } })
put("Markise", "trim", 0, Y0 + 9.6, -D / 2 - 1.4, len - 0.4, 0.3, 2.6, burger and { 255, 208, 40 } or AWN[shopNo % #AWN + 1], "Fabric", { pitch = 14 })
end
for _, u in ipairs({ -len * 0.25, len * 0.25 }) do bay(put, "B", D / 2, u, Y0 + 7.2, 3.2, 8.6, true) end
end
local ROOFA, ROOFB, GOLD = { 84, 128, 112 }, { 70, 112, 98 }, { 226, 184, 72 }
local function dome(put, W, y0, a, b, rise)
local N = 16
local rings = {}
for _, phi in ipairs({ 0, 32, 60, 80 }) do
local sc, h, pts = math.cos(math.rad(phi)), rise * math.sin(math.rad(phi)), {}
for k = 0, N - 1 do
local t = 2 * math.pi * k / N
local c, sn = math.cos(t), math.sin(t)
pts[#pts + 1] = { sc * a * (c < 0 and -1 or 1) * math.abs(c) ^ 0.5, y0 + h, sc * b * (sn < 0 and -1 or 1) * math.abs(sn) ^ 0.5 }
end
rings[#rings + 1] = pts
end
local apex = { 0, y0 + rise, 0 }
local function face(p1, p2, p3, col)
local hint = { (p1[1] + p2[1] + p3[1]) / 3, (p1[2] + p2[2] + p3[2]) / 3 - (y0 - rise * 0.5), (p1[3] + p2[3] + p3[3]) / 3 }
wtri(W, "Kuppel", "roof", p1, p2, p3, 0.8, col, "Metal", hint)
end
for i = 1, #rings - 1 do
for k = 1, N do
local k2 = k % N + 1
local col = ((i + k) % 2 == 0) and ROOFA or ROOFB
face(rings[i][k], rings[i][k2], rings[i + 1][k2], col)
face(rings[i][k], rings[i + 1][k2], rings[i + 1][k], col)
end
end
local top = rings[#rings]
for k = 1, N do face(top[k], top[k % N + 1], apex, (k % 2 == 0) and ROOFA or ROOFB) end
local fy = y0 + rise - 0.3 -- Spitze aus sechs Dreiecken
for k = 0, 5 do
local t0, t1 = math.pi * k / 3, math.pi * (k + 1) / 3
local p1, p2, p3 = { 1.1 * math.cos(t0), fy, 1.1 * math.sin(t0) }, { 1.1 * math.cos(t1), fy, 1.1 * math.sin(t1) }, { 0, fy + 6.5, 0 }
wtri(W, "KuppelSpitze", "roof", p1, p2, p3, 0.4, GOLD, "Metal", { (p1[1] + p2[1]) / 2, fy + 1, (p1[3] + p2[3]) / 2 })
end
end
local function tower(x, z, psi, Wt)
local put, Wf = frame(x, z, psi)
local Ht = H + 12
stats.towers = stats.towers + 1
put("Turm", "body", 0, Y0 + Ht / 2, 0, Wt, Ht, D, SAND2, "SmoothPlastic", { collide = true })
put("TurmKranz", "trim", 0, Y0 + Ht - 0.8, 0, Wt + 1.4, 1.6, D + 1.4, { 244, 236, 214 }, "Concrete")
for _, face in ipairs({ "F", "B", "L", "R" }) do
local half = (face == "F" or face == "B") and D / 2 or Wt / 2
local len = (face == "F" or face == "B") and Wt or D
facebox(put, face, half, "TurmSockel", "trim", 0, Y0 + 1.2, 0.25, len, 2.4, 0.5, { 140, 136, 130 }, "Concrete")
for k = 1, 5 do facebox(put, face, half, "TurmGesims", "trim", 0, Y0 + 14 + 12 * (k - 1), 0.4, len, 0.7, 0.8, { 214, 200, 170 }, "Concrete") end
for _, u in ipairs({ -len / 2 + 0.6, len / 2 - 0.6 }) do facebox(put, face, half, "Lisene", "trim", u, Y0 + 2.4 + (Ht - 3.6) / 2, 0.3, 1.2, Ht - 3.6, 0.6, TRIM, "Concrete") end
for k = 1, 5 do
for _, u in ipairs({ -len / 3, 0, len / 3 }) do bay(put, face, half, u, Y0 + 14 + 12 * (k - 1) + 6, 2.8, 6.4, rng() < 0.3) end
end
for _, u in ipairs({ -len / 3, 0, len / 3 }) do bay(put, face, half, u, Y0 + 7.2, 3.6, 8.6, true) end
end
dome(put, Wf, Y0 + Ht, Wt / 2, D / 2, 14)
end
local TW = D -- Eckturm: Grundfläche quadratisch (Breite = Tiefe)
local zN = S.rowN -- Mittellinie der Nordzeile; die Südzeile liegt spiegelbildlich zur Platzmitte
local zS = 2 * cz - zN
local xW = S.x0 + D / 2 + 1.6 -- Mittellinie der Westzeile (1,6 Abstand zur Platzgrenze für Gesimse und Fensterrahmen der Rückseite)
local idx = 0
local function rowEW(z, psi, burgerAt) -- Zeile von der Platzkante x0 bis zum Eckturm am Ostende
local xa, xb = S.x0 + 2.3, S.eastEnd - TW - 0.7
local m = math.floor((xb - xa) / S.seg + 0.5)
local Lr = (xb - xa) / m
for k = 1, m do
idx = idx + 1
segment(xa + (k - 0.5) * Lr, z, psi, Lr, idx, { burger = burgerAt and (k == burgerAt or k == burgerAt + 1) })
if k == math.floor(m / 2) then roofSigns[#roofSigns + 1] = { x = xa + (k - 0.5) * Lr, z = z, psi = psi } end
end
tower(S.eastEnd - TW / 2 - 0.7, z, psi, TW)
end
rowEW(zN, 180, 10)
rowEW(zS, 0, nil)
do -- Westzeile: zwischen Nord- und Südzeile je ein Stück bis zum Eckturm neben dem Karlstor
local function run(za, zb)
local m = math.max(1, math.floor((zb - za) / S.seg + 0.5))
local Lr = (zb - za) / m
for k = 1, m do
idx = idx + 1
segment(xW, za + (k - 0.5) * Lr, 270, Lr, idx, {})
end
end
run(zN + D / 2, cz - S.gate - TW)
run(cz + S.gate + TW, zS - D / 2)
tower(xW, cz - S.gate - TW / 2, 270, TW)
tower(xW, cz + S.gate + TW / 2, 270, TW)
end
for _, rs in ipairs(roofSigns) do
local put = frame(rs.x, rs.z, rs.psi)
local base = TOP + 7.6
for _, lx in ipairs({ -12, 12 }) do put("SchriftPfosten", "trim", lx, base + 2.4, -4, 0.8, 4.8, 0.8, { 90, 90, 96 }, "Metal") end
put("SchriftBrett", "sign", 0, base + 7.5, -4, 34, 7, 0.8, { 176, 32, 40 }, "SmoothPlastic")
put("SchriftOSRUM", "sign", 0, base + 7.5, -4.5, 31, 5.4, 0.2, { 0, 0, 0 }, "SmoothPlastic", { text = { s = "OSRUM", color = { 250, 244, 236 } } })
end
do
local gx, gz = xW, cz
local put, Wf = frame(gx, gz, 270)
local GD = D - 1.6
local WALL, WALL2 = { 238, 236, 228 }, { 226, 222, 210 }
local TT, MT = H - 2.2, H - 6.2 -- Mauerkrone Türme / Mittelbau (Zinnen setzen 2,2 obendrauf)
local function archPts(hw, ySpring, n) -- Spitzbogen aus zwei Kreisbögen (Radius = Breite): Punkte von links nach rechts, y relativ zum Pflaster
local R, pts = 2 * hw, {}
for k = 0, n do
local th = math.rad(180 - 60 * k / n)
pts[#pts + 1] = { hw + R * math.cos(th), ySpring + R * math.sin(th) }
end
for k = n - 1, 0, -1 do pts[#pts + 1] = { -pts[k + 1][1], pts[k + 1][2] } end
return pts
end
local function archWall(cxm, hw, ySpring, xl, xr, top, n)
put("TorMauer", "body", (xl + cxm - hw) / 2, Y0 + top / 2, 0, cxm - hw - xl, top, GD, WALL, "SmoothPlastic", { collide = true })
put("TorMauer", "body", (cxm + hw + xr) / 2, Y0 + top / 2, 0, xr - cxm - hw, top, GD, WALL, "SmoothPlastic", { collide = true })
local pts = archPts(hw, ySpring, n)
for k = 1, #pts - 1 do
local a, b = pts[k], pts[k + 1]
local xa, xb = cxm + a[1], cxm + b[1]
local yhi = math.max(a[2], b[2])
if top > yhi then put("TorMauer", "body", (xa + xb) / 2, Y0 + (yhi + top) / 2, 0, xb - xa + 0.02, top - yhi, GD, WALL, "SmoothPlastic", { collide = true }) end
local third = (a[2] < b[2]) and { xa, Y0 + b[2], 0 } or { xb, Y0 + a[2], 0 }
wtri(Wf, "TorMauer", "body", { xa, Y0 + a[2], 0 }, { xb, Y0 + b[2], 0 }, third, GD, WALL, "SmoothPlastic", nil, { collide = true })
end
end
local function moulding(cxm, hw, ySpring, n, band)
local inner, outer = archPts(hw, ySpring, n), archPts(hw + band, ySpring, n)
for _, fz in ipairs({ -1, 1 }) do
local zz = fz * (GD / 2 + 0.25)
for k = 1, #inner - 1 do
local p1, p2 = { cxm + inner[k][1], Y0 + inner[k][2], zz }, { cxm + inner[k + 1][1], Y0 + inner[k + 1][2], zz }
local q1, q2 = { cxm + outer[k][1], Y0 + outer[k][2], zz }, { cxm + outer[k + 1][1], Y0 + outer[k + 1][2], zz }
wtri(Wf, "TorLeiste", "trim", p1, p2, q1, 0.5, WALL2, "Concrete", { 0, 0, fz })
wtri(Wf, "TorLeiste", "trim", p2, q2, q1, 0.5, WALL2, "Concrete", { 0, 0, fz })
end
for _, sd in ipairs({ -1, 1 }) do put("TorLeiste", "trim", cxm + sd * (hw + band / 2), Y0 + ySpring / 2, zz, band, ySpring, 0.5, WALL2, "Concrete") end
end
end
archWall(0, 7.5, 22, -12, 12, MT, 9)
moulding(0, 7.5, 22, 9, 1.4)
for _, sd in ipairs({ -1, 1 }) do
archWall(sd * 21, 3.5, 11, sd * 21 - 9, sd * 21 + 9, TT, 6)
moulding(sd * 21, 3.5, 11, 6, 0.9)
put("TorTurmGesims", "trim", sd * 21, Y0 + TT - 1, 0, 19.2, 1.4, GD + 1.2, WALL2, "Concrete")
put("TorTurmStreifen", "trim", sd * 21, Y0 + 22, 0, 19, 0.8, GD + 1.0, WALL2, "Concrete")
for _, fz in ipairs({ -1, 1 }) do
for _, wy in ipairs({ 30, 41, 51 }) do bay(put, fz < 0 and "F" or "B", GD / 2, sd * 21, Y0 + wy, 2.2, 4.4, false) end
local zz = fz * (GD / 2 + 0.3)
put("TorTafel", "trim", sd * 27.6, Y0 + 30, zz, 4.2, 6, 0.5, { 214, 206, 190 }, "Concrete")
put("TorTafelSchrift", "sign", sd * 27.6, Y0 + 30, zz + fz * 0.3, 3.6, 1.1, 0.1, { 0, 0, 0 }, "SmoothPlastic", { yaw = fz < 0 and 0 or 180, text = { s = "ANNO 1302", color = { 90, 86, 80 } } })
end
end
for _, fz in ipairs({ -1, 1 }) do
local zz = fz * (GD / 2 + 0.35)
for _, sd in ipairs({ -1, 1 }) do -- Wappen in den Zwickeln neben dem Hauptbogen
local u, wy = sd * 9.9, Y0 + 30
local col = sd < 0 and { 70, 110, 190 } or { 220, 220, 226 }
put("TorWappen", "trim", u, wy, zz, 3.4, 3.4, 0.5, col, "SmoothPlastic")
wtri(Wf, "TorWappen", "trim", { u - 1.7, wy - 1.7, zz }, { u + 1.7, wy - 1.7, zz }, { u, wy - 4.2, zz }, 0.5, col, "SmoothPlastic", { 0, 0, fz })
put("TorWappenKreuz", "trim", u, wy, zz + fz * 0.3, 0.6, 3.0, 0.2, { 190, 150, 50 }, "Metal")
end
put("TorSchrift", "sign", 0, Y0 + 42, fz * (GD / 2 + 0.4), 12, 1.6, 0.1, { 0, 0, 0 }, "SmoothPlastic", { yaw = fz < 0 and 0 or 180, text = { s = "KARLSTOR", color = { 90, 86, 80 } } })
end
put("TorMittelGesims", "trim", 0, Y0 + MT - 0.8, 0, 26, 1.6, GD + 1.2, WALL2, "Concrete")
local function merlons(lx0, lx1, y)
local len = lx1 - lx0
local k = math.max(2, math.floor(len / 3.6))
for q = 1, k do
for _, fz in ipairs({ -GD / 2 + 1, GD / 2 - 1 }) do
put("Zinne", "trim", lx0 + (q - 0.5) * len / k, y + 1.1, fz, len / k * 0.55, 2.2, 1.6, WALL, "Concrete", { collide = true })
stats.merlons = stats.merlons + 1
end
end
for _, lx in ipairs({ lx0 + 0.8, lx1 - 0.8 }) do
for _, fz in ipairs({ -GD / 4, 0, GD / 4 }) do put("Zinne", "trim", lx, y + 1.1, fz, 1.6, 2.2, 3, WALL, "Concrete", { collide = true }) stats.merlons = stats.merlons + 1 end
end
end
merlons(-12, 12, Y0 + MT)
merlons(-30, -12, Y0 + TT)
merlons(12, 30, Y0 + TT)
end
local CONC, STEEL, UBLUE, SGREEN, WHITE = { 226, 224, 218 }, { 60, 64, 70 }, { 0, 94, 184 }, { 0, 150, 70 }, { 255, 255, 255 }
for pi, U in ipairs(pits) do
local len, wd = U.x1 - U.x0, U.z1 - U.z0
local put = frame(U.x0, (U.z0 + U.z1) / 2, 90)
local nSteps, landing = 14, 6
local rise, run = U.depth / nSteps, (len - landing) / nSteps
local bottom = 1 - U.depth
local lanes = { { -4.6, 3.8, { 70, 74, 80 }, "Metal" }, { 0, 4.8, { 168, 166, 160 }, "Granite" }, { 4.6, 3.8, { 70, 74, 80 }, "Metal" } }
for k = 1, nSteps do
local t = 1 - k * rise
for _, ln in ipairs(lanes) do
put("UBahnStufe", "plaza", ln[1], (t - 12) / 2, (k - 0.5) * run, ln[2], t + 12, run, ln[3], ln[4], { collide = true })
end
end
put("UBahnPodest", "plaza", 0, (bottom - 12) / 2, len - landing / 2, wd - 2.4, bottom + 12, landing, { 150, 148, 144 }, "Granite", { collide = true })
local slope = math.sqrt((len - landing) ^ 2 + U.depth ^ 2)
local pitch = math.deg(math.atan2(U.depth, len - landing))
for _, lx in ipairs({ -7.2, -2.4, 2.4, 7.2 }) do -- Handläufe (sinken mit der Treppe)
put("UBahnHandlauf", "plaza", lx, 1 - U.depth / 2 + 2.6, (len - landing) / 2, 0.3, 0.3, slope, STEEL, "Metal", { pitch = pitch })
end
for _, sd in ipairs({ -1, 1 }) do -- Seitenwände (Betonrahmen) bis 1,6 über das Pflaster
put("UBahnWand", "plaza", sd * (wd / 2 - 0.6), -5.2 + 0.8, len / 2, 1.2, 13.6 + 1.6, len, CONC, "Concrete", { collide = true })
for k = 0, 5 do -- Glasgeländer auf dem Rahmen
put("UBahnGlas", "glass", sd * (wd / 2 - 0.6), 3.2, (k + 0.5) * len / 6, 0.2, 1.8, len / 6 - 0.3, { 190, 220, 232 }, "Glass", { collide = false, transparency = 0.5 })
end
end
local pw, ph = 10, 8
for _, sd in ipairs({ -1, 1 }) do
put("UBahnWand", "plaza", sd * (pw / 2 + (wd - pw) / 4), -5.2 + 0.8, len - 0.6, (wd - pw) / 2, 13.6 + 1.6, 1.2, CONC, "Concrete", { collide = true })
end
put("UBahnWand", "plaza", 0, (bottom + ph + 2.4) / 2, len - 0.6, pw, 2.4 - bottom - ph, 1.2, CONC, "Concrete", { collide = true })
put("UBahnSchild", "plaza", 0, 3.2, len - 1.3, 14, 2.4, 0.3, UBLUE, "SmoothPlastic")
put("Schrift", "sign", 0, 3.2, len - 1.5, 13, 1.8, 0.2, WHITE, "SmoothPlastic", { yaw = 0, text = { s = "U  S  KARLSPLATZ", color = WHITE } })
put("UBahnPylon", "plaza", -(wd / 2 + 2.4), 6, -2.5, 0.8, 10, 0.8, { 30, 32, 36 }, "Metal", { collide = true })
put("UBahnU", "plaza", -(wd / 2 + 2.4), 10.8, -2.5, 4, 4, 0.4, UBLUE, "SmoothPlastic")
put("Schrift", "sign", -(wd / 2 + 2.4), 10.8, -2.8, 3.4, 3.4, 0.2, WHITE, "SmoothPlastic", { text = { s = "U", color = WHITE } })
put("Schrift", "sign", -(wd / 2 + 2.4), 10.8, -2.2, 3.4, 3.4, 0.2, WHITE, "SmoothPlastic", { yaw = 180, text = { s = "U", color = WHITE } })
local g0, g1 = len, len + U.gang
put("UBahnGangBoden", "plaza", 0, bottom - 0.5, (g0 + g1) / 2, pw + 2, 1, g1 - g0, { 150, 148, 144 }, "Granite", { collide = true })
put("UBahnGangDecke", "plaza", 0, bottom + ph + 1, (g0 + g1) / 2, pw + 2, 1, g1 - g0, { 200, 200, 196 }, "Concrete", { collide = true })
for _, sd in ipairs({ -1, 1 }) do put("UBahnGangWand", "plaza", sd * (pw / 2 + 0.5), bottom + ph / 2, (g0 + g1) / 2, 1, ph, g1 - g0, { 226, 222, 210 }, "Concrete", { collide = true }) end
put("UBahnGangWand", "plaza", 0, bottom + ph / 2, g1 + 0.5, pw + 2, ph, 1, { 226, 222, 210 }, "Concrete", { collide = true })
for k = 1, 3 do put("UBahnLicht", "plaza", 0, bottom + ph + 0.4, len + k * U.gang / 4, 1.2, 0.2, 3, { 255, 250, 236 }, "Neon") end
end
for z = S.z0 + 41, S.z1 - 12, 42 do -- mittig zwischen den Platanen (Bäume bei z = 80 + 42 k), nicht in den Kronen
vcyl("KugelleuchteMast", "plaza", -68, 13, z, 24, 0.8, { 150, 152, 156 }, "Metal", { collide = true })
for _, yy in ipairs({ 19.6, 23.6 }) do add("Kugelleuchte", "plaza", -68, yy, z, 4.4, 4.4, 4.4, { 255, 250, 238 }, "Neon", { shape = "Ball", tag = "StreetLamp", attrs = { Lit = true } }) end
stats.lamps = stats.lamps + 1
end
local GREENS = { { 70, 120, 60 }, { 88, 140, 70 }, { 60, 108, 58 } }
for i, z in ipairs({ 80, 122, 164, 206, 248, 290, 332, 372 }) do
local x = -64
vcyl("Baumscheibe", "plaza", x, 1.15, z, 0.3, 6, { 70, 66, 60 }, "Metal")
vcyl("PlataneStamm", "plaza", x, 7, z, 12, 2.2, { 150, 138, 116 }, "Wood", { collide = true })
add("PlataneKrone", "plaza", x, 18, z, 17, 15, 17, GREENS[i % 3 + 1], "Grass", { shape = "Ball" })
add("PlataneKrone", "plaza", x + 3, 15.5, z - 3, 12, 11, 12, GREENS[(i + 1) % 3 + 1], "Grass", { shape = "Ball" })
stats.trees = stats.trees + 1
end
for k = 0, S.taxi.n - 1 do
local z = S.taxi.z0 + S.taxi.len * (k + 0.5)
add("TaxiMarkierung", "sign", S.taxi.x, 0.58, z, 6.6, 3.4, 0.1, { 0, 0, 0 }, "SmoothPlastic", { pitch = 90, text = { s = "TAXI", color = { 250, 214, 60 } } })
stats.taxis = stats.taxis + 1
end
for _, z in ipairs({ S.taxi.z0 - 2, S.taxi.z0 + S.taxi.len * S.taxi.n + 2 }) do
vcyl("TaxiMast", "plaza", -49, 8, z, 14, 0.5, { 130, 134, 140 }, "Metal", { collide = true })
add("TaxiTafel", "sign", -49, 14.5, z, 0.4, 3.6, 3.6, { 30, 70, 160 }, "SmoothPlastic", { yaw = 0 })
add("TaxiSchrift", "sign", -49.3, 14.5, z, 3.2, 1.6, 0.1, { 0, 0, 0 }, "SmoothPlastic", { yaw = 270, text = { s = "TAXI", color = { 255, 255, 255 } } })
end
return { parts = parts, stats = stats }
end
return Stachus

end)()
local Autohaus = (function()
local Geo = Geo
local Autohaus = {}
local WHITE, GREY, DARK, CONC, ASPHALT, GLASS, BLUE, LINE = { 240, 240, 236 }, { 150, 154, 160 }, { 70, 74, 82 }, { 196, 196, 192 }, { 84, 90, 96 }, { 150, 186, 204 }, { 24, 66, 150 }, { 240, 240, 236 }
function Autohaus.plan(cfg)
local A = cfg.autohaus
local parts, stats = {}, { bays = 0, lamps = 0, trees = 0 }
local function r3(v) return math.floor(v * 1000 + 0.5) / 1000 end
local function add(name, kind, x, y, z, sx, sy, sz, color, mat, e)
e = e or {}
parts[#parts + 1] = {
name = name, kind = kind, size = { r3(sx), r3(sy), r3(sz) }, pos = { r3(x), r3(y), r3(z) }, yaw = e.yaw or 0, pitch = e.pitch or 0, roll = e.roll,
color = color, material = mat, collide = e.collide == true, shape = e.shape, text = e.text, tag = e.tag, lit = e.lit, attrs = e.attrs, transparency = e.transparency, wedge = e.wedge,
}
end
local function disc(name, x, y, z, h, d, color, mat, collide) -- stehende Scheibe
add(name, "decor", x, y, z, h, d, d, color, mat, { shape = "Cylinder", roll = 90, collide = collide })
end
local bx = A.frontX -- Westwand von Showroom und Werkstatt (hier endet der Vorplatz)
local zS0, zS1 = A.showroom[1], A.showroom[2] -- Showroom (z von Nord nach Süd)
local zW0, zW1 = A.werkstatt[1], A.werkstatt[2]
local zc = (zS0 + zS1) / 2
local xe = A.x1 - 2 -- Ostwand
local xm = (bx + xe) / 2
local Y = 0.5 -- Oberkante Boden (wie die Fahrbahn)
add("Vorplatz", "plaza", (A.x0 + bx) / 2, Y - 0.5, (A.z0 + A.z1) / 2, bx - A.x0, 1, A.z1 - A.z0, ASPHALT, "Asphalt", { collide = true })
add("Fundament", "plaza", xm, Y - 0.5, (A.z0 + A.z1) / 2, xe - bx, 1, A.z1 - A.z0, CONC, "Concrete", { collide = true })
for _, x in ipairs({ A.x0 + 8, A.x0 + 32 }) do
for z = zW1 + 4, zS1 - 2, 6 do
add("Boxenlinie", "dash", x + 8, Y + 0.1, z, 16, 0.2, 0.3, LINE, "SmoothPlastic")
stats.bays = stats.bays + 1
end
for _, xx in ipairs({ x, x + 16 }) do add("Boxenlinie", "dash", xx, Y + 0.1, (zW1 + 4 + zS1 - 2) / 2, 0.3, 0.2, zS1 - 2 - zW1 - 4, LINE, "SmoothPlastic") end
end
for _, z in ipairs({ zc - 14, zc, zc + 14 }) do disc("Drehteller", bx - 6, Y + 0.25, z, 0.5, 11, WHITE, "SmoothPlastic", true) end
for _, z in ipairs({ A.z0 + 0.4 }) do add("Zaun", "fence", (A.x0 + bx) / 2, Y + 0.7, z, bx - A.x0, 1.4, 0.2, DARK, "Metal") end
local H = 12
add("ShowroomBoden", "floor", xm, Y + 0.3, zc, xe - bx, 0.6, zS1 - zS0, { 200, 200, 196 }, "Concrete", { collide = true })
local R, N = 9, 6
local cx, cz = bx + R, zS1 - R
local gy = Y + H / 2 + 0.6
local function pane(x, z, len, yaw)
add("Glasfront", "glass", x, gy, z, len, H, 0.3, GLASS, "Glass", { yaw = yaw, tag = "HouseWindow", lit = true })
for _, yy in ipairs({ Y + 0.8 + H / 2, Y + H + 0.9 }) do add("Riegel", "trim", x, yy, z, len, 0.5, 0.7, DARK, "Metal", { yaw = yaw }) end
end
pane(bx + 0.15, (zS0 + cz) / 2, cz - zS0, 90)
pane((cx + xe) / 2, zS1 - 0.15, xe - cx, 0)
for k = 0, N do -- Pfosten an den Scheibenübergängen
local a = math.rad(90 * k / N)
add("Pfosten", "trim", cx - R * math.cos(a), Y + H / 2 + 0.6, cz + R * math.sin(a), 0.6, H + 0.2, 0.6, DARK, "Metal")
end
for k = 0, N - 1 do
local a0, a1 = math.rad(90 * k / N), math.rad(90 * (k + 1) / N)
local am = (a0 + a1) / 2
pane(cx - R * math.cos(am), cz + R * math.sin(am), 2 * R * math.sin((a1 - a0) / 2), math.deg(math.atan2(-math.cos(am), math.sin(am))))
end
for z = zS0, cz, (cz - zS0) / 3 do add("Pfosten", "trim", bx, Y + H / 2 + 0.6, z, 0.6, H + 0.2, 0.6, DARK, "Metal") end
for x = cx, xe, (xe - cx) / 3 do add("Pfosten", "trim", x, Y + H / 2 + 0.6, zS1, 0.6, H + 0.2, 0.6, DARK, "Metal") end
for _, dz in ipairs({ -2.1, 2.1 }) do
add("Eingangstuer", "glass", bx - 0.3, Y + 0.6 + 4.9, zc + dz, 0.3, 9.8, 4, { 160, 196, 212 }, "Glass", { tag = "ShopDoor" })
add("Tuergriff", "trim", bx - 0.7, Y + 0.6 + 4.6, zc + dz * 0.3, 0.3, 3, 0.25, { 200, 202, 206 }, "Metal")
end
for _, dz in ipairs({ -4.3, 0, 4.3 }) do add("Tuerrahmen", "trim", bx - 0.3, Y + 0.6 + 5, zc + dz, 0.6, 10.2, 0.4, DARK, "Metal") end
add("Tuerrahmen", "trim", bx - 0.3, Y + 0.6 + 10.1, zc, 0.6, 0.4, 8.8, DARK, "Metal")
add("Fussmatte", "decor", bx - 2.5, Y + 0.1, zc, 4, 0.2, 8.4, { 52, 54, 60 }, "Fabric")
add("Wand", "body", xm, Y + H / 2 + 0.6, zS0 + 0.4, xe - bx, H, 0.8, WHITE, "SmoothPlastic", { collide = true })
add("Wand", "body", xe + 0.4, Y + H / 2 + 0.6, zc, 0.8, H, zS1 - zS0, WHITE, "SmoothPlastic", { collide = true })
local roofY = Y + H + 1.2
add("Dachplatte", "roof", xm, roofY, zc, xe - bx + 2, 1.2, zS1 - zS0 + 2, CONC, "Concrete", { collide = true })
for _, z in ipairs({ zc - 14, zc, zc + 14 }) do -- Podeste im Showroom (leer)
disc("Podest", bx + 10, Y + 0.85, z, 0.5, 9, { 224, 224, 220 }, "SmoothPlastic", true)
add("Deckenlicht", "light", xm, Y + H + 0.2, z, xe - bx - 4, 0.2, 0.8, { 255, 250, 236 }, "Neon")
end
add("Empfangstheke", "decor", xe - 9, Y + 0.6 + 1.8, zS0 + 12, 3, 3.6, 14, { 224, 224, 220 }, "SmoothPlastic", { collide = true })
add("EmpfangsPlatte", "decor", xe - 9, Y + 0.6 + 3.7, zS0 + 12, 3.6, 0.3, 14.6, BLUE, "SmoothPlastic")
local lx, lz = xe - 10, zS1 - 10
disc("Loungetisch", lx, Y + 0.6 + 1.2, lz, 0.4, 5, WHITE, "SmoothPlastic", true)
add("Sofa", "decor", lx, Y + 0.6 + 1.4, lz - 4.5, 7, 2.8, 2.6, BLUE, "Fabric", { collide = true })
add("Sofa", "decor", lx, Y + 0.6 + 1.4, lz + 4.5, 7, 2.8, 2.6, BLUE, "Fabric", { collide = true })
for _, q in ipairs({ { bx + 4, zS0 + 4 }, { bx + 4, zS1 - 4 }, { xe - 3, zS1 - 3 } }) do
add("Topf", "decor", q[1], Y + 0.6 + 1, q[2], 2.4, 2, 2.4, { 70, 66, 62 }, "Concrete", { collide = true })
add("Zimmerpflanze", "bush", q[1], Y + 0.6 + 3.6, q[2], 3.4, 3.4, 3.4, { 52, 110, 58 }, "Grass", { shape = "Ball" })
end
add("InnenSchild", "sign", xe - 0.3, Y + 0.6 + 8, zc, 0.3, 3, 24, BLUE, "SmoothPlastic")
add("InnenSchrift", "sign", xe - 0.55, Y + 0.6 + 8, zc, 20, 2.4, 0.1, { 0, 0, 0 }, "SmoothPlastic", { yaw = 90, text = { s = "WILLKOMMEN", color = { 255, 255, 255 } } })
add("Vordach", "roof", bx - 3.5, Y + H, zc, 7, 0.5, 18, WHITE, "SmoothPlastic", { collide = true })
for _, z in ipairs({ zc - 8, zc + 8 }) do add("VordachStuetze", "trim", bx - 6.8, Y + H / 2, z, 0.5, H, 0.5, DARK, "Metal", { collide = true }) end
local signY = roofY + 0.6 + 2.3
add("Fassadenschild", "sign", bx - 0.6, signY, zc, 0.6, 4.6, 34, BLUE, "SmoothPlastic")
add("FassadenSchrift", "sign", bx - 0.95, signY, zc, 30, 3, 0.1, { 0, 0, 0 }, "SmoothPlastic", { yaw = 90, text = { s = "AUTOHAUS ISARTOR", color = { 255, 255, 255 } } })
local officeX0 = bx + 18
for z = zS0 + 4, zS1 - 4, 6 do add("Boxenlinie", "dash", (bx + officeX0) / 2 + 1, roofY + 0.7, z, 12, 0.2, 0.3, LINE, "SmoothPlastic") end
add("Gelaender", "rail", (bx + officeX0) / 2, roofY + 1.6, zS0 + 0.8, officeX0 - bx, 2, 0.3, GREY, "Metal", { collide = true })
add("Gelaender", "rail", bx + 5, roofY + 1.6, zS1 - 0.8, 10, 2, 0.3, GREY, "Metal", { collide = true })
for _, z in ipairs({ zS0 + 3, zS1 - 3 }) do add("Gelaender", "rail", bx + 0.2, roofY + 1.6, z, 0.3, 2, 6, GREY, "Metal", { collide = true }) end
local steps, zst = 13, zS1 + 1.4
local x0s, x1s = bx + 2, bx + 17
local rise = (roofY + 0.6 - Y) / steps
for k = 0, steps - 1 do
add("Treppenstufe", "steps", x0s + (k + 0.5) * (x1s - x0s) / steps, Y + (k + 1) * rise - 0.2, zst, (x1s - x0s) / steps + 0.05, 0.4, 2.6, GREY, "Metal", { collide = true })
end
local L = math.sqrt((x1s - x0s) ^ 2 + (roofY + 0.6 - Y) ^ 2)
local ang = math.deg(math.atan2(roofY + 0.6 - Y, x1s - x0s))
for _, dz in ipairs({ -1.3, 1.3 }) do add("Treppenwange", "steps", (x0s + x1s) / 2, (Y + roofY + 0.6) / 2 - 0.3, zst + dz, L, 0.4, 0.3, DARK, "Metal", { roll = ang }) end
local oH = 24
add("Buero", "body", (officeX0 + xe) / 2, roofY + 0.6 + oH / 2, zc, xe - officeX0, oH, zS1 - zS0, WHITE, "SmoothPlastic", { collide = true })
for _, dy in ipairs({ 6, 18 }) do
add("Bandfenster", "glass", officeX0 - 0.15, roofY + 0.6 + dy, zc, 0.3, 5, zS1 - zS0 - 4, GLASS, "Glass", { tag = "HouseWindow", lit = false })
add("Bandfenster", "glass", (officeX0 + xe) / 2, roofY + 0.6 + dy, zS1 + 0.15, xe - officeX0 - 4, 5, 0.3, GLASS, "Glass", { tag = "HouseWindow", lit = false })
end
add("Attika", "trim", (officeX0 + xe) / 2, roofY + 0.6 + oH + 0.4, zc, xe - officeX0 + 0.6, 0.8, zS1 - zS0 + 0.6, GREY, "Concrete")
local wH = 12
local zwc = (zW0 + zW1) / 2
add("Werkstatt", "body", xm, Y + wH / 2, zwc, xe - bx, wH, zW1 - zW0, WHITE, "SmoothPlastic", { collide = true })
add("WerkstattDach", "roof", xm, Y + wH + 0.3, zwc, xe - bx + 1, 0.6, zW1 - zW0 + 1, GREY, "Concrete")
for k = 0, 3 do add("Rolltor", "trim", bx - 0.15, Y + 4.5, zW0 + 4.5 + k * 6, 0.3, 8, 5, GREY, "Metal") end
add("ServiceSchild", "sign", bx - 0.2, Y + 10.2, zwc, 0.3, 2, 14, BLUE, "SmoothPlastic")
add("ServiceSchrift", "sign", bx - 0.45, Y + 10.2, zwc, 12, 1.6, 0.1, { 0, 0, 0 }, "SmoothPlastic", { yaw = 90, text = { s = "SERVICE", color = { 255, 255, 255 } } })
local px, pz = A.x0 + 5, A.z1 - 10
add("PylonSockel", "trim", px, Y + 0.5, pz, 3, 1, 3, CONC, "Concrete", { collide = true })
add("PylonMast", "trim", px, Y + 9, pz, 1.6, 17, 1.6, GREY, "Metal", { collide = true })
add("PylonSchild", "sign", px, Y + 16, pz, 0.8, 6, 10, BLUE, "SmoothPlastic")
add("PylonSchrift", "sign", px - 0.45, Y + 17.2, pz, 9, 1.8, 0.1, { 0, 0, 0 }, "SmoothPlastic", { yaw = 90, text = { s = "AUTOHAUS", color = { 255, 255, 255 } } })
add("PylonSchrift", "sign", px - 0.45, Y + 14.9, pz, 9, 1.6, 0.1, { 0, 0, 0 }, "SmoothPlastic", { yaw = 90, text = { s = "ISARTOR", color = { 255, 255, 255 } } })
local ppz = zS1 - 22
add("ParkplatzPfosten", "decor", A.x0 + 6, Y + 3.4, ppz, 0.4, 6.8, 0.4, GREY, "Metal", { collide = true })
add("ParkplatzSchild", "sign", A.x0 + 6, Y + 7.6, ppz, 0.3, 3.2, 3.2, BLUE, "SmoothPlastic")
add("ParkplatzSchrift", "sign", A.x0 + 5.8, Y + 7.6, ppz, 2.6, 2.6, 0.1, { 0, 0, 0 }, "SmoothPlastic", { yaw = 90, text = { s = "P", color = { 255, 255, 255 } } })
add("KundenSchild", "sign", A.x0 + 6, Y + 5.4, ppz, 0.3, 1.2, 5.6, BLUE, "SmoothPlastic")
add("KundenSchrift", "sign", A.x0 + 5.8, Y + 5.4, ppz, 5, 0.9, 0.1, { 0, 0, 0 }, "SmoothPlastic", { yaw = 90, text = { s = "KUNDEN", color = { 255, 255, 255 } } })
for _, z in ipairs({ zW1 + 6, zc, zS1 - 6 }) do
add("LampenMast", "lamp", A.x0 + 28, Y + 5, z, 0.5, 10, 0.5, { 40, 56, 48 }, "Metal", { collide = true })
add("LampenKopf", "lamp", A.x0 + 28, Y + 10.3, z, 2.6, 0.6, 1.2, { 255, 226, 150 }, "Neon", { tag = "StreetLamp", attrs = { Lit = true } })
stats.lamps = stats.lamps + 1
end
for _, q in ipairs({ { A.x0 + 4, A.z0 + 6 }, { A.x0 + 40, A.z0 + 4 }, { A.x0 + 4, A.z1 - 5 } }) do
add("AutohausStamm", "tree", q[1], Y + 4, q[2], 1.2, 8, 1.2, { 96, 70, 48 }, "Wood", { collide = true })
add("AutohausKrone", "tree", q[1], Y + 11, q[2], 9, 9, 9, { 88, 140, 70 }, "Grass", { shape = "Ball" })
stats.trees = stats.trees + 1
end
local V = A.vorfeld
if V then
local road
for _, r in ipairs(cfg.roads) do if r.name == V.road then road = r end end
local ra, rb = road.pts[2], road.pts[3]
local ex = 0
for _, st in ipairs(cfg.profiles[road.profile].strips) do ex = math.max(ex, math.abs(st[1]), math.abs(st[2])) end
local dl = math.sqrt((rb[1] - ra[1]) ^ 2 + (rb[2] - ra[2]) ^ 2)
local rux, ruz = (rb[1] - ra[1]) / dl, (rb[2] - ra[2]) / dl
local rnx, rnz = ruz, -rux -- weg von der Straße nach Norden
local function zEdge(x) return ra[2] + (ex - (x - ra[1]) * rnx) / rnz end -- Außenkante des Gehwegs
local X0 = A.x0 + 4
local function xMax(zSouth) -- letztes Stellplatzende (Vielfaches von 8 ab X0) mit V.margin Abstand zum Gehweg
local x = math.min(ra[1] + (ex - (zSouth + V.margin - ra[2]) * rnz) / rnx, A.x1 - 4)
return X0 + math.floor((x - X0) / 8) * 8
end
local rA, rB = V.rows[1], V.rows[2]
local xAisle, xB, xA = xMax(rB[1]), xMax(rB[2]), xMax(rA[2]) -- Fahrgasse, Reihe B, Reihe A
local function plate(x0, x1, z0, z1)
add("Vorfeld", "plaza", (x0 + x1) / 2, Y - 0.5, (z0 + z1) / 2, x1 - x0, 1, z1 - z0, ASPHALT, "Asphalt", { collide = true })
end
plate(A.x0, xAisle, A.z1, rB[1]) -- Reihe A und Fahrgasse
plate(A.x0, xB, rB[1], rB[2]) -- Reihe B
if xA > xAisle then plate(xAisle, xA, A.z1, rA[2]) end -- Reihe A läuft hinter der Fahrgasse weiter
for _, row in ipairs({ { rA, xA }, { rB, xB } }) do
for x = X0, row[2], 8 do add("Boxenlinie", "dash", x, Y + 0.1, (row[1][1] + row[1][2]) / 2, 0.3, 0.2, row[1][2] - row[1][1], LINE, "SmoothPlastic") end
stats.bays = stats.bays + (row[2] - X0) / 8
end
local function lawn(p, q, r)
for _, w in ipairs(Geo.wedges({ p[1], Y, p[2] }, { q[1], Y, q[2] }, { r[1], Y, r[2] }, 1, { 0, 1, 0 })) do
add("Rasen", "decor", w.pos[1], w.pos[2], w.pos[3], w.size[1], w.size[2], w.size[3], { 84, 132, 64 }, "Grass", { wedge = w.wedge })
end
end
local function quad(p1, p2, p3, p4) lawn(p1, p2, p3) lawn(p1, p3, p4) end
local function e(x) return { x, zEdge(x) - 1.4 } end
local xw, xe2 = A.x0 + 2, A.x1
quad({ xw, rB[2] }, { xB, rB[2] }, e(xB), e(xw))
quad({ xB, rB[1] }, { xAisle, rB[1] }, e(xAisle), e(xB))
quad({ xAisle, rA[2] }, { xA, rA[2] }, e(xA), e(xAisle))
quad({ xA, A.z1 }, { xe2, A.z1 }, e(xe2), e(xA))
for _, x in ipairs(V.trees) do
local z = zEdge(x) - 7
add("AutohausStamm", "tree", x, Y + 4, z, 1.2, 8, 1.2, { 96, 70, 48 }, "Wood", { collide = true })
add("AutohausKrone", "tree", x, Y + 11, z, 9, 9, 9, { 88, 140, 70 }, "Grass", { shape = "Ball" })
stats.trees = stats.trees + 1
end
for _, x in ipairs(V.lamps) do -- zwei Leuchten in der Fahrgasse
local z = (rA[2] + rB[1]) / 2
add("LampenMast", "lamp", x, Y + 5, z, 0.5, 10, 0.5, { 40, 56, 48 }, "Metal", { collide = true })
add("LampenKopf", "lamp", x, Y + 10.3, z, 2.6, 0.6, 1.2, { 255, 226, 150 }, "Neon", { tag = "StreetLamp", attrs = { Lit = true } })
stats.lamps = stats.lamps + 1
end
end
return { parts = parts, stats = stats }
end
return Autohaus

end)()
local Hochhaus = (function()
local Geo = Geo
local Hochhaus = {}
local FH, LOBBY, Y0 = 9, 14, 1 -- Geschosshöhe, Höhe des Erdgeschosses, Oberkante Gehweg
local SPANDREL, GLASS, GLASS_LIT, GLASS_TOP = { 196, 204, 214 }, { 62, 88, 116 }, { 255, 226, 150 }, { 34, 44, 60 }
local STEEL, BLUE, PLAZA = { 214, 218, 224 }, { 24, 68, 170 }, { 188, 184, 176 }
local function newRng(seed)
local s = seed
return function()
s = (s * 1103515245 + 12345) % 2147483648
return s / 2147483648
end
end
local function newPlan()
local parts = {}
local function add(name, kind, x, y, z, sx, sy, sz, color, mat, extra)
extra = extra or {}
parts[#parts + 1] = {
name = name, kind = kind, size = { Geo.round3(sx), Geo.round3(sy), Geo.round3(sz) },
pos = { Geo.round3(x), Geo.round3(y), Geo.round3(z) }, yaw = extra.yaw or 0, pitch = extra.pitch or 0, roll = extra.roll,
color = color, material = mat, collide = extra.collide == true, shape = extra.shape, tag = extra.tag, lit = extra.lit, text = extra.text,
transparency = extra.transparency,
}
end
local function vcyl(name, kind, x, y, z, h, d, color, mat, extra) -- stehender Zylinder, y = Mitte
extra = extra or {}
extra.shape, extra.roll = "Cylinder", 90
add(name, kind, x, y, z, h, d, d, color, mat, extra)
end
return parts, add, vcyl
end
local function glassExtra(rng, top)
return { tag = "HouseWindow", lit = not top and rng() < 0.3 }
end
local function glasTurm(t, add, vcyl, rng)
local W, D, r, N = t.w, t.d, t.r, t.floors
local H = LOBBY + N * FH
local x, z = t.x, t.z
local body = t.color or SPANDREL
local pm = t.pm or 9
add("Plaza", "plaza", x, Y0 - 0.3, z, W + 2 * pm, 1, D + 2 * pm, PLAZA, "Granite")
add("TurmKernA", "tower", x, Y0 + H / 2, z, W - 2 * r, H, D, body, "SmoothPlastic", { collide = true })
add("TurmKernB", "tower", x, Y0 + H / 2, z, W, H, D - 2 * r, body, "SmoothPlastic", { collide = true })
local cx, cz = W / 2 - r, D / 2 - r
for _, sx in ipairs({ -1, 1 }) do
for _, sz in ipairs({ -1, 1 }) do vcyl("TurmEcke", "tower", x + sx * cx, Y0 + H / 2, z + sz * cz, H, 2 * r, body, "SmoothPlastic", { collide = true }) end
end
local lh = LOBBY - 2
for _, sz in ipairs({ -1, 1 }) do
add("EGGlas", "glass", x, Y0 + 1 + lh / 2, z + sz * (D / 2 + 0.25), W - 2 * r, lh, 0.5, GLASS_TOP, "Glass", { tag = "HouseWindow", lit = true })
end
for _, sx in ipairs({ -1, 1 }) do
add("EGGlas", "glass", x + sx * (W / 2 + 0.25), Y0 + 1 + lh / 2, z, 0.5, lh, D - 2 * r, GLASS_TOP, "Glass", { tag = "HouseWindow", lit = true })
for _, sz in ipairs({ -1, 1 }) do vcyl("EGGlasEcke", "glass", x + sx * cx, Y0 + 1 + lh / 2, z + sz * cz, lh, 2 * r + 0.8, GLASS_TOP, "Glass") end
end
add("Vordach", "trim", x, Y0 + 11.5, z + D / 2 + 4, 16, 0.8, 8, { 70, 74, 82 }, "Metal")
for _, sx in ipairs({ -1, 1 }) do add("VordachStuetze", "trim", x + sx * 7.4, Y0 + 5.5, z + D / 2 + 7.4, 0.6, 11, 0.6, { 70, 74, 82 }, "Metal") end
add("Eingang", "door", x, Y0 + 4, z + D / 2 + 0.6, 8, 8, 0.4, { 30, 36, 46 }, "Glass", { tag = "HouseWindow", lit = true })
local sh = FH - 3.2
for k = 1, N do
local y = Y0 + LOBBY + (k - 0.5) * FH
local top = k > N - 2
local col = top and GLASS_TOP or GLASS
local ex = glassExtra(rng, top)
for _, sz in ipairs({ -1, 1 }) do
add("Glasband", "glass", x, y, z + sz * (D / 2 + 0.2), W - 2 * r, sh, 0.45, ex.lit and GLASS_LIT or col, "Glass", { tag = ex.tag, lit = ex.lit })
end
for _, sx in ipairs({ -1, 1 }) do
add("Glasband", "glass", x + sx * (W / 2 + 0.2), y, z, 0.45, sh, D - 2 * r, ex.lit and GLASS_LIT or col, "Glass", { tag = ex.tag, lit = ex.lit })
for _, sz in ipairs({ -1, 1 }) do vcyl("GlasbandEcke", "glass", x + sx * cx, y, z + sz * cz, sh, 2 * r + 0.8, ex.lit and GLASS_LIT or col, "Glass", { tag = ex.tag, lit = ex.lit }) end
end
end
local top = Y0 + H
add("Dachkranz", "trim", x, top + 0.6, z, W + 1.2, 1.2, D + 1.2, { 60, 66, 76 }, "Concrete")
add("Technik", "tower", x, top + 5, z, W * 0.5, 8, D * 0.45, { 150, 156, 164 }, "Concrete")
add("Mast", "tower", x + W * 0.18, top + 22, z, 0.8, 34, 0.8, { 190, 190, 194 }, "Metal")
add("Positionslicht", "tower", x + W * 0.18, top + 39.5, z, 1.6, 1.6, 1.6, { 255, 40, 40 }, "Neon", { shape = "Ball" })
if t.label then
add("Schriftzug", "sign", x, top - FH, z - D / 2 - 0.8, W * 0.7, 4.4, 0.2, { 0, 0, 0 }, "SmoothPlastic", { text = { s = t.label, color = { 235, 240, 248 } } })
add("Schriftzug", "sign", x, top - FH, z + D / 2 + 0.8, W * 0.7, 4.4, 0.2, { 0, 0, 0 }, "SmoothPlastic", { yaw = 180, text = { s = t.label, color = { 235, 240, 248 } } })
end
end
local function logo(add, vcyl, x, y, z, dz)
for _, s in ipairs({ -1, 1 }) do
local zz = z + s * dz
local function disc(name, d, col, off, mat)
add(name, "sign", x, y, zz + s * off, 1, d, d, col, mat or "SmoothPlastic", { shape = "Cylinder", yaw = 90 })
end
disc("LogoRing", 22, { 0, 150, 136 }, 0)
disc("LogoGrund", 17, { 244, 244, 238 }, 0.3)
add("LogoRaute", "sign", x, y, zz + s * 0.9, 9, 9, 0.4, { 18, 40, 92 }, "SmoothPlastic", { roll = 45 })
add("LogoSchrift", "sign", x, y, zz + s * 1.2, 14, 4.6, 0.2, { 0, 0, 0 }, "SmoothPlastic", { yaw = s == 1 and 180 or 0, text = { s = "BMO", color = { 255, 255, 255 } } })
end
end
local function bmoTurm(t, add, vcyl, rng)
local R, c, N = t.radius or 14, t.versatz or 12.5, t.floors
local H = LOBBY + N * FH
local x, z = t.x, t.z
add("Plaza", "plaza", x, Y0 - 0.3, z, 2 * (c + R) + 6, 1, 2 * (c + R) + 6, PLAZA, "Granite")
add("BMOKern", "tower", x, Y0 + (H + 10) / 2, z, 2 * c, H + 10, 2 * c, STEEL, "Metal", { collide = true })
local bandY = Y0 + LOBBY + 0.55 * N * FH
for _, sx in ipairs({ -1, 1 }) do
for _, sz in ipairs({ -1, 1 }) do
local px, pz = x + sx * c, z + sz * c
vcyl("BMOZylinder", "tower", px, Y0 + H / 2, pz, H, 2 * R, STEEL, "Metal", { collide = true })
vcyl("BMOEGGlas", "glass", px, Y0 + 1 + (LOBBY - 2) / 2, pz, LOBBY - 2, 2 * R + 0.8, GLASS_TOP, "Glass", { tag = "HouseWindow", lit = true })
for k = 1, N do
local y = Y0 + LOBBY + (k - 0.5) * FH
if math.abs(y - bandY) > 4.5 then
local lit = rng() < 0.28
vcyl("BMOFensterband", "glass", px, y, pz, FH - 4.2, 2 * R + 0.8, lit and GLASS_LIT or GLASS, "Glass", { tag = "HouseWindow", lit = lit })
end
end
vcyl("BMOBand", "trim", px, bandY, pz, 8, 2 * R + 3.4, BLUE, "SmoothPlastic")
vcyl("BMOKappe", "tower", px, Y0 + H + 4, pz, 8, 2 * R * 0.62, { 170, 176, 186 }, "Metal")
end
end
logo(add, vcyl, x, Y0 + H + 9, z, c + 0.2)
add("Positionslicht", "tower", x, Y0 + H + 17, z, 1.6, 1.6, 1.6, { 255, 40, 40 }, "Neon", { shape = "Ball" })
add("Vordach", "trim", x, Y0 + 11.5, z + c + R + 3, 18, 0.8, 8, { 70, 74, 82 }, "Metal")
add("Eingang", "door", x, Y0 + 4, z + c + R - 1.2, 8, 8, 0.4, { 30, 36, 46 }, "Glass", { tag = "HouseWindow", lit = true })
end
local function schuessel(t, add, vcyl)
local x, z, R = t.x, t.z, t.r or 26
add("Plaza", "plaza", x, Y0 - 0.3, z, 2 * R + 4, 1, 2 * R + 4, PLAZA, "Granite")
vcyl("WeltFoyer", "glass", x, Y0 + 4.5, z, 9, 2 * R, GLASS_TOP, "Glass", { tag = "HouseWindow", lit = true, collide = true })
local n, y = 12, Y0 + 9
for i = 1, n do
local f = i / n
local rad = R * (0.46 + 0.54 * math.sin(math.pi * f) ^ 0.7) -- Bauch in der Mitte
vcyl("WeltSchale", "tower", x, y + 1.6, z, 3.2, 2 * rad, { 186, 192, 202 }, "Metal", { collide = true })
y = y + 3.2
end
vcyl("WeltBand", "trim", x, Y0 + 9 + 0.5 * n * 3.2, z, 2.4, 2 * R + 1.2, BLUE, "SmoothPlastic")
vcyl("WeltDeckel", "tower", x, y + 0.4, z, 0.8, 2 * R * 0.5, { 120, 128, 140 }, "Metal")
add("WeltSchrift", "sign", x, Y0 + 4.5, z + R + 0.5, 24, 4, 0.2, { 0, 0, 0 }, "SmoothPlastic", { yaw = 180, text = { s = "BMO WELT", color = { 255, 255, 255 } } })
if t.bruecke then
local x0, x1 = t.bruecke.x, x - R + 2
add("Bruecke", "glass", (x0 + x1) / 2, Y0 + 22, t.bruecke.z, math.abs(x1 - x0), 4, 6, GLASS, "Glass", { tag = "HouseWindow", lit = false })
add("BrueckenDach", "trim", (x0 + x1) / 2, Y0 + 24.3, t.bruecke.z, math.abs(x1 - x0), 0.6, 7, { 150, 156, 164 }, "Metal")
end
end
function Hochhaus.plan(cfg)
local parts, add, vcyl = newPlan()
local rng = newRng(7)
local stats = { towers = 0, tallest = 0 }
for _, t in ipairs(cfg.hochhaeuser) do
local before = #parts
if t.art == "glas" then glasTurm(t, add, vcyl, rng)
elseif t.art == "bmo" then bmoTurm(t, add, vcyl, rng)
else schuessel(t, add, vcyl) end
for i = before + 1, #parts do parts[i].name = t.name .. "_" .. parts[i].name end
if t.art ~= "schuessel" then
stats.towers = stats.towers + 1
stats.tallest = math.max(stats.tallest, LOBBY + t.floors * FH)
end
end
return { parts = parts, stats = stats }
end
return Hochhaus

end)()
local Bushaltestellen = (function()
local Geo = Geo
local Bus = {}
local YAW = { N = 0, S = 180, W = 90, E = 270 } -- Blickrichtung (lokal -z) zur Straße
function Bus.plan(cfg)
local parts = {}
for i, s in ipairs(cfg.busstops) do
local yaw = YAW[s.zurStrasse]
local r = math.rad(yaw)
local c, sn = math.cos(r), math.sin(r)
local function add(name, kind, lx, y, lz, sx, sy, sz, color, mat, extra)
extra = extra or {}
parts[#parts + 1] = {
name = string.format("Bus%02d_%s", i, name), kind = kind, size = { sx, sy, sz },
pos = { Geo.round3(s.x + lx * c + lz * sn), y, Geo.round3(s.z - lx * sn + lz * c) }, yaw = (yaw + (extra.yaw or 0)) % 360, pitch = 0,
color = color, material = mat, collide = extra.collide == true, shape = extra.shape, roll = extra.roll, tag = extra.tag, text = extra.text,
attrs = { Haltestelle = s.name or ("Haltestelle " .. i) },
}
end
local FRAME, GLASS = { 52, 58, 66 }, { 150, 190, 210 }
add("Dach", "trim", 0, 9.4, 0, 9.4, 0.5, 4.2, FRAME, "Metal")
for _, sx in ipairs({ -4.4, 4.4 }) do add("Pfosten", "trim", sx, 5.2, -1.8, 0.4, 8.4, 0.4, FRAME, "Metal") end
for _, sx in ipairs({ -4.4, 4.4 }) do add("PfostenHinten", "trim", sx, 5.2, 1.8, 0.4, 8.4, 0.4, FRAME, "Metal") end
add("Rueckwand", "glass", 0, 5.6, 1.9, 8.8, 6.6, 0.2, GLASS, "Glass", { tag = nil })
add("Seitenwand", "glass", -4.5, 5.6, 0, 0.2, 6.6, 3.6, GLASS, "Glass")
add("Bank", "trim", 0, 2.6, 1.0, 5.6, 0.4, 1.4, { 140, 100, 64 }, "Wood")
add("Fahrplan", "sign", 3.2, 5.2, 1.7, 1.8, 2.6, 0.2, { 255, 214, 60 }, "SmoothPlastic")
add("SchildMast", "trim", 6.4, 5.5, -2.4, 0.4, 11, 0.4, { 120, 124, 130 }, "Metal")
add("SchildScheibe", "sign", 6.4, 10.4, -2.4, 0.3, 3.4, 3.4, { 0, 140, 70 }, "SmoothPlastic", { shape = "Cylinder", yaw = 90 })
add("SchildH", "sign", 6.4, 10.4, -2.62, 2.4, 2.4, 0.2, { 0, 0, 0 }, "SmoothPlastic", { text = { s = "H", color = { 255, 232, 60 } } })
end
return { parts = parts, stats = { stops = #cfg.busstops } }
end
return Bus

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
function TerrainPlanner.kanal(ops, cfg)
local K = cfg.water.kanal
K.name = "kanal"
river(ops, K)
for _, sm in ipairs(TerrainPlanner.riverSamples(K.pts)) do
if sm.z > K.bank.zmin then
local alongZ = math.abs(sm.uz) >= math.abs(sm.ux)
local sx, sz
if alongZ then sx, sz = K.bank.width / math.abs(sm.uz), STEP + 2 else sx, sz = STEP + 2, K.bank.width / math.abs(sm.ux) end
for _, side in ipairs({ -1, 1 }) do
local c = side * (K.bank.from + K.bank.width / 2)
block(ops, K.bank.material, sm.x - sm.uz * c, -4, sm.z + sm.ux * c, sx, 8, sz, "kanal_bank")
end
end
end
end
function TerrainPlanner.planKanal(cfg)
local ops = {}
TerrainPlanner.kanal(ops, cfg)
return ops
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
if t.round then -- Superellipsen-Insel aus 4 Studs breiten Streifen (so groß wie eine Terrain-Zelle)
local n = math.floor(2 * t.b / 4)
for i = 0, n - 1 do
local dz = -t.b + (i + 0.5) * 2 * t.b / n
block(ops, "Grass", t.cx, G + t.height / 2, t.cz + dz, 2 * t.a * (1 - math.abs(dz / t.b) ^ t.p) ^ (1 / t.p), t.height, 2 * t.b / n + 0.05)
end
else
block(ops, "Grass", (t.x0 + t.x1) / 2, G + t.height / 2, (t.z0 + t.z1) / 2, t.x1 - t.x0, t.height, t.z1 - t.z0)
end
local U = cfg.marienplatz and cfg.marienplatz.ubahn
if U then
block(ops, "Air", (U.x0 + U.x1) / 2, -3, (U.z0 + U.z1) / 2, U.x1 - U.x0, 18, U.z1 - U.z0, "ubahn")
block(ops, "Air", (U.x0 + U.x1) / 2, -5.5, U.z0 - U.gang / 2, 16, 11, U.gang + 1, "ubahn")
end
for _, U in ipairs(cfg.stachus and cfg.stachus.ubahn or {}) do
block(ops, "Air", (U.x0 + U.x1) / 2, -3, (U.z0 + U.z1) / 2, U.x1 - U.x0, 18, U.z1 - U.z0, "ubahn")
block(ops, "Air", U.x1 + U.gang / 2, -5.5, (U.z0 + U.z1) / 2, U.gang + 1, 11, 16, "ubahn")
end
cfg.water.isar.name, cfg.water.bach.name = "isar", "bach"
river(ops, cfg.water.isar)
river(ops, cfg.water.bach)
if cfg.water.kanal then TerrainPlanner.kanal(ops, cfg) end
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
if math.abs((x - t.cx) / t.a) ^ t.p + math.abs((z - t.cz) / t.b) ^ t.p <= 1 then return t.height end
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
if not underBridge(lx, lz) and Geo.polyDist(lx, lz, cfg.water.bach.pts) > 22 then -- nicht im Eisbach (die Isar-Böschung reicht bis zum Bach)
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
local hw = cfg.water.kanal.layers[1][3]
local zc = cfg.landmarks.eisbach.z
local function bachAt(z) -- Mittelpunkt und Laufrichtung des Bachs bei z
for i = 1, #pts - 1 do
local a, b = pts[i], pts[i + 1]
if z >= a[2] and z <= b[2] then
local ux, uz = Geo.dir(a[1], a[2], b[1], b[2])
return a[1] + (z - a[2]) / (b[2] - a[2]) * (b[1] - a[1]), ux, uz
end
end
end
local cx, ux, uz = bachAt(zc)
local cz = zc
local nx, nz = -uz, ux -- zeigt vom Bach nach Westen (Zuschauerseite)
local function at(a, l) return cx + ux * a + nx * l, cz + uz * a + nz * l end
local yawU, yawN = Geo.yawOf(ux, uz), Geo.yawOf(nx, nz)
local rngTree = newRng(31) -- eigene Zufallsfolge, damit die übrigen Grünanlagen unverändert bleiben
local WALL, CAP, CONC, WOOD, DARKW = { 150, 146, 134 }, { 190, 184, 170 }, { 170, 168, 160 }, { 132, 100, 68 }, { 86, 64, 46 }
local aEnd = 40 -- Ende der Mauern (vor der Luitpoldbrücke)
local wl0, wl1 = -(hw - 5.8), hw - 4.8 -- freie Wasserbreite zwischen Ost-Plateau und West-Steg
local wmid, ww = (wl0 + wl1) / 2, wl1 - wl0 - 0.4
local function slab(name, a0, y0, a1, y1, th, color, transp)
local da, dy = a1 - a0, y1 - y0
local phi = math.atan2(dy, da)
local x, z = at((a0 + a1) / 2 - math.sin(phi) * th / 2, wmid)
add(name, "wave", x, (y0 + y1) / 2 + math.cos(phi) * th / 2, z, math.sqrt(da * da + dy * dy), th, ww, color, "SmoothPlastic", { yaw = yawU, roll = math.deg(phi), transparency = transp })
end
local WATER, FOAM = { 62, 126, 162 }, { 246, 250, 252 }
local wx, wz = at(3, wmid)
add("Eisbachwelle", "wave", wx, -4, wz, 6.6, 4, ww, FOAM, "SmoothPlastic", { yaw = yawU, transparency = 1, tag = "Eisbachwelle", attrs = { Surf = true } })
local kx, kz = at(14, 0)
add("Kanalboden", "wave", kx, -5.9, kz, 66, 0.2, 2 * hw - 0.4, { 36, 84, 96 }, "SmoothPlastic", { yaw = yawU }) -- dunkles Bachbett unter dem Wasser (verdeckt das Muster des Terrain-Grunds)
local wx2, wz2 = at(21, 0)
add("Kanalwasser", "wave", wx2, -3.9, wz2, 44, 0.2, 2 * hw - 0.4, { 52, 112, 132 }, "SmoothPlastic", { yaw = yawU, transparency = 0.25 })
slab("Wellenhang", -3.5, -3.8, 1.5, -2.1, 0.4, WATER, 0.2)
slab("Wellenruecken", 1.5, -2.1, 3.3, -1.5, 0.4, WATER, 0.2)
slab("Wellenflanke", 3.3, -1.5, 6.8, -3.7, 0.4, WATER, 0.2)
slab("Wellenkrone", 1.6, -2.05, 3.6, -1.4, 0.75, FOAM, 0.12)
slab("Wellenkrone", 3.6, -1.4, 5.0, -2.3, 0.65, FOAM, 0.18)
for _, f in ipairs({ { 6.4, 9.6, -4.6, 5 }, { 6.8, 11, 3.2, 6 }, { 9.8, 13.4, -1.2, 7 }, { 12, 16, 4.6, 4 }, { 13.2, 18, -5, 5 }, { 16.6, 20.6, 0.4, 6 }, { 5.8, 8, 4.8, 3.5 }, { 8.4, 10.6, -6.4, 3 } }) do
local x, z = at((f[1] + f[2]) / 2, wmid + f[3])
add("Wellenschaum", "wave", x, -3.8, z, f[2] - f[1], 0.15, f[4], FOAM, "SmoothPlastic", { yaw = yawU, transparency = 0.35 })
end
for _, n in ipairs({ { 10.4, 1.0 }, { 17, 0.6 } }) do -- Nachläufer: flache Hügel aus zwei Platten
slab("Nachlauf", n[1] - 1.8, -3.85, n[1], -3.85 + n[2], 0.3, WATER, 0.3)
slab("Nachlauf", n[1], -3.85 + n[2], n[1] + 1.8, -3.85, 0.3, WATER, 0.3)
end
add("SurfZone", "zone", wx, -2.5, wz, 2 * hw, 6, 18, { 255, 255, 255 }, "SmoothPlastic", { yaw = yawN, transparency = 1, tag = "SurfZone", attrs = { Welle = "Eisbach" } })
local function wall(side, a0, a1)
local x, z = at((a0 + a1) / 2, side * (hw + 1.2))
add("Kanalmauer", "wall", x, -4.05, z, a1 - a0, 9.9, 2.4, WALL, "Cobblestone", { yaw = yawU, collide = true })
add("Mauerkappe", "wall", x, 1.2, z, a1 - a0, 0.4, 3.0, CAP, "Concrete", { yaw = yawU, collide = true })
end
wall(1, -7, -3) -- Anfang jeweils hinter der Brückenkante (der Kanal verläuft schräg zur Brücke, daher im Westen später als im Osten)
wall(1, 21, aEnd)
wall(-1, -17, -4)
wall(-1, 0, aEnd)
for i, top in ipairs({ -0.2, -1.5 }) do
local x, z = at(9, hw + 1.5 - (i - 1) * 1.8)
add("Kanalstufe", "steps", x, (top - 9) / 2, z, 22, top + 9, 1.8, CONC, "Concrete", { yaw = yawU, collide = true })
add("Sitzbohle", "decor", x, top + 0.1, z, 21, 0.2, 1.3, WOOD, "Wood", { yaw = yawU, collide = true })
end
local sx, sz = at(9, hw - 1.6)
add("Stegstufe", "steps", sx, (-2.5 - 9) / 2, sz, 22, -2.5 + 9, 1.0, WOOD, "Wood", { yaw = yawU, collide = true })
local wsx, wsz = at(9, hw - 3.4) -- West-Steg: Bohlen, Randbalken, Querbalken, Pfosten
add("StegWest", "deck", wsx, -3.6, wsz, 22, 0.4, 2.8, WOOD, "Wood", { yaw = yawU, collide = true })
local wbx, wbz = at(9, hw - 4.9)
add("StegWestBalken", "deck", wbx, -3.1, wbz, 22, 0.7, 0.7, DARKW, "Wood", { yaw = yawU, collide = true })
for a = -1, 19, 4 do
local qx, qz = at(a, hw - 3.4)
add("StegWestQuerbalken", "deck", qx, -3.35, qz, 0.6, 0.35, 3.2, DARKW, "Wood", { yaw = yawU })
end
for _, a in ipairs({ -1, 19 }) do
for _, l in ipairs({ hw - 1.4, hw - 4.9 }) do
local qx, qz = at(a, l)
add("StegWestPfosten", "deck", qx, -6, qz, 0.6, 4.4, 0.6, DARKW, "Wood", { yaw = yawU })
end
end
local px, pz = at(9, -(hw - 2.9))
add("Plateau", "deck", px, -3.6, pz, 22, 0.4, 5.8, WOOD, "Wood", { yaw = yawU, collide = true })
local bx, bz = at(9, -(hw - 6))
add("Plateaubalken", "deck", bx, -3.1, bz, 22, 0.7, 0.7, DARKW, "Wood", { yaw = yawU, collide = true })
for a = -1, 19, 4 do
local qx, qz = at(a, -(hw - 2.9))
add("Plateauquerbalken", "deck", qx, -3.35, qz, 0.6, 0.35, 6.2, DARKW, "Wood", { yaw = yawU })
end
for _, a in ipairs({ -1, 19 }) do
for _, l in ipairs({ -(hw - 0.4), -(hw - 5.8) }) do
local qx, qz = at(a, l)
add("Plateaupfosten", "deck", qx, -6, qz, 0.6, 4.4, 0.6, DARKW, "Wood", { yaw = yawU })
end
end
for _, a in ipairs({ 1, 17 }) do
local qx, qz = at(a, -(hw - 5.2))
add("Stegpoller", "deck", qx, -2.6, qz, 0.6, 1.6, 0.6, { 60, 62, 66 }, "Metal", { yaw = yawU, collide = true })
end
for i, top in ipairs({ -0.5, -1.6, -2.7 }) do -- Holztreppe in der Mauerlücke (a -4 bis 0)
local x, z = at(-2, -(hw + 1.6 - (i - 1) * 1.0))
add("Holzstufe", "steps", x, (top - 9) / 2, z, 4, top + 9, 1.0, WOOD, "Wood", { yaw = yawU, collide = true })
end
local function rettungsring(a, l, yc)
local R = 1.6
local x0, z0 = at(a, l)
add("RettungsringPfosten", "decor", x0, yc - 2.4, z0, 0.4, 4.8, 0.4, { 70, 62, 56 }, "Metal", { collide = true })
local tx, tz = at(a, l + 0.2)
add("RettungsringTafel", "decor", tx, yc, tz, 4.4, 4.4, 0.2, { 238, 200, 56 }, "SmoothPlastic", { yaw = yawU })
for k = 0, 15 do
local th = k * math.pi / 8
local x, z = at(a + R * math.cos(th), l + 0.6)
add("RettungsringSegment", "decor", x, yc + R * math.sin(th), z, 0.72, 0.6, 0.6, (math.floor(k / 2) % 2 == 0) and { 214, 40, 36 } or { 248, 248, 248 }, "SmoothPlastic", { yaw = yawU, roll = math.deg(th) + 90 })
end
end
rettungsring(26, hw + 2.8, 3.8) -- an der Westmauer
rettungsring(19.5, -(hw - 1.4), -0.8) -- am Ende des Ost-Stegs
for _, q in ipairs({ { 6, -25 }, { 18, -29 }, { 30, -26 }, { 40, -29 } }) do
local x, z = at(q[1], q[2])
tree(add, rngTree, x, 0, z, 1.15, "Eis")
end
for _, a in ipairs({ 4, 13, 22 }) do -- Bänke am Ostufer, Blick zum Wasser
local x, z = at(a, -(hw + 4.6))
bench(add, x, 0.5, z, math.deg(math.atan2(nx, nz)) + 180)
end
local dx, dz = at(20, 21)
add("Zuschauerdeck", "deck", dx, 0.25, dz, 26, 0.5, 10, { 140, 104, 70 }, "Wood", { yaw = yawU, collide = true })
local rx, rz = at(20, 16.2)
add("DeckGelaender", "deck", rx, 1.2, rz, 26, 1.2, 0.3, { 70, 62, 56 }, "Metal", { yaw = yawU, collide = true })
for _, a in ipairs({ -8, 0, 8 }) do
local x, z = at(20 + a, 24.2)
bench(add, x, 0.5, z, math.deg(math.atan2(nx, nz)))
end
local gx, gz = at(36, 16.5)
local signYaw = yawU + 180
add("Schild", "decor", gx, 3.4, gz, 9, 2.4, 0.3, { 36, 70, 110 }, "SmoothPlastic", { yaw = signYaw })
add("SchildPfosten", "decor", gx, 1.6, gz, 0.5, 3.2, 0.5, { 70, 62, 56 }, "Metal", { yaw = signYaw, collide = true })
local tx2, tz2 = gx + nx * 0.25, gz + nz * 0.25
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
local function eckBaeume(cfg, add, rng)
local n = 0
for _, sd in ipairs({ -1, 1 }) do
for _, q in ipairs({ { 108, -80 }, { 116, -62 }, { 96, -86 } }) do
tree(add, rng, sd * q[1], 0, q[2], 1.0, "Eck")
n = n + 1
end
end
return n
end
local function westPark(cfg, add, rng, free)
local n = 0
for x = 652, 730, 26 do
for z = -190, -110, 26 do
local tx, tz = x + (rng() - 0.5) * 12, z + (rng() - 0.5) * 12
if free(tx, tz) and tx < 738 then tree(add, rng, tx, 0, tz, 1.1, "West") n = n + 1 end
end
end
for x = 706, 736, 20 do
for z = -282, -214, 24 do
local tx, tz = x + (rng() - 0.5) * 8, z + (rng() - 0.5) * 8
if free(tx, tz) then tree(add, rng, tx, 0, tz, 1.0, "West") n = n + 1 end
end
end
return n
end
function Garden.planEisbach(cfg)
local parts = {}
eisbach(cfg, emitter(parts))
return parts
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
stats.eckTrees = eckBaeume(cfg, add, rng)
stats.westTrees = westPark(cfg, add, rng, free)
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
local Builder = (function()
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")
local Builder = {}
local MATERIALS = {
SmoothPlastic = Enum.Material.SmoothPlastic, Concrete = Enum.Material.Concrete, Brick = Enum.Material.Brick,
Glass = Enum.Material.Glass, Wood = Enum.Material.Wood, Metal = Enum.Material.Metal, Asphalt = Enum.Material.Asphalt,
Pavement = Enum.Material.Pavement, Grass = Enum.Material.Grass, Water = Enum.Material.Water, Neon = Enum.Material.Neon, Sand = Enum.Material.Sand, Rock = Enum.Material.Rock,
Marble = Enum.Material.Marble, Fabric = Enum.Material.Fabric, Ground = Enum.Material.Ground, Air = Enum.Material.Air,
Snow = Enum.Material.Snow, Granite = Enum.Material.Granite, Slate = Enum.Material.Slate, Cobblestone = Enum.Material.Cobblestone,
}
local function buildPart(spec, origin)
local p = Instance.new("Part")
p.Name = spec.name
p.Anchored = true
p.Size = Vector3.new(spec.size[1], spec.size[2], spec.size[3])
if spec.wedge then -- Dreieck aus Keilen (Geo.wedges): y-Achse = erster Schenkel, z-Achse = zweiter Schenkel (rechter Winkel bei -y/+z), x-Achse = Normale
local ey, ez = Vector3.new(spec.wedge[1][1], spec.wedge[1][2], spec.wedge[1][3]), Vector3.new(spec.wedge[2][1], spec.wedge[2][2], spec.wedge[2][3])
p.CFrame = CFrame.fromMatrix(origin + Vector3.new(spec.pos[1], spec.pos[2], spec.pos[3]), ey:Cross(ez), ey, ez)
p.Shape = Enum.PartType.Wedge
else
p.CFrame = CFrame.new(origin + Vector3.new(spec.pos[1], spec.pos[2], spec.pos[3]))
* CFrame.Angles(0, math.rad(spec.yaw), 0) * CFrame.Angles(math.rad(spec.pitch or 0), 0, math.rad(spec.roll or 0))
end
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
if spec.emitter then -- Düse: unsichtbares, geneigtes Teil mit Partikelstrahl nach oben (Top = Sprührichtung), z. B. Springbrunnen-Sprenkler
local e = spec.emitter
p.Transparency = 1
p.CastShadow = false
local pe = Instance.new("ParticleEmitter")
pe.Texture = "rbxasset://textures/particles/smoke_main.dds"
pe.Rate = e.rate
pe.Lifetime = NumberRange.new(e.life, e.life * 1.3)
pe.Speed = NumberRange.new(e.speed * 0.9, e.speed * 1.1)
pe.SpreadAngle = Vector2.new(e.spread, e.spread)
pe.Acceleration = Vector3.new(0, -e.gravity, 0)
pe.EmissionDirection = Enum.NormalId.Top
pe.Size = NumberSequence.new(e.size, e.size * 1.6)
pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 1) })
pe.Color = ColorSequence.new(Color3.fromRGB(e.color[1], e.color[2], e.color[3]))
pe.LightEmission = 0.4
pe.Parent = p
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
local PAVED = { road = true, walk = true, plaza = true, path = true, corner = true, bike = true }
function Builder.paveUnder(specs, origin, nearGrass)
local terrain = Workspace.Terrain
local rows = {}
for _, s in ipairs(specs) do
if PAVED[s.kind] and s.size[2] <= 3 and s.pos[2] > -6 and nearGrass(s) then
local r = math.rad(s.yaw or 0)
local ux, uz = math.cos(r), -math.sin(r) -- lokale x-Achse in der Draufsicht (lokale z-Achse: (sin, cos))
local hx, hz = s.size[1] / 2 + 1, s.size[3] / 2 + 1
if s.wedge then -- Dreieck: Rechteck aus den beiden Schenkeln
ux, uz = s.wedge[1][1], s.wedge[1][3]
hx, hz = s.size[2] / 2 + 1, s.size[3] / 2 + 1
end
local cx, cz = origin.X + s.pos[1], origin.Z + s.pos[3]
local rad = hx + hz
local y0 = math.floor((origin.Y + s.pos[2] - 6) / 4) * 4
for gx = math.floor((cx - rad) / 4), math.floor((cx + rad) / 4) do
for gz = math.floor((cz - rad) / 4), math.floor((cz + rad) / 4) do
local dx, dz = gx * 4 + 2 - cx, gz * 4 + 2 - cz
if math.abs(dx * ux + dz * uz) <= hx and math.abs(-dx * uz + dz * ux) <= hz then
local key = y0 .. ":" .. gz
rows[key] = rows[key] or { y0 = y0, gz = gz, cells = {} }
rows[key].cells[gx] = true
end
end
end
end
end
local n = 0
for _, row in pairs(rows) do
local xs = {}
for gx in pairs(row.cells) do xs[#xs + 1] = gx end
table.sort(xs)
local i = 1
while i <= #xs do -- zusammenhängende Zellen einer Reihe in einem Aufruf
local j = i
while xs[j + 1] == xs[j] + 1 do j = j + 1 end
local region = Region3.new(Vector3.new(xs[i] * 4, row.y0, row.gz * 4), Vector3.new((xs[j] + 1) * 4, row.y0 + 12, (row.gz + 1) * 4))
terrain:ReplaceMaterial(region, 4, Enum.Material.Grass, Enum.Material.Pavement)
n = n + 1
breathe(80)
i = j + 1
end
end
return n
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
function Builder.installScript(name, source)
local sss = game:GetService("ServerScriptService")
local old = sss:FindFirstChild(name)
if old then old:Destroy() end
local script = Instance.new("Script")
script.Name = name
script.Source = source
script.Parent = sss
end
function Builder.installController(source)
Builder.installScript("AmpelSteuerung", source)
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
local Rathaus = Rathaus
local Marienplatz = Marienplatz
local Hochhaus = Hochhaus
local Bushaltestellen = Bushaltestellen
local Stachus = Stachus
local Autohaus = Autohaus
local Werkstatt = Werkstatt
local Anlagen = Anlagen
local Tram = Tram
local Garden = Garden
local TerrainPlanner = TerrainPlanner
local WallPlanner = WallPlanner
local Builder = Builder
local Geo = Geo
local BuildAll = {}
local function nearGrass(x, z, r)
for _, p in ipairs(Config.parks) do
if x + r > p.x0 - 8 and x - r < p.x1 + 8 and z + r > p.z0 - 8 and z - r < p.z1 + 8 then return true end
end
local t = Config.terrace
if x + r > t.x0 - 8 and x - r < t.x1 + 8 and z + r > t.z0 - 8 and z - r < t.z1 + 8 then return true end
for _, h in ipairs(Config.hills) do
if math.sqrt((x - h.x) ^ 2 + (z - h.z) ^ 2) < h.layers[1][1] + r + 8 then return true end
end
return Geo.polyDist(x, z, Config.water.isar.pts) < Config.water.isar.layers[1][3] + 10 + r
end
local STEPS = {
terrain = function(opts, origin)
if opts.clearTerrain ~= false then Builder.clearTerrain() end
local ops = TerrainPlanner.plan(Config)
Builder.applyTerrain(ops, origin)
return string.format("%d Terrain-Operationen", #ops)
end,
kanal = function(opts, origin) -- nur der Eisbach-Kanal (Terrain), wenn das übrige Terrain schon steht; bei "terrain" ist er schon dabei
local ops = TerrainPlanner.planKanal(Config)
Builder.applyTerrain(ops, origin)
return string.format("%d Terrain-Operationen (Eisbach-Kanal)", #ops)
end,
eisbach = function(opts, origin) -- Eisbach-Szene in der fertigen Karte gezielt erneuern (Kanal-Terrain, Brückenbögen, Welle, Mauern), übrige Ordner bleiben unberührt
local map = game:GetService("Workspace"):FindFirstChild("Map")
local roads, gardens = map.Strassen, map.Gruenanlagen
Builder.applyTerrain(TerrainPlanner.planKanal(Config), origin)
local OLD = {} -- Namen der früheren und der neuen Eisbach-Teile im Umkreis der Welle
for _, n in ipairs({ "Eisbachwelle", "Schussrinne", "Kanalwasser", "Kanalboden", "Wellenschaum", "Wellental", "Gischt", "Wellenkamm", "Wellenzug", "SurfZone", "Ufermauer", "Kanalmauer", "Mauerkappe", "Kanalstufe", "Plateau", "Plateaubalken",
"Plateauquerbalken", "Plateaupfosten", "Holzstufe", "RettungsringPfosten", "Rettungsring", "EisStamm", "EisKrone", "Zuschauerdeck", "DeckGelaender", "Schild", "SchildPfosten", "Schrift",
"BankSitz", "BankLehne", "BankBein", "Uferweg", "Wellenhang", "Wellenruecken", "Wellenflanke", "Wellenkrone", "Nachlauf", "Sitzbohle", "Stegstufe", "StegWest", "StegWestBalken", "StegWestQuerbalken",
"StegWestPfosten", "Stegpoller", "RettungsringSegment", "RettungsringTafel", "Kanalboden", "Kanalwasser" }) do OLD[n] = true end
local removed = 0
for _, c in ipairs(gardens:GetChildren()) do
if c:IsA("BasePart") and OLD[c.Name] and c.Position.X > 600 and c.Position.X < 700 and c.Position.Z > 315 and c.Position.Z < 400 then c:Destroy() removed = removed + 1 end
end
for _, c in ipairs(roads:GetChildren()) do
if c.Name:sub(1, 7) == "Eisbach" then c:Destroy() removed = removed + 1 end
end
local bridge = {}
for _, p in ipairs(RoadsPlanner.plan(Config).parts) do
if p.name:sub(1, 7) == "Eisbach" then bridge[#bridge + 1] = p end
end
Builder.buildParts(bridge, roads, origin)
local scene = Garden.planEisbach(Config)
Builder.buildParts(scene, gardens, origin)
return string.format("%d alte Teile entfernt, %d Brückenteile und %d Teile der Szene neu", removed, #bridge, #scene)
end,
fugen = function(opts, origin) -- Plattenfugen und Bänder (Stachus, Marienplatz) in der fertigen Karte erneuern, übrige Teile bleiben
local map = game:GetService("Workspace"):FindFirstChild("Map")
local n = 0
local function redo(folder, parts)
for _, c in ipairs(folder:GetChildren()) do
if c.Name == "Fuge" or c.Name == "Band" then c:Destroy() end
end
local list = {}
for _, p in ipairs(parts) do
if p.name == "Fuge" or p.name == "Band" then list[#list + 1] = p end
end
Builder.buildParts(list, folder, origin)
n = n + #list
end
redo(map.Stachus, Stachus.plan(Config).parts)
redo(map.Marienplatz, Marienplatz.plan(Config).parts)
return string.format("%d Fugen und Bänder erneuert", n)
end,
zylinder = function(opts, origin) -- flache Scheiben (Pflasterringe, Baumscheiben) und Brunnen-Düsen in der fertigen Karte erneuern, übrige Teile bleiben
local map = game:GetService("Workspace"):FindFirstChild("Map")
local n = 0
local function redo(folder, parts, names)
for _, c in ipairs(folder:GetChildren()) do
if names[c.Name] then c:Destroy() end
end
local list = {}
for _, p in ipairs(parts) do
if names[p.name] then list[#list + 1] = p end
end
Builder.buildParts(list, folder, origin)
n = n + #list
end
redo(map.Stachus, Stachus.plan(Config).parts, { Wasserstrahl = true, Duese = true, Pflasterring = true, Baumscheibe = true })
redo(map.Marienplatz, Marienplatz.plan(Config).parts, { SaeulenKreis = true, Baumscheibe = true })
return string.format("%d Teile erneuert", n)
end,
stachuslaternen = function(opts, origin) -- nur die Kugelleuchten am Stachus in der fertigen Karte neu setzen
local folder = game:GetService("Workspace"):FindFirstChild("Map").Stachus
for _, c in ipairs(folder:GetChildren()) do
if c.Name == "KugelleuchteMast" or c.Name == "Kugelleuchte" then c:Destroy() end
end
local list = {}
for _, p in ipairs(Stachus.plan(Config).parts) do
if p.name == "KugelleuchteMast" or p.name == "Kugelleuchte" then list[#list + 1] = p end
end
Builder.buildParts(list, folder, origin)
return string.format("%d Teile der Kugelleuchten erneuert", #list)
end,
pave = function(opts, origin) -- Terrain unter Wegen und Straßen von Gras zu Pflaster, damit dort keine Gras-Büschel wachsen
local roadPlan = RoadsPlanner.plan(Config)
local specs = {}
for _, list in ipairs({ roadPlan.parts, Garden.plan(Config, roadPlan, Specials).parts }) do
for _, p in ipairs(list) do specs[#specs + 1] = p end
end
local n = Builder.paveUnder(specs, origin, function(p) return nearGrass(p.pos[1], p.pos[3], math.max(p.size[1], p.size[3]) / 2) end)
return string.format("%d Zellenreihen unter Wegen und Straßen von Gras zu Pflaster", n)
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
marienplatz = function(opts, origin)
local folder = Builder.container("Marienplatz")
local rh, mp = Rathaus.plan(Config), Marienplatz.plan(Config)
Builder.buildParts(rh, folder, origin)
Builder.buildParts(mp.parts, folder, origin)
return string.format("%d Teile (Rathaus %d, Platz %d), %d Kugelleuchten, %d Platanen, U-Bahn-Abgang mit %d Stufen", #rh + #mp.parts, #rh, #mp.parts, mp.stats.lamps, mp.stats.trees, mp.stats.steps)
end,
skyline = function(opts, origin)
local plan = Hochhaus.plan(Config)
Builder.buildParts(plan.parts, Builder.container("Hochhaeuser"), origin)
return string.format("%d Teile, %d Hochhäuser (höchstes %d Studs)", #plan.parts, plan.stats.towers, plan.stats.tallest)
end,
bus = function(opts, origin)
local plan = Bushaltestellen.plan(Config)
Builder.buildParts(plan.parts, Builder.container("Bushaltestellen"), origin)
return string.format("%d Haltestellen, %d Teile", plan.stats.stops, #plan.parts)
end,
einfahrten = function(opts, origin) -- Einfahrten (Kerben im Gehweg) in der fertigen Karte erneuern, übrige Straßenteile bleiben
local folder = game:GetService("Workspace"):FindFirstChild("Map").Strassen
local removed = 0
for _, c in ipairs(folder:GetChildren()) do
if c.Name == "Einfahrt" or c.Name == "EinfahrtRampe" then c:Destroy() removed = removed + 1 end
end
local list = {}
for _, p in ipairs(RoadsPlanner.plan(Config).parts) do
if p.name == "Einfahrt" or p.name == "EinfahrtRampe" then list[#list + 1] = p end
end
Builder.buildParts(list, folder, origin)
return string.format("%d alte Teile entfernt, %d neu", removed, #list)
end,
kreiselwege = function(opts, origin) -- alle Gehwege, Eckrundungen und der Siegestor-Kreisel neu; Fahrbahnen und übrige Straßenteile bleiben
local folder = game:GetService("Workspace"):FindFirstChild("Map").Strassen
local CORNER = { GehwegEcke = true, GehwegEckeRund = true, EckAsphalt = true }
local function mine(name, x, z)
return name:match("^%w+_%d+_walk$") or name:match("^SiegestorKreisel_") or name == "GehwegKurve" or name == "KreiselEckAsphalt" or CORNER[name]
end
local removed = 0
for _, c in ipairs(folder:GetChildren()) do
if c:IsA("BasePart") and mine(c.Name, c.Position.X - origin.X, c.Position.Z - origin.Z) then c:Destroy() removed = removed + 1 end
end
local list = {}
for _, p in ipairs(RoadsPlanner.plan(Config).parts) do
if mine(p.name, p.pos[1], p.pos[3]) then list[#list + 1] = p end
end
Builder.buildParts(list, folder, origin)
return string.format("%d alte Gehwegteile entfernt, %d neu", removed, #list)
end,
tankshop = function(opts, origin) -- nur die Eingangstür des Allguth-Shops (Schiebetür, Glastür, Matte) erneuern
local model = game:GetService("Workspace"):FindFirstChild("Map").Gebaeude.Sonderbauten["Sonder_Tankstellen-Shop"]
local NAMES = { ShopTuer = true, ShopTuerrahmen = true, Schiebetuer = true, Schiebetuerrahmen = true, Schiebetuerantrieb = true, Tuersensor = true,
Glastuer = true, GlastuerRahmen = true, GlastuerGriff = true, Tuermatte = true }
local removed = 0
for _, c in ipairs(model:GetChildren()) do
if NAMES[c.Name] then c:Destroy() removed = removed + 1 end
end
local spec
for _, sp in ipairs(Specials) do if sp.name == "Tankstellen-Shop" then spec = sp end end
local list = {}
for _, p in ipairs(Planner.planSpecial(spec, { seed = opts.seed or 1 }).houses[1].parts) do
if NAMES[p.name] then list[#list + 1] = p end
end
Builder.buildParts(list, model, origin)
return string.format("%d alte Türteile entfernt, %d neu", removed, #list)
end,
kaffeehaus = function(opts, origin) -- Café neu (Terrasse zur Leopoldstraße, Parkplatz im Süden)
local folder = game:GetService("Workspace"):FindFirstChild("Map").Gebaeude.Sonderbauten
local old = folder:FindFirstChild("Sonder_Kaffeehaus")
if old then old:Destroy() end
for _, sp in ipairs(Specials) do
if sp.name == "Kaffeehaus" then Builder.build(Planner.planSpecial(sp, { seed = opts.seed or 1 }), folder, origin) end
end
return "Kaffeehaus neu gebaut"
end,
autohaus = function(opts, origin)
local plan = Autohaus.plan(Config)
Builder.buildParts(plan.parts, Builder.container("Autohaus"), origin)
return string.format("%d Teile (%d Boxenlinien, %d Leuchten, %d Bäume), keine Fahrzeuge", #plan.parts, plan.stats.bays, plan.stats.lamps, plan.stats.trees)
end,
anlagen = function(opts, origin) -- Allee, Klinikpark, Ufer-Parks: Rasen (Terrain), Wege, Bäume usw.; ersetzt nur den Ordner Anlagen
local ops = Anlagen.terrain(Config)
Builder.applyTerrain(ops, origin)
local plan = Anlagen.plan(Config)
Builder.buildParts(plan.parts, Builder.container("Anlagen"), origin)
Builder.paveUnder(plan.parts, origin, function() return true end) -- keine Gras-Büschel durch die Kieswege
local st = plan.stats
return string.format("%d Anlagen, %d Teile, %d Rasen-Blöcke, %d Bäume, %d Bänke, %d Leuchten, %d Büsche, %d Findlinge", st.areas, #plan.parts, #ops, st.trees, st.benches, st.lamps, st.bushes, st.rocks)
end,
tram = function(opts, origin) -- Gleise, Haltestellen und die blaue Bahn; mit opts.tramSource legt der Schritt auch das Fahr-Script TramSteuerung an
local plan = Tram.plan(Config)
local folder = Builder.container("Tram")
Builder.build(plan, folder, origin)
Builder.buildParts(plan.parts, folder, origin)
local script = ""
if opts.tramSource then
Builder.installScript("TramSteuerung", opts.tramSource)
script = ", Script TramSteuerung angelegt"
end
local st = plan.stats
return string.format("%d Teile (Strecke %.0f Studs, %d Halte), Wagen %d Teile, %d Sitze%s", #plan.parts, st.len, st.stops, #plan.houses[1].parts + #plan.houses[2].parts, st.seats, script)
end,
werkstatt = function(opts, origin)
local plan = Werkstatt.plan(Config)
Builder.buildParts(plan.parts, Builder.container("Werkstatt"), origin)
return string.format("%d Teile (%d Tore, %d Schriften, %d Leuchten)", #plan.parts, plan.stats.gates, plan.stats.texts, plan.stats.lamps)
end,
stachus = function(opts, origin)
local plan = Stachus.plan(Config)
Builder.buildParts(plan.parts, Builder.container("Stachus"), origin)
local st = plan.stats
return string.format("%d Teile (%d Abschnitte, %d Läden, %d Wasserstrahlen, %d Zinnen, %d Taxis)", #plan.parts, st.segs, st.shops, st.jets, st.merlons, st.taxis)
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
local plan = Planner.planBlock(block, { seed = opts.seed or 1, raise = Config.eckhaeuser })
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
if next(only) == nil or only.IsarWestufer then
local plan = Planner.planWestbank(Config, { seed = opts.seed or 1 })
local folder = Builder.container("Gebaeude", "IsarWestufer")
Builder.build(plan, folder, origin)
Builder.buildParts(plan.parts, folder, origin)
local st = Planner.stats(plan)
houses, parts = houses + st.houses, parts + st.parts + #plan.parts
end
if next(only) == nil or only.SiegestorEcken then
local plan = Planner.planCorners(Config, { seed = opts.seed or 1 })
Builder.build(plan, Builder.container("Gebaeude", "SiegestorEcken"), origin)
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
BuildAll.order = { "terrain", "roads", "lights", "landmarks", "marienplatz", "stachus", "autohaus", "werkstatt", "anlagen", "gardens", "pave", "houses", "skyline", "bus", "tram", "wall" }
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
BuildAll.run({ steps = STEPS, only = ONLY, origin = ORIGIN, afterBuild = Ampel.start })
