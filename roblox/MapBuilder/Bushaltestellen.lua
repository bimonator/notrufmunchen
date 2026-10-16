-- Bushaltestellen.lua
-- Wartehäuschen (Glas, Dach, Bank, Fahrplankasten) mit Haltestellenschild (grüne Scheibe mit "H") auf dem Gehweg, offene Seite zur Straße.
-- Config.busstops = { { x, z, zurStrasse = "N"|"S"|"W"|"E", name }, ... } (x/z = Mitte auf dem Gehweg). Reine Geometrie.

local Geo = require(script and script.Parent.Geo or "Geo")

local Bus = {}

local YAW = { N = 0, S = 180, W = 90, E = 270 } -- Blickrichtung (lokal -z) zur Straße

function Bus.plan(cfg)
	local parts = {}
	for i, s in ipairs(cfg.busstops) do
		local yaw = YAW[s.zurStrasse]
		local r = math.rad(yaw)
		local c, sn = math.cos(r), math.sin(r)
		-- lokal: lx entlang des Gehwegs, lz nach hinten (weg von der Straße); Wandlung wie in Planner.add
		local function add(name, kind, lx, y, lz, sx, sy, sz, color, mat, extra)
			extra = extra or {}
			parts[#parts + 1] = {
				name = string.format("Bus%02d_%s", i, name), kind = kind, size = { sx, sy, sz },
				pos = { Geo.round3(s.x + lx * c + lz * sn), y, Geo.round3(s.z - lx * sn + lz * c) }, yaw = (yaw + (extra.yaw or 0)) % 360, pitch = 0,
				color = color, material = mat, collide = extra.collide == true, shape = extra.shape, roll = extra.roll, tag = extra.tag, text = extra.text,
				attrs = { Haltestelle = s.name or ("Haltestelle " .. i) },
			}
		end
		local FRAME, GLASS = { 52, 58, 66 }, { 150, 190, 210 }
		add("Dach", "trim", 0, 9.4, 0, 9.4, 0.5, 4.2, FRAME, "Metal")
		for _, sx in ipairs({ -4.4, 4.4 }) do add("Pfosten", "trim", sx, 5.2, -1.8, 0.4, 8.4, 0.4, FRAME, "Metal") end
		for _, sx in ipairs({ -4.4, 4.4 }) do add("PfostenHinten", "trim", sx, 5.2, 1.8, 0.4, 8.4, 0.4, FRAME, "Metal") end
		add("Rueckwand", "glass", 0, 5.6, 1.9, 8.8, 6.6, 0.2, GLASS, "Glass", { tag = nil })
		add("Seitenwand", "glass", -4.5, 5.6, 0, 0.2, 6.6, 3.6, GLASS, "Glass")
		add("Bank", "trim", 0, 2.6, 1.0, 5.6, 0.4, 1.4, { 140, 100, 64 }, "Wood")
		add("Fahrplan", "sign", 3.2, 5.2, 1.7, 1.8, 2.6, 0.2, { 255, 214, 60 }, "SmoothPlastic")
		-- Haltestellenschild vor dem Häuschen (zur Straße hin versetzt)
		add("SchildMast", "trim", 6.4, 5.5, -2.4, 0.4, 11, 0.4, { 120, 124, 130 }, "Metal")
		add("SchildScheibe", "sign", 6.4, 10.4, -2.4, 0.3, 3.4, 3.4, { 0, 140, 70 }, "SmoothPlastic", { shape = "Cylinder", yaw = 90 })
		add("SchildH", "sign", 6.4, 10.4, -2.62, 2.4, 2.4, 0.2, { 0, 0, 0 }, "SmoothPlastic", { text = { s = "H", color = { 255, 232, 60 } } })
	end
	return { parts = parts, stats = { stops = #cfg.busstops } }
end

return Bus
