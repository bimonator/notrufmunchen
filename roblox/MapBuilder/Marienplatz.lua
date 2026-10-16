-- Marienplatz.lua
-- Marienplatz und Frauenplatz nach Fotos: Granitpflaster mit Fugen und rotbraunen Bändern, Mariensäule (Stufen, Balustrade mit Blumen,
-- Putten, roter Marmorschaft, goldene Madonna mit Strahlenkranz), U-Bahn-Abgang vor dem Rathaus (Treppe nach Norden hinab, Podest,
-- Portal mit U/S-Schildern, kurzer beleuchteter Gang), Kugelleuchten (zwei Glaskugeln am Mast), Platanen mit Baumscheiben, Sitzstufen aus Naturstein,
-- Café-Terrassen mit blauen Schirmen, Fahrräder und Bänke. Reine Geometrie; Teilefelder wie in den anderen Planern.

local Geo = require(script and script.Parent.Geo or "Geo")

local Marienplatz = {}

local GRANITE, JOINT, BAND = { 204, 198, 188 }, { 172, 166, 156 }, { 150, 96, 84 }

function Marienplatz.plan(cfg)
	local M = cfg.marienplatz
	local P, U, S = M.plaza, M.ubahn, M.saeule
	local parts = {}
	local stats = { lamps = 0, trees = 0, steps = 0, bikes = 0 }
	local function add(name, x, y, z, sx, sy, sz, color, mat, extra)
		extra = extra or {}
		parts[#parts + 1] = {
			name = name, kind = extra.kind or "plaza", size = { Geo.round3(sx), Geo.round3(sy), Geo.round3(sz) }, pos = { Geo.round3(x), Geo.round3(y), Geo.round3(z) },
			yaw = extra.yaw or 0, pitch = extra.pitch or 0, roll = extra.roll, color = color, material = mat, collide = extra.collide == true,
			shape = extra.shape, text = extra.text, tag = extra.tag, attrs = extra.attrs, transparency = extra.transparency,
		}
	end
	local function vcyl(name, x, y, z, h, d, color, mat, extra)
		extra = extra or {}
		extra.shape, extra.roll = "Cylinder", 90
		add(name, x, y, z, h, d, d, color, mat, extra)
	end
	local function rect(name, x0, z0, x1, z1, top, thick, color, mat, extra)
		if x1 - x0 > 0.01 and z1 - z0 > 0.01 then add(name, (x0 + x1) / 2, top - thick / 2, (z0 + z1) / 2, x1 - x0, thick, z1 - z0, color, mat, extra) end
	end
	local function inPit(x, z, m) return x > U.x0 - m and x < U.x1 + m and z > U.z0 - m and z < U.z1 + m end

	-- Pflaster (Oberkante 1) in vier Stücken um den U-Bahn-Abgang, Fugen alle 8 Studs, rotbraune Bänder und Randband
	local pave = { collide = true }
	rect("Pflaster", P.x0, P.z0, P.x1, U.z0, 1, 2, GRANITE, "Granite", pave)
	rect("Pflaster", P.x0, U.z1, P.x1, P.z1, 1, 2, GRANITE, "Granite", pave)
	rect("Pflaster", P.x0, U.z0, U.x0, U.z1, 1, 2, GRANITE, "Granite", pave)
	rect("Pflaster", U.x1, U.z0, P.x1, U.z1, 1, 2, GRANITE, "Granite", pave)
	local function line(name, x0, z0, x1, z1, w, color, y, h) -- Linie (Höhe h, nicht zu dünn: dünnere Linien flackern gegen den Boden) längs x (z0 == z1) oder längs z, am U-Bahn-Abgang unterbrochen
		local spans = { { 0, 1 } }
		if z0 == z1 and z0 > U.z0 and z0 < U.z1 then spans = { { 0, (U.x0 - x0) / (x1 - x0) }, { (U.x1 - x0) / (x1 - x0), 1 } } end
		if x0 == x1 and x0 > U.x0 and x0 < U.x1 then spans = { { 0, (U.z0 - z0) / (z1 - z0) }, { (U.z1 - z0) / (z1 - z0), 1 } } end
		for _, sp in ipairs(spans) do
			local ax, az, bx, bz = x0 + (x1 - x0) * sp[1], z0 + (z1 - z0) * sp[1], x0 + (x1 - x0) * sp[2], z0 + (z1 - z0) * sp[2]
			if z0 == z1 and bx - ax > 0.5 then add(name, (ax + bx) / 2, y, z0, bx - ax, h, w, color, "SmoothPlastic") end
			if x0 == x1 and bz - az > 0.5 then add(name, x0, y, (az + bz) / 2, w, h, bz - az, color, "SmoothPlastic") end
		end
	end
	for x = P.x0 + 8, P.x1 - 4, 8 do line("Fuge", x, P.z0, x, P.z1, 0.3, JOINT, 1.1, 0.2) end
	for z = P.z0 + 8, P.z1 - 4, 8 do line("Fuge", P.x0, z, P.x1, z, 0.3, JOINT, 1.1, 0.2) end
	for _, z in ipairs({ 120, 200, 280 }) do line("Band", P.x0, z, P.x1, z, 2.4, BAND, 1.15, 0.3) end
	for _, x in ipairs({ -560, -450, -380 }) do line("Band", x, P.z0, x, P.z1, 2.4, BAND, 1.15, 0.3) end
	line("Band", P.x0 + 1.2, P.z0, P.x0 + 1.2, P.z1, 2.4, BAND, 1.15, 0.3)
	line("Band", P.x1 - 1.2, P.z0, P.x1 - 1.2, P.z1, 2.4, BAND, 1.15, 0.3)
	line("Band", P.x0, P.z1 - 1.2, P.x1, P.z1 - 1.2, 2.4, BAND, 1.15, 0.3)

	-- Mariensäule: Kreis im Pflaster, achteckige Stufen, Balustrade mit Blumen, Sockel, Putten, Marmorschaft, Kapitell, goldene Madonna
	local MARBLE, RED, BRONZE, GOLD, PINK = { 214, 206, 194 }, { 150, 58, 58 }, { 64, 68, 60 }, { 230, 188, 70 }, { 222, 86, 140 }
	vcyl("SaeulenKreis", S.x, 1.15, S.z, 0.3, 46, BAND, "Granite")
	vcyl("SaeulenKreis", S.x, 1.3, S.z, 0.3, 40, GRANITE, "Granite")
	for k = 1, 3 do
		local d = 34 - 5 * k
		for _, yw in ipairs({ 0, 45 }) do add("SaeulenStufe", S.x, 1 + 0.8 * k - 0.4, S.z, d, 0.8, d, MARBLE, "Marble", { yaw = yw, collide = true }) end
	end
	local top = 3.4
	for _, sd in ipairs({ -1, 1 }) do
		add("Balustrade", S.x + sd * 9.5, top + 1.2, S.z, 0.8, 2.4, 19.8, MARBLE, "Marble", { collide = true })
		add("Balustrade", S.x, top + 1.2, S.z + sd * 9.5, 19.8, 2.4, 0.8, MARBLE, "Marble", { collide = true })
		add("Blumenbeet", S.x + sd * 7.6, top + 0.7, S.z, 2.6, 1.4, 16, PINK, "Fabric")
		add("Blumenbeet", S.x, top + 0.7, S.z + sd * 7.6, 16, 1.4, 2.6, PINK, "Fabric")
		for _, sv in ipairs({ -1, 1 }) do
			add("BalustradePfosten", S.x + sd * 9.5, top + 1.6, S.z + sv * 9.5, 1.6, 3.2, 1.6, MARBLE, "Marble", { collide = true })
			-- Putto auf kleinem Sockel an der Sockelecke
			add("PuttoSockel", S.x + sd * 5.6, top + 0.8, S.z + sv * 5.6, 2, 1.6, 2, MARBLE, "Marble", { collide = true })
			vcyl("Putto", S.x + sd * 5.6, top + 2.8, S.z + sv * 5.6, 2.4, 1.4, BRONZE, "Metal")
			add("PuttoKopf", S.x + sd * 5.6, top + 4.6, S.z + sv * 5.6, 1.2, 1.2, 1.2, BRONZE, "Metal", { shape = "Ball" })
			add("PuttoLanze", S.x + sd * 5.2, top + 4.2, S.z + sv * 5.2, 0.25, 6, 0.25, BRONZE, "Metal", { yaw = sd * sv * 45, pitch = 25 })
		end
	end
	add("Saeulensockel", S.x, top + 5, S.z, 8, 10, 8, MARBLE, "Marble", { collide = true })
	add("Saeulensockel", S.x, top + 10.4, S.z, 9.4, 0.8, 9.4, MARBLE, "Marble")
	vcyl("Saeulenfuss", S.x, top + 11.4, S.z, 1.2, 4.2, MARBLE, "Marble")
	vcyl("Mariensaeule", S.x, top + 26, S.z, 28, 3, RED, "Marble", { collide = true })
	vcyl("Kapitell", S.x, top + 40.8, S.z, 1.6, 4.4, GOLD, "Metal")
	add("Kapitell", S.x, top + 42, S.z, 5, 0.8, 5, GOLD, "Metal")
	add("Mondsichel", S.x, top + 42.8, S.z, 3.4, 0.5, 1.2, GOLD, "Metal")
	for k, d in ipairs({ 3, 2.6, 2.2, 1.8 }) do vcyl("Madonna", S.x, top + 42.8 + k * 1.1, S.z, 1.2, d, GOLD, "Metal") end
	vcyl("Madonna", S.x, top + 48.6, S.z, 1.6, 1.6, GOLD, "Metal")
	add("MadonnaKopf", S.x, top + 50, S.z, 1.3, 1.3, 1.3, GOLD, "Metal", { shape = "Ball" })
	vcyl("MadonnaKrone", S.x, top + 50.9, S.z, 0.6, 1, GOLD, "Metal")
	add("Strahlenkranz", S.x, top + 50.2, S.z - 0.7, 0.2, 3.6, 3.6, { 250, 220, 120 }, "Neon", { shape = "Cylinder", yaw = 90 })
	add("Christuskind", S.x - 1.1, top + 48.4, S.z + 0.5, 0.9, 0.9, 0.9, GOLD, "Metal", { shape = "Ball" })
	add("Zepter", S.x + 1.1, top + 48.8, S.z + 0.3, 0.2, 3, 0.2, GOLD, "Metal")
	local function bench(x, z, yaw)
		add("Bank", x, 2.1, z, 5, 0.5, 1.6, { 120, 84, 56 }, "Wood", { yaw = yaw, collide = true })
		add("BankLehne", x, 3, z, 5, 1.4, 0.3, { 120, 84, 56 }, "Wood", { yaw = yaw })
		add("BankFuss", x, 1.5, z, 4.4, 1, 1.2, { 60, 62, 66 }, "Metal", { yaw = yaw })
	end
	for _, b in ipairs({ { S.x - 22, S.z, 90 }, { S.x + 22, S.z, 90 }, { S.x, S.z + 22, 0 } }) do bench(b[1], b[2], b[3]) end

	-- U-Bahn-Abgang: 14 Stufen nach Norden hinab (Oberkanten von 1 bis 1 - depth), Podest, Seitenwände mit Geländer, Portal in der Nordwand,
	-- dahinter ein beleuchteter Gang (Terrain-Aushub in TerrainPlanner), Schilder U, S und MARIENPLATZ
	local CONC, STEEL, UBLUE, SGREEN, WHITE = { 176, 174, 168 }, { 70, 74, 80 }, { 0, 94, 184 }, { 0, 150, 70 }, { 255, 255, 255 }
	local nSteps, landing = 14, 6
	local rise, run = U.depth / nSteps, (U.z1 - U.z0 - landing) / nSteps
	local bottom, ux = 1 - U.depth, (U.x0 + U.x1) / 2
	local inner = U.x1 - U.x0 - 2.4
	for k = 1, nSteps do
		local t = 1 - k * rise
		add("UBahnStufe", ux, (t - 12) / 2, U.z1 - (k - 0.5) * run, inner, t + 12, run, { 150, 148, 144 }, "Granite", { collide = true })
		stats.steps = stats.steps + 1
	end
	add("UBahnPodest", ux, (bottom - 12) / 2, U.z0 + landing / 2, inner, bottom + 12, landing, { 150, 148, 144 }, "Granite", { collide = true })
	for _, sd in ipairs({ -1, 1 }) do
		local wx = (sd < 0) and (U.x0 + 0.6) or (U.x1 - 0.6)
		add("UBahnWand", wx, -5.2, (U.z0 + U.z1) / 2, 1.2, 13.6, U.z1 - U.z0, CONC, "Concrete", { collide = true })
		add("UBahnHandlauf", wx - sd * 0.9, 1 - U.depth / 2 + 3, (U.z0 + landing + U.z1) / 2, 0.3, 0.3, math.sqrt((U.z1 - U.z0 - landing) ^ 2 + U.depth ^ 2), STEEL, "Metal",
			{ pitch = -math.deg(math.atan2(U.depth, U.z1 - U.z0 - landing)) })
	end
	-- Nordwand mit Portal (12 breit, 8 hoch) und Schildern
	local pw, ph = 12, 8
	add("UBahnWand", U.x0 + (inner + 2.4 - pw) / 4, -5.2, U.z0 + 0.6, (U.x1 - U.x0 - pw) / 2, 13.6, 1.2, CONC, "Concrete", { collide = true })
	add("UBahnWand", U.x1 - (inner + 2.4 - pw) / 4, -5.2, U.z0 + 0.6, (U.x1 - U.x0 - pw) / 2, 13.6, 1.2, CONC, "Concrete", { collide = true })
	add("UBahnWand", ux, (bottom + ph + 1.6) / 2, U.z0 + 0.6, pw, 1.6 - bottom - ph, 1.2, CONC, "Concrete", { collide = true })
	add("UBahnSchild", ux, bottom + ph + 2.2, U.z0 + 1.3, 16, 2.4, 0.3, UBLUE, "SmoothPlastic")
	add("Schrift", ux, bottom + ph + 2.2, U.z0 + 1.5, 15, 1.8, 0.2, WHITE, "SmoothPlastic", { kind = "text", yaw = 180, text = { s = "U  S  MARIENPLATZ", color = WHITE } })
	-- Geländer oben an West-, Ost- und Nordkante (Süden ist der Zugang)
	for _, e in ipairs({ { U.x0 + 0.6, U.z0, U.x0 + 0.6, U.z1 }, { U.x1 - 0.6, U.z0, U.x1 - 0.6, U.z1 }, { U.x0, U.z0 + 0.6, U.x1, U.z0 + 0.6 } }) do
		local len = math.max(e[3] - e[1], e[4] - e[2])
		local alongX = e[3] - e[1] > 0.1
		add("Gelaender", (e[1] + e[3]) / 2, 4.2, (e[2] + e[4]) / 2, alongX and len or 0.3, 0.3, alongX and 0.3 or len, STEEL, "Metal", { collide = true })
		for k = 0, math.floor(len / 4) do
			local px, pz = alongX and (e[1] + k * len / math.floor(len / 4)) or e[1], alongX and e[2] or (e[2] + k * len / math.floor(len / 4))
			add("GelaenderPfosten", px, 2.6, pz, 0.3, 3.2, 0.3, STEEL, "Metal", { collide = true })
		end
	end
	-- Pylon mit U- und S-Schild am Zugang (Südwestecke)
	local sx, sz = U.x0 - 3, U.z1 + 2
	add("UBahnPylon", sx, 6, sz, 0.8, 10, 0.8, STEEL, "Metal", { collide = true })
	add("UBahnU", sx, 10.4, sz, 4, 4, 0.4, UBLUE, "SmoothPlastic")
	add("Schrift", sx, 10.4, sz + 0.3, 3.4, 3.4, 0.2, WHITE, "SmoothPlastic", { kind = "text", yaw = 180, text = { s = "U", color = WHITE } })
	add("UBahnS", sx, 5.6, sz, 0.4, 4, 4, SGREEN, "SmoothPlastic", { shape = "Cylinder", yaw = 90 })
	add("Schrift", sx, 5.6, sz + 0.3, 2.8, 2.8, 0.2, WHITE, "SmoothPlastic", { kind = "text", yaw = 180, text = { s = "S", color = WHITE } })
	-- Gang hinter dem Portal: Boden, Decke, Wände, Rückwand mit Fahrplan, drei Deckenleuchten
	local g0, g1 = U.z0 - U.gang, U.z0
	rect("UBahnGangBoden", ux - pw / 2 - 1, g0, ux + pw / 2 + 1, g1, bottom, 1, { 150, 148, 144 }, "Granite", { collide = true })
	rect("UBahnGangDecke", ux - pw / 2 - 1, g0, ux + pw / 2 + 1, g1, bottom + ph + 1, 1, { 200, 200, 196 }, "Concrete", { collide = true })
	for _, sd in ipairs({ -1, 1 }) do add("UBahnGangWand", ux + sd * (pw / 2 + 0.5), bottom + ph / 2, (g0 + g1) / 2, 1, ph, U.gang, { 226, 222, 210 }, "Concrete", { collide = true }) end
	add("UBahnGangWand", ux, bottom + ph / 2, g0 - 0.5, pw + 2, ph, 1, { 226, 222, 210 }, "Concrete", { collide = true })
	add("Fahrplan", ux, bottom + 4.5, g0 + 0.1, 6, 3, 0.2, { 30, 34, 40 }, "SmoothPlastic")
	add("Schrift", ux, bottom + 4.5, g0 + 0.3, 5.6, 1.4, 0.2, { 255, 200, 60 }, "SmoothPlastic", { kind = "text", yaw = 180, text = { s = "U3 U6  S1-S8", color = { 255, 200, 60 } } })
	for k = 1, 3 do add("UBahnLicht", ux, bottom + ph + 0.4, g0 + k * U.gang / 4, 1.2, 0.2, 3, { 255, 250, 236 }, "Neon") end

	-- Kugelleuchten: Mast mit zwei gestapelten Glaskugeln (Tag StreetLamp)
	local lamps = {}
	for x = -620, -380, 48 do lamps[#lamps + 1] = { x, 182 } end
	for _, x in ipairs({ -340, -230 }) do lamps[#lamps + 1] = { x, 116 } end
	for x = -620, -230, 65 do lamps[#lamps + 1] = { x, 262 } end
	for _, l in ipairs(lamps) do
		vcyl("KugelleuchteMast", l[1], 12, l[2], 22, 0.8, { 150, 152, 156 }, "Metal", { collide = true })
		for _, yy in ipairs({ 18.6, 22.6 }) do add("Kugelleuchte", l[1], yy, l[2], 4.4, 4.4, 4.4, { 255, 250, 238 }, "Neon", { shape = "Ball", tag = "StreetLamp", attrs = { Lit = true } }) end
		vcyl("KugelleuchteKappe", l[1], 25, l[2], 0.6, 1.2, { 150, 152, 156 }, "Metal")
		stats.lamps = stats.lamps + 1
	end
	-- Platanen mit Baumscheibe und gefleckter heller Rinde
	local trees = { { -606, 214 }, { -572, 238 }, { -538, 214 }, { -504, 240 }, { -470, 214 }, { -560, 300 }, { -330, 300 }, { -236, 222 } }
	local GREENS = { { 70, 120, 60 }, { 88, 140, 70 }, { 60, 108, 58 } }
	for i, t in ipairs(trees) do
		vcyl("Baumscheibe", t[1], 1.15, t[2], 0.3, 6, { 70, 66, 60 }, "Metal")
		vcyl("PlataneStamm", t[1], 7, t[2], 12, 2.2, { 150, 138, 116 }, "Wood", { collide = true })
		add("PlataneKrone", t[1], 18, t[2], 17, 15, 17, GREENS[i % 3 + 1], "Grass", { shape = "Ball" })
		add("PlataneKrone", t[1] + 4, 15.5, t[2] - 3, 12, 11, 12, GREENS[(i + 1) % 3 + 1], "Grass", { shape = "Ball" })
		add("PlataneKrone", t[1] - 4, 15, t[2] + 3, 12, 10, 12, GREENS[(i + 2) % 3 + 1], "Grass", { shape = "Ball" })
		stats.trees = stats.trees + 1
	end
	-- Sitzstufen aus Naturstein unter den Platanen (drei Stufen, steigen nach Norden an)
	for k = 1, 3 do add("Sitzstufe", -555, (0.9 * k + 1) / 2, 254 - (k - 0.5) * 4, 90, 0.9 * k + 1, 4, { 128, 124, 116 }, "Granite", { collide = true }) end
	-- Café-Terrassen mit blauen Schirmen (Westrand und Ostrand)
	for _, c in ipairs({ { -612, 300 }, { -245, 290 } }) do
		for i = 0, 2 do
			for j = 0, 1 do
				local tx, tz = c[1] + j * 12, c[2] - 10 + i * 10
				vcyl("CafeTisch", tx, 3.4, tz, 0.3, 3, { 240, 238, 230 }, "SmoothPlastic", { collide = true })
				vcyl("CafeTischFuss", tx, 2.2, tz, 2.2, 0.4, { 50, 54, 58 }, "Metal")
				for _, sd in ipairs({ -1, 1 }) do add("CafeStuhl", tx + sd * 2.4, 2.5, tz, 1.4, 0.4, 1.4, { 40, 44, 52 }, "Metal", { collide = true }) end
			end
			vcyl("CafeSchirmStange", c[1] + 6, 5.6, c[2] - 10 + i * 10, 9.2, 0.3, { 200, 200, 196 }, "Metal")
			vcyl("CafeSchirm", c[1] + 6, 10.2, c[2] - 10 + i * 10, 0.4, 11, { 34, 70, 150 }, "Fabric")
		end
	end
	-- Fahrräder an den Kugelleuchten (Räder als Scheiben, Rahmen, Sattel, Lenker)
	for _, l in ipairs({ lamps[2], lamps[4], lamps[#lamps - 1] }) do
		for k = 0, 3 do
			local bx, bz = l[1] + 3 + k * 1.6, l[2] + 2
			for _, o in ipairs({ -1.4, 1.4 }) do add("Fahrradrad", bx, 2.4, bz + o, 0.15, 2.6, 2.6, { 30, 30, 32 }, "SmoothPlastic", { shape = "Cylinder", yaw = 90 }) end
			add("Fahrradrahmen", bx, 3, bz, 0.2, 0.2, 2.8, ({ { 40, 40, 44 }, { 160, 40, 40 }, { 50, 90, 150 }, { 230, 230, 226 } })[k + 1], "Metal")
			add("Fahrradsattel", bx, 3.9, bz - 0.8, 0.5, 0.2, 1, { 60, 44, 36 }, "SmoothPlastic")
			add("Fahrradlenker", bx, 4, bz + 1.3, 1.6, 0.2, 0.2, { 60, 62, 66 }, "Metal")
			stats.bikes = stats.bikes + 1
		end
	end
	return { parts = parts, stats = stats }
end

return Marienplatz
