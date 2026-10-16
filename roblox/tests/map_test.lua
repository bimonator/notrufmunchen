-- Tests für Straßen, Terrain und Mapgrenze (kein Roblox nötig):  python3 run_with_lupa.py map_test.lua
package.path = "../MapBuilder/?.lua;MapBuilder/?.lua;roblox/MapBuilder/?.lua;" .. package.path
local Config = require("Config")
local Geo = require("Geo")
local RoadsPlanner = require("RoadsPlanner")
local TerrainPlanner = require("TerrainPlanner")
local WallPlanner = require("WallPlanner")
local LightsPlanner = require("LightsPlanner")
local Planner = require("Planner")

local failures = 0
local function check(cond, msg)
	if not cond then
		failures = failures + 1
		print("FEHLER: " .. msg)
	end
end

-- ===== Straßen =====
local road = RoadsPlanner.plan(Config)
local parts, segs = road.parts, road.segments
print(string.format("Straßen: %d Teile, %d Segmente, %d Parkbuchten, %d Strichlinien", #parts, #segs, road.stats.bays, road.stats.dashes))

check(road.stats.bays >= 125 and road.stats.bays <= 175, "Parkbuchten " .. road.stats.bays)
-- keine Parkbuchten vor den Tankstellen-Einfahrten
for _, b in ipairs(Config.bays) do
	if b[1] == 38.5 and b[3] == 38.5 then
		for _, d in ipairs(Config.driveways) do
			local za, zb = math.min(b[2], b[4]), math.max(b[2], b[4])
			if d.x0 == 43 then check(zb <= d.z0 or za >= d.z1, "Parkbucht vor der Einfahrt: " .. b[2] .. ".." .. b[4]) end
		end
	end
end
for _, p in ipairs(parts) do
	check(p.pos[2] > -25 and p.pos[2] < 20, "Teil " .. p.name .. " liegt auf Höhe " .. p.pos[2])
	check(p.size[1] > 0 and p.size[2] > 0 and p.size[3] > 0, "Teil " .. p.name .. " ohne Größe")
end

-- Gehwege liegen nie in einer anderen Straße (dort würde ein Bordstein quer über die Kreuzung laufen)
local function inSeg(px, pz, s, margin)
	local r = s.cutRect or s.rect -- Kreisverkehr: nur seine Fahrbahn zählt, sein Gehweg darf von anderen Gehwegen überlagert werden
	local dx, dz = px - r.ax, pz - r.az
	local a, b = dx * r.ux + dz * r.uz, dx * r.nx + dz * r.nz
	return a > r.s0 + margin and a < r.s1 - margin and math.abs(b) < r.w - margin
end
local walks, bad = 0, 0
for _, p in ipairs(parts) do
	if p.kind == "walk" and p.seg then -- Brückengehwege haben kein seg und liegen bewusst auf der Straße
		walks = walks + 1
		local r = math.rad(p.yaw)
		local ux, uz = math.cos(r), -math.sin(r)
		local steps = math.max(1, math.floor(p.size[1] / 3))
		local hit
		for k = 0, steps do -- Punkte entlang des ganzen Gehwegstücks prüfen, nicht nur die Mitte
			local t = -p.size[1] / 2 + 0.5 + (p.size[1] - 1) * k / steps
			local x, z = p.pos[1] + ux * t, p.pos[3] + uz * t
			for _, s in ipairs(segs) do
				local own = segs[p.seg] -- Nachbarsegmente derselben Straße mit kleinem Knick (Ellipse) überlappen am Knick nur unmerklich
				if s.id ~= p.seg and not (s.road == own.road and s.ux * own.ux + s.uz * own.uz > 0.95) and inSeg(x, z, s, 0.5) then hit = s.road.name break end
			end
			if hit then break end
		end
		if hit then
			bad = bad + 1
			print("  Gehweg in Straße: " .. p.name .. " bei " .. p.pos[1] .. "," .. p.pos[3] .. " in " .. hit)
		end
	end
end
check(walks > 40, "zu wenige Gehwege: " .. walks)
check(bad == 0, bad .. " Gehwegteile liegen in anderen Straßen")

-- Kein Z-Fighting: wo sich zwei Fahrbahn- oder Platzteile überlappen, liegen ihre Oberkanten mindestens 0,03 auseinander
do
	local flat = {}
	for _, p in ipairs(parts) do
		if (p.kind == "road" or p.kind == "plaza" or p.kind == "median") and p.pos[2] > -3 and p.pitch == 0 then flat[#flat + 1] = p end
	end
	local same = 0
	for i, a in ipairs(flat) do
		local ta = a.pos[2] + a.size[2] / 2
		local r = math.rad(a.yaw)
		local ux, uz = math.cos(r), -math.sin(r)
		for _, fx in ipairs({ -0.35, 0, 0.35 }) do
			for _, fz in ipairs({ -0.3, 0.3 }) do
				local px = a.pos[1] + ux * a.size[1] * fx + uz * a.size[3] * fz
				local pz = a.pos[3] + uz * a.size[1] * fx - ux * a.size[3] * fz
				for j, b in ipairs(flat) do
					if j ~= i and Geo.inPart(px, pz, b, 0.2) and math.abs(ta - (b.pos[2] + b.size[2] / 2)) < 0.03 then same = same + 1 print("  Flackern: " .. a.name .. " und " .. b.name .. " bei " .. px .. "," .. pz) end
				end
			end
		end
	end
	check(same == 0, same .. " Überlappungen mit gleicher Oberkante (Flackern)")
end

-- Jede Straßen-Mittellinie ist asphaltiert
local uncovered = 0
for _, s in ipairs(segs) do
	local steps = math.floor(s.len / 15)
	for k = 0, steps do
		local t = math.min(s.len, k * 15)
		local x, z = s.ax + s.ux * t, s.az + s.uz * t
		if s.prof.strips[1][3] ~= "plaza" then
			local found = false
			for _, p in ipairs(parts) do
				if (p.kind == "road" or p.kind == "median") and Geo.inPart(x, z, p, 0) then found = true break end
			end
			if not found then
				uncovered = uncovered + 1
				print(string.format("  ohne Asphalt: %s bei %.1f, %.1f", s.road.name, x, z))
			end
		end
	end
end
check(uncovered == 0, uncovered .. " Punkte ohne Asphalt")

-- Kreisverkehr um das Siegestor: Ring schließt an Achse, H2 und Diagonale an, die Insel liegt innerhalb des Rings
do
	local ringR, islandR = Config.landmarks.siegestor.ringR, Config.landmarks.siegestor.islandR
	local ring, ends = nil, {}
	for _, rd in ipairs(Config.roads) do
		if rd.name == "SiegestorKreisel" then ring = rd end
		assert(rd.name ~= "Achse", "alte Achse ohne Kreisverkehr")
	end
	check(ring ~= nil and #ring.pts == 96, "Kreisverkehr fehlt")
	check(islandR + 2.4 <= ringR - 12 + 0.01, "Insel ragt in die Fahrbahn: " .. islandR)
	check(Config.tunnel == nil, "Tunnel entfällt")
	-- Anschlüsse: jede Zufahrt endet innerhalb des Rings (Abstand zur Mitte zwischen Innen- und Außenrand)
	local function inRing(x, z) local d = math.sqrt(x * x + z * z) return d > ringR - 12 and d < ringR + 12 end
	for _, rd in ipairs(Config.roads) do
		if rd.name == "H2" then check(inRing(rd.pts[2][1], rd.pts[2][2]), "H2 endet nicht im Ring") end
		if rd.name == "Diagonale" then check(inRing(rd.pts[1][1], rd.pts[1][2]), "Diagonale beginnt nicht im Ring") end
		if rd.name == "ZulaufNord" then check(inRing(rd.pts[2][1], rd.pts[2][2]), "Zulauf Nord endet nicht im Ring") end
		if rd.name == "ZulaufSued" then check(inRing(rd.pts[1][1], rd.pts[1][2]), "Zulauf Süd beginnt nicht im Ring") end
	end
	-- keine Häuser im Ring (Randhäuser weichen)
	for _, b in ipairs(require("Blocks")) do
		for _, h in ipairs(Planner.planBlock(b, { seed = 1 }).houses) do
			for _, p in ipairs(h.parts) do
				if p.name == "Body" then
					local x0, z0, x1, z1 = p.pos[1] - p.size[1] / 2, p.pos[3] - p.size[3] / 2, p.pos[1] + p.size[1] / 2, p.pos[3] + p.size[3] / 2
					-- nächster Punkt der Hausfläche zur Mitte
					local nx, nz = math.max(x0, math.min(0, x1)), math.max(z0, math.min(0, z1))
					check(math.sqrt(nx * nx + nz * nz) > ringR + 12 + 1, h.name .. " steht im Kreisverkehr")
				end
			end
		end
	end
end

-- Isar-Brücken: flach auf Straßenhöhe, länger als die Uferböschung, Pfeiler im Wasser und auf der Kiesbank, darunter keine Straße mehr
local hwBank = Config.water.isar.layers[1][3]
for _, b in ipairs(Config.isarBridges) do
	local r = math.rad(b.yaw)
	local ux, uz = math.cos(r), -math.sin(r)
	local deck, piers, columns, flat, capY = nil, 0, 0, 0, nil
	for _, p in ipairs(parts) do
		local along = (p.pos[1] - b.x) * ux + (p.pos[3] - b.z) * uz
		local across = -(p.pos[1] - b.x) * uz + (p.pos[3] - b.z) * ux
		if p.name == "BrueckeFahrbahn" and math.abs(across) < 1 and math.abs(along) < 1 then deck = p end
		if p.name == "BrueckePfeilerBalken" and math.abs(across) < 1 then piers = piers + 1 end
		if p.name == "BrueckeSaeule" and math.abs(across + 21) < 0.5 then
			columns = columns + 1
			local bottom = p.pos[2] - p.size[1] / 2
			check(p.shape == "Cylinder" and p.roll == 90, b.name .. " Säule nicht senkrecht")
			check(math.abs(bottom + 1 - (p.pos[2] - p.size[1] / 2 + 1)) < 1e-6 and bottom <= -8, b.name .. " Säule steht nicht im Wasser/auf der Kiesbank: " .. bottom)
		end
		if p.seg and (p.kind == "road" or p.kind == "walk" or p.kind == "median") and math.abs(across) < 24 and math.abs(along) < b.len / 2 - 3 then flat = flat + 1 end
	end
	check(deck ~= nil, b.name .. " ohne Fahrbahn")
	if deck then
		check(math.abs(deck.pos[2] + deck.size[2] / 2 - 0.5) < 1e-6, b.name .. " Fahrbahn nicht auf Straßenhöhe")
		check(deck.size[1] >= 2 * hwBank + 20, b.name .. " Brücke kürzer als die Böschung: " .. deck.size[1])
	end
	if b.style == "maximilian" then
		local slices, statues, minSoffit, lamps, pier = 0, 0, 1e9, 0, 0
		for _, p in ipairs(parts) do
			if p.name == "BrueckeBogen" then
				slices = slices + 1
				minSoffit = math.min(minSoffit, p.pos[2] - p.size[2] / 2)
				check(p.pos[2] + p.size[2] / 2 <= -0.99, "Bogenscheibe ragt in das Deck")
			end
			if p.name == "StatueSockel" then statues = statues + 1 end
			if p.name == "BrueckenLaterne" then lamps = lamps + 1 end
			if p.name == "BrueckePfeiler" and math.abs(p.pos[1] - b.x) < 1 then pier = pier + 1 check(p.pos[2] - p.size[2] / 2 <= -14.9, "Mittelpfeiler steht nicht im Flussbett") end
		end
		check(slices == 48, "Bogenscheiben " .. slices)
		check(minSoffit >= -7.05 and minSoffit <= -6.5, "Bogenansatz " .. minSoffit)
		check(minSoffit > Config.water.isar.waterTop, "Bogen taucht ins Wasser")
		check(statues == 2 and lamps == 6 and pier == 1, "Maximilianbrücke: Statuen " .. statues .. ", Laternen " .. lamps .. ", Mittelpfeiler " .. pier)
	else
		check(piers >= 3, b.name .. " Pfeilerreihen " .. piers)
		check(columns == piers, b.name .. " Säulen " .. columns .. " zu Pfeilern " .. piers)
	end
	check(flat == 0, b.name .. ": " .. flat .. " flache Straßenteile unter der Brücke")
end

-- Brücken
local decks = 0
for _, p in ipairs(parts) do
	if p.kind == "deck" and string.find(p.name, "Deck_", 1, true) == 1 then decks = decks + 1 end
end
check(decks == #Config.bridges, "Brückendecks " .. decks)

-- ===== Terrain =====
local ops = TerrainPlanner.plan(Config)
print(string.format("Terrain: %d Operationen", #ops))
local G = Config.groundTop
local area = 0
for _, o in ipairs(ops) do
	check((o.yaw or 0) == 0, "Terrain-Operation mit Drehung")
	if o.op == "block" and o.material == "Pavement" then
		area = area + o.size[1] * o.size[3]
		check(math.abs(o.pos[2] + o.size[2] / 2 - G) < 1e-6, "Boden endet nicht auf groundTop")
	end
end
local m = Config.map
check(math.abs(area - (m.xmax - m.xmin) * (m.zmax - m.zmin)) < 1e-6, "Bodenkacheln decken die Karte nicht genau ab: " .. area)

-- Flussform: das Ausgehobene entspricht dem Puffer (Halbbreite je Schicht) um die Mittellinie, das Wasser nur im Bett
local function distToPolyline(x, z, pts)
	local best = 1e9
	for i = 1, #pts - 1 do
		local ax, az, bx, bz = pts[i][1], pts[i][2], pts[i + 1][1], pts[i + 1][2]
		local dx, dz = bx - ax, bz - az
		local t = math.max(0, math.min(1, ((x - ax) * dx + (z - az) * dz) / (dx * dx + dz * dz)))
		local px, pz = ax + t * dx - x, az + t * dz - z
		best = math.min(best, math.sqrt(px * px + pz * pz))
	end
	return best
end
local function covered(material, x, z, y, tag)
	for _, o in ipairs(ops) do
		if o.material == material and o.op == "block" and (tag == nil or o.tag == tag) and math.abs(x - o.pos[1]) <= o.size[1] / 2 and math.abs(z - o.pos[3]) <= o.size[3] / 2
			and y > o.pos[2] - o.size[2] / 2 and y < o.pos[2] + o.size[2] / 2 then return true end
	end
	return false
end
for name, rv in pairs(Config.water) do
	local checked = 0
	for x = -700, 1150, 30 do
		for z = m.zmin + 12, m.zmax - 12, 30 do
			local d = distToPolyline(x, z, rv.pts)
			for li, ly in ipairs(rv.layers) do
				local ymid = (ly[1] + ly[2]) / 2
				local hw = ly[3]
				if d < hw - 5 then
					check(covered("Air", x, z, ymid, name), string.format("%s: Punkt %d,%d (Abstand %.0f) nicht ausgehoben, Schicht %d", name, x, z, d, li))
					checked = checked + 1
					if ly[1] <= rv.waterTop then check(covered("Water", x, z, ymid, name), string.format("%s: Punkt %d,%d ohne Wasser, Schicht %d", name, x, z, li)) end
				elseif d > hw + 5 then
					-- ausserhalb des Flusses bleibt das Terrain stehen (nur in der Tunnel-Achse darf Luft sein)
					check(not covered("Air", x, z, ymid, name), string.format("%s: Punkt %d,%d (Abstand %.0f) zu weit ausgehoben, Schicht %d", name, x, z, d, li))
					checked = checked + 1
				end
				if ly[1] > rv.waterTop then check(not covered("Water", x, z, ymid, name), name .. " Wasser über der Wasserlinie") end
			end
		end
	end
	check(checked > 200, name .. " zu wenige Messpunkte: " .. checked)
end
for _, o in ipairs(ops) do
	if o.material == "Water" then
		check(o.pos[2] + o.size[2] / 2 <= -4 + 1e-6, "Wasser über der höchsten Wasserlinie")
		check(o.pos[2] - o.size[2] / 2 >= -14 - 1e-6, "Wasser unter dem Flussbett")
	end
end
-- Hügel und Terrasse niedrig, relativ zum Boden
for _, o in ipairs(ops) do
	if o.op == "cylinder" then check(o.pos[2] + o.height / 2 <= G + 8 + 1e-6, "Hügel höher als 8") end
	if o.op == "block" and o.material == "Grass" and o.pos[2] > G then check(o.pos[2] + o.size[2] / 2 <= G + 4 + 1e-6, "Terrasse höher als 4") end
end

-- ===== Mapgrenze =====
local wall = WallPlanner.plan(Config, { seed = 1 })
local st = Planner.stats(wall)
print(string.format("Mapgrenze: %d Gebäude, %d Teile + %d Tor-Teile", st.houses, st.parts, #wall.parts))
check(st.houses > 100, "zu wenige Wandgebäude: " .. st.houses)
local inner, outer = Config.ring, Config.map
local minH, maxH = 999, 0
for _, h in ipairs(wall.houses) do
	local body
	for _, p in ipairs(h.parts) do
		if p.name == "Body" then body = p end
	end
	check(body ~= nil, h.name .. " ohne Body")
	local x0, _, z0, x1, _, z1 = Planner.aabb(body)
	check(x0 >= outer.xmin - 0.01 and x1 <= outer.xmax + 0.01 and z0 >= outer.zmin - 0.01 and z1 <= outer.zmax + 0.01, h.name .. " außerhalb der Karte")
	check(not (x0 < inner.xmax - 0.01 and x1 > inner.xmin + 0.01 and z0 < inner.zmax - 0.01 and z1 > inner.zmin + 0.01), h.name .. " ragt in die Ringstraße")
	-- Tore bleiben frei
	for side, list in pairs(Config.wall.gates) do
		for _, g in ipairs(list) do
			local special = string.find(h.name, "Sonder_", 1, true) == 1
			if h.side == side and not special then
				check(not (x0 < g[2] - 0.01 and x1 > g[1] + 0.01), h.name .. " steht im Tor " .. g[1] .. ".." .. g[2])
			end
		end
	end
	if string.find(h.name, "Sonder_", 1, true) ~= 1 then minH, maxH = math.min(minH, h.height), math.max(maxH, h.height) end
end
check(minH >= 14 + 12 * 5 and maxH <= 14 + 12 * 8, "Wandhöhen " .. minH .. ".." .. maxH)
local special = 0
for _, h in ipairs(wall.houses) do
	if string.find(h.name, "Sonder_", 1, true) == 1 then special = special + 1 end
end
check(special == 2, "Querriegel und Feldherrnhalle erwartet")
check(#wall.parts == 4, "Brückenhäuser und Gitter erwartet")

-- ===== Ampeln =====
local lights = LightsPlanner.plan(Config, road)
print(string.format("Beleuchtung: %d Laternen, %d Ampeln, %d Fußgängerampeln, %d Teile", lights.stats.lamps, lights.stats.signals, lights.stats.ped, #lights.parts))
check(lights.stats.lamps > 200, "zu wenige Laternen: " .. lights.stats.lamps)
check(lights.stats.signals == #Config.signals and lights.stats.ped == #Config.pedSignals, "Ampeln unvollständig")
local groups, ng = {}, 0
for _, s in ipairs(Config.signals) do
	if not groups[s.name] then groups[s.name] = true ng = ng + 1 end
end
check(ng == 5, "Ampelanlagen " .. ng .. " statt 5")
-- Jeder Mast steht auf einem Gehweg und in keiner Fahrbahn
local masts = 0
for _, p in ipairs(lights.parts) do
	if p.name == "AmpelMast" or p.name == "FussgaengerMast" or p.name == "LaternenMast" then
		masts = masts + 1
		local onWalkPart, onAsphalt = false, false
		for _, w in ipairs(parts) do
			if (w.kind == "walk" or w.kind == "green") and Geo.inPart(p.pos[1], p.pos[3], w, 0) then onWalkPart = true end
			if (w.kind == "road" or w.kind == "median") and w.pos[2] > -3 and Geo.inPart(p.pos[1], p.pos[3], w, 0) then onAsphalt = true end
		end
		check(onWalkPart, "Mast ohne Gehweg: " .. p.name .. " bei " .. p.pos[1] .. "," .. p.pos[3])
		check(not onAsphalt, "Mast auf Fahrbahn: " .. p.name .. " bei " .. p.pos[1] .. "," .. p.pos[3])
	end
end
check(masts == lights.stats.lamps + #Config.signals + #Config.pedSignals, "Mastanzahl " .. masts)
-- Laternen nicht dichter als 10 Studs, Leopoldstraße beidseitig
local lampPos, west, east, close = {}, 0, 0, 0
for _, p in ipairs(lights.parts) do
	if p.name == "LaternenMast" then lampPos[#lampPos + 1] = p end
end
for i, a in ipairs(lampPos) do
	if math.abs(a.pos[1]) > 40 and math.abs(a.pos[1]) < 60 and a.pos[3] < -150 then
		if a.pos[1] < 0 then west = west + 1 else east = east + 1 end
	end
	for j = i + 1, #lampPos do
		local dx, dz = a.pos[1] - lampPos[j].pos[1], a.pos[3] - lampPos[j].pos[3]
		if dx * dx + dz * dz < 100 then close = close + 1 end
	end
end
check(close == 0, close .. " Laternenpaare enger als 10 Studs")
check(west > 3 and east >= 2, "Achse: Laternen West " .. west .. ", Ost " .. east)
-- Ampeln: Ausleger reicht über die Fahrbahn (Länge >= 12), zwei Köpfe je Mast
local arms = 0
for _, p in ipairs(lights.parts) do
	if p.name == "AmpelArm" then arms = arms + 1 check(p.size[1] >= 12, "Ausleger zu kurz") end
end
check(arms == #Config.signals, "Ausleger " .. arms)
-- Signalkopf: pro Mast 3 Lampen, genau eine (rot) an; jede Lampe kennt Gruppe, Achse und Farbe für Ampel.lua
local on, total = 0, 0
for _, p in ipairs(lights.parts) do
	if p.tag == "TrafficLight" then
		total = total + 1
		if p.attrs.Lit then on = on + 1 end
		check(p.attrs.Group and (p.attrs.Axis == "NS" or p.attrs.Axis == "EW") and p.attrs.Lamp, "Ampellampe ohne Attribute")
	end
end
check(total == 6 * #Config.signals and on == 2 * #Config.signals, "Ampellampen " .. total .. "/" .. on)

-- Schaltlogik (Ampel.lua)
local Ampel = require("Ampel")
local ac = Ampel.config
local cycle = 2 * (ac.green + ac.yellow + ac.clear)
local seen, conflict = {}, 0
for t = 0, cycle * 2, 0.5 do
	local ns, ew = Ampel.junction(ac, t)
	seen[ns .. "/" .. ew] = true
	if ns ~= "Red" and ew ~= "Red" then conflict = conflict + 1 end
end
check(conflict == 0, "beide Richtungen gleichzeitig nicht rot: " .. conflict)
check(seen["Green/Red"] and seen["Yellow/Red"] and seen["Red/Green"] and seen["Red/Yellow"] and seen["Red/Red"], "Phasen unvollständig")
local g0, e0 = Ampel.junction(ac, 0)
local g1, e1 = Ampel.junction(ac, cycle)
check(g0 == g1 and e0 == e1, "Zyklus wiederholt sich nicht")
check(select(1, Ampel.junction(ac, ac.green + 0.1)) == "Yellow" and select(2, Ampel.junction(ac, ac.green + ac.yellow + ac.clear + 0.1)) == "Green", "Phasenfolge")
-- Feuerwache: grün, bei Alarm gelb dann rot, nach Entwarnung wieder grün
local st = { mode = "Green", since = 0 }
check(Ampel.wache(ac, st, false, 5) == "Green", "Wache ohne Alarm nicht grün")
check(Ampel.wache(ac, st, true, 10) == "Yellow", "Wache bei Alarm nicht gelb")
check(Ampel.wache(ac, st, true, 10 + ac.yellow + 0.1) == "Red", "Wache bei Alarm nicht rot")
check(Ampel.wache(ac, st, true, 100) == "Red", "Wache bleibt bei Alarm nicht rot")
check(Ampel.wache(ac, st, false, 101.5) == "Green", "Wache nach Entwarnung nicht grün")
check(Ampel.ped(ac, 1) == "Green" and Ampel.ped(ac, ac.pedGreen + 1) == "Red", "Fußgängerampel")

-- Ampel.start gegen Attrappen: Wache-Lampen folgen dem Attribut WacheAlarm
do
	local function newLamp(group, axis, lamp)
		local a = { Group = group, Axis = axis, Lamp = lamp, Lit = false }
		return { GetAttribute = function(_, k) return a[k] end, SetAttribute = function(_, k, v) a[k] = v end, attrs = a }
	end
	local lamps = { newLamp("Wache_V1", "NS", "Red"), newLamp("Wache_V1", "NS", "Yellow"), newLamp("Wache_V1", "NS", "Green"), newLamp("Achse_X", "NS", "Green"), newLamp("Achse_X", "EW", "Red") }
	local wsAttr = { WacheAlarm = false }
	local now = 0
	local steps
	local services = {
		CollectionService = { GetTagged = function(_, tag) return tag == "TrafficLight" and lamps or {} end },
		Workspace = { GetAttribute = function(_, k) return wsAttr[k] end },
	}
	game = { GetService = function(_, n) return services[n] end }
	Enum = { Material = { Neon = "Neon", SmoothPlastic = "SmoothPlastic" } }
	Color3 = { fromRGB = function(r, g, b) return { r, g, b } end }
	os.clock = function() return now end
	task = { spawn = function(f) steps = coroutine.wrap(f) end, wait = function() coroutine.yield() end }
	Ampel.start()
	steps()
	check(lamps[3].attrs.Lit and not lamps[1].attrs.Lit, "Wache ohne Alarm: grün erwartet")
	wsAttr.WacheAlarm = true
	now = 20
	steps() steps()
	now = 20 + ac.yellow + 0.5
	steps()
	check(lamps[1].attrs.Lit and not lamps[3].attrs.Lit, "Wache bei Alarm: rot erwartet")
	wsAttr.WacheAlarm = false
	now = 40
	steps() now = 42 steps()
	check(lamps[3].attrs.Lit and not lamps[1].attrs.Lit, "Wache nach Alarm: wieder grün erwartet")
end

-- ===== Wahrzeichen =====
local Landmarks = require("Landmarks")
local lm = Landmarks.plan(Config)
print(string.format("Wahrzeichen: %d Teile", #lm.parts))
do
	local sg, fe = Landmarks.siegestor(Config), Landmarks.friedensengel(Config)
	local y0 = Config.landmarks.siegestor.baseY
	local function aabb(p)
		local sx, sy, sz = p.size[1], p.size[2], p.size[3]
		if p.shape == "Cylinder" and p.roll == 90 then sx, sy = sy, sx end -- stehender Zylinder: Achse lokal x wird zur Höhe
		return p.pos[1] - sx / 2, p.pos[2] - sy / 2, p.pos[3] - sz / 2, p.pos[1] + sx / 2, p.pos[2] + sy / 2, p.pos[3] + sz / 2
	end
	local maxY, texts, blocked = 0, 0, 0
	for _, p in ipairs(sg) do
		local x0, ya, z0, x1, yb, z1 = aabb(p)
		check(x0 >= -34 and x1 <= 34 and z0 >= -8.8 and z1 <= 8.8, "Siegestor: " .. p.name .. " liegt nicht auf der Mittelinsel")
		maxY = math.max(maxY, yb)
		if p.text then texts = texts + 1 end
		-- Durchgänge frei: Mittelbogen |x| < 7, y bis Kämpfer 20; Seitenbögen |x -+ 18| < 4, y bis 14 (nur Teile mit Kollision)
		if p.collide and z0 < 6 and z1 > -6 then
			if x0 < 7 and x1 > -7 and ya < y0 + 19.9 then blocked = blocked + 1 end
			for _, cx in ipairs({ -18, 18 }) do
				if x0 < cx + 4 and x1 > cx - 4 and ya < y0 + 13.9 then blocked = blocked + 1 end
			end
		end
	end
	check(blocked == 0, "Siegestor: " .. blocked .. " Teile versperren die Durchgänge")
	check(maxY > y0 + 70 and maxY < 100, "Siegestor Höhe " .. maxY)
	check(texts == 2, "Siegestor: Inschriften " .. texts)
	local gold, column = 0, 0
	for _, p in ipairs(fe) do
		local x0, ya, z0, x1, yb, z1 = aabb(p)
		check(x0 >= Config.terrace.x0 - 20 and x1 <= Config.terrace.x1 and z0 >= Config.terrace.z0 - 4 and z1 <= Config.terrace.z1, "Friedensengel: " .. p.name .. " liegt nicht auf der Terrasse")
		if p.color[1] == 236 and p.color[2] == 184 then gold = gold + 1 end
		if p.name == "Saeule" then column = p.size[1] end
		check(yb < 140, "Friedensengel zu hoch")
	end
	local steps = 0
	for _, p in ipairs(fe) do if p.name == "TerrassenStufe" then steps = steps + 1 end end
	check(steps == 4, "Treppe zur Terrasse: " .. steps)
	check(column >= 60 and gold >= 6, "Friedensengel: Säule " .. column .. ", Goldteile " .. gold)
end

-- Sonderbauten liegen außerhalb der Isar-Böschung (und der Ring-Außenkante bleibt frei)
for _, sp in ipairs(require("Specials")) do
	for _, cx in ipairs({ sp.x0, sp.x1 }) do
		for _, cz in ipairs({ sp.z0, sp.z1 }) do
			check(Geo.polyDist(cx, cz, Config.water.isar.pts) > Config.water.isar.layers[1][3], sp.name .. " liegt in der Isar-Böschung")
		end
	end
end
for _, rd in ipairs(Config.roads) do -- Straßenpunkte (außer Brückenstraßen) liegen nicht in der Böschung
	if rd.name == "Ring" or rd.name == "Diagonale" or rd.name == "V3" then
		for _, pt in ipairs(rd.pts) do check(Geo.polyDist(pt[1], pt[2], Config.water.isar.pts) > Config.water.isar.layers[1][3] - 1, rd.name .. " Eckpunkt in der Böschung") end
	end
end

-- ===== Grünanlagen =====
local Garden = require("Garden")
local Specials = require("Specials")
local gp = Garden.plan(Config, road, Specials)
local g = gp.parts
print(string.format("Grünanlagen: %d Teile, %d Bäume (Hofgarten %d, Englischer Garten %d), Ufer: %d Wegplatten, %d Bänke, %d Büsche, %d Findlinge",
	#g, gp.stats.hofTrees + gp.stats.egTrees, gp.stats.hofTrees, gp.stats.egTrees, gp.stats.bank.slabs, gp.stats.bank.benches, gp.stats.bank.bushes, gp.stats.bank.rocks))
check(gp.stats.hofTrees >= 40 and gp.stats.egTrees >= 60, "zu wenige Bäume")
check(gp.stats.bank.slabs >= 60 and gp.stats.bank.benches >= 6 and gp.stats.bank.rocks >= 10 and gp.stats.bank.bushes >= 20, "Ufer zu kahl")
do
	local isar, bach = Config.water.isar, Config.water.bach
	local hwBank = isar.layers[1][3]
	local trunks, onRoad, inWater, hill, columns, umbrellas, sign, benchSeats = 0, 0, 0, 0, 0, 0, false, 0
	local h = Config.hills[1]
	for _, p in ipairs(g) do
		check(p.pos[2] > -14 and p.pos[2] < 120, p.name .. " Höhe " .. p.pos[2])
		if p.name == "Stamm" then
			trunks = trunks + 1
			for _, s in ipairs(segs) do
				local r = s.rect
				local dx, dz = p.pos[1] - r.ax, p.pos[3] - r.az
				local a, b = dx * r.ux + dz * r.uz, dx * r.nx + dz * r.nz
				if a > r.s0 - 4 and a < r.s1 + 4 and math.abs(b) < r.w + 4 then onRoad = onRoad + 1 end
			end
			if Geo.polyDist(p.pos[1], p.pos[3], isar.pts) < hwBank or Geo.polyDist(p.pos[1], p.pos[3], bach.pts) < 18 then inWater = inWater + 1 end
			if math.sqrt((p.pos[1] - h.x) ^ 2 + (p.pos[3] - h.z) ^ 2) < 20 then hill = hill + 1 end
		end
		if p.name == "Saeule" and math.sqrt((p.pos[1] - h.x) ^ 2 + (p.pos[3] - h.z) ^ 2) < 13 then columns = columns + 1 check(p.pos[2] - p.size[2] / 2 >= 10, "Monopteros-Säule zu tief") end
		if p.name == "Schirm" then umbrellas = umbrellas + 1 end
		if p.name == "Schrift" and p.text and p.text.s == "PRINZ EINS" then sign = true end
		if p.name == "BankSitz" then benchSeats = benchSeats + 1 end
		if p.name == "Uferweg" then check(math.abs(p.pos[2] + 3.9) < 1e-6, "Uferweg nicht auf der Uferstufe") end
	end
	check(onRoad == 0 and inWater == 0 and hill == 0, "Bäume auf Straße/im Wasser/auf dem Hügelplateau: " .. onRoad .. "/" .. inWater .. "/" .. hill)
	check(columns == 9, "Monopteros: Säulen " .. columns)
	check(umbrellas == 8 and sign, "Prinz Eins: Schirme " .. umbrellas)
	check(benchSeats >= 20, "zu wenige Bänke " .. benchSeats)
	-- Uferwege laufen nicht unter den Brücken durch
	for _, p in ipairs(g) do
		if p.name == "Uferweg" then
			for _, b in ipairs(Config.isarBridges) do
				local r = math.rad(b.yaw)
				local ux, uz = math.cos(r), -math.sin(r)
				local dx, dz = p.pos[1] - b.x, p.pos[3] - b.z
				check(not (math.abs(dx * ux + dz * uz) < b.len / 2 - 2 and math.abs(-dx * uz + dz * ux) < b.wid / 2 + b.walk), "Uferweg unter Brücke " .. b.name)
			end
		end
	end
end

-- Frauenkirche, Chinesischer Turm, Eisbachwelle, Biergarten
do
	local fk, tm = Landmarks.frauenkirche(Config), Landmarks.chinesischerTurm(Config)
	local function count(list, name) local n = 0 for _, p in ipairs(list) do if p.name == name then n = n + 1 end end return n end
	local maxY, minX, maxX, minZ, maxZ = 0, 1e9, -1e9, 1e9, -1e9
	for _, p in ipairs(fk) do
		maxY = math.max(maxY, p.pos[2] + p.size[2] / 2)
		if p.collide ~= false and p.name ~= "Dach" and p.name ~= "First" and p.name ~= "Sockel" then
			minX, maxX = math.min(minX, p.pos[1] - p.size[1] / 2), math.max(maxX, p.pos[1] + p.size[1] / 2)
			minZ, maxZ = math.min(minZ, p.pos[3] - p.size[3] / 2), math.max(maxZ, p.pos[3] + p.size[3] / 2)
		end
	end
	check(#Config.plazas == 0, "Plätze sollen vorerst entfernt sein")
	local sc = Config.landmarks.frauenkirche.scale or 1
	check(maxX - minX >= 380 * sc and maxZ - minZ >= 145 * sc, "Frauenkirche zu klein: " .. (maxX - minX) .. " x " .. (maxZ - minZ))
	local mp = Config.marienplatz
	check(minX >= mp.plaza.x0 - 8 and maxX <= mp.rathaus.x0 - 5 and minZ >= 58.5 and maxZ <= mp.ubahn.z1 + 40, "Frauenkirche liegt nicht im Nordwesten des Marienplatzes: " .. minX .. ".." .. maxX .. ", " .. minZ .. ".." .. maxZ)
	check(count(fk, "Lisene") == 16 and count(fk, "Masswerkfries") == 16 and count(fk, "Turmspitzfenster") == 64 and count(fk, "Wimperg") == 1 and count(fk, "Westfenster") == 2, "Frauenkirche: Turmdetails/Portal unvollständig")
	check(count(fk, "Kuppel") == 2 and count(fk, "KuppelRing") > 2 * 100 and count(fk, "Uhr") == 4 and count(fk, "Dach") == 2, "Frauenkirche: Hauben/Uhren/Dach")
	check(count(fk, "Uhrzeiger") == 8 and count(fk, "Uhrstrich") == 48 and count(fk, "Uhrziffer") == 16, "Frauenkirche: Ziffernblätter unvollständig")
	check(count(fk, "Gaube") == 20 and count(fk, "Schallloch") == 8, "Frauenkirche: Gauben/Schalllöcher")
	check(count(fk, "Fenster") >= 28, "Frauenkirche: Fenster " .. count(fk, "Fenster"))
	check(maxY > 280 * sc and maxY < 380 * sc, "Frauenkirche Höhe " .. maxY)
	local roofs = 0
	for _, p in ipairs(fk) do if p.name == "Dach" then roofs = roofs + 1 check(math.abs(p.pitch) > 35 and math.abs(p.pitch) < 60, "Dachneigung " .. p.pitch) end end
	-- keine Straße führt mehr durch die Kirche (Kreisel entfällt), die Fußgängerzone beginnt hinter dem Chor
	for _, rd in ipairs(Config.roads) do
		check(rd.name ~= "Kreisel" and rd.name ~= "KreiselWest", "Kreisel-Straße noch vorhanden: " .. rd.name)
		check(rd.name ~= "Fussgaengerzone", "Fußgängerzone soll entfernt sein")
		check(rd.name ~= "KirchplatzNord", "Straße zur Kirche soll entfallen")
	end
	local bg = Config.landmarks.biergarten
	check(count(tm, "TurmDach") == 5 and count(tm, "TurmSaeule") == 8, "Chinesischer Turm: Dächer/Säulen")
	for _, p in ipairs(tm) do
		check(p.pos[1] > bg.x0 and p.pos[1] < bg.x1 and p.pos[3] > bg.z0 and p.pos[3] < bg.z1, "Turm außerhalb des Biergartens: " .. p.name)
	end
	local sets, trees, wave, zone, signs, deckOk = 0, 0, nil, nil, 0, false
	for _, p in ipairs(g) do
		if p.name == "Biertisch" then sets = sets + 1 end
		if p.name == "Eisbachwelle" then wave = p end
		if p.name == "SurfZone" then zone = p end
		if p.name == "Schrift" and p.text and (p.text.s == "BIERGARTEN" or p.text.s == "EISBACHWELLE") then signs = signs + 1 end
		if p.name == "Zuschauerdeck" then deckOk = true end
		if p.name == "Stamm" and p.pos[1] > bg.x0 and p.pos[1] < bg.x1 and p.pos[3] > bg.z0 and p.pos[3] < bg.z1 then trees = trees + 1 end
	end
	check(sets >= 15, "Biergarten: Bierbänke " .. sets)
	check(trees == 0, "Bäume im Biergarten: " .. trees)
	check(signs == 2 and deckOk, "Schilder/Deck fehlen")
	check(wave and wave.tag == "Eisbachwelle" and zone and zone.tag == "SurfZone", "Eisbachwelle ohne Tags")
	if wave then
		check(Geo.polyDist(wave.pos[1], wave.pos[3], Config.water.bach.pts) < 1, "Welle liegt nicht im Bach")
		check(wave.pos[2] - wave.size[2] / 2 > Config.water.kanal.layers[2][2] and wave.pos[2] + wave.size[2] / 2 > Config.water.bach.waterTop + 1, "Welle ragt nicht aus dem Wasser")
		check(wave.size[1] <= 2 * Config.water.kanal.layers[1][3], "Welle breiter als der Kanal")
		for _, sp in ipairs(Specials) do
			check(not (wave.pos[1] > sp.x0 - 10 and wave.pos[1] < sp.x1 + 10 and wave.pos[3] > sp.z0 - 10 and wave.pos[3] < sp.z1 + 10), "Welle zu nah an " .. sp.name)
		end
	end
	-- Eisbachwelle an der Maximilianbrücke: Welle flussabwärts der Brücke (keine Figuren), Durchlass im Widerlager (der Bach läuft unter der Brücke durch)
	local br
	for _, b in ipairs(Config.isarBridges) do if b.style == "maximilian" then br = b end end
	local southEdge = br.z + br.wid / 2 + br.walk
	local function bachX(z)
		local pts = Config.water.bach.pts
		for i = 1, #pts - 1 do
			if z >= pts[i][2] and z <= pts[i + 1][2] then return pts[i][1] + (z - pts[i][2]) / (pts[i + 1][2] - pts[i][2]) * (pts[i + 1][1] - pts[i][1]) end
		end
	end
	for _, p in ipairs(g) do check(p.tag ~= "Statist" and p.name ~= "Surfbrett", "Eisbachwelle: Figuren/Bretter sind nicht gewünscht") end
	check(wave and wave.pos[3] > southEdge + 6 and wave.pos[3] < southEdge + 20, "Welle nicht direkt flussabwärts der Brücke")
	local kw = Config.water.kanal.layers[1][3]
	for z = br.z - 28, southEdge, 4 do -- Widerlager lassen den Kanal (Wasserbreite 26) frei
		local bx = bachX(z)
		for _, p in ipairs(parts) do
			if p.name == "BrueckeWiderlager" then
				check(not (bx - kw < p.pos[1] + p.size[1] / 2 and bx + kw > p.pos[1] - p.size[1] / 2), "Widerlager versperrt den Eisbach bei z=" .. z)
			end
		end
	end
	-- Eisbach-Szene: gemauerter Kanal mit Plateau, Stufen und Gischt; Brücke mit zwei Bögen, Mittelpfeiler, Rosetten und Eckpfosten (keine Figuren)
	local function cnt(list, name)
		local n = 0
		for _, p in ipairs(list) do if p.name == name then n = n + 1 end end
		return n
	end
	check(cnt(g, "Kanalmauer") == 4 and cnt(g, "Plateau") == 1 and cnt(g, "Kanalstufe") == 4 and cnt(g, "Holzstufe") == 3 and cnt(g, "Wellenkamm") == 1 and cnt(g, "Wellenzug") == 2 and cnt(g, "Gischt") == 0, "Eisbach: Kanal/Plateau/Stufen/Wellenzug unvollständig (keine Gischt-Kugeln)")
	check(cnt(parts, "EisbachPfeiler") == 1 and cnt(parts, "EisbachBogen") >= 24 and cnt(parts, "EisbachRosette") == 6 and cnt(parts, "EisbachBruestung") == 2 and cnt(parts, "EisbachPfosten") == 4, "Eisbachbrücke: Bögen/Rosetten unvollständig")
	for _, p in ipairs(g) do
		if p.name == "Kanalmauer" then
			check(Geo.polyDist(p.pos[1], p.pos[3], Config.water.kanal.pts) < kw + 3 and p.pos[3] > southEdge, "Kanalmauer liegt nicht am Kanal unterhalb der Brücke")
		end
	end
end

-- ===== Gerundete Gehwegecken und Gehweg um den Kreisverkehr am Siegestor =====
do
	local kurven, asph = 0, 0
	for _, p in ipairs(parts) do
		if p.name == "GehwegKurve" then kurven = kurven + 1 end
		if p.name == "EckAsphalt" then asph = asph + 1 end
		if p.wedge then check(p.size[2] > 0 and p.size[3] > 0 and p.size[1] > 0, "Keil ohne Größe") end
	end
	check(road.stats.corners >= 40 and kurven > 8 * road.stats.corners and asph > 3 * road.stats.corners and road.stats.curves == 8, "Gehwegecken: " .. road.stats.corners .. " (" .. kurven .. "/" .. asph .. "), Kreiselkurven " .. road.stats.curves)
	local ringWalks = 0
	for _, p in ipairs(parts) do
		if p.kind == "walk" and p.seg and segs[p.seg].road.name == "SiegestorKreisel" then
			ringWalks = ringWalks + 1
			local r = math.sqrt(p.pos[1] ^ 2 + p.pos[3] ^ 2)
			check(r > 80 and r < 91, "Kreisverkehr-Gehweg liegt nicht außen: r = " .. r)
		end
	end
	check(ringWalks >= 8, "Kreisverkehr: Gehwegteile " .. ringWalks)
end

-- ===== Fußgängerüberwege (Zebrastreifen) =====
do
	local bars, off = 0, 0
	for _, p in ipairs(parts) do
		if p.name == "Zebra" then
			bars = bars + 1
			local on = false
			for _, o in ipairs(parts) do
				if o.kind == "road" and o.pos[2] > -3 and Geo.inPart(p.pos[1], p.pos[3], o, 0) then on = true break end
			end
			if not on then off = off + 1 end
		end
	end
	check(road.stats.zebras == #Config.crossings and #Config.crossings == 12, "Zebrastreifen: " .. road.stats.zebras)
	check(bars >= 70 and off == 0, "Zebra-Streifen: " .. bars .. ", davon " .. off .. " nicht auf der Fahrbahn")
end

-- ===== Marienplatz: Neues Rathaus, Mariensäule, U-Bahn-Abgang, Kugelleuchten, Platanen =====
do
	local Rathaus, Marienplatz, Landmarks2 = require("Rathaus"), require("Marienplatz"), require("Landmarks")
	local M, U = Config.marienplatz, Config.marienplatz.ubahn
	local rh, mp = Rathaus.plan(Config), Marienplatz.plan(Config)
	local function count(list, name) local n = 0 for _, p in ipairs(list) do if p.name == name then n = n + 1 end end return n end
	local maxY = 0
	for _, p in ipairs(rh) do
		maxY = math.max(maxY, p.pos[2] + p.size[2] / 2)
		check(p.pos[1] >= M.rathaus.x0 - 1 and p.pos[1] <= M.rathaus.x1 + 1 and p.pos[3] >= M.rathaus.z0 - 1 and p.pos[3] <= M.rathaus.z1 + 6, "Rathaus: " .. p.name .. " liegt außerhalb des Grundrisses")
	end
	check(maxY > 120 and maxY < 140, "Rathaus Höhe " .. maxY)
	check(count(rh, "Fenster") >= 90 and count(rh, "GlockenspielFigur") == 12 and count(rh, "Uhrzeiger") == 2 and count(rh, "Blumen") == 8 and count(rh, "Erker") == 2,
		"Rathaus: Fenster " .. count(rh, "Fenster") .. ", Glockenspiel " .. count(rh, "GlockenspielFigur") .. ", Zeiger " .. count(rh, "Uhrzeiger"))
	local lowest = 1e9
	for _, p in ipairs(mp.parts) do
		if p.name == "UBahnStufe" then lowest = math.min(lowest, p.pos[2] + p.size[2] / 2) end
		if p.name == "Pflaster" then
			local x0, z0, x1, z1 = p.pos[1] - p.size[1] / 2, p.pos[3] - p.size[3] / 2, p.pos[1] + p.size[1] / 2, p.pos[3] + p.size[3] / 2
			check(not (x0 < U.x1 - 0.01 and x1 > U.x0 + 0.01 and z0 < U.z1 - 0.01 and z1 > U.z0 + 0.01), "Pflaster liegt über dem U-Bahn-Abgang")
			check(x0 >= M.plaza.x0 - 0.01 and x1 <= M.plaza.x1 + 0.01 and z0 >= M.plaza.z0 - 0.01 and z1 <= M.plaza.z1 + 0.01, "Pflaster außerhalb des Platzes")
		end
	end
	check(mp.stats.steps == 14 and math.abs(lowest - (1 - U.depth)) < 0.01, "U-Bahn: Stufen " .. mp.stats.steps .. ", unterste Stufe " .. lowest)
	local carve = 0
	for _, op in ipairs(TerrainPlanner.plan(Config)) do if op.tag == "ubahn" then carve = carve + 1 check(op.material == "Air", "U-Bahn-Aushub ist nicht Luft") end end
	check(carve == 2 + 2 * #Config.stachus.ubahn, "U-Bahn: Aushub " .. carve)
	check(count(mp.parts, "Mariensaeule") == 1 and count(mp.parts, "Madonna") >= 4 and count(mp.parts, "Putto") == 4, "Mariensäule unvollständig")
	-- Leuchten und Bäume stehen auf dem Platz, nicht in Kirche, Rathaus, Kiosk, Grube oder Häuserzeile
	local fk = Landmarks2.frauenkirche(Config)
	local fx0, fz0, fx1, fz1 = 1e9, 1e9, -1e9, -1e9
	for _, p in ipairs(fk) do
		fx0, fx1 = math.min(fx0, p.pos[1] - p.size[1] / 2), math.max(fx1, p.pos[1] + p.size[1] / 2)
		fz0, fz1 = math.min(fz0, p.pos[3] - p.size[3] / 2), math.max(fz1, p.pos[3] + p.size[3] / 2)
	end
	local kiosk
	for _, sp in ipairs(require("Specials")) do if sp.name == "Kiosk" then kiosk = sp end end
	for _, p in ipairs(mp.parts) do
		if p.name == "KugelleuchteMast" or p.name == "PlataneStamm" or p.name == "CafeTisch" or p.name == "Sitzstufe" then
			local x, z = p.pos[1], p.pos[3]
			check(x > M.plaza.x0 and x < M.plaza.x1 and z > M.plaza.z0 and z < M.plaza.z1 - 2, p.name .. " nicht auf dem Platz")
			check(not (x > fx0 - 2 and x < fx1 + 2 and z > fz0 - 2 and z < fz1 + 2), p.name .. " in der Frauenkirche bei " .. x .. "," .. z)
			check(not (x > M.rathaus.x0 - 2 and x < M.rathaus.x1 + 2 and z > M.rathaus.z0 - 2 and z < M.rathaus.z1 + 6), p.name .. " im Rathaus")
			check(not (x > kiosk.x0 - 2 and x < kiosk.x1 + 2 and z > kiosk.z0 - 2 and z < kiosk.z1 + 2), p.name .. " im Kiosk")
			check(not (x > U.x0 - 3 and x < U.x1 + 3 and z > U.z0 - U.gang - 3 and z < U.z1 + 3), p.name .. " am U-Bahn-Abgang")
		end
	end
	check(mp.stats.lamps >= 14 and mp.stats.trees >= 8 and mp.stats.bikes >= 12, "Marienplatz: Leuchten " .. mp.stats.lamps .. ", Bäume " .. mp.stats.trees .. ", Räder " .. mp.stats.bikes)
	print(string.format("Marienplatz: Rathaus %d Teile, Platz %d Teile, %d Kugelleuchten, %d Platanen", #rh, #mp.parts, mp.stats.lamps, mp.stats.trees))
end

-- ===== Isar-Allee (Ostufer): Straße, Radweg, Laternen, Bäume, Parkbuchten =====
do
	local a = Config.allee
	local nx, nz = -a.uz, a.ux -- Normale nach Westen (zur Isar)
	local function across(x, z) return (x - a.ax) * nx + (z - a.az) * nz end
	local function along(x, z) return (x - a.ax) * a.ux + (z - a.az) * a.uz end
	local half = Config.profiles.allee.half
	for t = 0, a.len, 40 do -- parallel zur Isar, Gehwegkante hinter der Böschungskante
		local d = Geo.polyDist(a.ax + a.ux * t, a.az + a.uz * t, Config.water.isar.pts)
		check(math.abs(d - 126.5) < 3, "Allee nicht parallel zur Isar: " .. d)
		check(d - 33.5 >= Config.water.isar.layers[1][3] + 2.5, "Allee-Gehweg zu nah an der Isar-Böschung: " .. (d - 33.5))
	end
	local kinds = {}
	for _, p in ipairs(parts) do
		if p.seg and segs[p.seg].road.name == "IsarAllee" then kinds[p.kind] = (kinds[p.kind] or 0) + 1 end
		if p.kind == "bike" then check(p.color[1] > 150 and p.color[2] < 90 and p.color[3] < 90, "Radweg nicht rot") end
	end
	check(kinds.road and kinds.bike and kinds.green and kinds.walk, "Allee: Streifen fehlen")
	local lt = LightsPlanner.plan(Config, road)
	local lampT = {}
	for _, p in ipairs(lt.parts) do
		if p.name == "LaternenMast" and math.abs(across(p.pos[1], p.pos[3]) - 3.5) < 0.2 and along(p.pos[1], p.pos[3]) > 0 and along(p.pos[1], p.pos[3]) < a.len then lampT[#lampT + 1] = along(p.pos[1], p.pos[3]) end
	end
	table.sort(lampT)
	check(#lampT >= 8, "Allee: Laternen " .. #lampT)
	for i = 2, #lampT do check(math.abs(lampT[i] - lampT[i - 1] - 48) < 0.5, "Allee: Laternenabstand " .. (lampT[i] - lampT[i - 1])) end
	local Garden = require("Garden")
	local gp = Garden.plan(Config, road, require("Specials")).parts
	local trunks, treeT = 0, {}
	for _, p in ipairs(gp) do
		if p.name == "AlleeStamm" then
			trunks = trunks + 1
			treeT[#treeT + 1] = along(p.pos[1], p.pos[3])
			check(math.abs(across(p.pos[1], p.pos[3]) - 19.5) < 0.2, "Allee: Baum nicht im Grünstreifen")
		end
	end
	table.sort(treeT)
	check(trunks == math.floor((a.trees.to - a.trees.from) / a.trees.step) + 1, "Allee: Bäume " .. trunks)
	for i = 2, #treeT do check(math.abs(treeT[i] - treeT[i - 1] - a.trees.step) < 0.5, "Allee: Baumabstand") end
	for _, tl in ipairs(treeT) do for _, ll in ipairs(lampT) do check(math.abs(tl - ll) > 3, "Allee: Baum und Laterne zu nah") end end
	local bayLines = 0
	for _, p in ipairs(parts) do
		if p.name == "BayLine" and along(p.pos[1], p.pos[3]) > 0 and along(p.pos[1], p.pos[3]) < a.len and math.abs(across(p.pos[1], p.pos[3]) + a.bay.off) < 0.2 then
			bayLines = bayLines + 1
			check(p.yaw ~= 0 and math.abs(p.size[3] - Config.bay.width) < 1e-6, "Allee: Parklinie nicht quer zur Straße")
		end
	end
	check(bayLines >= 20, "Allee: Parklinien " .. bayLines)
	check(Config.ring.xmax == 1200 and Config.map.xmax == 1260, "Karte nicht nach Osten erweitert")
end

print(string.format("Wand: Höhe %d bis %d", minH, maxH))
if failures > 0 then
	print(failures .. " FEHLER")
	error("Tests fehlgeschlagen")
end
print("Alle Karten-Tests bestanden")
