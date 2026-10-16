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
local LightsPlanner = require(script and script.Parent.LightsPlanner or "LightsPlanner")
local Landmarks = require(script and script.Parent.Landmarks or "Landmarks")
local Rathaus = require(script and script.Parent.Rathaus or "Rathaus")
local Marienplatz = require(script and script.Parent.Marienplatz or "Marienplatz")
local Garden = require(script and script.Parent.Garden or "Garden")
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
	lights = function(opts, origin)
		local plan = LightsPlanner.plan(Config, RoadsPlanner.plan(Config))
		Builder.buildParts(plan.parts, Builder.container("Strassenmobiliar"), origin)
		return string.format("%d Laternen, %d Ampelmasten, %d Fußgängerampeln, %d Teile", plan.stats.lamps, plan.stats.signals, plan.stats.ped, #plan.parts)
	end,
	landmarks = function(opts, origin)
		local plan = Landmarks.plan(Config)
		Builder.buildParts(plan.parts, Builder.container("Wahrzeichen"), origin)
		return string.format("%d Teile (Siegestor, Friedensengel, Frauenkirche, Chinesischer Turm)", #plan.parts)
	end,
	marienplatz = function(opts, origin)
		local folder = Builder.container("Marienplatz")
		local rh, mp = Rathaus.plan(Config), Marienplatz.plan(Config)
		Builder.buildParts(rh, folder, origin)
		Builder.buildParts(mp.parts, folder, origin)
		return string.format("%d Teile (Rathaus %d, Platz %d), %d Kugelleuchten, %d Platanen, U-Bahn-Abgang mit %d Stufen", #rh + #mp.parts, #rh, #mp.parts, mp.stats.lamps, mp.stats.trees, mp.stats.steps)
	end,
	gardens = function(opts, origin)
		local plan = Garden.plan(Config, RoadsPlanner.plan(Config), Specials)
		Builder.buildParts(plan.parts, Builder.container("Gruenanlagen"), origin)
		local st = plan.stats
		return string.format("%d Teile, %d Bäume, %d Uferweg-Platten, %d Findlinge", #plan.parts, st.hofTrees + st.egTrees, st.bank.slabs, st.bank.rocks)
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
		if next(only) == nil or only.IsarAllee then
			local plan = Planner.planAllee(Config, { seed = opts.seed or 1 })
			Builder.build(plan, Builder.container("Gebaeude", "IsarAllee"), origin)
			local st = Planner.stats(plan)
			houses, parts = houses + st.houses, parts + st.parts
		end
		if next(only) == nil or only.IsarWestufer then
			local plan = Planner.planWestbank(Config, { seed = opts.seed or 1 })
			local folder = Builder.container("Gebaeude", "IsarWestufer")
			Builder.build(plan, folder, origin)
			Builder.buildParts(plan.parts, folder, origin)
			local st = Planner.stats(plan)
			houses, parts = houses + st.houses, parts + st.parts + #plan.parts
		end
		if next(only) == nil or only.SiegestorEcken then
			local plan = Planner.planCorners(Config, { seed = opts.seed or 1 })
			Builder.build(plan, Builder.container("Gebaeude", "SiegestorEcken"), origin)
			local st = Planner.stats(plan)
			houses, parts = houses + st.houses, parts + st.parts
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

BuildAll.order = { "terrain", "roads", "lights", "landmarks", "marienplatz", "gardens", "houses", "wall" }

-- Nach dem Terrain: echte Bodenhöhe messen (alles weitere wird daran ausgerichtet) und prüfen, ob Wasser da ist.
local function afterTerrain(base)
	local ground = Builder.measureGround(base)
	print(string.format("[boden] Terrain-Oberkante gemessen: %.1f, alle weiteren Teile werden daran ausgerichtet", ground))
	local pts = Config.water.isar.pts
	local mid = pts[math.ceil(#pts / 2)]
	local water = Builder.countWater(base + Vector3.new(mid[1], Config.water.isar.waterTop - 2, mid[2]))
	if water == nil then
		print("[wasser] Auslesen nicht möglich, bitte im Studio nachsehen")
	elseif water == 0 then
		print("[wasser] KEIN Terrain-Wasser gefunden, setze blaue Ersatz-Platten (nicht schwimmbar)")
		Builder.waterFallback(pts, 38, Config.water.isar.waterTop + 0.2, base + Vector3.new(0, ground, 0))
	else
		print(string.format("[wasser] ok (%d Wasser-Zellen am Messpunkt)", water))
	end
	return ground
end

function BuildAll.run(opts)
	opts = opts or {}
	local base = opts.origin or Vector3.new(0, 0, 0)
	local steps = opts.steps or BuildAll.order
	local ground = 0
	local hasTerrain = false
	for _, n in ipairs(steps) do hasTerrain = hasTerrain or n == "terrain" end
	if not hasTerrain then ground = Builder.measureGround(base) end -- vorhandenes Terrain, z. B. beim zweiten Lauf
	for _, name in ipairs(steps) do
		local origin = base + Vector3.new(0, ground, 0)
		local ok, result = pcall(STEPS[name], opts, origin) -- ein fehlerhafter Schritt stoppt die anderen nicht
		print(string.format("[%s] %s", name, ok and result or ("FEHLER: " .. tostring(result))))
		if name == "terrain" and ok then
			local ok2, g = pcall(afterTerrain, base)
			if ok2 then ground = g else print("[boden] FEHLER: " .. tostring(g)) end
		end
	end
	if opts.controllerSource then -- Plugin: Ampel-Skript dauerhaft anlegen
		local ok, err = pcall(Builder.installController, opts.controllerSource)
		print(ok and "[ampel] Script AmpelSteuerung in ServerScriptService angelegt" or ("[ampel] FEHLER: " .. tostring(err)))
	end
	if opts.afterBuild then opts.afterBuild() print("[ampel] läuft (nur bis zum Stoppen)") end -- Test-Script
	pcall(function() game:GetService("ChangeHistoryService"):SetWaypoint("MapBuilder") end) -- Strg+Z
	print("Fertig")
end

return BuildAll
