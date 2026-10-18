-- Baenke.lua
-- Parkbank, 40 % größer als die erste Fassung (6,2 lang, 2,1 tief, Sitzhöhe 2): drei Sitzlatten, drei geneigte Rückenlatten, Gusseisen-Seitenteile mit Armlehnen und
-- zwei unsichtbare Sitze (Part-Feld seat = true, Builder macht daraus ein Seat; man setzt sich, indem man hineinläuft). Die Figur blickt in Richtung lokal -z.
-- add(name, kind, x, y, z, sx, sy, sz, color, material, extra) ist der Teile-Erzeuger des Aufrufers (extra: yaw, pitch, collide, seat, transparency).

local Baenke = {}

local WOOD, IRON = { 150, 100, 62 }, { 46, 50, 54 }
local TILT = math.rad(12) -- Rückenlehne nach hinten geneigt

-- Bank bei (x, z) auf dem Boden y; yaw = Blickrichtung wie bei Teilen (lokale x-Achse läuft entlang der Bank, die Lehne steht bei lokal +z)
function Baenke.add(add, x, y, z, yaw)
	local r = math.rad(yaw)
	local c, s = math.cos(r), math.sin(r)
	local function put(name, lx, ly, lz, sx, sy, sz, color, mat, extra)
		extra = extra or {}
		extra.yaw = yaw
		add(name, "bench", x + lx * c + lz * s, y + ly, z - lx * s + lz * c, sx, sy, sz, color, mat, extra)
	end
	local LEN, BACK = 6.2, 0.95 -- Länge, Lage der Rückseite (lokal z)
	for _, lz in ipairs({ -0.74, 0, 0.74 }) do put("BankLatte", 0, 1.89, lz, LEN, 0.22, 0.62, WOOD, "Wood", { collide = true }) end
	for _, lx in ipairs({ -1.5, 1.5 }) do put("BankSitz", lx, 2.0, 0, 2.9, 0.16, 1.9, WOOD, "Wood", { collide = true, seat = true, transparency = 1 }) end
	for _, ly in ipairs({ 2.6, 3.2, 3.8 }) do put("BankRueckenlatte", 0, ly, BACK + (ly - 1.95) * math.tan(TILT) - 0.14, LEN - 0.4, 0.5, 0.16, WOOD, "Wood", { pitch = 12 }) end
	for _, sd in ipairs({ -1, 1 }) do
		local lx = sd * 2.85
		put("BankRahmen", lx, 0.95, -0.8, 0.2, 1.9, 0.45, IRON, "Metal") -- vorderes Bein
		put("BankRahmen", lx, 0.95, BACK, 0.2, 1.9, 0.45, IRON, "Metal") -- hinteres Bein
		put("BankRahmen", lx, 1.72, 0.07, 0.2, 0.2, 2.1, IRON, "Metal") -- Sitzträger
		put("BankRahmen", lx, 3.1, BACK + 1.15 * math.sin(TILT), 0.2, 2.4, 0.4, IRON, "Metal", { pitch = 12 }) -- Rückenpfosten über dem hinteren Bein
		put("BankArmlehne", lx, 2.92, -0.3, 0.26, 0.18, 1.7, IRON, "Metal")
		put("BankRahmen", lx, 2.45, -0.8, 0.2, 0.9, 0.2, IRON, "Metal") -- Stütze der Armlehne
	end
end

return Baenke
