-- Werkstatt.lua
-- Freie Kfz-Werkstatt südlich der Tankstelle (nach Foto): flache weiße Halle mit grauer Blende, drei Rolltoren mit Glasfeldern, Torschilder, Fensterachse, gelbes
-- Werkstatt-Schild und Dachschild "Service-Center", davor gepflasterter Hof mit Stellplätzen, Zaun, Pylon. Der Name ist erfunden ("ADAN").
-- Front nach Süden. Koordinaten: x = Ost, z = Süd, y = oben; alle Teile achsparallel. Text: yaw 180 = Schrift schaut nach Süden. Reine Geometrie.

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
	local function text(name, x, y, z, sx, sy, s, color, bg) -- Schrift nach Süden auf einer Fläche
		add(name, "sign", x, y, z, sx, sy, 0.1, bg or { 0, 0, 0 }, "SmoothPlastic", { yaw = 180, text = { s = s, color = color } })
		stats.texts = stats.texts + 1
	end
	local Y = 1.0 -- Oberkante Boden (wie das Tankstellen-Plateau, damit man ohne Stufe hinüberfährt)
	local H = 10 -- Traufhöhe der Halle
	local bx0, bx1 = W.hall[1], W.hall[2] -- Halle von West nach Ost
	local bz0, bz1 = W.z0 + 4, W.z0 + 4 + W.depth -- Halle von Nord nach Süd, Front bei bz1
	local zc = (bz0 + bz1) / 2

	-- Hof (Pflaster) und Halle
	add("Hof", "plaza", (W.x0 + W.x1) / 2, Y - 0.6, (W.z0 + W.z1) / 2, W.x1 - W.x0, 1.2, W.z1 - W.z0, ASPH, "Asphalt", { collide = true })
	add("Halle", "body", (bx0 + bx1) / 2, Y + H / 2, zc, bx1 - bx0, H, bz1 - bz0, WHITE, "SmoothPlastic", { collide = true })
	add("Dachrand", "trim", (bx0 + bx1) / 2, Y + H + 0.5, zc, bx1 - bx0 + 0.8, 1.0, bz1 - bz0 + 0.8, WHITE, "Concrete")
	add("Sockel", "trim", (bx0 + bx1) / 2, Y + 0.5, bz1 + 0.15, bx1 - bx0 + 0.2, 1.0, 0.5, { 150, 154, 158 }, "Concrete")

	-- Fassade: Blende über den Toren, Tore, Pfeiler, Fensterachse
	local zf = bz1 + 0.15 -- Vorderkante der Halle
	add("Blende", "trim", (bx0 + bx1) / 2, Y + H - 1.3, zf + 0.25, bx1 - bx0 + 0.2, 2.6, 0.5, GREY, "Concrete")
	local gateW, pilW = 12, 6
	for g = 1, 3 do
		local gx = bx0 + 4 + gateW / 2 + (g - 1) * (gateW + pilW)
		add("TorRahmen", "trim", gx, Y + 4.3, zf + 0.2, gateW + 0.6, 8.6, 0.4, GREY, "Metal")
		add("TorGlas", "glass", gx, Y + 5.6, zf + 0.45, gateW - 0.8, 5.6, 0.2, GLASS, "Glass", { tag = "HouseWindow", lit = false })
		add("TorSockel", "trim", gx, Y + 1.5, zf + 0.5, gateW - 0.8, 3, 0.3, { 176, 180, 184 }, "Metal")
		for k = 1, 3 do add("TorSprosse", "trim", gx - (gateW - 0.8) / 2 + k * (gateW - 0.8) / 4, Y + 5.6, zf + 0.62, 0.3, 5.6, 0.2, DARK, "Metal") end
		for k = 1, 2 do add("TorSprosse", "trim", gx, Y + 3.7 + k * 1.9, zf + 0.62, gateW - 0.8, 0.3, 0.2, DARK, "Metal") end
		add("TorSchildPlatte", "sign", gx + gateW / 2 + 2.2, Y + 5, zf + 0.2, 2.6, 2.4, 0.2, { 120, 124, 128 }, "SmoothPlastic")
		text("TorSchildText", gx + gateW / 2 + 2.2, Y + 5, zf + 0.35, 2.2, 1.2, "Tor " .. g, { 255, 255, 255 }, { 120, 124, 128 })
		stats.gates = stats.gates + 1
	end
	-- gelbe Werkstattschilder auf der Blende (über Tor 1 und Tor 3) und Blendentext dazwischen und rechts
	for _, g in ipairs({ 1, 3 }) do
		local gx = bx0 + 4 + gateW / 2 + (g - 1) * (gateW + pilW)
		add("WerkstattSchild", "sign", gx, Y + H - 1.3, zf + 0.6, gateW + 0.2, 3.2, 0.4, YELLOW, "SmoothPlastic")
		text("WerkstattSchrift", gx, Y + H - 0.6, zf + 0.85, 9, 1.4, "ADAN", { 255, 255, 255 }, YELLOW)
		text("WerkstattSchrift", gx, Y + H - 2.1, zf + 0.85, 9, 1, "Werkstatt", { 255, 255, 255 }, YELLOW)
	end
	local gx2 = bx0 + 4 + gateW / 2 + (gateW + pilW)
	text("BlendeText", gx2, Y + H - 1.3, zf + 0.6, 10, 1.6, "Huber", { 255, 255, 255 }, GREY)

	-- Dachschild "Service-Center": zwei Pfosten, graue Tafel, gelbes Feld links
	local sx0, sx1 = bx0 + 2, bx0 + 2 + 36
	for _, px in ipairs({ sx0 + 3, sx1 - 3 }) do add("DachschildPfosten", "trim", px, Y + H + 2, zc + 3, 0.5, 4, 0.5, DARK, "Metal") end
	add("DachschildTafel", "sign", (sx0 + sx1) / 2, Y + H + 4.4, zc + 3, sx1 - sx0, 3.2, 0.4, GREY, "Concrete")
	add("DachschildGelb", "sign", sx0 + 4.4, Y + H + 4.4, zc + 3.25, 8.4, 3.2, 0.2, YELLOW, "SmoothPlastic")
	text("DachschildGelbText", sx0 + 4.4, Y + H + 4.4, zc + 3.4, 7.6, 1.8, "ADAN", { 0, 0, 0 }, YELLOW)
	text("DachschildText", (sx0 + sx1) / 2 + 4.4, Y + H + 4.4, zc + 3.4, 24, 1.8, "Service-Center", { 255, 255, 255 }, GREY)

	-- Kundenannahme: verglaster Anbau an der Westseite der Halle
	local lx0, lx1, lz0, lz1 = W.x0 + 2, bx0, bz1 - 14, bz1 + 4
	add("AnnahmeBoden", "floor", (lx0 + lx1) / 2, Y + 0.3, (lz0 + lz1) / 2, lx1 - lx0, 0.6, lz1 - lz0, { 200, 200, 196 }, "Concrete", { collide = true })
	add("AnnahmeGlas", "glass", (lx0 + lx1) / 2, Y + 3.6, lz1, lx1 - lx0, 6, 0.3, GLASS, "Glass", { tag = "HouseWindow", lit = true })
	add("AnnahmeGlas", "glass", lx0, Y + 3.6, (lz0 + lz1) / 2, 0.3, 6, lz1 - lz0, GLASS, "Glass", { tag = "HouseWindow", lit = true })
	for k = 0, 3 do add("AnnahmePfosten", "trim", lx0 + k * (lx1 - lx0) / 3, Y + 3.6, lz1, 0.5, 6.4, 0.5, DARK, "Metal") end
	add("AnnahmeDach", "roof", (lx0 + lx1) / 2, Y + 7.1, (lz0 + lz1) / 2, lx1 - lx0 + 1, 0.6, lz1 - lz0 + 1, GREY, "Concrete")
	add("AnnahmeTuer", "trim", lx0 + (lx1 - lx0) / 2, Y + 3.2, lz1 + 0.2, 3.6, 5.6, 0.2, DARK, "Metal")
	add("AnnahmePflanze", "bush", lx0 + 3, Y + 1.6, lz1 - 4, 2.6, 2.6, 2.6, { 56, 110, 60 }, "Grass", { shape = "Ball" })
	add("AnnahmeSchild", "sign", lx0 + (lx1 - lx0) / 2, Y + 8.1, lz1 + 0.3, 10, 1.6, 0.3, YELLOW, "SmoothPlastic")
	text("AnnahmeSchrift", lx0 + (lx1 - lx0) / 2, Y + 8.1, lz1 + 0.55, 9.2, 1.1, "Kundenannahme", { 0, 0, 0 }, YELLOW)

	-- Stellplätze am Südrand des Hofs, Fahrgasse vor den Toren bleibt frei
	local zs0, zs1 = W.z1 - 16, W.z1 - 0.5
	for x = W.x0 + 8, W.x1 - 8, 8 do add("StellplatzLinie", "dash", x, Y + 0.1, (zs0 + zs1) / 2, 0.3, 0.2, zs1 - zs0, { 240, 240, 236 }, "SmoothPlastic") end
	stats.stalls = math.floor((W.x1 - W.x0 - 16) / 8)
	add("StellplatzLinie", "dash", (W.x0 + W.x1) / 2, Y + 0.1, zs0, W.x1 - W.x0 - 16, 0.2, 0.3, { 240, 240, 236 }, "SmoothPlastic")

	-- Zaun an der Ostseite mit offenem Rolltor, Pylon an der Südostecke, zwei Leuchten
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
	text("PylonSchrift", px, Y + 14, pz + 0.35, 6, 2.2, "ADAN", { 0, 0, 0 }, YELLOW)
	text("PylonSchrift", px, Y + 11.4, pz + 0.35, 6, 1.4, "Werkstatt", { 0, 0, 0 }, YELLOW)
	for _, lx in ipairs({ W.x0 + 22, W.x1 - 24 }) do
		local lz = bz1 + 9
		add("LampenMast", "lamp", lx, Y + 5, lz, 0.5, 10, 0.5, { 40, 56, 48 }, "Metal", { collide = true })
		add("LampenKopf", "lamp", lx, Y + 10.3, lz, 2.6, 0.6, 1.2, { 255, 226, 150 }, "Neon", { tag = "StreetLamp", attrs = { Lit = true } })
		stats.lamps = stats.lamps + 1
	end
	return { parts = parts, stats = stats }
end

return Werkstatt
