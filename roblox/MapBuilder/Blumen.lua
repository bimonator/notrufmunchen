-- Blumen.lua
-- Blumenbeet statt einfarbiger Fläche: Erde, dunkler Blattteppich, optional niedrige Buchseinfassung und viele einzelne Blumen (Stiel, Blüte, bei jeder dritten eine
-- gelbe Mitte) in drei Farben, die in Bändern von außen nach innen wechseln (Parterre-Muster), mit etwas Zufall in Höhe, Größe und Lage.
-- add(name, kind, x, y, z, sx, sy, sz, color, material, extra) ist der Teile-Erzeuger des Aufrufers; rng() liefert Zufallszahlen in [0, 1).

local Blumen = {}

-- Farbbänder (außen, mittig, innen)
Blumen.PALETTES = {
	{ { 214, 60, 76 }, { 244, 204, 64 }, { 238, 238, 232 } }, -- rot, gelb, weiß
	{ { 150, 90, 185 }, { 240, 150, 190 }, { 238, 238, 232 } }, -- lila, rosa, weiß
	{ { 244, 204, 64 }, { 236, 132, 48 }, { 200, 62, 72 } }, -- gelb, orange, rot
	{ { 108, 128, 216 }, { 150, 90, 185 }, { 238, 238, 232 } }, -- blau, lila, weiß
}
local SOIL, LEAF, STEM, HEDGE, CENTER = { 84, 60, 42 }, { 58, 108, 56 }, { 66, 130, 60 }, { 46, 92, 52 }, { 246, 206, 60 }

-- Beet mit Mitte (cx, cz), Breite w (x) und Tiefe d (z) auf dem Boden y; palette = Index in PALETTES; edging = Buchseinfassung ringsum.
-- Liefert die Zahl der Blumen.
function Blumen.bed(add, cx, cz, w, d, y, rng, palette, edging)
	local pal = Blumen.PALETTES[(palette - 1) % #Blumen.PALETTES + 1]
	add("BeetErde", "decor", cx, y + 0.2, cz, w, 0.4, d, SOIL, "Ground")
	add("BeetLaub", "decor", cx, y + 0.45, cz, w - 0.6, 0.2, d - 0.6, LEAF, "Grass")
	if edging then
		for _, e in ipairs({ { 0, -d / 2 + 0.3, w, 0.6 }, { 0, d / 2 - 0.3, w, 0.6 }, { -w / 2 + 0.3, 0, 0.6, d - 1.2 }, { w / 2 - 0.3, 0, 0.6, d - 1.2 } }) do
			add("BeetRand", "decor", cx + e[1], y + 0.55, cz + e[2], e[3], 1.1, e[4], HEDGE, "Grass", { collide = true })
		end
	end
	local step = 1.7
	local n = 0
	local nx, nz = math.max(1, math.floor((w - 1.6) / step) + 1), math.max(1, math.floor((d - 1.6) / step) + 1)
	for i = 0, nx - 1 do
		for j = 0, nz - 1 do
			local u = nx > 1 and (i / (nx - 1) * 2 - 1) or 0 -- -1 .. 1 über das Beet
			local v = nz > 1 and (j / (nz - 1) * 2 - 1) or 0
			local q = math.max(math.abs(u), math.abs(v)) -- 1 am Rand, 0 in der Mitte
			local band = q > 0.72 and 1 or (q > 0.36 and 2 or 3)
			if rng() < 0.12 then band = band % 3 + 1 end -- ab und zu eine Blume in der Nachbarfarbe
			local fx = cx + (nx > 1 and u * (w - 1.6) / 2 or 0) + (rng() - 0.5) * 0.7
			local fz = cz + (nz > 1 and v * (d - 1.6) / 2 or 0) + (rng() - 0.5) * 0.7
			local h = 0.7 + 0.6 * rng()
			local size = 0.6 + 0.3 * rng()
			add("Blumenstiel", "decor", fx, y + 0.55 + h / 2, fz, 0.12, h, 0.12, STEM, "Grass")
			add("Blume", "decor", fx, y + 0.55 + h + size * 0.2, fz, size, size, size, pal[band], "SmoothPlastic", { shape = "Ball" })
			if (i + j) % 3 == 0 then add("BlumeMitte", "decor", fx, y + 0.55 + h + size * 0.45, fz, 0.28, 0.28, 0.28, CENTER, "SmoothPlastic", { shape = "Ball" }) end
			n = n + 1
		end
	end
	return n
end

return Blumen
