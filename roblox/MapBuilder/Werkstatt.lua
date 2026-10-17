-- Werkstatt.lua
-- Kfz-Werkstatt südlich der Tankstelle (nach Foto): flache weiße Durchfahrtshalle, an Nord- und Südseite je drei offene Rolltor-Durchfahrten (die Torpaneele mit Glasfeldern
-- sind hochgefahren und sitzen über der Öffnung), graue Blende, gelbe Werkstatt-Schilder, Torschilder, Dachschild "Service-Center" (beidseitig), Innenraum mit Hebebühnen,
-- Werkbank, Reifenstapeln und Deckenleuchten, Kundenannahme als Glasanbau im Westen (Durchgang in die Halle). Hof aus demselben Asphalt wie die Tankstelle,
-- Stellplätze, Zaun, Pylon (beidseitig). Der Name ist erfunden ("ADAN").
-- Koordinaten: x = Ost, z = Süd, y = oben; alle Teile achsparallel. Text: yaw 180 = Schrift schaut nach Süden, yaw 0 = nach Norden. Reine Geometrie.

local Werkstatt = {}

local WHITE, GREY, DARK, YELLOW = { 240, 240, 236 }, { 132, 136, 142 }, { 58, 62, 70 }, { 255, 200, 0 }
local GLASS, ASPH = { 120, 156, 178 }, { 78, 80, 86 } -- ASPH wie das Plateau der Tankstelle

function Werkstatt.plan(cfg)
	local W = cfg.werkstatt
	local parts, stats = {}, { gates = 0, texts = 0, stalls = 0, lamps = 0 }
	local function r3(v) return math.floor(v * 1000 + 0.5) / 1000 end
	local function add(name, kind, x, y, z, sx, sy, sz, color, mat, e)
		e = e or {}
		parts[#parts + 1] = {
			name = name, kind = kind, size = { r3(sx), r3(sy), r3(sz) }, pos = { r3(x), r3(y), r3(z) }, yaw = e.yaw or 0, pitch = 0, roll = e.roll,
			color = color, material = mat, collide = e.collide == true, shape = e.shape, text = e.text, tag = e.tag, lit = e.lit, attrs = e.attrs, transparency = e.transparency,
		}
	end
	local function text(name, x, y, z, sx, sy, s, color, bg, fz) -- Schrift auf einer Fläche; fz = +1 nach Süden, -1 nach Norden
		add(name, "sign", x, y, z, sx, sy, 0.1, bg or { 0, 0, 0 }, "SmoothPlastic", { yaw = fz == 1 and 180 or 0, text = { s = s, color = color } })
		stats.texts = stats.texts + 1
	end
	local Y = 1.0 -- Oberkante Boden (wie das Tankstellen-Plateau, damit man ohne Stufe hinüberfährt)
	local H = 10 -- Traufhöhe der Halle
	local OH = 7 -- lichte Höhe der Tordurchfahrten
	local bx0, bx1 = W.hall[1], W.hall[2] -- Halle von West nach Ost
	local bz0, bz1 = W.z0 + W.hallOffset, W.z0 + W.hallOffset + W.depth -- Halle von Nord nach Süd
	local zc = (bz0 + bz1) / 2
	local xc = (bx0 + bx1) / 2
	local wallH = H - 0.8 -- Wandhöhe bis unter das Dach

	-- Hof (Pflaster) und Hallenhülle: Boden, Dach, Seitenwände (West mit Durchgang zur Kundenannahme), Dachrand
	add("Hof", "plaza", (W.x0 + W.x1) / 2, Y - 0.6, (W.z0 + W.z1) / 2, W.x1 - W.x0, 1.2, W.z1 - W.z0, ASPH, "Asphalt", { collide = true })
	add("WerkstattBoden", "floor", xc, Y + 0.1, zc, bx1 - bx0, 0.2, bz1 - bz0, { 188, 188, 184 }, "Concrete", { collide = true })
	add("Halle", "roof", xc, Y + H - 0.4, zc, bx1 - bx0, 0.8, bz1 - bz0, WHITE, "SmoothPlastic", { collide = true })
	for _, z in ipairs({ bz0 + 0.2, bz1 - 0.2 }) do add("Dachrand", "trim", xc, Y + H + 0.5, z, bx1 - bx0 + 0.8, 1.0, 0.6, WHITE, "Concrete") end
	for _, x in ipairs({ bx0, bx1 }) do add("Dachrand", "trim", x, Y + H + 0.5, zc, 0.6, 1.0, bz1 - bz0 + 0.8, WHITE, "Concrete") end
	local gz0, gz1 = zc - 4, zc + 4 -- Durchgang in der Westwand, 4 hoch
	add("HalleWandWest", "body", bx0 + 0.5, Y + wallH / 2, (bz0 + gz0) / 2, 1, wallH, gz0 - bz0, WHITE, "SmoothPlastic", { collide = true })
	add("HalleWandWest", "body", bx0 + 0.5, Y + wallH / 2, (gz1 + bz1) / 2, 1, wallH, bz1 - gz1, WHITE, "SmoothPlastic", { collide = true })
	add("HalleWandWest", "body", bx0 + 0.5, Y + 4 + (wallH - 4) / 2, zc, 1, wallH - 4, gz1 - gz0, WHITE, "SmoothPlastic", { collide = true }) -- Sturz über dem Durchgang
	add("HalleWandOst", "body", bx1 - 0.5, Y + wallH / 2, zc, 1, wallH, bz1 - bz0, WHITE, "SmoothPlastic", { collide = true })
	for _, wz in ipairs({ zc - 6, zc + 6 }) do -- Fenster in der Ostwand (zur Zufahrtsgasse)
		add("SeitenFensterRahmen", "trim", bx1 + 0.15, Y + 5.2, wz, 0.4, 4.6, 7.6, DARK, "Metal")
		add("SeitenFenster", "glass", bx1 + 0.35, Y + 5.2, wz, 0.2, 3.8, 6.8, GLASS, "Glass", { tag = "HouseWindow", lit = true })
	end
	add("Sockel", "trim", bx1 + 0.1, Y + 0.5, zc, 0.4, 1.0, bz1 - bz0, { 150, 154, 158 }, "Concrete")

	-- Fassaden Süd (fz = +1) und Nord (fz = -1): Pfeiler, Sturz, Blende, drei Durchfahrten mit hochgefahrenen Glaspaneelen, Torschilder, gelbe Schilder
	local gateW, pilW = 12, 6
	local function gateX(g) return bx0 + 4 + gateW / 2 + (g - 1) * (gateW + pilW) end
	for _, fz in ipairs({ 1, -1 }) do
		local zo = fz == 1 and bz1 or bz0 -- Außenkante der Fassade
		local zw = zo - fz * 0.5 -- Mitte der Fassadenwand (1 dick)
		add("HallePfeiler", "body", bx0 + 2, Y + wallH / 2, zw, 4, wallH, 1, WHITE, "SmoothPlastic", { collide = true })
		add("HallePfeiler", "body", bx1 - 2, Y + wallH / 2, zw, 4, wallH, 1, WHITE, "SmoothPlastic", { collide = true })
		for g = 1, 2 do add("HallePfeiler", "body", gateX(g) + (gateW + pilW) / 2, Y + wallH / 2, zw, pilW, wallH, 1, WHITE, "SmoothPlastic", { collide = true }) end
		add("HalleSturz", "body", xc, Y + OH + (wallH - OH) / 2, zw, bx1 - bx0, wallH - OH, 1, WHITE, "SmoothPlastic", { collide = true })
		add("Blende", "trim", xc, Y + H - 1.3, zo + fz * 0.25, bx1 - bx0 + 0.2, 2.6, 0.5, GREY, "Concrete")
		add("Sockel", "trim", xc, Y + 0.5, zo + fz * 0.15, bx1 - bx0 + 0.2, 1.0, 0.5, { 150, 154, 158 }, "Concrete")
		for g = 1, 3 do
			local gx = gateX(g)
			add("TorRahmen", "trim", gx, Y + OH - 0.1, zo + fz * 0.2, gateW + 0.8, 0.6, 0.5, GREY, "Metal")
			for _, sd in ipairs({ -1, 1 }) do add("TorRahmen", "trim", gx + sd * (gateW / 2 + 0.2), Y + OH / 2, zo + fz * 0.2, 0.5, OH, 0.5, GREY, "Metal") end
			-- hochgefahrene Paneele über der Öffnung (Glasfeld mit Sprossen)
			add("TorGlas", "glass", gx, Y + OH + 1.5, zo + fz * 0.05, gateW - 0.8, 2.2, 0.2, GLASS, "Glass", { tag = "HouseWindow", lit = false })
			for k = 1, 3 do add("TorSprosse", "trim", gx - (gateW - 0.8) / 2 + k * (gateW - 0.8) / 4, Y + OH + 1.5, zo + fz * 0.2, 0.3, 2.2, 0.2, DARK, "Metal") end
			add("TorSprosse", "trim", gx, Y + OH + 1.5, zo + fz * 0.2, gateW - 0.8, 0.3, 0.2, DARK, "Metal")
			add("TorSchildPlatte", "sign", gx + gateW / 2 + 2.9, Y + 5, zo + fz * 0.2, 2.6, 2.4, 0.2, { 120, 124, 128 }, "SmoothPlastic")
			text("TorSchildText", gx + gateW / 2 + 2.9, Y + 5, zo + fz * 0.35, 2.2, 1.2, "Tor " .. (g + (fz == 1 and 0 or 3)), { 255, 255, 255 }, { 120, 124, 128 }, fz)
			stats.gates = stats.gates + 1
		end
		-- gelbe Werkstattschilder auf der Blende (über Tor 1 und Tor 3), "Huber" über Tor 2
		for _, g in ipairs({ 1, 3 }) do
			local gx = gateX(g)
			add("WerkstattSchild", "sign", gx, Y + H - 1.3, zo + fz * 0.6, gateW + 0.2, 3.2, 0.4, YELLOW, "SmoothPlastic")
			text("WerkstattSchrift", gx, Y + H - 0.6, zo + fz * 0.85, 9, 1.4, "ADAN", { 255, 255, 255 }, YELLOW, fz)
			text("WerkstattSchrift", gx, Y + H - 2.1, zo + fz * 0.85, 9, 1, "Werkstatt", { 255, 255, 255 }, YELLOW, fz)
		end
		text("BlendeText", gateX(2), Y + H - 1.3, zo + fz * 0.6, 10, 1.6, "Huber", { 255, 255, 255 }, GREY, fz)
		add("Vordach", "roof", xc, Y + H - 2.9, zo + fz * 1.6, bx1 - bx0 - 2, 0.3, 2.4, GREY, "Concrete") -- schmale Auskragung über der Durchfahrt
	end

	-- Dachschild "Service-Center": zwei Pfosten, graue Tafel, gelbes Feld links, auf beiden Seiten lesbar
	local sx0, sx1 = bx0 + 2, bx0 + 2 + 36
	for _, px in ipairs({ sx0 + 3, sx1 - 3 }) do add("DachschildPfosten", "trim", px, Y + H + 2, zc, 0.5, 4, 0.5, DARK, "Metal") end
	add("DachschildTafel", "sign", (sx0 + sx1) / 2, Y + H + 4.4, zc, sx1 - sx0, 3.2, 0.4, GREY, "Concrete")
	for _, fz in ipairs({ 1, -1 }) do
		add("DachschildGelb", "sign", sx0 + 4.4, Y + H + 4.4, zc + fz * 0.25, 8.4, 3.2, 0.2, YELLOW, "SmoothPlastic")
		text("DachschildGelbText", sx0 + 4.4, Y + H + 4.4, zc + fz * 0.4, 7.6, 1.8, "ADAN", { 0, 0, 0 }, YELLOW, fz)
		text("DachschildText", (sx0 + sx1) / 2 + 4.4, Y + H + 4.4, zc + fz * 0.4, 24, 1.8, "Service-Center", { 255, 255, 255 }, GREY, fz)
	end

	-- Innenraum: zwei Hebebühnen (mittlere Gasse bleibt frei), Werkbank an der Westwand, Reifenstapel, Ölfässer, Deckenleuchten
	for _, g in ipairs({ 1, 3 }) do
		local gx = gateX(g)
		for _, sd in ipairs({ -1, 1 }) do
			add("HebebuehnePfosten", "decor", gx + sd * 4, Y + 3.2, zc, 0.9, 6.4, 1.2, { 236, 190, 40 }, "Metal", { collide = true })
			add("HebebuehneArm", "decor", gx + sd * 2.4, Y + 2, zc - 4, 0.8, 0.5, 3.4, { 70, 74, 80 }, "Metal")
			add("HebebuehneArm", "decor", gx + sd * 2.4, Y + 2, zc + 4, 0.8, 0.5, 3.4, { 70, 74, 80 }, "Metal")
		end
		add("HebebuehneQuerbalken", "decor", gx, Y + 6.2, zc, 8.8, 0.6, 1.2, { 236, 190, 40 }, "Metal")
	end
	add("Werkbank", "decor", bx0 + 3, Y + 1.7, zc + 6.5, 2.4, 0.4, 5, { 150, 112, 76 }, "Wood", { collide = true })
	add("WerkbankKorpus", "decor", bx0 + 3, Y + 0.8, zc + 6.5, 2.2, 1.6, 4.6, { 80, 84, 92 }, "Metal", { collide = true })
	add("Werkzeugkasten", "decor", bx0 + 3, Y + 2.5, zc + 7.5, 1.6, 1.2, 2.2, { 200, 50, 44 }, "Metal")
	for k = 0, 3 do add("Reifen", "decor", bx1 - 3, Y + 0.7 + k * 1.3, zc - 7, 1.3, 3, 3, { 28, 28, 30 }, "SmoothPlastic", { shape = "Cylinder" }) end
	for k = 0, 2 do add("Reifen", "decor", bx1 - 3, Y + 0.7 + k * 1.3, zc - 3.6, 1.3, 3, 3, { 28, 28, 30 }, "SmoothPlastic", { shape = "Cylinder" }) end
	for _, dz in ipairs({ 4, 6.4 }) do add("Oelfass", "decor", bx1 - 3, Y + 1.7, zc + dz, 2, 3.2, 2, { 40, 70, 150 }, "Metal", { shape = "Cylinder", roll = 90 }) end
	for g = 1, 3 do
		for _, dz in ipairs({ -5, 5 }) do
			add("Deckenleuchte", "lamp", gateX(g), Y + H - 1.0, zc + dz, 6, 0.3, 0.8, { 255, 252, 236 }, "Neon", { tag = "StreetLamp", attrs = { Lit = true } })
			stats.lamps = stats.lamps + 1
		end
	end

	-- Kundenannahme: verglaster Anbau an der Westseite der Halle (Durchgang in der Westwand)
	local lx0, lx1, lz0, lz1 = W.x0 + 2, bx0, bz1 - 14, bz1 + 4
	add("AnnahmeBoden", "floor", (lx0 + lx1) / 2, Y + 0.3, (lz0 + lz1) / 2, lx1 - lx0, 0.6, lz1 - lz0, { 200, 200, 196 }, "Concrete", { collide = true })
	add("AnnahmeGlas", "glass", (lx0 + lx1) / 2, Y + 3.6, lz1, lx1 - lx0, 6, 0.3, GLASS, "Glass", { tag = "HouseWindow", lit = true })
	add("AnnahmeGlas", "glass", lx0, Y + 3.6, (lz0 + lz1) / 2, 0.3, 6, lz1 - lz0, GLASS, "Glass", { tag = "HouseWindow", lit = true })
	add("AnnahmeGlas", "glass", (lx0 + lx1) / 2, Y + 3.6, lz0, lx1 - lx0, 6, 0.3, GLASS, "Glass", { tag = "HouseWindow", lit = true })
	for k = 0, 3 do add("AnnahmePfosten", "trim", lx0 + k * (lx1 - lx0) / 3, Y + 3.6, lz1, 0.5, 6.4, 0.5, DARK, "Metal") end
	add("AnnahmeDach", "roof", (lx0 + lx1) / 2, Y + 7.1, (lz0 + lz1) / 2, lx1 - lx0 + 1, 0.6, lz1 - lz0 + 1, GREY, "Concrete")
	add("AnnahmeTuer", "trim", lx0 + (lx1 - lx0) / 2, Y + 3.2, lz1 + 0.2, 3.6, 5.6, 0.2, DARK, "Metal")
	add("AnnahmePflanze", "bush", lx0 + 3, Y + 1.6, lz0 + 4, 2.6, 2.6, 2.6, { 56, 110, 60 }, "Grass", { shape = "Ball" })
	add("AnnahmeTresen", "decor", lx0 + 4, Y + 1.5, lz1 - 5, 7, 2.4, 1.6, { 150, 112, 76 }, "Wood", { collide = true })
	add("AnnahmeSchild", "sign", lx0 + (lx1 - lx0) / 2, Y + 8.1, lz1 + 0.3, 10, 1.6, 0.3, YELLOW, "SmoothPlastic")
	text("AnnahmeSchrift", lx0 + (lx1 - lx0) / 2, Y + 8.1, lz1 + 0.55, 9.2, 1.1, "Kundenannahme", { 0, 0, 0 }, YELLOW, 1)

	-- Stellplätze am Südrand des Hofs, Fahrgassen vor den Toren bleiben frei
	local zs0, zs1 = W.z1 - 16, W.z1 - 0.5
	for x = W.x0 + 8, W.x1 - 8, 8 do add("StellplatzLinie", "dash", x, Y + 0.1, (zs0 + zs1) / 2, 0.3, 0.2, zs1 - zs0, { 240, 240, 236 }, "SmoothPlastic") end
	stats.stalls = math.floor((W.x1 - W.x0 - 16) / 8)
	add("StellplatzLinie", "dash", (W.x0 + W.x1) / 2, Y + 0.1, zs0, W.x1 - W.x0 - 16, 0.2, 0.3, { 240, 240, 236 }, "SmoothPlastic")

	-- Zaun an der Ostseite mit offenem Rolltor, Pylon an der Südostecke (beidseitig), zwei Leuchten
	local fx = W.x1 - 0.5
	for z = W.z0 + 2, W.z1 - 8, 6 do
		if z < W.gate[1] or z > W.gate[2] then
			add("ZaunPfosten", "fence", fx, Y + 2, z, 0.4, 4, 0.4, GREY, "Metal", { collide = true })
			add("ZaunFeld", "fence", fx, Y + 2, z + 3, 0.2, 3.4, 5.6, { 170, 174, 180 }, "Metal", { collide = true, transparency = 0.2 })
		end
	end
	local px, pz = W.x1 - 6, W.z1 - 1
	add("PylonMast", "trim", px, Y + 5, pz, 1.0, 10, 1.0, DARK, "Metal", { collide = true })
	add("PylonSchild", "sign", px, Y + 13, pz, 7, 5.6, 0.6, YELLOW, "SmoothPlastic")
	for _, fz in ipairs({ 1, -1 }) do
		text("PylonSchrift", px, Y + 14, pz + fz * 0.35, 6, 2.2, "ADAN", { 0, 0, 0 }, YELLOW, fz)
		text("PylonSchrift", px, Y + 11.4, pz + fz * 0.35, 6, 1.4, "Werkstatt", { 0, 0, 0 }, YELLOW, fz)
	end
	for _, lx in ipairs({ W.x0 + 22, W.x1 - 24 }) do
		local lz = bz1 + 9
		add("LampenMast", "lamp", lx, Y + 5, lz, 0.5, 10, 0.5, { 40, 56, 48 }, "Metal", { collide = true })
		add("LampenKopf", "lamp", lx, Y + 10.3, lz, 2.6, 0.6, 1.2, { 255, 226, 150 }, "Neon", { tag = "StreetLamp", attrs = { Lit = true } })
		stats.lamps = stats.lamps + 1
	end
	return { parts = parts, stats = stats }
end

return Werkstatt
