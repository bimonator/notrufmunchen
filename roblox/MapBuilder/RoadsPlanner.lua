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
		collide = extra.collide ~= false, seg = extra.seg, shape = extra.shape, roll = extra.roll, wedge = extra.wedge,
	}
end

-- Flaches Dreieck aus zwei rechtwinkligen Keilen (Part-Shape Wedge, Dicke senkrecht): p1, p2, p3 = { x, z }. Der Keil hat den rechten Winkel am Fußpunkt der Höhe auf die
-- längste Seite; wedge = { ey, ez } sind die Richtungen seiner beiden Schenkel (Größe = Dicke, Länge ey, Länge ez), Builder baut daraus das Koordinatensystem.
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
				{ wedge = { { dx, dz }, { -hx, -hz } } })
		end
	end
end

-- Streifen aus Dreiecken zwischen zwei gleich langen Linienzügen P und Q (Rand an der Straße, Rand am Gebäude)
local function strip(parts, name, P, Q, top, thick, color, material)
	for i = 1, #P - 1 do
		tri(parts, name, P[i], P[i + 1], Q[i], top, thick, color, material)
		tri(parts, name, P[i + 1], Q[i + 1], Q[i], top, thick, color, material)
	end
end

-- Große Fliesen wie am Marienplatz: Fugen alle TILE Studs quer und längs auf eine Platzfläche (Mitte cx, cz; Länge len entlang u, Breite w quer)
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
				-- core: andere Gehwege laufen bis an die Fahrbahn des Kreises durch und schließen so nahtlos an dessen Gehweg an
				cutRect = prof.core and Geo.rect(a[1], a[2], b[1], b[2], prof.core, extA, extB) or nil,
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

-- Einmündungskurven am Kreisverkehr (siehe Config.kreiselEcken). Rechnet im Frame der Zufahrt: a = Abstand von p0 entlang u (vom Kreisel weg), b = seitlich zur Seite sv.
-- Straßenseitige Kante (Radius rho, Mitte im Gehweg) und Gebäudeseite (Radius rho1, Mitte im Block) runden die Ecke; beide Wege bestehen aus Gerade, Bogen und Kreisbogen.
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

-- Abschnitte (t-Werte) entlang der Linie P + u*t, die in anderen Straßen liegen
local function crossCuts(segs, self, px, pz, L, margin)
	local cuts = {}
	for _, o in ipairs(segs) do
		-- benachbarte Segmente derselben Straße mit kleinem Knick (Ellipse, Kurven) schneiden sich nicht gegenseitig: sonst reißt der Gehweg an jedem Knick auf
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
				if seg.outerA == so then cuts[#cuts + 1] = { -1, seg.extA } end -- Außenseite von Knicken: Gehweg endet am Knickpunkt, eine Rundung schließt an
				if seg.outerB == so then cuts[#cuts + 1] = { L - seg.extB, L + 1 } end
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

	-- Einmündungskurven am Kreisverkehr: Gehweg als Dreiecksstreifen zwischen straßen- und gebäudeseitiger Kante, Asphalt in der abgerundeten Straßenecke
	stats.curves = #curves
	for _, k in ipairs(curves) do
		strip(parts, "GehwegKurve", k.P, k.Q, TOP.walk, THICK.walk, COLOR.walk, MATERIAL.walk)
		for i = 1, #k.apexArc - 1 do -- Asphalt: Fächer vom Scheitel der Straßenecke zur Bordsteinrundung
			tri(parts, "EckAsphalt", k.apex, k.apexArc[i], k.apexArc[i + 1], 0.52, 1, COLOR.road, MATERIAL.road)
		end
	end

	-- Einfahrten: Kerbe im Gehweg (Rampe zur Straße, Asphalt auf Gehwegebene, Rampe zum Grundstück)
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

	-- Knicke einer Straße: außen läuft der Gehweg in einem Kreisbogen um den Knickpunkt (Halbmesser = Gehwegkanten) statt mit spitzer Ecke
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

	-- Gehwegecken an jeder Kreuzung und Einmündung (beliebiger Winkel): beide Gehwege sind an der Ecke durch die Straßenrechtecke unterbrochen. Ein Dreiecksstreifen
	-- schließt die Lücke zwischen Bordsteinrundung (Radius CURB, Mitte im Gehweg) und gerundeter Gebäudeecke (Mitte im Block); Asphalt füllt die Rundung an der Fahrbahn.
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
	-- Linienzüge P (an der Straße) und Q (am Gebäude) der Ecke am Schnittpunkt (px, pz); ea, eb = Richtung der Schenkel, da/db = Gehweg von A zur Seite von B und umgekehrt
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
			if A.road ~= B.road and not A.prof.core and not B.prof.core then
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

	-- Zebrastreifen: Streifen parallel zur Fahrtrichtung, nebeneinander quer über die Fahrbahn (a0..a1 von der Mitte in Richtung Normale)
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
		-- Eisbach-Durchlass als Steinbrücke mit zwei Bögen und Mittelpfeiler (wie an der Eisbachwelle), darüber eine höhere Brüstung mit Rosetten und Eckpfosten
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
