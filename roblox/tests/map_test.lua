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

check(road.stats.bays == 157, "Parkbuchten " .. road.stats.bays .. " statt 157 (Plan)")
for _, p in ipairs(parts) do
	check(p.pos[2] > -25 and p.pos[2] < 20, "Teil " .. p.name .. " liegt auf Höhe " .. p.pos[2])
	check(p.size[1] > 0 and p.size[2] > 0 and p.size[3] > 0, "Teil " .. p.name .. " ohne Größe")
end

-- Gehwege liegen nie in einer anderen Straße (dort würde ein Bordstein quer über die Kreuzung laufen)
local function inSeg(px, pz, s, margin)
	local dx, dz = px - s.rect.ax, pz - s.rect.az
	local a, b = dx * s.rect.ux + dz * s.rect.uz, dx * s.rect.nx + dz * s.rect.nz
	return a > s.rect.s0 + margin and a < s.rect.s1 - margin and math.abs(b) < s.rect.w - margin
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
				if s.id ~= p.seg and inSeg(x, z, s, 0.5) then hit = s.road.name break end
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

-- Jede Straßen-Mittellinie ist asphaltiert (außer im Tunnelbereich der Achse)
local tun = Config.tunnel
local uncovered = 0
for _, s in ipairs(segs) do
	local steps = math.floor(s.len / 15)
	for k = 0, steps do
		local t = math.min(s.len, k * 15)
		local x, z = s.ax + s.ux * t, s.az + s.uz * t
		local underground = s.road.name == tun.road and z > tun.z0 + 0.5 and z < tun.z1 - 0.5
		if not underground and s.prof.strips[1][3] ~= "plaza" then
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

-- Tunnel: oben keine Fahrbahn und kein Mittelstreifen der Achse zwischen z0 und z1 (Betrag x < 34)
local leaks = 0
for _, p in ipairs(parts) do
	local onAxis = p.seg and segs[p.seg].road.name == tun.road
	if onAxis and (p.kind == "road" or p.kind == "median" or p.kind == "dash") then
		if math.abs(p.pos[1]) < 34 and p.pos[3] > tun.z0 + 1 and p.pos[3] < tun.z1 - 1 then leaks = leaks + 1 end
	end
end
check(leaks == 0, leaks .. " Achsen-Teile über dem Tunnel")
local ramps = {}
for _, p in ipairs(parts) do
	if p.name == "Rampe" then ramps[#ramps + 1] = p end
end
check(#ramps == 2, "zwei Rampen erwartet")
for _, r in ipairs(ramps) do
	check(math.abs(math.abs(r.pitch) - math.deg(math.atan2(17, 136))) < 0.01, "Rampenneigung " .. r.pitch)
	check(math.abs(r.pos[2] - (-8.5)) < 0.01, "Rampenhöhe " .. r.pos[2])
end
check(ramps[1].pitch > 0 and ramps[2].pitch < 0, "Rampe Nord fällt nach Süden, Rampe Süd steigt")
local clear = 0
for _, p in ipairs(parts) do
	if p.name == "TunnelBoden" then clear = (-2.6) - (p.pos[2] + 0.5) end
end
check(clear >= 13.5, "lichte Höhe " .. clear)

-- Gewölbte Isar-Brücken: Scheitel, Enden auf Straßenniveau, zwei Pfeiler, darunter keine flache Straße mehr
for _, b in ipairs(Config.archBridges) do
	local r = math.rad(b.yaw)
	local ux, uz = math.cos(r), -math.sin(r)
	local topMax, topEnd, n, piers, flat = -1e9, 1e9, 0, 0, 0
	for _, p in ipairs(parts) do
		local along = (p.pos[1] - b.x) * ux + (p.pos[3] - b.z) * uz
		local across = -(p.pos[1] - b.x) * uz + (p.pos[3] - b.z) * ux
		if p.name == "BrueckeFahrbahn" and math.abs(across) < 2 and math.abs(along) < b.len / 2 + 1 then
			n = n + 1
			local top = p.pos[2] + 2 -- Platte 4 dick, Oberkante etwa Mitte + 2
			topMax = math.max(topMax, top)
			if math.abs(along) > b.len / 2 - b.len / 16 then topEnd = math.min(topEnd, top) end
		end
		if p.name == "BrueckePfeiler" and math.abs(across) < 2 and math.abs(along) < b.len / 2 then
			piers = piers + 1
			check(math.abs((p.pos[2] - p.size[2] / 2) - (-14)) < 0.01, b.name .. " Pfeiler steht nicht auf dem Flussbett")
		end
		if p.seg and (p.kind == "road" or p.kind == "walk" or p.kind == "median") and math.abs(across) < 24 and math.abs(along) < b.len / 2 - 3 then flat = flat + 1 end
	end
	check(n == 16, b.name .. " Fahrbahnplatten " .. n)
	check(math.abs(topMax - (0.5 + b.peak)) < 0.8, b.name .. " Scheitelhöhe " .. topMax .. " statt " .. (0.5 + b.peak))
	check(topEnd < 0.5 + 2.5, b.name .. " Brückenenden zu hoch: " .. topEnd)
	check(piers == 2, b.name .. " Pfeiler " .. piers)
	check(flat == 0, b.name .. ": " .. flat .. " flache Straßenteile unter der Brücke")
end

-- Brücken
local decks = 0
for _, p in ipairs(parts) do
	if p.kind == "deck" then decks = decks + 1 end
end
check(decks == #Config.bridges + 2 * #Config.archBridges, "Brückendecks und Pfeiler " .. decks)

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

-- ===== Laternen und Ampeln =====
local lights = LightsPlanner.plan(Config, road)
print(string.format("Beleuchtung: %d Laternen, %d Ampeln, %d Fußgängerampeln, %d Teile", lights.stats.lamps, lights.stats.signals, lights.stats.ped, #lights.parts))
check(lights.stats.lamps > 250, "zu wenige Laternen: " .. lights.stats.lamps)
check(lights.stats.signals == #Config.signals and lights.stats.ped == 2, "Ampeln unvollständig")
-- Nummerierung der Ampelgruppen laut Plan: Ring Nord, H1, Odeonsplatz, 2 Wachen-Ausfahrten
local groups = {}
for _, s in ipairs(Config.signals) do groups[s.name] = true end
local ng = 0
for _ in pairs(groups) do ng = ng + 1 end
check(ng == 5, "Ampelanlagen " .. ng .. " statt 5")
-- Jeder Mast (Laterne, Ampel) steht auf einem Gehweg und in keiner Fahrbahn einer Straße
local carriage = {}
for _, p in ipairs(parts) do
	if p.kind == "road" or p.kind == "median" or p.kind == "tunnel" then carriage[#carriage + 1] = p end
end
local masts, onRoad, offWalk = 0, 0, 0
for _, p in ipairs(lights.parts) do
	if p.name == "LaternenMast" or p.name == "AmpelMast" or p.name == "FussgaengerMast" then
		masts = masts + 1
		local onWalkPart = false
		for _, w in ipairs(parts) do
			if (w.kind == "walk" or w.kind == "plaza") and Geo.inPart(p.pos[1], p.pos[3], w, 0) then onWalkPart = true break end
		end
		local onAsphalt = false
		for _, c in ipairs(carriage) do
			if c.pos[2] > -3 and Geo.inPart(p.pos[1], p.pos[3], c, 0) then onAsphalt = true break end
		end
		if not onWalkPart then offWalk = offWalk + 1 print("  Mast ohne Gehweg: " .. p.name .. " bei " .. p.pos[1] .. "," .. p.pos[3]) end
		if onAsphalt then onRoad = onRoad + 1 print("  Mast auf Fahrbahn: " .. p.name .. " bei " .. p.pos[1] .. "," .. p.pos[3]) end
	end
end
check(masts == lights.stats.lamps + lights.stats.signals + lights.stats.ped, "Mastanzahl " .. masts)
check(onRoad == 0, onRoad .. " Masten auf der Fahrbahn")
check(offWalk == 0, offWalk .. " Masten außerhalb von Gehwegen")
-- Laternen stehen nicht dichter als der halbe Abstand (keine doppelten)
local lampPos = {}
for _, p in ipairs(lights.parts) do
	if p.name == "LaternenMast" then lampPos[#lampPos + 1] = p end
end
local close = 0
for i = 1, #lampPos do
	for j = i + 1, #lampPos do
		local dx, dz = lampPos[i].pos[1] - lampPos[j].pos[1], lampPos[i].pos[3] - lampPos[j].pos[3]
		if dx * dx + dz * dz < 10 * 10 then close = close + 1 end
	end
end
check(close == 0, close .. " Laternenpaare enger als 10 Studs")
-- Leopoldstraße (Achse, nördlich des Tunnels) hat Laternen auf beiden Seiten
local west, east = 0, 0
for _, p in ipairs(lampPos) do
	if math.abs(p.pos[1]) > 40 and math.abs(p.pos[1]) < 60 and p.pos[3] < -150 then
		if p.pos[1] < 0 then west = west + 1 else east = east + 1 end
	end
end
check(west > 3 and east > 3, "Achse: Laternen West " .. west .. ", Ost " .. east)
-- Signalkopf: pro Ampelmast 3 Lampen, genau eine (rot) an
local lampsOn, signalLamps = 0, 0
for _, p in ipairs(lights.parts) do
	if p.tag == "TrafficLight" then
		signalLamps = signalLamps + 1
		if p.attrs.Lit then lampsOn = lampsOn + 1 end
	end
end
check(signalLamps == 3 * #Config.signals and lampsOn == #Config.signals, "Ampellampen " .. signalLamps .. "/" .. lampsOn)

print(string.format("Wand: Höhe %d bis %d", minH, maxH))
if failures > 0 then
	print(failures .. " FEHLER")
	error("Tests fehlgeschlagen")
end
print("Alle Karten-Tests bestanden")
