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
			text = e.text, tag = e.tag, lit = e.lit, attrs = e.attrs, transparency = e.transparency,
		}
	end
	local function vcyl(name, kind, x, y, z, h, d, color, mat, e)
		e = e or {}
		e.shape, e.roll = "Cylinder", 90
		add(name, kind, x, y, z, h, d, d, color, mat, e)
	end
	-- lokales Hausmaß: lx entlang der Fassade, lz in das Gebäude (Front lz < 0), Drehung wie in Planner.add
	local function frame(cx, cz, psi)
		local r = math.rad(psi)
		local c, s = math.cos(r), math.sin(r)
		return function(name, kind, lx, y, lz, sx, sy, sz, color, mat, e)
			e = e or {}
			local ee = {}
			for k, v in pairs(e) do ee[k] = v end
			ee.yaw = (psi + (e.yaw or 0)) % 360
			add(name, kind, cx + lx * c + lz * s, y, cz - lx * s + lz * c, sx, sy, sz, color, mat, ee)
		end
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
			for i = 1, #zs - 1, 2 do add("Fuge", "plaza", x, 1.03, (zs[i] + zs[i + 1]) / 2, 0.18, 0.06, zs[i + 1] - zs[i], { 172, 166, 156 }, "SmoothPlastic") end
		else
			add("Fuge", "plaza", x, 1.03, (S.z0 + S.z1) / 2, 0.18, 0.06, S.z1 - S.z0, { 172, 166, 156 }, "SmoothPlastic")
		end
	end
	for z = S.z0 + 8, S.z1 - 4, 8 do
		if inPit(px0 + 1, z) then
			add("Fuge", "plaza", (S.x0 + px0) / 2, 1.03, z, px0 - S.x0, 0.06, 0.18, { 172, 166, 156 }, "SmoothPlastic")
			add("Fuge", "plaza", (px1 + S.x1) / 2, 1.03, z, S.x1 - px1, 0.06, 0.18, { 172, 166, 156 }, "SmoothPlastic")
		else
			add("Fuge", "plaza", (S.x0 + S.x1) / 2, 1.03, z, S.x1 - S.x0, 0.06, 0.18, { 172, 166, 156 }, "SmoothPlastic")
		end
	end
	for i, rr in ipairs({ 52, 49, 46 }) do vcyl("Pflasterring", "plaza", cx, 1.08 + i * 0.01, cz, 0.08, 2 * rr, i == 2 and { 150, 96, 84 } or { 186, 180, 170 }, "Granite") end

	-- Brunnen: Beckenrand aus Granitblöcken, Wasser, Strahlenkränze, Mittelstrahl, Poller
	local R = S.basin
	for i = 0, 35 do
		local a = math.rad(i * 10)
		add("Beckenrand", "plaza", cx + R * math.cos(a), 2.1, cz + R * math.sin(a), 8, 2.2, 2.6, STONE, "Granite", { yaw = math.deg(math.atan2(-math.cos(a), -math.sin(a))) % 360, collide = true })
	end
	vcyl("Beckenboden", "plaza", cx, 1.2, cz, 0.3, 2 * R, { 120, 140, 156 }, "Concrete")
	vcyl("Wasser", "plaza", cx, 2.3, cz, 0.4, 2 * R - 2, { 130, 180, 214 }, "SmoothPlastic", { transparency = 0.45 })
	for _, ring in ipairs({ { 20, 24, 10, 6 }, { 32, 30, 8, 5 } }) do -- Radius, Strahlen, Reichweite, Höhe des Bogens
		for k = 0, ring[2] - 1 do
			local a = math.rad(k * 360 / ring[2] + (ring[1] > 25 and 6 or 0))
			for j = 0, 5 do
				local t = j / 5
				local r = ring[1] + ring[3] * t
				add("Wasserstrahl", "plaza", cx + r * math.cos(a), 2.6 + 4 * ring[4] * t * (1 - t), cz + r * math.sin(a), 0.9, 0.9, 0.9, { 240, 248, 255 }, "SmoothPlastic", { shape = "Ball", transparency = 0.25 })
			end
			stats.jets = stats.jets + 1
		end
	end
	vcyl("Mittelstrahl", "plaza", cx, 9, cz, 14, 1.4, { 240, 248, 255 }, "SmoothPlastic", { transparency = 0.3 })
	vcyl("Mittelsockel", "plaza", cx, 2.2, cz, 1.6, 8, STONE, "Granite", { collide = true })
	for i = 0, 35 do -- Poller (niedrige Steinstümpfe) rund um das Becken
		local a = math.rad(i * 10 + 5)
		vcyl("Poller", "plaza", cx + (R + 7) * math.cos(a), 2.3, cz + (R + 7) * math.sin(a), 2.6, 2.4, { 150, 146, 140 }, "Granite", { collide = true })
	end
	for i = 0, 9 do -- Sitzsteine auf der Ostseite
		local a = math.rad(-72 + i * 16)
		add("Sitzstein", "plaza", cx + (R + 11) * math.cos(a), 2.3, cz + (R + 11) * math.sin(a), 3.4, 2.6, 2.6, { 160, 156, 148 }, "Granite", { yaw = i * 23, collide = true })
	end

	-- Gebäudezeilen: Nordzeile (Front nach Süden), Südzeile (Front nach Norden), Westzeile mit Karlstor (Front nach Osten); alle Wand an Wand
	local shopNo, roofSigns = 0, {}
	local function segment(x, z, psi, len, idx, opts)
		opts = opts or {}
		local put = frame(x, z, psi)
		local W = len + 1.4
		stats.segs = stats.segs + 1
		put("Gebaeude", "body", 0, Y0 + H / 2, 0, W, H, D, SAND, "SmoothPlastic", { collide = true })
		put("Sockel", "trim", 0, Y0 + 1.2, -D / 2 - 0.25, W, 2.4, 0.5, { 140, 136, 130 }, "Concrete")
		for k = 1, S.floors - 1 do put("Gesims", "trim", 0, Y0 + 14 + 12 * (k - 1), -D / 2 - 0.4, W, 0.7, 0.8, { 214, 200, 170 }, "Concrete") end
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
		-- Fenster: innen (zum Brunnen) und außen
		for k = 1, S.floors - 1 do
			local yb = Y0 + 14 + 12 * (k - 1)
			put("Fenster", "glass", 0, yb + 6, -D / 2 - 0.15, 3.8, 6.4, 0.3, rng() < 0.3 and GLASS_LIT or GLASS, "Glass", { tag = "HouseWindow", lit = false })
			put("Fensterbank", "trim", 0, yb + 2.6, -D / 2 - 0.45, 5, 0.5, 0.9, { 214, 200, 170 }, "Concrete")
			if k == 1 or k == 3 then
				put("BalkonPlatte", "balcony", 0, yb + 0.3, -D / 2 - 1.2, W - 1.2, 0.5, 2.4, { 170, 166, 158 }, "Concrete")
				put("BalkonGitter", "balcony", 0, yb + 1.9, -D / 2 - 2.3, W - 1.2, 2.4, 0.25, { 60, 60, 66 }, "Metal")
			end
			put("FensterAussen", "glass", 0, yb + 6, D / 2 + 0.15, 3.8, 6.4, 0.3, rng() < 0.3 and GLASS_LIT or GLASS, "Glass", { tag = "HouseWindow", lit = false })
		end
		-- Erdgeschoss: Pilaster und Laden mit Schild und Markise (innen), dunkle Fensterfläche (außen)
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
		put("EGFensterAussen", "glass", 0, Y0 + 6, D / 2 + 0.15, len - 1.6, 8, 0.3, GLASS, "Glass", { tag = "HouseWindow", lit = false })
	end
	-- Endturm: breiter Block mit 6 Geschossen und gerundetem Dach (ohne Stufen und Kanten)
	local ROOF = { 96, 58, 56 }
	local function tower(x, z, psi, Wt, endSide)
		local put = frame(x, z, psi)
		local Ht = H + 12
		stats.towers = stats.towers + 1
		put("Turm", "body", 0, Y0 + Ht / 2, 0, Wt, Ht, D, SAND2, "SmoothPlastic", { collide = true })
		put("TurmSockel", "trim", 0, Y0 + 1.2, -D / 2 - 0.25, Wt, 2.4, 0.5, { 140, 136, 130 }, "Concrete")
		put("TurmKranz", "trim", 0, Y0 + Ht - 0.8, 0, Wt + 1.4, 1.6, D + 0.8, { 244, 236, 214 }, "Concrete")
		for k = 1, 5 do put("TurmGesims", "trim", 0, Y0 + 14 + 12 * (k - 1), -D / 2 - 0.4, Wt, 0.7, 0.8, { 214, 200, 170 }, "Concrete") end
		for k = 1, 5 do
			local yb = Y0 + 14 + 12 * (k - 1)
			for _, lx in ipairs({ -8, 0, 8 }) do
				put("TurmFenster", "glass", lx, yb + 6, -D / 2 - 0.15, 3.8, 6.4, 0.3, rng() < 0.3 and GLASS_LIT or GLASS, "Glass", { tag = "HouseWindow", lit = false })
				put("TurmFensterAussen", "glass", lx, yb + 6, D / 2 + 0.15, 3.8, 6.4, 0.3, rng() < 0.3 and GLASS_LIT or GLASS, "Glass", { tag = "HouseWindow", lit = false })
			end
			if endSide then
				for _, lz in ipairs({ -10, 0, 10 }) do put("TurmFensterStirn", "glass", endSide * (Wt / 2 + 0.15), yb + 6, lz, 0.3, 6.4, 3.8, rng() < 0.3 and GLASS_LIT or GLASS, "Glass", { tag = "HouseWindow", lit = false }) end
			end
		end
		for _, lx in ipairs({ -8, 0, 8 }) do put("TurmEG", "glass", lx, Y0 + 6, -D / 2 - 0.15, 5.6, 8, 0.3, GLASS, "Glass", { tag = "HouseWindow", lit = true }) end
		local rise = 10
		-- gerundetes Tonnendach: liegender Halb-Ellipsenzylinder (Achse entlang der Tiefe) über dem ganzen Turm; die untere Hälfte steckt im Mauerwerk
		put("Rundach", "roof", 0, Y0 + Ht, 0, D, 2 * rise, Wt, ROOF, "Metal", { shape = "Cylinder", yaw = 90 })
		put("Turmkugel", "roof", 0, Y0 + Ht + rise + 1, 0, 2.2, 2.2, 2.2, { 226, 184, 72 }, "Metal", { shape = "Ball" })
	end
	local TW = 26 -- Breite der Endtürme
	local zN = S.rowN -- Mittellinie der Nordzeile; die Südzeile liegt spiegelbildlich zur Platzmitte
	local zS = 2 * cz - zN
	local xW = S.x0 + D / 2 -- Mittellinie der Westzeile
	local idx = 0
	local function rowEW(z, psi, side, burgerAt) -- Zeile von der Platzkante x0 bis zum Ostende, am Ende ein Turm
		local xa, xb = S.x0 + 0.7, S.eastEnd - 0.7
		local m = math.floor((xb - xa) / S.seg + 0.5)
		local Lr = (xb - xa) / m
		for k = 1, m do
			idx = idx + 1
			segment(xa + (k - 0.5) * Lr, z, psi, Lr, idx, { burger = burgerAt and (k == burgerAt or k == burgerAt + 1) })
			if k == math.floor(m / 2) then roofSigns[#roofSigns + 1] = { x = xa + (k - 0.5) * Lr, z = z, psi = psi } end
		end
		tower(S.eastEnd - TW / 2 - 0.7, z, psi, TW, side)
	end
	rowEW(zN, 180, -1, 11)
	rowEW(zS, 0, 1, nil)
	do -- Westzeile zwischen den beiden Zeilen, Lücke fürs Karlstor, daneben je ein Turm
		local za, zb = zN + D / 2, zS - D / 2
		local m = math.floor((zb - za) / S.seg + 0.5)
		local Lr = (zb - za) / m
		for k = 1, m do
			local z = za + (k - 0.5) * Lr
			if math.abs(z - cz) >= S.gate + Lr * 0.1 then
				idx = idx + 1
				segment(xW, z, 270, Lr, idx, {})
			end
		end
		tower(xW, cz - S.gate - TW / 2, 270, TW, nil)
		tower(xW, cz + S.gate + TW / 2, 270, TW, nil)
	end
	-- Dachschrift OSRUM auf beiden Flügeln
	for _, rs in ipairs(roofSigns) do
		local put = frame(rs.x, rs.z, rs.psi)
		local base = TOP + 7.6
		for _, lx in ipairs({ -12, 12 }) do put("SchriftPfosten", "trim", lx, base + 2.4, -4, 0.8, 4.8, 0.8, { 90, 90, 96 }, "Metal") end
		put("SchriftBrett", "sign", 0, base + 7.5, -4, 34, 7, 0.8, { 176, 32, 40 }, "SmoothPlastic")
		put("SchriftOSRUM", "sign", 0, base + 7.5, -4.5, 31, 5.4, 0.2, { 0, 0, 0 }, "SmoothPlastic", { text = { s = "OSRUM", color = { 250, 244, 236 } } })
	end

	-- Karlstor (so hoch wie die Flügel, Zinnen bis zur Traufe): Mittelbau mit Bogendurchgang zwischen zwei Zinnentürmen; Front (lz < 0) zum Brunnen
	do
		local gx, gz = xW, cz
		local put = frame(gx, gz, 270)
		local GD = D - 1.6
		local WALL, WALL2 = { 238, 236, 228 }, { 226, 222, 210 }
		local TT, MT = H - 2.2, H - 6.2 -- Mauerkrone Türme / Mittelbau (Zinnen setzen 2,2 obendrauf)
		for _, sd in ipairs({ -1, 1 }) do
			put("TorTurm", "body", sd * 21, Y0 + TT / 2, 0, 18, TT, GD, WALL, "SmoothPlastic", { collide = true })
			put("TorTurmGesims", "trim", sd * 21, Y0 + TT - 1, 0, 19.2, 1.4, GD + 1.2, WALL2, "Concrete")
			for _, wz in ipairs({ -GD / 2 - 0.15, GD / 2 + 0.15 }) do
				put("TorSeitenbogen", "trim", sd * 21, Y0 + 6, wz, 6, 12, 0.3, { 60, 56, 52 }, "SmoothPlastic")
				put("TorSeitenbogen", "trim", sd * 21, Y0 + 12, wz, 4.2, 4.2, 0.3, { 60, 56, 52 }, "SmoothPlastic", { roll = 45 })
				for _, wy in ipairs({ 26, 40, 52 }) do put("TorFenster", "glass", sd * 21, Y0 + wy, wz, 2.6, 5, 0.3, GLASS, "Glass", { tag = "HouseWindow", lit = false }) end
				put("TorTurmStreifen", "trim", sd * 21, Y0 + 18, wz, 19, 0.8, 0.5, WALL2, "Concrete")
			end
		end
		for _, sd in ipairs({ -1, 1 }) do -- Pfeiler beidseits des Durchgangs (|lx| 6 bis 12)
			put("TorPfeiler", "body", sd * 9, Y0 + MT / 2, 0, 6, MT, GD, WALL, "SmoothPlastic", { collide = true })
		end
		local rr, spring, m = 6, 12, 12 -- Bogen: Halbkreis
		local w = 2 * rr / m
		for i = 1, m do
			local xc = -rr + (i - 0.5) * w
			local bottom = spring + math.sqrt(math.max(0, rr * rr - xc * xc))
			put("TorBogen", "body", xc, Y0 + (bottom + MT) / 2, 0, w + 0.05, MT - bottom, GD, WALL, "SmoothPlastic", { collide = true })
		end
		for _, fz in ipairs({ -GD / 2 - 0.3, GD / 2 + 0.3 }) do
			for _, sd in ipairs({ -1, 1 }) do put("TorBogenLeiste", "trim", sd * 6.5, Y0 + 7, fz, 1, 14, 0.6, WALL2, "Concrete") end
			put("TorBogenLeiste", "trim", 0, Y0 + 18.8, fz, 1.6, 2, 0.6, WALL2, "Concrete")
			put("TorUhr", "sign", 0, Y0 + MT - 16, fz, 0.4, 7, 7, { 250, 246, 236 }, "SmoothPlastic", { shape = "Cylinder", yaw = 90 })
			put("TorUhrRand", "trim", 0, Y0 + MT - 16, fz + (fz < 0 and -0.1 or 0.1), 0.2, 8, 8, { 60, 56, 52 }, "Metal", { shape = "Cylinder", yaw = 90 })
			put("TorWappen", "trim", -9, Y0 + MT - 16, fz, 3, 4, 0.3, { 70, 110, 190 }, "SmoothPlastic")
			put("TorWappen", "trim", 9, Y0 + MT - 16, fz, 3, 4, 0.3, { 220, 220, 226 }, "SmoothPlastic")
		end
		put("TorMittelGesims", "trim", 0, Y0 + MT - 0.8, 0, 26, 1.6, GD + 1.2, WALL2, "Concrete")
		-- Zinnen auf Mittelbau und Türmen
		local function merlons(lx0, lx1, y)
			local len = lx1 - lx0
			local k = math.max(2, math.floor(len / 3.6))
			for i = 1, k do
				for _, fz in ipairs({ -GD / 2 + 1, GD / 2 - 1 }) do
					put("Zinne", "trim", lx0 + (i - 0.5) * len / k, y + 1.1, fz, len / k * 0.55, 2.2, 1.6, WALL, "Concrete", { collide = true })
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
		for _, fz in ipairs({ -GD / 2 - 0.4, GD / 2 + 0.4 }) do
			put("TorSchrift", "sign", 0, Y0 + MT - 5, fz, 12, 1.6, 0.1, { 0, 0, 0 }, "SmoothPlastic", { yaw = fz < 0 and 0 or 180, text = { s = "KARLSTOR", color = { 90, 86, 80 } } })
		end
	end

	-- U-Bahn-Abgänge (nach Foto): weißer Betonrahmen, in der Mitte eine Treppe zwischen zwei Rolltreppen, Glasgeländer, Pylon mit U-Schild;
	-- dir = +1: der Abstieg führt nach Süden (Zugang am Nordende z0), dir = -1: nach Norden (Zugang am Südende z1)
	local CONC, STEEL, UBLUE, SGREEN, WHITE = { 226, 224, 218 }, { 60, 64, 70 }, { 0, 94, 184 }, { 0, 150, 70 }, { 255, 255, 255 }
	for pi, U in ipairs(pits) do
		local len, wd = U.z1 - U.z0, U.x1 - U.x0
		local ux = (U.x0 + U.x1) / 2
		local nSteps, landing = 14, 6
		local rise, run = U.depth / nSteps, (len - landing) / nSteps
		local bottom = 1 - U.depth
		local function zAt(t) return U.dir > 0 and (U.z0 + t) or (U.z1 - t) end -- t = Abstand vom Zugang
		local lanes = { { -4.6, 3.8, { 70, 74, 80 }, "Metal" }, { 0, 4.8, { 168, 166, 160 }, "Granite" }, { 4.6, 3.8, { 70, 74, 80 }, "Metal" } }
		for k = 1, nSteps do
			local t = 1 - k * rise
			for _, ln in ipairs(lanes) do
				add("UBahnStufe", "plaza", ux + ln[1], (t - 12) / 2, zAt((k - 0.5) * run), ln[2], t + 12, run, ln[3], ln[4], { collide = true })
			end
		end
		add("UBahnPodest", "plaza", ux, (bottom - 12) / 2, zAt(len - landing / 2), wd - 2.4, bottom + 12, landing, { 150, 148, 144 }, "Granite", { collide = true })
		local slope = math.sqrt((len - landing) ^ 2 + U.depth ^ 2)
		local pitch = U.dir * math.deg(math.atan2(U.depth, len - landing))
		for _, lx in ipairs({ -7.2, -2.4, 2.4, 7.2 }) do -- Handläufe (sinken mit der Treppe)
			add("UBahnHandlauf", "plaza", ux + lx, 1 - U.depth / 2 + 2.6, zAt((len - landing) / 2), 0.3, 0.3, slope, STEEL, "Metal", { pitch = pitch })
		end
		for _, sd in ipairs({ -1, 1 }) do -- Seitenwände (Betonrahmen) bis 1,6 über das Pflaster
			add("UBahnWand", "plaza", ux + sd * (wd / 2 - 0.6), -5.2 + 0.8, (U.z0 + U.z1) / 2, 1.2, 13.6 + 1.6, len, CONC, "Concrete", { collide = true })
			for k = 0, 5 do -- Glasgeländer auf dem Rahmen
				add("UBahnGlas", "glass", ux + sd * (wd / 2 - 0.6), 3.2, U.z0 + (k + 0.5) * len / 6, 0.2, 1.8, len / 6 - 0.3, { 190, 220, 232 }, "Glass", { collide = false, transparency = 0.5 })
			end
		end
		-- Zugangsende: schräg abfallender Rahmen (Rampe aus Beton) und Pylon; Gegenende: Wand mit Portal und Schild
		local ez, wz = zAt(0), zAt(len)
		local sdir = U.dir
		local pw, ph = 10, 8
		for _, sd in ipairs({ -1, 1 }) do
			add("UBahnWand", "plaza", ux + sd * (pw / 2 + (wd - pw) / 4), -5.2 + 0.8, wz - sdir * 0.6, (wd - pw) / 2, 13.6 + 1.6, 1.2, CONC, "Concrete", { collide = true })
		end
		add("UBahnWand", "plaza", ux, (bottom + ph + 2.4) / 2, wz - sdir * 0.6, pw, 2.4 - bottom - ph, 1.2, CONC, "Concrete", { collide = true })
		add("UBahnSchild", "plaza", ux, 3.2, wz - sdir * 1.3, 14, 2.4, 0.3, UBLUE, "SmoothPlastic")
		add("Schrift", "sign", ux, 3.2, wz - sdir * 1.5, 13, 1.8, 0.2, WHITE, "SmoothPlastic", { yaw = sdir > 0 and 180 or 0, text = { s = "U  S  KARLSPLATZ", color = WHITE } })
		local sx, sz = U.x0 - 2.4, ez + sdir * -2.5
		add("UBahnPylon", "plaza", sx, 6, sz, 0.8, 10, 0.8, { 30, 32, 36 }, "Metal", { collide = true })
		add("UBahnU", "plaza", sx, 10.8, sz, 4, 4, 0.4, UBLUE, "SmoothPlastic")
		add("Schrift", "sign", sx, 10.8, sz - 0.3, 3.4, 3.4, 0.2, WHITE, "SmoothPlastic", { text = { s = "U", color = WHITE } })
		add("Schrift", "sign", sx, 10.8, sz + 0.3, 3.4, 3.4, 0.2, WHITE, "SmoothPlastic", { yaw = 180, text = { s = "U", color = WHITE } })
		-- Gang hinter dem Portal: Boden, Decke, Wände, Rückwand, Leuchten
		local g0, g1 = math.min(wz, wz + sdir * U.gang), math.max(wz, wz + sdir * U.gang)
		add("UBahnGangBoden", "plaza", ux, bottom - 0.5, (g0 + g1) / 2, pw + 2, 1, g1 - g0, { 150, 148, 144 }, "Granite", { collide = true })
		add("UBahnGangDecke", "plaza", ux, bottom + ph + 1, (g0 + g1) / 2, pw + 2, 1, g1 - g0, { 200, 200, 196 }, "Concrete", { collide = true })
		for _, sd in ipairs({ -1, 1 }) do add("UBahnGangWand", "plaza", ux + sd * (pw / 2 + 0.5), bottom + ph / 2, (g0 + g1) / 2, 1, ph, g1 - g0, { 226, 222, 210 }, "Concrete", { collide = true }) end
		add("UBahnGangWand", "plaza", ux, bottom + ph / 2, wz + sdir * (U.gang + 0.5), pw + 2, ph, 1, { 226, 222, 210 }, "Concrete", { collide = true })
		for k = 1, 3 do add("UBahnLicht", "plaza", ux, bottom + ph + 0.4, wz + sdir * k * U.gang / 4, 1.2, 0.2, 3, { 255, 250, 236 }, "Neon") end
	end

	-- Kugelleuchten und Platanen auf der Ostseite, Taxistand an der Leopoldstraße
	for z = S.z0 + 24, S.z1 - 12, 42 do
		vcyl("KugelleuchteMast", "plaza", -68, 13, z, 24, 0.8, { 150, 152, 156 }, "Metal", { collide = true })
		for _, yy in ipairs({ 19.6, 23.6 }) do add("Kugelleuchte", "plaza", -68, yy, z, 4.4, 4.4, 4.4, { 255, 250, 238 }, "Neon", { shape = "Ball", tag = "StreetLamp", attrs = { Lit = true } }) end
		stats.lamps = stats.lamps + 1
	end
	local GREENS = { { 70, 120, 60 }, { 88, 140, 70 }, { 60, 108, 58 } }
	for i, z in ipairs({ 80, 122, 164, 206, 248, 290, 332, 372 }) do
		local x = -64
		vcyl("Baumscheibe", "plaza", x, 1.05, z, 0.1, 6, { 70, 66, 60 }, "Metal")
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
