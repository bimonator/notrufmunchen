-- Rathaus.lua
-- Neues Rathaus am Marienplatz (nach Fotos, verkleinert): neugotische Fassade mit 9 Achsen, Arkaden im Erdgeschoss, Balkone mit rosa
-- Blumenkästen, Spitzbogenfenster in drei Geschossen, zwei Erker, runde Ecktürmchen, steiles Schieferdach mit Gauben und Firstzier, Fialen,
-- Mittelturm mit Tor, Glockenspiel (zwei Figurenreihen), Uhr, Umgang, Glockenstube, Helm und Münchner Kindl. Front nach Süden (z1).
-- Teilefelder wie in den anderen Planern. Reine Geometrie.

local Geo = require(script and script.Parent.Geo or "Geo")

local Rathaus = {}

function Rathaus.plan(cfg)
	local R = cfg.marienplatz.rathaus
	local parts = {}
	local W, D = R.x1 - R.x0, R.z1 - R.z0
	local cx, zf, y0 = (R.x0 + R.x1) / 2, R.z1, 1
	local STONE, LIGHT, DARK, ROOF, GLASS = { 150, 146, 136 }, { 198, 192, 178 }, { 40, 38, 40 }, { 58, 62, 68 }, { 50, 62, 78 }
	local PINK, LEAF, GOLD = { 222, 86, 140 }, { 60, 110, 56 }, { 226, 184, 72 }
	-- u = Versatz nach Osten zur Mitte, v = Abstand vor der Fassade (positiv = nach Süden), y absolut
	local function add(name, u, y, v, sx, sy, sz, color, mat, extra)
		extra = extra or {}
		parts[#parts + 1] = {
			name = name, kind = extra.kind or "landmark", size = { Geo.round3(sx), Geo.round3(sy), Geo.round3(sz) },
			pos = { Geo.round3(cx + u), Geo.round3(y), Geo.round3(zf + v) }, yaw = extra.yaw or 0, pitch = extra.pitch or 0, roll = extra.roll,
			color = color, material = mat, collide = extra.collide == true, shape = extra.shape, tag = extra.tag, attrs = extra.attrs, lit = extra.lit,
		}
	end
	-- Spitzbogen (Rechteck + 45-Grad-Raute) in einer Fläche quer zu z (side = nil) oder quer zu x (side = true); y = Unterkante
	local function pointed(name, u, y, v, w, hgt, color, mat, side, extra)
		local hh, sq = hgt - w / 2, w / math.sqrt(2)
		extra = extra or {}
		if side then
			add(name, u, y + hh / 2, v, 0.3, hh, w, color, mat, extra)
			add(name, u, y + hh, v, 0.3, sq, sq, color, mat, { pitch = 45, kind = extra.kind })
		else
			add(name, u, y + hh / 2, v, w, hh, 0.3, color, mat, extra)
			add(name, u, y + hh, v, sq, sq, 0.3, color, mat, { roll = 45, kind = extra.kind })
		end
	end
	local function vcyl(name, u, y, v, h, d, color, mat, extra)
		extra = extra or {}
		extra.shape, extra.roll = "Cylinder", 90
		add(name, u, y, v, h, d, d, color, mat, extra)
	end
	local H = 50
	add("Body", 0, y0 + H / 2, -D / 2, W, H, D, STONE, "Concrete", { collide = true })
	add("Sockel", 0, y0 + 1, 0.3, W, 2, 0.6, { 110, 106, 100 }, "Concrete")
	for _, yy in ipairs({ 14, 26, 38, 49.5 }) do add("Gesims", 0, y0 + yy, 0.5, W + 1, 1, 1, LIGHT, "Concrete") end
	-- Achsen: Arkaden, Pfeiler, Balkone mit Blumen, je Geschoss zwei Spitzbogenfenster (Mittelachse = Turm)
	local n = 9
	local b = W / n
	for j = 0, n do add("Pfeiler", -W / 2 + j * b, y0 + H / 2, 0.6, 1.4, H, 1.2, LIGHT, "Concrete") end
	for i = 1, n do
		local u = -W / 2 + (i - 0.5) * b
		if i ~= 5 then
			pointed("ArkadeGewaende", u, y0, 0.15, 12, 13.5, LIGHT, "Concrete")
			pointed("Arkade", u, y0, 0.35, 10, 12, DARK, "SmoothPlastic")
			add("Balkon", u, y0 + 14.6, 1.6, b - 1.4, 0.8, 3.2, LIGHT, "Concrete", { collide = true })
			add("Bruestung", u, y0 + 16.2, 3, b - 1.4, 2.4, 0.5, LIGHT, "Concrete")
			add("Blumenkasten", u, y0 + 17.2, 2.4, b - 2.6, 0.9, 1.3, LEAF, "Grass")
			add("Blumen", u, y0 + 18.1, 2.4, b - 3, 1.2, 1.1, PINK, "Fabric")
			for _, fl in ipairs({ { 16.5, 8.5 }, { 28.5, 8 }, { 40.5, 7 } }) do
				for _, o in ipairs({ -b / 4, b / 4 }) do
					pointed("FensterGewaende", u + o, y0 + fl[1] - 0.6, 0.15, 4.4, fl[2] + 1.2, LIGHT, "Concrete")
					pointed("Fenster", u + o, y0 + fl[1], 0.35, 3.2, fl[2], GLASS, "Glass", nil, { kind = "glass", tag = "HouseWindow" })
				end
			end
		end
	end
	-- Erker in der zweiten und achten Achse (1. und 2. Obergeschoss)
	for _, i in ipairs({ 2, 8 }) do
		local u = -W / 2 + (i - 0.5) * b
		add("Erker", u, y0 + 27, 2, 9, 22, 4, LIGHT, "Concrete", { collide = true })
		add("ErkerFenster", u, y0 + 22, 4.1, 6, 6, 0.3, GLASS, "Glass", { kind = "glass" })
		add("ErkerFenster", u, y0 + 33, 4.1, 6, 6, 0.3, GLASS, "Glass", { kind = "glass" })
		add("ErkerDach", u, y0 + 39, 2, 10, 1, 5, ROOF, "Slate")
	end
	-- runde Ecktürmchen mit Kegelhelm
	for _, sd in ipairs({ -1, 1 }) do
		local u = sd * (W / 2 - 3)
		vcyl("Ecktuermchen", u, y0 + 38.5, 1, 47, 8, STONE, "Concrete", { collide = true })
		for _, yy in ipairs({ 27, 50 }) do vcyl("EcktuermchenBand", u, y0 + yy, 1, 1, 9, LIGHT, "Concrete") end
		for _, s in ipairs(Geo.lathe(13.5, function(h) return 8.4 * (1 - h / 15) + 0.6 end, 0.3, 0.5)) do vcyl("EcktuermchenHelm", u, y0 + 62.5 + s.y, 1, s.dick, s.d, ROOF, "Slate") end
		add("EcktuermchenKugel", u, y0 + 77.5, 1, 1.4, 1.4, 1.4, GOLD, "Metal", { shape = "Ball" })
		for k = 0, 2 do pointed("EcktuermchenFenster", u + sd * 0, y0 + 30 + k * 10, 5.1, 2, 5, GLASS, "Glass", nil, { kind = "glass" }) end
	end
	-- Schieferdach: zwei geneigte Platten, First mit Zier, Stufengiebel an den Seiten, Gauben, Fialen auf den Pfeilern
	local run, rise = D / 2, 22
	local ang = math.deg(math.atan2(rise, run))
	local slope = math.sqrt(run * run + rise * rise)
	add("Dach", 0, y0 + H + rise / 2, -run / 2, W + 2, 1.2, slope + 1, ROOF, "Slate", { pitch = ang })
	add("Dach", 0, y0 + H + rise / 2, -D + run / 2, W + 2, 1.2, slope + 1, ROOF, "Slate", { pitch = -ang })
	add("First", 0, y0 + H + rise + 0.6, -run, W + 2, 1.2, 1.6, ROOF, "Slate")
	for k = 0, 19 do add("Firstzier", -W / 2 + 3.5 + k * (W - 7) / 19, y0 + H + rise + 1.8, -run, 1.6, 1.6, 0.5, { 90, 96, 100 }, "Metal", { roll = 45 }) end
	for _, sd in ipairs({ -1, 1 }) do
		for k = 1, 8 do add("Giebel", sd * (W / 2 - 0.6), y0 + H + (k - 0.5) * rise / 8, -run, 1.2, rise / 8, D * (1 - (k - 1) / 8), STONE, "Concrete", { collide = true }) end
	end
	for i = 1, n do
		if i ~= 5 then
			local u = -W / 2 + (i - 0.5) * b
			add("Gaube", u, y0 + H + 9, -7.5, 4, 5, 4, STONE, "Concrete")
			add("GaubeFenster", u, y0 + H + 9, -5.4, 2.4, 3, 0.3, GLASS, "Glass", { kind = "glass" })
			add("GaubeDach", u, y0 + H + 12, -7.5, 4.8, 0.6, 4.8, ROOF, "Slate", { roll = 0 })
		end
	end
	for j = 0, n do
		if j ~= 4 and j ~= 5 then
			vcyl("Fiale", -W / 2 + j * b, y0 + H + 3.5, 0.8, 7, 1.4, LIGHT, "Concrete")
			add("FialeKugel", -W / 2 + j * b, y0 + H + 7.4, 0.8, 1.2, 1.2, 1.2, LIGHT, "Concrete", { shape = "Ball" })
		end
	end
	-- Seitenfassaden: je Geschoss drei Spitzbogenfenster
	for _, sd in ipairs({ -1, 1 }) do
		for _, fy in ipairs({ 16.5, 28.5, 40.5 }) do
			for k = 1, 3 do pointed("Seitenfenster", sd * (W / 2 + 0.2), y0 + fy, -D * k / 4, 3.2, 7.5, GLASS, "Glass", true, { kind = "glass", tag = "HouseWindow" }) end
		end
	end
	-- Mittelturm: Schaft mit Tor, Glockenspiel, Uhr, Umgang, Glockenstube mit Schallöffnungen, Ecktürmchen, Helm, Münchner Kindl
	local TW, TV = 26, -3 -- Breite, Mitte (Tiefe 14, ragt 4 vor die Fassade)
	add("Turm", 0, y0 + 35, TV, TW, 70, 14, STONE, "Concrete", { collide = true })
	for _, sd in ipairs({ -1, 1 }) do add("TurmLisene", sd * (TW / 2 - 0.8), y0 + 35, 4.3, 1.6, 70, 0.8, LIGHT, "Concrete") end
	for _, yy in ipairs({ 17, 28, 56 }) do add("TurmBand", 0, y0 + yy, 4.4, TW + 0.6, 1, 0.8, LIGHT, "Concrete") end
	pointed("TorGewaende", 0, y0, 4.15, 16, 19, LIGHT, "Concrete")
	pointed("Tor", 0, y0, 4.35, 12, 16, DARK, "Wood", nil, { tag = "HouseDoor" })
	for _, o in ipairs({ -4, 4 }) do pointed("TurmFenster", o, y0 + 19.5, 4.35, 3, 7, GLASS, "Glass", nil, { kind = "glass" }) end
	pointed("GlockenspielNische", 0, y0 + 29, 4.15, 16, 26, GOLD, "Metal")
	pointed("Glockenspiel", 0, y0 + 30, 4.35, 14, 24, { 30, 44, 70 }, "SmoothPlastic", nil, { tag = "Glockenspiel" })
	local FIG = { { 200, 40, 40 }, { 40, 90, 170 }, { 230, 200, 60 }, { 60, 140, 70 }, { 240, 240, 236 }, { 150, 70, 160 } }
	for t, yy in ipairs({ 32.5, 42 }) do
		add("GlockenspielBuehne", 0, y0 + yy - 0.6, 4.9, 12, 0.6, 1.6, GOLD, "Metal")
		for k = 1, 6 do
			local fu = -6 + (k - 0.5) * 2
			add("GlockenspielFigur", fu, y0 + yy + 1.3, 4.9, 1.2, 2.6, 0.9, FIG[(k + t) % #FIG + 1], "SmoothPlastic", { tag = "GlockenspielFigur" })
			add("GlockenspielKopf", fu, y0 + yy + 3, 4.9, 0.9, 0.9, 0.9, { 232, 196, 160 }, "SmoothPlastic", { shape = "Ball" })
		end
	end
	-- Uhr (10:10) über dem Glockenspiel
	add("UhrRand", 0, y0 + 63, 4.4, 0.5, 11.4, 11.4, DARK, "Metal", { shape = "Cylinder", yaw = 90 })
	add("Uhr", 0, y0 + 63, 4.65, 0.3, 10, 10, { 246, 242, 230 }, "SmoothPlastic", { shape = "Cylinder", yaw = 90 })
	for _, hd in ipairs({ { 300, 2.8 }, { 60, 4 } }) do -- Zeiger: von Süden gesehen dreht roll gegen den Uhrzeigersinn, daher negativ
		local phi = math.rad(hd[1])
		add("Uhrzeiger", (hd[2] / 2) * math.sin(phi), y0 + 63 + (hd[2] / 2) * math.cos(phi), 4.9, 0.5, hd[2], 0.3, DARK, "Metal", { roll = -hd[1] })
	end
	for k = 0, 3 do
		local phi = math.rad(k * 90)
		add("Uhrstrich", 4 * math.sin(phi), y0 + 63 + 4 * math.cos(phi), 4.9, (k % 2 == 0) and 0.4 or 1, (k % 2 == 0) and 1 or 0.4, 0.3, DARK, "Metal")
	end
	add("Umgang", 0, y0 + 70.5, TV, TW + 4, 1, 18, LIGHT, "Concrete", { collide = true })
	for _, sd in ipairs({ -1, 1 }) do
		add("Gelaender", 0, y0 + 72, TV + sd * 8.8, TW + 4, 1.6, 0.4, LIGHT, "Concrete")
		add("Gelaender", sd * (TW / 2 + 1.8), y0 + 72, TV, 0.4, 1.6, 18, LIGHT, "Concrete")
		for _, sv in ipairs({ -1, 1 }) do
			vcyl("TurmFiale", sd * (TW / 2 - 1), y0 + 77, TV + sv * 6, 12, 2.2, LIGHT, "Concrete")
			add("TurmFialeKugel", sd * (TW / 2 - 1), y0 + 83.6, TV + sv * 6, 1.6, 1.6, 1.6, GOLD, "Metal", { shape = "Ball" })
		end
	end
	add("Glockenstube", 0, y0 + 82, TV, 18, 22, 12, STONE, "Concrete", { collide = true })
	for _, o in ipairs({ -4, 4 }) do
		pointed("Schallloch", o, y0 + 76, TV + 6.15, 3.4, 12, DARK, "SmoothPlastic")
		pointed("Schallloch", o, y0 + 76, TV - 6.15, 3.4, 12, DARK, "SmoothPlastic")
	end
	for _, sd in ipairs({ -1, 1 }) do pointed("Schallloch", sd * 9.15, y0 + 76, TV, 3.4, 12, DARK, "SmoothPlastic", true) end
	add("Kranz", 0, y0 + 93.4, TV, 20, 1, 14, LIGHT, "Concrete")
	for _, s in ipairs(Geo.lathe(28.5, function(h) return 15 * (1 - h / 30.4) ^ 1.2 + 1 end, 0.3, 0.5)) do vcyl("Turmhelm", 0, y0 + 95 + s.y, TV, s.dick, s.d, ROOF, "Slate") end
	vcyl("Kindl", 0, y0 + 127, TV, 2.4, 1.2, GOLD, "Metal")
	add("KindlKopf", 0, y0 + 128.8, TV, 1, 1, 1, GOLD, "Metal", { shape = "Ball" })
	return parts
end

return Rathaus
