-- Tram.lua
-- Blaue Straßenbahn auf der markierten Linie: Strecke mit gerundeten Ecken (Gleisbett + Schienen), Haltestellen (Bahnsteig, Wartehäuschen,
-- Namensband, Schild "H") und die Bahn selbst (zwei Wagen mit Gelenk, 16 Sitzmarken). Reine Geometrie; Fahren, Einsteigen und Aussteigen macht das
-- Script TramSteuerung (liest Strecke und Halte aus den Attributen am Wagenboden "Body" des Vorderwagens).
-- Config.tram = { route = { {x, z, R}, ... } (Eckpunkte, R = Rundungsradius, 0 = spitz), stops = { {name, x, z, side}, ... } (aufsteigend entlang der Strecke,
-- side = Bahnsteigseite relativ zur Fahrtrichtung vom ersten zum letzten Halt, 1 = rechts), carLen, gap, width, bed, gauge, speed, accel, dwell, dwellEnd, platform = { len, off, w } }
-- Wagen-Koordinaten: lx = Fahrtrichtung, lz = rechts, Oberkante Wagenboden 2,5.

local Geo = require(script and script.Parent.Geo or "Geo")

local Tram = {}

local BLUE, WHITE, GREY, DARK, YELLOW = { 0, 98, 175 }, { 240, 244, 248 }, { 176, 178, 180 }, { 38, 42, 50 }, { 250, 210, 40 }
local GLASS = { 170, 210, 235 }
local BED_Y, RAIL_Y, FLOOR = 0.83, 1.01, 2.5

-- Strecke als dichter Linienzug { x, z, s } (s = Weg ab Anfang); an den Ecken Kreisbögen mit Sehnen von höchstens 3,5 Studs
function Tram.path(cfg)
	local v = cfg.tram.route
	local pts = { { x = v[1][1], z = v[1][2] } }
	local prevT = 0 -- Tangentenlänge der vorigen Rundung
	for i = 2, #v - 1 do
		local P, A, B = v[i], v[i - 1], v[i + 1]
		local ax, az, al = Geo.dir(P[1], P[2], A[1], A[2])
		local bx, bz, bl = Geo.dir(P[1], P[2], B[1], B[2])
		local phi = math.acos(math.max(-1, math.min(1, ax * bx + az * bz))) -- Innenwinkel zwischen den Schenkeln
		local R = P[3] or 0
		if R <= 0 or phi > math.pi - 1e-4 then
			assert(prevT <= al + 1e-6, "Tram: Rundungen überlappen bei Eckpunkt " .. i)
			pts[#pts + 1] = { x = P[1], z = P[2] }
			prevT = 0
		else
			local t = R / math.tan(phi / 2)
			assert(t + prevT <= al + 1e-6, "Tram: Rundung R" .. R .. " passt nicht auf den Schenkel vor Eckpunkt " .. i)
			local mx, mz = ax + bx, az + bz
			local ml = math.sqrt(mx * mx + mz * mz)
			local c = R / math.sin(phi / 2)
			local cx, cz = P[1] + mx / ml * c, P[2] + mz / ml * c
			local a0 = math.atan2(P[2] + az * t - cz, P[1] + ax * t - cx)
			local turn = math.pi - phi
			local sweep = ((-ax) * bz - (-az) * bx > 0 and 1 or -1) * turn -- Drehsinn der Fahrt
			local n = math.max(2, math.ceil(R * turn / 3.5))
			for k = 0, n do
				local a = a0 + sweep * k / n
				pts[#pts + 1] = { x = cx + R * math.cos(a), z = cz + R * math.sin(a) }
			end
			local e = pts[#pts]
			assert(math.abs(e.x - (P[1] + bx * t)) < 0.05 and math.abs(e.z - (P[2] + bz * t)) < 0.05, "Tram: Rundung dreht falsch herum bei Eckpunkt " .. i)
			prevT = t
		end
	end
	local last = v[#v]
	local _, _, ll = Geo.dir(v[#v - 1][1], v[#v - 1][2], last[1], last[2])
	assert(prevT <= ll + 1e-6, "Tram: letzte Rundung passt nicht auf den Endschenkel")
	pts[#pts + 1] = { x = last[1], z = last[2] }
	local s = 0
	pts[1].s = 0
	for i = 2, #pts do
		s = s + math.sqrt((pts[i].x - pts[i - 1].x) ^ 2 + (pts[i].z - pts[i - 1].z) ^ 2)
		pts[i].s = s
	end
	return { pts = pts, len = s }
end

-- Punkt und Fahrtrichtung bei Weg s (außerhalb [0, len] bleibt der Punkt am Streckenende)
function Tram.at(path, s)
	local pts = path.pts
	local lo, hi = 1, #pts
	while hi - lo > 1 do
		local mid = math.floor((lo + hi) / 2)
		if pts[mid].s <= s then lo = mid else hi = mid end
	end
	local a, b = pts[lo], pts[hi]
	local ux, uz, l = Geo.dir(a.x, a.z, b.x, b.z)
	local t = math.max(0, math.min(l, s - a.s))
	return a.x + ux * t, a.z + uz * t, ux, uz
end

-- Halte auf die Strecke legen: { name, s, x, z, ux, uz, off (Abstand der Wunschposition zur Strecke), side }
function Tram.stops(cfg, path)
	local out = {}
	for i, st in ipairs(cfg.tram.stops) do
		local best = { d = 1e9 }
		for k = 1, #path.pts - 1 do
			local a, b = path.pts[k], path.pts[k + 1]
			local dx, dz = b.x - a.x, b.z - a.z
			local l2 = dx * dx + dz * dz
			local t = math.max(0, math.min(1, ((st.x - a.x) * dx + (st.z - a.z) * dz) / l2))
			local d = math.sqrt((st.x - a.x - t * dx) ^ 2 + (st.z - a.z - t * dz) ^ 2)
			if d < best.d then best = { d = d, s = a.s + t * math.sqrt(l2) } end
		end
		local x, z, ux, uz = Tram.at(path, best.s)
		out[i] = { name = st.name, s = best.s, x = x, z = z, ux = ux, uz = uz, off = best.d, side = st.side or 1 }
		assert(i == 1 or out[i].s > out[i - 1].s, "Tram: Halte müssen entlang der Strecke aufsteigen: " .. st.name)
	end
	return out
end

-- Rahmen um (cx, cz) mit lokaler x-Achse (fx, fz) und z-Achse (-fz, fx); add(name, kind, lx, y, lz, sx, sy, sz, color, material, extra)
local function frame(cx, cz, fx, fz, parts, attrs)
	local yaw = Geo.yawOf(fx, fz)
	return function(name, kind, lx, y, lz, sx, sy, sz, color, mat, o)
		o = o or {}
		local p = {
			name = name, kind = kind, size = { sx, sy, sz }, pos = { Geo.round3(cx + lx * fx - lz * fz), Geo.round3(y), Geo.round3(cz + lx * fz + lz * fx) },
			yaw = (yaw + (o.yaw or 0)) % 360, pitch = 0, color = color, material = mat, collide = o.collide == true, shape = o.shape, roll = o.roll,
			tag = o.tag, text = o.text, transparency = o.transparency, attrs = o.attrs or attrs,
		}
		parts[#parts + 1] = p
		return p
	end
end

-- Gleisbett (dunkler Streifen) und zwei Schienen je Streckenstück, am Ende ein Prellbock
local function track(path, T, parts)
	for i = 1, #path.pts - 1 do
		local a, b = path.pts[i], path.pts[i + 1]
		local ux, uz, l = Geo.dir(a.x, a.z, b.x, b.z)
		local add = frame((a.x + b.x) / 2, (a.z + b.z) / 2, ux, uz, parts)
		add("Gleisbett", "rail", 0, BED_Y, 0, l + 0.3, 0.14, T.bed, { 96, 98, 100 }, "Concrete")
		for _, o in ipairs({ -1, 1 }) do add("Schiene", "rail", 0, RAIL_Y, o * T.gauge / 2, l + 0.3, 0.22, 0.4, { 150, 154, 160 }, "Metal") end
	end
	for _, e in ipairs({ { path.pts[1], path.pts[2] }, { path.pts[#path.pts], path.pts[#path.pts - 1] } }) do
		local ux, uz = Geo.dir(e[2].x, e[2].z, e[1].x, e[1].z) -- vom Streckenende weg
		local add = frame(e[1].x + ux * 1.2, e[1].z + uz * 1.2, ux, uz, parts)
		add("Prellbock", "rail", 0, 1.5, 0, 1.6, 1.4, 5.2, { 200, 60, 50 }, "Metal")
		add("PrellbockStreifen", "rail", 0, 1.5, 0, 1.7, 0.5, 5.3, YELLOW, "Metal")
	end
end

-- Haltestelle i: Bahnsteig rechts (side = 1) bzw. links neben dem Gleis, Wartehäuschen mit Namensband, zwei Schilder "H"
local function stop(parts, st, i, T)
	local P = T.platform
	local add = frame(st.x, st.z, st.side * st.ux, st.side * st.uz, parts, { Haltestelle = st.name })
	local zc = P.off + P.w / 2
	add("Bahnsteig", "trim", 0, 0.75, zc, P.len, 0.5, P.w, GREY, "Concrete", { collide = true })
	add("Bahnsteigkante", "trim", 0, 1.03, P.off + 0.4, P.len, 0.06, 0.7, YELLOW, "SmoothPlastic")
	-- Wartehäuschen: Dach, vier Pfosten, Rück- und Seitenwand aus Glas, Bank, Fahrplan, Leuchte
	local zr, zb = P.off + 1.8, P.off + P.w - 0.6 -- Vorderkante und Rückwand
	local zm = (zr + zb) / 2
	add("Dach", "trim", 0, 9.2, zm, 12, 0.4, zb - zr + 0.8, BLUE, "Metal")
	for _, lx in ipairs({ -5.6, 5.6 }) do
		for _, lz in ipairs({ zr + 0.4, zb - 0.4 }) do add("Pfosten", "trim", lx, 5.1, lz, 0.4, 8.2, 0.4, BLUE, "Metal") end
	end
	add("Rueckwand", "glass", 0, 4.4, zb, 11.6, 6.4, 0.2, GLASS, "Glass")
	add("Seitenwand", "glass", -5.8, 4.4, zm, 0.2, 6.4, zb - zr, GLASS, "Glass")
	add("Bank", "trim", 0, 2.0, zb - 1.0, 7, 0.4, 1.4, { 140, 100, 64 }, "Wood")
	for _, lx in ipairs({ -2.8, 2.8 }) do add("Bankstuetze", "trim", lx, 1.5, zb - 1.0, 0.4, 1.0, 1.2, DARK, "Metal") end
	add("Fahrplan", "sign", 3.8, 4.8, zb - 0.2, 1.8, 2.6, 0.2, YELLOW, "SmoothPlastic")
	add("Leuchte", "lamp", 0, 8.95, zm, 6, 0.2, 0.6, { 255, 248, 225 }, "Neon", { tag = "StreetLamp", attrs = { Lit = true, Haltestelle = st.name } })
	-- Namensband an der Dachkante zum Gleis: blaue Tafel, davor die weiße Schrift (Vorderseite = Richtung Gleis)
	add("Namensband", "sign", 0, 8.4, zr - 0.1, 12.4, 1.5, 0.25, BLUE, "SmoothPlastic")
	add("Haltestellenname", "sign", 0, 8.4, zr - 0.3, 11.8, 1.1, 0.1, BLUE, "SmoothPlastic", { text = { s = st.name, color = WHITE } })
	-- Haltestellenschilder an beiden Bahnsteigenden: Mast, blaue Scheibe, "H"
	for _, lx in ipairs({ -17.5, 17.5 }) do
		local lz = P.off + 0.9
		add("SchildMast", "trim", lx, 6.5, lz, 0.4, 11, 0.4, { 120, 124, 130 }, "Metal")
		add("SchildScheibe", "sign", lx, 10.6, lz - 0.1, 0.3, 3.6, 3.6, BLUE, "SmoothPlastic", { shape = "Cylinder", yaw = 90 })
		add("SchildH", "sign", lx, 10.6, lz - 0.32, 2.4, 2.4, 0.2, BLUE, "SmoothPlastic", { text = { s = "H", color = WHITE } })
	end
end

-- Ein Wagen mit Mittelpunkt (cx, cz), Fahrtrichtung (ux, uz). outer = +1: Außenende (Führerstand) bei +lx, -1: bei -lx; am anderen Ende hängt das Gelenk.
local function car(T, cx, cz, ux, uz, outer, parts)
	local add = frame(cx, cz, ux, uz, parts)
	local L, W = T.carLen, T.width
	local hw = W / 2
	add("Body", "trim", 0, 2.1, 0, L, 0.8, W - 0.4, BLUE, "SmoothPlastic")
	add("Innenboden", "trim", 0, FLOOR + 0.06, 0, L - 0.8, 0.1, W - 0.8, { 110, 118, 128 }, "SmoothPlastic")
	add("Dach", "trim", 0, 8.75, 0, L, 0.5, W - 0.2, { 214, 220, 226 }, "SmoothPlastic")
	add("Dachaufbau", "trim", -outer * 2, 9.35, 0, 6.5, 0.7, 3.4, { 150, 156, 164 }, "Metal")
	add("Innenlicht", "lamp", 0, 8.4, 0, 8, 0.12, 0.7, { 255, 248, 225 }, "Neon", { tag = "StreetLamp", attrs = { Lit = true } })
	for _, bx in ipairs({ -4.6, 4.6 }) do add("Drehgestell", "trim", bx, 1.5, 0, 4, 0.8, 4.6, DARK, "Metal") end
	for _, lx in ipairs({ -2.9, 2.9 }) do
		for _, lz in ipairs({ -1.6, 1.6 }) do add("Haltestange", "trim", lx, FLOOR + 3, lz, 0.25, 5.9, 0.25, YELLOW, "Metal") end
	end
	for _, e in ipairs({ -1, 1 }) do
		add("Stirn", "trim", e * (L / 2 - 0.25), 5.7, 0, 0.5, 6.4, W - 0.4, BLUE, "SmoothPlastic")
		if e == outer then
			local ex = e * (L / 2)
			add("Frontscheibe", "glass", ex + e * 0.02, 6.6, 0, 0.2, 2.6, W - 1.6, { 30, 44, 60 }, "Glass")
			for _, lz in ipairs({ -2.5, 2.5 }) do add("Scheinwerfer", "lamp", ex + e * 0.05, 3.4, lz, 0.2, 0.8, 0.9, { 255, 244, 200 }, "Neon") end
			add("Stossfaenger", "trim", ex + e * 0.1, 2.8, 0, 0.5, 0.5, W - 0.6, GREY, "Metal")
			add("Zielanzeige", "sign", ex + e * 0.06, 8.1, 0, 0.12, 0.9, 4.2, { 20, 22, 26 }, "SmoothPlastic")
			add("Ziel", "sign", ex + e * 0.14, 8.1, 0, 4, 0.7, 0.1, { 20, 22, 26 }, "SmoothPlastic", { yaw = e == 1 and 270 or 90, text = { s = "Linie 1", color = { 255, 176, 40 } } })
		end
	end
	if outer == 1 then -- Gelenk zum Hinterwagen, am hinteren Ende des Vorderwagens
		add("Faltenbalg", "trim", -(L / 2 + T.gap / 2), 5.6, 0, T.gap + 0.6, 5.8, W - 1.2, { 30, 32, 36 }, "Fabric")
	end
	for _, s in ipairs({ -1, 1 }) do
		local wz = s * (hw - 0.15)
		local flip = s == 1 and 0 or 180 -- Sitzmarken schauen zum Gang
		add("Schuerze", "trim", 0, FLOOR + 0.95, wz, L - 0.6, 1.9, 0.3, BLUE, "SmoothPlastic")
		add("Zierstreifen", "trim", 0, FLOOR + 1.75, wz + s * 0.02, L - 0.6, 0.3, 0.3, WHITE, "SmoothPlastic")
		add("Oberteil", "trim", 0, 7.85, wz, L - 0.6, 1.3, 0.3, BLUE, "SmoothPlastic")
		for _, lx in ipairs({ -7.75, -2.35, 2.35, 7.75 }) do add("Pfosten", "trim", lx, 5.8, wz, 0.5, 2.8, 0.34, BLUE, "SmoothPlastic") end
		for _, lx in ipairs({ -5.05, 5.05 }) do add("Fenster", "glass", lx, 5.8, wz, 5.1, 2.8, 0.2, GLASS, "Glass") end
		add("Tuer", "glass", 0, FLOOR + 2.35, wz, 4.2, 4.7, 0.2, { 150, 196, 230 }, "Glass")
		add("Tuertaster", "trim", 2.6, FLOOR + 1.9, wz + s * 0.2, 0.4, 0.5, 0.15, YELLOW, "SmoothPlastic")
		add("Einstieg", "trim", 0, 4.3, s * (hw + 0.3), 1, 1, 1, BLUE, "SmoothPlastic", { transparency = 1 })
		for _, bx in ipairs({ -5.05, 5.05 }) do
			add("Bankstuetze", "trim", bx, FLOOR + 0.25, s * (hw - 1.15), 4.6, 0.5, 1.2, DARK, "Metal")
			add("Bank", "trim", bx, FLOOR + 0.7, s * (hw - 1.15), 4.8, 0.4, 1.4, { 70, 100, 150 }, "Fabric")
			add("Lehne", "trim", bx, FLOOR + 1.6, s * (hw - 0.6), 4.8, 1.3, 0.2, { 70, 100, 150 }, "Fabric")
			for _, dx in ipairs({ -1.2, 1.2 }) do add("Sitzmarke", "trim", bx + dx, FLOOR + 1.0, s * (hw - 1.15), 1.9, 0.2, 1.6, WHITE, "SmoothPlastic", { yaw = flip, transparency = 1 }) end
		end
	end
end

function Tram.plan(cfg)
	local T = cfg.tram
	local path = Tram.path(cfg)
	local stops = Tram.stops(cfg, path)
	local parts = {}
	track(path, T, parts)
	for i, st in ipairs(stops) do stop(parts, st, i, T) end
	local d = T.carLen + T.gap -- Abstand der Wagenmitten
	local s0 = stops[1].s
	local houses, seats = {}, 0
	for _, outer in ipairs({ 1, -1 }) do
		local x, z, ux, uz = Tram.at(path, s0 + outer * d / 2)
		local cp = {}
		car(T, x, z, ux, uz, outer, cp)
		for _, p in ipairs(cp) do if p.name == "Sitzmarke" then seats = seats + 1 end end
		if outer == 1 then -- Strecke und Fahrdaten für TramSteuerung
			local rt, sp = {}, {}
			for _, p in ipairs(path.pts) do rt[#rt + 1] = string.format("%.1f,%.1f,%.1f;", p.x, p.z, p.s) end
			for _, q in ipairs(stops) do sp[#sp + 1] = string.format("%.1f|%d|%s;", q.s, q.side, q.name) end
			cp[1].attrs = { Route = table.concat(rt), Stops = table.concat(sp), Abstand = d, Start = s0, Tempo = T.speed, Beschl = T.accel, Halt = T.dwell, HaltEnde = T.dwellEnd, Bahnsteig = T.platform.off + T.platform.w / 2 }
		end
		houses[#houses + 1] = { name = outer == 1 and "TramVorn" or "TramHinten", floors = 1, side = "Q", parts = cp }
	end
	return { parts = parts, houses = houses, path = path, stops = stops, stats = { stops = #stops, seats = seats, len = path.len, pathPts = #path.pts } }
end

return Tram
