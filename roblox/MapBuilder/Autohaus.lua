-- Autohaus.lua
-- Autohaus auf dem Grundstück östlich der V3 (nördlich der Diagonale, südlich von Volksbank und Klinikum-Hochhaus), Front nach Westen zur V3:
-- Vorplatz mit leeren Ausstellungsflächen und Drehtellern (Fahrzeuge kommen später), Showroom mit Glasfront, Dachparkdeck mit Außentreppe,
-- Bürogeschoss darüber, Werkstatt dahinter, Pylon und Fassadenschild "AUTOHAUS ISARTOR" (erfundener Name). Reine Geometrie, Teilefelder wie in den anderen Planern.
-- Koordinaten: x = Ost, z = Süd, y = oben; alle Teile achsparallel. Text: yaw 90 = Schrift schaut nach Westen.

local Autohaus = {}

local WHITE, GREY, DARK, CONC, ASPHALT, GLASS, BLUE, LINE = { 240, 240, 236 }, { 150, 154, 160 }, { 70, 74, 82 }, { 196, 196, 192 }, { 84, 90, 96 }, { 150, 186, 204 }, { 24, 66, 150 }, { 240, 240, 236 }

function Autohaus.plan(cfg)
	local A = cfg.autohaus
	local parts, stats = {}, { bays = 0, lamps = 0, trees = 0 }
	local function r3(v) return math.floor(v * 1000 + 0.5) / 1000 end
	local function add(name, kind, x, y, z, sx, sy, sz, color, mat, e)
		e = e or {}
		parts[#parts + 1] = {
			name = name, kind = kind, size = { r3(sx), r3(sy), r3(sz) }, pos = { r3(x), r3(y), r3(z) }, yaw = e.yaw or 0, pitch = e.pitch or 0, roll = e.roll,
			color = color, material = mat, collide = e.collide == true, shape = e.shape, text = e.text, tag = e.tag, lit = e.lit, attrs = e.attrs, transparency = e.transparency,
		}
	end
	local function disc(name, x, y, z, h, d, color, mat, collide) -- stehende Scheibe
		add(name, "decor", x, y, z, h, d, d, color, mat, { shape = "Cylinder", roll = 90, collide = collide })
	end
	local bx = A.frontX -- Westwand von Showroom und Werkstatt (hier endet der Vorplatz)
	local zS0, zS1 = A.showroom[1], A.showroom[2] -- Showroom (z von Nord nach Süd)
	local zW0, zW1 = A.werkstatt[1], A.werkstatt[2]
	local zc = (zS0 + zS1) / 2
	local xe = A.x1 - 2 -- Ostwand
	local xm = (bx + xe) / 2
	local Y = 0.5 -- Oberkante Boden (wie die Fahrbahn)

	-- Vorplatz (Asphalt) und Fundament unter dem Gebäude
	add("Vorplatz", "plaza", (A.x0 + bx) / 2, Y - 0.5, (A.z0 + A.z1) / 2, bx - A.x0, 1, A.z1 - A.z0, ASPHALT, "Asphalt", { collide = true })
	add("Fundament", "plaza", xm, Y - 0.5, (A.z0 + A.z1) / 2, xe - bx, 1, A.z1 - A.z0, CONC, "Concrete", { collide = true })
	-- Ausstellungsflächen: zwei Blöcke mit weißen Boxenlinien (leer), dazwischen die Fahrgasse
	for _, x in ipairs({ A.x0 + 8, A.x0 + 32 }) do
		for z = zW1 + 4, zS1 - 2, 6 do
			add("Boxenlinie", "dash", x + 8, Y + 0.1, z, 16, 0.2, 0.3, LINE, "SmoothPlastic")
			stats.bays = stats.bays + 1
		end
		for _, xx in ipairs({ x, x + 16 }) do add("Boxenlinie", "dash", xx, Y + 0.1, (zW1 + 4 + zS1 - 2) / 2, 0.3, 0.2, zS1 - 2 - zW1 - 4, LINE, "SmoothPlastic") end
	end
	for _, z in ipairs({ zc - 14, zc, zc + 14 }) do disc("Drehteller", bx - 6, Y + 0.25, z, 0.5, 11, WHITE, "SmoothPlastic", true) end
	for _, z in ipairs({ A.z0 + 0.4, A.z1 - 0.4 }) do add("Zaun", "fence", (A.x0 + bx) / 2, Y + 0.7, z, bx - A.x0, 1.4, 0.2, DARK, "Metal") end

	-- Showroom: Glasfront nach Westen und Süden, massive Nord- und Ostwand, Dachplatte (Parkdeck)
	local H = 12
	add("ShowroomBoden", "floor", xm, Y + 0.3, zc, xe - bx, 0.6, zS1 - zS0, { 200, 200, 196 }, "Concrete", { collide = true })
	add("Glasfront", "glass", bx + 0.15, Y + H / 2 + 0.6, zc, 0.3, H, zS1 - zS0, GLASS, "Glass", { tag = "HouseWindow", lit = true })
	add("Glasfront", "glass", xm, Y + H / 2 + 0.6, zS1 - 0.15, xe - bx, H, 0.3, GLASS, "Glass", { tag = "HouseWindow", lit = true })
	for z = zS0, zS1, (zS1 - zS0) / 4 do add("Pfosten", "trim", bx, Y + H / 2 + 0.6, z, 0.6, H + 0.2, 0.6, DARK, "Metal") end
	for x = bx, xe, (xe - bx) / 4 do add("Pfosten", "trim", x, Y + H / 2 + 0.6, zS1, 0.6, H + 0.2, 0.6, DARK, "Metal") end
	for _, yy in ipairs({ Y + 0.8 + H / 2, Y + H + 0.9 }) do
		add("Riegel", "trim", bx, yy, zc, 0.7, 0.5, zS1 - zS0, DARK, "Metal")
		add("Riegel", "trim", xm, yy, zS1, xe - bx, 0.5, 0.7, DARK, "Metal")
	end
	add("Wand", "body", xm, Y + H / 2 + 0.6, zS0 + 0.4, xe - bx, H, 0.8, WHITE, "SmoothPlastic", { collide = true })
	add("Wand", "body", xe + 0.4, Y + H / 2 + 0.6, zc, 0.8, H, zS1 - zS0, WHITE, "SmoothPlastic", { collide = true })
	local roofY = Y + H + 1.2
	add("Dachplatte", "roof", xm, roofY, zc, xe - bx + 2, 1.2, zS1 - zS0 + 2, CONC, "Concrete", { collide = true })
	for _, z in ipairs({ zc - 14, zc, zc + 14 }) do -- Podeste im Showroom (leer)
		disc("Podest", bx + 10, Y + 0.85, z, 0.5, 9, { 224, 224, 220 }, "SmoothPlastic", true)
		add("Deckenlicht", "light", xm, Y + H + 0.2, z, xe - bx - 4, 0.2, 0.8, { 255, 250, 236 }, "Neon")
	end
	-- Vordach über dem Eingang
	add("Vordach", "roof", bx - 3.5, Y + H, zc, 7, 0.5, 18, WHITE, "SmoothPlastic", { collide = true })
	for _, z in ipairs({ zc - 8, zc + 8 }) do add("VordachStuetze", "trim", bx - 6.8, Y + H / 2, z, 0.5, H, 0.5, DARK, "Metal", { collide = true }) end
	-- Fassadenschild auf der Dachkante (steht auf dem Deck), Schrift nach Westen
	local signY = roofY + 0.6 + 2.3
	add("Fassadenschild", "sign", bx - 0.6, signY, zc, 0.6, 4.6, 34, BLUE, "SmoothPlastic")
	add("FassadenSchrift", "sign", bx - 0.95, signY, zc, 30, 3, 0.1, { 0, 0, 0 }, "SmoothPlastic", { yaw = 90, text = { s = "AUTOHAUS ISARTOR", color = { 255, 255, 255 } } })

	-- Parkdeck auf dem Showroom (vor dem Bürogeschoss): Boxenlinien, Geländer an Nord- und Südkante, Außentreppe an der Südseite
	local officeX0 = bx + 18
	for z = zS0 + 4, zS1 - 4, 6 do add("Boxenlinie", "dash", (bx + officeX0) / 2 + 1, roofY + 0.7, z, 12, 0.2, 0.3, LINE, "SmoothPlastic") end
	add("Gelaender", "rail", (bx + officeX0) / 2, roofY + 1.6, zS0 + 0.8, officeX0 - bx, 2, 0.3, GREY, "Metal", { collide = true })
	add("Gelaender", "rail", bx + 5, roofY + 1.6, zS1 - 0.8, 10, 2, 0.3, GREY, "Metal", { collide = true })
	for _, z in ipairs({ zS0 + 3, zS1 - 3 }) do add("Gelaender", "rail", bx + 0.2, roofY + 1.6, z, 0.3, 2, 6, GREY, "Metal", { collide = true }) end
	local steps, zst = 13, zS1 + 1.4
	local x0s, x1s = bx + 2, bx + 17
	local rise = (roofY + 0.6 - Y) / steps
	for k = 0, steps - 1 do
		add("Treppenstufe", "steps", x0s + (k + 0.5) * (x1s - x0s) / steps, Y + (k + 1) * rise - 0.2, zst, (x1s - x0s) / steps + 0.05, 0.4, 2.6, GREY, "Metal", { collide = true })
	end
	local L = math.sqrt((x1s - x0s) ^ 2 + (roofY + 0.6 - Y) ^ 2)
	local ang = math.deg(math.atan2(roofY + 0.6 - Y, x1s - x0s))
	for _, dz in ipairs({ -1.3, 1.3 }) do add("Treppenwange", "steps", (x0s + x1s) / 2, (Y + roofY + 0.6) / 2 - 0.3, zst + dz, L, 0.4, 0.3, DARK, "Metal", { roll = ang }) end

	-- Bürogeschoss (zwei Etagen) hinten auf dem Dach, Bandfenster nach Westen und Süden
	local oH = 24
	add("Buero", "body", (officeX0 + xe) / 2, roofY + 0.6 + oH / 2, zc, xe - officeX0, oH, zS1 - zS0, WHITE, "SmoothPlastic", { collide = true })
	for _, dy in ipairs({ 6, 18 }) do
		add("Bandfenster", "glass", officeX0 - 0.15, roofY + 0.6 + dy, zc, 0.3, 5, zS1 - zS0 - 4, GLASS, "Glass", { tag = "HouseWindow", lit = false })
		add("Bandfenster", "glass", (officeX0 + xe) / 2, roofY + 0.6 + dy, zS1 + 0.15, xe - officeX0 - 4, 5, 0.3, GLASS, "Glass", { tag = "HouseWindow", lit = false })
	end
	add("Attika", "trim", (officeX0 + xe) / 2, roofY + 0.6 + oH + 0.4, zc, xe - officeX0 + 0.6, 0.8, zS1 - zS0 + 0.6, GREY, "Concrete")

	-- Werkstatt nördlich: weiße Halle mit vier Rolltoren zur Vorplatzseite und Schild "SERVICE"
	local wH = 12
	local zwc = (zW0 + zW1) / 2
	add("Werkstatt", "body", xm, Y + wH / 2, zwc, xe - bx, wH, zW1 - zW0, WHITE, "SmoothPlastic", { collide = true })
	add("WerkstattDach", "roof", xm, Y + wH + 0.3, zwc, xe - bx + 1, 0.6, zW1 - zW0 + 1, GREY, "Concrete")
	for k = 0, 3 do add("Rolltor", "trim", bx - 0.15, Y + 4.5, zW0 + 4.5 + k * 6, 0.3, 8, 5, GREY, "Metal") end
	add("ServiceSchild", "sign", bx - 0.2, Y + 10.2, zwc, 0.3, 2, 14, BLUE, "SmoothPlastic")
	add("ServiceSchrift", "sign", bx - 0.45, Y + 10.2, zwc, 12, 1.6, 0.1, { 0, 0, 0 }, "SmoothPlastic", { yaw = 90, text = { s = "SERVICE", color = { 255, 255, 255 } } })

	-- Pylon an der V3-Ecke, Schrift nach Westen
	local px, pz = A.x0 + 5, A.z1 - 10
	add("PylonSockel", "trim", px, Y + 0.5, pz, 3, 1, 3, CONC, "Concrete", { collide = true })
	add("PylonMast", "trim", px, Y + 9, pz, 1.6, 17, 1.6, GREY, "Metal", { collide = true })
	add("PylonSchild", "sign", px, Y + 16, pz, 0.8, 6, 10, BLUE, "SmoothPlastic")
	add("PylonSchrift", "sign", px - 0.45, Y + 17.2, pz, 9, 1.8, 0.1, { 0, 0, 0 }, "SmoothPlastic", { yaw = 90, text = { s = "AUTOHAUS", color = { 255, 255, 255 } } })
	add("PylonSchrift", "sign", px - 0.45, Y + 14.9, pz, 9, 1.6, 0.1, { 0, 0, 0 }, "SmoothPlastic", { yaw = 90, text = { s = "ISARTOR", color = { 255, 255, 255 } } })

	-- Leuchten auf dem Vorplatz (in der Fahrgasse zwischen den Ausstellungsflächen), Bäume an den Rändern
	for _, z in ipairs({ zW1 + 6, zc, zS1 - 6 }) do
		add("LampenMast", "lamp", A.x0 + 28, Y + 5, z, 0.5, 10, 0.5, { 40, 56, 48 }, "Metal", { collide = true })
		add("LampenKopf", "lamp", A.x0 + 28, Y + 10.3, z, 2.6, 0.6, 1.2, { 255, 226, 150 }, "Neon", { tag = "StreetLamp", attrs = { Lit = true } })
		stats.lamps = stats.lamps + 1
	end
	for _, q in ipairs({ { A.x0 + 4, A.z0 + 6 }, { A.x0 + 40, A.z0 + 4 }, { A.x0 + 50, A.z1 - 6 } }) do
		add("AutohausStamm", "tree", q[1], Y + 4, q[2], 1.2, 8, 1.2, { 96, 70, 48 }, "Wood", { collide = true })
		add("AutohausKrone", "tree", q[1], Y + 11, q[2], 9, 9, 9, { 88, 140, 70 }, "Grass", { shape = "Ball" })
		stats.trees = stats.trees + 1
	end
	return { parts = parts, stats = stats }
end

return Autohaus
