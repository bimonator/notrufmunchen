-- WallPlanner.lua
-- Mapgrenze: durchgehendes Häuserband (60 tief, ca. 74-110 hoch) rund um die Ringstraße, Fassade zur Straße.
-- Lücken für Querriegel (Nord), Feldherrnhalle (Süd) und die zwei Flusstore (Brückenhäuser mit Gitter).

local Planner = require(script and script.Parent.Planner or "Planner")
local Geo = require(script and script.Parent.Geo or "Geo")

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
	-- Flusstore: Gebäude über dem Wasser (ab Höhe 22) und ein Gitter an der Kartenkante
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
