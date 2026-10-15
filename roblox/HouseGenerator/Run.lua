-- Run.lua
-- Aufruf in der Command Bar (Studio, Edit-Modus):
--   require(game.ServerStorage.HouseGenerator.Run).run()
-- Optionen: origin (Vector3, Position des Siegestors), seed (Zahl), only ({ "B_NordMitte" })

local Planner = require(script.Parent.Planner)
local Builder = require(script.Parent.Builder)
local Blocks = require(script.Parent.Blocks)

local Run = {}

function Run.run(opts)
	opts = opts or {}
	local origin = opts.origin or Vector3.new(0, 0, 0)
	local only = {}
	for _, n in ipairs(opts.only or {}) do only[n] = true end
	local houses, parts = 0, 0
	for _, block in ipairs(Blocks) do
		if next(only) == nil or only[block.name] then
			local plan = Planner.planBlock(block, { seed = opts.seed or 1 })
			Builder.build(plan, Builder.container(block.name), origin)
			local st = Planner.stats(plan)
			houses, parts = houses + st.houses, parts + st.parts
			print(string.format("%s: %d Häuser, %d Teile", block.name, st.houses, st.parts))
		end
	end
	pcall(function() game:GetService("ChangeHistoryService"):SetWaypoint("HouseGenerator") end) -- Strg+Z
	print(string.format("Fertig: %d Häuser, %d Teile", houses, parts))
end

return Run
