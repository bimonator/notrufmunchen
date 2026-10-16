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
		check(#plan.inner >= 3, tag .. "zu wenige Hinterhäuser: " .. #plan.inner)
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
	-- E-Ladepark (Ostseite des Grundstücks): 8 Stellplätze, 4 Ladesäulen (Tag EVCharger), Schriftband, alles östlich vom Schirm und innerhalb des Grundstücks
	local ev, stalls, chargers, evText = lot.ev, 0, 0, 0
	for _, p in ipairs(tank) do
		if string.sub(p.name, 1, 2) == "EV" then
			check(p.pos[1] - p.size[1] / 2 >= lot.canopy[3] + 1 and p.pos[1] + p.size[1] / 2 <= lot.lot[3], "E-Ladepark: " .. p.name .. " liegt nicht zwischen Schirm und Grundstücksrand")
			check(p.pos[3] - p.size[3] / 2 >= lot.z1 - 40 and p.pos[3] + p.size[3] / 2 <= lot.canopy[4], "E-Ladepark: " .. p.name .. " liegt nicht neben dem Schirm")
		end
		if p.name == "EVStellplatz" then stalls = stalls + 1 end
		if p.tag == "EVCharger" then chargers = chargers + 1 end
		if p.name == "EVSchrift" and p.text and p.text.s ~= "" then evText = evText + 1 end
	end
	check(ev and stalls == ev.n and chargers == ev.n / 2 and evText == 2, "E-Ladepark: Stellplätze " .. stalls .. ", Säulen " .. chargers .. ", Schriftzüge " .. evText)
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
		check(helm == 18 and hands == 2 and bricks >= 8 and windows >= 20, "Kirche: Helm " .. helm .. ", Zeiger " .. hands .. ", Ziegel " .. bricks .. ", Fenster " .. windows)
		check(math.abs(along(church.ox, church.oz) - (a.church[1] + a.church[2]) / 2) < 0.5, "Kirche: Lage in der Zeile")
	end
	print(string.format("Isar-Allee: %d Häuser, Kirche mit %d Teilen", houses, church and #church.parts or 0))
end

if failures > 0 then
	print(failures .. " FEHLER")
	error("Tests fehlgeschlagen")
end
print("Alle Tests bestanden")
