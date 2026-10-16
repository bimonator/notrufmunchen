-- Stachus.lua
-- Der Platz am Odeonsplatz wird zum Stachus (Karlsplatz): Halbkreis aus Geschäftshäusern (Ellipse mit geraden Schenkeln), offen zur Leopoldstraße,
-- in der Westmitte das Karlstor (Mittelbau mit Spitzbogen zwischen zwei Zinnentürmen), in der Mitte der große Springbrunnen mit Strahlen und Pollern,
-- Granitpflaster, Kugelleuchten, Platanen und ein Taxistand auf den Parkbuchten der Leopoldstraße. Erdgeschoss mit Läden (auch ein Burger-Lokal),
-- Dachschrift "OSRUM" (Anspielung, kein echter Name). Reine Geometrie; Teilefelder wie in den anderen Planern.

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
	local stats = { segs = 0, shops = 0, jets = 0, merlons = 0, taxis = 0, lamps = 0, trees = 0 }
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

	-- Pflaster mit Fugen, Ringbändern um den Brunnen
	add("Pflaster", "plaza", (S.x0 + S.x1) / 2, 0, (S.z0 + S.z1) / 2, S.x1 - S.x0, 2, S.z1 - S.z0, { 204, 198, 188 }, "Granite", { collide = true })
	for x = S.x0 + 8, S.x1 - 4, 8 do add("Fuge", "plaza", x, 1.03, (S.z0 + S.z1) / 2, 0.18, 0.06, S.z1 - S.z0, { 172, 166, 156 }, "SmoothPlastic") end
	for z = S.z0 + 8, S.z1 - 4, 8 do add("Fuge", "plaza", (S.x0 + S.x1) / 2, 1.03, z, S.x1 - S.x0, 0.06, 0.18, { 172, 166, 156 }, "SmoothPlastic") end
	for i, rr in ipairs({ 62, 58, 53 }) do vcyl("Pflasterring", "plaza", cx, 1.08 + i * 0.01, cz, 0.08, 2 * rr, i == 2 and { 150, 96, 84 } or { 186, 180, 170 }, "Granite") end

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
		add("Sitzstein", "plaza", cx + (R + 13) * math.cos(a), 2.3, cz + (R + 13) * math.sin(a), 3.4, 2.6, 2.6, { 160, 156, 148 }, "Granite", { yaw = i * 23, collide = true })
	end

	-- Halbkreis-Gebäude: Mittellinie einer Ellipse (West), vorn zum Brunnen, mit geraden Schenkeln nach Osten
	local function centre(th) return cx - ac * math.sin(th), cz - bc * math.cos(th) end
	local function psiAt(th)
		local fx, fz = math.sin(th) / ac, math.cos(th) / bc
		local l = math.sqrt(fx * fx + fz * fz)
		return math.deg(math.atan2(-fx / l, -fz / l)) % 360
	end
	local samples, total = { { 0, 0 } }, 0
	do
		local px, pz = centre(0)
		for k = 1, 720 do
			local th = math.pi * k / 720
			local x, z = centre(th)
			total = total + math.sqrt((x - px) ^ 2 + (z - pz) ^ 2)
			samples[#samples + 1] = { th, total }
			px, pz = x, z
		end
	end
	local function thetaAt(s)
		for k = 2, #samples do
			if samples[k][2] >= s then
				local a, b = samples[k - 1], samples[k]
				return a[1] + (b[1] - a[1]) * (s - a[2]) / math.max(1e-9, b[2] - a[2])
			end
		end
		return math.pi
	end
	local n = S.segments
	local L = total / n
	local shopNo, roofSigns = 0, {}
	local function segment(x, z, psi, len, idx, opts)
		opts = opts or {}
		local put = frame(x, z, psi)
		local W = len + 1.4
		local tall = opts.extra or 0
		local Ht = H + tall
		stats.segs = stats.segs + 1
		put("Gebaeude", "body", 0, Y0 + Ht / 2, 0, W, Ht, D, opts.color or SAND, "SmoothPlastic", { collide = true })
		put("Sockel", "trim", 0, Y0 + 1.2, -D / 2 - 0.25, W, 2.4, 0.5, { 140, 136, 130 }, "Concrete")
		for k = 1, S.floors - 1 + (tall > 0 and 2 or 0) do put("Gesims", "trim", 0, Y0 + 14 + 12 * (k - 1), -D / 2 - 0.4, W, 0.7, 0.8, { 214, 200, 170 }, "Concrete") end
		put("Kranzgesims", "trim", 0, Y0 + Ht - 0.8, 0, W + 1.2, 1.6, D + 1.2, { 244, 236, 214 }, "Concrete")
		-- Mansarddach innen und außen
		local rise, run = 7, 4
		local ln = math.sqrt(run * run + rise * rise)
		local ang = math.deg(math.atan2(rise, run))
		local base = Y0 + Ht
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
		for k = 1, S.floors - 1 + (tall > 0 and 2 or 0) do
			local yb = Y0 + 14 + 12 * (k - 1)
			put("Fenster", "glass", 0, yb + 6, -D / 2 - 0.15, 3.8, 6.4, 0.3, rng() < 0.3 and GLASS_LIT or GLASS, "Glass", { tag = "HouseWindow", lit = false })
			put("Fensterbank", "trim", 0, yb + 2.6, -D / 2 - 0.45, 5, 0.5, 0.9, { 214, 200, 170 }, "Concrete")
			if k == 1 or k == 3 then
				put("BalkonPlatte", "balcony", 0, yb + 0.3, -D / 2 - 1.2, W - 1.2, 0.5, 2.4, { 170, 166, 158 }, "Concrete")
				put("BalkonGitter", "balcony", 0, yb + 1.9, -D / 2 - 2.3, W - 1.2, 2.4, 0.25, { 60, 60, 66 }, "Metal")
			end
			if not opts.noOuter then put("FensterAussen", "glass", 0, yb + 6, D / 2 + 0.15, 3.8, 6.4, 0.3, rng() < 0.3 and GLASS_LIT or GLASS, "Glass", { tag = "HouseWindow", lit = false }) end
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
		if not opts.noOuter then put("EGFensterAussen", "glass", 0, Y0 + 6, D / 2 + 0.15, len - 1.6, 8, 0.3, GLASS, "Glass", { tag = "HouseWindow", lit = false }) end
		if opts.endSide then -- Stirnseite des Schenkels (zur Leopoldstraße): Fenster in allen Geschossen
			for k = 1, S.floors - 1 + 2 do
				local yb = Y0 + 14 + 12 * (k - 1)
				for _, lz in ipairs({ -6, 6 }) do put("FensterStirn", "glass", opts.endSide * (W / 2 + 0.15), yb + 6, lz, 0.3, 6.4, 3.8, rng() < 0.3 and GLASS_LIT or GLASS, "Glass", { tag = "HouseWindow", lit = false }) end
			end
			put("StirnSockel", "trim", opts.endSide * (W / 2 + 0.2), Y0 + 6, 0, 0.4, 12, D - 4, { 150, 146, 140 }, "Concrete")
		end
		-- Eck-/Endturm: erhöhter Aufsatz mit gestuftem Dach und Kugel
		if tall > 0 then
			for i, w in ipairs({ 0.8, 0.55, 0.3 }) do put("Turmdach", "roof", 0, base + rise + 3 + (i - 1) * 4.4, 0, W * w, 4.4, D * w, SLATE, "Metal") end
			put("Turmkugel", "roof", 0, base + rise + 16, 0, 2.2, 2.2, 2.2, { 226, 184, 72 }, "Metal", { shape = "Ball" })
		end
	end
	local function skipGate(z, len) return math.abs(z - cz) < S.gate + len * 0.1 end
	local skipped, firstSkip, lastSkip = {}, nil, nil
	for k = 1, n do
		local _, z = centre(thetaAt((k - 0.5) * L))
		if skipGate(z, L) then
			skipped[k] = true
			firstSkip, lastSkip = firstSkip or k, k
		end
	end
	local idx = 0
	for k = 1, n do
		if not skipped[k] then
			local th = thetaAt((k - 0.5) * L)
			local x, z = centre(th)
			local ang = psiAt(th)
			idx = idx + 1
			segment(x, z, ang, L, idx, { burger = (k == 6 or k == 7), extra = (k == firstSkip - 1 or k == lastSkip + 1) and 20 or 0 })
			if k == 14 or k == n - 13 then roofSigns[#roofSigns + 1] = { x = x, z = z, psi = ang } end
		end
	end
	-- gerade Schenkel nach Osten (Nordende: Front nach Süden, Südende: Front nach Norden)
	for _, e in ipairs({ { th = 0 }, { th = math.pi } }) do
		local x0, z0 = centre(e.th)
		local psi = psiAt(e.th)
		local dir = e.th == 0 and 1 or 1
		for k = 1, S.legs do
			idx = idx + 1
			segment(x0 + (k - 0.5) * L * dir, z0, psi, L, idx, { extra = (k == S.legs) and 20 or 0, endSide = (k == S.legs) and (e.th == 0 and -1 or 1) or nil })
		end
	end
	-- Dachschrift OSRUM auf beiden Flügeln
	for _, rs in ipairs(roofSigns) do
		local put = frame(rs.x, rs.z, rs.psi)
		local base = TOP + 7.6
		for _, lx in ipairs({ -12, 12 }) do put("SchriftPfosten", "trim", lx, base + 2.4, -4, 0.8, 4.8, 0.8, { 90, 90, 96 }, "Metal") end
		put("SchriftBrett", "sign", 0, base + 7.5, -4, 34, 7, 0.8, { 176, 32, 40 }, "SmoothPlastic")
		put("SchriftOSRUM", "sign", 0, base + 7.5, -4.5, 31, 5.4, 0.2, { 0, 0, 0 }, "SmoothPlastic", { text = { s = "OSRUM", color = { 250, 244, 236 } } })
	end

	-- Karlstor: Mittelbau mit Bogendurchgang (Spitzbogen aus Scheibchen) zwischen zwei Zinnentürmen; Front (lz < 0) zum Brunnen
	do
		local gx, gz = cx - ac, cz
		local put = frame(gx, gz, 270)
		local GD = 22
		local WALL, WALL2 = { 238, 236, 228 }, { 226, 222, 210 }
		local TT, MT = 38, 28 -- Höhe Türme / Mittelbau
		for _, sd in ipairs({ -1, 1 }) do
			put("TorTurm", "body", sd * 19, Y0 + TT / 2, 0, 14, TT, GD, WALL, "SmoothPlastic", { collide = true })
			put("TorTurmGesims", "trim", sd * 19, Y0 + TT - 1, 0, 15.2, 1.4, GD + 1.2, WALL2, "Concrete")
			put("TorSeitenbogen", "trim", sd * 19, Y0 + 5, -GD / 2 - 0.15, 5, 10, 0.3, { 60, 56, 52 }, "SmoothPlastic")
			put("TorSeitenbogen", "trim", sd * 19, Y0 + 10, -GD / 2 - 0.15, 3.5, 3.5, 0.3, { 60, 56, 52 }, "SmoothPlastic", { roll = 45 })
			put("TorSeitenbogen", "trim", sd * 19, Y0 + 5, GD / 2 + 0.15, 5, 10, 0.3, { 60, 56, 52 }, "SmoothPlastic")
			put("TorSeitenbogen", "trim", sd * 19, Y0 + 10, GD / 2 + 0.15, 3.5, 3.5, 0.3, { 60, 56, 52 }, "SmoothPlastic", { roll = 45 })
			for _, wz in ipairs({ -GD / 2 - 0.15, GD / 2 + 0.15 }) do
				put("TorFenster", "glass", sd * 19, Y0 + 24, wz, 2.2, 4, 0.3, GLASS, "Glass", { tag = "HouseWindow", lit = false })
			end
		end
		for _, sd in ipairs({ -1, 1 }) do -- Pfeiler beidseits des Durchgangs (|lx| 6 bis 12)
			put("TorPfeiler", "body", sd * 9, Y0 + MT / 2, 0, 6, MT, GD, WALL, "SmoothPlastic", { collide = true })
		end
		local rr, spring, m = 6, 12, 12 -- Bogen: Halbkreis, Spitzenaufsatz durch die Raute
		local w = 2 * rr / m
		for i = 1, m do
			local xc = -rr + (i - 0.5) * w
			local bottom = spring + math.sqrt(math.max(0, rr * rr - xc * xc))
			put("TorBogen", "body", xc, Y0 + (bottom + MT) / 2, 0, w + 0.05, MT - bottom, GD, WALL, "SmoothPlastic", { collide = true })
		end
		for _, fz in ipairs({ -GD / 2 - 0.3, GD / 2 + 0.3 }) do
			put("TorBogenRahmen", "trim", 0, Y0 + spring + rr / 2 + 0.7, fz, 0.6, rr + 1.4, 0.6, WALL2, "Concrete", { shape = "Cylinder", roll = 90 }) -- Schlussstein-Zierleiste
			for _, sd in ipairs({ -1, 1 }) do put("TorBogenLeiste", "trim", sd * 6.5, Y0 + 7, fz, 1, 14, 0.6, WALL2, "Concrete") end
			put("TorBogenLeiste", "trim", 0, Y0 + 18.8, fz, 1.6, 2, 0.6, WALL2, "Concrete")
			put("TorUhr", "sign", 0, Y0 + 22.6, fz, 5, 5, 0.4, { 250, 246, 236 }, "SmoothPlastic", { shape = "Cylinder", yaw = 90 })
			put("TorUhrRand", "trim", 0, Y0 + 22.6, fz + (fz < 0 and -0.1 or 0.1), 5.8, 5.8, 0.2, { 60, 56, 52 }, "Metal", { shape = "Cylinder", yaw = 90 })
			put("TorWappen", "trim", -9, Y0 + 22.6, fz, 2.6, 3.2, 0.3, { 70, 110, 190 }, "SmoothPlastic")
			put("TorWappen", "trim", 9, Y0 + 22.6, fz, 2.6, 3.2, 0.3, { 220, 220, 226 }, "SmoothPlastic")
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
				for _, fz in ipairs({ -GD / 4, GD / 4 }) do put("Zinne", "trim", lx, y + 1.1, fz, 1.6, 2.2, 3, WALL, "Concrete", { collide = true }) stats.merlons = stats.merlons + 1 end
			end
		end
		merlons(-12, 12, Y0 + MT)
		merlons(-26, -12, Y0 + TT)
		merlons(12, 26, Y0 + TT)
		put("TorSchrift", "sign", 0, Y0 + 26.3, -GD / 2 - 0.4, 12, 1.4, 0.1, { 0, 0, 0 }, "SmoothPlastic", { text = { s = "KARLSTOR", color = { 90, 86, 80 } } })
		put("TorSchrift", "sign", 0, Y0 + 26.3, GD / 2 + 0.4, 12, 1.4, 0.1, { 0, 0, 0 }, "SmoothPlastic", { yaw = 180, text = { s = "KARLSTOR", color = { 90, 86, 80 } } })
	end

	-- Kugelleuchten und Platanen auf der Ostseite, Taxistand an der Leopoldstraße
	for z = S.z0 + 24, S.z1 - 12, 42 do
		vcyl("KugelleuchteMast", "plaza", -72, 13, z, 24, 0.8, { 150, 152, 156 }, "Metal", { collide = true })
		for _, yy in ipairs({ 19.6, 23.6 }) do add("Kugelleuchte", "plaza", -72, yy, z, 4.4, 4.4, 4.4, { 255, 250, 238 }, "Neon", { shape = "Ball", tag = "StreetLamp", attrs = { Lit = true } }) end
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
	local bx = S.taxi.x
	for k = 0, S.taxi.n - 1 do
		local z = S.taxi.z0 + S.taxi.len * (k + 0.5)
		if k ~= 2 and k ~= 5 then -- zwei Buchten frei, damit es lebendig wirkt
			local col = (k % 3 == 1) and { 40, 40, 44 } or { 238, 230, 202 }
			add("TaxiKarosserie", "vehicle", bx, 1.9, z, 4.2, 1.6, 9.4, col, "Metal", { collide = true })
			add("TaxiKabine", "vehicle", bx, 3.3, z - 0.4, 3.7, 1.4, 5, { 56, 74, 90 }, "Glass")
			add("TaxiDach", "vehicle", bx, 4.1, z - 0.4, 3.8, 0.25, 5.2, col, "Metal")
			add("TaxiSchild", "vehicle", bx, 4.6, z - 0.4, 1.5, 0.6, 0.7, { 255, 214, 60 }, "Neon")
			for _, wx in ipairs({ -2.1, 2.1 }) do
				for _, wz in ipairs({ -3, 3 }) do add("TaxiRad", "vehicle", bx + wx, 1.2, z + wz, 0.7, 1.9, 1.9, { 30, 30, 32 }, "Metal", { shape = "Cylinder" }) end
			end
			for _, lx in ipairs({ -1.4, 1.4 }) do add("TaxiLicht", "vehicle", bx + lx, 2.2, z + 4.75, 0.9, 0.5, 0.2, { 255, 246, 200 }, "Neon") end
			stats.taxis = stats.taxis + 1
		end
	end
	for _, z in ipairs({ S.taxi.z0 - 2, S.taxi.z0 + S.taxi.len * S.taxi.n + 2 }) do
		vcyl("TaxiMast", "plaza", -49, 8, z, 14, 0.5, { 130, 134, 140 }, "Metal", { collide = true })
		add("TaxiTafel", "sign", -49, 14.5, z, 0.4, 3.6, 3.6, { 30, 70, 160 }, "SmoothPlastic", { yaw = 0 })
		add("TaxiSchrift", "sign", -49.3, 14.5, z, 3.2, 1.6, 0.1, { 0, 0, 0 }, "SmoothPlastic", { yaw = 270, text = { s = "TAXI", color = { 255, 255, 255 } } })
	end
	return { parts = parts, stats = stats }
end

return Stachus
