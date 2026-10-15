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
					if j ~= i and Geo.inPart(px, pz, b, 0.2) and math.abs(ta - (b.pos[2] + b.size[2] / 2)) < 0.03 then same = same + 1 end
				end
			end
		end
	end
	check(same == 0, same .. " Überlappungen mit gleicher Oberkante (Flackern)")
end

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

-- ===== Ampeln =====
local lights = LightsPlanner.plan(Config)
print(string.format("Ampeln: %d Masten, %d Fußgängerampeln, %d Teile", lights.stats.signals, lights.stats.ped, #lights.parts))
check(lights.stats.signals == #Config.signals and lights.stats.ped == 2, "Ampeln unvollständig")
local groups, ng = {}, 0
for _, s in ipairs(Config.signals) do
	if not groups[s.name] then groups[s.name] = true ng = ng + 1 end
end
check(ng == 5, "Ampelanlagen " .. ng .. " statt 5")
-- Jeder Mast steht auf einem Gehweg und in keiner Fahrbahn
local masts = 0
for _, p in ipairs(lights.parts) do
	if p.name == "AmpelMast" or p.name == "FussgaengerMast" then
		masts = masts + 1
		local onWalkPart, onAsphalt = false, false
		for _, w in ipairs(parts) do
			if w.kind == "walk" and Geo.inPart(p.pos[1], p.pos[3], w, 0) then onWalkPart = true end
			if (w.kind == "road" or w.kind == "median") and w.pos[2] > -3 and Geo.inPart(p.pos[1], p.pos[3], w, 0) then onAsphalt = true end
		end
		check(onWalkPart, "Mast ohne Gehweg: " .. p.name .. " bei " .. p.pos[1] .. "," .. p.pos[3])
		check(not onAsphalt, "Mast auf Fahrbahn: " .. p.name .. " bei " .. p.pos[1] .. "," .. p.pos[3])
	end
end
check(masts == #Config.signals + #Config.pedSignals, "Mastanzahl " .. masts)
-- Signalkopf: pro Mast 3 Lampen, genau eine (rot) an; jede Lampe kennt Gruppe, Achse und Farbe für Ampel.lua
local on, total = 0, 0
for _, p in ipairs(lights.parts) do
	if p.tag == "TrafficLight" then
		total = total + 1
		if p.attrs.Lit then on = on + 1 end
		check(p.attrs.Group and (p.attrs.Axis == "NS" or p.attrs.Axis == "EW") and p.attrs.Lamp, "Ampellampe ohne Attribute")
	end
end
check(total == 3 * #Config.signals and on == #Config.signals, "Ampellampen " .. total .. "/" .. on)

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

print(string.format("Wand: Höhe %d bis %d", minH, maxH))
if failures > 0 then
	print(failures .. " FEHLER")
	error("Tests fehlgeschlagen")
end
print("Alle Karten-Tests bestanden")
