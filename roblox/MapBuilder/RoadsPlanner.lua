-- RoadsPlanner.lua
-- Straßen, Gehwege, Markierungen, Parkbuchten, Plätze, Brücken als Teileliste.
-- Reine Geometrie (keine Roblox-Funktionen). Teile haben dieselben Felder wie die Häuser aus Planner.lua, dazu optional pitch.

local Geo = require(script and script.Parent.Geo or "Geo")

local RoadsPlanner = {}

local COLOR = {
	road = { 84, 90, 96 }, walk = { 168, 172, 174 }, plaza = { 214, 208, 196 }, median = { 118, 150, 98 }, green = { 104, 148, 84 }, bike = { 176, 66, 58 },
	dash = { 236, 236, 230 }, deck = { 140, 140, 146 }, rail = { 70, 70, 76 }, tunnel = { 110, 110, 116 },
}
local MATERIAL = { road = "Asphalt", walk = "Concrete", plaza = "Concrete", median = "Grass", green = "Grass", bike = "Asphalt" }
local TOP = { road = 0.5, walk = 1.0, plaza = 0.5, median = 0.8, green = 1.0, bike = 0.8 }
-- Markierungen stehen 0,1 bis 0,2 Studs über der Fahrbahn (Fahrbahn-Oberkante 0,5 bis 0,62)
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

-- Große Fliesen wie am Marienplatz: Fugen alle TILE Studs quer und längs auf eine Platzfläche (Mitte cx, cz; Länge len entlang u, Breite w quer)
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

-- Fahrbahnen, die sich überlappen (Kreuzungen, Ecken der Ringstraße), liegen sonst auf exakt gleicher Höhe und flackern (Z-Fighting).
-- Darum bekommt jede Straße eine Stufe (greedy-Färbung); Stufe k hebt die Fahrbahn um k * 0,04 Studs.
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
		-- gestrichelte Mittel-/Spurlinien
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

	-- Parkbuchten: Trennlinien quer zum Parkstreifen
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

	-- Isar-Brücken: flach auf Straßenhöhe (Oberkante 0,5), Gehwege und Brüstungen aus Stein; getragen von Pfeilerreihen (Querbalken auf vier Säulen)
	-- im Flussbett und auf der Kiesbank. Auf den Uferstufen liegt die Brücke frei darüber, an den Enden greift sie ins Gelände.
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
	-- Maximilianbrücke: dünnes Deck auf Straßenhöhe, darunter zwei flache Segmentbögen (aus senkrechten Scheiben unter dem Deck) über einen
	-- Mittelpfeiler mit Vorköpfen im Fluss, Widerlager an beiden Seiten, Statuen auf Sockeln über dem Pfeiler und klassische Laternen.
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
		-- Bögen: Spannweite 2 * span / 2 je Bogen, Kämpfer auf -7, Scheitel der Untersicht auf -2,5
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
		-- Statuen auf Sockeln über dem Pfeiler (beide Seiten)
		local STATUE = { 176, 172, 162 }
		for _, sd in ipairs({ -1, 1 }) do
			local x, z = at(0, sd * 25.5)
			part(parts, "StatueSockel", "deck", x, 3.5, z, 5, 5, 5, b.yaw, BODY, "Concrete", {})
			part(parts, "StatueGewand", "deck", x, 8.5, z, 3.2, 5, 3.2, b.yaw, STATUE, "Concrete", { collide = false })
			part(parts, "StatueTorso", "deck", x, 12.2, z, 2.6, 2.6, 2, b.yaw, STATUE, "Concrete", { collide = false })
			part(parts, "StatueKopf", "deck", x, 14.3, z, 1.6, 1.8, 1.6, b.yaw, STATUE, "Concrete", { collide = false })
		end
		-- Laternen: Pfosten mit Leuchtkasten (Tag StreetLamp), am Pfeiler und über den Bogenansätzen
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
