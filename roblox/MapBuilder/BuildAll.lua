-- BuildAll.lua
-- Baut die Karte in einem Rutsch oder schrittweise. Aufruf (Command Bar, Edit-Modus):
--   require(game.ServerStorage.MapBuilder.BuildAll).run()
--   require(game.ServerStorage.MapBuilder.BuildAll).run({ steps = { "roads" } })
-- Optionen: steps (Standard alle), origin (Vector3, Position des Siegestors), seed, only (Blocknamen für "houses"), clearTerrain (true/false)

local Config = require(script and script.Parent.Config or "Config")
local Blocks = require(script and script.Parent.Blocks or "Blocks")
local Planner = require(script and script.Parent.Planner or "Planner")
local Specials = require(script and script.Parent.Specials or "Specials")
local RoadsPlanner = require(script and script.Parent.RoadsPlanner or "RoadsPlanner")
local TerrainPlanner = require(script and script.Parent.TerrainPlanner or "TerrainPlanner")
local WallPlanner = require(script and script.Parent.WallPlanner or "WallPlanner")
local Builder = require(script and script.Parent.Builder or "Builder")

local BuildAll = {}

local STEPS = {
	terrain = function(opts, origin)
		if opts.clearTerrain ~= false then Builder.clearTerrain() end
		local ops = TerrainPlanner.plan(Config)
		Builder.applyTerrain(ops, origin)
		return string.format("%d Terrain-Operationen", #ops)
	end,
	roads = function(opts, origin)
		local plan = RoadsPlanner.plan(Config)
		Builder.buildParts(plan.parts, Builder.container("Strassen"), origin)
		return string.format("%d Teile, %d Parkbuchten", #plan.parts, plan.stats.bays)
	end,
	houses = function(opts, origin)
		local only, houses, parts = {}, 0, 0
		for _, n in ipairs(opts.only or {}) do only[n] = true end
		for _, block in ipairs(Blocks) do
			if next(only) == nil or only[block.name] then
				local plan = Planner.planBlock(block, { seed = opts.seed or 1 })
				Builder.build(plan, Builder.container("Gebaeude", block.name), origin)
				local st = Planner.stats(plan)
				houses, parts = houses + st.houses, parts + st.parts
			end
		end
		if next(only) == nil then
			local folder = Builder.container("Gebaeude", "Sonderbauten")
			for _, spec in ipairs(Specials) do
				local plan = Planner.planSpecial(spec, { seed = opts.seed or 1 })
				Builder.build(plan, folder, origin)
				local st = Planner.stats(plan)
				houses, parts = houses + st.houses, parts + st.parts
			end
		end
		return string.format("%d Häuser, %d Teile", houses, parts)
	end,
	wall = function(opts, origin)
		local plan = WallPlanner.plan(Config, { seed = opts.seed or 1 })
		local folder = Builder.container("Mapgrenze")
		Builder.build(plan, folder, origin)
		Builder.buildParts(plan.parts, folder, origin)
		local st = Planner.stats(plan)
		return string.format("%d Gebäude, %d Teile", st.houses, st.parts + #plan.parts)
	end,
}

BuildAll.order = { "terrain", "roads", "houses", "wall" }

function BuildAll.run(opts)
	opts = opts or {}
	local origin = opts.origin or Vector3.new(0, 0, 0)
	for _, name in ipairs(opts.steps or BuildAll.order) do
		local ok, result = pcall(STEPS[name], opts, origin) -- ein fehlerhafter Schritt stoppt die anderen nicht
		print(string.format("[%s] %s", name, ok and result or ("FEHLER: " .. tostring(result))))
	end
	pcall(function() game:GetService("ChangeHistoryService"):SetWaypoint("MapBuilder") end) -- Strg+Z
	print("Fertig")
end

return BuildAll
