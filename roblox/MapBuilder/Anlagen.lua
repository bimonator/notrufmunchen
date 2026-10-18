-- Anlagen.lua
-- Gestaltete Grünflächen als Teileliste (reine Geometrie): Allee beim Schlossgarten, Klinikpark, Isar-Ufer-Parks. Jede Anlage (Config.anlagen) ist ein Polygon mit
-- Rasen (Terrain, Anlagen.terrain), Kieswegen, Teichen, Beeten, Bäumen, Büschen, Findlingen, Bänken und Leuchten. Kein Teil liegt auf einem Weg oder im Teich;
-- Bäume halten Abstand zum Rand. Teilefelder wie in den anderen Planern. Koordinaten: x = Ost, z = Süd, y = oben (Gelände = 0).

local Geo = require(script and script.Parent.Geo or "Geo")
local Baenke = require(script and script.Parent.Baenke or "Baenke")
local Blumen = require(script and script.Parent.Blumen or "Blumen")

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

-- Rasen als 4 Studs breite Spalten (Terrain-Blöcke), die Spalten folgen dem Polygon
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
	local parts, stats = {}, { areas = 0, trees = 0, benches = 0, lamps = 0, rocks = 0, bushes = 0, beds = 0, flowers = 0, pathSegs = 0 }
	local function add(name, kind, x, y, z, sx, sy, sz, color, mat, e)
		e = e or {}
		parts[#parts + 1] = {
			name = name, kind = kind, size = { Geo.round3(sx), Geo.round3(sy), Geo.round3(sz) }, pos = { Geo.round3(x), Geo.round3(y), Geo.round3(z) }, yaw = Geo.round3(e.yaw or 0),
			pitch = e.pitch or 0, roll = e.roll, color = color, material = mat, collide = e.collide == true, shape = e.shape, tag = e.tag, lit = e.lit, attrs = e.attrs, transparency = e.transparency, seat = e.seat,
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
		Baenke.add(add, x, 0, z, math.deg(math.atan2(nx, nz)))
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

		-- Wege (Kies): Teilstücke mit runden Gelenken
		for _, p in ipairs(s.paths or {}) do
			for i = 1, #p.pts - 1 do
				local a, b = p.pts[i], p.pts[i + 1]
				local ux, uz, len = Geo.dir(a[1], a[2], b[1], b[2])
				add("AnlagenWeg", "path", (a[1] + b[1]) / 2, 0.15, (a[2] + b[2]) / 2, len, 0.4, p.w, KIES, "Pavement", { yaw = Geo.yawOf(ux, uz) })
				stats.pathSegs = stats.pathSegs + 1
				if i < #p.pts - 1 then disc("AnlagenWegGelenk", b[1], 0.15, b[2], p.w, 0.4, KIES, "Pavement") end
			end
		end
		-- Teiche: Wasserfläche in einem Steinrand aus Segmenten
		for _, q in ipairs(s.ponds or {}) do
			disc("Teich", q[1], 0.1, q[2], q[3] * 2, 0.5, { 52, 112, 132 }, "SmoothPlastic", { transparency = 0.2 })
			local n = math.max(12, math.floor(q[3] * 1.4))
			for k = 0, n - 1 do
				local th = 2 * math.pi * k / n
				add("TeichRand", "decor", q[1] + (q[3] + 0.6) * math.cos(th), 0.55, q[2] + (q[3] + 0.6) * math.sin(th), 2 * math.pi * (q[3] + 0.6) / n + 0.3, 1.1, 1.8, STONE, "Cobblestone", { yaw = math.deg(-th) + 90, collide = true })
			end
		end
		-- Blumenbeete: Raster aus 5x5 Feldern, farbig, mit niedriger Hecke
		for _, b in ipairs(s.beds or {}) do
			local bedRng = newRng(37)
			for i = 0, b[3] - 1 do
				for j = 0, b[4] - 1 do
					stats.flowers = stats.flowers + Blumen.bed(add, b[1] + i * 5 + 2.5, b[2] + j * 5 + 2.5, 4.4, 4.4, 0, bedRng, i + 2 * j + 1, false)
				end
			end
			for _, e in ipairs({ { b[1] + b[3] * 2.5, b[2] - 0.5, b[3] * 5 + 1, 1 }, { b[1] + b[3] * 2.5, b[2] + b[4] * 5 + 0.5, b[3] * 5 + 1, 1 }, { b[1] - 0.5, b[2] + b[4] * 2.5, 1, b[4] * 5 }, { b[1] + b[3] * 5 + 0.5, b[2] + b[4] * 2.5, 1, b[4] * 5 } }) do
				add("BeetHecke", "decor", e[1], 0.7, e[2], e[3], 1.4, e[4], HEDGE, "Grass", { collide = true })
			end
			stats.beds = stats.beds + 1
		end
		-- Baumreihen (Allee): feste Abstände entlang einer Geraden
		for _, r in ipairs(s.rows or {}) do
			for x = r.x0, r.x1, r.step do tree(rng, x, r.z, 0.95, GREENS) end
		end
		-- freie Baumgruppen: versetztes Raster mit Zufall, Abstand zu Rand, Wegen, Teichen, Beeten
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
		-- Büsche
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
		-- Findlinge (am Ufer)
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
		-- Bänke und Leuchten entlang der Wege (Seite abwechselnd)
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
