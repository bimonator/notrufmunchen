-- RoadsPlanner.lua
-- Straßen, Gehwege, Markierungen, Parkbuchten, Plätze, Brücken und die Siegestor-Unterführung als Teileliste.
-- Reine Geometrie (keine Roblox-Funktionen). Teile haben dieselben Felder wie die Häuser aus Planner.lua, dazu optional pitch.

local Geo = require(script and script.Parent.Geo or "Geo")

local RoadsPlanner = {}

local COLOR = {
	road = { 84, 90, 96 }, walk = { 168, 172, 174 }, plaza = { 214, 208, 196 }, median = { 118, 150, 98 },
	dash = { 236, 236, 230 }, deck = { 140, 140, 146 }, rail = { 70, 70, 76 }, tunnel = { 110, 110, 116 },
}
local MATERIAL = { road = "Asphalt", walk = "Concrete", plaza = "Pavement", median = "Grass" }
local TOP = { road = 0.5, walk = 1.0, plaza = 0.5, median = 0.8 }
local THICK = { road = 1, walk = 2, plaza = 1, median = 1.8 }

local function part(parts, name, kind, x, y, z, sx, sy, sz, yaw, color, material, extra)
	extra = extra or {}
	parts[#parts + 1] = {
		name = name, kind = kind, size = { sx, sy, sz },
		pos = { Geo.round3(x), Geo.round3(y), Geo.round3(z) },
		yaw = Geo.round3(yaw), pitch = extra.pitch or 0, color = color, material = material,
		collide = extra.collide ~= false, seg = extra.seg,
	}
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
	local tun = cfg.tunnel
	local stats = { bays = 0, dashes = 0 }

	for _, seg in ipairs(segs) do
		local yaw = Geo.yawOf(seg.ux, seg.uz)
		local p0x, p0z = seg.ax - seg.ux * seg.extA, seg.az - seg.uz * seg.extA
		local L = seg.len + seg.extA + seg.extB
		local nx, nz = -seg.uz, seg.ux
		-- Tunnelbereich als Abschnitt entlang dieser Straße (nur die Achse läuft in z-Richtung)
		local tunnelCut
		if seg.road.name == tun.road then
			local t0, t1 = (tun.z0 - p0z) * seg.uz, (tun.z1 - p0z) * seg.uz
			if t0 > t1 then t0, t1 = t1, t0 end
			tunnelCut = { t0, t1 }
		end
		local bridgeCuts = {}
		for _, b in ipairs(cfg.archBridges) do
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
			if kind == "walk" then cuts = crossCuts(segs, seg, sx, sz, L, 0.05) end
			if st[4] and tunnelCut then cuts[#cuts + 1] = tunnelCut end
			for _, bc in ipairs(bridgeCuts) do cuts[#cuts + 1] = bc end
			for _, sp in ipairs(Geo.subtract({ { 0, L } }, cuts)) do
				local len = sp[2] - sp[1]
				if len > 0.5 then
					local c = (sp[1] + sp[2]) / 2
					part(parts, string.format("%s_%d_%s", seg.road.name, seg.id, kind), kind, sx + seg.ux * c, TOP[kind] - THICK[kind] / 2, sz + seg.uz * c,
						len, THICK[kind], w, yaw, COLOR[kind], MATERIAL[kind], { seg = seg.id })
				end
			end
		end
		-- gestrichelte Mittel-/Spurlinien
		for _, d in ipairs(seg.prof.dashes) do
			local sx, sz = p0x + nx * d, p0z + nz * d
			local cuts = crossCuts(segs, seg, sx, sz, L, 0.5)
			if seg.prof.dashesUnderground and tunnelCut then cuts[#cuts + 1] = tunnelCut end
			for _, bc in ipairs(bridgeCuts) do cuts[#cuts + 1] = bc end
			for _, sp in ipairs(Geo.subtract({ { 0, L } }, cuts)) do
				local t = sp[1] + 1
				while t + 6 <= sp[2] - 1 do
					local c = t + 3
					part(parts, "Dash", "dash", sx + seg.ux * c, 0.53, sz + seg.uz * c, 6, 0.06, 0.4, yaw, COLOR.dash, "SmoothPlastic", { collide = false, seg = seg.id })
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
			local sx, sz = (math.abs(ux) > 0.5) and 0.3 or cfg.bay.width, (math.abs(ux) > 0.5) and cfg.bay.width or 0.3
			part(parts, "BayLine", "dash", x, 0.53, z, sx, 0.06, sz, 0, COLOR.dash, "SmoothPlastic", { collide = false })
		end
		stats.bays = stats.bays + n
	end

	for _, pl in ipairs(cfg.plazas) do
		part(parts, "Plaza_" .. pl.name, "plaza", (pl.x0 + pl.x1) / 2, -0.05, (pl.z0 + pl.z1) / 2, pl.x1 - pl.x0, 1, pl.z1 - pl.z0, 0, COLOR.plaza, MATERIAL.plaza, {})
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

	-- Gewölbte Isar-Brücken: Fahrbahn und Gehwege als geneigte Platten entlang einer Parabel, Brüstungen, Pfeiler im Fluss
	local STONE = { 196, 188, 172 }
	for _, b in ipairs(cfg.archBridges) do
		local r = math.rad(b.yaw)
		local ux, uz = math.cos(r), -math.sin(r) -- Richtung der Brücke
		local nx2, nz2 = -uz, ux -- quer
		local yawZ = b.yaw + 90 -- lokale z-Achse der Platten läuft entlang der Brücke
		local N = 16
		local function top(s) -- Oberkante der Fahrbahn bei s (Mitte = 0)
			local q = 2 * s / b.len
			return 0.5 + b.peak * (1 - q * q)
		end
		for i = 0, N - 1 do
			local s0, s1 = -b.len / 2 + b.len * i / N, -b.len / 2 + b.len * (i + 1) / N
			local sm = (s0 + s1) / 2
			local y0, y1 = top(s0), top(s1)
			local ym = (y0 + y1) / 2
			local L = math.sqrt((s1 - s0) ^ 2 + (y1 - y0) ^ 2) + 0.2
			local pitch = -math.deg(math.atan2(y1 - y0, s1 - s0)) -- steigt mit s: negativer Pitch
			local cx, cz = b.x + ux * sm, b.z + uz * sm
			local function slab(name, kind, lat, w, thick, up, color, mat)
				part(parts, name, kind, cx + nx2 * lat, ym + up - thick / 2, cz + nz2 * lat, w, thick, L, yawZ, color, mat, { pitch = pitch })
			end
			slab("BrueckeFahrbahn", "road", 0, b.wid, 4, 0, COLOR.road, "Asphalt")
			for _, side in ipairs({ -1, 1 }) do
				slab("BrueckeGehweg", "walk", side * (b.wid / 2 + b.walk / 2), b.walk, 4, 0.5, STONE, "Concrete")
				slab("BrueckeBruestung", "rail", side * (b.wid / 2 + b.walk + 0.6), 1.2, 4.5, 4, STONE, "Concrete")
			end
		end
		for _, side in ipairs({ -1, 1 }) do -- zwei Pfeiler im Fluss, vom Flussbett (-14) bis unter die Fahrbahn
			local s = side * b.len * 0.2
			local deckBottom = top(s) - 4
			part(parts, "BrueckePfeiler", "deck", b.x + ux * s, (deckBottom - 14) / 2, b.z + uz * s, 6, deckBottom + 14, b.wid + 2 * b.walk - 4, b.yaw, STONE, "Concrete", {})
		end
		stats.archBridges = (stats.archBridges or 0) + 1
	end

	-- Unterführung: Rampen (geneigt), Boden, Decke unter der Querstraße, Seitenwände des Tunnelkastens
	local w = tun.half * 2
	local drop = tun.surfaceTop - tun.floorTop
	for _, ramp in ipairs({ { tun.rampN, 1 }, { tun.rampS, -1 } }) do
		local z0, z1 = ramp[1][1], ramp[1][2]
		local dz = z1 - z0
		local L = math.sqrt(dz * dz + drop * drop)
		local ang = math.deg(math.atan2(drop, dz)) -- positiv = fällt nach Süden
		part(parts, "Rampe", "tunnel", 0, (tun.surfaceTop + tun.floorTop) / 2 - 0.5, (z0 + z1) / 2, w, 1, L, 0, COLOR.road, "Asphalt", { pitch = ramp[2] * ang })
	end
	local bz0, bz1 = tun.box[1], tun.box[2]
	part(parts, "TunnelBoden", "tunnel", 0, tun.floorTop - 0.5, (bz0 + bz1) / 2, w, 1, bz1 - bz0, 0, COLOR.road, "Asphalt", {})
	part(parts, "TunnelDecke", "tunnel", 0, -1.1, (bz0 + bz1) / 2, w, 3, bz1 - bz0, 0, COLOR.tunnel, "Concrete", {})
	for _, side in ipairs({ -1, 1 }) do
		part(parts, "TunnelWand", "tunnel", side * (tun.half + 1), tun.floorTop - 1 + 8.75, (bz0 + bz1) / 2, 2, 17.5, bz1 - bz0, 0, COLOR.tunnel, "Concrete", {})
	end
	stats.stalls = stats.bays
	return { parts = parts, stats = stats, segments = segs }
end

return RoadsPlanner
