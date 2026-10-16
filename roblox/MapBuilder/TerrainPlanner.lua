-- TerrainPlanner.lua
-- Liste von Terrain-Operationen (Grundfläche, Parks, Hügel, Terrasse, Isar, Bach).
-- Reine Daten, die Builder.lua mit Terrain:FillBlock / FillCylinder ausführt. Reihenfolge ist wichtig.
-- Alle Blöcke sind achsparallel (keine Drehung): so hängt das Ergebnis nicht davon ab, wie Roblox gedrehte Blöcke füllt.
-- Op: { op = "block" | "cylinder", material, pos = {x,y,z}, size = {x,y,z} | height, radius }

local Geo = require(script and script.Parent.Geo or "Geo")

local TerrainPlanner = {}

local function block(ops, material, x, y, z, sx, sy, sz, tag)
	ops[#ops + 1] = { op = "block", material = material, pos = { Geo.round3(x), Geo.round3(y), Geo.round3(z) }, size = { Geo.round3(sx), Geo.round3(sy), Geo.round3(sz) }, yaw = 0, tag = tag }
end

-- Wasserlauf: entlang der Mittellinie in dünnen, achsparallelen Scheiben. Pro Scheibe erst die Schichten ausheben (Böschung),
-- danach Wasser bis zur Wasserlinie einfüllen. Die Scheibenbreite folgt der Laufrichtung: Breite / |Richtungsanteil|.
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
	-- Uferstufen vorab mit Sand/Gras füllen; das Ausheben unten lässt davon nur den Ring zwischen den Stufenkanten stehen
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

-- Eisbach-Kanal: wie ein Fluss (senkrechte Wände), dazu links und rechts ein Streifen Erde (bank) flussabwärts der Maximilianbrücke
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

-- nur die Kanal-Operationen (für den Schritt "kanal", wenn das übrige Terrain schon steht)
function TerrainPlanner.planKanal(cfg)
	local ops = {}
	TerrainPlanner.kanal(ops, cfg)
	return ops
end

function TerrainPlanner.plan(cfg)
	local ops = {}
	local G = cfg.groundTop
	local m, depth, tile = cfg.map, 20, 512
	-- 1. Boden in Kacheln (ein riesiger Block wäre unhandlich)
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
	-- 2. Grasflächen (oberste 4 Studs)
	for _, p in ipairs(cfg.parks) do
		block(ops, "Grass", (p.x0 + p.x1) / 2, G - 2, (p.z0 + p.z1) / 2, p.x1 - p.x0, 4, p.z1 - p.z0)
	end
	-- 3. Hügel (gestapelte Zylinder) und Terrasse, Höhen relativ zum Boden
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
	-- U-Bahn-Abgang am Marienplatz: Grube für Treppe und Podest, dahinter der Gang (Wände und Decke sind Teile aus Marienplatz.lua)
	local U = cfg.marienplatz and cfg.marienplatz.ubahn
	if U then
		block(ops, "Air", (U.x0 + U.x1) / 2, -3, (U.z0 + U.z1) / 2, U.x1 - U.x0, 18, U.z1 - U.z0, "ubahn")
		block(ops, "Air", (U.x0 + U.x1) / 2, -5.5, U.z0 - U.gang / 2, 16, 11, U.gang + 1, "ubahn")
	end
	-- U-Bahn-Abgänge am Stachus: Grube und dahinter der Gang (Wände und Decke sind Teile aus Stachus.lua)
	for _, U in ipairs(cfg.stachus and cfg.stachus.ubahn or {}) do
		block(ops, "Air", (U.x0 + U.x1) / 2, -3, (U.z0 + U.z1) / 2, U.x1 - U.x0, 18, U.z1 - U.z0, "ubahn")
		local zEnd = U.dir > 0 and U.z1 + U.gang / 2 or U.z0 - U.gang / 2
		block(ops, "Air", (U.x0 + U.x1) / 2, -5.5, zEnd, 16, 11, U.gang + 1, "ubahn")
	end
	-- 4. Isar und Bach
	cfg.water.isar.name, cfg.water.bach.name = "isar", "bach"
	river(ops, cfg.water.isar)
	river(ops, cfg.water.bach)
	if cfg.water.kanal then TerrainPlanner.kanal(ops, cfg) end
	return ops
end

return TerrainPlanner
