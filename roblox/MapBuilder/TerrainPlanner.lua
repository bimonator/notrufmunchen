-- TerrainPlanner.lua
-- Liste von Terrain-Operationen (Grundfläche, Parks, Hügel, Terrasse, Isar, Bach, Tunnelgraben).
-- Reine Daten, die Builder.lua mit Terrain:FillBlock / FillCylinder ausführt. Reihenfolge ist wichtig.
-- Op: { op = "block" | "cylinder", material, pos = {x,y,z}, size = {x,y,z} | height, radius, yaw }

local Geo = require(script and script.Parent.Geo or "Geo")

local TerrainPlanner = {}

local function block(ops, material, x, y, z, sx, sy, sz, yaw)
	ops[#ops + 1] = { op = "block", material = material, pos = { Geo.round3(x), Geo.round3(y), Geo.round3(z) }, size = { sx, sy, sz }, yaw = Geo.round3(yaw or 0) }
end

-- Wasserlauf als Stapel von Schichten: Luft ausheben (Böschung), danach Wasser bis zur Wasserlinie einfüllen.
local function river(ops, rv)
	local pts, n = rv.pts, #rv.pts
	local dirs = {}
	for i = 1, n - 1 do
		local ux, uz, l = Geo.dir(pts[i][1], pts[i][2], pts[i + 1][1], pts[i + 1][2])
		dirs[i] = { ux, uz, l }
	end
	for pass = 1, 2 do -- 1 = ausheben, 2 = fluten
		for _, ly in ipairs(rv.layers) do
			local top, bot, hw = ly[1], ly[2], ly[3]
			if pass == 1 or top <= rv.waterTop then
				for i = 1, n - 1 do
					local function ext(j)
						if not dirs[j] then return 0 end
						local c = math.max(-1, math.min(1, dirs[i][1] * dirs[j][1] + dirs[i][2] * dirs[j][2]))
						return hw * math.tan(math.acos(c) / 2)
					end
					local eA, eB = (i > 1) and ext(i - 1) or 0, (i < n - 1) and ext(i + 1) or 0
					local L = dirs[i][3] + eA + eB
					local c = (dirs[i][3] + eB - eA) / 2 -- Mitte relativ zum Segmentanfang
					local x, z = pts[i][1] + dirs[i][1] * c, pts[i][2] + dirs[i][2] * c
					block(ops, pass == 1 and "Air" or "Water", x, (top + bot) / 2, z, L, top - bot, hw * 2, Geo.yawOf(dirs[i][1], dirs[i][2]))
				end
			end
		end
	end
end

function TerrainPlanner.plan(cfg)
	local ops = {}
	local m, depth, tile = cfg.map, 20, 512
	-- 1. Boden in Kacheln (ein riesiger Block wäre unhandlich)
	local x = m.xmin
	while x < m.xmax do
		local w = math.min(tile, m.xmax - x)
		local z = m.zmin
		while z < m.zmax do
			local d = math.min(tile, m.zmax - z)
			block(ops, "Pavement", x + w / 2, -depth / 2, z + d / 2, w, depth, d)
			z = z + d
		end
		x = x + w
	end
	-- 2. Grasflächen (oberste 4 Studs)
	for _, p in ipairs(cfg.parks) do
		block(ops, "Grass", (p.x0 + p.x1) / 2, -2, (p.z0 + p.z1) / 2, p.x1 - p.x0, 4, p.z1 - p.z0)
	end
	-- 3. Hügel (gestapelte Zylinder) und Terrasse
	for _, h in ipairs(cfg.hills) do
		for _, ly in ipairs(h.layers) do
			ops[#ops + 1] = { op = "cylinder", material = "Grass", pos = { h.x, (ly[2] + ly[3]) / 2, h.z }, height = ly[3] - ly[2], radius = ly[1] }
		end
	end
	local t = cfg.terrace
	block(ops, "Grass", (t.x0 + t.x1) / 2, t.height / 2, (t.z0 + t.z1) / 2, t.x1 - t.x0, t.height, t.z1 - t.z0)
	-- 4. Tunnelgraben der Siegestor-Unterführung
	local tn = cfg.tunnel
	block(ops, "Air", 0, -8.5, (tn.z0 + tn.z1) / 2, tn.half * 2, 17, tn.z1 - tn.z0)
	-- 5. Isar und Bach
	river(ops, cfg.water.isar)
	river(ops, cfg.water.bach)
	return ops
end

return TerrainPlanner
