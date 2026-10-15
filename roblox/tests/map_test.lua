-- Tests für Straßen, Terrain und Mapgrenze (kein Roblox nötig):  python3 run_with_lupa.py map_test.lua
package.path = "../MapBuilder/?.lua;MapBuilder/?.lua;roblox/MapBuilder/?.lua;" .. package.path
local Config = require("Config")
local Geo = require("Geo")
local RoadsPlanner = require("RoadsPlanner")
local TerrainPlanner = require("TerrainPlanner")
local WallPlanner = require("WallPlanner")
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
	check(p.pos[2] > -25 and p.pos[2] < 6, "Teil " .. p.name .. " liegt auf Höhe " .. p.pos[2])
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
	if p.kind == "walk" then
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

-- Brücken
local decks = 0
for _, p in ipairs(parts) do
	if p.kind == "deck" then decks = decks + 1 end
end
check(decks == #Config.bridges, "Brückendecks " .. decks)

-- ===== Terrain =====
local ops = TerrainPlanner.plan(Config)
print(string.format("Terrain: %d Operationen", #ops))
local area = 0
for _, o in ipairs(ops) do
	if o.op == "block" and o.material == "Pavement" then area = area + o.size[1] * o.size[3] end
end
local m = Config.map
check(math.abs(area - (m.xmax - m.xmin) * (m.zmax - m.zmin)) < 1e-6, "Bodenkacheln decken die Karte nicht genau ab: " .. area)
local air, water = 0, 0
for _, o in ipairs(ops) do
	if o.material == "Air" then air = air + 1 end
	if o.material == "Water" then
		water = water + 1
		check(o.pos[2] + o.size[2] / 2 <= -4 + 1e-6, "Wasser über der Wasserlinie")
		check(o.pos[2] - o.size[2] / 2 >= -14 - 1e-6, "Wasser unter dem Flussbett")
	end
end
-- Isar: 11 Segmente x 4 Schichten + 4 Schichten x 11 Segmente Wasser (nur Schichten unter -8: 2) ; Bach analog
check(air == 11 * 4 + 6 * 2 + 1, "Ausheb-Operationen " .. air)
check(water == 11 * 2 + 6 * 1, "Flut-Operationen " .. water)

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

print(string.format("Wand: Höhe %d bis %d", minH, maxH))
if failures > 0 then
	print(failures .. " FEHLER")
	error("Tests fehlgeschlagen")
end
print("Alle Karten-Tests bestanden")
