-- MapBuilder_Teil1.lua  (automatisch erzeugt mit make_bundles.py, nicht von Hand ändern)
-- ModuleScript mit dem Namen "Teil1" als Kind des Scripts MapBuilder (bzw. des Plugin-Scripts) anlegen und diesen Text einfügen.
return function(M)
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
M.Geo = Geo
M.Config = Config
M.Planner = Planner
M.Blocks = Blocks
M.Specials = Specials
M.Werkstatt = Werkstatt
M.Anlagen = Anlagen
M.Tram = Tram
end
