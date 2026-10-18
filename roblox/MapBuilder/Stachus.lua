-- Stachus.lua
-- Der Platz am Odeonsplatz wird zum Stachus (Karlsplatz): eckiger Hof aus Geschäftshäusern (Nord-, West- und Südzeile), offen zur Leopoldstraße,
-- in der Westmitte das Karlstor (Mittelbau mit Spitzbogen zwischen zwei Zinnentürmen), in der Mitte der große Springbrunnen mit Strahlen und Pollern,
-- Granitpflaster, Kugelleuchten, Platanen und ein Taxistand (Beschriftung "TAXI" auf den Parkbuchten der Leopoldstraße). Erdgeschoss mit Läden (auch ein
-- Burger-Lokal), Dachschrift "OSRUM" (Anspielung, kein echter Name), zwei U-Bahn-Abgänge (nach Foto: Betonrahmen, Treppe zwischen zwei Rolltreppen),
-- Nord- und Südzeile schließen Wand an Wand an das Neue Rathaus bzw. die Häuserzeile am Marienplatz an, Endtürme mit flachem Walmdach. Reine Geometrie; Teilefelder wie in den anderen Planern.

local Geo = require(script and script.Parent.Geo or "Geo")

local Stachus = {}

local SAND, SAND2, SLATE, STONE, DARK = { 236, 222, 190 }, { 222, 204, 166 }, { 66, 72, 84 }, { 206, 200, 186 }, { 70, 66, 62 }
local GLASS, GLASS_LIT = { 74, 98, 118 }, { 255, 224, 150 }
local SHOPS = { "LEDERWAREN", "APOTHEKE", "BÄCKEREI", "UHREN SCHMID", "SPORTHAUS", "CAFÉ ROSA", "MODE & CO", "BUCHHANDLUNG", "OPTIK", "SCHMUCK", "EISDIELE", "SCHUHE", "BLUMEN", "BANK" }
local SIGNS = { { 40, 40, 44 }, { 30, 90, 56 }, { 120, 70, 40 }, { 30, 50, 96 }, { 110, 30, 40 }, { 60, 60, 66 } }
local AWN = { { 190, 60, 50 }, { 60, 100, 150 }, { 70, 130, 90 }, { 220, 170, 60 } }

local function newRng(seed)
	local s = seed
	return function()
		s = (s * 1103515245 + 12345) % 2147483648
		return s / 2147483648
	end
end

function Stachus.plan(cfg)
	local S = cfg.stachus
	local parts = {}
	local stats = { segs = 0, shops = 0, jets = 0, merlons = 0, taxis = 0, lamps = 0, trees = 0, towers = 0, pits = #cfg.stachus.ubahn }
	local rng = newRng(11)
	local function add(name, kind, x, y, z, sx, sy, sz, color, mat, e)
		e = e or {}
		parts[#parts + 1] = {
			name = name, kind = kind, size = { Geo.round3(sx), Geo.round3(sy), Geo.round3(sz) }, pos = { Geo.round3(x), Geo.round3(y), Geo.round3(z) },
			yaw = e.yaw or 0, pitch = e.pitch or 0, roll = e.roll, color = color, material = mat, collide = e.collide == true, shape = e.shape,
			text = e.text, tag = e.tag, lit = e.lit, attrs = e.attrs, transparency = e.transparency, emitter = e.emitter, wedge = e.wedge,
		}
	end
	local function vcyl(name, kind, x, y, z, h, d, color, mat, e)
		e = e or {}
		e.shape, e.roll = "Cylinder", 90
		add(name, kind, x, y, z, h, d, d, color, mat, e)
	end
	-- lokales Hausmaß: lx entlang der Fassade, lz in das Gebäude (Front lz < 0), Drehung wie in Planner.add; liefert put und die Umrechnung W(lx, y, lz) -> x, y, z
	local function frame(cx, cz, psi)
		local r = math.rad(psi)
		local c, s = math.cos(r), math.sin(r)
		local function W(lx, y, lz) return cx + lx * c + lz * s, y, cz - lx * s + lz * c end
		return function(name, kind, lx, y, lz, sx, sy, sz, color, mat, e)
			e = e or {}
			local ee = {}
			for k, v in pairs(e) do ee[k] = v end
			ee.yaw = (psi + (e.yaw or 0)) % 360
			add(name, kind, cx + lx * c + lz * s, y, cz - lx * s + lz * c, sx, sy, sz, color, mat, ee)
		end, W
	end
	-- Dreieck aus Keilen im lokalen Maß: a, b, c = { lx, y, lz }; hint = Richtung der Außenseite (lokal), die Fläche liegt auf der Ebene, die Dicke geht nach innen
	local function wtri(W, name, kind, a, b, c, thick, color, mat, hint, e)
		local function pt(v) local x, y, z = W(v[1], v[2], v[3]) return { x, y, z } end
		local h
		if hint then
			local hx, hy, hz = W(hint[1], hint[2], hint[3])
			local ox, oy, oz = W(0, 0, 0)
			h = { hx - ox, hy - oy, hz - oz }
		end
		for _, w in ipairs(Geo.wedges(pt(a), pt(b), pt(c), thick, h)) do
			local ee = {}
			for k, v in pairs(e or {}) do ee[k] = v end
			ee.wedge = w.wedge
			add(name, kind, w.pos[1], w.pos[2], w.pos[3], w.size[1], w.size[2], w.size[3], color, mat, ee)
		end
	end
	-- Teil auf einer Gebäudefläche: face F (Front, lz < 0), B (Rückseite), L/R (Schmalseiten); half = halbe Ausdehnung senkrecht zur Fläche, u = Lage entlang der Fläche,
	-- n = Abstand von der Wand nach außen (Mitte des Teils), su = Länge entlang der Fläche, sn = Dicke
	local function facebox(put, face, half, name, kind, u, y, n, su, sy, sn, color, mat, e)
		if face == "F" then put(name, kind, u, y, -(half + n), su, sy, sn, color, mat, e)
		elseif face == "B" then put(name, kind, u, y, half + n, su, sy, sn, color, mat, e)
		elseif face == "L" then put(name, kind, -(half + n), y, u, sn, sy, su, color, mat, e)
		else put(name, kind, half + n, y, u, sn, sy, su, color, mat, e) end
	end
	local TRIM = { 226, 212, 184 }
	-- Fenster mit Gewände: Rahmenplatte, Glas, Sprosse, Fensterbank und Sturz
	local function bay(put, face, half, u, yc, ww, wh, lit)
		facebox(put, face, half, "FensterRahmen", "trim", u, yc, 0.3, ww + 1.4, wh + 1.4, 0.6, TRIM, "Concrete")
		facebox(put, face, half, "Fenster", "glass", u, yc, 0.62, ww, wh, 0.2, lit and GLASS_LIT or GLASS, "Glass", { tag = "HouseWindow", lit = false })
		facebox(put, face, half, "Fenstersprosse", "trim", u, yc, 0.8, 0.25, wh, 0.25, TRIM, "Concrete")
		facebox(put, face, half, "Fensterbank", "trim", u, yc - wh / 2 - 0.7, 0.7, ww + 2.2, 0.5, 1.4, TRIM, "Concrete")
		facebox(put, face, half, "Sturz", "trim", u, yc + wh / 2 + 0.9, 0.5, ww + 2, 0.7, 1.0, TRIM, "Concrete")
	end
	local cx, cz, ac, bc, D = S.cx, S.cz, S.ac, S.bc, S.depth
	local H, Y0 = 14 + 12 * (S.floors - 1), 1
	local TOP = Y0 + H

	-- Pflaster (Oberkante 1) in Stücken um die U-Bahn-Gruben, Fugen alle 8 Studs (an den Gruben unterbrochen), Ringbänder um den Brunnen
	local pits = S.ubahn
	local px0, px1 = pits[1].x0, pits[1].x1 -- beide Gruben liegen in demselben x-Streifen
	local function slab(x0, z0, x1, z1)
		if x1 - x0 > 0.01 and z1 - z0 > 0.01 then add("Pflaster", "plaza", (x0 + x1) / 2, 0, (z0 + z1) / 2, x1 - x0, 2, z1 - z0, { 204, 198, 188 }, "Granite", { collide = true }) end
	end
	slab(S.x0, S.z0, px0, S.z1)
	slab(px1, S.z0, S.x1, S.z1)
	local zs = { S.z0 }
	for _, pt in ipairs(pits) do zs[#zs + 1] = pt.z0 zs[#zs + 1] = pt.z1 end
	zs[#zs + 1] = S.z1
	table.sort(zs)
	for i = 1, #zs - 1, 2 do slab(px0, zs[i], px1, zs[i + 1]) end
	local function inPit(x, z)
		for _, pt in ipairs(pits) do if x > pt.x0 - 0.1 and x < pt.x1 + 0.1 and z > pt.z0 - 0.1 and z < pt.z1 + 0.1 then return true end end
		return false
	end
	for x = S.x0 + 8, S.x1 - 4, 8 do
		if x > px0 and x < px1 then -- Fuge längs z, an den Gruben unterbrochen
			for i = 1, #zs - 1, 2 do add("Fuge", "plaza", x, 1.1, (zs[i] + zs[i + 1]) / 2, 0.3, 0.2, zs[i + 1] - zs[i], { 172, 166, 156 }, "SmoothPlastic") end
		else
			add("Fuge", "plaza", x, 1.1, (S.z0 + S.z1) / 2, 0.3, 0.2, S.z1 - S.z0, { 172, 166, 156 }, "SmoothPlastic")
		end
	end
	for z = S.z0 + 8, S.z1 - 4, 8 do
		if inPit(px0 + 1, z) then
			add("Fuge", "plaza", (S.x0 + px0) / 2, 1.1, z, px0 - S.x0, 0.2, 0.3, { 172, 166, 156 }, "SmoothPlastic")
			add("Fuge", "plaza", (px1 + S.x1) / 2, 1.1, z, S.x1 - px1, 0.2, 0.3, { 172, 166, 156 }, "SmoothPlastic")
		else
			add("Fuge", "plaza", (S.x0 + S.x1) / 2, 1.1, z, S.x1 - S.x0, 0.2, 0.3, { 172, 166, 156 }, "SmoothPlastic")
		end
	end
	-- Der ganze Brunnen (Becken, Düsen, Mittelstrahl, Poller, Sitzsteine, Pflasterringe) ist um K verkleinert: Maße und Radien um die Mitte, Höhen über dem Pflaster (Oberkante 1)
	local K = S.fountainScale or 0.9
	local function ky(y) return 1 + (y - 1) * K end
	for i, rr in ipairs({ 52, 49, 46 }) do vcyl("Pflasterring", "plaza", cx, 1.0 + i * 0.15, cz, 0.3, 2 * rr * K, i == 2 and { 150, 96, 84 } or { 186, 180, 170 }, "Granite") end

	-- Brunnen: Beckenrand aus Granitblöcken, Wasser, Strahlenkränze, Mittelstrahl, Poller
	local R = S.basin * K
	for i = 0, 35 do
		local a = math.rad(i * 10)
		add("Beckenrand", "plaza", cx + R * math.cos(a), ky(2.1), cz + R * math.sin(a), 8 * K, 2.2 * K, 2.6 * K, STONE, "Granite", { yaw = math.deg(math.atan2(-math.cos(a), -math.sin(a))) % 360, collide = true })
	end
	vcyl("Beckenboden", "plaza", cx, 1.2, cz, 0.3, 2 * R, { 120, 140, 156 }, "Concrete")
	vcyl("Wasser", "plaza", cx, ky(2.3), cz, 0.4, 2 * R - 2 * K, { 130, 180, 214 }, "SmoothPlastic", { transparency = 0.45 })
	for _, ring in ipairs({ { 20, 24, 10, 6, 30, 26 }, { 32, 30, 8, 5, 35, 22 } }) do -- Radius, Düsen, Reichweite, Höhe, Neigung nach außen (Grad), Strahlgeschwindigkeit
		for k = 0, ring[2] - 1 do
			local a = math.rad(k * 360 / ring[2] + (ring[1] > 25 and 6 or 0))
			-- Sprenkler: unsichtbare Düse, nach außen geneigt, sprüht einen Partikelstrahl im Bogen (Reichweite ca. ring[3], Höhe ca. ring[4] / 1,5); Geschwindigkeit mit sqrt(K), damit die Reichweite mit K schrumpft
			add("Duese", "plaza", cx + ring[1] * K * math.cos(a), ky(2.6), cz + ring[1] * K * math.sin(a), 0.5, 0.5, 0.5, { 240, 248, 255 }, "SmoothPlastic",
				{ yaw = (90 - math.deg(a)) % 360, pitch = ring[5], emitter = { rate = 16, speed = ring[6] * math.sqrt(K), spread = 3, gravity = 60, life = 1.1, size = 0.5, color = { 225, 240, 255 } } })
			stats.jets = stats.jets + 1
		end
	end
	vcyl("Mittelstrahl", "plaza", cx, ky(9), cz, 14 * K, 1.4 * K, { 240, 248, 255 }, "SmoothPlastic", { transparency = 0.3 })
	vcyl("Mittelsockel", "plaza", cx, ky(2.2), cz, 1.6 * K, 8 * K, STONE, "Granite", { collide = true })
	for i = 0, 35 do -- Poller (niedrige Steinstümpfe) rund um das Becken
		local a = math.rad(i * 10 + 5)
		vcyl("Poller", "plaza", cx + (R + 7 * K) * math.cos(a), ky(2.3), cz + (R + 7 * K) * math.sin(a), 2.6 * K, 2.4 * K, { 150, 146, 140 }, "Granite", { collide = true })
	end
	for i = 0, 9 do -- Sitzsteine auf der Ostseite
		local a = math.rad(-72 + i * 16)
		add("Sitzstein", "plaza", cx + (R + 11 * K) * math.cos(a), ky(2.3), cz + (R + 11 * K) * math.sin(a), 3.4 * K, 2.6 * K, 2.6 * K, { 160, 156, 148 }, "Granite", { yaw = i * 23, collide = true })
	end

	-- Gebäudezeilen: Nordzeile (Front nach Süden), Südzeile (Front nach Norden), Westzeile mit Karlstor (Front nach Osten); alle Wand an Wand
	local shopNo, roofSigns = 0, {}
	local function segment(x, z, psi, len, idx, opts)
		opts = opts or {}
		local put = frame(x, z, psi)
		local W = len + 1.4
		stats.segs = stats.segs + 1
		put("Gebaeude", "body", 0, Y0 + H / 2, 0, W, H, D, SAND, "SmoothPlastic", { collide = true })
		for _, face in ipairs({ "F", "B" }) do
			facebox(put, face, D / 2, "Sockel", "trim", 0, Y0 + 1.2, 0.25, W, 2.4, 0.5, { 140, 136, 130 }, "Concrete")
			for k = 1, S.floors - 1 do facebox(put, face, D / 2, "Gesims", "trim", 0, Y0 + 14 + 12 * (k - 1), 0.4, W, 0.7, 0.8, { 214, 200, 170 }, "Concrete") end
			-- Lisene: senkrechter Pfeilerstreifen an der Segmentgrenze
			facebox(put, face, D / 2, "Lisene", "trim", -len / 2, Y0 + 2.4 + (H - 3.6) / 2, 0.3, 1.0, H - 3.6, 0.6, TRIM, "Concrete")
		end
		put("Kranzgesims", "trim", 0, Y0 + H - 0.8, 0, W + 0.4, 1.6, D + 0.8, { 244, 236, 214 }, "Concrete")
		-- Mansarddach innen und außen
		local rise, run = 7, 4
		local ln = math.sqrt(run * run + rise * rise)
		local ang = math.deg(math.atan2(rise, run))
		local base = Y0 + H
		put("Mansard", "roof", 0, base + rise / 2 + 0.3, -D / 2 + run / 2, W, 0.8, ln, SLATE, "Metal", { pitch = -ang })
		put("Mansard", "roof", 0, base + rise / 2 + 0.3, D / 2 - run / 2, W, 0.8, ln, SLATE, "Metal", { pitch = ang })
		put("MansardFuellung", "body", 0, base + rise / 2 + 0.3, 0, W, rise, D - 2 * run, { 56, 60, 70 }, "SmoothPlastic", { collide = true })
		put("Dach", "roof", 0, base + rise + 0.6, 0, W, 0.6, D - 2 * run, SLATE, "Metal")
		if idx % 2 == 0 then
			put("Gaube", "body", 0, base + 2.6, -D / 2 + 2.2, 3.8, 4.4, 2.6, SAND, "SmoothPlastic")
			put("GaubeFenster", "glass", 0, base + 2.6, -D / 2 + 0.85, 2.4, 2.8, 0.2, GLASS, "Glass", { tag = "HouseWindow", lit = rng() < 0.3 })
			put("GaubeDach", "roof", 0, base + 5.0, -D / 2 + 2.2, 4.6, 0.5, 3.4, SLATE, "Metal")
		end
		-- Obergeschosse: zwei Fenster je Feld mit Gewände, innen (zum Brunnen) und außen; Balkone mit Stabgitter innen
		for k = 1, S.floors - 1 do
			local yb = Y0 + 14 + 12 * (k - 1)
			for _, u in ipairs({ -len * 0.25, len * 0.25 }) do
				bay(put, "F", D / 2, u, yb + 6, 2.8, 6.2, rng() < 0.3)
				bay(put, "B", D / 2, u, yb + 6, 2.8, 6.2, rng() < 0.3)
			end
			if k == 1 or k == 3 then
				put("BalkonPlatte", "balcony", 0, yb + 0.3, -D / 2 - 1.2, W - 1.2, 0.5, 2.4, { 170, 166, 158 }, "Concrete")
				for _, yy in ipairs({ yb + 0.9, yb + 3.0 }) do put("BalkonHolm", "balcony", 0, yy, -D / 2 - 2.3, W - 1.2, 0.25, 0.25, { 60, 60, 66 }, "Metal") end
				local nb = 7
				for q = 0, nb do put("BalkonStab", "balcony", -(W - 1.2) / 2 + q * (W - 1.2) / nb, yb + 1.95, -D / 2 - 2.3, 0.18, 2.1, 0.18, { 60, 60, 66 }, "Metal") end
			end
		end
		-- Erdgeschoss: Pilaster und Laden mit Schild und Markise (innen), Schaufenster mit Rahmen (außen)
		put("Pilaster", "trim", -len / 2, Y0 + 7, -D / 2 - 0.6, 1.2, 14, 1.2, { 214, 200, 170 }, "Concrete")
		if not opts.noShop then
			shopNo = shopNo + 1
			stats.shops = stats.shops + 1
			local burger = opts.burger
			local name = burger and "McDonnell's" or SHOPS[(shopNo * 5) % #SHOPS + 1]
			local sc = burger and { 190, 30, 36 } or SIGNS[shopNo % #SIGNS + 1]
			put("LadenGlas", "glass", 0, Y0 + 5.2, -D / 2 - 0.2, len - 1.4, 8.4, 0.3, { 150, 190, 206 }, "Glass", { tag = "HouseWindow", lit = true })
			put("LadenSchild", "trim", 0, Y0 + 11.3, -D / 2 - 0.5, len - 0.2, 2.2, 0.5, sc, "SmoothPlastic")
			put("LadenSchrift", "sign", 0, Y0 + 11.3, -D / 2 - 0.8, len - 0.8, 1.7, 0.1, { 0, 0, 0 }, "SmoothPlastic", { text = { s = name, color = burger and { 255, 208, 40 } or { 244, 238, 220 } } })
			put("Markise", "trim", 0, Y0 + 9.6, -D / 2 - 1.4, len - 0.4, 0.3, 2.6, burger and { 255, 208, 40 } or AWN[shopNo % #AWN + 1], "Fabric", { pitch = 14 })
		end
		for _, u in ipairs({ -len * 0.25, len * 0.25 }) do bay(put, "B", D / 2, u, Y0 + 7.2, 3.2, 8.6, true) end
	end
	-- Facettenkuppel: Ring aus 16 Punkten (abgerundetes Quadrat) schrumpft in vier Stufen zur Spitze; alle Flächen sind Dreiecke aus Keilen
	local ROOFA, ROOFB, GOLD = { 84, 128, 112 }, { 70, 112, 98 }, { 226, 184, 72 }
	local function dome(put, W, y0, a, b, rise)
		local N = 16
		local rings = {}
		for _, phi in ipairs({ 0, 32, 60, 80 }) do
			local sc, h, pts = math.cos(math.rad(phi)), rise * math.sin(math.rad(phi)), {}
			for k = 0, N - 1 do
				local t = 2 * math.pi * k / N
				local c, sn = math.cos(t), math.sin(t)
				pts[#pts + 1] = { sc * a * (c < 0 and -1 or 1) * math.abs(c) ^ 0.5, y0 + h, sc * b * (sn < 0 and -1 or 1) * math.abs(sn) ^ 0.5 }
			end
			rings[#rings + 1] = pts
		end
		local apex = { 0, y0 + rise, 0 }
		local function face(p1, p2, p3, col)
			local hint = { (p1[1] + p2[1] + p3[1]) / 3, (p1[2] + p2[2] + p3[2]) / 3 - (y0 - rise * 0.5), (p1[3] + p2[3] + p3[3]) / 3 }
			wtri(W, "Kuppel", "roof", p1, p2, p3, 0.8, col, "Metal", hint)
		end
		for i = 1, #rings - 1 do
			for k = 1, N do
				local k2 = k % N + 1
				local col = ((i + k) % 2 == 0) and ROOFA or ROOFB
				face(rings[i][k], rings[i][k2], rings[i + 1][k2], col)
				face(rings[i][k], rings[i + 1][k2], rings[i + 1][k], col)
			end
		end
		local top = rings[#rings]
		for k = 1, N do face(top[k], top[k % N + 1], apex, (k % 2 == 0) and ROOFA or ROOFB) end
		local fy = y0 + rise - 0.3 -- Spitze aus sechs Dreiecken
		for k = 0, 5 do
			local t0, t1 = math.pi * k / 3, math.pi * (k + 1) / 3
			local p1, p2, p3 = { 1.1 * math.cos(t0), fy, 1.1 * math.sin(t0) }, { 1.1 * math.cos(t1), fy, 1.1 * math.sin(t1) }, { 0, fy + 6.5, 0 }
			wtri(W, "KuppelSpitze", "roof", p1, p2, p3, 0.4, GOLD, "Metal", { (p1[1] + p2[1]) / 2, fy + 1, (p1[3] + p2[3]) / 2 })
		end
	end
	-- Eckturm: quadratischer Block (alle vier Seiten gleich lang, gleiche Fenster) mit Facettenkuppel
	local function tower(x, z, psi, Wt)
		local put, Wf = frame(x, z, psi)
		local Ht = H + 12
		stats.towers = stats.towers + 1
		put("Turm", "body", 0, Y0 + Ht / 2, 0, Wt, Ht, D, SAND2, "SmoothPlastic", { collide = true })
		put("TurmKranz", "trim", 0, Y0 + Ht - 0.8, 0, Wt + 1.4, 1.6, D + 1.4, { 244, 236, 214 }, "Concrete")
		for _, face in ipairs({ "F", "B", "L", "R" }) do
			local half = (face == "F" or face == "B") and D / 2 or Wt / 2
			local len = (face == "F" or face == "B") and Wt or D
			facebox(put, face, half, "TurmSockel", "trim", 0, Y0 + 1.2, 0.25, len, 2.4, 0.5, { 140, 136, 130 }, "Concrete")
			for k = 1, 5 do facebox(put, face, half, "TurmGesims", "trim", 0, Y0 + 14 + 12 * (k - 1), 0.4, len, 0.7, 0.8, { 214, 200, 170 }, "Concrete") end
			for _, u in ipairs({ -len / 2 + 0.6, len / 2 - 0.6 }) do facebox(put, face, half, "Lisene", "trim", u, Y0 + 2.4 + (Ht - 3.6) / 2, 0.3, 1.2, Ht - 3.6, 0.6, TRIM, "Concrete") end
			for k = 1, 5 do
				for _, u in ipairs({ -len / 3, 0, len / 3 }) do bay(put, face, half, u, Y0 + 14 + 12 * (k - 1) + 6, 2.8, 6.4, rng() < 0.3) end
			end
			for _, u in ipairs({ -len / 3, 0, len / 3 }) do bay(put, face, half, u, Y0 + 7.2, 3.6, 8.6, true) end
		end
		dome(put, Wf, Y0 + Ht, Wt / 2, D / 2, 14)
	end
	local TW = D -- Eckturm: Grundfläche quadratisch (Breite = Tiefe)
	local zN = S.rowN -- Mittellinie der Nordzeile; die Südzeile liegt spiegelbildlich zur Platzmitte
	local zS = 2 * cz - zN
	local xW = S.x0 + D / 2 + 1.6 -- Mittellinie der Westzeile (1,6 Abstand zur Platzgrenze für Gesimse und Fensterrahmen der Rückseite)
	local idx = 0
	local function rowEW(z, psi, burgerAt) -- Zeile von der Platzkante x0 bis zum Eckturm am Ostende
		local xa, xb = S.x0 + 2.3, S.eastEnd - TW - 0.7
		local m = math.floor((xb - xa) / S.seg + 0.5)
		local Lr = (xb - xa) / m
		for k = 1, m do
			idx = idx + 1
			segment(xa + (k - 0.5) * Lr, z, psi, Lr, idx, { burger = burgerAt and (k == burgerAt or k == burgerAt + 1) })
			if k == math.floor(m / 2) then roofSigns[#roofSigns + 1] = { x = xa + (k - 0.5) * Lr, z = z, psi = psi } end
		end
		tower(S.eastEnd - TW / 2 - 0.7, z, psi, TW)
	end
	rowEW(zN, 180, 10)
	rowEW(zS, 0, nil)
	do -- Westzeile: zwischen Nord- und Südzeile je ein Stück bis zum Eckturm neben dem Karlstor
		local function run(za, zb)
			local m = math.max(1, math.floor((zb - za) / S.seg + 0.5))
			local Lr = (zb - za) / m
			for k = 1, m do
				idx = idx + 1
				segment(xW, za + (k - 0.5) * Lr, 270, Lr, idx, {})
			end
		end
		run(zN + D / 2, cz - S.gate - TW)
		run(cz + S.gate + TW, zS - D / 2)
		tower(xW, cz - S.gate - TW / 2, 270, TW)
		tower(xW, cz + S.gate + TW / 2, 270, TW)
	end
	-- Dachschrift OSRUM auf beiden Flügeln
	for _, rs in ipairs(roofSigns) do
		local put = frame(rs.x, rs.z, rs.psi)
		local base = TOP + 7.6
		for _, lx in ipairs({ -12, 12 }) do put("SchriftPfosten", "trim", lx, base + 2.4, -4, 0.8, 4.8, 0.8, { 90, 90, 96 }, "Metal") end
		put("SchriftBrett", "sign", 0, base + 7.5, -4, 34, 7, 0.8, { 176, 32, 40 }, "SmoothPlastic")
		put("SchriftOSRUM", "sign", 0, base + 7.5, -4.5, 31, 5.4, 0.2, { 0, 0, 0 }, "SmoothPlastic", { text = { s = "OSRUM", color = { 250, 244, 236 } } })
	end

	-- Karlstor (nach Foto): Mittelbau mit hohem Spitzbogen zwischen zwei Zinnentürmen mit je einem kleineren Spitzbogen-Durchgang; Bogenleisten, Wappen,
	-- Schrifttafeln, Fenster mit Gewände. Die Bögen sind aus Dreiecken (Keilen) gebaut, keine Treppenstufen. Front (lz < 0) zum Brunnen.
	do
		local gx, gz = xW, cz
		local put, Wf = frame(gx, gz, 270)
		local GD = D - 1.6
		local WALL, WALL2 = { 238, 236, 228 }, { 226, 222, 210 }
		local TT, MT = H - 2.2, H - 6.2 -- Mauerkrone Türme / Mittelbau (Zinnen setzen 2,2 obendrauf)
		local function archPts(hw, ySpring, n) -- Spitzbogen aus zwei Kreisbögen (Radius = Breite): Punkte von links nach rechts, y relativ zum Pflaster
			local R, pts = 2 * hw, {}
			for k = 0, n do
				local th = math.rad(180 - 60 * k / n)
				pts[#pts + 1] = { hw + R * math.cos(th), ySpring + R * math.sin(th) }
			end
			for k = n - 1, 0, -1 do pts[#pts + 1] = { -pts[k + 1][1], pts[k + 1][2] } end
			return pts
		end
		-- Mauermasse um einen Durchgang: Pfeiler links/rechts bis zur Oberkante, darüber Streifen aus Rechteck und Dreieck entlang des Bogens
		local function archWall(cxm, hw, ySpring, xl, xr, top, n)
			put("TorMauer", "body", (xl + cxm - hw) / 2, Y0 + top / 2, 0, cxm - hw - xl, top, GD, WALL, "SmoothPlastic", { collide = true })
			put("TorMauer", "body", (cxm + hw + xr) / 2, Y0 + top / 2, 0, xr - cxm - hw, top, GD, WALL, "SmoothPlastic", { collide = true })
			local pts = archPts(hw, ySpring, n)
			for k = 1, #pts - 1 do
				local a, b = pts[k], pts[k + 1]
				local xa, xb = cxm + a[1], cxm + b[1]
				local yhi = math.max(a[2], b[2])
				if top > yhi then put("TorMauer", "body", (xa + xb) / 2, Y0 + (yhi + top) / 2, 0, xb - xa + 0.02, top - yhi, GD, WALL, "SmoothPlastic", { collide = true }) end
				local third = (a[2] < b[2]) and { xa, Y0 + b[2], 0 } or { xb, Y0 + a[2], 0 }
				wtri(Wf, "TorMauer", "body", { xa, Y0 + a[2], 0 }, { xb, Y0 + b[2], 0 }, third, GD, WALL, "SmoothPlastic", nil, { collide = true })
			end
		end
		-- Bogenleiste (Archivolte) um den Durchgang, vorn und hinten
		local function moulding(cxm, hw, ySpring, n, band)
			local inner, outer = archPts(hw, ySpring, n), archPts(hw + band, ySpring, n)
			for _, fz in ipairs({ -1, 1 }) do
				local zz = fz * (GD / 2 + 0.25)
				for k = 1, #inner - 1 do
					local p1, p2 = { cxm + inner[k][1], Y0 + inner[k][2], zz }, { cxm + inner[k + 1][1], Y0 + inner[k + 1][2], zz }
					local q1, q2 = { cxm + outer[k][1], Y0 + outer[k][2], zz }, { cxm + outer[k + 1][1], Y0 + outer[k + 1][2], zz }
					wtri(Wf, "TorLeiste", "trim", p1, p2, q1, 0.5, WALL2, "Concrete", { 0, 0, fz })
					wtri(Wf, "TorLeiste", "trim", p2, q2, q1, 0.5, WALL2, "Concrete", { 0, 0, fz })
				end
				for _, sd in ipairs({ -1, 1 }) do put("TorLeiste", "trim", cxm + sd * (hw + band / 2), Y0 + ySpring / 2, zz, band, ySpring, 0.5, WALL2, "Concrete") end
			end
		end
		-- Mittelbau mit hohem Spitzbogen, Türme mit kleineren Durchgängen
		archWall(0, 7.5, 22, -12, 12, MT, 9)
		moulding(0, 7.5, 22, 9, 1.4)
		for _, sd in ipairs({ -1, 1 }) do
			archWall(sd * 21, 3.5, 11, sd * 21 - 9, sd * 21 + 9, TT, 6)
			moulding(sd * 21, 3.5, 11, 6, 0.9)
			put("TorTurmGesims", "trim", sd * 21, Y0 + TT - 1, 0, 19.2, 1.4, GD + 1.2, WALL2, "Concrete")
			put("TorTurmStreifen", "trim", sd * 21, Y0 + 22, 0, 19, 0.8, GD + 1.0, WALL2, "Concrete")
			for _, fz in ipairs({ -1, 1 }) do
				for _, wy in ipairs({ 30, 41, 51 }) do bay(put, fz < 0 and "F" or "B", GD / 2, sd * 21, Y0 + wy, 2.2, 4.4, false) end
				local zz = fz * (GD / 2 + 0.3)
				put("TorTafel", "trim", sd * 27.6, Y0 + 30, zz, 4.2, 6, 0.5, { 214, 206, 190 }, "Concrete")
				put("TorTafelSchrift", "sign", sd * 27.6, Y0 + 30, zz + fz * 0.3, 3.6, 1.1, 0.1, { 0, 0, 0 }, "SmoothPlastic", { yaw = fz < 0 and 0 or 180, text = { s = "ANNO 1302", color = { 90, 86, 80 } } })
			end
		end
		for _, fz in ipairs({ -1, 1 }) do
			local zz = fz * (GD / 2 + 0.35)
			for _, sd in ipairs({ -1, 1 }) do -- Wappen in den Zwickeln neben dem Hauptbogen
				local u, wy = sd * 9.9, Y0 + 30
				local col = sd < 0 and { 70, 110, 190 } or { 220, 220, 226 }
				put("TorWappen", "trim", u, wy, zz, 3.4, 3.4, 0.5, col, "SmoothPlastic")
				wtri(Wf, "TorWappen", "trim", { u - 1.7, wy - 1.7, zz }, { u + 1.7, wy - 1.7, zz }, { u, wy - 4.2, zz }, 0.5, col, "SmoothPlastic", { 0, 0, fz })
				put("TorWappenKreuz", "trim", u, wy, zz + fz * 0.3, 0.6, 3.0, 0.2, { 190, 150, 50 }, "Metal")
			end
			put("TorSchrift", "sign", 0, Y0 + 42, fz * (GD / 2 + 0.4), 12, 1.6, 0.1, { 0, 0, 0 }, "SmoothPlastic", { yaw = fz < 0 and 0 or 180, text = { s = "KARLSTOR", color = { 90, 86, 80 } } })
		end
		put("TorMittelGesims", "trim", 0, Y0 + MT - 0.8, 0, 26, 1.6, GD + 1.2, WALL2, "Concrete")
		-- Zinnen auf Mittelbau und Türmen
		local function merlons(lx0, lx1, y)
			local len = lx1 - lx0
			local k = math.max(2, math.floor(len / 3.6))
			for q = 1, k do
				for _, fz in ipairs({ -GD / 2 + 1, GD / 2 - 1 }) do
					put("Zinne", "trim", lx0 + (q - 0.5) * len / k, y + 1.1, fz, len / k * 0.55, 2.2, 1.6, WALL, "Concrete", { collide = true })
					stats.merlons = stats.merlons + 1
				end
			end
			for _, lx in ipairs({ lx0 + 0.8, lx1 - 0.8 }) do
				for _, fz in ipairs({ -GD / 4, 0, GD / 4 }) do put("Zinne", "trim", lx, y + 1.1, fz, 1.6, 2.2, 3, WALL, "Concrete", { collide = true }) stats.merlons = stats.merlons + 1 end
			end
		end
		merlons(-12, 12, Y0 + MT)
		merlons(-30, -12, Y0 + TT)
		merlons(12, 30, Y0 + TT)
	end

	-- U-Bahn-Abgänge (nach Foto): weißer Betonrahmen, in der Mitte eine Treppe zwischen zwei Rolltreppen, Glasgeländer, Pylon mit U-Schild;
	-- der Zugang liegt am Westende (zum Brunnen), die Treppe führt nach Osten in Richtung Taxistand nach unten (lokal: lz = Abstand vom Zugang, lx quer)
	local CONC, STEEL, UBLUE, SGREEN, WHITE = { 226, 224, 218 }, { 60, 64, 70 }, { 0, 94, 184 }, { 0, 150, 70 }, { 255, 255, 255 }
	for pi, U in ipairs(pits) do
		local len, wd = U.x1 - U.x0, U.z1 - U.z0
		local put = frame(U.x0, (U.z0 + U.z1) / 2, 90)
		local nSteps, landing = 14, 6
		local rise, run = U.depth / nSteps, (len - landing) / nSteps
		local bottom = 1 - U.depth
		local lanes = { { -4.6, 3.8, { 70, 74, 80 }, "Metal" }, { 0, 4.8, { 168, 166, 160 }, "Granite" }, { 4.6, 3.8, { 70, 74, 80 }, "Metal" } }
		for k = 1, nSteps do
			local t = 1 - k * rise
			for _, ln in ipairs(lanes) do
				put("UBahnStufe", "plaza", ln[1], (t - 12) / 2, (k - 0.5) * run, ln[2], t + 12, run, ln[3], ln[4], { collide = true })
			end
		end
		put("UBahnPodest", "plaza", 0, (bottom - 12) / 2, len - landing / 2, wd - 2.4, bottom + 12, landing, { 150, 148, 144 }, "Granite", { collide = true })
		local slope = math.sqrt((len - landing) ^ 2 + U.depth ^ 2)
		local pitch = math.deg(math.atan2(U.depth, len - landing))
		for _, lx in ipairs({ -7.2, -2.4, 2.4, 7.2 }) do -- Handläufe (sinken mit der Treppe)
			put("UBahnHandlauf", "plaza", lx, 1 - U.depth / 2 + 2.6, (len - landing) / 2, 0.3, 0.3, slope, STEEL, "Metal", { pitch = pitch })
		end
		for _, sd in ipairs({ -1, 1 }) do -- Seitenwände (Betonrahmen) bis 1,6 über das Pflaster
			put("UBahnWand", "plaza", sd * (wd / 2 - 0.6), -5.2 + 0.8, len / 2, 1.2, 13.6 + 1.6, len, CONC, "Concrete", { collide = true })
			for k = 0, 5 do -- Glasgeländer auf dem Rahmen
				put("UBahnGlas", "glass", sd * (wd / 2 - 0.6), 3.2, (k + 0.5) * len / 6, 0.2, 1.8, len / 6 - 0.3, { 190, 220, 232 }, "Glass", { collide = false, transparency = 0.5 })
			end
		end
		-- Gegenende (Osten): Wand mit Portal und Schild; Gang dahinter
		local pw, ph = 10, 8
		for _, sd in ipairs({ -1, 1 }) do
			put("UBahnWand", "plaza", sd * (pw / 2 + (wd - pw) / 4), -5.2 + 0.8, len - 0.6, (wd - pw) / 2, 13.6 + 1.6, 1.2, CONC, "Concrete", { collide = true })
		end
		put("UBahnWand", "plaza", 0, (bottom + ph + 2.4) / 2, len - 0.6, pw, 2.4 - bottom - ph, 1.2, CONC, "Concrete", { collide = true })
		put("UBahnSchild", "plaza", 0, 3.2, len - 1.3, 14, 2.4, 0.3, UBLUE, "SmoothPlastic")
		put("Schrift", "sign", 0, 3.2, len - 1.5, 13, 1.8, 0.2, WHITE, "SmoothPlastic", { yaw = 0, text = { s = "U  S  KARLSPLATZ", color = WHITE } })
		put("UBahnPylon", "plaza", -(wd / 2 + 2.4), 6, -2.5, 0.8, 10, 0.8, { 30, 32, 36 }, "Metal", { collide = true })
		put("UBahnU", "plaza", -(wd / 2 + 2.4), 10.8, -2.5, 4, 4, 0.4, UBLUE, "SmoothPlastic")
		put("Schrift", "sign", -(wd / 2 + 2.4), 10.8, -2.8, 3.4, 3.4, 0.2, WHITE, "SmoothPlastic", { text = { s = "U", color = WHITE } })
		put("Schrift", "sign", -(wd / 2 + 2.4), 10.8, -2.2, 3.4, 3.4, 0.2, WHITE, "SmoothPlastic", { yaw = 180, text = { s = "U", color = WHITE } })
		-- Gang hinter dem Portal: Boden, Decke, Wände, Rückwand, Leuchten
		local g0, g1 = len, len + U.gang
		put("UBahnGangBoden", "plaza", 0, bottom - 0.5, (g0 + g1) / 2, pw + 2, 1, g1 - g0, { 150, 148, 144 }, "Granite", { collide = true })
		put("UBahnGangDecke", "plaza", 0, bottom + ph + 1, (g0 + g1) / 2, pw + 2, 1, g1 - g0, { 200, 200, 196 }, "Concrete", { collide = true })
		for _, sd in ipairs({ -1, 1 }) do put("UBahnGangWand", "plaza", sd * (pw / 2 + 0.5), bottom + ph / 2, (g0 + g1) / 2, 1, ph, g1 - g0, { 226, 222, 210 }, "Concrete", { collide = true }) end
		put("UBahnGangWand", "plaza", 0, bottom + ph / 2, g1 + 0.5, pw + 2, ph, 1, { 226, 222, 210 }, "Concrete", { collide = true })
		for k = 1, 3 do put("UBahnLicht", "plaza", 0, bottom + ph + 0.4, len + k * U.gang / 4, 1.2, 0.2, 3, { 255, 250, 236 }, "Neon") end
	end

	-- Kugelleuchten und Platanen auf der Ostseite, Taxistand an der Leopoldstraße
	for z = S.z0 + 41, S.z1 - 12, 42 do -- mittig zwischen den Platanen (Bäume bei z = 80 + 42 k), nicht in den Kronen
		vcyl("KugelleuchteMast", "plaza", -68, 13, z, 24, 0.8, { 150, 152, 156 }, "Metal", { collide = true })
		for _, yy in ipairs({ 19.6, 23.6 }) do add("Kugelleuchte", "plaza", -68, yy, z, 4.4, 4.4, 4.4, { 255, 250, 238 }, "Neon", { shape = "Ball", tag = "StreetLamp", attrs = { Lit = true } }) end
		stats.lamps = stats.lamps + 1
	end
	local GREENS = { { 70, 120, 60 }, { 88, 140, 70 }, { 60, 108, 58 } }
	for i, z in ipairs({ 80, 122, 164, 206, 248, 290, 332, 372 }) do
		local x = -64
		vcyl("Baumscheibe", "plaza", x, 1.15, z, 0.3, 6, { 70, 66, 60 }, "Metal")
		vcyl("PlataneStamm", "plaza", x, 7, z, 12, 2.2, { 150, 138, 116 }, "Wood", { collide = true })
		add("PlataneKrone", "plaza", x, 18, z, 17, 15, 17, GREENS[i % 3 + 1], "Grass", { shape = "Ball" })
		add("PlataneKrone", "plaza", x + 3, 15.5, z - 3, 12, 11, 12, GREENS[(i + 1) % 3 + 1], "Grass", { shape = "Ball" })
		stats.trees = stats.trees + 1
	end
	-- Taxistand: auf jede Parkbucht ist "TAXI" aufgemalt (flach auf der Fahrbahn, lesbar für Fahrer Richtung Süden); keine Fahrzeuge
	for k = 0, S.taxi.n - 1 do
		local z = S.taxi.z0 + S.taxi.len * (k + 0.5)
		add("TaxiMarkierung", "sign", S.taxi.x, 0.58, z, 6.6, 3.4, 0.1, { 0, 0, 0 }, "SmoothPlastic", { pitch = 90, text = { s = "TAXI", color = { 250, 214, 60 } } })
		stats.taxis = stats.taxis + 1
	end
	for _, z in ipairs({ S.taxi.z0 - 2, S.taxi.z0 + S.taxi.len * S.taxi.n + 2 }) do
		vcyl("TaxiMast", "plaza", -49, 8, z, 14, 0.5, { 130, 134, 140 }, "Metal", { collide = true })
		add("TaxiTafel", "sign", -49, 14.5, z, 0.4, 3.6, 3.6, { 30, 70, 160 }, "SmoothPlastic", { yaw = 0 })
		add("TaxiSchrift", "sign", -49.3, 14.5, z, 3.2, 1.6, 0.1, { 0, 0, 0 }, "SmoothPlastic", { yaw = 270, text = { s = "TAXI", color = { 255, 255, 255 } } })
	end
	return { parts = parts, stats = stats }
end

return Stachus
