-- MapBuilder_Teil2.lua  (automatisch erzeugt mit make_bundles.py, nicht von Hand ändern)
-- ModuleScript mit dem Namen "Teil2" als Kind des Scripts MapBuilder (bzw. des Plugin-Scripts) anlegen und diesen Text einfügen.
return function(M)
local Geo = M.Geo
local Config = M.Config
local Planner = M.Planner
local Blocks = M.Blocks
local Specials = M.Specials
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
if o.id ~= self.id and not (o.road == self.road and o.ux * self.ux + o.uz * self.uz > 0.95) then
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
local function walkSide(seg, dirx, dirz) -- Gehwegstreifen von seg auf der Seite der Richtung (dirx, dirz): Abstände (innen, außen) zur Mittellinie
local sideSign = ((-seg.uz) * dirx + seg.ux * dirz) > 0 and 1 or -1
for _, st in ipairs(seg.prof.strips) do
if st[3] == "walk" and st[1] * sideSign > 0 and st[2] * sideSign > 0 then return math.min(math.abs(st[1]), math.abs(st[2])), math.max(math.abs(st[1]), math.abs(st[2])) end
end
end
local function inRect(r, x, z)
local dx, dz = x - r.ax, z - r.az
local u, v = dx * r.ux + dz * r.uz, dx * r.nx + dz * r.nz
return u > r.s0 and u < r.s1 and math.abs(v) < r.w
end
stats.corners = 0
for i = 1, #segs do
for j = i + 1, #segs do
local A, B = segs[i], segs[j]
if A.road ~= B.road and math.abs(A.ux * B.ux + A.uz * B.uz) < 0.05 then
local dx, dz = B.ax - A.ax, B.az - A.az
local ta, tb = dx * A.ux + dz * A.uz, -(dx * B.ux + dz * B.uz) -- Schnittpunkt der Mittellinien (Straßen stehen senkrecht)
if ta > -0.5 and ta < A.len + 0.5 and tb > -0.5 and tb < B.len + 0.5 then
local px, pz = A.ax + A.ux * ta, A.az + A.uz * ta
for _, sa in ipairs({ -1, 1 }) do
for _, sb in ipairs({ -1, 1 }) do
local ea = { sa * A.ux, sa * A.uz }
local eb = { sb * B.ux, sb * B.uz }
local da0, da1 = walkSide(A, eb[1], eb[2]) -- Gehweg von A auf der Seite von B
local db0, db1 = walkSide(B, ea[1], ea[2])
if da0 and db0 then
local extA = (sa > 0) and (A.len - ta) or ta
local extB = (sb > 0) and (B.len - tb) or tb
local qx = px + ea[1] * (db0 + db1) / 2 + eb[1] * (da0 + da1) / 2
local qz = pz + ea[2] * (db0 + db1) / 2 + eb[2] * (da0 + da1) / 2
local free = extA >= db1 - 0.5 and extB >= da1 - 0.5
for _, C in ipairs(segs) do
if free and C.road ~= A.road and C.road ~= B.road and inRect(C.rect, qx, qz) then free = false end
end
if free then
local R = math.min(5, (db1 - db0) / 2, (da1 - da0) / 2)
local function at(u, v) return px + ea[1] * u + eb[1] * v, pz + ea[2] * u + eb[2] * v end
local yaw = Geo.yawOf(A.ux, A.uz)
local x1, z1 = at((db0 + R + db1) / 2, (da0 + da1) / 2)
part(parts, "GehwegEcke", "corner", x1, 0, z1, db1 - db0 - R, 2, da1 - da0, yaw, COLOR.walk, MATERIAL.walk, { seg = A.id })
local x2, z2 = at(db0 + R / 2, (da0 + R + da1) / 2)
part(parts, "GehwegEcke", "corner", x2, 0, z2, R, 2, da1 - da0 - R, yaw, COLOR.walk, MATERIAL.walk, { seg = A.id })
local x3, z3 = at(db0 + R, da0 + R)
part(parts, "GehwegEckeRund", "corner", x3, 0, z3, 2, 2 * R, 2 * R, 0, COLOR.walk, MATERIAL.walk, { seg = A.id, shape = "Cylinder", roll = 90 })
local x4, z4 = at(db0 + R / 2, da0 + R / 2) -- Asphalt in der Rundung (zwischen Scheibe und Straßenecke), sonst blitzt der Boden durch
part(parts, "EckAsphalt", "corner", x4, 0, z4, R, 1, R, yaw, COLOR.road, MATERIAL.road, { seg = A.id })
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
for k = 0, 9 do vcyl("EcktuermchenHelm", u, y0 + 62.5 + k * 1.5, 1, 1.8, 8.4 * (1 - k / 10) + 0.6, ROOF, "Slate") end
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
for k = 0, 15 do vcyl("Turmhelm", 0, y0 + 95 + k * 1.9, TV, 2.2, 15 * (1 - k / 16) ^ 1.2 + 1, ROOF, "Slate") end
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
local function line(name, x0, z0, x1, z1, w, color, y) -- Linie längs x (z0 == z1) oder längs z, am U-Bahn-Abgang unterbrochen
local spans = { { 0, 1 } }
if z0 == z1 and z0 > U.z0 and z0 < U.z1 then spans = { { 0, (U.x0 - x0) / (x1 - x0) }, { (U.x1 - x0) / (x1 - x0), 1 } } end
if x0 == x1 and x0 > U.x0 and x0 < U.x1 then spans = { { 0, (U.z0 - z0) / (z1 - z0) }, { (U.z1 - z0) / (z1 - z0), 1 } } end
for _, sp in ipairs(spans) do
local ax, az, bx, bz = x0 + (x1 - x0) * sp[1], z0 + (z1 - z0) * sp[1], x0 + (x1 - x0) * sp[2], z0 + (z1 - z0) * sp[2]
if z0 == z1 and bx - ax > 0.5 then add(name, (ax + bx) / 2, y, z0, bx - ax, 0.06, w, color, "SmoothPlastic") end
if x0 == x1 and bz - az > 0.5 then add(name, x0, y, (az + bz) / 2, w, 0.06, bz - az, color, "SmoothPlastic") end
end
end
for x = P.x0 + 8, P.x1 - 4, 8 do line("Fuge", x, P.z0, x, P.z1, 0.18, JOINT, 1.03) end
for z = P.z0 + 8, P.z1 - 4, 8 do line("Fuge", P.x0, z, P.x1, z, 0.18, JOINT, 1.03) end
for _, z in ipairs({ 120, 200, 280 }) do line("Band", P.x0, z, P.x1, z, 2.4, BAND, 1.05) end
for _, x in ipairs({ -560, -450, -380 }) do line("Band", x, P.z0, x, P.z1, 2.4, BAND, 1.05) end
line("Band", P.x0 + 1.2, P.z0, P.x0 + 1.2, P.z1, 2.4, BAND, 1.05)
line("Band", P.x1 - 1.2, P.z0, P.x1 - 1.2, P.z1, 2.4, BAND, 1.05)
line("Band", P.x0, P.z1 - 1.2, P.x1, P.z1 - 1.2, 2.4, BAND, 1.05)
local MARBLE, RED, BRONZE, GOLD, PINK = { 214, 206, 194 }, { 150, 58, 58 }, { 64, 68, 60 }, { 230, 188, 70 }, { 222, 86, 140 }
vcyl("SaeulenKreis", S.x, 1.04, S.z, 0.08, 46, BAND, "Granite")
vcyl("SaeulenKreis", S.x, 1.07, S.z, 0.08, 40, GRANITE, "Granite")
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
vcyl("Baumscheibe", t[1], 1.05, t[2], 0.1, 6, { 70, 66, 60 }, "Metal")
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
local stats = { segs = 0, shops = 0, jets = 0, merlons = 0, taxis = 0, lamps = 0, trees = 0 }
local rng = newRng(11)
local function add(name, kind, x, y, z, sx, sy, sz, color, mat, e)
e = e or {}
parts[#parts + 1] = {
name = name, kind = kind, size = { Geo.round3(sx), Geo.round3(sy), Geo.round3(sz) }, pos = { Geo.round3(x), Geo.round3(y), Geo.round3(z) },
yaw = e.yaw or 0, pitch = e.pitch or 0, roll = e.roll, color = color, material = mat, collide = e.collide == true, shape = e.shape,
text = e.text, tag = e.tag, lit = e.lit, attrs = e.attrs, transparency = e.transparency,
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
return function(name, kind, lx, y, lz, sx, sy, sz, color, mat, e)
e = e or {}
local ee = {}
for k, v in pairs(e) do ee[k] = v end
ee.yaw = (psi + (e.yaw or 0)) % 360
add(name, kind, cx + lx * c + lz * s, y, cz - lx * s + lz * c, sx, sy, sz, color, mat, ee)
end
end
local cx, cz, ac, bc, D = S.cx, S.cz, S.ac, S.bc, S.depth
local H, Y0 = 14 + 12 * (S.floors - 1), 1
local TOP = Y0 + H
add("Pflaster", "plaza", (S.x0 + S.x1) / 2, 0, (S.z0 + S.z1) / 2, S.x1 - S.x0, 2, S.z1 - S.z0, { 204, 198, 188 }, "Granite", { collide = true })
for x = S.x0 + 8, S.x1 - 4, 8 do add("Fuge", "plaza", x, 1.03, (S.z0 + S.z1) / 2, 0.18, 0.06, S.z1 - S.z0, { 172, 166, 156 }, "SmoothPlastic") end
for z = S.z0 + 8, S.z1 - 4, 8 do add("Fuge", "plaza", (S.x0 + S.x1) / 2, 1.03, z, S.x1 - S.x0, 0.06, 0.18, { 172, 166, 156 }, "SmoothPlastic") end
for i, rr in ipairs({ 62, 58, 53 }) do vcyl("Pflasterring", "plaza", cx, 1.08 + i * 0.01, cz, 0.08, 2 * rr, i == 2 and { 150, 96, 84 } or { 186, 180, 170 }, "Granite") end
local R = S.basin
for i = 0, 35 do
local a = math.rad(i * 10)
add("Beckenrand", "plaza", cx + R * math.cos(a), 2.1, cz + R * math.sin(a), 8, 2.2, 2.6, STONE, "Granite", { yaw = math.deg(math.atan2(-math.cos(a), -math.sin(a))) % 360, collide = true })
end
vcyl("Beckenboden", "plaza", cx, 1.2, cz, 0.3, 2 * R, { 120, 140, 156 }, "Concrete")
vcyl("Wasser", "plaza", cx, 2.3, cz, 0.4, 2 * R - 2, { 130, 180, 214 }, "SmoothPlastic", { transparency = 0.45 })
for _, ring in ipairs({ { 20, 24, 10, 6 }, { 32, 30, 8, 5 } }) do -- Radius, Strahlen, Reichweite, Höhe des Bogens
for k = 0, ring[2] - 1 do
local a = math.rad(k * 360 / ring[2] + (ring[1] > 25 and 6 or 0))
for j = 0, 5 do
local t = j / 5
local r = ring[1] + ring[3] * t
add("Wasserstrahl", "plaza", cx + r * math.cos(a), 2.6 + 4 * ring[4] * t * (1 - t), cz + r * math.sin(a), 0.9, 0.9, 0.9, { 240, 248, 255 }, "SmoothPlastic", { shape = "Ball", transparency = 0.25 })
end
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
add("Sitzstein", "plaza", cx + (R + 13) * math.cos(a), 2.3, cz + (R + 13) * math.sin(a), 3.4, 2.6, 2.6, { 160, 156, 148 }, "Granite", { yaw = i * 23, collide = true })
end
local function centre(th) return cx - ac * math.sin(th), cz - bc * math.cos(th) end
local function psiAt(th)
local fx, fz = math.sin(th) / ac, math.cos(th) / bc
local l = math.sqrt(fx * fx + fz * fz)
return math.deg(math.atan2(-fx / l, -fz / l)) % 360
end
local samples, total = { { 0, 0 } }, 0
do
local px, pz = centre(0)
for k = 1, 720 do
local th = math.pi * k / 720
local x, z = centre(th)
total = total + math.sqrt((x - px) ^ 2 + (z - pz) ^ 2)
samples[#samples + 1] = { th, total }
px, pz = x, z
end
end
local function thetaAt(s)
for k = 2, #samples do
if samples[k][2] >= s then
local a, b = samples[k - 1], samples[k]
return a[1] + (b[1] - a[1]) * (s - a[2]) / math.max(1e-9, b[2] - a[2])
end
end
return math.pi
end
local n = S.segments
local L = total / n
local shopNo, roofSigns = 0, {}
local function segment(x, z, psi, len, idx, opts)
opts = opts or {}
local put = frame(x, z, psi)
local W = len + 1.4
local tall = opts.extra or 0
local Ht = H + tall
stats.segs = stats.segs + 1
put("Gebaeude", "body", 0, Y0 + Ht / 2, 0, W, Ht, D, opts.color or SAND, "SmoothPlastic", { collide = true })
put("Sockel", "trim", 0, Y0 + 1.2, -D / 2 - 0.25, W, 2.4, 0.5, { 140, 136, 130 }, "Concrete")
for k = 1, S.floors - 1 + (tall > 0 and 2 or 0) do put("Gesims", "trim", 0, Y0 + 14 + 12 * (k - 1), -D / 2 - 0.4, W, 0.7, 0.8, { 214, 200, 170 }, "Concrete") end
put("Kranzgesims", "trim", 0, Y0 + Ht - 0.8, 0, W + 1.2, 1.6, D + 1.2, { 244, 236, 214 }, "Concrete")
local rise, run = 7, 4
local ln = math.sqrt(run * run + rise * rise)
local ang = math.deg(math.atan2(rise, run))
local base = Y0 + Ht
put("Mansard", "roof", 0, base + rise / 2 + 0.3, -D / 2 + run / 2, W, 0.8, ln, SLATE, "Metal", { pitch = -ang })
put("Mansard", "roof", 0, base + rise / 2 + 0.3, D / 2 - run / 2, W, 0.8, ln, SLATE, "Metal", { pitch = ang })
put("MansardFuellung", "body", 0, base + rise / 2 + 0.3, 0, W, rise, D - 2 * run, { 56, 60, 70 }, "SmoothPlastic", { collide = true })
put("Dach", "roof", 0, base + rise + 0.6, 0, W, 0.6, D - 2 * run, SLATE, "Metal")
if idx % 2 == 0 then
put("Gaube", "body", 0, base + 2.6, -D / 2 + 2.2, 3.8, 4.4, 2.6, SAND, "SmoothPlastic")
put("GaubeFenster", "glass", 0, base + 2.6, -D / 2 + 0.85, 2.4, 2.8, 0.2, GLASS, "Glass", { tag = "HouseWindow", lit = rng() < 0.3 })
put("GaubeDach", "roof", 0, base + 5.0, -D / 2 + 2.2, 4.6, 0.5, 3.4, SLATE, "Metal")
end
for k = 1, S.floors - 1 + (tall > 0 and 2 or 0) do
local yb = Y0 + 14 + 12 * (k - 1)
put("Fenster", "glass", 0, yb + 6, -D / 2 - 0.15, 3.8, 6.4, 0.3, rng() < 0.3 and GLASS_LIT or GLASS, "Glass", { tag = "HouseWindow", lit = false })
put("Fensterbank", "trim", 0, yb + 2.6, -D / 2 - 0.45, 5, 0.5, 0.9, { 214, 200, 170 }, "Concrete")
if k == 1 or k == 3 then
put("BalkonPlatte", "balcony", 0, yb + 0.3, -D / 2 - 1.2, W - 1.2, 0.5, 2.4, { 170, 166, 158 }, "Concrete")
put("BalkonGitter", "balcony", 0, yb + 1.9, -D / 2 - 2.3, W - 1.2, 2.4, 0.25, { 60, 60, 66 }, "Metal")
end
if not opts.noOuter then put("FensterAussen", "glass", 0, yb + 6, D / 2 + 0.15, 3.8, 6.4, 0.3, rng() < 0.3 and GLASS_LIT or GLASS, "Glass", { tag = "HouseWindow", lit = false }) end
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
if not opts.noOuter then put("EGFensterAussen", "glass", 0, Y0 + 6, D / 2 + 0.15, len - 1.6, 8, 0.3, GLASS, "Glass", { tag = "HouseWindow", lit = false }) end
if opts.endSide then -- Stirnseite des Schenkels (zur Leopoldstraße): Fenster in allen Geschossen
for k = 1, S.floors - 1 + 2 do
local yb = Y0 + 14 + 12 * (k - 1)
for _, lz in ipairs({ -6, 6 }) do put("FensterStirn", "glass", opts.endSide * (W / 2 + 0.15), yb + 6, lz, 0.3, 6.4, 3.8, rng() < 0.3 and GLASS_LIT or GLASS, "Glass", { tag = "HouseWindow", lit = false }) end
end
put("StirnSockel", "trim", opts.endSide * (W / 2 + 0.2), Y0 + 6, 0, 0.4, 12, D - 4, { 150, 146, 140 }, "Concrete")
end
if tall > 0 then
for i, w in ipairs({ 0.8, 0.55, 0.3 }) do put("Turmdach", "roof", 0, base + rise + 3 + (i - 1) * 4.4, 0, W * w, 4.4, D * w, SLATE, "Metal") end
put("Turmkugel", "roof", 0, base + rise + 16, 0, 2.2, 2.2, 2.2, { 226, 184, 72 }, "Metal", { shape = "Ball" })
end
end
local function skipGate(z, len) return math.abs(z - cz) < S.gate + len * 0.1 end
local skipped, firstSkip, lastSkip = {}, nil, nil
for k = 1, n do
local _, z = centre(thetaAt((k - 0.5) * L))
if skipGate(z, L) then
skipped[k] = true
firstSkip, lastSkip = firstSkip or k, k
end
end
local idx = 0
for k = 1, n do
if not skipped[k] then
local th = thetaAt((k - 0.5) * L)
local x, z = centre(th)
local ang = psiAt(th)
idx = idx + 1
segment(x, z, ang, L, idx, { burger = (k == 6 or k == 7), extra = (k == firstSkip - 1 or k == lastSkip + 1) and 20 or 0 })
if k == 14 or k == n - 13 then roofSigns[#roofSigns + 1] = { x = x, z = z, psi = ang } end
end
end
for _, e in ipairs({ { th = 0 }, { th = math.pi } }) do
local x0, z0 = centre(e.th)
local psi = psiAt(e.th)
local dir = e.th == 0 and 1 or 1
for k = 1, S.legs do
idx = idx + 1
segment(x0 + (k - 0.5) * L * dir, z0, psi, L, idx, { extra = (k == S.legs) and 20 or 0, endSide = (k == S.legs) and (e.th == 0 and -1 or 1) or nil })
end
end
for _, rs in ipairs(roofSigns) do
local put = frame(rs.x, rs.z, rs.psi)
local base = TOP + 7.6
for _, lx in ipairs({ -12, 12 }) do put("SchriftPfosten", "trim", lx, base + 2.4, -4, 0.8, 4.8, 0.8, { 90, 90, 96 }, "Metal") end
put("SchriftBrett", "sign", 0, base + 7.5, -4, 34, 7, 0.8, { 176, 32, 40 }, "SmoothPlastic")
put("SchriftOSRUM", "sign", 0, base + 7.5, -4.5, 31, 5.4, 0.2, { 0, 0, 0 }, "SmoothPlastic", { text = { s = "OSRUM", color = { 250, 244, 236 } } })
end
do
local gx, gz = cx - ac, cz
local put = frame(gx, gz, 270)
local GD = 22
local WALL, WALL2 = { 238, 236, 228 }, { 226, 222, 210 }
local TT, MT = 38, 28 -- Höhe Türme / Mittelbau
for _, sd in ipairs({ -1, 1 }) do
put("TorTurm", "body", sd * 19, Y0 + TT / 2, 0, 14, TT, GD, WALL, "SmoothPlastic", { collide = true })
put("TorTurmGesims", "trim", sd * 19, Y0 + TT - 1, 0, 15.2, 1.4, GD + 1.2, WALL2, "Concrete")
put("TorSeitenbogen", "trim", sd * 19, Y0 + 5, -GD / 2 - 0.15, 5, 10, 0.3, { 60, 56, 52 }, "SmoothPlastic")
put("TorSeitenbogen", "trim", sd * 19, Y0 + 10, -GD / 2 - 0.15, 3.5, 3.5, 0.3, { 60, 56, 52 }, "SmoothPlastic", { roll = 45 })
put("TorSeitenbogen", "trim", sd * 19, Y0 + 5, GD / 2 + 0.15, 5, 10, 0.3, { 60, 56, 52 }, "SmoothPlastic")
put("TorSeitenbogen", "trim", sd * 19, Y0 + 10, GD / 2 + 0.15, 3.5, 3.5, 0.3, { 60, 56, 52 }, "SmoothPlastic", { roll = 45 })
for _, wz in ipairs({ -GD / 2 - 0.15, GD / 2 + 0.15 }) do
put("TorFenster", "glass", sd * 19, Y0 + 24, wz, 2.2, 4, 0.3, GLASS, "Glass", { tag = "HouseWindow", lit = false })
end
end
for _, sd in ipairs({ -1, 1 }) do -- Pfeiler beidseits des Durchgangs (|lx| 6 bis 12)
put("TorPfeiler", "body", sd * 9, Y0 + MT / 2, 0, 6, MT, GD, WALL, "SmoothPlastic", { collide = true })
end
local rr, spring, m = 6, 12, 12 -- Bogen: Halbkreis, Spitzenaufsatz durch die Raute
local w = 2 * rr / m
for i = 1, m do
local xc = -rr + (i - 0.5) * w
local bottom = spring + math.sqrt(math.max(0, rr * rr - xc * xc))
put("TorBogen", "body", xc, Y0 + (bottom + MT) / 2, 0, w + 0.05, MT - bottom, GD, WALL, "SmoothPlastic", { collide = true })
end
for _, fz in ipairs({ -GD / 2 - 0.3, GD / 2 + 0.3 }) do
put("TorBogenRahmen", "trim", 0, Y0 + spring + rr / 2 + 0.7, fz, 0.6, rr + 1.4, 0.6, WALL2, "Concrete", { shape = "Cylinder", roll = 90 }) -- Schlussstein-Zierleiste
for _, sd in ipairs({ -1, 1 }) do put("TorBogenLeiste", "trim", sd * 6.5, Y0 + 7, fz, 1, 14, 0.6, WALL2, "Concrete") end
put("TorBogenLeiste", "trim", 0, Y0 + 18.8, fz, 1.6, 2, 0.6, WALL2, "Concrete")
put("TorUhr", "sign", 0, Y0 + 22.6, fz, 5, 5, 0.4, { 250, 246, 236 }, "SmoothPlastic", { shape = "Cylinder", yaw = 90 })
put("TorUhrRand", "trim", 0, Y0 + 22.6, fz + (fz < 0 and -0.1 or 0.1), 5.8, 5.8, 0.2, { 60, 56, 52 }, "Metal", { shape = "Cylinder", yaw = 90 })
put("TorWappen", "trim", -9, Y0 + 22.6, fz, 2.6, 3.2, 0.3, { 70, 110, 190 }, "SmoothPlastic")
put("TorWappen", "trim", 9, Y0 + 22.6, fz, 2.6, 3.2, 0.3, { 220, 220, 226 }, "SmoothPlastic")
end
put("TorMittelGesims", "trim", 0, Y0 + MT - 0.8, 0, 26, 1.6, GD + 1.2, WALL2, "Concrete")
local function merlons(lx0, lx1, y)
local len = lx1 - lx0
local k = math.max(2, math.floor(len / 3.6))
for i = 1, k do
for _, fz in ipairs({ -GD / 2 + 1, GD / 2 - 1 }) do
put("Zinne", "trim", lx0 + (i - 0.5) * len / k, y + 1.1, fz, len / k * 0.55, 2.2, 1.6, WALL, "Concrete", { collide = true })
stats.merlons = stats.merlons + 1
end
end
for _, lx in ipairs({ lx0 + 0.8, lx1 - 0.8 }) do
for _, fz in ipairs({ -GD / 4, GD / 4 }) do put("Zinne", "trim", lx, y + 1.1, fz, 1.6, 2.2, 3, WALL, "Concrete", { collide = true }) stats.merlons = stats.merlons + 1 end
end
end
merlons(-12, 12, Y0 + MT)
merlons(-26, -12, Y0 + TT)
merlons(12, 26, Y0 + TT)
put("TorSchrift", "sign", 0, Y0 + 26.3, -GD / 2 - 0.4, 12, 1.4, 0.1, { 0, 0, 0 }, "SmoothPlastic", { text = { s = "KARLSTOR", color = { 90, 86, 80 } } })
put("TorSchrift", "sign", 0, Y0 + 26.3, GD / 2 + 0.4, 12, 1.4, 0.1, { 0, 0, 0 }, "SmoothPlastic", { yaw = 180, text = { s = "KARLSTOR", color = { 90, 86, 80 } } })
end
for z = S.z0 + 24, S.z1 - 12, 42 do
vcyl("KugelleuchteMast", "plaza", -72, 13, z, 24, 0.8, { 150, 152, 156 }, "Metal", { collide = true })
for _, yy in ipairs({ 19.6, 23.6 }) do add("Kugelleuchte", "plaza", -72, yy, z, 4.4, 4.4, 4.4, { 255, 250, 238 }, "Neon", { shape = "Ball", tag = "StreetLamp", attrs = { Lit = true } }) end
stats.lamps = stats.lamps + 1
end
local GREENS = { { 70, 120, 60 }, { 88, 140, 70 }, { 60, 108, 58 } }
for i, z in ipairs({ 80, 122, 164, 206, 248, 290, 332, 372 }) do
local x = -64
vcyl("Baumscheibe", "plaza", x, 1.05, z, 0.1, 6, { 70, 66, 60 }, "Metal")
vcyl("PlataneStamm", "plaza", x, 7, z, 12, 2.2, { 150, 138, 116 }, "Wood", { collide = true })
add("PlataneKrone", "plaza", x, 18, z, 17, 15, 17, GREENS[i % 3 + 1], "Grass", { shape = "Ball" })
add("PlataneKrone", "plaza", x + 3, 15.5, z - 3, 12, 11, 12, GREENS[(i + 1) % 3 + 1], "Grass", { shape = "Ball" })
stats.trees = stats.trees + 1
end
local bx = S.taxi.x
for k = 0, S.taxi.n - 1 do
local z = S.taxi.z0 + S.taxi.len * (k + 0.5)
if k ~= 2 and k ~= 5 then -- zwei Buchten frei, damit es lebendig wirkt
local col = (k % 3 == 1) and { 40, 40, 44 } or { 238, 230, 202 }
add("TaxiKarosserie", "vehicle", bx, 1.9, z, 4.2, 1.6, 9.4, col, "Metal", { collide = true })
add("TaxiKabine", "vehicle", bx, 3.3, z - 0.4, 3.7, 1.4, 5, { 56, 74, 90 }, "Glass")
add("TaxiDach", "vehicle", bx, 4.1, z - 0.4, 3.8, 0.25, 5.2, col, "Metal")
add("TaxiSchild", "vehicle", bx, 4.6, z - 0.4, 1.5, 0.6, 0.7, { 255, 214, 60 }, "Neon")
for _, wx in ipairs({ -2.1, 2.1 }) do
for _, wz in ipairs({ -3, 3 }) do add("TaxiRad", "vehicle", bx + wx, 1.2, z + wz, 0.7, 1.9, 1.9, { 30, 30, 32 }, "Metal", { shape = "Cylinder" }) end
end
for _, lx in ipairs({ -1.4, 1.4 }) do add("TaxiLicht", "vehicle", bx + lx, 2.2, z + 4.75, 0.9, 0.5, 0.2, { 255, 246, 200 }, "Neon") end
stats.taxis = stats.taxis + 1
end
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
local wx, wz = at(0, 0)
add("Eisbachwelle", "wave", wx, -3.7, wz, 13, 5.5, 5.5, { 214, 234, 246 }, "SmoothPlastic", { shape = "Cylinder", yaw = yawN, transparency = 0.2, tag = "Eisbachwelle", attrs = { Surf = true } })
local sx, sz = at(-1.6, 0)
add("Wellenschaum", "wave", sx, -1.3, sz, 13, 0.6, 2.8, { 248, 252, 255 }, "SmoothPlastic", { yaw = yawN, transparency = 0.1 })
local tx, tz = at(3.6, 0)
add("Wellental", "wave", tx, -3.85, tz, 13, 0.3, 6, { 190, 220, 238 }, "SmoothPlastic", { yaw = yawN, transparency = 0.4 })
add("SurfZone", "zone", wx, -2.5, wz, 14, 6, 14, { 255, 255, 255 }, "SmoothPlastic", { yaw = yawN, transparency = 1, tag = "SurfZone", attrs = { Welle = "Eisbach" } })
local STONEW = { 170, 164, 150 }
for _, side in ipairs({ -1, 1 }) do -- Ufermauern an beiden Ufern, flussabwärts der Brücke
local mx, mz = at(14, side * 13.6)
add("Ufermauer", "wall", mx, -1.4, mz, 30, 5.2, 1.2, STONEW, "Concrete", { yaw = yawU, collide = true })
end
local dx, dz = at(20, 21)
add("Zuschauerdeck", "deck", dx, 0.25, dz, 26, 0.5, 10, { 140, 104, 70 }, "Wood", { yaw = yawU, collide = true })
local rx, rz = at(20, 15.8)
add("DeckGelaender", "deck", rx, 1.2, rz, 26, 1.2, 0.3, { 70, 62, 56 }, "Metal", { yaw = yawU, collide = true })
for _, a in ipairs({ -8, 0, 8 }) do
local bx, bz = at(20 + a, 24.2)
bench(add, bx, 0.5, bz, math.deg(math.atan2(nx, nz)))
end
local px, pz = at(8, 16.2)
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
M.RoadsPlanner = RoadsPlanner
M.LightsPlanner = LightsPlanner
M.Landmarks = Landmarks
M.Rathaus = Rathaus
M.Marienplatz = Marienplatz
M.Stachus = Stachus
M.Hochhaus = Hochhaus
M.Bushaltestellen = Bushaltestellen
M.TerrainPlanner = TerrainPlanner
M.Garden = Garden
M.WallPlanner = WallPlanner
end
