-- Landmarks.lua
-- Wahrzeichen als Teileliste (reine Geometrie): Siegestor (nach Foto: drei Bögen, Säulen, Attika mit Inschrift, Statue) und
-- Friedensengel (Säule mit goldenem Engel in einem Springbrunnenbecken). Teilefelder wie in RoadsPlanner (name, kind, size, pos, yaw, pitch, color, material, collide).

local Geo = require(script and script.Parent.Geo or "Geo")

local Landmarks = {}

local function new(parts, cx, cz)
	-- add(name, x, y, z, sx, sy, sz, color, material, extra): x, z relativ zur Mitte (cx, cz), y absolut; extra = { pitch, collide, text, transparency, shape, roll, yaw }
	return function(name, x, y, z, sx, sy, sz, color, material, extra)
		extra = extra or {}
		parts[#parts + 1] = {
			name = name, kind = extra.kind or "landmark", size = { sx, sy, sz }, pos = { Geo.round3(cx + x), Geo.round3(y), Geo.round3(cz + z) },
			yaw = extra.yaw or 0, pitch = extra.pitch or 0, roll = extra.roll, color = color, material = material, collide = extra.collide ~= false,
			text = extra.text, transparency = extra.transparency, shape = extra.shape,
		}
	end
end

-- Siegestor: Breite 64 (quer zur Achse), Tiefe 12, Höhe bis Attika 58, Statue darüber. Mitte = Ursprung, steht auf der Mittelinsel des Kreisverkehrs (siehe siegestorInsel).
-- Öffnungen: Mittelbogen 16 breit (Kämpfer 20, Scheitel 28), Seitenbögen 10 breit (Kämpfer 14, Scheitel 19).
function Landmarks.siegestor(cfg)
	local parts = {}
	local L = cfg.landmarks.siegestor
	local add = new(parts, L.x, L.z)
	local y0 = L.baseY
	local STONE, LIGHT, DARK, RELIEF = { 214, 200, 170 }, { 226, 214, 186 }, { 176, 162, 134 }, { 192, 178, 150 }
	local BRONZE, GOLD = { 92, 140, 118 }, { 226, 184, 72 }
	local D, TOP = 12, 42 -- Tiefe, Höhe der Unterkante des Gebälks
	local function pier(x0, x1, name)
		add(name, (x0 + x1) / 2, y0 + TOP / 2, 0, x1 - x0, TOP, D, STONE, "Concrete")
	end
	pier(-32, -23, "PfeilerAussen")
	pier(-13, -8, "PfeilerMitte")
	pier(8, 13, "PfeilerMitte")
	pier(23, 32, "PfeilerAussen")
	-- Bögen: senkrechte Scheiben, deren Unterkante der Halbkreis bildet
	local function arch(cx, r, spring, n, name)
		local w = 2 * r / n
		for i = 1, n do
			local xc = -r + (i - 0.5) * w
			local bottom = spring + math.sqrt(math.max(0, r * r - xc * xc))
			add(name, cx + xc, y0 + (bottom + TOP) / 2, 0, w + 0.05, TOP - bottom, D, STONE, "Concrete")
		end
	end
	arch(0, 8, 20, 8, "BogenMitte")
	arch(-18, 5, 14, 6, "BogenSeite")
	arch(18, 5, 14, 6, "BogenSeite")
	local function deco(name, x, y, z, sx, sy, sz, color, mat, extra)
		extra = extra or {}
		extra.collide = false
		add(name, x, y, z, sx, sy, sz, color, mat, extra)
	end
	local function vcyl(name, x, y, z, h, d, color, mat)
		add(name, x, y, z, h, d, d, color, mat, { shape = "Cylinder", roll = 90, collide = false })
	end
	-- Säulen (korinthisch: Fuß, Kanneluren, Halsring, Kelch mit zwei Blattkränzen, Voluten, Abakus) an Vorder- und Rückseite
	for _, sz in ipairs({ -1, 1 }) do
		local z = sz * (D / 2 + 0.8)
		for _, x in ipairs({ -27.5, -10.5, 10.5, 27.5 }) do
			add("Saeule", x, y0 + 20, z, 36, 2.4, 2.4, LIGHT, "Concrete", { shape = "Cylinder", roll = 90 })
			add("SaeuleSockel", x, y0 + 1, z, 3.8, 2, 3.8, DARK, "Concrete")
			vcyl("SaeuleFuss", x, y0 + 2.5, z, 1, 3.2, STONE, "Concrete")
			for i = 0, 5 do -- Kanneluren
				local an = math.rad(i * 60)
				deco("Kannelur", x + 1.2 * math.cos(an), y0 + 20, z + 1.2 * math.sin(an), 0.25, 33, 0.25, DARK, "Concrete")
			end
			vcyl("SaeuleHals", x, y0 + 37.6, z, 0.8, 2.8, STONE, "Concrete")
			vcyl("SaeuleKelch", x, y0 + 39, z, 2.4, 2.9, LIGHT, "Concrete")
			for i = 0, 7 do -- Akanthusblätter in zwei Kränzen
				local an = math.rad(i * 45 + (i % 2) * 22)
				deco("Akanthus", x + 1.45 * math.cos(an), y0 + 38.4 + (i % 2) * 0.8, z + 1.45 * math.sin(an), 0.8, 1.7, 0.8, DARK, "Concrete")
			end
			for _, cx in ipairs({ -1, 1 }) do
				for _, cz in ipairs({ -1, 1 }) do deco("Volute", x + cx * 1.55, y0 + 40.6, z + cz * 1.55, 0.7, 0.7, 0.7, STONE, "Concrete", { shape = "Ball" }) end
			end
			add("Abakus", x, y0 + 41.3, z, 3.8, 0.8, 3.8, STONE, "Concrete", { collide = false })
			-- Gebälkvorsprung über der Säule
			deco("GebaelkKroepfung", x, y0 + TOP + 1.7, sz * 7.2, 5.4, 3.4, 2.4, STONE, "Concrete")
		end
		-- Sockelstufen vor dem Tor
		deco("Stylobat", 0, y0 + 0.4, sz * 7.4, 68, 0.8, 2.6, DARK, "Concrete")
		deco("Stylobat", 0, y0 + 1.1, sz * 6.9, 64, 0.6, 1.6, STONE, "Concrete")
		-- Quader (Rustika) an den Pfeilern
		for _, seg in ipairs({ { -32, -23 }, { -13, -8 }, { 8, 13 }, { 23, 32 } }) do
			for _, yy in ipairs({ 5, 9, 13 }) do deco("Rustika", (seg[1] + seg[2]) / 2, y0 + yy, sz * (D / 2 + 0.1), seg[2] - seg[1] + 0.4, 0.3, 0.3, DARK, "Concrete") end
		end
		-- Kämpfergesims auf den Mittelpfeilern
		for _, x in ipairs({ -10.5, 10.5 }) do deco("Kaempfer", x, y0 + 20, sz * (D / 2 + 0.1), 6.2, 0.9, 0.9, STONE, "Concrete") end
	end
	-- Archivolten (Bogenprofile) und Schlusssteine an Vorder- und Rückseite
	local function archivolt(cx, r, spring, name)
		local R2, m = r + 1.7, 14
		local w = 2 * R2 / m
		for _, sz in ipairs({ -1, 1 }) do
			for i = 1, m do
				local xc = -R2 + (i - 0.5) * w
				local inner = (math.abs(xc) < r) and (spring + math.sqrt(r * r - xc * xc)) or spring
				local outer = spring + math.sqrt(math.max(0, R2 * R2 - xc * xc))
				if outer - inner > 0.3 then deco(name, cx + xc, y0 + (inner + outer) / 2, sz * (D / 2 + 0.25), w + 0.05, outer - inner, 0.5, LIGHT, "Concrete") end
			end
			deco("Schlussstein", cx, y0 + spring + r + 0.7, sz * (D / 2 + 0.5), 1.8, 3.4, 1, STONE, "Concrete")
		end
	end
	archivolt(0, 8, 20, "ArchivolteMitte")
	archivolt(-18, 5, 14, "ArchivolteSeite")
	archivolt(18, 5, 14, "ArchivolteSeite")
	-- Gebälk: Architrav, Fries, Zahnschnitt, Kranzgesims; Attika mit Rahmen, Eckpylonen, Reliefs
	add("Gebaelk", 0, y0 + TOP + 1.5, 0, 66, 3, D + 2, STONE, "Concrete")
	deco("Fries", 0, y0 + TOP + 2.2, -D / 2 - 1.05, 64, 1.2, 0.2, DARK, "Concrete")
	deco("Fries", 0, y0 + TOP + 2.2, D / 2 + 1.05, 64, 1.2, 0.2, DARK, "Concrete")
	add("Attika", 0, y0 + TOP + 8.5, 0, 60, 11, D, LIGHT, "Concrete")
	add("Kranz", 0, y0 + TOP + 15, 0, 66, 2, D + 2, STONE, "Concrete")
	for _, sz in ipairs({ -1, 1 }) do
		for i = 0, 35 do deco("Zahnschnitt", -31.5 + i * 1.8, y0 + TOP + 13.6, sz * (D / 2 + 1.35), 0.9, 0.9, 0.9, DARK, "Concrete") end
		deco("AttikaRahmen", 0, y0 + TOP + 5.9, sz * (D / 2 + 0.1), 56, 0.5, 0.3, DARK, "Concrete")
		deco("AttikaRahmen", 0, y0 + TOP + 11.1, sz * (D / 2 + 0.1), 56, 0.5, 0.3, DARK, "Concrete")
		for _, ex in ipairs({ -28, 28 }) do
			deco("AttikaRahmen", ex, y0 + TOP + 8.5, sz * (D / 2 + 0.1), 0.5, 5.7, 0.3, DARK, "Concrete")
			deco("AttikaEcke", ex + (ex < 0 and -1 or 1) * 1.2, y0 + TOP + 8.5, sz * (D / 2 + 0.6), 3.6, 11, 1.2, STONE, "Concrete")
		end
	end
	add("Schrift", 0, y0 + TOP + 8.5, -D / 2 - 0.15, 52, 2.4, 0.2, { 60, 56, 50 }, "SmoothPlastic",
		{ collide = false, kind = "text", text = { s = "DEM SIEGE GEWEIHT · VOM KRIEG ZERSTÖRT · ZUM FRIEDEN MAHNEND", color = { 60, 56, 50 } } })
	add("Schrift", 0, y0 + TOP + 8.5, D / 2 + 0.15, 30, 3, 0.2, { 60, 56, 50 }, "SmoothPlastic",
		{ collide = false, kind = "text", yaw = 180, text = { s = "SIEGESTOR", color = { 60, 56, 50 } } })
	-- Reliefs über den Seitenbögen: Rahmen und Figurengruppe (Krieger, Pferde)
	for _, sz in ipairs({ -1, 1 }) do
		local zr = sz * (D / 2 + 0.15)
		for _, cx in ipairs({ -18, 18 }) do
			deco("Relief", cx, y0 + 31, zr, 9, 7, 0.4, RELIEF, "Concrete")
			deco("ReliefRahmen", cx, y0 + 34.7, zr + sz * 0.1, 10, 0.6, 0.5, STONE, "Concrete")
			deco("ReliefRahmen", cx, y0 + 27.3, zr + sz * 0.1, 10, 0.6, 0.5, STONE, "Concrete")
			deco("ReliefRahmen", cx - 4.7, y0 + 31, zr + sz * 0.1, 0.6, 7, 0.5, STONE, "Concrete")
			deco("ReliefRahmen", cx + 4.7, y0 + 31, zr + sz * 0.1, 0.6, 7, 0.5, STONE, "Concrete")
			for i = 1, 4 do -- stehende Figuren
				local fx = cx - 3.4 + (i - 1) * 2.3
				deco("ReliefFigur", fx, y0 + 30.2 + (i % 2) * 0.4, zr + sz * 0.3, 0.9, 3.6 + (i % 2), 0.4, DARK, "Concrete")
				deco("ReliefKopf", fx, y0 + 32.4 + (i % 2) * 0.9, zr + sz * 0.3, 0.8, 0.8, 0.4, DARK, "Concrete", { shape = "Ball" })
			end
			deco("ReliefPferd", cx, y0 + 28.8, zr + sz * 0.3, 3, 1.3, 0.4, DARK, "Concrete")
		end
	end
	for _, sx in ipairs({ -1, 1 }) do -- Seitenflächen: Relieffeld und Pilaster
		deco("SeitenRelief", sx * 32.2, y0 + 31, 0, 0.4, 7, 8, RELIEF, "Concrete")
		deco("SeitenRahmen", sx * 32.3, y0 + 34.7, 0, 0.5, 0.6, 9, STONE, "Concrete")
		deco("SeitenRahmen", sx * 32.3, y0 + 27.3, 0, 0.5, 0.6, 9, STONE, "Concrete")
		for _, sz in ipairs({ -4, 4 }) do deco("SeitenPilaster", sx * 32.2, y0 + 20, sz, 0.5, 38, 1.4, LIGHT, "Concrete") end
	end
	-- Eckfiguren auf den Attika-Enden
	for _, sx in ipairs({ -1, 1 }) do
		deco("EckSockel", sx * 29.5, y0 + TOP + 17.6, 0, 5, 3.2, 5, STONE, "Concrete")
		deco("EckFigurRock", sx * 29.5, y0 + TOP + 21, 0, 2.4, 3.8, 2.4, BRONZE, "Metal")
		deco("EckFigurTorso", sx * 29.5, y0 + TOP + 24, 0, 2.2, 2.6, 1.6, BRONZE, "Metal")
		deco("EckFigurKopf", sx * 29.5, y0 + TOP + 26, 0, 1.4, 1.4, 1.4, BRONZE, "Metal", { shape = "Ball" })
		deco("EckFigurSpeer", sx * 29.5 + sx * 1.6, y0 + TOP + 24, 0, 0.3, 9, 0.3, { 70, 66, 60 }, "Metal")
	end
	-- Quadriga: Bavaria auf dem Wagen, gezogen von vier Löwen (Blick nach Norden, -z)
	local yt = y0 + TOP + 16
	add("StatueSockel", 0, yt + 2, 0, 24, 4, 8, STONE, "Concrete")
	deco("StatueSockelGesims", 0, yt + 4.3, 0, 25.4, 0.6, 8.8, DARK, "Concrete")
	local yp = yt + 4.6 -- Plattform
	deco("Wagen", 0, yp + 1.4, 2.4, 11, 2.8, 3.6, BRONZE, "Metal")
	deco("WagenBug", 0, yp + 2.9, 0.5, 11.4, 0.5, 0.5, GOLD, "Metal")
	deco("Deichsel", 0, yp + 1.2, -1.5, 0.5, 0.5, 4.6, { 70, 66, 60 }, "Metal")
	for _, sx in ipairs({ -6, 6 }) do deco("Wagenrad", sx, yp + 1.7, 2.6, 0.6, 3.4, 3.4, { 70, 100, 86 }, "Metal", { shape = "Cylinder" }) end
	for i = 1, 4 do
		local lx = -7.5 + (i - 1) * 5
		deco("LoeweKoerper", lx, yp + 1.6, -1.2, 2.2, 2.4, 4.4, BRONZE, "Metal")
		deco("LoeweBrust", lx, yp + 2.0, -3.2, 2.2, 2.8, 1.2, BRONZE, "Metal")
		deco("LoeweMaehne", lx, yp + 2.9, -3.7, 3, 3, 1.4, { 62, 102, 86 }, "Metal")
		deco("LoeweKopf", lx, yp + 2.6, -4.7, 1.7, 1.7, 1.6, BRONZE, "Metal")
		deco("LoeweTatze", lx - 0.6, yp + 0.5, -3.6, 0.7, 1.2, 0.7, BRONZE, "Metal")
		deco("LoeweTatze", lx + 0.6, yp + 0.5, -3.6, 0.7, 1.2, 0.7, BRONZE, "Metal")
		deco("LoeweSchwanz", lx, yp + 2.4, 1.4, 0.35, 0.35, 2.2, BRONZE, "Metal", { pitch = -20 })
	end
	local ys = yp + 2.8 -- Wagenboden der Figur
	add("StatueRock", 0, ys + 4, 2.4, 4.6, 8, 3.2, BRONZE, "Metal", { collide = false })
	deco("StatueGuertel", 0, ys + 6, 2.4, 4.9, 0.6, 3.5, GOLD, "Metal")
	add("StatueTorso", 0, ys + 10.6, 2.4, 3.8, 5.6, 2.6, BRONZE, "Metal", { collide = false })
	deco("StatueKopf", 0, ys + 14.4, 2.4, 2.1, 2.4, 2.1, BRONZE, "Metal", { shape = "Ball" })
	deco("StatueHelm", 0, ys + 15.6, 2.4, 2.4, 1.4, 2.4, GOLD, "Metal")
	deco("StatueHelmbusch", 0, ys + 17, 2.4, 0.6, 1.6, 2.2, GOLD, "Metal")
	deco("StatueLanze", -3.4, ys + 12, 2.4, 0.5, 22, 0.5, { 70, 66, 60 }, "Metal")
	deco("StatueLanzenspitze", -3.4, ys + 23.4, 2.4, 0.9, 2.2, 0.3, GOLD, "Metal", { roll = 12 })
	deco("StatueArm", -2.4, ys + 11.4, 2.4, 1.1, 4.2, 1.1, BRONZE, "Metal")
	deco("StatueSchild", 2.8, ys + 9.5, 1.0, 3.6, 3.6, 0.5, GOLD, "Metal", { shape = "Cylinder" })
	deco("StatueUmhang", 0, ys + 9.6, 3.9, 4.6, 8.4, 0.4, { 62, 102, 86 }, "Metal")
	return parts
end

-- Mittelinsel des Kreisverkehrs um das Siegestor: Rasenscheibe, Kranz aus Randsteinen, Natursteinplatte unter dem Tor.
function Landmarks.siegestorInsel(cfg)
	local parts = {}
	local L = cfg.landmarks.siegestor
	local add = new(parts, L.x, L.z)
	local R = L.islandR
	add("InselRasen", 0, 0.35, 0, 1.5, 2 * R, 2 * R, { 96, 156, 72 }, "Grass", { shape = "Cylinder", roll = 90, collide = true })
	local n = 44
	for i = 1, n do -- Randsteine auf dem Kreis (Radius R + 1,2), Oberkante 1,5
		local a = 2 * math.pi * (i - 0.5) / n
		local rr = R + 1.2
		add("InselRandstein", rr * math.cos(a), 0.65, rr * math.sin(a), 2 * math.pi * rr / n + 0.25, 1.7, 2.4, { 190, 186, 176 }, "Concrete",
			{ yaw = math.deg(math.atan2(-math.cos(a), -math.sin(a))) % 360, collide = true })
	end
	add("InselPlatte", 0, L.baseY - 0.2, 0, 80, 0.4, 30, { 206, 200, 186 }, "Concrete", { collide = true })
	return parts
end

-- Friedensengel: rundes Becken mit Wasser und Strahlen, gestufter Sockel mit Reliefs und Urnen, kannelierte Säule, korinthisches Kapitell
-- und der goldene Engel: wallendes Gewand, Flügel aus je fünf Federn, erhobener rechter Arm mit Ölzweig, linke Hand mit kleiner Nike.
-- Der Engel blickt nach Westen (zur Maximilianstraße).
function Landmarks.friedensengel(cfg)
	local parts = {}
	local L = cfg.landmarks.friedensengel
	local add = new(parts, L.x, L.z)
	local y0 = L.baseY
	local STONE, VERD, BRONZE, GOLD, WATER = { 206, 200, 186 }, { 150, 176, 166 }, { 52, 62, 58 }, { 236, 184, 44 }, { 120, 170, 210 }
	local function vcyl(name, x, y, z, h, d, color, mat, extra)
		extra = extra or {}
		add(name, x, y, z, h, d, d, color, mat, { shape = "Cylinder", roll = 90, collide = extra.collide ~= false, transparency = extra.transparency })
	end
	vcyl("Rondell", 0, y0 + 0.45, 0, 0.9, 56, STONE, "Concrete")
	local yb = y0 + 0.9
	-- Beckenrand: 24 Steinblöcke auf einem Kreis (Radius 18), tangential gedreht
	for i = 0, 23 do
		local a = math.rad(i * 15)
		local tx, tz = -math.sin(a), math.cos(a)
		add("Beckenrand", 18 * math.cos(a), yb + 1, 18 * math.sin(a), 5.2, 2, 2, STONE, "Concrete", { yaw = math.deg(math.atan2(-tz, tx)) % 360 })
	end
	vcyl("Wasser", 0, yb + 0.9, 0, 0.4, 35.6, WATER, "SmoothPlastic", { collide = false, transparency = 0.45 })
	vcyl("SockelStufe", 0, yb + 1.5, 0, 3, 23, STONE, "Concrete")
	vcyl("SockelStufe", 0, yb + 4.5, 0, 3, 17, STONE, "Concrete")
	add("SockelStufe", 0, yb + 9, 0, 11, 6, 11, STONE, "Concrete")
	add("SockelGesims", 0, yb + 12.3, 0, 12.6, 0.8, 12.6, STONE, "Concrete")
	for _, sd in ipairs({ { 0, -1, 0 }, { 0, 1, 180 }, { -1, 0, 90 }, { 1, 0, 270 } }) do -- Bronzereliefs an den vier Seiten des Sockels
		local px, pz = sd[1] * 5.65, sd[2] * 5.65
		local along = (sd[1] ~= 0)
		add("SockelRelief", px, yb + 9, pz, along and 0.3 or 7, 4, along and 7 or 0.3, BRONZE, "Metal", { collide = false })
	end
	for _, cx in ipairs({ -7.4, 7.4 }) do -- Urnen auf den Ecken der mittleren Stufe
		for _, cz in ipairs({ -7.4, 7.4 }) do
			add("Urne", cx, yb + 7.4, cz, 1.8, 2.4, 1.8, STONE, "Concrete", { collide = false })
			add("UrneKopf", cx, yb + 9, cz, 2.2, 2.2, 2.2, STONE, "Concrete", { shape = "Ball", collide = false })
		end
	end
	local ys = yb + 12.7 -- Säulenfuß
	vcyl("SaeuleFuss", 0, ys + 1.5, 0, 3, 9, STONE, "Concrete")
	vcyl("Saeule", 0, ys + 3 + 32, 0, 64, 7, VERD, "Concrete")
	for i = 0, 7 do -- Kanneluren: acht dünne Rillenstäbe rund um den Schaft
		local a = math.rad(i * 45)
		vcyl("SaeuleKannelur", 3.55 * math.cos(a), ys + 3 + 32, 3.55 * math.sin(a), 58, 0.7, { 128, 156, 146 }, "Concrete", { collide = false })
	end
	for _, dy in ipairs({ 4.5, 33, 61.5 }) do vcyl("SaeuleRing", 0, ys + dy, 0, 1.4, 7.8, STONE, "Concrete", { collide = false }) end
	local yk = ys + 3 + 64
	vcyl("Kapitell", 0, yk + 3, 0, 6, 8.4, BRONZE, "Metal")
	for i = 0, 7 do -- Akanthusblätter
		local a = math.rad(i * 45 + 22.5)
		add("KapitellBlatt", 5.2 * math.cos(a), yk + 3.4, 5.2 * math.sin(a), 2, 4.4, 2, BRONZE, "Metal", { shape = "Ball", collide = false })
	end
	add("Abakus", 0, yk + 7, 0, 11, 2, 11, BRONZE, "Metal")
	for _, cx in ipairs({ -5.2, 5.2 }) do for _, cz in ipairs({ -5.2, 5.2 }) do add("Volute", cx, yk + 6, cz, 2.2, 2.2, 2.2, BRONZE, "Metal", { shape = "Ball", collide = false }) end end
	vcyl("Trommel", 0, yk + 11, 0, 6, 6.5, BRONZE, "Metal")
	vcyl("EngelSockel", 0, yk + 14.4, 0, 0.8, 8, BRONZE, "Metal", { collide = false })
	-- Engel (Maßeinheit k = 1,9 Studs, damit er aus der Ferne als goldene Figur zu erkennen ist). Vorne ist -x, rechts (aus Sicht der Figur) ist -z.
	local ya = yk + 14.8
	local k = 1.9
	local function G(name, x, y, z, sx, sy, sz, extra) add(name, x * k, ya + y * k, z * k, sx * k, sy * k, sz * k, GOLD, "Metal", extra) end
	local function ball(name, x, y, z, d) G(name, x, y, z, d, d, d, { shape = "Ball", collide = false }) end
	local function limb(name, a, b, d) -- Zylinder von Punkt a nach Punkt b (Einheiten k)
		local dx, dy, dz = b[1] - a[1], b[2] - a[2], b[3] - a[3]
		local hz = math.sqrt(dx * dx + dz * dz)
		G(name, (a[1] + b[1]) / 2, (a[2] + b[2]) / 2, (a[3] + b[3]) / 2, math.sqrt(hz * hz + dy * dy), d, d,
			{ shape = "Cylinder", roll = math.deg(math.atan2(dy, hz)), yaw = Geo.yawOf(dx, dz), collide = false })
	end
	local function gcyl(name, y, h, d, x) G(name, x or 0, y, 0, h, d, d, { shape = "Cylinder", roll = 90, collide = false }) end
	for i = 0, 11 do -- Gewand: zwölf Scheiben, unten weit ausgestellt, zur Taille hin fließend schmaler
		local u = i / 11
		gcyl("EngelRock", 0.35 + i * 0.5, 0.75, 3.4 + 2.1 * (1 - u) ^ 1.7)
	end
	gcyl("EngelGuertel", 6.15, 0.5, 3.55)
	gcyl("EngelRumpf", 7.4, 2.3, 2.9)
	ball("EngelBrust", -0.15, 8.8, 0, 3.3)
	ball("EngelSchulter", 0, 9.3, -1.55, 1.2)
	ball("EngelSchulter", 0, 9.3, 1.55, 1.2)
	gcyl("EngelHals", 10.15, 0.9, 0.9)
	ball("EngelKopf", -0.05, 11.3, 0, 2.1)
	ball("EngelHaar", 0.4, 11.35, 0, 2.3)
	for i = 0, 7 do -- Lorbeerkranz
		local a = math.rad(i * 45)
		ball("EngelKranz", -0.05 + 1.1 * math.cos(a), 12.1, 1.1 * math.sin(a), 0.55)
	end
	-- Flügel: je fünf Federn in einem Fächer, nach hinten (+x) geneigt
	local lens = { 7, 6.6, 5.9, 5, 4 }
	for _, side in ipairs({ -1, 1 }) do
		ball("EngelFluegelAnsatz", 0.9, 9.4, side * 0.9, 1.5)
		for i, l in ipairs(lens) do
			local pd = 8 + (i - 1) * 12
			local p, r = math.rad(pd), math.rad(-12)
			local dx, dy, dz = -math.sin(r), math.cos(r) * math.cos(p), side * math.cos(r) * math.sin(p) -- Richtung der Feder (Rx(p) * Rz(r) auf die y-Achse)
			G("EngelFluegel", 0.9 + dx * l / 2, 9.4 + dy * l / 2, side * 0.9 + dz * l / 2, 0.4, l, 1.25, { pitch = side * pd, roll = -12, collide = false })
		end
	end
	-- rechter Arm erhoben mit Ölzweig
	limb("EngelArm", { 0, 9.3, -1.55 }, { -0.9, 10.0, -2.9 }, 0.85)
	limb("EngelArm", { -0.9, 10.0, -2.9 }, { -1.4, 12.0, -3.1 }, 0.75)
	ball("EngelHand", -1.4, 12.2, -3.1, 0.9)
	limb("EngelZweig", { -1.4, 12.3, -3.1 }, { -1.9, 14.9, -3.3 }, 0.22)
	for i = 0, 5 do
		local t = (i + 1) / 7
		ball("EngelBlatt", -1.4 - 0.5 * t, 12.3 + 2.6 * t, -3.1 - 0.2 * t + ((i % 2 == 0) and -0.45 or 0.45), 0.6)
	end
	-- linker Arm nach vorn, auf der Hand eine kleine Nike
	limb("EngelArm", { 0, 9.3, 1.55 }, { -0.7, 8.4, 2.4 }, 0.85)
	limb("EngelArm", { -0.7, 8.4, 2.4 }, { -2.0, 8.9, 2.5 }, 0.75)
	ball("EngelHand", -2.0, 8.9, 2.5, 0.9)
	gcyl("EngelNike", 9.7, 1.2, 0.5, -2.1) -- kleine Figur: Körper, Kopf, Flügel
	for _, sd in ipairs({ -1, 1 }) do G("EngelNikeFluegel", -1.95, 9.9, 2.5 + sd * 0.3, 0.1, 1.2, 0.5, { pitch = sd * 30, collide = false }) end
	ball("EngelNikeKopf", -2.1, 10.5, 2.5, 0.5)
	-- Wasserstrahlen am Sockel
	for _, a in ipairs({ { 4.5, 0 }, { -4.5, 0 }, { 0, 4.5 }, { 0, -4.5 } }) do
		add("Wasserstrahl", a[1], yb + 4, a[2], 0.9, 8, 0.9, { 240, 248, 255 }, "SmoothPlastic", { collide = false, transparency = 0.5 })
	end
	-- Aufgang an der Westkante der Insel: vier Stufen vom inneren Gehweg des Ovals (Oberkante 1) hinauf zur Terrasse (Oberkante 4), Wangenmauern, Plattenweg zum Rondell
	local t = cfg.terrace
	local sx0 = t.x0 - 12 - L.x
	for i = 1, 4 do
		local top = 1 + 0.75 * i
		add("TerrassenStufe", sx0 + (i - 1) * 3 + (12 - (i - 1) * 3 + 0.5) / 2, top / 2, 0, 12 - (i - 1) * 3 + 0.5, top, 24, STONE, "Concrete")
	end
	for _, sd in ipairs({ -1, 1 }) do
		add("TerrassenWange", sx0 + 6, 2.2, sd * 12.8, 12, 4.4, 1.6, STONE, "Concrete")
	end
	local pw0, pw1 = t.x0 + 0.5 - L.x, -28
	add("Plattenweg", (pw0 + pw1) / 2, 4.05, 0, pw1 - pw0, 0.2, 10, { 214, 208, 196 }, "Concrete", { collide = false })
	return parts
end

-- Ziffernblatt mit Rand, 12 Strichen, römischen Ziffern an den Viertelstunden und zwei Zeigern (10:10). face = "W", "E", "N" oder "S"
-- (Blickrichtung der Fläche). add = Teile-Erzeuger mit Koordinaten relativ zur Kirchenmitte.
local function clock(add, x, y, z, R, face)
	local WHITE, DARK, GOLD = { 246, 242, 230 }, { 36, 34, 32 }, { 214, 176, 70 }
	local nx = (face == "W") and -1 or ((face == "E") and 1 or 0)
	local nz = (face == "N") and -1 or ((face == "S") and 1 or 0)
	local onX = nx ~= 0
	local yaw = (face == "W") and 90 or ((face == "E") and 270 or ((face == "N") and 0 or 180))
	local sgn = (face == "W" or face == "S") and 1 or -1 -- Richtung "rechts" aus Sicht des Betrachters entlang z (x-Flächen) bzw. x (z-Flächen)
	if face == "N" then sgn = -1 end
	local function pos(dy, dr) return x + (onX and 0 or dr), y + dy, z + (onX and dr or 0) end
	-- Rand und Scheibe (Zylinder, Achse in Flächennormale)
	local function disc(name, dia, thick, off, color, mat)
		local ox, oy, oz = x + nx * off, y, z + nz * off
		if onX then add(name, ox, oy, oz, thick, dia, dia, color, mat, { shape = "Cylinder", collide = false })
		else add(name, ox, oy, oz, thick, dia, dia, color, mat, { shape = "Cylinder", yaw = 90, collide = false }) end
	end
	disc("UhrRand", R * 2 + 3, 0.8, 0.5, DARK, "Metal")
	disc("Uhr", R * 2, 0.8, 0.9, WHITE, "SmoothPlastic")
	local function oriented(name, dy, dr, sx, sy, sz, rot, color, off)
		local px, py, pz = pos(dy, dr)
		px, pz = px + nx * off, pz + nz * off
		if onX then add(name, px, py, pz, sx, sy, sz, color, "Metal", { pitch = rot, collide = false })
		else add(name, px, py, pz, sx, sy, sz, color, "Metal", { roll = rot, collide = false }) end
	end
	local function toRot(phi) return onX and (sgn * phi) or (-sgn * phi) end
	for i = 0, 11 do -- Striche
		local phi = math.rad(i * 30)
		local len = (i % 3 == 0) and 2.6 or 1.5
		local rr = R - 0.9 - len / 2
		if onX then oriented("Uhrstrich", rr * math.cos(phi), sgn * rr * math.sin(phi), 0.3, len, 0.45, math.deg(phi) * sgn, DARK, 1.2)
		else oriented("Uhrstrich", rr * math.cos(phi), sgn * rr * math.sin(phi), 0.45, len, 0.3, -math.deg(phi) * sgn, DARK, 1.2) end
	end
	local function hand(name, phiDeg, len, w)
		local phi = math.rad(phiDeg)
		local rr = len / 2
		if onX then oriented(name, rr * math.cos(phi), sgn * rr * math.sin(phi), 0.3, len, w, phiDeg * sgn, DARK, 1.5)
		else oriented(name, rr * math.cos(phi), sgn * rr * math.sin(phi), w, len, 0.3, -phiDeg * sgn, DARK, 1.5) end
	end
	hand("Uhrzeiger", -60, R * 0.55, 0.9) -- Stundenzeiger auf 10
	hand("Uhrzeiger", 60, R * 0.8, 0.6) -- Minutenzeiger auf 2
	local nums = { { "XII", 0 }, { "III", 90 }, { "VI", 180 }, { "IX", 270 } }
	for _, nm in ipairs(nums) do
		local phi = math.rad(nm[2])
		local rr = R - 4.4
		local px, py, pz = pos(rr * math.cos(phi), sgn * rr * math.sin(phi))
		add("Uhrziffer", px + nx * 1.2, py, pz + nz * 1.2, 3.2, 2, 0.2, DARK, "SmoothPlastic", { yaw = yaw, kind = "text", collide = false, text = { s = nm[1], color = DARK } })
	end
	add("UhrGold", x + nx * 1.7, y, z + nz * 1.7, 1.4, 1.4, 1.4, GOLD, "Metal", { shape = "Ball", collide = false })
end

-- Zwiebelhaube: 28 dünne, sich überlappende Scheiben (Schritt 1,6 Studs) folgen einer glatten Kurve (Hals, runder Bauch, geschwungene Spitze),
-- darauf Laterne, kleine Kappe, Spitze und Kreuz. Der Bauch ist die Scheibe "Kuppel", alle anderen heißen "KuppelRing".
local function onion(add, x, y, z, color)
	local GOLD = { 214, 176, 70 }
	local H = 43
	local function radius(h)
		if h <= 11 then return 19 + 10 * math.sin(math.pi / 2 * h / 11) end
		local u = (h - 11) / (H - 11)
		return 3 + 26 * math.cos(math.pi / 2 * u) ^ 2.2
	end
	for _, s in ipairs(Geo.lathe(H, function(h) return 2 * radius(h) end, 0.3, 0.5)) do
		add(s.h0 <= 11 and 11 < s.h1 and "Kuppel" or "KuppelRing", x, y + 1 + s.y, z, s.dick, s.d, s.d, color, "Metal", { shape = "Cylinder", roll = 90, collide = true })
	end
	add("Laterne", x, y + 49, z, 10, 8, 8, color, "Metal", { shape = "Cylinder", roll = 90, collide = true })
	add("Laternenkappe", x, y + 56, z, 8, 8, 8, color, "Metal", { shape = "Ball", collide = false })
	add("Spitze", x, y + 62, z, 3.4, 3.4, 3.4, GOLD, "Metal", { shape = "Ball", collide = false })
	add("Kreuz", x, y + 70, z, 1.2, 14, 1.2, GOLD, "Metal", { collide = false })
	add("Kreuz", x, y + 72, z, 6, 1.2, 1.2, GOLD, "Metal", { collide = false })
end

-- Frauenkirche (nach Fotos, nahe am Originalmaßstab von etwa 4 Studs je Meter): langes Backsteinschiff mit hohen Spitzbogenfenstern,
-- riesiges steiles Ziegeldach mit Gauben, zwei sehr hohe Türme mit Glockenstuben, Uhren und grünen Zwiebelhauben am Westende,
-- Hauptportal mit Rosette. Steht auf dem Kirchplatz.
function Landmarks.frauenkirche(cfg)
	local parts = {}
	local L = cfg.landmarks.frauenkirche
	local cxn = (L.x0 + L.x1) / 2
	local add = new(parts, cxn, L.z)
	local y0 = L.baseY
	local BRICK, BRICK2, BAND, ROOF, GREEN = { 150, 112, 88 }, { 138, 100, 78 }, { 196, 172, 142 }, { 196, 84, 48 }, { 96, 160, 140 }
	local len, hw, wallH, rise, H = L.x1 - L.x0, L.width / 2, L.wallH, L.roofRise, L.towerH
	add("Sockel", 0, y0 + 1.5, 0, len + 10, 3, 2 * hw + 10, { 150, 148, 142 }, "Concrete")
	local yb = y0 + 3
	add("Schiff", 0, yb + wallH / 2, 0, len, wallH, 2 * hw, BRICK, "Brick", { collide = true })
	add("Gesims", 0, yb + wallH + 1, 0, len + 3, 2, 2 * hw + 3, BAND, "Concrete")
	add("Sockelband", 0, yb + 2, 0, len + 2, 4, 2 * hw + 2, { 128, 120, 112 }, "Concrete")
	-- hohe Spitzbogenfenster mit Steingewände, Sohlbank und Strebepfeilern dazwischen
	local first = -len / 2 + 70
	local n = math.floor((len / 2 - 20 - first) / 22) + 1
	for i = 0, n - 1 do
		local wx = first + i * 22
		for _, sd in ipairs({ -1, 1 }) do
			local zz = sd * (hw + 0.4)
			add("FensterGewaende", wx, yb + 33, sd * (hw + 0.15), 11.4, 50, 0.4, BAND, "Concrete", { collide = false })
			add("Fenster", wx, yb + 31, zz, 8, 44, 0.8, { 50, 62, 78 }, "Glass", { collide = false, kind = "glass", tag = "HouseWindow" })
			add("FensterBogen", wx, yb + 55, zz, 6, 6, 0.8, { 50, 62, 78 }, "Glass", { collide = false, kind = "glass" })
			add("FensterSpitze", wx, yb + 60, zz, 3.4, 5, 0.8, { 50, 62, 78 }, "Glass", { collide = false, kind = "glass" })
			add("Sohlbank", wx, yb + 8.2, sd * (hw + 0.9), 12.4, 1, 1.8, BAND, "Concrete", { collide = false })
			add("Strebepfeiler", wx + 11, yb + wallH / 2, sd * (hw + 2), 4, wallH, 4, BAND, "Concrete", { collide = true })
			add("StrebepfeilerKappe", wx + 11, yb + wallH + 2, sd * (hw + 2), 5, 4, 5, { 176, 150, 124 }, "Concrete")
		end
	end
	-- Satteldach: Platten mit Überstand, Ziegelreihen, First, Gauben; Giebelstufen am Ostende mit Rosette
	local run = hw + 3
	local slope = math.sqrt(run * run + rise * rise)
	local ang = math.deg(math.atan2(rise, run))
	local ca, sa = math.cos(math.rad(ang)), math.sin(math.rad(ang))
	local roofY = yb + wallH + rise / 2 + 2
	for _, sd in ipairs({ -1, 1 }) do
		add("Dach", 0, roofY, sd * run / 2, len + 6, 1.6, slope, ROOF, "Slate", { pitch = sd * ang })
		for xr = -len / 2, len / 2, 9 do -- Ziegelreihen (dunkler, längs der Neigung)
			local off = 1.0
			add("Dachrippe", xr, roofY + off * ca, sd * run / 2 + sd * off * sa, 1, 0.5, slope - 1, { 150, 62, 38 }, "Slate", { pitch = sd * ang, collide = false })
		end
		for k = 1, 10 do -- Gauben auf halber Dachhöhe
			local gx = -len / 2 + 30 + (k - 1) * (len - 60) / 9
			local u = 0.5
			local gy = (yb + wallH + 2) + u * rise
			local gz = sd * run * (1 - u)
			add("Gaube", gx, gy + 2, gz, 6, 6, 5, { 168, 140, 116 }, "Concrete", { collide = true })
			add("GaubeFenster", gx, gy + 2, gz + sd * 2.6, 3.4, 3.8, 0.3, { 50, 62, 78 }, "Glass", { collide = false, kind = "glass" })
			add("GaubeDach", gx, gy + 5.4, gz, 7.4, 0.8, 6.4, { 120, 56, 36 }, "Slate")
		end
	end
	add("First", 0, yb + wallH + rise + 3, 0, len + 6, 1.6, 3, { 170, 70, 40 }, "Slate")
	local steps = 12
	for k = 1, steps do -- Giebelstufen an beiden Enden (im Westen steht davor die Turmfront mit Portal und Westfenster)
		for _, ex in ipairs({ -1, 1 }) do
			add("Giebel", ex * (len / 2 - 0.8), yb + wallH + (k - 0.5) * rise / steps + 2, 0, 1.6, rise / steps, 2 * hw * (1 - (k - 1) / steps), BRICK, "Brick", { collide = true })
		end
	end
	add("Chorrosette", len / 2 + 0.2, yb + wallH + 22, 0, 0.6, 18, 18, { 70, 86, 110 }, "Glass", { shape = "Cylinder", collide = false, kind = "glass" })
	-- Türme: je 48 breit, Untergeschoss aus Backstein, Glockengeschoss etwas schmaler mit Schallöffnungen, Achteck, Zwiebelhaube
	local tw, tx = 48, -len / 2 + 24
	local H1 = 110
	for _, sd in ipairs({ -1, 1 }) do
		local tz = sd * (hw - tw / 2)
		add("Turm", tx, yb + H1 / 2, tz, tw, H1, tw, BRICK2, "Brick", { collide = true })
		for _, cxx in ipairs({ -tw / 2 + 1.5, tw / 2 - 1.5 }) do
			for _, czz in ipairs({ -tw / 2 + 1.5, tw / 2 - 1.5 }) do add("TurmEcke", tx + cxx, yb + H / 2, tz + czz, 3, H, 3, BAND, "Concrete") end
		end
		for k = 1, 4 do add("TurmBand", tx, yb + k * 22, tz, tw + 1.6, 2, tw + 1.6, BAND, "Concrete") end
		add("TurmAbsatz", tx, yb + H1 + 1.5, tz, tw + 4, 3, tw + 4, BAND, "Concrete", { collide = true })
		local tw2 = 42
		add("Turm", tx, yb + H1 + 3 + (H - H1 - 3) / 2, tz, tw2, H - H1 - 3, tw2, BRICK, "Brick", { collide = true })
		for k = 1, 3 do add("TurmBand", tx, yb + H1 + 3 + k * 26, tz, tw2 + 1.6, 2, tw2 + 1.6, BAND, "Concrete") end
		for _, yy in ipairs({ 40, 80 }) do -- Fensterschlitze im Untergeschoss
			add("Turmfenster", tx - tw / 2 - 0.3, yb + yy, tz, 0.8, 18, 5, { 40, 44, 52 }, "Glass", { collide = false, kind = "glass" })
			add("Turmfenster", tx, yb + yy, tz + sd * (tw / 2 + 0.3), 5, 18, 0.8, { 40, 44, 52 }, "Glass", { collide = false, kind = "glass" })
		end
		-- Schallöffnungen im Glockengeschoss: zwei hohe Bögen je Außenseite
		local by = yb + H - 26
		for _, o in ipairs({ -8, 8 }) do
			add("Schallloch", tx - tw2 / 2 - 0.3, by, tz + o, 0.8, 30, 8, { 30, 32, 38 }, "Glass", { collide = false, kind = "glass" })
			add("SchallBogen", tx - tw2 / 2 - 0.3, by + 17, tz + o, 0.8, 6, 5, { 30, 32, 38 }, "Glass", { collide = false, kind = "glass" })
			add("Schallloch", tx + o, by, tz + sd * (tw2 / 2 + 0.3), 8, 30, 0.8, { 30, 32, 38 }, "Glass", { collide = false, kind = "glass" })
			add("SchallBogen", tx + o, by + 17, tz + sd * (tw2 / 2 + 0.3), 5, 6, 0.8, { 30, 32, 38 }, "Glass", { collide = false, kind = "glass" })
		end
		clock(add, tx - tw2 / 2, yb + H - 70, tz, 11, "W")
		clock(add, tx, yb + H - 70, tz + sd * (tw2 / 2), 11, sd < 0 and "N" or "S")
		-- Achteck (zwei gegeneinander gedrehte Quadrate) als Übergang zur Haube
		local oct = 34
		add("Achteck", tx, yb + H + 11, tz, oct, 22, oct, BRICK2, "Brick", { collide = true })
		add("Achteck", tx, yb + H + 11.02, tz, oct, 22, oct, BRICK2, "Brick", { collide = true, yaw = 45 })
		add("AchteckBand", tx, yb + H + 22.5, tz, oct + 6, 1.4, oct + 6, BAND, "Concrete", { collide = true })
		for _, o in ipairs({ 0 }) do
			add("AchteckBogen", tx - oct / 2 - 0.3, yb + H + 11, tz, 0.8, 12, 5, { 30, 32, 38 }, "Glass", { collide = false, kind = "glass" })
			add("AchteckBogen", tx, yb + H + 11, tz + sd * (oct / 2 + 0.3), 5, 12, 0.8, { 30, 32, 38 }, "Glass", { collide = false, kind = "glass" })
		end
		onion(add, tx, yb + H + 23, tz, GREEN)
	end
	-- Details nach Fotos: Spitzbögen als Rechteck + 45-Grad-Raute; face "W" = Fläche quer zu x, sonst quer zu z
	local LIGHT, DEEP = { 222, 210, 190 }, { 150, 128, 108 }
	local function pointed(name, face, x, y, z, w, hgt, color, mat)
		local hh, sq = hgt - w / 2, w / math.sqrt(2)
		if face == "W" then
			add(name, x, y + hh / 2, z, 0.8, hh, w, color, mat, { collide = false })
			add(name, x, y + hh, z, 0.8, sq, sq, color, mat, { collide = false, pitch = 45 })
		else
			add(name, x, y + hh / 2, z, w, hh, 0.8, color, mat, { collide = false })
			add(name, x, y + hh, z, sq, sq, 0.8, color, mat, { collide = false, roll = 45 })
		end
	end
	-- Türme: Lisenen (helle Streifen), Maßwerkfriese (helles Band mit vier Blendbögen) und schlanke Spitzbogenfenster in zwei Reihen,
	-- jeweils an der Westseite und an der Außenseite (Nord/Süd) jedes Turms
	for _, sd in ipairs({ -1, 1 }) do
		local tz = sd * (hw - tw / 2)
		for _, st in ipairs({ { w = tw, y0 = 0, y1 = H1, friezes = { 30, 64, 98 }, wins = { 14, 44, 74 } }, { w = 42, y0 = H1 + 3, y1 = H, friezes = { H1 + 34 }, wins = { H1 + 12 } } }) do
			local wx, wz = tx - st.w / 2 - 0.4, tz + sd * (st.w / 2 + 0.4) -- Westfläche (x) und Außenfläche (z)
			for _, o in ipairs({ -st.w / 4, st.w / 4 }) do
				add("Lisene", wx, yb + (st.y0 + st.y1) / 2, tz + o, 1.2, st.y1 - st.y0, 1.8, BAND, "Concrete", { collide = false })
				add("Lisene", tx + o, yb + (st.y0 + st.y1) / 2, wz, 1.8, st.y1 - st.y0, 1.2, BAND, "Concrete", { collide = false })
			end
			for _, fy in ipairs(st.friezes) do
				add("Masswerkfries", wx - 0.2, yb + fy, tz, 0.6, 6, st.w - 2, LIGHT, "Concrete", { collide = false })
				add("Masswerkfries", tx, yb + fy, wz + sd * 0.2, st.w - 2, 6, 0.6, LIGHT, "Concrete", { collide = false })
				for k = 0, 3 do
					local o = -st.w / 2 + 1 + (k + 0.5) * (st.w - 2) / 4
					pointed("Masswerkbogen", "W", wx - 0.6, yb + fy - 2.4, tz + o, 4, 4.6, DEEP, "Concrete")
					pointed("Masswerkbogen", "Z", tx + o, yb + fy - 2.4, wz + sd * 0.6, 4, 4.6, DEEP, "Concrete")
				end
			end
			for _, wy in ipairs(st.wins) do
				for _, o in ipairs({ -st.w / 4 + 4, st.w / 4 - 4 }) do
					pointed("Turmspitzfenster", "W", wx - 0.2, yb + wy, tz + o, 3, 12, { 40, 44, 52 }, "Glass")
					pointed("Turmspitzfenster", "Z", tx + o, yb + wy, wz + sd * 0.2, 3, 12, { 40, 44, 52 }, "Glass")
				end
			end
		end
	end
	-- Steinband in halber Höhe der Langhauswände
	for _, sd in ipairs({ -1, 1 }) do add("Wandband", 0, yb + 24, sd * (hw + 0.3), len, 1.4, 0.6, BAND, "Concrete", { collide = false }) end
	-- Westportal in einer hellen Vorhalle (wie im Foto): Spitzbogen mit drei Gewänden, Holztür, Figuren, Ziergiebel mit Kreuzblume und Fialen, Stufen;
	-- darüber das hohe Westfenster
	local px = -len / 2 - 8
	add("Vorhalle", px + 4, yb + 22, 0, 8, 44, 30, LIGHT, "Concrete", { collide = true })
	pointed("PortalGewaende", "W", px - 0.3, yb, 0, 22, 34, { 232, 222, 204 }, "Concrete")
	pointed("PortalGewaende", "W", px - 0.6, yb, 0, 18, 30, { 206, 192, 170 }, "Concrete")
	pointed("PortalNische", "W", px - 0.9, yb, 0, 14, 26, { 120, 104, 88 }, "Concrete")
	pointed("Portal", "W", px - 1.2, yb, 0, 10, 20, { 56, 40, 32 }, "Wood")
	for _, o in ipairs({ -6, 6 }) do add("Portalfigur", px - 1.4, yb + 14, o, 1.4, 5, 1.6, { 236, 228, 210 }, "Concrete", { collide = false }) end
	add("Wimperg", px - 0.4, yb + 44.6, 0, 0.8, 15, 15, LIGHT, "Concrete", { pitch = 45, collide = false })
	add("Kreuzblume", px - 0.6, yb + 56.4, 0, 2.4, 2.4, 2.4, LIGHT, "Concrete", { shape = "Ball", collide = false })
	for _, o in ipairs({ -13.5, 13.5 }) do
		add("Fiale", px - 0.4, yb + 28, o, 2, 56, 2, LIGHT, "Concrete", { collide = false })
		add("FialeSpitze", px - 0.4, yb + 57.5, o, 1.6, 1.6, 1.6, LIGHT, "Concrete", { shape = "Ball", collide = false })
	end
	for i = 1, 4 do add("PortalStufe", px - 2 - i * 2, yb - 0.4 - i * 0.2, 0, 3, 0.8, 26 + i * 2, { 160, 156, 148 }, "Concrete", { collide = true }) end
	pointed("WestfensterGewaende", "W", -len / 2 - 0.3, yb + 61, 0, 15, 54, LIGHT, "Concrete")
	pointed("Westfenster", "W", -len / 2 - 0.6, yb + 63, 0, 11, 50, { 50, 62, 78 }, "Glass")
	for k = 1, 3 do add("Westfensterpfosten", -len / 2 - 0.8, yb + 83, -5.5 + k * 2.75, 0.4, 40, 0.5, LIGHT, "Concrete", { collide = false }) end
	-- verkleinern (scale) um die Kirchenmitte und den Sockel
	local sc = L.scale or 1
	if sc ~= 1 then
		for _, p in ipairs(parts) do
			p.pos = { Geo.round3(cxn + (p.pos[1] - cxn) * sc), Geo.round3(y0 + (p.pos[2] - y0) * sc), Geo.round3(L.z + (p.pos[3] - L.z) * sc) }
			p.size = { Geo.round3(p.size[1] * sc), Geo.round3(p.size[2] * sc), Geo.round3(p.size[3] * sc) }
		end
	end
	return parts
end

-- Chinesischer Turm: fünf Stockwerke aus Holz mit weit ausladenden Dächern, Säulenumgang unten, vergoldete Spitze
function Landmarks.chinesischerTurm(cfg)
	local parts = {}
	local L = cfg.landmarks.turm
	local add = new(parts, L.x, L.z)
	local y = L.baseY
	local WOOD, ROOFC, GOLD = { 142, 100, 62 }, { 66, 88, 70 }, { 214, 176, 70 }
	local function disc(name, yy, dia, h, color, mat, collide)
		add(name, 0, yy, 0, h, dia, dia, color, mat, { shape = "Cylinder", roll = 90, collide = collide })
	end
	disc("TurmSockel", y + 0.6, 24, 1.2, { 150, 148, 142 }, "Concrete", true)
	y = y + 1.2
	disc("TurmKern", y + 4, 9, 8, WOOD, "Wood", true)
	for i = 1, 8 do -- Säulenumgang
		local a = 2 * math.pi * (i - 1) / 8
		add("TurmSaeule", 6.4 * math.cos(a), y + 4, 6.4 * math.sin(a), 0.9, 8, 0.9, { 120, 80, 50 }, "Wood", { collide = true })
	end
	y = y + 8
	local tiers = { { 22, 8 }, { 18, 7 }, { 15, 6 }, { 12, 5 }, { 9, 4 } } -- Dachdurchmesser, Kerndurchmesser
	for i, t in ipairs(tiers) do
		disc("TurmDachRand", y + 0.3, t[1], 0.6, ROOFC, "Metal", true)
		disc("TurmDach", y + 1.2, t[1] - 5, 1.2, ROOFC, "Metal", true)
		y = y + 1.8
		if i < #tiers then
			disc("TurmGeschoss", y + 2.5, t[2], 5, WOOD, "Wood", true)
			disc("TurmBruestung", y + 4.6, t[2] + 1.4, 0.8, { 120, 80, 50 }, "Wood")
			y = y + 5
		end
	end
	add("TurmSpitze", 0, y + 3.5, 0, 0.7, 7, 0.7, GOLD, "Metal", { collide = false })
	add("TurmKugel", 0, y + 2, 0, 2.2, 2.2, 2.2, GOLD, "Metal", { shape = "Ball", collide = false })
	return parts
end

function Landmarks.plan(cfg)
	local parts = {}
	for _, list in ipairs({ Landmarks.siegestorInsel(cfg), Landmarks.siegestor(cfg), Landmarks.friedensengel(cfg), Landmarks.frauenkirche(cfg), Landmarks.chinesischerTurm(cfg) }) do
		for _, p in ipairs(list) do parts[#parts + 1] = p end
	end
	return { parts = parts }
end

return Landmarks
