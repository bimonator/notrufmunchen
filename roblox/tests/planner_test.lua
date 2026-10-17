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

	-- 7. Hinterhäuser im Innenhof: im Hof, 2-3 Geschosse, Gasse >= 10 zu Randhäusern, Sonderflächen und Grundstück bleiben frei
	check(block.noInner == nil or #plan.inner == 0, tag .. "Hinterhäuser trotz noInner")
	for i, h in ipairs(plan.inner) do
		local b = bodyOf(h)
		local x0, _, z0, x1, _, z1 = Planner.aabb(b)
		check(x0 >= cy[1] - EPS and x1 <= cy[3] + EPS and z0 >= cy[2] - EPS and z1 <= cy[4] + EPS, tag .. h.name .. " liegt nicht im Innenhof")
		check(h.floors >= 2 and h.floors <= 3, tag .. h.name .. " Geschosse " .. h.floors)
		for _, o in ipairs(plan.houses) do
			local ox0, _, oz0, ox1, _, oz1 = Planner.aabb(bodyOf(o))
			local gx, gz = math.max(ox0 - x1, x0 - ox1), math.max(oz0 - z1, z0 - oz1)
			check(math.max(gx, gz) >= 10, tag .. h.name .. " zu dicht an " .. o.name)
		end
		for j = i + 1, #plan.inner do
			local ox0, _, oz0, ox1, _, oz1 = Planner.aabb(bodyOf(plan.inner[j]))
			check(math.max(ox0 - x1, x0 - ox1, oz0 - z1, z0 - oz1) >= 10, tag .. h.name .. " zu dicht an " .. plan.inner[j].name)
		end
		local avoid = {}
		for _, r in ipairs(block.reserved or {}) do avoid[#avoid + 1] = r end
		if block.lot then avoid[#avoid + 1] = block.lot end
		for _, r in ipairs(avoid) do
			check(not (x0 < r[3] + 9 and x1 > r[1] - 9 and z0 < r[4] + 9 and z1 > r[2] - 9), tag .. h.name .. " steht auf Sonderfläche/Grundstück")
		end
	end
	if block.name == "G_LeopoldOst" then
		local lane = block.reserved[1] -- Zufahrt zur Tankstelle bleibt frei
		for _, h in ipairs(plan.houses) do
			local x0, _, z0, x1, _, z1 = Planner.aabb(bodyOf(h))
			check(not (x0 < lane[3] - 0.05 and x1 > lane[1] + 0.05 and z0 < lane[4] - 0.05 and z1 > lane[2] + 0.05), tag .. h.name .. " steht vor der Tankstelle")
		end
	end
	-- 8. Rückseiten haben Fenster und eine Hintertür
	for _, h in ipairs(plan.houses) do
		local back, door = 0, false
		for _, p in ipairs(h.parts) do
			if string.find(p.name, "GlassR", 1, true) == 1 then back = back + 1 end
			if p.name == "BackDoor" then door = true end
		end
		check(back >= h.floors and door, tag .. h.name .. " ohne Rückfenster/Hintertür")
	end

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
	for _, pl in ipairs(plans) do -- Tankstelle: Schirm 68 breit, Shop schließt an die schmale Seite an, zwei Einfahrten zur Straße
		local sp = pl.sp
		if sp.lot then
			local c = sp.canopy
			check(c[3] - c[1] >= 66, "Schirm nicht doppelt so breit: " .. (c[3] - c[1]))
			check(c[1] >= sp.lot[1] and c[3] <= sp.lot[3] and c[2] >= sp.lot[2] and c[4] <= sp.lot[4], "Schirm außerhalb des Grundstücks")
			check(sp.x0 >= sp.lot[1] and sp.x1 <= sp.lot[3] and sp.z0 >= sp.lot[2] and sp.z1 <= sp.lot[4], "Shop außerhalb des Grundstücks")
			check(math.abs(sp.z1 - c[2]) < 0.01 and sp.x0 == c[1] and sp.x1 == c[3], "Shop schließt nicht an die schmale Seite des Schirms an (Nordende)")
			check(#sp.curbGaps == 2 and sp.curbGaps[1][2] - sp.curbGaps[1][1] >= 28 and sp.curbGaps[2][2] - sp.curbGaps[2][1] >= 28, "Einfahrten zu schmal")
			check(sp.lot[1] <= 58, "Grundstück liegt nicht an der Straße")
			check(sp.z1 <= c[2] + 0.01 and sp.curbGaps[2][1] > c[4], "Shop nicht gegenüber der Einfahrt")
		end
	end
	for i = 1, #plans do
		for j = i + 1, #plans do
			check(not overlap3(plans[i].b, plans[j].b), plans[i].sp.name .. " überlappt " .. plans[j].sp.name)
		end
	end
	print(string.format("Sonderbauten: %d, Grundflächen stimmen", #plans))
end

-- Sonderbauten nach Fotovorlagen: Schrift, Tore, Durchfahrt, Glasturm
do
	local function parts(name)
		for _, sp in ipairs(Specials) do
			if sp.name == name then return Planner.planSpecial(sp, { seed = 1 }).houses[1].parts end
		end
	end
	local function count(ps, name) local n = 0 for _, p in ipairs(ps) do if p.name == name then n = n + 1 end end return n end
	local function texts(ps) local t = {} for _, p in ipairs(ps) do if p.text then t[#t + 1] = p.text.s end end return table.concat(t, "|") end
	local wache = parts("Feuer-und-Rettungswache")
	check(count(wache, "Pfeiler") == 10, "Wache: 4 Tore vorn und hinten = 10 Pfeiler, ist " .. count(wache, "Pfeiler"))
	check(string.find(texts(wache), "FEUERWACHE", 1, true) and string.find(texts(wache), "RETTUNGSWACHE", 1, true), "Wache: Schrift fehlt")
	check(count(wache, "TopBlock") == 1 and count(wache, "Hallenboden") == 1, "Wache: Kopfbau/Halle fehlt")
	local pol = parts("Polizeiwache")
	check(string.find(texts(pol), "POLIZEI", 1, true) ~= nil and count(pol, "PolizeiSchild") == 1, "Polizei: Schild fehlt")
	local l, r
	for _, p in ipairs(pol) do
		if p.name == "GroundL" then l = p end
		if p.name == "GroundR" then r = p end
	end
	check(l and r and math.abs((r.lpos[1] - r.size[1] / 2) - (l.lpos[1] + l.size[1] / 2) - 14) < EPS, "Polizei: Durchfahrt nicht 14 breit")
	local tank = parts("Tankstellen-Shop")
	local glass, white = 0, 0
	for _, p in ipairs(tank) do
		if p.name == "ShopGlas" then glass = glass + 1 end
		if p.name == "ShopHinterwand" and p.color[1] == 250 then white = white + 1 end
		check(not (p.color[3] > 150 and p.color[3] > p.color[1] + 40 and p.name:find("Shop", 1, true)), "Shop darf nicht blau sein: " .. p.name)
	end
	check(glass >= 4 and white == 1, "Shop: Glasfront/weiße Wände fehlen")
	-- Allguth nach Fotos: Rasenstreifen (2 Abschnitte, nicht an den Einfahrten), Preis-Totem, Schirm mit Rundung, Schriftzug, 8 Stützen
	local lawn, hedge, prices, brand, pillars, arcs, roundRoofs, totemH, logoA = 0, 0, 0, 0, 0, 0, 0, 0, 0
	local lot = nil
	for _, sp in ipairs(Specials) do if sp.lot then lot = sp end end
	for _, p in ipairs(tank) do
		if p.name == "Rasen" then
			lawn = lawn + 1
			for _, g in ipairs(lot.curbGaps) do check(not (p.pos[3] + p.size[3] / 2 > g[1] and p.pos[3] - p.size[3] / 2 < g[2]), "Rasen liegt in der Einfahrt") end
		end
		if p.name == "Hecke" then hedge = hedge + 1 end
		if p.tag == "FuelPrice" then prices = prices + 1 end
		if p.name == "Schrift" and p.text and p.text.s == "A" then brand = brand + 1 end
		if p.text and string.find(p.text.s, "ALLGUTH", 1, true) then check(false, "Firmenname ALLGUTH nicht gewünscht") end
		if p.name == "CanopyPillar" then pillars = pillars + 1 end
		if p.name == "CanopyBand" and p.yaw ~= 0 and p.yaw ~= 90 and p.yaw ~= 180 and p.yaw ~= 270 then arcs = arcs + 1 end
		if p.name == "CanopyRoofRund" then roundRoofs = roundRoofs + 1 end
		if p.name == "TotemPylon" then totemH = p.size[2] end
		if p.name == "LogoA" then logoA = logoA + 1 end
	end
	check(lawn == 2 and hedge >= 6, "Rasen/Hecke: " .. lawn .. "/" .. hedge)
	check(prices == 10, "Preiszeilen " .. prices .. " (5 Sorten, beide Seiten)")
	check(brand >= 8, "A-Logos " .. brand)
	check(pillars == 8 and roundRoofs == 2 and arcs >= 12, "Schirm: Stützen " .. pillars .. ", Rundungen " .. roundRoofs .. ", Bogenstücke " .. arcs)
	check(totemH >= 30, "Totem zu niedrig " .. totemH)
	check(logoA == 0, "altes Dach-A noch vorhanden")
	-- Parkplätze im Südteil (gegenüber der schmalen Südseite des Schirms): 10 Plätze = 1 Behinderten-, 3 Lade- und 6 normale Plätze; die Ladeplätze haben je eine Säule
	-- (Tag EVCharger) und keine Überdachung; alle Teile liegen im Grundstück südlich des Schirms
	local pk = lot.parking
	local kindsN = { H = 0, E = 0, N = 0 }
	for _, k in ipairs(pk.kinds) do kindsN[k] = kindsN[k] + 1 end
	local stalls, handi, chargers, lines, signs = 0, 0, 0, 0, 0
	for _, p in ipairs(tank) do
		if p.name == "EVStellplatz" then stalls = stalls + 1 end
		if p.name == "BehindertenStellplatz" then handi = handi + 1 end
		if p.tag == "EVCharger" then chargers = chargers + 1 end
		if p.name == "StellplatzLinie" then lines = lines + 1 end
		if p.name == "RollstuhlSchild" then signs = signs + 1 end
		if p.name == "StellplatzLinie" or p.name == "EVStellplatz" or p.name == "BehindertenStellplatz" or p.name == "EVSaeule" then
			check(p.pos[3] - p.size[3] / 2 >= lot.canopy[4] + 20 and p.pos[3] + p.size[3] / 2 <= lot.lot[4] and p.pos[1] - p.size[1] / 2 >= lot.lot[1] + 20 and p.pos[1] + p.size[1] / 2 <= lot.lot[3], "Parkplatz: " .. p.name .. " liegt nicht im Südteil des Grundstücks")
		end
		check(string.sub(p.name, 1, 2) ~= "EV" or (p.name ~= "EVDach" and p.name ~= "EVPfosten" and p.name ~= "EVBlende"), "Ladeplätze dürfen keine Überdachung haben")
	end
	check(kindsN.H == 1 and kindsN.E == 3 and kindsN.N == 6, "Plätze nach Art: " .. kindsN.H .. "/" .. kindsN.E .. "/" .. kindsN.N)
	check(stalls == 3 and handi == 1 and chargers == 3 and lines == #pk.kinds + 1 and signs == 1, "Parkplätze: Ladeplätze " .. stalls .. ", Behinderten " .. handi .. ", Säulen " .. chargers .. ", Linien " .. lines .. ", Schilder " .. signs)
	local offices = 0
	for _, sp in ipairs(Specials) do if sp.style == "buero" then offices = offices + 1 end end
	check(offices == 3, "Hintergrundgebäude " .. offices)
	local gates = 0
	for _, p in ipairs(wache) do
		if p.tag == "FireGate" then gates = gates + 1 check(not p.collide, "Tor kollidiert") end
	end
	check(gates >= 8 * 5, "Wache: Tore " .. gates)
	local arms, spawns = 0, 0
	for _, p in ipairs(pol) do
		if p.tag == "Schranke" then arms = arms + 1 end
		if p.tag == "VehicleSpawn" then spawns = spawns + 1 end
	end
	check(arms == 8 and spawns == 4, "Polizeihof: Schranken-Arme " .. arms .. ", Spawns " .. spawns)
	local klinik = parts("Krankenhaus")
	check(count(klinik, "Glasturm") == 1 and string.find(texts(klinik), "KLINIKUM", 1, true) ~= nil, "Klinikum: Glasturm/Schrift fehlt")
	check(count(klinik, "Geschossplatte") == 8, "Klinikum: 4 Geschossplatten je Seite, ist " .. count(klinik, "Geschossplatte"))
	for _, ps in ipairs({ wache, pol, klinik }) do
		for _, p in ipairs(ps) do
			local _, y0, _, _, y1 = Planner.aabb(p)
			check(y1 <= 90 and y0 >= -0.5, p.name .. " Höhe " .. y0 .. ".." .. y1)
		end
	end
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

do -- Stilvarianten: alle fünf kommen vor
	local seen, total = {}, 0
	for _, block in ipairs(Blocks) do
		for _, h in ipairs(Planner.planBlock(block, { seed = 1 }).houses) do seen[h.variant] = (seen[h.variant] or 0) + 1 total = total + 1 end
	end
	for _, v in ipairs({ "plain", "palazzo", "erker", "jugend", "modern" }) do check((seen[v] or 0) >= 3, "Stilvariante " .. v .. " zu selten: " .. (seen[v] or 0)) end
	print(string.format("Varianten: plain %d, palazzo %d, erker %d, jugend %d, modern %d", seen.plain or 0, seen.palazzo or 0, seen.erker or 0, seen.jugend or 0, seen.modern or 0))
end
print(string.format("Gesamt: %d Häuser, %d Teile, Grundfläche %.0f Studs²", totalHouses, totalParts, totalArea))
-- ===== Isar-Allee: Häuserzeile mit Backsteinkirche =====
do
	local Config = require("Config")
	local RoadsPlanner = require("RoadsPlanner")
	local segs = RoadsPlanner.segments(Config)
	local plan = Planner.planAllee(Config, { seed = 1 })
	local a = Config.allee
	local nx, nz = -a.uz, a.ux
	local half = Config.profiles.allee.half
	local function across(x, z) return (x - a.ax) * nx + (z - a.az) * nz end
	local function along(x, z) return (x - a.ax) * a.ux + (z - a.az) * a.uz end
	local houses, church = 0, nil
	local order = {}
	for _, h in ipairs(plan.houses) do
		if string.find(h.name, "Kirche", 1, true) then church = h else houses = houses + 1 end
		order[#order + 1] = { s = along(h.ox, h.oz), w = h.width, name = h.name }
		for _, p in ipairs(h.parts) do -- Erker, Balkone und Markisen dürfen über den Gehweg ragen (bis -27,5 = Fahrbahnrand), nie in die Fahrbahn
			check(across(p.pos[1], p.pos[3]) <= -28, "Allee: " .. h.name .. "/" .. p.name .. " liegt in der Straße (" .. across(p.pos[1], p.pos[3]) .. ")")
		end
		local body = bodyOf(h)
		local r, c, s = math.rad(h.yaw), 0, 0
		c, s = math.cos(r), math.sin(r)
		for _, lx in ipairs({ -h.width / 2, h.width / 2 }) do
			for _, lz in ipairs({ 0, h.depth }) do -- Eckpunkte des Grundrisses in Weltkoordinaten: keine liegt in einer anderen Straße
				local x, z = h.ox + lx * c + lz * s, h.oz - lx * s + lz * c
				for _, sg in ipairs(segs) do
					local rc = sg.rect
					local dx, dz = x - rc.ax, z - rc.az
					local aa, bb = dx * rc.ux + dz * rc.uz, dx * rc.nx + dz * rc.nz
					check(not (aa > rc.s0 and aa < rc.s1 and math.abs(bb) < rc.w), "Allee: " .. h.name .. " liegt in der Straße " .. sg.road.name)
				end
			end
		end
		check(body ~= nil, "Allee: " .. h.name .. " ohne Body")
	end
	check(houses >= 10 and houses <= 12, "Allee: Häuser " .. houses)
	table.sort(order, function(p, q) return p.s < q.s end)
	for i = 2, #order do
		check(order[i].s - order[i - 1].s >= (order[i].w + order[i - 1].w) / 2 - 0.05, "Allee: " .. order[i].name .. " überlappt " .. order[i - 1].name)
	end
	check(order[1].s - order[1].w / 2 >= a.rowFrom - 0.5 and order[#order].s + order[#order].w / 2 <= a.rowTo + 0.5, "Allee: Zeile außerhalb des Bereichs")
	check(church ~= nil, "Allee: Kirche fehlt")
	if church then
		local maxY, helm, hands, bricks, windows = 0, 0, 0, 0, 0
		for _, p in ipairs(church.parts) do
			maxY = math.max(maxY, p.pos[2] + p.size[2] / 2)
			if p.name == "Turmhelm" then helm = helm + 1 end
			if p.name == "Uhrzeiger" then hands = hands + 1 end
			if p.material == "Brick" and p.color[1] > 120 and p.color[1] < 170 and p.color[2] < 90 then bricks = bricks + 1 end
			if p.tag == "HouseWindow" then windows = windows + 1 end
		end
		check(maxY > 110 and maxY < 140, "Kirche: Höhe " .. maxY)
		check(helm > 18 * 3 and hands == 2 and bricks >= 8 and windows >= 20, "Kirche: Helm " .. helm .. ", Zeiger " .. hands .. ", Ziegel " .. bricks .. ", Fenster " .. windows)
		check(math.abs(along(church.ox, church.oz) - (a.church[1] + a.church[2]) / 2) < 0.5, "Kirche: Lage in der Zeile")
	end
	print(string.format("Isar-Allee: %d Häuser, Kirche mit %d Teilen", houses, church and #church.parts or 0))
end

-- ===== "Kaffeehaus Odeon" (keine echten Markennamen/Logos) =====
do
	local function named(sname)
		for _, sp in ipairs(Specials) do if sp.name == sname then return Planner.planSpecial(sp, { seed = 1 }).houses[1].parts end end
	end
	local function n(list, name) local c = 0 for _, p in ipairs(list) do if p.name == name then c = c + 1 end end return c end
	local function hasText(list, s) for _, p in ipairs(list) do if p.text and string.find(p.text.s, s, 1, true) then return true end end return false end
	local c = named("Kaffeehaus")
	check(c and not named("Casino-Odeon"), "Kaffeehaus fehlt oder Casino-Odeon noch da")
	check(hasText(c, "KAFFEEHAUS ODEON") and n(c, "Tisch") == 8 and n(c, "Schirm") == 4 and n(c, "Kaffeetuer") == 2 and n(c, "SchildBohne") == 1, "Kaffeehaus: Schrift/Tische/Schirme/Tür/Schild unvollständig")
	-- 50 % größer als vorher (Kino 70x60 -> 105x90, Café 60x40 -> 90x60) und je ein Parkplatz daneben
	for _, nm in ipairs({ "Kaffeehaus" }) do
		for _, sp in ipairs(Specials) do
			if sp.name == nm then
				local a, b = sp.x1 - sp.x0, sp.z1 - sp.z0
				check(a * b >= (nm == "Casino-Odeon" and 70 * 60 or 60 * 40) * 2.2, nm .. " ist nicht 50 % größer")
				check(sp.lots and #sp.lots == 1, nm .. " ohne Parkplatz")
				local lt = named(nm)
				local lines = 0
				for _, p in ipairs(lt) do if p.name == "StellplatzLinie" then lines = lines + 1 end end
				check(lines >= 10, nm .. ": Stellplatzlinien " .. lines)
			end
		end
	end
	for _, list in ipairs({ c }) do
		check(not hasText(list, "STARBUCKS") and not hasText(list, "Starbucks"), "echter Markenname im Bauwerk")
	end
end

-- ===== Klinikum-Parkhaus, Volksbank, Prinz Eins (50 % größer, mit Parkplatz) =====
do
	local function spec(nm) for _, sp in ipairs(Specials) do if sp.name == nm then return sp end end end
	local function parts2(nm) return Planner.planSpecial(spec(nm), { seed = 1 }).houses[1].parts end
	local function n(list, name) local c = 0 for _, p in ipairs(list) do if p.name == name then c = c + 1 end end return c end
	local kl, ph, bk, pe = spec("Krankenhaus"), spec("Klinikum-Parkhaus"), spec("Volksbank"), spec("Prinz-Eins")
	check(ph.x0 == kl.x1 and ph.z0 == kl.z0 and ph.z1 == kl.z1 and ph.x1 - ph.x0 == kl.x1 - kl.x0, "Parkhaus grenzt nicht in gleicher Größe an das Klinikum")
	local pk = parts2("Klinikum-Parkhaus")
	local maxY = 0
	for _, p in ipairs(pk) do maxY = math.max(maxY, p.pos[2] + p.size[2] / 2) end
	check(n(pk, "Parkdeck") == 3 and n(pk, "Stuetze") == 3 * 35 and n(pk, "Auffahrt") == 1 and n(pk, "Schranke") == 8 and maxY > 33 and maxY < 40, "Parkhaus: Decks " .. n(pk, "Parkdeck") .. ", Stützen " .. n(pk, "Stuetze") .. ", Höhe " .. maxY)
	check(n(pk, "StellplatzLinie") == 3 * 56, "Parkhaus: Stellplatzlinien " .. n(pk, "StellplatzLinie"))
	local bank = parts2("Volksbank")
	local txt = false
	for _, p in ipairs(bank) do if p.text and p.text.s == "Volksbank" then txt = true end end
	check(txt and n(bank, "Geldautomat") == 2 and n(bank, "Drehtuer") == 1, "Volksbank: Schriftzug/Geldautomaten/Tür fehlen")
	check((pe.x1 - pe.x0) == 84 and pe.floors == 3 and pe.lots and #pe.lots == 1, "Prinz Eins nicht vergrößert oder ohne Parkplatz")
	-- keine Überlappung der neuen Flächen untereinander und mit anderen Sonderbauten
	local rects = {}
	for _, sp in ipairs(Specials) do
		rects[#rects + 1] = { sp.name, sp.x0, sp.z0, sp.x1, sp.z1 }
		for i, r in ipairs(sp.lots or {}) do rects[#rects + 1] = { sp.name .. "-Parkplatz" .. i, r[1], r[2], r[3], r[4] } end
	end
	for i = 1, #rects do
		for j = i + 1, #rects do
			local a, b = rects[i], rects[j]
			check(not (a[2] < b[4] - 0.01 and a[4] > b[2] + 0.01 and a[3] < b[5] - 0.01 and a[5] > b[3] + 0.01), "Überlappung: " .. a[1] .. " und " .. b[1])
		end
	end
end

-- ===== Eckhäuser am Siegestor =====
do
	local Config = require("Config")
	local RoadsPlanner = require("RoadsPlanner")
	local segs = RoadsPlanner.segments(Config)
	local plan = Planner.planCorners(Config, { seed = 1 })
	local bodies = {}
	for _, block in ipairs(Blocks) do
		for _, h in ipairs(Planner.planBlock(block, { seed = 1 }).houses) do bodies[#bodies + 1] = { Planner.aabb(bodyOf(h)) } end
	end
	for _, sp in ipairs(Specials) do bodies[#bodies + 1] = { sp.x0, 0, sp.z0, sp.x1, 0, sp.z1 } end
	local names = {}
	for _, h in ipairs(plan.houses) do
		names[#names + 1] = h.name
		local r, c, s = math.rad(h.yaw), 0, 0
		c, s = math.cos(r), math.sin(r)
		local cxs = Config.landmarks.siegestor
		for _, lx in ipairs({ -h.width / 2, 0, h.width / 2 }) do
			for _, lz in ipairs({ 0, h.depth }) do
				local x, z = h.ox + lx * c + lz * s, h.oz - lx * s + lz * c
				for _, sg in ipairs(segs) do
					local rc = sg.rect
					local dx, dz = x - rc.ax, z - rc.az
					local aa, bb = dx * rc.ux + dz * rc.uz, dx * rc.nx + dz * rc.nz
					check(not (aa > rc.s0 and aa < rc.s1 and math.abs(bb) < rc.w), "Eckhaus " .. h.name .. " liegt in der Straße " .. sg.road.name)
				end
				for _, b in ipairs(bodies) do
					check(not (x > b[1] - 0.3 and x < b[4] + 0.3 and z > b[3] - 0.3 and z < b[6] + 0.3), "Eckhaus " .. h.name .. " überlappt ein Gebäude bei " .. x .. "," .. z)
				end
				if lz == 0 then check(math.abs(math.sqrt((x - cxs.x) ^ 2 + (z - cxs.z) ^ 2) - 92) < 1.2, "Eckhaus-Fassade nicht auf dem Kreis") end
			end
		end
	end
	check(#plan.houses >= 6 and #plan.houses <= 10, "Eckhäuser: " .. #plan.houses)
end

-- ===== Westufer der Isar gegenüber der Allee: Häuserzeile, Ufergehweg, Baumreihe =====
do
	local Config = require("Config")
	local Geo = require("Geo")
	local RoadsPlanner = require("RoadsPlanner")
	local segs = RoadsPlanner.segments(Config)
	local plan = Planner.planWestbank(Config, { seed = 1 })
	local houses = #plan.houses
	check(houses >= 5 and houses <= 7, "Westufer: Häuser " .. houses)
	local isar = Config.water.isar
	for _, h in ipairs(plan.houses) do
		local r, c, s = math.rad(h.yaw), 0, 0
		c, s = math.cos(r), math.sin(r)
		for _, lx in ipairs({ -h.width / 2, h.width / 2 }) do
			for _, lz in ipairs({ -3, h.depth }) do -- Eckpunkte inkl. Erker/Vordächer: nicht in der Böschung, nicht in Straßen
				local x, z = h.ox + lx * c + lz * s, h.oz - lx * s + lz * c
				check(Geo.polyDist(x, z, isar.pts) > isar.layers[1][3] + 20, "Westufer: " .. h.name .. " zu nah an der Isar (" .. Geo.polyDist(x, z, isar.pts) .. ")")
				for _, sg in ipairs(segs) do
					local rc = sg.rect
					local dx, dz = x - rc.ax, z - rc.az
					local aa, bb = dx * rc.ux + dz * rc.uz, dx * rc.nx + dz * rc.nz
					check(not (aa > rc.s0 and aa < rc.s1 and math.abs(bb) < rc.w), "Westufer: " .. h.name .. " liegt in der Straße " .. sg.road.name)
				end
			end
		end
	end
	local trunks, walk = 0, false
	for _, p in ipairs(plan.parts) do
		if p.name == "WestuferStamm" then
			trunks = trunks + 1
			check(Geo.polyDist(p.pos[1], p.pos[3], isar.pts) > isar.layers[1][3] + 3, "Westufer: Baum in der Böschung")
		end
		if p.name == "WestuferGehweg" then
			walk = true
			check(Geo.polyDist(p.pos[1], p.pos[3], isar.pts) > isar.layers[1][3] + 3, "Westufer: Gehweg in der Böschung")
		end
	end
	check(trunks >= 6 and walk, "Westufer: Bäume " .. trunks)
end

-- ===== Stachus =====
do
	local Config = require("Config")
	local Stachus = require("Stachus")
	local S = Config.stachus
	local plan = Stachus.plan(Config)
	local st = plan.stats
	local texts, passage, outside = {}, 0, 0
	for _, p in ipairs(plan.parts) do
		local hx, hz = p.size[1] / 2, p.size[3] / 2
		if p.yaw % 180 == 90 then hx, hz = hz, hx end
		if p.yaw % 90 ~= 0 then hx = math.max(hx, hz) hz = hx end
		if p.shape == "Cylinder" and p.roll == 90 then hx, hz = p.size[2] / 2, p.size[2] / 2 end
		if p.pitch ~= 0 then -- geneigte Platten (Dach, Markise): waagerechte Ausdehnung
			local c, sn = math.abs(math.cos(math.rad(p.pitch))), math.abs(math.sin(math.rad(p.pitch)))
			if p.yaw % 180 == 90 then hx = hx * c + p.size[2] / 2 * sn else hz = hz * c + p.size[2] / 2 * sn end
		end
		if not string.find(p.name, "^Taxi") and p.name ~= "Fuge" and p.name ~= "Pflaster" then
			if p.pos[1] - hx < S.x0 - 0.5 or p.pos[1] + hx > S.x1 + 0.5 or p.pos[3] - hz < S.z0 - 0.5 or p.pos[3] + hz > S.z1 + 0.5 then
				outside = outside + 1
				if outside <= 5 then print("außerhalb: " .. p.name .. " " .. p.pos[1] .. "," .. p.pos[3]) end
			end
		end
		if p.text then texts[p.text.s] = (texts[p.text.s] or 0) + 1 end
		-- Durchgang des Karlstors frei: |z - cz| < 6, y < 12 über dem Pflaster, x im Torbau
		if p.collide and math.abs(p.pos[1] - (S.x0 + S.depth / 2)) < 11 and p.pos[2] - p.size[2] / 2 < 12 and p.pos[2] + p.size[2] / 2 > 2 and math.abs(p.pos[3] - S.cz) - hz < 5.5 and not string.find(p.name, "^Gebaeude") then
			passage = passage + 1
			print("Durchgang blockiert: " .. p.name)
		end
	end
	for _, p in ipairs(plan.parts) do -- Pflaster liegt nicht über den U-Bahn-Gruben
		if p.name == "Pflaster" then
			local x0, z0, x1, z1 = p.pos[1] - p.size[1] / 2, p.pos[3] - p.size[3] / 2, p.pos[1] + p.size[1] / 2, p.pos[3] + p.size[3] / 2
			for _, U in ipairs(S.ubahn) do check(not (x0 < U.x1 - 0.01 and x1 > U.x0 + 0.01 and z0 < U.z1 - 0.01 and z1 > U.z0 + 0.01), "Stachus: Pflaster über der U-Bahn-Grube") end
		end
	end
	local steps = 0
	for _, p in ipairs(plan.parts) do if p.name == "UBahnStufe" then steps = steps + 1 end end
	check(steps == 14 * 3 * #S.ubahn, "Stachus: U-Bahn-Stufen " .. steps)
	check(outside == 0, "Stachus: " .. outside .. " Teile außerhalb der Platzfläche")
	check(passage == 0, "Karlstor: Durchgang blockiert")
	check(texts["OSRUM"] == 2 and (texts["McDonnell's"] or 0) >= 2 and texts["KARLSTOR"] == 2 and texts["TAXI"] == S.taxi.n + 2, "Stachus: Schriften OSRUM/McDonnell's/KARLSTOR/TAXI unvollständig")
	check(st.segs >= 30 and st.jets >= 48 and st.merlons >= 30 and st.taxis == 8 and st.towers == 4 and st.pits == 2 and st.lamps >= 6 and st.trees == 8, string.format("Stachus: segs %d jets %d zinnen %d taxis %d tuerme %d gruben %d lampen %d baeume %d", st.segs, st.jets, st.merlons, st.taxis, st.towers, st.pits, st.lamps, st.trees))
	check(#plan.parts > 2000 and #plan.parts < 9000, "Stachus: Teile " .. #plan.parts)
	-- Wings enden vor der Straße, Tor liegt zwischen den Flügeln (West), keine Sonderbauten im Platz
	for _, sp in ipairs(Specials) do
		check(not (sp.x0 < S.x1 and sp.x1 > S.x0 and sp.z0 < S.z1 and sp.z1 > S.z0), sp.name .. " steht im Stachus")
	end
	for _, b in ipairs(Blocks) do
		check(not (b.xmin < S.x1 and b.xmax > S.x0 and b.zmin < S.z1 and b.zmax > S.z0), b.name .. " überlappt den Stachus")
	end
	print(string.format("Stachus: %d Teile (%d Abschnitte, %d Läden, %d Strahlen, %d Zinnen)", #plan.parts, st.segs, st.shops, st.jets, st.merlons))
end

-- ===== Autohaus an der V3 (ohne Fahrzeuge) =====
do
	local Config = require("Config")
	local RoadsPlanner = require("RoadsPlanner")
	local Autohaus = require("Autohaus")
	local Specials = require("Specials")
	local Blocks = require("Blocks")
	local A = Config.autohaus
	local plan = Autohaus.plan(Config)
	local segs = RoadsPlanner.segments(Config)
	local function roadAt(x, z)
		for _, sg in ipairs(segs) do
			local rc = sg.rect
			local dx, dz = x - rc.ax, z - rc.az
			local a, b = dx * rc.ux + dz * rc.uz, dx * rc.nx + dz * rc.nz
			if a > rc.s0 and a < rc.s1 and math.abs(b) < rc.w + 1 then return sg end
		end
	end
	local texts, outside, maxY = {}, 0, 0
	for _, p in ipairs(plan.parts) do
		local hx, hz = p.size[1] / 2, p.size[3] / 2
		if (p.yaw or 0) % 180 == 90 then hx, hz = hz, hx end -- um 90 Grad gedrehte Teile (Schrift nach Westen)
		if p.roll == nil or p.roll == 90 or p.name == "Treppenwange" then
			if p.pos[1] - hx < A.x0 - 0.5 or p.pos[1] + hx > A.x1 + 0.5 or p.pos[3] - hz < A.z0 - 0.5 or p.pos[3] + hz > (A.vorfeld and A.vorfeld.zMax or A.z1) + 0.5 then
				if p.name ~= "Treppenwange" then outside = outside + 1 print("Autohaus außerhalb: " .. p.name .. " " .. p.pos[1] .. "," .. p.pos[3]) end
			end
		end
		maxY = math.max(maxY, p.pos[2] + p.size[2] / 2)
		if p.text then texts[p.text.s] = (texts[p.text.s] or 0) + 1 end
		check(not string.find(string.lower(p.name), "auto$") and p.name ~= "Fahrzeug" and p.tag ~= "VehicleSpawn", "Autohaus: Fahrzeuge sind noch nicht gewünscht")
	end
	check(outside == 0, "Autohaus: " .. outside .. " Teile außerhalb des Grundstücks")
	-- Vorfeld: Platten und Keil-Dreiecke liegen nicht in der Diagonale (Fahrbahn plus Gehweg)
	local nV, nR = 0, 0
	for _, p in ipairs(plan.parts) do
		if p.name == "Vorfeld" or p.name == "Rasen" then
			if p.name == "Rasen" then nR = nR + 1 else nV = nV + 1 end
			for _, c in ipairs({ { 0, 0 }, { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } }) do
				local x, z = p.pos[1] + c[1] * (p.wedge and 0 or p.size[1] / 2), p.pos[3] + c[2] * (p.wedge and 0 or p.size[3] / 2)
				check(roadAt(x, z) == nil, string.format("Autohaus-Vorfeld: %s bei (%.0f,%.0f) liegt in einer Straße", p.name, x, z))
			end
		end
	end
	check(nV == 3 and nR >= 8, "Autohaus-Vorfeld: Platten " .. nV .. ", Rasenteile " .. nR)
	for _, c in ipairs({ { A.x0, A.z0 }, { A.x1, A.z0 }, { A.x0, A.z1 }, { A.x1, A.z1 }, { (A.x0 + A.x1) / 2, A.z1 } }) do
		check(roadAt(c[1], c[2]) == nil, string.format("Autohaus: Grundstücksecke (%d,%d) liegt in einer Straße", c[1], c[2]))
	end
	for _, sp in ipairs(Specials) do check(not (sp.x0 < A.x1 and sp.x1 > A.x0 and sp.z0 < A.z1 and sp.z1 > A.z0), sp.name .. " überlappt das Autohaus") end
	for _, b in ipairs(Blocks) do check(not (b.xmin < A.x1 and b.xmax > A.x0 and b.zmin < A.z1 and b.zmax > A.z0), b.name .. " überlappt das Autohaus") end
	check(texts["AUTOHAUS ISARTOR"] == 1 and texts["SERVICE"] == 1 and texts["AUTOHAUS"] == 1 and texts["ISARTOR"] == 1, "Autohaus: Schilder unvollständig")
	check(#plan.parts > 100 and #plan.parts < 400 and maxY > 38 and maxY < 45, string.format("Autohaus: Teile %d, Höhe %.1f", #plan.parts, maxY))
	print(string.format("Autohaus: %d Teile (%d Boxenlinien, %d Leuchten, %d Bäume), höchster Punkt %.1f", #plan.parts, plan.stats.bays, plan.stats.lamps, plan.stats.trees, maxY))
end

-- ===== Skyline, höhere Eckhäuser, Bushaltestellen =====
do
	local Config = require("Config")
	local Geo = require("Geo")
	local RoadsPlanner = require("RoadsPlanner")
	local Hochhaus = require("Hochhaus")
	local Bus = require("Bushaltestellen")
	local segs = RoadsPlanner.segments(Config)
	local function inRoad(x, z, margin, kinds)
		for _, sg in ipairs(segs) do
			local rc = sg.rect
			local dx, dz = x - rc.ax, z - rc.az
			local a, b = dx * rc.ux + dz * rc.uz, dx * rc.nx + dz * rc.nz
			if a > rc.s0 and a < rc.s1 and math.abs(b) < rc.w + margin then return sg, b end
		end
	end
	local plan = Hochhaus.plan(Config)
	check(plan.stats.towers == 5 and plan.stats.tallest >= 140, "Hochhäuser: " .. plan.stats.towers .. ", höchstes " .. plan.stats.tallest)
	local foot = {}
	for _, t in ipairs(Config.hochhaeuser) do
		local hx, hz
		if t.art == "glas" then hx, hz = t.w / 2 + (t.pm or 9), t.d / 2 + (t.pm or 9)
		elseif t.art == "bmo" then hx, hz = (t.versatz or 12.5) + (t.radius or 14) + 3, (t.versatz or 12.5) + (t.radius or 14) + 3
		else hx, hz = t.r + 2, t.r + 2 end
		local f = { t.name, t.x - hx, t.z - hz, t.x + hx, t.z + hz }
		foot[#foot + 1] = f
		check(f[2] > Config.map.xmin and f[4] < Config.map.xmax and f[3] > Config.map.zmin and f[5] < Config.map.zmax, t.name .. " liegt nicht auf der Karte")
		for _, px in ipairs({ f[2], f[4] }) do
			for _, pz in ipairs({ f[3], f[5] }) do
				local sg = inRoad(px, pz, 0)
				check(not sg, t.name .. " ragt in die Straße " .. (sg and sg.road.name or ""))
			end
		end
		for _, sp in ipairs(Specials) do
			check(not (f[2] < sp.x1 and f[4] > sp.x0 and f[3] < sp.z1 and f[5] > sp.z0), t.name .. " überlappt " .. sp.name)
		end
		for _, b in ipairs(Blocks) do -- Blockhäuser dürfen den Turm nicht schneiden
			local bp = Planner.planBlock(b, { seed = 1 })
			local all = {}
			for _, h in ipairs(bp.houses) do all[#all + 1] = h end
			for _, h in ipairs(bp.inner) do all[#all + 1] = h end
			for _, h in ipairs(all) do
				local x0, _, z0, x1, _, z1 = Planner.aabb(bodyOf(h))
				check(not (x0 < f[4] - 0.5 and x1 > f[2] + 0.5 and z0 < f[5] - 0.5 and z1 > f[3] + 0.5), t.name .. " schneidet " .. h.name)
			end
		end
	end
	for i = 1, #foot do
		for j = i + 1, #foot do
			local a, b = foot[i], foot[j]
			check(not (a[2] < b[4] and a[4] > b[2] and a[3] < b[5] and a[5] > b[3]), a[1] .. " überlappt " .. b[1])
		end
	end
	for _, p in ipairs(plan.parts) do
		for k = 1, 3 do check(p.pos[k] == p.pos[k] and p.size[k] == p.size[k] and p.size[k] > 0, "Hochhaus: ungültiges Teil " .. p.name) end
	end
	check(#plan.parts > 400 and #plan.parts < 6000, "Hochhaus: Teile " .. #plan.parts)
	local logos = 0
	for _, p in ipairs(plan.parts) do if p.text and p.text.s == "BMO" then logos = logos + 1 end end
	check(logos == 2, "BMO-Logo nicht auf beiden Seiten: " .. logos)

	-- Eckhäuser: Geschosszahl mal 3
	for name, mul in pairs(Config.eckhaeuser) do
		local found = false
		for _, b in ipairs(Blocks) do
			local base, raised = Planner.planBlock(b, { seed = 1 }), Planner.planBlock(b, { seed = 1, raise = Config.eckhaeuser })
			for i, h in ipairs(base.houses) do
				if h.name == name then
					found = true
					check(raised.houses[i].floors == math.floor(h.floors * mul + 0.5), name .. ": Geschosse " .. raised.houses[i].floors .. " statt " .. h.floors * mul)
				end
			end
		end
		check(found, "Eckhaus nicht gefunden: " .. name)
	end

	-- Bushaltestellen: auf dem Gehweg, mit Abstand zueinander, Fahrbahn auf der angegebenen Seite
	local bp = Bus.plan(Config)
	check(bp.stats.stops == #Config.busstops and #Config.busstops >= 12, "Bushaltestellen: " .. bp.stats.stops)
	for i, st in ipairs(Config.busstops) do
		local sg, b = inRoad(st.x, st.z, 0)
		check(sg, "Haltestelle " .. i .. " liegt nicht an einer Straße")
		if sg then
			local rc = sg.rect
			check(math.abs(b) > 14 and math.abs(b) < rc.w, string.format("Haltestelle %d nicht auf dem Gehweg (Abstand %.1f)", i, b))
			local DIRS = { N = { 0, -1 }, S = { 0, 1 }, W = { -1, 0 }, E = { 1, 0 } }
			local dir = DIRS[st.zurStrasse]
			local dot = dir[1] * rc.nx * (b > 0 and -1 or 1) + dir[2] * rc.nz * (b > 0 and -1 or 1)
			check(dot > 0.9, "Haltestelle " .. i .. ": Fahrbahn liegt nicht auf der Seite " .. st.zurStrasse)
		end
		for j = 1, i - 1 do check(math.sqrt((st.x - Config.busstops[j].x) ^ 2 + (st.z - Config.busstops[j].z) ^ 2) > 60, "Haltestellen " .. i .. "/" .. j .. " zu dicht") end
	end
end

-- ===== Schaufenster an der Leopoldstraße =====
do
	local shops, kinds = 0, {}
	for _, b in ipairs(Blocks) do
		local plan = Planner.planBlock(b, { seed = 1 })
		for _, h in ipairs(plan.houses) do
			local glass, names = 0, {}
			for _, p in ipairs(h.parts) do
				if p.name == "SchauGlas" then glass = glass + 1 end
				if p.name == "LadenSchrift" then names[#names + 1] = p.text.s end
			end
			if b.shopSide == h.side and h.width >= 24 then
				check(glass >= 1 and #names == glass, h.name .. ": Schaufenster " .. glass)
				shops = shops + glass
				for _, n in ipairs(names) do kinds[n] = true end
			else
				check(glass == 0, h.name .. " hat Schaufenster abseits der Leopoldstraße")
			end
		end
	end
	local n = 0
	for _ in pairs(kinds) do n = n + 1 end
	check(shops >= 8 and n >= 4, "Schaufenster: " .. shops .. " Läden, " .. n .. " Namen")
	print(string.format("Schaufenster: %d Läden (%d verschiedene Namen)", shops, n))
end

if failures > 0 then
	print(failures .. " FEHLER")
	error("Tests fehlgeschlagen")
end
print("Alle Tests bestanden")

-- ===== Werkstatt südlich der Tankstelle =====
do
	local Config = require("Config")
	local RoadsPlanner = require("RoadsPlanner")
	local Werkstatt = require("Werkstatt")
	local Specials = require("Specials")
	local Blocks = require("Blocks")
	local W = Config.werkstatt
	local plan = Werkstatt.plan(Config)
	local segs = RoadsPlanner.segments(Config)
	local texts, outside = {}, 0
	for _, p in ipairs(plan.parts) do
		local hx, hz = p.size[1] / 2, p.size[3] / 2
		if p.pos[1] - hx < W.x0 - 0.5 or p.pos[1] + hx > W.x1 + 0.5 or p.pos[3] - hz < W.z0 - 0.5 or p.pos[3] + hz > W.z1 + 0.5 then outside = outside + 1 print("außerhalb: " .. p.name .. " " .. p.pos[1] .. "," .. p.pos[3]) end
		if p.text then texts[p.text.s] = (texts[p.text.s] or 0) + 1 end
	end
	check(outside == 0, "Werkstatt: " .. outside .. " Teile außerhalb des Grundstücks")
	for _, c in ipairs({ { W.x0, W.z0 }, { W.x1, W.z0 }, { W.x0, W.z1 }, { W.x1, W.z1 } }) do
		for _, sg in ipairs(segs) do
			local rc = sg.rect
			local dx, dz = c[1] - rc.ax, c[2] - rc.az
			local a, b = dx * rc.ux + dz * rc.uz, dx * rc.nx + dz * rc.nz
			check(not (a > rc.s0 and a < rc.s1 and math.abs(b) < rc.w + 1), string.format("Werkstatt: Ecke (%d,%d) liegt in einer Straße", c[1], c[2]))
		end
	end
	for _, sp in ipairs(Specials) do check(not (sp.x0 < W.x1 and sp.x1 > W.x0 and sp.z0 < W.z1 and sp.z1 > W.z0), sp.name .. " überlappt die Werkstatt") end
	for _, h in ipairs(Config.hochhaeuser) do if h.w then check(not (h.x - h.w / 2 < W.x1 and h.x + h.w / 2 > W.x0 and h.z - h.d / 2 < W.z1 and h.z + h.d / 2 > W.z0), h.name .. " überlappt die Werkstatt") end end
	check(texts["Service-Center"] == 2 and texts["Tor 1"] == 1 and texts["Tor 2"] == 1 and texts["Tor 3"] == 1 and texts["Tor 4"] == 1 and texts["Tor 5"] == 1 and texts["Tor 6"] == 1 and (texts["ADAN"] or 0) >= 8 and (texts["Werkstatt"] or 0) >= 6, "Werkstatt: Schilder unvollständig (beide Seiten)")
	check(plan.stats.gates == 6 and #plan.parts > 150 and #plan.parts < 450, "Werkstatt: Teile " .. #plan.parts)
	print(string.format("Werkstatt: %d Teile (%d Tore, %d Leuchten)", #plan.parts, plan.stats.gates, plan.stats.lamps))
end


-- ===== Anlagen (Allee, Klinikpark, Ufer-Parks) =====
do
	local Config = require("Config")
	local RoadsPlanner = require("RoadsPlanner")
	local Anlagen = require("Anlagen")
	local Specials = require("Specials")
	local segs = RoadsPlanner.segments(Config)
	local plan = Anlagen.plan(Config)
	local ops = Anlagen.terrain(Config)
	local function inRoad(x, z, m)
		for _, sg in ipairs(segs) do
			local rc = sg.rect
			local dx, dz = x - rc.ax, z - rc.az
			local a, b = dx * rc.ux + dz * rc.uz, dx * rc.nx + dz * rc.nz
			if a > rc.s0 - m and a < rc.s1 + m and math.abs(b) < rc.w + m then return true end
		end
		return false
	end
	-- jeder Eckpunkt jeder Anlage liegt außerhalb von Straßen und Sonderbauten
	for _, s in ipairs(Config.anlagen) do
		for _, p in ipairs(s.poly) do
			check(not inRoad(p[1], p[2], 0), string.format("Anlage %s: Eckpunkt (%d,%d) liegt in einer Straße", s.name, p[1], p[2]))
			for _, sp in ipairs(Specials) do check(not (p[1] > sp.x0 and p[1] < sp.x1 and p[2] > sp.z0 and p[2] < sp.z1), string.format("Anlage %s: Eckpunkt in %s", s.name, sp.name)) end
		end
	end
	local nTrees = 0
	for _, p in ipairs(plan.parts) do
		check(not inRoad(p.pos[1], p.pos[3], 0), string.format("Anlagen: %s bei (%.0f,%.0f) liegt in einer Straße", p.name, p.pos[1], p.pos[3]))
		if p.name == "AnlageStamm" then nTrees = nTrees + 1 end
	end
	check(plan.stats.areas == #Config.anlagen and nTrees > 120 and plan.stats.benches >= 30 and plan.stats.lamps >= 10 and #ops > 100, string.format("Anlagen: Bäume %d, Bänke %d, Leuchten %d, Rasenblöcke %d", nTrees, plan.stats.benches, plan.stats.lamps, #ops))
	check(#plan.parts > 700 and #plan.parts < 6000, "Anlagen: Teile " .. #plan.parts)
	print(string.format("Anlagen: %d Teile (%d Bäume, %d Bänke, %d Leuchten, %d Büsche, %d Findlinge, %d Rasenblöcke)", #plan.parts, nTrees, plan.stats.benches, plan.stats.lamps, plan.stats.bushes, plan.stats.rocks, #ops))
end
