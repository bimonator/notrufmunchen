-- Garden.lua
-- Grünanlagen und Ausschmückung als Teileliste (reine Geometrie): Hofgarten (Wege, Dianatempel, Brunnen, Beete, Hecken, Arkaden),
-- Englischer Garten (Bäume, Wege, Bachweg), Monopteros-Tempel, Uferwege/Kiesbänke/Büsche an der Isar und der Vorplatz von Prinz Eins.
-- Teilefelder wie in den anderen Planern (name, kind, size, pos, yaw, pitch, roll, color, material, collide, shape, text, transparency, tag, attrs).

local Geo = require(script and script.Parent.Geo or "Geo")
local TerrainPlanner = require(script and script.Parent.TerrainPlanner or "TerrainPlanner")

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

-- Oberkante des Geländes am Punkt (Hügel, Terrasse, Uferstufen der Isar)
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

-- Baum: Stamm, ein bis zwei Kugelkronen
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

-- Bank: Sitzfläche, Lehne, zwei Beine; yaw = Blickrichtung wie bei Teilen (lokale x-Achse läuft entlang der Bank)
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

-- Rundpavillon: Stufen, Säulen auf einem Kreis, Gebälkring, Dach
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

-- Springbrunnen: Becken, Wasser, Mittelsäule, Strahl
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
	-- Wege: Hauptachsen, Randwege, Platz in der Mitte
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
	-- Blumenbeete in den vier Vierteln (rot, gelb, lila, weiß im Wechsel)
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
	-- Hecken entlang der Hauptachse, Lücken an Brunnen und Platz
	for x = p.x0 + 24, p.x1 - 24, 16 do
		if math.abs(x - cx) > 30 and math.abs(x - fx[1]) > 18 and math.abs(x - fx[2]) > 18 then
			for _, sd in ipairs({ -1, 1 }) do add("Hecke", "decor", x, 1.2, cz + sd * 7.5, 14, 2.4, 1.6, HEDGE, "Grass", { collide = true }) end
		end
	end
	-- Arkaden an der Nordkante: Rückwand, Säulen, Dach
	add("ArkadenWand", "decor", cx, 4.5, p.z0 - 0.5, p.x1 - p.x0 - 20, 9, 1, { 214, 196, 160 }, "Concrete", { collide = true })
	for x = p.x0 + 10, p.x1 - 10, 10 do add("ArkadenSaeule", "decor", x, 4.5, p.z0 + 3, 1.8, 9, 1.8, { 226, 214, 184 }, "Concrete", { collide = true }) end
	add("ArkadenDach", "decor", cx, 9.4, p.z0 + 1.5, p.x1 - p.x0 - 20, 0.8, 7, { 170, 90, 70 }, "Concrete", { collide = true })
	-- Bänke an den Hauptwegen
	for x = p.x0 + 36, p.x1 - 36, 44 do
		if math.abs(x - cx) > 34 and math.abs(x - fx[1]) > 20 and math.abs(x - fx[2]) > 20 then
			bench(add, x, 0, cz - 6, 180)
			bench(add, x, 0, cz + 6, 0)
		end
	end
	-- Bäume in lockerem Raster, nicht auf Wegen, Beeten, Hecken, Plätzen
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
	-- Baumreihen an den Randwegen
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
	-- Aufgang von Westen: breite Stufen über beide Terrassen des Hügels
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
	-- Weg am Bach entlang (Westufer, 20 Studs Abstand)
	local bs = TerrainPlanner.riverSamples(cfg.water.bach.pts)
	for i = 1, #bs, 2 do
		local s = bs[i]
		if s.z > p.z0 + 8 and s.z < p.z1 - 8 then
			local nx, nz = -s.uz, s.ux
			local x, z = s.x + nx * 20, s.z + nz * 20
			if free(x, z) then add("WegBach", "path", x, 0.1, z, 17, 0.5, 4, SAND, "Pavement", { yaw = Geo.yawOf(s.ux, s.uz) }) end
		end
	end
	-- Bänke am Hügel und am Hauptweg
	for _, z in ipairs({ p.z0 + 60, 140, 200, 240 }) do
		bench(add, 513, 0, z, 270)
		bench(add, 527, 0, z, 90)
	end
	-- Bäume: dicht im Westen am Bach, lichter um den Monopteros-Hügel und zum Fluss hin
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

-- Uferwege, Bänke, Büsche und Findlinge an beiden Ufern der Isar
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

-- Prinz Eins: gepflasterter Vorplatz, roter Teppich mit Absperrpfosten, Vordach, Leuchtschild, Terrassentische mit Schirmen
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
	-- Vordach auf zwei Stützen, Leuchtschild darüber
	add("Vordach", "decor", cx, 12.6, z1 + 6, 18, 0.6, 12, { 40, 32, 60 }, "Metal")
	for _, sd in ipairs({ -8.4, 8.4 }) do add("VordachStuetze", "decor", cx + sd, 6.5, z1 + 11.4, 0.6, 12, 0.6, GOLD, "Metal", { collide = true }) end
	add("TuerRahmen", "decor", cx, 6, z1 + 0.2, 10, 11, 0.5, GOLD, "Metal")
	add("Tuer", "glass", cx, 5.6, z1 + 0.5, 8.4, 10, 0.3, { 30, 36, 48 }, "Glass")
	add("Leuchtschild", "decor", cx, 18.5, z1 + 0.3, 26, 5.4, 0.6, { 26, 18, 44 }, "SmoothPlastic")
	for _, dy in ipairs({ -2.8, 2.8 }) do add("Neonleiste", "decor", cx, 18.5 + dy, z1 + 0.7, 26, 0.3, 0.3, { 255, 60, 180 }, "Neon") end
	add("Schrift", "text", cx, 18.5, z1 + 0.65, 22, 3.6, 0.2, { 255, 255, 255 }, "SmoothPlastic", { yaw = 180, text = { s = "PRINZ EINS", color = { 255, 255, 255 } } })
	-- Terrassentische mit Schirmen links und rechts
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

-- Eisbachwelle (nach Fotos): gemauerter Kanal flussabwärts der Maximilianbrücke; von der Brücke blickt man auf die stehende Welle. Die Welle besteht aus flachen,
-- schrägen Wasserplatten mit weißer Krone und Schaumflecken (keine Zylinder). Seitlich zwei Holzstege dicht über dem Wasser (Ost: Plateau, West: unter den Sitzstufen),
-- Sitzstufen mit Holzbohlen und Bänke an den Ufern, Rettungsringe (Segmente rot/weiß auf gelber Tafel). Keine Figuren. Tags Eisbachwelle und SurfZone für ein späteres
-- Surf-Skript. Lokales Maß: a = flussabwärts (nach Süden) ab der Welle, l = nach Westen (Zuschauerseite).
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

	-- Wasserplatte zwischen zwei Punkten des Längsprofils (a, y), Oberseite auf der Linie; roll neigt sie um die Querachse
	local function slab(name, a0, y0, a1, y1, th, color, transp)
		local da, dy = a1 - a0, y1 - y0
		local phi = math.atan2(dy, da)
		local x, z = at((a0 + a1) / 2 - math.sin(phi) * th / 2, wmid)
		add(name, "wave", x, (y0 + y1) / 2 + math.cos(phi) * th / 2, z, math.sqrt(da * da + dy * dy), th, ww, color, "SmoothPlastic", { yaw = yawU, roll = math.deg(phi), transparency = transp })
	end
	local WATER, FOAM = { 62, 126, 162 }, { 246, 250, 252 }

	-- Welle: Kern (unsichtbar, trägt die Tags), Anlauf, Rücken, steile Flanke, weiße Krone, Schaumflecken und zwei kleine Nachläufer
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

	-- Kanalmauern aus Naturstein an beiden Ufern; im Westen Lücke für die Sitzstufen, im Osten kleine Lücke für die Holztreppe
	local function wall(side, a0, a1)
		local x, z = at((a0 + a1) / 2, side * (hw + 1.2))
		add("Kanalmauer", "wall", x, -4.05, z, a1 - a0, 9.9, 2.4, WALL, "Cobblestone", { yaw = yawU, collide = true })
		add("Mauerkappe", "wall", x, 1.2, z, a1 - a0, 0.4, 3.0, CAP, "Concrete", { yaw = yawU, collide = true })
	end
	wall(1, -7, -3) -- Anfang jeweils hinter der Brückenkante (der Kanal verläuft schräg zur Brücke, daher im Westen später als im Osten)
	wall(1, 21, aEnd)
	wall(-1, -17, -4)
	wall(-1, 0, aEnd)
	-- Sitzstufen im Westen (a -2 bis 20): zwei Betonstufen mit Holzbohlen als Sitzfläche, darunter der West-Steg
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
	-- Holzplateau (Ost-Steg), dicht über dem Wasser: Bohlen, Randbalken, Querbalken, Pfosten, Poller
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

	-- Rettungsringe: gelbe Tafel auf einem Pfosten, davor der Ring aus 16 Segmenten (rot/weiß im Wechsel), Ebene längs des Kanals (Blick vom Ufer)
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
	-- Kastanien am Ostufer (im Park); am Westufer steht Prinz Eins
	for _, q in ipairs({ { 6, -25 }, { 18, -29 }, { 30, -26 }, { 40, -29 } }) do
		local x, z = at(q[1], q[2])
		tree(add, rngTree, x, 0, z, 1.15, "Eis")
	end
	for _, a in ipairs({ 4, 13, 22 }) do -- Bänke am Ostufer, Blick zum Wasser
		local x, z = at(a, -(hw + 4.6))
		bench(add, x, 0.5, z, math.deg(math.atan2(nx, nz)) + 180)
	end

	-- Westufer: Deck mit Geländer und drei Bänken, Schild
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

-- Biergarten um den Chinesischen Turm: Kiesfläche, Ausschank mit Schild, Bierbänke in Reihen, Kastanien am Rand
local function biergarten(cfg, add, rng, free)
	local b, t = cfg.landmarks.biergarten, cfg.landmarks.turm
	local cx, cz = (b.x0 + b.x1) / 2, (b.z0 + b.z1) / 2
	add("BiergartenKies", "plaza", cx, 0, cz, b.x1 - b.x0, 0.5, b.z1 - b.z0, { 214, 204, 176 }, "Pavement")
	-- Ausschank am Nordrand
	local kx, kz = b.x0 + 24, b.z0 + 8
	add("AusschankWand", "decor", kx, 5.2, kz, 40, 10, 12, { 240, 236, 226 }, "SmoothPlastic", { collide = true })
	add("AusschankDach", "decor", kx, 10.9, kz, 43, 0.8, 15, { 196, 84, 48 }, "Slate", { collide = true })
	for i = -1, 1 do add("Ausschankfenster", "glass", kx + i * 12, 5.5, kz + 6.1, 8, 3.6, 0.3, { 50, 62, 78 }, "Glass") end
	add("AusschankTheke", "decor", kx, 2.2, kz + 7, 38, 1.4, 1.6, { 140, 104, 70 }, "Wood", { collide = true })
	add("BiergartenSchild", "decor", kx, 8.2, kz + 6.3, 18, 2.6, 0.3, { 36, 90, 60 }, "SmoothPlastic")
	add("Schrift", "text", kx, 8.2, kz + 6.55, 16.4, 2, 0.2, { 255, 255, 255 }, "SmoothPlastic", { yaw = 180, text = { s = "BIERGARTEN", color = { 255, 255, 255 } } })
	-- Bierbänke in Reihen, um den Turm herum ausgespart
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
	-- Kastanien rund um die Fläche (Süd- und Ostkante, West- und Nordkante teilweise)
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

-- Isar-Allee: eine Baumreihe im Grünstreifen zwischen Radweg und Uferweg
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

-- Hintergärten hinter den Eckhäusern am Siegestor: je drei Bäume (Nordwest, an der x-Achse gespiegelt für Nordost)
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

-- Park hinter den Westufer-Häusern: lockere Baumgruppen auf dem Rasen (Raster 24, versetzt), nicht auf Straßen und mit Abstand zu den Hausrückseiten
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

-- nur die Teile der Eisbach-Szene (für den Schritt "eisbach", der eine fertige Karte gezielt aktualisiert); Garden.plan enthält dieselben Teile
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
