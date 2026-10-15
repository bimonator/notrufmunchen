-- Planner.lua
-- Reine Geometrie für Häuser (Blockränder, Sonderbauten, Mapgrenze). Keine Roblox-Funktionen, läuft in Luau und in Lua 5.1 (Tests).
-- Koordinaten wie im Kartenplan: x = Ost, z = Süd, y = oben. Einheiten: Studs.
-- Lokales Haus-System: x läuft entlang der Fassade, z zeigt von der Fassade in den Block hinein, y nach oben.
-- Alles, was vor der Wand liegt (Fenster, Gesimse, Balkone), hat lokal z < 0.

local Planner = {}

Planner.DEFAULTS = {
	depth = 28, -- Gebäudetiefe
	setback = 2, -- Abstand der Fassade zur Blockkante (der Gehweg liegt schon in der Straße)
	targetWidth = 30, -- Mindest-Durchschnittsbreite eines Hauses (Anzahl = Länge / targetWidth, abgerundet)
	floorY = 1, -- Gehweg-Oberkante = Boden des Erdgeschosses
	groundH = 14, -- Höhe Erdgeschoss
	upperH = 12, -- Höhe jedes Obergeschosses
	floorWeights = { { 3, 0.2 }, { 4, 0.35 }, { 5, 0.3 }, { 6, 0.15 } }, -- Geschosse und ihre Häufigkeit
	seed = 1,
	litChance = 0.35, -- Anteil Fenster, die nachts leuchten
	simple = false, -- true: keine Fensterbänke, Balkone, Schornsteine, Erker, Seitenfenster (Mapgrenze, spart Teile)
	palette = { -- Putzfarben (RGB 0-255)
		{ 236, 226, 200 }, { 232, 208, 150 }, { 214, 200, 178 }, { 228, 186, 150 }, { 196, 204, 200 }, { 214, 168, 150 },
		{ 188, 200, 216 }, { 240, 224, 160 }, { 222, 170, 130 }, { 240, 238, 232 }, { 176, 190, 170 }, { 200, 200, 204 },
	},
}

local function round3(v)
	return math.floor(v * 1000 + 0.5) / 1000
end

local function hash(s)
	local h = 0
	for i = 1, #s do
		h = (h * 31 + string.byte(s, i)) % 2147483647
	end
	return h
end

-- Park-Miller: Zwischenwerte bleiben unter 2^53, daher in Luau und Lua 5.1 identisch.
local function newRng(seed)
	local state = (seed % 2147483646) + 1
	local self = {}
	function self.next()
		state = (state * 16807) % 2147483647
		return state / 2147483647
	end
	function self.int(a, b) -- beide Grenzen eingeschlossen
		return a + math.floor(self.next() * (b - a + 1))
	end
	function self.pick(t)
		return t[self.int(1, #t)]
	end
	function self.weighted(list) -- { { wert, gewicht }, ... }
		local r, cum = self.next(), 0
		for _, e in ipairs(list) do
			cum = cum + e[2]
			if r <= cum then return e[1] end
		end
		return list[#list][1]
	end
	return self
end

local function tint(c, f) -- Richtung weiß mischen
	return { math.floor(c[1] + (255 - c[1]) * f), math.floor(c[2] + (255 - c[2]) * f), math.floor(c[3] + (255 - c[3]) * f) }
end

local function shade(c, f) -- Richtung schwarz mischen
	return { math.floor(c[1] * (1 - f)), math.floor(c[2] * (1 - f)), math.floor(c[3] * (1 - f)) }
end

local function mergeOpts(opts)
	local o = {}
	for k, v in pairs(Planner.DEFAULTS) do o[k] = v end
	if opts then
		for k, v in pairs(opts) do o[k] = v end
	end
	return o
end

-- Teil im lokalen Haus-System anlegen; Position wird in Weltkoordinaten umgerechnet.
local function add(h, name, kind, lx, ly, lz, sx, sy, sz, color, material, extra)
	extra = extra or {}
	local r = math.rad(h.yaw)
	local c, s = math.cos(r), math.sin(r)
	local part = {
		name = name, kind = kind,
		size = { sx, sy, sz },
		pos = { round3(h.ox + lx * c + lz * s), round3(ly), round3(h.oz - lx * s + lz * c) },
		yaw = (h.yaw + (extra.yaw or 0)) % 360, pitch = extra.pitch or 0,
		color = color, material = material,
		collide = extra.collide == true,
		lit = extra.lit, tag = extra.tag,
		lpos = { lx, ly, lz },
	}
	h.parts[#h.parts + 1] = part
	return part
end

-- Fläche (face) "front", "+x" oder "-x"; u = Position entlang der Fläche, d = Abstand vor der Wand
local function onFace(h, face, u, d)
	if face == "front" then return u, -d, 0 end
	if face == "+x" then return h.width / 2 + d, u, -90 end
	return -h.width / 2 - d, u, 90
end

local FRAME = { 70, 62, 56 }
local GLASS = { 70, 92, 112 }
local GLASS_LIT = { 255, 214, 140 }
local SHUTTERS = { { 70, 100, 80 }, { 110, 60, 50 }, { 60, 70, 100 }, { 90, 90, 94 } }
local AWNINGS = { { 190, 60, 50 }, { 60, 100, 150 }, { 70, 130, 90 }, { 220, 170, 60 } }

-- Fenster: Rahmen und Scheibe sitzen vor der Wand (kein Ausschnitt), Fensterbank darunter. shift = zusätzlicher Abstand (Erker).
local function addWindow(h, label, face, u, yc, w, hgt, lit, shift)
	shift = shift or 0
	local lx, lz, ey = onFace(h, face, u, 0.2 + shift)
	add(h, "Frame" .. label, "frame", lx, yc, lz, w + 1.6, hgt + 1.6, 0.4, FRAME, "SmoothPlastic", { yaw = ey })
	lx, lz = onFace(h, face, u, 0.4 + shift)
	add(h, "Glass" .. label, "glass", lx, yc, lz, w, hgt, 0.2, lit and GLASS_LIT or GLASS, "Glass", { yaw = ey, lit = lit, tag = "HouseWindow" })
	if h.simple then return end
	lx, lz = onFace(h, face, u, 0.5 + shift)
	add(h, "Sill" .. label, "trim", lx, yc - hgt / 2 - 1.1, lz, w + 3, 0.6, 1.0, { 200, 196, 188 }, "Concrete", { yaw = ey })
end

local function planHouse(h, o, rng, cornerA, cornerB)
	local W, D = h.width, h.depth
	local floors = rng.weighted(o.floorWeights)
	if h.forceFloors then floors = h.forceFloors end
	local H = o.groundH + o.upperH * (floors - 1)
	local y0 = o.floorY
	local facade = rng.pick(o.palette)
	if h.color then facade = h.color end
	local doorSign = (rng.next() < 0.5) and -1 or 1
	local balconyStyle = rng.weighted({ { "none", 0.35 }, { "single", 0.25 }, { "full", 0.15 }, { "juliet", 0.25 } })
	local roofRoll = rng.next()
	local roof = (roofRoll < 0.5) and "flat" or ((roofRoll < 0.8 and floors >= 4) and "mansard" or ((floors <= 4) and "staffel" or "flat"))
	local chimneys = rng.int(0, 2)
	local erker = rng.next() < 0.4 and floors >= 4 and W >= 28 and not h.simple
	local shutters = rng.next() < 0.35 and not h.simple
	local shop = rng.next() < 0.4 and W >= 30
	local plinthColor = rng.pick({ { 140, 140, 140 }, { 112, 104, 98 }, { 160, 150, 138 } })
	local ledgeColor = (rng.next() < 0.5) and tint(facade, 0.35) or shade(facade, 0.12)
	local shutterColor = rng.pick(SHUTTERS)
	local awning = rng.pick(AWNINGS)
	h.floors, h.height, h.facade, h.roof = floors, H, facade, roof

	-- Hauptkörper, Sockel, Gesimse
	add(h, "Body", "body", 0, y0 + H / 2, D / 2, W, H, D, facade, "SmoothPlastic", { collide = true })
	add(h, "Plinth", "trim", 0, y0 + 1.2, -0.25, W, 2.4, 0.5, plinthColor, "Concrete")
	for k = 1, floors - 1 do
		local yb = y0 + o.groundH + o.upperH * (k - 1)
		add(h, "Ledge" .. k, "trim", 0, yb, -0.4, W, 0.7, 0.8, ledgeColor, "Concrete")
	end
	add(h, "Cornice", "trim", 0, y0 + H - 0.8, -0.8, W, 1.6, 1.6, tint(facade, 0.45), "Concrete")

	-- Dach: flach mit Attika, Mansarddach (steile Front, flaches Dach dahinter) oder zurückgesetztes Staffelgeschoss
	local base = y0 + H
	add(h, "Roof", "roof", 0, base + 0.3, D / 2, W, 0.6, D, { 96, 96, 100 }, "Concrete", { collide = true })
	local roofTop = base + 0.6
	if roof == "flat" or roof == "staffel" then
		add(h, "ParapetF", "trim", 0, base + 1.6, 0.4, W, 2, 0.8, tint(facade, 0.2), "Concrete")
		add(h, "ParapetB", "trim", 0, base + 1.6, D - 0.4, W, 2, 0.8, tint(facade, 0.2), "Concrete")
	end
	if roof == "mansard" then
		local run, rise = 3.5, 6
		local len = math.sqrt(run * run + rise * rise)
		add(h, "MansardFront", "roof", 0, base + rise / 2 + 0.3, run / 2, W, 0.8, len, { 88, 88, 96 }, "Metal", { pitch = -math.deg(math.atan2(rise, run)) })
		add(h, "MansardFill", "body", 0, base + rise / 2 + 0.3, run + (D - run - 1) / 2, W, rise, D - run - 1, shade(facade, 0.08), "SmoothPlastic", { collide = true })
		add(h, "MansardTop", "roof", 0, base + rise + 0.6, run + (D - run) / 2, W, 0.6, D - run, { 88, 88, 96 }, "Metal")
		roofTop = base + rise + 0.9
	elseif roof == "staffel" then
		add(h, "Staffel", "body", 0, roofTop + 5, D / 2, W - 4, 10, D - 12, tint(facade, 0.15), "SmoothPlastic", { collide = true })
		add(h, "StaffelGlass", "glass", 0, roofTop + 5, 5.8, W - 8, 6, 0.3, GLASS, "Glass", { tag = "HouseWindow", lit = false })
		add(h, "StaffelRoof", "roof", 0, roofTop + 10.3, D / 2, W - 3, 0.6, D - 11, { 96, 96, 100 }, "Concrete")
		roofTop = roofTop + 10.6
	end
	for i = 1, h.simple and 0 or chimneys do
		local lim = math.floor(W / 2 - 3)
		add(h, "Chimney" .. i, "chimney", rng.int(-lim, lim), roofTop + 3, D - 6, 2.5, 6, 2.5, { 170, 100, 80 }, "Brick")
	end

	-- Obergeschoss: Fenster, Erker, Fensterläden, Balkone
	local nw = math.max(2, math.floor((W - 4) / 9))
	local erkerIdx
	if erker then
		erkerIdx = 1
		for i = 1, nw do
			if math.abs(-W / 2 + (i - 0.5) * W / nw) < math.abs(-W / 2 + (erkerIdx - 0.5) * W / nw) then erkerIdx = i end
		end
		local ex = -W / 2 + (erkerIdx - 0.5) * W / nw
		local yb1 = y0 + o.groundH
		add(h, "Erker", "body", ex, yb1 + o.upperH, -1.25, 8, o.upperH * 2, 2.5, tint(facade, 0.1), "SmoothPlastic", { collide = true })
		add(h, "ErkerRoof", "trim", ex, yb1 + o.upperH * 2 + 0.3, -1.45, 8.6, 0.6, 3.1, { 96, 96, 100 }, "Concrete")
	end
	for k = 1, floors - 1 do
		local yb = y0 + o.groundH + o.upperH * (k - 1)
		for i = 1, nw do
			local u = -W / 2 + (i - 0.5) * W / nw
			local lit = rng.next() < o.litChance
			if erker and i == erkerIdx and k <= 2 then
				addWindow(h, "E" .. k, "front", u, yb + 6, 4.4, 6.4, lit, 2.5)
			else
				addWindow(h, "F" .. k .. "_" .. i, "front", u, yb + 6, 4.4, 6.4, lit)
				if shutters then
					for _, sd in ipairs({ -1, 1 }) do
						add(h, "Shutter" .. k .. "_" .. i, "trim", u + sd * 3.8, yb + 6, -0.15, 1.4, 7.8, 0.3, shutterColor, "Wood")
					end
				end
			end
		end
		if k >= 2 and not h.simple and balconyStyle ~= "none" and not (erker and k <= 2) then
			local bw = (balconyStyle == "full") and (W - 10) or math.min(14, W - 10)
			if balconyStyle ~= "juliet" and (balconyStyle == "full" or k % 2 == 0) then
				add(h, "Balcony" .. k, "balcony", 0, yb + 0.3, -1.25, bw, 0.6, 2.5, { 150, 150, 150 }, "Concrete")
				add(h, "Rail" .. k, "balcony", 0, yb + 2.1, -2.35, bw, 3, 0.3, { 60, 60, 66 }, "Metal")
			elseif balconyStyle == "juliet" then
				add(h, "Rail" .. k, "balcony", 0, yb + 2.1, -0.5, math.min(W - 12, 18), 2.4, 0.3, { 60, 60, 66 }, "Metal")
			end
		end
	end

	-- Erdgeschoss: Tür auf einer Seite; Schaufenster mit Markise oder zwei kleinere Fenster
	local a = W / 2 - 6
	local dx = doorSign * a
	add(h, "DoorFrame", "frame", dx, y0 + 5, -0.25, 6.4, 10, 0.5, { 70, 52, 42 }, "Wood")
	add(h, "Door", "door", dx, y0 + 4.5, -0.55, 5, 9, 0.3, { 110, 70, 45 }, "Wood")
	add(h, "DoorCanopy", "trim", dx, y0 + 10.6, -1, 7, 0.5, 2, { 120, 120, 124 }, "Concrete")
	if shop then
		local lo, hi = -W / 2 + 2, W / 2 - 2
		if doorSign > 0 then hi = dx - 4.5 else lo = dx + 4.5 end
		local ws = hi - lo
		addWindow(h, "Shop", "front", (lo + hi) / 2, y0 + 7.5, ws - 1.6, 7, rng.next() < o.litChance)
		add(h, "Awning", "trim", (lo + hi) / 2, y0 + 12, -1.6, ws, 0.5, 3.2, awning, "Concrete")
	elseif W >= 24 then
		local nwg = math.max(1, math.floor((W - 21) / 9) + 1)
		for i = 1, nwg do
			addWindow(h, "G_" .. i, "front", -dx + doorSign * 9 * (i - 1), y0 + 8, 4.4, 5.4, rng.next() < o.litChance)
		end
	end

	-- Eckhaus: Fenster auch an der Seitenfläche zur Querstraße
	for _, face in ipairs({ cornerA and "-x" or false, cornerB and "+x" or false }) do
		if face and not h.simple then
			for _, u in ipairs({ 7, D - 7 }) do
				for k = 1, floors - 1 do
					addWindow(h, "SideF" .. k .. "_" .. face .. u, face, u, y0 + o.groundH + o.upperH * (k - 1) + 6, 4.4, 6.4, rng.next() < o.litChance)
				end
				addWindow(h, "SideG_" .. face .. u, face, u, y0 + 8, 4.4, 5.4, rng.next() < o.litChance)
			end
		end
	end
end

-- Zufällige Hausbreiten, die genau die Länge füllen (Abweichung höchstens etwa +-10 % vom Durchschnitt)
local function splitWidths(len, n, rng)
	local w, sum = {}, 0
	for i = 1, n do
		w[i] = 0.9 + 0.2 * rng.next()
		sum = sum + w[i]
	end
	for i = 1, n do w[i] = len * w[i] / sum end
	return w
end

-- Häuser entlang mehrerer Fassadenlinien. side = { name, yaw, sx, sz, ux, uz, len, corners, ranges }
-- ranges = { { t0, t1 }, ... } begrenzt die bebaubaren Abschnitte (Lücken z. B. für Tore); Standard: ganze Länge.
local function planSides(name, sides, o, rng, plan, depth)
	for _, side in ipairs(sides) do
		local ranges = side.ranges or { { 0, side.len } }
		local idx = 0
		for ri, range in ipairs(ranges) do
			local len = range[2] - range[1]
			if len >= 12 then
				local n = math.max(1, math.floor(len / o.targetWidth))
				local widths = splitWidths(len, n, rng)
				local t = range[1]
				for i = 1, n do
					idx = idx + 1
					local width = widths[i]
					local h = {
						side = side.name, index = idx, simple = o.simple,
						ox = side.sx + side.ux * (t + width / 2), oz = side.sz + side.uz * (t + width / 2),
						yaw = side.yaw, width = width, depth = depth, parts = {},
						name = string.format("Haus_%s_%s%d", name, side.name, idx),
					}
					t = t + width
					planHouse(h, o, rng, side.corners and ri == 1 and i == 1, side.corners and ri == #ranges and i == n)
					plan.houses[#plan.houses + 1] = h
				end
			end
		end
	end
end

local function bodyOf(h)
	for _, p in ipairs(h.parts) do
		if p.name == "Body" then return p end
	end
end

-- Achsparallele Außenmaße eines Teils (Drehung nur in 90-Grad-Schritten).
function Planner.aabb(p)
	local sx, sy, sz = p.size[1], p.size[2], p.size[3]
	if p.yaw % 180 == 90 then sx, sz = sz, sx end
	return p.pos[1] - sx / 2, p.pos[2] - sy / 2, p.pos[3] - sz / 2, p.pos[1] + sx / 2, p.pos[2] + sy / 2, p.pos[3] + sz / 2
end

-- block = { name, xmin, zmin, xmax, zmax, reserved = { {x0,z0,x1,z1}, ... } } (Außenkante = Straßenrand).
-- Häuser, die in reserved-Flächen (Sonderbauten) stehen würden, entfallen.
function Planner.planBlock(block, opts)
	local o = mergeOpts(opts)
	local rng = newRng(o.seed + hash(block.name))
	local s, D = o.setback, o.depth
	local xmin, zmin, xmax, zmax = block.xmin, block.zmin, block.xmax, block.zmax
	local sides = {
		{ name = "N", yaw = 0, sx = xmin + s, sz = zmin + s, ux = 1, uz = 0, len = (xmax - xmin) - 2 * s, corners = true },
		{ name = "S", yaw = 180, sx = xmax - s, sz = zmax - s, ux = -1, uz = 0, len = (xmax - xmin) - 2 * s, corners = true },
		{ name = "W", yaw = 90, sx = xmin + s, sz = zmax - s - D, ux = 0, uz = -1, len = (zmax - zmin) - 2 * s - 2 * D, corners = false },
		{ name = "E", yaw = 270, sx = xmax - s, sz = zmin + s + D, ux = 0, uz = 1, len = (zmax - zmin) - 2 * s - 2 * D, corners = false },
	}
	local plan = { block = block, houses = {}, dropped = 0, courtyard = { xmin + s + D, zmin + s + D, xmax - s - D, zmax - s - D } }
	planSides(block.name, sides, o, rng, plan, D)
	if block.reserved then
		local kept = {}
		for _, h in ipairs(plan.houses) do
			local x0, _, z0, x1, _, z1 = Planner.aabb(bodyOf(h))
			local hit = false
			for _, r in ipairs(block.reserved) do
				if x0 < r[3] - 0.5 and x1 > r[1] + 0.5 and z0 < r[4] - 0.5 and z1 > r[2] + 0.5 then hit = true end
			end
			if hit then plan.dropped = plan.dropped + 1 else kept[#kept + 1] = h end
		end
		plan.houses = kept
	end
	return plan
end

-- Sonderbau (Bank, Wache, Krankenhaus ...) als Platzhalter-Gebäude auf einer Rechteckfläche.
-- spec = { name, x0, z0, x1, z1, facing = "N"|"S"|"E"|"W" (Seite zur Straße), floors, color, canopy = { x0, z0, x1, z1 } }
function Planner.planSpecial(spec, opts)
	local o = mergeOpts(opts)
	local rng = newRng(o.seed + hash(spec.name))
	local f = spec.facing
	local h = {
		side = f, index = 0, simple = false, forceFloors = spec.floors, color = spec.color, parts = {}, name = "Sonder_" .. spec.name,
	}
	if f == "N" then h.ox, h.oz, h.yaw, h.width, h.depth = (spec.x0 + spec.x1) / 2, spec.z0, 0, spec.x1 - spec.x0, spec.z1 - spec.z0
	elseif f == "S" then h.ox, h.oz, h.yaw, h.width, h.depth = (spec.x0 + spec.x1) / 2, spec.z1, 180, spec.x1 - spec.x0, spec.z1 - spec.z0
	elseif f == "W" then h.ox, h.oz, h.yaw, h.width, h.depth = spec.x0, (spec.z0 + spec.z1) / 2, 90, spec.z1 - spec.z0, spec.x1 - spec.x0
	else h.ox, h.oz, h.yaw, h.width, h.depth = spec.x1, (spec.z0 + spec.z1) / 2, 270, spec.z1 - spec.z0, spec.x1 - spec.x0 end
	planHouse(h, o, rng, false, false)
	if spec.canopy then -- Tankstellen-Schirm: Dach auf vier Pfeilern, 8 Zapfsäulen
		local c = spec.canopy
		local cx, cz, w, d = (c[1] + c[3]) / 2, (c[2] + c[4]) / 2, c[3] - c[1], c[4] - c[2]
		local function w3(name, x, y, z, sx, sy, sz, color, mat)
			h.parts[#h.parts + 1] = { name = name, kind = "trim", size = { sx, sy, sz }, pos = { round3(x), round3(y), round3(z) }, yaw = 0, pitch = 0, color = color, material = mat, collide = false, lpos = { 0, y, 0 } }
		end
		w3("CanopyRoof", cx, 14.5, cz, w, 1, d, { 232, 200, 60 }, "SmoothPlastic")
		for _, px in ipairs({ c[1] + 3, c[3] - 3 }) do
			for _, pz in ipairs({ c[2] + 3, c[4] - 3 }) do w3("CanopyPillar", px, 7.5, pz, 1.5, 14, 1.5, { 200, 200, 204 }, "Metal") end
		end
		for _, px in ipairs({ cx - 6, cx + 6 }) do
			for k = 0, 3 do w3("Pump", px, 3.5, c[2] + 10 + k * (d - 20) / 3, 1.5, 5, 1.5, { 200, 60, 50 }, "SmoothPlastic") end
		end
	end
	return { houses = { h } }
end

-- Mapgrenze: Häuserband rund um die Karte, Fassade zeigt nach innen zur Ringstraße.
-- wall = { inner = {xmin,zmin,xmax,zmax} (Ringaußenkante), outer = {...} (Kartenrand), gates = { N = {{x0,x1},...}, S = ... },
--          specials = { { side, name, x0, x1, floors } } }
function Planner.planWall(wall, opts)
	local o = mergeOpts(opts)
	o.simple, o.setback = true, 0
	local D = math.abs(wall.outer.xmin - wall.inner.xmin)
	local rng = newRng(o.seed + hash("Mapgrenze"))
	local ix0, iz0, ix1, iz1 = wall.inner.xmin, wall.inner.zmin, wall.inner.xmax, wall.inner.zmax
	local oz0, oz1 = wall.outer.zmin, wall.outer.zmax
	local function ranges(len, startCoord, dirSign, gaps) -- Lücken (Weltkoordinate) in Abschnitte entlang der Laufrichtung umrechnen
		local cuts = {}
		for _, g in ipairs(gaps or {}) do
			local a, b = (g[1] - startCoord) * dirSign, (g[2] - startCoord) * dirSign
			if a > b then a, b = b, a end
			cuts[#cuts + 1] = { a, b }
		end
		table.sort(cuts, function(p, q) return p[1] < q[1] end)
		local out, pos = {}, 0
		for _, c in ipairs(cuts) do
			if c[1] > pos then out[#out + 1] = { pos, c[1] } end
			pos = math.max(pos, c[2])
		end
		if pos < len then out[#out + 1] = { pos, len } end
		return out
	end
	local innerW = ix1 - ix0
	local sides = {
		{ name = "N", yaw = 180, sx = ix1, sz = iz0, ux = -1, uz = 0, len = innerW, ranges = ranges(innerW, ix1, -1, wall.gates.N) },
		{ name = "S", yaw = 0, sx = ix0, sz = iz1, ux = 1, uz = 0, len = innerW, ranges = ranges(innerW, ix0, 1, wall.gates.S) },
		{ name = "W", yaw = 270, sx = ix0, sz = oz0, ux = 0, uz = 1, len = oz1 - oz0 },
		{ name = "E", yaw = 90, sx = ix1, sz = oz1, ux = 0, uz = -1, len = oz1 - oz0 },
	}
	local plan = { houses = {}, wall = wall }
	planSides("Wand", sides, o, rng, plan, D)
	for _, sp in ipairs(wall.specials) do -- Sonderbauten in den Lücken (Querriegel, Feldherrnhalle)
		local north = sp.side == "N"
		local h = {
			side = sp.side, index = 0, simple = true, forceFloors = sp.floors,
			ox = (sp.x0 + sp.x1) / 2, oz = north and iz0 or iz1,
			yaw = north and 180 or 0, width = sp.x1 - sp.x0, depth = D, parts = {}, name = "Sonder_" .. sp.name,
		}
		planHouse(h, o, rng, false, false)
		plan.houses[#plan.houses + 1] = h
	end
	return plan
end

function Planner.stats(plan)
	local parts, area = 0, 0
	for _, h in ipairs(plan.houses) do
		parts = parts + #h.parts
		area = area + h.width * h.depth
	end
	return { houses = #plan.houses, parts = parts, footprint = area }
end

return Planner
