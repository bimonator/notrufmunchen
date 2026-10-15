-- Tests für Planner.lua. Laufen in jedem Lua 5.1+ (kein Roblox nötig):
--   cd roblox/tests && lua planner_test.lua      (oder: python3 run_with_lupa.py)
package.path = "../MapBuilder/?.lua;MapBuilder/?.lua;roblox/MapBuilder/?.lua;" .. package.path
local Planner = require("Planner")
local Blocks = require("Blocks")
local Specials = require("Specials")

local EPS = 0.01 -- Positionen sind auf 0,001 gerundet
local failures = 0
local function check(cond, msg)
	if not cond then
		failures = failures + 1
		print("FEHLER: " .. msg)
	end
end

local function bodyOf(h)
	for _, p in ipairs(h.parts) do
		if p.name == "Body" then return p end
	end
end

local function overlap3(a, b)
	local ax0, ay0, az0, ax1, ay1, az1 = Planner.aabb(a)
	local bx0, by0, bz0, bx1, by1, bz1 = Planner.aabb(b)
	return ax0 < bx1 - EPS and bx0 < ax1 - EPS and ay0 < by1 - EPS and by0 < ay1 - EPS and az0 < bz1 - EPS and bz0 < az1 - EPS
end

local totalHouses, totalParts, totalArea = 0, 0, 0

for _, block in ipairs(Blocks) do
	local plan = Planner.planBlock(block, { seed = 1 })
	local st = Planner.stats(plan)
	totalHouses, totalParts, totalArea = totalHouses + st.houses, totalParts + st.parts, totalArea + st.footprint
	local tag = "[" .. block.name .. "] "
	check(st.houses >= 5, tag .. "zu wenige Häuser: " .. st.houses)

	-- 1. Fassadenlängen: Breiten je Seite ergeben die Seitenlänge
	local sum = { N = 0, S = 0, W = 0, E = 0 }
	for _, h in ipairs(plan.houses) do
		sum[h.side] = sum[h.side] + h.width
		check(h.width >= 24 and h.width <= 60, tag .. h.name .. " Breite " .. h.width)
		check(h.floors >= 3 and h.floors <= 6, tag .. h.name .. " Geschosse")
	end
	local lx = (block.xmax - block.xmin) - 4
	local lz = (block.zmax - block.zmin) - 4 - 56
	if not block.reserved then -- bei Sonderbauten entfallen Häuser, dann ist die Summe kleiner
		check(math.abs(sum.N - lx) < EPS and math.abs(sum.S - lx) < EPS, tag .. "N/S-Länge")
		check(math.abs(sum.W - lz) < EPS and math.abs(sum.E - lz) < EPS, tag .. "W/E-Länge")
	end
	for _, r in ipairs(block.reserved or {}) do -- nichts steht auf Sonderflächen
		for _, h in ipairs(plan.houses) do
			local x0, _, z0, x1, _, z1 = Planner.aabb(bodyOf(h))
			check(not (x0 < r[3] - 0.4 and x1 > r[1] + 0.4 and z0 < r[4] - 0.4 and z1 > r[2] + 0.4), tag .. h.name .. " steht auf der Sonderfläche")
		end
	end
	-- Abwechslung: mehrere Farben, Geschosszahlen, Dachformen und unterschiedliche Breiten
	local colors, floorSet, roofs, minW, maxW = {}, {}, {}, 1e9, 0
	for _, h in ipairs(plan.houses) do
		colors[h.facade[1] .. "," .. h.facade[2] .. "," .. h.facade[3]] = true
		floorSet[h.floors] = true
		roofs[h.roof] = true
		minW, maxW = math.min(minW, h.width), math.max(maxW, h.width)
	end
	local function count(t) local n = 0 for _ in pairs(t) do n = n + 1 end return n end
	if st.houses >= 14 then
		check(count(colors) >= 5, tag .. "zu wenige Farben: " .. count(colors))
		check(count(floorSet) >= 3, tag .. "zu wenige Geschosszahlen: " .. count(floorSet))
		check(count(roofs) >= 2, tag .. "zu wenige Dachformen: " .. count(roofs))
		check(maxW - minW >= 3, tag .. "Hausbreiten zu gleichförmig")
	end

	-- 2. Grundflächen: im Block, nicht im Innenhof, ohne Überlappung
	local cy = plan.courtyard
	for i, h in ipairs(plan.houses) do
		local b = bodyOf(h)
		check(b ~= nil, tag .. h.name .. " ohne Body")
		local x0, _, z0, x1, _, z1 = Planner.aabb(b)
		check(x0 >= block.xmin - EPS and x1 <= block.xmax + EPS and z0 >= block.zmin - EPS and z1 <= block.zmax + EPS, tag .. h.name .. " liegt außerhalb des Blocks")
		check(not (x0 < cy[3] - EPS and x1 > cy[1] + EPS and z0 < cy[4] - EPS and z1 > cy[2] + EPS), tag .. h.name .. " ragt in den Innenhof")
		for j = i + 1, #plan.houses do
			check(not overlap3(b, bodyOf(plan.houses[j])), tag .. h.name .. " überlappt " .. plan.houses[j].name)
		end
	end

	-- 3. Alle Teile höchstens 2 Studs über den Blockrand hinaus (Erker, Markisen: ragen in den 10 Studs breiten Gehweg)
	for _, h in ipairs(plan.houses) do
		for _, p in ipairs(h.parts) do
			local x0, y0, z0, x1, y1, z1 = Planner.aabb(p)
			check(x0 >= block.xmin - 2 - EPS and x1 <= block.xmax + 2 + EPS and z0 >= block.zmin - 2 - EPS and z1 <= block.zmax + 2 + EPS, tag .. h.name .. "/" .. p.name .. " ragt über den Blockrand")
			check(y0 >= 0.5 and y1 <= 90, tag .. h.name .. "/" .. p.name .. " Höhe " .. y1)
		end
		check(h.height <= 74, tag .. h.name .. " zu hoch")
	end

	-- 4. Rahmen (Fenster, Tür) liegen innerhalb der Wandfläche und überlappen sich nicht
	for _, h in ipairs(plan.houses) do
		local frames = {}
		for _, p in ipairs(h.parts) do
			if p.kind == "frame" then
				frames[#frames + 1] = p
				if string.find(p.name, "FrameSide", 1, true) then
					check(p.lpos[3] - p.size[1] / 2 >= -EPS and p.lpos[3] + p.size[1] / 2 <= h.depth + EPS, tag .. h.name .. "/" .. p.name .. " Seitenfenster außerhalb")
				else
					check(math.abs(p.lpos[1]) + p.size[1] / 2 <= h.width / 2 + EPS, tag .. h.name .. "/" .. p.name .. " Fenster/Tür außerhalb der Fassade")
				end
				check(p.lpos[2] - p.size[2] / 2 >= 1 - EPS and p.lpos[2] + p.size[2] / 2 <= 1 + h.height + EPS, tag .. h.name .. "/" .. p.name .. " Höhe")
			end
		end
		for i = 1, #frames do
			for j = i + 1, #frames do
				check(not overlap3(frames[i], frames[j]), tag .. h.name .. ": " .. frames[i].name .. " überlappt " .. frames[j].name)
			end
		end
	end

	-- 5. Eckhäuser (erstes/letztes Haus der N- und S-Seite) haben Seitenfenster, alle anderen nicht
	for _, h in ipairs(plan.houses) do
		local side = 0
		for _, p in ipairs(h.parts) do
			if string.find(p.name, "FrameSide", 1, true) then side = side + 1 end
		end
		if h.side == "W" or h.side == "E" then check(side == 0, tag .. h.name .. " hat Seitenfenster") end
	end

	-- 6. Deterministisch, und anderer Seed ändert das Ergebnis
	local again = Planner.stats(Planner.planBlock(block, { seed = 1 }))
	check(again.parts == st.parts and again.footprint == st.footprint, tag .. "nicht deterministisch")
	local other = Planner.planBlock(block, { seed = 2 })
	local differs = false
	for i, h in ipairs(other.houses) do
		if h.floors ~= plan.houses[i].floors or h.facade[1] ~= plan.houses[i].facade[1] or #h.parts ~= #plan.houses[i].parts then differs = true end
	end
	check(differs, tag .. "Seed hat keine Wirkung")

	print(string.format("%-12s %2d Häuser, %4d Teile, Grundfläche %6.0f, Innenhof %.0f x %.0f", block.name, st.houses, st.parts, st.footprint, cy[3] - cy[1], cy[4] - cy[2]))
end

-- Sonderbauten: eigene Grundfläche, kein Block-Haus darauf, keine Überlappung untereinander
do
	local plans = {}
	for _, sp in ipairs(Specials) do
		local pl = Planner.planSpecial(sp, { seed = 1 })
		local b = bodyOf(pl.houses[1])
		local x0, _, z0, x1, _, z1 = Planner.aabb(b)
		check(math.abs(x0 - sp.x0) < 0.01 and math.abs(x1 - sp.x1) < 0.01 and math.abs(z0 - sp.z0) < 0.01 and math.abs(z1 - sp.z1) < 0.01,
			sp.name .. " hat nicht die geplante Grundfläche: " .. x0 .. "," .. z0 .. "," .. x1 .. "," .. z1)
		plans[#plans + 1] = { sp = sp, b = b }
	end
	for i = 1, #plans do
		for j = i + 1, #plans do
			check(not overlap3(plans[i].b, plans[j].b), plans[i].sp.name .. " überlappt " .. plans[j].sp.name)
		end
	end
	print(string.format("Sonderbauten: %d, Grundflächen stimmen", #plans))
end

-- Eckhäuser gezielt (Block B)
do
	local plan = Planner.planBlock(Blocks[2], { seed = 1 })
	local n, s = {}, {}
	for _, h in ipairs(plan.houses) do
		if h.side == "N" then n[#n + 1] = h end
		if h.side == "S" then s[#s + 1] = h end
	end
	local function sideFrames(h)
		local c = 0
		for _, p in ipairs(h.parts) do
			if string.find(p.name, "FrameSide", 1, true) then c = c + 1 end
		end
		return c
	end
	check(sideFrames(n[1]) > 0 and sideFrames(n[#n]) > 0, "N-Eckhäuser ohne Seitenfenster")
	check(sideFrames(s[1]) > 0 and sideFrames(s[#s]) > 0, "S-Eckhäuser ohne Seitenfenster")
	if #n > 2 then check(sideFrames(n[2]) == 0, "mittleres Haus mit Seitenfenstern") end
end

print(string.format("Gesamt: %d Häuser, %d Teile, Grundfläche %.0f Studs²", totalHouses, totalParts, totalArea))
if failures > 0 then
	print(failures .. " FEHLER")
	error("Tests fehlgeschlagen")
end
print("Alle Tests bestanden")
