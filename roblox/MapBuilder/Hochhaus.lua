-- Hochhaus.lua
-- Skyline: Glas-Hochhäuser mit abgerundeten Ecken (nach den Fotos), der Vierzylinder-Turm "BMO" (vier Zylinder, blaues Band, eigenes Logo,
-- bewusst kein BMW-Logo/-Name) und das Schüssel-Gebäude "BMO Welt" mit Brücke zum Turm. Reine Geometrie, Teilefelder wie in den anderen Planern.
-- Konfiguration in Config.hochhaeuser: { name, art = "glas"|"bmo"|"schuessel", x, z, ... }.

local Geo = require(script and script.Parent.Geo or "Geo")

local Hochhaus = {}

local FH, LOBBY, Y0 = 9, 14, 1 -- Geschosshöhe, Höhe des Erdgeschosses, Oberkante Gehweg
local SPANDREL, GLASS, GLASS_LIT, GLASS_TOP = { 196, 204, 214 }, { 62, 88, 116 }, { 255, 226, 150 }, { 34, 44, 60 }
local STEEL, BLUE, PLAZA = { 214, 218, 224 }, { 24, 68, 170 }, { 188, 184, 176 }

local function newRng(seed)
	local s = seed
	return function()
		s = (s * 1103515245 + 12345) % 2147483648
		return s / 2147483648
	end
end

local function newPlan()
	local parts = {}
	local function add(name, kind, x, y, z, sx, sy, sz, color, mat, extra)
		extra = extra or {}
		parts[#parts + 1] = {
			name = name, kind = kind, size = { Geo.round3(sx), Geo.round3(sy), Geo.round3(sz) },
			pos = { Geo.round3(x), Geo.round3(y), Geo.round3(z) }, yaw = extra.yaw or 0, pitch = extra.pitch or 0, roll = extra.roll,
			color = color, material = mat, collide = extra.collide == true, shape = extra.shape, tag = extra.tag, lit = extra.lit, text = extra.text,
			transparency = extra.transparency,
		}
	end
	local function vcyl(name, kind, x, y, z, h, d, color, mat, extra) -- stehender Zylinder, y = Mitte
		extra = extra or {}
		extra.shape, extra.roll = "Cylinder", 90
		add(name, kind, x, y, z, h, d, d, color, mat, extra)
	end
	return parts, add, vcyl
end

-- Glasband einer Etage: dunkles Glas, einzelne Etagen nachts beleuchtet (Tag wie bei den Häusern)
local function glassExtra(rng, top)
	return { tag = "HouseWindow", lit = not top and rng() < 0.3 }
end

-- Glas-Hochhaus mit abgerundeten Ecken: Kern aus zwei Kästen und vier Eckzylindern, je Etage ein Glasband (vier Seiten und vier Ecken).
local function glasTurm(t, add, vcyl, rng)
	local W, D, r, N = t.w, t.d, t.r, t.floors
	local H = LOBBY + N * FH
	local x, z = t.x, t.z
	local body = t.color or SPANDREL
	local pm = t.pm or 9
	add("Plaza", "plaza", x, Y0 - 0.3, z, W + 2 * pm, 1, D + 2 * pm, PLAZA, "Granite")
	add("TurmKernA", "tower", x, Y0 + H / 2, z, W - 2 * r, H, D, body, "SmoothPlastic", { collide = true })
	add("TurmKernB", "tower", x, Y0 + H / 2, z, W, H, D - 2 * r, body, "SmoothPlastic", { collide = true })
	local cx, cz = W / 2 - r, D / 2 - r
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do vcyl("TurmEcke", "tower", x + sx * cx, Y0 + H / 2, z + sz * cz, H, 2 * r, body, "SmoothPlastic", { collide = true }) end
	end
	-- Erdgeschoss: dunkle Glasfront rundum
	local lh = LOBBY - 2
	for _, sz in ipairs({ -1, 1 }) do
		add("EGGlas", "glass", x, Y0 + 1 + lh / 2, z + sz * (D / 2 + 0.25), W - 2 * r, lh, 0.5, GLASS_TOP, "Glass", { tag = "HouseWindow", lit = true })
	end
	for _, sx in ipairs({ -1, 1 }) do
		add("EGGlas", "glass", x + sx * (W / 2 + 0.25), Y0 + 1 + lh / 2, z, 0.5, lh, D - 2 * r, GLASS_TOP, "Glass", { tag = "HouseWindow", lit = true })
		for _, sz in ipairs({ -1, 1 }) do vcyl("EGGlasEcke", "glass", x + sx * cx, Y0 + 1 + lh / 2, z + sz * cz, lh, 2 * r + 0.8, GLASS_TOP, "Glass") end
	end
	-- Vordach und Eingang an der Südseite (z+)
	add("Vordach", "trim", x, Y0 + 11.5, z + D / 2 + 4, 16, 0.8, 8, { 70, 74, 82 }, "Metal")
	for _, sx in ipairs({ -1, 1 }) do add("VordachStuetze", "trim", x + sx * 7.4, Y0 + 5.5, z + D / 2 + 7.4, 0.6, 11, 0.6, { 70, 74, 82 }, "Metal") end
	add("Eingang", "door", x, Y0 + 4, z + D / 2 + 0.6, 8, 8, 0.4, { 30, 36, 46 }, "Glass", { tag = "HouseWindow", lit = true })
	-- Etagen: Glasband (Höhe 5,8 von 9), die obersten zwei Etagen dunkler (Technik-/Kranzgeschoss)
	local sh = FH - 3.2
	for k = 1, N do
		local y = Y0 + LOBBY + (k - 0.5) * FH
		local top = k > N - 2
		local col = top and GLASS_TOP or GLASS
		local ex = glassExtra(rng, top)
		for _, sz in ipairs({ -1, 1 }) do
			add("Glasband", "glass", x, y, z + sz * (D / 2 + 0.2), W - 2 * r, sh, 0.45, ex.lit and GLASS_LIT or col, "Glass", { tag = ex.tag, lit = ex.lit })
		end
		for _, sx in ipairs({ -1, 1 }) do
			add("Glasband", "glass", x + sx * (W / 2 + 0.2), y, z, 0.45, sh, D - 2 * r, ex.lit and GLASS_LIT or col, "Glass", { tag = ex.tag, lit = ex.lit })
			for _, sz in ipairs({ -1, 1 }) do vcyl("GlasbandEcke", "glass", x + sx * cx, y, z + sz * cz, sh, 2 * r + 0.8, ex.lit and GLASS_LIT or col, "Glass", { tag = ex.tag, lit = ex.lit }) end
		end
	end
	-- Dach: Kranz, Technikaufbau, Mast mit Positionslicht, Schriftzug nach Norden und Süden
	local top = Y0 + H
	add("Dachkranz", "trim", x, top + 0.6, z, W + 1.2, 1.2, D + 1.2, { 60, 66, 76 }, "Concrete")
	add("Technik", "tower", x, top + 5, z, W * 0.5, 8, D * 0.45, { 150, 156, 164 }, "Concrete")
	add("Mast", "tower", x + W * 0.18, top + 22, z, 0.8, 34, 0.8, { 190, 190, 194 }, "Metal")
	add("Positionslicht", "tower", x + W * 0.18, top + 39.5, z, 1.6, 1.6, 1.6, { 255, 40, 40 }, "Neon", { shape = "Ball" })
	if t.label then
		add("Schriftzug", "sign", x, top - FH, z - D / 2 - 0.8, W * 0.7, 4.4, 0.2, { 0, 0, 0 }, "SmoothPlastic", { text = { s = t.label, color = { 235, 240, 248 } } })
		add("Schriftzug", "sign", x, top - FH, z + D / 2 + 0.8, W * 0.7, 4.4, 0.2, { 0, 0, 0 }, "SmoothPlastic", { yaw = 180, text = { s = t.label, color = { 235, 240, 248 } } })
	end
end

-- Logo (eigener Entwurf: Ring, Raute, Schriftzug; absichtlich ohne Ähnlichkeit zum Original) als Doppelscheibe an der Nord- und Südseite
local function logo(add, vcyl, x, y, z, dz)
	for _, s in ipairs({ -1, 1 }) do
		local zz = z + s * dz
		local function disc(name, d, col, off, mat)
			add(name, "sign", x, y, zz + s * off, 1, d, d, col, mat or "SmoothPlastic", { shape = "Cylinder", yaw = 90 })
		end
		disc("LogoRing", 22, { 0, 150, 136 }, 0)
		disc("LogoGrund", 17, { 244, 244, 238 }, 0.3)
		add("LogoRaute", "sign", x, y, zz + s * 0.9, 9, 9, 0.4, { 18, 40, 92 }, "SmoothPlastic", { roll = 45 })
		add("LogoSchrift", "sign", x, y, zz + s * 1.2, 14, 4.6, 0.2, { 0, 0, 0 }, "SmoothPlastic", { yaw = s == 1 and 180 or 0, text = { s = "BMO", color = { 255, 255, 255 } } })
	end
end

-- Vierzylinder-Turm: vier Zylinder (2 x 2) mit Kern, blaues Band auf halber Höhe, Kappen oben, Logo auf dem Kern
local function bmoTurm(t, add, vcyl, rng)
	local R, c, N = t.radius or 14, t.versatz or 12.5, t.floors
	local H = LOBBY + N * FH
	local x, z = t.x, t.z
	add("Plaza", "plaza", x, Y0 - 0.3, z, 2 * (c + R) + 6, 1, 2 * (c + R) + 6, PLAZA, "Granite")
	add("BMOKern", "tower", x, Y0 + (H + 10) / 2, z, 2 * c, H + 10, 2 * c, STEEL, "Metal", { collide = true })
	local bandY = Y0 + LOBBY + 0.55 * N * FH
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			local px, pz = x + sx * c, z + sz * c
			vcyl("BMOZylinder", "tower", px, Y0 + H / 2, pz, H, 2 * R, STEEL, "Metal", { collide = true })
			vcyl("BMOEGGlas", "glass", px, Y0 + 1 + (LOBBY - 2) / 2, pz, LOBBY - 2, 2 * R + 0.8, GLASS_TOP, "Glass", { tag = "HouseWindow", lit = true })
			for k = 1, N do
				local y = Y0 + LOBBY + (k - 0.5) * FH
				if math.abs(y - bandY) > 4.5 then
					local lit = rng() < 0.28
					vcyl("BMOFensterband", "glass", px, y, pz, FH - 4.2, 2 * R + 0.8, lit and GLASS_LIT or GLASS, "Glass", { tag = "HouseWindow", lit = lit })
				end
			end
			vcyl("BMOBand", "trim", px, bandY, pz, 8, 2 * R + 3.4, BLUE, "SmoothPlastic")
			vcyl("BMOKappe", "tower", px, Y0 + H + 4, pz, 8, 2 * R * 0.62, { 170, 176, 186 }, "Metal")
		end
	end
	logo(add, vcyl, x, Y0 + H + 9, z, c + 0.2)
	add("Positionslicht", "tower", x, Y0 + H + 17, z, 1.6, 1.6, 1.6, { 255, 40, 40 }, "Neon", { shape = "Ball" })
	add("Vordach", "trim", x, Y0 + 11.5, z + c + R + 3, 18, 0.8, 8, { 70, 74, 82 }, "Metal")
	add("Eingang", "door", x, Y0 + 4, z + c + R - 1.2, 8, 8, 0.4, { 30, 36, 46 }, "Glass", { tag = "HouseWindow", lit = true })
end

-- Schüssel-Gebäude: Glasfoyer, "Doppelkegel" aus Scheiben (unten schmal, oben schmal, Bauch in der Mitte), blaues Band, Schriftzug; Brücke zum Turm
local function schuessel(t, add, vcyl)
	local x, z, R = t.x, t.z, t.r or 26
	add("Plaza", "plaza", x, Y0 - 0.3, z, 2 * R + 4, 1, 2 * R + 4, PLAZA, "Granite")
	vcyl("WeltFoyer", "glass", x, Y0 + 4.5, z, 9, 2 * R, GLASS_TOP, "Glass", { tag = "HouseWindow", lit = true, collide = true })
	local n, y = 12, Y0 + 9
	for i = 1, n do
		local f = i / n
		local rad = R * (0.46 + 0.54 * math.sin(math.pi * f) ^ 0.7) -- Bauch in der Mitte
		vcyl("WeltSchale", "tower", x, y + 1.6, z, 3.2, 2 * rad, { 186, 192, 202 }, "Metal", { collide = true })
		y = y + 3.2
	end
	vcyl("WeltBand", "trim", x, Y0 + 9 + 0.5 * n * 3.2, z, 2.4, 2 * R + 1.2, BLUE, "SmoothPlastic")
	vcyl("WeltDeckel", "tower", x, y + 0.4, z, 0.8, 2 * R * 0.5, { 120, 128, 140 }, "Metal")
	add("WeltSchrift", "sign", x, Y0 + 4.5, z + R + 0.5, 24, 4, 0.2, { 0, 0, 0 }, "SmoothPlastic", { yaw = 180, text = { s = "BMO WELT", color = { 255, 255, 255 } } })
	if t.bruecke then
		local x0, x1 = t.bruecke.x, x - R + 2
		add("Bruecke", "glass", (x0 + x1) / 2, Y0 + 22, t.bruecke.z, math.abs(x1 - x0), 4, 6, GLASS, "Glass", { tag = "HouseWindow", lit = false })
		add("BrueckenDach", "trim", (x0 + x1) / 2, Y0 + 24.3, t.bruecke.z, math.abs(x1 - x0), 0.6, 7, { 150, 156, 164 }, "Metal")
	end
end

function Hochhaus.plan(cfg)
	local parts, add, vcyl = newPlan()
	local rng = newRng(7)
	local stats = { towers = 0, tallest = 0 }
	for _, t in ipairs(cfg.hochhaeuser) do
		local before = #parts
		if t.art == "glas" then glasTurm(t, add, vcyl, rng)
		elseif t.art == "bmo" then bmoTurm(t, add, vcyl, rng)
		else schuessel(t, add, vcyl) end
		for i = before + 1, #parts do parts[i].name = t.name .. "_" .. parts[i].name end
		if t.art ~= "schuessel" then
			stats.towers = stats.towers + 1
			stats.tallest = math.max(stats.tallest, LOBBY + t.floors * FH)
		end
	end
	return { parts = parts, stats = stats }
end

return Hochhaus
