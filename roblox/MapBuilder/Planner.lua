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
		lit = extra.lit, tag = extra.tag, text = extra.text,
		lpos = { lx, ly, lz },
	}
	h.parts[#h.parts + 1] = part
	return part
end

-- Fläche (face) "front", "+x" oder "-x"; u = Position entlang der Fläche, d = Abstand vor der Wand
local function onFace(h, face, u, d)
	if face == "front" then return u, -d, 0 end
	if face == "back" then return u, h.depth + d, 180 end
	if face == "+x" then return h.width / 2 + d, u, -90 end
	return -h.width / 2 - d, u, 90
end

local FRAME = { 70, 62, 56 }
local GLASS = { 70, 92, 112 }
local GLASS_LIT = { 255, 214, 140 }
local SHUTTERS = { { 70, 100, 80 }, { 110, 60, 50 }, { 60, 70, 100 }, { 90, 90, 94 } }
local AWNINGS = { { 190, 60, 50 }, { 60, 100, 150 }, { 70, 130, 90 }, { 220, 170, 60 } }

-- Fenster: Rahmen und Scheibe sitzen vor der Wand (kein Ausschnitt), Fensterbank darunter. shift = zusätzlicher Abstand (Erker).
local function addWindow(h, label, face, u, yc, w, hgt, lit, shift, noSill)
	shift = shift or 0
	local lx, lz, ey = onFace(h, face, u, 0.2 + shift)
	add(h, "Frame" .. label, "frame", lx, yc, lz, w + 1.6, hgt + 1.6, 0.4, FRAME, "SmoothPlastic", { yaw = ey })
	lx, lz = onFace(h, face, u, 0.4 + shift)
	add(h, "Glass" .. label, "glass", lx, yc, lz, w, hgt, 0.2, lit and GLASS_LIT or GLASS, "Glass", { yaw = ey, lit = lit, tag = "HouseWindow" })
	if h.simple or noSill then return end
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

	-- Rückseite zum Innenhof: Fenster in jedem Geschoss, zwei Erdgeschossfenster und eine Hintertür
	if h.rear then
		for k = 1, floors - 1 do
			local yb = y0 + o.groundH + o.upperH * (k - 1)
			for i = 1, nw do
				addWindow(h, "R" .. k .. "_" .. i, "back", -W / 2 + (i - 0.5) * W / nw, yb + 6, 4.4, 6.4, rng.next() < o.litChance, 0, true)
			end
		end
		local bx, bz = onFace(h, "back", dx, 0.25)
		add(h, "BackDoorFrame", "frame", bx, y0 + 5, bz, 6.4, 10, 0.5, { 70, 52, 42 }, "Wood", { yaw = 180 })
		bx, bz = onFace(h, "back", dx, 0.55)
		add(h, "BackDoor", "door", bx, y0 + 4.5, bz, 5, 9, 0.3, { 110, 70, 45 }, "Wood", { yaw = 180 })
		for i = 1, math.max(1, math.floor((W - 21) / 9) + 1) do
			addWindow(h, "RG_" .. i, "back", -dx + doorSign * 9 * (i - 1), y0 + 8, 4.4, 5.4, rng.next() < o.litChance, 0, true)
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
			if len >= 24 then -- kürzere Lücken bleiben frei (Mindesthausbreite 24)
				local n = math.max(1, math.floor(len / o.targetWidth))
				local widths = splitWidths(len, n, rng)
				local t = range[1]
				for i = 1, n do
					idx = idx + 1
					local width = widths[i]
					local h = {
						side = side.name, index = idx, simple = o.simple, rear = o.rear ~= false,
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


-- Hinterhäuser: der Innenhof wird mit niedrigen Häusern (2 bis 3 Geschosse) in einem Raster gefüllt, dazwischen 12 Studs breite Gassen,
-- 14 Studs Abstand zu den Rückseiten der Randhäuser. Sonderflächen (reserved) und das Tankstellen-Grundstück (lot) bleiben mit 10 Studs Rand frei.
local function planInner(plan, block, o, rng)
	plan.inner = {}
	if block.noInner then return end
	local cy = plan.courtyard
	local M, GAP, TARGET, MAXW = 14, 12, 34, 46
	local x0, z0, x1, z1 = cy[1] + M, cy[2] + M, cy[3] - M, cy[4] - M
	local cols, rows = math.floor((x1 - x0 + GAP) / (TARGET + GAP)), math.floor((z1 - z0 + GAP) / (TARGET + GAP))
	if cols < 1 or rows < 1 then return end
	local cw, cd = (x1 - x0 - (cols - 1) * GAP) / cols, (z1 - z0 - (rows - 1) * GAP) / rows
	local w, d = math.min(cw, MAXW), math.min(cd, MAXW)
	local avoid = {}
	for _, r in ipairs(block.reserved or {}) do avoid[#avoid + 1] = r end
	if block.lot then avoid[#avoid + 1] = block.lot end
	for _, r in ipairs(block.avoidInner or {}) do avoid[#avoid + 1] = r end
	for r = 1, rows do
		for c = 1, cols do
			local cx, cz = x0 + (c - 1) * (cw + GAP) + cw / 2, z0 + (r - 1) * (cd + GAP) + cd / 2
			local blocked = false
			for _, a in ipairs(avoid) do
				if cx - w / 2 < a[3] + 10 and cx + w / 2 > a[1] - 10 and cz - d / 2 < a[4] + 10 and cz + d / 2 > a[2] - 10 then blocked = true end
			end
			if not blocked then
				local south = r % 2 == 0 -- Reihen wechseln die Blickrichtung
				local h = {
					side = "I", index = #plan.inner + 1, simple = true, rear = true, forceFloors = rng.int(2, 3),
					ox = cx, oz = south and cz + d / 2 or cz - d / 2, yaw = south and 180 or 0, width = w, depth = d, parts = {},
					name = string.format("Hof_%s_%d", block.name, #plan.inner + 1),
				}
				planHouse(h, o, rng, false, false)
				plan.inner[#plan.inner + 1] = h
			end
		end
	end
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
	-- Reservierte Flächen (Sonderbauten) sparen Abschnitte der Randbebauung aus; die Nachbarhäuser werden auf die Restlänge verteilt und
	-- schließen so bündig an die Sonderbauten an (eine durchgehende Häuserlinie).
	for _, side in ipairs(sides) do
		local r = math.rad(side.yaw)
		local cs, sn = math.cos(r), math.sin(r)
		local cuts = {}
		for _, rc in ipairs(block.reserved or {}) do
			local lo, hi, zlo, zhi = 1e9, -1e9, 1e9, -1e9
			for _, px in ipairs({ rc[1], rc[3] }) do
				for _, pz in ipairs({ rc[2], rc[4] }) do
					local lx, lz = (px - side.sx) * cs - (pz - side.sz) * sn, (px - side.sx) * sn + (pz - side.sz) * cs
					lo, hi, zlo, zhi = math.min(lo, lx), math.max(hi, lx), math.min(zlo, lz), math.max(zhi, lz)
				end
			end
			if zhi > 0.5 and zlo < D - 0.5 and hi > 0 and lo < side.len then cuts[#cuts + 1] = { math.max(0, lo), math.min(side.len, hi) } end
		end
		if #cuts > 0 then
			table.sort(cuts, function(a, b) return a[1] < b[1] end)
			local ranges, pos = {}, 0
			for _, cu in ipairs(cuts) do
				if cu[1] > pos then ranges[#ranges + 1] = { pos, cu[1] } end
				pos = math.max(pos, cu[2])
			end
			if pos < side.len then ranges[#ranges + 1] = { pos, side.len } end
			side.ranges = ranges
		end
	end
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
	planInner(plan, block, o, rng)
	return plan
end


-- ===== Sonderbauten nach Fotovorlagen (Feuerwache 4 Schwabing, Polizeiinspektion, Klinikum) =====
local DARKG = { 58, 60, 64 }
local GLASS_DARK = { 40, 50, 60 }
local WHITE = { 236, 236, 232 }

-- Fensterband: Glasfelder mit Pfosten und Riegeln zwischen u0 und u1; d = Abstand vor der Wand (negativ = zurückgesetzt).
-- litChance nil = nachts nicht beleuchtet (Tore), sonst Anteil leuchtender Felder.
local function ribbon(h, o, rng, face, yc, hgt, u0, u1, step, glass, frame, d, litChance, gateTag)
	local n = math.max(1, math.floor((u1 - u0) / step))
	local w = (u1 - u0) / n
	for i = 1, n do
		local u = u0 + (i - 0.5) * w
		local lx, lz, ey = onFace(h, face, u, d)
		local extra = { yaw = ey }
		if litChance then extra.tag, extra.lit = "HouseWindow", rng.next() < litChance end
		if gateTag then extra.tag = gateTag end
		add(h, "Glass", "glass", lx, yc, lz, w - 0.5, hgt, 0.2, glass, "Glass", extra)
		if i < n then
			lx, lz = onFace(h, face, u0 + i * w, d + 0.1)
			add(h, "Pfosten", "trim", lx, yc, lz, 0.5, hgt + 0.6, 0.5, frame, "Metal", { yaw = ey })
		end
	end
	local lx, lz, ey = onFace(h, face, (u0 + u1) / 2, d + 0.1)
	for _, dy in ipairs({ -hgt / 2 - 0.2, hgt / 2 + 0.2 }) do
		add(h, "Riegel", "trim", lx, yc + dy, lz, u1 - u0 + 0.4, 0.5, 0.5, frame, "Metal", { yaw = ey })
	end
end

-- Einzelfenster mit hellem Rahmen
local function win(h, o, rng, face, u, yc, w, hgt, frame, glass)
	local lx, lz, ey = onFace(h, face, u, 0.2)
	add(h, "Frame", "frame", lx, yc, lz, w + 1.4, hgt + 1.4, 0.4, frame, "SmoothPlastic", { yaw = ey })
	lx, lz = onFace(h, face, u, 0.4)
	add(h, "Glass", "glass", lx, yc, lz, w, hgt, 0.2, glass, "Glass", { yaw = ey, tag = "HouseWindow", lit = rng.next() < o.litChance })
end

-- Schrift: unsichtbare Platte mit SurfaceGui (Builder), Vorderseite zeigt in Blickrichtung des Teils
local function label(h, face, u, y, d, w, hgt, text, color)
	local lx, lz, ey = onFace(h, face, u, d)
	add(h, "Schrift", "text", lx, y, lz, w, hgt, 0.2, color, "SmoothPlastic", { yaw = ey, text = { s = text, color = color } })
end

-- Feuerwache: durchgehende Fahrzeughalle (hohl) mit 4 Toren vorn (Feuerwehr) und 4 hinten (Rettung), roter Obergeschoss-Block
-- mit Fensterbändern, höherer Kopfbau, Schrift, Mast. Die Tore sind Geisterteile (nicht kollidierend, Tag "FireGate"), damit man
-- schon durchfahren kann; ein späteres Skript kann sie öffnen und schließen.
local function styleFeuerwache(h, o, rng)
	local W, D, y0 = h.width, h.depth, o.floorY
	local RED, HALL, UP = { 192, 36, 34 }, { 44, 46, 52 }, 36
	h.floors, h.height, h.facade, h.roof = 4, 14 + UP, RED, "flat"
	add(h, "Hallenboden", "body", 0, y0 - 0.5, D / 2, W, 1, D, { 104, 106, 110 }, "Concrete", { collide = true })
	for _, side in ipairs({ -1, 1 }) do -- Seitenwände der Halle, bündig mit den Nachbarhäusern
		add(h, "HalleWand", "body", side * (W / 2 - 1.2), y0 + 7, D / 2, 2.4, 14, D - 6, HALL, "Concrete", { collide = true })
	end
	add(h, "Body", "body", 0, y0 + 14 + UP / 2, D / 2, W, UP, D, RED, "SmoothPlastic", { collide = true })
	local roofTop = y0 + 14 + UP + 0.6
	add(h, "Roof", "roof", 0, roofTop - 0.3, D / 2, W, 0.6, D, { 90, 90, 96 }, "Concrete", { collide = true })
	local bays, pw = 4, 2.4
	local bw = (W - 5 * pw) / bays
	for _, face in ipairs({ "front", "back" }) do
		for b = 0, bays do
			local u = -W / 2 + pw / 2 + b * (bw + pw)
			local lx, lz, ey = onFace(h, face, u, -4.2)
			add(h, "Pfeiler", "trim", lx, y0 + 7, lz, pw, 14, 2.4, DARKG, "Concrete", { yaw = ey, collide = true })
			if b < bays then
				lx, lz = onFace(h, face, u + pw / 2 + bw / 2, -4.2)
				add(h, "Sturz", "trim", lx, y0 + 13, lz, bw, 2, 2.4, DARKG, "Concrete", { yaw = ey, collide = true })
				local u0 = u + pw / 2
				ribbon(h, o, rng, face, y0 + 6, 11.6, u0 + 0.5, u0 + bw - 0.5, 3.6, GLASS_DARK, DARKG, -3.6, nil, "FireGate")
			end
		end
		for k = 1, 3 do
			ribbon(h, o, rng, face, y0 + 14 + 12 * (k - 1) + 6, 5.6, -W / 2 + 4, W / 2 - 4, 7, GLASS, DARKG, 0.2, o.litChance)
		end
	end
	local tbw = W / 3 -- Kopfbau am Ostende, bündig zur Front
	add(h, "TopBlock", "body", W / 2 - tbw / 2, roofTop + 6, D * 0.3, tbw, 12, D * 0.6, RED, "SmoothPlastic", { collide = true })
	add(h, "TopBand", "trim", W / 2 - tbw / 2, roofTop + 9.5, -0.15, tbw, 2.4, 0.3, GLASS_DARK, "SmoothPlastic")
	add(h, "Antenne", "trim", W / 2 - 4, roofTop + 20, D * 0.45, 0.6, 16, 0.6, { 140, 140, 146 }, "Metal")
	label(h, "front", W / 2 - tbw / 2, roofTop + 4.5, 0.2, tbw - 4, 4, "FEUERWACHE SCHWABING", { 250, 250, 250 })
	label(h, "back", 0, y0 + 14 + UP - 1.7, 0.2, 40, 2.6, "RETTUNGSWACHE", { 250, 250, 250 })
end

-- Polizeiinspektion: roter Sockel, graue Obergeschosse mit hellen Fensterrahmen, Durchfahrt zum Innenhof, blaues Schild
local function stylePolizei(h, o, rng)
	local W, D, y0 = h.width, h.depth, o.floorY
	local floors = h.forceFloors or 4
	local GREY, RED, UP = { 92, 94, 104 }, { 190, 52, 48 }, o.upperH * (floors - 1)
	h.floors, h.height, h.facade, h.roof = floors, 14 + UP, GREY, "flat"
	add(h, "Body", "body", 0, y0 + 14 + UP / 2, D / 2, W, UP, D, GREY, "SmoothPlastic", { collide = true })
	add(h, "Roof", "roof", 0, y0 + 14 + UP + 0.3, D / 2, W, 0.6, D, { 80, 80, 86 }, "Concrete", { collide = true })
	local a0, a1 = W / 2 - 36, W / 2 - 22 -- Durchfahrt (14 breit, 14 hoch) bleibt offen; lokal +x ist bei Blick nach Süden Westen
	local nwin = math.floor((a0 + W / 2 - 16) / 12)
	add(h, "GroundL", "body", (-W / 2 + a0) / 2, y0 + 7, D / 2, a0 + W / 2, 14, D, RED, "SmoothPlastic", { collide = true })
	add(h, "GroundR", "body", (a1 + W / 2) / 2, y0 + 7, D / 2, W / 2 - a1, 14, D, RED, "SmoothPlastic", { collide = true })
	for _, face in ipairs({ "front", "back" }) do
		local lx, lz, ey = onFace(h, face, a1 + 1.5, 1.5)
		add(h, "Pfeiler", "trim", lx, y0 + 7, lz, 3, 14, 3, WHITE, "Concrete", { yaw = ey, collide = true })
		for i = 1, nwin do win(h, o, rng, face, a0 - 8 - 12 * (i - 1), y0 + 7.5, 4.6, 8, DARKG, { 70, 110, 100 }) end
		local nw = math.floor((W - 8) / 9)
		for k = 1, floors - 1 do
			for i = 1, nw do
				win(h, o, rng, face, -W / 2 + 4 + (i - 0.5) * (W - 8) / nw, y0 + 14 + 12 * (k - 1) + 6, 5.2, 5.8, WHITE, GLASS)
			end
		end
	end
	local ux = W / 2 - 11 -- Eingang mit Vordach und blauem Schild
	add(h, "DoorFrame", "frame", ux, y0 + 5, -0.25, 6.4, 10, 0.5, DARKG, "Metal")
	add(h, "Door", "door", ux, y0 + 4.5, -0.55, 5, 9, 0.3, GLASS_DARK, "Glass")
	add(h, "Vordach", "trim", ux, y0 + 10.8, -2, 9, 0.5, 4, { 110, 112, 118 }, "Concrete")
	add(h, "PolizeiSchild", "trim", ux, y0 + 12.6, -0.4, 11, 2.6, 0.5, { 30, 80, 190 }, "SmoothPlastic")
	label(h, "front", ux, y0 + 12.6, 0.8, 10, 2, "POLIZEI", { 255, 255, 255 })
end

-- Klinikum: Betonfassade mit auskragenden Geschossplatten und Brüstungsbändern, Fensterbänder, Stützen im Sockel,
-- Glasturm an der Ecke, Schriftzug und senkrechtes Schild
local function styleKlinik(h, o, rng)
	local W, D, y0 = h.width, h.depth, o.floorY
	local floors = h.forceFloors or 5
	local UP = o.upperH * (floors - 1)
	local CONC, SLAB, PARA, MAG = { 150, 146, 140 }, { 176, 172, 164 }, { 124, 120, 114 }, { 200, 30, 100 }
	local GLASSB = { 96, 140, 160 }
	h.floors, h.height, h.facade, h.roof = floors, 14 + UP, CONC, "flat"
	add(h, "Ground", "body", 0, y0 + 7, D / 2, W - 12, 14, D - 12, { 58, 66, 76 }, "Concrete", { collide = true })
	add(h, "Body", "body", 0, y0 + 14 + UP / 2, D / 2, W, UP, D, CONC, "Concrete", { collide = true })
	add(h, "Roof", "roof", 0, y0 + 14 + UP + 0.3, D / 2, W, 0.6, D, { 96, 96, 100 }, "Concrete", { collide = true })
	add(h, "Staffel", "body", 0, y0 + 14 + UP + 6.6, D / 2, W - 40, 12, D - 50, { 170, 166, 158 }, "Concrete", { collide = true })
	for _, face in ipairs({ "front", "back" }) do
		for u = -W / 2 + 10, W / 2 - 9, 20 do
			local lx, lz, ey = onFace(h, face, u, 3 - 0.1)
			add(h, "Stuetze", "trim", lx, y0 + 7, lz, 3, 14, 3, CONC, "Concrete", { yaw = ey, collide = true })
		end
		for k = 1, floors - 1 do
			local yb = y0 + 14 + 12 * (k - 1)
			local lx, lz, ey = onFace(h, face, 0, 1.5)
			add(h, "Geschossplatte", "balcony", lx, yb + 0.5, lz, W, 1, 3, SLAB, "Concrete", { yaw = ey })
			lx, lz = onFace(h, face, 0, 2.75)
			add(h, "Bruestung", "balcony", lx, yb + 2.25, lz, W, 2.5, 0.5, PARA, "Concrete", { yaw = ey })
			ribbon(h, o, rng, face, yb + 6.4, 5, -W / 2 + 3, W / 2 - 3, 8, GLASS, DARKG, 0.2, o.litChance)
		end
	end
	-- Glasturm an der Nordecke (in z-Richtung der Fassade am Ende), springt 12 Studs vor
	local gx, gw = W / 2 - 17, 34
	local gh = 14 + UP
	add(h, "Glasturm", "glass", gx, y0 + gh / 2, -6, gw, gh, 12, GLASSB, "Glass", { collide = true })
	for i = 0, 6 do
		add(h, "Pfosten", "trim", gx - gw / 2 + i * gw / 6, y0 + gh / 2, -12.2, 0.6, gh, 0.6, DARKG, "Metal")
	end
	for k = 1, 4 do
		add(h, "Riegel", "trim", gx, y0 + k * gh / 4, -12.2, gw, 0.6, 0.6, DARKG, "Metal")
	end
	add(h, "GlasturmDach", "roof", gx, y0 + gh + 0.5, -6, gw + 0.6, 1, 12.6, CONC, "Concrete")
	add(h, "SchildTraeger", "trim", W / 2 - 38, y0 + 14 + 8, -3.4, 3.4, 17.6, 0.6, { 190, 188, 184 }, "SmoothPlastic")
	label(h, "front", W / 2 - 38, y0 + 14 + 8, 3.8, 3, 16, "K\nL\nI\nN\nI\nK\nU\nM", MAG)
	label(h, "front", -W / 2 + 30, y0 + 14 + 24 + 2.25, 3.15, 36, 2.2, "KLINIKUM", MAG)
end


-- Bürogebäude hinter der Tankstelle (nach Foto): dunkle Glasfassade mit weißen Geschossbändern, hohe Stahlpfeiler bis über das Dach,
-- weit auskragendes Dach mit aufgesetztem Oberlichtband. Fassade (vorn) zur Tankstelle, Rückseite ebenfalls verglast.
local function styleBuero(h, o, rng)
	local W, D, y0 = h.width, h.depth, o.floorY
	local floors = h.forceFloors or 5
	local H = 14 + 12 * (floors - 1)
	local DARK, BAND, STEEL = { 38, 48, 62 }, { 214, 218, 222 }, { 170, 176, 182 }
	h.floors, h.height, h.facade, h.roof = floors, H, DARK, "flat"
	add(h, "Body", "body", 0, y0 + H / 2, D / 2, W, H, D, DARK, "SmoothPlastic", { collide = true })
	for _, face in ipairs({ "front", "back" }) do
		for k = 0, floors - 1 do
			local yb = y0 + (k == 0 and 0 or 14 + 12 * (k - 1))
			local lx, lz, ey = onFace(h, face, 0, 1.3)
			add(h, "Geschossband", "trim", lx, yb + 0.5, lz, W + 1, 1, 2.6, BAND, "Concrete", { yaw = ey })
			ribbon(h, o, rng, face, yb + (k == 0 and 8 or 6.5), k == 0 and 11 or 8.6, -W / 2 + 2, W / 2 - 2, 7, GLASS, DARKG, 0.3, o.litChance)
		end
		for u = -W / 2 + 7, W / 2 - 6, 14 do -- Stahlpfeiler vor der Fassade, ragen über das Dach
			local lx, lz, ey = onFace(h, face, u, 3)
			add(h, "Stahlpfeiler", "trim", lx, y0 + H / 2 + 3, lz, 1.4, H + 6, 1.4, STEEL, "Metal", { yaw = ey, collide = true })
		end
	end
	add(h, "Dach", "roof", 0, y0 + H + 1.1, D / 2, W + 6, 1.4, D + 9, { 200, 204, 208 }, "Concrete", { collide = true })
	add(h, "Dach", "roof", 0, y0 + H + 3.4, D / 2, W - 14, 1.2, D + 3, { 214, 218, 222 }, "Concrete", { collide = true })
	add(h, "Oberlicht", "glass", 0, y0 + H + 5.6, D / 2, W - 22, 3.2, D - 6, { 96, 124, 146 }, "Glass", { collide = false })
end

local STYLES = { feuerwache = styleFeuerwache, polizei = stylePolizei, klinik = styleKlinik, buero = styleBuero }


-- Teil in Weltkoordinaten (für Anlagen, die nicht zum Haus-Koordinatensystem passen: Tankstelle, Polizeihof)
local function W3(h, name, kind, x, y, z, sx, sy, sz, color, mat, extra)
	extra = extra or {}
	h.parts[#h.parts + 1] = {
		name = name, kind = kind, size = { round3(sx), round3(sy), round3(sz) }, pos = { round3(x), round3(y), round3(z) }, yaw = extra.yaw or 0, pitch = 0,
		color = color, material = mat, collide = extra.collide == true, lpos = { 0, y, 0 }, tag = extra.tag, attrs = extra.attrs, lit = extra.lit,
		text = extra.text, shape = extra.shape, roll = extra.roll, transparency = extra.transparency,
	}
end

-- Tankstellen-Shop (nach Beschreibung): weiß mit rotem Band, schließt an die schmale Seite des Schirms an, hohl mit Glasfront zur Straße (West)
local function styleTankstelle(h, spec)
	local x0, z0, x1, z1 = spec.x0, spec.z0, spec.x1, spec.z1
	local cx, cz, w, d = (x0 + x1) / 2, (z0 + z1) / 2, x1 - x0, z1 - z0
	local WHITE, RED, GL = { 250, 250, 250 }, { 200, 40, 40 }, { 160, 176, 172 }
	h.floors, h.height, h.facade, h.roof = 1, 14, WHITE, "flat"
	W3(h, "Body", "body", cx, 14.5, cz, w, 1, d, WHITE, "SmoothPlastic", { collide = true }) -- Dach, bündig mit dem Schirm
	W3(h, "ShopHinterwand", "body", x1 - 0.6, 7.5, cz, 1.2, 13, d, WHITE, "SmoothPlastic", { collide = true })
	for _, zz in ipairs({ z0 + 0.6, z1 - 0.6 }) do W3(h, "ShopSeitenwand", "body", cx, 7.5, zz, w, 13, 1.2, WHITE, "SmoothPlastic", { collide = true }) end
	W3(h, "ShopSockel", "body", x0 + 0.6, 2.1, cz, 1.2, 2.2, d - 2.4, WHITE, "SmoothPlastic", { collide = true })
	W3(h, "ShopSturz", "body", x0 + 0.6, 12.9, cz, 1.2, 2.2, d - 2.4, WHITE, "SmoothPlastic", { collide = true })
	W3(h, "ShopBand", "trim", x0 - 0.1, 14.2, cz, 0.4, 2.8, d, RED, "SmoothPlastic")
	for _, zz in ipairs({ z0 - 0.1, z1 + 0.1 }) do W3(h, "ShopBand", "trim", cx, 14.2, zz, w, 2.8, 0.4, RED, "SmoothPlastic") end
	W3(h, "ShopBandHinten", "trim", x1 + 0.1, 14.2, cz, 0.4, 2.8, d, RED, "SmoothPlastic")
	W3(h, "Schrift", "text", x0 - 0.35, 14.2, cz, 18, 2, 0.2, { 255, 255, 255 }, "SmoothPlastic", { yaw = 90, text = { s = "ALLGUTH", color = { 255, 255, 255 } } })
	-- Glasfassade zur Straße: Scheiben links und rechts der Schiebetür (8 breit), Pfosten, rote Türrahmen
	local door = 8
	local function panes(za, zb)
		local n = math.max(1, math.floor((zb - za) / 4))
		local pw = (zb - za) / n
		for i = 1, n do
			W3(h, "ShopGlas", "glass", x0 + 0.6, 7.1, za + (i - 0.5) * pw, 0.3, 8.8, pw - 0.4, GL, "Glass", { collide = true, tag = "HouseWindow", lit = false })
			W3(h, "ShopPfosten", "trim", x0 + 0.6, 7.1, za + i * pw, 0.6, 9, 0.5, { 70, 74, 80 }, "Metal")
		end
	end
	panes(z0 + 1.2, cz - door / 2)
	panes(cz + door / 2, z1 - 1.2)
	W3(h, "ShopTuer", "glass", x0 + 0.6, 6.2, cz, 0.3, 10.4, door, GL, "Glass", { tag = "ShopDoor" }) -- ohne Kollision, man läuft hinein
	for _, zz in ipairs({ cz - door / 2, cz + door / 2 }) do W3(h, "ShopTuerrahmen", "trim", x0 + 0.6, 6.2, zz, 0.7, 10.6, 0.5, RED, "SmoothPlastic") end
	W3(h, "ShopTuerrahmen", "trim", x0 + 0.6, 11.6, cz, 0.7, 0.5, door, RED, "SmoothPlastic")
	-- Einrichtung: Kasse am Eingang, Regale an der Rückwand
	W3(h, "Kasse", "trim", x0 + 5, 3, cz - 11, 3, 4, 9, { 190, 190, 194 }, "SmoothPlastic", { collide = true })
	for _, zz in ipairs({ z0 + 7, cz + 4, z1 - 7 }) do W3(h, "Regal", "trim", x1 - 3, 4.5, zz, 2.2, 7, 8, { 220, 220, 224 }, "SmoothPlastic", { collide = true }) end
	W3(h, "Kuehlregal", "trim", cx, 4, z1 - 3.5, 12, 6, 2.4, { 150, 190, 215 }, "SmoothPlastic", { collide = true })
end

-- Polizeihof hinter der Durchfahrt: Hof mit Parkbuchten, vier Fahrzeug-Spawnflächen, Zaun zum Hofgarten, Ausfahrt an der Ostseite mit Schranke,
-- Einfahrt durch die Durchfahrt mit Schranke. Alles in Weltkoordinaten; Schranken tragen den Tag "Schranke" (Attribut Offen).
local function compoundPolizei(h, spec, o)
	local ASPH, WHITE, RED = { 70, 72, 78 }, { 240, 240, 236 }, { 200, 40, 40 }
	local function slab(name, x0, z0, x1, z1) W3(h, name, "trim", (x0 + x1) / 2, 0.4, (z0 + z1) / 2, x1 - x0, 1.2, z1 - z0, ASPH, "Asphalt", { collide = true }) end
	local ax0 = spec.x0 + 22 -- Durchfahrt (14 breit), siehe stylePolizei
	slab("Hof", spec.x0 + 16, 296, spec.x1 + 2, spec.z0)
	slab("Durchfahrt", ax0, spec.z0, ax0 + 14, spec.z1 + 2)
	slab("Ausfahrt", spec.x1 + 2, 296, spec.x1 + 20, spec.z1 + 2)
	for i = 0, 14 do -- Parkbuchten an der Nordkante
		W3(h, "Parklinie", "dash", spec.x0 + 24 + 8 * i, 1.05, 306, 0.3, 0.1, 16, WHITE, "SmoothPlastic")
	end
	for i = 1, 4 do -- Spawnflächen für Streifenwagen
		W3(h, "FahrzeugSpawn", "spawn", spec.x0 + 20 + 24 * i, 1.12, 330, 12, 0.2, 20, { 36, 60, 120 }, "SmoothPlastic", { tag = "VehicleSpawn", attrs = { Team = "Polizei" } })
	end
	-- Zaun an der Nordkante (lockere Einfriedung, Gitterstäbe alle 4 Studs)
	local fx0, fx1 = spec.x0 + 16, spec.x1 + 2
	W3(h, "ZaunRiegel", "trim", (fx0 + fx1) / 2, 4.6, 296.2, fx1 - fx0, 0.4, 0.4, { 50, 54, 58 }, "Metal")
	W3(h, "ZaunRiegel", "trim", (fx0 + fx1) / 2, 1.6, 296.2, fx1 - fx0, 0.4, 0.4, { 50, 54, 58 }, "Metal")
	for x = fx0, fx1, 4 do W3(h, "ZaunStab", "trim", x, 3, 296.2, 0.3, 3.4, 0.3, { 50, 54, 58 }, "Metal") end
	-- Schranken: Pfosten (rot-weiß) und Arm quer über die Fahrspur, geschlossen
	local function barrier(name, px, pz, len)
		W3(h, name .. "Pfosten", "trim", px, 3, pz, 1.4, 4, 1.4, RED, "SmoothPlastic", { collide = true })
		local n = 4
		for i = 1, n do
			W3(h, name .. "Arm", "trim", px + 0.7 + (i - 0.5) * len / n, 4.2, pz, len / n, 0.5, 0.5, (i % 2 == 1) and RED or WHITE, "SmoothPlastic",
				{ collide = true, tag = "Schranke", attrs = { Offen = false, Gruppe = name } })
		end
	end
	barrier("SchrankeEinfahrt", ax0 + 0.2, spec.z1 - 2, 13)
	barrier("SchrankeAusfahrt", spec.x1 + 3, 346, 16)
end

local COMPOUNDS = { polizei = compoundPolizei }

-- Allguth-Schirm nach Fotos: flaches weißes Dach, vorn (Nordseite) abgerundete Ecken, rotes Band mit weißem Schriftzug ALLGUTH,
-- kräftige weiße Stützen in zwei Reihen, Deckenleuchten, zwei Zapfsäulen-Inseln mit weiß-roten Säulen. Hinten (Süd) schließt der Shop an.
local function canopyAllguth(h, c)
	local x0, z0, x1, z1 = c[1], c[2], c[3], c[4]
	local cx, cz, w, d = (x0 + x1) / 2, (z0 + z1) / 2, x1 - x0, z1 - z0
	local WHITE, RED, TRIM = { 250, 250, 250 }, { 200, 32, 40 }, { 236, 236, 238 }
	local r = 8
	W3(h, "CanopyRoof", "trim", cx, 14.5, (z0 + r + z1) / 2, w, 1, d - r, WHITE, "SmoothPlastic")
	W3(h, "CanopyRoof", "trim", cx, 14.5, z0 + r / 2, w - 2 * r, 1, r, WHITE, "SmoothPlastic")
	for _, px in ipairs({ x0 + r, x1 - r }) do -- Rundung: Zylinder mit 0,04 Überstand gegen Flackern
		W3(h, "CanopyRoofRund", "trim", px, 14.5, z0 + r, 1.08, 2 * r, 2 * r, WHITE, "SmoothPlastic", { shape = "Cylinder", roll = 90 })
	end
	local zs, ze = z0 + r, z1 -- gerade Bänder an den Längsseiten
	W3(h, "CanopyBand", "trim", x0 + 0.4, 14.2, (zs + ze) / 2, 0.8, 2.8, ze - zs, RED, "SmoothPlastic")
	W3(h, "CanopyBand", "trim", x1 - 0.4, 14.2, (zs + ze) / 2, 0.8, 2.8, ze - zs, RED, "SmoothPlastic")
	W3(h, "CanopyBand", "trim", cx, 14.2, z0 + 0.4, w - 2 * r, 2.8, 0.8, RED, "SmoothPlastic")
	for _, e in ipairs({ { x0 + 0.5, (zs + ze) / 2, 0.9, ze - zs }, { x1 - 0.5, (zs + ze) / 2, 0.9, ze - zs } }) do
		W3(h, "CanopyTrim", "trim", e[1], 15.85, e[2], e[3], 0.5, e[4], TRIM, "SmoothPlastic")
	end
	for ci, cc in ipairs({ { x0 + r, z0 + r, 180 }, { x1 - r, z0 + r, 270 } }) do -- Bogenstücke der Bänder
		local n, rad = 6, r - 0.4
		for k = 1, n do
			local a = math.rad(cc[3] + (k - 0.5) * 90 / n)
			local tx, tz = -math.sin(a), math.cos(a)
			W3(h, "CanopyBand", "trim", cc[1] + rad * math.cos(a), 14.2, cc[2] + rad * math.sin(a), rad * (math.pi / 2) / n + 0.3, 2.8, 0.8, RED, "SmoothPlastic", { yaw = math.deg(math.atan2(-tz, tx)) % 360 })
		end
	end
	-- Schriftzug auf dem Band: Westseite (zur Straße), Ostseite und Nordstirnseite
	local function brand(x, z, yaw) W3(h, "Schrift", "text", x, 14.2, z, 22, 2, 0.2, { 255, 255, 255 }, "SmoothPlastic", { yaw = yaw, text = { s = "ALLGUTH", color = { 255, 255, 255 } } }) end
	brand(x0 - 0.1, (zs + ze) / 2 - 8, 90)
	brand(x1 + 0.1, (zs + ze) / 2 - 8, 270)
	brand(cx, z0 - 0.1, 0)
	-- Stützen: zwei Reihen à vier, kräftig weiß
	for _, px in ipairs({ x0 + 10, x1 - 10 }) do
		for k = 0, 3 do W3(h, "CanopyPillar", "trim", px, 7.5, z0 + 14 + k * (d - 28) / 3, 2.6, 14, 2.6, WHITE, "Concrete", { collide = true }) end
	end
	-- Deckenleuchten (Neon) in drei Reihen
	for _, lx in ipairs({ cx - 18, cx, cx + 18 }) do
		for k = 0, 4 do W3(h, "Deckenlicht", "trim", lx, 13.9, z0 + 10 + k * (d - 20) / 4, 0.2, 1.6, 1.6, { 255, 250, 230 }, "Neon", { shape = "Cylinder", roll = 90 }) end
	end
	-- Zapfsäulen-Inseln: Betonsockel, je vier weiß-rote Säulen mit Display
	for _, px in ipairs({ cx - 13, cx + 13 }) do
		W3(h, "Insel", "trim", px, 1.3, cz, 5, 0.6, d - 14, { 190, 188, 182 }, "Concrete", { collide = true })
		for kk = 0, 3 do
			local pz = z0 + 10 + kk * (d - 20) / 3
			W3(h, "Pump", "trim", px, 4.4, pz, 2.2, 5.6, 1.6, { 244, 244, 246 }, "SmoothPlastic", { collide = true })
			W3(h, "PumpKopf", "trim", px, 6.8, pz, 2.3, 1.4, 1.7, RED, "SmoothPlastic")
			for _, sd in ipairs({ -1, 1 }) do W3(h, "PumpDisplay", "trim", px, 5.4, pz + sd * 0.85, 1.6, 0.9, 0.2, { 20, 24, 28 }, "SmoothPlastic") end
		end
	end
end

-- Grundstücksausstattung nach Fotos: Rasenstreifen zwischen Gehweg und Tankstelle (nicht an den Einfahrten), Hecke, Büsche,
-- quadratische Logoschilder, Ein-/Ausfahrt-Schilder und das Preis-Totem (Tag "FuelPrice" je Preiszeile für ein späteres Skript).
local function lotDecor(h, spec)
	local l, K = spec.lot, 1.4
	local LAWN, HEDGE, WHITE, RED = { 88, 158, 62 }, { 40, 88, 48 }, { 244, 244, 246 }, { 200, 32, 40 }
	local sections, z = {}, l[2] + K
	for _, g in ipairs(spec.curbGaps) do
		if g[1] > z then sections[#sections + 1] = { z, g[1] } end
		z = g[2]
	end
	if z < l[4] - K then sections[#sections + 1] = { z, l[4] - K } end
	local lx0, lx1 = l[1] + K + 0.4, l[1] + 13
	for _, sct in ipairs(sections) do
		W3(h, "Rasen", "decor", (lx0 + lx1) / 2, 1.0, (sct[1] + sct[2]) / 2, lx1 - lx0, 0.6, sct[2] - sct[1] - 1, LAWN, "Grass")
		local zz = sct[1] + 4
		while zz + 9 < sct[2] - 3 do
			W3(h, "Hecke", "decor", lx1 - 1.4, 2.5, zz + 4.5, 1.8, 2.4, 9, HEDGE, "Grass", { collide = true })
			zz = zz + 10
		end
		for bz = sct[1] + 8, sct[2] - 6, 15 do W3(h, "Busch", "bush", lx0 + 2.4, 3.3, bz, 4.4, 4.4, 4.4, HEDGE, "Grass", { shape = "Ball" }) end
	end
	-- quadratische Logoschilder (weiß mit rotem A), beidseitig lesbar
	local function logoSign(x, zc)
		W3(h, "SchildPfosten", "decor", x, 3.3, zc, 0.4, 4, 0.4, { 80, 82, 86 }, "Metal", { collide = true })
		W3(h, "LogoSchild", "decor", x, 6.5, zc, 4.6, 4.6, 0.3, WHITE, "SmoothPlastic")
		for _, sd in ipairs({ { -1, 0 }, { 1, 180 } }) do
			W3(h, "LogoRot", "decor", x, 6.5, zc + sd[1] * 0.2, 3.2, 3.2, 0.2, RED, "SmoothPlastic")
			W3(h, "Schrift", "text", x, 6.5, zc + sd[1] * 0.4, 3.2, 3.2, 0.2, { 255, 255, 255 }, "SmoothPlastic", { yaw = sd[2], text = { s = "A", color = { 255, 255, 255 } } })
		end
	end
	if sections[1] then logoSign(lx0 + 3, (sections[1][1] + sections[1][2]) / 2 + 12) end
	if sections[2] then logoSign(lx0 + 3, (sections[2][1] + sections[2][2]) / 2) end
	-- Ein- und Ausfahrt-Schilder an den Rasenenden
	local function gateSign(zc, label)
		W3(h, "SchildPfosten", "decor", l[1] + 4.5, 2.8, zc, 0.4, 3, 0.4, { 80, 82, 86 }, "Metal", { collide = true })
		W3(h, "FahrtSchild", "decor", l[1] + 4.5, 5.8, zc, 7, 2.6, 0.3, { 36, 70, 110 }, "SmoothPlastic")
		for _, sd in ipairs({ { -1, 0 }, { 1, 180 } }) do
			W3(h, "Schrift", "text", l[1] + 4.5, 5.8, zc + sd[1] * 0.25, 6.4, 2, 0.2, { 255, 255, 255 }, "SmoothPlastic", { yaw = sd[2], text = { s = label, color = { 255, 255, 255 } } })
		end
	end
	if spec.curbGaps[1] and sections[1] then gateSign(sections[1][1] + 1, "EINFAHRT") end
	if spec.curbGaps[2] and sections[1] then gateSign(sections[1][2] - 1, "AUSFAHRT") end
	-- Preis-Totem: Stahlpylon mit rotem Kopf (weißes A, ALLGUTH) und schwarzer Preistafel, an beiden Flachseiten
	local tx, tz = l[1] + 6, sections[1] and (sections[1][1] + sections[1][2]) / 2 - 2 or l[2] + 20
	W3(h, "TotemPylon", "decor", tx, 17.3, tz, 6.2, 32, 1.8, { 70, 74, 80 }, "Metal", { collide = true })
	local fuels = { { "SUPER", "1,81", "Super" }, { "SUPER E10", "1,75", "E10" }, { "SUPER PLUS", "1,95", "SuperPlus" }, { "DIESEL", "1,69", "Diesel" }, { "AUTOGAS", "0,89", "Autogas" } }
	for _, sd in ipairs({ { -1, 0 }, { 1, 180 } }) do
		local zf = tz + sd[1] * 1.0
		W3(h, "TotemKopf", "decor", tx, 28.8, zf, 5.6, 8.6, 0.3, RED, "SmoothPlastic")
		W3(h, "Schrift", "text", tx, 30.2, zf + sd[1] * 0.25, 4, 5, 0.2, { 255, 255, 255 }, "SmoothPlastic", { yaw = sd[2], text = { s = "A", color = { 255, 255, 255 } } })
		W3(h, "Schrift", "text", tx, 26.2, zf + sd[1] * 0.25, 5.2, 1.3, 0.2, { 255, 255, 255 }, "SmoothPlastic", { yaw = sd[2], text = { s = "ALLGUTH", color = { 255, 255, 255 } } })
		W3(h, "TotemTafel", "decor", tx, 14.5, zf, 5.6, 17, 0.3, { 18, 20, 24 }, "SmoothPlastic")
		for i, f in ipairs(fuels) do
			local yy = 22.4 - (i - 0.5) * 3.35
			local off = sd[1] * 0.25
			W3(h, "Schrift", "text", tx - sd[1] * 1.15, yy, zf + off, 3.1, 1.9, 0.2, { 255, 255, 255 }, "SmoothPlastic", { yaw = sd[2], text = { s = f[1], color = { 255, 255, 255 } } })
			W3(h, "Preis", "text", tx + sd[1] * 1.55, yy, zf + off, 1.9, 1.9, 0.2, { 90, 235, 120 }, "SmoothPlastic",
				{ yaw = sd[2], text = { s = f[2], color = { 90, 235, 120 } }, tag = "FuelPrice", attrs = { Fuel = f[3], Price = tonumber((string.gsub(f[2], ",", "."))) } })
		end
	end
end

-- Sonderbau (Bank, Wache, Krankenhaus ...) als Platzhalter-Gebäude auf einer Rechteckfläche.
-- spec = { name, x0, z0, x1, z1, facing = "N"|"S"|"E"|"W" (Seite zur Straße), floors, color, canopy = { x0, z0, x1, z1 } }
function Planner.planSpecial(spec, opts)
	local o = mergeOpts(opts)
	local rng = newRng(o.seed + hash(spec.name))
	local f = spec.facing
	local h = {
		side = f, index = 0, simple = false, rear = true, forceFloors = spec.floors, color = spec.color, parts = {}, name = "Sonder_" .. spec.name,
	}
	if f == "N" then h.ox, h.oz, h.yaw, h.width, h.depth = (spec.x0 + spec.x1) / 2, spec.z0, 0, spec.x1 - spec.x0, spec.z1 - spec.z0
	elseif f == "S" then h.ox, h.oz, h.yaw, h.width, h.depth = (spec.x0 + spec.x1) / 2, spec.z1, 180, spec.x1 - spec.x0, spec.z1 - spec.z0
	elseif f == "W" then h.ox, h.oz, h.yaw, h.width, h.depth = spec.x0, (spec.z0 + spec.z1) / 2, 90, spec.z1 - spec.z0, spec.x1 - spec.x0
	else h.ox, h.oz, h.yaw, h.width, h.depth = spec.x1, (spec.z0 + spec.z1) / 2, 270, spec.z1 - spec.z0, spec.x1 - spec.x0 end
	if spec.style == "tankstelle" then styleTankstelle(h, spec)
	elseif STYLES[spec.style] then STYLES[spec.style](h, o, rng)
	else planHouse(h, o, rng, false, false) end
	if spec.canopy then canopyAllguth(h, spec.canopy) end
	if spec.lot then -- Tankstellen-Grundstück: Plateau (Asphalt, Oberkante 1) mit Betonkante; zur Straße offen, nur zwischen den Ein-/Ausfahrten (curbGaps) steht eine niedrige Kante
		local l = spec.lot
		local KERB, K = { 190, 188, 182 }, 1.4
		W3(h, "Plateau", "trim", (l[1] + l[3]) / 2, 0.4, (l[2] + l[4]) / 2, l[3] - l[1], 1.2, l[4] - l[2], { 78, 80, 86 }, "Asphalt", { collide = true })
		local function kerb(x0, z0, x1, z1) W3(h, "Kante", "trim", (x0 + x1) / 2, 1.25, (z0 + z1) / 2, x1 - x0, 0.5, z1 - z0, KERB, "Concrete", { collide = true }) end
		kerb(l[1], l[2], l[3], l[2] + K)
		kerb(l[1], l[4] - K, l[3], l[4])
		kerb(l[3] - K, l[2] + K, l[3], l[4] - K)
		local z = l[2] + K
		for _, g in ipairs(spec.curbGaps) do -- Straßenseite: Kante zwischen den Einfahrten
			if g[1] > z then kerb(l[1], z, l[1] + K, g[1]) end
			z = g[2]
		end
		if z < l[4] - K then kerb(l[1], z, l[1] + K, l[4] - K) end
		lotDecor(h, spec)
	end
	if spec.compound then COMPOUNDS[spec.compound](h, spec, o) end
	return { houses = { h } }
end

-- Mapgrenze: Häuserband rund um die Karte, Fassade zeigt nach innen zur Ringstraße.
-- wall = { inner = {xmin,zmin,xmax,zmax} (Ringaußenkante), outer = {...} (Kartenrand), gates = { N = {{x0,x1},...}, S = ... },
--          specials = { { side, name, x0, x1, floors } } }
function Planner.planWall(wall, opts)
	local o = mergeOpts(opts)
	o.simple, o.setback, o.rear = true, 0, false
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
	local n = #plan.houses
	for _, list in ipairs({ plan.houses, plan.inner or {} }) do
		for _, h in ipairs(list) do
			parts = parts + #h.parts
			area = area + h.width * h.depth
		end
	end
	return { houses = n + #(plan.inner or {}), parts = parts, footprint = area }
end

return Planner
